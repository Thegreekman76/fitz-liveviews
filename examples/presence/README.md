# Presence counter — lifecycle hooks (Phase 3c)

A live **"N online"** counter with **no buttons**. The count is driven entirely
by the WebSocket lifecycle:

- **`event on_mount()`** → fires when a client connects (`flv_mount`), bumping a
  shared count.
- **`event on_disconnect()`** → fires when a client's socket closes
  (`flv_disconnect`), dropping it.

Every change is broadcast to everyone still connected — `ws.broadcast(...)`
delivers even after the disconnecting socket has closed, so the "farewell" frame
lands.

## Run

```
fitz run
```

Open <http://127.0.0.1:3000/> in two or three tabs — the count climbs. Close a
tab — it drops, live, in the others.

## How the hooks fire

Fitz-core `@ws` can't intercept `recv`, so the loop fires the hooks itself. The
shape matters: `ws.recv()?` *returns from the handler* on disconnect, so the
leave hook would never run. Match on `recv()` with `Err(_) => break`, then fire
`flv_disconnect` after the loop:

```
async fn presence_socket(ws: WsConn<LiveFrame>) {
  let _ = flv_mount("Presence", "room")                    // on connect
  ws.broadcast(...)?                                        // tell everyone
  loop {
    let r = ws.recv()
    match r {
      Ok(frame) => { dispatch_component_events(frame); ws.broadcast(...)? }
      Err(_)    => { break }
    }
  }
  let _ = flv_disconnect("Presence", "room")                // on close
  let _ = ws.broadcast(...)                                 // farewell to the rest
}
```

`flv_mount` / `flv_disconnect` are thin wrappers over `dispatch_to` — a silent
no-op if the component declares no such handler, so they're always safe to call.
