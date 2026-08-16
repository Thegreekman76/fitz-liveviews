#!/usr/bin/env bash
# Build the SSR → client hydration demo (Phase 11).
#
# ONE source, TWO compilations:
#   1. `fitz run --bin prerender`  → the server HTML that seeds index.html's
#      `#app` (regenerate + paste when you change App.fitzv's template).
#   2. `fitz build --bin app`      → the wasm-client bundle that ADOPTS that
#      server DOM on boot. Lands at `target/wasm/app/app.js` + `app_bg.wasm`;
#      we mirror it to `./pkg/` so index.html serves one relative path
#      (`./pkg/app.js`).
#
# Prerequisites (install once per machine):
#   rustup target add wasm32-unknown-unknown
#   cargo install wasm-pack
#   cargo install --git https://github.com/Thegreekman76/fitz   # the `fitz` CLI
#
# Usage:
#   ./build.sh            # regenerate server HTML note + build wasm + mirror
#   ./build.sh --serve    # build, then serve on http://localhost:8000
set -euo pipefail

cd "$(dirname "$0")"

BIN=app

echo "==> server HTML (paste under <div id=\"app\"> in index.html if the template changed):"
echo "    fitz run --bin prerender"

echo "==> fitz build --bin $BIN"
fitz build --bin "$BIN"

echo "==> mirror target/wasm/$BIN -> ./pkg"
rm -rf pkg
mkdir -p pkg
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
