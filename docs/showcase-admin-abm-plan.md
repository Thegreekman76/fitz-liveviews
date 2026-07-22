# Admin ABM — flagship showcase plan

**Status**: planned (registered 2026-07-19). Not started.

**One-liner**: a complete backend **admin panel** — login, dashboard,
collapsible menu, theme switch, and a rich **ABM/CRUD** (grid + forms)
over a **RRHH + Accesos** (People & Access) domain — built on
PostgreSQL, dockerized, server-rendered with Fitz LiveViews.

This is the flagship demo for the public launch. It is **not just a
fitz-liveviews demo** — it exercises the *entire* Fitz stack in one
recognizable app, and it is the engine that drives the Companion UI
library (Phase 9) upward.

---

## Why this showcase

Every backend dev instantly recognizes an admin panel (Django admin,
Laravel Nova, AdminJS, Retool). The pitch it enables:

> A complete back-office — login, dashboard, rich data grid and forms —
> in **one language**, with Postgres, dockerized, **no JS build**.

Marketing goal: **visibility / GitHub stars**. The narrative is stronger
than the kanban because it reads as a *real business app*, not a toy.

## The whole Fitz stack, in one app

- **ORM (Phase 10)** — `@table` types, relations, QueryBuilder. Grid
  pagination / sort / filter map 1:1 to `.where` / `.order_by` /
  `.limit` / `.offset`. `.preload(...)` for relations. Aggregates for
  group counts.
- **PostgreSQL + Docker** — `fitz docker init` generates the Dockerfile
  + compose with the `postgres` service.
- **HTTP + WebSockets (LiveViews)** — the whole UI is server-rendered
  and reactive over WS.
- **`Response { body_bytes }` (v0.19.0)** — CSV/XLSX export, straight
  download.
- **Auth nativo (JWT / Argon2)** — the login + `@authenticated`
  gate on every admin route.
- **Frontend `.fitzv`** — SFC components for the shell and each screen.

## Scope: SSR-first

Everything server-rendered (round-trip over WebSocket = the LiveViews
sweet spot). The heavy interactions that want a buttery client-side feel
(drag-to-group, snappy tree view, chip multiselect with instant filter)
work today via server round-trips and get polished client-side **as
Fitz core Phase 11.7 (WASM client-side) matures** — that becomes a
second content moment for a relaunch.

## Responsive: hard requirement

Mobile-first, no fixed widths, **every component tested at 320px**
(per the project rule). Grid collapses to cards on mobile, sidebar
becomes a drawer, tables wrap in `overflow-x: auto`.

---

## Domain: RRHH + Accesos (People & Access)

Chosen because it makes *every* rich feature fit naturally:

| Entity | Role in the showcase |
|---|---|
| **Empleados** | The flagship grid + the alta/edición form |
| **Departamentos** | grouping dimension + `select` source |
| **Roles / Permisos** | group-checkbox (permissions by module) |
| **Ubicaciones** (País→Provincia→Localidad) | cascade select + tree |
| **Organigrama** ("reporta a") | tree view + group select |
| **Skills / Idiomas** | multiselect |

## App skeleton

- **Login** — auth nativo, JWT session, `@authenticated` on the rest.
- **Dashboard** — headline metrics (reuses the `dashboard` example
  pattern: live metric tiles).
- **Shell** — collapsible left menu (desktop = sidebar, mobile =
  drawer), topbar, breadcrumbs.
- **Theme switch** — light / dark (+ auto/system as a 3rd state) via
  CSS custom properties + `data-theme` on root, runtime switch without
  recompiling CSS. Selector lives in the topbar. (Aligns with the
  Phase 9.A theme system.)
- **Modules** — Empleados (star), plus the support entities that feed
  cascade / tree / group-checkbox.

## Grid feature list

Requested by the author. Feasibility noted.

| Feature | Feasibility (SSR) |
|---|---|
| Pagination | ✅ trivial (`.limit`/`.offset`) |
| Sort + multisort | ✅ trivial (`.order_by`) |
| Filters | ✅ trivial (`.where`) |
| Search | ✅ trivial |
| Row actions (edit / delete / view) | ✅ |
| Delete with confirmation | ✅ (modal) |
| Row selection (checkboxes) | ✅ (selection state server-side) |
| Multi-delete | ✅ |
| Export button (CSV/XLSX) | ✅ `Response { body_bytes }` |
| **Column grouping (drag-to-group)** | ⚠️ works via server round-trip; heaviest item |

