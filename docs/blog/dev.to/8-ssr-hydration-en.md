---
title: "Isomorphic hydration in Fitz: first paint on the server, then WASM adopts the DOM"
published: false
description: The same `.fitzv` renders on the server for first paint (works with JS disabled), and the client-WASM runtime then ADOPTS that server-painted DOM instead of throwing it away and re-rendering — state restored from an embedded payload, listeners wired, no wipe, no flash. One source, both ends.
tags: webdev, rust, opensource, frontend
series: FitzLiveViews
cover_image:
canonical_url:
---

> TL;DR — Mark a component `hydrate` and the **same `.fitzv`** does two
> jobs: the server renders it to HTML for a fast first paint (SEO,
> works-without-JS), and on boot the client-WASM runtime **adopts** that
> exact DOM — restoring the serialized state from an embedded
> `<script>`, walking the existing nodes, and wiring the event
> listeners — instead of wiping and rebuilding. No re-render flash, no
> lost DOM identity, no "hydration mismatch" class of bug. *(Part 8 of
> the FitzLiveViews series — the payoff [Part 7](#) promised.)*

Part 7 closed the fullstack loop: a `.fitzv` component calling an `@rpc`
server function, typed end to end. It ended on a promise — *SSR
hydration: the same component rendered on the server for first paint,
then the WASM runtime taking over the existing DOM*. This is that part.

## Why hydration, and why it's usually painful

Server-side rendering gives you the good first paint: the browser shows
real HTML immediately, search engines see content, the page works with
JavaScript disabled. But then the interactive runtime has to *take over*
that page. The naive way — mount the app fresh — throws the
server-painted DOM away and rebuilds it, producing a flash and doing the
work twice. The framework way — reconcile a virtual DOM against the
server HTML — is where "hydration mismatch" warnings come from, and it
ships the whole framework runtime to do it.

Fitz does neither. The WASM runtime **adopts** the exact nodes the
server painted.

## One source, both ends

A `.fitzv` component already compiles two ways: to server HTML (the
LiveViews path) and to a standalone WASM app. Hydration is opt-in with
one marker on the root:

```
component App hydrate {
  state {
    name: Str = "world"
  }

  event on_name() { name = payload["value"] }

  <template>
    <p class="greeting">Hello, <span class="nm">{name}</span></p>
    <input @input="on_name" value="{name}" />
  </template>
}
```

The marker is opt-in so components rendered for the LiveViews
WS-takeover (whose DOM diff forbids a `<script>` in the root) stay
byte-identical. When it's present, both halves cooperate.

## What the server emits

The SSR emitter paints the DOM **and** leaves the client everything it
needs to adopt it:

- The rendered HTML, exactly as the component's template produces it.
- A **state payload** — `<script type="application/json"
  id="__flv_state_App">{"name":"Ada"}</script>` — so the client boots
  with the server's state, not the template defaults.
- **Adoption markers** the client walks by: `<!--fi-->…<!--/fi-->`
  around interpolations in mixed text (`Hello, {name}!`),
  `<!--fr-->…<!--/fr-->` around `{#if}`/`{#for}` regions, a
  `<div class="__fitz-child-Card">` wrapper around a composed child, and
  slot content inlined in the parent's scope.

This is a real render-a-string on the server — not a hand-authored
`index.html`. The server computes `App_render(App { name: "Ada" })` and
that string is what the browser paints and the WASM adopts.

## What the client does on boot

Instead of `mount()` (which wipes the root and builds), a hydratable
component runs `hydrate()`:

1. It sees the mount root already has content.
2. It restores the serialized state from the `<script>` payload —
   primitives, and composite state too (`List<T>`, `Map<Str,V>`,
   nullables, imported nominal types round-trip through JSON).
3. It walks the existing DOM with a cursor (depth-first), mapping each
   element/text/comment node onto the same keep-node handles the build
   walk would have created — **no `create_element`, no wipe**.
4. It wires the `@input`/`@click` listeners onto the adopted nodes.

From there a state change patches in place (keep-node reconciliation),
so the live `<input>` keeps its caret. The page was never rebuilt — it
was taken over.

## It really runs

Verified end-to-end in real Chrome (via Puppeteer), and the test is the
convincing part: a JS property is set on a server-painted node **before**
`init()` runs. After hydration, that property is **still there** — proof
the node was *adopted*, not recreated. The greeting shows `"Ada"` (the
server's state, not the template default `"world"`), typing patches the
text in place, and there are zero page errors. The runnable examples
cover the shapes:
[`hydrate`](https://github.com/Thegreekman76/fitz/tree/main/examples/view/hydrate)
(base),
[`hydrate-mixed`](https://github.com/Thegreekman76/fitz/tree/main/examples/view/hydrate-mixed)
(mixed static+interpolated text),
[`hydrate-regions`](https://github.com/Thegreekman76/fitz/tree/main/examples/view/hydrate-regions)
(`{#if}`/`{#for}`), and
[`hydrate-composition`](https://github.com/Thegreekman76/fitz/tree/main/examples/view/hydrate-composition)
(`<Child />` + slots, adopted across the component boundary).

## Why this is different

Hydration is a solved problem in the JS world — the point is *what it
costs*:

- **React / Next.js** ship the framework runtime to the client and run a
  reconciliation pass to attach to the server HTML; a mismatch between
  the two is a whole category of warnings. Fitz adopts the exact nodes
  by walking them — there's nothing to reconcile and no framework
  runtime to ship.
- **Astro islands / partial hydration** are great, but each island is
  still a JS-framework runtime. Fitz's client is a single compiled WASM
  app that took over the whole server-painted tree.
- **Phoenix LiveView / Hotwire** are server-driven: the "client" is a
  thin JS layer patching the DOM. Fitz's client is a real compiled app
  with its own state — it just *starts* from the server's DOM instead of
  a blank mount.

Same source both ends, node-for-node adoption, opt-in per component,
keep-node patching afterward, zero framework runtime. That combination
is the differentiator.

## The honest edges (MVP)

- Hydration is **opt-in** with the `hydrate` marker (universal
  auto-hydration is a future improvement — opt-in keeps the LiveViews
  path byte-identical).
- Composite state restore is covered; types that don't round-trip
  through JSON (a `Map` with a non-`Str` key, tuples, functions) reset to
  their default on restore, symmetric with the dump.
- Named slots in the SSR emitter and dynamic composition inside a
  `{#if}`/`{#for}` are later slices; the default slot + static
  composition adopt today.

That's the loop the series has been building toward: the server paints
first (fast, indexable, `@rpc`-fed), and the same `.fitzv` — as a WASM
app — takes over that exact DOM and keeps it alive. Next up: the
companion UI library the flagship admin panel is built from — ~40
importable components, extracted from a real app.
