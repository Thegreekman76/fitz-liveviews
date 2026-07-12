# Chat — multi-user real-time (Phase 3a + 3b)

Multi-user chat over a single WebSocket. Type your name and a message,
hit send, and every open browser window sees it appear — with the
author input persisted across sends and the message input cleared,
because Phase 3b's diff engine patches the DOM without re-mounting the
form.

Source: [`examples/chat/`](https://github.com/Thegreekman76/fitz-liveviews/tree/main/examples/chat)

## Run

```powershell
cd examples/chat
fitz run
```

Open http://127.0.0.1:3000/ in two browser windows. Type a name and a
message in one window and send — the message appears in both windows
instantly. **This is the "wow moment" of LiveViews.**

## What each file does

- **`fitz.toml`** — package manifest with `fitz_liveviews` path
  dependency pointing to the parent library.
- **`src/main.fitz`** — the whole chat, ~60 lines:
    1. `type Message { author, text }` — a chat message
    2. `type ChatRoom { messages: List<Message> }` — the shared state
    3. `let chat_room: ChatRoom = ChatRoom { messages: [] }` — top-level
       `let` becomes `Arc<Mutex<ChatRoom>>` under F17, so mutations
       from any WebSocket handler are visible to all connections
    4. `let last_chat_html: Str = ""` — snapshot of the last broadcast,
       used to compute diffs
    5. `fn render_chat(room)` — turns state into `Html`
    6. `@get("/")` — initial page render
    7. `@ws("/live/chat")` — receives events, mutates shared state,
       computes patches from the snapshot, calls `ws.broadcast(...)`

## The whole source

```fitz
--8<-- "chat/src/main.fitz"
```

## The three magic pieces

### Shared state via top-level `let`

```fitz
let chat_room: ChatRoom = ChatRoom { messages: [] }
```

That single line is the entire "multi-user backend". No Redis, no
external state store. Fitz's F17 wraps every top-level `let` in
`Arc<Mutex<T>>`.

### Broadcast via `ws.broadcast(...)`

```fitz
ws.broadcast(LiveFrame { html: new_html, patches: patches })?
```

Fitz's WebSocket runtime tracks every connected client of an endpoint.
`broadcast(msg)` sends `msg` to all of them — sender included,
matching the Phoenix / Socket.IO convention.

### Forms via `data-flv-submit` and `data-flv-clear`

```html
<form data-flv-submit="send_message">
  <input name="author" placeholder="Your name" />
  <input name="text" placeholder="Your message" data-flv-clear />
</form>
```

- `data-flv-submit` — intercept form submit, package inputs into
  payload map, send as event
- `data-flv-clear` — after the form submits, wipe this input
  (opt-in; without it, the input value is preserved)

## The lazy-snapshot trick

Notice how the handler does this on the first message:

```fitz
if (last_chat_html == "") {
  last_chat_html = render_chat(chat_room).raw
}
chat_room.messages.push(...)
```

Without this init, the first diff would be `"" → full div HTML`,
which the guard in `diff_html` rejects, and the client would fall
back to full HTML replace — wiping the form values the user just
typed. Snapshotting the BEFORE-mutation render lets the first diff
produce clean append patches for the new `<li>` without touching
the form.

## What proves it works

- Two browser windows.
- Both windows see the same messages in the same order.
- New messages appear in the other window within milliseconds.
- **The author input keeps its value** across every send — that's
  the Phase 3b diff engine preserving DOM state.
- **The message input clears** after send — because it has
  `data-flv-clear`.
- HTML escaping neutralizes any `<script>` payload sent as author
  or text — try typing `<script>alert('xss')</script>` as your
  text; you will see the literal characters, no popup.

## Known limitations

- **No persistence.** Restart the server and the messages disappear.
  Persistent storage plugs into Fitz's ORM (Phase 4 territory).
- **No presence.** No "Bob joined" / "Bob is typing" — those need
  lifecycle hooks (Phase 3c or Phase 4).
- **No moderation.** Every author is trusted. Real chats need
  authentication (Phase 3c `@authenticated @ws(...)`).
- **Race on newly-connected clients during broadcast.** If a client
  finishes its HTTP `GET` and then receives a broadcast patch that
  was diffed from an older server snapshot, the patches may not
  apply cleanly. The `html` fallback recovers, but silently.
