---
title: "Tu primer componente de Fitz LiveViews, dos veces: SSR y WASM del mismo source"
published: false
description: Un componente .fitzv, dos targets de compilación — server-rendered por WebSocket, o compilado a WebAssembly para offline. El mismo archivo, sin reescribir. Un recorrido con un counter.
tags: webdev, rust, opensource, frontend
series: FitzLiveViews español
cover_image:
canonical_url:
---

> TL;DR — Un componente de [Fitz LiveViews](https://github.com/Thegreekman76/fitz-liveviews) es un solo archivo `.fitzv`. Lo interesante: **el mismo archivo compila a dos targets distintos** sin reescribir nada. **Server-rendered** (SSR) — el servidor guarda el estado, renderiza HTML, y parchea el browser por WebSocket; ideal para estado compartido, DB-driven, multi-usuario. **Client-WASM** — el mismo componente compila a WebAssembly y corre entero en el browser; ideal para widgets offline sin round-trip. Este post construye un counter y lo shipea de las dos formas. *(Parte 2 de la serie FitzLiveViews — [empezá acá](https://dev.to/) si te perdiste la parte 1.)*

En la [parte 1](https://dev.to/) hice el pitch: UI en tiempo real en un solo lenguaje, sin build de JavaScript. Ahora construyamos algo y shipeémoslo de dos formas desde el mismo source.

## El componente

Un counter como componente de un solo archivo (`.fitzv`) — state, events, template, style:

```
component Counter {
  state { count: Int = 0 }

  event increment() { count = count + 1 }
  event decrement() { count = count - 1 }
  event reset() { count = 0 }

  <template>
    <div id="counter-app">
      <p>Count: {count}</p>
      <button @click="increment">+1</button>
      <button @click="decrement">-1</button>
      <button @click="reset">Reset</button>
    </div>
  </template>

  <style scoped>
    #counter-app { padding: 1.5rem; font-family: system-ui; }
    button { padding: 0.5rem 1rem; margin: 0 0.25rem; }
  </style>
}
```

`state` es la data reactiva. Cada handler de `event` la muta directo — sin `setState`, sin reducers. `<template>` es markup real; `{count}` interpola y auto-escapa. `@click="increment"` bindea un evento del DOM a un handler. `<style scoped>` es CSS namespaceado a este componente. Si escribiste Vue o Svelte, esto te suena — la diferencia es lo que pasa después.

## Target 1 — server-rendered (por WebSocket)

El target SSR es el default. El componente corre en el servidor; un `main.fitz` chiquito lo cablea a una ruta HTTP (primer paint) y una ruta WebSocket (la capa en vivo):

```
from fitz_liveviews import html_response, live_layout, LiveFrame,
  diff_html, component, dispatch_component_events
from Counter import Counter, Counter_render,
  Counter_increment, Counter_decrement, Counter_reset

@get("/")
fn page() -> Response {
  return html_response(live_layout("/live/counter", "counter-app",
    component("Counter", "root")))
}

@ws("/live/counter")
async fn socket(ws: WsConn<LiveFrame>) {
  let last = component("Counter", "root").raw
  loop {
    let frame = ws.recv()?
    let _ = dispatch_component_events(frame)   // rutea el evento al componente
    let new_html = component("Counter", "root").raw
    ws.send(LiveFrame { html: new_html, patches: diff_html(last, new_html) })?
    last = new_html
  }
}

@server(3000) fn main() => 0
```

Qué pasa en un click: el browser manda el evento por el WebSocket → `dispatch_component_events` lo rutea al handler → el handler muta el estado → el servidor recomputa el HTML, **lo diffea contra el render anterior, y manda solo los parches**. El browser los aplica. Nunca escribiste JavaScript de cliente, nunca definiste una API, nunca serializaste un payload. El estado vive en el servidor, así que sobrevive reloads y puede ser compartido o respaldado por DB.

`fitz run`, abrís `http://localhost:3000`, clickeás. Esa es toda la app — tres archivos (`Counter.fitzv`, `main.fitz`, `fitz.toml`), y es exactamente lo que ves arriba. La versión completa y lista para correr está en el repo en [`examples/counter/`](https://github.com/Thegreekman76/fitz-liveviews/tree/main/examples/counter) — `git clone`, `cd examples/counter`, `fitz run`.

## Target 2 — client-WASM (offline, sin servidor)

Ahora el *mismo `Counter.fitzv`* — sin cambios — compilado a WebAssembly. Declaralo como un bin wasm en `fitz.toml`:

```toml
[[bin]]
name = "counter"
main = "Counter.fitzv"
target = "wasm-client"
mount = "#app"       # requerido: dónde monta el componente en la página
```

Buildealo:

```bash
fitz build --bin counter --target wasm-client
# → emite un crate wasm-bindgen + web-sys, corre wasm-pack,
#   produce counter.js + counter_bg.wasm
```

Metés los dos archivos en una página con `<div id="app"></div>` y un `<script type="module">import init from './counter.js'; init()</script>`, y el counter corre **entero en el browser** — sin servidor, sin WebSocket. El estado vive en celdas `Rc<RefCell<T>>`; los handlers de `@click` mutan el DOM directo.

**Está corriendo ahora mismo** en la [galería de componentes en vivo](https://thegreekman76.github.io/fitz-liveviews/live/) — ese counter es este archivo exacto compilado a WASM. El bundle son **11.4 KB gzipped** por todo (sin runtime de framework aparte que bajar primero).

## Mismo source — ¿entonces qué target?

| | Server-rendered | Client-WASM |
|---|---|---|
| Dónde vive el estado | en el servidor | en el browser |
| Multi-usuario / compartido / DB | ✅ natural | ❌ (por pestaña) |
| Funciona offline | ❌ (necesita el socket) | ✅ |
| Round-trip por interacción | un mensaje WS | ninguno |
| Ideal para | dashboards, CRUD, chat, cualquier cosa compartida | widgets, calculadoras, herramientas offline |

El punto no es "elegí uno para siempre". Es que un componente presentacional — un badge, una card, un stepper — puede servir a los dos, y decidís por componente. ¿Estado compartido? SSR. ¿Local, offline, cero latencia? WASM. El mismo `.fitzv`.

## Qué viene en la serie

- **#3 — Forms, payloads e inputs en vivo.** Cómo los eventos llevan data: click payloads, form submits, y el binding de valores con `@input` / `@change`.
- **#4+ — Construyendo el flagship.** Un panel de administración real: auth por cookie, DataGrids en vivo sobre Postgres, i18n, y Docker.

Dale una estrella al [repo](https://github.com/Thegreekman76/fitz-liveviews) si te cierra la idea de un-source-dos-targets. Lo próximo: forms y payloads.
