# Companion UI library — pattern catalog

**Purpose**: living catalog of reusable component patterns emerging
from the Phase 8 SFC migrations of the 4 canonical examples
(counter/dashboard/chat/kanban). Direct input for Phase 9 (Companion
UI library) — the shortlist of 8 MVP components + their APIs will
be consolidated from this catalog when Phase 9.A arranca.

**Anti-goal**: not a spec. Patterns here are OBSERVATIONS from real
migration code, not committed API decisions. Phase 9.A picks the
shortlist + finalises signatures.

**Update convention**: every migration in Phase 8 (8.3 dashboard →
8.4 chat → 8.5 kanban) appends its findings. Each entry cites:
source example + minimal shape observed + rationale + API sketch.

---

## Populated during Phase 8.2 (counter) + Phase 8.3 (dashboard)

### `Button` — action element with variants

**Sources**:

- `examples/counter/src/Counter.fitzv` — `<button @click="increment">+1</button>`
  × 3 (increment / decrement / reset).
- `examples/dashboard/src/MetricTile.fitzv` — `<button class="btn
  btn-inc" @click="bump">+1</button>` × 2 (bump / reset).

**Common shape observed**:

- Text child (no icon-only case yet).
- `@click="event_name"` — always tied to a LiveView event handler.
- Variants marked by class: `.btn-inc` (blue prominent), `.btn-reset`
  (gray subtle). Dashboard uses full-width classes; counter uses
  browser defaults. Migration diff shrinks a lot if a canonical
  `<Button variant="...">` API existed.

**API sketch (candidate)**:

```
<Button variant="primary" @click="event_name">Label</Button>
<Button variant="secondary" @click="event_name">Label</Button>
<Button variant="danger" @click="event_name">Delete</Button>
<Button variant="ghost" size="sm" @click="event_name">Reset</Button>
```

**Rationale**: 5 occurrences across 2 migrations. Consistent shape
(text + event). Variants map cleanly to accent color + weight
convention already emerging in dashboard.

### `Card` — bordered/shadowed container with optional header + accent

**Sources**:

- `examples/dashboard/src/main.fitz::render_tile()` — parent wraps
  each `MetricTile` inside `<article class="tile tile-{accent}">
  <header class="tile-header"><h3 class="tile-label">{label}</h3>
  </header>{inner.raw}</article>`. CSS gives border-radius,
  shadow, top-border accent stripe (blue/green/red/purple/orange/
  teal), and vertical flex layout.

**Common shape observed**:

- Optional header slot (label / title).
- Body slot (component or arbitrary HTML).
- Accent color prop (top-border stripe pattern).
- Card acts as a WRAPPING container — clean separation between
  parent-owned config (label + accent) and component-owned state
  (count).

**API sketch (candidate)**:

```
<Card accent="blue">
  <header slot="header">
    <h3>Users Signed Up</h3>
  </header>
  <MetricTile ... />
</Card>
```

**Rationale**: 1 occurrence but the shape is CANONICAL (Vuetify's
`VCard`, MUI's `<Card>`, DaisyUI's `card`). Confident it will
appear in chat (message bubble) and kanban (card entity).

### `Icon` — inline visual glyph

**Sources**: not yet observed in counter or dashboard (both use text
buttons only). Expected in chat (avatars, send arrow) and kanban
(edit pencil, delete X, drag handle).

**Prospective API** (based on standard libraries):

```
<Icon name="chart" size="md" />
<Icon name="plus" />
```

**Rationale**: placeholder — will be added when a migration actually
uses one. Deferred until chat or kanban surfaces the need.

---

## Populated during Phase 8.4 (chat, 2026-07-16)

Chat migration (`examples/chat/`) surfaced these patterns:

### `Input` — text field with label + placeholder + validation attrs

**Sources**:

- `examples/chat/src/ChatRoom.fitzv` template — 2 `<input>` fields:
  - `<input name="author" placeholder="Your name" required
    autocomplete="off" />`
  - `<input name="text" placeholder="Your message" required
    autocomplete="off" data-flv-clear />`

**Common shape observed**:

- `name=` for form field key (used by `data-flv-submit` payload
  packing).
