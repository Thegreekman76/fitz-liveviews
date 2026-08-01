---
title: "Construyendo el flagship (3): una librería de UI empaquetada, i18n, y Docker de un comando"
published: false
description: La mitad reusable del flagship — cada grilla, input de form, diálogo y toast es un componente drop-in de fitz_liveviews.ui.*, tematizado con design tokens, traducido ES/EN, y con un setup Postgres + Docker de un comando.
tags: webdev, rust, opensource, frontend
series: FitzLiveViews español
cover_image:
canonical_url:
---

> TL;DR — El [Admin flagship](https://github.com/Thegreekman76/fitz-liveviews/tree/main/examples/admin) no es solo una app — es la app de la que se *extrajo* la **librería de UI empaquetada** (`fitz_liveviews.ui.*`). El DataGrid, los headers ordenables, la toolbar, el pager, el diálogo de confirmación, los toasts, el tree view, cada input de form — todos componentes drop-in que `import`ás y renderizás. Están tematizados con design tokens `--flv-*` (así un switch light/dark/auto es gratis), traducidos ES/EN con un diccionario chiquito del lado del servidor, y todo corre con un `docker compose up`. Esto cierra la trilogía del flagship. *(Parte 6 de la serie FitzLiveViews.)*

Las partes [4](https://dev.to/) y [5](https://dev.to/) mostraron la auth del flagship y su grid en vivo. Esta es sobre *reuso*: la app está construida casi enteramente con componentes empaquetados, y así construirías la tuya.

> **Extractos de la app real** ([`examples/admin/`](https://github.com/Thegreekman76/fitz-liveviews/tree/main/examples/admin)); el camino runnable es `git clone` + `docker compose up`.

## La librería se extrajo de esta app

Abrí el tope de la pantalla de empleados y ves la librería, importada pieza por pieza — esto es textual de la app:

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

Cada uno es un sub-path de dependencia del `fitz.toml` (`fitz_liveviews.ui.X`) — el import cross-directory / de dependencia que te deja sacar un componente de la librería en vez de copiarlo. Renderizás uno construyendo sus props y tomando `.raw`:

```
let filters = grid_filters_render(grid_filters {
  pills: estado_pills,
  filter_label: t(locale, "grid.col.estado"),
}).raw
```

La fila de empleado (`EmpleadoRow`) queda app-específica a propósito — es la fila del dominio, re-renderizada N veces por frame en vivo. Todo lo que la *rodea* es la librería. El catálogo está en [`docs/ui-components.md`](https://thegreekman76.github.io/fitz-liveviews/ui-components/), y podés jugar con los componentes aislados en la [galería](https://thegreekman76.github.io/fitz-liveviews/live/).

## Un switch de tema, en todos lados

Cada componente empaquetado lee sus colores de design tokens `--flv-*` (`--flv-color-primary`, `--flv-surface`, `--flv-text`, …). La app define esos tokens una vez, aliaseados a su paleta, con valores light y dark detrás de un atributo `data-theme`. Un script inline chiquito setea ese atributo **antes del primer paint** desde la preferencia guardada — así no hay flash — y el switch de tema solo lo cambia. Como *todos* los componentes leen los mismos tokens, todo el panel — grid, forms, diálogos, chips — cambia light/dark/auto de una. Sin cablear el tema por componente.

## i18n sin librería

La traducción es un diccionario del lado del servidor — sin framework de i18n, sin paso de build:

```
// i18n.fitz
fn t(locale: Str, key: Str) -> Str { ... }   // "es"/"en" + key → string
```

Cada string user-facing pasa por `t(locale, "grid.search")`. El locale activo viene de una cookie; un handler `GET /lang/{code}` la setea y redirige de vuelta:

```
@get("/lang/{code}")
fn set_lang(code: Str, referer: Str?) -> Response {
  let cookie = lang_cookie_name() + "=" + loc + "; Path=/; SameSite=Lax; Max-Age=31536000"
  return Response {
    status: 303,
    headers: { "Set-Cookie": cookie, "Location": back },   // de vuelta a donde estabas
  }
}
```

El switch `🌐 ES / EN` en la topbar pega a esa ruta. Como el render es del lado del servidor, cambiar idioma re-renderiza cada string en el próximo frame — incluso adentro del grid en vivo.

## Un comando para correrlo

Todo el stack — Postgres con schema + seed, y la app — es un `docker compose up`:

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

El `Dockerfile` son dos stages: un `fitz build` en la imagen oficial de Fitz, después el **binario nativo** resultante copiado a un runtime `distroless` — sin intérprete, sin Python, sin node. Postgres corre `db/init.sql` (schema + seed) al primer boot; la app espera el healthcheck y sirve. `fitz run` y el binario buildeado renderizan bit-a-bit idéntico, así que desarrollás sobre el intérprete y shipeás el binario.

```bash
git clone https://github.com/Thegreekman76/fitz-liveviews
cd fitz-liveviews/examples/admin
docker compose up --build
# → http://localhost:3000/   login: admin@fitz.dev / admin1234
```

## Todo el stack, un lenguaje

Alejate y mirá lo que ese comando levanta: auth por cookie (Argon2id + JWT), un shell responsive tematizado, DataGrids en vivo consultando Postgres por WebSockets, forms ricos, i18n, export CSV, todo construido con una librería de UI empaquetada — y es **un lenguaje, un binario, sin build de JavaScript, sin `node_modules`**. Ese es el pitch de la parte 1, probado en algo real.

## Esa es la serie (por ahora)

Seis posts: el pitch, el counter dos veces, forms y payloads, y el flagship en tres partes. Si algo te dio curiosidad, el mejor próximo paso es correr el flagship — `docker compose up` — y después leer los mismos componentes en el [catálogo](https://thegreekman76.github.io/fitz-liveviews/ui-components/).

Dale una estrella al [repo](https://github.com/Thegreekman76/fitz-liveviews), probalo, y contame qué construirías con esto.
