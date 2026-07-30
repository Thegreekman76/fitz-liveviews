# Companion UI — component catalog

A cookbook of the UI components you can build with Fitz LiveViews today.
Every one is **SSR-first** (server-rendered, reactive over a WebSocket),
needs **zero JS build**, and works identically under `fitz run` and the
native binary from `fitz build`.

Most of these are **patterns** built on the [HTML primitives](html.md) and the
[LiveView core](live.md) — you build them in your app. But the three most
reusable — **Pager**, **Toast** and **ConfirmDialog** — plus a **theme** ship as
an importable sub-library (`fitz_liveviews.ui.*`) you can drop straight in
without copying any `.fitzv`. See [Packaged components](#packaged-components)
right below. This page is the reference. Two runnable companions:

- the **[Component gallery](examples/gallery.md)** renders each component **on
  its own** — no database, no auth — so you can lift a single pattern straight
  into your project;
- the **[Admin ABM example](examples/admin.md)** is the full implementation of
  *every* component below working together (a People & Access back-office over
  PostgreSQL, dockerized, internationalized ES/EN).

!!! tip "The two rendering modes"
    - **SSR (static)** — rendered once on a `@get` page. Interactivity that is
      purely client-side (collapse, tabs on a non-live page) can use native
      HTML like `<details>` with **zero JS**.
    - **Live (WS)** — rendered inside a `live_embed(...)` / `live_layout(...)`
      root. User actions fire `data-flv-*` events; the `@ws` handler re-queries
      / re-renders and diff-patches the DOM. State lives per-connection in the
      handler loop.

---

## Packaged components

The kit ships as an importable sub-library. Instead of copying the `.fitzv` into
your project, pull each piece straight from the dependency by dotted sub-path.
Two groups: **stateful** components, one instance per connection (Toast /
ConfirmDialog / Modal — plus the controlled Pager), and **presentational
primitives** (Button / Card / Badge / Alert / Input / Spinner / Icon), plus a
**theme**:

```
from fitz_liveviews.ui.Pager import pager, pager_render
from fitz_liveviews.ui.Toast import toast, toast_render, toast_show, toast_dismiss
from fitz_liveviews.ui.ConfirmDialog import confirm_dialog, confirm_dialog_render, confirm_dialog_ask, confirm_dialog_cancel
from fitz_liveviews.ui.Modal import modal, modal_render, modal_show, modal_close
from fitz_liveviews.ui.Button import button, button_render
from fitz_liveviews.ui.Card import card, card_render
from fitz_liveviews.ui.Badge import badge, badge_render
from fitz_liveviews.ui.Alert import alert, alert_render
from fitz_liveviews.ui.Input import input, input_render
from fitz_liveviews.ui.Spinner import spinner, spinner_render
from fitz_liveviews.ui.icon import icon
from fitz_liveviews.ui.theme import ui_theme
from fitz_liveviews.ui.Breadcrumbs import breadcrumbs, breadcrumbs_render
from fitz_liveviews.ui.shell_types import Crumb, NavItem, NavGroup
from fitz_liveviews.ui.ThemeToggle import theme_toggle, theme_toggle_render
from fitz_liveviews.ui.theme_scripts import theme_boot_script, theme_cycle_script
from fitz_liveviews.ui.Sidebar import sidebar_render
from fitz_liveviews.ui.Topbar import topbar_render, initials_of
from fitz_liveviews.ui.AppShell import app_shell, ui_shell_css, shell_behavior_script
```

They're **i18n-agnostic** (the host passes already-localized text), styled with
`<style scoped>` that reads `--flv-*` theme tokens (with literal fallbacks), and
render identically under `fitz run` and the `fitz build` binary. The
[Admin ABM](https://github.com/Thegreekman76/fitz-liveviews/tree/main/examples/admin)
consumes the app-level components; the [gallery](examples/gallery.md) renders every
piece in isolation.

!!! note "Register once, in your entry file"
    Import each component you use in your project's **entry** file (the one with
    `@server`) so the compiler auto-registers it (`flv_register`). Import `Html`
    from `fitz_liveviews` there too, so the cross-module render-fn signature
    resolves to `Html` and not a degraded `Any`.

### Pager — controlled pagination

Presentational and **controlled**: `page` / `total_pages` are your grid's query
state, not the component's. Render it directly every frame — no per-connection
store:

```
let pager_html = pager_render(pager { page: page, total_pages: total_pages }).raw
```

It declares no event handlers; its buttons fire `page_prev` / `page_next` /
`goto_page` (the numbered button carries `data-flv-value-page="{n}"`), which
**fall through** to your `@ws` loop. You mutate `page`, re-query, re-render.

| field | type | default |
|---|---|---|
| `page` | `Int` | `1` |
| `total_pages` | `Int` | `1` |

### Toast — transient flash

Stateful, one instance **per connection**. Seed it once, drive it with
`dispatch_to`:

```
let toast_html = component_with("toast", cid, toast { }).raw
// ...in the @ws loop:
let _ = dispatch_to("toast", cid, "dismiss", { })          // top of every iteration
let _ = dispatch_to("toast", cid, "show",
    { "message": t(locale, "toast.saved"), "kind": "success" })  // after a save
```

Transient by convention: dispatch `dismiss` at the top of each loop iteration and
`show` in the branch that produced the message, so the flash lives for exactly
one render.

| event | payload | effect |
|---|---|---|
| `show` | `message`, `kind` (`success` / `error` / `info`) | opens with the message |
| `dismiss` | — | closes and clears |

Fields: `open: Bool`, `message: Str`, `kind: Str = "success"`. The × button fires
`dismiss` from inside the component (routed by `dispatch_component_events`).

### ConfirmDialog — confirm / cancel modal

Stateful, one instance **per connection**. **Seed the labels** at init (already
localized) and pass the formatted body in the `ask` payload:

```
let modal = component_with("confirm_dialog", cid, confirm_dialog {
    title: t(locale, "confirm.title"),
    cancel_label: t(locale, "confirm.cancel"),
    confirm_label: t(locale, "confirm.delete")
}).raw
// ...to open it from a toolbar / row button:
let _ = dispatch_to("confirm_dialog", cid, "ask",
    { "ids": selected, "message": confirm_msg(locale, count) })
```

| event | payload | effect |
|---|---|---|
| `ask` | `ids`, `message` | opens; stores `ids` for the host to read back |
| `cancel` | — | closes and clears |

The Cancel button fires `cancel` (handled by the component). The **Delete** button
fires `confirm_delete`, which the component deliberately does **not** declare — it
falls through to your loop, where you read the pending ids
(`component_state("confirm_dialog", cid).ids`), run the delete, then close the
dialog with a `cancel` dispatch.

Fields: `open`, `ids`, `message`, `title` (`"Confirmar"`), `cancel_label`
(`"Cancelar"`), `confirm_label` (`"Eliminar"`).

### Modal — generic dialog

Stateful, one instance **per connection** — a general dialog (unlike ConfirmDialog,
which is specifically confirm / cancel). Seed it, then `show` / `close` it:

```
let dialog = component_with("modal", cid, modal { }).raw
// ...open it, seeding the content in the payload:
let _ = dispatch_to("modal", cid, "show",
    { "title": t(locale, "employee.edit"), "body": form_html })
```

| event | payload | effect |
|---|---|---|
| `show` | `title`, `body` (both optional) | opens; `body` is RAW HTML |
| `close` | — | closes and clears the body |

The × button **and a click on the backdrop** both fire `close`; clicks on the modal
content don't (the backdrop sits behind a `pointer-events: none` wrapper, so
background clicks fall through to it — no JS). `title` is escaped; `body` is RAW HTML
you build in the host. Fields: `open`, `title`, `body`, `close_label` (`"Cerrar"`).

