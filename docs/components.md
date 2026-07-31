# LiveComponents

> Reusable server-rendered components with independent per-instance
> state. One definition, many instances, each carrying its own state
> in the framework's store.

**Status**: MVP landed in Phase 4 (framework layer + kanban refactor
+ dashboard example). API is stable within Phase 4 but expected to
grow (implicit registration from decorators, per-instance init
payload, presence primitives). Nothing here is aspirational — every
snippet on this page runs today.

## When to reach for a component

A "component" here is a *server-side* concept — it lives inside the
Fitz process, holds its own slice of state in a shared store, and is
rendered as raw HTML that the parent LiveView interpolates into its
template. There is no JavaScript component library involved.

Reach for one when:

1. **You want per-instance state isolation.** A per-card edit
   toggle, a per-row expand/collapse, a per-tab open/closed flag
   — anything where "N repeated widgets each own a slice of UI
   state" is the shape you have.
2. **You want to reuse the same widget shape in different
   containers.** The dashboard example renders six identical
   `metric_tile` instances; each has independent `count` state.
3. **You want to keep the parent WS handler small.** Every event
   the component handles disappears from the parent's `if
   (frame.event == "...")` ladder.

You do **not** need a component for:

- A single stateful widget that has no siblings — put the state
  directly in the parent LiveView.
- A pure formatting helper — write a plain `fn(...) -> Html`
  (see [`docs/html.md`](html.md) for `flv` / `h_join` / `h_when`).
- Shared state across ALL connections — use a top-level `let`
  (see [Phase 3a additions in the LiveViews guide](liveviews.md#phase-3a-additions-forms-broadcast-shared-state)).

## The three decorators

Fitz core exposes three decorators that the checker validates. Since
Fitz core v0.20.1 the compiler auto-generates one `flv_register(...)`
call per component from the decorators — no manual boot call needed
in your program. Manual calls still work and take precedence if you
prefer explicit boot wiring.

| Decorator                            | Attaches to  | Meaning                                            |
|--------------------------------------|--------------|----------------------------------------------------|
| `@live_component("name")`            | `type T`     | This type is the state of a component named `name` |
| `@render_for("name")`                | `fn`         | This fn renders `name`'s state as HTML             |
| `@on("name", "event")`               | `fn`         | This fn handles `event` for component `name`       |

A single fn may carry multiple `@on(...)` decorators — one per event
it handles.

**One important gotcha**: the `@render_for` return type must be
`Str` or omitted (inferred as `Any`), *not* the fitz-liveviews `Html`
nominal. The checker in Fitz core does not know about the framework's
`Html` type today — it accepts `Str` (raw HTML) or `Any` (gradual
escape). In practice: drop the `-> Html` annotation; return
`html(...)` from the body; the framework calls `.raw` at runtime.

```fitz
// ✅ Works
@render_for("card_editor")
fn card_editor_render(state: CardEditor) {
  return html("<div>...</div>")
}

// ❌ Rejected by the checker
@render_for("card_editor")
fn card_editor_render(state: CardEditor) -> Html {
  return html("<div>...</div>")
}
```

## The three framework builtins

Layered on top of the decorators, the framework in `src/lib.fitz`
provides three plain Fitz functions you actually call:

| Function                                                             | Purpose                                               |
|----------------------------------------------------------------------|-------------------------------------------------------|
| `flv_register(name, initial_state, render_fn, event_handlers)`       | Wire a component into the registry — call once at boot |
| `component(name, instance_id) -> Html`                               | Render an instance, wrapped with tracking attributes  |
| `dispatch_component_events(frame: LiveFrame) -> Bool`                | Route a frame to its handler; returns `true` on match |

## A minimal component from scratch

Let's build the smallest useful component: a per-row expand/collapse
toggle. State is `is_open: Bool`. Events are `open` / `close`.

### 1. Declare the state type

```fitz
@live_component("row_toggle")
type RowToggle {
  is_open: Bool = false
}
```

### 2. Write the render function

```fitz
@render_for("row_toggle")
fn row_toggle_render(state: RowToggle) {
  if (state.is_open) {
    return html("""<button data-flv-click="close">▼ Hide</button>""")
  }
  return html("""<button data-flv-click="open">▶ Show</button>""")
}
```

### 3. Write one handler per event

```fitz
@on("row_toggle", "open")
fn row_toggle_open(state: RowToggle, payload: Map<Str, Str>) -> RowToggle {
  return RowToggle { is_open: true }
}

