# Chat — Fitz LiveViews (Phase 3a shared state + Phase 8.4 SFC migration)

Multi-user chat over a single WebSocket. Type your name and a
message, hit send, and every open browser window sees it appear.

Migrated to `.fitzv` single-file component syntax in Phase 8.4
(2026-07-16) once Fitz core v0.21.0 shipped §9.cc + §9.dd +
§9.ee (chat migration probe blockers). Pre-migration version
kept `type Message`, shared state, and manual event dispatch all
inline in `main.fitz`.

## Run

```powershell
fitz run
```

Open http://127.0.0.1:3000/ in two browser windows. Type a name
and a message in one window and send — the message appears in
both windows instantly. This is the "wow moment" of LiveViews.

## What each file does

- **`fitz.toml`** — package manifest with `fitz_liveviews` path
  dependency pointing to the parent library.
- **`src/message.fitz`** — the `type Message { author, text }`
  declaration. Extracted from `main.fitz` so both `main.fitz` and
  `ChatRoom.fitzv` can import it without creating a circular
  dependency (canonical pattern for cross-file shared types in
  `.fitzv` component projects).
- **`src/ChatRoom.fitzv`** — the single-file component. Compact
  block: `from message import Message` + `state { messages:
  List<Message> = [] }` + `event send_message()` (with nested
  payload guards + `messages.push(Message { ... })`) + `<template>`
  with `{#for m in messages}` message list + submit form. Fitz
  core's view pipeline transforms this into classic Fitz source
  with `@live_component("ChatRoom")` on the type, `@render_for
  ("ChatRoom") fn ChatRoom_render`, and `@on("ChatRoom",
  "send_message") fn ChatRoom_send_message`.
- **`src/main.fitz`** — the parent shell. Just imports (`from
  ChatRoom import ...`, `from message import Message`, `from
  fitz_liveviews import ...`) + the HTTP GET route + the WS
  handler. The WS handler has ZERO event branches — every event
  routes via `dispatch_component_events(frame)`. The compiler
  auto-injects `flv_register("ChatRoom", ChatRoom { },
  ChatRoom_render, {"send_message": ChatRoom_send_message})`
  from the metadata (Fitz core v0.21.0+ Phase 11.6.e §9.bb
  cross-module auto-inject).

## The migration diff

Pre-migration `main.fitz` was ~115 lines: type declarations +
shared `let chat_room` + render fns + WS handler with manual event
dispatch + 3 levels of `if (frame.payload.has(...))` guards +
`chat_room.messages.push(Message { ... })`.

Post-migration:
- `main.fitz`: ~50 lines (imports + HTTP GET + WS handler with
  single `dispatch_component_events` call).
- `ChatRoom.fitzv`: ~40 lines (state + event + template — all
  the domain logic).
- `message.fitz`: ~5 lines (shared type).

The event body's shape is IDENTICAL to the pre-migration handler's
inner block — nested payload guards + `messages.push(Message { ...
})`. Post Fitz core §9.cc + §9.dd + §9.ee, all of that reads
cleanly in `.fitzv` syntax.

## The magic pieces

### Singleton component state = shared state

The SFC's `state { messages: List<Message> = [] }` gives every
connected client the SAME instance state via `component("ChatRoom",
"room")`. The `"room"` instance_id is fixed — one shared history
across all clients. Natural broadcast semantics without a hand-
rolled top-level `let chat_room` + Arc<Mutex>.

### Bare `.push()` on shadow-local state

```fitz
event send_message() {
  if (payload.has("author")) {
    if (payload.has("text")) {
      let author = payload["author"]
      let text = payload["text"]
      messages.push(Message { author: author, text: text })
    }
  }
}
```

Post Fitz core §9.cc V-6, bare `messages.push(...)` on the
shadow-local state field is accepted by the SSR emitter's §9.aa
walker. Semantics: Fitz `List<T>` is `Arc<Mutex<Vec<T>>>` per
F17, so mutating the shadow local propagates to `state.messages`
via the shared Arc; the struct-lit return re-packages the (now-
mutated) same Arc. Zero-copy state mutation.

### Cross-file `Message` type via `from` import

```fitz
from message import Message

component ChatRoom {
  state { messages: List<Message> = [] }
  ...
}
```

Post Fitz core §9.dd V-3+V-5, `.fitzv` files can `from X import Y`
at their top (Vue/Svelte convention). The view emitter emits it
verbatim as classic Fitz `from message import Message` in the
transformed source; the classic loader resolves `Message` from
the sibling `message.fitz` module normally.

### Forms via `data-flv-submit`

```html
<form data-flv-submit="send_message">
  <input name="author" required autocomplete="off" />
  <input name="text" required autocomplete="off" data-flv-clear />
  <button type="submit">Send</button>
</form>
```

The Fitz LiveViews client JS listens for form submits with this
attribute, prevents the default page reload, packages every named
input into a `payload: Map<Str, Str>`, and ships it as an event.
The bare `required` attr (HTML5 spec) is accepted post §9.ee V-2.

## Known limitations (unchanged from Phase 3a MVP)

- **The author field clears on every message.** The `data-flv-
  clear` attr on the text input intentionally clears it after send
  so the next message starts fresh. Author field also clears
  because we broadcast a full HTML replace rather than a targeted
  DOM patch — Phase 3b's diff engine (already shipped) mitigates
  this for other examples but the chat pattern still bulk-replaces.
- **No persistence.** Restart the server and the messages
  disappear. Persistent storage plugs into Fitz's ORM.
- **No presence.** No "Bob joined" / "Bob is typing" — those need
  lifecycle hooks.
- **No moderation.** Every author is trusted. Real chats need
  authentication (`@authenticated @live(...)`).

## What proves it works

- Two browser windows.
- Both windows see the same messages in the same order.
- New messages appear in the other window within milliseconds.
- HTML escaping neutralizes any `<script>` payload sent as author
  or text — try typing `<script>alert('xss')</script>` as your
  text; you will see the literal characters, no popup.

See [`ROADMAP.md`](../../ROADMAP.md) for the roadmap and
[`docs/live.md`](../../docs/live.md) for the LiveView API reference.
