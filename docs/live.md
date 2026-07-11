# LiveViews (Phase 2)

Phase 2 delivers the end-to-end plumbing to build real-time UIs: an
initial HTML render, a WebSocket connection, an event/patch cycle, and
a tiny vanilla JS client that ties the browser to the server.

## Overview

A LiveView in Fitz is **two paired handlers**:

1. **`@get(...)`** — returns the initial HTML plus the client-side
   script. First paint is fast and SEO-friendly.
2. **`@ws(...)`** — receives events from the browser, mutates state,
   sends back the new HTML.

The client script (~30 lines of vanilla JS, embedded in the response)
opens the WebSocket, forwards clicks with `data-flv-click`, and replaces
the LiveView root's `outerHTML` on each patch.

## Public API added in Phase 2

| Name                                                      | Purpose                                                        |
|-----------------------------------------------------------|----------------------------------------------------------------|
| `type LiveFrame { event, payload, html }`                 | Envelope used by the WebSocket in both directions              |
| `let LIVE_CLIENT_JS`                                      | The vanilla JS runtime (~30 LoC, embedded automatically)       |
| `fn live_layout(ws_path, root_id, initial) -> Html`       | Wraps initial HTML with the `<script>` tag                     |
| `fn html_response(h) -> Response`                         | Turns `Html` into a `Response` with `Content-Type: text/html`  |

## Design decisions locked for Phase 2

Documented so future readers understand what the MVP does and does not do.

1. **No `@live` decorator.** Fitz does not allow user-defined decorators
   without touching the compiler. We use `@get` + `@ws` explicitly and
   provide `live_layout()` as the glue. `@live` remains a Phase 6+
   opportunistic upgrade.
2. **No diff engine.** Every event triggers a full re-render, sent as
   the complete HTML for the LiveView root. Diff lands in Phase 3.
3. **One-type WebSocket envelope.** `WsConn<LiveFrame>` is used for both
   directions — bidirectional typed WebSockets are a Fitz-language
   deuda. `LiveFrame` has three optional fields; the direction fills in
   the ones it needs.
4. **`data-flv-click`** for events.  Explicit, unique to this library.
   Vue-style `@click`, Phoenix-style `phx-click`, or HTMX-style
   attributes could be added later.
5. **Per-connection state.** Each browser tab has its own state — no
   sharing between clients. Shared / DB-backed state lands in Phase 4.
6. **Inline client JS.** No `/live/client.js` endpoint — the ~30-line
   runtime is injected in every LiveView response. Zero configuration,
   zero cache benefit. Extraction is a Phase 5 opportunistic polish.

## Anatomy of a LiveView

Here is the counter (`examples/counter/src/main.fitz`) walked through:

### 1. State

```fitz
type CounterState {
  count: Int = 0
}
```

Just a normal Fitz `type`. Nothing library-specific.

### 2. Render function

```fitz
fn render(state: CounterState) -> Html {
  return html("""<div id="counter-app">
  <p>Count: {state.count}</p>
  <button data-flv-click="increment">+1</button>
</div>""")
}
```

Note the `id="counter-app"` — this is the identifier the JS client uses
to find and replace the root element. It **must** match the `root_id`
you pass to `live_layout` below.

`data-flv-click="increment"` on the button tells the client to send an
event named `increment` when the button is clicked.

### 3. HTTP entry point

```fitz
@get("/")
fn counter_page() -> Response {
  let initial = render(CounterState { count: 0 })
  return html_response(live_layout("/live/counter", "counter-app", initial))
}
```

This is what a browser hitting `/` gets. `live_layout` bundles the
first render with the JS `<script>`; `html_response` sets
`Content-Type: text/html` so the browser renders it instead of
displaying JSON.

### 4. WebSocket handler

```fitz
@ws("/live/counter")
async fn counter_socket(ws: WsConn<LiveFrame>) {
  let state = CounterState { count: 0 }
  loop {
    let frame = ws.recv()?
    if (frame.event == "increment") {
      state = CounterState { count: state.count + 1 }
    }
    ws.send(LiveFrame { event: "", payload: {}, html: render(state).raw })?
  }
}
```

`ws.recv()` blocks until the client sends a frame. Its `event` field
matches the `data-flv-click` attribute of whatever button was pressed.
We mutate our per-connection state, then send back a frame whose `html`
field holds the newly-rendered fragment.

### 5. Server config

```fitz
@server(3000)
fn main() => 0
```

Standard Fitz — binds to port 3000.

## Running the example

```powershell
cd examples/counter
fitz run
```

Open http://127.0.0.1:3000/ in two browser tabs. Each tab has its own
counter (per-connection state); clicks update instantly without a page
reload.

## Escaping user data

The Phase 1 convention still applies: user-controlled data must be
wrapped with `flv(...)` before interpolation. LiveViews doesn't change
this. `flv()` returns `Str`, which drops into `html("""...""")`
templates directly.

```fitz
html("<p>Hello {flv(user.name)}</p>")
```

## What is coming next

- **Phase 3** — HTML diff engine (send only what changed), template
  control flow (`{#for}`, `{#if}`), forms (`data-flv-submit`),
  broadcast to multiple clients of the same LiveView.
- **Phase 4** — Stateful child components (`LiveComponent`), shared
  state, per-user presence primitives.
- **Phase 6** — VSCode extension with HTML highlighting inside
  `html("""...""")`, autocomplete for state fields and event handlers.