@on("row_toggle", "close")
fn row_toggle_close(state: RowToggle, payload: Map<Str, Str>) -> RowToggle {
  return RowToggle { is_open: false }
}
```

Each handler takes `(state, payload)` and returns the **new** state.
Immutable-style — no in-place mutation. The framework stores the
returned value in the shared store, keyed by `(name, instance_id)`.

### 4. Registration is automatic

Since Fitz core v0.20.1, the compiler walks the metadata that
`@live_component` + `@render_for` + `@on` leave in the `TypeEnv` and
auto-appends the equivalent `flv_register(...)` call to the top-level
program, before the HTTP server starts. You don't need to write it
by hand.

If you prefer explicit registration, or need per-instance seed data
that differs from the type defaults, you can still write a manual
call. It runs before the implicit injection, and the injection skips
components you already registered:

```fitz
flv_register(
  "row_toggle",
  RowToggle { is_open: true },  // override the default `false`
  row_toggle_render,
  {
    "open": row_toggle_open,
    "close": row_toggle_close,
  }
)
```

Requirements for the implicit path:
- Every field of the `@live_component` type must declare a default.
  Without them, the synthesized `TypeName {}` empty struct literal
  would fail. Add `= <default>` on every field.
- `flv_register` must be in scope (import it from `fitz_liveviews`).
  The compiler surfaces a clear error at build time if it isn't.
- Every `@live_component("name")` needs a matching `@render_for("name")`
  fn. Otherwise the injection aborts with a clear error citing the
  missing renderer.

### 5. Embed instances in the parent template

```fitz
fn render_row(row: Row) -> Html {
  let toggle = component("row_toggle", "row-{row.id}")
  return html("""<tr>
    <td>{flv(row.label)}</td>
    <td>{toggle.raw}</td>
  </tr>""")
}
```

`component(name, instance_id)` returns an `Html` value. The framework
wraps the render output with a `<div data-flv-component-name="row_toggle"
data-flv-value-instance_id="row-42">...</div>` so click events fired
from inside are routed correctly.

### 6. Route events in the WS handler

```fitz
@ws("/live/table")
async fn table_socket(ws: WsConn<LiveFrame>) {
  loop {
    let frame = ws.recv()?
    if (dispatch_component_events(frame)) {
      // A `row_toggle` handler updated its instance's state.
    } else {
      // Parent-level events, e.g. sorting, filtering, etc.
    }
    let new_html = render_table(rows).raw
    let patches = diff_html(last_html, new_html)
    ws.send(LiveFrame { html: new_html, patches: patches })?
    last_html = new_html
  }
}
```

`dispatch_component_events(frame)` returns `true` if the frame carried
a component context (`component_name` + `instance_id` in the payload,
enriched automatically by the client runtime) *and* the named
component + event were registered. Otherwise it returns `false` and
you handle the frame yourself.

## The canonical `@ws` loop pattern

Every LiveView using components follows the same shape at the top of
its loop:

```fitz
loop {
  let frame = ws.recv()?
  // Optional: lazy-init the previous-render snapshot for shared-state
  // apps so the first diff is a clean append instead of empty→full.
  if (last_html == "") {
    last_html = render_root().raw
  }
  // Route to a component first.
  let handled = dispatch_component_events(frame)
  if (handled) {
    // Optional: if the component's state change also triggers
    // parent-side effects (e.g. the kanban's "save" event updates
    // Board.cards from payload["text"]), do them here.
    if (frame.event == "save") { /* parent effect */ }
  } else {
    // Parent-level branches: create, delete, filter, sort, ...
    if (frame.event == "create") { ... }
    if (frame.event == "delete") { ... }
  }
  // Re-render + diff + broadcast (or send, depending on your app).
  let new_html = render_root().raw
  let patches = diff_html(last_html, new_html)
  ws.broadcast(LiveFrame { html: new_html, patches: patches })?
  last_html = new_html
}
```

You will see this exact shape in both examples that ship with the
framework:

- **[Kanban](examples/kanban.md)** — one component (`card_editor`),
  parent has four branches. Component's `save` fires a parent effect
  (updating `Board.cards`).
- **[Dashboard](examples/dashboard.md)** — six instances of one
  component (`metric_tile`), parent has **zero** branches. Every
  event is a component event.

!!! tip "Ready-made component patterns"
    For a catalog of concrete UI components — DataGrid, tabbed/stepped forms,
    modal, toasts, tree, cascade selects, and more — with a snippet each, see the
    **[UI components catalog](ui-components.md)**. Its full runnable reference is
    the **[Admin ABM](examples/admin.md)** example.

## How the client walks up to find the component context

Every click / submit inside a component instance needs to reach the
server with `component_name` + `instance_id` in the payload so
`dispatch_component_events` can route it. The client-side runtime
does this automatically.

When the user clicks a `data-flv-click` element, the runtime:

1. Reads `data-flv-value-*` attributes on the clicked element into
   the payload.
2. Walks up the DOM to the closest `[data-flv-component-name]` — the
   framework's wrapper around each component instance.
3. Adds `component_name` and any `data-flv-value-*` attributes from
   the wrapper (which is where `instance_id` lives) to the payload.
4. Sends the frame.

You do not write any of this logic. Just wrap your data-flv-value-\*
attributes on the buttons / forms inside the component template and
put `{component("name", "id").raw}` in the parent template. The
framework and the client runtime handle the routing.

## State isolation — the whole point

Every `component("name", id)` call is looked up by the composite key
`"{name}:{id}"`. Two calls with different `id`s → two independent
state entries.

```fitz
// Two live instances of the same component. Independent counters.
{component("metric_tile", "signups").raw}
{component("metric_tile", "revenue").raw}
```

An event for `instance_id="signups"` only ever mutates
`COMPONENT_STATE_STORE["metric_tile:signups"]`. `revenue`'s state
stays untouched. The dashboard example demonstrates this end-to-end.

## Component ↔ parent cooperation

Components own **UI-only** state — the kind of state that would live
in `useState` on the client in a React app or in a `data-let` on the
element in a Vue app. Persistent business data (the Board's cards,
the user's cart, the article being edited) still lives in top-level
`let`s owned by the parent LiveView.

When both need to update on the same event, the pattern is:

```fitz
let handled = dispatch_component_events(frame)
if (handled) {
  // Component already updated its own UI state.
  if (frame.event == "save") {
    // Parent applies the corresponding data change.
    board.cards = board.cards.map(fn(c) => apply_save(...))
  }
}
```

The kanban's `card_editor` uses exactly this split:

- `card_editor.is_editing` → owned by the component (UI).
- `card_editor.text` → the edit buffer, owned by the component
  (short-lived UI state).
- `Board.cards[i].title` → owned by the parent (persistent data).

The `save` handler on the component sets `is_editing = false` and
captures the new text; the parent handler *also* picks up
`payload["text"]` and writes it into `Board.cards`. Nothing about the
component reaches for `Board`.

## Gotchas of gradual typing at the framework boundary

The framework layer stores `render_fn` and each event handler as
`Any`. That is deliberate — Fitz's checker cannot express "this fn
takes some `T` where `T` is the type declared by the matching
`@live_component`". Consequences:

1. **The checker will not catch a handler with the wrong param
   type.** If you register `bump: some_int_handler` where
   `some_int_handler` expects `Int` instead of `MetricTile`, the
   checker accepts. The runtime will crash on the first dispatch
   with a type mismatch. Verify handler signatures manually.
2. **The framework unwraps the render result via `.raw`.** If your
   render fn returns a plain `Str` instead of an `Html`, the
   `.raw` access will fail at runtime. Always return an `html(...)`
   value.
3. **`payload` is `Map<Str, Str>`.** Every value is a string. If
   your event carries a number (`card_id`, `count`, etc.), parse it
   with `Str.parse_int(...)` inside the handler.

## Per-connection instances (`component_with`)

The state store is process-global, keyed `"{name}:{instance_id}"` — so
*who* shares an instance is entirely decided by the id you pass. Three
scopes, one mechanism:

- **Shared** — a fixed id (`component("Board", "main")`): every
  connection reads and mutates the same state. Right for collaborative
  views (the kanban, the dashboard tiles).
- **Domain-keyed** — an id derived from data
  (`component("row_toggle", "row-{row.id}")`): one instance per row,
  still shared across connections.
- **Per-connection** — an id minted per socket. Right for UI state
  that must NOT leak between users: dialogs, selections, filters. The
  Admin ABM's ConfirmDialog is the canonical example.

The per-connection recipe (v0.11.0):

```fitz
@ws("/live/screen")
async fn screen_socket(ws: WsConn<LiveFrame>, cookie: Str?) {
    let locale = locale_from_cookie(cookie)
    // One instance id per socket. `Uuid.v4()` returns a `Uuid`;
    // instance ids are `Str`, so convert at the mint site.
    let cid = Uuid.v4().to_str()
    ...
}
```

and in the render fn, seed the instance with connection-scoped data
using **`component_with(name, id, initial)`** — like
`component(name, id)`, but the FIRST render seeds the state store with
`initial` instead of the registry-wide `initial_state` (later renders
ignore it):

```fitz
let dlg = component_with("confirm_dialog", cid, confirm_dialog { locale: locale })
```

The SSR first paint (no socket yet) renders the component with a shared
placeholder id — `component_with("confirm_dialog", "ssr", ...)` — which
is safe because events only travel over the socket: nothing can mutate
the placeholder instance, and the live render replaces it on the first
event.

Known limitation: per-connection instances are never evicted from the
store (no disconnect hook, and `Map` has no `remove` in Fitz core yet).
Each connection leaks one small state entry per component — fine at
showcase scale; an `flv_drop_instance(...)` cleanup API is planned once
core grows `Map.remove`.

## What the framework does not (yet) provide

- ~~**Per-instance init payload.**~~ *Done in v0.11.0.*
  `component_with(name, id, initial)` seeds an instance with its own
  initial state — see "Per-connection instances" above.
- **`dispatch_to_all(name, event, payload)`** for bulk actions across
  every registered instance. Today you loop by hand over instance
  ids you tracked yourself.
- ~~**Implicit registration from decorators.**~~ *Done in Fitz core
  v0.20.1.* `@live_component` + `@render_for` + `@on` auto-generate
  the boot registration.
- **Presence** (per-user state across connections). Coming after
  Phase 4.
- **Component-scoped CSS.** Emit CSS from the parent's `<style>` for
  now. Scoped styles land after Phase 4.
- **Nested components** — a component embedding another component.
  Should work in principle (nothing in the framework blocks it) but
  is not tested. Report bugs.

## See also

- **[LiveViews guide (`docs/liveviews.md`)](liveviews.md)** — the framework
  from Phase 2 (initial render + WebSocket + patch cycle) that
  components sit on top of.
- **[HTML primitives (`docs/html.md`)](html.md)** — `flv`,
  `h_join`, `h_when`, `h_either` used inside render templates.
- **[Kanban example (`docs/examples/kanban.md`)](examples/kanban.md)** —
  one component (`card_editor`) alongside parent-level events.
- **[Dashboard example (`docs/examples/dashboard.md`)](examples/dashboard.md)** —
  many instances of one component (`metric_tile`), parent handler
  with zero branches.
