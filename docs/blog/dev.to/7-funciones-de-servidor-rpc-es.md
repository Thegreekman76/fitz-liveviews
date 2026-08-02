---
title: "Funciones de servidor en Fitz: llamá al server desde un componente WASM, sin plomería"
published: false
description: Una `@rpc async fn` en un módulo Fitz classic es llamable directo desde un `.fitzv` client-WASM — `get_user(42).await?` — como si fuera local. El compilador emite las dos mitades desde una sola declaración, tipada de punta a punta, cero dependencias.
tags: webdev, rust, opensource, frontend
series: FitzLiveViews español
cover_image:
canonical_url:
---

> TL;DR — Marcás una `async fn` con `@rpc` y la llamás desde un
> componente `.fitzv` **como si fuera local**: `let u =
> get_user(42).await?`. El compilador genera las **dos mitades** desde
> esa única declaración — un endpoint `POST /__rpc/get_user` del lado
> server (que puede tocar la DB, auth, secrets) y un stub `fetch` del
> lado client — con el mismo `type` compartido back y front. Sin handler
> HTTP a mano, sin `fetch`, sin JSON glue, sin rutas escritas a mano,
> sin deps externas. *(Parte 7 de la serie FitzLiveViews — el momento
> "todo el stack junto, sin plomería".)*

Las partes anteriores mostraron un componente `.fitzv` compilando de
**dos formas**: a HTML server-rendered (LiveViews sobre un WebSocket) y
a una SPA WebAssembly standalone. Las dos están buenas — pero un
componente en el browser es una isla. Cualquier cosa *real* —leer la
base, verificar un token— tiene que pasar en el server, y el puente
clásico es plomería: escribís un endpoint, escribís un `fetch`, parseás
el JSON de ida y de vuelta, y mantenés los tipos sincronizados a mano.

Esta parte borra todo eso con un decorator.

## Una declaración, las dos mitades

Acá hay una función de servidor. Es una `async fn` normal — podría abrir
una conexión a Postgres, correr una query del ORM, verificar un JWT. Lo
único especial es `@rpc`:

```
// api.fitz (classic — tiene db, auth, secrets)
type User {
  id: Int
  name: Str
}

@rpc
async fn get_user(id: Int) -> Result<User> {
  let conn = db.connect(db_url()).await?
  return User.where(fn(u) => u.id == id).first(conn).await
}
```

Y acá el cliente llamándola, dentro del event handler de un componente
`.fitzv`:

```
// App.fitzv (client-WASM)
from api import get_user, User

component App {
  state { name: Str = "" }

  event load() {
    let u = get_user(42).await?   // ← un round-trip, tipado, como una llamada local
    name = u.name
  }

  <template>
    <p>{name}</p>
    <button @click="load">Cargar usuario 42</button>
  </template>
}
```

Esa es toda la app. Sin `fetch`. Sin `/api/users/:id`. Sin
`JSON.parse` + una interface `User` hecha a mano que se desincroniza del
server. El tipo `User` vive **una vez** en `api.fitz`; el server lo
compila a un binario nativo, el client lo compila a WASM, y comparten la
definición.

## Qué emite el compilador en realidad

`@rpc` es invisible-pero-tipado porque el compilador escribe los dos
lados por vos.

**Del lado server** (`fitz build --bin server`): la `@rpc` fn se monta
como `POST /__rpc/get_user`. El body es un objeto JSON con un campo por
parámetro (`{"id": 42}`); cada param se deserializa de su campo, la
función corre, y su `Result<T>` se vuelve `200` + el JSON de `T` (Ok) o
`500` + `{"error": ...}` (Err). Reusa toda la cadena de `@post` —
observability, panic-catch, todo.

**Del lado client** (`fitz build --bin web --target wasm-client`): la
`@rpc` fn importada se emite como un stub `fetch` async — su cuerpo
(server-side) **no** se transpila al WASM. El stub serializa los args,
POSTea al mismo origen (así la cookie de sesión viaja sola), y mapea la
respuesta a `Result<T>`. Y como el event handler ahora hace `.await`, el
compilador lo parte en un wrapper sync + un worker async
(`spawn_local`), así que el estado se actualiza y el componente
re-renderiza cuando llega la respuesta.

Vos escribís `get_user(42).await?`. Obtenés un round-trip de red con un
resultado tipado.

## Corre de verdad

El [ejemplo runnable](https://github.com/Thegreekman76/fitz/tree/main/examples/view/rpc)
es una SPA de dos botones más un binario de server. Verificado
end-to-end en Chrome real: clickeás "Greet" y el saludo vuelve del
server (`"Hello, world!"`); clickeás "Cargar usuario" y el `User` se
pide, se deserializa y se renderiza (`"Ada"`) — cero errores de página.
El crate del cliente compila a un `.wasm` real vía `wasm-pack`; el
server responde las rutas `/__rpc/*` exactas.

```bash
fitz build --bin server     # monta POST /__rpc/* en :3838
fitz build --bin web        # → target/wasm/web/{web.js, web_bg.wasm}
```

Serví la SPA desde el **mismo origen** que el server (en producción, que
el server sirva el bundle, o poné a los dos detrás de un reverse proxy)
para que el `fetch("/__rpc/...")` relativo lo alcance.

## Por qué es distinto

Las funciones de servidor no son nuevas — Next.js Server Actions, Remix
loaders/actions, SvelteKit `+page.server`, tRPC, Phoenix tienen el
patrón. Lo distinto en Fitz:

- **Sin paso de infraestructura.** Sin directiva `"use server"`, sin
  router de tRPC, sin generador de código. Un decorator; el compilador
  hace el resto.
- **El mismo `type`, literal.** No "tipos inferidos" cruzando un borde
  — la misma definición exacta de `User` compilada a un struct nativo y
  a un struct WASM. Cero drift, por construcción.
- **Cero deps externas.** La mitad server reusa el stack HTTP nativo;
  la mitad client trae `fetch` + `serde` solo cuando un crate realmente
  usa `@rpc`. Sin `@trpc/*`, sin magia de bundler.
- **Un solo lenguaje, los dos extremos.** La fn del server y el
  componente del client son el mismo Fitz, chequeados por el mismo
  checker.

## Los bordes honestos (MVP)

- Un tipo nominal que cruza el cable se importa también en el `.fitzv`
  (`from api import ..., User`) para que el cliente tenga su struct.
- Auth apilable sobre el endpoint generado (`@authenticated`/`@admin`)
  es refinamiento post-MVP; por ahora la cookie de sesión same-origin
  viaja con el request y verificás el token dentro del cuerpo de la
  `@rpc`.
- El componente re-renderiza una vez, cuando llega la respuesta — un
  flash de "cargando…" a mitad de camino es un slice posterior de
  reactividad fine-grained.

Ese es el loop fullstack cerrado: un componente en el browser llamando a
una función en el server, tipado de punta a punta, sin nada en el medio
que hayas tenido que escribir. Lo que sigue: hidratación SSR — el mismo
`.fitzv` renderizado en el server para el first paint, y después el
runtime WASM tomando control del DOM existente (incluyendo el estado que
produjeron tus llamadas `@rpc`).
