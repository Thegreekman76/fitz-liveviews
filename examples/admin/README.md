# Admin ABM — flagship showcase

A complete back-office **admin panel** built entirely in Fitz: login, a
responsive shell with a light/dark/auto theme switch, a dashboard, and two live
CRUD screens (Empleados + Departamentos) — on **PostgreSQL**, dockerized,
server-rendered with Fitz LiveViews, internationalized ES/EN. No JS build.

This is the flagship demo for Fitz + fitz-liveviews: it exercises the whole
stack (ORM + Postgres + HTTP + WebSockets + auth + `Response{}` export) in one
recognizable app over a **People & Access** domain.

> Built slice by slice (S1–S10). The full plan and component inventory are in
> [`docs/showcase-admin-abm-plan.md`](../../docs/showcase-admin-abm-plan.md).

---

## What it gives you

- **Login** — a real session: credentials → Argon2id verify → signed JWT in
  an `HttpOnly` cookie. Unauthenticated page requests **redirect** to `/login`
  (browser-correct, not a JSON 401).
- **Responsive shell** — collapsible sidebar on desktop, off-canvas drawer on
  mobile (works down to 320px), topbar with the current user, a 🌐 **ES/EN**
  language switch, and a **light / dark / auto** theme switch (persisted
  per-browser, applied before first paint — no flash).
- **Dashboard** — stat cards with **real counts from Postgres** (employees,
  active, inactive, departments) + a pure-CSS bar chart, via the Fitz ORM.
- **Empleados DataGrid** — the flagship live view: SSR first paint + a `@ws`
  socket that re-queries Postgres and diff-and-patches on every event (search,
  estado + department filters, sort, pagination, rich tabbed/stepped forms,
  cascade selects, row selection + multi-delete, group-by, per-row expand,
  CSV export). All grid state is per-connection.
- **Departamentos ABM** — the same live architecture, kept simple: grid +
  create/edit/delete + an employee count per area.
- **LiveComponents** — reusable SFCs (`ConfirmDialog`, `Toast`, `Pager`,
  `GridToolbar`, `GridFilters`, `EmpleadoRow`, `EmpleadoForm`). The
  per-connection widgets (ConfirmDialog, Toast) mint a uuid per socket via
  `component_with(...)` and are **shared across both CRUD screens** — the seed
  of a companion UI library.
- **Companion UI primitives** — the employee form adopts the packaged
  presentational primitives from `fitz_liveviews.ui.*`: `Input` (text/email/date
  fields), `Alert` (the validation banner) and `Button` (save/finish/cancel), all
  themed through the `--flv-*` tokens aliased to the admin's own palette in
  `shell.fitz`. The grid keeps hand-tuned markup on purpose — its per-row buttons
  render N times per live frame, where a primitive's inline scoped `<style>` would
  duplicate on every row.
- **Postgres + Docker** — one `docker compose up` brings up the database
  (schema + seed) and the app. Bit-for-bit identical under `fitz run` and the
  native `fitz build` binary.

Demo login: **`admin@fitz.dev`** / **`admin1234`**

---

## Run it

### Option A — Docker (everything, one command)

```bash
docker compose up --build
```

Then open **http://localhost:3000/**. Postgres creates the database and runs
`db/init.sql` (schema + demo seed) on first boot; the app waits for it and
serves.

### Option B — local `fitz run` (needs a local Postgres)

1. Create the database and role (once):

   ```bash
   createdb fitz_admin
   psql -c "CREATE ROLE fitz LOGIN PASSWORD 'fitz'" 
   psql -c "ALTER DATABASE fitz_admin OWNER TO fitz"
   ```

2. Load the schema + seed (once):

   ```bash
   psql "postgres://fitz:fitz@localhost:5432/fitz_admin" -f db/init.sql
   ```

3. Run the app:

   ```bash
   fitz run
   ```

   Point it at a different database by exporting `DATABASE_URL` first (see
   `.env.example`). Open **http://127.0.0.1:3000/**.

---

## Routes

| Route             | Auth        | What it does                              |
|-------------------|-------------|-------------------------------------------|
| `GET  /login`     | public      | Login page                                |
| `POST /login`     | public      | Validate creds → set session cookie       |
| `GET  /logout`    | public      | Clear cookie → redirect to `/login`       |
| `GET  /`          | cookie      | Dashboard (stat cards from Postgres)      |
| `GET  /empleados` | cookie      | Employees DataGrid (SSR first paint)      |
| `WS   /live/empleados` | cookie | Employees live layer (search/filter/sort/CRUD) |
| `GET  /empleados/export.csv` | cookie | CSV export of the filtered set     |
| `GET  /departamentos` | cookie  | Departments ABM (SSR first paint)         |
| `WS   /live/departamentos` | cookie | Departments live layer (search/sort/CRUD) |

Unauthenticated requests to a protected route return `303 → /login`.

---

## How it fits together

```
examples/admin/
├── db/init.sql          schema + demo seed (admin, departments, employees)
├── docker-compose.yml   postgres + app
├── Dockerfile           multi-stage: fitz build → distroless
└── src/
    ├── config.fitz      env-var helpers (DATABASE_URL, JWT_SECRET, cookie name)
    ├── models.fitz      @table types: User, Departamento, Empleado, ubicaciones…
    ├── i18n.fitz        server-side ES/EN dictionary (t(locale, key))
    ├── session.fitz     cookie → JWT → user lookup (browser-style auth)
    ├── auth.fitz        login page + POST /login (Set-Cookie) + logout
    ├── shell.fitz       full HTML document, responsive shell, theme CSS + JS
    ├── dashboard.fitz   the dashboard (stat cards + chart from the ORM)
    ├── empleados.fitz   the Empleados DataGrid + rich forms (SSR + @ws)
    ├── departamentos.fitz  the Departamentos ABM (SSR + @ws)
    ├── *.fitzv          LiveComponents: ConfirmDialog, Toast, Pager,
    │                    GridToolbar, GridFilters, EmpleadoRow, EmpleadoForm
    └── main.fitz        imports the modules + @server; serves
```

**Auth is cookie-based on purpose.** A browser can't send an
`Authorization: Bearer` header on page navigation or a WebSocket handshake,
but it always sends cookies. So the session token rides in an `HttpOnly`
cookie, and each protected page reads it with `@header(name="cookie")`,
resolves the user, and redirects to `/login` on failure — the way Django or
Rails gate a browser session. (Login posts JSON via `fetch`, because Fitz
`@post` handlers take a JSON body, not form-urlencoded — a future core
enhancement could accept form posts and let the login be a plain `<form>`.)

**The app never connects to the database at boot** — only during requests.
The schema and seed live in `db/init.sql` (run by Postgres on first boot, or
with `psql -f` locally). Connecting at boot under `fitz run` would bind the
connection pool to the interpreter's short-lived startup runtime, which is
gone by the time requests arrive.

---

## What's next

The stack is complete (auth + ORM + live grids + forms + LiveComponents + i18n
+ Docker). The remaining direction is **extracting the LiveComponents into a
reusable companion UI library** — the widgets under `src/*.fitzv` (ConfirmDialog,
Toast, Pager, GridToolbar, …) are already shared across the Empleados and
Departamentos screens; the next step is packaging them so any Fitz LiveViews
app can install and compose them. See
[`docs/showcase-admin-abm-plan.md`](../../docs/showcase-admin-abm-plan.md).
Each slice is deployable on its own.
