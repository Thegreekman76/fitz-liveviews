# Counter — Fitz LiveViews Phase 2 hello world

A real-time counter driven by WebSocket events. Click a button, the
number updates without a page reload. No JavaScript build step, no
`npm install`, no bundler.

## Run

```powershell
fitz run
```

Then open http://127.0.0.1:3000/ — ideally in two browser tabs at once
so you can see each tab has its own independent counter
(per-connection state is a Phase 2 MVP choice; shared state lands in
Phase 4).

## What each file does

- **`fitz.toml`** — package manifest. Declares this project as a `[bin]`
  and pulls in the `fitz_liveviews` library via a `path = "../.."`
  dependency.
- **`src/main.fitz`** — the whole counter:
  1. `type CounterState` — the state (just an `Int`)
  2. `fn render(state)` — turns state into `Html`
  3. `@get("/")` — initial HTML render + client-side script bundle
  4. `@ws("/live/counter")` — receives events, mutates state, sends new HTML
  5. `@server(3000)` — binds the port

## Poking under the hood

Check the server logs and the network tab of your browser's dev
tools. You'll see:

1. `GET /` returns the initial HTML.
2. The browser upgrades a connection at `ws://127.0.0.1:3000/live/counter`.
3. Each click sends a small JSON frame like
   `{"event":"increment","payload":{},"html":""}`.
4. The server responds with a JSON frame carrying the new HTML for the
   `counter-app` element.
5. The client JS replaces `document.getElementById("counter-app").outerHTML`
   with the new HTML.

## What's missing (comes later)

- **Diff engine.** Right now the server sends the entire counter HTML
  on every click. In Phase 3, only the delta ships across the wire.
- **Shared state.** Two tabs = two counters. Phase 4 adds per-LiveView
  shared state.
- **Forms.** No `data-flv-submit` yet — Phase 3.
- **`@live` decorator.** The current `@get` + `@ws` pattern is a Phase
  2 MVP shape. `@live("/counter")` as a single decorator is a Phase 6+
  language enhancement.

See [`ROADMAP.md`](../../ROADMAP.md) at the project root for the full
plan.
