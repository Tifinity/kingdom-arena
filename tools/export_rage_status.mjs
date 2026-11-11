#!/usr/bin/env node
// 把 pixelfx 的 status/seething 导出成“纯光环”精灵表。
//
// 原效果会把替身角色本身重画成发抖、涨红的样子。游戏里的单位已经有自己的精灵，
// 所以这里传入一个空的 24×24 角色遮罩：身体和眼睛不再绘制，只保留怒纹、蒸汽、
// 应激线和红光，叠在真实单位周围。遮罩尺寸决定怒纹/蒸汽相对脚底的高度，
// 24 像素与原作站立角色高度一致（本项目角色也约 24 像素高）。
//
//   PIXELFX_DIR=../pixelfx node tools/export_rage_status.mjs
//
// 输出 assets/fx/pixelfx/elite_orc_rage.png（80×80 网格，36 帧）和同名 JSON。

import { join, resolve } from "node:path";
import { existsSync } from "node:fs";
import { pathToFileURL } from "node:url";

const DIR = resolve(process.env.PIXELFX_DIR ?? "../pixelfx");
if (!existsSync(join(DIR, "tools/lib/fxlib.mjs"))) {
  console.error(`pixelfx not found at ${DIR}; set PIXELFX_DIR to a pixelfx checkout`);
  process.exit(1);
}
const fxlib = await import(pathToFileURL(join(DIR, "tools/lib/fxlib.mjs")));

const fx = await fxlib.loadEffect("status/seething");
const mask = { w: 24, h: 24, data: new Uint8Array(24 * 24) };
const actor = { mask, x: -12, y: -24, w: 24, h: 24 };
const render = fxlib.renderFrames(fx, { actor: false, options: { actor } });
const sheet = fxlib.spriteSheet(fx, render, "elite_orc_rage");

const out = resolve("assets/fx/pixelfx/elite_orc_rage");
fxlib.save(`${out}.png`, sheet.png);
fxlib.save(`${out}.json`, JSON.stringify(sheet.json, null, 2));
console.log(`status/seething -> ${out}.png (${render.frames.length} frames)`);