## Form (alta / edición) — rich components

| Component | Feasibility (SSR) |
|---|---|
| Select | ✅ |
| Cascade select | ✅ classic LiveView (onchange → server → re-render dependent) |
| Checkbox | ✅ |
| Group select | ✅ (optgroup) |
| Group checkbox | ✅ (fieldset — permissions by module) |
| Multiselect (basic) | ✅ (checkbox list) |
| **Multiselect (chips / type-to-filter)** | ⚠️ basic is SSR; polished needs client JS |
| **Tree view** | ⚠️ expand/collapse via server events; fluid version waits 11.7 |

## Component inventory that emerges (redefines Phase 9)

The point the author made: *"bugs will surface, but so will many
components."* This is dogfooding at scale — each Fitz core gap becomes a
core fix; each repeated UI pattern gets extracted. This lifts the
Companion UI library from **8 basic components** to **~22-25**:

- **Shell**: AppShell · Sidebar (collapsible/drawer) · Topbar · Menu
  (nested dropdown) · Breadcrumbs · ThemeToggle
- **Auth**: LoginForm
- **Dashboard**: StatCard · Chart (if it fits)
- **DataGrid**: columns · sort/multisort · filters · search ·
  pagination · selection · row actions · grouping · toolbar · export
- **Forms**: FormLayout · Input · Select · CascadeSelect · MultiSelect
  · GroupSelect · Checkbox · CheckboxGroup · TreeView
- **Feedback**: Modal · ConfirmDialog · Toast/Alert · Badge · Spinner

## Slices (SSR-first, each one deployable)

1. **S1 — DONE** ✅ Login + responsive shell + theme switch + dashboard.
   100% viable today; gives a navigable skeleton to deploy early.
2. **S2 — DONE** ✅ (2026-07-22, lib v0.6.0) DataGrid (Empleados),
   read-only: columns + pagination. SSR first paint on `GET /empleados` +
   live pagination over `@ws("/live/empleados")` with `WsConn<LiveFrame>`
   (per-connection page state, diff-and-patch to that socket only), embedded
   in the shell via the new `live_embed` lib fn. Verified end-to-end on the
   native binary and via `docker compose up --build`. **Dogfooding →
   Fitz core**: surfaced the cross-module `List<Nominal>` codegen hang
   (WsConn message type + `diff_html` return in a submodule) → fixed as
   Fitz **v0.26.1 (W19+W20)**; the app no longer needs to import `Patch`.
3. **S3 — DONE** ✅ (2026-07-22, Fitz v0.27.0) The grid is fully interactive
   — search, estado filter, **departamento filter**, sort with asc/desc
   toggle, and **numbered pages** — all as WS events that re-query Postgres
   server-side (chained `.where` ANDs; `.ilike("%q%")` for search; dynamic
   `.order_by(col, ascending)`; `str.to_int()` to parse the page number /
   department id from the `Map<Str,Str>` payload). Verified end-to-end on
   the native binary + Docker + local Postgres. **No workarounds** — the two
   gaps this slice surfaced were both fixed in Fitz core (dogfooding):
   **W21** (dynamic `.order_by(ascending:)` in `fitz build`) and **W22**
   (the `str.to_int() -> Result<Int>` builtin). `FITZ_TAG` pinned to
   v0.27.0.
