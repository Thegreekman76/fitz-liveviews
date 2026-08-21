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
| `fn live_layout_with(opts, ws_path, root_id, initial) -> Html` | Same, with a customizable mobile-friendly shell (FLV-01)  |
| `type LayoutOpts { title, lang, head_extra, body_class, theme, theme_color }` | Options for `live_layout_with`             |
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

#### Customizing the document — `live_layout_with` (FLV-01)

`live_layout` is the zero-config path. When you need a custom title,
`<html lang>`, a theme, or `<head>` extras (a `<link rel=manifest>`, a
favicon, an app `<style>`, Open Graph meta), use `live_layout_with` with
a `LayoutOpts`. Unlike `app_shell`, it produces a **minimal** document —
no admin sidebar/topbar chrome — ideal for a game or a public app that
owns the whole page.

```fitz
let opts = LayoutOpts {
  title: "MatHelp",
  lang: locale,                                  // "es-AR", "en", …
  theme: "auto",                                 // <html data-theme>
  theme_color: "#7c3aed",                        // browser UI tint
  body_class: "game",
  head_extra: html("""
    <link rel="manifest" href="/static/manifest.webmanifest">
    <link rel="icon" href="/static/favicon.ico">
    <style>{ui_theme().raw}</style>
  """),
}
return html_response(live_layout_with(opts, "/live/game", "game", initial))
```

The default `<head>` is already mobile-friendly: `viewport-fit=cover`
(so the layout extends under notches), a `theme-color`, and
`format-detection: telephone=no`. `live_layout(...)` delegates to
`live_layout_with(LayoutOpts {}, ...)`, so every existing caller gains
`<html lang="en">` (accessibility) and the mobile head for free.

> **PWA note:** serve the `manifest.webmanifest`, favicon and CSS as
> static files with `@server(static_dir="./public", static_prefix="/static")`
> (Fitz core ≥ v0.51.0) — one binary + Postgres, no nginx.

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

### Live input events — `@input`, `@keydown`, debounce (v0.42.0)

Beyond click/submit, the client runtime wires **live input** events so a field
can drive the server *as you type* — a search box, a validated field, a
submit-on-Enter. In a `.fitzv` you write them as `@event` bindings; the SSR
emitter lowers each to `data-flv-<event>`.

| Binding | Fires on | Payload | Use it for |
| --- | --- | --- | --- |
| `@input` → `data-flv-input` | every keystroke | `value` (post-key) + form fields | live search / as-you-type filters |
| `@change` → `data-flv-change` | native `change` (blur/commit) | `value` | selects, toggles, cascade filters |
| `@keydown` → `data-flv-keydown` | keydown | `value` (pre-key) + `key` | key actions (submit-on-Enter, Escape) |

Two plain attributes tune them (no `@`, they pass straight through):

- **`data-flv-debounce="300"`** — coalesce a keystroke burst with a per-element
  timer, so the socket sees **one** frame ~300 ms after the user pauses instead
  of one per key. Absent or `0` sends immediately. Applies to `input`/`keydown`.
