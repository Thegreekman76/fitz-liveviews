# Playground — design spec

> Working design doc for the `.fitzv` **edit-and-preview playground** — the
> feature the [component gallery](examples/gallery.md) is the "seed" for. This is
> a plan, not a shipped feature. It spans two repos: the sandbox work lands in
> **Fitz core** (`fitz`), the playground app in **fitz-liveviews**.
>
> Status: **spec only.** No implementation yet. Written after a feasibility pass
> that changed the picture (see §2).

---

## 1. What it is

A page where you type a `.fitzv` component source into an editor and see it
rendered, live, next to it — the "seed for the future playground" that the
gallery README and `ui-components.md` already gesture at.

The intended home is the **docs site** (GitHub Pages), alongside the gallery. That
makes it **public**, which makes it **execute untrusted code** — anyone can submit
any `.fitzv`. Security is therefore the spine of this whole design, not an
afterthought.

**MVP goal:** source `.fitzv` → the component's **initial SSR HTML**, rendered in
a preview pane. Interactivity (clicking buttons, firing events over `@ws`) is a
later phase — it widens the attack surface and isn't needed to "see the
component".

---

## 2. The feasibility verdict (why this shape)

Two facts from the core investigation decide the architecture:

1. **The view pipeline never produces HTML.** `view::transform_fitzv_source(src)`
   emits **classic Fitz source** (a `String`), not HTML. The HTML only exists
   once that source is *executed* by the interpreter with the `fitz_liveviews`
   library in scope. There is no `render(source) -> html` in the compiler.

2. **The interpreter is not WASM-portable today.** The pure front of the pipeline
   (`parse → expand → check → emit_module_ssr`) could compile to `wasm32`, but it
   only gets you to classic source. Getting to HTML needs the interpreter +
   `fitz_liveviews` runtime, which depend on `tokio (full)`, `axum`, `reqwest`,
   `lettre`, `pyo3` — none `wasm32`-friendly.

| | **Server-side render** | **WASM compiler (in-browser)** |
|---|---|---|
| Path to HTML today | **Exists** — `transform_fitzv_source` → interpret with `fitz_liveviews` → `X_render(state).raw`, all in-process, no rustc | **Doesn't exist** — emitter is wasm-friendly but only yields classic source; runtime isn't portable |
| Security posture | Runs untrusted code on **your** server → needs a sandbox we build | Runs in the **browser's** sandbox → safe by design, no server exposure |
| Hosting | Needs compute (a backend); **can't** run on GitHub Pages | Static; **runs on Pages** with no backend |
| Effort | Sandbox + resource limits (large, delicate) | Port the interpreter to wasm (very large, core refactor) |

**Decision:** build the **server-side** path. WASM is the **north star** — it's
the only way to a truly static, self-securing playground — but it's a core
project of its own and out of scope now. This spec is server-side; §8 keeps WASM
on the record as the eventual target.

---

## 3. Architecture — the render path

The render is a fixed pipeline, all in-process (no compile-to-binary step):

```
untrusted .fitzv source
  │
  ├─ view::transform_fitzv_source(src, "<playground>.fitzv")   → classic Fitz source (String)
  │     (parse → expand → check → emit SSR; returns FitzError on bad input)
  │
  ├─ lexer::tokenize + parser::parse                            → classic AST
  │
  ├─ eval_program_with_env(program, base_dir, RESTRICTED_env, deps)   ← the sandbox lives here
  │     (binds `X_render`, `type X`, etc. into the restricted env)
  │
  ├─ env.get("X_render")  +  Value::new_instance("X", defaults)   → the render fn + a seed state
  ├─ invoke_value(render_fn, [state], "X_render", span)           → Value::Instance { type "Html", raw }
  │
  └─ read the `raw` field                                        → HTML string → preview
```

Every API in that chain is public and confirmed to exist in core
(`view::transform_fitzv_source`, `evaluator::{new_repl_env, eval_program_with_env,
invoke_value}`, `Value::new_instance`). **What's missing is (a) a restricted env,
(b) resource limits, and (c) a convenience wrapper** `render_component_from_string`
so the app doesn't hand-assemble this chain.

**Seed state (MVP):** use the component's declared field **defaults** to build the
initial `state` (the same thing `flv_register` synthesizes as `X {}`). No
user-editable state in the MVP — one less input to validate. Editable/example
state is a later refinement.

**`fitz_liveviews` must resolve.** The emitted source does
`from fitz_liveviews import Html, html`. The restricted env's `dep_registry` must
expose **exactly** `fitz_liveviews` and nothing else (see §4.1).

---

## 4. The sandbox (the hard part — nothing exists yet)

Principle: **defense in depth.** Two independent layers, because the language-level
sandbox *will* have holes (hermetic sandboxing of a full interpreter is a known-hard
problem), and the container/host isolation is the net that catches an escape.

