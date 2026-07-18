import {
  cpSync,
  existsSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  rmSync,
  unlinkSync,
  writeFileSync,
} from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { gzipSync } from "node:zlib";

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const source = join(root, "builds", "web");
const destination = join(root, "public", "game");

if (!existsSync(join(source, "index.html"))) {
  throw new Error(
    "Godot Web build not found. Export builds/web/index.html before preparing hosting files.",
  );
}

rmSync(destination, { recursive: true, force: true });
mkdirSync(destination, { recursive: true });
cpSync(source, destination, { recursive: true });
for (const filename of readdirSync(destination)) {
  if (filename.endsWith(".import")) {
    unlinkSync(join(destination, filename));
  }
}

const wasmPath = join(destination, "index.wasm");
const compressedWasmPath = `${wasmPath}.gz`;
const wasm = readFileSync(wasmPath);
writeFileSync(compressedWasmPath, gzipSync(wasm, { level: 9 }));
unlinkSync(wasmPath);

const enginePath = join(destination, "index.js");
let engine = readFileSync(enginePath, "utf8");
const originalFetch = `\t\treturn fetch(file).then(function (response) {
\t\t\tif (!response.ok) {
\t\t\t\treturn Promise.reject(new Error(\`Failed loading file '\${file}'\`));
\t\t\t}
\t\t\tconst tr = getTrackedResponse(response, tracker[file]);`;
const compressedFetch = `\t\tconst requestFile = file.endsWith('.wasm') ? \`\${file}.gz\` : file;
\t\treturn fetch(requestFile).then(function (response) {
\t\t\tif (!response.ok) {
\t\t\t\treturn Promise.reject(new Error(\`Failed loading file '\${requestFile}'\`));
\t\t\t}
\t\t\tif (file.endsWith('.wasm')) {
\t\t\t\tif (typeof DecompressionStream === 'undefined' || response.body == null) {
\t\t\t\t\treturn Promise.reject(new Error('This browser cannot decompress the WebAssembly build.'));
\t\t\t\t}
\t\t\t\tresponse = new Response(
\t\t\t\t\tresponse.body.pipeThrough(new DecompressionStream('gzip')),
\t\t\t\t\t{ headers: { 'Content-Type': 'application/wasm' } },
\t\t\t\t);
\t\t\t}
\t\t\tconst tr = getTrackedResponse(response, tracker[file]);`;

if (!engine.includes(originalFetch)) {
  throw new Error("Godot engine loader shape changed; gzip patch was not applied.");
}
engine = engine.replace(originalFetch, compressedFetch);
writeFileSync(enginePath, engine);

const htmlPath = join(destination, "index.html");
let html = readFileSync(htmlPath, "utf8");
const originalViewport =
  '<meta name="viewport" content="width=device-width, user-scalable=no, initial-scale=1.0">';
const iPadViewport =
  '<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover">';
const originalCanvasStyle = `#canvas {
\tdisplay: block;
}`;
const responsiveCanvasStyle = `#canvas {
\tdisplay: block;
\tposition: fixed;
\tinset: 0;
\twidth: 100vw !important;
\theight: 100vh !important;
\twidth: 100dvw !important;
\theight: 100dvh !important;
\tmax-width: 100%;
\tmax-height: 100%;
}`;
const originalBodyStyle = `body {
\tcolor: white;
\tbackground-color: black;
\toverflow: hidden;
\ttouch-action: none;
}`;
const responsiveBodyStyle = `html, body {
\twidth: 100%;
\theight: 100%;
\toverflow: hidden;
\toverscroll-behavior: none;
}

body {
\tcolor: white;
\tbackground-color: black;
\tposition: fixed;
\tinset: 0;
\toverflow: hidden;
\ttouch-action: none;
\t-webkit-text-size-adjust: 100%;
}`;

if (
  !html.includes(originalViewport) ||
  !html.includes(originalCanvasStyle) ||
  !html.includes(originalBodyStyle)
) {
  throw new Error("Godot HTML shell shape changed; iPad viewport patch was not applied.");
}
html = html
  .replace(originalViewport, iPadViewport)
  .replace(originalBodyStyle, responsiveBodyStyle)
  .replace(originalCanvasStyle, responsiveCanvasStyle);
writeFileSync(htmlPath, `${html.trimEnd()}\n`);

const workerPath = join(destination, "index.service.worker.js");
let worker = readFileSync(workerPath, "utf8");
const originalCacheable = `const CACHEABLE_FILES = ["index.wasm","index.pck"];`;
const compressedCacheable = `const CACHEABLE_FILES = ["index.wasm.gz","index.pck"];`;

if (!worker.includes(originalCacheable)) {
  throw new Error("Godot service worker shape changed; gzip cache patch was not applied.");
}
worker = worker.replace(originalCacheable, compressedCacheable);
writeFileSync(workerPath, `${worker.trimEnd()}\n`);

console.log(
  `Prepared iPad Web build: ${(wasm.length / 1024 / 1024).toFixed(1)} MiB WASM -> ` +
    `${(readFileSync(compressedWasmPath).length / 1024 / 1024).toFixed(1)} MiB gzip`,
);
