# Live gallery

Twelve real Fitz LiveViews components compiled to **WebAssembly** and running
in **your browser** — no server, no WebSocket. Each widget owns its state in
Rust inside the WASM instance; every interaction reacts client-side. It's all
one bundle (~44 KB gzipped), composed from twelve standalone `.fitzv`.

<div class="live-embed">
  <!--
    The gallery is embedded in an <iframe> on purpose: it's a standalone,
    self-contained page (its own <script type="module"> + wasm). Embedding
    it isolates it from Material's `navigation.instant` SPA loader — a
    direct nav link would get intercepted and mashed into the docs shell.
    Absolute URL keeps it deterministic regardless of directory-URL config.
  -->
  <iframe
    src="https://thegreekman76.github.io/fitz-liveviews/live/"
    title="Fitz LiveViews — live client-WASM gallery"
    loading="lazy"
    style="width:100%; height:760px; border:1px solid var(--md-default-fg-color--lightest); border-radius:8px;">
  </iframe>
</div>

Prefer it full-screen? Open the standalone page directly:
[**thegreekman76.github.io/fitz-liveviews/live/** ↗](https://thegreekman76.github.io/fitz-liveviews/live/){target=_blank}

## Companion UI, dual-targeted (SSR → WASM)

These are **SSR [companion UI](ui-components.md) components** — `Badge`, `Chip`,
`CountBadge`, `StatCard`, `Tooltip`, `Checkbox`, `ExpansionPanel` — compiled to
WebAssembly from their *exact* server-side source, unchanged. One `.fitzv`
targets both SSR (rendered over a WebSocket) and client-WASM: the
[`flv` passthrough](client-wasm.md) makes the HTML-escaping helper a no-op on
the client (a DOM text node escapes intrinsically), so the presentational
components run offline in the browser too — single source, two targets.

<div class="live-embed">
  <iframe
    src="https://thegreekman76.github.io/fitz-liveviews/live/embed/?c=showcase"
    title="Companion UI components compiled to WebAssembly"
    loading="lazy"
    style="width:100%; height:420px; border:1px solid var(--md-default-fg-color--lightest); border-radius:8px;">
  </iframe>
</div>

## How it's built

Each widget is a **standalone client component** — a `.fitzv` that imports
nothing from `fitz_liveviews`, uses plain `{count}` interpolation, and wires
local `@click` handlers. It compiles with the core's client-WASM target:

```bash
fitz build --target wasm-client
```

which emits a `wasm-bindgen` + `web-sys` crate, runs `wasm-pack`, and
produces a `.wasm` bundle. A single component is ~12 KB gzipped; the full
composed gallery (`Gallery.fitzv`, which composes the twelve via cross-file
`<Child/>`) is ~44 KB. The look reuses the same `--flv-*` design tokens as
the server-rendered companion UI, so client and SSR components look identical.

> **Client-WASM vs SSR.** The companion UI (`src/ui/`) is server-rendered
> and diffed over a WebSocket — best for shared/DB-driven state. Client-WASM
> is best for local, zero-round-trip, offline-capable interactivity. The full
> decision matrix, the capability envelope, and a step-by-step authoring guide
> live in **[Client-WASM — offline widgets](client-wasm.md)**.

The source lives in
[`examples/wasm-gallery/`](https://github.com/Thegreekman76/fitz-liveviews/tree/main/examples/wasm-gallery).
