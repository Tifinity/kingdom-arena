import assert from "node:assert/strict";
import { join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { freezeStatusEffect } from "./freeze_status_fx.mjs";

const root = fileURLToPath(new URL("../", import.meta.url));
const pixelfx = resolve(process.env.PIXELFX_DIR ?? join(root, "../pixelfx"));
const fromPixelfx = path => import(pathToFileURL(join(pixelfx, path)));
const core = await fromPixelfx("src/core/index.js");
const { loadEffect, renderFrames, contactSheet, spriteSheet, save, writeVideo } =
  await fromPixelfx("tools/lib/fxlib.mjs");

const source = await loadEffect("ice/freeze");
const { inPoly } = await fromPixelfx("src/fx/ice/_lib.js");
const mod = freezeStatusEffect(source.mod, core, inPoly);
const effect = { id: "status/arena-freeze", meta: mod.meta, mod };
const preview = process.argv[2];

if (preview) {
  const reference = renderFrames(source);
  save(join(preview, "reference.png"), contactSheet(source, reference, { max: 12, zoom: 1 }));
  const withActor = { ...effect, meta: { ...effect.meta, actor: 2 } };
  const frames = renderFrames(withActor, { options: { actor: core.stockActor(2) } });
  save(join(preview, "arena-freeze.png"), contactSheet(withActor, frames, { max: 16, zoom: 1 }));
  writeVideo(join(preview, "arena-freeze.gif"), frames, 2);
} else {
  const frames = renderFrames(effect, { actor: false });
  assert.ok(frames.frames.at(-1).clear.every((channel, index) => index % 4 !== 3 || channel === 0),
    "Freeze must clear on its final frame");
  const name = "freeze_status";
  const sheet = spriteSheet(effect, frames, name);
  save(join(root, "assets/fx/pixelfx", name + ".png"), sheet.png);
  console.log({ ...sheet.json.meta.pixelfx, shatterFrame: Math.round(mod.freezeDuration * frames.fps) });
}
