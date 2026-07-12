# {{name}}

A [Fitz LiveViews](https://github.com/Thegreekman76/fitz-liveviews) app.

The starting point is a real-time counter — click the buttons, the
number changes in every open browser tab connected to the same
process, without any JavaScript build step.

## Run it

```powershell
fitz run
```

Then open <http://127.0.0.1:3000/>.

## What is in the box

- **`fitz.toml`** — package manifest. Declares this project as a `[bin]`
  and pulls in the `fitz_liveviews` library from the GitHub tag. Bump
  the tag when you want new framework features.
- **`src/main.fitz`** — the whole app:
  - `type AppState` — the state.
  - `fn render(state)` — turns state into `Html`.
  - `@get("/")` — initial HTML render + client-side runtime script.
  - `@ws("/live")` — receives events, mutates state, sends new HTML.
  - `@server(3000)` — binds the port.

## Where to go next

- Replace the counter with your own state + render + event handlers.
- Look at [`examples/`](https://github.com/Thegreekman76/fitz-liveviews/tree/main/examples)
  in the framework repo for chat (shared state, broadcasts) and kanban
  (data-flv-value payloads, responsive layout).
- Read the [guide](https://thegreekman76.github.io/fitz-liveviews/)
  for the full API — `flv()` escaping, composition helpers,
  live components (Phase 4).

## Troubleshooting

- **`fitz` not found?** Install Fitz from
  <https://github.com/Thegreekman76/fitz>. This template requires
  Fitz **v0.19.6 or later** for the `fitz new --template` flag.
- **Two tabs, two counters?** That is by design — each WebSocket
  connection has its own state. See the framework's chat example for
  the shared-state pattern (`ws.broadcast(...)`).
- **Want the browser to hot-reload during development?** Not yet — the
  server restart / manual refresh loop is what we have today.
