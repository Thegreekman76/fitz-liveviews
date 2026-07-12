# Kanban — collaborative real-time board (Phase 3b showcase)

The **flagship demo** of Fitz LiveViews. A three-column kanban board
(To Do / In Progress / Done) with card creation, movement, and
deletion — every action broadcast in real time to every open browser,
DOM state preserved across renders.

Source: [`examples/kanban/`](https://github.com/Thegreekman76/fitz-liveviews/tree/main/examples/kanban)

## Run

```powershell
cd examples/kanban
fitz run
```

Open http://127.0.0.1:3000/ in **two browser windows** side by side.
Type a title and your name, hit `Add Card`. The card appears in both
windows within milliseconds. Use `→` to move forward, `←` to move
back, `×` to delete.

## Why this example matters

The counter proves reactivity works. The chat proves broadcast +
forms work. **The kanban proves the whole stack scales to a serious
app in ~250 lines of Fitz** — no bundler, no framework, no ORM, no
external services.

It exercises every Phase 1 → Phase 3b feature:

- HTML primitives (`html`, `flv`, `h_join`, `h_when`)
- LiveView layout with the full HTML document + viewport meta
- Shared state via top-level `let` (Fitz F17 = `Arc<Mutex>`)
- Broadcast via `ws.broadcast(...)`
- Forms with `data-flv-submit` and `data-flv-clear`
- **`data-flv-value-*` for click payloads** (new in v0.2.0)
- Server-side HTML diff engine → compact patches over the wire
- Client-side patch application with `outerHTML` fallback
- Responsive by default (grid → stacked below 768px)

## The whole source

```fitz
--8<-- "kanban/src/main.fitz"
```

## Anatomy — the three-way showcase

### 1. Shared state via top-level `let`

```fitz
let board: Board = Board { cards: [], next_id: 1 }
let last_board_html: Str = ""
```

Two top-level `let`s. Every WebSocket handler sees the same values,
mutations are safely serialized by `Arc<Mutex>` under the hood. No
Redis, no pub-sub library.

### 2. Payloads with `data-flv-value-*`

The card action buttons need to tell the server WHICH card they refer
to. The `data-flv-value-<key>` convention (introduced in v0.2.0)
auto-serializes into the event payload:

```html
<button data-flv-click="move_right" data-flv-value-card_id="42">→</button>
```

The client extracts every `data-flv-value-<key>` attribute and puts
it in the payload map:

```fitz
if (frame.event == "move_right") {
  if (frame.payload.has("card_id")) {
    let target_id = frame.payload["card_id"]
    board.cards = board.cards.map(fn(c) => maybe_move(target_id, "right", c))
  }
}
```

### 3. Diff patches doing minimum work

When a card moves, the diff engine emits the smallest possible patch
list — usually one `remove` in the source column plus one `append`
in the destination. The rest of the DOM is untouched:

- The create form keeps its focus, its half-typed input value, and
  its cursor position
- Cards in other columns do not re-mount
- No flash, no scroll jump, no relayout beyond the actual change

Compare this to a naive `innerHTML = newHtml` on the whole app —
that would re-mount every card, blow away the form, and cause a
visible flicker.

### 4. Responsive by default

Grid layout with a media query:

```css
.board { display: grid; grid-template-columns: repeat(3, 1fr); }
@media (max-width: 768px) {
  .board { grid-template-columns: 1fr; }
}
```

Three columns on desktop. One stacked column on mobile. Test with
browser DevTools at 375px viewport.

## The `KANBAN_CSS` constant trick

Fitz templates interpolate `{expr}` inside strings, so **the `{` and
`}` used by CSS collide** with Fitz syntax. Two workarounds:

- Escape every brace inline (`\{` and `\}`) — tedious to scatter
- Move the CSS to a `let` constant with the escapes done once — clean

We do the second. See `KANBAN_CSS` in the source. Same trick can be
used for any embedded `<style>` block.

## Where LiveComponents would shine

If cards grew to support per-card edit state (click to expand into a
form), the parent's `Board` type would need to track `is_editing`
per card. That is exactly the "state hoisting" problem that Phase 4
LiveComponents solve — each card would own its own state without
polluting the parent.

The kanban is deliberately built without LiveComponents to make the
motivation for that phase clear from real code.

## Known limitations

- **No drag & drop** — buttons instead. Deferred to Phase 3c.
- **No persistence** — restart the server, board resets. ORM
  integration is Phase 4 territory.
- **No auth** — anyone can create / move / delete anyone's card.
- **Concurrent create race** — two users creating simultaneously may
  briefly collide on `next_id`. A proper UUID would fix it.
- **Card order within a column is insertion order** — no manual
  reordering within a column yet.
