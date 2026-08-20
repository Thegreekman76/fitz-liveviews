# Norte — fitz-liveviews (framework LiveViews)

Backlog técnico surgido de la auditoría hecha para **MatHelp** (juego de matemática
mobile-first, i18n es-AR + en, Postgres, 100% Fitz). Primer proyecto real de terceros
apoyado de punta a punta en el stack.

Fecha del análisis: **2026-08-19** · Actualizado: **2026-08-20** (hallazgos de la fase F0)
Versión auditada: **v0.47.0** (el core `fitz` está en v0.48.0).
Los IDs `FITZ-*` viven en `fitz/docs/norte-mathelp.md`.

Documento vivo: marcá los checkboxes al implementar. IDs estables — no renumerar.

> **Nota de renumeración (2026-08-20):** en el archivo del core, `FITZ-09` (Map.remove) y
> `FITZ-10` (differ) se renumeraron a **FITZ-13** y **FITZ-14** para dejar libres los IDs que el
> autor asignó a los hallazgos nuevos. Acá, `FLV-03` (eviction) ahora depende de **FITZ-13**.

---

## Resumen ejecutivo

De los 9 puntos del framework (B1–B9): 5 confirmados, 2 parciales, 2 refutados. La fase F0 sumó
**FLV-10** — la manifestación de un bug de codegen del core (**FITZ-09**) dentro de la librería, y es
el hallazgo más grave para el framework.

- **FLV-10 (`flv_cookie` no compila a nativo) es un ALTO.** `flv_cookie(cookie: Str?, name: Str) -> Str?`
  (`src/lib.fitz:2430`) dispara el bug del codegen de `T?` del core (**FITZ-09**): el Rust generado emite
  `return ()` donde va `return None`. Consecuencia: **cualquier app que dependa de fitz-liveviews y compile
  a nativo choca**. Verificado: **`examples/admin` no compila con `fitz build`** (importa el framework
  entero) — la app insignia solo se validó con `fitz run`. Se cierra cuando cierre FITZ-09 en el core.
- **FLV-04 (reconnect sin replay) sigue siendo el trabajo de verdad** — el que separa demo de producto.
  El runtime crea el socket una vez, sin `onclose`/reconnect (`src/lib.fitz:224`), y el `instance_id` es
  UUID nuevo por socket. En mobile la conexión se corta todos los días.
- **FLV-06 (DataGrid cards) REFUTADO — ya resuelto** (`@media 640px` + `data-label`).
- **B7 refutado a medias:** `{#elseif}` falta (código en fitz core `src/view/`), `@submit` ya existe.
- **B1 refutado a medias:** `app_shell(title, lang, head_extra)` ya customiza el head; falta un layout
  *mínimo* sin el chrome de admin (FLV-01).
- **FLV-03 (eviction) bloqueada por el core:** el store no se puede limpiar sin `Map.remove` (**FITZ-13**).

**Recomendación de arranque:** los quick wins que MatHelp usa ya — **FLV-09 (docs i18n)** + **FLV-01
(layout mínimo)** + **FLV-05 (touch targets)**. En paralelo, **FLV-10 se cierra solo** cuando el core
arregle FITZ-09. El trabajo grande, **FLV-04 (reconnect)**, se planifica aparte (costo L).

---

## Tabla priorizada (unificada cross-repo, re-priorizada 2026-08-20)

Misma tabla en los dos archivos; acá se detallan solo las fichas de fitz-liveviews.
Filas `FITZ-*` viven en `fitz/docs/norte-mathelp.md`.

| #  | ID       | Tarea                                   | Estado              | Impacto     | Costo | Riesgo | Depende / desbloquea |
|----|----------|-----------------------------------------|---------------------|-------------|-------|--------|----------------------|
| 1  | FITZ-01  | Módulo `rand` (fitz core)               | Confirmado          | Bloqueante  | M     | Ninguno| —                    |
| 2  | FITZ-09  | Codegen `-> T?` (fitz core)             | Confirmado (repro)  | Alto        | S     | Bajo   | **cierra FLV-10**    |
| 9  | FLV-04   | Reconnect + state replay                | Confirmado          | Alto        | L     | Medio  | **T3**               |
| 10 | FLV-09   | Capítulo `docs/i18n.md`                  | Confirmado          | Alto        | S     | Ninguno| FITZ-03, FITZ-05, FLV-01 |
| 12 | FLV-01   | Layout customizable (`live_layout_with`)| Ya resuelto         | Medio       | S     | Ninguno| —                    |
| 13 | FITZ-13  | `Map.remove` (fitz core)                | Ya resuelto (v0.50.0)| Medio      | S     | Bajo   | **desbloquea FLV-03**|
| 14 | FLV-03   | Eviction / TTL de instancias            | Confirmado (desbloqueado)| Medio  | M     | Bajo   | ~~FITZ-13~~ (listo)  |
| 15 | FLV-10   | `flv_cookie` no compila a nativo        | Ya resuelto (FITZ-09)| **Alto**   | —     | —      | ~~FITZ-09~~ (cerrado v0.49.0) |
| 16 | FLV-07   | `{#elseif}` (código en fitz core `src/view/`) | Confirmado    | Medio       | S     | Bajo   | —                    |
| 17 | FLV-05   | Touch targets ≥ 44px                    | Ya resuelto         | Medio       | S     | Bajo   | **T3**               |
| 18 | FLV-02   | Warning por `<style>`/`<script>` en root | Confirmado         | Medio       | M     | Bajo   | —                    |
| 23 | FLV-08   | `dispatch_to_all`                       | Confirmado          | Bajo        | M     | Bajo   | —                    |

