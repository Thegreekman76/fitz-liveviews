# Counter — the "hello world" (Phase 2)

A real-time counter driven by WebSocket events. Click a button, the
number updates without a page reload. No JavaScript build step, no
`npm install`, no bundler.

Source: [`examples/counter/`](https://github.com/Thegreekman76/fitz-liveviews/tree/main/examples/counter)

## Run

```powershell
cd examples/counter
fitz run
```

Then open http://127.0.0.1:3000/ — ideally in two browser tabs at once
so you can see each tab has its own independent counter (per-connection
state; shared state lands in Phase 4).

## What each file does

- **`fitz.toml`** — package manifest. Declares this project as a `[bin]`
  and pulls in the `fitz_liveviews` library via a `path = "../.."`
  dependency.
- **`src/main.fitz`** — the whole counter:
    1. `type CounterState` — the state (just an `Int`)
    2. `fn render(state)` — turns state into `Html`
    3. `@get("/")` — initial HTML render + client-side script bundle
    4. `@ws("/live/counter")` — receives events, mutates state, computes
       the diff against the last snapshot, and sends compact patches
    5. `@server(3000)` — binds the port

## The whole source

```fitz
--8<-- "counter/src/main.fitz"
```

## Poking under the hood

Check the server logs and the network tab of your browser's dev
tools. You'll see:

1. `GET /` returns the initial HTML.
2. The browser upgrades a connection at `ws://127.0.0.1:3000/live/counter`.
3. Each click sends a small JSON frame like
   `{"event":"increment","payload":{},"html":"","patches":[]}`.
4. The server responds with a JSON frame carrying:
    - `patches` — compact list like `[{"op":"text","path":[0,3,0],"content":"Count: 6"}]`
    - `html` — the full new HTML as a fallback (only used if patches fail)
5. The client walks the DOM by path index and applies patches directly.
   Only the `<p>` element mutates — no re-mount of the surrounding tree.

## What's missing (comes later)

- **Shared state.** Two tabs = two counters. Phase 4 adds per-LiveView
  shared state.
- **Forms.** No `data-flv-submit` needed here — but chat uses it in
  Phase 3a.
- **`@live` decorator.** The current `@get` + `@ws` pattern is a Phase
  2 MVP shape. `@live("/counter")` as a single decorator is a Phase
  6+ language enhancement.

See the [Roadmap](https://github.com/Thegreekman76/fitz-liveviews/blob/main/ROADMAP.md)
for the full plan.
