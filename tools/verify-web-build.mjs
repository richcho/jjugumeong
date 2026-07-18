import {
  existsSync,
  readFileSync,
  statSync,
} from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const game = join(root, "public", "game");
const buildInfo = JSON.parse(
  readFileSync(join(root, "data", "build.json"), "utf8"),
);
const buildLabel = `${buildInfo.product_name} ${buildInfo.version}`;

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function readText(filename) {
  const path = join(game, filename);
  assert(existsSync(path), `Missing Web build file: ${filename}`);
  return readFileSync(path, "utf8");
}

const requiredFiles = [
  "index.html",
  "index.js",
  "index.pck",
  "index.wasm.gz",
  "index.manifest.json",
  "index.service.worker.js",
  "index.offline.html",
  "index.144x144.png",
  "index.180x180.png",
  "index.512x512.png",
];
for (const filename of requiredFiles) {
  const path = join(game, filename);
  assert(existsSync(path), `Missing Web build file: ${filename}`);
  assert(statSync(path).size > 0, `Empty Web build file: ${filename}`);
}

const html = readText("index.html");
for (const token of [
  `name="jjugumeong-build" content="${buildLabel}"`,
  `name="jjugumeong-phase" content="${buildInfo.phase}"`,
  "viewport-fit=cover",
  "width: 100dvw !important",
  "height: 100dvh !important",
  "position: fixed",
  "touch-action: none",
  "controllerchange",
]) {
  assert(html.includes(token), `Missing iPad HTML requirement: ${token}`);
}

const manifest = JSON.parse(readText("index.manifest.json"));
assert(manifest.name === buildInfo.display_name, "PWA display name mismatch");
assert(manifest.display === "standalone", "PWA display must be standalone");
assert(manifest.orientation === "landscape", "PWA orientation must be landscape");
const iconSizes = new Set(manifest.icons.map((icon) => icon.sizes));
for (const size of ["144x144", "180x180", "512x512"]) {
  assert(iconSizes.has(size), `PWA icon is missing: ${size}`);
}

const worker = readText("index.service.worker.js");
for (const token of [
  `const CACHE_VERSION = '${buildLabel}|`,
  '"index.wasm.gz"',
  "self.skipWaiting()",
  "self.clients.claim()",
]) {
  assert(worker.includes(token), `Missing service worker requirement: ${token}`);
}

const engine = readText("index.js");
for (const token of [
  "file.endsWith('.wasm')",
  "DecompressionStream('gzip')",
  "application/wasm",
]) {
  assert(engine.includes(token), `Missing compressed WASM loader requirement: ${token}`);
}

assert(!existsSync(join(game, "index.wasm")), "Uncompressed WASM must not be deployed");
const gzip = readFileSync(join(game, "index.wasm.gz"));
assert(gzip[0] === 0x1f && gzip[1] === 0x8b, "WASM gzip header is invalid");

console.log(
  `Verified ${buildLabel} Web build: viewport, PWA, service worker, and gzip WASM PASS`,
);
