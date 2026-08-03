# Client-WASM — plan (live interactive gallery on GitHub Pages)

> **Planning doc / internal.** Not in the mkdocs nav. The north star: a **live,
> interactive component gallery hosted on GitHub Pages** — users click real
> components running in their browser, no install, no server. This is the
> visibility / stars engine for the project.

## Why this is a *parallel* component set (not a recompile of the SSR ones)

The fitz core has a mature `.fitzv` → **client-WASM** target (`fitz build
--target wasm-client`, `fitz` Phase 11: `src/view/codegen_wasm.rs` +
`wasm_build.rs`; ~17 examples under `fitz/examples/view/`). It emits a
self-contained `wasm-bindgen` + `web-sys` crate → `wasm-pack build --release
--target web` → a `.wasm` + JS glue mounted into a `<div id="app">`.

**But the SSR companion UI components cannot target it as-is.** Two blockers that
compound (confirmed in core code + a build experiment):

1. **Framework import doesn't resolve.** The WASM loaders
   (`wasm_build.rs::load_imported_{nominals,fns,components}`) are
   **sibling-file-only** (`base_dir.join("{stem}.fitzv")`), skip dotted paths
   (`if imp.path.len() != 1 { continue }`), and there is **no `dep_registry`** in
   the wasm build path. So `from fitz_liveviews import flv` (a `fitz.toml`
   dependency) resolves to nothing; `{flv(label)}` then fails at rustc link with
   `cannot find function flv`. The view checker is lenient (shape-only) so it
   passes `fitz check` and only breaks at the wasm-pack step.
2. **Different render model.** SSR = a `type` + `<name>_render(state) -> Html`
   string-builder (needs `Html`/`flv`). wasm-client = the template compiled to
   `web-sys` DOM ops (`create_element` / `create_text_node` / `append_child`),
   where `Html`/`flv` don't exist **and aren't needed** — a DOM text node escapes
   intrinsically. The correct wasm idiom is plain `{label}`, not `{flv(label)}`.

**Conclusion:** author a **parallel client-side set** — standalone `.fitzv` that
import **nothing** from `fitz_liveviews`, live in a flat directory, use `{x}`
(not `{flv(x)}`), `@click`/`@submit` **local** event handlers (not the SSR
`data-flv-click` fall-through), and reuse the **same `--flv-*` tokens + scoped
CSS** so they look identical to the SSR companion UI. This is exactly the shape
the core's `examples/view/*` already use.

### wasm-client capability envelope (what a client component may use)

- State: `Int`/`Float`/`Bool`/`Str` (+ `Nullable`/`List`/`Map` + **sibling**
  nominal types). No tuples/functions/unimported-nominals.
- Events: **sync**, no params (params deferred in core); `@click` + `@submit`
  only; a payload handler gets `payload: &HashMap<String,String>`.
- Control-flow `{#if}` / `{#for}` (iterable must be a bare state-field ident),
  keyed `<Child key=…>` composition, cross-file `<Child/>` (sibling `.fitzv`),
  slots (default + named), payload bubbling.
- Helpers: pure sibling `.fitz` fns that survive the transpiler (**no** `match` /
  loops / `?`, fully annotated). Shared nominals in a sibling `card.fitz`.
- The naive reactivity model re-renders the whole subtree on each state mutation.

## Staging (CW.1 → CW.6 — one focused commit per sub-step)

### CW.1 — Toolchain + first live example on Pages (the "hello WASM" + prove the whole pipeline)
- `examples/wasm-gallery/` (new): one standalone client `.fitzv` (a Counter or a
  Toggle), styled with the `--flv-*` tokens inline, + `index.html` + README +
  a build script (`fitz build --target wasm-client` → `wasm-pack build`).
- **GitHub Pages deploy**: a workflow (extend `docs.yml` or a new `pages-wasm.yml`)
  that runs the wasm-pack build in CI and publishes the `pkg/` + host page to
  Pages (a `/live/` subpath of the existing docs site, or a dedicated deploy).
- Acceptance: open the Pages URL, click the component, it reacts client-side.
- Commit: `feat(wasm): client-WASM toolchain + first live example on GitHub Pages`.

### CW.2 — The client-side component set (the parallel widgets, in themed tandas)
- Author the genuinely-client-interactive components as standalone client `.fitzv`
  (self-contained, `{x}`, `@click`), reusing the SSR look (same `--flv-*` classes):
  candidates — **Counter**, **Toggle/Switch**, **Tabs** (client panel switch),
  **Accordion/ExpansionPanel**, **Rating**, **Stepper**, **Modal** (open/close),
  a small **TodoList** (list + add/remove, exercises `{#for}` + payload).
- No framework import; keep to the capability envelope above.
- Commit per component or per themed tanda.

### CW.3 — The live gallery page (the showcase)
- Compose the client components into one interactive gallery. The wasm entry
  mounts a **single root**, so either: (a) a `Gallery.fitzv` root that composes the
  others via cross-file `<Child/>`, or (b) several bins each mounting into its own
  `#slot`. Add the client-side theme (light/dark) toggle.