Estado ∈ `Confirmado` · `Parcial` · `Refutado` · `Ya resuelto`
Impacto ∈ `Bloqueante` · `Alto` · `Medio` · `Bajo` · Costo ∈ `S` (horas) · `M` (días) · `L` (semana+)
(los `#` saltados son filas `FITZ-*` — ver el archivo hermano para la tabla completa)

---

## Fichas

### FLV-10 · `flv_cookie` no compila a nativo (manifestación de FITZ-09)

- [ ] Implementado
- **Estado:** Confirmado con repro (sobre el binario compilado).
- **Evidencia:** `flv_cookie(cookie: Str?, name: Str) -> Str?` (`src/lib.fitz:2430-...`) tiene el patrón
  exacto del bug de codegen de `T?` del core (**FITZ-09**): `null => { return null }`, `c => c`, y un
  `return null` de tail. El Rust generado (`fitz_liveviews.rs:1432` en un build real del autor) emite
  `let mut raw: String = (match cookie.clone() { None => { return () }, ... })` → `E0308: expected
  Option<String>, found ()`. Verificado que **`examples/admin` importa el framework entero**
  (`auth.fitz:17`, `dashboard.fitz:15`, `departamentos.fitz:27`, ... con dep `{ path = "../.." }`), por lo
  que el codegen transpila el módulo del framework completo → el `flv_cookie` roto va al Rust generado →
  **`examples/admin` no compila con `fitz build`**.
- **Impacto en un usuario real (ALTO):** `flv_cookie` resuelve el locale y la sesión desde la cookie del
  handshake — lo necesita toda app con i18n o auth. Como el codegen transpila el módulo entero, **cualquier
  app que dependa de fitz-liveviews y compile a nativo choca**, la use o no directamente. La app insignia del
  framework no compila a nativo; solo se validó con `fitz run`.
- **Workaround hoy:** correr el intérprete (`fitz run`) en producción / Docker. Funciona, pero pierde el
  binario nativo (~9x de performance + runtime distroless).
- **Propuesta:** **no hay trabajo del lado de fitz-liveviews** — el fix es en el core (FITZ-09: emitir
  `None`/`Some(...)` en posición de `return` dentro de una fn `-> T?`). Esta ficha existe para (a) que quede
  registrada en el repo del framework y (b) definir el criterio de verificación acá.
- **Criterio de aceptación (cierre de FLV-10):** con FITZ-09 arreglado en el core, `fitz build` compila la
  **librería entera** (`flv_cookie` incluida) **y** `examples/admin` compila y corre igual que interpretado
  (paridad `fitz run` ↔ binario).
- **Archivos a tocar:** ninguno en fitz-liveviews (el fix es `fitz/src/codegen.rs`). Verificación: buildear
  `examples/admin` con el core arreglado; sumar `examples/admin` (o un mini programa que llame `flv_cookie`)
  al smoke de builds nativos si no está.
- **Tests:** un smoke que `fitz build examples/admin` compile; idealmente el corpus de paridad de FITZ-14
  incluye un caso `-> T?` que ejercite `flv_cookie`.
- **Docs:** — (se cierra con FITZ-09).
- **Dependencias:** **FITZ-09 (core)**. FLV-10 no se puede cerrar antes.
- **Notas de diseño:** conviene que, tras cerrar FITZ-09, el CI del framework buildee `examples/admin` a
  nativo (hoy aparentemente solo corre `fitz check`/`fitz run` sobre él) — es la app insignia y debería estar
  cubierta por la vía compilada, no solo la interpretada.

---

### FLV-04 · Reconnect + state replay

