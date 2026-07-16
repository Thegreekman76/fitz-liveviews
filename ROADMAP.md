# Fitz LiveViews — Roadmap

Real-time server-rendered UI for Fitz. WebSocket diffing, zero JS build,
Phoenix LiveView-inspired.

This roadmap is **living** — phases close in order, deliverables are ticked
as they land. Aspirational timelines are best-effort, not commitments.

---

## Phase 0 — Repo bootstrap 🏁 (in progress)

Get the repo to a state that looks and feels like a real open-source project,
even before any real code lands.

- [x] MIT License
- [x] `fitz.toml` (package manifest with `[lib]` section)
- [x] `.gitignore` (Fitz + editor + OS)
- [x] `src/lib.fitz` placeholder
- [ ] **Extended README** — pitch, comparison table (LiveViews vs Vue vs Phoenix),
      quick start (aspirational), install, contributing
- [ ] **ROADMAP.md** (this file)
- [ ] **Logo** — main hero (Fitz-related visual language, distinct identity)
- [ ] **Social preview** (1280×640 for GitHub Settings → Social preview)
- [ ] **`assets/` folder** — SVG source + PNG derivatives + build script
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
- [ ] Loops with stable keys (`{#for x in xs key=x.id}`) for efficient
      diff (currently we don't handle reordering well)
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
- [ ] Per-instance init payload — today every instance starts with the
      same `initial_state`; a `component(name, id, init_payload)` shape
      would let each instance start with per-instance seed data
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

## Phase 9 — Companion UI library 🧩

**Trigger**: post-migrations completas de Phase 8. Emergent de los
patterns extraídos en 8.6, no diseñado en vacuum. Building una UI
kit **AS** los examples se refactorizan produce APIs validadas
contra código real, no bloat especulativo.

**Racional**: todo framework serio de UI real-time tiene una
companion (Vuetify/Vue, MUI/React, chakra/solid). Ninguno debería
roll-your-own CSS para el 90% del caso (Button/Card/Modal). Alinea
con la filosofía "un lenguaje con HTTP + DB + auth + WS + jobs +
**UI kit** ciudadanos primera" del stack Fitz.

**Anti-goal**: NO ser Vuetify-completo con 40+ componentes. MVP
recortado, foco y disciplina. Full kit crece por PR con demand
real, no por completeness.

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

- [ ] **9.B** **Build MVP — 8 componentes + tema** (~2-3 sesiones):
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

- [ ] **9.C** **Refactor 4 examples usando la lib** (~1 sesión):
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
