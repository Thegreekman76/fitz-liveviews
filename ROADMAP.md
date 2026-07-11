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

- [ ] `Html` opaque type (tree structure, not a string)
- [ ] `html(template: Str) -> Html` core function
- [ ] String interpolation `{expr}` inside templates (reuses Fitz's)
- [ ] Template control flow: `{#for x in xs}...{/for}`, `{#if cond}...{/if}`
- [ ] Component composition via `fn` params of type `Html`
- [ ] Auto-escaping of user content (XSS-safe by default)
- [ ] Unit tests for template rendering
- [ ] Example: `examples/hello-html/` — render a static HTML page

## Phase 2 — LiveView core (MVP) 🚀

Server + WS + JS client + diff engine end-to-end.

- [ ] `@live("/path")` decorator (mounts HTTP GET + WS handler)
- [ ] `@on("event")` decorator for event handlers
- [ ] Initial HTML render on HTTP GET (SEO-friendly first paint)
- [ ] Vanilla JS client (~500 LoC) served at `/live/client.js`
- [ ] Client → server event protocol over WebSocket
- [ ] Server-side HTML diff engine → patch list
- [ ] Server → client patch protocol
- [ ] Example: **counter** (`examples/counter/`) — the "hello world"

**Milestone: first blog post draft "It works" (internal, not published yet)**

## Phase 3 — Real-world features 📦

Everything you need for actual apps.

- [ ] `@submit` handler for forms with typed form data
- [ ] `@input`, `@change`, `@keydown` handlers
- [ ] Debouncing configuration on inputs (client-side)
- [ ] Loops with stable keys (`{#for x in xs key=x.id}`) for efficient diff
- [ ] Broadcast to multiple clients of the same LiveView
- [ ] Auth integration (`@authenticated @live(...)`, user injected)
- [ ] `@on_mount` and `@on_disconnect` lifecycle hooks
- [ ] `@every(N secs)` for server-pushed periodic updates
- [ ] Example: **multi-user chat** (`examples/chat/`) — full stack

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
