# Counter — Fitz LiveViews Phase 2 hello world

A real-time counter driven by WebSocket events. Click a button, the
number updates without a page reload. No JavaScript build step, no
`npm install`, no bundler.

## Run

```powershell
fitz run
```

Then open http://127.0.0.1:3000/ — ideally in two browser tabs at once
so you can watch both stay in sync (all tabs share one server-side
state instance since the Phase 11.6.e migration; see the note at the
bottom).

## What each file does

- **`fitz.toml`** — package manifest. Declares this project as a `[bin]`
  and pulls in the `fitz_liveviews` library via a `path = "../.."`
  dependency.
- **`src/Counter.fitzv`** — the counter as a single-file component:
  1. `state { count: Int = 0 }` — the state
  2. `event increment() { count = count + 1 }` (+ `decrement` + `reset`)
  3. `<template>` — the HTML with `@click="handler"` attrs
- **`src/main.fitz`** — the tiny shim wiring the component into HTTP:
  1. `from Counter import ...` — brings the `@live_component`-generated
     symbols into scope
  2. `flv_register(...)` — registers the component at boot (manual for
     now; see "What's missing" below)
  3. `@get("/")` — initial HTML render + client-side script bundle
  4. `@ws("/live/counter")` — routes frames via
     `dispatch_component_events(frame)` (no manual `state = ...`
     mutation loop like the pre-11.6.e version)
  5. `@server(3000)` — binds the port

## Poking under the hood

Check the server logs and the network tab of your browser's dev
tools. You'll see:

1. `GET /` returns the initial HTML.
2. The browser upgrades a connection at `ws://127.0.0.1:3000/live/counter`.
3. Each click sends a small JSON frame like
   `{"event":"increment","payload":{"component_name":"Counter","instance_id":"root"}}`.
4. The server calls `dispatch_component_events(frame)` which routes the
   event to the `Counter_increment` fn (auto-generated from the
   `event increment()` block in `Counter.fitzv`), mutating the
   component's state in `COMPONENT_STATE_STORE`.
5. The server re-renders the component and ships an incremental patch
   (diff against the previous HTML) so the browser DOM updates without
   losing focus.

## Migration notes (Phase 11.6.e)

This example was migrated from raw-string HTML (`html("""<div>...</div>""")`
inside a `render(state)` fn) to a single-file component (`.fitzv`) in
Phase 11.6.e. Key changes vs the pre-11.6.e version:

- **State + template + events live in `Counter.fitzv`** as an SFC.
  The compiler transforms it into classic Fitz source with
  `@live_component("Counter")` + `@render_for` + `@on` decorators,
  which fitz-liveviews's runtime picks up.
- **`main.fitz` shrinks** to the HTTP handlers + a manual
  `flv_register(...)` call. Event routing is a single
  `dispatch_component_events(frame)` call — no per-event `if` branches
  like the original.
- **Behaviour change**: shared state across all tabs (via
  `component("Counter", "root")`) instead of per-connection state.
  Matches the Phase 4 dashboard/kanban model.

## What's missing (comes later)

- **Cross-module auto-inject of `flv_register`.** v0.20.1's implicit
  registration only scans the top-level program for `@live_component`
  types, so when the type is imported from a `.fitzv` sibling the
  registration is manual. Follow-up mini-fase after 11.6.e will thread
  `env.live_components` cross-module.
- **`@live` decorator.** The current `@get` + `@ws` pattern is a
  compact but two-step shape. `@live("/counter")` collapsing both into
  one decorator is a language enhancement pending Fitz core support.

See [`ROADMAP.md`](../../ROADMAP.md) at the project root for the full
plan.
