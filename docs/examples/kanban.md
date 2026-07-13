# Kanban — collaborative real-time board (Phase 4 showcase)

The **flagship demo** of Fitz LiveViews. A three-column kanban board
(To Do / In Progress / Done) with card creation, movement, inline
title editing, and deletion — every action broadcast in real time to
every open browser, DOM state preserved across renders.

Source: [`examples/kanban/`](https://github.com/Thegreekman76/fitz-liveviews/tree/main/examples/kanban)

## Run

```powershell
cd examples/kanban
fitz run
```

Open http://127.0.0.1:3000/ in **two browser windows** side by side.
Type a title and your name, hit `Add Card`. The card appears in both
windows within milliseconds. Use `→` to move forward, `←` to move
back, `×` to delete. Click `edit` on any card to open its inline
editor — the toggle is *per card_id*, so opening one card's editor
does not disturb any other card.

## Why this example matters

The counter proves reactivity works. The chat proves broadcast +
forms work. **The kanban proves the whole stack scales to a serious
app in ~475 lines of Fitz** — no bundler, no framework, no ORM, no
external services — and *shows* how `@live_component` slots into an
existing LiveView without rewriting the parent handler.

It exercises every Phase 1 → Phase 4 feature:

- HTML primitives (`html`, `flv`, `h_join`, `h_when`)
- LiveView layout with the full HTML document + viewport meta
- Shared state via top-level `let` (Fitz F17 = `Arc<Mutex>`)
- Broadcast via `ws.broadcast(...)`
- Forms with `data-flv-submit` and `data-flv-clear`
- `data-flv-value-*` for click payloads
- Server-side HTML diff engine → compact patches over the wire
- **`@live_component("card_editor")`** — per-card edit UI with
  independent state (`is_editing` + `text` buffer), one instance
  per card_id, dispatched via `dispatch_component_events(frame)`
- Client-side patch application with `outerHTML` fallback
- Responsive by default (grid → stacked below 768px)

## The whole source

```fitz
--8<-- "kanban/src/main.fitz"
```

## Anatomy — the four-way showcase

### 1. Shared state via top-level `let`

```fitz
let board: Board = Board { cards: [], next_id: 1 }
let last_board_html: Str = ""
```

Two top-level `let`s. Every WebSocket handler sees the same values,
mutations are safely serialized by `Arc<Mutex>` under the hood. No
Redis, no pub-sub library.

### 2. `@live_component` for per-card state isolation

The `CardEditor` state and its three handlers are a self-contained
unit. Since Fitz core v0.20.1, the compiler auto-registers the
component from the decorators — no manual boot call needed:

```fitz
@live_component("card_editor")
type CardEditor { is_editing: Bool = false, text: Str = "" }

// The compiler auto-generates the equivalent of:
//
//   flv_register(
//     "card_editor",
//     CardEditor {},  // uses type defaults
//     card_editor_render,
//     { "start": card_editor_start,
//       "cancel": card_editor_cancel,
//       "save": card_editor_save,
//     }
//   )
//
// from the `@render_for("card_editor")` and `@on("card_editor", ...)`
// decorators, appended to the top-level program before the HTTP
// server starts.
```

The parent embeds an instance per card:

```fitz
let editor_instance = component("card_editor", "editor-{c.id}")
```

Two cards → two independent state entries in the framework's store.
Opening editor for card 5 leaves card 3 untouched.

### 3. Payloads with `data-flv-value-*`

The card action buttons need to tell the server WHICH card they refer
to. The `data-flv-value-<key>` convention auto-serializes into the
event payload:

```html
<button data-flv-click="move_right" data-flv-value-card_id="42">→</button>
```

For clicks *inside* a component wrapper, the client also enriches
the payload with `component_name` and `instance_id` by walking up
to the closest `[data-flv-component-name]` element. That is what
`dispatch_component_events` reads.

### 4. Component ↔ parent cooperation on save

The `card_editor` component owns the UI state (open/closed + edit
buffer). The Board's card titles are owned by the parent. On save,
both need to update. The pattern:

```fitz
let handled = dispatch_component_events(frame)
if (handled) {
  // Component updated its own UI state.
  if (frame.event == "save") {
    // Parent applies the corresponding data change.
    board.cards = board.cards.map(fn(c) => apply_title_edit(card_id, new_text, c))
  }
} else {
  // Parent-only events: create_card, move_left, move_right, delete_card.
}
```

Neither the component reaches into `Board`, nor does the parent poke
inside the component's state. They cooperate purely through the
`save` event's payload. See
[`docs/components.md`](../components.md#component-parent-cooperation)
for the full walkthrough.

### 5. Diff patches doing minimum work

When a card moves, the diff engine emits the smallest possible patch
list — usually one `remove` in the source column plus one `append`
in the destination. The rest of the DOM is untouched:

- The create form keeps its focus, its half-typed input value, and
  its cursor position
- Cards in other columns do not re-mount
- Open editors in other cards stay open
- No flash, no scroll jump, no relayout beyond the actual change

Compare this to a naive `innerHTML = newHtml` on the whole app —
that would re-mount every card, blow away the form and any open
editor, and cause a visible flicker.

### 6. Responsive by default

Grid layout with a media query:

```css
.board { display: grid; grid-template-columns: repeat(3, 1fr); }
@media (max-width: 768px) {
  .board { grid-template-columns: 1fr; }
}
```

Three columns on desktop. One stacked column on mobile. The edit
form's `flex-wrap: wrap` lets the input + Save + Cancel stack
cleanly at narrow widths. Test with browser DevTools at 320px
viewport.

## The `KANBAN_CSS` constant trick

Fitz templates interpolate `{expr}` inside strings, so **the `{` and
`}` used by CSS collide** with Fitz syntax. Two workarounds:

- Escape every brace inline (`\{` and `\}`) — tedious to scatter
- Move the CSS to a `let` constant with the escapes done once — clean

We do the second. See `KANBAN_CSS` in the source. Same trick can be
used for any embedded `<style>` block.

## Known limitations

- **No drag & drop** — buttons instead. Deferred to Phase 4.x
  polish.
- **No persistence** — restart the server, board resets. ORM
  integration is separate.
- **No auth** — anyone can create / move / delete / edit anyone's
  card.
- **Concurrent create race** — two users creating simultaneously may
  briefly collide on `next_id`. A proper UUID would fix it.
- **Card order within a column is insertion order** — no manual
  reordering within a column yet.
