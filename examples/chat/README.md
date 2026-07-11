# Chat — Fitz LiveViews Phase 3a

Multi-user chat over a single WebSocket. Type your name and a message,
hit send, and every open browser window sees it appear.

## Run

```powershell
fitz run
```

Open http://127.0.0.1:3000/ in two browser windows. Type a name and a
message in one window and send — the message appears in both windows
instantly. This is the "wow moment" of LiveViews.

## What each file does

- **`fitz.toml`** — package manifest with `fitz_liveviews` path
  dependency pointing to the parent library.
- **`src/main.fitz`** — the whole chat, ~50 lines:
  1. `type Message { author, text }` — a chat message
  2. `type ChatRoom { messages: List<Message> }` — the shared state
  3. `let chat_room: ChatRoom = ChatRoom { messages: [] }` — top-level
     `let` becomes `Arc<Mutex<ChatRoom>>` under F17, so mutations from
     any WebSocket handler are visible to all connections
  4. `fn render_chat(room)` — turns state into `Html`
  5. `@get("/")` — initial page render
  6. `@ws("/live/chat")` — receives events, mutates shared state, calls
     `ws.broadcast(...)` to push the new HTML to every connected client

## The magic pieces

### Shared state via top-level `let`

```fitz
let chat_room: ChatRoom = ChatRoom { messages: [] }
```

That single line is the entire "multi-user backend". No Redis, no
external state store. Fitz's F17 wraps every top-level `let` in
`Arc<Mutex<T>>`, so `.push()`, `.messages`, field mutations from any
WebSocket handler are safely shared across all connections.

### Broadcast via `ws.broadcast(...)`

```fitz
ws.broadcast(LiveFrame { event: "", payload: {}, html: render_chat(chat_room).raw })?
```

Fitz's WebSocket runtime tracks every connected client of an endpoint.
`broadcast(msg)` sends `msg` to all of them — sender included, matching
the Phoenix/Socket.IO convention. No pub-sub library, no subscription
management.

### Forms via `data-flv-submit`

```html
<form data-flv-submit="send_message">
  <input name="author" ... />
  <input name="text" ... />
</form>
```

The Fitz LiveViews client JS listens for form submits with this
attribute, prevents the default page reload, packages every named
input into a `payload: Map<Str, Str>`, and ships it as an event.

## Known limitations (Phase 3a MVP)

- **The author field clears on every message.** Because we replace the
  entire `chat-app` div's `outerHTML`, the form re-renders empty each
  time. A proper diff engine (Phase 3b) would preserve the input
  values and cursor position by patching the DOM in place instead of
  replacing it.
- **No persistence.** Restart the server and the messages disappear.
  Persistent storage plugs into Fitz's ORM (Phase 4 territory).
- **No presence.** No "Bob joined" / "Bob is typing" — those need
  lifecycle hooks (Phase 3b or Phase 4).
- **No moderation.** Every author is trusted. Real chats need
  authentication (Phase 3b `@authenticated @live(...)`).

## What proves it works

- Two browser windows.
- Both windows see the same messages in the same order.
- New messages appear in the other window within milliseconds.
- HTML escaping neutralizes any `<script>` payload sent as author or
  text — try typing `<script>alert('xss')</script>` as your text; you
  will see the literal characters, no popup.

See [`ROADMAP.md`](../../ROADMAP.md) for the roadmap and
[`docs/live.md`](../../docs/live.md) for the LiveView API reference.
