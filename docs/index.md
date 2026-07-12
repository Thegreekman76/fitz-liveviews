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

---

## What it is for

Concrete use cases where LiveViews shines:

- **Collaborative editing** — kanban boards, shared documents, live
  cursors (see the [kanban example](examples/kanban.md)).
- **Real-time dashboards** — metrics, order status, alerts that update
  without a page reload.
- **Live-validated forms** — server checks each field as you type,
  errors appear in place with no `fetch` roundtrip written by hand.
- **Multi-user apps** — chat, comments, live reactions
  (see the [chat example](examples/chat.md)).
- **Admin panels** — internal tools where you want fast iteration and
  don't want to maintain a separate SPA + API.

Not a fit: fully offline-first apps, heavy client-side animation, or
apps that must work without a persistent WebSocket connection.

---

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
- **[LiveComponents](components.md)** 🧩 — reusable server-rendered components with per-instance state
- **[Counter example](examples/counter.md)** — the "hello world"
- **[Chat example](examples/chat.md)** — multi-user real-time with broadcast + patches
- **[Kanban example](examples/kanban.md)** ⭐ — flagship showcase: shared state, `data-flv-value-*` payloads, and a compact 3-column responsive board with a per-card `@live_component("card_editor")`
- **[Dashboard example](examples/dashboard.md)** 🧩 — grid of six independent `metric_tile` instances driven by a zero-branch parent WS handler

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
