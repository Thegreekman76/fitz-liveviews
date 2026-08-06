---
title: "Write it for the server, run it in the browser: dual-target UI components in Fitz"
published: false
description: The Fitz LiveViews companion UI is server-rendered. But the SAME `.fitzv` component now compiles to WebAssembly and runs in the browser too — icons, forms, charts — with no rewrite and no parallel version. All 38 components dual-target from one source. Here's what it took.
tags: webdev, rust, opensource, frontend
series: FitzLiveViews
cover_image:
canonical_url:
---

> TL;DR — The companion UI ships as **server-rendered** components. But
> the exact same `.fitzv` source now also compiles to **WebAssembly** and
> runs client-side — no rewrite, no hand-maintained "client version". A
> markup component like a `Button` (which renders an SVG icon) and a
> list-driven one like a `Select` (fed `List<FieldOption>`) both go from
> *server-only* to *runs-in-the-browser* by changing the compiler, not the
> component. **38 of 38** components dual-target today; the live gallery
> runs 22 of them. *(Part 9 of the FitzLiveViews series.)*

Part 6 built the companion UI library — ~40 importable components,
server-rendered, styled with scoped CSS, extracted from a real admin app.
Part 8 taught the same `.fitzv` to hydrate: paint on the server, then let
a WASM app adopt the DOM. This part closes a gap between those two: making
the *companion components themselves* run client-side from their exact
server source.

## The usual deal: two versions of every component

Every "isomorphic UI" story eventually hits the same wall. You have a
component that renders on the server. You want it to *also* be interactive
in the browser. In most stacks that means a second implementation — a
client build of the same widget, kept in sync by hand. The server renders
one thing; a JS bundle re-implements it.

Fitz's companion UI started there too: a server-rendered set, plus a
*parallel* hand-written client set for the live gallery. The bet was that
a subset could share one source. It turned out most of it can.

## One source, two backends

A `.fitzv` single-file component is compiled by two backends:

- **SSR** → classic Fitz that builds an HTML string. This is what the
  LiveViews runtime serves and diffs over the WebSocket.
- **client-WASM** (`fitz build --target wasm-client`) → Rust compiled to
  WebAssembly that builds real DOM with `web-sys`, runs in the browser,
  no server.

Same `<template>`, same state, same events. The compiler emits two things
from one file. The question was never *can they share templates* — they
already do. It was: **which real companion components hit a wall on the
WASM side, and why?**

## The three walls (and how they came down)

**1. Markup helpers.** A `Button` renders an icon: `{raw_html(icon(name).raw)}`.
That `icon` helper returns an SVG string wrapped in `Html` (fitz's
newtype over raw markup). Two problems on WASM: interpolating a markup
string into the DOM *escapes* it (you'd see `&lt;svg&gt;` as text), and
the `Html` type didn't exist client-side at all.

Fixed with two pieces. A **raw-HTML sink**: `{raw_html(x)}` injects the
string via `set_inner_html` on the parent instead of an escaping text node
(React's `dangerouslySetInnerHTML` model). And an **`Html` shim**: the
`Html` newtype maps to a tiny generated struct so helpers that return it
transpile. The neat part — on the SSR side the emitter *strips* the
`raw_html(...)` marker (classic interpolation is already raw), so the SAME
source is byte-identical on the server. Write `{raw_html(icon(name).raw)}`
once; it renders unescaped on both ends.

**2. List-driven components.** A `Select` is `{#for o in options}` over a
`List<FieldOption>` — a list of a nominal type — with `{#if o.on}` per
option. The `{#for}` and the field-access condition lowered fine. The wall
was *feeding it data*: passing `<Select options="{opts}" />` (a
`List<nominal>` prop) and seeding `opts: List<FieldOption> = [FieldOption
{ ... }]` (a `List<nominal>` default). Both were primitive-only on WASM.

Fixed by letting a bare state field lower to a `.clone()` for any
non-nullable target — a `Vec<FieldOption>` clones the same as an `i64` —
and by teaching the default emitter to lower a nominal struct-literal.
Now `Select`, `RadioGroup`, and a `BarChart` (fed `List<Bar>`) all render
with real data client-side.

**3. Helper-body list building.** A pager helper does `let out = []; for n
in 1..pages { out.push(n) }`. That range `for` and a `.push` on a *local*
list (not a state field) weren't supported in helper bodies. Small fix,
now they are.

## The sweep: 38 of 38

With those in place, the honest measure: build *every* companion component
to WASM and see what compiles. **16 of the 18 remaining** did with no
changes at all. Adding the earlier markup/list work got us to 36 of 38.

The two that held out were the interesting ones. `Pager` and
`ConfirmDialog` are **controlled** components: their buttons fire
*fall-through* events (`data-flv-click="page_prev"`, `confirm_delete`)
that aren't the component's own events — they bubble up to the parent's
`@ws` loop, which does the real work. A fall-through event had no meaning
in a standalone browser mount with no parent loop.

So we gave it one. A `data-flv-click` whose name isn't a local event now
fires the component's callback slot when a composing parent binds it
(`<Pager @page_prev="..." />`), and is a documented inert no-op when
nobody does (standalone). The view checker was relaxed to accept that
binding when the child *emits* the event via `data-flv-*` — not only when
it declares it. With that, `Pager` and `ConfirmDialog` compile and render
to WASM too: **38 of 38** — one source, server *and* browser.

(Two more residual gaps closed in the same pass: interpolated props into a
`Nullable<T>` target now wrap `Some(...)`, and a `List<nominal>` state
default can omit fields — they fill from the nominal's declared defaults,
byte-accurate with the server.)

## The payoff

The live gallery now runs **22 companion components** compiled to
WebAssembly, in the browser, from their exact server source — badges,
cards, alerts, inputs, a button with a real SVG icon, a select and radio
group fed live options, a bar chart, and now the controlled `Pager` +
`ConfirmDialog`. No parallel client versions. You wrote them for the
server; the compiler made them run in the browser too.

That's the whole pitch of a compiled, isomorphic language: the component
is the component. The runtime is a compiler flag.

*Next: fine-grained reactivity (so a live text input keeps its caret) —
patch-in-place instead of naive re-render.*
