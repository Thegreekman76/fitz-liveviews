# C1 — Your first live component

**Prerequisite:** the `fitz` binary (≥ v0.28.1) on your `PATH`. Check with
`fitz --version`. If you don't have it, follow the
[Fitz install guide](https://thegreekman76.github.io/fitz/curso/m1-setup/c1-instalacion/).

**Objective:** create a new project, run a real-time counter in the browser,
and understand every line of it.

**Why it matters:** the counter is small, but it's the *whole* pattern in
miniature — state on the server, an initial HTML render, a WebSocket loop that
applies events and ships diffs. Every screen you build later, up to the full
[Admin ABM](../examples/admin.md), is this same shape scaled up. Learn it once
here and the rest is composition.

---

## 1. Create the project

```bash
fitz new my-counter --template liveviews
cd my-counter
```

`fitz new` scaffolds a ready-to-run project: a `fitz.toml` manifest that
depends on `fitz_liveviews`, and a `src/main.fitz` with a working counter. That
one command is your whole setup — no `npm install`, no `package.json`, no build
config.

You get two files:

```
my-counter/
├── fitz.toml         package manifest + the fitz_liveviews dependency
└── src/
    └── main.fitz     the counter: state, render, HTTP, WebSocket, server
```

The manifest pins the framework to a released tag so your builds are
reproducible:

```toml
[package]
name = "my-counter"
version = "0.0.1"
edition = "2026"

[bin]
main = "src/main.fitz"

[dependencies]
fitz_liveviews = { git = "https://github.com/Thegreekman76/fitz-liveviews", tag = "v0.10.0" }
```

---

## 2. Run it

```bash
fitz run
```

You'll see the server bind to port 3000. Open **http://127.0.0.1:3000/** and
click **+1** — the number changes with no page reload. Open your browser's dev
tools → Network → WS and you'll see a single WebSocket connection carrying tiny
JSON frames on each click. That's the whole runtime.

Leave it running; edits are a `Ctrl-C` and `fitz run` away (or use `fitz dev`
for auto-reload).

---

## 3. Read the code, piece by piece

Open `src/main.fitz`. It's four parts. Here they are in the order the data
flows.

### The import

```fitz
from fitz_liveviews import Html, html, live_layout, html_response, LiveFrame, diff_html
```

Six names, and you'll use all of them:

- **`Html`** — the type of a rendered fragment (a string that's been marked as
  safe HTML).
- **`html(...)`** — wraps a template string into an `Html`.
- **`live_layout(...)`** — produces the full HTML document plus the tiny client
  runtime that opens the WebSocket.
- **`html_response(...)`** — turns `Html` into an HTTP `Response`.
- **`LiveFrame`** — the message shape sent over the socket (`html` + `patches`).
- **`diff_html(...)`** — compares two HTML strings and returns the compact
  patch list.

### The state

```fitz
type AppState {
  count: Int = 0
}
```

State is a plain Fitz `type`. It lives **on the server**, one value per
connection. There is no client-side store, no `useState`, no reactivity magic —
the value is just a variable in the WebSocket handler (you'll see it below).
Because it's a typed `type`, the compiler checks every field access.

### The render function

```fitz
fn render(state: AppState) -> Html {
  return html("""<div id="app">
  <h1>my-counter</h1>
  <p>Count: {state.count}</p>
  <button data-flv-click="increment">+1</button>
  <button data-flv-click="decrement">-1</button>
  <button data-flv-click="reset">Reset</button>
</div>""")
}
```

`render` is a pure function: **state in, `Html` out**. Two things to notice:

- **`{state.count}`** — interpolation. The compiler knows `count` is an `Int`
  and type-checks it. Anything user-provided should go through `flv(...)` to
  escape it (more on that in C2); a plain `Int` is safe as-is.
- **`data-flv-click="increment"`** — this is how you wire an event with **zero
  JavaScript**. When the button is clicked, the client runtime sends
  `{"event": "increment"}` over the socket. The attribute name is the whole
  API: `data-flv-click` = "on click, fire this event."

### The initial page (`@get`)

```fitz
@get("/")
fn page() -> Response {
  let initial = render(AppState { count: 0 })
  return html_response(live_layout("/live", "app", initial))
}
```

The first time a browser hits `/`, it gets real HTML — good for load time and
for search engines. `live_layout` takes three things:

1. **`"/live"`** — the WebSocket path the client should connect to.
2. **`"app"`** — the `id` of the element that gets live-updated (matches the
   `<div id="app">` in `render`).
3. **`initial`** — the first render, embedded in the page.

So the page arrives fully rendered, *then* the client opens the socket and
takes over updates. No blank-screen-then-hydrate.

### The live loop (`@ws`)

```fitz
@ws("/live")
async fn socket(ws: WsConn<LiveFrame>) {
  let state = AppState { count: 0 }
  let last_html = render(state).raw
  loop {
    let frame = ws.recv()?
    if (frame.event == "increment") {
      state = AppState { count: state.count + 1 }
    }
    if (frame.event == "decrement") {
      state = AppState { count: state.count - 1 }
    }
    if (frame.event == "reset") {
      state = AppState { count: 0 }
    }
    let new_html = render(state).raw
    let patches = diff_html(last_html, new_html)
    ws.send(LiveFrame { html: new_html, patches: patches })?
    last_html = new_html
  }
}
```

This is the heart of it. Read it top to bottom:

1. **`state`** and **`last_html`** are locals — one copy per connection. This
   *is* your state store.
2. **`loop { ... }`** runs for the life of the connection.
3. **`ws.recv()?`** waits for the next event from that browser. The `?`
   propagates a disconnect cleanly.
4. The **`if` blocks** apply the event to `state`. This is your update logic —
   the equivalent of a reducer, but it's just Fitz.
5. **`render(state)`** produces the new HTML, **`diff_html`** compares it to the
   last one, and **`ws.send`** ships only the patches. The browser applies them
   to the DOM in place — input focus, scroll position, and cursor are
   preserved because only the changed nodes move.
6. **`last_html = new_html`** so the next diff compares against what's on screen.

The event names in the handler (`"increment"`, `"decrement"`, `"reset"`) match
the `data-flv-click` values in `render`. That string is the entire contract
between the button and the server.

### The server

```fitz
@server(3000)
fn main() => 0
```

Binds port 3000. `@get`/`@ws` handlers register themselves; `main` is just the
entry point.

---

## 4. Make a change

Try it. In `render`, add a line under the count:

```fitz
  <p>Doubled: {state.count * 2}</p>
```

Restart (`Ctrl-C`, `fitz run`) or let `fitz dev` reload, refresh the page, and
click. "Doubled" updates alongside "Count" — and because of the diff, only the
two `<p>` elements move, not the whole page.

You just changed the UI by editing a Fitz function. No component re-render
config, no dependency array, no `fetch`.

---

## 5. The same counter, the clean way: a single-file component

The `render` function above works, but writing HTML as a `"""..."""` string —
with `{state.count}` interpolation and, once you have user input, `flv(...)` to
escape it — gets noisy fast. Fitz LiveViews has a second authoring style for
exactly this: the **single-file component** (`.fitzv`), which reads like Vue or
Svelte. Here's the whole counter as one:

```fitz
component Counter {
  state { count: Int = 0 }

  event increment() { count = count + 1 }
  event decrement() { count = count - 1 }
  event reset() { count = 0 }

  <template>
    <div id="counter-app">
      <p>Count: {count}</p>
      <button @click="increment">+1</button>
      <button @click="decrement">-1</button>
      <button @click="reset">Reset</button>
    </div>
  </template>
}
```

Compare it to the string version. Same behavior, but:

- **`state { ... }`** replaces the `type AppState` — the state fields live in the
  component.
- **`event increment() { count = count + 1 }`** replaces the whole `@ws`
  event-ladder. Each handler mutates state directly; the framework re-renders and
  diffs for you.
- **`<template>`** is real markup, not a string. `{count}` interpolates (and
  auto-escapes) with no `flv`, no `.raw`.
- **`@click="increment"`** is the event binding — the same idea as
  `data-flv-click`, just tidier.

The component doesn't run on its own; a small `main.fitz` mounts it. That
wiring is the boilerplate cost of the SFC style:

```fitz
from fitz_liveviews import html_response, live_layout, LiveFrame, diff_html, component, dispatch_component_events
from Counter import Counter, Counter_render, Counter_increment, Counter_decrement, Counter_reset

@get("/")
fn page() -> Response {
  return html_response(live_layout("/live/counter", "counter-app", component("Counter", "root")))
}

@ws("/live/counter")
async fn socket(ws: WsConn<LiveFrame>) {
  let last = component("Counter", "root").raw
  loop {
    let frame = ws.recv()?
    let _ = dispatch_component_events(frame)          // routes the event to the component
    let new_html = component("Counter", "root").raw
    ws.send(LiveFrame { html: new_html, patches: diff_html(last, new_html) })?
    last = new_html
  }
}

@server(3000)
fn main() => 0
```

Notice the `@ws` loop is now generic — `dispatch_component_events(frame)` handles
*any* event the component declares, so you never touch this loop again as the
component grows. (The `from Counter import ...` line has to list each event
handler by its generated name; that's the one rough edge of the style today.)

The complete SFC counter is the
[`examples/counter`](https://github.com/Thegreekman76/fitz-liveviews/tree/main/examples/counter)
project — `Counter.fitzv` plus that `main.fitz`.

### When to use each

| | **String helpers** (`fn render(...) -> Html`) | **SFC** (`.fitzv` component) |
|---|---|---|
| Best for | small pure fragments, one-off pages, gluing things together | anything stateful or reused, real screens |
| HTML | `"""..."""` strings, `flv` / `.raw` / `h_join` | real `<template>`, auto-escaped `{expr}` |
| Events | your own `if frame.event == ...` ladder | `event name() { ... }` + `dispatch_component_events` |
| Setup | one file, zero ceremony | component file + a `main.fitz` wiring |
| Feels like | writing a handler | writing a Vue/Svelte component |

They're **complementary**, not either/or. Real apps use SFCs for the stateful
components and keep a few string helpers around for small formatting bits (a
badge, a date). The rest of this course shows **both** side by side so you can
pick per situation — this chapter's counter in each style is the template.

---

## 6. Build a native binary (optional)

The same program compiles to a standalone binary:

```bash
fitz build
./target/release/my-counter        # my-counter.exe on Windows
```

It serves the **exact same page** — `fitz run` and `fitz build` are bit-for-bit
equivalent. In production you ship one file; no Node, no runtime, no framework
install on the server.

---

## Checkpoint

You should now have:

- [x] A project created with `fitz new --template liveviews`.
- [x] The counter running at `http://127.0.0.1:3000/`, updating live on click.
- [x] A mental model of the four parts: **state** (a `type`), **render**
      (state → `Html`), **`@get`** (initial page), **`@ws`** (the event/diff
      loop).
- [x] One edit of your own (the "Doubled" line) reflected live.

---

## Troubleshooting

!!! failure "`fitz: command not found`"
    The `fitz` binary isn't on your `PATH`. See the
    [install guide](https://thegreekman76.github.io/fitz/curso/m1-setup/c1-instalacion/).

!!! failure "The page loads but clicking does nothing"
    The counter needs the WebSocket. Check the browser dev tools → Network → WS:
    there should be one connection to `/live`. If it's failing, confirm the path
    in `live_layout("/live", ...)` matches the `@ws("/live")` path exactly — they
    must be identical.

!!! failure "`could not resolve dependencies`"
    `fitz new` uses a git dependency, so the first `fitz run` clones the
    framework. You need network access and `git` installed. After the first
    resolve it's cached in `fitz.lock`.

!!! failure "Port 3000 already in use"
    Something else is on 3000. Change `@server(3000)` to another port (e.g.
    `@server(4000)`) and open that instead.

---

## What's next

C1 gave you one component with plain click events. **[C2 — Events, payloads &
forms](c2-events-payloads-forms.md)** adds the two things every real screen
needs: buttons that carry *data* (`data-flv-value-*`) and a live `<form>` that
serializes every field on submit.

Until then, poke at the counter: add a `+10` button (a new event), or a second
independent counter on the same page. If you want to see where this pattern
goes, open the [component gallery](../examples/gallery.md) — every control there
is this same `@ws` loop with more events.
