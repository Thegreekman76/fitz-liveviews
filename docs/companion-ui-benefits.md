# Companion UI — what the refactor actually bought

Phase 9.C refactored the four bundled examples — **Counter**, **Dashboard**,
**Chat** and **Kanban** — to consume the packaged companion UI primitives
(`fitz_liveviews.ui.*`) instead of hand-rolling every `<button>`, form field and
card with local CSS. This page reports what changed, honestly — including where
the payoff is *not* raw lines of code.

It's also the first time the **presentational** primitives (Button / Card /
Badge / Icon / Input) run inside real apps rather than the isolated
[gallery](examples/gallery.md). Dogfooding them surfaced two API gaps (both
fixed) and one Fitz-core limitation (documented). That validation is the real
deliverable of 9.C — "build the kit *as* the examples adopt it, so the API is
proven against real code, not speculation".

## Which primitives each example now uses

| Example | Primitives adopted | Notes |
|---|---|---|
| Counter | `Button`, theme | three actions → `button_render`, `on_click` routes to the component's `@on` handler |
| Dashboard | `Card`, `Icon`, `Badge`, `Button`, theme | each tile is a `Card`; header icon + live `Badge`; `+1`/`reset` are `Button`s |
| Chat | `Card`, `Input`, `Button`, theme | each message is a `Card` (author-escaped); composer = two `Input`s + a submit `Button` |
| Kanban | `Card`, `Icon`, `Input`, `Button`, theme | each card is a `Card` with baked-in `Icon` actions; add-form = two `Input`s + submit `Button` |

`Modal` is **not** exercised by these four — see [What's deferred](#whats-deferred).

## Lines of code — the honest number

The roadmap framed 9.C as "measure the LoC reduction". The real number is
roughly **flat**, and it's worth being precise about why.

| Example | src LoC before | src LoC after | Δ |
|---|--:|--:|--:|
| Counter | 101 | 116 | **+15** |
| Dashboard | 259 | 255 | **−4** |
| Chat | 168 | 200 | **+32** |
| Kanban | 501 | 486 | **−15** |
| **Total** | **1029** | **1057** | **+28** |

Two things move LoC *up*, and they cancel most of the CSS savings:

1. **The examples that had no CSS gain code, not lose it.** Counter and Chat
   started as bare, unstyled markup. Adopting primitives *adds* a themed,
   accessible, XSS-safe UI they didn't have before — so their line count grows
   even though the result is strictly better.

2. **A Fitz-core limitation forces a helper module per example.** A struct
   literal inside a `{...}` template interpolation
   (`{button_render(button { … }).raw}`) passes `fitz check` but **fails at
   `fitz run`** — the SSR emitter doesn't round-trip the nested braces
   (`expected ',' between struct literal fields`). So every primitive used
   *inside* a `.fitzv` `<template>` is hoisted into a thin wrapper fn in a
   sibling classic-Fitz module (`counter_ui.fitz`, `chat_ui.fitz`,
   `board_ui.fitz`, …) and called as a bare ref (`{inc_button().raw}`, the K-4
   pattern the Board already used). Those wrapper modules are ~15–30 LoC each,
   most of it doc comments.

**If the SSR emitter round-tripped nested-brace struct literals, the helper
modules vanish and the total tips clearly negative.** That's a concrete,
well-motivated Fitz-core improvement this refactor surfaced. Until then, the
helper-fn indirection is the price of using a render-fn primitive inside a
component template. (Primitives called from a *classic* `.fitz` render fn —
`render_tile`, `render_card` — are called directly, no wrapper needed.)

### Where the code genuinely shrank: hand-rolled CSS

The clear win is deleting hand-rolled styling that the primitives + `ui_theme()`
now provide (surface, borders, shadows, focus rings, button variants, dark
mode):

| Example | CSS block before | after | Δ |
|---|--:|--:|--:|
| Dashboard (`DASHBOARD_CSS`) | ~84 | ~62 | **−22** |
| Kanban (`KANBAN_CSS`) | ~116 | ~81 | **−35** |

Roughly **−57 lines of CSS** you no longer own, maintain or keep consistent by
hand — and every one of those pixels now follows the user's light/dark theme for
free.

## The wins that aren't line counts

- **Dark mode + theming for free.** Every primitive reads `--flv-*` tokens.
  Dropping `{ui_theme().raw}` into each example gives light/dark theming that the
  original hand-rolled CSS never had.
- **Accessibility baked in.** Buttons get real `type` attributes, inputs get
  labels/hints/error styling, icons carry `aria-label`s — without each example
  reinventing them.
- **XSS-safety by default.** `Card` / `Badge` / `Input` escape their text props
  (`flv(...)`); the Chat refactor renders `<b>world</b>` as visible text, not
  live markup, with zero extra code in the example.
- **Consistency.** One Button look, one Card, one field style across all four
  examples — change the theme once, every example follows.
- **Less surface to get wrong.** The Kanban's three columns collapsed to a single
  `render_card(c)` helper (it derives the available move actions from
  `c.column`), so adding a column or an action is now a one-line change.

## API gaps found by dogfooding — and fixed

Running the primitives in real apps (not the gallery) exposed two gaps. Both are
now shipped:

1. **`Button` couldn't drive a form.** The first real form usage (Chat, Kanban
   add-forms) needs a submit button, but `Button` only emitted `data-flv-click`
   with no `type`. Inside a `<form>` that both submits natively *and* fires an
   empty click. **Fix:** `Button` gained `submit: Bool` — `submit: true` renders
   `type="submit"` and omits `data-flv-click`; the default now renders explicit
   `type="button"` so a click button never accidentally submits a form it sits
   in.

