import { copyFileSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const outputDirectory = join(root, "dist", ".openai");

mkdirSync(outputDirectory, { recursive: true });
copyFileSync(
  join(root, ".openai", "hosting.json"),
  join(outputDirectory, "hosting.json"),
);

console.log("Copied Sites hosting metadata into dist/.openai.");
