# Dashboard — reusable metric tiles (Phase 4 showcase)

Six identical metric tiles rendered from a `TileConfig` list. Each
tile is an independent instance of the same
`@live_component("metric_tile")` — pressing `+1` or `reset` on one
tile updates *only* that tile's state, and every open browser sees the
patch via `ws.broadcast(...)`.

Source: [`examples/dashboard/`](https://github.com/Thegreekman76/fitz-liveviews/tree/main/examples/dashboard)

## Why this example exists

The kanban shows what `@live_component` looks like when *one*
component instance lives inside a larger app (the card editor).
This example shows what it looks like when *many* instances of the
same component sit next to each other — the "duplicate the widget
N times without duplicating the logic" case that composable UI
frameworks are supposed to shine at.

The parent WS handler has **zero** explicit event branches. Every
event is a component event (`bump` or `reset` scoped to one tile).
`dispatch_component_events(frame)` handles the routing; the parent
just re-renders and broadcasts.

## Run

```powershell
cd examples/dashboard
fitz run
```

Open http://127.0.0.1:3000/ in **two browser windows**. Click `+1`
on the "Users Signed Up" tile a few times. Only that tile's count
increments — in both windows, at the same time. Click `reset` on
another tile — that other tile clears independently.

## What each file does

- **`fitz.toml`** — package manifest with `fitz_liveviews` path
  dependency
- **`src/main.fitz`** — the whole dashboard, split cleanly:
    1. `@live_component("metric_tile")` + `MetricTile { count }`
       — one component definition, all tiles share it
    2. `@render_for("metric_tile")` + two `@on(...)` handlers —
       `bump` and `reset`
    3. `type TileConfig { id, label, accent }` — the
       parent-owned per-tile styling (label + accent color)
    4. `let TILES: List<TileConfig>` — six tiles by config
    5. `render_tile`, `render_dashboard` — the view
    6. `DASHBOARD_CSS` — grid + accents + responsive breakpoint
    7. `flv_register("metric_tile", ...)` — one call at boot
    8. `@get("/")` and `@ws("/live/dashboard")` — the handlers

## The composition pattern

The component owns per-instance **state** (the counter). The parent
owns per-tile **config** (the label and accent color). They compose
via a wrapping card:

```fitz
fn render_tile(tile: TileConfig) -> Html {
  let inner = component("metric_tile", tile.id)
  return html("""<article class="tile tile-{tile.accent}">
    <header class="tile-header">
      <h3 class="tile-label">{flv(tile.label)}</h3>
    </header>
    {inner.raw}
  </article>""")
}
```

- The `<article>` is parent-controlled. It carries the label and the
  accent class.
- `{inner.raw}` inlines the component's rendered body (counter +
  buttons + the framework's wrapper div with `data-flv-component-name`
  and `data-flv-value-instance_id`).
- Click events from inside `{inner.raw}` walk up to the framework's
  wrapper, pick up `component_name` + `instance_id`, and route via
  `dispatch_component_events(frame)` to the correct tile's state.

## The zero-branch WS handler

```fitz
@ws("/live/dashboard")
async fn dashboard_socket(ws: WsConn<LiveFrame>) {
  loop {
    let frame = ws.recv()?
    if (last_dashboard_html == "") {
      last_dashboard_html = render_dashboard().raw
    }
    let _handled = dispatch_component_events(frame)
    let new_html = render_dashboard().raw
    let patches = diff_html(last_dashboard_html, new_html)
    ws.broadcast(LiveFrame { html: new_html, patches: patches })?
    last_dashboard_html = new_html
  }
}
```

Compare this to a hand-written version without components: you would
need six pairs of `if (frame.event == "bump_signups")` /
`if (frame.event == "bump_revenue")` branches, or one branch keyed on
`frame.payload["tile_id"]` — either way you would end up hand-rolling
a per-tile state store. `dispatch_component_events` collapses all
that boilerplate.

## Responsive by default

The tile grid uses `grid-template-columns: repeat(auto-fill,
minmax(220px, 1fr))`. Wide viewports get 4-5 columns; medium ones
get 2-3; a phone at 375px gets 1. A media query below 480px stacks
everything and shrinks the counter font size. Verify in DevTools
with the iPhone SE viewport.

## What's missing (candidates for future work)

- **Per-tile config in the component** — today the label and accent
  are parent-supplied via the wrapping `<article>`. If we wanted the
  component to own them too, we would need per-instance seed data
  passed at `flv_register` or via a `data-flv-init` payload. Neither
  exists in Phase 4 MVP.
- **Persistent counts** — every restart resets the store. Wire up
  Fitz's ORM if you need this.
- **Bulk actions** — a "reset all" button. Would need a parent-side
  event that iterates over all instance ids and calls each tile's
  handler manually, or the framework could expose a
  `dispatch_to_all(component_name, event, payload)` helper. Not in
  scope for Phase 4 MVP.
