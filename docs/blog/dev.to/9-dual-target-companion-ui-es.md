---
title: "Escribilo para el server, corrélo en el browser: componentes UI dual-target en Fitz"
published: false
description: La companion UI de Fitz LiveViews es server-rendered. Pero el MISMO componente `.fitzv` ahora compila a WebAssembly y corre en el browser también — iconos, forms, charts — sin reescribir nada y sin versión paralela. Los 38 componentes dual-targetean desde un solo source. Acá está lo que costó.
tags: webdev, rust, opensource, frontend
series: FitzLiveViews
cover_image:
canonical_url:
---

> TL;DR — La companion UI se entrega como componentes **server-rendered**.
> Pero el mismísimo source `.fitzv` ahora también compila a
> **WebAssembly** y corre client-side — sin reescribir, sin una "versión
> client" mantenida a mano. Un componente con markup como un `Button` (que
> renderiza un icono SVG) y uno lista-driven como un `Select` (alimentado
> con `List<FieldOption>`) pasan de *solo-server* a *corre-en-el-browser*
> cambiando el compilador, no el componente. **38 de 38** dual-targetean
> hoy; la gallery en vivo corre 22. *(Parte 9 de la serie FitzLiveViews.)*

La Parte 6 construyó la librería companion UI — ~40 componentes
importables, server-rendered, con estilos scoped, extraídos de un admin
real. La Parte 8 le enseñó al mismo `.fitzv` a hidratar: pintar en el
server, y que una app WASM adopte el DOM. Esta parte cierra un hueco entre
las dos: hacer que los *componentes companion mismos* corran client-side
desde su source de server exacto.

## El trato de siempre: dos versiones de cada componente

Toda historia de "UI isomórfica" choca tarde o temprano con la misma
pared. Tenés un componente que renderiza en el server. Querés que *además*
sea interactivo en el browser. En la mayoría de los stacks eso significa
una segunda implementación — un build client del mismo widget,
sincronizado a mano. El server renderiza una cosa; un bundle de JS la
re-implementa.

La companion UI de Fitz arrancó ahí también: un set server-rendered, más
un set client *paralelo* escrito a mano para la gallery. La apuesta era
que un subset podía compartir un solo source. Resultó que casi todo puede.

## Un source, dos backends

Un componente single-file `.fitzv` lo compilan dos backends:

- **SSR** → Fitz clásico que arma un string HTML. Es lo que el runtime de
  LiveViews sirve y diffea por el WebSocket.
- **client-WASM** (`fitz build --target wasm-client`) → Rust compilado a
  WebAssembly que arma DOM real con `web-sys`, corre en el browser, sin
  server.

Mismo `<template>`, mismo state, mismos eventos. El compilador emite dos
cosas desde un archivo. La pregunta nunca fue *si podían compartir
templates* — ya lo hacen. Fue: **qué componentes companion reales pegaban
contra una pared del lado WASM, y por qué.**

## Las tres paredes (y cómo cayeron)

**1. Helpers de markup.** Un `Button` renderiza un icono:
`{raw_html(icon(name).raw)}`. Ese helper `icon` devuelve un string SVG
envuelto en `Html` (el newtype de Fitz sobre markup crudo). Dos problemas
en WASM: interpolar un string de markup en el DOM lo *escapa* (verías
`&lt;svg&gt;` como texto), y el tipo `Html` no existía client-side.

Resuelto con dos piezas. Un **sink raw-HTML**: `{raw_html(x)}` inyecta el
string vía `set_inner_html` sobre el padre en vez de un text node que
escapa (el modelo `dangerouslySetInnerHTML` de React). Y un **shim
`Html`**: el newtype `Html` mapea a un struct chico generado, así los
helpers que lo devuelven transpilan. Lo lindo — del lado SSR el emisor
*stripea* el marker `raw_html(...)` (la interpolación clásica ya es cruda),
así el MISMO source es byte-idéntico en el server. Escribís
`{raw_html(icon(name).raw)}` una vez; renderiza sin escapar en ambos lados.

**2. Componentes lista-driven.** Un `Select` es `{#for o in options}` sobre
una `List<FieldOption>` — una lista de un tipo nominal — con `{#if o.on}`
por opción. El `{#for}` y la condición de field-access lowereaban bien. La
pared era *alimentarlo con data*: pasar `<Select options="{opts}" />` (una
prop `List<nominal>`) y sembrar `opts: List<FieldOption> = [FieldOption {
... }]` (un default `List<nominal>`). Ambos eran solo-primitivos en WASM.

Resuelto dejando que un bare state field lowerea a un `.clone()` para
cualquier target no-nullable — un `Vec<FieldOption>` clona igual que un
`i64` — y enseñándole al emisor de defaults a lowerear un struct-literal
nominal. Ahora `Select`, `RadioGroup` y un `BarChart` (alimentado con
`List<Bar>`) renderizan con data real client-side.

**3. Armado de listas en cuerpos de helper.** Un helper de pager hace `let
out = []; for n in 1..pages { out.push(n) }`. Ese `for` sobre un range y un
`.push` sobre una lista *local* (no un state field) no se soportaban en
cuerpos de helper. Fix chico, ahora sí.

## El barrido: 38 de 38

Con eso en su lugar, la medida honesta: buildear *cada* componente
companion a WASM y ver qué compila. **16 de los 18 restantes** lo hicieron
sin ningún cambio. Sumando el trabajo previo de markup/listas llegamos a 36
de 38.

Los dos que faltaban eran los interesantes. `Pager` y `ConfirmDialog` son
componentes **controlados**: sus botones disparan eventos *fall-through*
(`data-flv-click="page_prev"`, `confirm_delete`) que no son eventos
propios del componente — burbujean al loop `@ws` del parent, que hace el
trabajo real. Un evento fall-through no tenía sentido en un mount
standalone en el browser sin loop padre.

Así que se lo dimos. Un `data-flv-click` cuyo nombre no es un evento local
ahora dispara el callback slot del componente cuando un parent que lo
compone lo bindea (`<Pager @page_prev="..." />`), y es un no-op inerte
documentado cuando nadie lo hace (standalone). El checker del view se
relajó para aceptar ese binding cuando el hijo *emite* el evento vía
`data-flv-*` — no solo cuando lo declara. Con eso, `Pager` y
`ConfirmDialog` también compilan y renderizan a WASM: **38 de 38** — un
source, server *y* browser.

(Dos gaps residuales más se cerraron en la misma pasada: props interpoladas
a un target `Nullable<T>` ahora envuelven `Some(...)`, y un default
`List<nominal>` puede omitir campos — se rellenan con los defaults
declarados del nominal, byte-accurate con el server.)

## El pago

La gallery en vivo ahora corre **22 componentes companion** compilados a
WebAssembly, en el browser, desde su source de server exacto — badges,
cards, alerts, inputs, un botón con un icono SVG real, un select y un radio
group alimentados con opciones vivas, un bar chart, y ahora los controlados
`Pager` + `ConfirmDialog`. Sin versiones client paralelas. Los escribiste
para el server; el compilador los hizo correr en el browser también.

Ese es todo el pitch de un lenguaje compilado e isomórfico: el componente
es el componente. El runtime es un flag del compilador.

*Lo que sigue: reactividad fine-grained (para que un input de texto en vivo
conserve el caret) — patch-in-place en vez de re-render naive.*
