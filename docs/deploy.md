# Deploy

Production deploy patterns for apps built with Fitz LiveViews. The
`fitz build` output is a single native binary — deploying it is closer
to a Go app than to a Node or Rails app.

---

## What you actually deploy

An app that uses `fitz-liveviews` is a normal Fitz app: it declares a
`[bin]` in its `fitz.toml`, imports the library as a dep, and produces
one native binary when you run `fitz build`. That binary embeds:

- The HTTP server (axum + tokio linked statically)
- The WebSocket handler with typed `LiveFrame` diffs
- The ~30-line vanilla JS client, served inline in every response
- The server-side HTML diff engine
- Whatever else your app uses (ORM, Python interop, cron jobs)

Deploying is: **copy the binary, run it**.

You do **not** need Node, Python, Ruby, or the BEAM VM on the target box.
The only exception is Python interop — either bundle CPython with
`fitz build --bundle-python`, or use a `python:3.12-slim` runtime image.

---

## Two approaches

Both produce identical runtime behavior:

1. **Docker** (recommended) — `fitz docker init` gives you a working
   Dockerfile in seconds. Best for Kubernetes, Fly.io, Railway, ECS, or
   any container platform. Also the simplest way to cross-compile if
   your dev machine is macOS or Windows.
2. **Bare metal / VPS with systemd** — plain binary + systemd unit. Best
   when you have a single VPS and want minimum moving parts. Uses Docker
   only as a cross-compiler.

If unsure, start with Docker.

---

## Prerequisites

