# Admin ABM — refactor a LiveComponents del grid (`empleados.fitz`)

> **Estado: refactor CERRADO** (Empleados: rebanadas 1-4; Departamentos:
> rebanada 5, requiere fitz core **v0.37.14**). Este doc se conserva como
> registro histórico + catálogo de gotchas del DSL `.fitzv` (sección
> "⚠️ Gotchas", útil para autoría). Documento de trabajo original del
> refactor incremental del DataGrid de empleados (`src/empleados.fitz`,
> ~1840 LoC) a **LiveComponents `.fitzv`**. Las referencias de versión del
> core adentro de este doc son históricas por rebanada; la de record es la
> del entorno (abajo).

## Objetivo

Descomponer el monolito `empleados.fitz` en los "pedazos naturales":
**toolbar/search · filtros · grilla+filas · form**, cada uno como un `.fitzv`
presentacional/controlado, siguiendo los patrones ya endurecidos con
ConfirmDialog (per-connection), Toast (per-connection, transitorio) y Pager
(presentacional/controlado + `<style scoped>`).

## Estado (2026-07-26)

| Rebanada | Componente | Estado | Validación |
|---|---|---|---|
| 1. Toolbar/search | `GridToolbar.fitzv` | ✅ hecho | run == binario bit-a-bit (16→19 frames) |
| 2. Filtros (deptos + group-by) | `GridFilters.fitzv` | ✅ hecho | run == binario bit-a-bit (19 frames) |
| 3. Grilla+filas (`grid_row`) | `EmpleadoRow.fitzv` | ✅ hecho | run == binario bit-a-bit (30 frames) |
| 4. Form (`form_html`) | `EmpleadoForm.fitzv` | ✅ hecho | run == binario, idéntico módulo line-endings (30 frames) |
| 5. Departamentos (paridad) | `DepartamentoRow.fitzv` + `DepartamentoForm.fitzv` | ✅ hecho | `fitz build` verde (requiere fitz core **v0.37.14**) |

**El refactor cerró para Empleados**; la Rebanada 5 lleva la pantalla
**Departamentos** a la misma arquitectura (fila + form como `.fitzv`
presentacional/controlado), cerrando el `dep_row`/`form_html` inline. Todos como
`.fitzv` presentacional/controlado, compilando a binario nativo con paridad ante
`fitz run`. Próximo: C6 del curso "Ship it" + playground
(seed = `examples/gallery`).

**`fitz build` verde.** Las rebanadas 1-4 (Empleados) están commiteadas; la
rebanada 5 (Departamentos) requiere fitz core v0.37.14 y aterriza en el commit
de esta tanda.

---

## Patrón de extracción (el que endurecimos)

Componente **presentacional/controlado** (modelo Pager, NO per-connection):

1. `X.fitzv` declara `state { ... }` (los "props") con **defaults literales**
   (necesario para la auto-registración `flv_register` — v0.20.1 sintetiza
   `X {}`), sin `event` handlers.
2. El parent (`render_grid`) lo renderiza **directo** cada frame:
   `let x_html: Str = x_render(x { prop: val, ... }).raw`. No usa
   `component_with` ni el store; no hay wrapper `data-flv-component-name`.
3. Los eventos de sus botones/forms **caen al parent** (el componente no
   declara handlers → `dispatch_component_events` devuelve false → el `@ws`
   loop del parent los maneja). Mismo contrato de fall-through que Pager.
