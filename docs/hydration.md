# Hydration — server-render first, then adopt client-side

The bridge that closes the loop between the two halves of the frontend story. A
**single `.fitzv`** paints on the **server** — fast first paint, indexable, works
with JavaScript off — and then a **client-WASM bundle adopts that exact
server-painted DOM** via `hydrate()` instead of re-creating it. No blank-mount
flash, no framework runtime shipped, **node-for-node adoption** (nothing to
reconcile — unlike React/Next hydration-mismatch warnings). After adoption the
keep-node patch model keeps the DOM alive.

This is the natural next step on top of the [client-WASM](client-wasm.md)
dual-target work: the same component that server-renders becomes interactive
client-side, from one source.

!!! info "Requires Fitz core"
    Hydration landed in Fitz core **v0.31.0** (the `hydrate` marker). The three
    demos on this page are validated against core **v0.41.4** — composition and
    region hydration needed the SSR-side fixes in v0.41.3 / v0.41.4.

## Where hydration fits

| Mode | First paint | Interactivity | Use it for |
| --- | --- | --- | --- |
| **LiveViews (SSR + WS)** | server HTML | server re-renders, diffed over WebSocket | most apps — forms, dashboards, CRUD |
| **[Client-WASM](client-wasm.md)** | blank, then client mount | 100% client-side, no server | offline widgets, zero round-trip |
| **Hydration** | **server HTML**, then **adopted** client-side | client-side from the same source | SEO + fast first paint **and** local interactivity |

## How it works

A component opts in with the **`hydrate` marker** on its root:

```
component App hydrate { ... }
```

The same `App.fitzv` compiles **two ways** from one source:

- `fitz run --bin prerender` (classic) → the **server HTML** that seeds the host
  page's `#app` (the `data-flv-*` attrs + a trailing
  `<script type="application/json" id="__flv_state_App">` state payload).
- `fitz build --bin app --target wasm-client` → the **wasm bundle** whose
  `start()` sees the mount root already has server DOM and calls `App::hydrate(root)`
  instead of `mount()`: it restores the state from the `<script>`, walks the
  existing nodes onto the component's handles (no wipe, no `create_element`),
  wires the listeners — and if the root is empty, falls back to a fresh client
  mount (so the same bundle still works as a standalone SPA).

The marker is **opt-in** so components SSR-rendered for the WebSocket takeover
(whose HTML diff forbids a `<script>` in the LiveView root) stay byte-identical.

---

## 1. Keep-node — a live input, caret preserved

