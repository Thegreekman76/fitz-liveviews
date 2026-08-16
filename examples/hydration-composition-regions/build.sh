#!/usr/bin/env bash
# Build the hydration-of-composition-with-region demo. Needs Fitz core v0.41.4+.
#   1. fitz run --bin prerender  → server HTML seeding index.html's #app
#   2. fitz build --bin app      → wasm bundle that adopts it (Badge + region)
# Usage: ./build.sh [--serve]
set -euo pipefail
cd "$(dirname "$0")"
BIN=app
echo "==> server HTML (paste under <div id=\"app\"> if the template changed): fitz run --bin prerender"
echo "==> fitz build --bin $BIN"
fitz build --bin "$BIN"
rm -rf pkg && mkdir -p pkg
cp "target/wasm/$BIN/$BIN.js" pkg/
cp "target/wasm/$BIN/${BIN}_bg.wasm" pkg/
cp "target/wasm/$BIN/$BIN.d.ts" pkg/ 2>/dev/null || true
cp "target/wasm/$BIN/${BIN}_bg.wasm.d.ts" pkg/ 2>/dev/null || true
cp "target/wasm/$BIN/package.json" pkg/ 2>/dev/null || true
echo "==> done. bundle at ./pkg/"
[[ "${1:-}" == "--serve" ]] && python -m http.server 8000
