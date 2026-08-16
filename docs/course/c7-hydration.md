# C7 — Hydration: server-render first, then adopt client-side

**Prerequisite:** a machine set up for client-WASM builds — `rustup target add
wasm32-unknown-unknown`, `cargo install wasm-pack`, and the `fitz` CLI
(v0.41.4+). Reading [C1](c1-first-live-component.md) helps; this chapter is
otherwise self-contained.

**Objective:** build a component that **paints on the server** (fast first paint,
works with JavaScript off) and then a WebAssembly bundle **adopts that exact DOM**
client-side — from one `.fitzv`. You'll see the server HTML, the adopt on boot,
and interactivity with a preserved caret.

**Why it matters:** the whole course so far was **SSR** — the server renders and
diffs over a WebSocket ([C1–C6](index.md)). [Client-WASM](../client-wasm.md) is
the opposite — 100% in the browser, blank first paint. **Hydration is both**: the
server paints first (SEO, no flash), then the same component becomes interactive
locally with no round-trip. It's the bridge between the two halves of the
frontend story, and it costs you one keyword.

> Reference page: [Hydration (SSR → client)](../hydration.md) — the capability
> and the three live demos. This chapter builds the first one from scratch.

## 1. The idea, in one picture

```
  server                          browser
  ──────                          ───────
  App.fitzv ──fitz run──▶  <div id="app"> …server HTML… </div>   ① first paint (no JS)
                          + <script id="__flv_state_App">{…}</script>
  App.fitzv ──fitz build─▶  app.wasm  ──init()──▶  App::hydrate(#app)   ② adopt, don't rebuild
                                                    · restore state from the <script>
                                                    · walk the existing nodes (no create_element)
                                                    · wire the listeners
```

**Two compilations, one source.** The same `App.fitzv` becomes the server HTML
*and* the wasm bundle that adopts it. If the mount root is empty (no server HTML),
`start()` falls back to a fresh client mount — so the bundle still works as a
standalone SPA.

## 2. Create the project

```sh
mkdir hydration-demo && cd hydration-demo
```

We'll write four files: the component, a manifest with **two** bins, a tiny
prerender program, and the host page. Start with the component.

`App.fitzv`:

```
component App hydrate {
  state {
    label: Str = "shipping"
  }

  event on_label() { label = payload["value"] }
  event reset()    { label = "shipping" }

  <template>
    <div class="card">
      <p class="greeting">Label: <span class="lbl">{label}</span></p>
      <label class="row">
        <span>Type a label</span>
        <input class="inp" @input="on_label" value="{label}" placeholder="type here" autocomplete="off" />
      </label>
      <button class="btn" @click="reset">reset</button>
    </div>
  </template>
}
```

### The `hydrate` marker

`component App hydrate { … }` — the marker after the name is the whole opt-in. It
tells the **SSR emitter** to append a `<script type="application/json"
id="__flv_state_App">` state payload to the server HTML, so the wasm has the
state to restore on boot. It's opt-in because components rendered for the
WebSocket takeover (C1–C6) forbid a `<script>` in their diffed root — those stay
byte-identical.

### The shape rules

This is a **keep-node** component: a live control (`@input`) over a static
template. Two authoring rules make the adopt line up 1:1 with the server DOM:

- **Sole-child interpolations.** A dynamic `{label}` is the *only* child of its
  element (`<span class="lbl">{label}</span>`), so the server text node maps
  cleanly onto the adopt walk. That's why the label is wrapped in its own
  `<span>`, not written inline as `Label: {label}`.
- **No `<style scoped>` on the hydrating root.** A scoped block would be emitted
  as the first child of the mount root and the adopt walk would map the template
  root onto it. Styling goes in the host page's `<head>` (next section).

## 3. The manifest — two bins from one file

`fitz.toml`:

```toml
[package]
name = "hydration-demo"
version = "0.1.0"
edition = "2026"

[dependencies]
fitz_liveviews = { path = "../.." }   # or your dependency line

[[bin]]
name = "app"
main = "App.fitzv"
target = "wasm-client"   # the browser bundle that ADOPTS the DOM
mount = "#app"

[[bin]]
name = "prerender"
main = "prerender.fitz"  # prints the server HTML
```

Same `App.fitzv`, two targets: `app` (wasm-client) and — through `prerender` — the
SSR emitter.

## 4. Generate the server HTML

`prerender.fitz`:

```
from fitz_liveviews import flv_register
from App import App, App_render, App_on_label, App_reset

let state = App { label: "Ada" }
print(App_render(state).raw)
```

`from App import App_render` compiles `App.fitzv` through the **SSR emitter** and
`App_render(state).raw` prints the exact server HTML. The state is
`App { label: "Ada" }` — **deliberately different** from the component default
`"shipping"` — so on boot you can prove the wasm restored state from the
`<script>`, not the default.

```sh
fitz run --bin prerender
```

You'll see the `<div class="card">…</div>` with `data-flv-*` attributes and a
trailing `<script type="application/json" id="__flv_state_App">{"label":"Ada"}</script>`.
Copy that output — it's the `#app` content in the next step.

## 5. The host page

