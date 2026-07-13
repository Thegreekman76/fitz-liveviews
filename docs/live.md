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

## Phase 3a additions — forms, broadcast, shared state

Phase 3a extends the plumbing without changing the API surface much.
Three patterns land: forms with `data-flv-submit`, shared state via
top-level `let`, and multi-client broadcast with `ws.broadcast(...)`.

### Forms

The client runtime intercepts any `<form data-flv-submit="event_name">`
submission, prevents the default page reload, and packages every named
input into a `Map<Str, Str>` payload:

```html
<form data-flv-submit="save_note">
  <input name="title" />
  <textarea name="body"></textarea>
</form>
```

The server side receives it as:

```fitz
if (frame.event == "save_note") {
  let title = frame.payload["title"]
  let body = frame.payload["body"]
  // ...
}
```

### Shared state via top-level `let`

For multi-user views, declare state at the top level of the file:

```fitz
type ChatRoom { messages: List<Message> = [] }
let chat_room: ChatRoom = ChatRoom { messages: [] }
```

Fitz's F17 wraps every top-level `let` in `Arc<Mutex<T>>`, so mutations
from any WebSocket handler are safely visible to all connections. No
Redis, no pub-sub library.

### Broadcast

Use `ws.broadcast(msg)` to send a frame to every client connected to
the same `@ws(...)` endpoint. It follows the Phoenix/Socket.IO
convention: the sender receives the broadcast too.

```fitz
@ws("/live/chat")
async fn chat_socket(ws: WsConn<LiveFrame>) {
  loop {
    let frame = ws.recv()?
    // ... mutate shared state ...
    ws.broadcast(LiveFrame { html: render_chat(chat_room).raw, ... })?
  }
}
```

The `examples/chat/` project shows all three patterns together.

## Phase 3b additions — server-side diff engine

Phase 3b upgrades the patch protocol from "send the whole HTML" to
"send only what changed". The server parses the previous and next
renders into node trees, computes a minimal patch list, and ships it
over the WebSocket. The client applies patches directly to the DOM,
which preserves focus, input values, and cursor position on any
element that wasn't rewritten.

### Anatomy of the patch pipeline

1. Your `render(state)` returns an `Html`.
2. Server computes `diff_html(last_html, new_html) -> List<Patch>`.
3. Server sends `LiveFrame { html: new_html, patches: patches }`.
4. Client tries `patches` first. If any patch fails (e.g., the client
   is out of sync), it silently falls back to `html` and replaces the
   root's `outerHTML`.

### Six patch ops

| Op            | `path` targets       | `content`                    | `name`        |
|---------------|----------------------|------------------------------|---------------|
| `text`        | text node            | new text (entities decoded)  | —             |
| `replace`     | element to replace   | new HTML fragment            | —             |
| `append`      | parent element       | new child HTML fragment      | —             |
| `remove`      | element to remove    | —                            | —             |
| `set_attr`    | element              | new attribute value          | attribute name|
| `remove_attr` | element              | —                            | attribute name|

`path` is a list of child indices starting from the root's outer-most
element. Path `[0]` refers to the root. Path `[0, 2]` refers to the
root's third child. And so on.

### The pattern in your handler

Track a snapshot of the last HTML you broadcast, then diff on every event:

```fitz
@ws("/live/counter")
async fn counter_socket(ws: WsConn<LiveFrame>) {
  let state = CounterState { count: 0 }
  let last_html = render(state).raw
  loop {
    let frame = ws.recv()?
    // ... update `state` ...
    let new_html = render(state).raw
    let patches = diff_html(last_html, new_html)
    ws.send(LiveFrame { html: new_html, patches: patches })?
    last_html = new_html
  }
}
```

For shared-state / broadcast handlers, keep `last_html` at the top
level (shared) instead of local, so every broadcast diffs against the
canonical server snapshot.

### Passing values with `data-flv-value-*`

When a click or submit event fires, sometimes you need to send an
identifier along with it — a card ID, a row ID, a column name.

Use the `data-flv-value-<key>="<value>"` convention on the same
element that carries `data-flv-click` or `data-flv-submit`. Every
matching attribute is serialized into the event payload map:

```html
<button data-flv-click="delete_card" data-flv-value-card_id="42">
  Delete
</button>

<button data-flv-click="move_right"
        data-flv-value-card_id="42"
        data-flv-value-column="in_progress">→</button>
```

Server side:

```fitz
if (frame.event == "delete_card") {
  let card_id = frame.payload["card_id"]
  chat_room.messages.remove_where(fn(m) => m.id == card_id)
}

if (frame.event == "move_right") {
  let card_id = frame.payload["card_id"]
  let column = frame.payload["column"]
  // ...
}
```

Forms can carry `data-flv-value-*` too — attributes on the `<form>`
element are extracted first, then merged with the named input values
(form fields win on name collision):