- **`data-flv-keyfilter="Enter,Escape"`** — restrict `@keydown` to the listed
  `event.key`s (Phoenix's `phx-key`), e.g. submit-on-Enter without a `<form>`.

```html
<!-- debounced live search: one frame ~300ms after you stop typing -->
<input @input="on_search" data-flv-debounce="300" value="{query}" />

<!-- submit on Enter only -->
<input @keydown="on_submit" data-flv-keyfilter="Enter" value="{draft}" />
```

The handler reads `payload["value"]` (and `payload["key"]` for keydown):

```
event on_search() { query = payload["value"] }
```

**`@input` vs `@keydown`:** on `keydown` the field value is *pre-key* (the char
isn't in `.value` yet), so use `@input` when you need the typed value and
`@keydown` (+ `data-flv-keyfilter`) for key-driven actions. A runnable
debounced filter lives in [`examples/live-search/`](https://github.com/Thegreekman76/fitz-liveviews/tree/main/examples/live-search).

### Lifecycle hooks — `on_mount` / `on_disconnect` (v0.43.0)

Run code when a client **connects** and when its socket **closes** — presence
counters, per-connection setup/teardown, "who's online". The component declares
two ordinary events:

```
component Presence {
  state { count: Int = 0 }
  event on_mount()      { count = count + 1 }
  event on_disconnect() { count = count - 1 }
  <template><div id="presence-app"><h1>{count} online</h1></div></template>
}
```

Fitz-core `@ws` can't intercept `recv`, so **you** fire the hooks from the loop
with `flv_mount(name, id)` / `flv_disconnect(name, id)`. The shape matters —
`ws.recv()?` *returns from the handler* on disconnect, so the leave hook would
never run. Use a `match` on `recv()` with `Err(_) => break`:

```
@ws("/live/presence")
async fn presence_socket(ws: WsConn<LiveFrame>) {
  let _ = flv_mount("Presence", "room")                                 // on connect
  ws.broadcast(LiveFrame { html: component("Presence", "room").raw, patches: [] })?
  loop {
    let r = ws.recv()
    match r {
      Ok(frame) => {
        let _ = dispatch_component_events(frame)
        ws.broadcast(LiveFrame { html: component("Presence", "room").raw, patches: [] })?
      }
      Err(_) => { break }
    }
  }
  let _ = flv_disconnect("Presence", "room")                            // on close
  let _ = ws.broadcast(LiveFrame { html: component("Presence", "room").raw, patches: [] })
}
```

- Call `flv_mount` **before** the first render/broadcast, so state it seeds shows
  in the client's first frame.
- `ws.broadcast(...)` **still delivers after the socket closes**, so the
  `on_disconnect` "farewell" (the decremented count) reaches the clients still
  connected.
- The helpers are thin wrappers over `dispatch_to(...)` — a silent `false` no-op
  if the component declares no `on_mount`/`on_disconnect`, so calling them is
  always safe.

Runnable in [`examples/presence/`](https://github.com/Thegreekman76/fitz-liveviews/tree/main/examples/presence) — a live "N online" counter with no buttons at all.

### Server-pushed updates — `@every` (v0.44.0)

So far every frame was a reaction to a client event. Sometimes the **server**
should push on its own schedule — a live clock, a metric tick, a countdown. The
pattern is a `@background` fn that loops on `sleep` + re-render + push, spawned
per connection with the socket:

```
@background
async fn clock_tick(ws: WsConn<LiveFrame>) {
  loop {
    let _ = sleep(1000).await                          // every second
    let t = DateTime.now().format("%H:%M:%S")
    let _ = dispatch_to("Clock", "room", "tick", {"now": t})
    ws.send(flv_frame("Clock", "room"))?               // push the re-render
  }
}

@ws("/live/clock")
async fn clock_socket(ws: WsConn<LiveFrame>) {
  spawn(clock_tick(ws))                                // ws is cloned into the task
  loop {
    let r = ws.recv()
    match r { Ok(f) => { dispatch_component_events(f) }, Err(_) => { break } }
  }
}
```

- **`spawn(clock_tick(ws))`** hands the connection to a background task — `WsConn`
  is accepted as a `@background` parameter and a `spawn` argument (no core change).
- **`ws.send(...)?`** is also the cleanup: when the tab closes the send errors and
  `?` ends the ticker task, so it doesn't leak.
- **`flv_frame(name, id)`** builds a full-re-render frame (`patches: []`, client
  does `outerHTML =`). For a diffed push, keep a per-loop `last` and send
  `LiveFrame { html: now, patches: diff_html(last, now) }` instead.

**Per-connection vs shared.** The ticker above uses `ws.send`, so each connection
ticks itself — perfect for per-client views (a session timer, "your data"). For
**shared** state, use `ws.broadcast` instead: every connection's ticker still
fires, but the writes are idempotent and all clients stay in sync.

An `@every(N)` decorator that writes the ticker + spawn for you is a possible
future; today it's this small, explicit pattern. Runnable in
[`examples/clock/`](https://github.com/Thegreekman76/fitz-liveviews/tree/main/examples/clock).

### Versioned patches (v0.45.0)

Patches are applied optimistically: the client tries `applyPatches`, and on any
throw it falls back to the frame's full `html`. That already resyncs a
*misapplied* batch. To also catch a *silently stale* one — patches that apply
without throwing but target a tree the client no longer matches (a missed frame
in a broadcast fan-out) — stamp your frames with a **monotonic version**:

```
ws.broadcast(flv_versioned("/live/clock", flv_frame("Clock", "room")))?
```

`flv_versioned(endpoint, frame)` gives every frame on `endpoint` a strictly
increasing `version`. The client tracks `lastVersion`; if a frame isn't exactly
`lastVersion + 1`, it skips the patches and takes the `html` resync. Use **one
shared endpoint counter** across all senders reaching the same clients, so
everyone agrees on the sequence. It's **opt-in** — unstamped frames stay
`version: 0` and behave exactly as before.

### Securing a live socket (v0.46.0)

A LiveView socket is a plain WebSocket: unless you check, **anyone can connect**.
The browser sends the same-origin **HttpOnly session cookie** on the WS upgrade
automatically, so a `@ws` handler authenticates by reading that cookie —
`@header(name="cookie")` (Fitz core) reads it into a param, and
`flv_cookie(cookie, name)` pulls out the value:

```
fn email_from_cookie(cookie: Str?) -> Str? {
  let token  = match flv_cookie(cookie, "session") { null => { return null }, t => t }
  let claims = match jwt.decode(token, secret())   { Ok(c) => c, Err(_) => { return null } }
  return match claims.get("email") { Ok(e) => e, Err(_) => null }
}

@header(name="cookie")
@ws("/live/secure")
async fn secure_socket(ws: WsConn<LiveFrame>, cookie: Str?) {
  let email = match email_from_cookie(cookie) {
    null => { return },          // anon → silent close, zero frames
    e => e,
  }
  ws.send(flv_frame("Secure", email))?
  loop {
    let r = ws.recv()
    match r {
      Ok(f) => { dispatch_component_events(f); ws.send(flv_frame("Secure", email))? }
      Err(_) => { break }
    }
  }
}
```

- Validate **before the first `ws.send`/`broadcast`** — a `return` there closes
  the socket and an anonymous client gets nothing. (`jwt.encode` at login sets
  the cookie `HttpOnly; SameSite=Lax`; JS can't read it, so it can't leak through
  the `__flv_init` query channel — the cookie is the right transport.)
- **Reject with a redirect (v0.47.0).** Instead of a silent close, send a
  redirect frame so the tab bounces to `/login`:
  `ws.send(flv_redirect("/login"))?` then `return`. `flv_redirect(url)` is also
  the way to do a **server-initiated navigation** at any time — an expired
  session mid-stream, a "you were signed out", a moved resource: the client does
  `window.location = url`.
- **Zero Fitz-core change, zero client change** — the browser already sends the
  cookie; the handler just checks it.

**Injected `user`, reject before the upgrade.** If you'd rather the framework
reject anon with a **401 before the WS upgrade** and **inject a `user: User`**,
add one global `@auth_provider` that reads the cookie header (it receives the
full headers map) and stack `@authenticated @ws`:

```
@auth_provider
async fn check(headers: Map<Str, Str>) -> Result<User> { /* cookie → jwt.decode → user */ }

@authenticated
@ws("/live/secure")
async fn secure_socket(ws: WsConn<LiveFrame>, user: User) { /* user injected + validated */ }
```

Both patterns are library-only. Runnable in
[`examples/auth-live/`](https://github.com/Thegreekman76/fitz-liveviews/tree/main/examples/auth-live).

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
- **Event bindings.** `data-flv-click`, `data-flv-submit` and
  `data-flv-change` (v0.7.0 — fires on native `change`, used by cascade
  selects) are the client-side bindings today. A click can also opt into
  serializing its enclosing form with `data-flv-form` (v0.9.0), which is how
  tabbed / stepped forms keep typed values across a re-render.
  `data-flv-input`, `data-flv-keydown` and debouncing are still future.
- **Race on newly-connected clients during broadcast.** If a client
  finishes its HTTP `GET` and then receives a broadcast patch that was
  diffed from an older server snapshot, the patches may not apply
  cleanly. Since v0.45.0 an opt-in **version protocol** (`flv_versioned`)
  stamps frames so the client detects a gap and takes a full `html`
  resync instead of applying stale patches (the same mechanism that
  drives reconnect replay — see "Reconnection & state replay").
- **Reconnect: DOM/domain state only.** Reconnection + state replay
  (v0.48.0, FLV-04) rehydrates the store-backed state, but ephemeral UI
  state (focus, scroll, unsent input) is lost on the full resync, and a
  process restart clears the in-memory store. Persist anything critical.
  Outbox backpressure and multi-instance coordination are still future.

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

## Passing connection context to a `@ws` handler

A live socket often needs per-connection context — the active locale, the
tenant, a role. Two ways, depending on where the context lives:

- **Headers / cookies** — read them at the handshake with `@header` (the WS
  upgrade *is* an HTTP request). Requires **Fitz core v0.28.0+**:

  ```fitz
  @header(name="cookie")
  @ws("/live/grid")
  async fn socket(ws: WsConn<Msg>, cookie: Str?) {
    let locale = locale_from_cookie(cookie)
    // ... use `locale` for the whole connection ...
  }
  ```

  Since Fitz core v0.49.0 you can read a single cookie declaratively with
  `@cookie(name="...")` on the `@ws` handler instead of parsing the raw
  header — the recommended path for the active locale. The full pattern
  (cookie + `<html lang>` + `/lang/{code}` + `t(locale, key)`) is in the
  [i18n guide](i18n.md), including *the* trap: the locale reaches the
  socket through the handshake cookie, **not** `__flv_init`.

- **Query-string context** — bake it into the `ws_path` of `live_embed(...)`
  (e.g. `"/live/grid?tenant=acme"`). On connect the client sends those query
  params as a **`__flv_init`** event (lib v0.10.0), so the handler reads them
  from the first event:

  ```fitz
  loop {
    let frame = ws.recv()?
    if (frame.event == "__flv_init") {
      let tenant = pget(frame.payload, "tenant", "default")
      // ... re-render the diff baseline for this tenant, then `continue` ...
    }
    // ... normal events ...
  }
  ```

## Reconnection & state replay (FLV-04)

Mobile connections drop — a tunnel, a locked screen, a suspended tab. Since
v0.48.0 the client runtime **reconnects automatically** and can **replay the
LiveView's state** so the user picks up where they left off.

**Reconnect is automatic — no code change.** `LIVE_CLIENT_JS` now recreates
the socket on `onclose` with exponential backoff + jitter (250ms → capped at
10s), resetting the delay after a successful connection. An intentional
navigation (`flv_redirect`, or `beforeunload`) does **not** reconnect. Every
existing app un-freezes on its own after a blip.

**State replay is opt-in — use the component store + a stable id.** Local
per-connection state (`let state = ...` inside the handler) dies with the
socket, so a reconnect starts fresh. To *replay*, keep state in the component
store (`component(...)` / `component_with(...)`) keyed by a **stable session
id**. The client generates one per tab, keeps it in `sessionStorage` (so it
survives the drop *and* a reload), and sends it in every `__flv_init` as
`__flv_session`. Read it with **`flv_session_id(init)`** instead of minting a
fresh `Uuid.v4()` per socket:

```fitz
@ws("/live/game")
async fn socket(ws: WsConn<LiveFrame>) {
  let init = ws.recv()?                 // first frame is __flv_init
  let cid = flv_session_id(init)        // STABLE across reconnects
  let _ = flv_mount("Game", cid)
  ws.send(flv_frame("Game", cid))?      // initial render — or replay after a drop
  loop {
    match ws.recv() {
      Ok(frame) => {
        dispatch_component_events(frame)
        ws.send(flv_frame("Game", cid))?
      }
      Err(_) => { break }
    }
  }
  let _ = flv_disconnect("Game", cid)   // fires on_disconnect; does NOT evict
}
```

On reconnect the same `__flv_session` arrives, `flv_session_id` returns the
same `cid`, the store still holds the state (it is not evicted on disconnect —
see [components.md](components.md) for eviction/TTL), and `flv_frame(...)`
re-renders the current state. The client applies it as a full `html` resync —
the version-gap detector already forces one because the server's per-endpoint
version counter is ahead of the reconnected client's `lastVersion`.

**What survives:** domain state kept in the store (or re-derived from Postgres).
**What may not:** ephemeral UI state (focus, scroll, unsent input) — the DOM is
replaced wholesale on the resync. Persist anything you must not lose.

**If the process restarted** (deploy, crash), the in-memory store is gone, so
the reconnect gets a fresh instance. Persist critical state to the DB and
re-derive it in the handler for a true "resume" across restarts.

### Manual smoke (sockets are flaky in CI)

The reconnect loop is verified manually — automated socket tests are flaky:

1. `fitz run` a reconnect-ready app (store + `flv_session_id`), open it, and
   interact so the component state changes (e.g. increment a counter).
2. In DevTools → Network, throttle to **Offline** (or stop/restart the server,
   or kill the tunnel). The socket closes; the DOM freezes.
3. Watch the console/network: within ~250ms–10s the client reconnects (a new
   WS with a new `__flv_init` carrying the **same** `__flv_session`).
4. Confirm the view rehydrates to its previous state (a full `html` resync) and
   events work again. `sessionStorage` shows the `flv:sid:...` key persisting.

The state-replay logic itself is covered by an automated, socket-free test
(`flv04_reconnect_replays_state_from_store` in `src/lib.fitz`).

## Ready-made components

For concrete, real-world UI components built on these primitives — DataGrid,
tabbed/stepped forms, modal, toasts, tree, cascade selects, and more — see the
**[UI components catalog](ui-components.md)** (runnable reference: the
**[Admin ABM](examples/admin.md)**).

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