The simplest hydratable shape: a **live control** (`@input` / `@click`) over a
static template. It auto-hydrates and patches **in place**, so typing keeps the
caret. ([`examples/hydration/`](https://github.com/Thegreekman76/fitz-liveviews/tree/main/examples/hydration))

<div class="live-embed">
  <iframe
    src="https://thegreekman76.github.io/fitz-liveviews/live/hydration/"
    title="Live — hydration (keep-node)"
    loading="lazy"
    style="width:100%; height:340px; border:1px solid var(--md-default-fg-color--lightest); border-radius:8px;">
  </iframe>
</div>

```
component App hydrate {
  state { label: Str = "shipping", variant: Str = "primary" }
  event on_label() { label = payload["value"] }
  event toggle()   { if (variant == "primary") { variant = "success" } else { variant = "primary" } }
  <template>
    <span class="flv-badge" data-variant="{variant}"><span class="flv-badge-txt">{label}</span></span>
    <input class="flv-input" @input="on_label" value="{label}" />
    <button class="flv-btn" @click="toggle">toggle colour</button>
  </template>
}
```

**Observe:** the pill reads the **server** state on first paint, not the default;
typing updates it live and **keeps the caret**; the toggle patches the pill's
`data-variant` on the adopted `<span>`.

## 2. Composition — adopt the real `<Badge>`

A `hydrate` tree that composes the actual `src/ui/Badge` companion via a
cross-file `<Child />` import, with interpolated props. The wasm adopts the
composed Badge **across the parent/child boundary**.
([`examples/hydration-composition/`](https://github.com/Thegreekman76/fitz-liveviews/tree/main/examples/hydration-composition))

<div class="live-embed">
  <iframe
    src="https://thegreekman76.github.io/fitz-liveviews/live/hydration-composition/"
    title="Live — hydration of composition"
    loading="lazy"
    style="width:100%; height:360px; border:1px solid var(--md-default-fg-color--lightest); border-radius:8px;">
  </iframe>
</div>

```
from fitz_liveviews.ui.Badge import badge as Badge

component App hydrate {
  state { label: Str = "active", variant: Str = "success" }
  event toggle() { ... }
  <template>
    <Badge label="{label}" variant="{variant}" size="md" />
    <button class="flv-btn" @click="toggle">toggle status</button>
  </template>
}
```

**Observe:** the pill is the **real companion Badge** (its scoped styles + colour
come from `src/ui/Badge.fitzv`); a JS property tagged on the Badge node before
boot **survives** → adopted, not recreated.

!!! note "Naive-composition caveat"
    Composition has no in-place patch model, so hydration = **adopt on boot**
    (no first-paint flash, server nodes preserved). The first state change
    re-renders the tree wholesale. For a preserved caret, keep the live input in
    a keep-node component (demo 1).

## 3. Composition + a region

A `{#for}` list beside the composed Badge, inside the same hydrating tree — both
adopted on boot (the region's items are server-painted between `<!--fr-->`
comment anchors).
([`examples/hydration-composition-regions/`](https://github.com/Thegreekman76/fitz-liveviews/tree/main/examples/hydration-composition-regions))

<div class="live-embed">
  <iframe
    src="https://thegreekman76.github.io/fitz-liveviews/live/hydration-composition-regions/"
    title="Live — hydration of composition + region"
    loading="lazy"
    style="width:100%; height:380px; border:1px solid var(--md-default-fg-color--lightest); border-radius:8px;">
  </iframe>
</div>

```
<template>
  <Badge label="{label}" variant="{variant}" size="md" />
  <ul class="flv-hcard-stages">
    {#for t in tags}
      <li class="flv-hcard-stage"><span class="tn">{t}</span></li>
    {/for}
  </ul>
  <button class="flv-btn" @click="toggle">toggle status</button>
</template>
```

**Observe:** the list is a `{#for}` **region** — its items are server-painted and
**adopted** on boot (not recreated). This unblocks composed
tabs/steppers/accordions that have no live `@input` of their own.

## What hydrates, and the edges

- **Keep-node** (live `@input`/`@change` over a static template): auto-hydrates,
  patches in place, caret preserved. `{#if}`/`{#for}` regions adopt.
- **Composition** (`<Child />` + `<slot>`), opt-in via the `hydrate` marker:
  adopts across the boundary; naive re-render on state change.
- **Regions inside a composition tree** (core v0.41.4): a static `{#if}`/`{#for}`
  adopts (the adopt walk skips the server anchors).
- **Scoped styles** (core v0.41.5): a hydrating component can carry its own
  `<style scoped>` / `<style global>` — the adopt walk skips the server-painted
  style block. Co-locate the CSS with the component, or keep it in the host
  `<head>`. See [Styling & theming](styling.md).
- **Authoring constraints:** dynamic text interpolations are the sole child of
  their element (`<span>{x}</span>`); event bodies stay in the SSR ∩ WASM
  envelope (plain `if`/`else`).
- **Out of scope:** a `<Child/>` **dynamically inside** a `{#for}` (keyed
  reconciliation of composed children) — it clashes with the naive
  wipe-and-rebuild model.

The full server HTML for each demo is generated with `fitz run --bin prerender`
and baked into its `index.html`; regenerate it when you change a template.
