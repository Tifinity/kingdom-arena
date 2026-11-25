import { execFileSync } from "node:child_process";
import { join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { meta, redPalette, SOURCE_SIZE, towerDrawing } from "./main_base_tower.mjs";

// Requires pixelfx and Python 3 with Pillow. Pass a directory to render a preview.
const root = fileURLToPath(new URL("../", import.meta.url));
const pixelfx = resolve(process.env.PIXELFX_DIR ?? join(root, "../pixelfx"));
const core = await import(pathToFileURL(join(pixelfx, "src/core/index.js")));
const { contactSheet, renderFrames, save, spriteSheet } = await import(
  pathToFileURL(join(pixelfx, "tools/lib/fxlib.mjs"))
);
const sourcePath = join(root, "artifacts/main_base_tower_source.png");
const source = execFileSync("python3", ["-c", [
  "from PIL import Image",
  "import sys",
  "image = Image.open(sys.argv[1]).convert('RGBA')",
  "if image.size != tuple(map(int, sys.argv[2:])): sys.exit('Unexpected tower crop dimensions')",
  "sys.stdout.buffer.write(image.tobytes())",
].join("\n"), sourcePath, ...SOURCE_SIZE.map(String)]);
const fx = { id: "props/main-base-tower", mod: { meta, draw: towerDrawing(core, source) }, meta };
const blue = renderFrames(fx);
const preview = process.argv[2];
const red = renderFrames(fx, { options: { palette: redPalette, flip: !!preview } });
const teams = { ...blue, frames: [blue.frames[0], red.frames[0]], n: 2 };

if (preview) {
  save(join(preview, "main-base-tower.png"), contactSheet(fx, teams, { title: "MAIN BASE TOWER  /  BLUE + RED", zoom: 3 }));
} else {
  const name = "main_base_tower";
  save(join(root, "assets/fx/pixelfx", name + ".png"), spriteSheet(fx, teams, name).png);
}
