---
title: "Building the flagship (2): a live DataGrid that queries Postgres on every keystroke"
published: false
description: The flagship's centerpiece — an employees grid where search, filters, sort, and pagination are real SQL against Postgres, re-run and diff-patched over a WebSocket per interaction, with per-connection state. No client framework.
tags: webdev, rust, opensource, frontend
series: FitzLiveViews
cover_image:
canonical_url:
---

> TL;DR — The [Admin flagship](https://github.com/Thegreekman76/fitz-liveviews/tree/main/examples/admin)'s employees screen is a **live DataGrid**: type in the search box, click a filter pill, sort a column, page through — and each one re-runs a **real SQL query** against Postgres through the Fitz ORM, then diff-patches the table over a WebSocket. Nothing is filtered in memory; the `count` reflects the active filters; the sort is a dynamic `ORDER BY`. All grid state (search term, filters, sort, page) is **per-connection**, so two browsers filter independently. No React, no API endpoints, no client state management. *(Part 5 of the FitzLiveViews series — the flagship's centerpiece.)*

[Part 4](https://dev.to/) gave the flagship auth and a shell. This is the screen that makes it worth building: an employees grid that behaves like a rich SPA data table, but is *entirely* server-driven.

> **The code below is excerpted from the real app** ([`examples/admin/`](https://github.com/Thegreekman76/fitz-liveviews/tree/main/examples/admin)) — the full grid is a few hundred lines. The snippets show the shape faithfully; the guaranteed-to-work path is `git clone` + `docker compose up` (see "Try it").

## The shape

SSR paints the grid once (so the first load is instant and crawlable), then a `@ws` socket takes over the live layer. Each connection keeps its own grid state — the current search, filters, sort, and page — and on every event it rebuilds the query, renders, diffs, and patches:

```
@header(name="cookie")
@ws("/live/empleados")
async fn live(ws: WsConn<LiveFrame>, cookie: Str?) {
  let user = match user_from_cookie(cookie).await { ... }   // gate the socket
  let conn = db.connect(db_url()).await?

  // Per-connection grid state — two browsers filter independently.
  let q = ""            // search term
  let estado = "all"    // Todos / Activos / Inactivos
  let depto = 0         // department filter (0 = all)
  let sort_col = "nombre"
  let asc = true
  let page = 0

  let last = render_grid(conn, q, estado, depto, sort_col, asc, page).await

  loop {
    let frame = ws.recv()?
    // update state from the event's payload
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

`pget` / `pget_int` just read the event payload (a `Map<Str, Str>`) with defaults — `str.to_int()` parses the page number and department id. Notice there's no per-event branching: the loop reads the payload into state and re-renders. Add a filter dimension by adding a state variable and a `.where`.

## Every dimension is real SQL

`render_grid` builds one query through the Fitz ORM. Each active dimension is a chained `.where` (they AND together), the sort is a dynamic `ORDER BY`, and pagination is `LIMIT`/`OFFSET`:

```
async fn rows_for(conn, q, estado, depto, sort_col, asc, page) -> List<Empleado> {
  let query = Empleado.where(fn(e) => e.nombre.ilike("%" + q + "%"))

  // Estado + department filters are more ANDed WHEREs, applied
  // conditionally — the whole thing is one SQL statement.
  // ... .where(fn(e) => e.activo == true) ...
  // ... .where(fn(e) => e.departamento_id == depto) ...

  return query
    .order_by(sort_col, asc)          // dynamic ORDER BY <col> ASC|DESC
    .limit(PAGE_SIZE)
    .offset(page * PAGE_SIZE)
    .all(conn).await
}
```

The **count reflects the filters** — the same `.where` chain, terminated with `.count(conn)` instead of `.all` — so "showing 8 of 23" is honest, not a client-side guess. Search is `ilike("%q%")` (case-insensitive `LIKE`); the estado pills map to `.where(e.activo == …)`; the department pills to `.where(e.departamento_id == …)`. It's all SQL, all typed, all in the same `.fitz` file as the socket.

## What the browser does

Nothing you write. The grid's controls are the same `data-flv-*` conventions from [part 3](https://dev.to/): the search box is a `data-flv-change` input that sends `{"q": "<text>"}`, a filter pill is a `data-flv-click` with a `data-flv-value-estado`, a sortable header sends `{"sort": "cargo"}`. The framework serializes those into the socket message; your loop reads them from `frame.payload`. The diff engine sends only the `<tr>`s that changed. Keyed diffing (`{#for … key=e.id}`) means a mid-list insert (a new row from a save) patches cleanly instead of cascading.

The result feels like a client-side data table — instant search, snappy sort — but the source of truth is Postgres, the query is real, and there's zero client state to keep in sync with the server.

## Per-connection, for free

Because the grid state lives in the `@ws` loop's local variables, **each connection has its own**. Two admins on the same page filter independently; there's no shared client store, no query-param juggling. Open the app in two tabs and filter each differently — they don't interfere. That isolation is just... how server-side local variables work.

The same screen also does row selection + multi-delete, group-by, per-row expand, and a CSV export (a `Response { content_type: "text/csv", ... }` that bakes the active search into its `href`). All of it is more `.where` chains and more diffs.

## Try it

```bash
cd fitz-liveviews/examples/admin && docker compose up --build
# → http://localhost:3000/empleados   (login: admin@fitz.dev / admin1234)
```

Type in the search, click the estado/department pills, sort a column, page through — every one is a round-trip to Postgres, diffed back to your table.

## What's next in this series

- **#6 — The packaged UI library + i18n + Docker.** Every reusable piece of this app — `DataGrid`, `GridToolbar`, `Pager`, `ConfirmDialog`, `Toast`, `TreeView`, the form inputs — is a drop-in component from `fitz_liveviews.ui.*`. The library was *extracted* from this app. Plus ES/EN i18n and the one-command Docker setup.

Star the [repo](https://github.com/Thegreekman76/fitz-liveviews) if a Postgres-backed live grid without a client framework is the kind of thing you'd use. Next: the library it's all built from.
