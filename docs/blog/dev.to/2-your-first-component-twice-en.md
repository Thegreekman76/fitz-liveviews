---
title: "Your first Fitz LiveViews component, twice: SSR and WASM from one source"
published: false
description: One .fitzv component, two compile targets — server-rendered over a WebSocket, or compiled to WebAssembly for offline. Same file, no rewrite. A walkthrough with a counter.
tags: webdev, rust, opensource, frontend
series: FitzLiveViews
cover_image:
canonical_url:
---

> TL;DR — A [Fitz LiveViews](https://github.com/Thegreekman76/fitz-liveviews) component is a single `.fitzv` file. The interesting part: **the same file compiles to two different targets** with no rewrite. **Server-rendered** (SSR) — the server holds the state, renders HTML, and patches the browser over a WebSocket; best for shared, DB-driven, multi-user state. **Client-WASM** — the same component compiles to WebAssembly and runs entirely in the browser; best for offline, zero-round-trip widgets. This post builds a counter and ships it both ways. *(Part 2 of the FitzLiveViews series — [start here](https://dev.to/) if you missed part 1.)*

In [part 1](https://dev.to/) I made the pitch: real-time UI in one language, no JavaScript build. Now let's build something and ship it two ways from the same source.

## The component

Here's a counter as a single-file component (`.fitzv`) — state, events, template, style:

```
component Counter {
  state { count: Int = 0 }

  event increment() { count = count + 1 }
  event decrement() { count = count - 1 }
  event reset() { count = 0 }

  <template>
    <div id="counter-app">
      <p>Count: {count}</p>
      <button @click="increment">+1</button>
      <button @click="decrement">-1</button>
      <button @click="reset">Reset</button>
    </div>
  </template>

  <style scoped>
    #counter-app { padding: 1.5rem; font-family: system-ui; }
    button { padding: 0.5rem 1rem; margin: 0 0.25rem; }
  </style>
}
```

`state` is the reactive data. Each `event` handler mutates it directly — no `setState`, no reducers. `<template>` is real markup; `{count}` interpolates and auto-escapes. `@click="increment"` binds a DOM event to a handler. `<style scoped>` is CSS namespaced to this component. If you've written Vue or Svelte, this is familiar — the difference is what happens next.

## Target 1 — server-rendered (over a WebSocket)

The SSR target is the default. The component runs on the server; a tiny `main.fitz` wires it into an HTTP route (first paint) and a WebSocket route (the live layer):

```
from fitz_liveviews import html_response, live_layout, LiveFrame,
  diff_html, component, dispatch_component_events
from Counter import Counter, Counter_render,
  Counter_increment, Counter_decrement, Counter_reset

@get("/")
fn page() -> Response {
  return html_response(live_layout("/live/counter", "counter-app",
    component("Counter", "root")))
}

@ws("/live/counter")
async fn socket(ws: WsConn<LiveFrame>) {
  let last = component("Counter", "root").raw
  loop {
    let frame = ws.recv()?
    let _ = dispatch_component_events(frame)   // route the event to the component
    let new_html = component("Counter", "root").raw
    ws.send(LiveFrame { html: new_html, patches: diff_html(last, new_html) })?
    last = new_html
  }
}

@server(3000) fn main() => 0
```

What happens on a click: the browser sends the event over the WebSocket → `dispatch_component_events` routes it to the handler → the handler mutates state → the server recomputes the HTML, **diffs it against the previous render, and sends only the patches**. The browser applies them. You never wrote client JavaScript, never defined an API, never serialized a payload. The state lives on the server, so it survives reloads and can be shared or DB-backed.

`fitz run`, open `http://localhost:3000`, click. That's the whole app.

## Target 2 — client-WASM (offline, no server)

Now the *same `Counter.fitzv`* — no changes — compiled to WebAssembly. Declare it as a wasm bin in `fitz.toml`:

```toml
[[bin]]
name = "counter"
main = "Counter.fitzv"
target = "wasm-client"
mount = "#app"       # required: where the component mounts in the page
```

Build it:

```bash
fitz build --bin counter --target wasm-client
# → emits a wasm-bindgen + web-sys crate, runs wasm-pack,
#   produces counter.js + counter_bg.wasm
```

Drop the two files into a page with `<div id="app"></div>` and a `<script type="module">import init from './counter.js'; init()</script>`, and the counter runs **entirely in the browser** — no server, no WebSocket. The state lives in `Rc<RefCell<T>>` cells; `@click` handlers mutate the DOM directly.

**It's running right now** in the [live component gallery](https://thegreekman76.github.io/fitz-liveviews/live/) — that counter is this exact file compiled to WASM. The bundle is **11.4 KB gzipped** for the whole thing (no separate framework runtime to load first).

## Same source — so which target?

| | Server-rendered | Client-WASM |
|---|---|---|
| State lives | on the server | in the browser |
| Multi-user / shared / DB-backed | ✅ natural | ❌ (per-tab) |
| Works offline | ❌ (needs the socket) | ✅ |
| Round-trip per interaction | one WS message | none |
| Best for | dashboards, CRUD, chat, anything shared | widgets, calculators, offline tools |

The point isn't "pick one forever." It's that a presentational component — a badge, a card, a stepper — can serve both, and you decide per component. Shared state? SSR. Local, offline, zero-latency? WASM. Same `.fitzv`.

## What's next in this series

- **#3 — Forms, payloads, and live inputs.** How events carry data: click payloads, form submits, and the `@input` / `@change` value binding.
- **#4+ — Building the flagship.** A real admin panel: cookie auth, live DataGrids over Postgres, i18n, and Docker.

Star the [repo](https://github.com/Thegreekman76/fitz-liveviews) if the one-source-two-targets idea clicks. Next: forms and payloads.
