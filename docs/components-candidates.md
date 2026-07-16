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

## Populated during Phase 8.5 (kanban, 2026-07-16)

Kanban migration (`examples/kanban/`) surfaced these patterns:

### `Button` (variants observed in kanban)

**Additional variant classes seen** (extends Phase 8.3 `Button`):

- `.btn` (base) — neutral grey background, small padding
- `.btn-del` — destructive (red-ish). Used for card delete `×`.
- `.btn-edit` — subtle secondary (blue-ish). Used for card
  "edit" trigger.
- `.btn-save` — success (green-ish). Used for card editor save.

**API refinement (candidate)**:

```
<Button variant="primary">Add Card</Button>
<Button variant="danger" size="sm" aria-label="Delete card">×</Button>
<Button variant="ghost" size="sm">edit</Button>
<Button variant="success" size="sm">Save</Button>
```

Rationale: 4 variants ARE emerging as canonical (primary /
success / danger / ghost). MVP could ship with those 4; more
variants (warning / info) added later if demand emerges.

### `Toggle` / conditional UI pattern (edit-in-place)

**Sources**:

- `examples/kanban/src/CardEditor.fitzv` — `{#if is_editing}
  <form>...</form> {#else} <button data-flv-click="start">edit
  </button> {/if}` — toggle between static display and edit form.

**Pattern**: state field controls which subtree renders. Not a
"component" per se; a common template pattern that MVP `<Modal>`,
`<Alert dismissable>`, `<Tabs>`, etc. all use internally.

**Not a shortlist component** — this is a template-level idiom,
not something to abstract as a reusable primitive. Document as
"canonical pattern" instead in Phase 9 docs.

### `Icon` — arrow characters as icons (interim; SVG in Phase 9)

**Sources**:

- `examples/kanban/src/main.fitz::render_card` — `←`/`→`/`×`
  arrow chars used as button labels for move-left/move-right/
  delete. Text-based, no SVG library.

**Rationale**: kanban proves the NEED for icons in real UIs
(actions with visual affordance beyond text). MVP `<Icon>` should
support at least these directional + destructive icons: arrow-
left/arrow-right/close/edit/plus/trash/check.

**API sketch (unchanged from Phase 8.3)**:

```
<Icon name="arrow-left" size="sm" />
<Icon name="close" />
<Icon name="edit" />
```

### `Column` / `BoardColumn` (kanban-specific)

**Sources**:

- `examples/kanban/src/main.fitz::render_column` — `<section
  class="column"><h2>{title}</h2><ul class="card-list">
  {items}</ul></section>` per column.

**Pattern**: NOT a core primitive — kanban-specific. Same
argument as chat's `MessageList` / `MessageBubble`: composition
of `<Card>` + text.

**API sketch (kanban-specific composition)**:

```
<BoardColumn title="To Do" count={cards.len()}>
  {#for c in cards}
    <CardComponent card={c} />
  {/for}
</BoardColumn>
```

**Rationale**: too specific for MVP shortlist. Save for kanban-
adjacent examples in Phase 9 docs / cookbook.

---

## Phase 9.A — consolidation checklist (fillable when 9.A arranca)

After all 4 migrations complete (counter/dashboard/chat/kanban),
populate this section with the final shortlist for the MVP UI
library:

- [x] **Counter migration complete** (Phase 8.2 CERRADO)
- [x] **Dashboard migration complete** (Phase 8.3 CERRADO)
- [x] **Chat migration complete** (Phase 8.4 CERRADO)
- [x] **Kanban migration complete** (Phase 8.5 CERRADA PARCIAL —
      board-level state stays classic until Phase 11.7+)

Ready for Phase 9.A:

- [ ] **8 core components shortlist** — pick from patterns
      observed above:
  - **Button** (9 occurrences across 4 examples — canonical shape
    with 4 variants primary/success/danger/ghost + sm/md sizes +
    icon slot)
  - **Card** (2+ occurrences: dashboard tile wrapper, chat message
    bubble candidate — canonical shape with header/body/footer
    slots + accent color prop + optional clickable variant)
  - **Input** (2+ occurrences: chat form, kanban create form,
    kanban card editor — canonical shape with name/placeholder/
    validation attrs + label + hint + error prop)
  - **Modal** (kanban card editor is CLOSE — the `{#if is_editing}`
    toggle is Modal-adjacent — MVP as backdrop + close +
    focus-trap)
  - **Alert** (not observed yet — include as scaffolding for
    Phase 9.B: info/success/warn/danger variants + dismissible)
  - **Badge** (dashboard tile count is Badge-adjacent — MVP as
    count/status pill + color variants)
  - **Spinner** (not observed yet — include for async state
    scaffolding)
  - **Icon** (kanban arrow chars prove the NEED — MVP with 20-30
    core SVG icons)
- [ ] **Aesthetic direction** — pick A (Custom minimalist Radix-
      style) vs B (Vuetify Material) vs C (DaisyUI utility)
      based on patterns actually observed. Kanban's classes
      (`.btn-del`/`.btn-edit`/`.btn-save`) suggest B/C would fit
      naturally; A stays neutral.
- [ ] **Theme system tokens** — enumerate CSS custom props from
      observed usage:
      - `--flv-color-primary` (Fitz orange `#CE412B`)
      - `--flv-color-success` (green `#3c763d`)
      - `--flv-color-danger` (red `#a94442`)
      - `--flv-color-info` (blue `#31708f`)
      - `--flv-color-muted` (grey `#666`)
      - `--flv-radius-md` (6-8px)
      - `--flv-shadow-card` (`0 1px 3px rgba(0,0,0,0.08)`)
      - Font: `system-ui, -apple-system, "Segoe UI", sans-serif`
- [ ] **Placement decision** — sub-package inside `src/lib.fitz`
      vs path dep hermano `fitz-liveviews-ui/`.
- [ ] **Component-by-component API finalisation** — from
      sketches above to committed signatures.

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
