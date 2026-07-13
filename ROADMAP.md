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
- [ ] Codegen pass: turn `@live_component` + `@render_for` + `@on`
      into an implicit registration and remove the explicit
      `flv_register(...)` call (future — public API stays the same)
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
