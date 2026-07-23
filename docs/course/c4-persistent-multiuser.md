# C4 — Persistent & multi-user state

**Prerequisite:** [C3](c3-composing-ui.md) — you can compose a screen from
helpers and back it with a `type`. You'll also need a running **PostgreSQL**
(the [ORM chapter of the Fitz guide](https://thegreekman76.github.io/fitz/guide/#postgres-orm-nativo)
covers `@table` if it's new to you).

**Objective:** move state out of memory and into the database, and keep two
browsers in sync — the step from "a nice demo" to "a real app".

**Why it matters:** so far every screen's state lived in the `@ws` handler's
locals — one copy per connection, gone when the socket closes. Real apps have
*shared, durable* data: a list two users both edit, a record that survives a
restart. That means the database is the source of truth, and every connection
renders a projection of it. Fitz's native ORM and `ws.broadcast(...)` make this
about fifteen lines.

---

## The shape

Three pieces change from C2's in-memory list:

1. **A `@table` type** — the note lives in Postgres, not a `List<Str>`.
2. **`render` queries the DB** — every render reads the current rows, so the
   screen always reflects the database.
3. **`ws.broadcast(...)`** instead of `ws.send(...)** — a change from *one*
   browser is pushed to *all* of them.

Here's the whole thing — the
[`examples/course/c4-shared-notes`](https://github.com/Thegreekman76/fitz-liveviews/tree/main/examples/course/c4-shared-notes)
project:

```fitz
--8<-- "course/c4-shared-notes/src/main.fitz"
```

---

## Run it

Point `DATABASE_URL` at a Postgres you can write to (or use the default in the
code), create the table, and run:

```bash
# one-time: create the table
psql "$DATABASE_URL" -c \
  "CREATE TABLE IF NOT EXISTS notes (id BIGSERIAL PRIMARY KEY, content TEXT NOT NULL)"

fitz run
```

Open http://127.0.0.1:3000/ in **two** browser tabs. Add a note in one — it
appears in **both**, instantly, and it's in the database. Restart the server:
the notes are still there.

---

## Reading it

**The database is the source of truth.** There's no `let notes = [...]` holding
state. `render` connects, runs `Note.where(fn(n) => n.id > 0).all(conn)`, and
builds the list from whatever's in the table right now. Add or delete, re-render,
and the new query reflects the change. Nothing to keep in sync by hand.

**`ws.broadcast` fans out to everyone.** `ws.send` replies to the one socket
that sent the event; `ws.broadcast` pushes the same frame to *every* connected
client. Because all clients render the same canonical list (the DB), one shared
`last_html` snapshot at the top level is correct for the diff — that's why it's
a top-level `let`, not a per-connection local.

**Writes are ordinary ORM calls.** `Note.insert(conn, Note { content: c })` and
`Note.where(fn(x) => x.id == n).delete(conn)` — the same ORM you'd use in a plain
`@post` handler. The event carries the id via `data-flv-value-id="{n.id}"` (the
C2 pattern), and `get_or(...).to_int()` parses it back.

**Connect per event, not once.** The handler opens a connection inside the loop
per event rather than holding one open for the socket's lifetime — simplest and
safe; a connection pool is a refinement, not a requirement.

---

## Why this chapter is string-helper only

C1–C3 showed each screen in both the string-helper form and the SFC (`.fitzv`)
form. C4 is deliberately just the string-helper form — and the reason is the
best "when to use each" lesson in the course:

**The SFC model is for in-memory UI state, not database-as-truth.** Two concrete
walls:

1. **An SFC's render is state-in.** `@render_for fn X_render(state: X) -> Html`
   takes the component's state and returns markup. It doesn't (and can't) run a
   `db.connect(...).await` to read the current rows — so there's no way to
   *display* the database from inside a component.
2. **SFC event handlers can't `.await` yet.** Try an async DB write inside an
   `event` block and the SSR emitter stops you:
   *"event body RHS uses `.await` — the SSR walker does not yet handle. Deferred
   to Phase 11.7+."* So a component can't *write* to the database in an event
   either, for now.

The `@ws` handler has neither limit: it's a plain `async fn`, so it connects,
queries, mutates, and broadcasts freely. That's the rule of thumb C4 nails down:

- **SFC** — per-instance UI state that lives and dies in the browser session
  (an edit toggle, a filter, a stepper, a counter).
- **String-helper `@ws` handler** — anything that touches the database, is
  shared across users, or must persist.

Real apps use both: SFCs for the interactive widgets, `@ws` handlers (with
helpers) for the data. You already have both tools; C4 is where the boundary
between them becomes obvious.

---

## Checkpoint

- [x] The notes list renders from Postgres on load.
- [x] Adding/removing a note in one tab updates **both** tabs (broadcast).
- [x] The data survives a server restart (it's in the DB).
- [x] You can say why a DB-backed list is a `@ws` handler, not an SFC.

---

## Troubleshooting

!!! failure "`DB error: ...` on the page"
    The app couldn't connect. Check `DATABASE_URL` and that Postgres is running
    and reachable. The default in the example points at
    `postgres://fitz:fitz@localhost:5432/fitz_course`.

!!! failure "`relation \"notes\" does not exist`"
    Create the table (the `psql ... CREATE TABLE` line above). The app doesn't
    create it for you.

!!! failure "Two tabs don't sync"
    You're using `ws.send` instead of `ws.broadcast`. `send` only replies to the
    sender; `broadcast` reaches every client.

!!! failure "`.await` rejected inside an `event` block"
    That's expected (see "Why this chapter is string-helper only"). Move the DB
    work into the `@ws` handler.

---

## What's next

You can persist and share state. **C5 — LiveComponents** goes the other
direction: reusable components with their *own* per-instance state
(`@live_component`), the pattern behind the kanban card editor and the dashboard
tiles — exactly the in-memory UI state the SFC form is built for. The
[kanban](../examples/kanban.md) and [dashboard](../examples/dashboard.md)
examples are where this lands.
