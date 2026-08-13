# Fitz LiveViews — Roadmap

Real-time server-rendered UI for Fitz. WebSocket diffing, zero JS build,
Phoenix LiveView-inspired.

This roadmap is **living** — phases close in order, deliverables are ticked
as they land. Aspirational timelines are best-effort, not commitments.

---

## Phase 0 — Repo bootstrap 🏁 ✅ (done)

Get the repo to a state that looks and feels like a real open-source project,
even before any real code lands.

- [x] MIT License
- [x] `fitz.toml` (package manifest with `[lib]` section)
- [x] `.gitignore` (Fitz + editor + OS)
- [x] `src/lib.fitz` placeholder
- [x] **Extended README** — pitch, comparison table (LiveViews vs Vue vs Phoenix),
      quick start, install, contributing
- [x] **ROADMAP.md** (this file)
- [x] **Logo** — main hero (`assets/logo.png`, Fitz-related visual language)
- [x] **`assets/` folder** — SVG source + PNG derivatives + build script
- [ ] **Social preview** (1280×640 for GitHub Settings → Social preview)
- [ ] **Repo topics** on GitHub (`fitz-lang`, `liveview`, `websocket`,
      `server-rendered`, `real-time`, `reactive-ui`, `no-build`, `native-binary`)

## Phase 1 — Templates and stateless components 🎨

The foundation: build HTML from Fitz.

- [x] `Html` opaque type (`type Html { raw: Str }` — tree postponed to Phase 2)
- [x] `html(raw: Str) -> Html` constructor
- [x] `raw_html(s: Str) -> Html` alias for explicit "unsafe intent"
- [x] `flv(s: Str) -> Str` — escape user data (branded name for
      "fitz-liveviews escape")
