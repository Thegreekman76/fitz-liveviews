# Client-WASM — offline, zero-round-trip widgets

Fitz LiveViews is **SSR-first**: components render on the server and diff over a
WebSocket. But the Fitz core has a second target — it can compile a `.fitzv`
straight to **WebAssembly** that runs entirely in the browser, no server, no
WebSocket. That's what this page is about: the **client-WASM** mode, and when to
reach for it instead of SSR.

!!! tip "▶ See it live"
    The **[live gallery](live-gallery.md)** runs twelve client-WASM components
    in your browser right now — Counter, Toggle, Tabs, Stepper, Rating,
    Accordion, Modal, TodoList, Carousel, Photo, FileUpload, Loader. All of it
    is one ~44 KB (gzipped) bundle, hosted as static files on GitHub Pages.
    Source: [`examples/wasm-gallery/`](https://github.com/Thegreekman76/fitz-liveviews/tree/main/examples/wasm-gallery).

## SSR vs client-WASM — which one?

The two modes solve different problems. Most apps use **SSR** (that's the whole
companion UI). Reach for **client-WASM** only when the interactivity is genuinely
local and you want zero server round-trips.

| | **SSR / LiveView (WS)** | **Client-WASM** |
|---|---|---|
| Where state lives | Server, per-connection | In the browser (Rust in the WASM instance) |
| Network per interaction | A WebSocket round-trip | None — fully local |
| Works offline | No | **Yes** |
| Shared / multi-user state | **Yes** (broadcast, presence) | No — each browser is isolated |
| Database / auth / secrets | **Yes** (server-side) | No |
| Bundle shipped to the client | Zero JS build | A `.wasm` bundle (~12 KB gz per component) |
| Best for | Dashboards, chat, forms, CRUD, anything DB- or auth-driven | Counters, toggles, tabs, steppers, wizards, calculators — purely client-side widgets |

**Rule of thumb:** if the interaction needs the server (data, other users, auth),
it's SSR. If it's a self-contained widget that could run on a static page with no
backend at all, client-WASM gives you native-speed reactivity with no round-trip.

## Sharing source with the SSR kit

A client component used to be a genuinely *separate* file from its SSR twin.
Two core changes closed that gap:

1. **`flv` is an identity passthrough on WASM** (CW.6, core v0.29.2). SSR builds
   an `Html` string with `flv(...)` to escape user data; client-WASM compiles
   the template to real DOM operations (`create_element` / `create_text_node`),
   where a text node escapes **intrinsically**. So `flv(x)` on the WASM target
   lowers to plain `x` — an SSR component authored with `{flv(label)}` +
   `from fitz_liveviews import flv` compiles to `--target wasm-client`
   **unchanged**. (The raw-HTML helpers — `html` / `raw_html` / `h_join` /
   `h_when` / `h_either` — stay SSR-only and hard-error, since a DOM text node
   can't inject unescaped markup.)
2. **The framework import resolves** (CW.8, core v0.29.6). The wasm loader now
   consults the `fitz.toml` dependency registry, so
   `from fitz_liveviews.ui.Badge import badge as Badge` resolves the component
   under the dependency's root and inlines it into your standalone crate — you
   can consume the companion UI as a **library** from an external WASM app.

So a presentational component can now be **one source, two targets**. What still
gates a given SSR component from dual-targeting is the client-side capability
**envelope** below (`{#if}`/`{#for}` shape, event/helper body constructs), not
the import or the escaping. A client component reuses the same **`--flv-*`
design tokens** as the SSR kit — define them once in the host page's `<head>`
(the same values as `src/ui/theme.fitz`), and every component reads them via
`var(--flv-*)`, so client and server widgets look identical.

## Authoring a client component

A client `.fitzv` is the familiar shape — `state`, `event`, `<template>`,
`<style scoped>` — with a client-side capability envelope.

```
component Counter {
  state { count: Int = 0 }

  event increment() { count = count + 1 }
  event decrement() { count = count - 1 }
  event reset() { count = 0 }

  <template>
    <div class="counter">
      <button class="btn" @click="decrement">-</button>
      <span class="value">{count}</span>
      <button class="btn" @click="increment">+</button>
    </div>
  </template>

  <style scoped>
    .btn { background: var(--flv-color-primary, #ce412b); color: #fff; }
    .value { font-weight: 700; }
  </style>
}
```

> **▶ Here it is, running.** The exact `Counter` above, compiled to WebAssembly
> and mounted right here — click it. Every widget in the
> [live gallery](live-gallery.md) is this same shape.

<div class="live-embed">
  <iframe
    src="https://thegreekman76.github.io/fitz-liveviews/live/embed/?c=counter"
    title="Live — Counter (client-WASM)"
    loading="lazy"
    style="width:100%; height:220px; border:1px solid var(--md-default-fg-color--lightest); border-radius:8px;">
  </iframe>
</div>

### What works

- **State**: `Int` / `Float` / `Bool` / `Str`, plus `List<T>` / `Map` and
  **sibling** nominal types (a `type` in a classic `.fitz` next to the component).
- **Control flow**: `{#if cond}` / `{#else}` / `{/if}` and `{#for x in items}` /
  `{/for}`. Conditions can compare (`{#if active == 0}`, `{#if stars >= 3}`); the
  loop iterable can be a bare state field or a call (`{#for c in cards_in(cards, "todo")}`).
- **Event bodies**: assignments to state, comparisons (`x == y`, `n >= 3` —
  since v0.28.2), `if`-as-value on the RHS
  (`qty = if (qty < 10) { qty + 1 } else { qty }`), `let` bindings + local
  reassignment, `match` as a value, range `for` loops (`for n in 1..(max+1)`),
  string interpolation + concatenation (`let id = "{next_id}"`, `a + b`), and
  list ops (`items.push(...)`, `items = items.filter(fn(x) => ...)`, `.map`,
  `.len()`). The last three (match / for / concat) landed in v0.29.5.
- **String methods + logical `and`/`or`** (Fitz core v0.29.8): `.upper()` /
  `.lower()` / `.trim()` / `.contains(x)` / `.starts_with(x)` / `.ends_with(x)` /
  `.replace(a, b)`, and `and` / `or` in expression position — so a
  case-insensitive filter now compiles client-side:
  `names.filter(fn(x) => q == "" or x.lower().contains(q.lower()))`.
  (`.split` / `.to_int`, which return `List` / `Result`, still defer.)
- **Form submit**: `<form data-flv-submit="add">` + `<input name="text" data-flv-clear />`;
  the handler reads `payload["text"]` (guard with `payload.has("text")`), and
  `data-flv-clear` resets the input after submit.
- **Form value events** (`@input` / `@change`, v0.29.7): `<input @input="on_type">`,
  `<select @change="on_pick">`, `<textarea @input="on_edit">` — the handler
  reads the control's live value from `payload["value"]` and writes it to state.
  `@input` fires per keystroke, `@change` on selection/blur. (A live text
  `<input>` re-mounts each keystroke under naive re-render — see the reactivity
  note below.)
- **Click payload**: `<button data-flv-click="pick" data-flv-value-key="{x}">` →
  the handler reads `payload["key"]`.
- **File input** (v0.29.3): `<input type="file" data-flv-file="on_file" accept="image/*">`
  → the handler reads `payload["data"]` (the file as a `data:` URL — drop it into
  `<img src="{img}">` for an instant preview), plus `payload["name"]` and
  `payload["type"]`. Read entirely client-side via the browser's `FileReader`;
  no server, no upload.
- **Attribute interpolation**: full-value (`style="{bar}"`) and **mixed**
  (`style="width: {pct}%"`, `class="toast toast-{kind}"`, v0.29.4) — the literal
  segments interleave with each `{expr}` in a `set_attribute`.
- **Cross-file composition**: `from Card import Card` then `<Card />` — each child
  keeps its own state (that's how the gallery composes twelve widgets into one bundle).
- **Dependency imports** (CW.8, v0.29.6): `from fitz_liveviews.ui.Badge import badge as Badge`
  then `<Badge label="live" />` — pull a companion UI component from a `fitz.toml`
  dependency instead of copying it into your app. (The companion component is
  named `badge` lowercase; alias it to a Capitalized `Badge` so the template
  treats `<Badge />` as a component, not an HTML tag.)

### Gotchas (the view-lexer / wasm-emitter envelope)

These are real limits of today's `.fitzv` → WASM pipeline. Each has a clean
workaround:

| Won't compile | Use instead |
|---|---|
| logical-not `!x` in an event body (only `!=` is lexed) | flip a Bool with `on = on == false` |
| unary negation `-1` in an event body | a non-negative sentinel (e.g. `9` for "none") |
| a helper that returns HTML as a string (`fn stars(...) -> Str` building `<input …>`) | renders as escaped text on WASM — keep that component SSR-only, or build the DOM in the template |
| a state change with no visual variant | render both states with modifier classes via `{#if}{#else}` (e.g. a toggle's `switch-on` / `knob-on`) |

> Two earlier gotchas are now closed: inline `==` / `!=` in an event body or
> closure works since v0.28.2, and `match` / range `for` / local reassignment in
> event & helper bodies work since v0.29.5.

!!! note "Reactivity model"
    Each state mutation re-renders the whole component subtree (naive re-render).
    That's why an element recreated across a `{#if}` doesn't CSS-transition — the
    state is always correct, but cross-render animation isn't available yet.

## Building and deploying

Declare the component as a `[[bin]]` with the `wasm-client` target and a mount
selector (mount is required):

```toml
[[bin]]
name = "counter"
main = "Counter.fitzv"
target = "wasm-client"
mount = "#app"
```

Then build (needs `rustup target add wasm32-unknown-unknown` + `cargo install
wasm-pack`):

```bash
fitz build --bin counter --target wasm-client
```

This emits a `wasm-bindgen` + `web-sys` crate under `target/wasm-build/counter/`,
runs `wasm-pack build --release --target web`, and copies the browser-ready
bundle to `target/wasm/counter/`. Serve it over **HTTP** (ES modules don't load
over `file://`) and mount it:

```html
<div id="app"></div>
<script type="module">
  import init from './pkg/counter.js';
  init();
</script>
```

The gallery's own [`docs.yml`](https://github.com/Thegreekman76/fitz-liveviews/blob/main/.github/workflows/docs.yml)
builds the bundle in CI and publishes it into the GitHub Pages site under
`/live/`, deployed in the same artifact as these docs.

## When *not* to use client-WASM

- You need **shared state** across users, **broadcast**, or **presence** → SSR.
- You need the **database**, **auth**, or **secrets** → SSR (that stays on the server).
- The bundle grows with every component composed into one root; a very large set
  eventually wants separate bundles / lazy loading rather than one mega-bundle.

For everything server-driven, the [companion UI catalog](ui-components.md) is the
home base. Client-WASM is the escape hatch for the genuinely-local corner.
