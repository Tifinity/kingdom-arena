#!/usr/bin/env node
// 把一个 pixelfx 特效渲染成两张精灵表：角色身后的一层和角色身前的一层。
//
//   PIXELFX_DIR=../pixelfx node tools/pixelfx_split_layers.mjs holy/aegis-ring --out assets/fx/pixelfx/aegis_ring
//
// 输出 <out>_back.png / <out>_front.png 和两份 Aseprite 风格 JSON。地面法阵这类既有地面光斑、
// 又有绕圈立起的光柱的特效，拆层后才能让单位真正站在结界里面。

import { join, dirname, resolve } from "node:path";
import { existsSync } from "node:fs";
import { pathToFileURL } from "node:url";

const args = process.argv.slice(2), flags = {}, ids = [];
for (let i = 0; i < args.length; i++) {
  const a = args[i];
  if (!a.startsWith("--")) ids.push(a);
  else flags[a.slice(2)] = args[++i];
}
if (!ids.length || !flags.out) {
  console.error("usage: node tools/pixelfx_split_layers.mjs <fx id> --out <path without extension>");
  process.exit(1);
}

const DIR = resolve(process.env.PIXELFX_DIR ?? "../pixelfx");
if (!existsSync(join(DIR, "tools/lib/fxlib.mjs"))) {
  console.error(`pixelfx not found at ${DIR}; set PIXELFX_DIR to a pixelfx checkout`);
  process.exit(1);
}
const fxlib = await import(pathToFileURL(join(DIR, "tools/lib/fxlib.mjs")));
const core = await import(pathToFileURL(join(DIR, "src/core/index.js")));

const options = flags.opts ? JSON.parse(flags.opts) : {};
const out = flags.out.replace(/\.png$/, ""), name = out.split("/").pop();

for (const id of ids) {
  const fx = await import(pathToFileURL(join(DIR, "src/fx", `${id}.js`)));
  const [W, H] = fx.meta.size, fps = flags.fps ? +flags.fps : fx.meta.fps;
  const n = Math.max(1, Math.round(fx.meta.duration * fps) + (fx.meta.loop ? 0 : 1));
  const inst = core.createFx(fx, { x: fx.meta.origin[0], y: fx.meta.origin[1], ...options });
  const layers = { back: [], front: [] };
  for (let i = 0; i < n; i++) {
    if (i > 0) inst.update(1 / fps);
    for (const layer of ["back", "front"]) {
      const frame = core.createFrame(W, H);
      inst.draw(frame, layer);
      layers[layer].push({ t: i / fps, clear: core.composite(frame, new Uint8ClampedArray(W * H * 4), null) });
    }
  }
  for (const layer of ["back", "front"]) {
    const sheet = fxlib.spriteSheet({ id, meta: fx.meta, mod: fx }, { w: W, h: H, fps, frames: layers[layer] }, `${name}-${layer}`);
    const png = `${out}_${layer}.png`, json = `${out}_${layer}.json`;
    fxlib.save(png, sheet.png);
    fxlib.save(json, JSON.stringify(sheet.json, null, 1));
    console.log(`${id} ${layer}: ${n} frames ${W}x${H} -> ${png} ${json}`);
  }
}
