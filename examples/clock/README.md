# Server-pushed clock — `@every` global ticker (Phase 3c)

A live **HH:MM:SS** clock with **no buttons and no polling**. A **single global**
`@every(1)` ticker re-renders the shared clock and `ws_broadcast`s it to every
connected tab — no per-connection `spawn`.

## Run

```
fitz run
```

Open <http://127.0.0.1:3000/> in one or more tabs — the time updates every second
on its own, the same across all of them.

## The `@every` pattern (shared state, done right)

Fitz core has an **`@every(N)` decorator** (v0.42.0): it runs a top-level fn every
N seconds, server-wide, from boot. Combined with `ws_broadcast(...)`, that's one
global ticker for all clients — no `spawn(tick(ws))` per connection.

```
@every(1)
async fn clock_tick() -> Null {
  let t = DateTime.now().format("%H:%M:%S")
  let _ = dispatch_to("Clock", "room", "tick", {"now": t})
  ws_broadcast("/live/clock", flv_frame("Clock", "room"))   // → every connected tab
  return null
}

@ws("/live/clock")
async fn clock_socket(ws: WsConn<LiveFrame>) {
  // immediate first frame so a new tab doesn't wait for the next global tick
  let t0 = DateTime.now().format("%H:%M:%S")
  let _ = dispatch_to("Clock", "room", "tick", {"now": t0})
  ws.send(flv_frame("Clock", "room"))?
  loop {
    let r = ws.recv()
    match r { Ok(f) => { dispatch_component_events(f) }, Err(_) => { break } }
  }
}
```

- **`@every(1)`** — the whole ticker is a decorator on a plain top-level fn; no
  `spawn`, no `WsConn` param, no manual loop. First tick after 1 s; it coexists
  with `@server`/`@ws`.
- **`ws_broadcast(endpoint, msg)`** reaches every client on the endpoint from a
  scheduler task (needs Fitz core ≥ v0.42.1, which installs a global broadcaster
  so a scheduler on a worker thread can broadcast).
- The `@ws` handler only sends the **initial** frame on connect and then reads
  events; the periodic updates all come from the one global ticker.

**Per-connection vs global:** for per-client state (a session timer, "your data")
use the per-connection pattern — a `@background` ticker `spawn`ed with the socket,
pushing with `ws.send`. For **shared** state like a clock, the global `@every` +
`ws_broadcast` above is one ticker for everyone.
