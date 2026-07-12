<div align="center">
  <img src="assets/logo.png" alt="Fitz LiveViews logo" width="200" />

  # Fitz LiveViews

  **Real-time server-rendered UI for Fitz.**

  WebSocket diffing · Zero JS build · Phoenix LiveView-inspired

  [![CI](https://github.com/Thegreekman76/fitz-liveviews/actions/workflows/ci.yml/badge.svg)](https://github.com/Thegreekman76/fitz-liveviews/actions/workflows/ci.yml)
  [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
  [![Status: Phase 3b](https://img.shields.io/badge/Status-Phase%203b%20(diff%20engine)-blue.svg)](ROADMAP.md)
</div>

---

## Status: ✅ Phase 3b — server-side diff engine landed

Everything you need to ship a real-time UI works end-to-end today:

- **Phase 1** — `Html` type + `flv()` XSS escape + composition helpers
- **Phase 2** — `@get` + `@ws` + `live_layout` pattern; counter example
- **Phase 3a** — Forms via `data-flv-submit`, shared state, `ws.broadcast(...)`; multi-user chat example
- **Phase 3b** — HTML parser + tree diff + client walker → compact patches over WS, DOM state preserved
- **Phase 5** — [Docs site](https://thegreekman76.github.io/fitz-liveviews/) (MkDocs Material) + CI/CD workflows
- **Phase 6** — VSCode extension bundled at [`editors/vscode/`](editors/vscode/) — HTML highlighting inside `html("""...""")` + 11 snippets

See [ROADMAP.md](ROADMAP.md) for what is coming in Phase 3c, 4, and 7.

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

## Quick start (aspirational — lands with Phase 2)

```bash
# Install Fitz
curl -fsSL https://get.fitz.dev | sh

# Create a project with LiveViews
fitz new my-live-app --with liveviews
cd my-live-app

# Dev mode with hot reload
fitz dev
```

Then open `http://localhost:3000` and edit `src/app.fitz` — the browser
updates on save without losing state.

## Documentation

Full docs site: **[thegreekman76.github.io/fitz-liveviews](https://thegreekman76.github.io/fitz-liveviews/)**

Or read the source:

- [`docs/html.md`](docs/html.md) — HTML primitives (`Html`, `flv`, `h_join`, `h_when`, `h_either`)
- [`docs/live.md`](docs/live.md) — LiveView core (`live_layout`, `LiveFrame`, diff engine)
- [`examples/counter/`](examples/counter/) — real-time counter (Phase 2)
- [`examples/chat/`](examples/chat/) — multi-user chat with broadcast + patches (Phase 3a + 3b)

## VSCode extension

An extension bundled at [`editors/vscode/`](editors/vscode/) adds HTML
syntax highlighting inside `html("""...""")` templates and 11 snippets
for the common Phase 2 + 3 patterns (`liveview`, `render`, `get`, `ws`,
`broadcast`, `flv`, `hwhen`, `heither`, `hjoin`, `btnclick`, `flvform`).

Install from the local `.vsix` (until Marketplace publish):

```powershell
cd editors/vscode
npx @vscode/vsce package --no-dependencies
code --install-extension fitz-liveviews-*.vsix
```

Requires the base [Fitz Language extension](https://marketplace.visualstudio.com/items?itemName=thegreekman76.fitz-language),
which VSCode will offer to install automatically.

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
