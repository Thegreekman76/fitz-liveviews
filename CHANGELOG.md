# Changelog

All notable changes to `fitz-liveviews` — the real-time server-rendered
UI library for Fitz. Uses [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
format. Older phase progress is tracked in [`ROADMAP.md`](ROADMAP.md);
this file summarises what shipped at each release.

## [v0.45.1] — 2026-08-17 — Clock demo: global `@every` ticker

The `examples/clock/` server-pushed clock now uses Fitz core's **`@every(N)`
decorator** (v0.42.0) instead of a per-connection `@background` ticker `spawn`ed
with the socket: a **single global** `@every(1)` fn re-renders the shared clock
and `ws_broadcast`s it to every connected tab — one ticker for all clients, no
`spawn(tick(ws))`. Requires Fitz core **≥ v0.42.1** (which installs a global WS
broadcaster so a scheduler task can `ws_broadcast`). Headless-Chrome validated:
the time advances every second across tabs.

## [v0.45.0] — 2026-08-17 — Phase 3c: version-numbered patches

Closes one of the two remaining Phase 3c items. A `LiveFrame` can carry a
**monotonic version**, so the client detects a *missed frame* and resyncs with a
full `html` replace instead of applying a patch batch onto a tree at the wrong
version. Library-only, opt-in, **byte-compatible**.

### Added

- **`LiveFrame.version: Int = 0`** — an optional sequence number. The client
  tracks `lastVersion`; if a frame's version isn't exactly `lastVersion + 1` (a
  gap), it skips the patches and takes the frame's `html`. `version: 0`
  (unstamped) is "unversioned" — the old behavior, so every current sender is
  unaffected and the wire stays compatible (frames just gain a `"version":0`).
- **`flv_versioned(endpoint, frame) -> LiveFrame`** — stamps a frame with the
  next version for `endpoint`, backed by a per-endpoint shared counter so a
  broadcast fan-out (every client reached by `ws.broadcast` / `ws_broadcast`)
  agrees on one sequence. Endpoints count independently.

  ```
  ws.broadcast(flv_versioned("/live/clock", flv_frame("Clock", "room")))?
  ```

### Notes

- **Why modest:** the existing `onmessage` try/catch already falls back to `html`
  whenever `applyPatches` *throws*, so it already resynced the corrupt/misapplied
  case. Versioning adds the *silent semantic-gap* case (patches that apply cleanly
  but target a stale tree) — worth the field + helper + client gap-check, not a
  bidirectional resync protocol. That larger protocol stays deferred.
- **Byte-compatible.** No compiler change; existing examples untouched (they send
  unstamped `version: 0` frames). 3 new lib `@test`s (117 tests pass). VSCode
  extension stays at 0.38.0.

## [v0.44.0] — 2026-08-17 — Phase 3c slice 3: `@every(N)` server-pushed updates

The third slice of **Phase 3c**. The **server** can now push updates on an
interval — a live clock, a metric tick, a countdown — with no client polling and
no client interaction. Library pattern over the existing async/spawn primitives,
**zero Fitz-core change** (verified `WsConn` is accepted as a `@background`
parameter and as a `spawn` argument).

### The pattern

A `@background async fn` loops on `sleep(N).await` + re-render + push, spawned
per connection in the `@ws` handler with the connection handle:

```
@background
async fn clock_tick(ws: WsConn<LiveFrame>) {
  loop {
    let _ = sleep(1000).await
    let t = DateTime.now().format("%H:%M:%S")
    let _ = dispatch_to("Clock", "room", "tick", {"now": t})
    ws.send(flv_frame("Clock", "room"))?      // ? ends the ticker when the tab closes
  }
}

@ws("/live/clock")
async fn clock_socket(ws: WsConn<LiveFrame>) {
  spawn(clock_tick(ws))
  loop { let r = ws.recv(); match r { Ok(f) => { dispatch_component_events(f) }, Err(_) => { break } } }
}
```

The `ws.send(...)?` is the cleanup: when the socket closes, the send errors and
`?` ends the ticker task — no orphaned loop. For **shared** state, `ws.broadcast`
instead of `ws.send` (every connection's ticker still fires, but the writes are
idempotent).

### Added

- **`flv_frame(name, id) -> LiveFrame`** — a full-re-render frame (the current
  render, `patches: []`), so the client replaces the root's `outerHTML`. Handy
  for low-frequency pushes (an `@every` tick, a lifecycle broadcast) where
  threading a `last` snapshot to diff isn't worth it. New lib `@test` (114 tests).
- **`examples/clock/`** — a server-pushed **HH:MM:SS** clock. No buttons, no
  polling: a per-connection ticker sleeps a second, renders `DateTime.now()`, and
  pushes. **Headless-Chrome validated 3/3** (first pushed time is HH:MM:SS · the
  time advances every second — 4 distinct values over 3s · zero page errors).

### Notes

- **Spike result:** `fitz check` + `fitz run` confirm the checker accepts
  `WsConn<T>` as a `@background` fn parameter and `ws` as a `spawn(tick(ws))`
  argument, and the ticks arrive over the socket — so slice 3 is pure library, no
  core change. An `@every(N)` **decorator** that generates the ticker + spawn is a
  possible future core sugar.
- **Pure library, byte-compatible.** No compiler change; existing examples
  untouched (the demo is a new example). VSCode extension stays at 0.38.0.

## [v0.43.0] — 2026-08-17 — Phase 3c slice 2: lifecycle hooks (on_mount / on_disconnect)

The second slice of **Phase 3c**. A component can now run code when a client
**connects** and when its socket **closes** — presence counters, per-connection
setup/teardown, "who's online". Library-only (a convention over the existing
dispatch/registry), **zero Fitz-core change**.

### Added

- **`flv_mount(name, id) -> Bool`** — fires the component instance's `on_mount`
  event. Call it once on `@ws` handler entry, before the recv loop and the first
  render, so seeded state shows in the client's first frame.
- **`flv_disconnect(name, id) -> Bool`** — fires the instance's `on_disconnect`
  event. Call it after the loop breaks. `ws.broadcast(...)` still delivers even
  though the sender's socket is closed, so an `on_disconnect` "farewell" frame
  (a decremented count, a "user left" note) reaches the clients still connected.
- Both are thin wrappers over `dispatch_to(name, id, "<hook>", {})` — a silent
  `false` no-op when the component declares no such handler, so the loop can call
  them unconditionally. The component opts in by declaring `event on_mount()` /
  `event on_disconnect()` in its `.fitzv` (normal events, dispatched
  programmatically rather than by a `data-flv-*` binding).
- **`examples/presence/`** — a live "N online" counter with **no buttons**: each
  connecting tab bumps a shared count via `on_mount`, each closing tab drops it
  via `on_disconnect`, broadcast to everyone still connected. **Headless-Chrome
  validated 4/4** (tab 1 → "1" · tab 2 → both "2" · close tab 1 → the remaining
  tab shows "1" · zero page errors).

### Notes

- **The loop shape matters.** `ws.recv()?` *returns from the handler* on
  disconnect, so `flv_disconnect` would never run. The canonical shape is a
  `match` on `recv()` with `Err(_) => break`, then fire the leave hook after the
  loop. Documented in the guide and the `flv_mount` doc comment.
- **Pure library, byte-compatible.** No compiler change; existing examples'
  loops are untouched (the demo lives in a new example). 3 new lib `@test`s
  (113 lib tests pass).
- **Next in Phase 3c:** `@every(N secs)` server-pushed periodic updates
  (slice 3). VSCode extension stays at 0.38.0.

## [v0.42.0] — 2026-08-16 — Phase 3c slice 1: live input events + debounce

The first slice of **Phase 3c** (real-world LiveView polish). The client runtime
gains live-input event wiring — as-you-type filters, key-driven actions, and
per-element debounce — all in the embedded client JS, **zero Fitz-core change**.

### Added

- **`data-flv-input`** — the client now listens for the `input` event, firing on
  every keystroke and packaging the field value under `payload['value']` (plus
  the enclosing form and any `data-flv-value-*`). Mirrors the existing `change`
  handler. A `.fitzv` writes `@input="on_search"`, which the SSR emitter already
  lowers to `data-flv-input="on_search"`.
- **`data-flv-keydown`** — fires on `keydown`, carrying the pressed key under
  `payload['key']` (and the pre-key value under `payload['value']`). An optional
  **`data-flv-keyfilter="Enter,Escape"`** restricts it to the listed
  `event.key`s — e.g. submit-on-Enter without a form. (Note: on keydown the field
  value is *pre-key*; use `data-flv-input` when you need the value after the
  keystroke.)
- **`data-flv-debounce="300"`** — coalesces a keystroke burst with a per-element
  timer (a `WeakMap<Element,timeoutId>` in the client runtime), so a live-search
  field sends **one** frame ~300 ms after the user stops typing rather than one
  per key. Absent or `0` sends immediately. Applies to `data-flv-input` and
  `data-flv-keydown`.
- **`examples/live-search/`** — a debounced as-you-type filter over a fruit list.
  Typing narrows the list server-side (`{#if it.contains(query)}`); the diff
  engine patches only the `<ul>`. **Headless-Chrome validated 6/6** (initial 20
  items · no send mid-burst · a 3-keystroke burst coalesces to **one**
  `on_search` · list patched to the 2 matches · value round-trips · zero page
  errors).

### Notes

- **Pure library.** No compiler change: `@input`/`@keydown` in a `.fitzv` already
  parse as generic `@event` bindings and lower to `data-flv-<event>` in the SSR
  emitter (verified against Fitz core; works as far back as the 0.29.x line).
  Compatible with the same core the library already required.
- **Byte-compatible.** Only the injected `<script>` runtime grows; the LiveView
  root HTML and every WS `html`/`patches` frame are unchanged, so existing
  examples' `fitz run` ↔ binary smokes stay identical. 5 new lib `@test`s assert
  the handlers/attributes are present (110 lib tests pass).
- **Next in Phase 3c:** `@on_mount`/`@on_disconnect` lifecycle (slice 2) and
  `@every(N secs)` server-pushed updates (slice 3). The VSCode extension stays at
  0.38.0 — no new `.fitzv` grammar/LSP surface.

## [v0.41.4] — 2026-08-16 — Phase 11: hydration of composition + a `{#for}` region

Aligns with Fitz core **v0.41.4** and adds the next hydration slice: a `{#for}`
region next to a composed companion, inside a hydrating tree. Needed a core fix
— a naive (composition) component with an explicit `hydrate` marker can now adopt
a static `{#if}`/`{#for}` region — which landed in core v0.41.4 (before it, this
shape aborted with a "naive-region adopt not supported" error).

### Added

- **`examples/hydration-composition-regions/`** — a `component App hydrate` tree
  that composes the real `src/ui/Badge` **and** renders a `{#for}` list beside
  it. On boot the wasm bundle **adopts both** — the composed Badge across the
  parent/child boundary, and the region's list items server-painted between
  `<!--fr-->`/`<!--/fr-->` anchors — instead of recreating them. **Headless-Chrome
  validated 7/7** (boot · Badge state restored from the `<script>` — `idle`, not
  the default `active` · composed Badge adopted · `{#for}` region adopted from
  the server — `clone`/`test`, not the defaults · toggle re-render · region
  survives re-render · no page errors) + no horizontal overflow at 320px.

  Unblocks tabs/steppers/accordions composed **without** a live `@input` (which
  had no clean workaround — keep-node region adopt requires `@input`). Still out
  of scope: a `<Child/>` **dynamically inside** a `{#for}` (keyed reconciliation
  of composed children) — a larger slice that clashes with the naive
  wipe-and-rebuild model. The naive-composition caveat stands (hydration wins the
  first paint; the first state change re-renders the tree wholesale).

## [v0.41.3] — 2026-08-16 — Phase 11: hydration of composition with the REAL Badge

Aligns with Fitz core **v0.41.3** and adds the next hydration slice: composing
the actual `src/ui/Badge` companion inside a hydrating tree. This needed a core
fix — SSR-composing a cross-file `<Child />` through the classic loader — which
landed in core v0.41.3 (before it, only the wasm target could resolve an
imported companion; `App_render` couldn't).

### Added

- **`examples/hydration-composition/`** — SSR → client hydration of a `component
  App hydrate` tree that composes the **real `src/ui/Badge.fitzv`** via a
  cross-file `<Child />` import (CW.8) with interpolated props
  (`label="{label}"`). The **same** `App.fitzv` compiles two ways: `fitz run
  --bin prerender` server-renders the card (the Badge included, with its
  `<style scoped>` + `{flv(...)}`) and `fitz build --bin app` builds the wasm
  bundle that **adopts** that server-painted DOM **across the parent/child
  boundary**. **Headless-Chrome validated 7/7** (boot · state restored from the
  `<script>` payload — `paused`, not the default `active` · cross-boundary
  adoption witness survives · child scoped `<style>` preserved · toggle
  re-render ×2 · no page errors) + no horizontal overflow at 320px.

  Two findings worth recording: the composed child's **leading `<style scoped>`
  does not break the adopt walk** (an earlier worry — it hydrates fine), and
  **interpolated child props work in the composition-hydration path**. The
  naive-composition caveat stands (first state change re-renders the tree
  wholesale — the interaction is a `@click` toggle, not a live `@input`, which
  belongs in the keep-node `examples/hydration/`). `{#if}`/`{#for}` regions
  inside a hydrating composition tree are the next slice.

## [v0.41.2] — 2026-08-16 — Phase 11 first adoption: SSR → client hydration demo

Realigns the lib version with Fitz core (**v0.41.2**), jumping from v0.38.0. The
intervening core releases (v0.39 `fitz check` for `.fitzv`, v0.40 checker
refinements, v0.41 `jwt.decode`/`jwt.encode` heterogéneo + LSP dedup) are
**transparent to the lib** — no API/authoring change was required; the companion
UI `@test` suite passes **227/227** against v0.41.2. The headline of this release
is the first framework-side adoption of **Phase 11 (SSR → client hydration)**,
landed on the core in v0.31.0 and documented in the lib but not yet exercised by
any `.fitzv`.

### Added

- **`examples/hydration/`** — the isomorphic hydration bridge, end-to-end. One
  `App.fitzv` (`component App hydrate { ... }`) compiles **two ways** from **one**
  source: `fitz run --bin prerender` prints the server HTML that seeds
  `index.html`'s `#app`, and `fitz build --bin app` builds the wasm-client bundle
  that **adopts** that server-painted DOM on boot (`hydrate()`, not `mount()`) —
  no blank-mount flash, node-for-node adoption, then keep-node patches keep it
  alive. A companion-flavoured card: a live `<input>`, a `--flv-*`-styled pill
  echoing it (caret preserved on edit), and a `toggle colour` button that patches
  the pill's `data-variant` on the adopted node. **Headless-Chrome validated 9/9**
  (boot · state restored from the `<script>` payload, not the default · adoption
  witness survives · live patch · caret preserved on mid-string edit · variant
  attr patch · label preserved · no page errors) + no horizontal overflow at
  320px. Establishes the authoring pattern for hydrating components: no
  `<style scoped>` on the hydrating root (styling goes in the host `<head>`);
  event bodies in the SSR∩WASM envelope (plain `if`/`else`, not `match`);
  sole-child text interpolations. Cross-file `<Badge>` composition + `{#if}`/
  `{#for}` regions in the hydration path are the next slices.

## [v0.38.0] — 2026-08-14 — deshelperize atributos booleanos condicionales (gotcha #6) + examples

**Minor bump** (tracks Fitz core **v0.38.0**, la versión que introdujo el
bool-attr condicional). Aprovecha el cierre del **gotcha #6** (`attr={boolExpr}`,
llave SIN comillas → atributo presente sii truthy) para colapsar los
`{#if}<X attr/>{#else}<X/>{/if}` de la companion UI a un único `<X attr={cond}/>`.
Toca componentes públicos de `src/ui/*` (su HTML renderizado cambia
cosméticamente: el atributo booleano se emite **bare** — `disabled`, no
`disabled=""` — y un slot false deja un espacio; el DOM es idéntico). La API
pública (firmas + props) no cambia. **Requiere Fitz core v0.38.0+** para compilar
(la sintaxis `attr={expr}`). La extensión VSCode sube a 0.38.0 en paralelo
(highlight de `attr={expr}` bare + `.vsix` rebuildeado).

### Changed

- **Companion UI: atributos booleanos condicionales** (gotcha #6, requiere Fitz
  core **v0.38.0**). 15 colapsos limpios en `src/ui/*`: `Checkbox`/`CheckboxGroup`/
  `RadioGroup`/`MultiSelect` (`checked={o.on}`), `Select`/`GroupSelect`
  (`selected={o.on}`, opciones), `DatePicker`/`Button` (`disabled={disabled}`),
  `ExpansionPanel` (`open={open}`). **`Textarea` + `Input`** colapsan sus nested
  `{#if disabled}{#else}{#if required}…` a `disabled={disabled}
  required={required}` — esto **arregla un bug latente**: la rama `disabled` hoy
  OMITE `required`, así que un control `disabled + required` perdía el `required`;
  el colapso emite ambos (HTML válido). `Admin ABM/EmpleadoRow.fitzv`: el checkbox
  de selección pasa a `checked={checked}`. Los `{#if}/{#else}` restantes (chevron,
  badges, Pager, Button-loading, Select-disabled externo) cambian texto/markup o
  togglean pares handler+attr, no un atributo booleano suelto → sin tocar. Suite
  `@test` de la gallery: 227/227 verde (7 asserts actualizados al render bare del
  bool-attr). Validado: `fitz check` de los 11 componentes + Admin ABM real
  (login + grid `/empleados` renderizando `EmpleadoRow` con `checked={checked}`).
  +29/−75 LoC. **Cierra el catálogo de gotchas del `.fitzv`** que forzaban
  helpers/variantes (junto con #1 en v0.37.17).

### Added

- **Client-side theme toggle en la live gallery** (`examples/wasm-gallery/
  index.html`, CW.6). Un `<button id="flv-theme-btn">` + JS inline (un
  componente client-WASM `.fitzv` no alcanza `<html>`/`localStorage` — solo su
  subtree montado), mirror de `theme_scripts.fitz` (`flvCycleTheme`/boot): cicla
  light → dark → auto sobre `localStorage` + `data-theme` en `<html>`. Los dark
  tokens ganan un selector `:root[data-theme="dark"]` (mirror del SSR
  `theme.fitz`), con `prefers-color-scheme` gateado a auto/unset para que la
  elección explícita gane. Oculto en iframe (`window.self !== window.top`) para
  no chocar con el toggle de Material en `live-gallery.md`. Validado 14/14
  headless-Chrome (ciclo + tokens CSS + persistencia).

### Changed

- **Admin ABM: pantalla Departamentos a LiveComponents** (rebanada 5, paridad
  con Empleados). `DepartamentoRow.fitzv` + `DepartamentoForm.fitzv` +
  `dep_helpers.fitz` reemplazan los helpers inline `dep_row`/`form_html` de
  `departamentos.fitz`, con la misma arquitectura `.fitzv` presentacional/
  controlado que Empleados (fila + form, `data-flv-key` para diffing keyed).
  **Requiere fitz core v0.37.14** (cierra el bug de codegen de state compartido
  de módulo con `let PAGE_SIZE` primitivo usado por handlers `@ws`). `fitz build`
  del admin verde, paridad ante `fitz run`.

- **Admin ABM: deshelperize i18n-en-atributo** (aprovecha el cierre del gotcha
  #1 en fitz core **v0.37.17** — comillas dobles anidadas en valores de
  atributo). Los `.fitzv` interpolan `t(locale, "…")` directo dentro de
  `placeholder`/`data-tooltip` en vez de pasar por helpers que movían la comilla
  a un `.fitz`. Borrados los wrappers `dep_ph_nombre`/`dep_ph_codigo`/
  `dep_tip_empleados` (`dep_helpers.fitz`), `row_tip_detail`/`row_tip_edit`/
  `row_tip_delete` (`row_helpers.fitz`) y `ph_notas` (`form_helpers.fitz`, ya era
  dead code); `dep_helpers.fitz` conserva solo `dep_codigo_chip` y
  `row_helpers.fitz` solo `row_class` (necesita `match`). Paridad **byte-a-byte**
  validada (`/departamentos` + `/empleados` + el form de departamentos por WS,
  helpers vs inline, idénticos módulo el uuid per-connection). +23/−40 LoC.

### Docs

- Higiene de trackers: ROADMAP tilda 8.1/8.2/8.3/8.6 (trabajo ya shipeado),
  unifica el conteo de widgets client-WASM a **13** (era 8/12 disperso),
  `client-wasm.md` idem; `REFACTOR-NOTES.md` refrescado (refactor cerrado,
  `git status` stale removido, deuda WASM "mixed attr interp" marcada CERRADA en
  CW.9, versiones del core normalizadas).

## [v0.37.0] — 2026-08-06 — CW.9 follow-ups: 38/38 companion components dual-target (Pager + ConfirmDialog unblocked)

**Minor bump** (tracks Fitz core **v0.37.0**). The three residual CW.9 debts
in the wasm emitter are closed in Fitz core (all confined to `src/view/`,
byte-compat, no new `.fitzv` syntax): interpolated props into a `Nullable<T>`
target now wrap `Some(...)`; `List<nominal>` state defaults fill omitted fields
from the nominal's declared defaults; and `data-flv-click` fall-through events
bubble to a composing parent's callback slot (with a view-checker relaxation
that accepts `<Child @X />` when the child EMITS `X` via `data-flv-*`, not only
when it declares `event X`). This **unblocks the two *controlled* components
(`Pager`, `ConfirmDialog`)** whose buttons fire fall-through events — the
companion UI now reaches **38 of 38 dual-target**.

### Changed

- **`src/ui/_wasm_showcase.fitzv`** — adds `Pager` (numbered buttons via
  `page_range`, page 2 of 5) and `ConfirmDialog` (mounted closed) to the live
  composed showcase, taking it to **22 components**. Both compile + render to
  real WASM from their exact server source; mounted standalone (no `@ws` host
  loop) their fall-through clicks are inert — they're presentational in the
  gallery, fully controlled when composed under a server-driven parent.

### Verified

- Fitz core `cargo test --lib` **4020** (default) / **4181** (`--features lsp`);
  `fitz test` of `examples/ui-gallery` **227/227** SSR green (the checker
  relaxation only *relaxes* — nothing that passed before now fails). The
  showcase (`examples/wasm-gallery`, bin `showcase`) compiles to real WASM via
  `fitz build --target wasm-client` (`wasm-pack` → `:-) Done`).

## [v0.36.0] — 2026-08-06 — CW.9 iter2: live showcase grows to 20 dual-target components (+ sweep: 36/38 dual-target)

**Minor bump** (tracks Fitz core **v0.36.0**). A sweep of the remaining
companion components found **16 of 18** already compile to client-WASM;
three small core fixes (helper-body list `for`/`.push`, interpolated
non-primitive props, `List<nominal>` state defaults) close the gaps to
**populate** the list-driven components. The live composed showcase
(`src/ui/_wasm_showcase.fitzv`, bin `showcase`) now runs **20 dual-target
components** with real data, all from their exact server source.

### Changed

- **`_wasm_showcase.fitzv`** — adds `Select`, `RadioGroup`, and `BarChart`
  **with real data**: the showcase holds `List<FieldOption>` + `List<Bar>`
  state defaults and passes them as interpolated props
  (`<Select options="{opts}" />`, `<BarChart bars="{bars}" />`). Together
  with the `Button` + `GridToolbar` added in v0.35.x, the showcase is now 20
  components (was 15).

### Notes

- **36 of 38 companion components dual-target** to wasm. The two exceptions,
  **Pager** and **ConfirmDialog**, are *controlled* components: their
  buttons fire fall-through events to the parent's `@ws` loop
  (`data-flv-click="page_prev"` / `confirm_delete`, not local component
  events), which have no standalone-wasm equivalent without event-bubbling
  wiring. They stay SSR-appropriate.
- Follow-ups (fitz core): interpolated props into a `Nullable<T>` target
  (`Some(...)` wrap); filling omitted fields in a `List<nominal>` default
  from the nominal's declared defaults.

## [v0.35.0] — 2026-08-06 — CW.9: five markup/list companion components dual-target (SSR + client-WASM)

**Minor bump** (tracks Fitz core **v0.35.0**). Five companion UI components
that were SSR-only now compile to **client-WASM from their exact server
source**, with their SSR output byte-identical (all 227 ui-gallery tests
green). This lands on top of the CW.9 wasm-envelope work in the core
(`src/view/`): the raw-HTML sink + `Html` shim, a bool field access in a
`{#if}` condition, `for x in <list>` in helper bodies, and a fn-alias fix
in the wasm loader.

### Changed

- **`Button.fitzv`** — the icon interpolation is now
  `{raw_html(render_icon(icon).raw)}` (the explicit raw-HTML marker). Renders
  the SVG unescaped on both targets: verbatim on SSR (the marker strips to
  `{...}`) and via `set_inner_html` on wasm. `render_icon` returns `Html`,
  which the core's wasm emitter models with its `__FlvHtml` shim.
- **`GridToolbar.fitzv`** — the `{actions}` slot is now `{raw_html(actions)}`
  so the host-provided action markup renders raw on the wasm target too
  (byte-identical on SSR).
- **`Select.fitzv` / `RadioGroup.fitzv`** — now dual-target **unchanged**:
  the core learned to lower `{#if o.on}` (a `Bool` field on a `{#for}` loop
  var of `List<FieldOption>`).
- **`BarChart.fitzv`** — now dual-targets **unchanged**: the core learned to
  lower `for b in bars` (a list `for`) in the `bar_scale` helper body.

### Docs

- README badge/status refreshed to v0.35.0 (Companion UI + client-WASM +
  hydration). Phase 0 marked done, **Phase 11 — SSR-isomorphic hydration**
  formalized, and the CW.9 block updated to reflect the five dual-target
  components. `showcase-admin-abm-plan.md` stale "not built" list corrected.

## [v0.31.0] — 2026-08-03 — VSCode grammar for `.fitzv` + `hydrate` marker highlighting

**Minor bump** — the VSCode extension gains a TextMate grammar for `.fitzv`
single-file components, including highlighting for the `hydrate` marker (the
Fitz core v0.31.0 SSR-isomorphic hydration opt-in). No change to the
`fitz_liveviews` library API — this is editor tooling.

> **Version note**: v0.26.0 → v0.30.0 were never released. The `fitz.toml`
> version jumped straight from v0.25.0 to v0.31.0 to track the Fitz core
> version. The work in between landed as examples/docs commits without a
> library API bump: CW.6 dual-target research, CW.7 client-WASM showcase
> (grown to 15 components), CW.8 cross-dir/dep wasm imports, the 7-part blog
> series (EN + ES), the whole-framework `docs/architecture.md`, and the
> `@rpc` server-functions coverage.

### Added

- **`.fitzv` grammar** in the VSCode extension — syntax highlighting for the
  single-file component blocks (`component` / `state` / `event` /
  `<template>` / `<style scoped>`), including the `hydrate` marker.

## [v0.25.0] — 2026-07-30 — Client-WASM live gallery

**Minor bump** — ships a **live, interactive component gallery** hosted on GitHub
Pages: eight `.fitzv` components compiled to **WebAssembly**, running in the
visitor's browser (no server, no WebSocket), composed into one ~34 KB (gzipped)
bundle. This is the visibility engine — real widgets you can touch, no install.
It's a *parallel* client-side set (not a recompile of the SSR companion UI) that
reuses the same `--flv-*` tokens so it looks identical. Built against Fitz core
**v0.29.1**. No change to the `fitz_liveviews` library API — this is examples,
docs, and CI.

CI note: the gallery's gate is the Pages build (`docs.yml` runs
`fitz build --bin gallery --target wasm-client` on every push touching it).
`fitz check --target wasm-client` doesn't exist in the current core, and plain
`fitz check` lexes a `.fitzv` as classic Fitz, so `ci.yml` is left unchanged.

