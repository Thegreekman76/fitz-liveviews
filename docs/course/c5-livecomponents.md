# C5 — LiveComponents

**Prerequisite:** [C4](c4-persistent-multiuser.md) — you know when to reach for
an SFC (in-memory UI state) versus a string-helper handler (the database).

**Objective:** define a component **once** and render **many independent
instances** of it, each with its own state.

**Why it matters:** C1–C4 had one component per page. Real screens repeat a
*stateful* widget: a metric tile on a dashboard, a card editor on every kanban
card, an expand/collapse on every row. You don't want one shared counter for all
of them — you want each instance to own its slice of state. That's a
**LiveComponent**: one definition, `component("Name", "<instance-id>")` per copy,
independent state each.

---

## The idea: an instance is a name + an id

You've already been calling `component("Name", "id")` to mount a single SFC (the
`main.fitz` wiring since C1). The second argument is the **instance id**, and
it's the whole trick: the framework keeps a separate state store per
`(component name, instance id)` pair. Mount the same component under two
different ids and you get two independent instances.

So a dashboard of three counters is *one* `Tile` component and three ids.

---

## The component

Nothing new here — it's the counter from C1, as an SFC:

```fitz
--8<-- "course/c5-metric-tiles/src/Tile.fitzv"
```

---

## The parent renders many

The parent owns the *layout and config* (which tiles, what labels); each `Tile`
owns its *state* (its count). They compose by the parent calling
`component("Tile", cfg.id)` once per tile — the
[`examples/course/c5-metric-tiles`](https://github.com/Thegreekman76/fitz-liveviews/tree/main/examples/course/c5-metric-tiles)
project:

```fitz
--8<-- "course/c5-metric-tiles/src/main.fitz"
```

Run it (`cd examples/course/c5-metric-tiles && fitz run`) and open
http://127.0.0.1:3000/. Press **+1** on "Downloads" — only that tile's number
moves. "Signups" and "Errors" don't budge. Three counters, one definition.

---

## Reading it

**`component("Tile", cfg.id)` is the instance.** Each `TileCfg` carries a unique
`id` (`"downloads"`, `"signups"`, `"errors"`). `render_tile` mounts the `Tile`
component under that id and wraps it in a card with the parent-supplied label.
Same component, three instances, three independent `count`s.

**The parent owns config, the component owns state.** The label lives in
`TileCfg` (parent data); the count lives in `Tile`'s `state` (per instance).
That split keeps the component reusable — it knows nothing about labels or
layout, just how to count.

**`dispatch_component_events(frame)` routes to the right instance.** When you
click +1 on a tile, the client sends the event *with that tile's instance id*
(the framework reads it from the `data-flv-component-name` / instance wrapper the
composition emits). `dispatch_component_events` looks up the matching instance
and mutates only its state. The `@ws` loop is the same generic three lines from
C1 — it never grows as you add tiles or events.

**No per-instance wiring.** You didn't write an `if frame.event == ...` for each
tile. One component, one dispatch call, N instances — the handler doesn't care
how many.

---

## When to reach for a LiveComponent

- **You have N of the same stateful widget** — dashboard tiles, kanban card
  editors, per-row expand toggles, a list of independently-editable items.
- **Each needs its own slice of UI state** — open/closed, editing/not,
  a local count, a draft value.
- **You want the parent handler to stay small** — every event the component
  handles disappears from the parent's dispatch.

You do **not** need a LiveComponent for a single stateful widget with no
siblings (put the state in the page's `@ws` handler) or a pure formatting
fragment (a plain `fn -> Html` helper, C3). And remember C4's boundary: component
state is **in-memory** — for shared, durable data, the database + a string-helper
handler is still the tool.

This is the pattern behind the two flagship showcases: the
[dashboard](../examples/dashboard.md) (six independent `metric_tile` instances)
and the [kanban](../examples/kanban.md) (a `card_editor` per card). Both are this
chapter, scaled up.

---

## Checkpoint

- [x] Three tiles render from one `Tile` component.
- [x] Bumping one tile changes only that tile — per-instance state is isolated.
- [x] The `@ws` handler is the same generic loop regardless of tile count.
- [x] You can say what the instance id (`component("Name", "id")`) does.

---

## Troubleshooting

!!! failure "All tiles change together"
    They're sharing one instance id. Each `component("Tile", "<id>")` needs a
    **distinct** id — reuse the same string and you get one shared instance.

!!! failure "Clicking a tile does nothing"
    The composition wrapper carries the instance context for
    `dispatch_component_events` to route on. Make sure you mount via
    `component("Tile", id)` (which emits that wrapper), not by pasting the
    component's raw HTML yourself.

---

## What's next

You can build reusable, independently-stateful components. **C6 — Ship it** is
the last step: `fitz build` turns any of these projects into a single native
binary, and a small Dockerfile puts it in a container — the same path the
[Admin ABM](../examples/admin.md) uses to deploy.
