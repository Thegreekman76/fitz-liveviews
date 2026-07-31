# Client-WASM — offline, zero-round-trip widgets

Fitz LiveViews is **SSR-first**: components render on the server and diff over a
WebSocket. But the Fitz core has a second target — it can compile a `.fitzv`
straight to **WebAssembly** that runs entirely in the browser, no server, no
WebSocket. That's what this page is about: the **client-WASM** mode, and when to
reach for it instead of SSR.

!!! tip "▶ See it live"
    The **[live gallery](live-gallery.md)** runs ten client-WASM components in
    your browser right now — Counter, Toggle, Tabs, Stepper, Rating, Accordion,
    Modal, TodoList, Carousel, Photo. All of it is one ~40 KB (gzipped) bundle,
    hosted as static files on GitHub Pages. Source: [`examples/wasm-gallery/`](https://github.com/Thegreekman76/fitz-liveviews/tree/main/examples/wasm-gallery).

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

## Why client components are a *parallel* set

The companion UI components (`src/ui/`) **cannot** be recompiled to WASM as-is —
they're a genuinely separate set. Two reasons:

1. **The framework import doesn't resolve.** The core's wasm loader is
   sibling-file-only and has no dependency registry, so
   `from fitz_liveviews import flv` resolves to nothing on the WASM target.
2. **Different render model.** SSR builds an `Html` string with `flv(...)` to
   escape user data. Client-WASM compiles the template to real DOM operations
   (`create_element` / `create_text_node`), where a text node escapes
   intrinsically — `flv` isn't needed and doesn't exist.

So a client component is **standalone**: it imports nothing from
`fitz_liveviews`, uses plain `{value}` interpolation (not `{flv(value)}`), and
wires **local** `@click` handlers. To keep it looking identical to the SSR kit,
it reuses the same **`--flv-*` design tokens** — you define them once in the host
page's `<head>` (the same values as `src/ui/theme.fitz`), and every component
reads them via `var(--flv-*)`.

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
- **Event bodies**: assignments to state, `if`-as-value on the RHS
  (`qty = if (qty < 10) { qty + 1 } else { qty }`), `let` bindings, string
  interpolation (`let id = "{next_id}"`), and list ops
  (`items.push(...)`, `items = items.filter(fn(x) => ...)`, `.map`, `.len()`).
- **Form submit**: `<form data-flv-submit="add">` + `<input name="text" data-flv-clear />`;
  the handler reads `payload["text"]` (guard with `payload.has("text")`), and
  `data-flv-clear` resets the input after submit.
- **Click payload**: `<button data-flv-click="pick" data-flv-value-key="{x}">` →
  the handler reads `payload["key"]`.
- **Cross-file composition**: `from Card import Card` then `<Card />` — each child
  keeps its own state (that's how the gallery composes ten widgets into one bundle).

### Gotchas (the view-lexer / wasm-emitter envelope)

These are real limits of today's `.fitzv` → WASM pipeline. Each has a clean
workaround:

| Won't compile | Use instead |
|---|---|
| `!` in an event body (only `!=` is lexed) | flip a Bool with `on = on == false` |
| inline `==` / `!=` in an event body / closure | put the predicate in a sibling `.fitz` (`fn keep(t: Str, x: Str) -> Bool { return x != t }`) and call it |
| unary negation `-1` in an event body | a non-negative sentinel (e.g. `9` for "none") |
| a state change with no visual variant | render both states with modifier classes via `{#if}{#else}` (e.g. a toggle's `switch-on` / `knob-on`) |

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