### Added — client-WASM live gallery (CW.1)

- **`examples/wasm-gallery/`** — the first live, client-side component compiled to
  **WebAssembly** and run in the browser (no server, no WebSocket). A standalone
  `Counter.fitzv` styled with the companion UI's `--flv-*` tokens, driven by the
  real `fitz build --target wasm-client` CLI (`[[bin]] target = "wasm-client",
  mount = "#app"` — the first example in the ecosystem to use the manifest-driven
  wasm flow). Ships `index.html`, `build.sh`, and a README. Bundle: 29 KB raw /
  12.4 KB gzipped, well under the core's 40 KB gate.
- **`docs.yml` extended** — the Pages workflow now builds the wasm gallery in CI
  and publishes it into the single Pages artifact under `/live/`
  (<https://thegreekman76.github.io/fitz-liveviews/live/>). GitHub Pages allows one
  deployment per repo, so mkdocs (`site/`) + the gallery (`site/live/`) deploy
  together.
- **`docs/live-gallery.md`** + a **"Live gallery"** nav item — the gallery is
  embedded via an `<iframe>` on a real docs page rather than linked directly. A
  direct same-origin nav link was intercepted by Material's `navigation.instant`
  SPA loader and mashed into the docs shell (visible only until a hard refresh);
  the iframe isolates the self-contained wasm page cleanly.

> Client-WASM is a **parallel component set**, not a recompile of the SSR
> companion UI (the core's wasm loader is sibling-file-only, has no `dep_registry`,
> and uses a DOM-ops render model). See [`docs/client-wasm-plan.md`](docs/client-wasm-plan.md).
> The formal version bump ships with CW.5.

### Added — the client component set (CW.2)

Eight standalone client components, each a `[[bin]]` in
`examples/wasm-gallery/fitz.toml`; all compile to wasm. The composed live gallery
page lands in CW.3.

- **`Counter.fitzv`** — `Int` state, arithmetic events (from CW.1).
- **`Toggle.fitzv`** — a Bool switch. The `.fitzv` view lexer rejects `!` in event
  bodies (only `!=`), so the flip is `on = on == false`.
- **`Tabs.fitzv`** — client-side panel switching (`{#if active == N}` comparison
  conditions + `{#if}{#else}` to highlight the active tab). The headline of the
  client-WASM story: zero round-trips, instant panel swap.
- **`Stepper.fitzv`** — a bounded `[0, 10]` input using an `if`-as-value on the RHS
  of the event-body assignment.
- **`Rating.fitzv`** — a 0–5 star picker (`{#if stars >= N}` fill).
- **`Accordion.fitzv`** — a 3-section expander, one open at a time (`Int` state,
  `if`-as-value to close). The wasm emitter defers unary negation `-1`, so the
  "closed" sentinel is a non-negative `9`.
- **`Modal.fitzv`** — an open/close dialog (`{#if open}` mounts/unmounts the overlay).
- **`TodoList.fitzv`** — add/remove a `List<Str>` (`{#for}`, `items.push(...)` from a
  `data-flv-submit` form payload, `items.filter(...)` to remove via a
  `data-flv-value-*` click payload). The `!=` remove predicate lives in the sibling
  `todo_helpers.fitz` (the view lexer rejects inline `!=` in event bodies).

### Added — the composed live gallery (CW.3)

- **`Gallery.fitzv`** — a single root component that composes all eight widgets via
  cross-file `<Child/>` composition (core v0.25.0+). Each child keeps its own state
  (persistent per-instance), so every widget in the responsive grid is independently
  interactive — from **one** wasm bundle, ~34 KB gzipped, mounted into `#app`.
- The live `/live/` page (and the `/live-gallery/` iframe that embeds it) now shows
  the whole set. `docs.yml`, `index.html`, and `build.sh` build/mount the `gallery`
  bin; the iframe height grew to fit the grid.

### Added — docs (CW.4)

- **`docs/client-wasm.md`** — the client-WASM guide: the SSR-vs-client decision
  matrix, why client components are a parallel set (not a recompile of the SSR kit),
  the capability envelope with the real view-lexer/emitter gotchas (`!` → `== false`,
  inline `==`/`!=` → sibling helper, `-1` → sentinel, state-variant classes), and
  how to build/deploy. Added to the Guide nav.
- **"▶ see it live" pointers** — `docs/ui-components.md` now flags client-WASM as a
  third rendering mode and links the guide + live gallery; `live-gallery.md`
  cross-links the guide.

### Fixed

- **Toggle switch was visually stuck** — only the label flipped (Apagado/Encendido);
  the knob never moved. The on-state now renders `switch-on` / `knob-on` modifier
  classes (block-level `{#if}{#else}`, same pattern as Tabs' active tab), so the
  switch fills and the knob slides.
- **CI: `docs.yml` wasm build failed once the manifest declared more than one
  `[[bin]]`** — `fitz build --target wasm-client` is ambiguous with several bins.
  The step now passes `--bin gallery` (the composed gallery root).
- The `wasm-gallery` host page painted only the centered 680px column, exposing the
  browser's default (near-black) canvas on the sides in dark mode. Backgrounding
  `<html>` + `color-scheme: light dark` now paints the full viewport in both schemes.

## [v0.24.0] — 2026-07-30 — `Chip` + `CountBadge` + `Tooltip` + `Divider` + `ExpansionPanel` (Feedback family)

**Minor bump** — ships the **Feedback family**, extracted from the Admin ABM into
the package: the small presentational primitives. **This closes the companion UI
library's component extraction** — every reusable piece of the Admin ABM is now
packaged. Built against Fitz core **v0.29.1**.

### Added — the 5 primitives

- **`fitz_liveviews.ui.Chip`** — `chip { label, variant }`. A soft-tinted tag pill
  (a permission, a skill, a category). Variants: primary / success / danger /
  warning / info / muted. (Badge is the solid status pill; Chip is the soft tint.)
- **`fitz_liveviews.ui.CountBadge`** — `count_badge { count, max, variant }`. A
  small solid count pill (a group tally, an unread counter). With `max` set, counts
  over it render as "max+" (e.g. 99+).
- **`fitz_liveviews.ui.Tooltip`** — `tooltip { content, tip }`. A CSS-only hover
  bubble (zero JS) wrapping raw `content`; an empty `tip` renders nothing. The
  standalone, scoped version of the global `[data-tooltip]` the AppShell chrome
  provides.
- **`fitz_liveviews.ui.Divider`** — `divider { label }`. An `<hr>`, or (with a
  `label`) a centered caption between two lines.
- **`fitz_liveviews.ui.ExpansionPanel`** — `expansion_panel { summary, body, open }`.
  A collapsible section on the native `<details>`/`<summary>` — zero JS, great on
  static SSR pages that don't re-render live.
- All are `.fitzv` SFCs with `<style scoped>` over `--flv-*` tokens, presentational
  (no state, no events), and render identically under `fitz run` and the
  `fitz build` binary.

### Changed — Admin ABM adoption

- The expand-row detail chips + the departamentos código use the packaged **Chip**;
  the grouped-grid member tally uses **CountBadge**; the dashboard's separator +
  collapsible chart section use **Divider** + **ExpansionPanel**. The local `chip`
  helper is gone (renamed `chip_tag` → the Chip component). The `.chip` /
  `.grp-count` / `.divider` / `.exp-panel` styles moved out of `admin_css()` (the
  `.detail-v.chips` flex container stays). The Admin ABM's icon-button tooltips keep
  using AppShell's global `[data-tooltip]`.

### Verified

- `fitz test` (ui-gallery) — **227 unit tests pass** (9 new for the Feedback
  family). `fitz check` + `fitz build` on the Admin ABM (native binary). Rendered
  against a local PostgreSQL (dashboard Divider/ExpansionPanel, departamentos Chip,
  grouped-grid CountBadge); the WS smoke passes and `fitz run` ↔ native binary are
  **bit-a-bit identical** (modulo per-connection uuids + multi-line-literal
  whitespace).

## [v0.23.0] — 2026-07-30 — `FormLayout` + `FormRow` + `GroupSelect` + `MultiSelect` + `Tabs` + `Stepper` + `TreeView` (Forms family — composite)

**Minor bump** — ships the **Forms family (composite)**, extracted from the Admin
ABM into the package: the layout primitives + the richer, stateful/interaction
controls. This closes the Forms extraction (inputs shipped in v0.22.0). Built
against Fitz core **v0.29.1**.

### Added — the 7 composite components

- **`fitz_liveviews.ui.FormLayout`** — `form_layout { submit_event, body, card }`.
  The `<form data-flv-submit>` shell (a vertical stack, optionally inside a card).
- **`fitz_liveviews.ui.FormRow`** — `form_row { label, field, cols }`. A labeled
  row, or (when `cols > 1`) a responsive grid that collapses to one column on
  narrow screens.
- **`fitz_liveviews.ui.GroupSelect`** — `group_select { name, label, groups:
  List<OptionGroup>, head_label, … }`. A `<select>` whose options are bucketed into
  `<optgroup>`s (a "reports to" grouped by department).
- **`fitz_liveviews.ui.MultiSelect`** — `multi_select { name, label, groups:
  List<OptionGroup> }`. A grouped multi-select: checkboxes in titled `<fieldset>`s
  sharing one `name` (a module × permission matrix). For a flat multi-select, use
  CheckboxGroup.
- **`fitz_liveviews.ui.Tabs`** — `tabs { items: List<Tab>, tab_event }`. A
  server-tracked tab nav (`data-flv-form` so switching a tab serializes typed
  values). Renders only the nav — the panels stay in the host DOM.
- **`fitz_liveviews.ui.Stepper`** — `stepper { steps: List<Step> }`. A numbered
  wizard indicator (states done / active / pending). Numbers come from a pure-CSS
  counter, the connector lines from a `::after` pseudo-element (no filler markup).
- **`fitz_liveviews.ui.TreeView`** — `tree_view { nodes: List<TreeNode> }`. An
  expandable hierarchy. The SSR template can't recurse, so the host flattens its
  hierarchy into the currently-visible `List<TreeNode>` (each with a `depth` indent
  + `expanded` arrow); a branch toggle fires `event` with `value`.
- **`fitz_liveviews.ui.form_layout_helpers`** — `type OptionGroup { label, options:
  List<FieldOption> }` (GroupSelect / MultiSelect), `type Tab { label, value,
  active }`, `type Step { label, state }`, `type TreeNode { label, depth, leaf,
  expanded, event, value, icon }`, and `tree_arrow(expanded)`.
- All are `.fitzv` SFCs with `<style scoped>` over `--flv-*` tokens, controlled
  (the host owns the active tab/step + the tree's expanded set), and i18n-agnostic.
  They render identically under `fitz run` and the `fitz build` binary.

### Changed — Admin ABM adoption

- `form_helpers.fitz` / `EmpleadoForm.fitzv` render the packaged composite
  controls: the "reporta a" GroupSelect, the permisos MultiSelect, the país /
  provincia / ciudad **Select in cascade mode** (`on_change`), and the form's Tabs
  (edit) / Stepper (create wizard). `empleados.fitz` renders the ubicaciones
  **TreeView** (flattening its país→provincia→ciudad hierarchy into a
  `List<TreeNode>`). The local `reporta_options` / `permisos_html` /
  `pais_options` / `tab_btn` / `step_dot` / `stepper_bar` / `tree_html` helpers are
  gone.
- The tab / stepper / permission-matrix / tree-list / inline-select styles moved
  out of `admin_css()` into the components' scoped blocks. The tab PANELS
  (`.tab-panel`), the tree SCREEN wrapper (`.tree-card` / `.tree-foot`), the shared
  `.tree-arrow` (grouped grid rows), and the form row/grid layout stay.
- The tree toggle handlers (`toggle_pais` / `toggle_prov`) now read
  `payload["value"]` (the generic TreeView emits `data-flv-value-value`).

### Verified

- `fitz test` (ui-gallery) — **218 unit tests pass** (11 new for the composite
  family). `fitz check` + `fitz build` on the Admin ABM (native binary,
  cross-module `List<OptionGroup>` / `List<Tab>` / `List<Step>` / `List<TreeNode>`;
  GroupSelect / MultiSelect import `FieldOption` so the nested `OptionGroup.options`
  resolves). Rendered against a local PostgreSQL; the WS smoke exercises the form
  create/edit flow + the tree, and `fitz run` ↔ native binary are **bit-a-bit
  identical** (modulo per-connection uuids + multi-line-literal whitespace).

## [v0.22.0] — 2026-07-30 — `Textarea` + `Select` + `Checkbox` + `CheckboxGroup` + `RadioGroup` + `Rating` + `DatePicker` (Forms family — inputs)

**Minor bump** — ships the **Forms family (inputs)**, extracted from the Admin ABM
into the package: the leaf form inputs. Text stays `Input` (already packaged); this
release adds the multi-line, choice, and date inputs. Built against Fitz core
**v0.29.1**.

### Added — the 7 form-input components

- **`fitz_liveviews.ui.Textarea`** — `textarea { name, label, value, placeholder,
  rows, hint, error, disabled, required }`. The multi-line sibling of Input, same
  `.flv-field` label + hint/error shell.
- **`fitz_liveviews.ui.Select`** — `select { name, label, options: List<FieldOption>,
  hint, error, disabled, on_change }`. A labeled `<select>`; `on_change` fires a
  `data-flv-change` fall-through event (country → province cascade). `<optgroup>`
  (GroupSelect) is a later component.
- **`fitz_liveviews.ui.Checkbox`** — `checkbox { name, label, value, on }`. A single
  labeled box.
- **`fitz_liveviews.ui.CheckboxGroup`** — `checkbox_group { name, label, options:
  List<FieldOption>, chips }`. Boxes sharing one `name` (a multi-select). `chips:
  true` renders a wrap-around pill list that fills each pill while checked (pure CSS
  `:has(input:checked)`, no server round-trip).
- **`fitz_liveviews.ui.RadioGroup`** — `radio_group { name, label, options:
  List<FieldOption> }`. Mutually-exclusive radios sharing one `name`.
- **`fitz_liveviews.ui.Rating`** — `rating { name, value, max }`. A 0..max star
  input via radios + the `row-reverse` / `input:checked ~ label` CSS trick (zero JS).
- **`fitz_liveviews.ui.DatePicker`** — `date_picker { name, label, value, hint,
  error, disabled }`. A labeled native `<input type="date">`.
- **`fitz_liveviews.ui.form_input_helpers`** — `type FieldOption { label, value, on }`
  (shared by Select / RadioGroup / CheckboxGroup) + `rating_stars(name, selected,
  max)` (the reversed star radios; the Rating template interpolates it inside its
  scoped `.flv-rating` wrapper — the scoped element selectors reach the helper's
  radios/labels).
- All are `.fitzv` SFCs with `<style scoped>` over `--flv-*` tokens (literal
  fallbacks), controlled (no event handlers — they render into your form and you
  read the values back by `name`), and i18n-agnostic. They render identically under
  `fitz run` and the `fitz build` binary.

### Changed — Admin ABM adoption

- `EmpleadoForm.fitzv` / `form_helpers.fitz` now render the packaged inputs: the
  notas Textarea, the departamento Select, the estado RadioGroup, the desempeño
  Rating, the skills CheckboxGroup (chips), and the fecha DatePicker. The local
  `depto_options` / `skills_html` / `rating_input` helpers are gone; `field_*`
  wrappers build the `List<FieldOption>` and render the components.
- The radio / rating / skill-chip / inline-textarea styles moved out of
  `admin_css()` into the components' scoped blocks. The form layout
  (`.form-row` / `.form-grid-*` / `.abm-form`), the grouped-permission matrix
  (`.perm-*`), the Tabs/Stepper (`.tab-*` / `.step*`), the CascadeSelect / GroupSelect
  (inline `<select>`s), and the read-only star display (`.stars-ro`) stay — they're
  app-specific or a later Forms session.

### Verified

- `fitz test` (ui-gallery) — **207 unit tests pass** (15 new for the Forms family).
- `fitz check` + `fitz build` on the Admin ABM (native binary, cross-module
  `List<FieldOption>`). Rendered against a local PostgreSQL; the WS smoke exercises
  the create/edit form flow and `fitz run` ↔ native binary are **bit-a-bit
  identical** in form content (modulo per-connection uuids + multi-line-literal
  whitespace).

## [v0.21.0] — 2026-07-30 — `DataGrid` + `SortableHeader` + `GridToolbar` + `GridFilters` (DataGrid family)

**Minor bump** — ships the **DataGrid family**, extracted from the Admin ABM into
the package: the live table shell, the sortable column header, the search toolbar
and the filter pill bar. The whole grid CSS (table shell, mobile-card transform,
sortable headers, toolbar, pills) moved out of the app's `admin_css()` and into
the components' `<style scoped>` blocks. Built against Fitz core **v0.29.1**.

### Added — `DataGrid` / `SortableHeader` / `GridToolbar` / `GridFilters`

- **`fitz_liveviews.ui.DataGrid`** — `data_grid { head, body, foot, info, empty,
  cols }`. The card + horizontal-scroll + `<table>` shell, plus the **grid → cards
  mobile transform** (`@media (max-width: 640px)`: each row's `<td data-label>`
  becomes a stacked card). `head`/`body`/`foot` are raw markup you build; `info` +
  `foot` form the footer; an empty `body` renders a centered empty row spanning
  `cols`. The scoped CSS reaches the host-provided rows via descendant *element*
  selectors inside the scoped `table.flv-grid` — that's how the mobile cards style
  rows the component never renders itself.
- **`fitz_liveviews.ui.SortableHeader`** — `sortable_header { label, col,
  active_col, dir, cls, sort_event }`. A clickable `<th>` that fires `sort` (or a
  custom `sort_event`) carrying the column key in `data-flv-value-col`; the active
  column shows an ▲/▼ arrow (via the `sort_arrow` helper). Mix with plain `<th>`s
  to build the grid's `head`.
- **`fitz_liveviews.ui.GridToolbar`** — `grid_toolbar { q, placeholder,
  search_label, clear_label, search_event, actions }`. A search `<form>` firing
  `search` (the input's `q` rides in the payload) + an optional clear button + a
  raw right-side `actions` slot for domain buttons.
- **`fitz_liveviews.ui.GridFilters`** — `grid_filters { pills: List<Pill>,
  filter_label }`. A data-driven filter pill bar. One instance renders any
  dimension: a distinct event per pill (estado / group-by) or one shared event +
  a `value` payload the loop reads as `payload["value"]` (a department id).
- **`fitz_liveviews.ui.grid_helpers`** — the data helpers: `type Pill { label,
  event, value, active }` and `sort_arrow(col, active_col, dir) -> Str`.
- All four are `.fitzv` SFCs with `<style scoped>` over `--flv-*` tokens (literal
  fallbacks), controlled (no event handlers — events fall through to the host
  loop), and i18n-agnostic (the host passes already-localized labels). They render
  identically under `fitz run` and the `fitz build` binary.

### Changed — Admin ABM adoption

- `empleados.fitz` and `departamentos.fitz` now render the packaged DataGrid
  family: `data_grid_render` / `sortable_header_render` / `grid_toolbar_render` /
  `grid_filters_render`. The estado / departamento / group-by filters are three
  `GridFilters` instances; the sortable headers are `SortableHeader`; the table
  shell + empty state + footer are `DataGrid`. The app-specific `EmpleadoRow`
  stays (it's the domain row).
- The app-local `GridToolbar.fitzv` / `GridFilters.fitzv` (Empleados-specific,
  with baked-in estado pills + i18n) were **deleted** — the packaged, generalized
  versions replace them. The local `sort_th` helpers are gone too.
- `admin_css()` shrank: the grid table shell (`.grid-scroll` / `table.grid` /
  `.grid-empty` / `.grid-foot` / `.grid-info`), the mobile-card `@media`, the
  sortable-header (`.th-sort`), the toolbar (`.grid-toolbar` / `.grid-search` /
  `.btn-search` / `.grid-actions`) and the pill (`.grid-filters` / `.pill` /
  `.filter-label` / `.grid-deptos` / `.grid-group`) styles all travel with their
  components now. `.grid-card` / `.col-*` / `.btn-clear` / `.badge` stay — they're
  reused by the DB-error panel, forms, and domain rows.
- The `filter_depto` handler now reads `payload["value"]` (was `payload["depto"]`)
  — the generic GridFilters emits `data-flv-value-value`.

### Verified

- `fitz test` (ui-gallery) — **192 unit tests pass** (18 new for the DataGrid
  family + `sort_arrow`).
- `fitz check` + `fitz build` on the Admin ABM (native binary). Rendered against
  a local PostgreSQL; the WS smoke (`dev/grid_smoke.py`, 30 frames) passes and
  `fitz run` ↔ native binary are **bit-a-bit identical** in grid content (modulo
  per-connection uuids + multi-line-literal whitespace).

## [v0.20.0] — 2026-07-30 — `StatCard` + `BarChart` + `ProgressBar` (Dashboard family)

**Minor bump** — ships the **Dashboard family**, extracted from the Admin ABM
into the package: the metric card, the horizontal bar chart, and the determinate
progress bar. Built against Fitz core **v0.29.1**.

### Added — `StatCard` / `BarChart` / `ProgressBar` (Dashboard family)

- **`fitz_liveviews.ui.StatCard`** — `stat_card { label, value, hint, accent }`.
  A headline metric card with an accent-tinted left border (`data-accent`:
  `blue` / `green` / `amber` / `violet` / `primary`). Presentational, no events.
- **`fitz_liveviews.ui.BarChart`** — `bar_chart { bars: List<Bar> }`. A pure-CSS
  horizontal bar chart (zero JS, responsive). Controlled like Pager: the host
  builds a `List<Bar>` (label + value) and runs it through `bar_scale(...)`,
  which fills each bar's `pct` (0..100), scaling to the busiest bar (an SSR
  template can't do the cross-item max math, so it's a helper).
- **`fitz_liveviews.ui.ProgressBar`** — `progress_bar { label, value, max, pct,
  accent }`. A labeled determinate bar (`label` + `value/max · pct%` + a filled
  track). Like Spinner, the host passes the percent — compute it with
  `pct_of(value, max)` (`accent`: `blue` / `green` / `amber`).
- **`fitz_liveviews.ui.chart_helpers`** — the data helpers: `type Bar { label,
  value, pct }`, `pct_of(value, max) -> Int` (guarded against division by zero,
  clamped 0..100), and `bar_scale(bars) -> List<Bar>` (fills each `pct`, the
  busiest bar reaching 100%).
- All three are `.fitzv` SFCs with `<style scoped>` over `--flv-*` tokens (`accent`
  as `data-accent`, computed widths as inline `style="width: {pct}%"` — the
  mixed-attribute interpolation from Fitz core v0.28.7). A new `--flv-shadow`
  token (aliased to the shell's `--shadow`) themes the card elevation.

### Changed — Admin ABM adoption

- `dashboard.fitz` now renders `stat_card_render` / `bar_chart_render` /
  `progress_bar_render`; the local `stat_card` / `bar_chart` / `progress_bar`
  helpers were removed. The `.stat-card*` / `.chart-*` / `.pbar-*` CSS moved out
  of the admin's `admin_css()` (it now travels scoped with each component); the
  `.stat-grid` / `.pbars` layout wrappers stay. The components are imported in the
  entry (`main.fitz`) for `§9.bb` auto-registration + cross-module `-> Html`.
  **Visuals unchanged** — verified against a live server (dashboard renders 4
  StatCards, the 4-department BarChart, and 2 ProgressBars; old classes gone).
  `fitz check` + `fitz test` (178/178) + `fitz build` of the admin verified.
- 8 gallery `@test` (178 total), `docs/ui-components.md` sections + composition
  note, VSCode snippets (`ui-statcard` / `ui-barchart` / `ui-progressbar`).

## [v0.19.0] — 2026-07-30 — `Sidebar` + `Topbar` + `AppShell` (Shell family, part 3)

**Minor bump** — ships the last three **Shell-family** pieces, extracted from the
Admin ABM into the package: the branded nav rail, the sticky top bar, and the
full document layout. Built against Fitz core **v0.29.1**.

### Added — `Sidebar` / `Topbar` / `AppShell` (Shell family, part 3)

- **`fitz_liveviews.ui.shell_types`** — a nav data model alongside `Crumb`:
  `NavItem` (`href` / `label` / `key` / `icon`) and `NavGroup` (`items` + optional
  `label` / `icon`). A group with `label == ""` renders its items as flat
  top-level links; a named group nests them in a native `<details>` menu that
  auto-opens when one of its items is the active screen (zero JS).
- **`fitz_liveviews.ui.Sidebar`** — `sidebar_render(brand, brand_mark, groups,
  active, foot) -> Html`. Builds the left rail from a `List<NavGroup>`; leaf links
  close the mobile drawer. Controlled/presentational, no events.
- **`fitz_liveviews.ui.Topbar`** — `topbar_render(title, menu_label, user_name,
  user_initials, actions, user_trail) -> Html` + helper `initials_of(name)`. The
  `actions` (before the user chip) and `user_trail` (after) are pre-rendered
  `Html` the host composes with its own routes + localized labels (language
  switch, theme toggle, logout). The hamburger fires `flvToggleNav()`.
- **`fitz_liveviews.ui.AppShell`** — `app_shell(title, lang, head_extra, sidebar,
  topbar, crumbs, body, body_extra) -> Html`: the full `<!doctype html>` page. It
  **bakes** the chrome stylesheet `ui_shell_css()` (design tokens + reset +
  `.sidebar` / `.topbar` / `.content` + collapse/drawer responsive) and
  `shell_behavior_script()` (the drawer/collapse JS). `ui_shell_css()` and
  `shell_behavior_script()` are exported too, so a bare page (e.g. a login screen)
  can inline the chrome tokens without the whole shell.
- Kept as plain `.fitz` render helpers (not `.fitzv`): the two-level
  groups→items nav loop wrapping a `<details>` and the document assembly don't fit
  an SSR `{#for}` template. Same split as `theme_scripts` / `icon` / `theme`.

### Changed — Admin ABM adoption

- `page_layout` now composes the packaged `Sidebar` / `Topbar` / `Breadcrumbs` and
  hands them to `app_shell`. The monolithic `shell_css()` was split: the chrome
  moved into the packaged `ui_shell_css()`, and the admin keeps only its
  screen-specific CSS in `admin_css()`. `render_sidebar` / `render_topbar` /
  `nav_item` / `initials` / `interactive_js` were removed. **Class names are
  unchanged**, so the visuals are byte-for-byte the same — verified against a live
  server (login → dashboard / empleados / departamentos all 200; sidebar / topbar /
  crumbs / drawer / auto-open group / chrome + screen CSS intact) and a 320px
  visual pass. `fitz check` + `fitz test` (170/170) + `fitz build` of the admin
  verified.
- 12 gallery `@test` (170 total), `docs/ui-components.md` sections + composition
  guide, VSCode snippets (`ui-sidebar` / `ui-topbar` / `ui-appshell`).

## [v0.18.0] — 2026-07-30 — `ThemeToggle` component + reusable theme scripts (Shell family, part 2)

**Minor bump** — ships the second **Shell-family** piece: the light / dark /
auto theme switch, extracted from the Admin ABM into the package. Built against
Fitz core **v0.29.1**.

### Added — `ThemeToggle` + theme scripts (Shell family, part 2)

- **`fitz_liveviews.ui.ThemeToggle`** — a controlled/presentational theme switch
  button. Renders `id="flv-theme-btn"` + `onclick="flvCycleTheme()"`; declares no
  events (the theme is per-browser — the click runs client-side JS, never a
  WebSocket event, so it can't flip the theme for everyone). Props: `label`
  (SSR-initial text, default `"🖥️ Auto"`) and `aria_label` (default `"Theme"`).
  `<style scoped>` over `--flv-*` tokens.
- **`fitz_liveviews.ui.theme_scripts`** — the reusable machinery, generalized
  from the admin's `theme_init_js` / `flvCycleTheme` (storage key + labels now
  parameters):
  - `theme_boot_script(storage_key) -> Html` — anti-FOUC `<script>` for `<head>`
    (applies the saved theme before first paint).
  - `theme_cycle_script(storage_key, light, dark, auto) -> Html` — `<script>`
    before `</body>` (defines `flvCycleTheme` light → dark → auto, paints the
    button). `storage_key` must match the boot script.
- **Adopted in the Admin ABM**: `render_topbar` now renders the `theme_toggle`
  component; `page_layout` / `login_layout` use the packaged boot + cycle scripts.
  The admin's `theme_init_js` was removed and `interactive_js` trimmed to the
  sidebar/drawer toggle (theme cycling moved to the package). The dead `.theme-btn`
  CSS was dropped — the scoped component carries its own styles, and the admin's
  `--flv-*` token aliases keep it visually identical. Verified `fitz check` +
  `fitz build` of the admin.
- 3 gallery `@test` (159 total), `docs/ui-components.md` section, VSCode snippet
  (`ui-theme-toggle`).

## [v0.17.0] — 2026-07-30 — Keyed-grid verification + grouped mode keyed + `Breadcrumbs` component

**Minor bump** — closes the keyed-diffing follow-up (verify + grouped-mode gap)
and ships the first **Shell-family** packaged component, `Breadcrumbs`. Built
against Fitz core **v0.29.1** (the `{#for x in xs key=x.id}` sugar).

### Keyed grid — verified + grouped mode now keyed

- **The `{#for key=}` sugar does NOT fit the Admin grid — and that's correct.**
  The live grid's `<tbody>` is built imperatively in classic Fitz (rows are the
  `EmpleadoRow` **component**, and `<Child />` inside `{#for}` is WASM-only in
  SSR; the grid also interleaves a detail `<tr>` on expand + group-header `<tr>`s,
  which break the sugar's "exactly one root element per iteration" rule). Keyed
  diffing is **already active** via `EmpleadoRow`'s hand-written
  `data-flv-key="emp-{id}"` — exactly what the sugar emits. Forcing the sugar
  would mean inlining the row markup and dropping the `EmpleadoRow` extraction, a
  regression. The finding is documented in `ROADMAP.md` (Keyed diffing section).
- **Grouped mode is now keyed too.** `group_section`'s header row gained
  `data-flv-key="grp-{key}"` and the empty-state row gained
  `data-flv-key="grid-empty"`, so every `<tbody>` level (flat, grouped, empty) is
  fully keyed — a mixed keyed/unkeyed level previously fell back to a positional
  diff.
- **Durable regression coverage (`src/lib.fitz`, +7 `@test`).** New `keyed_grid_*`
  tests exercise the real `diff_html` engine and assert: alta → one `insert_keyed`
  (no cascade), delete → one `remove_keyed`, sort → one `move_keyed`, filter →
  keyed removes, content edits addressed **by key**, expand-detail as one keyed
  insert, and a grouped headers+rows level staying keyed. These replace the
  one-off jsdom replay with in-repo `fitz test` coverage.

### Added — `Breadcrumbs` (Shell family, part 1)

- **`fitz_liveviews.ui.Breadcrumbs`** — a controlled/presentational navigation
  trail. Pass a `List<Crumb>` (from `fitz_liveviews.ui.shell_types`); every crumb
  with `href != ""` is a link and the last hop (`href == ""`) renders as the
  current page (`aria-current="page"`). N levels; CSS-drawn separators (no
  interleaved nodes). `<style scoped>` over `--flv-*` tokens. Props: `items`,
  `aria_label`.
- **`fitz_liveviews.ui.shell_types`** — `type Crumb { label: Str, href: Str = "" }`.
- **Adopted in the Admin ABM**: `render_breadcrumbs` now renders the component;
  the bar placement (padding + bottom border) stays with the host as `.crumb-bar`.
  Verified `fitz check` + `fitz build` (docker path) of the admin.
- 4 gallery `@test` (160 total), `docs/ui-components.md` section, VSCode snippet
  (`ui-breadcrumbs`), and `data-flv-key` added to the injection grammar.

### Extraction roadmap

- `ROADMAP.md` §9.D lays out the full Admin-ABM extraction toward the ~22-25
  target, split into cohesive future sessions (Shell parts 2/3, Dashboard,
  DataGrid, Forms ×2, Feedback). 12 components packaged so far.

## [v0.16.0] — 2026-07-29 — Keyed diffing (list insert/move/remove)

**Minor bump** — teaches the server-side diff engine to match list children by
`data-flv-key` instead of by position, so inserting / removing / reordering a
list item produces a tiny, robust patch set (Phoenix LiveView's keyed
comprehensions) instead of a large positional cascade. Motivated by dogfooding
the Admin ABM: expanding a grid row (inserting a `<tr class="detail-row">`
mid-`<tbody>`) went from **72 patches that intermittently misapplied in the
browser to 3 that apply deterministically**. Fully backward-compatible — a level
without keys keeps the exact positional diff, so every existing view is
unchanged.

### Added — keyed reconciliation (`src/lib.fitz`)

- `type Patch` gains `key` and `before` fields, and three structural ops:
  - `insert_keyed` — insert `content` into the parent at `path` before the
    element whose key == `before` (`""` → append at end).
  - `move_keyed` — move the existing element with key == `key` before `before`.
  - `remove_keyed` — remove the element with key == `key`.
- A level uses keyed reconciliation only when **every** element child (old and
  new) carries `data-flv-key` and every other child is whitespace-only text;
  otherwise it falls back to the positional diff. Whitespace text nodes are
  ignored **only** at a keyed level (positional paths still count them so index
  paths keep matching the browser's `childNodes`).
- Matched elements are placed right-to-left anchored against already-placed
  siblings; elements stable under an LCS of the key order are never moved, so a
  pure insert/remove costs exactly one structural patch (zero moves).
- Content changes to a matched element (e.g. a class/text change) are addressed
  **by key** (a document-wide `data-flv-key` lookup) plus an index subpath, so
  they are immune to index drift and whitespace between siblings.
- Client `applyPatches` grows `findByKey` (uses `CSS.escape`) + `resolveTarget`
  and the three keyed ops; it keeps the `try/catch` → full-`html` fallback.
- Keys must be unique within the LiveView root. Keyed reconciliation applies at
  one list level (nested keyed lists inside a keyed element are diffed
  positionally relative to the outer key) — enough for the common table/list
  case and always backed by the full-`html` fallback.

### Added — tests + Admin ABM opt-in

- 8 new `@test`s in `src/lib.fitz` (insert-in-middle, append, remove, reverse
  reorder, content-by-key, whitespace-ignored, unkeyed-stays-positional, the
  expand-row pattern) — 100 pass.
- `examples/admin` opts in: `EmpleadoRow.fitzv` rows carry `data-flv-key="emp-{id}"`
  and the expand-row detail carries `data-flv-key="detail-{e.id}"` (no
  workarounds; grouped mode, whose group headers are unkeyed, cleanly falls back
  to positional). Toggle-row 72 → 3 patches. Validated end-to-end: the real
  client `applyPatches` (jsdom) reproduces the server `tbody` across an
  accumulating expand/collapse/sort/filter sequence, and `fitz run` ↔ native
  binary stay byte-identical on the grid WS smoke.

## [v0.15.0] — 2026-07-29 — Button gains icon + click payload + tooltip

**Minor bump** — extends the **Button** primitive so it can stand in for the raw
`btn-icon` action buttons of a real admin grid (row edit/delete/expand), motivated
by adopting the companion UI across the Admin ABM showcase. All four additions are
backward-compatible (default empty/off); every existing `button { ... }` renders the
same markup plus three inert empty attributes.

### Added — Button API (backward-compatible)

- `icon: Str` — renders an SVG from the [icon set](src/ui/icon.fitz) before the
  label. `label` is now optional, so `button { icon: "trash" }` is an **icon-only**
  button. This partially closes the Cut 2 deferral of icon slots (Button only; Card
  and Input still compose `icon(...)` in the host).
- `value: Str` — a fall-through click carries `data-flv-value-value="{value}"`, read
  in the `@ws` loop as `payload["value"]` (e.g. the row id an edit/delete button acts
  on). Not emitted on `submit` buttons (those drive a form, not a click event).
- `tooltip: Str` — emitted as `data-tooltip`. The kit ships no tooltip CSS; the host
  styles `[data-tooltip]:not([data-tooltip=""])` so an unset tooltip renders nothing.
- `aria_label: Str` — accessible name for icon-only buttons (ignored by AT when
  empty, so a text button falls back to its visible label).

`value`, `tooltip` and `aria-label` are always emitted with interpolated values;
their empty defaults are inert, which keeps Button's variant tree flat (no
combinatorial explosion of conditional attributes).

### Added — gallery, tests, docs, editor

- `examples/ui-gallery` renders an icon+label button and an icon-only button with a
  value payload + tooltip; 5 new `@test`s in `components_test.fitz` (137 pass).
- `docs/ui-components.md` — Button section documents the four new props + the
  icon-only / payload / tooltip pattern.
- VSCode snippet `ui-button-icon` for the icon-only + payload button.

## [v0.14.0] — 2026-07-28 — Examples refactored onto the companion UI (9.C)

**Minor bump** — the four bundled examples (Counter, Dashboard, Chat, Kanban) now
consume the packaged companion UI primitives (`fitz_liveviews.ui.*`) instead of
hand-rolling every button, form field and card with local CSS. This is the first
time the **presentational** primitives (Button / Card / Badge / Icon / Input) run
inside real apps rather than the isolated gallery — dogfooding them surfaced two
API gaps (both fixed below) and one Fitz-core limitation (documented).

### Added — primitive API (backward-compatible, motivated by the refactor)

- **Button** gained `submit: Bool` — `submit: true` renders `type="submit"` and
  omits `data-flv-click`, so it drives an enclosing `<form data-flv-submit="…">`
  instead of firing its own event. A default button now renders explicit
  `type="button"`, so a click button never accidentally submits a form it sits in.
- **Input** gained `required: Bool`, `clear: Bool` and `autocomplete: Str`, making
  it a first-class **live-form** field: `required` for client validation, `clear`
  emits `data-flv-clear` (the client empties the field after a successful submit).

### Changed — examples

- **Counter** — the three actions render through `Button` (`on_click` routes to the
  component's `@on` handler exactly like the raw `@click` did) + `ui_theme()`.
- **Dashboard** — each tile is a `Card` with an `Icon` header + live `Badge`; `+1` /
  `reset` are `Button`s; ~22 lines of hand-rolled tile/button CSS deleted.
- **Chat** — each message is a `Card` (author-escaped, XSS-safe); the composer is
  two `Input`s + a submit `Button` (the message field's `clear: true` empties it
  after each send).
- **Kanban** — each card is a `Card` with baked-in `Icon` action buttons; the
  add-form is two `Input`s + a submit `Button`; the three columns collapsed to one
  shared `render_card(c)` helper; ~35 lines of hand-rolled CSS deleted.
- New sibling presentational-helper modules (`counter_ui.fitz`, `chat_ui.fitz`,
  `metric_tile_ui.fitz`, `board_ui.fitz`) wrap primitive calls for use inside
  `.fitzv` templates (see the SSR note below).

### Notes

- **Native-build parity** holds for Counter / Dashboard / Chat (`fitz run` ==
  `fitz build`). **Kanban stays `fitz run`-only** — its `type Board` (in
  `card.fitz`) collides with the `Board` module (from `Board.fitzv`) in the
  Fitz-core codegen (`E0255 / E0573`); the un-refactored Kanban fails identically,
  so this is a pre-existing Fitz-core limitation, not a regression.
- **SSR limitation surfaced**: a struct literal inside a `{...}` template
  interpolation (`{button_render(button { … }).raw}`) passes `fitz check` but fails
  at `fitz run` (the SSR emitter doesn't round-trip the nested braces), which is why
  primitives used inside a `.fitzv` template are hoisted into helper fns. Fixing
  this in Fitz core would let the helper modules go away.
- New tests: gallery `@test`s 130 → 132 (`button` submit, `input` required/clear/
  autocomplete). New reference doc: [`docs/companion-ui-benefits.md`](docs/companion-ui-benefits.md).
  New VSCode snippets `ui-button-submit`, `ui-input-form`.

## [v0.13.0] — 2026-07-28 — Companion UI library: 8 primitives (cut 2)

**Minor bump** — ships cut 2 of the companion UI library: the eight generic
primitives from roadmap 9.B, added to `fitz_liveviews.ui.*` in the same
dotted-sub-path style as cut 1. Seven are pure presentational / SSR (render fn:
props in, HTML out, no state); **Modal** is stateful, one instance per connection
(like ConfirmDialog).

### Added — packaged UI primitives (`fitz_liveviews.ui.*`)

- **Button** — `variant` (primary / secondary / danger / ghost), `size` (sm / md /
  lg), `disabled` + `loading` (both render a real `disabled`; loading shows an
  inline spinner). A click fires the fall-through event named by `on_click`.
- **Card** — escaped `title` header; `body` and `footer` are **RAW HTML** (a card
  holds anything — a table, a form, other components), omitted when empty;
  `elevation` (none / sm / md / lg); `clickable` variant firing `on_click`.
- **Badge** — count or status pill; `variant` (primary / success / danger / info /
  muted), `size` (sm / md).
- **Alert** — colored callout; `variant` (info / success / warning / danger) drives
  a left accent + tint; escaped `title` / `body`; `dismissible` fires `on_dismiss`.
- **Input** — labeled, **controlled** form field (its `value` lives in your form);
  `input_type` (text / email / password / number), `label` / `placeholder` / `hint`,
  `error` (switches to the invalid style via CSS `:has()`), `disabled`. Every
  attribute value is escaped.
- **Spinner** — indeterminate rotating ring by default; `progress: 0..100` for a
  determinate ring (filled via the `--flv-p` custom property, no client JS); sizes
  sm / md / lg; `inline` vs block.
- **Icon** (`fitz_liveviews.ui.icon`) — `icon(name).raw` returns a 1em,
  `currentColor` SVG; 23 baked-in outline icons; unknown names render an empty
  `<svg>` so a typo degrades gracefully.
- **Modal** — stateful, per-connection generic dialog: `show` (seeds `title` /
  `body` from the payload) / `close`. The × button and a backdrop click both close
  it; content clicks don't (a `pointer-events` layering trick, no JS).
- **Theme** — `ui_theme()` gains a `--flv-color-warning` token (for the Alert
  `warning` variant); every primitive reads `--flv-*` with literal fallbacks, so it
  renders un-themed and re-themes by aliasing the tokens. Scoped, self-contained
  `<style scoped>`; parity `fitz run` ↔ `fitz build`.

### Added — docs, tests, editor snippets

- `docs/ui-components.md` — eight new entries under "Packaged components", plus
  "Packaged" cross-links from the hand-rolled Button/Input/Alert/Modal/Badge/Spinner
  patterns.
- `examples/ui-gallery/tests/components_test.fitz` — 26 new `@test` (128 total),
  covering render output, escaping vs raw injection, the invalid/disabled states,
  and Modal's show/close (`fitz test` from the gallery).
- VSCode extension — new snippets: `ui-import-primitives`, `ui-button`, `ui-card`,
  `ui-badge`, `ui-alert`, `ui-input`, `ui-spinner`, `ui-icon`, `ui-modal-seed`,
  `ui-modal-show` (and `ui-import` now includes Modal).

### Notes — not in this cut

Deferred from the 9.B spec (the render-fn / SSR model doesn't support them yet):
Button/Card/Input **icon slots** (no slots in a render fn — compose `icon(...)` in
the host), and Modal **focus trap + ESC-to-close** (both need client-side JS the
SSR path doesn't inject). The theme stays a single `ui_theme()` token layer rather
than separate `themes/*.css` files.

### Requires

Fitz core **v0.29.0** — dep-subpath imports, `@live_component` auto-registration for
imported components, and the 16 MB worker stack for real-world WS renders.

## [v0.12.0] — 2026-07-28 — Companion UI library: Pager / Toast / ConfirmDialog + theme (cut 1)

**Minor bump** — ships the first cut of a companion UI component library: the
three most reusable LiveComponents, generalized out of the Admin ABM into an
importable sub-package, plus a re-themable design-token layer.

### Added — packaged UI components (`fitz_liveviews.ui.*`)

- **Pager**, **Toast** and **ConfirmDialog** live in `src/ui/*.fitzv`, imported
  by dotted sub-path — `from fitz_liveviews.ui.Pager import pager, pager_render`
  — instead of vendoring the `.fitzv` into your app. Enabled by Fitz core
  **v0.29.0** (dep-subpath imports + `@live_component` auto-registration for
  imported components).
- **i18n stays out of the library**: the host passes already-localized text —
  Toast takes a `message`; ConfirmDialog seeds its labels at init and takes a
  formatted body in the `ask` payload.
- **Theme** (`fitz_liveviews.ui.theme`) — `ui_theme()` emits `--flv-*` design
  tokens (light + a `[data-theme="dark"]` override). Every component reads
  `--flv-*` with literal fallbacks, so a host re-themes them either by dropping
  in `ui_theme()` or by aliasing `--flv-*` to its own tokens.
- Scoped, self-contained `<style scoped>`; parity `fitz run` ↔ `fitz build`.

### Changed — the Admin ABM consumes the library

The Admin ABM example drops its vendored Pager / Toast / ConfirmDialog copies
(−220 LoC of components, −203 LoC net) and imports them from
`fitz_liveviews.ui.*`, aliasing `--flv-*` to its own tokens so the components
inherit its light / dark / auto theming.

### Added — docs, tests, editor snippets

- `docs/ui-components.md` — a "Packaged components" section documenting the three
  plus the theme (state, events, wiring, theming).
- `examples/ui-gallery/tests/components_test.fitz` — 12 `@test` covering the
  render fns, the event handlers, and the theme (`fitz test` from the gallery).
- VSCode extension — 8 new snippets (`ui-import`, `ui-pager`, `ui-toast-seed`,
  `ui-toast-show`, `ui-dialog-seed`, `ui-dialog-ask`, `ui-dialog-confirm`,
  `ui-theme`).

### Requires

Fitz core **v0.29.0** — dep-subpath imports, `@live_component` auto-registration
for imported components, and the 16 MB worker stack for real-world WS renders.

## [v0.11.0] — 2026-07-24 — `component_with`: per-instance init payload + the per-connection instance pattern

**Minor bump** — closes the "per-instance init payload" item that was open on
the Phase 4 roadmap since LiveComponents shipped, and establishes the
architecture for **per-connection** component instances (the Admin ABM
LiveComponents refactor, slice 1).

### Added — `component_with(name, id, initial) -> Html`

- Like `component(name, id)`, but the FIRST render of the instance seeds the
  state store with `initial` instead of the registry-wide `initial_state`.
  Later renders ignore `initial` and use the stored (possibly mutated) state.
- Two patterns it unlocks: per-instance seed data
  (`component_with("MetricTile", tile.id, MetricTile { label: tile.label })`)
  and **per-connection instances** — a `@ws` handler mints
  `let cid = Uuid.v4().to_str()` and renders
  `component_with("confirm_dialog", cid, confirm_dialog { locale: locale })`,
  so each socket owns an isolated instance seeded with connection-scoped data.
  SSR first paint uses a shared placeholder id (`"ssr"`) — safe because events
  only travel over the socket. Full recipe in `docs/components.md` →
  "Per-connection instances".
- Known limitation (documented): per-connection instances are never evicted
  from the store — no disconnect hook and `Map` has no `remove` in Fitz core
  yet. `flv_drop_instance(...)` is planned once core grows `Map.remove`.
- +3 tests (`cw_*`): seeds from the given initial, ignores initial on later
  renders, isolates per-connection instances. Lib suite: 92 green.

### Changed — Admin ABM: ConfirmDialog extracted as the first LiveComponent

- `examples/admin/src/ConfirmDialog.fitzv` (new SFC) owns the delete-confirm
  UI state that used to live as the `confirm_ids` local in the `@ws` loop of
  `empleados.fitz`. Canonical parent/component contract: `ask` is dispatched
  by the parent via `dispatch_to(...)` (the trigger buttons live outside the
  component), `cancel` routes automatically via `dispatch_component_events`,
  and the Delete button fires an undeclared `confirm_delete` that falls
  through to the parent loop — which reads the pending ids with
  `component_state(...)` (K-2), runs the real DB delete, and closes the
  dialog with `dispatch_to(..., "cancel", {})` (K-1).
- Validated end-to-end with 10/10 WS smoke on BOTH `fitz run` and the native
  binary (`fitz build`, Fitz core ≥ v0.28.6/W27): per-connection uuid
  instances, isolation between two sockets, real Postgres delete.
- Requires Fitz core **v0.28.6** (W27: `__FitzValue` import for coercion-only
  modules). Also exercises the entry-file conventions: the SFC + `flv_register`
  + `Html` must be imported in `main.fitz` (auto-registration §9.bb pre-scans
  the entry's DIRECT imports only).

## [v0.10.0] — 2026-07-22 — `__flv_init`: connection context for `@ws` handlers

**Minor bump** — a live socket can now learn per-connection context (locale,
tenant, …) that Fitz-core `@ws` can't expose from the handshake.

### Added — `__flv_init` on connect

- On `ws.onopen` the client parses the query params of its `ws_path` and sends
  them as a `__flv_init` event (`{event:"__flv_init", payload:{lang:"en"}, …}`).
- The `@ws` handler reads them from that first event and, typically, re-renders
  its diff baseline to match what the SSR page already shows.
- **Why**: Fitz-core `@ws` handlers can't read the handshake — `@header` is
  rejected at runtime and the `@ws` path must be a plain `Str` literal (no query
  or path params). So the SSR page bakes context into the socket URL
  (`live_embed("/live/x?lang=en", …)`) and the client hands it over on connect.
  Documented as a core finding to fix upstream (`d:\fitz`).
- Drives full **i18n** of the Admin ABM live grid + form (S9).

## [v0.9.0] — 2026-07-22 — serialize-on-click (`data-flv-form`) for in-form nav

**Minor bump** — a `data-flv-click` action button can now opt in to
serializing its enclosing form, so in-form navigation (tabs, stepper steps)
preserves the currently typed values across a server re-render.

### Added — `data-flv-form` opt-in on click

- When a `data-flv-click` element also has the `data-flv-form` attribute, the
  client runtime serializes its enclosing `<form>` into the event payload
  (reusing `serializeForm`, same as `data-flv-submit` / `data-flv-change`).
  Serialized **before** `collectValues`, so any explicit `data-flv-value-*`
  on the same element still wins.
- Motivation: tabbed / stepped forms switch sections with a click; without
  carrying the form, the server re-render would wipe unsaved input in the
  other sections. Buttons without `data-flv-form` are unaffected (e.g. the
  grid's "Limpiar" button keeps its explicit `data-flv-value-q=""`).
- Drives the **Tabs** and **Stepper** components in the Admin ABM showcase (S8).

## [v0.8.0] — 2026-07-22 — checkbox-group serialization + Admin ABM Slice 4c (permisos)

**Minor bump** — the client form serialization now understands checkbox
groups, unlocking the group-checkbox component.

### Changed — form serialization (`serializeForm`)

- `data-flv-submit` and `data-flv-change` now serialize form fields through a
  shared `serializeForm` helper: several checkboxes sharing a `name` (a
  checkbox group) are joined **comma-separated** and only when checked, so
  the server receives the whole selection (an all-unchecked group yields an
  empty string). Radios contribute the checked value. A single checkbox
  reports its `checked` state instead of always sending its `value`.

### Showcase (Admin ABM — `examples/admin`)

- **Slice 4c — group-checkbox (permisos)**: the employee form now has a
  permissions picker rendered as a `<fieldset>` per module, one checkbox per
  permiso (new `permisos` table + `empleado_permisos` join). Save syncs the
  selection (delete + insert); edit pre-checks the current permisos. Uses
  `str.split` + `str.to_int` to parse the comma-joined ids. Verified
  end-to-end on the native binary + local Postgres.

## [v0.7.0] — 2026-07-22 — `change` events + Admin ABM Slice 4 (rich edit form + cascade)

**Minor bump** — one new client capability plus the flagship showcase's
Slice 4 (create/edit form with a cascade select).

### Added — `data-flv-change` events

- The client runtime now wires the native **`change`** event: put
  `data-flv-change="event_name"` on an `<input>`/`<select>` and it fires a
  WS event carrying the element's value (`payload.value`, plus the element's
  `name`). When the changed element is inside a `<form>`, every named field
  is serialized into the payload too, so a re-render never wipes text the
  user already typed (checkboxes report `checked`). Enables cascade selects,
  live toggles, and onchange filters — the missing peer of `data-flv-click`
  and `data-flv-submit`.

### Showcase (Admin ABM — `examples/admin`)

- **Slice 4a — create/edit form**: a "Nuevo" button + per-row edit action
  open a form *inside the same LiveView as the grid* (it patches over the
  grid, the shell stays put). Inputs + selects, save via `Empleado.insert` /
  `.where(id).update`, server-side validation, cancel. `str.to_int()`
  parses the select ids from the payload.
- **Slice 4b — cascade select**: a país → provincia → ciudad hierarchy
  (new `paises`/`provincias`/`ciudades` tables + `ciudad_id` on `empleados`).
  Each `change` re-queries the dependent options server-side; typed fields
  are preserved across the re-render. Verified end-to-end on the native
  binary + local Postgres. Requires **Fitz ≥ v0.27.0** (`str.to_int`).

## [v0.6.0] — 2026-07-22 — `live_embed` + Admin ABM Slice 2 (live DataGrid)

**Minor bump** — one NEW public API plus the flagship showcase's Slice 2.

### Added

- **`live_embed(ws_path: Str, root_id: Str, initial: Html) -> Html`** —
  embeds a LiveView as a **fragment** inside an existing page, instead of
  owning the whole document like `live_layout` (which returns a full
  `<!doctype html>`). Returns `initial`'s render followed by the client
  `<script>` wired to `ws_path` + `root_id`; drop it inside your own
  `<main>` and only `#root_id` is patched — the surrounding shell (sidebar,
  topbar, tabs) stays put. Same contract as `live_layout`: `initial`'s
  outermost tag carries `id="{root_id}"` and a matching `@ws(ws_path)`
  handler recv/sends `LiveFrame`s. Covered by 2 `@test`s. VSCode snippet
  added.

### Showcase (Admin ABM — `examples/admin`)

- **Slice 2 — Empleados DataGrid (read-only)**: SSR first paint on
  `GET /empleados` + live pagination over `@ws("/live/empleados")` with
  `WsConn<LiveFrame>` (per-connection page state, diff-and-patch back to
  that socket only). Uses `live_embed` to sit inside the admin shell, plus
  the grid CSS. Verified end-to-end on the native binary and via
  `docker compose up --build` (login → grid → `page_next` → page 2).
- Requires **Fitz ≥ v0.26.1** (cross-module `List<Nominal>` codegen fix,
  W19+W20): the grid's `WsConn<LiveFrame>` (`LiveFrame.patches:
  List<Patch>`) and `let patches = diff_html(...)` now build to a native
  binary without importing `Patch` into the module. `Dockerfile` /
  `docker-compose.yml` pin `FITZ_TAG=v0.26.1`.

## [v0.5.0] — 2026-07-16 — K-1 + K-2 framework fns: `dispatch_to` + `component_state` + `set_component_state`

**Minor bump** — first NEW public API in the framework layer since
v0.4.0. Closes K-1 + K-2 debts documented in Fitz core
`docs/deudas-post-5b.md` (kanban migration surface).

### K-1: `dispatch_to(component_name, instance_id, event, payload)` — event bubbling substitute

Explicit event dispatch to a specific component + instance from
server code. Complements `dispatch_component_events(frame)` which
routes frames from the client. `dispatch_to` fires the target
component's registered event handler with the given payload,
updates the component's state in `COMPONENT_STATE_STORE`, and
returns `true` on success (or `false` silently if the component
name isn't registered or the event isn't in that component's
handler map — fire-and-forget safe).

Canonical use case (motivation from kanban Phase 8.5 partial): a
child component's event handler fires `dispatch_to` to notify a
sibling or parent component of a state change, avoiding the need
for parent WS handler post-processing to hand-roll cross-component
state propagation.

Example (child `save` bubbles to parent):

```fitz
event save() {
  text = payload["text"]
  is_editing = false
  dispatch_to("Board", "root", "card_saved", payload)
}
```

### K-2: `component_state(name, id)` + `set_component_state(name, id, new_state)` — direct state API

Read + write access to component state outside of registered event
handlers. Use cases:
- Parent WS handler post-processing (read a component's state
  after an event fired to inspect its result).
- Test fixtures (assert on component state after simulated events).
- Hydration (seed a component's state from a database read on
  initial page load).

`component_state` returns `null` if the component wasn't
registered; lazy-inits from `initial_state` if the instance was
never rendered or dispatched. `set_component_state` returns
`true`/`false` for registered/unregistered component.

Caveat: bypasses event handlers — the caller is responsible for
the state shape matching the component's declared type. Fitz's
gradual typing catches obvious mistakes at the call site.

### K-12: canonical child → parent dispatch pattern proven

New test `k12_canonical_child_dispatches_to_parent_via_dispatch_to`
demonstrates the pattern that motivated K-1 (CardEditor's save →
Board's card_saved) stripped to essentials: two components, one
fires the other via `dispatch_to` inside its event handler,
verified via `component_state` + subsequent render. Full kanban
`Board.fitzv` migration (from the current Phase 8.5 partial) is
now unblocked and can land as a follow-up commit that consumes
`dispatch_to`.

### API surface

New public fns in `src/lib.fitz`:
- `fn dispatch_to(component_name: Str, instance_id: Str, event: Str, payload: Map<Str, Str>) -> Bool`
- `fn component_state(component_name: Str, instance_id: Str) -> Any`
- `fn set_component_state(component_name: Str, instance_id: Str, new_state: Any) -> Bool`

No breaking changes — all existing APIs (`flv_register`,
`component`, `dispatch_component_events`) unchanged.

### Tests

13 new `@test` fns: 6 K-1 (fires+updates / silent fail on unknown
component / silent fail on unknown event / payload forwarding /
shared store with dispatch_component_events / instance isolation),
6 K-2 (initial state lazy-init / null for unknown / reflects post-
dispatch / direct write visible to render / silent fail on
unknown / overwrites dispatched), 1 K-12 canonical (child →
parent via dispatch_to). Total lib test count: 83/83 verde.

### VSCode extension

Bumped to v0.5.0 in lockstep. No grammar or snippet changes —
existing `livecomp` / `renderfor` / `onevent` snippets are
sufficient. `.vsix` regenerated for lockstep consistency.

### Debt residual (NO bloquea)

- **K-3 compound props** for `<Child prop={compound_value} />`
  remains ABIERTA in Fitz core (view emitter, ~80 LoC). Not
  blocking for kanban Board.fitzv migration (Board's initial
  state is empty).
- **Full kanban Board.fitzv migration** (from Phase 8.5 partial)
  now unblocked but not shipped in v0.5.0 — deferred to a
  follow-up commit that consumes `dispatch_to`.

## [v0.4.3] — 2026-07-16 — Phase 8: examples migrated to `.fitzv` SFC syntax

**Requires Fitz core v0.21.0+.** Docs-only sync-point release.
No `fitz-liveviews` code changes — the library API (`src/lib.fitz`,
~1700 LoC) is IDENTICAL to v0.4.2. What shipped is the migration
of all 4 canonical examples (counter / dashboard / chat / kanban
partial) from classic Fitz `@live_component` inline syntax to the
new `.fitzv` single-file component syntax that Fitz core Phase 11
(v0.21.0) introduced.

Bumped as a **sync-point marker**: the manifest reads v0.4.3
identifies "this fitz-liveviews works with `.fitzv` examples under
Fitz core v0.21.0+". Parallel to the precedent v0.4.2 (docs-only
lockstep bump with the VSCode extension).

### Migrated examples

- **`examples/counter/`** — Phase 8.2. Extracted `Counter.fitzv`
  SFC. `main.fitz` shrinks to imports + HTTP handlers; compiler
  auto-injects the `flv_register("Counter", ...)` boot call
  (Fitz core §9.bb cross-module auto-inject).
- **`examples/dashboard/`** — Phase 8.3. Extracted
  `MetricTile.fitzv` SFC (per-instance card state). Board render +
  6 tile config remain in `main.fitz`.
- **`examples/chat/`** — Phase 8.4. Full SFC migration. Extracted
  `type Message` to `message.fitz` sibling + `ChatRoom.fitzv` SFC
  owns state + event with nested payload guards + `messages.push
  (Message { ... })` + template with `{#for m in messages}` +
  submit form. `main.fitz` shrinks from ~115 LoC to ~50 LoC (WS
  handler has ZERO event branches). This migration surface 6
  view pipeline gaps in Fitz core (V-1 to V-6) that were CLOSED
  in the SAME SESSION via §9.cc + §9.dd + §9.ee — feedback loop
  of hours, not weeks.
- **`examples/kanban/`** — Phase 8.5 PARTIAL. Extracted
  `type Card` + `type Board` → `card.fitz` sibling + `card_editor`
  `@live_component` → `CardEditor.fitzv` SFC. Board-level state
  + WS handler + render fns REMAIN in classic Fitz — full
  `Board.fitzv` migration deferred to Phase 11.7+ pending Fitz
  core framework support for event bubbling between components
  (K-1/K-2/K-3 debts documented in Fitz core
  `docs/deudas-post-5b.md`). `main.fitz` shrinks from ~466 LoC
  to ~320 LoC (146 LoC reduction).

### Component patterns catalog (Phase 8.6)

`docs/components-candidates.md` new file catalogs reusable
component patterns observed across the 4 migrations. Ready for
Phase 9.A consolidation into the MVP UI library shortlist:
- **Button** — 9 occurrences, 4 variants (primary/success/danger/
  ghost) + sm/md sizes + icon slot.
- **Card** — dashboard tile wrapper + chat message bubble
  candidate. Canonical header/body/footer slots + accent color.
- **Input** — chat form + kanban create form + kanban card editor.
  Canonical `name`/`placeholder`/validation attrs + label + hint
  + error prop.
- **Modal** — kanban card editor toggle CLOSE — MVP with
  backdrop + close + focus-trap.
- **Alert / Badge / Spinner / Icon** — scaffolding for the 8-
  component MVP shortlist (Alert not observed; Badge kanban-
  adjacent; Spinner scaffolding; Icon proven-need via kanban
  arrow chars).

Theme system tokens enumerated from observed CSS:
`--flv-color-primary` (Fitz orange `#CE412B`), `--flv-color-success`
(`#3c763d`), `--flv-color-danger` (`#a94442`), `--flv-color-info`
(`#31708f`), `--flv-color-muted` (`#666`), `--flv-radius-md`
(6-8px), `--flv-shadow-card` (`0 1px 3px rgba(0,0,0,0.08)`).

### VSCode extension

Bumped to v0.4.3 in lockstep with the manifest. No grammar or
snippet changes (snippets `livecomp` / `renderfor` / `onevent`
were already SFC-ready since v0.4.2 — the `.fitzv` transform
consumes the same decorators). `.vsix` regenerated for lockstep
consistency.

### Debt residual (NO bloquea uso real)

K-1/K-2/K-3 framework gaps documentados en Fitz core
`docs/deudas-post-5b.md` para Phase 11.7+ prioritization:
- **K-1: Event bubbling entre componentes** — CardEditor's
  `save` no propaga a Board. Workaround: parent WS handler
  post-processes manually.
- **K-2: Cross-component state read/write API** —
  `component_state()` + `set_component_state()` pair needed
  para parent handlers a fetch/mutate component's state.
- **K-3: Component props para compound/nominal types** —
  `<Board initial-cards="{seedCards}" />` no soportado; MVP
  props sólo primitivos.

Combined estimate ~400-500 LoC framework + ~150 LoC lib. Los 3
son prerequisites para Phase 11.7 (client-side dynamic
capabilities + kanban SPA port acceptance criterion). No urgency
— kanban's current workaround (board state top-level) functions.

## [v0.4.2] — 2026-07-14 — Version alignment (docs-only)

Bumps the VSCode extension version to match the lib version so
`fitz.toml`, `editors/vscode/package.json` and the released `.vsix`
asset all read `0.4.2`. No behaviour change, no API change. From
this release onward, the lib and the extension bump in lockstep.

## [v0.4.1] — 2026-07-14 — Phase 5.A.1: implicit `flv_register(...)` from decorators

**Requires Fitz core v0.20.1+.** No `fitz-liveviews` code changes; the
library API is identical. What changed is the compiler: it now
auto-generates the `flv_register(...)` boot call from the metadata
that `@live_component` + `@render_for` + `@on` leave in the
`TypeEnv`. Users writing components no longer need the manual boot
call.

### Changed

- **Kanban example** (`examples/kanban/`) — dropped the manual
  `flv_register("card_editor", ...)` boot call. Metadata alone drives
  the registration.
- **Dashboard example** (`examples/dashboard/`) — dropped the manual
  `flv_register("metric_tile", ...)` boot call.
- **`docs/components.md`** — "Register the component at boot" section
  reframed as "Registration is automatic", with a note explaining
  when to fall back to manual registration (custom initial state that
  differs from the type defaults). The "Coming next" section marks
  implicit registration as done.
- **`docs/live.md`** — `@live_component` teaser example no longer
  shows the manual boot call; "coming next" section updated.
- **`README.md`** — Phase 5.A.1 bullet added to the overview list.
- **`ROADMAP.md`** — Phase 4 "Codegen pass: turn `@live_component` +
  `@render_for` + `@on` into implicit registration" item marked
  done, with a note about the invariants the compiler enforces at
  build time.

### Requirements for the implicit path

- Every field of the `@live_component` type must declare a default —
  the compiler synthesises `TypeName {}` and needs defaults for all
  fields to succeed.
- `flv_register` must be in scope. Import it from `fitz_liveviews` at
  the top of the file; the compiler surfaces a clear error at build
  time if it isn't.
- Every `@live_component("name")` needs a matching `@render_for("name")`
  fn. The compiler aborts the injection with a clear error citing
  the missing renderer.
- Aliased imports (`from fitz_liveviews import flv_register as
  register`) are treated as out of scope — the injection emits
  `flv_register` verbatim. Just don't alias.

### Backward-compatible fallback

Manual `flv_register(...)` calls still work; the compiler skips the
implicit injection for any component that already has a manual
registration. This is the escape hatch for custom initial state that
differs from the type defaults.

## [v0.4.0] — 2026-07-12 — Phase 4: LiveComponents (stateful, per-instance)

**Milestone release.** Phase 4 of the roadmap closes end-to-end with
LiveComponents — stateful child components with per-instance state,
built on top of three new Fitz core decorators (requires Fitz core
v0.20.0+).

### Added

- **Framework layer** (`src/lib.fitz`, Session 2 — 2026-07-12):
  - `flv_register(name, initial_state, render_fn, event_handlers)` —
    register a component at boot with its initial state, renderer, and
    an event handler map keyed by event name.
  - `component(name, id) -> Html` — embed a component instance in a
    parent template. Injects `data-flv-component-name` +
    `data-flv-value-instance_id` wrappers so the client runtime can
    route events without parent code.
  - `dispatch_component_events(frame) -> Bool` — auto-routes a
    `LiveFrame` to the matching component + event handler. Users call
    this at the top of their `@ws` handler loop. Auto-seeds state from
    `initial_state` on the first hit so an event arriving before the
    parent's render does not crash.
  - Per-instance state store keyed by `(component_name, instance_id)`.
- **Starter template** (`templates/basic/`, Session 2) — used by
  `fitz new my-app --template liveviews` to scaffold a minimal working
  project with `@server`, an HTML page, and a live counter.
- **Kanban refactor** (`examples/kanban/`, Session 3 — 2026-07-12) —
  moved per-card inline title editing to a `@live_component("card_editor")`.
  Before/after LoC + walkthrough in `docs/examples/kanban.md`.
- **New dashboard example** (`examples/dashboard/`, Session 3) — grid
  of live `metric_tile` components, six independent instances, zero
  parent event branches. Demonstrates state isolation.
- **`docs/components.md`** (Session 3) — full walkthrough covering the
  three decorators, the three framework builtins, the canonical `@ws`
  loop, state isolation, component ↔ parent cooperation, and
  gradual-typing gotchas.
- **README + ROADMAP updates** (Sessions 2 + 3) — reflect that Phase 4
  is done.

### Requires

- Fitz core **v0.20.0+** for the three new decorators
  (`@live_component`, `@render_for`, `@on`) validated by the checker,
  plus the `fitz new --template liveviews` CLI. See Fitz core's
  CHANGELOG v0.20.0.
- Client runtime (baked into the `<script>` tag emitted by
  `flv_page(...)`) walks up to the enclosing component wrapper so
  `<button data-flv-click="save">` inside a component gets
  `component_name` + `instance_id` in its payload automatically.

### Notes

- The three decorators are **markers** in Fitz core — the checker
  validates their shape and persists metadata in the `TypeEnv`. The
  runtime dispatch lives here (`flv_register` + `component` +
  `dispatch_component_events`). A future refinement may replace the
  explicit `flv_register(...)` call with an implicit codegen pass
  driven by the decorators; the public API stays the same.
- **VSCode extension v0.3.2** (`editors/vscode/`) ships alongside with
  `livecomp` / `renderfor` / `onevent` / `flvcomp` / `dispatchcomp`
  snippets (introduced in Session 2 and refined in Session 3), plus a
  grammar tweak in v0.3.2 adding `data-flv-component-name` as a
  highlighted LiveViews-directive attribute (Session 4).

### Deferred (Phase 4 stretch → future)

- **Codegen pass** turning `@live_component` + `@render_for` + `@on`
  into an implicit registration and removing the explicit
  `flv_register(...)` call.
- **Per-instance init payload** — today every instance starts with the
  same `initial_state`; a `component(name, id, init_payload)` shape
  would let each instance start with per-instance seed data.
- **`dispatch_to_all(name, event, payload)`** for bulk actions across
  every live instance of a component.

## [v0.3.0] — 2026-07-12 — Phase 3b showcase: collaborative Kanban

**Showcase release.** Built without Phase 4 LiveComponents intentionally
so the framework proves itself with the primitives available before
adding component sugar.

### Added

- `examples/kanban/` — collaborative Kanban board with 3 columns
  (`todo` / `doing` / `done`), inline card editing, dragging via
  buttons, real-time broadcast between browsers. Baseline docs in
  `docs/examples/kanban.md`.
- `docs/live.md` progress on the `@ws` handler pattern for shared
  state + `dispatch_frame(...)` helper.

## [v0.2.0] — Phase 3a: forms + broadcast + shared state

- Form data harvesting from `data-flv-submit`.
- Multi-client broadcast via a topic-keyed subscribers store.
- Shared server state (kept alive by the `@ws` handler loop) with
  optimistic-locking-safe update pattern.

## [v0.1.0] — Phase 1 + 2: HTML primitives + LiveView MVP

- `Html` opaque type, `html(raw)` constructor, `raw_html` alias,
  `flv(...)` escape helper.
- Convention-based XSS-safety (manual `flv()` for user data).
- Composition helpers `h_join`, `h_when`, `h_either`.
- LiveView core: `flv_page(...)`, `flv_run(...)`, `LiveFrame` record,
  client runtime bundled in the emitted `<script>`.
