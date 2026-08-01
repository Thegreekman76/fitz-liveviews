---
title: "Building the flagship (1): browser-correct cookie auth in Fitz"
published: false
description: The Admin panel's auth, in full — why it's cookie-based and not Bearer, an Argon2id + JWT login that Sets a HttpOnly cookie, and protected pages that resolve the user via the ORM and redirect to /login. Plus the responsive shell.
tags: webdev, rust, opensource, frontend
series: FitzLiveViews
cover_image:
canonical_url:
---

> TL;DR — Fitz has `@auth_provider` / `@authenticated` for Bearer-token APIs, but a **browser** admin panel needs something different: the browser can't send an `Authorization` header on a page navigation or a WebSocket handshake, and an unauthenticated request should **redirect to `/login`**, not return a JSON 401. So the [flagship Admin app](https://github.com/Thegreekman76/fitz-liveviews/tree/main/examples/admin) uses a session **cookie**: login verifies the password with **Argon2id**, signs a **JWT**, and puts it in an `HttpOnly` cookie; every protected page reads the cookie, resolves the user through the **ORM**, and redirects on failure — the way Django or Rails gate a browser session. All in Fitz, no external auth library. *(Part 4 of the FitzLiveViews series — the first of a few on the flagship.)*

Parts 1–3 built components in isolation. Now the real thing: a complete back-office admin panel — auth, a responsive shell, live DataGrids over Postgres, i18n, Docker. This post is auth and the shell; the next ones are the grids.

> **The code below is excerpted from the real app** ([`examples/admin/`](https://github.com/Thegreekman76/fitz-liveviews/tree/main/examples/admin)) to show the shape — it's a 14-file, Postgres-backed, dockerized project, so the guaranteed-to-work path is to clone it and run `docker compose up` (see "Try it" at the end). The snippets are faithful to the source; the repo is the runnable artifact.

## Why cookies, not `@auth_provider`

Fitz core ships `@auth_provider` + `@authenticated` — and they're great for a JSON API where the client sends `Authorization: Bearer <token>` and gets a `401` on failure. A browser admin panel wants two different things:

1. **The browser can't send an `Authorization` header** on plain page navigation, or on a WebSocket handshake. It *does* send cookies, automatically. So the session token rides in an `HttpOnly` cookie.
2. **An unauthenticated page should redirect to `/login`**, not dump a JSON error at the user.

So the app hand-rolls a cookie session — which in Fitz is about 40 lines, because JWT and password hashing are built into the language.

## Login — Argon2id + JWT → Set-Cookie

Login is a `@post` that takes JSON credentials, verifies the password against the stored Argon2id hash, signs a JWT, and returns it as a `Set-Cookie` header using the `Response { ... }` built-in:

```
@post("/login")
async fn login_submit(creds: Credentials, cookie: Str?) -> Response {
  let user = match find_by_email(creds.email).await { ... }

  // hash.verify is Argon2id — built into Fitz, no passlib/bcrypt dep.
  if (not hash.verify(creds.password, user.password_hash)) {
    return login_failed(...)
  }

  let claims = { "email": user.email, "role": user.role }
  let token = jwt.encode(claims, jwt_secret())     // HS256, built-in

  let set_cookie = session_cookie_name() + "=" + token
    + "; HttpOnly; Path=/; SameSite=Lax; Max-Age=86400"

  return Response {
    status: 200,
    headers: { "Set-Cookie": set_cookie },
  }
}
```

`hash.verify` (Argon2id) and `jwt.encode` (HS256) are Fitz built-ins — no `pip install passlib python-jose`, no `npm install bcrypt jsonwebtoken`. The `Response { ... }` built-in is what lets a handler set a custom header instead of returning plain JSON.

*(One wrinkle: login posts JSON via a small `fetch`, not a native `<form>`, because Fitz `@post` handlers take a JSON body, not form-urlencoded. A future core enhancement can accept form posts.)*

## The session check — cookie → JWT → user (via the ORM)

Resolving the logged-in user is: pull the token out of the raw `Cookie` header, decode the JWT, read the `email` claim, and look the user up in Postgres — through the Fitz ORM:

```
async fn user_from_cookie(cookie: Str?) -> Result<User> {
  let token  = token_from_cookie(cookie)?          // parse the Cookie header
  let claims = jwt.decode(token, jwt_secret())?    // verify signature + expiry
  let email  = match claims.get("email") { ... }

  let conn = db.connect(db_url()).await?
  return User.where(fn(u) => u.email == email).first(conn).await
}
```

Any failure — missing cookie, bad signature, expired token, unknown user — surfaces as `Err`, which a protected page turns into a redirect. Notice `User.where(fn(u) => u.email == email).first(conn)`: that's the native Fitz ORM, a typed query against Postgres, in the same file as the auth.

## Protecting a page

A protected handler reads the cookie with `@header(name="cookie")` and redirects to `/login` on any auth failure — a real `303`, browser-correct:

```
@header(name="cookie")
@get("/")
async fn dashboard(cookie: Str?) -> Response {
  let user = match user_from_cookie(cookie).await {
    Ok(u) => u,
    Err(_) => return redirect_to("/login"),   // 303 → /login
  }
  // ... render the dashboard for `user` ...
}
```

That's the whole gate. An unauthenticated request to `/` gets `303 → /login` — exactly what a browser expects, and what you can't express with a JSON-401 auth provider. `/logout` clears the cookie (`Max-Age=0`) and redirects. I verified the full flow end-to-end: `GET /` with no cookie → `303 /login`; `POST /login` → `Set-Cookie` with the `HttpOnly` JWT; `GET /` with the cookie → the dashboard.

## The responsive shell

Around every protected page is a shell built entirely from the companion UI library (`AppShell` / `Sidebar` / `Topbar` / `Breadcrumbs` / `ThemeToggle`):

- **Collapsible sidebar** on desktop, **off-canvas drawer** on mobile — works down to 320px.
- A **light / dark / auto** theme switch, persisted per-browser and **applied before first paint** (a tiny inline script reads the preference and sets the theme attribute before the body renders — no flash of the wrong theme).
- A **🌐 ES / EN** language switch (`GET /lang/{code}` sets a language cookie and redirects back).

Everything is themed through `--flv-*` design tokens aliased to the admin's palette, so the whole panel — every packaged component — inherits the theme switch for free.

## Try it

```bash
git clone https://github.com/Thegreekman76/fitz-liveviews
cd fitz-liveviews/examples/admin
docker compose up --build          # Postgres + the app, one command
# → http://localhost:3000/   login: admin@fitz.dev / admin1234
```

## What's next in this series

- **#5 — The live DataGrid.** The flagship's centerpiece: an employees grid with search, filters, sorting, and pagination, re-querying Postgres and diff-patching over a WebSocket on every keystroke.

Star the [repo](https://github.com/Thegreekman76/fitz-liveviews) if a real app in one language is your thing. Next: the live grid.
