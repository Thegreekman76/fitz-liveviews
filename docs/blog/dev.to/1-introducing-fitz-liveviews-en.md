---
title: "Introducing Fitz LiveViews: real-time UI in one language, zero JS build"
published: false
description: A real-time, server-rendered UI framework for the Fitz language — WebSocket diffing, no JavaScript build step, Phoenix LiveView-inspired, with an optional client-WASM target so the same component runs offline too.
tags: webdev, rust, opensource, frontend
series: FitzLiveViews
cover_image:
canonical_url:
---

> TL;DR — **Fitz LiveViews** is a real-time UI framework for [Fitz](https://github.com/Thegreekman76/fitz), a compiled, gradually-typed language where HTTP, WebSockets, auth, and an ORM are part of the syntax. You write single-file components (`.fitzv`) with `state` / `event` / `<template>`, and the server renders HTML, diffs it, and patches the browser over a WebSocket — **no JavaScript build step, no client framework**. The same `.fitzv` can *also* compile to WebAssembly for offline, zero-round-trip widgets. There's a live component gallery, a course, and a full flagship app (an admin panel with auth + Postgres + Docker) already built with it. **Repo**: [github.com/Thegreekman76/fitz-liveviews](https://github.com/Thegreekman76/fitz-liveviews) · **Docs**: [thegreekman76.github.io/fitz-liveviews](https://thegreekman76.github.io/fitz-liveviews/)

This is the first post in the **FitzLiveViews** series. I'll start with the pitch and the setup; the following posts build things.

## The problem

Building a modern web UI usually means two languages, two type systems, and a build pipeline: a backend (Python / Node / Go) plus a frontend framework (React / Vue / Svelte) plus its toolchain (Vite / Webpack / Babel). You duplicate your types across the wire, you keep two mental models in sync, and `node_modules` grows a personality of its own.

Phoenix LiveView (Elixir) showed there's another way: render on the server, push diffs over a WebSocket, and let the browser stay dumb. No client framework, no API to hand-write, no JSON serialization dance. Fitz LiveViews brings that model to Fitz — and adds a twist: the *same component* can also compile to WebAssembly when you want purely client-side, offline interactivity.

## What Fitz LiveViews looks like

A component is a single `.fitzv` file — state, event handlers, and a template, like Vue or Svelte:

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
}
```

On the **server-rendered** target, the framework registers this component, sends the initial HTML, and — on every event — recomputes the HTML, diffs it, and sends only the patches over a WebSocket. The browser applies them. You never write client JavaScript, never define an API, never serialize a payload by hand.

On the **client-WASM** target (`fitz build --target wasm-client`), the *same file* compiles to a `wasm-bindgen` + `web-sys` bundle that mounts and mutates the DOM directly — offline, no server. A single component is ~12 KB gzipped.

## What makes it different

- **One language, back to front.** Components, handlers, and the server all live in Fitz. Your `type User { ... }` is the same on both sides — no duplicated DTOs.
- **Zero JavaScript build.** No `npm install`, no bundler, no `node_modules`. The `fitz` binary compiles everything.
- **Type-checked templates.** The template has its own checker: a prop of the wrong type, an `@event` bound to a handler that doesn't exist, a `<slot slot="x">` with no `<slot name="x">` — all caught at compile time, pointing at the `.fitzv` and the line.
- **Dual-target: SSR *or* WASM from one source.** Server-rendered for shared, DB-driven, multi-user state; client-WASM for local, zero-round-trip, offline widgets. Same component model either way.
- **A packaged UI library.** `fitz_liveviews.ui.*` ships drop-in components (Badge, Card, DataGrid, Pager, Input, Select, Tabs, Stepper, TreeView, …), themed through `--flv-*` design tokens.

There's a **[live component gallery](https://thegreekman76.github.io/fitz-liveviews/live/)** — real components compiled to WebAssembly, running in your browser, no server. Click around.

## By the numbers

These are measured payload/build numbers from the flagship admin app and the gallery — not synthetic throughput claims:

- **A full server-rendered dashboard page ships ~1.1 KB of JavaScript** (3 tiny inline `<script>` blocks: theme-before-paint + the WebSocket live client), **zero external `<script src>`, and zero build step.** The page HTML is ~38 KB and that's *the whole thing* — there's no framework runtime to download first. Compare that to an SPA, where the framework runtime alone is ~40 KB (Svelte-ish) to ~140 KB (React + ReactDOM) *before* your code and your hydration payload.
- **A client-WASM component is ~12 KB gzipped** — the *entire* component, not "your code on top of a 100 KB runtime." The counter demo is 11.4 KB gzipped; the full 12-widget composed gallery is ~44 KB.
- **Zero `node_modules`, zero bundler config.** The `fitz` binary is the whole toolchain. `git clone` → `fitz run`.
- **Native binary ≈ 9× faster per interaction than the interpreter** (`fitz run` ↔ `fitz build` render bit-for-bit identical), so you develop on the interpreter and ship the binary.

(Cross-framework request-throughput benchmarks are honest future work — I'd rather ship measured payload numbers than hand-wave a load test.)

## How it compares

| | **Fitz LiveViews** | Phoenix LiveView | Hotwire (Turbo) | React/Vue/Svelte (SPA) | HTMX |
|---|---|---|---|---|---|
| Real-time diff over WebSocket | ✅ built-in | ✅ built-in | ~ (Turbo Streams) | manual | ~ (extension) |
| JavaScript build step | **none** | none | none | **required** | none |
| Languages in the stack | **1** (Fitz) | 1 (Elixir) | 2 (Ruby + JS) | 2+ (backend + JS/TS) | 1 backend + HTML |
| Offline / client-only target | ✅ **WASM, same source** | ❌ | ❌ | ✅ (JS) | ❌ |
| Type-checked templates | ✅ compiler | ~ (HEEx) | ❌ | ~ (TS/JSX) | ❌ |
| Compiles to a native binary | ✅ | ❌ (BEAM VM) | ❌ | ❌ | ❌ |
| Packaged UI component library | ✅ `fitz_liveviews.ui.*` | community | community | **huge ecosystem** | community |

Where Fitz LiveViews is genuinely different: **one language across the whole stack**, a **dual SSR/WASM target from a single source**, **compilation to a standalone native binary**, and **compiler-checked templates**. Where it's honestly behind: it's new, so the ecosystem is small — React/Vue/Svelte have a decade of libraries and hiring pools. If that trade — a smaller ecosystem for a radically simpler stack — sounds right for what you're building, read on.

## Getting started

**1. Install Fitz.** Fitz LiveViews is a library for the Fitz language, so you install Fitz first:

```bash
curl -sSf https://thegreekman76.github.io/fitz/install.sh | sh
fitz --version
```

The Fitz course walks through install / uninstall / updating in detail — see **[Fitz course · C1 — Installation](https://thegreekman76.github.io/fitz/curso/m1-setup/c1-instalacion/)**.

**2. Install the editor extensions.** Two VSCode extensions give you syntax highlighting, diagnostics, hover, and go-to-definition:

- **Fitz** — for `.fitz` files (the language). Grab the `.vsix` from the [Fitz releases](https://github.com/Thegreekman76/fitz/releases) and `code --install-extension fitz-language-*.vsix`.
- **Fitz LiveViews** — for `.fitzv` single-file components. Grab it from the [fitz-liveviews releases](https://github.com/Thegreekman76/fitz-liveviews/releases) and `code --install-extension fitz-liveviews-*.vsix`.

**3. Add the dependency.** In your project's `fitz.toml`:

```toml
[dependencies]
fitz_liveviews = { git = "https://github.com/Thegreekman76/fitz-liveviews" }
```

That's the whole setup — no Node, no bundler, no `package.json`.

## It's not a toy — there's a flagship

To prove the model on something real, there's a complete back-office **admin panel** built entirely in Fitz + Fitz LiveViews: login (Argon2id + a signed JWT session cookie), a responsive shell (collapsible sidebar, mobile drawer down to 320px, ES/EN switch, light/dark/auto theme), a dashboard with real counts from Postgres, and two live CRUD screens (employees + departments) with search, filters, sorting, pagination, rich tabbed forms, multi-delete, group-by, per-row expand, and CSV export — all diffed over WebSockets, all internationalized, all in one `docker compose up`.

Every reusable piece of it is a packaged component in `fitz_liveviews.ui.*` — the library was *extracted* from this app. It's the living reference.

## Where to go

- **Repo** — [github.com/Thegreekman76/fitz-liveviews](https://github.com/Thegreekman76/fitz-liveviews)
- **Docs** — [thegreekman76.github.io/fitz-liveviews](https://thegreekman76.github.io/fitz-liveviews/)
- **Live gallery** — [/live](https://thegreekman76.github.io/fitz-liveviews/live/)
- **Course** — a hands-on, chapter-by-chapter build ([overview](https://thegreekman76.github.io/fitz-liveviews/course/))
- **Client-WASM guide** — the offline-widget target ([client-wasm](https://thegreekman76.github.io/fitz-liveviews/client-wasm/))

## What's next in this series

- **#2 — Your first component, twice.** A counter that renders server-side over a WebSocket *and* compiles to WebAssembly — one source, two targets.
- **#3 — Forms, payloads, and live inputs.** How events carry data, and how `@input` / `@change` bind form values.
- **#4+ — Building the flagship.** A deep dive into the admin panel: cookie auth, live DataGrids over Postgres, the packaged UI library, i18n, and Docker.

If real-time UI without a JavaScript build sounds good, star the [repo](https://github.com/Thegreekman76/fitz-liveviews) and follow the series. Next up: the counter, twice.
