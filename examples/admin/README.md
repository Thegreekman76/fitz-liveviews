# Admin ABM — flagship showcase

A complete back-office **admin panel** built entirely in Fitz: login,
responsive shell, light/dark/auto theme switch, and a dashboard — on
**PostgreSQL**, dockerized, server-rendered with Fitz LiveViews. No JS build.

This is the flagship demo for Fitz + fitz-liveviews. It exercises the whole
stack in one recognizable app (an admin panel over a **People & Access**
domain) and grows slice by slice into a full ABM/CRUD.

> **This is Slice 1** — the navigable skeleton. See
> [`docs/showcase-admin-abm-plan.md`](../../docs/showcase-admin-abm-plan.md)
> for the full plan (slices S1–S6) and the component inventory.

---

## What Slice 1 gives you

- **Login** — a real session: credentials → Argon2id verify → signed JWT in
  an `HttpOnly` cookie. Unauthenticated page requests **redirect** to `/login`
  (browser-correct, not a JSON 401).
- **Responsive shell** — collapsible sidebar on desktop, off-canvas drawer on
  mobile (works down to 320px), topbar with the current user, and a
  **light / dark / auto** theme switch (persisted per-browser, applied before
  first paint — no flash).
- **Dashboard** — stat cards with **real counts from Postgres** (employees,
  active, inactive, departments) via the Fitz ORM.
- **Postgres + Docker** — one `docker compose up` brings up the database
  (schema + seed) and the app.

Slice 1 is **SSR-only** — server-rendered on every request. The live
WebSocket layer and `.fitzv` components arrive in Slice 2 with the employees
grid.

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
| `GET  /empleados` | cookie      | Employees screen (placeholder — Slice 2)  |
| `GET  /departamentos` | cookie  | Departments screen (placeholder — Slice 2)|

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
    ├── models.fitz      @table types: User, Departamento, Empleado
    ├── session.fitz     cookie → JWT → user lookup (browser-style auth)
    ├── auth.fitz        login page + POST /login (Set-Cookie) + logout
    ├── shell.fitz       full HTML document, responsive shell, theme CSS + JS
    ├── dashboard.fitz   protected screens; dashboard counts from the ORM
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

Slice 2 adds the employees **DataGrid** (columns, pagination) over the live
WebSocket layer, then filters/sort/search (S3), rich edit forms (S4),
selection + multi-delete + export (S5), and column grouping + tree view (S6).
Each slice is deployable on its own.
