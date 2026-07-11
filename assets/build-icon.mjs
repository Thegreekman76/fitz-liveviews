// build-icon.mjs — Generates PNGs from the SVG sources.
//
// SVG sources live in this same `assets/` folder (single source of
// truth). We generate:
// - `assets/logo.png`        (256×256) — README and general purposes.
// - `assets/logo-social.png` (1280×640) — GitHub Social Preview
//                                          (upload manually to
//                                           Settings → Social preview).
//
// Uses @resvg/resvg-js — JS bindings for Rust's resvg SVG renderer.
// More reliable than cairosvg on Windows, lighter than sharp (no
// heavy native compilation).
//
// Usage:
//   npm install
//   npm run build:icon

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { Resvg } from "@resvg/resvg-js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

/**
 * Renders an SVG to PNG at the target width and writes it to disk.
 */
function render(svgFile, width, target, { loadSystemFonts = false } = {}) {
  const svg = fs.readFileSync(svgFile, "utf8");
  const resvg = new Resvg(svg, {
    fitTo: { mode: "width", value: width },
    background: "rgba(0, 0, 0, 0)", // transparent
    font: { loadSystemFonts },
  });
  const png = resvg.render().asPng();
  fs.writeFileSync(target, png);
  console.log(`Generated ${target} (${png.length} bytes)`);
}

// Logo 256×256 → README and general purposes.
render(
  path.join(__dirname, "logo.svg"),
  256,
  path.join(__dirname, "logo.png"),
);

// Social preview 1280×640 → GitHub Social Preview (uploaded manually
// to Settings → Social preview). `loadSystemFonts: true` because the
// SVG uses <text> with `Segoe UI, Arial, Helvetica, sans-serif` and
// we need resvg to find one on the host to render it.
render(
  path.join(__dirname, "logo-social.svg"),
  1280,
  path.join(__dirname, "logo-social.png"),
  { loadSystemFonts: true },
);