- [ ] Implementado
- **Estado:** Confirmado.
- **Evidencia:** `README.md:49-51` (reliability debt: "reconnect with state replay"). El runtime JS
  (`LIVE_CLIENT_JS`, `src/lib.fitz:219+`) crea el socket una vez (`:224`); solo `onmessage` (`:317`) y
  `onopen` (`:344`). Grep `onclose|reconnect|backoff|retry` → 0. El `__flv_init` (`:344-351`) solo transporta
  query params, no un id de sesión estable. El `instance_id` se acuña por socket
  (`examples/admin/src/departamentos.fitz:238`); el store está keyed por `"{name}:{instance_id}"`
  (`src/lib.fitz:2120`) → reconectar = UUID nuevo = estado huérfano.
- **Impacto en un usuario real:** un chico con datos móviles pierde señal 3 segundos, o el sistema suspende
  la pestaña. Al volver, el WebSocket está muerto y la partida se cortó. **En mobile pasa todos los días.**
  Para un framework *real-time*, el reconnect es tabla — la diferencia entre demo y producto.
- **Workaround hoy:** persistir cada respuesta a Postgres y ofrecer "reanudar partida". Sirve (MatHelp lo
  hace igual), pero es un rodeo por la DB y no cubre el estado efímero de UI.
- **Propuesta (diseño):** (1) cliente: `ws.onclose` con backoff exponencial (250ms→10s). (2) identidad
  estable: emitir un `instance_id`/token de LiveView en el HTML inicial (SSR) y reenviarlo en `__flv_init`.
  (3) replay: ante un `__flv_init` con id conocido, el server responde con el HTML actual del componente para
  rehidratar. Modelo Phoenix LiveView.
- **Criterio de aceptación:** cortando y restaurando el socket, la LiveView se rehidrata con su estado previo
  sin reload; el `instance_id` sobrevive; el estado en el store se reencuentra.
- **Archivos a tocar:** `src/lib.fitz` (`LIVE_CLIENT_JS`, `__flv_init`, keying del store, dispatch de
  full-render ante re-init). Cross-repo: verificar que el emisor SSR de `.fitzv` (fitz core `src/view/`)
  pueda hornear el `instance_id` estable (probablemente un `data-flv-instance` en el root, sin cambio de core).
- **Tests:** smoke manual (sockets flaky en CI). Documentar el procedimiento.
- **Docs:** `docs/liveviews.md` (modelo de reconexión).
- **Dependencias:** ninguna dura. **T3**. Mayor costo del backlog.
- **Notas de diseño:** el outbox backpressure y la coordinación multi-instancia (los otros reliability debts)
  son separables. El estado efímero de UI puede no sobrevivir el replay en el MVP; el de dominio sí (se
  re-deriva del server).

---

### FLV-09 · Capítulo `docs/i18n.md`

- [ ] Implementado
- **Estado:** Confirmado.
- **Evidencia:** `docs/ui-components.md:100` ("i18n-agnostic"). No existe `docs/i18n.md`. El patrón vive solo
  en el admin: cookie + `locale_from_cookie` (`examples/admin/src/i18n.fitz:13-34`), `<html lang>`
  (`shell.fitz:126`), `/lang/{code}` con `Set-Cookie` + 303 (`auth.fitz:107-125`), y el locale al `@ws` por
  **cookie del handshake** (`empleados.fitz:1046-1061`: `@header(name="cookie")` + `@ws`), no por `__flv_init`.
- **Impacto en un usuario real:** mantener i18n **fuera de la librería es correcto**, pero el patrón está
  enterrado en un ejemplo. Alguien que arranca multi-idioma (MatHelp) no lo encuentra y hardcodea strings. El
  bug clásico — el locale no llega al socket, los diffs vuelven en el idioma equivocado — es facilísimo de
  cometer y confusísimo de debuggear.
- **Workaround hoy:** copiar a mano el patrón del admin.
- **Propuesta:** `docs/i18n.md` con el camino oficial: (1) cookie de idioma; (2) `locale_from_cookie` en cada
  `@get` **y** `@ws`; (3) `<html lang>` vía `app_shell` (FLV-01); (4) `/lang/{code}` con `Set-Cookie` + 303;
  (5) diccionario `t(locale, key)` como responsabilidad del host; (6) **la advertencia**: el locale al `@ws`
  va por la cookie del handshake (`@header` sobre `@ws`), no `__flv_init`.
- **Criterio de aceptación:** un dev que sigue `docs/i18n.md` monta una app bilingüe con el locale correcto en
  HTTP y en el socket, sin leer el código del admin.
- **Archivos a tocar:** nuevo `docs/i18n.md`; `mkdocs.yml`; cross-link desde `docs/ui-components.md:100` y el
  cap de LiveViews.
- **Tests:** N/A (verificar que el ejemplo citado compila/corre).
- **Docs:** *es* la tarea.
- **Dependencias:** se escribe mejor **después** de FITZ-05 (cookies) y FLV-01, pero se puede arrancar hoy con
  el patrón manual. Núcleo de **T1**.
