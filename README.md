<div align="center">
  <img src="assets/logo.png" alt="Fitz LiveViews logo" width="200" />

  # Fitz LiveViews

  **Real-time server-rendered UI for Fitz.**

  WebSocket diffing · Zero JS build · Phoenix LiveView-inspired

  [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
  [![Status: Phase 0](https://img.shields.io/badge/Status-Phase%200%20(design)-orange.svg)](ROADMAP.md)
</div>

---

## Status: 🚧 Phase 0 — Repo bootstrap

This project is under active design. **Nothing works yet.** Star the repo to
follow along. See [ROADMAP.md](ROADMAP.md) for the phase-by-phase plan.

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

Coming with Phase 5 (see [ROADMAP.md](ROADMAP.md)).

Meanwhile, the [`examples/`](examples/) folder is the source of truth
for what works at each phase.

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
