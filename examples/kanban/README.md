# Kanban — collaborative real-time board (Phase 4 showcase)

The flagship demo. A kanban board with three columns (To Do / In
Progress / Done). Cards can be created, moved between columns with
`←`/`→` buttons, edited inline via a `@live_component("card_editor")`
(one instance per card_id, independent edit UI state), and deleted.
Every action from any client is broadcast to every other client in
real time with a compact patch list — the diff engine handles all of
it.

Source: [`examples/kanban/`](https://github.com/Thegreekman76/fitz-liveviews/tree/main/examples/kanban)

## Run

```powershell
cd examples/kanban
fitz run
```

Open http://127.0.0.1:3000/ in **two browser windows** (ideally
side-by-side). Type a title and your name in either window, click
`Add Card`. The card appears in both windows at the same time. Click
`edit` to open the inline title editor — the toggle is *per card_id*,
so opening one card's editor does not open any other. Click `→` to
move forward, `←` to move back, `×` to delete.

## What each file does

- **`fitz.toml`** — package manifest with `fitz_liveviews` path
  dependency
- **`src/main.fitz`** — the whole kanban, ~475 lines split cleanly:
    1. `type Card { id, title, author, column }` and
       `type Board { cards, next_id }` — the state
    2. `let board` and `let last_board_html` — shared state via
       top-level `let` (F17 wraps in `Arc<Mutex>`)
    3. `@live_component("card_editor")` + `@render_for` + three
       `@on(...)` handlers — the card editor component
    4. `next_column` / `prev_column` / `maybe_move` /
       `apply_title_edit` / `card_id_from_instance` — column and
       edit helpers
    5. `render_card`, `render_column`, `render_board` — the view
    6. `KANBAN_CSS` — CSS in its own constant so we escape `{` `}`
       once instead of scattering the escapes through the render
    7. `flv_register("card_editor", ...)` at the top level — one
       call at boot wires the component into the framework
    8. `@get("/")` and `@ws("/live/kanban")` — the handlers

## The whole-stack showcase

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

### `@live_component("card_editor")` — per-card state isolation

```fitz
@live_component("card_editor")
type CardEditor {
  is_editing: Bool = false
  text: Str = ""
}
```

One component definition, one instance per card_id (id =
`"editor-<card_id>"`). Clicking `edit` on card 5 opens the editor for
card 5 *only* — card 3's editor stays closed because it has its own
independent state entry in the framework's store. The parent renders
each editor slot with `{component("card_editor", "editor-{c.id}").raw}`
and the framework handles state seeding, event routing, and re-render.

The parent WS handler asks the framework to route the frame first:

```fitz
let handled = dispatch_component_events(frame)
if (handled) {
  // The component already updated its own UI state. If it was a
  // save, propagate to Board.cards so the title change persists.
  if (frame.event == "save") { /* update Board.cards */ }
} else {
  // Parent-only events (create_card, move_left, delete_card, ...)
}
```

See [`docs/components.md`](../../docs/components.md) for the full
component walkthrough.

### `data-flv-value-*` for identifiers

```html
<button data-flv-click="move_right" data-flv-value-card_id="42">→</button>
```

Every card action button carries `data-flv-value-card_id`. The client
runtime auto-serializes it into `frame.payload["card_id"]`. For clicks
*inside* the `card_editor` component wrapper, the runtime also walks
up to the wrapper's `data-flv-component-name` / `data-flv-value-instance_id`
attributes and adds them to the payload — that is what lets
`dispatch_component_events` know which component and which instance the
frame belongs to.

### Diff patches doing minimum work

Every action produces the smallest possible patch:

- **Move a card**: one `set_attr` on the column class, or one
  `append` / `remove` if the DOM tree changes shape
- **Create a card**: one `append` at the `To Do` list
- **Delete a card**: one `remove` at the card's path
- **Edit save**: one `text` patch on the card title's text node +
  small `replace` on the editor slot switching form → button

None of this touches the create form. The user's typed-but-not-yet
submitted title stays in the input — no lost work.

### Responsive by default

CSS grid with a media query. Three columns on desktop, one stacked
column on mobile. Edit form is `flex-wrap: wrap` so the input,
`Save`, and `Cancel` buttons stack cleanly at narrow widths. Try it
in DevTools with device emulation at 320px.

## What's missing (candidates for future work)

- **Drag & drop** — swap the `←` `→` buttons for HTML5 Drag & Drop.
  Requires client-side JS for `dragstart` / `dragover` / `drop`
  events. Deferred to Phase 4.x polish.
- **Persistence** — restart the server, board resets. Wire up Fitz's
  ORM.
- **Auth** — anyone can create/move/delete/edit anyone's card. Real
  boards need `@authenticated`.
- **Race on concurrent card creation** — two users submitting at the
  same time may get the same `next_id`. Rare in practice; a proper
  UUID or DB-generated ID would fix it in production.
