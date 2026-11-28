import assert from "node:assert/strict";
import { join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import * as groundPulse from "./roster_ground_pulse.mjs";
import { arenaStormCloud } from "./wizard_storm_cloud_fx.mjs";

const root = fileURLToPath(new URL("../", import.meta.url));
const pixelfx = resolve(process.env.PIXELFX_DIR ?? join(root, "../pixelfx"));
const { loadEffect, renderFrames, spriteSheet, contactSheet, writeVideo, save } =
  await import(pathToFileURL(join(pixelfx, "tools/lib/fxlib.mjs")));
const preview = process.argv[2];
const output = preview ?? join(root, "assets/fx/pixelfx");
const core = await import(pathToFileURL(join(pixelfx, "src/core/index.js")));
const lightning = await import(pathToFileURL(join(pixelfx, "src/fx/lightning/_lib.js")));
const cloud = arenaStormCloud(await loadEffect("lightning/storm-cloud"), core, lightning);
const strike = await loadEffect("lightning/lightning-strike");
const palette = ["#15233f", "#263f73", "#385ca4", "#5c81db", "#84b3ff", "#bbdeff", "#e4f3ff", "#fffaff"];

function exportFrames(name, effect, rendered) {
  if (preview) {
    save(join(output, name + ".png"), contactSheet(effect, rendered, { max: 12, zoom: 1 }));
    if (rendered.frames.length > 1) writeVideo(join(output, name + ".gif"), rendered, 2);
  } else {
    const sheet = spriteSheet(effect, rendered, name);
    save(join(output, name + ".png"), sheet.png);
    console.log(name, sheet.json.meta.pixelfx);
  }
}

const cloudBody = renderFrames(cloud, { bg: "dark", options: { palette,
  cloud: ["#1d2037", "#292d4b", "#363b61", "#474f79", "#606792", "#7e8bb7", "#a0aed2"] } });
exportFrames("wizard_storm_cloud", cloud, cloudBody);

const strikeFrames = renderFrames(strike, { bg: "dark", options: { palette, light: 0.65 } });
// First impact and flicker only. The source's later bolts and lingering scorch are outside the slice.
strikeFrames.frames = strikeFrames.frames.slice(23, 32).map((frame, index) => {
  const fade = [1, 1, 1, 0.92, 0.78, 0.58, 0.42, 0.20, 0][index];
  for (let pixel = 3; pixel < frame.clear.length; pixel += 4) frame.clear[pixel] *= fade;
  return { ...frame, color: frame.clear };
});
strikeFrames.n = strikeFrames.frames.length;
assert.ok(strikeFrames.frames.at(-1).clear.every((channel, index) => index % 4 !== 3 || channel === 0));
exportFrames("wizard_storm_strike", { ...strike, meta: { ...strike.meta, duration: 0.3 } }, strikeFrames);

const ring = { id: "status/wizard-storm-zone", mod: groundPulse, meta: groundPulse.meta };
const circle = renderFrames(ring, { options: { palette } });
circle.frames = [circle.frames[5]];
circle.n = 1;
exportFrames("wizard_storm_zone", ring, circle);
