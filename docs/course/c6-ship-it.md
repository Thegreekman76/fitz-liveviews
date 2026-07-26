# C6 — Ship it

**Prerequisite:** any project that runs with `fitz run` (the counter from
[C1](c1-first-live-component.md) is enough), plus `docker` on your machine.

**Objective:** turn a LiveViews app into a single native binary and run it — with
its Postgres — in containers, using the [Admin ABM](../examples/admin.md) as the
blueprint.

**Why it matters:** the whole course you ran `fitz run`. Production is different:
you ship a **binary**, not a source tree, and there's no runtime to install on the
server — no Node, no Python, no BEAM VM. Deploying a Fitz LiveViews app is closer
to shipping a Go binary than a Rails app: *copy the file, run it*. The Admin ABM
is the realistic version of that — a binary that also needs a database and a
couple of secrets — so it's the case we walk through here.

---

## 1. The binary (and the one new wrinkle)

You already met this in C1: `fitz build` compiles the same program to a
standalone binary.

```bash
cd examples/admin
fitz build
./target/release/admin-abm        # admin-abm.exe on Windows
```

The binary name comes from `[package].name` in `fitz.toml` (`admin-abm`). It's
**bit-for-bit** the same app as `fitz run` — same HTML, same WebSocket frames,
same behavior. It embeds the HTTP server, the WebSocket diff engine, the inline
JS client, and the ORM. Nothing else needs to be on the server.

The new wrinkle versus the C1 counter: the Admin ABM **talks to Postgres**. The
binary alone isn't the whole deployment — it needs a database next to it, and it
reads its connection string and JWT secret from **environment variables** (never
hardcoded). That's exactly what containers are good at, so the rest of this
chapter is one `Dockerfile` + one `docker-compose.yml`.

!!! note "This app builds locally because it lives inside the library repo"
    The Admin ABM depends on `fitz_liveviews` via a **path** dependency
    (`fitz_liveviews = { path = "../.." }`) because it sits inside the library's
    own repo. Your own app — the one you'd scaffold with
    `fitz new --template liveviews` (C1) — uses a **git** dependency instead, so
    its build is simpler (no repo layout to recreate). We call out where that
    changes the Dockerfile below.

---

## 2. The Dockerfile — multi-stage, builder → distroless

Here's the Admin ABM's `Dockerfile` in full:

```dockerfile
--8<-- "admin/Dockerfile"
```

Read it in two halves.

**Stage 1 — the builder.** It starts from the official Fitz image
(`ghcr.io/thegreekman76/fitz:<tag>`), which ships the `fitz` compiler plus the
Rust toolchain it uses under the hood. It copies the source in and runs
`fitz build`, producing a native **Linux** binary — even if your dev machine is
Windows or macOS. That's the free cross-compile: the build happens inside a Linux
container.

The one non-obvious part is **why the build context is the repo root, not this
folder**. Because the example uses the `../..` path dependency, that path must be
*inside* the Docker build context. So the Dockerfile recreates the repo layout —
it copies the library's `fitz.toml`+`src`, then the example's, then `cd`s into
`examples/admin` and builds. **In your own app this disappears:** with a git
dependency the context is just your app folder, and the Dockerfile that
`fitz docker init` generates is a few lines shorter.

**Stage 2 — the runtime.** It throws away the toolchain and starts fresh from
`gcr.io/distroless/cc-debian12` — just glibc, libgcc, and CA certificates. No
shell, no package manager, nothing to attack. It copies *only* the binary from
the builder stage, `EXPOSE`s 3000, and sets the binary as the entrypoint. The
final image is tiny because none of the build machinery ships with it.

**`ARG FITZ_TAG` pins the compiler version** so a rebuild six months from now
produces the same binary. Override it at build time with
`--build-arg FITZ_TAG=v0.28.6`.

!!! tip "You don't write this by hand"
    `fitz docker init` (Fitz core Phase 12.4) generates a working `Dockerfile`,
    `.dockerignore`, and `docker-compose.yml` for any Fitz app — it reads your
    `@server(N)` decorator and wires `EXPOSE N` + `ports: "N:N"` automatically.
    The Admin ABM's files started there; we only adjusted them for the path-dep
    layout and the Postgres service.

