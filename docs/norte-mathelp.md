# Norte — fitz-liveviews (framework LiveViews)

Backlog técnico surgido de la auditoría hecha para **MatHelp** (juego de matemática
mobile-first, i18n es-AR + en, Postgres, 100% Fitz). Primer proyecto real de terceros
apoyado de punta a punta en el stack.

Fecha del análisis: **2026-08-19** · Actualizado: **2026-08-20** (hallazgos de la fase F0)
Versión auditada: **v0.47.0** (el core `fitz` está en v0.48.0).
Los IDs `FITZ-*` viven en `fitz/docs/norte-mathelp.md`.

Documento vivo: marcá los checkboxes al implementar. IDs estables — no renumerar.

> **✅ BACKLOG CERRADO (2026-08-20).** Los cuatro hitos están completos: FLV-01/05/09 (Hito 1),
> FLV-02/03 (Hito 2), FLV-04 (Hito 3), FLV-07/08 (Hito 4). Los `FITZ-*` habilitantes se cerraron en el
> core (v0.49.0 → v0.52.0). El resumen ejecutivo y las fichas de abajo son el registro histórico del
> análisis; el estado real de cada ítem está en su ficha y en "Orden de ataque".

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
| 9  | FLV-04   | Reconnect + state replay                | Ya resuelto (v0.49.0)| Alto       | L→M   | Medio  | **cierra T3**        |
| 10 | FLV-09   | Capítulo `docs/i18n.md`                  | Ya resuelto (v0.50.0)| Alto       | S     | Ninguno| FITZ-03, FITZ-05, FLV-01 |
| 12 | FLV-01   | Layout customizable (`live_layout_with`)| Ya resuelto         | Medio       | S     | Ninguno| —                    |
| 13 | FITZ-13  | `Map.remove` (fitz core)                | Ya resuelto (v0.50.0)| Medio      | S     | Bajo   | **desbloquea FLV-03**|
| 14 | FLV-03   | Eviction / TTL de instancias            | Ya resuelto (v0.49.0)| Medio      | M     | Bajo   | ~~FITZ-13~~ (listo)  |
| 15 | FLV-10   | `flv_cookie` no compila a nativo        | Ya resuelto (FITZ-09)| **Alto**   | —     | —      | ~~FITZ-09~~ (cerrado v0.49.0) |
| 16 | FLV-07   | `{#elseif}` (código en fitz core `src/view/`) | Ya resuelto (core v0.52.0)| Medio  | S     | Bajo   | —                    |
| 17 | FLV-05   | Touch targets ≥ 44px                    | Ya resuelto         | Medio       | S     | Bajo   | **T3**               |
| 18 | FLV-02   | Warning por `<style>`/`<script>` en root | Ya resuelto (`.fitzv`, core v0.52.0)| Medio | M | Bajo | (runtime = follow-up)|
| 23 | FLV-08   | `dispatch_to_all`                       | Ya resuelto (v0.50.0)| Bajo       | M     | Bajo   | —                    |

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

- [x] Implementado (2026-08-20, v0.49.0) — **cierra T3 entero.** Cliente (`LIVE_CLIENT_JS`):
  `connect()` re-invocable + `ws.onclose` con backoff exponencial + jitter (250ms → cap 10s, reset al
  reconectar), **session id estable** por tab en `sessionStorage` (sobrevive el drop Y un reload),
  enviado en `__flv_init` como `__flv_session`; no reconecta tras navegación intencional (`__flv_redirect`
  / `beforeunload`). Server: helper `flv_session_id(frame) -> Str` (lee `__flv_session`, fallback
  `Uuid.v4().to_str()`) + `flv_is_init(frame)`. **El replay sale casi gratis**: el version-gap (ya
  existente) fuerza full `html` resync al reconectar, y el store persiste entre conexiones (no evicta en
  disconnect — coordinado con FLV-03). Docs: `docs/liveviews.md` sección "Reconnection & state replay" +
  procedimiento de smoke manual. 8 `@test` (7 de estructura del JS + helpers, 1 de replay puro socket-free
  `flv04_reconnect_replays_state_from_store`). **Decisiones (D1-D5) confirmadas**: id client-side +
  sessionStorage (cero cambios a fitz core), full HTML resync, backoff 250ms→10s+jitter, replay desde el
  store si vive / fresco si el proceso reinició, MVP acotado. **Follow-up documentado**: migrar el admin/
  counter a replay-completo del UI state (hoy el reconnect ya los descongela + re-query DB; solo el UI
  state local resetea).
- **Estado:** Ya resuelto.
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

