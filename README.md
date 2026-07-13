<div align="center">
  <img src="assets/logo.png" alt="Fitz LiveViews logo" width="200" />

  # Fitz LiveViews

  **Real-time server-rendered UI for Fitz.**

  WebSocket diffing · Zero JS build · Phoenix LiveView-inspired

  [![CI](https://github.com/Thegreekman76/fitz-liveviews/actions/workflows/ci.yml/badge.svg)](https://github.com/Thegreekman76/fitz-liveviews/actions/workflows/ci.yml)
  [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
  [![Status: Phase 4 landed](https://img.shields.io/badge/Status-Phase%204%20(LiveComponents)-brightgreen.svg)](ROADMAP.md)
</div>

---

## Status: ✅ Phase 4 (LiveComponents) — v0.4.0

Everything you need to ship a real-time UI works end-to-end today:

- **Phase 1** — `Html` type + `flv()` XSS escape + composition helpers
- **Phase 2** — `@get` + `@ws` + `live_layout` pattern; counter example
- **Phase 3a** — Forms via `data-flv-submit`, shared state, `ws.broadcast(...)`; multi-user chat example
- **Phase 3b** — HTML parser + tree diff + client walker → compact patches over WS, DOM state preserved
- **Phase 3b showcase** ⭐ — collaborative kanban board with `data-flv-value-*` payloads, responsive by default
- **Phase 4 (Sessions 1–3)** 🧩 — `@live_component` / `@render_for` / `@on` decorators (Fitz core), `flv_register` / `component` / `dispatch_component_events` (framework layer), `fitz new --template liveviews` scaffold, kanban refactored to use `@live_component("card_editor")` for per-card inline editing, new `examples/dashboard/` with six independent `metric_tile` instances, dedicated [`docs/components.md`](docs/components.md) walkthrough
- **Phase 5** — [Docs site](https://thegreekman76.github.io/fitz-liveviews/) (MkDocs Material) + CI/CD workflows
- **Phase 6** — VSCode extension v0.3.2 bundled at [`editors/vscode/`](editors/vscode/) — HTML highlighting inside `html("""...""")` + LiveComponents snippets (`livecomp` / `renderfor` / `onevent` / `flvcomp` / `dispatchcomp`)

See [ROADMAP.md](ROADMAP.md) for what is coming in Phase 3c, the rest of Phase 4 (release coordination + implicit registration + per-instance init), and beyond.

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

## Documentation

Full docs site: **[thegreekman76.github.io/fitz-liveviews](https://thegreekman76.github.io/fitz-liveviews/)**

Or read the source:

- [`docs/html.md`](docs/html.md) — HTML primitives (`Html`, `flv`, `h_join`, `h_when`, `h_either`)
- [`docs/live.md`](docs/live.md) — LiveView core (`live_layout`, `LiveFrame`, diff engine, `data-flv-value-*`)
- [`docs/components.md`](docs/components.md) 🧩 — LiveComponents walkthrough (`@live_component`, `@render_for`, `@on`, `flv_register`, `component`, `dispatch_component_events`)
- [`examples/counter/`](examples/counter/) — real-time counter (Phase 2)
- [`examples/chat/`](examples/chat/) — multi-user chat with broadcast + patches (Phase 3a + 3b)
- [`examples/kanban/`](examples/kanban/) ⭐ — collaborative kanban board with `@live_component("card_editor")` (Phase 4 showcase)
- [`examples/dashboard/`](examples/dashboard/) 🧩 — grid of independent `metric_tile` instances (Phase 4 showcase)

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

Way too early — the project is in Phase 0 (design and bootstrap). If you
want to follow along:

- ⭐ Star the repo
- 👀 Watch releases
- 💬 Open a discussion if you have ideas about design decisions
  (see the *Design decisions still open* section of [ROADMAP.md](ROADMAP.md))

Once we reach Phase 2 (working MVP), PRs and issues will be welcome.

## Credits

Fitz LiveViews stands on the shoulders of:

- [Phoenix LiveView](https://github.com/phoenixframework/phoenix_live_view) (Elixir)
- [Hotwire / Turbo](https://hotwired.dev/) (Ruby)
- [HTMX](https://htmx.org/)
- [Livewire](https://livewire.laravel.com/) (PHP)

Bringing the third-way idea to compiled, natively-typed languages.

## License

MIT. See [LICENSE](LICENSE).