---

## 3. Compose — the app and its Postgres, one command

A binary that needs a database wants a `docker-compose.yml` that brings both up
together:

```yaml
--8<-- "admin/docker-compose.yml"
```

Two services, wired to each other:

**`db`** is stock `postgres:16-alpine`. It mounts
[`db/init.sql`](https://github.com/Thegreekman76/fitz-liveviews/blob/main/examples/admin/db/init.sql)
into `/docker-entrypoint-initdb.d/`, which Postgres runs **once**, the first time
the data volume is created — that's the schema plus the demo seed (the
`admin@fitz.dev` login, departments, employees). The `healthcheck` lets the app
wait until the database is actually accepting connections.

**`app`** builds from the Dockerfile (with `context: ../..`, the repo root, for
the reason above) and `depends_on` the db being *healthy*. The two settings that
make the wiring work are in `environment`:

- **`DATABASE_URL`** points at host **`db`** — the service name, which Compose
  resolves over its internal DNS. Inside the network it's `db:5432`, not
  `localhost`. (Locally, with `fitz run`, the same var points at
  `localhost:5432` — see [`.env.example`](https://github.com/Thegreekman76/fitz-liveviews/blob/main/examples/admin/.env.example).)
- **`JWT_SECRET`** is read from your shell (with a demo fallback). In real
  production you pass a real secret here and never commit it.

The `ports: "3000:3000"` mapping reaches the app because the binary binds
`@server(3000, "0.0.0.0")` — more on that in a second.

---

## 4. Run it

```bash
cd examples/admin
docker compose up --build
```

The first run compiles the app (the builder stage — slow once, cached after) and
initializes Postgres from `init.sql`. When the db is healthy the app starts.
Open **<http://localhost:3000/>**, log in with **admin@fitz.dev / admin1234**,
and it's the same app you've been running with `fitz run` — sort the grid, edit
an employee through the tabs, flip the language — now in two containers.

To stop: `Ctrl-C`, then `docker compose down`. Add `-v` (`docker compose down -v`)
to also drop the Postgres volume — do that when you want `init.sql` to run again
from scratch.

---

## 5. The two LiveViews-specific settings

A plain HTTP app deploys with the auto-generated files as-is. LiveViews apps have
**two quirks** worth knowing — the Admin ABM already handles both:

**a) Bind to `0.0.0.0`, not `127.0.0.1`.** `@server(3000)` alone binds to
localhost, which is unreachable from outside the container — `docker run` would
answer "connection refused". The Admin's `main.fitz` uses
`@server(3000, "0.0.0.0")`, and `EXPOSE 3000` + `ports: "3000:3000"` follow from
that.

**b) Restart on crash.** LiveViews hold **per-connection state in memory** — a
crash drops every open browser session. In production add a restart policy to the
`app` service so the container comes back:

```yaml title="docker-compose.yml (app service)"
    restart: unless-stopped
```

Both are covered in depth — with the reasoning and the platform-specific
variants — in the [Deploy reference](../deploy.md).

---

## 6. Configuration and secrets

Everything environment-specific is an **env var**, never baked into the binary:

| Var | What | Where it's set |
|---|---|---|
| `DATABASE_URL` | Postgres connection string | `docker-compose.yml` (host `db`); `.env` / shell for `fitz run` |
| `JWT_SECRET` | session-token signing key | your shell / secrets manager in prod |

Two design choices worth copying in your own apps:

- **The app never runs DDL at boot.** The schema lives in `db/init.sql`, run by
  Postgres on first boot; the app just connects per-request. That keeps
  `fitz run` and the container identical — neither one migrates on startup.
- **The seed is data, not config.** The demo admin (`admin@fitz.dev`) is a row in
  `init.sql`, not an env var. Secrets you rotate (`JWT_SECRET`) are env vars;
  fixture data lives in SQL.

---

## 7. Getting it onto a real host

`docker compose up` is local. To put the Admin ABM (or your app) on the internet
you add three things this chapter deliberately doesn't re-teach — they're the
same for any LiveViews app and are written up once in the
**[Deploy reference](../deploy.md)**:

- **A container host** — Fly.io (`fly launch` detects the Dockerfile), Railway
  (autodetect), a registry + any box, or Kubernetes (`/healthz` is auto-mounted
  for probes).
- **A reverse proxy that upgrades WebSockets.** This is the LiveViews-specific
  piece: the `@ws("/live/...")` handshake fails if the proxy doesn't forward the
  `Upgrade` headers, and idle sockets die if its timeouts are short. Caddy and
  Traefik handle it automatically; nginx needs the `proxy_http_version 1.1` +
  `Upgrade`/`Connection` snippet. TLS rides along with the proxy.
- **Sticky sessions — the one hard limit.** Because state lives on the server that
  handled the connection, running more than one replica behind a load balancer
  needs session affinity, or the `@ws` upgrade can land on a replica that has no
  state. For an MVP, **one replica is plenty**; this only matters once you scale
  out. (Sharing state *across* replicas is a message-bus concern on the roadmap.)

The Deploy reference has the copy-paste config for each.

---

## Checkpoint

- [x] `fitz build` produces a single `admin-abm` binary.
- [x] `docker compose up --build` brings up the app **and** its Postgres, and the
      login works at `http://localhost:3000/` exactly like `fitz run`.
- [x] You can explain why `DATABASE_URL` points at `db` (Compose DNS), not
      `localhost`, inside the network.
- [x] You know the two LiveViews-specific settings: bind `0.0.0.0`, and a restart
      policy for the in-memory session state.
- [x] You know where secrets and schema live: env vars for secrets, `init.sql`
      for schema + seed, no DDL at boot.

---

## Troubleshooting

!!! failure "`connection refused` from the host after `docker compose up`"
    The server is bound to `127.0.0.1`. Change `@server(3000)` to
    `@server(3000, "0.0.0.0")` and rebuild (`docker compose up --build`).

!!! failure "The `app` container restarts in a loop"
    Read `docker logs admin-abm-app`. Usual causes: `DATABASE_URL` wrong or the
    db not ready (should be covered by `depends_on: service_healthy`), a missing
    env var, or a panic at startup. The logs name the exact error.

!!! failure "Login fails / a table doesn't exist"
    Postgres only runs `init.sql` when the data volume is **first** created. If
    the volume exists from an earlier, different schema, the new SQL never ran.
    Reset it: `docker compose down -v` then `docker compose up --build`.

!!! failure "First build is very slow"
    The builder stage compiles the library + your app from scratch. It's cached
    after the first run — later builds only recompile what changed.

!!! failure "Works locally, but `/live/empleados` 404s behind a proxy"
    The reverse proxy isn't forwarding the WebSocket upgrade. See the proxy
    snippets in the [Deploy reference](../deploy.md) — or use Caddy/Traefik,
    which handle it automatically.

---

## You made it — what you can do now

Six chapters ago you had `fitz --version`. Now you can:

- Write a live component from scratch — state, render, events, the `@ws` loop
  (**C1**).
- Wire any interaction with the `data-flv-*` conventions and a live `<form>`,
  zero JavaScript (**C2**).
- Compose a screen from reusable render helpers with scoped CSS (**C3**).
- Back it with Postgres and keep multiple users in sync (**C4**).
- Split reusable, independently-stateful parts into LiveComponents (**C5**).
- **Ship the whole thing as one native binary in a container (**C6**).**

Where to go from here:

- **[UI catalog](../ui-components.md)** — the pattern + snippet for every control,
  when you need one you haven't built yet.
- **[Admin ABM](../examples/admin.md)** — the flagship: every component from the
  catalog wired into a real back-office over Postgres. The blueprint you just
  deployed, in full.
- **[Deploy reference](../deploy.md)** — proxy, TLS, health checks, scaling, and
  the systemd (no-Docker) path, for when local `docker compose` becomes a real
  server.
- **[Component gallery](../examples/gallery.md)** — every control on one page, and
  the seed for the edit-and-preview **playground** that's coming next.

That's the course. You now understand a Fitz LiveViews app end to end — from one
counter to a deployed, database-backed, internationalized admin panel — with no
bundler, no `npm install`, and no JavaScript you had to write.
