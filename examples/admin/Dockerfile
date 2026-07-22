# Dockerfile for the Admin ABM showcase.
#
# The build context is the fitz-liveviews REPO ROOT (see docker-compose.yml:
# `context: ../..`), not this example's folder — because the example depends
# on the library via a path dependency (`fitz_liveviews = { path = "../.." }`),
# which must be inside the build context. We recreate the repo layout in the
# image so that `../..` resolves to the library during `fitz build`.
#
# Multi-stage:
#   Stage 1 (builder) — official Fitz image (fitz + Rust toolchain); compiles
#     the Fitz source to a native Linux binary.
#   Stage 2 (runtime) — distroless: just glibc + libgcc + ca-certificates.
#     No shell, no package manager.
#
# Pin the Fitz version for reproducibility:
#   docker build --build-arg FITZ_TAG=v0.26.1 ...
# v0.26.1 is the first release with the cross-module `List<Nominal>` codegen
# fix (W19+W20) that lets this app build without importing `Patch` (see
# empleados.fitz — the WS grid uses `WsConn<LiveFrame>` where `LiveFrame`
# has a `List<Patch>` field, and `diff_html` returns `List<Patch>`).

ARG FITZ_TAG=v0.26.1

# ---- Stage 1: builder ------------------------------------------------------
FROM ghcr.io/thegreekman76/fitz:${FITZ_TAG} AS builder

WORKDIR /build

# fitz-liveviews library (the `../..` path dependency).
COPY fitz.toml ./fitz.toml
COPY src ./src

# The admin example itself.
COPY examples/admin/fitz.toml ./examples/admin/fitz.toml
COPY examples/admin/src ./examples/admin/src

# `fitz build` reads the manifest from cwd and emits the binary to
# `target/release/<package.name>` (here: `admin-abm`).
WORKDIR /build/examples/admin
RUN fitz build

# ---- Stage 2: runtime ------------------------------------------------------
FROM gcr.io/distroless/cc-debian12

COPY --from=builder /build/examples/admin/target/release/admin-abm /usr/local/bin/app

# The program binds `@server(3000, "0.0.0.0")`, so `-p 3000:3000` reaches it.
EXPOSE 3000

ENTRYPOINT ["/usr/local/bin/app"]