- [x] Implementado (2026-08-20, v0.50.0) — nuevo `docs/i18n.md` con el camino oficial: (1) cookie de
  idioma + `normalize_locale`; (2) leer el locale en `@get`/`@post` con **`@cookie(name=...)`** (FITZ-05) y
  en `@ws` con **`@header(name="cookie")` + `locale_from_cookie`** (el parser reusable, porque `@cookie` no
  entra en la aridad de `@ws` — ver gap abajo); (3) `<html lang>` via `LayoutOpts`/`app_shell`; (4)
  `/lang/{code}` con `Response { cookies: [Cookie {...}], headers: { Location } }` + 303; (5) `t(locale,
  key)` como responsabilidad del host + interpolación de conteos en el diccionario. **La advertencia** en
  negrita: el locale al `@ws` va por la cookie del handshake, NO `__flv_init`. Todos los ejemplos de código
  type-checkean contra el `fitz` actual. Nav en `mkdocs.yml` + cross-links desde `ui-components.md` y
  `liveviews.md`. Cierra **T1** del lado del framework.
  **Gap del core descubierto** (anotado para `fitz/docs/norte-mathelp.md` → FITZ-05): `@cookie` sobre `@ws`
  falla el checker de aridad ("@ws expects 1 param + 1 per @header" — no cuenta `@cookie`). FITZ-05 fase A
  prometía `@ws`; el binding runtime/codegen puede estar, pero la aridad del checker no lo incluye. Workaround
  actual (documentado): `@header(name="cookie")` + parseo manual. Fix del core = sumar `@cookie` al conteo de
  `check_ws_handler`.
- **Estado:** Ya resuelto.
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

- [x] Implementado (2026-08-20, v0.49.0) — desbloqueado por `Map.remove` (FITZ-13, v0.50.0), coordinado
  con FLV-04. `flv_evict(name, id) -> Bool` (removal explícito), `flv_sweep_idle(max_idle_secs) -> Int`
  (TTL sweep — cada render/dispatch toca `COMPONENT_LAST_SEEN` con `DateTime.now().timestamp()`, el sweep
  evicta lo idle más allá del umbral, un reconnect re-renderiza → se salva), `flv_store_stats() ->
  Map<Str, Int>` (`{ "instances": N }`). **`flv_disconnect` NO evicta** (preserva el replay de FLV-04) —
  solo dispara `on_disconnect`. El barrido lo cablea el user a un `@every(N)`. Doc `components.md` sección
  "Eviction & TTL" (comment stale "never evicted" reemplazado). 3 `@test` (evict/stats/sweep). **`component_ttl`
  per-componente** = refinamiento futuro (hoy `flv_sweep_idle` global cubre el caso).
- **Estado:** Ya resuelto.
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

- [x] Implementado (2026-08-20, fitz core v0.52.0) — `{#if a}...{#elseif b}...{#else}...{/if}` en el parser
  de templates `.fitzv`. **Azúcar puro en el parser** (`d:\fitz\src\view\parser.rs`): `{#elseif b}`
  desazucara a `{#else}{#if b}...{/if}` — un `{#if}` anidado en `else_children`. **Cero cambios en AST,
  expand, checker ni los dos emisores** (SSR + client-WASM) — todos ya recorren `else_children`
  recursivamente. Enum nuevo `BranchTerm { Close, Else, ElseIf }` + `parse_if_from_cond` recursivo. 4 unit
  tests del parser (desugar, cadena de 3, sin else final, stray `{#elseif}` error) + smoke SSR end-to-end
  (chain A/B/C/F según score) + el ejemplo `examples/view/control-flow` sumó una rama `{#elseif}` y **compila
  a WASM real** (`wasm-pack :-) Done`). El `@submit` de la ficha original ya existía (refutado). Doc en el
  cap 36 del guide del core.
- **Estado:** Ya resuelto (implementado en fitz core v0.52.0).
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

- [x] Implementado (nivel `.fitzv`, 2026-08-20, fitz core v0.52.0) — **error claro y dirigido** cuando un
  `<style>`/`<script>` aparece dentro de un `<template>` de un `.fitzv`. Hallazgo que reencuadró la ficha:
  a nivel `.fitzv` NO había full-replace silencioso — ya erraba, pero con un mensaje confuso ("unexpected
  trailing tokens after expression (template interpolation)", porque el `{` del CSS dispara el parser de
  interpolación). El fix (`d:\fitz\src\view\parser.rs::parse_element`, ~15 LoC): interceptar el tag
  `style`/`script` justo tras leerlo y erra con un mensaje que apunta al workaround (CSS en `<style scoped>`
  a nivel componente, o en `head_extra`; estilos state-dependent con class/style interpolados). 2 unit tests.
  Los comentarios HTML (`<!-- -->`) ya se manejaban (se descartan, no rompen). **El checker de `.fitzv` no
  tiene mecanismo de warnings** (solo `Vec<CheckError>`) — por eso es un error, no un warning, y es el fit
  correcto (nunca funcionó). **La otra mitad — la deuda del diff engine runtime de fitz-liveviews**
  (`src/lib.fitz:1684`, `<style>`/`<script>` en HTML *renderizado* → `diff_html` cae a full-replace sin
  aviso) — queda diferida (caso raro: inyectar `<style>` vía render fn; el soporte completo del `<style>` en
  el root es un follow-up mayor).
