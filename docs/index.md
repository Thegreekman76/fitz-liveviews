<div align="center" markdown>
  ![Fitz LiveViews](assets/logo.png){ width="200" }

  # Fitz LiveViews

  **Real-time server-rendered UI for Fitz.**

  *WebSocket diffing · Zero JS build · Phoenix LiveView-inspired*
</div>

---

## Status: Phase 3b — server-side diff engine 🎉

Everything you need to build a real-time UI now works end-to-end:

- **Phase 0** — Repo bootstrap
- **Phase 1** — `Html` type and templating with XSS-safe `flv()` escape
- **Phase 2** — LiveView core (`@get` + `@ws` + `live_layout`) with the counter example
- **Phase 3a** — Forms via `data-flv-submit`, shared state, `ws.broadcast(...)` with the multi-user chat example
- **Phase 3b** — HTML parser + tree diff engine + client walker → compact patches over the wire, DOM state preserved (input values, focus, cursor position)

See the [Roadmap](https://github.com/Thegreekman76/fitz-liveviews/blob/main/ROADMAP.md) for what is coming in Phase 3c, 4, 5, and 6.

---

## What is this?

You write UIs like HTTP handlers. Fitz LiveViews takes care of updating them
in the browser via WebSocket — without you writing a line of JavaScript.

The "hello world" is a real-time counter:

```fitz
type CounterState { count: Int = 0 }

fn render(state: CounterState) -> Html {
  return html("""<div id="counter-app">
    <p>Count: {state.count}</p>
    <button data-flv-click="increment">+1</button>
  </div>""")
}

@get("/")
fn counter_page() -> Response {
  return html_response(
    live_layout("/live/counter", "counter-app", render(CounterState { count: 0 }))
  )
}

@ws("/live/counter")
async fn counter_socket(ws: WsConn<LiveFrame>) {
  let state = CounterState { count: 0 }
  let last_html = render(state).raw
  loop {
    let frame = ws.recv()?
    if (frame.event == "increment") {
      state = CounterState { count: state.count + 1 }
    }
    let new_html = render(state).raw
    let patches = diff_html(last_html, new_html)
    ws.send(LiveFrame { html: new_html, patches: patches })?
    last_html = new_html
  }
}

@server(3000)
fn main() => 0
```

Click the button, the count updates without a page reload. No React, no
bundler, no `useState`, no `fetch` call. Just a Fitz function.

---

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

---

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

---

## Comparison

|                              | Vue + FastAPI          | Phoenix LiveView  | HTMX + Go        | **fitz-liveviews**  |
|------------------------------|------------------------|-------------------|------------------|---------------------|
| Server language              | Python                 | Elixir            | Go               | Fitz                |
| Client bundle                | 30–100 KB              | ~5 KB             | ~10 KB           | ~5 KB               |
| Compile step for client      | Vite / Webpack         | `mix compile`     | None             | None                |
| Native binary                | ❌ (Python + Node)     | ❌ (BEAM VM)      | ✅               | ✅                  |
| Typed state ↔ template       | Volar + TS setup       | Runtime           | ❌               | Compiler-enforced   |
| WebSocket layer              | Manual (`socket.io`)   | Phoenix Channels  | ❌ (HTTP only)   | Native `WsConn<T>`  |
| **Server-side diff engine**  | ❌                     | ✅                | ❌               | ✅                  |
| Auto OpenAPI + AsyncAPI      | ❌                     | ❌                | ❌               | ✅ (from Fitz)      |
| Deploy                       | Node + Python + Nginx  | BEAM release      | Single binary    | Single binary       |

---

## Quick start

**Prerequisites:** the `fitz` binary. The [Fitz install guide](https://thegreekman76.github.io/fitz/curso/m1-setup/c1-instalacion/)
covers Windows, macOS, Linux, plus VSCode extension setup and
troubleshooting.

```bash
# Clone the repo
git clone https://github.com/Thegreekman76/fitz-liveviews
cd fitz-liveviews

# Run the counter (real-time, single user)
cd examples/counter
fitz run
```

Open `http://127.0.0.1:3000/`. Click `+1` and the number updates in
real time — no page reload, no `fetch`, no JavaScript build step.

For the multi-user chat, `cd examples/chat && fitz run` and open the
URL in **two** browser windows to see broadcast in action.

---

## Where to next

- **[HTML primitives](html.md)** — how `Html`, `flv()`, `h_join`, and friends work
- **[LiveViews](live.md)** — the pattern, the client runtime, the diff engine, and known limits
- **[Counter example](examples/counter.md)** — the "hello world"
- **[Chat example](examples/chat.md)** — multi-user real-time with broadcast + patches

---

## Credits

Fitz LiveViews stands on the shoulders of:

- [Phoenix LiveView](https://github.com/phoenixframework/phoenix_live_view) (Elixir)
- [Hotwire / Turbo](https://hotwired.dev/) (Ruby)
- [HTMX](https://htmx.org/)
- [Livewire](https://livewire.laravel.com/) (PHP)

Bringing the third-way idea to compiled, natively-typed languages.

---

## License

MIT. See [LICENSE](https://github.com/Thegreekman76/fitz-liveviews/blob/main/LICENSE).
