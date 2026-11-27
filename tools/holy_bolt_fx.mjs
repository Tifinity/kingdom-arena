import { resolve } from "node:path";
import { pathToFileURL } from "node:url";

const pixelfx = resolve(process.env.PIXELFX_DIR ?? "../pixelfx");
const { fit, rand, smooth, TAU } = await import(pathToFileURL(resolve(pixelfx, "src/core/index.js")));

export const meta = {
  name: "Holy missile",
  desc: "A golden pearl with a bright rim carries a short, softly curling wake of light.",
  tags: ["holy", "orb", "projectile", "loop"],
  size: [104, 48],
  origin: [70, 24],
  duration: 0.6,
  loop: true,
  fps: 30,
  bg: "dark",
  options: { palette: ["#3f222e", "#794724", "#af6928", "#d99238", "#eeba57", "#ffdb7c", "#ffe9a7", "#fff5d3"], seed: 17 },
};

export function draw(p, t, o) {
  const gold = fit(o.palette, 8);
  const phase = t / meta.duration * TAU;

  for (let distance = 50; distance >= 5; distance -= 1) {
    const progress = distance / 50;
    const fade = 1 - smooth(0.13, 1, progress);
    const y = Math.sin(progress * 3.8 - phase) * 5.0 * progress;
    const width = 4.5 * (1 - progress) + 0.8;
    p.disc(-distance, y, width, gold[4], fade * 0.12);
    p.disc(-distance, y - 0.5, 0.7 + width * 0.36, gold[5], fade * 0.18);
    if (distance % 3 === 0) p.disc(-distance, y + 1, width + 2, gold[3], fade * 0.09);
  }

  for (let i = 0; i < 5; i += 1) {
    const age = (t / meta.duration + rand(i, o.seed)) % 1;
    const x = -8 - age * 47;
    const y = Math.sin(phase - i * 2.4) * age * (4 + rand(i, o.seed + 1) * 4);
    const alpha = smooth(0.03, 0.22, age) * (1 - smooth(0.28, 0.97, age));
    p.disc(x, y, 0.6 + (1 - age) * 0.65, gold[i % 2 ? 5 : 4], alpha * 0.54);
  }

  const radius = 8.4 + Math.sin(phase) * 0.25;
  p.glow(0, 0, 15, gold[4], 0.21);
  p.circle(0, 0, radius + 1, gold[2]);
  p.circle(0, 0, radius, gold[3]);
  p.circle(0.8, -1.0, radius - 1.4, gold[4]);
  p.circle(1.5, -1.8, radius - 3.1, gold[5]);
  p.circle(2.6, -2.7, 3.0, gold[6]);
  p.circle(3.6, -3.8, 1.4, gold[7]);
}
