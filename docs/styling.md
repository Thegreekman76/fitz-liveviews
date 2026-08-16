# Styling & theming

CSS in Fitz LiveViews has **three layers**, and you'll usually use all three:

1. **Design tokens** — `--flv-*` CSS variables that define the palette, surfaces,
   borders, radii. Set them once in the host `<head>`; everything reads them.
2. **Scoped styles** — a `<style scoped>` block per component, class-mangled so it
   can't leak or collide.
3. **Global styles** — a `<style global>` block for page-level rules.

No build step, no CSS-in-JS, no `className` gymnastics — plain CSS in your
`.fitzv`, plus a token layer you can re-theme by overriding one variable.

## 1. Design tokens — `--flv-*`

Every companion UI component reads its colours, surfaces and borders from `--flv-*`
CSS variables with a **literal fallback**, e.g. `background: var(--flv-surface,
#fff)`. So a component renders fine with no theme loaded — and including the theme
lets the host **re-skin the whole kit by redefining a variable**.

`fitz_liveviews` ships the default token set as `ui_theme()`:

```
from fitz_liveviews.ui.theme import ui_theme
// ... in your page's <head>:
{ui_theme().raw}
```

That drops a `<style>` block defining the tokens:

```css
:root {
  --flv-color-primary: #ce412b;
  --flv-color-success: #2e7d32;
  --flv-color-danger:  #c62828;
  --flv-color-warning: #ed6c02;
  --flv-color-info:    #1565c0;
  --flv-color-muted:   #8b8b93;
  --flv-surface:   #ffffff;   /* card / input background */
  --flv-surface-2: #f5f5f7;   /* subtle fill */
  --flv-border:    #d9d9e0;
  --flv-text:       #1a1a1a;
  --flv-text-muted: #55555c;
  --flv-radius-md:   8px;
  --flv-shadow-card: 0 6px 20px rgba(0, 0, 0, .12);
}
```

**Re-theme** by redefining any of them *after* `ui_theme()`:

```html
{ui_theme().raw}
<style>:root { --flv-color-primary: #6d28d9; --flv-radius-md: 12px; }</style>
```

The whole companion UI turns purple with rounder corners — no component change.
The tokens carry no strong aesthetic on purpose (a neutral, Radix-style base), so
they're a clean canvas to brand.

## 2. Scoped styles — `<style scoped>`

A component styles itself with a `<style scoped>` block. Its class selectors are
**mangled with a per-component hash** so they can't leak out or collide with
another component's `.card` or `.title`:

```
component badge {
  state { label: Str = "", variant: Str = "muted" }
  <template>
    <span class="pill" data-variant="{variant}">{label}</span>
  </template>
  <style scoped>
    .pill {
      border-radius: 999px; padding: .2rem .6rem;
      background: var(--flv-surface-2, #f5f5f7);
      color: var(--flv-text, #1a1a1a);
    }
    .pill[data-variant="primary"] { background: var(--flv-color-primary, #ce412b); color: #fff; }
  </style>
}
```

Under the hood `.pill` becomes `.pill-badge-c-<hash>` (an FNV hash of the
component + CSS), and the same suffix is added to the `class` in the rendered
HTML. You write plain `.pill`; the scoping is automatic and invisible.

Read the tokens (`var(--flv-*)`) rather than hard-coding colours, so a host
re-theme reaches your component too.

## 3. Global styles — `<style global>`

For page-level rules that *should* be shared (a reset, `body` typography, a
utility class), use `<style global>` — emitted verbatim, not scoped:

```
<style global>
  body { font-family: system-ui, sans-serif; margin: 0; }
  .visually-hidden { position: absolute; width: 1px; height: 1px; overflow: hidden; }
</style>
```

Reach for `global` sparingly — scoped is the default so components stay
self-contained.

## 4. Dark mode

Theming is **per-browser** and lives in `localStorage` — it flips a
`data-theme` attribute on `<html>`, never travels over the WebSocket. The default
`ui_theme()` already ships the dark token overrides:

```css
:root[data-theme="dark"] {
  --flv-surface:   #1e1e22;
  --flv-surface-2: #2a2a30;
  --flv-border:    #3a3a42;
  --flv-text:       #e8e8ea;
  --flv-text-muted: #a0a0a8;
  --flv-shadow-card: 0 6px 20px rgba(0, 0, 0, .5);
}
```

So any component reading `var(--flv-*)` is dark-mode-ready for free. For your own
dark tweaks, mirror the selector:

```css
.badge-ok { background: #e8f5e9; color: #2e7d32; }
:root[data-theme="dark"] .badge-ok { background: #14351f; color: #7ee2a8; }
```

Wire the toggle with the `theme_scripts` helpers (boot + cycle) and the
`ThemeToggle` component:

```
from fitz_liveviews.ui.theme_scripts import theme_boot_script, theme_cycle_script
from fitz_liveviews.ui.ThemeToggle import theme_toggle, theme_toggle_render
```

- `theme_boot_script("my-theme")` — in `<head>`, sets `data-theme` from
  `localStorage` before first paint (no flash of the wrong theme).
- `theme_cycle_script(...)` — near `</body>`, defines `window.flvCycleTheme`
  (light → dark → auto) and paints the toggle button's label.
- `<html data-theme="auto">` — the starting attribute.

The Admin ABM ([examples/admin.md](examples/admin.md)) wires all of this.

## 5. Scoped styles and hydration (v0.41.5)

A component that **hydrates** ([SSR → client](hydration.md)) can carry its own
`<style scoped>` on its root — you don't have to move the CSS to the host
`<head>`. The SSR emitter server-paints the scoped `<style>` inline, the client
build injects it into `<head>` on boot, and the adopt walk **skips** the leftover
server-painted `<style>` so the DOM lines up:

```
component App hydrate {
  state { label: Str = "shipping" }
  event on_label() { label = payload["value"] }
  <template>
    <div class="card"><span class="lbl">{label}</span>
      <input class="inp" @input="on_label" value="{label}" />
    </div>
  </template>
  <style scoped>
    .lbl { font-weight: 700; color: var(--flv-color-primary, #ce412b); }
    .inp { padding: .4rem .6rem; }
  </style>
}
```

Before v0.41.5 this styling had to live in the host page; now it co-locates with
the component. (Only the SSR/LiveView WebSocket path still forbids `<style>` in
the diffed root — that's a protocol constraint, not a hydration one.)

## Rules of thumb

- **Colours, surfaces, radii → tokens.** Read `var(--flv-*, fallback)`; never
  hard-code a hex you'd want to re-theme.
- **Component look → `<style scoped>`.** Self-contained, collision-free.
- **Page reset / shared utilities → `<style global>`.** Sparingly.
- **Dark mode → `data-theme` + token overrides.** Free for token-driven CSS;
  mirror the `:root[data-theme="dark"]` selector for custom rules.