4. **S4** — Alta/edición forms with the rich components (cascade,
   group-checkbox, multiselect, tree).
   - **S4a — DONE** ✅ (2026-07-22) Create/edit form *inside the grid's
     LiveView* (patches over it): inputs + selects, save via `Empleado.insert`
     / `.where(id).update`, server-side validation, cancel. Row edit action +
     "Nuevo" button. Verified run + binary.
   - **S4b — DONE** ✅ (2026-07-22, lib v0.7.0) Cascade select
     (país → provincia → ciudad; new ubicaciones tables + `ciudad_id`). Each
     `change` re-queries the dependent options server-side; typed fields
     preserved. **Dogfood → lib**: added the `data-flv-change` event to the
     client runtime (v0.7.0). Verified run + binary. Also surfaced a Fitz
     core gap (checker doesn't flag an ORM query on an un-imported `@table`
     type, and the runtime hangs instead of erroring) — noted for a core fix.
   - **S4c — DONE** ✅ (2026-07-22, lib v0.8.0) Group-checkbox de permisos: un `<fieldset>` por módulo (nuevas tablas `permisos` + `empleado_permisos`), save sincroniza la selección, edit pre-marca. **Dogfood → lib**: serialización de checkbox-groups (comma-joined) en el runtime (v0.8.0). Verificado run + binario.
   - **S4d — DONE** ✅ (2026-07-22) Multiselect de skills (checkbox-list; nuevas tablas `skills` + `empleado_skills`). Reusa la serialización de checkbox-groups (v0.8.0) — sin cambio de lib. Save sincroniza, edit pre-marca. Verificado run + binario.
   - **S4e — DONE** ✅ (2026-07-22) Tree view de ubicaciones (país →
     provincia → ciudad, 3 niveles fijos, sin recursión — reusa las tablas
     de ubicaciones, sin schema nuevo). Expand/collapse de cada nodo como
     evento del server (`toggle_pais` / `toggle_prov`); los ids expandidos se
     llevan como sets comma-joined en el estado del socket (`tree_exp_pais` /
     `tree_exp_prov`), toggle vía el helper `toggle_id`. Botón "🌳 Ubicaciones"
     en el toolbar del grid → `show_tree`; "← Volver al grid" → `show_grid`.
     Showcase-only (sin cambio de lib). Verificado run + binario contra
     Postgres local. **Cierra S4 entero** (form + cascade + group-checkbox +
     multiselect + tree).
