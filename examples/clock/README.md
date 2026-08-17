# Server-pushed clock — `@every` (Phase 3c)

A live **HH:MM:SS** clock with **no buttons and no polling**. The *server* pushes
the current time every second. Each connection spawns a background ticker that
sleeps a second, re-renders `DateTime.now()`, and pushes the frame.

## Run

```
fitz run
```

Open <http://127.0.0.1:3000/> — the time updates every second on its own.

## The `@every` pattern

There's no `@every` decorator (yet) — it's a small, explicit pattern over the
async/spawn primitives: a `@background` fn loops on `sleep` + push, spawned per
connection with the socket handle.

```
@background
async fn clock_tick(ws: WsConn<LiveFrame>) {
  loop {
    let _ = sleep(1000).await
    let t = DateTime.now().format("%H:%M:%S")
    let _ = dispatch_to("Clock", "room", "tick", {"now": t})
    ws.send(flv_frame("Clock", "room"))?      // ? ends the ticker when the tab closes
  }
}

@ws("/live/clock")
async fn clock_socket(ws: WsConn<LiveFrame>) {
  spawn(clock_tick(ws))                        // ws is cloned into the task
  loop {
    let r = ws.recv()
    match r { Ok(f) => { dispatch_component_events(f) }, Err(_) => { break } }
  }
}
```

- `spawn(clock_tick(ws))` — `WsConn` is accepted as a `@background` parameter and
  a `spawn` argument (no core change needed).
- `ws.send(...)?` doubles as cleanup: when the socket closes the send errors and
  `?` ends the ticker, so nothing leaks.
- `flv_frame(name, id)` is a full-re-render frame; for a diffed push, thread a
  per-loop `last` and send `diff_html(last, now)` instead.

**Per-connection vs shared:** this demo uses `ws.send` (each connection ticks
itself). For shared state, use `ws.broadcast` — every connection's ticker still
fires, but the writes are idempotent and all clients stay in sync.
