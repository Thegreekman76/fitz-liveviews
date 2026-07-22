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
6. **S6** — Column grouping + tree view polish.

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
