# Admin ABM — the flagship back-office

A complete **People & Access** admin panel: login, dashboard, a rich data grid
over PostgreSQL, and full CRUD forms — all server-rendered over WebSockets,
dockerized, and internationalized ES/EN. It exercises the *entire* Fitz stack
(ORM + Postgres + HTTP + WebSockets + auth + `Response{}` export) in one
recognizable app, with **zero JS build**.

Source: [`examples/admin/`](https://github.com/Thegreekman76/fitz-liveviews/tree/main/examples/admin)

## Why this example exists

The counter/chat/kanban/dashboard examples each isolate one idea. The Admin ABM
is the opposite — it's the **reference implementation of every component** in the
[UI catalog](../ui-components.md), wired into a real business app. If you want to
see how the DataGrid, the tabbed/stepped forms, the cascade selects, the modal,
the toasts, the tree and the i18n all fit together, this is it.

It's also the app that drove three upstream fixes into Fitz core while it was
built (dogfooding): `str.to_int()`, a dynamic `.order_by(ascending:)`, and
`@header` on `@ws` (so the live socket reads the locale straight from the
handshake cookie).

## Run

The app reads/writes Postgres during requests (it never runs DDL at boot — the
schema lives in [`db/init.sql`](https://github.com/Thegreekman76/fitz-liveviews/blob/main/examples/admin/db/init.sql)).

**With Docker** (Postgres + app together):

```powershell
cd examples/admin
docker compose up --build
```

**Local Postgres** (schema loaded once, then `fitz run`):

```powershell
psql "postgres://fitz:fitz@localhost:5432/fitz_admin" -f db/init.sql
cd examples/admin
$env:DATABASE_URL = "postgres://fitz:fitz@localhost:5432/fitz_admin?sslmode=disable"
fitz run
```

Open <http://127.0.0.1:3000/>, log in with **admin@fitz.dev / admin1234**, and
click around: sort/filter/search the grid, expand a row, group by department,
select rows and delete, export CSV, create an employee through the onboarding
**stepper**, edit one through the **tabs**, and flip the language with the 🌐
switch in the topbar.

## Architecture

One small module per concern — the same shape a real Fitz service takes:

| File | Role |
|---|---|
| `models.fitz` | `@table` types (User, Departamento, Empleado, ubicaciones, permisos, skills) |
| `config.fitz` | env-var helpers (`db_url`, `jwt_secret`, cookie names) |
| `session.fitz` | cookie-based session (`user_from_cookie`) — browser-style, redirects not 401 |
| `i18n.fitz` | `t(locale, key)` dictionary (ES/EN, ~120 keys) + `locale_from_cookie` |
| `shell.fitz` | the chrome: `page_layout` (sidebar + topbar + breadcrumbs + theme) |
| `auth.fitz` | `GET/POST /login`, `/logout`, `/lang/{code}` |
| `dashboard.fitz` | `/` (stat cards + bar chart + progress) and `/departamentos` |
| `empleados.fitz` | the DataGrid + the rich forms, SSR first paint + `@ws` live layer |
| `main.fitz` | `import`s the modules + `@server(3000, "0.0.0.0")` |

The grid is served twice: an SSR first paint on `GET /empleados` (embedded in the
shell with `live_embed(...)`) and a live layer over `@ws("/live/empleados")` that
re-queries Postgres on every event and diff-patches back to that socket only. All
grid state (page, search, filters, sort, selection, grouping, expanded rows,
active tab) is **per-connection** in the `@ws` handler loop.

## The component tour

Every component here is documented in the **[UI catalog](../ui-components.md)**;
this is where to read the real code:

- **Shell** — collapsible sidebar (nested `<details>` menu), topbar with theme +
  language switch, breadcrumbs.
- **Auth** — JWT login + Argon2id verify + HttpOnly cookie.
- **Dashboard** — stat cards, a pure-CSS bar chart and progress bars from ORM
  counts, an expansion panel, a spinner "live" indicator.
- **DataGrid** — sortable columns, search, estado + department filters,
  pagination, row selection + multi-delete with a confirm modal, per-row expand
  showing permits + skills as chips, group-by with collapsible sections, and CSV
  export via `Response { body }`.
- **Forms** — the edit form as free **Tabs**, the create form as a guided
  **Stepper**; date picker, textarea, radio group, cascade select
  (país→provincia→ciudad), group select (reports-to), multiselect (skills),
  group-checkbox (permits), a star **rating**.
- **Feedback** — modal, toasts, badges, chips, tooltips.
- **i18n** — every string localized ES/EN; the `@ws` handler reads the active
  locale from the handshake cookie (`@header(name="cookie")`), so the live grid
  and forms translate with no client-side handshake.

## Where to go next

- **[UI catalog](../ui-components.md)** — the pattern + snippet for every
  component above.
- **[LiveViews](../live.md)** — how the diff-and-patch engine works.