4. **NO** se importa en `main.fitz** (a diferencia de Toast/ConfirmDialog
   per-connection). Se importa solo donde se usa (`empleados.fitz`). La
   auto-registración igual sucede y es inocua (nunca llamamos `component(...)`).
5. **CSS global** (en `shell.fitz`): `.grid-toolbar`/`.pill`/`.btn-*`/etc. son
   compartidos con el resto del grid, así que estos componentes **no** llevan
   `<style scoped>` (modelo Toast, no modelo Pager). Un scoped acá pelearía con
   la hoja compartida.

---

## ⚠️ Gotchas del DSL SSR `.fitzv` (descubiertos en el terreno — CRÍTICO)

1. **Comillas dobles anidadas dentro de un VALOR DE ATRIBUTO rompen el parse.**
   `placeholder="{t(locale, "grid.search.ph")}"` → *"view parse error: expected
   attribute name"*. El scanner de valores de atributo cierra el string en la
   comilla interna.
   **Fix:** pasar el string pre-computado como prop (`ph_search`), **o** envolver
   en un helper sin string-literal como arg: `data-tooltip="{tip_edit(locale)}"`
   donde `tip_edit` internamente hace `t(locale, "grid.tip.edit")` (la comilla
   vive dentro del helper, no en el template). **Interpolación en TEXTO** (entre
   tags) sí acepta comillas anidadas: `<h3>{t(locale, "confirm.title")}</h3>` OK.

2. **La interpolación `{expr}` NO auto-escapea.** El emisor SSR emite `{expr}`
   tal cual; `flv(...)` es el escaper explícito (por eso no hay doble-escape).
   ⇒ helpers que devuelven HTML crudo se pueden interpolar crudos
   (`{estado_badge(activo, locale)}` emite el `<span>` sin escapar). Usar
   `flv(...)` para todo dato de usuario.

3. **Multi-root template OK.** `GridFilters.fitzv` tiene dos `<div>` hermanos de
   nivel superior — parsea y valida run↔binario. No hace falta un wrapper.

4. **Estado `List<Nominal>` OK.** `deptos: List<Departamento> = []` + `{#for d in
   deptos}` funciona (el `{#for}` SSR baja a `.map`, que List tiene). Default
   debe ser literal (`[]`). Cross-módulo compila a binario (v0.28.5/6).
   **Ojo:** iterar un `Range` NO funciona (baja a `.map`, Range no tiene). Un
   helper de rango debe devolver `List<Int>` (patrón `page_range` del Pager).

5. **Sin `match` en templates.** Usar `{#if}/{#else}` o un helper (donde vive el
   `match`, en Fitz clásico).

6. **Bare `{...}` en POSICIÓN de atributo (entre atributos) rompe.** El viejo
   `...value-id="{id}"{checked} />` (interpolar un atributo suelto) da "expected
   attribute name". Para el `checked` del checkbox: emitir la variante completa
   con `{#if checked}<input ... checked />{#else}<input ... />{/if}`, o un helper
   que devuelva el `<input>` entero.

7. **`fitz check` NO view-parsea los `.fitzv`.** Los errores de view solo salen
   en `fitz run` / `fitz build`. Siempre validar un `.fitzv` nuevo con
   `fitz run` (no alcanza `fitz check`).

8. **Función/helper en atributo (sin comillas anidadas) SÍ:**
   `href="{export_href}"`, `data-tooltip="{tip_edit(locale)}"`, mixed
   `href="/x?q={url_enc(q)}&estado={estado}"` — todo OK (v0.28.7 mixed attr).

9. **Un módulo de helpers que usa `h_join(xs.map(fn(x) => html(...)))` DEBE
   importar `Html`** (`from fitz_liveviews import Html, flv, html, h_join`). Sin
   `Html` en el import, la firma cross-module de `h_join` degrada a `Any` y el
   closure de `.map` se emite devolviendo `__FitzValue` en vez de `Html` → 10×
   `error[E0308]: expected __FitzValue, found Arc<Mutex<HtmlData>>` en `fitz
   build`. Es el gotcha W27/v0.28.6 (el entry file / cualquier módulo que roce
   SFCs necesita `Html` importado). Pegó al mover los option-builders a
   `form_helpers.fitz` (`empleados.fitz` ya lo importaba, por eso ahí no salía).

Mapa completo del DSL: `d:\fitz\src\view\{expand,check,codegen_ssr,parser,lexer}.rs`.

---

## Rebanada 1 — `GridToolbar.fitzv` (hecha)

Search form + pills de estado + botones (export/tree/nuevo). Props:
`q`, `estado`, `export_href`, `ph_search` (placeholder pre-computado por el
gotcha #1), `locale`. Pills activas con `{#if estado == "…"}`.

**Cableado en `empleados.fitz`:**
- import: `from GridToolbar import grid_toolbar, grid_toolbar_render`
- en `render_grid`: `let toolbar_html: Str = grid_toolbar_render(grid_toolbar {
  q: q, estado: estado, export_href: export_href, ph_search: t(locale,
  "grid.search.ph"), locale: locale }).raw`
- en el return: el bloque `<div class="grid-toolbar">…</div>` → `{toolbar_html}`
- **eliminado:** `fn estado_pill(...)` + los `let pill_*` + labels
  `ph_search/lbl_search/lbl_clear/lbl_locations/lbl_new/lbl_export`.

## Rebanada 2 — `GridFilters.fitzv` (hecha)

Barra de deptos (`{#for d in deptos}` sobre `List<Departamento>`) + barra
"Agrupar por" (3 pills). Multi-root. Props: `deptos`, `depto`, `group_by`,
`locale`.

**Cableado:**
- import: `from GridFilters import grid_filters, grid_filters_render`
- en `render_grid`: `let filters_html: Str = grid_filters_render(grid_filters {
  deptos: deptos, depto: depto, group_by: group_by, locale: locale }).raw`
- return: la barra deptos + `{group_bar}` → `{filters_html}`
- **eliminado:** `fn depto_pill(...)`, `fn group_pill(...)`, los `let
  grp_*/group_bar/depto_todos/depto_pills/lbl_depto`.

---

## Rebanada 3 — `EmpleadoRow.fitzv` (✅ HECHO — implementado según este plan)

> El `{#if}` inline (chevron/checkbox/badge) compila y valida run↔binario sin
> whitespace feo — el riesgo del plan quedó descartado. `row_helpers.fitz` +
> `EmpleadoRow.fitzv` creados, los 2 call sites cableados, `grid_row` +
> `estado_badge` borrados. Plan original abajo como referencia.


**Decisión (elección del autor: "arquitectónicamente lo mejor + escalable"):**
SFC declarativo para la estructura del `<tr>`, con helpers puros en un módulo
nuevo `row_helpers.fitz` (separado para evitar el ciclo — `empleados.fitz`
importa `EmpleadoRow`) solo para los bits que el DSL no expresa inline: la clase
de fila (necesita `match`) y los tooltips (van en atributos → gotcha #1).

**Props (9 escalares, evita el default nominal):** `id: Int`, `nombre: Str`,
`email: Str`, `cargo: Str`, `depto: Str` (nombre del depto, pre-computado con
`depto_name(...)`), `activo: Bool`, `checked: Bool`, `expanded: Bool`,
`locale: Str`.

### `src/row_helpers.fitz` (nuevo)
```fitz
// Helpers puros para EmpleadoRow.fitzv. Módulo aparte para evitar el ciclo
// (empleados.fitz importa EmpleadoRow). Envuelven lo que el DSL no expresa
// inline: la clase de fila (match) y los tooltips (t() en atributo → comillas
// anidadas rompen; el helper mueve la comilla adentro).
from i18n import t

fn row_class(checked: Bool, expanded: Bool) -> Str {
    return match checked {
        true => "row-selected",
        false => match expanded {
            true => "row-expanded",
            false => "",
        },
    }
}

fn row_tip_detail(locale: Str) -> Str => t(locale, "grid.tip.detail")
fn row_tip_edit(locale: Str) -> Str => t(locale, "grid.tip.edit")
fn row_tip_delete(locale: Str) -> Str => t(locale, "grid.tip.delete")
```

### `src/EmpleadoRow.fitzv` (nuevo)
```fitz
from row_helpers import row_class, row_tip_detail, row_tip_edit, row_tip_delete
from i18n import t
from fitz_liveviews import flv

component empleado_row {
  state {
    id: Int = 0
    nombre: Str = ""
    email: Str = ""
    cargo: Str = ""
    depto: Str = ""
    activo: Bool = true
    checked: Bool = false
    expanded: Bool = false
    locale: Str = "es"
  }

  <template>
    <tr class="{row_class(checked, expanded)}">
      <td data-label="" class="col-exp"><button class="btn-icon btn-exp" data-tooltip="{row_tip_detail(locale)}" data-flv-click="toggle_row" data-flv-value-id="{id}">{#if expanded}▾{#else}▸{/if}</button></td>
      <td data-label="" class="col-sel">{#if checked}<input type="checkbox" class="row-sel" data-flv-click="toggle_sel" data-flv-value-id="{id}" checked />{#else}<input type="checkbox" class="row-sel" data-flv-click="toggle_sel" data-flv-value-id="{id}" />{/if}</td>
      <td data-label="ID" class="col-id">{id}</td>
      <td data-label="Nombre"><strong>{flv(nombre)}</strong></td>
      <td data-label="Email">{flv(email)}</td>
      <td data-label="Cargo">{flv(cargo)}</td>
      <td data-label="Departamento">{flv(depto)}</td>
      <td data-label="Estado">{#if activo}<span class="badge badge-ok">{flv(t(locale, "badge.active"))}</span>{#else}<span class="badge badge-off">{flv(t(locale, "badge.inactive"))}</span>{/if}</td>
      <td data-label="Acciones" class="col-actions">
        <button class="btn-icon" data-tooltip="{row_tip_edit(locale)}" data-flv-click="edit_empleado" data-flv-value-id="{id}">✎</button>
        <button class="btn-icon btn-danger" data-tooltip="{row_tip_delete(locale)}" data-flv-click="ask_delete_one" data-flv-value-id="{id}">🗑</button>
      </td>
    </tr>
  </template>
}
```
> **Riesgo a validar primero:** el `{#if}` **inline** (chevron/checkbox/badge en
> medio de una línea). Si el parser lo rechaza o mete whitespace feo, pasar a
> block-style o mover ese bit a un helper que devuelva el HTML (interpolación
> cruda, gotcha #2). Validar con `fitz run` apenas exista el archivo.

### Cableado en `empleados.fitz`
- import: `from EmpleadoRow import empleado_row, empleado_row_render`
- **call site A (flat loop, ~línea 1056):**
  `body_str = body_str + grid_row(e, deptos, sel, expanded, locale).raw`
  → `body_str = body_str + empleado_row_render(empleado_row { id: e.id, nombre:
  e.nombre, email: e.email, cargo: e.cargo, depto: depto_name(deptos,
  e.departamento_id), activo: e.activo, checked: id_checked(sel, e.id), expanded:
  id_checked(expanded, e.id), locale: locale }).raw`
- **call site B (`group_section`, ~línea 703):**
  `h_join(members.map(fn(e) => grid_row(e, deptos, sel, expanded, locale)))`
  → `h_join(members.map(fn(e) => empleado_row_render(empleado_row { id: e.id, ...
  igual ... })))` (el `_render` devuelve `Html`, así que sirve directo a
  `h_join`, sin `.raw`).
- **eliminar:** `fn grid_row(...)` y `fn estado_badge(...)` (ya no se usan; el
  badge quedó declarativo en el SFC). **Mantener** `depto_name(...)` (lo usa el
  parent para el prop `depto`, y también `row_detail`/`grouped_body`/export).

---

## Rebanada 4 — `EmpleadoForm.fitzv` (✅ HECHO — thin-shell, según este plan)

> Se fue por el thin-shell. `form_helpers.fitz` recibió los option-builders +
> permisos/skills + tabs/stepper/rating + 3 helpers nuevos de cáscara
> (`form_banner` / `form_header_nav` / `form_footer_nav`) + `panel_cls_*` +
> `ph_*` (placeholders i18n). `id_checked` se duplicó ahí (copia; sigue en
> `empleados.fitz`). El SFC tiene 25 props (18 escalares + 7 `List<Nominal>`,
> defaults literales `[]`); los inputs de texto son inline, los radios de estado
> usan `{#if}`, todo lo demás interpola helpers crudos. Gotcha nuevo que pegó al
> compilar: faltaba `import Html` en `form_helpers.fitz` (gotcha #9 arriba).
> El smoke NO ejercita un save *válido* (insertaría/actualizaría la DB y rompería
> el diff entre corridas independientes); el happy-path del save lo valida el
> autor en el browser. Plan original abajo como referencia.


`form_html(...)` (~180 líneas) + `form_screen(...)` (fetch async de opciones).
Es el más difícil: la estructura tiene tabs/stepper/cascadas `data-flv-change`, y
el contenido se arma con ~15 helpers imperativos de HTML crudo.

**Enfoque recomendado (thin shell + helpers, aprovechando gotcha #2):**
`EmpleadoForm.fitzv` como cáscara declarativa (tabs/panels/stepper/footer con
`{#if}`) que **interpola** los helpers existentes movidos a un módulo nuevo
`form_helpers.fitz` (para romper el ciclo). Los helpers devuelven HTML crudo y se
emiten crudos.

**Helpers a mover a `form_helpers.fitz`** (hoy en `empleados.fitz`):
`depto_options`, `option_tag`, `pais_options`, `provincia_options`,
`ciudad_options`, `permisos_html`, `skills_html`, `reporta_options`, `tab_btn`,
`tab_panel_cls`, `step_order`, `step_dot`, `stepper_bar`, `rating_input`,
`id_checked` (compartido — ¡ojo, también lo usa `empleados.fitz`! dejar copia o
importarlo de vuelta). Revisar dependencias cruzadas antes de mover.

**Estado del componente (mucho):** los ~20 escalares `f_*` (`edit_id`,
`f_nombre`, `f_email`, …, `f_tab`, `error`) + `List<Nominal>` (`deptos`,
`paises`, `provincias`, `ciudades`, `permisos`, `skills`, `colegas`). Todo con
defaults literales.

**Desafíos concretos:**
- Placeholders/labels con `t(locale, "…")` en atributos → gotcha #1 (props o
  helpers).
- Los `<select>` con `data-flv-change="cascade_*"` — atributo literal OK; las
  `<option>` las genera un helper (`{pais_options(paises, f_pais)}` crudo).
- `is_stepper`/`header_nav`/`footer_nav` (alta=stepper, edición=tabs) → `{#if
  edit_id == 0}` o un helper que devuelva el nav.
- Todos los paneles quedan en el DOM (solo se ocultan por CSS) para que el form
  serialice todo — mantener ese contrato.

**Validación:** extender `dev/grid_smoke.py` con pasos de form
(`new_empleado`, `edit_empleado`, `form_tab`, `cascade_pais`, `save_empleado`
con datos válidos/ inválidos) y assertear el HTML. Confirmar run↔binario.

> Alternativa si el thin-shell se complica: dejar `form_html` como render clásico
> (no todo tiene que ser SFC). Decidir al arrancar la rebanada.

---

## Cómo validar (run ↔ binario) — el smoke

Script: `dev/grid_smoke.py` (login → WS `/live/empleados` → secuencia fija de
eventos → vuelca el `html` de cada frame + assertea invariantes). Requiere
Python con `websocket-client` + `requests`.

```bash
# 0) fitz core v0.28.8 instalado (ver abajo). Postgres fitz_admin arriba.
cd d:/fitz-liveviews/examples/admin

# 1) run
fitz run &                      # sirve en :3000
python dev/grid_smoke.py 3000 run_frames.txt

# 2) binario
#   matar el run (taskkill del PID en :3000), luego:
fitz build                      # -> target/release/admin-abm.exe
DATABASE_URL="postgres://fitz:fitz@localhost:5432/fitz_admin?sslmode=disable" \
  ./target/release/admin-abm.exe &
python dev/grid_smoke.py 3000 binario_frames.txt

# 3) diff normalizando los UUIDs per-connection (Toast/ConfirmDialog cid)
UUID='[0-9a-f]\{8\}-[0-9a-f]\{4\}-[0-9a-f]\{4\}-[0-9a-f]\{4\}-[0-9a-f]\{12\}'
sed "s/$UUID/CID/g" run_frames.txt > a.txt
sed "s/$UUID/CID/g" binario_frames.txt > b.txt
diff a.txt b.txt   # esperado: vacío (== bit-a-bit salvo cid random)
```

Los diffs legítimos entre run y binario son dos, ambos cosméticos:

1. Los `instance_id` UUID per-connection (`let cid = Uuid.v4()`), aleatorios por
   conexión → se normalizan con el `sed` de arriba.
2. **La ubicación de los `\r` (CRLF) en líneas de whitespace de los literales /
   templates multi-línea** — artefacto preexistente conocido (v0.28.5: "HTML
   idéntico módulo line-endings"). El intérprete y el codegen intercalan los `\r`
   distinto en el whitespace de indentación; el contenido HTML (tags, atributos,
   texto) es idéntico y el navegador colapsa ese whitespace. Aparece desde que el
   grid incluye un `.fitzv` con `<template>` multi-línea (EmpleadoForm); el grid
   de una-línea-por-celda de EmpleadoRow no lo disparaba. **Normalizarlo con
   `tr -d '\r'` en ambos lados antes de diffear** (el diff queda vacío):

   ```bash
   sed "s/$UUID/CID/g" run_frames.txt | tr -d '\r' > a.txt
   sed "s/$UUID/CID/g" binario_frames.txt | tr -d '\r' > b.txt
   diff a.txt b.txt   # esperado: vacío
   ```

**El chequeo visual del CSS lo hace el autor** (el smoke headless no renderiza
estilos).

## Entorno

- **fitz core v0.37.14** compilado desde `d:\fitz` HEAD. La Rebanada 5
  (Departamentos) **requiere v0.37.14**: cierra un bug de codegen de state
  compartido de módulo (un `let PAGE_SIZE: Int = 8` de módulo usado por handlers
  `@ws` emitía `pub const` + materialización `__FITZ_STATE_PAGE_SIZE` faltante →
  E0425/E0530). Con < v0.37.14 el `fitz build` del admin falla. `fitz run` andaba
  en cualquier versión (el intérprete captura el env del módulo).
- **Postgres local** `fitz_admin` en `localhost:5432`, rol `fitz`/`fitz`
  (superuser `postgres`/`123mgp` solo para seed). 10 empleados, 4 deptos.
  Login demo: `admin@fitz.dev` / `admin1234`.

## Deudas residuales anotadas (no bloquean)

- ~~**Mixed attr interpolation en el target WASM**~~ — **CERRADO** en Fitz core
  CW.9 (v0.29.4): el emisor client-WASM ya soporta `style="width: {pct}%"` /
  `class="toast toast-{kind}"`. Este showcase es SSR-first, así que nunca lo
  necesitó, pero la deuda ya no existe.
- **Gotchas del DSL `.fitzv` que aún fuerzan helpers** (sección "⚠️ Gotchas"
  arriba): los dos molestos que quedan son #1 (comillas dobles anidadas en
  **valor de atributo** → helper por cada label i18n en atributo) y #6 (`{expr}`
  bare en atributo → variantes `{#if checked}...{#else}...{/if}`). Un fix del
  view-parser del core los cerraría. #7 (`fitz check` no view-parsea `.fitzv`):
  los errores de view solo salen en `fitz run`/`fitz build`.