- Deploy to Pages.
- Commit: `feat(wasm): live interactive component gallery`.

### CW.4 — Docs + the SSR-vs-client decision matrix
- `docs/client-wasm.md`: when to use SSR (`@ws`, server/DB-driven, shared state)
  vs client-WASM (local, zero-round-trip, offline-capable); how to author a client
  component; embed/link the live gallery.
- Add "▶ see it live" links from `docs/ui-components.md` to the gallery.
- Commit: docs.

### CW.5 — CI + release
- CI: `fitz check --target wasm-client` on the examples (fast); the wasm-pack build
  runs in the Pages job (heavier, like the core's `#[ignore]` build test).
- Release fitz-liveviews (bump) + CHANGELOG + ROADMAP (new phase "client-WASM live
  gallery") + `.vsix` if snippets/grammar changed.

### CW.6 — (optional, CORE) dual-target research
- Assess with the core whether a *subset* of components could share one source
  across SSR + wasm-client. Would need core work: `dep_registry` in the wasm
  loader, an `flv` passthrough (identity) in wasm, and a `data-flv-click` → local
  dispatch bridge. That's `fitz` Phase 11 territory — document findings, open
  core issues if warranted. Not required for the live gallery.

## CW.6 findings (2026-07-30) — dual-target IS feasible for a subset

Research done against the real core code (`fitz/src/view/`). The three
"blockers" from the top of this doc, re-assessed:

1. **Events (`data-flv-click` → local dispatch): already solved.** SSR emits
   `@click="x"` → `data-flv-click="x"` (socket dispatch); the wasm emitter
   already wires BOTH `@click` (local closure) and `data-flv-click` (local
   dispatch, R3.5b). All 38 SSR companion components author events as `@click`
   (none use the raw fall-through), so the convention is already unified — no
   bridge needed.
2. **`flv` passthrough: the one real change, and it is small.** `flv(s: Str) ->
   Str` HTML-escapes for the SSR string-builder. On wasm a `create_text_node` /
   `set_attribute` escapes intrinsically, so `flv` is the IDENTITY. A ~15-LoC
   special-case in `lower_call` (`flv(x)` → `x`) lets an SSR component compile
   to wasm UNCHANGED. The raw-HTML helpers (`html`/`raw_html`/`h_join`/
   `h_when`/`h_either`) inject deliberately-unescaped markup / fold `List<Html>`
   — identity would silently render markup as escaped text, so they HARD-ERROR
   as SSR-only. **Landed in fitz core + validated** (see CW.6 in the ROADMAP).
3. **`dep_registry` in the wasm loader: NOT needed for this subset.** The only
   framework import the companion set brings is `flv` (now special-cased); the
   `from fitz_liveviews import flv` line is already silently skipped by the
   sibling-only loader. `dep_registry` only matters if a shared component
   imports a NON-framework dep helper/nominal (not a sibling) — not the case
   for the companion UI. Deferred.

**Envelope landscape (the subset boundary).** Of the 38 SSR components: NONE
use raw-HTML helpers, and NONE use `@click`/`@submit` (they are presentational
— the parent wires interactivity). So the `flv` passthrough unblocks escaping
for ALL of them; the remaining gate is the existing wasm envelope: `{#if}` /
`{#for}` conditions limited to bool/numeric (no Str comparison / method-call
conditions), iterables must be bare state-field idents, state limited to
primitives / List / Map / sibling nominals, helpers without `match` / loops /
`?`. Pure-presentational primitives (Badge, Chip, ProgressBar, StatCard,
Rating, Tooltip, Divider, Spinner, CountBadge, SortableHeader, ThemeToggle)
dual-target trivially today; components whose `{#if}` uses a Str comparison
(Alert-style `variant == "error"`) or richer helpers stay SSR-only until the
wasm envelope grows.

**Bottom line:** dual-target for the presentational subset is live with a
single small core change. The heaviest-sounding blocker (`dep_registry`) was
unnecessary. The gallery can now grow "for free" from SSR sources that fit the
envelope, instead of hand-authoring parallel client versions.

## Gotchas (carry forward)
- wasm entry mounts the **first-declared** component; `[[bin]] mount="#app"` is
  **required** in `fitz.toml`.
- ES modules don't load over `file://` — serve over HTTP (Pages does this).
- `pkg/` + `target/` are gitignored; the `wasm-crate/` scaffold can be committed
  in-tree so a fresh clone can `wasm-pack build` (the core's counter does this).
- wasm-pack needs `wasm-opt = ['-O', '--enable-bulk-memory']` in the generated
  Cargo.toml (the core emits it) — older binaryen rejects bulk-memory otherwise.
- Pre-reqs on the build machine: `rustup target add wasm32-unknown-unknown` +
  `cargo install wasm-pack`.
