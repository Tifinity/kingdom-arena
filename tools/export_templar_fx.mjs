// PIXELFX_DIR=../pixelfx node tools/export_templar_fx.mjs [preview-directory]
import { join, resolve } from "node:path";
import { pathToFileURL } from "node:url";

const pixelfx = resolve(process.env.PIXELFX_DIR ?? "../pixelfx");
const fromPixelfx = (path) => import(pathToFileURL(join(pixelfx, path)));
const { band, ease, fit, rand, smooth, sparkle, TAU, WHITE } = await fromPixelfx("src/core/index.js");
const { GOLD } = await fromPixelfx("src/fx/holy/_lib.js");
const { loadEffect, renderFrames, contactSheet, spriteSheet, save } = await fromPixelfx("tools/lib/fxlib.mjs");

const wardRadius = 64;
const ward = {
  meta: {
    name: "Templar ground ward",
    desc: "A round gold seal expands across the floor, traces eight shield marks, and dissolves into sparks.",
    tags: ["holy", "aegis", "ground", "ring"],
    size: [152, 152],
    origin: [76, 76],
    duration: 2.8,
    loop: false,
    fps: 24,
    bg: "dark",
    options: { palette: GOLD, seed: 9 },
  },
  draw(p, t, o) {
    if (t >= ward.meta.duration) return;
    const gold = fit(o.palette, 8);
    const grow = ease.outCubic(smooth(0, 0.36, t));
    const fade = 1 - smooth(2.12, 2.62, t);
    const radius = wardRadius * (0.2 + 0.8 * grow);

    // Every position is in the ground plane. The arena camera supplies the foreshortening.
    p.disc(0, 0, radius - 3, gold[4], fade * 0.14);
    band(p, 0, 0, radius, 1, 4 - 1.5 * grow, fade, gold, undefined, t < 0.12);
    band(p, 0, 0, radius * 0.86, 1, 1.5, fade * 0.66, gold,
      (angle) => Math.cos(angle * 8) < 0.48);
    const pulse = 1 - smooth(0.13, 0.72, t);
    band(p, 0, 0, radius * (0.25 + 0.58 * grow), 1, 3, pulse * 0.82, gold);
    p.glow(0, 0, radius * 0.9, gold[4], 0.14 * fade + pulse * 0.3);
    if (pulse > 0.15) sparkle(p, 0, 0, pulse * 9, WHITE, gold[5], pulse);

    for (let i = 0; i < 8; i++) {
      const angle = i * TAU / 8;
      const dx = Math.cos(angle), dy = Math.sin(angle);
      const x = dx * radius * 0.89, y = dy * radius * 0.89;
      const size = 2 + grow * 4;
      // Inward-pointing shield glyph, rotated around the circumference.
      const point = (forward, side) => [x + dx * forward - dy * side, y + dy * forward + dx * side];
      const corners = [point(-size, 0), point(-size * 0.15, -size * 0.55),
        point(size * 0.55, -size * 0.55), point(size * 0.55, size * 0.55),
        point(-size * 0.15, size * 0.55)];
      for (let j = 0; j < corners.length; j++) {
        p.line(...corners[j], ...corners[(j + 1) % corners.length], gold[5], fade * 0.85);
      }
      const shimmer = Math.pow(0.5 + 0.5 * Math.cos(t * 8 - angle * 2), 4);
      const rimX = dx * radius, rimY = dy * radius;
      const strength = fade * shimmer;
      const arm = 3 * strength;
      p.line(rimX - arm, rimY, rimX + arm, rimY, gold[6], strength);
      p.line(rimX, rimY - arm, rimX, rimY + arm, gold[6], strength);
      p.glow(rimX, rimY, 6, gold[4], strength * 0.58);
    }

    for (let i = 0; i < 24; i++) {
      const angle = i * TAU / 24 + rand(i, o.seed) * 0.21;
      const delay = rand(i, o.seed + 1) * 0.21;
      const release = smooth(2.04 + delay, 2.70 + delay * 0.35, t);
      const alpha = smooth(0.02 + delay, 0.27 + delay, t) * (1 - release);
      const r = radius * (0.85 + rand(i, o.seed + 2) * 0.14) + release * 7;
      const glint = 0.5 + 0.5 * Math.sin(i * 2.4 + t * 10);
      p.dot(Math.cos(angle) * r, Math.sin(angle) * r, gold[i % 3 + 4], alpha * (0.44 + glint * 0.5));
    }
  },
};

const slash = await loadEffect("melee/radiant-wave");
const bladeGold = ["#3b1d2a", "#7a3a2c", "#b65b24", "#d98420", "#ffb729", "#ffda6b", "#ffed9e", "#fffbe4"];
const slashRender = renderFrames(slash, { actor: false, options: { palette: bladeGold, light: 0.7 } });
// Godot already plays the windup. Retain the release, travelling blade, and short spark tail.
slashRender.frames = slashRender.frames.slice(7, 25);
slashRender.n = slashRender.frames.length;

const ground = { id: "holy/templar-ground-ward", mod: ward, meta: ward.meta };
const out = resolve("assets/fx/pixelfx");
for (const [effect, render, name] of [
  [slash, slashRender, "templar_holy_blade"],
  [ground, renderFrames(ground), "aegis_ring_ground"],
]) {
  const sheet = spriteSheet(effect, render, name);
  save(join(out, name + ".png"), sheet.png);
  if (process.argv[2]) save(join(process.argv[2], name + ".png"), contactSheet(effect, render, { zoom: 1, max: 8 }));
  console.log(`${name}: ${render.n} frames, ${render.w} × ${render.h}, ${sheet.json.meta.pixelfx.columns} columns`);
}
