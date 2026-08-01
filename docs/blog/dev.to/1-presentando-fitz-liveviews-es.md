---
title: "Presentando Fitz LiveViews: UI en tiempo real en un solo lenguaje, sin build de JS"
published: false
description: Un framework de UI en tiempo real, server-rendered, para el lenguaje Fitz — diffing por WebSocket, sin paso de build de JavaScript, inspirado en Phoenix LiveView, con un target opcional a client-WASM para que el mismo componente corra offline.
tags: webdev, rust, opensource, frontend
series: FitzLiveViews
cover_image:
canonical_url:
---

> TL;DR — **Fitz LiveViews** es un framework de UI en tiempo real para [Fitz](https://github.com/Thegreekman76/fitz), un lenguaje compilado y de tipado gradual donde HTTP, WebSockets, auth y un ORM son parte de la sintaxis. Escribís componentes de un solo archivo (`.fitzv`) con `state` / `event` / `<template>`, y el servidor renderiza HTML, lo diffea y parchea el browser por WebSocket — **sin paso de build de JavaScript, sin framework de cliente**. El mismo `.fitzv` puede *además* compilar a WebAssembly para widgets offline sin round-trip. Ya hay una galería de componentes en vivo, un curso, y una app flagship completa (un panel de administración con auth + Postgres + Docker) construida con esto. **Repo**: [github.com/Thegreekman76/fitz-liveviews](https://github.com/Thegreekman76/fitz-liveviews) · **Docs**: [thegreekman76.github.io/fitz-liveviews](https://thegreekman76.github.io/fitz-liveviews/)

Este es el primer post de la serie **FitzLiveViews**. Arranco con el pitch y el setup; los siguientes construyen cosas.

## El problema

Armar una UI web moderna normalmente implica dos lenguajes, dos sistemas de tipos, y un pipeline de build: un backend (Python / Node / Go) más un framework de frontend (React / Vue / Svelte) más su toolchain (Vite / Webpack / Babel). Duplicás tus tipos de un lado al otro del cable, mantenés dos modelos mentales en sync, y `node_modules` desarrolla personalidad propia.

Phoenix LiveView (Elixir) mostró que hay otra forma: renderizar en el servidor, empujar diffs por WebSocket, y dejar que el browser quede tonto. Sin framework de cliente, sin API que escribir a mano, sin la danza de serializar JSON. Fitz LiveViews trae ese modelo a Fitz — y suma una vuelta de tuerca: el *mismo componente* puede además compilar a WebAssembly cuando querés interactividad puramente client-side y offline.

## Cómo se ve Fitz LiveViews

Un componente es un solo archivo `.fitzv` — state, event handlers y template, como Vue o Svelte:

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
}
```

En el target **server-rendered**, el framework registra el componente, manda el HTML inicial y — en cada evento — recomputa el HTML, lo diffea, y manda solo los parches por WebSocket. El browser los aplica. Nunca escribís JavaScript de cliente, nunca definís una API, nunca serializás un payload a mano.

En el target **client-WASM** (`fitz build --target wasm-client`), el *mismo archivo* compila a un bundle `wasm-bindgen` + `web-sys` que monta y muta el DOM directo — offline, sin servidor. Un componente pesa ~12 KB gzipped.

## Qué lo hace distinto

- **Un lenguaje, del back al front.** Componentes, handlers y el servidor viven todos en Fitz. Tu `type User { ... }` es el mismo de los dos lados — sin DTOs duplicados.
- **Cero build de JavaScript.** Sin `npm install`, sin bundler, sin `node_modules`. El binario `fitz` compila todo.
- **Templates con chequeo de tipos.** El template tiene su propio checker: un prop del tipo equivocado, un `@event` bindeado a un handler que no existe, un `<slot slot="x">` sin `<slot name="x">` — todo se caza en compile-time, apuntando al `.fitzv` y a la línea.
- **Dual-target: SSR *o* WASM del mismo source.** Server-rendered para estado compartido, DB-driven, multi-usuario; client-WASM para widgets locales, offline, sin round-trip. El mismo modelo de componentes en los dos casos.
- **Una librería de UI empaquetada.** `fitz_liveviews.ui.*` trae componentes drop-in (Badge, Card, DataGrid, Pager, Input, Select, Tabs, Stepper, TreeView, …), tematizados con design tokens `--flv-*`.

Hay una **[galería de componentes en vivo](https://thegreekman76.github.io/fitz-liveviews/live/)** — componentes reales compilados a WebAssembly, corriendo en tu browser, sin servidor. Jugá un rato.

## En números

Estos son números medidos de payload/build de la app flagship y la galería — no claims sintéticos de throughput:

- **Una página completa del dashboard server-rendered envía ~1.1 KB de JavaScript** (3 bloques `<script>` inline chiquitos: el theme-antes-del-paint + el cliente WebSocket en vivo), **cero `<script src>` externos, y cero paso de build.** El HTML de la página son ~38 KB y eso es *todo* — no hay runtime de framework que bajar primero. Compará con un SPA, donde el runtime del framework solo son ~40 KB (estilo Svelte) a ~140 KB (React + ReactDOM) *antes* de tu código y tu payload de hydration.
- **Un componente client-WASM son ~12 KB gzipped** — el componente *entero*, no "tu código arriba de un runtime de 100 KB". El demo del counter son 11.4 KB gzipped; la galería completa de 12 widgets compuestos son ~44 KB.
- **Cero `node_modules`, cero config de bundler.** El binario `fitz` es todo el toolchain. `git clone` → `fitz run`.
- **Binario nativo ≈ 9× más rápido por interacción que el intérprete** (`fitz run` ↔ `fitz build` renderizan bit-a-bit idéntico), así que desarrollás sobre el intérprete y shipeás el binario.

(Los benchmarks de throughput de requests cross-framework son trabajo futuro honesto — prefiero shipear números de payload medidos que agitar las manos con un load test.)

## Cómo se compara

| | **Fitz LiveViews** | Phoenix LiveView | Hotwire (Turbo) | React/Vue/Svelte (SPA) | HTMX |
|---|---|---|---|---|---|
| Diff en tiempo real por WebSocket | ✅ built-in | ✅ built-in | ~ (Turbo Streams) | manual | ~ (extensión) |
| Paso de build de JavaScript | **ninguno** | ninguno | ninguno | **requerido** | ninguno |
| Lenguajes en el stack | **1** (Fitz) | 1 (Elixir) | 2 (Ruby + JS) | 2+ (backend + JS/TS) | 1 backend + HTML |
| Target offline / solo-cliente | ✅ **WASM, mismo source** | ❌ | ❌ | ✅ (JS) | ❌ |
| Templates con chequeo de tipos | ✅ compilador | ~ (HEEx) | ❌ | ~ (TS/JSX) | ❌ |
| Compila a binario nativo | ✅ | ❌ (VM BEAM) | ❌ | ❌ | ❌ |
| Librería de componentes UI empaquetada | ✅ `fitz_liveviews.ui.*` | comunidad | comunidad | **ecosistema enorme** | comunidad |

Donde Fitz LiveViews es genuinamente distinto: **un lenguaje en todo el stack**, un **target dual SSR/WASM del mismo source**, **compilación a binario nativo standalone**, y **templates chequeados por el compilador**. Donde está honestamente atrás: es nuevo, así que el ecosistema es chico — React/Vue/Svelte tienen una década de librerías y de gente que las sabe. Si ese trade — un ecosistema más chico a cambio de un stack radicalmente más simple — suena bien para lo que estás construyendo, seguí leyendo.

## Cómo empezar

**1. Instalá Fitz.** Fitz LiveViews es una librería del lenguaje Fitz, así que primero instalás Fitz:

```bash
curl -sSf https://thegreekman76.github.io/fitz/install.sh | sh
fitz --version
```

El curso de Fitz recorre install / desinstalación / actualización en detalle — mirá **[Curso de Fitz · C1 — Instalación](https://thegreekman76.github.io/fitz/curso/m1-setup/c1-instalacion/)**.

**2. Instalá las extensiones del editor.** Dos extensiones de VSCode te dan syntax highlighting, diagnostics, hover y go-to-definition:

- **Fitz** — para archivos `.fitz` (el lenguaje). Bajá el `.vsix` de los [releases de Fitz](https://github.com/Thegreekman76/fitz/releases) y `code --install-extension fitz-language-*.vsix`.
- **Fitz LiveViews** — para componentes `.fitzv`. Bajalo de los [releases de fitz-liveviews](https://github.com/Thegreekman76/fitz-liveviews/releases) y `code --install-extension fitz-liveviews-*.vsix`.

**3. Agregá la dependencia.** En el `fitz.toml` de tu proyecto:

```toml
[dependencies]
fitz_liveviews = { git = "https://github.com/Thegreekman76/fitz-liveviews" }
```

Ese es todo el setup — sin Node, sin bundler, sin `package.json`.

## No es un juguete — hay un flagship

Para probar el modelo en algo real, hay un **panel de administración** de back-office completo, construido enteramente en Fitz + Fitz LiveViews: login (Argon2id + cookie de sesión con JWT firmado), un shell responsive (sidebar colapsable, drawer mobile hasta 320px, switch ES/EN, tema light/dark/auto), un dashboard con counts reales de Postgres, y dos pantallas CRUD en vivo (empleados + departamentos) con búsqueda, filtros, ordenamiento, paginación, forms ricos con tabs, multi-delete, group-by, expand por fila, y export a CSV — todo diffeado por WebSockets, todo internacionalizado, todo en un `docker compose up`.

Cada pieza reusable es un componente empaquetado en `fitz_liveviews.ui.*` — la librería se *extrajo* de esta app. Es la referencia viva.

## A dónde ir

- **Repo** — [github.com/Thegreekman76/fitz-liveviews](https://github.com/Thegreekman76/fitz-liveviews)
- **Docs** — [thegreekman76.github.io/fitz-liveviews](https://thegreekman76.github.io/fitz-liveviews/)
- **Galería en vivo** — [/live](https://thegreekman76.github.io/fitz-liveviews/live/)
- **Curso** — una construcción práctica, capítulo a capítulo ([overview](https://thegreekman76.github.io/fitz-liveviews/course/))
- **Guía Client-WASM** — el target de widgets offline ([client-wasm](https://thegreekman76.github.io/fitz-liveviews/client-wasm/))

## Qué viene en la serie

- **#2 — Tu primer componente, dos veces.** Un counter que renderiza server-side por WebSocket *y* compila a WebAssembly — un source, dos targets.
- **#3 — Forms, payloads e inputs en vivo.** Cómo los eventos llevan data, y cómo `@input` / `@change` bindean valores de formulario.
- **#4+ — Construyendo el flagship.** Un deep dive al panel de administración: auth por cookie, DataGrids en vivo sobre Postgres, la librería de UI empaquetada, i18n, y Docker.

Si UI en tiempo real sin build de JavaScript te suena bien, dale una estrella al [repo](https://github.com/Thegreekman76/fitz-liveviews) y seguí la serie. Lo próximo: el counter, dos veces.
