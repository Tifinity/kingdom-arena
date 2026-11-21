import { join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { armorGuardEffects } from "./armor_guard_fx.mjs";

const root = fileURLToPath(new URL("../", import.meta.url));
const pixelfx = resolve(process.env.PIXELFX_DIR ?? join(root, "../pixelfx"));
const core = await import(pathToFileURL(join(pixelfx, "src/core/index.js")));
const { contactSheet, renderAct, save, spriteSheet, writeVideo } = await import(pathToFileURL(join(pixelfx, "tools/lib/fxlib.mjs")));
const preview = process.argv[2];
const { intro, hold } = armorGuardEffects(core);
const { fps, size: [w, h], origin: [ox, oy] } = hold.meta;

function draw(frame, effect, time, layer) {
  const painter = core.painterFor(frame).place(ox, oy);
  const render = layer === "back" ? effect.drawBack : effect.draw;
  render(painter, time, core.resolveOptions(effect.meta));
}

const introCount = Math.round(intro.meta.duration * fps);
const holdCount = Math.round(hold.meta.duration * fps);
const preRoll = 7;
const background = core.backdrop("ground", w, h, oy);
const layers = { back: [], front: [], preview: [] };
for (let index = 0; index < introCount + holdCount; index++) {
  const time = (index - introCount) / fps;
  for (const layer of Object.keys(layers)) {
    const frame = core.createFrame(w, h);
    for (const pass of ["back", "front"]) {
      if (layer !== "preview" && layer !== pass) continue;
      if (layer === "preview" && pass === "front") {
        core.drawActor(core.painterFor(frame).place(ox, oy), core.stockActor());
      }
      if (index >= preRoll) draw(frame, hold, (time + hold.meta.duration) % hold.meta.duration, pass);
      if (index < introCount) draw(frame, intro, index / fps, pass);
    }
    const pixels = core.composite(frame, new Uint8ClampedArray(w * h * 4), layer === "preview" ? background : null);
    layers[layer].push({ t: index / fps, clear: pixels, color: pixels });
  }
}

const effect = { id: "status/armor-guard", mod: hold, meta: hold.meta };
if (preview) {
  const reel = { w, h, fps, frames: layers.preview, n: layers.preview.length };
  const timeline = { ...effect, meta: { ...effect.meta, duration: reel.n / fps, loop: false } };
  save(join(preview, "armor-guard.png"), contactSheet(timeline, reel, { zoom: 3, max: 18 }));
  writeVideo(join(preview, "armor-guard.gif"), reel, 4);
  const act = renderAct({ id: "status/armor-guard-lock", mod: intro, meta: intro.meta }, { fps });
  save(join(preview, "armor-guard-act.png"), contactSheet({ ...timeline, meta: intro.meta }, act, { zoom: 3, max: 18 }));
} else {
  for (const layer of ["back", "front"]) {
    const name = `armor_guard_${layer}`;
    const sheet = spriteSheet(effect, { w, h, fps, frames: layers[layer] }, name);
    save(join(root, "assets/fx/pixelfx", `${name}.png`), sheet.png);
    console.log(`${name}: ${w}x${h}, ${fps} FPS, ${introCount} intro + ${holdCount} loop frames, ${sheet.json.meta.pixelfx.columns} columns, pivot ${ox},${oy}`);
  }
}
