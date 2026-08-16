# SSR → client hydration of composition (with the real Badge)

The next slice on top of [`../hydration/`](../hydration/): that demo hydrated a
single keep-node component styled to *look* like the companion UI. This one
composes the **actual `src/ui/Badge.fitzv` primitive** via a cross-file
`<Child />` import (CW.8) inside a `component App hydrate` tree — the **same
source** server-renders (Badge included, with its `<style scoped>` +
`{flv(...)}`) and then the client-WASM bundle **adopts** that server-painted DOM
**across the parent/child boundary**.

> **Requires Fitz core ≥ v0.41.3.** SSR-composing a cross-file `<Child />`
> through the classic loader (what `fitz run --bin prerender` uses) landed there;
> before it, `App_render` couldn't resolve an imported companion — only the wasm
> target could. Client-WASM composition (CW.8) + hydration-of-composition
> (v0.31.0) were already there.

## What's here

```
examples/hydration-composition/
├── App.fitzv       # `component App hydrate` composing `from fitz_liveviews.ui.Badge import badge as Badge`
├── fitz.toml       # [[bin]] app (wasm-client) + [[bin]] prerender + fitz_liveviews path dep
├── prerender.fitz  # prints App_render(state).raw → the server HTML (Badge composed)
├── index.html      # host page: --flv-* tokens + server-painted #app + boot <script>
├── build.sh        # fitz build --bin app → wasm bundle → mirror to ./pkg/
└── README.md       # this file
```

## The two compilations of one source

| Compilation | Command | Produces |
| --- | --- | --- |
| **SSR** | `fitz run --bin prerender` | the card HTML with the composed `<div class="__fitz-child-Badge">…</div>` + the `<script>` state payload |
| **client-WASM** | `fitz build --bin app` | `pkg/app.js` + `app_bg.wasm` — adopts the server DOM (Badge inlined) on boot |

Both compile the **same** `App.fitzv`, which composes the **same** `src/ui/Badge`.

## Build & serve

```sh
./build.sh --serve            # build wasm, mirror to ./pkg/, serve on :8000
# regenerate the server HTML when App.fitzv's template changes:
fitz run --bin prerender      # paste the output under <div id="app"> in index.html
```

## What to observe

- The pill is the **real companion Badge** — its scoped `.flv-badge` styles and
  `data-variant` colouring come from `src/ui/Badge.fitzv`, not hand-written CSS.
- On first paint (server HTML) it reads **"paused"** in the muted colour — the
  server state, restored from the `<script>`, **not** the component default
  `"active"` (green). Proof the wasm restored state, not reset to default.
- `index.html` tags the Badge's node with a JS property **before** `init()`.
  After boot the property survives → the composed Badge was **adopted across the
  boundary, not recreated**.
- **toggle status** flips the state → the tree (Badge included) re-renders and
  the pill switches `active`↔`paused` / green↔muted.

Headless-Chrome validated 7/7 (boot · state restored · cross-boundary adoption
witness · child scoped `<style>` preserved · toggle re-render · toggle back · no
page errors) + no horizontal overflow at 320px.

## Naive-composition caveat

Composition has **no in-place patch model** (core hydrate-composition, v0.31.0),
so hydration here means: **adopt + wire on boot** (no first-paint flash, server
nodes preserved). The **first** state change re-renders the tree wholesale — that
is when the restored state and the naive-rebuilt Badge become visible. That is
why the interaction is a `@click` toggle, not a live `@input` (a live text input
with a preserved caret belongs in the keep-node [`../hydration/`](../hydration/)
demo).

## Constraints (carried from the core)

- Dynamic text interpolations are the **sole child** of their element; the
  hydrating root ships **no `<style scoped>`** (styling in the host `<head>`).
  The composed **child** Badge *does* ship a scoped `<style>` — that hydrates
  fine (the adopt walk handles the child's leading `<style>`).
- Event bodies stay in the **SSR ∩ WASM envelope** (plain `if`/`else`).
- Cross-file `<Badge>` + interpolated props (`label="{label}"`) both work here;
  `{#if}`/`{#for}` regions **inside** a hydrating composition tree are a later
  slice.
