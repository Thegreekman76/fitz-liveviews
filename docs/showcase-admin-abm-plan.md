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

1. **S1** — Login + responsive shell + theme switch + dashboard.
   100% viable today; gives a navigable skeleton to deploy early.
2. **S2** — DataGrid (Empleados), read-only: columns + pagination.
3. **S3** — Filters + sort/multisort + search on the grid.
4. **S4** — Alta/edición forms with the rich components (cascade,
   group-checkbox, multiselect, tree).
5. **S5** — Selection + multi-delete + confirm + export.
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