```html
<form data-flv-submit="save_edit" data-flv-value-card_id="42">
  <input name="title" />
  <button type="submit">Save</button>
</form>
```

The convention mirrors Phoenix LiveView's `phx-value-<key>` — familiar
to anyone coming from that world.

### Clearing inputs after submit

Since patches only touch what changed, the form inputs keep whatever
the user typed — great for a "name" input, annoying for a "message"
input on a chat. Opt in with `data-flv-clear` on any input that should
be wiped after its form submits:

```html
<form data-flv-submit="send_message">
  <input name="author" placeholder="Your name" />
  <input name="text" placeholder="Your message" data-flv-clear />
</form>
```

The client empties every input in the submitted form that carries
`data-flv-clear`, right after sending the event over the WebSocket.
Inputs without the attribute keep their value — that is the whole
point of Phase 3b's DOM preservation.

### The parser scope

We ship a minimal HTML parser that covers everything our templates
emit. Explicitly supported:

- Elements with `<tag>...</tag>` and `<tag />`
- Void elements: `<br>`, `<input>`, `<img>`, `<hr>`, `<meta>`,
  `<link>`, `<area>`, `<base>`, `<col>`, `<embed>`, `<source>`,
  `<track>`, `<wbr>`
- Attributes with double-quoted values: `<div id="x">`
- Boolean attributes: `<input required>`
- Nested elements to arbitrary depth
- HTML entities preserved as-is in text (`&amp;`, `&lt;`, etc.)

Explicitly NOT supported (documented so you know what to avoid):

- HTML comments `<!-- ... -->`
- Attributes with single quotes: `<div id='x'>` — use double quotes
- Unquoted attribute values: `<div id=x>`
- `<script>` and `<style>` inside the LiveView root (the client JS is
  attached OUTSIDE the root by `live_layout`)
- CDATA and DOCTYPE
- Element replacement of the root itself (kind or tag change of the
  outer wrapper) — this triggers the `html` fallback

## Known limitations of the current MVP

- **No persistence.** Shared state is in memory. Persistent storage
  plugs into Fitz's ORM (Phase 4 territory).
- **No fine-grained events.** `data-flv-click` and `data-flv-submit`
  are the only two client-side event bindings. `data-flv-input`,
  `data-flv-change`, `data-flv-keydown`, debouncing — all lands in
  Phase 3c.
- **Race on newly-connected clients during broadcast.** If a client
  finishes its HTTP `GET` and then receives a broadcast patch that was
  diffed from an older server snapshot, the patches may not apply
  cleanly. The `html` fallback recovers, but silently — no explicit
  version-numbering is in Phase 3b. Real production apps would want
  a version protocol; queue it up for a future phase.

## LiveComponents (Phase 4)

Reusable server-rendered components with independent per-instance
state — one component definition, many instances, each keeping its
own slice of UI state in the framework's store.

Session 3 shipped the full user-facing surface: the framework
builtins (`flv_register` / `component` / `dispatch_component_events`),
Fitz core validation of the three decorators (`@live_component`,
`@render_for`, `@on`), a refactored kanban with a per-card
`card_editor`, a new `examples/dashboard/` with six independent
tile instances, and a dedicated guide.

**Full walkthrough**: [`docs/components.md`](components.md).

A five-second preview:

```fitz
@live_component("row_toggle")
type RowToggle { is_open: Bool = false }

@render_for("row_toggle")
fn row_toggle_render(state: RowToggle) {
  if (state.is_open) { return html("<button data-flv-click=\"close\">▼</button>") }
  return html("<button data-flv-click=\"open\">▶</button>")
}

@on("row_toggle", "open")
fn row_toggle_open(s: RowToggle, p: Map<Str, Str>) -> RowToggle {
  return RowToggle { is_open: true }
}

// Boot: registration is automatic since Fitz core v0.20.1 — the
// compiler emits `flv_register("row_toggle", RowToggle {}, ...)`
// from the decorators. No manual boot call needed.

// Parent template:
// {component("row_toggle", "row-42").raw}

// @ws loop:
// if (dispatch_component_events(frame)) { /* handled */ } else { /* parent */ }
```

## What is coming next

- **Phase 4 (Session 4)** — Release coordination for Fitz core +
  framework layer + VSCode extension v0.3.0 (already shipped
  with `livecomp` / `renderfor` / `onevent` / `flvcomp` /
  `dispatchcomp` snippets).
- **Beyond Phase 4** — per-instance init payload, presence
  primitives (per-user state across connections),
  `dispatch_to_all(name, event, payload)` for bulk actions,
  `@every(N secs)` for periodic server-driven pushes, and
  fine-grained events (`data-flv-input`, `data-flv-change`,
  `data-flv-keydown`, debouncing). Implicit registration from
  decorators shipped in Fitz core v0.20.1.
