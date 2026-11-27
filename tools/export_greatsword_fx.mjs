// PIXELFX_DIR=../pixelfx node tools/export_greatsword_fx.mjs [preview-directory]
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const pixelfx = resolve(process.env.PIXELFX_DIR ?? join(root, "../pixelfx"));
const { loadEffect, renderFrames, contactSheet, spriteSheet, save, writeVideo } =
  await import(pathToFileURL(join(pixelfx, "tools/lib/fxlib.mjs")));

const preview = process.argv[2];
function exportEffect(name, effect, { start = 0, options } = {}) {
  const render = renderFrames(effect, { actor: false, options });
  render.frames = render.frames.slice(start);
  render.n = render.frames.length;
  const filename = `greatsword_${name}`;
  if (preview) {
    save(join(preview, filename + ".png"), contactSheet(effect, render, { zoom: 1, max: 16 }));
    writeVideo(join(preview, filename + ".gif"), render, 1);
  } else {
    const sheet = spriteSheet(effect, render, filename);
    save(join(root, "assets/fx/pixelfx", filename + ".png"), sheet.png);
    const { frameSize, frames, columns, pivot, fps } = sheet.json.meta.pixelfx;
    console.log({ filename, frameSize, frames, columns, pivot, fps });
  }
}

const cold = ["#1b2137", "#3a456b", "#5e718f", "#7eabb5", "#a0d5cf", "#cef2e0", "#edfbe5", "#fffbe9"];
const grave = ["#22152c", "#453353", "#725780", "#a27e9b", "#d1afa5", "#e5cbb1", "#f6e5c4", "#fff7db"];
exportEffect("pierce", await loadEffect("melee/thrust"),
  { start: 2, options: { palette: cold, sparks: cold.slice(3, 7).reverse(), light: 0.45 } });
exportEffect("decapitate", await loadEffect("impacts/sword-body-hit"),
  { start: 1, options: { palette: grave, light: 0.3 } });
