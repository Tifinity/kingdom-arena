// Ground-plane adaptation of pixelfx holy/heal-aoe (Healing ring).
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";

const pixelfx = resolve(process.env.PIXELFX_DIR ?? "../pixelfx");
const fromPixelfx = path => import(pathToFileURL(resolve(pixelfx, path)));
const { clamp, fit, rand, smooth, sparkle, WHITE } = await fromPixelfx("src/core/index.js");
const { plus } = await fromPixelfx("src/fx/holy/_lib.js");

export const radius = 112;
export const meta = {
  name: "Sanctuary healing ring",
  desc: "A seed of mint light blooms into one circular wave, leaving healing marks that dissolve across the floor.",
  tags: ["holy", "heal", "aoe", "ring", "ground"],
  size: [248, 248], origin: [124, 124], duration: 1.2, loop: false, fps: 30, bg: "dark",
  options: { palette: ["#142c28", "#245045", "#34785d", "#60aa78", "#91cf93", "#c5e7a8", "#ecf3c5", "#fff7dc"], seed: 6 },
};

const RELEASE = 0.06;
const TRAVEL = 0.47;

// The same radial clock drives the front and each plus sign's arrival.
const frontAt = t => radius * (1 - (1 - clamp((t - RELEASE) / TRAVEL)) ** 2);
const passedAt = d => RELEASE + TRAVEL * (1 - Math.sqrt(1 - clamp(d / radius)));

export function draw(p, t, o) {
  if (t >= meta.duration) return;
  const colors = fit(o.palette, 8);
  const front = frontAt(t), fade = 1 - smooth(0.62, 0.96, t);
  const seed = (0.5 + 0.5 * smooth(0, RELEASE, t)) * (1 - smooth(0.1, 0.29, t));
  if (seed > 0) {
    p.glow(0, 0, 18, colors[4], 0.38 * seed);
    sparkle(p, 0, 0, 4 + 5 * seed, WHITE, colors[5], seed);
  }

  if (front >= 2 && fade > 0) {
    const clear = 1 - smooth(0.55, 0.94, t);
    p.each(-front, -front, front, front, (x, y, sx, sy) => {
      const distance = Math.hypot(x, y);
      const inset = front - distance;
      if (inset <= 0) return;

      // The wash trails the bright rim, which stays legible as it fades over the stone.
      const age = t - passedAt(distance);
      p.blendPx(sx, sy, colors[4], 0.16 * clear * Math.exp(-age * 4.5));
      if (inset >= 3) return;
      const crest = smooth(0, 0.85, inset) * (1 - smooth(1.2, 3, inset));
      p.blendPx(sx, sy, inset < 1.9 ? colors[6] : colors[4], crest * fade * 0.96);
    });
    for (let i = 0; i < 8; i++) {
      const angle = (i + rand(i, o.seed + 3) * 0.5) * Math.PI / 4 + t * 0.9;
      const x = Math.cos(angle) * (front - 1), y = Math.sin(angle) * (front - 1);
      p.glow(x, y, 9, colors[5], fade * 0.38);
      p.blend(x, y, WHITE, fade * 0.86);
    }
  }

  for (let i = 0; i < 20; i++) {
    const angle = i * 2.3999632297 + rand(i, o.seed) * 0.38;
    const distance = radius * Math.sqrt(0.06 + 0.78 * rand(i, o.seed + 1));
    const elapsed = t - passedAt(distance);
    const life = 0.45 + 0.24 * rand(i, o.seed + 2);
    const alpha = smooth(0, 0.09, elapsed) * (1 - smooth(life * 0.54, life, elapsed));
    if (alpha <= 0) continue;
    const x = Math.cos(angle) * distance, y = Math.sin(angle) * distance;
    const large = i % 5 === 0;
    plus(p, x, y, large ? 4 : 2, large ? 3 : 1, colors, alpha * 0.88);
    p.glow(x, y, large ? 8 : 5, colors[4], alpha * 0.21);
  }
}