5. **S5 — DONE** ✅ (2026-07-22) Row selection + multi-delete + confirm
   dialog + CSV export. Per-row checkbox + header "select all" (reflects the
   current page); a selection bar shows the count with "Eliminar
   seleccionados" / "Limpiar selección". Delete (single via the row 🗑 or bulk
   via the bar) opens a **ConfirmDialog** modal; confirm runs `delete_ids`
   (clears the permisos + skills join rows first, then the empleado). Selection
   state (`sel`) + pending-confirm ids (`confirm_ids`) live per-connection in
   the socket, tracked as comma-joined sets (reuses the `toggle_id`/`id_checked`
   helpers from S4e). **CSV export** is a plain `@get("/empleados/export.csv?
   q={q}&estado={estado}&depto={depto}")` (a WS can't stream a download) that
   returns `Response { content_type: "text/csv", headers: Content-Disposition,
   body }` — it respects the active filters (search + estado + depto), not the
   checkbox selection. Verified run + binary against local Postgres (selection,
   select-all, clear, single + multi delete with real row removal, filtered
   export). Showcase-only, **no lib change** — **no workarounds** (query params
   in the path template, `Response`, ORM `.delete`, and `str.chars()` for CSV
   quoting all existed). Components extracted: **Checkbox · CheckboxGroup
   (select-all) · Modal · ConfirmDialog · Toolbar (export) · Badge (selection
   count)**.
6. **S6 — DONE** ✅ (2026-07-22) Column grouping (SSR row-grouping, the
   AG-Grid / Excel "group by" pattern — the drag-to-group polish waits for
   client-side 11.7). A "Agrupar por" pill control (Sin agrupar / Departamento
   / Estado) buckets the current filtered result set into collapsible sections,
   each with a header (expand/collapse toggle + label + **count badge**) and its
   member rows. Grouping shows every matching row (no pagination — the pager is
   swapped for a total count); collapsed section keys (`"depto-1"` /
   `"estado-active"`) live per-connection as a comma-joined set (`toggle_str` /
   `str_in`, the string-keyed sibling of `toggle_id`). Verified run + binary
   against local Postgres (group by depto/estado, collapse/expand a section,
   back to flat). Showcase-only, **no lib change**, **no workarounds**.
   Components extracted: **GroupPanel / RowGrouping · CountBadge**.

### S7 — Component completion pass (in progress)

S1-S6 cover the DataGrid + rich forms end-to-end. S7 rounds out the Companion
UI inventory (~22-25) with the remaining SSR-viable components.

- **S7a — DONE** ✅ (2026-07-22) **Chart** on the dashboard: a pure-CSS bar
  chart of *empleados por departamento*, scaled to the busiest department,
  straight from ORM counts (counted in Fitz over one `.all(...)`). Zero JS,
  responsive. Replaced the stale "Slice 2" placeholder panel. Verified run +
  binary.
- **S7b — DONE** ✅ (2026-07-22) **Toast / Alert**: a transient flash after a
  save ("Empleado guardado") or delete ("N empleado(s) eliminado(s)"), floating
  bottom-right, success/error variants. Flash lives for exactly one render —
  cleared at the top of the WS loop so any next event (or the × button →
  `dismiss_flash`) dismisses it. Verified run + binary (success on save/delete,
  auto-clear on next event).
- **S7c — DONE** ✅ (2026-07-22) **Breadcrumbs** in the shell: "Admin /
  <screen>" under the topbar, home crumb links to the dashboard. Verified run +
  binary. Showcase-only.
- **S7d — DONE** ✅ (2026-07-22) **Expandable rows** (Vuetify `v-data-table`
  expand pattern) + **Chips**. A chevron column toggles a detail `<tr>` under
  each row showing the employee's **departamento**, **ubicación**
  ("Ciudad, Provincia, País"), **permisos** and **skills** — the last two as
  chips (joins run only for the expanded rows). Expanded ids live per-connection
  as a comma-joined set (`toggle_row` → `toggle_id`). `render_grid` was
  refactored to receive a pre-built `body: Html` so `grid_html` (async) can
  interleave the detail rows (flat mode; grouping stays flat-row). Verified run +
  binary (expand/collapse single + multiple, chips render the joined names).
  Components extracted: **ExpandableRow / RowDetail · Chip**.

All of S7a-d are **no core gap, no workarounds, no lib change**. Components
extracted: **Chart/BarChart · Toast/Alert · Breadcrumbs · ExpandableRow · Chip**.

Still open (SSR-viable, lower priority):

- **GroupSelect (optgroup)** — a `<select>` with grouped options ("reporta a" by
  department; needs a `reporta_a` column → small schema add).
- **Tabs** — organize the (now long) edit form into Datos / Ubicación / Accesos /
  Skills. Needs server-side active-tab state (the LiveView re-render resets any
  CSS-only tab selection). High value → candidate S8 anchor.
- **DatePicker** (native `<input type="date">`, `fecha_ingreso`), **Textarea**
  (`notas`), **Radio group** (estado) — form inputs from the Vuetify catalog.
- **Tooltip** (CSS-only hints), **Multisort** (shift-click → client-runtime
  tweak → lib), **Spinner**, **Menu (nested dropdown)**.

### Vuetify catalog cross-check (2026-07-22)

Mapped the admin's components against Vuetify's catalog to find gaps. **Covered**:
tables/data-table (grid + sort + filter + search + pagination + selection +
grouping + expand + export), cards (StatCard/panels), chart, forms (input/select/
cascade/checkbox/checkbox-group/multiselect/tree), dialogs+snackbar+alert+badge+
chips, app-bar/drawer/breadcrumbs/pagination, avatar. **Not yet built (all
SSR-viable)**: Tabs, DatePicker, Textarea, Radio, Tooltip, GroupSelect (optgroup),
Stepper (multi-step form wizard), Rating (skill level), ProgressBar/Spinner,
ExpansionPanel (generic), Divider, nested Menu. Media (carousel/parallax/video)
and virtual tables are out of scope for an admin panel. → **S8 anchors on form
enrichment**: Tabs + DatePicker + Textarea + Radio + GroupSelect (reporta_a),
one schema migration for the new columns.

### S8 — Form enrichment + component completion (in progress)

- **S8a — DONE** ✅ (2026-07-22, lib v0.9.0) The edit form, enriched and
  organized into **Tabs** (Datos / Organización / Accesos), plus four new form
  components. One schema migration added `reporta_a bigint`, `fecha_ingreso
  text` (ISO date — Fitz dates are Str), `notas text`. New components:
  - **Tabs** — server-tracked active tab (`f_tab`). All panels stay in the DOM
    (hidden via CSS) so the form serializes every field on save regardless of
    the visible tab. Switching tabs carries the typed values via the new lib
    **`data-flv-form`** opt-in (see below) → nothing typed is lost.
  - **DatePicker** — native `<input type="date">` bound to `fecha_ingreso`.
  - **Textarea** — `notas`.
  - **Radio group** — estado (activo/inactivo), replacing the select.
  - **GroupSelect (optgroup)** — "reporta a", colleagues grouped by department
    (`<optgroup>`), excluding the row being edited.
  - **Lib v0.9.0** (`data-flv-form`): a `data-flv-click` button can opt into
    serializing its enclosing form — the foundation for in-form tab/stepper
    navigation. Serialized before `collectValues`, so explicit `data-flv-value-*`
    still wins (the grid's "Limpiar" button is unaffected). +1 lib test (88).
  - Verified run + binary against local Postgres: create with all fields, tab
    switch preserving typed input, edit prefill (date/notas/radio/reporta_a),
    save round-trip. **No core gap, no workarounds.** Components: Tabs ·
    DatePicker · Textarea · Radio · GroupSelect.
- **S8b — DONE** ✅ (2026-07-22) Dashboard analytics + **Stepper**:
  - **ProgressBar** — labeled % bars (Activos / Inactivos over total) on the
    dashboard, scaled ratios straight from ORM counts.
  - **ExpansionPanel** — native `<details>`/`<summary>` (zero JS) wrapping the
    bar chart; the dashboard is SSR-only so native collapse is perfect.
  - **Divider** (`<hr class="divider">`) + **Spinner** (CSS keyframes, shown as
    a small "en vivo" indicator in the dashboard header).
  - **Stepper** — the "alta" form is now a guided 3-step **onboarding** wizard
    (Datos → Organización → Accesos) with a numbered step indicator (past steps
    marked done, current active), contextual **← Atrás / Siguiente → /
    Finalizar** nav, while **edición keeps the free Tabs**. Both reuse the same
    panels + `f_tab` state + `form_tab` event; the nav buttons use
    `data-flv-form` so stepping never loses typed input. Verified run + binary
    (step forward/back preserving input, Finalizar on last step saves, edit
    still shows tabs). Components: ProgressBar · ExpansionPanel · Divider ·
    Spinner · Stepper.
- **S8c — DONE** ✅ (2026-07-22) Shell + form polish:
  - **nested Menu** — the sidebar's "Organización" group is a native
    `<details>` (zero JS) holding Empleados + Departamentos, auto-open when one
    of them is the active screen.
  - **Tooltip** — CSS-only `[data-tooltip]::after` on the grid action buttons
    (Ver detalle / Editar / Eliminar).
  - **Rating** — a `nivel` 0-5 star field (new column). Star **input** via
    radios + the `row-reverse` / `input:checked ~ label` CSS trick (no JS),
    on the Datos tab; read-only ★★★☆☆ **display** in the expand-row detail.
  - Verified run + binary: nested menu open state, tooltips, rating widget +
    save (`nivel`), edit prefill (radio checked), detail stars. **No core gap.**
    Components: nested Menu · Tooltip · Rating.

**S8 complete** — the Companion UI inventory is now essentially full (the
remaining Vuetify items — virtual tables, media — are out of scope for an admin
panel). Next: **S9 (i18n)**.

### S9 — Internationalization (i18n) — in progress

**Internationalize the whole ABM and every component** (author directive,
2026-07-22): every user-facing string routed through a translation layer,
**ES + EN**, language switch in the topbar (persisted in a cookie like the
theme). This doubles as the reusable **i18n pattern for the Companion UI
library** — components take a `locale` and translate through `t(...)`, never
hard-coding a language.

- **S9a — DONE** ✅ (2026-07-22) Infra + shell chrome. New `i18n.fitz`:
  `t(locale, key)` dictionary (dotted keys, `pick(locale, es, en)`, unknown key
  → itself), `locale_from_cookie` (cookie `flv_admin_lang`, default `es`),
  `other_locale` / `lang_flag`. New `@get("/lang/{code}")` sets the cookie +
  303-redirects to the Referer. Topbar **language switch** (🌐 ES/EN). `locale`
  threaded through `page_layout` → sidebar / topbar / breadcrumbs; `<html lang>`
  reflects it. Verified run + binary (switch ES↔EN, nav/breadcrumbs/tagline/
  aria translate, cookie persists). **Dogfood → Fitz core finding**: a local
  `let t` in one function clobbered the module-imported `t` used by others
  (checker didn't catch it; runtime `t is not invokable`); worked around by
  renaming the local, logged as a core scoping bug to fix in `d:\fitz`.
- **S9b — DONE** ✅ (2026-07-22, lib v0.10.0) All the screens. Dictionary grew
  to cover dashboard, grid, form, tree, confirm dialog, toasts, badges, tooltips,
  detail panel and login (~120 keys). `locale` threaded through the whole grid
  chain (grid_html → render_grid → grid_row / grouped_body / row_detail /
  estado_badge / sort_th / pills), the form (form_screen → form_html + tabs /
  stepper / depto_options / reporta_options), tree_screen, grid_error and the WS
  toast/validation messages. Login page + login_layout translated. Verified run
  + binary in both languages (dashboard, grid SSR + live WS re-renders, form
  tabs/stepper, tree, confirm/toast). **Core findings → documented, not worked
  around** (author directive): a `@ws` handler **can't read the handshake** —
  `@header` on `@ws` is rejected at runtime (checker passes → mismatch) and the
  `@ws` path must be a plain `Str` literal (no query/path params). So the live
  socket can't learn the locale the normal HTTP way. **Lib v0.10.0 (`__flv_init`)**
  solves it as a reusable feature: on connect the client sends the `ws_path`
  query params as a `__flv_init` event; the SSR bakes the locale into
  `live_embed("/live/empleados?lang={loc}", …)`; the `@ws` handler reads it from
  that first event and re-renders its diff baseline. (Earlier finding: a local
  `let t` clobbering an imported `t` — both logged for a Fitz-core fix in
  `d:\fitz`.)
- **S9c — DONE** ✅ (2026-07-22) i18n residuals — the client-`<script>` strings.
  The theme-toggle labels (☀️ Claro/Light · 🌙 Oscuro/Dark · 🖥️ Auto) are now
  injected into `interactive_js(locale)`; the login-error strings ('Error al
  ingresar'/'Sign-in error', 'Error de red'/'Network error') into
  `login_js(locale)`; and the 401 body from `login_failed(locale)` is localized
  (login_submit reads the lang cookie). **i18n is now complete.** Verified run +
  binary in both languages. **Second codegen finding (same scoping root)**: a
  local `let cookie = <String>` shadowing the `cookie: Str?` param made the
  codegen infer it as `Option<String>` → `fitz build` failed with E0308 (checker
  passed — another checker/codegen mismatch). Renamed the local to `set_cookie`;
  logged alongside the `let t` finding for the Fitz-core fix.

**S9 (i18n) complete** — every screen + every client-`<script>` string localized
ES/EN.

- **Core fixes landed (Fitz v0.28.0)** ✅ (2026-07-22) The two scoping bugs
  (local `let` shadowing an import/param) and **`@header` on `@ws`** were fixed
  in `d:\fitz`. **The ABM now reads the locale straight from the handshake
  cookie** — `@header(name="cookie") @ws("/live/empleados") … cookie: Str?` +
  `locale_from_cookie(cookie)`. The client-side `__flv_init` handshake and the
  `?lang=` query on `live_embed` are **removed** (the lib's `__flv_init` stays
  as a general feature; the ABM just no longer needs it). Verified run + binary
  against local Postgres (grid + form translate ES/EN from the cookie). The
  local renames (`nm`, `set_cookie`) are kept — clearer names, and no longer
  load-bearing now that the scoping bug is fixed.

Next per the author's order: the **Companion UI adoption package**.

## Expected Fitz core gaps (dogfooding)

Same mechanism as the chat/kanban migrations (which pushed §9.cc/dd/ee
to Fitz core in a day). Each blocker becomes a core fix or a documented
debt. Likely candidates:

- Client-side dynamic capabilities for the heavy interactions
  (drag-to-group, fluid tree, chip multiselect) → Fitz core Phase 11.7.
- Cross-file `<Child />` composition at scale (§9.y debt) — an admin
  shell composing many screen components will stress this.
- Whatever the grid + rich forms surface that the 4 current examples
  never did.

## Non-goals (for now)

- Buttery 100% client-side grid (no server round-trip) — waits for 11.7.
- Full RBAC engine beyond the permissions demo.
- Real auth hardening (refresh tokens, blacklist) beyond the login demo.