!!! note "Not in this MVP"
    Focus trap and ESC-to-close need client-side JS the SSR path doesn't inject —
    pair the modal with your own global key handler if you need them.

### Button — action button

Presentational: props in, HTML out, no state. A click emits the fall-through event
named by `on_click` (routed to your `@ws` loop, exactly like the Pager's buttons).
Re-render it every frame:

```
let save_btn = button_render(button {
    label: t(locale, "actions.save"), variant: "primary", on_click: "save"
}).raw
```

`disabled` and `loading` both render a real `disabled` attribute so the click can't
fire; `loading` also shows an inline spinner. For a form's submit button, set
`submit: true`: it renders `type="submit"` (and omits `data-flv-click`) so it drives
an enclosing `<form data-flv-submit="…">` instead of firing its own event. A default
button renders explicit `type="button"`, so it never accidentally submits a form it
happens to sit inside.

```
let submit_btn = button_render(button {
    label: t(locale, "actions.send"), variant: "primary", submit: true
}).raw
```

Set `icon` to render an SVG from the [icon set](#icon--svg-icon) before the label.
Leave `label` empty for an icon-only button — pass `aria_label` so assistive tech
still has a name. A fall-through click can carry a `value` payload, read back in your
loop as `payload["value"]` (e.g. the row id an edit/delete button acts on), and
`tooltip` is emitted as `data-tooltip` for your own hover CSS:

```
let del_btn = button_render(button {
    icon: "trash", variant: "ghost", size: "sm",
    on_click: "delete_row", value: "{row.id}",
    tooltip: t(locale, "actions.delete"), aria_label: t(locale, "actions.delete")
}).raw
```

The kit ships no tooltip CSS — style `[data-tooltip]:not([data-tooltip=""])` in the
host so an unset tooltip renders nothing. `value`, `tooltip` and `aria-label` are
always emitted with interpolated values; their empty defaults are inert (an empty
`aria-label` is ignored by AT, an empty `data-flv-value-value` is ignored by your
loop), which is why they don't need an on/off flag.

| field | type | default | notes |
|---|---|---|---|
| `label` | `Str` | `""` | button text (escaped); optional when `icon` is set |
| `variant` | `Str` | `"primary"` | `primary` / `secondary` / `danger` / `ghost` |
| `size` | `Str` | `"md"` | `sm` / `md` / `lg` |
| `on_click` | `Str` | `""` | fall-through click event name (ignored when `submit`) |
| `disabled` | `Bool` | `false` | non-interactive |
| `loading` | `Bool` | `false` | non-interactive + spinner |
| `submit` | `Bool` | `false` | `type="submit"` form button (no `data-flv-click`) |
| `icon` | `Str` | `""` | icon name from the icon set, rendered before the label |
| `value` | `Str` | `""` | click payload → `data-flv-value-value`, read as `payload["value"]` (not on `submit`) |
| `tooltip` | `Str` | `""` | emitted as `data-tooltip` (host styles the hover) |
| `aria_label` | `Str` | `""` | accessible name for icon-only buttons |

### Card — content container

Presentational. `title` is escaped header text; `body` and `footer` are **RAW HTML**
you build in the host, so a card can hold anything (a table, a form, other
components). Header and footer are omitted when empty:

```
let profile = card_render(card {
    title: t(locale, "card.profile"),
    body: profile_html,
    footer: card_actions_html,
    elevation: "md"
}).raw
```

`clickable: true` turns the whole card into a fall-through button firing `on_click`.

| field | type | default | notes |
|---|---|---|---|
| `title` | `Str` | `""` | escaped header text (omitted if empty) |
| `body` | `Str` | `""` | **RAW** HTML body |
| `footer` | `Str` | `""` | **RAW** HTML footer (omitted if empty) |
| `elevation` | `Str` | `"sm"` | `none` / `sm` / `md` / `lg` shadow |
| `clickable` | `Bool` | `false` | whole card is a fall-through button |
| `on_click` | `Str` | `""` | click event name (when `clickable`) |

### Badge — count / status pill

Presentational pill for a count or a short status label:

```
let status = badge_render(badge { label: t(locale, "status.active"), variant: "success" }).raw
let count = badge_render(badge { label: "12", variant: "primary", size: "sm" }).raw
```

| field | type | default | notes |
|---|---|---|---|
| `label` | `Str` | `""` | text or count (escaped) |
| `variant` | `Str` | `"muted"` | `primary` / `success` / `danger` / `info` / `muted` |
| `size` | `Str` | `"md"` | `sm` / `md` |

### Alert — colored callout

Presentational. `title` and `body` are escaped text; the `variant` drives a colored
left accent plus a subtle tint. `dismissible: true` shows an × that fires the
fall-through event named by `on_dismiss` (your loop removes the alert from state):

```
let warn = alert_render(alert {
    variant: "warning", title: t(locale, "alert.disk"), body: t(locale, "alert.disk.body"),
    dismissible: true, on_dismiss: "hide_disk_alert"
}).raw
```

| field | type | default | notes |
|---|---|---|---|
| `variant` | `Str` | `"info"` | `info` / `success` / `warning` / `danger` |
| `title` | `Str` | `""` | escaped title (omitted if empty) |
| `body` | `Str` | `""` | escaped message |
| `dismissible` | `Bool` | `false` | shows a × close button |
| `on_dismiss` | `Str` | `""` | dismiss event name (when `dismissible`) |

### Input — labeled form field

Presentational and **controlled** — its `value` lives in your form, not the
component. Give it a `name` and read it back from the form's `data-flv-submit`
handler (the standard fitz-liveviews form pattern). All attribute values are escaped;
set `error` to switch to the invalid style, otherwise `hint` shows helper text:

```
let email = input_render(input {
    name: "email", label: t(locale, "field.email"), value: form_email,
    input_type: "email", error: email_error
}).raw
```

| field | type | default | notes |
|---|---|---|---|
| `name` | `Str` | `""` | form field name (read from the submit payload) |
| `label` | `Str` | `""` | escaped label (omitted if empty) |
| `value` | `Str` | `""` | current value (host-controlled) |
| `input_type` | `Str` | `"text"` | passes through to the `type` attribute — `text` / `email` / `password` / `number` / `date` / … |
| `placeholder` | `Str` | `""` | escaped placeholder |
| `hint` | `Str` | `""` | helper text (shown when no error) |
| `error` | `Str` | `""` | error message; non-empty ⇒ invalid style |
| `disabled` | `Bool` | `false` | disables the input |
| `required` | `Bool` | `false` | emits `required` for client-side validation |
| `clear` | `Bool` | `false` | emits `data-flv-clear` — the client empties it after a successful submit |
| `autocomplete` | `Str` | `""` | passed through to the `autocomplete` attribute (e.g. `"off"`) |

`required` and `clear` make `Input` a first-class **live-form** field: pair it with a
`<form data-flv-submit="…">` and a submit `Button`, and the client validates on
submit and empties `clear` fields after the server accepts the frame (a chat message
box, a "new item" title box).

### Spinner — loading indicator

Presentational. Indeterminate by default (a rotating ring); pass `progress: 0..100`
for a determinate ring, filled via the `--flv-p` custom property (no client JS):

```
let loading = spinner_render(spinner { size: "md", label: t(locale, "loading") }).raw
let uploaded = spinner_render(spinner { progress: 65, label: "65%" }).raw
```

| field | type | default | notes |
|---|---|---|---|
| `size` | `Str` | `"md"` | `sm` / `md` / `lg` |
| `label` | `Str` | `""` | screen-reader status text |
| `inline` | `Bool` | `false` | `true` sits it on the text baseline |
| `progress` | `Int` | `-1` | `-1` indeterminate; `0..100` determinate |

### Icon — SVG icon set

Stateless: `icon(name).raw` returns a 1em, `currentColor` SVG. Size it with
`font-size`, color it with `color` (the paths use `stroke="currentColor"`). Unknown
names render an empty `<svg>` so a typo degrades gracefully:

```
let trash = icon("trash").raw
```

23 baked-in icons: `check` `close` `plus` `minus` `edit` `trash` `warning` `info`
`success` `download` `upload` `search` `home` `user` `cog` `dashboard` `menu`
`chevron-left` `chevron-right` `chevron-up` `chevron-down` `arrow-left`
`arrow-right`.

### Theme — `--flv-*` tokens

Every packaged component reads `--flv-*` design tokens (with literal fallbacks, so
they render un-themed too). Two ways to theme them:

- **Drop in the default theme** — `{ui_theme().raw}` in your `<head>` defines the
  `--flv-*` tokens for light plus a `[data-theme="dark"]` override.
- **Alias to your own tokens** — if your app already has a design system, map the
  `--flv-*` names to your variables once. Aliasing to `var(--...)` means they
  resolve lazily and follow your theme across every state (this is what the Admin
  ABM does, so the components inherit its light / dark / auto theming):

```css
:root {
  --flv-color-primary: var(--primary);
  --flv-color-success: #16a34a;
  --flv-color-danger:  #ef4444;
  --flv-surface:       var(--surface);
  --flv-surface-2:     var(--surface-2);
  --flv-border:        var(--border);
  --flv-text:          var(--text);
  --flv-radius-md:     8px;
  --flv-shadow-card:   0 10px 30px rgba(0, 0, 0, .25);
}
```

Unit tests for all three live in
[`examples/ui-gallery/tests/components_test.fitz`](https://github.com/Thegreekman76/fitz-liveviews/tree/main/examples/ui-gallery/tests)
(`fitz test` from the gallery).

### Breadcrumbs — navigation trail

The first packaged piece of the **Shell family**. Pass a `List<Crumb>` (from
`fitz_liveviews.ui.shell_types`); every crumb with `href != ""` renders as a
link, and the last hop uses `href == ""` to render as the current page
(`aria-current="page"`, no link). N levels — the trail grows with the list.
Separators are drawn by CSS, so you never interleave separator nodes. It's
controlled/presentational: render it fresh with `breadcrumbs_render(...)`; it
declares no events.

```
from fitz_liveviews.ui.Breadcrumbs import breadcrumbs, breadcrumbs_render
from fitz_liveviews.ui.shell_types import Crumb

let crumbs: List<Crumb> = [
    Crumb { label: "Admin", href: "/" },
    Crumb { label: "Empleados", href: "/empleados" },
    Crumb { label: "Ada Lovelace", href: "" },   // current page
]
let trail = breadcrumbs_render(breadcrumbs { items: crumbs, aria_label: "Ruta" }).raw
```

The widget styles the trail only (colors, separators, wrap); where the bar sits
in your chrome — padding, a bottom border — stays with the host (the Admin ABM
wraps it in a `.crumb-bar`). Props: `items: List<Crumb>` and `aria_label: Str`
(default `"Breadcrumb"`). Styled with `<style scoped>` over `--flv-*` tokens.

### ThemeToggle — light / dark / auto switch

The second Shell-family piece: a per-browser theme switch. It's three cooperating
parts — a button component plus two tiny inline scripts. The theme lives in
`localStorage` and flips `data-theme` on `<html>`; it **never goes over the
WebSocket** (broadcasting it would change the theme for everyone), so the click
runs client-side JS instead of firing a LiveComponent event.

- `theme_toggle_render(theme_toggle { label, aria_label }).raw` — the button
  (`id="flv-theme-btn"`, `onclick="flvCycleTheme()"`). Controlled/presentational,
  no events. `label` is only the SSR-initial text; the cycle script repaints it.
- `theme_boot_script(storage_key).raw` — anti-FOUC `<script>` for `<head>`:
  applies the saved theme before first paint.
- `theme_cycle_script(storage_key, light_label, dark_label, auto_label).raw` —
  `<script>` before `</body>`: defines `flvCycleTheme` (light → dark → auto) and
  paints the button. The `storage_key` must match the boot script.

```
from fitz_liveviews.ui.ThemeToggle import theme_toggle, theme_toggle_render
from fitz_liveviews.ui.theme_scripts import theme_boot_script, theme_cycle_script

// <head>
{theme_boot_script("my-app-theme").raw}

// topbar
{theme_toggle_render(theme_toggle { label: "🖥️ Auto", aria_label: "Theme" }).raw}

// before </body>
{theme_cycle_script("my-app-theme", "☀️ Light", "🌙 Dark", "🖥️ Auto").raw}
```

Props (`theme_toggle`): `label: Str` (default `"🖥️ Auto"`, the SSR-initial text)
and `aria_label: Str` (default `"Theme"`). Labels are embedded into JS
single-quoted strings — pass already-localized text without apostrophes. Styled
with `<style scoped>` over `--flv-*` tokens.

### Sidebar — branded nav rail

The third Shell-family piece: the left rail, built from a **nav data model**. A
`NavGroup` with `label == ""` renders its `items` as flat top-level links; a
named group nests them inside a native `<details>` menu that **auto-opens** when
one of its items is the active screen (zero JS). Leaf links close the mobile
drawer on click. Controlled/presentational — render it fresh each frame; it
declares no events. It's a plain `.fitz` render helper (the two-level
groups→items loop wrapping a `<details>` can't be a flat SSR `{#for}` template).

```
from fitz_liveviews.ui.Sidebar import sidebar_render
from fitz_liveviews.ui.shell_types import NavItem, NavGroup

let nav: List<NavGroup> = [
    NavGroup { items: [NavItem { href: "/", label: "Dashboard", key: "dashboard", icon: "📊" }] },
    NavGroup {
        label: "Organization", icon: "🗂️",
        items: [
            NavItem { href: "/employees", label: "Employees", key: "employees", icon: "👥" },
            NavItem { href: "/departments", label: "Departments", key: "departments", icon: "🏢" },
        ],
    },
]
let sidebar = sidebar_render("My App", "▲", nav, active, "People & Access")
```

`sidebar_render(brand, brand_mark, groups, active, foot) -> Html`. `active`
matches each `NavItem.key`. The `.sidebar` / `.nav-*` chrome — desktop collapse
and the mobile off-canvas drawer — is styled by `ui_shell_css()` (baked by
`AppShell`).

| type | field | default |
|---|---|---|
| `NavItem` | `href`, `label` | — (required) |
| `NavItem` | `key`, `icon` | `""` |
| `NavGroup` | `items` | `[]` |
| `NavGroup` | `label`, `icon` | `""` |

### Topbar — sticky header

The fourth Shell-family piece: the top bar — a drawer/collapse hamburger
(`flvToggleNav()`), the page title, a flexible action cluster, a user chip
(avatar + name), and a trailing slot. `actions` and `user_trail` are
pre-rendered `Html` you compose with your own routes + localized labels
(language switch, theme toggle, logout), so the bar stays app-agnostic.
Controlled — no events.

```
from fitz_liveviews.ui.Topbar import topbar_render, initials_of

let theme_switch = theme_toggle_render(theme_toggle { label: "🖥️ Auto", aria_label: "Theme" }).raw
let actions = html("""<a class="icon-btn lang-btn" href="/lang/en">🌐 ES</a>
  {theme_switch}""")
let logout = html("""<a class="icon-btn" href="/logout" aria-label="Log out">🚪</a>""")
let topbar = topbar_render(title, "Menu", user_name, initials_of(user_name), actions, logout)
```

`topbar_render(title, menu_label, user_name, user_initials, actions, user_trail)
-> Html`. `actions` renders before the user chip, `user_trail` after. The helper
`initials_of(name) -> Str` gives the avatar text (first letter, upper, or `"?"`
for blank) — pass your own for two-letter initials or an image. Styled by
`ui_shell_css()` (the `.topbar` / `.icon-btn` / `.user-chip` chrome).

### AppShell — document layout

The fifth Shell-family piece: the full `<!doctype html>` page. It takes the
already-rendered `sidebar` / `topbar` / `crumbs` / `body` and arranges them,
**baking** the chrome stylesheet (`ui_shell_css()` — tokens + reset + `.sidebar`
/ `.topbar` / `.content` + collapse/drawer responsive) and the drawer/collapse
behavior script. You supply your screen CSS + theme scripts via `head_extra` /
`body_extra`.

```
from fitz_liveviews.ui.AppShell import app_shell

let head_extra = html("""{boot}
  <style>{my_screen_css()}</style>""")            // theme boot script + your CSS
let body_extra = theme_cycle_script("my-app-theme", "☀️ Light", "🌙 Dark", "🖥️ Auto")
let page = app_shell(title, locale, head_extra, sidebar, topbar, crumbs, body, body_extra)
```

`app_shell(title, lang, head_extra, sidebar, topbar, crumbs, body, body_extra) ->
Html`. Pass an empty `html("")` for `crumbs` to skip the breadcrumb bar.
`ui_shell_css()` and `shell_behavior_script()` are exported too, so a bare page
(e.g. a login screen) can inline the chrome tokens without the whole shell.

| arg | type | role |
|---|---|---|
| `title` | `Str` | `<title>` text (escaped) |
| `lang` | `Str` | `<html lang="...">` |
| `head_extra` | `Html` | theme boot script + your screen `<style>` |
| `sidebar` / `topbar` / `crumbs` / `body` | `Html` | rendered pieces |
| `body_extra` | `Html` | theme cycle script + app JS |

---

## Shell — composing the pieces

The Admin ABM's `page_layout` wires the five Shell-family pieces into one
document: it builds the nav model, renders the `Sidebar` / `Topbar` /
`Breadcrumbs`, and hands them to `app_shell`, which bakes the chrome CSS +
drawer/collapse script. The host owns only its **screen** CSS (`admin_css`) +
i18n + routes.

```
fn page_layout(title: Str, active: Str, user_name: Str, body: Html, locale: Str) -> Html {
    let sidebar = sidebar_render("Fitz Admin", "▲", admin_nav(locale), active, t(locale, "app.tagline"))
    let topbar = topbar_render(title, t(locale, "topbar.menu"), user_name,
        initials_of(user_name), topbar_actions(locale), topbar_logout(locale))
    let crumbs = render_breadcrumbs(title, locale)   // wraps packaged Breadcrumbs in .crumb-bar

    let boot = theme_boot_script("flv-admin-theme").raw
    let screen_css = admin_css()
    let head_extra = html("""{boot}
  <style>{screen_css}</style>""")
    let body_extra = theme_cycle_script("flv-admin-theme",
        t(locale, "theme.light"), t(locale, "theme.dark"), t(locale, "theme.auto"))

    return app_shell("{title} · Fitz Admin", locale, head_extra, sidebar, topbar, crumbs, body, body_extra)
}
```

The nav data model (`NavItem` / `NavGroup`) makes the sidebar declarative — the
"Organización" group is one named `NavGroup`, so it renders as a native
`<details>` menu that auto-opens on its child screens:

```
fn admin_nav(locale: Str) -> List<NavGroup> {
    return [
        NavGroup { items: [NavItem { href: "/", label: t(locale, "nav.dashboard"), key: "dashboard", icon: "📊" }] },
        NavGroup {
            label: t(locale, "nav.organizacion"), icon: "🗂️",
            items: [
                NavItem { href: "/empleados", label: t(locale, "nav.empleados"), key: "empleados", icon: "👥" },
                NavItem { href: "/departamentos", label: t(locale, "nav.departamentos"), key: "departamentos", icon: "🏢" },
            ],
        },
    ]
}
```

For a bare page with no shell (e.g. login), skip `app_shell` and inline the
chrome tokens yourself with `ui_shell_css()` + your screen CSS:

```
let boot = theme_boot_script("flv-admin-theme").raw
return html("""<!doctype html><html lang="{locale}" data-theme="auto"><head>
  <title>{flv(title)}</title>{boot}
  <style>{ui_shell_css()}{admin_css()}</style>
</head><body class="login-body">{body.raw}</body></html>""")
```

---

## Auth

### LoginForm

A `@post("/login")` that verifies with `hash.verify`, signs a JWT with
`jwt.encode`, and sets an HttpOnly cookie via `Response { headers }`. The page
posts via `fetch(..., JSON)` (Fitz `@post` deserializes JSON), then redirects.

```
@header(name="cookie")
@post("/login")
async fn login_submit(creds: Credentials, cookie: Str?) -> Response {
    let user = match find_by_email(creds.email).await { Ok(u) => u, Err(_) => return login_failed(...) }
    if (not hash.verify(creds.password, user.password_hash)) { return login_failed(...) }
    let token = jwt.encode({ "email": user.email, "role": user.role }, jwt_secret())
    let set_cookie = session_cookie_name() + "=" + token + "; HttpOnly; Path=/; SameSite=Lax; Max-Age=86400"
    return Response { status: 200, headers: { "Set-Cookie": set_cookie }, body: "{...}" }
}
```

---

## Dashboard

### StatCard

```
fn stat_card(label: Str, value: Int, hint: Str, accent: Str) -> Str {
    return """<div class="stat-card {accent}"><div class="stat-value">{value}</div>
      <div class="stat-label">{flv(label)}</div><div class="stat-hint">{flv(hint)}</div></div>"""
}
```

### BarChart · ProgressBar

Pure CSS bars from ORM counts — zero JS. Scale each bar to the busiest value;
count in Fitz over one `.all(...)`.

```
fn progress_bar(label: Str, value: Int, max: Int, accent: Str) -> Str {
    let pct = match max <= 0 { true => 0, false => (value * 100) / max }
    return """<div class="pbar-row"><div class="pbar-head"><span>{flv(label)}</span>
      <span>{value}/{max} · {pct}%</span></div>
      <div class="pbar-track"><div class="pbar-fill {accent}" style="width: {pct}%"></div></div></div>"""
}
```

### Spinner

!!! tip "Packaged"
    Spinner ships as [`fitz_liveviews.ui.Spinner`](#spinner-loading-indicator) with
    sizes + a determinate mode — import it instead of the inline ring below, which
    is the underlying pattern.

A CSS keyframes ring, used as a small "live" indicator.

```
<span class="spinner"></span>
/* .spinner { border: 2px solid …; border-top-color: var(--primary); animation: spin .7s linear infinite; } */
```

---

## DataGrid

The flagship. A live table over `@ws` where every dimension — search, filters,
sort, pagination, selection, grouping, expand — is a tiny event that re-queries
Postgres server-side and diff-patches the result back to *that* socket only.
Grid state is per-connection in the `@ws` loop.

### Columns · sortable headers

```
fn sort_th(label: Str, col: Str, cls: Str, sort_col: Str, sort_dir: Str) -> Str {
    let arrow = match col == sort_col { true => match sort_dir == "desc" { true => " ▼", false => " ▲" }, false => "" }
    return """<th class="{cls} th-sort" data-flv-click="sort" data-flv-value-col="{col}">{flv(label)}{arrow}</th>"""
}
```

The `sort` event flips `sort_dir` when the same column is clicked again, then
re-queries with a dynamic `.order_by(col, ascending: asc)`.

### Search · filters (pills)

A `<form data-flv-submit="search">` sends the query; filter pills send a
`data-flv-click` event. Each event resets the page and re-queries with chained
`.where` (the ORM ANDs them), `.ilike("%q%")` for search.

### Pagination

The numbered page buttons + prev/next ship as
[`fitz_liveviews.ui.Pager`](#pager-controlled-pagination) — a controlled
component you render with your grid's `page` / `total_pages`. On the query side:
`.limit(PAGE_SIZE).offset(offset)`; the page number rides in the payload and is
parsed with `str.to_int()`.

### Selection · multi-delete

A checkbox per row + a header "select all" (reflects the current page). Selected
ids live as a comma-joined set in the handler; a selection bar shows the count.
Delete opens a **ConfirmDialog**; confirm runs the delete + clears the set.

```
<input type="checkbox" class="row-sel" data-flv-click="toggle_sel" data-flv-value-id="{e.id}"{checked} />
```

### Row actions · Expandable rows

A chevron toggles a detail `<tr>` under the row (department, location, permits +
skills as **chips**). The joins run only for expanded rows. `render_grid` takes
a pre-built `body: Html` so `grid_html` (async) can interleave the detail rows.

### Grouping

A "group by" pill control buckets the filtered rows into collapsible sections
(AG-Grid / Excel style). Collapsed section keys live as a string set; grouping
shows every matching row (no pagination).

### Toolbar · CSV export

Export is a plain `@get("/empleados/export.csv?q={q}&estado={estado}&depto={depto}")`
(a WebSocket can't stream a download) returning
`Response { content_type: "text/csv", headers: Content-Disposition, body }`. It
respects the active filters.

---

## Forms

The rich edit form. All inputs stay in the DOM (even hidden tabs) so a save
serializes every field regardless of the visible tab.

### FormLayout · Input · Textarea · DatePicker

!!! tip "Packaged"
    Input ships as [`fitz_liveviews.ui.Input`](#input-labeled-form-field) with a
    label, hint, error state and escaped attributes — import it instead of
    hand-rolling the `<input>` below, which is the underlying pattern.

```
<div class="form-row"><label>{flv(l_nombre)}</label>
  <input name="nombre" value="{flv(f_nombre)}" placeholder="{flv(ph)}" /></div>
<textarea name="notas" rows="3">{flv(f_notas)}</textarea>
<input name="fecha_ingreso" type="date" value="{flv(f_fecha)}" />
```

### Select · CascadeSelect · GroupSelect · MultiSelect

- **CascadeSelect** — `<select data-flv-change="cascade_pais">`; each change
  re-queries the dependent options server-side, preserving the typed fields.
- **GroupSelect** — `<select>` with `<optgroup>` (e.g. "reports to", colleagues
  grouped by department).
- **MultiSelect** — a checkbox list sharing a `name`; the client joins the
  checked ones comma-separated (`serializeForm`, lib v0.8.0).

### Checkbox · CheckboxGroup · Radio · Rating

- **CheckboxGroup** — a `<fieldset>` per module (permissions).
- **Radio** — status active/inactive.
- **Rating** — a 0-5 star input via radios + the `row-reverse` /
  `input:checked ~ label` CSS trick (no JS). Read-only `★★★☆☆` for display.

### Tabs · Stepper

Both organize a long form and both need **server-tracked active state** (a
LiveView re-render resets any CSS-only selection). The nav buttons opt into
`data-flv-form` (lib v0.9.0) so switching a tab / step carries the typed values.

- **Tabs** (edit) — free navigation between sections.
- **Stepper** (create) — a guided onboarding wizard with a numbered indicator +
  Back / Next / Finish.

```
<button type="button" class="tab-btn{on}" data-flv-form
        data-flv-click="form_tab" data-flv-value-tab="{val}">{flv(label)}</button>
```

### TreeView

A país → provincia → ciudad tree; expand/collapse of each node is a server
event (`toggle_pais` / `toggle_prov`), expanded ids tracked as comma-joined sets.

---

## Feedback

### Modal · ConfirmDialog

!!! tip "Packaged"
    ConfirmDialog ships as [`fitz_liveviews.ui.ConfirmDialog`](#confirmdialog-confirm-cancel-modal),
    and a generic dialog as [`fitz_liveviews.ui.Modal`](#modal-generic-dialog) —
    import them instead of hand-rolling the markup below. The snippet is the
    underlying pattern.

```
<div class="modal-overlay"><div class="modal">
  <h3>{t(locale, "confirm.title")}</h3><p>{confirm_q}</p>
  <div class="modal-actions">
    <button class="btn-clear" data-flv-click="cancel_delete">{t(locale, "confirm.cancel")}</button>
    <button class="btn-danger" data-flv-click="confirm_delete">{t(locale, "confirm.delete")}</button>
  </div></div></div>
```

### Toast / Alert

!!! tip "Packaged"
    Toast ships as [`fitz_liveviews.ui.Toast`](#toast-transient-flash), and a static
    inline callout as [`fitz_liveviews.ui.Alert`](#alert-colored-callout) — import
    them instead of the inline snippet below, which is the underlying pattern.

A transient flash after a save / delete. It lives for exactly one render — the
handler clears it at the top of the loop, so any next event dismisses it.

```
let toast = match flash == "" { true => "", false => """<div class="toast toast-{flash_kind}">
  <span>{flv(flash)}</span><button class="toast-x" data-flv-click="dismiss_flash">×</button></div>""" }
```

### Badge · CountBadge · Chip

!!! tip "Packaged"
    Badge ships as [`fitz_liveviews.ui.Badge`](#badge-count-status-pill) with color
    variants + sizes — import it instead of hand-rolling the pill below, which is the
    underlying pattern.

```
<span class="badge badge-ok">{t(locale, "badge.active")}</span>   <!-- status -->
<span class="grp-count">{n}</span>                                <!-- count -->
<span class="chip">{flv(label)}</span>                            <!-- tag -->
```

### Tooltip · Divider · ExpansionPanel

- **Tooltip** — CSS-only, driven by `data-tooltip` (`[data-tooltip]::after`).
- **Divider** — `<hr class="divider">`.
- **ExpansionPanel** — native `<details>`/`<summary>`, zero JS (great on SSR
  pages that don't re-render live).

---

## Internationalization

Every component takes a `locale` and translates through `t(locale, key)` — see
the [Admin ABM](https://github.com/Thegreekman76/fitz-liveviews/tree/main/examples/admin)'s
`i18n.fitz`. The live socket reads the locale from the handshake cookie with
`@header(name="cookie") @ws(...)` (Fitz core v0.28.0), so the grid + form
translate ES/EN with no client-side handshake.

---

## Where to go next

- **[Admin ABM](https://github.com/Thegreekman76/fitz-liveviews/tree/main/examples/admin)**
  — the complete, runnable reference for every component above.
- **[HTML primitives](html.md)** · **[LiveViews](live.md)** — the foundations
  these are built on.
- Per-component standalone examples + an interactive playground are the next
  step of the adoption package.