- **Estado:** Ya resuelto (nivel `.fitzv` — error claro; runtime diff-engine = follow-up).
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

- [x] Implementado (2026-08-20, v0.50.0) — `dispatch_to_all(name, event, payload) -> Int` en `src/lib.fitz`:
  itera `COMPONENT_STATE_STORE` por el prefijo de key `"{name}:"` (el `:` desambigua `board` de `boardx`),
  extrae el id con `key.right(key.len() - prefix.len())`, y hace `dispatch_to(name, id, event, payload)` a
  cada instancia, devolviendo cuántas alcanzó (skipea las que no declaran handler del evento). Para
  broadcasts server-driven cross-instance (modo duelo, cambio de setting global). Actualiza el estado; el
  push de los renders a los clientes lo hace el user (`ws.broadcast`). Iterar un snapshot de `.keys()` es
  seguro (`dispatch_to` solo sobreescribe values, no agrega/quita keys). 2 `@test` (hits-all con
  disambiguación de prefijo + evento desconocido → 0). Doc en `components.md`.
- **Estado:** Ya resuelto.
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

### T1 · La cadena del i18n — ✅ CERRADO
Del lado de **fitz-liveviews**: ~~**FLV-01**~~ (`<html lang>` via `live_layout_with` — **v0.48.0**) +
~~**FLV-09**~~ (`docs/i18n.md`, el camino oficial — **v0.50.0**). Del lado del core: ~~**FITZ-03**~~ (`fs`),
~~**FITZ-04**~~ (locale), ~~**FITZ-05**~~ (cookies) — todos cerrados. La cadena entera del i18n está armada y
documentada. (Gap residual del core anotado: `@cookie` sobre `@ws` — workaround `@header(name="cookie")`.)

### T2 · Paridad `fitz run` ↔ `fitz build`
No es tema del framework en sí, **pero FLV-10 es su manifestación más visible**: `flv_cookie` (y por extensión
`examples/admin`, y cualquier app que dependa del framework) no compila a nativo por el bug de codegen de `T?`
del core (FITZ-09). Se cierra cuando cierre FITZ-09 + FITZ-14 (differ) en el core. Ver `fitz/docs/norte-mathelp.md`.

### T3 · Mobile como ciudadano de primera — ✅ CERRADO
~~**FLV-04**~~ (reconnect + state replay — **cerrado v0.49.0**), ~~**FLV-01**~~ (viewport/theme-color —
**cerrado v0.48.0**), ~~**FLV-05**~~ (touch targets — **cerrado v0.48.0**), **FLV-06** ya resuelto. Del
lado del core: ~~**FITZ-02**~~ (static → app instalable — **cerrado v0.51.0**). **T3 entero cerrado**: una
app Fitz en un celular se instala como PWA, tiene targets táctiles cómodos, y sobrevive un corte de señal
(reconnecta con backoff + replaya su estado). Justo donde LiveViews debía brillar.

---

## Orden de ataque sugerido (re-priorizado 2026-08-20)

**Hito 1 — Quick wins que MatHelp usa desde el día 1.** ✅ CERRADO
~~`FLV-01 (layout mínimo, S)`~~ ✅ **v0.48.0** + ~~`FLV-05 (touch targets, S)`~~ ✅ **v0.48.0** +
~~`FLV-09 (docs i18n, S)`~~ ✅ **v0.50.0** (`docs/i18n.md` con el camino oficial `@cookie`/`@header`).
**FLV-10 ya se cerró** cuando el core arregló FITZ-09 (v0.49.0) — `flv_cookie` y `examples/admin` compilan a
nativo.

**Hito 2 — Eliminar las trampas.** ✅ CERRADO (nivel `.fitzv`)
~~`FLV-02 (warning por `<style>`/`<script>`)`~~ ✅ **core v0.52.0** (error claro a nivel `.fitzv`; el
diff-engine runtime queda como follow-up) + ~~`FITZ-13 (`Map.remove`, core)`~~ ✅ **v0.50.0** →
~~`FLV-03 (eviction)`~~ ✅ **v0.49.0**.

**Hito 3 — El trabajo de verdad.** ✅ CERRADO
~~`FLV-04 (reconnect + state replay)`~~ ✅ **v0.49.0**. La pieza que separaba demo de producto. Resultó Costo
**M** (no L): el version-gap + la persistencia del store ya construían casi todo el replay; solo faltaba
reconnect + id estable, 100% client-side + un helper.

**Hito 4 — Futuro.** ✅ CERRADO
~~`FLV-07 ({#elseif}, core)`~~ ✅ **core v0.52.0** (sugar del parser, desugar a `{#if}` anidado en el else) +
~~`FLV-08 (dispatch_to_all)`~~ ✅ **v0.50.0** (broadcast cross-instance por prefijo de key del store).

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
