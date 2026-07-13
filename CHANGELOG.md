# Changelog

All notable changes to `fitz-liveviews` — the real-time server-rendered
UI library for Fitz. Uses [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
format. Older phase progress is tracked in [`ROADMAP.md`](ROADMAP.md);
this file summarises what shipped at each release.

## [Unreleased] — 2026-07-13 — Phase 5.A.1: implicit `flv_register(...)` from decorators

**Requires Fitz core v0.20.1+.** No `fitz-liveviews` code changes; the
library API is identical. What changed is the compiler: it now
auto-generates the `flv_register(...)` boot call from the metadata
that `@live_component` + `@render_for` + `@on` leave in the
`TypeEnv`. Users writing components no longer need the manual boot
call.

### Changed

- **Kanban example** (`examples/kanban/`) — dropped the manual
  `flv_register("card_editor", ...)` boot call. Metadata alone drives
  the registration.
- **Dashboard example** (`examples/dashboard/`) — dropped the manual
  `flv_register("metric_tile", ...)` boot call.
- **`docs/components.md`** — "Register the component at boot" section
  reframed as "Registration is automatic", with a note explaining
  when to fall back to manual registration (custom initial state that
  differs from the type defaults). The "Coming next" section marks
  implicit registration as done.
- **`docs/live.md`** — `@live_component` teaser example no longer
  shows the manual boot call; "coming next" section updated.
- **`README.md`** — Phase 5.A.1 bullet added to the overview list.
- **`ROADMAP.md`** — Phase 4 "Codegen pass: turn `@live_component` +
  `@render_for` + `@on` into implicit registration" item marked
  done, with a note about the invariants the compiler enforces at
  build time.

### Requirements for the implicit path

- Every field of the `@live_component` type must declare a default —
  the compiler synthesises `TypeName {}` and needs defaults for all
  fields to succeed.
- `flv_register` must be in scope. Import it from `fitz_liveviews` at
  the top of the file; the compiler surfaces a clear error at build
  time if it isn't.
- Every `@live_component("name")` needs a matching `@render_for("name")`
  fn. The compiler aborts the injection with a clear error citing
  the missing renderer.
- Aliased imports (`from fitz_liveviews import flv_register as
  register`) are treated as out of scope — the injection emits
  `flv_register` verbatim. Just don't alias.

### Backward-compatible fallback

Manual `flv_register(...)` calls still work; the compiler skips the
implicit injection for any component that already has a manual
registration. This is the escape hatch for custom initial state that
differs from the type defaults.

## [v0.4.0] — 2026-07-12 — Phase 4: LiveComponents (stateful, per-instance)

**Milestone release.** Phase 4 of the roadmap closes end-to-end with
LiveComponents — stateful child components with per-instance state,
built on top of three new Fitz core decorators (requires Fitz core
v0.20.0+).

### Added

- **Framework layer** (`src/lib.fitz`, Session 2 — 2026-07-12):
  - `flv_register(name, initial_state, render_fn, event_handlers)` —
    register a component at boot with its initial state, renderer, and
    an event handler map keyed by event name.
  - `component(name, id) -> Html` — embed a component instance in a
    parent template. Injects `data-flv-component-name` +
    `data-flv-value-instance_id` wrappers so the client runtime can
    route events without parent code.
  - `dispatch_component_events(frame) -> Bool` — auto-routes a
    `LiveFrame` to the matching component + event handler. Users call
    this at the top of their `@ws` handler loop. Auto-seeds state from
    `initial_state` on the first hit so an event arriving before the
    parent's render does not crash.
  - Per-instance state store keyed by `(component_name, instance_id)`.
- **Starter template** (`templates/basic/`, Session 2) — used by
  `fitz new my-app --template liveviews` to scaffold a minimal working
  project with `@server`, an HTML page, and a live counter.
- **Kanban refactor** (`examples/kanban/`, Session 3 — 2026-07-12) —
  moved per-card inline title editing to a `@live_component("card_editor")`.
  Before/after LoC + walkthrough in `docs/examples/kanban.md`.
- **New dashboard example** (`examples/dashboard/`, Session 3) — grid
  of live `metric_tile` components, six independent instances, zero
  parent event branches. Demonstrates state isolation.
- **`docs/components.md`** (Session 3) — full walkthrough covering the
  three decorators, the three framework builtins, the canonical `@ws`
  loop, state isolation, component ↔ parent cooperation, and
  gradual-typing gotchas.
- **README + ROADMAP updates** (Sessions 2 + 3) — reflect that Phase 4
  is done.

### Requires

- Fitz core **v0.20.0+** for the three new decorators
  (`@live_component`, `@render_for`, `@on`) validated by the checker,
  plus the `fitz new --template liveviews` CLI. See Fitz core's
  CHANGELOG v0.20.0.
- Client runtime (baked into the `<script>` tag emitted by
  `flv_page(...)`) walks up to the enclosing component wrapper so
  `<button data-flv-click="save">` inside a component gets
  `component_name` + `instance_id` in its payload automatically.

### Notes

- The three decorators are **markers** in Fitz core — the checker
  validates their shape and persists metadata in the `TypeEnv`. The
  runtime dispatch lives here (`flv_register` + `component` +
  `dispatch_component_events`). A future refinement may replace the
  explicit `flv_register(...)` call with an implicit codegen pass
  driven by the decorators; the public API stays the same.
- **VSCode extension v0.3.2** (`editors/vscode/`) ships alongside with
  `livecomp` / `renderfor` / `onevent` / `flvcomp` / `dispatchcomp`
  snippets (introduced in Session 2 and refined in Session 3), plus a
  grammar tweak in v0.3.2 adding `data-flv-component-name` as a
  highlighted LiveViews-directive attribute (Session 4).

### Deferred (Phase 4 stretch → future)

- **Codegen pass** turning `@live_component` + `@render_for` + `@on`
  into an implicit registration and removing the explicit
  `flv_register(...)` call.
- **Per-instance init payload** — today every instance starts with the
  same `initial_state`; a `component(name, id, init_payload)` shape
  would let each instance start with per-instance seed data.
- **`dispatch_to_all(name, event, payload)`** for bulk actions across
  every live instance of a component.

## [v0.3.0] — 2026-07-12 — Phase 3b showcase: collaborative Kanban

**Showcase release.** Built without Phase 4 LiveComponents intentionally
so the framework proves itself with the primitives available before
adding component sugar.

### Added

- `examples/kanban/` — collaborative Kanban board with 3 columns
  (`todo` / `doing` / `done`), inline card editing, dragging via
  buttons, real-time broadcast between browsers. Baseline docs in
  `docs/examples/kanban.md`.
- `docs/live.md` progress on the `@ws` handler pattern for shared
  state + `dispatch_frame(...)` helper.

## [v0.2.0] — Phase 3a: forms + broadcast + shared state

- Form data harvesting from `data-flv-submit`.
- Multi-client broadcast via a topic-keyed subscribers store.
- Shared server state (kept alive by the `@ws` handler loop) with
  optimistic-locking-safe update pattern.

## [v0.1.0] — Phase 1 + 2: HTML primitives + LiveView MVP

- `Html` opaque type, `html(raw)` constructor, `raw_html` alias,
  `flv(...)` escape helper.
- Convention-based XSS-safety (manual `flv()` for user data).
- Composition helpers `h_join`, `h_when`, `h_either`.
- LiveView core: `flv_page(...)`, `flv_run(...)`, `LiveFrame` record,
  client runtime bundled in the emitted `<script>`.
