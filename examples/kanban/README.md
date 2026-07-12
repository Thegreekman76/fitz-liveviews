# Kanban — collaborative real-time board (Phase 3b showcase)

The flagship demo. A kanban board with three columns (To Do / In
Progress / Done). Cards can be created, moved between columns with
`←`/`→` buttons, and deleted. Every action from any client is
broadcast to every other client in real time with a compact patch
list — the diff engine handles all of it.

Source: [`examples/kanban/`](https://github.com/Thegreekman76/fitz-liveviews/tree/main/examples/kanban)

## Run

```powershell
cd examples/kanban
fitz run
```

Open http://127.0.0.1:3000/ in **two browser windows** (ideally
side-by-side). Type a title and your name in either window, click
`Add Card`. The card appears in both windows at the same time. Click
`→` to move it forward, `←` to move it back, `×` to delete.

## What each file does

- **`fitz.toml`** — package manifest with `fitz_liveviews` path
  dependency
- **`src/main.fitz`** — the whole kanban, ~250 lines split cleanly:
    1. `type Card { id, title, author, column }` and
       `type Board { cards, next_id }` — the state
    2. `let board` and `let last_board_html` — shared state via
       top-level `let` (F17 wraps in `Arc<Mutex>`)
    3. `next_column` / `prev_column` / `maybe_move` — column
       progression helpers
    4. `render_card`, `render_column`, `render_board` — the view
    5. `KANBAN_CSS` — CSS in its own constant so we escape `{` `}`
       once instead of scattering the escapes through the render
    6. `@get("/")` and `@ws("/live/kanban")` — the handlers

## The three-way showcase

This example is Fitz LiveViews' most compact demonstration of the
whole stack working together:

### Broadcast + shared state

```fitz
let board: Board = Board { cards: [], next_id: 1 }
let last_board_html: Str = ""
```

Two top-level `let`s. Every WebSocket handler sees the same values,
mutations are safely serialized by `Arc<Mutex>` under the hood.
`ws.broadcast(...)` fires the update to every connected client.

### `data-flv-value-*` for identifiers

```html
<button data-flv-click="move_right" data-flv-value-card_id="42">→</button>
```

Every card action button carries `data-flv-value-card_id`. The client
runtime auto-serializes it into `frame.payload["card_id"]`. Server
picks it up:

```fitz
if (frame.event == "move_right") {
  if (frame.payload.has("card_id")) {
    let target_id = frame.payload["card_id"]
    board.cards = board.cards.map(fn(c) => maybe_move(target_id, "right", c))
  }
}
```

### Diff patches doing minimum work

Every action produces the smallest possible patch:

- **Move a card**: one `set_attr` on the column class, or one
  `append` / `remove` if the DOM tree changes shape
- **Create a card**: one `append` at the `To Do` list
- **Delete a card**: one `remove` at the card's path

None of this touches the create form. The user's typed-but-not-yet
submitted title stays in the input — no lost work.

### Responsive by default

CSS grid with a media query. Three columns on desktop, one stacked
column on mobile. Try it in DevTools with device emulation at 375px.

## What's missing (candidates for future work)

- **Drag & drop** — swap the `←` `→` buttons for HTML5 Drag & Drop.
  Requires client-side JS for `dragstart` / `dragover` / `drop`
  events. Deferred to Phase 3c.
- **Per-card edit state** — click a card to expand into an edit
  form. This is where **LiveComponents** (Phase 4) would earn their
  keep: each card would own its `is_editing` state instead of the
  parent hoisting it into a `Map<card_id, Bool>`.
- **Persistence** — restart the server, board resets. Wire up Fitz's
  ORM (Phase 4 territory).
- **Auth** — anyone can create/move/delete anyone's card. Real
  boards need `@authenticated`. Phase 3c.
- **Race on concurrent card creation** — two users submitting at the
  same time may get the same `next_id`. Rare in practice; a proper
  UUID or DB-generated ID would fix it in production.
