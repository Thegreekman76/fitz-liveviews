---
title: "Hidratación isomórfica en Fitz: first paint en el server, y después WASM adopta el DOM"
published: false
description: El mismo `.fitzv` se renderiza en el server para el first paint (funciona con JS deshabilitado), y el runtime client-WASM después ADOPTA ese DOM pintado por el server en vez de tirarlo y re-renderizar — estado restaurado desde un payload embebido, listeners cableados, sin wipe, sin flash. Un solo source, los dos extremos.
tags: webdev, rust, opensource, frontend
series: FitzLiveViews español
cover_image:
canonical_url:
---

> TL;DR — Marcás un componente con `hydrate` y el **mismo `.fitzv`** hace
> dos trabajos: el server lo renderiza a HTML para un first paint rápido
> (SEO, funciona-sin-JS), y al boot el runtime client-WASM **adopta** ese
> DOM exacto — restaurando el estado serializado desde un `<script>`
> embebido, recorriendo los nodos existentes y cableando los event
> listeners — en vez de tirar todo y reconstruir. Sin flash de
> re-render, sin perder la identidad del DOM, sin la categoría de bug
> "hydration mismatch". *(Parte 8 de la serie FitzLiveViews — el pago que
> prometió la [Parte 7](#).)*

La Parte 7 cerró el loop fullstack: un componente `.fitzv` llamando a una
función de servidor `@rpc`, tipada de punta a punta. Terminó con una
promesa — *hidratación SSR: el mismo componente renderizado en el server
para el first paint, y después el runtime WASM tomando control del DOM
existente*. Esta es esa parte.

## Por qué hidratación, y por qué suele doler

El server-side rendering te da el buen first paint: el browser muestra
HTML real de una, los buscadores ven contenido, la página funciona con
JavaScript deshabilitado. Pero después el runtime interactivo tiene que
*tomar control* de esa página. La forma naive —montar la app de cero—
tira el DOM pintado por el server y lo reconstruye, produciendo un flash
y haciendo el trabajo dos veces. La forma framework —reconciliar un
virtual DOM contra el HTML del server— es de donde salen los warnings de
"hydration mismatch", y encima manda el runtime entero del framework para
hacerlo.

Fitz no hace ninguna de las dos. El runtime WASM **adopta** los nodos
exactos que pintó el server.

## Un solo source, los dos extremos

Un componente `.fitzv` ya compila de dos formas: a HTML del server (el
camino LiveViews) y a una app WASM standalone. La hidratación es opt-in
con un marcador en el root:

```
component App hydrate {
  state {
    name: Str = "world"
  }

  event on_name() { name = payload["value"] }

  <template>
    <p class="greeting">Hello, <span class="nm">{name}</span></p>
    <input @input="on_name" value="{name}" />
  </template>
}
```

El marcador es opt-in para que los componentes renderizados para el
WS-takeover de LiveViews (cuyo diff de DOM prohíbe un `<script>` en el
root) queden byte-idénticos. Cuando está, las dos mitades cooperan.

## Qué emite el server

El emisor SSR pinta el DOM **y** le deja al cliente todo lo que necesita
para adoptarlo:

- El HTML renderizado, exactamente como lo produce el template del
  componente.
- Un **payload de estado** — `<script type="application/json"
  id="__flv_state_App">{"name":"Ada"}</script>` — así el cliente bootea
  con el estado del server, no con los defaults del template.
- **Marcadores de adopción** por los que el cliente camina:
  `<!--fi-->…<!--/fi-->` alrededor de las interpolaciones en texto mixto
  (`Hello, {name}!`), `<!--fr-->…<!--/fr-->` alrededor de las regiones
  `{#if}`/`{#for}`, un `<div class="__fitz-child-Card">` envolviendo a un
  hijo compuesto, y el contenido de slot inlineado en el scope del padre.

Esto es un render-a-string de verdad en el server — no un `index.html`
hecho a mano. El server computa `App_render(App { name: "Ada" })` y ese
string es lo que el browser pinta y el WASM adopta.

## Qué hace el cliente al boot

En vez de `mount()` (que limpia el root y construye), un componente
hidratable corre `hydrate()`:

1. Ve que el root del mount ya tiene contenido.
2. Restaura el estado serializado desde el payload del `<script>` —
   primitivos, y estado compuesto también (`List<T>`, `Map<Str,V>`,
   nullables, tipos nominales importados round-trippean por JSON).
3. Recorre el DOM existente con un cursor (depth-first), mapeando cada
   nodo elemento/texto/comentario sobre los mismos handles keep-node que
   el walk de build habría creado — **sin `create_element`, sin wipe**.
4. Cablea los listeners `@input`/`@click` sobre los nodos adoptados.

De ahí en más un cambio de estado parchea in-place (reconciliación
keep-node), así que el `<input>` vivo conserva su caret. La página nunca
se reconstruyó — se tomó control de ella.

## Corre de verdad

Verificado end-to-end en Chrome real (vía Puppeteer), y el test es la
parte convincente: se le pone una propiedad JS a un nodo pintado por el
server **antes** de que corra `init()`. Después de la hidratación, esa
propiedad **sigue ahí** — prueba de que el nodo fue *adoptado*, no
recreado. El saludo muestra `"Ada"` (el estado del server, no el default
del template `"world"`), tipear parchea el texto in-place, y hay cero
errores de página. Los ejemplos runnable cubren las formas:
[`hydrate`](https://github.com/Thegreekman76/fitz/tree/main/examples/view/hydrate)
(base),
[`hydrate-mixed`](https://github.com/Thegreekman76/fitz/tree/main/examples/view/hydrate-mixed)
(texto mixto estático+interpolado),
[`hydrate-regions`](https://github.com/Thegreekman76/fitz/tree/main/examples/view/hydrate-regions)
(`{#if}`/`{#for}`), y
[`hydrate-composition`](https://github.com/Thegreekman76/fitz/tree/main/examples/view/hydrate-composition)
(`<Child />` + slots, adoptados cruzando el borde del componente).

## Por qué es distinto

La hidratación es un problema resuelto en el mundo JS — la cuestión es
*qué cuesta*:

- **React / Next.js** mandan el runtime del framework al cliente y
  corren una pasada de reconciliación para engancharse al HTML del
  server; un mismatch entre los dos es una categoría entera de warnings.
  Fitz adopta los nodos exactos recorriéndolos — no hay nada que
  reconciliar ni runtime de framework que mandar.
- **Astro islands / hidratación parcial** están buenísimos, pero cada
  isla sigue siendo un runtime de framework JS. El cliente de Fitz es una
  sola app WASM compilada que tomó control del árbol entero pintado por
  el server.
- **Phoenix LiveView / Hotwire** son server-driven: el "cliente" es una
  capa fina de JS parcheando el DOM. El cliente de Fitz es una app
  compilada de verdad con su propio estado — solo que *arranca* desde el
  DOM del server en vez de un mount en blanco.

Mismo source los dos extremos, adopción nodo-por-nodo, opt-in por
componente, parcheo keep-node después, cero runtime de framework. Esa
combinación es el diferencial.

## Los bordes honestos (MVP)

- La hidratación es **opt-in** con el marcador `hydrate` (la
  auto-hidratación universal es una mejora futura — el opt-in mantiene el
  camino LiveViews byte-idéntico).
- El restore de estado compuesto está cubierto; los tipos que no
  round-trippean por JSON (un `Map` con key no-`Str`, tuplas, funciones)
  resetean a su default al restaurar, simétrico con el dump.
- Los named slots en el emisor SSR y la composición dinámica adentro de
  un `{#if}`/`{#for}` son slices posteriores; el slot default + la
  composición estática adoptan hoy.

Ese es el loop hacia el que venía la serie: el server pinta primero
(rápido, indexable, alimentado por `@rpc`), y el mismo `.fitzv` — como
app WASM — toma control de ese DOM exacto y lo mantiene vivo. Lo que
sigue: la librería de UI companion de la que está hecho el panel admin
flagship — ~40 componentes importables, extraídos de una app real.
