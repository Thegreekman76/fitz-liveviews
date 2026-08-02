---
title: "Server functions in Fitz: call the server from a WASM component, no plumbing"
published: false
description: A `@rpc async fn` in a classic Fitz module is callable directly from a client-WASM `.fitzv` — `get_user(42).await?` — as if it were local. The compiler emits both halves from one declaration, typed end-to-end, zero dependencies.
tags: webdev, rust, opensource, frontend
series: FitzLiveViews
cover_image:
canonical_url:
---

> TL;DR — Mark an `async fn` with `@rpc` and call it from a `.fitzv`
> component **as if it were local**: `let u = get_user(42).await?`. The
> compiler generates **both halves** from that one declaration — a
> `POST /__rpc/get_user` endpoint on the server (which can touch the DB,
> auth, secrets) and a `fetch`-based stub on the client — with the same
> `type` shared back and front. No hand-written HTTP handler, no
> `fetch`, no JSON glue, no route strings, no external deps. *(Part 7 of
> the FitzLiveViews series — the "whole stack, no plumbing" moment.)*

Earlier parts showed a `.fitzv` component compiling **two ways**: to
server-rendered HTML (LiveViews over a WebSocket) and to a standalone
WebAssembly SPA. Both are great — but a component in the browser is an
island. Anything *real* — reading the database, checking a token — has
to happen on the server, and the classic bridge is plumbing: write an
endpoint, write a `fetch`, marshal the JSON both ways, and keep the
types in sync by hand.

This part erases all of that with one decorator.

## One declaration, both halves

Here's a server function. It's a normal `async fn` — it could open a
Postgres connection, run an ORM query, verify a JWT. The only special
thing is `@rpc`:

```
// api.fitz (classic — has db, auth, secrets)
type User {
  id: Int
  name: Str
}

@rpc
async fn get_user(id: Int) -> Result<User> {
  let conn = db.connect(db_url()).await?
  return User.where(fn(u) => u.id == id).first(conn).await
}
```

And here's the client calling it, inside a `.fitzv` component's event
handler:

```
// App.fitzv (client-WASM)
from api import get_user, User

component App {
  state { name: Str = "" }

  event load() {
    let u = get_user(42).await?   // ← a round-trip, typed, like a local call
    name = u.name
  }

  <template>
    <p>{name}</p>
    <button @click="load">Load user 42</button>
  </template>
}
```

That's the whole app. No `fetch`. No `/api/users/:id`. No
`JSON.parse` + a hand-written `User` interface that drifts from the
server. The `User` type lives **once** in `api.fitz`; the server
compiles it into a native binary, the client compiles it into WASM, and
they share the definition.

## What the compiler actually emits

`@rpc` is invisible-but-typed because the compiler writes both sides for
you.

**Server side** (`fitz build --bin server`): the `@rpc` fn is mounted as
`POST /__rpc/get_user`. The request body is a JSON object with one field
per parameter (`{"id": 42}`); each param is deserialized from its field,
the function runs, and its `Result<T>` becomes `200` + the JSON of `T`
(Ok) or `500` + `{"error": ...}` (Err). It reuses the entire `@post`
pipeline — observability, panic-catch, everything.

**Client side** (`fitz build --bin web --target wasm-client`): the
imported `@rpc` fn is emitted as an async `fetch` stub — its
(server-side) body is **not** transpiled into the WASM. The stub
serializes the args, POSTs same-origin (so the session cookie rides
along), and maps the reply back to `Result<T>`. And because the event
handler now `.await`s, the compiler splits it into a sync wrapper + an
async worker (`spawn_local`), so state updates and a re-render fire when
the reply lands.

You write `get_user(42).await?`. You get a network round-trip with a
typed result.

## It really runs

The [runnable example](https://github.com/Thegreekman76/fitz/tree/main/examples/view/rpc)
is a two-button SPA plus a server binary. Verified end-to-end in real
Chrome: click "Greet" and the greeting comes back from the server
(`"Hello, world!"`); click "Load user" and the `User` is fetched,
deserialized, and rendered (`"Ada"`) — zero page errors. The client
crate compiles to a real `.wasm` via `wasm-pack`; the server answers the
exact `/__rpc/*` routes.

```bash
fitz build --bin server     # mounts POST /__rpc/* on :3838
fitz build --bin web        # → target/wasm/web/{web.js, web_bg.wasm}
```

Serve the SPA from the **same origin** as the server (in production,
have the server serve the bundle, or put both behind one reverse proxy)
so the relative `fetch("/__rpc/...")` reaches it.

## Why this is different

Server functions aren't new — Next.js Server Actions, Remix
loaders/actions, SvelteKit `+page.server`, tRPC, Phoenix all have the
pattern. What's different in Fitz:

- **No infrastructure step.** No `"use server"` directive, no tRPC
  router, no code generator. One decorator; the compiler does the rest.
- **The same `type`, literally.** Not "inferred types" across a
  boundary — the exact same `User` definition compiled to both a native
  struct and a WASM struct. Zero drift, by construction.
- **Zero external deps.** The server half reuses the built-in HTTP
  stack; the client half pulls in `fetch` + `serde` only when a crate
  actually uses `@rpc`. No `@trpc/*`, no bundler magic.
- **One language, both ends.** The server fn and the client component
  are the same Fitz, checked by the same checker.

## The honest edges (MVP)

- A nominal type that crosses the wire is imported into the `.fitzv`
  too (`from api import ..., User`) so the client gets its struct.
- Stacked auth on the generated endpoint (`@authenticated`/`@admin`) is
  a post-MVP refinement; for now the same-origin session cookie travels
  with the request and you check the token inside the `@rpc` body.
- The component re-renders once, when the reply arrives — a mid-request
  "loading…" flash is a later fine-grained-reactivity slice.

That's the fullstack loop closed: a component in the browser calling a
function on the server, typed end-to-end, with nothing in between that
you had to write. Next up: SSR hydration — the same `.fitzv` rendered on
the server for first paint, then the WASM runtime taking over the
existing DOM (including the state your `@rpc` calls produced).
