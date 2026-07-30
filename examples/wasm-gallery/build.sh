#!/usr/bin/env bash
# Build the live client-WASM gallery.
#
# Runs the real `fitz build --bin gallery` CLI, which generates a
# wasm-bindgen crate under `target/wasm-build/gallery/`, invokes
# `wasm-pack build --release --target web`, and copies the browser-ready
# bundle to `target/wasm/gallery/`. We then mirror that bundle to `./pkg/`
# (next to index.html) so local serving and the GitHub Pages `/live/`
# layout share ONE relative path (`./pkg/gallery.js`).
#
# `Gallery.fitzv` composes all eight component `.fitzv` into one bundle.
# To preview a single component instead, run e.g. `fitz build --bin toggle`.
#
# Prerequisites (install once per machine):
#   rustup target add wasm32-unknown-unknown
#   cargo install wasm-pack
#   cargo install --git https://github.com/Thegreekman76/fitz   # the `fitz` CLI
#
# Usage:
#   ./build.sh            # build
#   ./build.sh --serve    # build, then serve on http://localhost:8000
set -euo pipefail

cd "$(dirname "$0")"

BIN=gallery

echo "==> fitz build --bin $BIN"
fitz build --bin "$BIN"

echo "==> mirror target/wasm/$BIN -> ./pkg"
rm -rf pkg
mkdir -p pkg
cp "target/wasm/$BIN/$BIN.js" pkg/
cp "target/wasm/$BIN/${BIN}_bg.wasm" pkg/
# .d.ts + package.json are informational; copy if present.
cp "target/wasm/$BIN/$BIN.d.ts" pkg/ 2>/dev/null || true
cp "target/wasm/$BIN/${BIN}_bg.wasm.d.ts" pkg/ 2>/dev/null || true
cp "target/wasm/$BIN/package.json" pkg/ 2>/dev/null || true

echo "==> done. bundle at ./pkg/"
ls -l "pkg/${BIN}_bg.wasm" | awk -v b="$BIN" '{print "    "b"_bg.wasm: "$5" bytes"}'

if [[ "${1:-}" == "--serve" ]]; then
  echo "==> serving on http://localhost:8000 (Ctrl+C to stop)"
  python -m http.server 8000
fi
