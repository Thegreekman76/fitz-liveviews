#!/usr/bin/env bash
# Build the live client-WASM gallery (CW.1).
#
# Runs the real `fitz build --target wasm-client` CLI, which generates a
# wasm-bindgen crate under `target/wasm-build/counter/`, invokes
# `wasm-pack build --release --target web`, and copies the browser-ready
# bundle to `target/wasm/counter/`. We then mirror that bundle to `./pkg/`
# (next to index.html) so local serving and the GitHub Pages `/live/`
# layout share ONE relative path (`./pkg/counter.js`).
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

echo "==> fitz build --target wasm-client"
fitz build --target wasm-client

echo "==> mirror target/wasm/counter -> ./pkg"
rm -rf pkg
mkdir -p pkg
cp target/wasm/counter/counter.js pkg/
cp target/wasm/counter/counter_bg.wasm pkg/
# .d.ts + package.json are informational; copy if present.
cp target/wasm/counter/counter.d.ts pkg/ 2>/dev/null || true
cp target/wasm/counter/counter_bg.wasm.d.ts pkg/ 2>/dev/null || true
cp target/wasm/counter/package.json pkg/ 2>/dev/null || true

echo "==> done. bundle at ./pkg/"
ls -l pkg/counter_bg.wasm | awk '{print "    counter_bg.wasm: "$5" bytes"}'

if [[ "${1:-}" == "--serve" ]]; then
  echo "==> serving on http://localhost:8000 (Ctrl+C to stop)"
  python -m http.server 8000
fi
