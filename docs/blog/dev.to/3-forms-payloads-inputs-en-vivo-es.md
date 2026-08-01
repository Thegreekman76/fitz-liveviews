---
title: "Forms, payloads e inputs en vivo en Fitz LiveViews"
published: false
description: Cómo los eventos llevan data en Fitz LiveViews — click payloads, form submits, y binding de valores en vivo con @input / @change — con una lista de nombres a la que agregás, quitás y contás, en vivo.
tags: webdev, rust, opensource, frontend
series: FitzLiveViews español
cover_image:
canonical_url:
---

> TL;DR — Los eventos en [Fitz LiveViews](https://github.com/Thegreekman76/fitz-liveviews) llevan data de tres formas: un **click payload** (`data-flv-value-*`) marca un botón con el valor que tiene que mandar; un **form submit** (`data-flv-submit`) lee los inputs con nombre del form; y un **valor en vivo** (`@input` / `@change`) entrega el valor actual de un control en `payload["value"]`. Las tres caen en el mismo lado — un mapa `payload` que tu handler lee. Este post construye una lista de nombres en vivo (agregar / quitar / contar) que corre server-rendered y como WebAssembly. *(Parte 3 de la serie FitzLiveViews.)*

Las partes [1](https://dev.to/) y [2](https://dev.to/) cubrieron el pitch y el counter. Un counter solo lee `+1`/`-1` — no entra data. Las UIs reales toman input: texto, selecciones, campos de formulario. Acá está cómo esa data llega a tus handlers.

## El `payload`

Cada handler de evento tiene un `payload` en scope — un `Map<Str, Str>`. Los tres mecanismos de abajo lo llenan; tu handler lo lee con `payload["clave"]` (guardá con `payload.has("clave")`):

### 1. Click payload — un botón que lleva un valor

Marcá cualquier elemento con `data-flv-value-<clave>="{expr}"`, y cuando un `data-flv-click` sobre él (o un ancestro) dispara, ese valor viaja:

```
<button data-flv-click="remove" data-flv-value-item="{it}">×</button>
```

```
event remove() {
  if (payload.has("item")) {
    let target = payload["item"]
    names = names.filter(fn(it) => it != target)
  }
}
```

El botón de borrar *sabe qué fila es* porque el valor de la fila está estampado en él. Sin IDs pasados por un callback, sin captura de closure.

### 2. Form submit — el form entero de una

`data-flv-submit="handler"` en un `<form>` lee cada input con nombre al payload en el submit; `data-flv-clear` limpia el campo después:

```
<form data-flv-submit="add">
  <input name="item" placeholder="Agregar un nombre" data-flv-clear />
  <button type="submit">Agregar</button>
</form>
```

```
event add() {
  if (payload.has("item")) {
    let n = payload["item"]
    if (n != "") { names.push(n) }
  }
}
```

`payload["item"]` es el valor del input al momento del submit. Sin `preventDefault`, sin `FormData`, sin `fetch`.

### 3. Valor en vivo — `@input` / `@change`

Para un control que reporta mientras tipeás o al seleccionar, `@input` (cada tecla) y `@change` (al blur/selección) entregan el valor actual en `payload["value"]`:

```
<input @input="on_name" value="{name}" />
<select @change="on_color"> … </select>
```

```
event on_name() { name = payload["value"] }
```

El mismo `payload["value"]` cubre `<input>`, `<select>` y `<textarea>`. En el target server-rendered esto es el atributo clásico `data-flv-change`; en el target client-WASM es el decorador `@input` / `@change` — mismo payload, mismo handler, así que un `.fitzv` sirve a los dos.

## Todo junto — una lista de nombres en vivo

```
component NameList {
  state {
    names: List<Str> = ["Ada", "Grace", "Margaret"]
  }

  event add() {
    if (payload.has("item")) {
      let n = payload["item"]
      if (n != "") { names.push(n) }
    }
  }

  event remove() {
    if (payload.has("item")) {
      let target = payload["item"]
      names = names.filter(fn(it) => it != target)
    }
  }

  <template>
    <div class="names">
      <form data-flv-submit="add">
        <input name="item" placeholder="Agregar un nombre" data-flv-clear />
        <button type="submit">Agregar</button>
      </form>
      <ul>
        {#for it in names}
          <li>{it} <button data-flv-click="remove" data-flv-value-item="{it}">×</button></li>
        {/for}
      </ul>
      <p>{names.len()} total</p>
    </div>
  </template>
}
```

`{#for it in names}` itera; `{it}` interpola cada ítem; el botón de borrar estampa su propio valor. Agregá un nombre, quitá una fila, mirá el contador — sin código de cliente, sin API.

Cablealo a un `main.fitz` (la misma forma que el counter de la [parte 2](https://dev.to/)) y corre:

```
from fitz_liveviews import Html, html, live_layout, html_response,
  LiveFrame, diff_html, component, dispatch_component_events, flv_register
from NameList import NameList, NameList_render, NameList_add, NameList_remove

@get("/")
fn page() -> Response {
  return html_response(live_layout("/live/names", "names-app",
    component("NameList", "root")))
}

@ws("/live/names")
async fn socket(ws: WsConn<LiveFrame>) {
  let last = component("NameList", "root").raw
  loop {
    let frame = ws.recv()?
    let _ = dispatch_component_events(frame)
    let new_html = component("NameList", "root").raw
    ws.send(LiveFrame { html: new_html, patches: diff_html(last, new_html) })?
    last = new_html
  }
}

@server(3000) fn main() => 0
```

`fitz run`, abrís `http://localhost:3000`, agregás y quitás nombres. (Corrí exactamente esto — la página renderiza la lista sembrada, el contador, y el form/botones cableados.) El **build client-WASM de la misma lista** está corriendo en la [galería en vivo](https://thegreekman76.github.io/fitz-liveviews/live/embed/?c=namelist) — agregar/quitar/contar entero en tu browser, offline.

## Dos caveats honestos

- **Métodos de string en WASM.** Un filtro case-insensitive (`names.filter(fn(x) => x.lower().contains(q))`) funciona en el target server-rendered pero (todavía) no en client-WASM — el envelope wasm no tiene `.lower()` / `.contains()` aún. Así que la lista de nombres WASM de arriba tiene agregar/quitar/contar; un *filtro* en vivo queda server-side por ahora. (El envelope crece release a release; esto está en la lista.)
- **Los inputs de texto en vivo se re-montan.** El modelo de render actual es dirty-flag + naive re-render: un cambio de estado reconstruye el DOM del componente. Para un `<select> @change` es invisible; para un `<input> @input` en vivo, el campo se re-monta en cada tecla — el valor se re-bindea con `value="{name}"`, pero el caret salta al final. La reactividad fine-grained (patch in-place) es el próximo paso del modelo de render. El valor siempre llega al handler de forma confiable; eso es lo que `@input` garantiza hoy.

## Qué viene en la serie

- **#4+ — Construyendo el flagship.** Un panel de administración completo en Fitz + Fitz LiveViews: auth por cookie (Argon2id + JWT), DataGrids en vivo consultando Postgres por WebSockets, la librería de UI empaquetada, i18n, y un setup Docker de un comando.

Si eventos tipados sin framework de cliente te suena bien, dale una estrella al [repo](https://github.com/Thegreekman76/fitz-liveviews). Lo próximo: una app real.