- `placeholder=` for hint text.
- `required` bare HTML5 boolean attr for client-side validation
  (accepted post Fitz core §9.ee V-2).
- `autocomplete="off"` for chat-style inputs.
- Optional `data-flv-clear` bare attr — LiveViews convention to
  clear input after form submit (accepted post §9.ee V-2).

**API sketch (candidate)**:

```
<Input
  name="author"
  placeholder="Your name"
  required
  autocomplete="off"
/>
<Input
  name="text"
  placeholder="Your message"
  required
  clear-on-submit
/>
```

**Rationale**: chat + kanban (card_editor `<input>`) + eventual
future CRUD example all need Input. Canonical shape widely
established (Vuetify VTextField, MUI TextField, chakra Input).

### `MessageList` / `MessageBubble` (chat-specific composition)

**Sources**:

- `examples/chat/src/ChatRoom.fitzv` template `<ul>` with `{#for
  m in messages}` rendering `<li><strong>{m.author}:</strong>
  {m.text}</li>` per message.

**Common shape observed**:

- Simple `<ul><li>` list with per-item template.
- Author + text as text content (no avatar in MVP; timestamps
  deferred).

**API sketch (candidate — chat-specific)**:

```
<MessageList items={messages}>
  {#for m in messages}
    <MessageBubble author={m.author} text={m.text} />
  {/for}
</MessageList>
```

**Rationale**: chat is the ONLY canonical use case. Kanban/dash
don't need it. Might NOT be a core `Card`-adjacent primitive —
could live as a chat-specific composition or as a `List` +
`ListItem` general primitive with a chat-specific example.

### Form (submit-first, no separate `<Form>` wrapper)

**Sources**:

- `examples/chat/src/ChatRoom.fitzv` template `<form data-flv-
  submit="send_message">` wrapping 2 inputs + submit button.

**Common shape observed**:

- LiveViews convention: `<form data-flv-submit="event_name">`.
  Framework client JS intercepts submit, packages named inputs,
  ships as event.
- Bare `<form>` element (no fancy `<Form>` component).

**API sketch**: probably NO `<Form>` component in MVP — the bare
`<form>` element with LiveViews conventions is already ergonomic
and matches HTML spec. Users compose forms with `<Input>` +
`<Button>` inside a bare `<form>`.

**Rationale**: `<Form>` wrappers in other frameworks (Vuetify
VForm, MUI FormControl) add value with client-side validation
state, submission handling, field arrays. For MVP, bare `<form>`
is enough — advanced form patterns land in Phase 9.B+.

## To populate during Phase 8.5 (kanban)

## To populate during Phase 8.5 (kanban)

Expected patterns from kanban migration:

- `Modal` — card editor overlay (probable Phase 9.B core component).
- `Input` — card title editing.
- `BoardColumn` — kanban-specific composition (probable `<Card>` +
  list of nested Cards).
- `MenuButton` — 3-dot context menu on cards (edit, delete, move).

---

## Phase 9.A — consolidation checklist (fillable when 9.A arranca)

After all 4 migrations complete, populate this section with the
final shortlist for the MVP UI library:

- [ ] **8 core components** — pick from patterns observed above:
  - Candidate: Button (5 occurrences, canonical shape)
  - Candidate: Card (canonical shape, 1+ occurrences)
  - Candidate: Input (expected chat + kanban)
  - Candidate: Modal (expected kanban)
  - Candidate: Alert (not yet observed — include as scaffolding?)
  - Candidate: Badge (not yet observed — include for count/status?)
  - Candidate: Spinner (not yet observed — include for async state?)
  - Candidate: Icon (expected chat + kanban)
- [ ] **Aesthetic direction** — pick A (Custom minimalist Radix-
  style) vs B (Vuetify Material) vs C (DaisyUI utility) based on
  the patterns actually observed.
- [ ] **Theme system tokens** — enumerate CSS custom props from
  observed usage (`--flv-color-primary`, `--flv-radius-md`, etc).
- [ ] **Placement decision** — sub-package inside `src/lib.fitz` vs
  path dep hermano `fitz-liveviews-ui/`.
- [ ] **Component-by-component API finalisation** — from sketches
  above to committed signatures.
