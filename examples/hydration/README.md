# SSR → client hydration (Phase 11)

The bridge that closes the loop between the two halves of the Fitz LiveViews
frontend story. **One `.fitzv`** paints on the **server** (fast first paint,
indexable, works with JS off) and then a **client-WASM bundle adopts that exact
server-painted DOM** via `hydrate()` instead of re-creating it — no blank-mount
flash, no framework runtime shipped, node-for-node adoption (nothing to
reconcile, unlike React/Next hydration-mismatch warnings). After adoption, the
keep-node patch model keeps the DOM alive, so the live `<input>` keeps its
caret.

This is the natural next step on top of the CW.6–CW.8 dual-target work: a
companion-flavoured, interactive component that is **server-rendered first** and
**then becomes interactive** from a single source.

> **Requires Fitz core ≥ v0.31.0** (the `hydrate` marker; this example is
> validated against v0.41.2).

## What's here

```
examples/hydration/
├── App.fitzv       # the component — `component App hydrate { ... }`
├── fitz.toml       # [[bin]] app (wasm-client) + [[bin]] prerender (classic) + fitz_liveviews path dep
├── prerender.fitz  # prints App_render(state).raw → the server HTML that seeds #app
├── index.html      # host page: --flv-* tokens + server-painted #app + boot <script>
├── build.sh        # fitz build --bin app → wasm bundle → mirror to ./pkg/
└── README.md       # this file
```

## The two compilations of one source

`App.fitzv` compiles **two ways** from **one** source:

| Compilation | Command | Produces |
| --- | --- | --- |
| **SSR** (server first paint) | `fitz run --bin prerender` | the `<div class="flv-hcard">…</div>` + the `<script>` state payload that seeds `index.html`'s `#app` |
| **client-WASM** (adopting bundle) | `fitz build --bin app` | `pkg/app.js` + `app_bg.wasm` — the bundle that adopts the server DOM on boot |

The `prerender` bin imports `App_render` from `App.fitzv` through the SSR
emitter, so its output already carries the `data-flv-*` attrs (fitz-liveviews'
WS-takeover binds to them — **inert** to the wasm adopt walk) and the trailing
`<script type="application/json" id="__flv_state_App">` state payload.

## The `hydrate` marker

`component App hydrate { … }` — the marker is **SSR-side only**: it tells the SSR
emitter to append the `<script>` state payload so the server HTML carries the
state the wasm restores on boot. It is **opt-in** so components SSR-rendered for
the WS-takeover (whose HTML diff forbids `<script>` in the LiveView root) stay
byte-identical. On the wasm side the component already auto-hydrates (it is
keep-node, region-free), so the marker adds nothing to the wasm output.

The generated `start()`:

1. Resolves the mount root (`#app`).
2. If the root **already has server-painted DOM** → `App::hydrate(root)`:
   restore state from the `<script>`, walk the existing nodes onto the keep-node
   handles (no wipe, no `create_element`), wire the listeners, mark built.
3. If the root is **empty** → fresh client `mount()` (still works as a
   standalone SPA).

## Build & serve

```sh
./build.sh --serve            # build wasm, mirror to ./pkg/, serve on :8000
# or, step by step:
fitz build --bin app          # → target/wasm/app/, mirrored to ./pkg/ by build.sh
python -m http.server 8000    # then open http://localhost:8000
```

If you change `App.fitzv`'s **template**, regenerate the server HTML and paste it
back under `<div id="app">…</div>` in `index.html`:

```sh
fitz run --bin prerender
```

## What to observe

- The pill reads **"priority"** on first paint (server HTML) and **stays
  "priority"** after the wasm boots — the state was restored from the
  `<script>`, not reset to the component default `"shipping"`.
- `index.html` tags the pill's text node with a JS property **before** calling
  `init()`. After hydration the property is still there → the node was
  **adopted, not recreated**.
- Typing in the input updates the pill live and **keeps the caret** (keep-node
  patch over the adopted `<input>`).
- **toggle colour** flips `variant` → the pill's `data-variant` attribute is
  patched on the adopted `<span>` and the CSS re-colours it.

Headless-Chrome validated: 9/9 (boot · state restore · adoption witness · live
patch · caret preserved · variant patch · label preserved · no page errors) plus
no horizontal overflow at 320px.

## Constraints (core slice-1) & honest edges

- Hydration is gated to **keep-node, region-free** components (a live
  `@input`/`@click` over a static template — no `{#if}`/`{#for}`), and dynamic
  text interpolations must be the **sole child** of their element
  (`<span>{label}</span>`) so the server text nodes map 1:1 onto the adopt walk.
  That is why the pill wraps its text in its own `<span>`.
- **No `<style scoped>`** on the hydrating component: a scoped block is emitted
  as the first child of the mount root and the adopt walk would map the template
  root onto it. Styling lives in `index.html`'s `<head>` with the same `--flv-*`
  tokens (the same pattern the core `examples/view/hydrate/` uses).
- The event body stays in the **intersection of the SSR + WASM envelopes**: a
  plain `if`/`else` (not `match`, which compiles to WASM but the SSR walker
  defers) — the component must render on both targets.
- **Controlled-input nuance**: keep-node patches an `<input>`'s value via
  `setAttribute`, which a browser won't apply over a value the user has typed.
  The `toggle` button therefore patches a `data-variant` attribute on a
  **non-input** `<span>` (where `setAttribute` works cleanly). Property-level
  input binding is part of fine-grained reactivity (core Phase 11.10).

## Later slices

Cross-file `<Badge>` composition + `{#if}`/`{#for}` regions in the hydration
path (the core `hydrate-composition` / `hydrate-regions` examples show they work
on the core side) are natural follow-ups: a parent that composes an actual
`src/ui/*` companion primitive and hydrates it.