- **Notas de diseño:** mantener la lib i18n-agnóstica (no se toca). Falta documentación, no código. Resaltar en
  negrita el dato del handshake-cookie sobre `@ws` — el error más caro.

---

### FLV-01 · Layout customizable (`live_layout_with`)

- [x] Implementado (2026-08-20, v0.48.0) — `fn live_layout_with(opts: LayoutOpts, ws_path, root_id, initial) -> Html`
  + `type LayoutOpts { title, lang, head_extra, body_class, theme, theme_color }`. `<head>` default
  mobile-friendly (`viewport-fit=cover` + `theme-color` + `format-detection: telephone=no`), `<html lang>`
  + `data-theme`, `<body class>`, título escapado con `flv`. `live_layout(...)` **delega** con
  `LayoutOpts {}` (aditivo — todo caller existente gana `lang="en"` + head mobile). 5 `@test` nuevos
  (`live_layout_with_*`) + el `live_layout_wraps_in_full_html_document` reapuntado. Docs en
  `docs/liveviews.md` (sección "Customizing the document") + tabla de API. **T1** (`<html lang>`) y **T3**
  (viewport/theme-color).
- **Estado:** Ya resuelto.
- **Evidencia:** `src/lib.fitz:503-517` (`live_layout` con `<title>Fitz LiveView</title>` fijo `:510`, `<html>`
  sin `lang` `:506`). **PERO** `app_shell(title, lang, head_extra, sidebar, topbar, crumbs, body, body_extra)`
  (`src/ui/AppShell.fitz:36-64`) emite `<html lang="{lang}">`, `<title>{flv(title)}</title>` y `{head_extra.raw}`.
  El admin usa `app_shell` (`shell.fitz:114`), no reimplementa el shell con `live_embed`.
- **Impacto en un usuario real:** MatHelp necesita `viewport-fit=cover`, `theme-color`, `apple-mobile-web-app-capable`,
  `<link rel=manifest>`, `<html lang="{locale}">`. Con `app_shell` ya se inyectan vía `head_extra` — pero
  `app_shell` trae todo el chrome de admin (sidebar/topbar/crumbs), que un juego no quiere. Falta un layout
  **mínimo** customizable.
- **Workaround hoy:** `app_shell` con chrome vacío, o `live_embed` a mano (como `login_layout`).
- **Propuesta (API cerrada):**
  ```fitz
  fn live_layout_with(opts: LayoutOpts, ws_path: Str, root_id: Str, initial: Html) -> Html
  type LayoutOpts {
      title: Str = "Fitz LiveView"
      lang: Str = "en"
      head_extra: Html = html("")   // meta, theme-color, manifest, favicon, CSS
      body_class: Str = ""
      theme: Str = "auto"
  }
  ```
  `live_layout(...)` queda delegando con defaults. Aditivo. **Bonus mobile (→ T3):** que el `<head>` default
  ya traiga `viewport-fit=cover` y `theme-color`.
- **Criterio de aceptación:** `live_layout_with(...)` produce `<html lang>` + `<title>` custom + `head_extra`,
  **sin** el chrome de admin; `live_layout(...)` clásico sin regresión.
- **Archivos a tocar:** `src/lib.fitz:503` (`live_layout_with` + `LayoutOpts`, `live_layout` delega);
  reusar la parte de head de `AppShell.fitz` sin su chrome.
- **Tests:** `@test` de `<html lang>` + `head_extra` en el output; `live_layout` sin regresión.
- **Docs:** `docs/liveviews.md` + `docs/ui-components.md`.
- **Dependencias:** ninguna. **T1** (`<html lang>`) y **T3** (viewport/theme-color).
- **Notas de diseño:** barato (S) porque `app_shell` ya resolvió el mecanismo; esto es extraer un layout mínimo
  con defaults mobile-friendly. Reusar, no reinventar.

---

### FITZ-13 · `Map.remove` (fitz core) — prerequisito de FLV-03

- [ ] (se implementa en fitz core — ver `fitz/docs/norte-mathelp.md` → FITZ-13)
- **Estado:** Confirmado. Ficha completa en el archivo del core.
- **Resumen:** el store de componentes no puede evictar (`src/lib.fitz:2206`) porque `Map` no tiene `remove`
  en el core. `m.remove(key) -> Bool` desbloquea FLV-03. Anotado acá por la dependencia cross-repo.

---

### FLV-03 · Eviction / TTL de instancias

