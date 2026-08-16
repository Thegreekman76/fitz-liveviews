#!/usr/bin/env bash
# Build the SSR → client hydration-of-composition demo.
#
#   1. `fitz run --bin prerender`  → server HTML seeding index.html's #app
#      (regenerate + paste when you change App.fitzv's template).
#   2. `fitz build --bin app`      → wasm-client bundle that ADOPTS that DOM
#      (the composed real Badge included). Mirrored to ./pkg/.
#
# Cross-file `<Child />` SSR composition needs Fitz core v0.41.3+.
#
# Prerequisites (once per machine):
#   rustup target add wasm32-unknown-unknown
#   cargo install wasm-pack
#   cargo install --git https://github.com/Thegreekman76/fitz
#
# Usage: ./build.sh [--serve]
set -euo pipefail
cd "$(dirname "$0")"
BIN=app
echo "==> server HTML (paste under <div id=\"app\"> if the template changed):"
echo "    fitz run --bin prerender"
echo "==> fitz build --bin $BIN"
fitz build --bin "$BIN"
echo "==> mirror target/wasm/$BIN -> ./pkg"
rm -rf pkg && mkdir -p pkg
cp "target/wasm/$BIN/$BIN.js" pkg/
cp "target/wasm/$BIN/${BIN}_bg.wasm" pkg/
cp "target/wasm/$BIN/$BIN.d.ts" pkg/ 2>/dev/null || true
cp "target/wasm/$BIN/${BIN}_bg.wasm.d.ts" pkg/ 2>/dev/null || true
cp "target/wasm/$BIN/package.json" pkg/ 2>/dev/null || true
echo "==> done. bundle at ./pkg/"
ls -l "pkg/${BIN}_bg.wasm" | awk -v b="$BIN" '{print "    "b"_bg.wasm: "$5" bytes"}'
if [[ "${1:-}" == "--serve" ]]; then
  echo "==> serving on http://localhost:8000 (Ctrl+C to stop)"
  python -m http.server 8000
fi