- The `fitz` binary installed locally (see the [Fitz install guide](https://thegreekman76.github.io/fitz/curso/m1-setup/c1-instalacion/))
- Your app runs correctly with `fitz run` locally
- `docker` and (optionally) `docker compose` on your dev machine and target host

---

## Approach 1: Docker

### 1. Generate the base files

From the root of your app (where `fitz.toml` lives):

```bash
fitz docker init
```

This writes three files (from Fitz core Phase 12.4):

- `Dockerfile` — multi-stage build with `ghcr.io/thegreekman76/fitz` as
  builder and `gcr.io/distroless/cc-debian12` as runtime (~30 MB final image)
- `.dockerignore` — excludes `target/`, `.git/`, `.env*`, and friends
- `docker-compose.yml` — a minimal compose file with port mapping

The detector reads your `@server(N)` decorator and emits `EXPOSE N` +
`ports: "N:N"` automatically.

### 2. Two adjustments specific to LiveViews

The auto-generated files are correct for a plain HTTP app, but **LiveViews
apps have two quirks worth fixing before you deploy**:

#### a) Bind to `0.0.0.0`, not `127.0.0.1`

Fitz's `@server(port)` alone binds to `127.0.0.1` — inaccessible from
outside the container. In Docker you always want to bind to `0.0.0.0`:

```fitz
@server(3000, "0.0.0.0")
fn main() => 0
```

The generated Dockerfile already includes a comment mentioning this.
Without it, `docker run -p 3000:3000 <app>` returns "connection refused"
from the host.

#### b) Add `restart: unless-stopped` to `docker-compose.yml`

`fitz docker init` only adds a restart policy when it detects `@cron`.
But LiveViews apps hold per-connection state in memory — a crash kills
every open browser session. Set the policy so the container restarts:

```yaml title="docker-compose.yml"
services:
  app:
    build: .
    ports:
      - "3000:3000"
    restart: unless-stopped   # <-- add this
```

### 3. Build and run locally

```bash
docker compose up --build
```

Open `http://localhost:3000`. The counter/chat/kanban works identically
to `fitz run`.

### 4. Ship it

=== "Fly.io"

    ```bash
    fly launch      # detects Dockerfile automatically
    fly deploy
    ```

=== "Railway"

    Connect the repo — Railway autodetects the Dockerfile. No config needed.

=== "Registry-based (any host)"

    ```bash
    docker build -t your-registry/counter:v1 .
    docker push your-registry/counter:v1
    # then pull + run on the target host
    ```

=== "Kubernetes"

    Build + push as above, then a standard `Deployment` + `Service` +
    `Ingress`. See the health-check section below for the probe config.

---

## Approach 2: VPS with systemd

Skip Docker at runtime. Compile the binary and copy it directly to the server.

### 1. Cross-compile via Docker

There is no `fitz build --target` flag today — cross-compile goes through
Docker. Reuse the same `Dockerfile` that `fitz docker init` produced;
just extract the binary from the builder stage instead of running the
final image:

```bash
# Build only the builder stage
docker build --target builder -t counter-builder .

# Extract the binary
docker create --name counter-tmp counter-builder
docker cp counter-tmp:/app/target/release/counter-example ./counter-example
docker rm counter-tmp
```

You now have a Linux binary in your working directory. Confirm with
`file counter-example` (should say "ELF 64-bit LSB executable").

If you develop directly on the target Linux, plain `fitz build` is enough
and this whole step is unnecessary.

### 2. Copy the binary to the server

```bash
scp counter-example user@vps:/opt/counter/
ssh user@vps 'chmod +x /opt/counter/counter-example'
```

### 3. Write a systemd unit

`/etc/systemd/system/counter.service`:

```ini
[Unit]
Description=Counter LiveView
After=network.target

[Service]
Type=simple
User=counter
WorkingDirectory=/opt/counter
ExecStart=/opt/counter/counter-example
Restart=on-failure
RestartSec=5

# Environment (add secrets, DB URLs, etc.)
Environment=RUST_LOG=info

[Install]
WantedBy=multi-user.target
```

Enable + start:

```bash
sudo systemctl enable --now counter
sudo systemctl status counter
```

Same guarantee as Docker — the binary is standalone, no Python/Node/BEAM
runtime needed on the box.

---

## Reverse proxy — the WebSocket piece

Your app binds to port 3000 (or whatever `@server` says) on plain HTTP.
For real production you almost always want:

- **TLS termination** — Let's Encrypt certificates
- **Port 80/443 in front, 3000 inside** — the app doesn't need root privileges
- **WebSocket upgrade support** — this is the piece specific to LiveViews

The proxy **must** support HTTP → WebSocket upgrade, or the
`@ws("/live/counter")` handshake fails. Timeouts **must be long** or the
proxy kills idle WebSockets after ~60 seconds by default.

=== "nginx"

    ```nginx title="nginx.conf snippet"
    server {
        listen 443 ssl http2;
        server_name counter.example.com;

        ssl_certificate     /etc/letsencrypt/live/counter.example.com/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/counter.example.com/privkey.pem;

        location / {
            proxy_pass http://127.0.0.1:3000;
            proxy_http_version 1.1;

            # WebSocket upgrade — required for @ws handlers
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";

            # Standard forwarding
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            # Long timeouts — WebSockets stay open
            proxy_read_timeout  3600s;
            proxy_send_timeout  3600s;
        }
    }
    ```

=== "Caddy"

    Caddy handles WebSocket upgrade and TLS automatically. Full Caddyfile:

    ```caddy
    counter.example.com {
        reverse_proxy 127.0.0.1:3000
    }
    ```

    Caddy fetches and renews Let's Encrypt certificates on its own. Nothing
    extra needed for WebSockets. Recommended for new deploys unless you
    already run nginx or Traefik.

=== "Traefik"

    With Docker Compose and Traefik in front:

    ```yaml title="docker-compose.yml"
    services:
      app:
        build: .
        restart: unless-stopped
        labels:
          - "traefik.enable=true"
          - "traefik.http.routers.counter.rule=Host(`counter.example.com`)"
          - "traefik.http.routers.counter.entrypoints=websecure"
          - "traefik.http.routers.counter.tls.certresolver=letsencrypt"
          - "traefik.http.services.counter.loadbalancer.server.port=3000"
    ```

    Traefik detects the container, routes on the hostname, terminates TLS,
    and handles WebSocket upgrade transparently.

---

## TLS

Three options depending on the proxy:

- **Caddy** — automatic, nothing to configure
- **Traefik** — `certresolver=letsencrypt` in the Docker labels + Traefik
  config with your email
- **nginx** — run `certbot --nginx -d counter.example.com` once; certbot
  edits your nginx config and adds a cron job for renewal

For local dev you can skip TLS entirely — WebSocket works over plain
`http://localhost:3000` without issue.

---

## Health and readiness

Fitz auto-mounts a `/healthz` endpoint on every server binary (Fitz core
Phase 12.1). No code required — `GET /healthz` returns `200 OK` as long
as the server is up.

Use it in Kubernetes probes:

```yaml title="k8s deployment snippet"
livenessProbe:
  httpGet:
    path: /healthz
    port: 3000
  periodSeconds: 10
readinessProbe:
  httpGet:
    path: /healthz
    port: 3000
  periodSeconds: 5
```

Or in Docker Compose (requires wget/curl in the runtime image — the
default distroless does not ship them; the generated `docker-compose.yml`
includes a comment with the workaround if you need it).

If you need custom readiness logic (e.g. "wait for the DB migration"),
declare a `@healthz` handler in your Fitz code and it takes precedence
over the auto-mounted one.

---

## Horizontal scale — the sticky sessions caveat

This is the one **hard limit** of LiveViews. It is not specific to Fitz —
it applies to Phoenix LiveView, Hotwire, and every server-authoritative
model: **state lives on the server that handled the initial connection.**

If you run **more than one replica** behind a load balancer:

- The initial `@get("/")` may hit replica A.
- The follow-up `@ws("/live/counter")` upgrade may hit replica B.
- Replica B has no state for this session → the LiveView breaks.

The fix is **sticky sessions** (also called "session affinity"):

- **nginx** — `ip_hash;` in the upstream block, or the commercial
  `sticky` module for cookie-based affinity
- **Traefik** — `traefik.http.services.<name>.loadbalancer.sticky.cookie=true`
- **Kubernetes** — `service.spec.sessionAffinity: ClientIP`
- **Cloud LBs** (AWS ALB, GCP LB, Fly.io) — enable session affinity in the
  target group / load balancer settings

For most LiveViews apps in the "MVP + first users" stage, **one replica
is plenty**. Sticky sessions only matter once you actually need horizontal
scale.

Sharing state across replicas (e.g. broadcast to every user of every
replica) needs a message bus — Postgres `LISTEN/NOTIFY` or Redis pub/sub.
That is a Phase 4+ concern on the fitz-liveviews roadmap.

---

## Common pitfalls

**WebSocket disconnects after ~60 seconds**

Your reverse proxy is killing idle connections. Increase `proxy_read_timeout`
(nginx) or the equivalent. See the nginx snippet above.

**`connection refused` from the Docker host**

You forgot to bind to `0.0.0.0`. Change `@server(3000)` to
`@server(3000, "0.0.0.0")` and rebuild the image.

**Container restarts every few seconds**

Check `docker logs <container>` — likely a panic on startup. Common
causes: DB connection string wrong, required env var missing, or the
port is already in use inside the container.

**The `/live/*` route returns 404 through the proxy**

WebSocket upgrade headers are not being forwarded. Confirm
`proxy_http_version 1.1` and the `Upgrade`/`Connection` headers in
the nginx config (or use Caddy/Traefik, which handle this automatically).

**The counter increments but the browser never updates**

The initial HTTP GET works but the WS handshake is failing. Check the
browser console — an error like `WebSocket connection to 'wss://...'
failed` means the proxy isn't upgrading. Same fix as above.

**Two browser tabs show different counts**

Expected until Phase 4 — the counter example uses per-connection state
by design. Each tab is its own session. See `examples/chat/` for the
shared-state pattern using top-level `let` wrapped in `Arc<Mutex>`.

---

## What is not covered here

- **Kubernetes deep-dive** — the auto-mounted `/healthz` and the sticky
  session config above are enough for a basic `Deployment` + `Service` +
  `Ingress`. Full K8s hardening (HPA, PodDisruptionBudgets, network
  policies, mesh sidecars) is beyond this guide.
- **Multi-region / geo-distributed deploys** — LiveViews with global users
  has extra latency concerns (a WS round-trip on every event). Practically,
  keep users routed to the nearest region.
- **Presence tracking across replicas** — deferred to Phase 7+ on the
  fitz-liveviews roadmap.
- **Zero-downtime deploys** — depends on the orchestrator. Docker Compose
  cuts users off; Kubernetes with a rolling strategy plus
  `terminationGracePeriodSeconds` drains cleanly. Fitz's SIGTERM handling
  is documented in [Fitz core Phase 12.4](https://thegreekman76.github.io/fitz/curso/m7-produccion-deploy/c4-deploy-docker-k8s/).

For anything not covered, open a discussion on the
[GitHub repo](https://github.com/Thegreekman76/fitz-liveviews/discussions).