- [ ] Implementado
- **Estado:** Confirmado. **Bloqueada por FITZ-13** (`Map.remove` en fitz core).
- **Evidencia:** `src/lib.fitz:2124` (`COMPONENT_STATE_STORE`), `:2206-2210` ("never evicted ... `Map` has no
  `remove` yet"); `docs/components.md:398-402`. **`flv_disconnect` SÍ existe** (`:2377-2379`) pero solo dispara
  `on_disconnect` — **no borra la entrada** (falta `Map.remove`). La doc "no disconnect hook" está desactualizada.
- **Impacto en un usuario real:** cada partida usa una instancia `Uuid.v4()`. Cien chicos/día = cien entradas
  que **nunca se liberan** — leak lento en un proceso long-running. En un juego infantil, abrir-y-abandonar es
  el caso normal.
- **Workaround hoy:** persistir a Postgres, tratar la memoria como caché. El leak sigue.
- **Propuesta (API cerrada):**
  ```fitz
  flv_evict(name, id) -> Bool
  component_ttl(name, secs)
  flv_store_stats() -> Map<Str, Int>
  ```
  Y que **`flv_disconnect` evicte por default** (o documentar que hay que llamarlo). El `flv_drop_instance`
  "planned" (`:2206`) es esto.
- **Criterio de aceptación:** `flv_evict` libera memoria; `component_ttl` evicta inactivas; `flv_store_stats`
  reporta el conteo. Un ciclo de N conexiones no crece la memoria sin techo.
- **Archivos a tocar:** `src/lib.fitz` (store `:2124`, `flv_disconnect` `:2377`, nuevos
  `flv_evict`/`component_ttl`/`flv_store_stats`/`flv_drop_instance`). **Requiere `Map.remove` (FITZ-13)**.
- **Tests:** `@test` de `flv_evict` + `flv_store_stats`; ciclo sin crecimiento de memoria.
- **Docs:** `docs/components.md` (actualizar "never evicted").
- **Dependencias:** **FITZ-13 (`Map.remove`) es prerequisito duro.**
- **Notas de diseño:** el TTL necesita timestamp por instancia + barrido periódico; el `flv_evict` explícito +
  `flv_disconnect`-evicta-por-default cubre el 90% (el chico cierra la pestaña → `onclose` → disconnect → evict)
  sin el barrido en el MVP.

---

### FLV-07 · `{#elseif}` (código en fitz core `src/view/`)

- [ ] Implementado
- **Estado:** Confirmado para `{#elseif}`. `@submit` **refutado** (ya existe).
- **Evidencia (`{#elseif}` falta):** grep `elseif|elif|else.?if` en `src/**/*.fitzv` → 0. Solo
  `{#if}`/`{#else}`/`{#for}` (`src/ui/Card.fitzv:24-34`). Para encadenar hay que anidar
  (`src/ui/form_layout_helpers.fitz:53`).
- **Evidencia (`@submit` ya existe — REFUTADO):** el azúcar `@event → data-flv-<event>` es genérico
  (`docs/liveviews.md:340-347`; lowering en fitz core `src/view/`). `@submit` produce `data-flv-submit`. Los
  forms usan el atributo crudo por convención (`src/ui/FormLayout.fitzv:22`), no por falta de soporte.
- **Impacto en un usuario real:** las cadenas de dificultad de MatHelp quedan anidadas hasta el absurdo.
  `{#elseif}` las aplana. `@submit` ya se puede usar.
- **Workaround hoy:** anidar `{#if}` dentro de `{#else}`.
- **Propuesta:** `{#elseif cond}` en el parser de templates. **El código vive en fitz core**
  (`d:\fitz\src\view\parser.rs`/`expand.rs`), no en este repo — dependencia cross-repo. Para `@submit`: sin
  trabajo de código; documentarlo.
- **Criterio de aceptación:** `{#if a}...{#elseif b}...{#else}...{/if}` parsea y renderiza; `@submit`
  documentado y funcionando.
- **Archivos a tocar:** **fitz core** `src/view/parser.rs` + `expand.rs`; fitz-liveviews `docs/liveviews.md`.
- **Tests:** en core, parser/expand de `{#elseif}`; en liveviews, un `.fitzv` de ejemplo.
- **Docs:** `docs/liveviews.md` (directivas + aclarar `@submit`).
- **Dependencias:** **el `{#elseif}` es trabajo de fitz core.** Marcado también en `fitz/docs/norte-mathelp.md`.
- **Notas de diseño:** reformular: "falta `{#elseif}`" correcto; "falta `@submit`" impreciso (ya lowerea a
  `data-flv-submit`).

---

### FLV-05 · Touch targets ≥ 44px

- [x] Implementado (2026-08-20, v0.48.0) — token `--flv-touch-target: 44px` en `ui_theme()` +
  `@media (pointer: coarse) { min-height/min-width: var(--flv-touch-target, 44px) }` en `Button` / `Pager`
  / `Tabs` / `SortableHeader` (los interactivos del stack; DataGrid ya colapsa a cards <640px, sus tappables
  son Button/SortableHeader). Solo táctil — desktop compacto sin cambios. Verificado renderizando cada
  componente (`pointer: coarse` + el token aparecen en el `<style scoped>` expandido). Docs: sección "Mobile
  readiness — touch targets" + token en `docs/ui-components.md`. **T3**.
- **Estado:** Ya resuelto.
- **Evidencia:** grep `--flv-touch-target|44px|pointer: coarse` en `src/ui` → 0. Tamaños < 44px:
  `Button.fitzv:94-96` (sm≈28, md≈32, lg≈42), `Pager.fitzv:53-66` (≈28), `Tabs.fitzv:35-38` (≈33-34),
  `DataGrid.fitzv:83-84`. Salvedad: **Pager no tiene prop `size`** (`:24-27`) — el ejemplo puntual del prompt
  no aplica, el problema de fondo sí.
- **Impacto en un usuario real:** en un celu de 360px con un chico de 9 usando el pulgar, los tamaños actuales
  generan errores de tap — y en un juego, un tap errado se lee como "respondí mal", lo peor pedagógicamente.
- **Workaround hoy:** override del CSS con `min-height: 44px` propio.
- **Propuesta:** token `--flv-touch-target: 44px` con `min-height`/`min-width` en los interactivos, y `@media
  (pointer: coarse)` que suba tamaños en táctiles (sin agrandar en desktop).
- **Criterio de aceptación:** en `pointer: coarse`, Button/Pager/Tabs miden ≥ 44px; en desktop compactos.
- **Archivos a tocar:** `src/ui/Button.fitzv`, `Pager.fitzv`, `Tabs.fitzv`, `DataGrid.fitzv`; token
  `--flv-touch-target` en el theme.
- **Tests:** N/A (CSS visual). Smoke manual a 320-360px táctil.
- **Docs:** checklist mobile-readiness en `docs/ui-components.md`.
- **Dependencias:** ninguna. **T3**. Costo S.
- **Notas de diseño:** `(pointer: coarse)` es más preciso que `max-width`. No agrandar en desktop.

---

### FLV-02 · Warning por `<style>`/`<script>` en el root diffeado

- [ ] Implementado
- **Estado:** Confirmado (silencio por omisión, no guard explícito).
- **Evidencia:** `docs/liveviews.md:568-577` (no soportados en el root: comentarios, comillas simples,
  `<script>`, `<style>`, CDATA/DOCTYPE). `parse_element` (`src/lib.fitz:999-1042`) no tiene chequeo; el texto
  interno con `<`/`{` rompe el descenso. `diff_html` (`:1684-1701`) hace `return []` cuando el árbol no colapsa
  → full `html` replace **sin aviso**. No hay `warn`/`error`.
- **Impacto en un usuario real:** MatHelp necesita CSS que depende del estado (barra de progreso, color por
  dificultad, animación de acierto). Hoy todo vive fuera del root, rompiendo la encapsulación de `<style scoped>`.
  Peor: **restricción invisible** — cae a full-replace silencioso, te enterás porque la app va lenta.
- **Workaround hoy:** `<style>` fuera del root (en `head_extra`); clases toggleadas por interpolación de
  atributos dentro del root.
- **Propuesta:** (1) **mínimo:** warning en compile time al detectar `<style>`/`<script>`/comentario en el root.
  (2) **completo:** soportar `<style>` en el root (nodo opaco, el diff no desciende).
- **Criterio de aceptación (nivel 1):** compilar un `.fitzv` con `<style>` en el root emite un warning claro.
  Nivel 2: el `<style>` en el root ya no rompe el diff.
- **Archivos a tocar:** warning → emisor SSR/checker de `.fitzv` (fitz core `src/view/check.rs`/`codegen_ssr.rs`);
  soporte completo → parser del diff (`src/lib.fitz:999`, `:1684`).
- **Tests:** un `.fitzv` con `<style>` en el root → warning; (nivel 2) no cae a full-replace.
- **Docs:** `docs/liveviews.md:568-577`.
- **Dependencias:** el warning toca fitz core (`src/view/`); el soporte completo toca este repo. Cross-repo parcial.
- **Notas de diseño:** el warning es la mitad barata de alto retorno — elimina la trampa hoy. El soporte completo
  puede esperar.

---

### FLV-08 · `dispatch_to_all`

- [ ] Implementado
- **Estado:** Confirmado (prioridad baja).
- **Evidencia:** `docs/components.md:409-411` (pendiente, sin tachar). Grep `fn dispatch_to_all` → 0. Existe
  `dispatch_component_events` (una instancia) y `ws.broadcast` (`:2355,2364` — fan-out de socket, sin routing
  por instancia).
- **Impacto en un usuario real:** para un futuro modo "duelo" entre hermanos. No es del MVP.
- **Workaround hoy:** loopear sobre ids trackeados, o `ws.broadcast`.
- **Propuesta:** `dispatch_to_all(name, event, payload) -> Int` que itera el store por `name` y dispatchea a cada
  instancia.
- **Criterio de aceptación:** dispara el evento en todas las instancias vivas de `name` y devuelve el conteo.
- **Archivos a tocar:** `src/lib.fitz` (iterar `COMPONENT_STATE_STORE` por prefijo).
- **Tests:** `@test` con 2+ instancias.
- **Docs:** `docs/components.md`.
- **Dependencias:** ninguna dura. Bajo — modo duelo futuro.
- **Notas de diseño:** no confundir con `ws.broadcast` (transporte de socket).

---

## Épicos transversales

### T1 · La cadena del i18n
Del lado de **fitz-liveviews**: **FLV-01** (`<html lang>` sin reimplementar el shell; parcial por `app_shell`) +
**FLV-09** (documentar el camino oficial). Del lado del core: **FITZ-03** (`fs`), **FITZ-04** (locale), **FITZ-05**
(cookies). El `docs/i18n.md` queda mejor tras FITZ-03/05 pero se arranca hoy. **Un épico único con dueño.**

### T2 · Paridad `fitz run` ↔ `fitz build`
No es tema del framework en sí, **pero FLV-10 es su manifestación más visible**: `flv_cookie` (y por extensión
`examples/admin`, y cualquier app que dependa del framework) no compila a nativo por el bug de codegen de `T?`
del core (FITZ-09). Se cierra cuando cierre FITZ-09 + FITZ-14 (differ) en el core. Ver `fitz/docs/norte-mathelp.md`.

### T3 · Mobile como ciudadano de primera
Del lado de **fitz-liveviews**: **FLV-04** (reconnect — el único que queda, Costo L), ~~**FLV-01**~~
(viewport/theme-color en el head default — **cerrado v0.48.0**), ~~**FLV-05**~~ (touch targets —
**cerrado v0.48.0**). **FLV-06** ya resuelto. Del lado del core: ~~**FITZ-02**~~ (static → app instalable —
**cerrado v0.51.0**). Con FLV-01/FLV-05/FITZ-02 cerrados, **T3 queda a un solo ítem: FLV-04 (reconnect)**.
Una app Fitz en un celular ya se instala como PWA y tiene targets táctiles cómodos; falta que sobreviva un
corte de señal (reconnect + replay).

---

## Orden de ataque sugerido (re-priorizado 2026-08-20)

**Hito 1 — Quick wins que MatHelp usa desde el día 1.** (parcial)
~~`FLV-01 (layout mínimo, S)`~~ ✅ **v0.48.0** + ~~`FLV-05 (touch targets, S)`~~ ✅ **v0.48.0** + `FLV-09
(docs i18n, S)` (pendiente). **FLV-10 ya se cerró** cuando el core arregló FITZ-09 (v0.49.0) — `flv_cookie`
y `examples/admin` compilan a nativo. Queda solo `FLV-09` de este hito.

**Hito 2 — Eliminar las trampas.**
`FLV-02 (warning por `<style>`/`<script>`, al menos el nivel warning)` + `FITZ-13 (`Map.remove`, core)` →
`FLV-03 (eviction)`.

**Hito 3 — El trabajo de verdad.**
`FLV-04 (reconnect + state replay, L)`. La pieza que separa demo de producto. Smoke manual, planificar con tiempo.

**Hito 4 — Futuro.**
`FLV-07 ({#elseif}, core)` + `FLV-08 (dispatch_to_all)`. Bajo, sin urgencia.

---

## Refutados / fuera de alcance

| ID | Por qué no va | Evidencia |
|----|---------------|-----------|
| FLV-06 (DataGrid cards) | **Ya resuelto** (`@media (max-width: 640px)` + `::before` con `data-label`). Residual: breakpoint fijo, sin prop para optar. | `src/ui/DataGrid.fitzv:99-122` |
| B7 (mitad `@submit`) | **Ya existe.** `@event → data-flv-<event>` genérico (core `src/view/`); `@submit` lowerea a `data-flv-submit`. | `docs/liveviews.md:340-347`; `src/ui/FormLayout.fitzv:22` |
| B1 (conclusión "no hay head") | **Refutada.** `app_shell(title, lang, head_extra)` ya customiza. Falta un layout mínimo (FLV-01). | `src/ui/AppShell.fitz:36-64`; `shell.fitz:114` |

---

## Qué se puede construir HOY con este repo (v0.47.0, sin cambios)

### ✅ Sale limpio, sin workaround (con `fitz run`)
- LiveViews con diffs por WebSocket (`@ws` + `WsConn<T>` + `data-flv-*` + diff engine).
- Componentes UI companion + **DataGrid responsive (ya colapsa a cards en mobile <640px)**.
- `app_shell(title, lang, head_extra, …)` → head customizable (`<html lang>`, theme-color, manifest, favicon).
- Event bindings `@click`/`@input`/`@change`/`@keydown`/`@submit`.
- i18n end-to-end (cookie + `locale_from_cookie` en `@get` y `@ws` + `<html lang>` + `/lang/{code}`) — copiándolo del admin.
- `flv_disconnect` como hook de lifecycle (aunque **no** evicta memoria).

### ⚠️ Sale, pero con workaround — AISLALO detrás de un módulo con la firma futura
| Necesidad | Workaround HOY | Qué tarea lo elimina | Costo de migrar |
|---|---|---|---|
| **Binario nativo** | **No compila** (FLV-10/FITZ-09). Correr el intérprete en Docker | FITZ-09 (core) | Trivial: descomentás el build cuando `T?` compile |
| Layout de juego (sin chrome de admin) | `app_shell` con chrome vacío, o `live_embed` a mano | FLV-01 | Trivial: `live_layout_with(LayoutOpts {...})` |
| `<html lang>` + viewport + theme-color | Pasarlos por `head_extra` de `app_shell` | FLV-01 | Trivial (pasan a defaults / `LayoutOpts`) |
| Reconnect en mobile | Persistir a Postgres + "reanudar partida" | FLV-04 | Medio (el replay cubre el estado de dominio) |
| CSS que depende del estado | `<style>` FUERA del root (en `head_extra`) + clases toggleadas por atributos | FLV-02 | Medio |
| Cadenas de dificultad (4+ ramas) | Anidar `{#if}` en `{#else}` | FLV-07 | Fácil (`{#elseif}`) |
| Touch targets grandes | Override del CSS con `min-height: 44px` | FLV-05 | Trivial |
| Liberar memoria del store | Persistir a Postgres; el leak sigue | FITZ-13 → FLV-03 | Fácil (`flv_evict`) |

### 🚫 No sale hoy de ninguna forma
- **Binario nativo de una app con fitz-liveviews (FLV-10/FITZ-09).** El Docker corre el intérprete hasta que el
  core arregle `T?`. No bloquea *shippear* (el intérprete anda), sí pierde ~9x + distroless.
- **Reconnect automático con replay (FLV-04)** — no existe ni se agrega desde el host. Persistir a Postgres +
  "reanudar" es la estrategia de fiabilidad hasta que FLV-04 llegue.

### 🪤 Trampas conocidas
- **`flv_cookie` (y todo el framework) no compila a nativo** (FLV-10). Si tu Docker falla con `E0308` sobre
  `Option<String>`, es esto — corré el intérprete.
- **`<style>`/`<script>`/comentarios HTML dentro del root** → full-replace silencioso (`src/lib.fitz:1684`). App
  lenta, transiciones cortadas. Poné el `<style>` en `head_extra`, NUNCA en el root.
- **El store nunca evicta** (`src/lib.fitz:2206`) — leak por partida. Persistí a Postgres.
- **`flv_disconnect` NO libera memoria** — solo dispara `on_disconnect`.
- **El locale al `@ws` va por la cookie del handshake** (`@header(name="cookie")`), no `__flv_init`. Si te lo
  olvidás, los diffs vuelven en el idioma equivocado.
- **El `instance_id` es UUID nuevo por socket** — no sobrevive reconexiones (hasta FLV-04).

### 📐 Recomendaciones de arquitectura para MatHelp (fitz-liveviews)
1. **Correr el intérprete en Docker ahora**, con el build nativo comentado y listo para descomentar cuando cierre
   FITZ-09/FLV-10.
2. **Un `game_layout(...)` propio** que hoy envuelva `app_shell` con head mobile (`viewport-fit=cover`,
   `theme-color`, `<link rel=manifest>`, `<html lang="{locale}">`). Migrás su cuerpo cuando exista `live_layout_with`.
3. **Todo el estado crítico en Postgres, el store como caché** — cubre el leak (FLV-03) Y el reconnect (FLV-04) a
   la vez. Guardá el progreso tras cada respuesta.
4. **CSS de estado con clases toggleadas por atributos, no `<style>` en el root.** `<style>` global en `head_extra`.
5. **`locale_from_cookie(cookie)` en CADA `@get` y CADA `@ws`** (con `@header(name="cookie")`) — primera línea de
   cada handler.
6. **Cadenas de dificultad en un helper** (`{#if}` anidados hoy, `{#elseif}` mañana). **Override de touch en un
   `theme.fitz` propio** (un bloque, borrable de una).

El principio: **workarounds fáciles de borrar.** El más caro es el del intérprete-en-Docker (FLV-10/FITZ-09), pero
es un comentario — el día que `T?` compile, descomentás el build nativo. Persistí a Postgres desde el día 1 (cubre
FLV-03 y FLV-04), aislá el layout y el CSS de touch, y nunca caigas en las trampas silenciosas del diff engine.