- [x] String interpolation `{expr}` inside templates (reuses Fitz's native)
- [x] Component composition via `fn` params of type `Html`
- [x] Composition helpers: `h_join`, `h_when`, `h_either`
- [x] Convention-based XSS-safety (manual `flv()` for user data —
      auto-escaping via lint rule in Phase 6)
- [x] Unit tests via `@test` (15 tests in `src/lib.fitz`)
- [x] Documentation: `docs/html.md` with API + XSS convention + example
- [ ] Runnable example `examples/hello-html/` — deferred to Phase 2, when
      `@live` and HTTP integration land

**Deferred to Phase 3** (proven pattern first, template engine later):

- Template control flow `{#for x in xs}...{/for}`, `{#if cond}...{/if}` —
  the `h_*` helpers cover the same ground with slightly more boilerplate

## Phase 2 — LiveView core (MVP) 🚀

Server + WS + JS client end-to-end.

- [x] Explicit `@get(...)` + `@ws(...)` pattern (native Fitz decorators;
      language-level `@live` deferred to Phase 6+)
- [x] `LiveFrame` type — envelope used by WS in both directions
- [x] `live_layout(ws_path, root_id, initial)` — wraps initial HTML with
      the client `<script>`
- [x] `html_response(h)` — wraps `Html` with `Content-Type: text/html`
- [x] Initial HTML render on HTTP GET (SEO-friendly first paint)
- [x] Embedded vanilla JS client (~30 LoC, injected inline)
- [x] Client → server event protocol over WebSocket (JSON `LiveFrame`)
- [x] Server → client patch protocol (JSON `LiveFrame` with `html`)
- [x] Example: **counter** (`examples/counter/`) — verified with
      `fitz run` + `curl` (HTML+content-type OK) + manual browser test
- [x] `docs/live.md` with the API, design decisions, and walkthrough

**Deferred to Phase 3** (proven pattern first, engine later):

- Server-side HTML diff engine → patch list (full replace works for MVP)
- Template control flow `{#for}`, `{#if}` (see Phase 1 deferral)
- Forms with `data-flv-submit` and typed form data
- Broadcast to multiple clients of the same LiveView

**Milestone reached: it works end-to-end.** First blog post draft "It works"
lives internally for now.

## Phase 3a — Forms + broadcast + shared state 📦

The "wow moment" of LiveViews — multi-user real-time.

- [x] Forms via `data-flv-submit` (client packages named inputs into
      payload map, prevents default reload)
- [x] Broadcast via `ws.broadcast(msg)` — sends to every client of the
      endpoint (Phoenix / Socket.IO convention: sender included)
- [x] Shared state pattern: top-level `let` wrapped in `Arc<Mutex>` by
      Fitz's F17. Documented in `docs/live.md`.
- [x] Example: **multi-user chat** (`examples/chat/`) — verified
      end-to-end with two browser windows

## Phase 3b showcase — collaborative Kanban ⭐ (2026-07-12)

The flagship demo of Fitz LiveViews. Three-column kanban board with
card create/move/delete, broadcast to every connected client, DOM
state preserved across every render, responsive from 320px up.
Built without Phase 4 LiveComponents intentionally — makes the
motivation for that phase clear from real code.

- [x] `data-flv-value-*` convention — click / submit events auto-
      serialize `data-flv-value-<key>="<val>"` attributes into the
      event payload map (Phoenix-style `phx-value-*`)
- [x] `live_layout` upgraded to emit a full HTML5 document with
      `<meta viewport>` and doctype (breaking change from fragment
      output; test coverage confirms all 61 tests still green)
- [x] `examples/kanban/` — types, shared state, 4 handlers, CSS
      in its own escaped constant, docs walk-through
- [x] Responsive by design: grid on desktop, stacked on mobile
      (memory rule: fitz-liveviews UIs are always responsive)
- [x] VSCode extension v0.2.0 — grammar recognizes
      `data-flv-value-*`, snippet `btnvalue` for value payloads

## Phase 3b — Server-side diff engine 🔬

Compact patches over the wire, DOM state preserved on the client.

- [x] Minimal HTML parser in Fitz (`parse_html`) — supports our
      template subset; ~200 LoC + 15 tests
- [x] Node tree types (`type Node { kind, tag, attrs, children, text }`,
      `type Attr { name, value }`)
- [x] Tree diff algorithm (`diff_html(old_str, new_str)`) with 6 patch
      ops: `text`, `replace`, `append`, `remove`, `set_attr`,
      `remove_attr`; ~200 LoC + 16 tests
- [x] `type Patch { op, path, content, name }` — single-type
      discriminator (no unions in Fitz)
- [x] `LiveFrame` extended with `patches: List<Patch> = []`
- [x] Client JS grows a DOM walker + `applyPatches` (~40 LoC of JS);
      tries patches first, falls back to `html` outerHTML replace on
      error or absence
- [x] Counter and chat examples updated to send patches; verified
      end-to-end via curl + browser
- [x] `docs/live.md` gains the "Phase 3b additions" section (patch
      protocol, patch ops table, canonical handler pattern, parser
      scope, race caveat)

## Phase 3c — Real-world polish 📦

- [ ] Template control flow `{#for x in xs}...{/for}`,
      `{#if cond}...{/if}` — needs a mini template engine
- [ ] `data-flv-input`, `data-flv-change`, `data-flv-keydown` handlers
- [ ] Debouncing configuration on inputs (client-side)
- [x] **Keyed diffing** (v0.16.0) — `diff_html` matches list children by
      `data-flv-key` (LCS reconciliation) instead of by position, emitting
      `insert_keyed`/`move_keyed`/`remove_keyed` + by-key content patches. A
      mid-list insert/remove is now one structural patch, robust on the client.
      Backward-compatible (unkeyed levels stay positional). The Admin ABM's
      expand-row went 72 → 3 patches. Opt-in today via an explicit
      `data-flv-key` attribute on list items.
- [x] **Sugar**: `{#for x in xs key=x.id}` in the SSR template DSL (Fitz core
      v0.29.1) — the `key=<expr>` clause desugars in `expand` to a
      `data-flv-key="{<expr>}"` interpolation attr on the loop body's single
      root element, which the keyed engine above consumes. The key expr is
      scoped with the loop var, type-checked, and byte-for-byte for keyless
      `{#for}`. WASM target sets it as a plain DOM attr (parity). Validated
      `fitz run` ↔ native binary (identical `<li data-flv-key="...">`).
- [ ] Auth integration (`@authenticated @live(...)`, user injected)
- [ ] `@on_mount` and `@on_disconnect` lifecycle hooks
- [ ] `@every(N secs)` for server-pushed periodic updates
- [ ] Version-numbered patches to detect out-of-sync clients (currently
      silent fallback to `html`)

## Phase 4 — Stateful components (LiveComponents) 🧩 (Session 3 landed 2026-07-12)

Per-instance state without hoisting everything to the parent.

- [x] `@live_component(name)`, `@render_for(name)` and `@on(name, event)`
      decorators in Fitz core (Sessions 1.a + 1.b — checker validates
      shape and registers metadata; runtime wiring is explicit for now)
- [x] `fitz new my-app --template liveviews` template CLI (Session 1.c)
      scaffolds a working starter from `templates/basic/`
- [x] `flv_register(name, initial_state, render_fn, event_handlers)` —
      register a component at boot
- [x] `component(name, id) -> Html` — embed an instance in a parent
      template; injects `data-flv-component-name` + `data-flv-value-instance_id`
- [x] `dispatch_component_events(frame) -> Bool` — route a `LiveFrame`
      to the matching component + event handler; auto-seeds state
      from `initial_state` on the first hit so an event arriving
      before the parent's render does not crash
- [x] Per-instance state store keyed by `(component_name, instance_id)`
- [x] Client runtime walks up to the enclosing component wrapper so
      `<button data-flv-click="save">` inside a component gets
      `component_name` + `instance_id` in its payload automatically
- [x] `examples/kanban/` refactored to use `@live_component("card_editor")`
      for per-card inline title editing (Session 3, 2026-07-12)
- [x] `examples/dashboard/` — grid of live `metric_tile` components,
      six independent instances, zero parent event branches (Session 3,
      2026-07-12)
- [x] Full component walkthrough in `docs/components.md` covering the
      three decorators, the three framework builtins, the canonical
      `@ws` loop, state isolation, component ↔ parent cooperation,
      and gradual-typing gotchas (Session 3)
- [x] VSCode extension v0.3.2 with `livecomp` / `renderfor` / `onevent`
      / `flvcomp` / `dispatchcomp` snippets (Session 2 introduced,
      Session 3 refined, v0.3.2 adds `data-flv-component-name` to the
      grammar so component wrappers get the LiveViews-directive
      highlight)
- [x] Codegen pass: turn `@live_component` + `@render_for` + `@on`
      into an implicit registration and remove the explicit
      `flv_register(...)` call (Fitz core Phase 5, v0.20.1+). The
      compiler walks the metadata that `resolve_program` persisted in
      `TypeEnv` and appends one synthetic `flv_register(...)` call per
      component to the top-level `program`, after checking and before
      eval/codegen. `examples/kanban/` and `examples/dashboard/`
      dropped the manual boot call. Public API stays the same:
      manual calls still work and take precedence over the implicit
      injection.
- [x] Per-instance init payload — **done in v0.11.0 (2026-07-24)** as
      `component_with(name, id, initial)`: like `component(name, id)`
      but the FIRST render of the instance seeds the state store with
      `initial` instead of the registry-wide `initial_state`. Powers
      the per-connection instance pattern of the Admin ABM (uuid per
      socket + connection-scoped seed data such as the locale).
- [ ] `dispatch_to_all(name, event, payload)` for bulk actions across
      every live instance of a component

## Phase 5 — Docs site + CI/CD 🌟

- [x] MkDocs Material config (`mkdocs.yml`) with Fitz orange palette
- [x] Home page (`docs/index.md`) — hero + pitch + comparison table +
      quick start
- [x] `docs/html.md` and `docs/live.md` — the two API guides
- [x] `docs/examples/counter.md` and `docs/examples/chat.md` with the
      source embedded via `pymdownx.snippets`
- [x] `.github/workflows/ci.yml` — runs `fitz test` on every push/PR
      and verifies both examples compile (cached Fitz binary keeps
      the loop fast)
- [x] `.github/workflows/docs.yml` — builds MkDocs and deploys to
      GitHub Pages on every push touching `docs/`, `mkdocs.yml`,
      `README.md`, or example sources
- [x] `.github/workflows/release.yml` — packages the VSCode `.vsix`
      on every `v*.*.*` tag and attaches it to the GitHub Release
- [x] CI status badge in the README
- [x] **Deploy guide** (`docs/deploy.md`) — production patterns for apps built
      with fitz-liveviews: standalone binary from `fitz build`, Dockerfile
      multi-stage → distroless (~30 MB image) via `fitz docker init`, reverse
      proxy configs (nginx / Traefik / Caddy) with WebSocket upgrade + TLS
      termination, systemd unit example, sticky sessions for horizontal scale,
      health/readiness endpoints via auto-mounted `/healthz`. Verified against
      the counter example.
- [ ] CSS scoping (BEM convention or scoped `<style>` tag support)
- [ ] Client-side directive escape hatches (dropdowns, tooltips)
- [ ] Blog post ES + EN — launch narrative
- [ ] Public release + Show HN

## Phase 6 — VSCode extension 🎯

- [x] Bundled at `editors/vscode/` inside this repo (Fitz core did the
      same — one repo, easier ecosystem release)
- [x] `package.json` with `extensionDependencies` on
      `thegreekman76.fitz-language`, snippets + injection grammar
      contributions
- [x] HTML injection grammar inside `string.quoted.triple.fitz` scope
      — tag names, attributes, entities, comments all get proper
      HTML scopes; Fitz's `{expr}` interpolation stays intact
- [x] Fitz LiveViews directives (`data-flv-click`, `data-flv-submit`,
      `data-flv-input`, `data-flv-change`, `data-flv-keydown`,
      `data-flv-clear`, `data-flv-ws`, `data-flv-root`) get a
      distinct highlight
- [x] Snippets: `liveview`, `render`, `get`, `ws`, `broadcast`,
      `flv`, `hwhen`, `heither`, `hjoin`, `btnclick`, `flvform`
- [x] `.vsix` packages cleanly with `@vscode/vsce package` (verified
      locally at 15.76 KB)
- [ ] LSP-level autocomplete inside templates (state fields,
      event handler names)
- [ ] Emmet expansion inside `html("""...""")`
- [ ] Hover on component function references
- [ ] Diagnostics: unclosed tags, unknown handlers
- [ ] Publish to VSCode Marketplace (manual step — requires publisher
      account and PAT)

## Phase 8 — SFC Migration to `.fitzv` (Fitz v0.21.0+) 🎨 CERRADA ENTERA 2026-07-16 (v0.4.3)

**Trigger**: Fitz core shipped Phase 11 (native frontend `.fitzv`
compilado a WASM + SSR emitter for fitz-liveviews) en v0.21.0
(2026-07-16). fitz-liveviews es el primer consumidor real de
`.fitzv` SFC syntax. Migrar los 4 examples es el dogfooding que
valida Phase 11 end-to-end y surface bugs reales (el patrón §9.aa
event-body widening apareció al preparar chat/kanban migrations —
la migración empírica descubre corners del walker que el
self-audit no ve).

**Cierre resumen (2026-07-16)**: 8.1 → 8.6 CERRADAS en el día,
todas en la misma sesión post Fitz core v0.21.0 shipping. Los 6
gaps del view pipeline (V-1 a V-6) que la chat migration probe
surface fueron cerrados EN EL MISMO DÍA en Fitz core (§9.cc + §9.dd
+ §9.ee) — feedback loop de horas en vez de semanas. Chat + kanban
partial migrations shipped. K-1/K-2/K-3 framework gaps
documentados en Fitz core para Phase 11.7+. Formal 8.7 closure
con bump v0.4.3 sync-point (marca "post-Fitz-v0.21.0" en el
manifest paralelo al precedente v0.4.2 docs-only lockstep).

**Post-Phase-8 closure (2026-07-16, v0.5.0)**: K-1 + K-2 framework
gaps CERRADAS en fitz-liveviews (`dispatch_to` + `component_state`
+ `set_component_state` — first NEW public API desde v0.4.0). El
canonical child → parent dispatch pattern está PROVEN via
`k12_canonical_child_dispatches_to_parent_via_dispatch_to` test.
Unblocks full `Board.fitzv` kanban migration (from Phase 8.5
partial) — deferido a follow-up commit que consume `dispatch_to`.
K-3 compound props sigue ABIERTA en Fitz core view emitter (~80
LoC, low priority — no bloquea kanban's Board.fitzv). Lib API
count: 3 nuevas fns públicas; 83 lib tests (+13 vs v0.4.3).

**Phases 7, 8, 9 numbering**: Phase 7 sigue como "Beyond MVP
deferred backlog". Phase 8 + Phase 9 son concrete-next-work
post-Fitz-v0.21.0 shipping, temporalmente adelante de Phase 7.

- [ ] **8.1** Bump Fitz core dep `0.20.1 → 0.21.0` en `fitz.toml`
      + smoke `fitz check` sobre lib. Verificar que `.fitzv` loader
      (Phase 11.6.d) resuelve transparente y auto-inject (Phase
      11.6.e §9.bb) elimina `flv_register(...)` manual.
- [ ] **8.2** Land **counter migration** — draft ya aplicada
      uncommitted desde §9.z. Files:
      `examples/counter/src/Counter.fitzv` (nuevo) + rewritten
      `examples/counter/src/main.fitz` (drop manual
      `flv_register(...)` — auto-inject Phase 11.6.e §9.bb) +
      updated `examples/counter/README.md`. Trivial commit + push,
      ~5 min.
- [ ] **8.3** **Migrate dashboard** — extract
      `examples/dashboard/src/MetricTile.fitzv` (single-file
      component per metric tile) + rewrite `main.fitz` con
      `from MetricTile import MetricTile, MetricTile_render,
      MetricTile_<events>` (canonical shape §9.bb). Auto-inject
      removes manual `flv_register(...)`. Probable clean migration
      (dashboard sigue el mismo shape que counter).
- [x] **8.4** **Migrate chat — CERRADA 2026-07-16 (post Fitz core
      §9.cc + §9.dd + §9.ee).** El chat migration probe original
      surface 5 blockers concretos del view pipeline (V-1 HTML
      comments, V-2 bare boolean attrs, V-3 cross-file nominals en
      state, V-4 `payload` en checker scope, V-5 cross-file
      nominals en struct literals) + V-6 probable (`.push()` bare
      expr stmt en shadow-local event body). Los 6 blockers fueron
      cerrados en la misma sesión (Fitz core `docs/deudas-post-
      5b.md` sección "View pipeline gaps — CERRADAS ENTERAS
      2026-07-16"): §9.cc (V-4 + V-6, ~70 LoC), §9.ee (V-1 + V-2,
      ~80 LoC + tests), §9.dd (V-3 + V-5 via `from X import Y`
      syntax en `.fitzv`, ~500 LoC + 19 tests). **Chat migration
      shipped**: `examples/chat/src/message.fitz` (5 LoC, `type
      Message`), `examples/chat/src/ChatRoom.fitzv` (40 LoC SFC
      con state + event con nested payload guards + template con
      `{#for m in messages}` + submit form), rewritten `main.fitz`
      (50 LoC — imports + HTTP GET + WS handler con zero event
      branches vía `dispatch_component_events`). Total LoC per
      concern DIVIDIDO (domain logic en `.fitzv`, wiring en
      `main.fitz`, shared type en `message.fitz`) vs pre-
      migration monolithic 115 LoC en `main.fitz`. Smoke real
      end-to-end verde: `fitz check` + `fitz run` + `curl / →
      200` con `data-flv-component-name="ChatRoom"` +
      `data-flv-submit="send_message"` + `<h1>Fitz LiveViews
      Chat</h1>` en HTML. Patterns emergentes catalogados en
      `docs/components-candidates.md` (Input canonical shape,
      MessageList/MessageBubble chat-specific, Form as bare
      `<form>`).
- [x] **8.5** **Migrate kanban — CERRADA PARCIAL 2026-07-16.**
      Chat migration (Phase 8.4) probó que el shared-state pattern
      SÍ puede migrarse full-SFC post §9.cc/§9.dd/§9.ee. Kanban
      tiene una complicación adicional: CardEditor's `save` event
      propaga a Board's cards state — full `Board.fitzv` migration
      necesita event bubbling entre componentes (Phase 11.7+
      scope). **Migración shipped**: `card.fitz` sibling (shared
      types Card + Board), `CardEditor.fitzv` SFC (extraído
      del inline `@live_component` en `main.fitz`, ~50 LoC con
      state + 3 events + template con `{#if}{#else}{/if}`
      toggle), rewritten `main.fitz` (~320 LoC vs 466 pre-migration
      = 146 LoC reduction; board state + render fns + WS handler
      quedan en classic Fitz). Smoke real end-to-end verde:
      `fitz check` cero errors + `fitz run` boot + `curl / →
      200` (8104 bytes) con 3 columns + create form + `<h1>Fitz
      LiveViews Kanban</h1>`. Full `Board.fitzv` migration
      DIFERIDA hasta Phase 11.7+ (event bubbling framework
      support). Patterns emergentes catalogados en
      `docs/components-candidates.md`.
- [ ] **8.6** **Pattern extraction** — durante 8.3-8.5, cataloguar
      en `docs/components-candidates.md` los patterns comunes que
      emergen (Button, Card, Modal, Input, MetricStat,
      MessageBubble, KanbanColumn). Input directo para Phase 9.A.
- [x] **8.7** **Cierre formal Phase 8 CERRADA (2026-07-16)** —
      CHANGELOG entry `[v0.4.3]` aggregating all Phase 8 sub-
      tasks. Migration es 100% **examples + docs**; la API pública
      de `src/lib.fitz` (1700 LoC) queda **intacta** — nada del
      lib code cambia con la SFC migration, sólo la forma en que
      los 4 examples ejercitan la misma API. README refreshed con
      `.fitzv` migration note + Fitz core v0.21.0+ requirement.
      VSCode extension sin cambios de grammar/snippets (snippets
      `livecomp` YA son SFC-ready desde v0.4.2) pero bumped a
      v0.4.3 en lockstep con el manifest. **Bump decidido: v0.4.2
      → v0.4.3** patch sync-point (paralelo al precedente v0.4.2
      docs-only). `.vsix` regenerado.

**Deudas residuales esperadas** (surface durante las 4 migrations;
se convertirán en §9.cc / §9.dd de Phase 11.6.e en Fitz core si son
bloqueantes):

- Cross-file `<Child />` composition (§9.y debt — probable trigger
  real cuando dashboard tenga MetricTile importado desde archivo
  hermano usado en template).
- Event bubbling entre componentes (dashboard: click en MetricTile
  propaga a Board? kanban: click en Card propaga a Column?).
- Client-side dynamic capabilities (kanban drag-drop confirma
  Phase 11.7 scope).
- Persistent child state (chat: `MessageInput` retains draft
  mientras se navega — hoy pierde en re-renders).

## Phase 8.9 — Flagship showcase: Admin ABM ⭐ (✅ BUILT — S1-S10)

The flagship demo for the public launch (goal: visibility / GitHub
stars). A complete backend **admin panel** — login, dashboard,
collapsible menu, theme switch, and a rich **ABM/CRUD** (data grid +
forms) over a **RRHH + Accesos** (People & Access) domain — built on
PostgreSQL, dockerized, server-rendered with LiveViews.

Not just a fitz-liveviews demo: it exercises the **entire Fitz stack**
in one recognizable app (ORM + Postgres + Docker + HTTP + WS +
`Response { body_bytes }` export + auth + `.fitzv`), and it is the
engine that lifts Phase 9's component shortlist from 8 basics to
~22-25 real components (DataGrid, TreeView, CascadeSelect, Modal, …).

- **Scope**: SSR-first. Heavy interactions (drag-to-group, fluid tree,
  chip multiselect) work via server round-trips today; buttery
  client-side versions land as Fitz core Phase 11.7 (WASM) matures.
- **Responsive**: hard requirement — every component tested at 320px.
- **Domain**: Empleados (star grid) + Departamentos / Roles-Permisos /
  Ubicaciones / Organigrama / Skills as support entities that feed the
  cascade / tree / group-checkbox / multiselect components.
- **Grid**: pagination · sort/multisort · filters · search · row
  actions · delete-with-confirm · selection · multi-delete · export ·
  column grouping.
- **Forms**: select · cascade select · checkbox · group select · group
  checkbox · multiselect · tree view.
- **Slices** (each deployable): S1 login + shell + theme + dashboard ·
  S2 read-only grid · S3 filters/sort/search/pagination · S4 rich
  forms · S5 selection/multi-delete/export · S6 grouping + tree.
- **Dogfooding**: expected to surface Fitz core gaps (same mechanism as
  the chat/kanban migrations that pushed §9.cc/dd/ee in a day) → each
  becomes a core fix or documented debt.

Full detail in [`docs/showcase-admin-abm-plan.md`](docs/showcase-admin-abm-plan.md).

> **✅ BUILT — slices S1-S10 (2026-07-22 →).** The full app lives in
> `examples/admin/` (login with Argon2id + JWT cookie, dashboard with real
> Postgres counts, responsive shell, i18n ES/EN, dockerized). Shipped slice
> by slice: S1 login+shell+theme+dashboard · S2 live DataGrid (v0.6.0) · S3
> filters/sort/search/pagination · S4 rich forms + cascade + permissions
> (v0.7.0/v0.8.0) · S5 selection/multi-delete/CSV export · S6 grouping + tree
> · S7-S8 component completion (chart, expandable rows, tabs, stepper, nested
> menu, tooltip, rating, …) · S9 i18n (lib v0.10.0 `__flv_init`) · S10 refactor
> to per-connection LiveComponents (lib v0.11.0 `component_with`). It became
> the extraction engine for the whole Companion UI library below and now
> consumes it, validated bit-for-bit `fitz run` ↔ native binary. The slice
> plan below is kept as the design record.

> **✅ Companion UI adoption + dogfooding (2026-07-29, v0.15.0).** The
> employee form adopted the packaged primitives — `Input` (nombre / email /
> cargo / fecha), `Alert` (validation banner) and `Button` (save / finish /
> cancel) — themed through the `--flv-*` tokens aliased to the admin palette,
> verified **bit-for-bit `fitz run` ↔ native binary** against Postgres. The
> **grid stays raw on purpose**: its row buttons render N times per live frame,
> where a primitive's inline scoped `<style>` would duplicate on every row (the
> same reason `EmpleadoRow` carries no scoped styles). To let `Button` cover
> row-action buttons it grew `icon` / `value` / `tooltip` / `aria_label` props
> (v0.15.0 — still shipped for once-per-frame use).

## Keyed diffing ⭐ — LANDED v0.16.0

Dogfooding the Admin ABM (2026-07-29) surfaced the **single highest-leverage
quality gap** for the live-grid UX. Expanding a grid row (inserting a
`<tr class="detail-row">` mid-tbody) **intermittently failed to apply in the
browser**. Root cause: `diff_html` (Phase 3b) was **positional / keyless**, so a
mid-list insertion shifted every following sibling and the diff emitted a large,
fragile patch set — measured **72 patches for one row toggle** — instead of
"insert one row". The server was always correct and deterministic; the fragility
was entirely in applying shifted positional patches on the client.

**Fixed in v0.16.0** with keyed reconciliation (Phoenix LiveView's keyed
comprehensions): when a list's children all carry `data-flv-key`, `diff_html`
matches them by key (LCS), emits `insert_keyed`/`move_keyed`/`remove_keyed` +
by-key content patches, and ignores inter-item whitespace. The Admin ABM's
expand-row toggle went **72 → 3 patches**, applying deterministically (verified
by replaying the real client `applyPatches` in jsdom across an accumulating
expand/collapse/sort/filter sequence, and by `fitz run` ↔ binary byte parity on
the WS smoke). Backward-compatible: unkeyed levels keep the positional diff.

**Shipped in Fitz core v0.29.1** — the ergonomic sugar `{#for x in xs key=x.id}`
in the SSR template DSL (desugars to `data-flv-key="{<expr>}"` on the loop body's
root element; the engine already consumes it). Keyed diffing is no longer opt-in
via a hand-written attribute.

> **The sugar does NOT fit the Admin grid — and that's correct (v0.16.x
> follow-up, 2026-07-30).** The live grid's `<tbody>` is built imperatively in
> classic Fitz (`empleados.fitz`: `for e in rows { body_str += empleado_row_render(...).raw }`),
> not as a `.fitzv` `{#for}`, for three reasons the sugar can't work around:
> (1) the rows are the `EmpleadoRow` **component**, and `<Child />` inside `{#for}`
> is WASM-only in SSR (Fitz core Phase 11.7); (2) the sugar requires the loop body
> to have **exactly one root element per iteration**, but the grid interleaves a
> second `<tr class="detail-row">` on expand and adds `<tr class="grp-row">`
> headers in grouped mode; (3) keyed diffing is **already active** — `EmpleadoRow`
> carries `data-flv-key="emp-{id}"` on its single `<tr>` root, which is exactly
> what the sugar emits. Forcing the sugar would mean inlining the row markup and
> dropping the `EmpleadoRow` extraction — a regression. So the grid keeps its
> hand-written keys; the sugar remains the right tool for **inline** single-element
> lists in a `.fitzv` template (none in the Admin ABM today: `GridFilters`'
> `{#for d in deptos}` body is an `{#if}/{#else}` pair, not a single root, and
> pills don't reorder).
>
> **Grouped mode is now keyed too (2026-07-30).** `group_section`'s header row
> gained `data-flv-key="grp-{key}"` and the empty-state row gained
> `data-flv-key="grid-empty"`, so every `<tbody>` level (flat, grouped, empty) is
> fully keyed — a mixed keyed/unkeyed level previously fell back to a positional
> diff. **Durable regression coverage**: `src/lib.fitz` gained 7 `@test` against
> the real `diff_html` engine (`keyed_grid_*`) proving alta→`insert_keyed`,
> delete→`remove_keyed`, sort→`move_keyed`, filter→`remove_keyed`, content edits
> addressed by key, expand-detail as one keyed insert, and the grouped-headers
> level staying keyed — none falling back to a positional cascade. These replace
> the one-off jsdom replay with in-repo `fitz test` coverage.

**Secondary reliability debts still to schedule (deferred)**: reconnect with
state replay, backpressure on the outbox, and multi-instance coordination.

## Phase 9 — Companion UI library 🧩 (✅ COMPLETE — Sessions A-H, v0.24.0)

**Trigger**: post-migrations completas de Phase 8 **+ the Admin ABM
flagship showcase (Phase 8.9)**. Emergent de los patterns extraídos en
8.6 y del showcase, no diseñado en vacuum. Building una UI kit **AS**
los examples se refactorizan produce APIs validadas contra código real,
no bloat especulativo. The Admin ABM redefines this shortlist upward:
from the original 8 basics to ~22-25 (adds DataGrid, TreeView,
CascadeSelect, MultiSelect, Modal, ConfirmDialog, Toast, AppShell,
Sidebar, etc).

**Racional**: todo framework serio de UI real-time tiene una
companion (Vuetify/Vue, MUI/React, chakra/solid). Ninguno debería
roll-your-own CSS para el 90% del caso (Button/Card/Modal). Alinea
con la filosofía "un lenguaje con HTTP + DB + auth + WS + jobs +
**UI kit** ciudadanos primera" del stack Fitz.

**Anti-goal**: NO ser Vuetify-completo con 40+ componentes. MVP
recortado, foco y disciplina. Full kit crece por PR con demand
real, no por completeness.

> **✅ Cut 1 shipped — v0.12.0 (2026-07-28).** Rather than start with the 8
> generic primitives (9.B), the first cut generalized the **3 most reusable
> components already proven in the Admin ABM** — **Pager**, **Toast**,
> **ConfirmDialog** — plus the **theme** (`--flv-*` tokens, light/dark) into the
> importable sub-package `fitz_liveviews.ui.*`, imported by dotted sub-path
> (enabled by Fitz core v0.29.0). Design decisions locked from 9.A: **direction
> A** (custom minimalist / Radix-neutral, `--flv-*` re-themable) and
> **placement** as a sub-package imported by dotted sub-path (a re-export from
> `lib.fitz` isn't possible — it cycles, because the component depends on the
> framework). The Admin ABM now consumes them (−203 LoC), aliasing `--flv-*` to
> its own tokens. Shipped alongside: docs (`docs/ui-components.md` §Packaged
> components), tests (`examples/ui-gallery/tests/components_test.fitz`, 12
> `@test`) and 8 VSCode snippets. **Cut 2** = the 8 generic primitives below
> (9.B).

> **✅ Cut 2 shipped — v0.13.0 (2026-07-28).** The **8 generic primitives (9.B)** —
> **Button**, **Card**, **Badge**, **Alert**, **Input**, **Spinner**, **Icon** and
> **Modal** — land in `fitz_liveviews.ui.*`, same dotted-sub-path style, same
> direction A / `--flv-*` re-themable tokens. Seven are pure presentational / SSR
> render fns; **Modal** is stateful per-connection (like ConfirmDialog). Shipped in
> two tandas of 4 with docs (`docs/ui-components.md`), 26 new `@test` (128 total in
> the gallery) and 10 VSCode snippets; the theme gained a `--flv-color-warning`
> token. **Deferred from the 9.B spec** (render-fn / SSR model): icon slots on
> Button/Card/Input (compose `icon(...)` in the host instead), Modal focus-trap +
> ESC-to-close (need client JS the SSR path doesn't inject); the token layer stays
> `ui_theme()` rather than separate `themes/*.css` files.
>
> **✅ Partially closed — v0.15.0 (2026-07-29).** **Button** gained an `icon` slot
> (+ `value` click payload, `tooltip`, `aria_label`), so it can replace the raw
> `btn-icon` row-action buttons of a real admin grid — motivated by adopting the
> companion UI across the Admin ABM showcase. Card and Input still compose
> `icon(...)` in the host; Modal focus-trap / ESC and the `themes/*.css` split remain
> deferred.
>
> **✅ Phase 9 COMPLETE — Sessions A-H, lib v0.24.0 (2026-07-30).** After
> Cut 1 / Cut 2 / 9.C, the rest of the shortlist shipped one release per
> session, each extracted from the Admin ABM + adopted + `fitz run` ↔ binary
> parity: **Shell** family (Breadcrumbs v0.17, ThemeToggle v0.18, Sidebar +
> Topbar + AppShell v0.19); **Dashboard** (StatCard / BarChart / ProgressBar
> v0.20); **DataGrid** (DataGrid / SortableHeader / GridToolbar / GridFilters
> v0.21); **Forms inputs** (Textarea / Select / Checkbox / CheckboxGroup /
> RadioGroup / Rating / DatePicker v0.22); **Forms composite** (FormLayout /
> FormRow / GroupSelect / MultiSelect / Tabs / Stepper / TreeView v0.23);
> **Feedback** (Chip / CountBadge / Tooltip / Divider / ExpansionPanel v0.24).
> **~40 components + 11 helper/theme modules** in `src/ui/*`; gallery `@test`
> 227. The 9.A/9.B checklist below is the original plan — kept as record.
> Remaining Phase-9-adjacent work: the **dual-target SSR→WASM** client build
> (CW.7/CW.9 — a platform-surface expansion, blocked by the Fitz core wasm
> envelope), not the SSR library itself.

- [ ] **9.A** **Extract & design decisions** (~1 sesión, docs-only):
    - Consolidar `docs/components-candidates.md` (poblado en 8.6)
      en el shortlist final de **8 componentes MVP**: `Button` /
      `Card` / `Input` / `Modal` / `Alert` / `Badge` / `Spinner` /
      `Icon`. Rationale por cada uno + APIs previstos.
    - **Design system decision** — pick 1 dirección visual y
      committear:
        - Opción A: **Custom minimalist** (Radix-style neutral
          primitives, sin opinion aesthetic, easy de tematizar por
          user).
        - Opción B: **Vuetify-inspired Material** (familiar para
          Vue users, opinionated pero probado).
        - Opción C: **DaisyUI-inspired utility** (Tailwind-
          adjacent, pequeño footprint, tokens semánticos).
    - **Theme system**: light + dark via CSS custom properties
      (`--flv-color-primary`, `--flv-color-bg`, `--flv-radius`,
      etc.). Toggle via `data-theme="dark"` en root. Runtime
      switching sin recompilar CSS.
    - **Responsive commitment** (feedback rule): mobile-first, sin
      fixed widths, testeado a 320px viewport meta obligatorio.
    - **Client-side interactivity limits**: MVP con SSR + limited
      interactivity (Modal focus trap, Input debounce). Full
      keyboard nav + advanced patterns bumpean contra Phase 11.7
      (Fitz core client-side dynamic capabilities). Documentar
      honesto qué anda y qué no.
    - **Placement**: `fitz-liveviews-ui/` como **sub-package**
      (`fitz.toml` `[lib] entry = "src/lib.fitz"` con re-exports)
      o **path dep hermano** — decisión de packaging en 9.A.
    - Snippet `flv-uibtn`/`flv-uicard`/etc para VSCode extension.

- [x] **9.B** **Build MVP — 8 componentes + tema** — ✅ shipped v0.13.0 (see the Cut 2 callout above for what landed + what deferred):
    - `Button` — variants primary/secondary/danger/ghost, size
      sm/md/lg, disabled + loading states, icon slot.
    - `Card` — header/body/footer slots, elevation levels,
      clickable variant.
    - `Input` — text/email/password/number, label + hint + error
      prop, prefix/suffix icon slots, disabled state.
    - `Modal` — backdrop, close button, title slot, focus trap
      (client-side JS mínimo), ESC key close.
    - `Alert` — info/success/warn/danger variants, dismissible,
      icon + title + body.
    - `Badge` — count (number) or status (pill), color variants,
      size sm/md.
    - `Spinner` — 3 sizes, indeterminate (default) + progress
      (0-100), inline vs block.
    - `Icon` — SVG-based system, bake in 20-30 icons core (arrow,
      check, close, edit, trash, plus, minus, warning, info,
      success, download, upload, search, home, user, cog,
      dashboard, menu, chevrons).
    - Theme system files: `themes/default.css` (light) +
      `themes/dark.css` + tokens CSS.
    - Unit tests via `@test` para renderizado + state changes
      (~2-3 tests por componente).
    - `docs/components.md` reference API + ejemplos runnable.

> **✅ 9.C shipped — v0.14.0 (2026-07-28).** The four bundled examples
> (Counter / Dashboard / Chat / Kanban) now consume the packaged primitives
> instead of hand-rolled markup + CSS. Since the primitives are render fns (not
> `@click` child components as the sketch below imagined), each `on_click` names a
> fall-through event that routes to the component's `@on` handler — the primitive
> emits the same `data-flv-*` protocol the raw markup did. Adoption: **Counter** →
> `Button`; **Dashboard** → `Card`+`Icon`+`Badge`+`Button`; **Chat** →
> `Card`+`Input`+`Button`; **Kanban** → `Card`+`Icon`+`Input`+`Button`. Dogfooding
> surfaced (and fixed) two API gaps — `Button.submit` (form submit buttons) and
> `Input.required`/`clear`/`autocomplete` (live-form fields) — plus one Fitz-core
> SSR limitation (nested-brace struct literals don't round-trip in template
> interpolation, so primitives inside a `.fitzv` template are hoisted into helper
> fns). `Modal` is **deferred**: its natural fit (a per-card inline editor) is
> blocked by the `<Child />`-inside-`{#for}` limitation (Phase 11.7). LoC is
> roughly flat (the win is ~57 fewer CSS lines + theming/dark/a11y/XSS for free);
> the honest analysis lives in
> [`docs/companion-ui-benefits.md`](docs/companion-ui-benefits.md). Native-build
> parity holds for Counter/Dashboard/Chat; Kanban stays `fitz run`-only on a
> pre-existing `Board` module/type codegen collision (not a regression).

- [x] **9.C** **Refactor 4 examples usando la lib** — ✅ shipped v0.14.0 (see callout above):
    - Counter → usa `<Button variant="primary" @click="increment">
      +1</Button>` en vez de raw `<button>`.
    - Dashboard → MetricTile usa `<Card>` con `<Icon name="chart"/>`
      + `<Badge>` status.
    - Chat → MessageBubble usa `<Card variant="ghost">`,
      MessageInput usa `<Input>` + `<Button>`.
    - Kanban → BoardColumn usa `<Card>`, CardEditor usa `<Modal>`
      + `<Input>` + `<Button>`.
    - Medir LoC reduction pre/post refactor + documentar en
      `docs/companion-ui-benefits.md`.
    - **Version bump depende de la decisión de placement en 9.A**:
        - Si **sub-package** (nuevos módulos suman a `src/lib.fitz`
          current): bump minor del core lib a **v0.5.0** (nueva
          API superficie con los 8 componentes exportados).
        - Si **path dep hermano** (`fitz-liveviews-ui/` con su
          propio `fitz.toml` + `[lib]` sección independiente):
          fresh package version **v0.1.0** para el companion +
          core lib sin bump (queda en v0.4.2 o v0.4.3 según lo
          decidido en 8.7).

**Decisión pendiente que NO se cierra hasta 9.A**: aesthetic
direction (Opción A/B/C arriba). Documentado como debt residual
hasta que 9.A arranque.

### 9.D — Full Admin-ABM extraction (all remaining components, split across sessions)

The Admin ABM redefined the shortlist upward (8 → ~22-25). Cuts 1+2 (v0.12.0 /
v0.13.0) shipped 11 packaged primitives; **v0.15.x adds `Breadcrumbs`** (first
Shell-family piece). This is the committed plan to extract **everything left**,
one cohesive cluster per session. Each session follows the same recipe: design a
clean, ergonomic API (props consistent with `fitz_liveviews.ui.*`, `--flv-*`
tokens, `<style scoped>`, no gotchas) → package under `src/ui/` → adopt in the
Admin ABM (the validation, so APIs are proven against real code, not speculative)
→ gallery `@test` + `docs/ui-components.md` + a VSCode snippet → verify
`fitz check` + `fitz test` + `fitz build` (docker path) + a 320px visual pass.

**Already packaged (13):** Pager · Toast · ConfirmDialog · Modal · Button ·
Card · Badge · Alert · Input · Spinner · Icon · **Breadcrumbs** ✅ ·
**ThemeToggle** ✅.

- [x] **Session A — Shell family, part 1: `Breadcrumbs`** (v0.15.x, this
  session). Packaged `fitz_liveviews.ui.Breadcrumbs` + `shell_types.Crumb`
  (N-level, CSS separators, `href == ""` = current). Adopted in the admin
  (`render_breadcrumbs` → the component; `.crumb-bar` keeps the bar placement).
  4 gallery tests, docs, snippet. `fitz build` of the admin verified.
- [x] **Session B — Shell family, part 2: `ThemeToggle`** (v0.18.0). Packaged
  `fitz_liveviews.ui.ThemeToggle` (button, `id="flv-theme-btn"` +
  `onclick="flvCycleTheme()"`, no events — client-side per-browser theme) +
  `fitz_liveviews.ui.theme_scripts` (`theme_boot_script(storage_key)` anti-FOUC
  head script + `theme_cycle_script(storage_key, light, dark, auto)` cycle over
  `localStorage` + `data-theme`, generalized from the admin's `theme_init_js` /
  `flvCycleTheme`). Adopted in the admin topbar + `page_layout` / `login_layout`;
  `theme_init_js` removed, `interactive_js` trimmed to sidebar/drawer, dead
  `.theme-btn` CSS dropped. 3 gallery tests, docs, `ui-theme-toggle` snippet.
  `fitz check` + `fitz build` of the admin verified.
- [x] **Session C — Shell family, part 3: `Sidebar` + `Topbar` + `AppShell`**
  (the heavy one). Delivered all three:
  (a) nav data model `NavItem` / `NavGroup` in `shell_types.fitz` (a `NavGroup`
  with `label == ""` → flat links; a named group → native `<details>` that
  auto-opens on its active child);
  (b) `shell_css()` split — chrome (tokens + reset + `.sidebar` / `.topbar` /
  `.content` / drawer / collapse / responsive) moved into the packaged
  `ui_shell_css()` (exported from `AppShell`), while the admin keeps its
  screen-specific CSS in `admin_css()`;
  (c) `fitz_liveviews.ui.Sidebar` (`sidebar_render`), `fitz_liveviews.ui.Topbar`
  (`topbar_render` + `initials_of`), and `fitz_liveviews.ui.AppShell` (`app_shell`
  document layout + baked `ui_shell_css()` + `shell_behavior_script()` drawer/collapse
  JS). Kept as plain `.fitz` render helpers (the two-level nav loop + document
  assembly don't fit an SSR `.fitzv` template). Adopted in the admin: `page_layout`
  now composes the packaged pieces; `render_sidebar` / `render_topbar` /
  `interactive_js` / `nav_item` / `initials` removed; class names unchanged.
  12 gallery tests, docs, `ui-sidebar` / `ui-topbar` / `ui-appshell` snippets.
  `fitz check` + `fitz test` (170/170) + `fitz build` verified; rendered against a
  live server (login → dashboard / empleados / departamentos all 200, sidebar /
  topbar / crumbs / drawer / auto-open group / chrome + screen CSS all intact).
  **Pending: the human 320px browser eyeball.**
- [x] **Session D — Dashboard family** (v0.20.0): `StatCard` (label/value/hint/
  accent) · `BarChart` (CSS bars) · `ProgressBar` (determinate). All three are
  `.fitzv` SFCs with scoped styles (`accent` → `data-accent`, computed widths →
  inline `style="width: {pct}%"`). `fitz_liveviews.ui.chart_helpers` carries
  `type Bar` + `pct_of(value, max)` (guarded) + `bar_scale(bars)` (fills each
  `pct`, scaling to the busiest bar — the cross-item math an SSR template can't
  do, same split as Pager / `page_range`). Added a `--flv-shadow` token (aliased
  to `--shadow`) for the card elevation. Adopted in `dashboard.fitz`; the local
  `stat_card` / `bar_chart` / `progress_bar` helpers removed, `.stat-card*` /
  `.chart-*` / `.pbar-*` CSS moved out of `admin_css()` (`.stat-grid` / `.pbars`
  wrappers stay). 8 gallery tests (178 total), docs, `ui-statcard` / `ui-barchart`
  / `ui-progressbar` snippets. `fitz check` + `fitz test` + `fitz build` verified;
  live-server render confirmed (4 StatCards + 4-dept BarChart + 2 ProgressBars,
  old classes gone).
- [x] **Session E — DataGrid family** (v0.21.0): `DataGrid` (card + scroll +
  `<table>` shell + the `data-label` → mobile-cards `@media`, reaching host rows
  via scoped descendant *element* selectors) · `SortableHeader` (clickable `<th>`
  firing `sort` + ▲/▼ arrow) · `GridToolbar` (generalized: search `<form>` + a
  raw `actions` slot; the estado pills + CSV export are gone from the component)
  · `GridFilters` (generalized: a data-driven `List<Pill>` bar — one instance per
  dimension, distinct-event or shared-event+`value` shapes). `grid_helpers`
  carries `type Pill { label, event, value, active }` + `sort_arrow(...)`. The
  app-local `GridToolbar.fitzv` / `GridFilters.fitzv` + the local `sort_th`
  helpers deleted; adopted in BOTH `empleados.fitz` and `departamentos.fitz`; the
  grid table/toolbar/pill/mobile CSS moved out of `admin_css()` (`.grid-card` /
  `.col-*` / `.btn-clear` stay — reused by the DB-error panel + forms + rows).
  `filter_depto` now reads `payload["value"]`. 18 gallery tests (192 total), docs,
  `ui-datagrid` / `ui-sortheader` / `ui-gridtoolbar` / `ui-gridfilters` snippets.
  `fitz check` + `fitz test` + `fitz build` verified; live Postgres render + WS
  smoke (30 frames) + `fitz run` ↔ binary parity confirmed. (Pager already
  packaged; `EmpleadoRow` stays app-specific — it's the domain row. Selection /
  multi-delete + grouping *controls* stay app-specific too: they're tied to the
  domain events; the generic table shell + headers + toolbar + filter bar are
  what generalized.)
- [x] **Session F — Forms family, part 1 (inputs)** (v0.22.0): `Textarea` (labeled
  multi-line) · `Select` (labeled `<select>` over a `List<FieldOption>`, `on_change`
  for a cascade) · `Checkbox` (single) / `CheckboxGroup` (shared-`name` multi-select,
  `chips: true` for a `:has(input:checked)` pill list) · `RadioGroup` (exclusive
  radios) · `Rating` (0..max pure-CSS star input) · `DatePicker` (native
  `<input type=date>`). `form_input_helpers` carries `type FieldOption { label,
  value, on }` + `rating_stars(...)`. Adopted in `EmpleadoForm.fitzv` /
  `form_helpers.fitz` (notas / depto / estado / desempeño / skills / fecha); the
  local `depto_options` / `skills_html` / `rating_input` deleted; the radio / rating /
  skill-chip / inline-textarea CSS moved out of `admin_css()`. 15 gallery tests (207
  total), docs, `ui-textarea` / `ui-select` / `ui-checkbox` / `ui-checkboxgroup` /
  `ui-radiogroup` / `ui-rating` / `ui-datepicker` snippets. `fitz check` + `fitz test`
  + `fitz build` verified; live Postgres form render + WS smoke + `fitz run` ↔ binary
  parity confirmed. (Input already packaged. CascadeSelect / GroupSelect / the grouped
  permission matrix stay app-specific → Session G.)
- [x] **Session G — Forms family, part 2 (composite)** (v0.23.0): `FormLayout`
  (`<form data-flv-submit>` + card) · `FormRow` (labeled row / `cols` grid) ·
  `CascadeSelect` (= Select with `on_change`, adopted for país/prov/ciudad) ·
  `GroupSelect` (`<select>` with `<optgroup>`s) · `MultiSelect` (grouped
  `<fieldset>` checkbox matrix) · `Tabs` + `Stepper` (server-tracked section nav —
  Tabs renders the nav, panels stay host-managed; Stepper is a CSS-counter wizard
  indicator) · `TreeView` (an expandable hierarchy the host flattens into a
  depth-based `List<TreeNode>` — the SSR template can't recurse). `form_layout_helpers`
  carries `OptionGroup` / `Tab` / `Step` / `TreeNode` + `tree_arrow(...)`. Adopted in
  `form_helpers.fitz` / `EmpleadoForm.fitzv` (reporta / permisos / cascade / tabs /
  stepper) and `empleados.fitz` (the ubicaciones TreeView); the local
  `reporta_options` / `permisos_html` / `pais_options` / `tab_btn` / `step_dot` /
  `stepper_bar` / `tree_html` deleted; the tab/stepper/perm/tree-list/inline-select
  CSS moved out of `admin_css()` (the tab panels, tree screen wrapper, shared
  `.tree-arrow` and form row/grid layout stay). `toggle_pais`/`toggle_prov` read
  `payload["value"]`. 11 gallery tests (218 total), docs, `ui-formlayout` /
  `ui-formrow` / `ui-groupselect` / `ui-multiselect` / `ui-tabs` / `ui-stepper` /
  `ui-treeview` snippets. `fitz check` + `fitz test` + `fitz build` verified; live
  Postgres render + WS smoke + `fitz run` ↔ binary parity confirmed. (Note:
  GroupSelect / MultiSelect must import `FieldOption` so the nested
  `OptionGroup.options` resolves cross-module in `fitz build`.) **Closes the Forms
  extraction** (inputs in v0.22.0 + composite here).
- [x] **Session H — Feedback & misc** (v0.24.0): `Chip` (soft-tinted tag pill,
  variants) · `CountBadge` (small solid count pill, `max` caps to "N+") · `Tooltip`
  (standalone CSS-only hover bubble; AppShell also provides a global
  `[data-tooltip]`) · `Divider` (an `<hr>`, or a labeled caption between lines) ·
  `ExpansionPanel` (collapsible native `<details>`, zero JS). Adopted in the admin:
  the detail-panel chips + departamentos código (Chip), the grouped-grid member
  tally (CountBadge), the dashboard separator + collapsible chart (Divider +
  ExpansionPanel); the local `chip` helper renamed to the Chip component; the
  `.chip` / `.grp-count` / `.divider` / `.exp-panel` CSS moved out of `admin_css()`.
  9 gallery tests (227 total), docs, `ui-chip` / `ui-countbadge` / `ui-tooltip` /
  `ui-divider` / `ui-expansionpanel` snippets. `fitz check` + `fitz test` + `fitz
  build` verified; live Postgres render + WS smoke + `fitz run` ↔ binary parity
  confirmed. **Closes the companion UI library's component extraction** — every
  reusable piece of the Admin ABM is now packaged.

> **Ordering rationale**: Breadcrumbs first (cleanest, self-contained, proves the
> Shell-family recipe). ThemeToggle next (scripts + one button, low risk).
> Sidebar/Topbar/AppShell get a dedicated session because the document-layout +
> CSS-split needs a visual 320px pass. Dashboard/DataGrid/Forms/Feedback follow
> the existing admin `.fitzv` extractions. Reconnect / backpressure / multi-instance
> reliability debts stay **deferred** (tracked in the Keyed diffing section).

## Phase 10 — Client-WASM live gallery 🌐 (in progress, 2026-07-30)

A **live, interactive component gallery on GitHub Pages** — real components
running as WebAssembly in the visitor's browser, no install, no server. This is
the visibility / stars engine: the docs site already lives on Pages, and the
gallery deploys alongside it under `/live/`.

Client-WASM is a **parallel component set**, not a recompile of the SSR companion
UI — the core's `.fitzv` → wasm-client loader is sibling-file-only, has no
`dep_registry`, and uses a different render model (DOM ops, not string-builder
`Html`), so `from fitz_liveviews import flv` can't resolve. The client set is
standalone `.fitzv` that import nothing, use plain `{x}` interpolation, wire local
`@click`, and reuse the **same `--flv-*` tokens** so they look identical. Full
rationale + capability envelope in [`docs/client-wasm-plan.md`](docs/client-wasm-plan.md).

- [x] **CW.1 — Toolchain + first live example on Pages** (2026-07-30) —
      `examples/wasm-gallery/`: a standalone `Counter.fitzv` styled with the
      `--flv-*` tokens, driven by the real `fitz build --target wasm-client` CLI
      (the first example in either repo to use the manifest-driven wasm flow —
      `[[bin]] target = "wasm-client", mount = "#app"`). `index.html` +
      `build.sh` + README. `docs.yml` extended to build the wasm in CI and
      publish it into the single Pages artifact under `/live/`. Bundle: 29 KB raw
      / 12.4 KB gzipped (well under the core's 40 KB gate). Verified end-to-end:
      `wasm-pack` compiles, bundle serves over HTTP with correct MIME
      (`application/wasm`), generated `lib.rs` wires `mount("#app")` + three click
      listeners + `{count}` render + scoped `var(--flv-*)` styles.
- [x] **CW.2 — The client-side component set** (2026-07-30) — eight standalone
      client `.fitzv`, all compile to wasm: Counter, Toggle, Tabs, Stepper, Rating,
      Accordion, Modal, and a TodoList (`{#for}` + `data-flv-submit`/`data-flv-value`
      payloads + sibling `todo_helpers.fitz`). Envelope notes: the view lexer rejects
      `!` and inline `==`/`!=` in event bodies, and the wasm emitter defers unary `-1`.
- [x] **CW.3 — The live gallery page** (2026-07-30) — `Gallery.fitzv` composes the
      eight via cross-file `<Child/>` into one bundle (~34 KB gzipped), mounted at
      `/live/` and embedded in `/live-gallery/`. Client-side theme toggle shipped
      2026-08-13 (see CW.6).
- [x] **CW.4 — Docs + SSR-vs-client decision matrix** (2026-07-30) —
      `docs/client-wasm.md` (the third rendering mode: decision matrix, the
      "parallel set" rationale, the capability envelope + gotchas, build/deploy),
      in the Guide nav; "▶ see it live" pointers from `docs/ui-components.md` and a
      cross-link from `live-gallery.md`.
- [x] **CW.6 — Client-side theme toggle** (2026-08-13) — a plain `<button id=
      "flv-theme-btn">` + inline JS in `wasm-gallery/index.html` (a client-WASM
      `.fitzv` can't reach `<html>` / `localStorage` — it only owns its mounted
      subtree), mirroring `theme_scripts.fitz`'s `flvCycleTheme`/boot: cycles
      light → dark → auto over `localStorage` + `data-theme` on `<html>`. The dark
      tokens gained a `:root[data-theme="dark"]` selector (mirroring the SSR
      `theme.fitz`), with the `prefers-color-scheme` media query gated to
      auto/unset so an explicit choice wins. Hidden when embedded in an iframe
      (`window.self !== window.top`) so it doesn't clash with Material's own toggle
      on the docs `live-gallery.md` page. Validated with a 14/14 headless-Chrome
      smoke (cycle + CSS tokens + localStorage persistence across reload).
- [x] **CW.5 — CI + release** (2026-07-30) — bump `0.24.0 → 0.25.0` (fitz.toml +
      extension package.json), CHANGELOG `[Unreleased]` → `[v0.25.0]`; the `.vsix`
      is built in CI by `release.yml` on the tag (grammar/snippets unchanged — the
      client `.fitzv` use the same view syntax). CI gate for the gallery is the
      Pages build in `docs.yml`; `fitz check --target wasm-client` is aspirational
      (the current core has no such flag, and plain `fitz check` lexes a `.fitzv`
      as classic Fitz), so `ci.yml` is left unchanged.
- [x] **CW.6 — dual-target research + core `flv` passthrough** (2026-07-30) —
      assessed whether a subset could share ONE source across SSR + wasm-client.
      **Finding: feasible, and cheaper than the plan assumed.** The `.fitzv` model
      already shares template/state/events across `codegen_ssr` + `codegen_wasm`;
      `@click` is already a unified convention (SSR → `data-flv-click`, wasm wires
      it locally, R3.5b). The one real blocker was `{flv(x)}`: `flv` HTML-escapes,
      redundant on a DOM text node (which escapes intrinsically), so it is the
      IDENTITY on wasm. A `flv` passthrough (+ hard-error on the raw-HTML helpers
      `html`/`raw_html`/`h_join`/`h_when`/`h_either`, which have no wasm equivalent)
      landed in **fitz core** (`src/view/codegen_wasm.rs`, `lower_call`, 2 unit
      tests) and was validated end-to-end: the UNCHANGED SSR `Badge.fitzv` +
      `Chip.fitzv` (both `from fitz_liveviews import flv` + `{flv(label)}`) compile
      `--target wasm-client` to a real `.wasm` bundle, with `{flv(label)}` lowering
      byte-identically to `{label}`. **The `dep_registry` in the wasm loader —
      framed as the big blocker — is NOT needed** for this subset: the only
      framework import is `flv`, now special-cased, and the import line is already
      skipped by the sibling-only loader. Deferred until a shared component
      genuinely needs a non-framework dep import. Full findings in
      [`docs/client-wasm-plan.md`](docs/client-wasm-plan.md). **Ships when fitz core
      cuts a release with the passthrough** (implemented + validated locally in
      `d:\fitz`, pending its release ceremony).
- [x] **CW.7 — Companion UI dual-target showcase** (2026-07-31) — **fifteen**
      SSR companion UI components (`Badge`, `Chip`, `CountBadge`, `StatCard`,
      `Tooltip`, `Checkbox`, `ExpansionPanel`, `Divider`, `Alert`, `Card`,
      `Input`, `Textarea`, `DatePicker`, `ProgressBar`, `Spinner`) now run in
      the live gallery, compiled to WASM from their *exact* server-side source
      via the CW.6 `flv` passthrough. (`ProgressBar` + `Spinner` joined once
      fitz core v0.29.4 added mixed attribute interpolation + negative numeric
      defaults — CW.9 #1.) Mechanism: a `src/ui/_wasm_showcase.fitzv` wrapper composes
      the real components **as siblings** (the wasm cross-file loader is
      sibling-only, so the wrapper must live next to the components) with
      static props, and the gallery bin `showcase` points `main` at it
      cross-dir. No core change — the sibling trick sidesteps the loader
      limitation. **Gotcha (cost one broken deploy):** the wasm SFC
      composition treats only **Capitalized** tags as child components
      (`expand.rs`, `is_ascii_uppercase`); the library components are declared
      lowercase (`component badge`), so `<badge>` silently emitted an empty
      `<badge>` HTML element instead of composing — the build "passed" but
      rendered nothing. Fix: import with a Capitalized alias
      (`from Badge import badge as Badge`) and compose `<Badge />`. **Re-harvest
      (2026-07-31)**: a debugging pass in real headless Chrome found that
      Str-comparison `{#if}` (`{#if variant == "error"}`, `{#if x != ""}`)
      **already compiles and runs** on the wasm target — it had been
      mis-categorized as a gap (never actually tested; the emitter's `{#if}`
      lowers both sides via `lower_expr`, so `String == String` is valid Rust).
      That unblocked `Alert`, `Card`, `Divider`, `Input`, `Textarea`,
      `DatePicker` straight from their SSR source, growing the showcase from 7
      to 13; then `ProgressBar` + `Spinner` joined at 15 once fitz core v0.29.4
      added mixed attribute interpolation + negative numeric defaults (CW.9
      #1). All verified rendering in headless Chrome (no page errors). Embedded
      at `/live/embed/?c=showcase`; CI cache `-v3`. Still SSR-only: helper-dep
      components (`Select`, `RadioGroup`, `GridToolbar` → sibling `.fitz`
      helpers that don't transpile, CW.9 #1 below), `Html`-typed props
      (`DataGrid`, `FormRow`), and `ThemeToggle` (SSR-injected
      `flvCycleTheme()`).
- [x] **CW.8 (CORE) — cross-dir / dependency imports in the wasm loader**
      (fitz core **v0.29.6**) — a `.fitzv` compiled with `fitz build --target
      wasm-client` can now import a component from a `fitz.toml` **dependency**
      by dotted sub-path (`from fitz_liveviews.ui.Badge import badge as
      Badge`), resolving it under the dep's root and inlining it into the
      standalone wasm crate, instead of the sibling-only resolution. Unblocks
      external wasm apps consuming the companion UI as a library. Implemented
      in `d:\fitz` (`src/view/wasm_build.rs`): the four view loaders gained
      `*_with_deps` variants resolving each import through a dep-aware
      `resolve_view_import` (mirroring the classic `codegen.rs`/`evaluator.rs`
      dep resolution bit-for-bit); framework builtins (`flv`, `html`, …) never
      trigger a dep load. Validated end-to-end: an external consumer importing
      `Badge` from a `fitz_liveviews` path dep compiled to a real `.wasm`
      (`wasm-pack` → `:-) Done`) with the dep component's struct + scoped
      styles inlined. **Does NOT unblock the SSR-only components** — those are
      blocked by the envelope (CW.9), not by import resolution. **MVP limit**:
      a dep component that composes a *bare-name* sibling (not a dotted
      sub-path) isn't resolved against the dep's own dir — the dual-target
      presentational primitives are leaves, so this doesn't block them.
- [ ] **CW.9 (deferred, CORE) — wasm envelope expansion (remaining SSR-only
      unlocks)** — the companion components still SSR-only are blocked by the
      client-WASM **capability envelope**. Two earlier "gaps" turned out to be
      non-gaps or already closed:
      - ~~Str-comparison `{#if}`~~ — **already works** (CW.7 re-harvest); it was
        mis-categorized (never tested). `lower_cond_expr` lowers both sides via
        `lower_expr`, so `{#if variant == "error"}` compiles as `String ==
        String`. No work needed.
      - ~~File input~~ — **done in v0.29.3** (`data-flv-file` reads a picked
        file via `FileReader` into state; drop `payload["data"]` into
        `<img src="{img}">`).
      - ~~Mixed attribute interpolation~~ — **done in v0.29.4**
        (`style="width: {pct}%"` lowers to a `format!`-based `set_attribute`).
        Plus negative numeric state defaults (`Int = -1`). Unblocked
        `ProgressBar` + `Spinner`.
      - ~~`@input` live binding + `<select>` change~~ — **done in v0.29.7**
        (fitz core CW.9). `@input` / `@change` read the target's live value
        into `payload["value"]` (covering `<input>`/`<select>`/`<textarea>`);
        the handler writes it to state. Matches the SSR `data-flv-<event>`
        lowering, so one `.fitzv` targets both. Example
        `examples/view/live-input/` in `d:\fitz`. Caveat: naive re-render
        makes a live text input lose its caret (fine-grained reactivity is a
        later iteration).
      - ~~Helper-fn `for` / `match` / local-reassign / string-concat~~ —
        **partly done in v0.29.5**: those constructs now lower in imported
        helper `fn` bodies + event bodies.
      - ~~`?` / `Result` in helper-fn bodies~~ — **done (CW.9 1a)** in fitz
        core `src/view/codegen_wasm.rs`. `Result<T>` now maps to
        `Result<T, String>` (Err pinned to String, matching classic Fitz +
        the `@rpc` stub); `Ok(v)` / `Err(e)` constructors, `?` propagation,
        and `match` arms that bind `Ok(v)` / `Err(e)` all lower. So a helper
        can validate and propagate failures, and a caller can `match` its
        Result. Verified end-to-end to real `.wasm`.
      - ~~HTML-string / `Html`-returning helpers can't render on wasm~~ —
        **done (CW.9 1b + 1c)**. Two coordinated pieces in fitz core:
        - **1b — raw-HTML sink.** `{raw_html(x)}` / `{html(x)}` as an element
          child injects the (unescaped) markup via `set_inner_html` on the
          parent instead of an escaping text node (React's
          `dangerouslySetInnerHTML` model — the raw interpolation must be the
          SOLE content of its parent). Needs `from fitz_liveviews import
          raw_html` in scope (parallel to `flv`). The SSR emitter strips the
          marker to `{x}` so the SAME source is byte-identical on SSR.
        - **1c — `Html` shim.** The companion markup helpers return `Html`
          (e.g. `icon -> Html` building an SVG via `html(...)`), not a bare
          `Str`. The wasm emitter now models `Html` with a per-bundle
          `__FlvHtml` shim (`html`/`raw_html` constructors + `.raw` access),
          so those helpers transpile. Plus a fn-alias fix in the wasm loader
          (`from icon import icon as render_icon`).
        Plus two small core lowerings closed the rest of the
        markup/list-component surface: a **bool field access in a `{#if}`
        condition** (`{#if o.on}` over a `List<FieldOption>`) and **`for x in
        <list>` in helper bodies** (`bar_scale`'s `for b in bars`).
        - **PROVEN on FIVE real companion components** (fitz core v0.35.0),
          each compiling to real `.wasm` with its SSR byte-identical (all 227
          ui-gallery tests green): **Button** (icon SVG via the sink),
          **Select** + **RadioGroup** (`{#for o in options}` + `{#if o.on}`,
          unchanged source), **GridToolbar** (`{raw_html(actions)}`), and
          **BarChart** (`bar_scale`'s list `for`, unchanged source).
        MVP limits: not yet inside keep-node / hydratable components; the
        `List<Html>`-folding helpers (`h_join`/`h_when`/`h_either`) stay
        SSR-only (no single-string form).

      The real remaining gap in `d:\fitz`:
      1. **Fine-grained reactivity** — patch-in-place instead of naive
         re-render, so a live text `@input` keeps its caret. It's a
         rendering-model upgrade (fitz core Fase 11.10), orthogonal to the
         constructs above.
      Independent of CW.8. Some components (DataGrid over server data, forms
      that submit server-side) will only ever render their *shell* client-side
      — their behavior is intrinsically server-driven.

      **CW.9 iter2 (fitz core v0.36.0)** — a sweep of the remaining companion
      components found **16 of 18** already compile to wasm; three more small
      core fixes closed the gaps to POPULATE the list-driven ones: helper-body
      list `for`/`.push` (Pager's `page_range`), interpolated **non-primitive**
      props (`<Select options="{opts}" />` — non-nullable List/Map/nominal;
      `Nullable<T>` targets still defer), and **`List<nominal>` state defaults**
      (`opts: List<FieldOption> = [FieldOption { ... }]`; MVP: all fields must
      be specified). Result: **36 of 38 companion components dual-target**.

      **CW.9 follow-ups (fitz core v0.37.0)** — the three remaining residual
      debts closed, all confined to `src/view/`, byte-compat, no new `.fitzv`
      syntax:
      1. **Interpolated props into a `Nullable<T>` target.** `<Badge
         caption="{note}" />` with `caption: Str?` no longer defers: a
         non-nullable source wraps `Some(...)`, an already-`Nullable` source
         clones directly.
      2. **Omitted fields in a `List<nominal>` default filled from the nominal's
         declared defaults** (byte-accurate with SSR) — `options:
         List<FieldOption> = [ FieldOption { label: "Red", value: "red" } ]`
         drops `on: Bool = true` and it's filled with `true` (no more "missing
         field" rustc error). Supplied fields keep the exact prior emit.
      3. **Fall-through-event bubbling on wasm.** A `data-flv-click="page_prev"`
         whose name isn't a local `event` fires the component's `__on_page_prev`
         callback slot when a parent binds `<Ctrl @page_prev="..." />`, else no
         listener is wired (inert standalone). The core view checker was relaxed
         to accept `<Child @X />` when the child EMITS `X` via `data-flv-*` (not
         only when it declares `event X`); a genuine typo still errors.

      This **unblocks `Pager` and `ConfirmDialog`** — the two *controlled*
      components (buttons fire fall-through events, not local events) — so the
      companion UI reaches **38 of 38 dual-target**.

      **Gallery status**: the live composed showcase
      (`src/ui/_wasm_showcase.fitzv`, bin `showcase`) now composes **22
      dual-target components** — `Select` / `RadioGroup` / `BarChart` (fed
      `List<FieldOption>` / `List<Bar>` state as interpolated props) plus the
      controlled `Pager` (numbered buttons via `page_range`, mounted standalone
      so its fall-through clicks are inert) and `ConfirmDialog` (mounted closed).
      Both compile + render to real WASM; wiring their fall-through events to a
      parent needs a `@ws`-style host loop (server-side), so in the standalone
      gallery they're presentational.

## Phase 11 — SSR-isomorphic hydration 💧 (core landed v0.31.0)

The bridge that closes the loop between the two halves of the frontend
story: the **same `.fitzv`** paints on the server for a fast, indexable
first paint, and then a **WASM app adopts that exact server-painted DOM**
via `hydrate()` instead of `mount()`. No blank-mount flash, no framework
runtime shipped to the client, node-for-node adoption (nothing to
reconcile — unlike React/Next hydration-mismatch warnings). After
adoption, the keep-node patch model from Phase 10 keeps the DOM alive.

**Landed in Fitz core v0.31.0** (Fase 11.12 on the core side). Opt-in per
component with the **`hydrate` marker** on the root — this keeps the
LiveViews SSR path byte-identical for components that don't ask for it.
Four core examples cover the surface: `hydrate` (primitive state),
`hydrate-mixed` (interleaved text + interpolation), `hydrate-regions`
(`{#if}`/`{#for}` regions restored between comment anchors), and
`hydrate-composition` (child + slot). VSCode grammar highlights the
marker (v0.31.0). Walkthrough: the blog post
[`docs/blog/dev.to/8-ssr-hydration-en.md`](docs/blog/dev.to/8-ssr-hydration-en.md).

**For fitz-liveviews specifically**: hydration is what lets a dual-target
companion component *server-render first* and *then* become interactive
client-side from the same source — the natural next step on top of the
CW.6–CW.8 dual-target work. Adopting it across the presentational subset
(and threading the `hydrate` marker through the SSR renderer + `.fitzv`
authoring) is the framework-side work.

**The honest edges (MVP)** — carried from the core, none blocking:

- [ ] **Universal auto-hydration** — today it's opt-in via the marker;
      auto-hydrating every component is a future improvement (opt-in keeps
      the byte-identical guarantee).
- [ ] **JSON round-trip of composite state** — primitive / `List` / `Map`
      (`Str` keys) / nominal state restore on hydration; a `Map` with a
      non-`Str` key, tuples, or functions reset to default on restore
      (symmetric with the dump).
- [ ] **Named slots in the SSR emitter** + **dynamic composition inside
      `{#if}`/`{#for}`** — later slices; the default slot + static
      composition adopt today.

---

## Phase 7 — Beyond MVP (deferred, opportunistic) 🔮

Ideas that would land only if there is real demand:

- Server-Sent Events fallback when WebSocket is blocked (corporate networks)
- Optimistic UI updates (client applies patch before server confirms)
- File uploads with progress
- Presence tracking primitives (`Presence.list(topic)`)
- LiveViews in native mobile via WebView (companion repo)
- Third-party template languages (bring your own renderer)
- Static export mode (`fitz-liveviews build --static` → SSG)

---

## Design decisions still open

Things to decide once we hit the phase — not committing prematurely:

1. **Template syntax for control flow**: `{#for}...{/for}` (Svelte-style) vs
   `<template x-for="...">` (Alpine-style) vs Fitz-native `for/if`
   expressions inside `{}` interpolation.
2. **Component identity**: how do we track "this specific card" for stateful
   components (auto-generated IDs vs explicit `key=` attribute).
3. **CSS scoping strategy**: scoped `<style>` blocks vs BEM convention vs
   Tailwind-only guidance.
4. **Server → client patch protocol**: JSON vs compact binary format
   (start with JSON, benchmark later).
5. **Client JS location**: embedded in the `fitz-liveviews` compiled binary
   vs served as a static asset from `assets/`.

---

## Non-goals (for now)

- Client-side routing (server-rendered means server decides routes)
- Full SPA-mode (this is deliberately server-first)
- SSR/hydration model like Nuxt/Next (different paradigm entirely)
- Replacing React/Vue for highly-interactive graphical apps (canvas editors,
  drag-drop with complex client state) — those keep using React/Vue
- Framework-agnostic mode (LiveViews is Fitz-specific by design)
