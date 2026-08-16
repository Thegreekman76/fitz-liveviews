# SSR → client hydration of composition + a region

Builds on [`../hydration-composition/`](../hydration-composition/): that demo
composed the real `src/ui/Badge` but had no regions. This one adds a `{#for}`
list next to the composed Badge, inside the same `component App hydrate` tree.
On boot the WASM bundle **adopts the whole server-painted DOM** — the composed
`<Badge>` **and** the region's list items — instead of recreating it.

> **Requires Fitz core ≥ v0.41.4.** A naive (composition) component with an
> explicit `hydrate` marker can now adopt a static `{#if}`/`{#for}` region: the
> adopt walk skips the cursor past the region's server-painted
> `<!--fr-->`/`<!--/fr-->` anchors (the SSR emitter writes them inside the
> hydratable child). Before it, this shape aborted with a "naive-region adopt
> not supported" error.

## Build & serve

```sh
./build.sh --serve            # build wasm, mirror to ./pkg/, serve on :8000
fitz run --bin prerender      # regenerate the server HTML when the template changes
```

## What to observe

- The pill is the real companion `<Badge>`; the list below it is a `{#for}`
  **region**. Both are server-painted, and both are **adopted** on boot (a JS
  property tagged on the Badge node before `init()` survives).
- On first paint the state reads the **server** values (`idle` / muted / a
  `clone`,`test` list), **not** the component defaults (`active` / success /
  `build`,`deploy`,`verify`) — proof the wasm restored state from the `<script>`.
- **toggle status** re-renders the tree (naive) — the Badge flips colour and the
  region rebuilds from state.

Headless-Chrome validated 7/7 (boot · Badge state restored · composed Badge
adopted across the boundary · `{#for}` region adopted from the server · toggle
re-render · region survives re-render · no page errors).

## Scope

- The region holds **plain items** and the composed `<Badge>` sits **outside**
  the loop. A `<Child/>` **dynamically inside** a `{#for}` (keyed reconciliation
  of composed children) is still out of scope — it hits a clear error and is a
  separate, larger slice (it clashes with the naive wipe-and-rebuild model).
- Naive-composition caveat (unchanged): hydration wins the **first paint**; the
  first state change re-renders the tree wholesale. For a preserved caret in a
  live text input, use the keep-node [`../hydration/`](../hydration/) demo.
