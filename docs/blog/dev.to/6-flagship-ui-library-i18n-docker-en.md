---
title: "Building the flagship (3): a packaged UI library, i18n, and one-command Docker"
published: false
description: The reusable half of the flagship — every grid, form input, dialog, and toast is a drop-in component from fitz_liveviews.ui.*, themed through design tokens, translated ES/EN, and shipped with a one-command Postgres + Docker setup.
tags: webdev, rust, opensource, frontend
series: FitzLiveViews
cover_image:
canonical_url:
---

> TL;DR — The [Admin flagship](https://github.com/Thegreekman76/fitz-liveviews/tree/main/examples/admin) isn't just an app — it's the app the **companion UI library** (`fitz_liveviews.ui.*`) was *extracted* from. The DataGrid, the sortable headers, the toolbar, the pager, the confirm dialog, the toasts, the tree view, every form input — all drop-in components you `import` and render. They're themed through `--flv-*` design tokens (so a light/dark/auto switch is free), translated ES/EN through a tiny server-side dictionary, and the whole thing runs with one `docker compose up`. This closes the flagship trilogy. *(Part 6 of the FitzLiveViews series.)*

Parts [4](https://dev.to/) and [5](https://dev.to/) showed the flagship's auth and its live grid. This one is about *reuse*: the app is built almost entirely from packaged components, and this is how you'd build yours.

> **Excerpts from the real app** ([`examples/admin/`](https://github.com/Thegreekman76/fitz-liveviews/tree/main/examples/admin)); the runnable path is `git clone` + `docker compose up`.

## The library was mined from this app

Open the top of the employees screen and you see the library, imported piece by piece — this is verbatim from the app:

```
from fitz_liveviews.ui.DataGrid import data_grid, data_grid_render
from fitz_liveviews.ui.SortableHeader import sortable_header, sortable_header_render
from fitz_liveviews.ui.GridToolbar import grid_toolbar, grid_toolbar_render
from fitz_liveviews.ui.GridFilters import grid_filters, grid_filters_render
from fitz_liveviews.ui.Pager import pager, pager_render
from fitz_liveviews.ui.ConfirmDialog import confirm_dialog, confirm_dialog_render, ...
from fitz_liveviews.ui.Toast import toast, toast_render, toast_show, toast_dismiss
from fitz_liveviews.ui.TreeView import tree_view, tree_view_render
from fitz_liveviews.ui.Chip import chip, chip_render
from fitz_liveviews.ui.CountBadge import count_badge, count_badge_render
```

Each is a `fitz.toml` dependency sub-path (`fitz_liveviews.ui.X`) — the cross-directory / dependency import that lets you pull a component out of the library instead of copying it. You render one by building its props and taking `.raw`:

```
let filters = grid_filters_render(grid_filters {
  pills: estado_pills,
  filter_label: t(locale, "grid.col.estado"),
}).raw
```

The employee row (`EmpleadoRow`) stays app-specific on purpose — it's the domain row, re-rendered N times per live frame. Everything *around* it is the library. The catalog is in [`docs/ui-components.md`](https://thegreekman76.github.io/fitz-liveviews/ui-components/), and you can play with the components in isolation in the [gallery](https://thegreekman76.github.io/fitz-liveviews/live/).

## One theme switch, everywhere

Every packaged component reads its colors from `--flv-*` design tokens (`--flv-color-primary`, `--flv-surface`, `--flv-text`, …). The app defines those tokens once, aliased to its palette, with light and dark values behind a `data-theme` attribute. A tiny inline script sets that attribute **before first paint** from the saved preference — so there's no flash — and the theme switch just flips it. Because *every* component reads the same tokens, the whole panel — grid, forms, dialogs, chips — switches light/dark/auto in one move. No per-component theme wiring.

## i18n without a library

Translation is a server-side dictionary — no i18n framework, no build step:

```
// i18n.fitz
fn t(locale: Str, key: Str) -> Str { ... }   // "es"/"en" + key → string
```

Every user-facing string goes through `t(locale, "grid.search")`. The active locale comes from a cookie; a `GET /lang/{code}` handler sets it and redirects back:

```
@get("/lang/{code}")
fn set_lang(code: Str, referer: Str?) -> Response {
  let cookie = lang_cookie_name() + "=" + loc + "; Path=/; SameSite=Lax; Max-Age=31536000"
  return Response {
    status: 303,
    headers: { "Set-Cookie": cookie, "Location": back },   // back to where you were
  }
}
```

The `🌐 ES / EN` switch in the topbar hits that route. Because rendering is server-side, switching language re-renders every string on the next frame — including inside the live grid.

## One command to run it

The whole stack — Postgres with schema + seed, and the app — is one `docker compose up`:

```yaml
services:
  db:
    image: postgres:16-alpine
    environment: { POSTGRES_USER: fitz, POSTGRES_PASSWORD: fitz, POSTGRES_DB: fitz_admin }
    volumes:
      - ./db/init.sql:/docker-entrypoint-initdb.d/init.sql:ro   # schema + seed
    healthcheck: { test: ["CMD-SHELL", "pg_isready -U fitz -d fitz_admin"], ... }
  app:
    build: { context: ../.., dockerfile: examples/admin/Dockerfile }
    depends_on: { db: { condition: service_healthy } }
    environment:
      DATABASE_URL: "postgres://fitz:fitz@db:5432/fitz_admin?sslmode=disable"
    ports: ["3000:3000"]
```

The `Dockerfile` is two stages: a `fitz build` in the official Fitz image, then the resulting **native binary** copied into a `distroless` runtime — no interpreter, no Python, no node. Postgres runs `db/init.sql` (schema + seed) on first boot; the app waits for the healthcheck and serves. `fitz run` and the built binary render bit-for-bit identical, so you develop on the interpreter and ship the binary.

```bash
git clone https://github.com/Thegreekman76/fitz-liveviews
cd fitz-liveviews/examples/admin
docker compose up --build
# → http://localhost:3000/   login: admin@fitz.dev / admin1234
```

## The whole stack, one language

Step back and look at what that one command brings up: cookie auth (Argon2id + JWT), a responsive themed shell, live DataGrids querying Postgres over WebSockets, rich forms, i18n, CSV export, all built from a packaged UI library — and it's **one language, one binary, no JavaScript build, no `node_modules`**. That's the pitch from part 1, proven on something real.

## That's the series (for now)

Six posts: the pitch, the counter twice, forms and payloads, and the flagship in three parts. If any of it made you curious, the best next step is to run the flagship — `docker compose up` — and then read the same components in the [catalog](https://thegreekman76.github.io/fitz-liveviews/ui-components/).

Star the [repo](https://github.com/Thegreekman76/fitz-liveviews), try it, and tell me what you'd build with it.