`index.html` — the `--flv-*` design tokens + component CSS in `<head>`, the
server HTML pasted into `#app`, and a module script that boots the wasm:

```html
<!doctype html>
<html>
  <head>
    <meta charset="utf-8" />
    <style>
      :root { --flv-color-primary: #ce412b; --flv-surface: #fff; --flv-text: #1a1a1a; }
      .card { display: flex; flex-direction: column; gap: .6rem; max-width: 22rem; }
      .inp  { padding: .4rem .6rem; }
    </style>
  </head>
  <body>
    <div id="app">
      <!-- PASTE the `fitz run --bin prerender` output here (verbatim) -->
    </div>
    <script type="module">
      // Tag a node BEFORE boot. If the wasm ADOPTS (not recreates), it survives.
      const span = document.querySelector('#app .lbl');
      if (span) span.__hydrationWitness = 'server-node';

      import init from './pkg/app.js';
      await init();
    </script>
  </body>
</html>
```

The `__hydrationWitness` line is a trick to *see* the adoption: we tag the label
node before the wasm boots. If hydration reused it (rather than re-creating it),
the property is still there afterwards.

## 6. Build and run

```sh
fitz build --bin app          # → target/wasm/app/, mirror app.js + app_bg.wasm to ./pkg/
python -m http.server 8000    # then open http://localhost:8000
```

Serve over HTTP (ES modules need an origin — `file://` won't do).

Live version of this exact demo:

<div class="live-embed">
  <iframe
    src="https://thegreekman76.github.io/fitz-liveviews/live/hydration/"
    title="Live — hydration (keep-node)"
    loading="lazy"
    style="width:100%; height:340px; border:1px solid var(--md-default-fg-color--lightest); border-radius:8px;">
  </iframe>
</div>

**What you should see:**

- The label reads **"Ada"** on first paint — the *server* state, not the default
  `"shipping"`. The wasm restored it from the `<script>`.
- In the console: `document.querySelector('#app .lbl').__hydrationWitness` is
  still `'server-node'` → the node was **adopted, not recreated**.
- Typing in the input updates the label live and **keeps the caret** (keep-node
  patches the adopted node in place). **reset** restores `"shipping"`.

## 7. Go further — hydrate a composition

The reference page has two more demos you can read the same way:

- [`examples/hydration-composition/`](https://github.com/Thegreekman76/fitz-liveviews/tree/main/examples/hydration-composition)
  — a `hydrate` tree that composes the **real `src/ui/Badge`** via a cross-file
  `<Child />` import; the wasm adopts the composed Badge across the parent/child
  boundary.
- [`examples/hydration-composition-regions/`](https://github.com/Thegreekman76/fitz-liveviews/tree/main/examples/hydration-composition-regions)
  — the same, plus a `{#for}` region whose list items are adopted from the
  server.

Composition hydrates **naively**: it adopts on boot (no flash), but the first
state change re-renders the tree wholesale — so its interaction is a `@click`
toggle, not a live `@input`. Keep live text inputs (with a preserved caret) in a
keep-node component like the one you just built.

## Checkpoint

You should now have:

- An `App.fitzv` with a `hydrate` marker that compiles two ways.
- A page whose `#app` is server-painted HTML (works with JS off) and whose wasm
  bundle **adopts** it on boot — the label reads the server state, the tagged
  node survives, and the input keeps its caret.

You understand the whole loop: `fitz run --bin prerender` for the server HTML,
`fitz build --bin app` for the adopting bundle, and the `hydrate` marker as the
one-keyword opt-in.

## Troubleshooting

- **The label shows the default, not the server value.** The `<script
  id="__flv_state_App">` payload isn't in `#app`, or you pasted the prerender
  output without it. Re-run `fitz run --bin prerender` and paste the *whole*
  output (the `<script>` is the last line).
- **The witness is gone / the input flashes on boot.** The wasm fresh-mounted
  instead of adopting — usually the mount root was empty (no server HTML pasted),
  so `start()` fell back to `mount()`. Paste the server HTML into `#app`.
- **`view emit error: … sole child …` or the adopt is misaligned.** A dynamic
  `{expr}` isn't the only child of its element. Wrap it: `<span>{expr}</span>`.
- **`view emit error: … <style scoped> …`** on the hydrating root. Move the styles
  to the host page's `<head>`; the hydrating root ships no scoped block.
- **404 on `./pkg/app.js`.** `fitz build --bin app` lands the bundle in
  `target/wasm/app/`; copy `app.js` + `app_bg.wasm` next to `index.html` under
  `./pkg/` (that's what the examples' `build.sh` does).

## What's next

That's the client-side capstone. You've now seen all three rendering modes:

- **SSR / LiveView** — server state, WebSocket diffing (**C1–C6**).
- **[Client-WASM](../client-wasm.md)** — 100% local, offline widgets.
- **Hydration** — server first paint **and** local interactivity, from one source.

Where to go from here:

- **[Hydration reference](../hydration.md)** — the three live demos and the full
  list of what hydrates (keep-node, composition, regions) and the edges.
- **[Component gallery](../examples/gallery.md)** — every control on one page.
- **[Admin ABM](../examples/admin.md)** — the flagship, for the full SSR stack.
