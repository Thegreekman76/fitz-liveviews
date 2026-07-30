# Live client-WASM gallery (CW.1)

The **live, interactive** side of Fitz LiveViews: a `.fitzv` component
compiled to **WebAssembly** and run entirely in the browser — no server,
no WebSocket. This is the first stone of the interactive component gallery
hosted on GitHub Pages.

> **Client-WASM ≠ SSR.** The companion UI (`src/ui/`) is *server-rendered*
> and diffed over a WebSocket. This gallery is a **parallel, client-side
> set**: standalone `.fitzv` that import nothing from `fitz_liveviews`, use
> plain `{count}` interpolation, and wire **local** `@click` handlers. Why
> a parallel set (and not a recompile of the SSR ones) is explained in
> `docs/client-wasm-plan.md`. The two look identical because they share the
> **same `--flv-*` design tokens** — defined once, here in the host page's
> `<head>`, same values as `src/ui/theme.fitz`.

## What's here

```
examples/wasm-gallery/
├── Counter.fitzv     # the source component (state + events + template + scoped style)
├── fitz.toml         # [[bin]] target = "wasm-client", mount = "#app"
├── index.html        # host page: --flv-* tokens + mount point + <script type="module">
├── build.sh          # fitz build --target wasm-client  →  mirror bundle to ./pkg/
└── README.md         # this file
```

Generated (gitignored): `target/` (the wasm-bindgen crate + bundle) and
`pkg/` (the local mirror `build.sh` makes next to `index.html`).

## Build it

Prerequisites (install once per machine):

```
rustup target add wasm32-unknown-unknown
cargo install wasm-pack
cargo install --git https://github.com/Thegreekman76/fitz   # the `fitz` CLI
```

Then:

```
./build.sh            # build + mirror to ./pkg/
./build.sh --serve    # build, then serve on http://localhost:8000
```

`build.sh` runs the real CLI flow:

1. `fitz build --target wasm-client` — runs the view pipeline
   (parse → expand → check → emit) and generates a `wasm-bindgen` +
   `web-sys` crate under `target/wasm-build/counter/`, then invokes
   `wasm-pack build --release --target web` and copies the browser-ready
   bundle to `target/wasm/counter/`.
2. It mirrors that bundle to `./pkg/` (next to `index.html`) so local
   serving and the GitHub Pages `/live/` layout share one relative path
   (`./pkg/counter.js`).

Open `http://localhost:8000/` (an **HTTP** origin — ES modules don't load
over `file://`) and click the buttons. The counter's state lives in Rust
inside the WASM instance; each click re-renders the component subtree.

## On GitHub Pages

The `Docs` workflow (`.github/workflows/docs.yml`) builds this gallery in
CI and publishes it into the docs site under **`/live/`**:

<https://thegreekman76.github.io/fitz-liveviews/live/>

GitHub Pages allows one deployment per repo, so the mkdocs site and the
gallery are assembled into a single artifact (`site/` + `site/live/`) and
deployed together.

## The capability envelope (what a client component may use)

- **State**: `Int` / `Float` / `Bool` / `Str` (+ `Nullable` / `List` /
  `Map` + sibling nominal types). No unimported nominals.
- **Events**: sync, no params; `@click` + `@submit`; a payload handler
  receives `payload: &HashMap<String, String>`.
- **Control flow**: `{#if}` / `{#for}` (iterable is a bare state-field
  ident), keyed `<Child key=…>` composition, cross-file sibling `<Child/>`,
  slots (default + named), payload bubbling.
- Reactivity is naive whole-subtree re-render on each state mutation.

`Counter.fitzv` stays well inside this envelope: `Int` state with a literal
default, sync no-param events whose body is a single assignment (`Int`
literal or arithmetic `BinOp`), and a class-based `<style scoped>`.

## Notes

- `fitz check` does **not** view-parse a `.fitzv` in this fitz version — it
  lexes it as classic Fitz and trips on the CSS. The real gate is
  `fitz build --target wasm-client`, which runs the full view pipeline.
- The mounted root is the **first** component declared in the entry
  `.fitzv`. `mount = "#app"` is mandatory in `fitz.toml` for a wasm-client
  bin (the manifest parser rejects it otherwise).
