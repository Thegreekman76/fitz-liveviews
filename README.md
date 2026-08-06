<div align="center">
  <img src="assets/logo.png" alt="Fitz LiveViews logo" width="200" />

  # Fitz LiveViews

  **Real-time server-rendered UI for Fitz.**

  WebSocket diffing · Zero JS build · Phoenix LiveView-inspired

  [![CI](https://github.com/Thegreekman76/fitz-liveviews/actions/workflows/ci.yml/badge.svg)](https://github.com/Thegreekman76/fitz-liveviews/actions/workflows/ci.yml)
  [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
  [![Status: v0.31.0](https://img.shields.io/badge/Status-Companion%20UI%20%2B%20Client--WASM%20v0.31.0-brightgreen.svg)](ROADMAP.md)
</div>

---

## Status: ✅ Companion UI complete · Client-WASM gallery live · SSR hydration — v0.31.0

**Requires Fitz core v0.31.0+.** Three things are true today: the **companion UI
library is complete** (~40 importable components under `fitz_liveviews.ui.*`
covering the whole surface of a real back-office app, every one extracted from —
and adopted by — the [Admin ABM showcase](examples/admin/) with bit-for-bit
`fitz run` ↔ native-binary parity); a **live client-WASM component gallery** runs
in the browser on GitHub Pages (no server, no WebSocket); and **SSR-isomorphic
hydration** landed in the core (v0.31.0), so a `.fitzv` can server-render for
first paint and then have a WASM app adopt that exact DOM. See the
**[component catalog](#companion-ui-library)** below and the full reference in
[`docs/ui-components.md`](docs/ui-components.md).

Everything you need to ship a real-time UI works end-to-end today:

- **Phase 1** — `Html` type + `flv()` XSS escape + composition helpers
- **Phase 2** — `@get` + `@ws` + `live_layout` pattern; counter example
- **Phase 3a** — Forms via `data-flv-submit`, shared state, `ws.broadcast(...)`; multi-user chat example
- **Phase 3b** — HTML parser + tree diff + client walker → compact patches over WS, DOM state preserved
- **Phase 3b showcase** ⭐ — collaborative kanban board with `data-flv-value-*` payloads, responsive by default
- **Phase 4 (Sessions 1–3)** 🧩 — `@live_component` / `@render_for` / `@on` decorators (Fitz core), `flv_register` / `component` / `dispatch_component_events` (framework layer), `fitz new --template liveviews` scaffold, kanban refactored to use `@live_component("card_editor")` for per-card inline editing, new `examples/dashboard/` with six independent `metric_tile` instances, dedicated [`docs/components.md`](docs/components.md) walkthrough
- **Phase 5.A.1 (Fitz core v0.20.1)** ✨ — Implicit `flv_register(...)` from the `@live_component` / `@render_for` / `@on` decorators. The compiler walks the metadata that lives in the `TypeEnv` and appends the boot registration automatically; the kanban and dashboard examples dropped their manual boot call
- **Phase 5** — [Docs site](https://thegreekman76.github.io/fitz-liveviews/) (MkDocs Material) + CI/CD workflows
- **Phase 6** — VSCode extension v0.4.3 bundled at [`editors/vscode/`](editors/vscode/) — HTML highlighting inside `html("""...""")` + LiveComponents snippets (`livecomp` / `renderfor` / `onevent` / `flvcomp` / `dispatchcomp`) — all snippets are SFC-ready
- **Phase 8 (Fitz core v0.21.0)** 🎨 — All 4 examples migrated to `.fitzv` single-file component syntax. `Counter.fitzv`, `MetricTile.fitzv`, `ChatRoom.fitzv`, `CardEditor.fitzv` shipped with state + events + `<template>` blocks compact in single files. Chat migration surface 6 view pipeline gaps in Fitz core (V-1 to V-6, closed same-session via §9.cc + §9.dd + §9.ee — feedback loop of hours). Component patterns catalog ready for Phase 9 (Companion UI library)
- **K-1 + K-2 (v0.5.0)** 🔗 — Event bubbling substitute via `dispatch_to(component_name, instance_id, event, payload)` + direct state read/write via `component_state(name, id)` + `set_component_state(name, id, new_state)`. Enables child → parent dispatch patterns (proven via `k12_canonical_child_dispatches_to_parent_via_dispatch_to` test). Unblocks full `Board.fitzv` kanban migration. First new public API since v0.4.0.
- **Phase 9 — Companion UI library (v0.12.0 → v0.24.0)** 🧩 — importable components under `fitz_liveviews.ui.*` (dotted sub-path). **Cut 1** (v0.12): Pager / Toast / ConfirmDialog + `--flv-*` theme. **Cut 2** (v0.13): the 8 generic primitives — Button / Card / Badge / Alert / Input / Spinner / Icon / Modal. **9.C** (v0.14): the bundled examples refactored onto the primitives. Then the whole Admin ABM was mined into the package, one family per release: **Shell** (v0.17–0.19: Breadcrumbs / ThemeToggle / Sidebar / Topbar / AppShell), **Dashboard** (v0.20: StatCard / BarChart / ProgressBar), **DataGrid** (v0.21: DataGrid / SortableHeader / GridToolbar / GridFilters), **Forms inputs** (v0.22: Textarea / Select / Checkbox / CheckboxGroup / RadioGroup / Rating / DatePicker), **Forms composite** (v0.23: FormLayout / FormRow / GroupSelect / MultiSelect / Tabs / Stepper / TreeView), and **Feedback** (v0.24: Chip / CountBadge / Tooltip / Divider / ExpansionPanel). Every family is adopted by the Admin ABM with `fitz run` ↔ binary parity + a growing gallery test suite (227 tests). **The extraction is complete** — see the [catalog](#companion-ui-library).
- **Phase 10 — Client-WASM live gallery (v0.25.0)** 🌐 — a live, interactive component gallery hosted on [GitHub Pages](https://thegreekman76.github.io/fitz-liveviews/live/): `.fitzv` components compiled to **WebAssembly**, running in the visitor's browser with no server and no WebSocket, composed into one ~34 KB (gzipped) bundle. CW.6–CW.8 (core v0.29.x) then relaxed dual-targeting so **15 presentational SSR components run client-side from their exact server source** — no hand-written parallel version. The remaining SSR-only components are gated by the wasm capability **envelope (CW.9)**, not by import resolution.
- **Phase 11 — SSR-isomorphic hydration (Fitz core v0.31.0)** 💧 — the same `.fitzv` paints on the server for first paint, then a WASM app **adopts that exact DOM** via `hydrate()` instead of `mount()` (opt-in with the `hydrate` marker on the root component). Landed in the core with four examples (`hydrate`, `hydrate-mixed`, `hydrate-regions`, `hydrate-composition`) + VSCode grammar highlighting for the marker. See the blog post [SSR + hydration](docs/blog/dev.to/8-ssr-hydration-en.md) for the walkthrough.

See [ROADMAP.md](ROADMAP.md) for what is coming next — with the companion UI
extraction complete, the client-WASM gallery live, and hydration landed, the
nortes are **CW.9** (growing the wasm envelope so more SSR components dual-target
for free) and the **reliability debts** (reconnect with state replay, outbox
backpressure, multi-instance coordination) ahead of a public launch.

---

## What is this?

You write UIs like HTTP handlers. Fitz LiveViews takes care of updating them
in the browser via WebSocket — without you writing a line of JavaScript.

The "hello world" is a real-time counter:

```fitz
type CounterState { count: Int = 0 }

@live("/counter")
fn counter(state: CounterState) -> Html {
  return html("""
    <div>
      <p>Count: {state.count}</p>
      <button @click="increment">+1</button>
    </div>
  """)
}

@on("increment")
fn increment(state: CounterState) -> CounterState {
  return CounterState { count: state.count + 1 }
}
```

Click the button, the count updates without a page reload. No React, no
bundler, no `useState`, no `fetch` call. Just a Fitz function.

## Why?

The web today gives you two options that both hurt:

- **Server-rendered classics** (Django, Rails, PHP) — simple but every click
  reloads the page. Feels dated.
- **SPAs** (React, Vue, Angular) — modern feel, but drowning in complexity:
  bundlers, two codebases, doubled types, separate deploys.

There is a third way that is underrated: **Phoenix LiveView** (Elixir),
**Hotwire** (Ruby), **HTMX**. The server renders HTML, a tiny JS client
morphs the DOM on updates. No bundle. No duplicated state. No SPA.

**But none of those third-way tools exist for a compiled, natively-typed
language.** `fitz-liveviews` fills that gap.

## What makes this different

Five things you don't get anywhere else in one package:

1. **Server-side state, no duplication** — the database is your source of
   truth. Client is a thin projection.
2. **Typed end-to-end** — state, events, templates, all validated by the
   Fitz compiler. No `defineProps<T>()`, no `tsconfig.json`.
3. **WebSocket-native** — Fitz has `@ws` and `WsConn<T>` in the core language.
   No `Socket.io`, no Phoenix Channels layer.
4. **Zero build step** — no Vite, no Webpack, no `npm install`, no
   `package.json`. `fitz dev` and go.
5. **Native binary output** — `fitz build` gives you one file. No Node, no
   BEAM, no Python runtime. Deploy is `docker run`.

## Why this works in Fitz

Most "LiveView-style" projects in other ecosystems have to ship an entire
runtime alongside the framework: a WebSocket layer, an async story, a
session/state model, sometimes even a mini language for events. That is
why they are heavy and hard to type end-to-end.

Fitz LiveViews is intentionally thin because the language already brings
the pieces that matter:

- **`@ws("/path")` + `WsConn<T>`** — typed WebSockets are a first-class
  citizen of the language, not a library. The diff channel just uses them.
- **`async fn` + `.await` + `Future<T>`** — the server never blocks on an
  event handler. No threadpool tuning, no callback hell.
- **`@get`/`@post` + native ORM** — the same handler that renders the
  initial HTML can also query the database, with no ceremony.
- **Compiler-enforced types** — state, events, and templates are all
  checked at build time. No `defineProps<T>()`, no runtime schema drift.
- **`fitz run` ↔ `fitz build` parity** — hot reload in dev, single
  standalone binary in prod. The runtime story is the same in both.

The Elixir community solved this by pinning everything to OTP + Phoenix.
JS/Ruby/Python solve it by inventing the WebSocket + serialization layer
**outside** the language. Fitz is closer to the Elixir model: the library
leans on primitives that the compiler already validates.

## What it is for

Concrete use cases where LiveViews shines:

- **Collaborative editing** — kanban boards, shared documents, live
  cursors (see the [kanban example](examples/kanban/)).
- **Real-time dashboards** — metrics, order status, alerts that update
  without a page reload.
- **Live-validated forms** — server checks each field as you type,
  errors appear in place with no `fetch` roundtrip written by hand.
- **Multi-user apps** — chat, comments, live reactions
  (see the [chat example](examples/chat/)).
- **Admin panels** — internal tools where you want fast iteration and
  don't want to maintain a separate SPA + API.

Not a fit: fully offline-first apps, heavy client-side animation, or
apps that must work without a persistent WebSocket connection.

## The advantage: Vue+Vuetify ergonomics with a LiveView reactive model

As the library grows into `@live_component` + templates + (eventually) a
UI companion, writing components will feel a lot like Vue with Vuetify:
props, slots, ready-made buttons/inputs/dialogs, no CSS by hand.

But the **reactive model** stays LiveView, not Vue: state lives on the
server, events travel over WebSocket, the server pushes diffs to the
client. Vue does it the other way around — reactivity in the browser
with a virtual DOM.

That combo is the sweet spot that neither side covers alone:

- Elixir LiveView is powerful but the HTML/CSS story is bare.
- Vue+Vuetify is beautiful but forces you to maintain an API + client
  state + sync layer.

Fitz LiveViews bets on having both at once — the ergonomics of Vue+Vuetify
with the simplicity of a server-authoritative model, on top of a compiled
binary and a typed core.

## Comparison

|                              | Vue + FastAPI          | Phoenix LiveView  | HTMX + Go        | **fitz-liveviews**  |
|------------------------------|------------------------|-------------------|------------------|---------------------|
| Server language              | Python                 | Elixir            | Go               | Fitz                |
| Client bundle                | 30–100 KB              | ~5 KB             | ~10 KB           | ~5 KB               |
| Compile step for client      | Vite / Webpack         | `mix compile`     | None             | None                |
| Native binary                | ❌ (Python + Node)     | ❌ (BEAM VM)      | ✅               | ✅                  |
| Typed state ↔ template       | Volar + TS setup       | Runtime           | ❌               | Compiler-enforced   |
| WebSocket layer              | Manual (`socket.io`)   | Phoenix Channels  | ❌ (HTTP only)   | Native `WsConn<T>`  |
| Auto OpenAPI + AsyncAPI      | ❌                     | ❌                | ❌               | ✅ (from Fitz)      |
| Deploy                       | Node + Python + Nginx  | BEAM release      | Single binary    | Single binary       |

## Quick start

**Prerequisites:** the `fitz` binary. The [Fitz install guide](https://thegreekman76.github.io/fitz/curso/m1-setup/c1-instalacion/)
covers Windows, macOS, and Linux — plus VSCode extension setup and
troubleshooting.

```bash
# Clone the repo
git clone https://github.com/Thegreekman76/fitz-liveviews
cd fitz-liveviews

# Run the counter (real-time, single user)
cd examples/counter
fitz run
```

Open `http://127.0.0.1:3000/` to see the counter. Click `+1` and watch
the number update instantly — no page reload, no `fetch` call, no
JavaScript build step.

For the multi-user chat demo, `cd examples/chat && fitz run` and open
`http://127.0.0.1:3000/` in **two** browser windows.

## Companion UI library

A batteries-included component kit ships **inside the package** — import each piece
by dotted sub-path (`from fitz_liveviews.ui.<Comp> import <name>, <name>_render`)
straight from the dependency, no vendoring. Every component is **SSR-first**
(server-rendered, reactive over the WebSocket), needs **zero JS build**, is styled
with `<style scoped>` over re-themeable `--flv-*` tokens (light / dark / auto), and
renders identically under `fitz run` and the `fitz build` binary. All were extracted
from — and are adopted by — the [Admin ABM showcase](examples/admin/).

| Family | Components |
| --- | --- |
| **Base** | `Pager` · `Toast` · `ConfirmDialog` · `Modal` · `theme` |
| **Primitives** | `Button` · `Card` · `Badge` · `Alert` · `Input` · `Spinner` · `Icon` |
| **Shell** | `Breadcrumbs` · `ThemeToggle` · `Sidebar` · `Topbar` · `AppShell` |
| **Dashboard** | `StatCard` · `BarChart` · `ProgressBar` |
| **DataGrid** | `DataGrid` · `SortableHeader` · `GridToolbar` · `GridFilters` |
| **Forms — inputs** | `Textarea` · `Select` · `Checkbox` · `CheckboxGroup` · `RadioGroup` · `Rating` · `DatePicker` |
| **Forms — composite** | `FormLayout` · `FormRow` · `GroupSelect` · `MultiSelect` · `Tabs` · `Stepper` · `TreeView` |
| **Feedback** | `Chip` · `CountBadge` · `Tooltip` · `Divider` · `ExpansionPanel` |

**~40 components.** Full reference (API, wiring, theming, snippets) in
[`docs/ui-components.md`](docs/ui-components.md); the runnable
[`examples/ui-gallery/`](examples/ui-gallery/) renders every one in isolation (with
`fitz test` covering them — 227 tests). VSCode snippets (`ui-<name>`) ship in the
[extension](editors/vscode/).

```fitz
from fitz_liveviews.ui.DataGrid import data_grid, data_grid_render
from fitz_liveviews.ui.Tabs import tabs, tabs_render
from fitz_liveviews.ui.theme import ui_theme
```

## Documentation

Full docs site: **[thegreekman76.github.io/fitz-liveviews](https://thegreekman76.github.io/fitz-liveviews/)**

Or read the source:

- [`docs/html.md`](docs/html.md) — HTML primitives (`Html`, `flv`, `h_join`, `h_when`, `h_either`)
- [`docs/liveviews.md`](docs/liveviews.md) — LiveView core (`live_layout`, `LiveFrame`, diff engine, `data-flv-value-*`)
- [`docs/components.md`](docs/components.md) 🧩 — LiveComponents walkthrough (`@live_component`, `@render_for`, `@on`, `flv_register`, `component`, `dispatch_component_events`)
- [`docs/ui-components.md`](docs/ui-components.md) 🧰 — Companion UI catalog: DataGrid, forms (tabs/stepper), modal, toasts, tree, cascade selects… with a snippet each (realizes the [`components-candidates`](docs/components-candidates.md) shortlist)
- [`examples/counter/`](examples/counter/) — real-time counter (Phase 2)
- [`examples/chat/`](examples/chat/) — multi-user chat with broadcast + patches (Phase 3a + 3b)
- [`examples/kanban/`](examples/kanban/) ⭐ — collaborative kanban board with `@live_component("card_editor")` (Phase 4 showcase)
- [`examples/dashboard/`](examples/dashboard/) 🧩 — grid of independent `metric_tile` instances (Phase 4 showcase)
- [`examples/admin/`](examples/admin/) ⭐ — flagship People & Access back-office: full DataGrid + rich forms + auth + i18n over Postgres, the runnable reference for the UI catalog

## VSCode extension

An extension bundled at [`editors/vscode/`](editors/vscode/) adds HTML
syntax highlighting inside `html("""...""")` templates and 16 snippets
for the common Phase 2 + 3 + 4 patterns (`liveview`, `render`, `get`,
`ws`, `broadcast`, `flv`, `hwhen`, `heither`, `hjoin`, `btnclick`,
`flvform`, `livecomp`, `renderfor`, `onevent`, `flvcomp`, `dispatchcomp`).

**Prerequisites:** the base **Fitz Language** extension has to be
installed first. It ships as a `.vsix` in [Fitz's own releases](https://github.com/Thegreekman76/fitz/releases)
(not on the VSCode Marketplace yet). The [Fitz install guide](https://thegreekman76.github.io/fitz/curso/m1-setup/c1-instalacion/)
walks through the setup.

Once Fitz Language is installed, grab the latest Fitz LiveViews
`.vsix` from the [**Releases page**](https://github.com/Thegreekman76/fitz-liveviews/releases/latest)
and install it:

```powershell
# Download from the Releases page, then:
code --install-extension fitz-liveviews-0.1.0.vsix
```

Or build one yourself from source:

```powershell
cd editors/vscode
npx @vscode/vsce package --no-dependencies
code --install-extension fitz-liveviews-*.vsix
```

Once both extensions publish to the VSCode Marketplace we will switch
to a single `code --install-extension thegreekman76.fitz-liveviews`.

## Contributing

The MVP works end-to-end (SSR + companion UI + client-WASM gallery +
hydration). The project is pre-1.0 and moving fast, but it's usable today.
If you want to follow along or help:

- ⭐ Star the repo
- 👀 Watch releases
- 💬 Open a discussion if you have ideas about design decisions
  (see the *Design decisions still open* section of [ROADMAP.md](ROADMAP.md))

Issues and PRs are welcome — expect the API to still shift before 1.0.

## Credits

Fitz LiveViews stands on the shoulders of:

- [Phoenix LiveView](https://github.com/phoenixframework/phoenix_live_view) (Elixir)
- [Hotwire / Turbo](https://hotwired.dev/) (Ruby)
- [HTMX](https://htmx.org/)
- [Livewire](https://livewire.laravel.com/) (PHP)

Bringing the third-way idea to compiled, natively-typed languages.

## License

MIT. See [LICENSE](LICENSE).
