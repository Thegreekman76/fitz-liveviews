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

## Phase 3b — Real-world polish 📦

Deferred from Phase 3a because Chat MVP proves the concept without them.

- [ ] Server-side HTML diff engine → patch list (fixes input-clearing
      on every render)
- [ ] Template control flow `{#for x in xs}...{/for}`,
      `{#if cond}...{/if}` — needs a mini template engine
- [ ] `data-flv-input`, `data-flv-change`, `data-flv-keydown` handlers
- [ ] Debouncing configuration on inputs (client-side)
- [ ] Loops with stable keys (`{#for x in xs key=x.id}`) for efficient diff
- [ ] Auth integration (`@authenticated @live(...)`, user injected)
- [ ] `@on_mount` and `@on_disconnect` lifecycle hooks
- [ ] `@every(N secs)` for server-pushed periodic updates

## Phase 4 — Stateful components (LiveComponents) 🧩

Per-instance state without hoisting everything to the parent.

- [ ] `@live_component(name)` decorator
- [ ] Per-instance state with stable component IDs
- [ ] Component lifecycle (mount, update, unmount)
- [ ] Parent ↔ child communication patterns
- [ ] Example: **nested accordions / dashboard tiles**

## Phase 5 — Polish and ecosystem 🌟

Everything needed for a real launch.

- [ ] CSS scoping (BEM convention or scoped `<style>` tag support)
- [ ] Client-side directive escape hatches (dropdowns, tooltips, focus)
- [ ] **Docs site** — MkDocs Material, GitHub Pages, custom domain if applicable
- [ ] **Blog post ES + EN** — launch narrative
- [ ] **Public release + Show HN**
- [ ] Companion repo: `fitz-liveviews-ui` — component library
  (buttons, forms, modals, tables) built on top

## Phase 6 — VSCode extension 🎯

First-class editor experience.

- [ ] Repo: `fitz-liveviews-vscode` (depends on base `fitz-language`)
- [ ] HTML injection grammar inside `html("""...""")`
- [ ] Autocomplete: HTML tags, attributes, `@directives`
- [ ] Emmet expansion inside templates
- [ ] Autocomplete: `@on(...)` handler names
- [ ] Autocomplete: state fields inside `{...}` interpolation
- [ ] Go-to-def: component function references
- [ ] Hover: component signatures
- [ ] Diagnostics: unclosed tags, unknown handlers, invalid directives
- [ ] Snippets: `liveview`, `on`, `component`
- [ ] Publish to VSCode Marketplace

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
