# Authenticated live socket (Phase 3c)

A LiveView whose WebSocket **only streams to a valid session cookie**. An
anonymous connection is dropped before the first frame — no framework magic,
no core change: the browser sends the same-origin **HttpOnly** session cookie on
the WS upgrade automatically, `@header(name="cookie")` reads it, and
`flv_cookie(...)` + `jwt.decode(...)` validate it.

## Run

```
fitz run
```

Open <http://127.0.0.1:3000/> — anonymous, you're redirected to `/login`. Log in
with **ada@example.com / secret**; the LiveView connects and shows *"Signed in as
ada@example.com"*. Click **Sign out** and the socket sends `flv_redirect("/login")`
so the tab navigates back. Headless-Chrome validated **6/6** (authenticated tab
renders + the socket is live; Sign out redirects to `/login`; an anonymous WS
gets a `flv_redirect` frame; anon `GET /` redirects to `/login`).

## Redirect frame (v0.47.0)

`flv_redirect(url) -> LiveFrame` is a frame the client turns into a
`window.location = url` navigation — a **server-initiated redirect**. Here the
anon socket bounces to `/login` instead of a silent close, and the **Sign out**
button triggers a redirect from the socket loop. Use it for an expired session
mid-stream, a "you were signed out", or a moved resource. (A real sign-out would
also clear the cookie via a `POST /logout`; the redirect is the navigation.)

## Pattern A — in-loop cookie validation (the MVP)

The gate is one `match` at connect, before the first render:

```
fn email_from_cookie(cookie: Str?) -> Str? {
  let token  = match flv_cookie(cookie, "flv_session") { null => { return null }, t => t }
  let claims = match jwt.decode(token, jwt_secret())   { Ok(c) => c, Err(_) => { return null } }
  return match claims.get("email") { Ok(e) => e, Err(_) => null }
}

@header(name="cookie")
@ws("/live/secure")
async fn secure_socket(ws: WsConn<LiveFrame>, cookie: Str?) {
  let email = match email_from_cookie(cookie) {
    null => { return },        // anon → silent close, zero frames
    e => e,
  }
  // ...validated: render + loop...
}
```

- `@header(name="cookie")` reads the handshake cookie — the browser sends the
  HttpOnly session cookie on the WS upgrade. (JS can't read it, so it can't
  travel through the `__flv_init` query channel — which is exactly why the
  cookie is the right transport.)
- The `return` before the first `ws.send` **closes the socket** — an anonymous
  client gets nothing.
- Login (`POST /login`) signs a JWT with `jwt.encode(...)` and sets it
  `HttpOnly; SameSite=Lax`. Zero client change, zero Fitz-core change.

## Pattern C — injected `user`, reject before the upgrade (optional upgrade)

If you'd rather the framework reject anon **with a 401 before the WS upgrade**
and **inject a `user: User`** (the "user injected" ergonomic), add one global
`@auth_provider` that reads the cookie header — it receives the full headers map:

```
@auth_provider
async fn check(headers: Map<Str, Str>) -> Result<User> {
  let cookie = match headers.get("cookie") { Ok(c) => c, Err(_) => return Err("no cookie") }
  // token_from_cookie + jwt.decode + user lookup...
  return Ok(user)
}

@authenticated
@ws("/live/secure")
async fn secure_socket(ws: WsConn<LiveFrame>, user: User) {
  // `user` is already validated + injected
}
```

Also zero Fitz-core change. Trade-off: one global provider per app, and the
socket fails with a JSON 401 instead of a silent close (fine — the SSR page
guard already handled the human redirect).