```
Layer 1 — language:  restricted evaluator (no db/http/smtp/env, no arbitrary imports, resource caps)
Layer 2 — host:      isolated container (no internal network, egress off, cgroup limits, hardened runtime)
```

### 4.1 Restricted evaluator (Fitz core, `fitz`)

Today `register_builtins(env)` is fixed and registers **everything**
unconditionally; there is no eval-context struct, no capabilities, no `restricted`
flag. Work to add:

**Disable the dangerous builtins.** These are `Value::Module`s / builtins bound
into the global env; removing (or stubbing) them at registration deactivates them
completely (they're accessed by name/field, not by import):

- `db`, `http`, `smtp` — network / DB egress (the SSRF and data-exfil vectors)
- `env`, `env_or`, `load_env`, `secret`, `config` — environment / secrets
- `spawn`, `ws_broadcast` — concurrency / fan-out
- `jwt`, `hash`, `auth` — not dangerous per se, but no place in a render preview

Mechanism (pick one): a `register_builtins(env, restricted: bool)` param wrapping
each dangerous block in `if !restricted`, **or** register-then-remove (needs a new
`Environment::remove`, which doesn't exist today). Keep `builtin_names()` in sync
either way. Recommendation: explicit param — most auditable.

**Block imports.**
- `from python import …` already has a dedicated branch in the import dispatch →
  make it error in restricted mode.
- **Path allowlist:** the loader canonicalizes every disk import to a `PathBuf`.
  In restricted mode, reject any canonical path that isn't `fitz_liveviews`. The
  user's `.fitzv` may import **only** `fitz_liveviews`; no other file on disk,
  no `../` traversal. The `dep_registry` passed to `eval_program_with_env` should
  contain a single entry.

**Isolate the input from the server.** The playground's own HTTP handler runs with
the full env (it needs `@post`, etc.). The **untrusted render must not reuse that
env.** Evaluate the input in a *separate* `new_repl_env()`-style env built in
restricted mode, with the single-entry `dep_registry`. The server env and the
sandbox env never touch.

### 4.2 Resource limits (Fitz core — **all new**, zero infrastructure today)

The interpreter has **no** limits of any kind right now: no recursion cap, no step
budget, no loop bound, no timeout, no cancellation. A bare `loop {}` in a `.fitzv`
hangs the thread forever. Ranked by importance / ease:

1. **Wall-clock timeout per render** (most important, easiest). Wrap the eval in
   `tokio::time::timeout`, or run it on a thread that gets killed. Kills `loop {}`,
   pathological recursion, and slow renders in one stroke. **Non-negotiable.**
2. **Loop-iteration cap** — a counter on `Stmt::While` / `Stmt::Loop` that errors
   past N iterations. Catches infinite loops even without relying solely on the
   timeout.
3. **Recursion-depth cap** — a counter in `invoke_value` that errors past a depth.
   Catches stack-blowing recursion.
4. **Input/output size caps** — reject source over N KB; cap the produced HTML
   size. Cheap, blocks trivial memory abuse.

Memory is the hard one to bound inside a tree-walker; the container memory limit
(§4.3) is the real backstop for it. The timeout + a memory cgroup covers the
practical DoS surface.

### 4.3 Container / host isolation (fitz-liveviews deploy)

**Docker alone is not a security sandbox** — containers share the host kernel.
It gives process + network isolation, not a hard barrier against a kernel-level
escape. What it *does* give, and must be configured:

- **Isolated network** — the playground container on its **own** Docker network,
  with **no route** to citai / fitzwatch networks or the host's `localhost`, and
  **egress blocked**. This is what kills SSRF-to-internal-services if Layer 1
  leaks. The single most important host-level control.
- **cgroup limits** — `--cpus`, `--memory`, `--pids-limit`. A malicious render
  can't starve neighbors.
- **Hardening** — `--read-only` rootfs, `--cap-drop=ALL`,
  `--security-opt=no-new-privileges`, seccomp, non-root user.
- **Harder runtime** if it shares a host with products — **gVisor (`runsc`)** or a
  microVM runtime (Firecracker/Kata) for *this container only*, to isolate the
  kernel. Fly.io Machines give this by default (Firecracker); on a self-managed
  VPS it's gVisor.

---

## 5. Deployment — where it runs

**GitHub Pages is static** — it serves files, runs no server-side code. The
server-side render therefore **cannot** run on Pages. The playground UI (editor +
preview) is static and *can* live on Pages; the render needs a **separate backend
with compute** that the static frontend calls via `POST /render` (with CORS for
the Pages origin).

### Hosting the backend

**Decision (2026-07-26): a new, separate DigitalOcean droplet.** Physical
separation from citai / fitzwatch means the blast radius of an escape is a
disposable droplet, not the products. Reuses the existing DO account (no new
vendor/card), and the cost is low and predictable (~$4–6/mo). The options
considered:

| Option | Cost | Isolation | Notes |
|---|---|---|---|
| **Separate DO droplet** ✅ chosen | ~$4–6/mo fixed | Physical separation from citai/fitzwatch | Already on DO; blast radius = a disposable droplet. Simplest safe choice. |
| Reuse the citai/fitzwatch VPS | ~$0 marginal | Docker network isolation + gVisor (must configure) | Viable *only* with the §4.3 checklist. Cheapest, most config, highest stakes (products on the same host). Rejected: not worth risking the products. |
| Fly.io Machines | ~$2–5/mo (no free tier since 2024; 2h/7-day trial only, card required) | Firecracker microVM by default | Adds a new account + card. Edge is microVM isolation, not price. Not worth it purely for hosting when already on DO. |

Even on a dedicated droplet the §4.3 controls still apply — the isolated network +
**egress off** is the non-negotiable, because that's the control that survives a
Layer-1 escape. The dedicated droplet just means "if it all goes wrong, only the
playground droplet is lost."

### Abuse controls (public endpoint)

- **Rate limit** `POST /render` per IP.
- **Request size cap** (mirrors §4.2 input cap).
- **Concurrency cap** — a bounded worker pool so N simultaneous renders can't
  exhaust CPU even within the timeout.

---

## 6. Frontend (the playground UI)

Static, Pages-hostable:

- **Editor** — a textarea for the MVP; CodeMirror (small, self-hostable) for
  syntax highlighting later. No Monaco (heavy).
- **Preview** — the returned HTML in a **`sandbox`ed `<iframe>`** (defense in
  depth on the *client* too: the rendered HTML is still untrusted markup).
- **Flow** — debounce edits → `POST /render {source}` → show HTML, or show the
  parse/check/`FitzError` messages the pipeline already returns.
- **Presets** — seed the editor from existing components (the gallery panels, the
  C1–C5 course components) so people start from something that runs.

---

## 7. MVP scope & phases

- **Phase 0 — spec.** This document.
- **Phase 1 — core sandbox (`fitz`).** `register_builtins(env, restricted)` +
  import allowlist + timeout + loop cap + recursion cap + input/output caps +
  a `render_component_from_string(source) -> Result<String>` convenience fn.
  Full unit tests, including *adversarial* ones (`from db import`, `loop {}`,
  deep recursion, `env(...)`, path traversal). **This is the big, delicate work
  and wants a security review.**
- **Phase 2 — backend (fitz-liveviews).** A small Fitz app with `@post("/render")`
  that runs the restricted render, plus rate limit + concurrency cap + size cap.
- **Phase 3 — frontend (fitz-liveviews, static).** Editor + sandboxed-iframe
  preview + presets. Deployable to Pages.
- **Phase 4 — deploy.** Hardened container per §4.3 on the chosen host; CORS;
  wire the Pages frontend to the backend URL.
- **Phase 5 (optional) — interactivity.** Preview reacts to events over `@ws`.
  Bigger attack surface (event bodies run arbitrary logic on every interaction),
  so it comes *after* Phase 1's sandbox is proven.

A lower-risk way to start: build **Phases 1–3 as an internal/local dev-tool
first** (trusted input, no public exposure), which validates the whole render path
without the hostile-input stakes — then harden (Phase 1's adversarial tests +
Phase 4) before going public.

---

## 8. Risks & open decisions

- **Hermetic sandboxing is hard.** Layer 1 will have holes; Layer 2 (egress-off,
  isolated network, hardened runtime) is the real safety net. Don't ship public
  without both.
- **Local-first or public-first?** Building the render path as a local dev-tool
  first de-risks Phase 1 (the code is trusted, like `fitz run`). Decide before
  Phase 2.
- **Seed state:** defaults-only (MVP) vs. user-editable example state (more input
  to validate).
- **Interactivity (Phase 5):** worth the extra surface, or is static preview
  enough for the "see the component" goal?
- **North star — WASM.** The only design that removes the server, the sandbox, and
  the hosting cost all at once (untrusted code runs in the *browser's* sandbox).
  It needs a core interpreter without async/IO compilable to `wasm32` — a large
  core project, but the ideal end state. Revisit if/when the core grows a
  wasm-friendly eval core.

---

## 9. Effort, honestly

- **Phase 1 (core sandbox + limits):** the bulk of the work, and the delicate
  part — it's building an untrusted-code executor in an interpreter that has zero
  isolation today. Wants an adversarial test suite and a security review.
- **Phases 2–4 (app + deploy):** moderate; the pieces (Fitz HTTP app, Docker
  hardening, static frontend) are well-trodden.
- **WASM north star:** very large; a core refactor, separate initiative.

The gating question isn't the UI — it's whether to invest in a hardened
untrusted-code sandbox in Fitz core, or wait for the WASM path that sidesteps it
entirely.
