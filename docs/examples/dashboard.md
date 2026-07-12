# Dashboard — reusable metric tiles (Phase 4 showcase)

Six identical metric tiles rendered from a `TileConfig` list. Each
tile is an independent instance of the same
`@live_component("metric_tile")` — pressing `+1` or `reset` on one
tile updates *only* that tile's state, and every open browser sees
the patch via broadcast.

Source: [`examples/dashboard/`](https://github.com/Thegreekman76/fitz-liveviews/tree/main/examples/dashboard)

## Why this example exists

The kanban shows what `@live_component` looks like when **one**
component instance lives inside a larger app (the card editor). This
example shows what it looks like when **many** instances of the same
component sit next to each other — the "duplicate the widget N times
without duplicating the logic" case that composable UI frameworks are
supposed to shine at.

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

## The whole source

```fitz
--8<-- "dashboard/src/main.fitz"
```

## Anatomy — the composition pattern

The component owns per-instance **state** (the counter). The parent
owns per-tile **config** (label + accent color). They compose via a
wrapping card:

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
  buttons + the framework's wrapper div with
  `data-flv-component-name` and `data-flv-value-instance_id`).
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

## Full component walkthrough

For the API surface (`@live_component` / `@render_for` / `@on` /
`flv_register` / `component` / `dispatch_component_events`), the
canonical `@ws` loop pattern, gotchas of gradual typing at the
framework boundary, and what the framework does *not* yet provide,
see [`docs/components.md`](../components.md).

## Known limitations

- **Per-tile config is parent-supplied.** Today the label and accent
  live outside the component. If we wanted the component to own them
  too, we would need per-instance seed data. Not in Phase 4 MVP.
- **No persistence.** Every restart resets the store. Wire up
  Fitz's ORM if you need this.
- **No bulk actions** (e.g., "reset all"). Would need a
  `dispatch_to_all(name, event, payload)` helper — not in scope for
  Phase 4 MVP.