2. **`Input` couldn't be a live-form field.** The `data-flv-submit` form pattern
   needs `required` (client validation) and `data-flv-clear` (empty the field
   after a successful submit — the Chat message box, the Kanban title box).
   **Fix:** `Input` gained `required: Bool`, `clear: Bool` and `autocomplete: Str`.

Both changes are covered by new gallery `@test`s (130 → 132 total).

## Native-build parity

Each refactored example still runs identically under `fitz run` and the
`fitz build` native binary — with one pre-existing exception:

| Example | `fitz run` | `fitz build` (native) |
|---|:--:|:--:|
| Counter | ✓ | ✓ |
| Dashboard | ✓ | ✓ |
| Chat | ✓ | ✓ |
| Kanban | ✓ | ✗ (pre-existing) |

The Kanban has never built to a native binary — its `card.fitz` declares a
`type Board` while `Board.fitzv` compiles to a module named `Board`, and the
Fitz-core codegen can't yet disambiguate a type and a module that share a name
(`E0255 / E0573`). Building the **un-refactored** Kanban from `git HEAD` fails
with the exact same error, so this is a Fitz-core limitation, not a regression
from 9.C. It stays a `fitz run` example (as its README always said); the refactor
preserves that behavior.

## What's deferred

- **`Modal` in a live example.** Its natural fit — a per-card inline editor
  (`CardEditor.fitzv`) — is blocked by the Fitz-core `<Child />`-inside-`{#for}`
  limitation (Phase 11.7 scope), which is exactly why the Board already dropped
  inline edit. A board-level "add card" modal is a UX redesign beyond a refactor.
  `Modal` stays gallery-tested; wiring it into a real example is a good follow-up
  once the composition limitation lifts.

- **`Button` with a per-item payload.** The Kanban's move/delete buttons carry
  `data-flv-value-card_id="{id}"`, and the `Button` primitive can't model a
  per-item `data-flv-value-*` (the attribute *name* is dynamic, which the
  template DSL doesn't interpolate). Those buttons stay hand-rolled — with a
  baked-in `Icon` — and it's an open question whether a future `Button` variant
  should carry a single fall-through value.

- **The SSR nested-brace round-trip** (see above) — the Fitz-core fix that would
  let primitives be called inline in templates and delete the helper modules.

## Bottom line

9.C didn't shrink the examples much — but it made them **themeable, accessible,
XSS-safe and consistent**, deleted ~57 lines of hand-rolled CSS, and — most
importantly — proved the primitives against real apps, shipping two API fixes
and pinning down two concrete follow-ups. That's the companion-UI payoff: not
fewer lines, but *lines you no longer have to design, style and secure yourself*.
