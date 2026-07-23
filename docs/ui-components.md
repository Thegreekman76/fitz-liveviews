# Companion UI — component catalog

A cookbook of the UI components you can build with Fitz LiveViews today.
Every one is **SSR-first** (server-rendered, reactive over a WebSocket),
needs **zero JS build**, and works identically under `fitz run` and the
native binary from `fitz build`.

These aren't a separate library you install — they're **patterns** built on
the [HTML primitives](html.md) and the [LiveView core](live.md). This page is
the reference; the **[Admin ABM example](https://github.com/Thegreekman76/fitz-liveviews/tree/main/examples/admin)**
is the full, runnable implementation of *every* component below (a People &
Access back-office over PostgreSQL, dockerized, internationalized ES/EN).

!!! tip "The two rendering modes"
    - **SSR (static)** — rendered once on a `@get` page. Interactivity that is
      purely client-side (collapse, tabs on a non-live page) can use native
      HTML like `<details>` with **zero JS**.
    - **Live (WS)** — rendered inside a `live_embed(...)` / `live_layout(...)`
      root. User actions fire `data-flv-*` events; the `@ws` handler re-queries
      / re-renders and diff-patches the DOM. State lives per-connection in the
      handler loop.

---

## Shell

The chrome around every screen. Built as plain render helpers (`page_layout`
composes the full document and drops the active screen into `<main>`).

### AppShell · Sidebar · Topbar

`page_layout(title, active, user, body, locale)` wraps the sidebar + topbar +
breadcrumbs around a screen body. The sidebar collapses to a drawer on mobile
(CSS-only, `data-*` toggles); the topbar carries the user chip, theme toggle
and language switch.

```
fn page_layout(title: Str, active: Str, user_name: Str, body: Html, locale: Str) -> Html {
    let sidebar = render_sidebar(active, locale)
    let topbar = render_topbar(title, user_name, locale)
    let crumbs = render_breadcrumbs(title, locale)
    return html("""<!doctype html><html lang="{locale}" ...>
      <body><div class="admin">{sidebar}
        <div class="main-col">{topbar}{crumbs}<main>{body.raw}</main></div>
      </div></body></html>""")
}
```

### nested Menu

A collapsible sidebar group is a native `<details>` — zero JS, auto-open when
one of its children is the active screen.

```
<details class="nav-group"{open}>
  <summary class="nav-item nav-group-head">🗂️ {flv(label)} <span class="nav-caret">▾</span></summary>
  <div class="nav-sub">{children}</div>
</details>
```

### Breadcrumbs

```
fn render_breadcrumbs(title: Str, locale: Str) -> Str {
    let home = t(locale, "crumb.admin")
    return """<nav class="breadcrumbs"><a href="/">{flv(home)}</a>
      <span class="crumb-sep">/</span><span class="crumb-current">{flv(title)}</span></nav>"""
}
```

### ThemeToggle

Light / dark / auto via `data-theme` on `<html>` + `localStorage`. An inline
head script sets the theme **before first paint** (no flash), and a body
script cycles it. Per-browser — never over the WebSocket.

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

Numbered page buttons + first/prev/next. `.limit(PAGE_SIZE).offset(offset)`.
The page number rides in the payload and is parsed with `str.to_int()`.

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

```
<div class="modal-overlay"><div class="modal">
  <h3>{t(locale, "confirm.title")}</h3><p>{confirm_q}</p>
  <div class="modal-actions">
    <button class="btn-clear" data-flv-click="cancel_delete">{t(locale, "confirm.cancel")}</button>
    <button class="btn-danger" data-flv-click="confirm_delete">{t(locale, "confirm.delete")}</button>
  </div></div></div>
```

### Toast / Alert

A transient flash after a save / delete. It lives for exactly one render — the
handler clears it at the top of the loop, so any next event dismisses it.

```
let toast = match flash == "" { true => "", false => """<div class="toast toast-{flash_kind}">
  <span>{flv(flash)}</span><button class="toast-x" data-flv-click="dismiss_flash">×</button></div>""" }
```

### Badge · CountBadge · Chip

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
