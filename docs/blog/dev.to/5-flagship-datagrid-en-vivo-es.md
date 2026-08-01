---
title: "Construyendo el flagship (2): un DataGrid en vivo que consulta Postgres en cada tecla"
published: false
description: La pieza central del flagship — una grilla de empleados donde search, filtros, sort y paginación son SQL real contra Postgres, re-ejecutado y diff-parcheado por WebSocket en cada interacción, con estado per-connection. Sin framework de cliente.
tags: webdev, rust, opensource, frontend
series: FitzLiveViews español
cover_image:
canonical_url:
---

> TL;DR — La pantalla de empleados del [Admin flagship](https://github.com/Thegreekman76/fitz-liveviews/tree/main/examples/admin) es un **DataGrid en vivo**: tipeás en el buscador, clickeás un pill de filtro, ordenás una columna, paginás — y cada uno re-ejecuta una **query SQL real** contra Postgres por el ORM de Fitz, después diff-parchea la tabla por WebSocket. Nada se filtra en memoria; el `count` refleja los filtros activos; el sort es un `ORDER BY` dinámico. Todo el estado del grid (término de búsqueda, filtros, sort, página) es **per-connection**, así que dos browsers filtran independientemente. Sin React, sin endpoints de API, sin manejo de estado en el cliente. *(Parte 5 de la serie FitzLiveViews — la pieza central del flagship.)*

La [parte 4](https://dev.to/) le dio al flagship auth y un shell. Esta es la pantalla que hace que valga la pena construirlo: una grilla de empleados que se comporta como una data table de SPA rica, pero es *enteramente* server-driven.

> **El código de abajo son extractos de la app real** ([`examples/admin/`](https://github.com/Thegreekman76/fitz-liveviews/tree/main/examples/admin)) — el grid completo son unos cientos de líneas. Los snippets muestran la forma fielmente; el camino garantizado-que-funciona es `git clone` + `docker compose up` (ver "Probalo").

## La forma

SSR pinta el grid una vez (así la primera carga es instantánea y crawleable), después un socket `@ws` toma la capa en vivo. Cada conexión guarda su propio estado del grid — el search, filtros, sort y página actuales — y en cada evento reconstruye la query, renderiza, diffea y parchea:

```
@header(name="cookie")
@ws("/live/empleados")
async fn live(ws: WsConn<LiveFrame>, cookie: Str?) {
  let user = match user_from_cookie(cookie).await { ... }   // gatea el socket
  let conn = db.connect(db_url()).await?

  // Estado del grid per-connection — dos browsers filtran independientemente.
  let q = ""            // término de búsqueda
  let estado = "all"    // Todos / Activos / Inactivos
  let depto = 0         // filtro de departamento (0 = todos)
  let sort_col = "nombre"
  let asc = true
  let page = 0

  let last = render_grid(conn, q, estado, depto, sort_col, asc, page).await

  loop {
    let frame = ws.recv()?
    // actualiza el estado desde el payload del evento
    q      = pget(frame.payload, "q", q)
    estado = pget(frame.payload, "estado", estado)
    depto  = pget_int(frame.payload, "depto", depto)
    // ... sort + page ...

    let html    = render_grid(conn, q, estado, depto, sort_col, asc, page).await
    let patches = diff_html(last, html)
    ws.send(LiveFrame { html: html, patches: patches })?
    last = html
  }
}
```

`pget` / `pget_int` solo leen el payload del evento (un `Map<Str, Str>`) con defaults — `str.to_int()` parsea el número de página y el id de departamento. Fijate que no hay branching por evento: el loop lee el payload al estado y re-renderiza. Agregás una dimensión de filtro agregando una variable de estado y un `.where`.

## Cada dimensión es SQL real

`render_grid` construye una query por el ORM de Fitz. Cada dimensión activa es un `.where` encadenado (que ANDean juntos), el sort es un `ORDER BY` dinámico, y la paginación es `LIMIT`/`OFFSET`:

```
async fn rows_for(conn, q, estado, depto, sort_col, asc, page) -> List<Empleado> {
  let query = Empleado.where(fn(e) => e.nombre.ilike("%" + q + "%"))

  // Los filtros de estado + departamento son más WHEREs ANDeados,
  // aplicados condicionalmente — todo es un solo statement SQL.
  // ... .where(fn(e) => e.activo == true) ...
  // ... .where(fn(e) => e.departamento_id == depto) ...

  return query
    .order_by(sort_col, asc)          // ORDER BY <col> ASC|DESC dinámico
    .limit(PAGE_SIZE)
    .offset(page * PAGE_SIZE)
    .all(conn).await
}
```

El **count refleja los filtros** — la misma cadena de `.where`, terminada con `.count(conn)` en vez de `.all` — así que "mostrando 8 de 23" es honesto, no una adivinanza del cliente. El search es `ilike("%q%")` (`LIKE` case-insensitive); los pills de estado mapean a `.where(e.activo == …)`; los de departamento a `.where(e.departamento_id == …)`. Todo es SQL, todo tipado, todo en el mismo archivo `.fitz` que el socket.

## Qué hace el browser

Nada que escribas vos. Los controles del grid son las mismas convenciones `data-flv-*` de la [parte 3](https://dev.to/): el buscador es un input `data-flv-change` que manda `{"q": "<texto>"}`, un pill de filtro es un `data-flv-click` con un `data-flv-value-estado`, un header ordenable manda `{"sort": "cargo"}`. El framework las serializa al mensaje del socket; tu loop las lee de `frame.payload`. El motor de diff manda solo los `<tr>` que cambiaron. El diffing por key (`{#for … key=e.id}`) hace que un insert en el medio de la lista (una fila nueva de un save) parchee limpio en vez de cascadear.

El resultado se siente como una data table de cliente — search instantáneo, sort ágil — pero la fuente de verdad es Postgres, la query es real, y hay cero estado de cliente que mantener en sync con el servidor.

## Per-connection, gratis

Como el estado del grid vive en las variables locales del loop `@ws`, **cada conexión tiene el suyo**. Dos admins en la misma página filtran independientemente; no hay store de cliente compartido, ni malabares de query-params. Abrí la app en dos pestañas y filtrá cada una distinto — no se interfieren. Ese aislamiento es simplemente... cómo funcionan las variables locales del lado del servidor.

La misma pantalla también hace selección de filas + multi-delete, group-by, expand por fila, y un export CSV (un `Response { content_type: "text/csv", ... }` que bakea el search activo en su `href`). Todo eso son más cadenas de `.where` y más diffs.

## Probalo

```bash
cd fitz-liveviews/examples/admin && docker compose up --build
# → http://localhost:3000/empleados   (login: admin@fitz.dev / admin1234)
```

Tipeá en el buscador, clickeá los pills de estado/departamento, ordená una columna, paginá — cada uno es un round-trip a Postgres, diffeado de vuelta a tu tabla.

## Qué viene en la serie

- **#6 — La librería de UI empaquetada + i18n + Docker.** Cada pieza reusable de esta app — `DataGrid`, `GridToolbar`, `Pager`, `ConfirmDialog`, `Toast`, `TreeView`, los inputs del form — es un componente drop-in de `fitz_liveviews.ui.*`. La librería se *extrajo* de esta app. Más i18n ES/EN y el setup Docker de un comando.

Dale una estrella al [repo](https://github.com/Thegreekman76/fitz-liveviews) si un grid en vivo sobre Postgres sin framework de cliente es el tipo de cosa que usarías. Lo próximo: la librería de la que está todo construido.
