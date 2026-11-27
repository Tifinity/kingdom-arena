import { resolve } from "node:path";
import { pathToFileURL } from "node:url";

const pixelfx = resolve(process.env.PIXELFX_DIR ?? "../pixelfx");
const { band, ease, fit, smooth } =
  await import(pathToFileURL(resolve(pixelfx, "src/core/index.js")));

export const radius = 80;
export const meta = {
  name: "Skill ground pulse",
  desc: "A thin ripple marks the edge of a single area hit and fades.",
  tags: ["ground", "area", "ring"], size: [176, 176], origin: [88, 88],
  duration: 0.65, loop: false, fps: 30, bg: "dark",
  options: { palette: ["#12312a", "#245249", "#357358", "#58a671", "#84ca80", "#c1e99b", "#ecf5c4", "#fffbe1"] },
};

export function draw(p, t, o) {
  const palette = fit(o.palette, 8).map((color, index, ramp) => ramp[Math.min(index, 5)]);
  const travel = ease.outCubic(smooth(0, 0.18, t));
  const fade = 1 - smooth(0.15, 0.60, t);
  const r = radius * (0.62 + travel * 0.38);
  p.disc(0, 0, r - 2, palette[3], fade * 0.065);
  band(p, 0, 0, r, 1, 0.85, fade * 0.67, palette);
  band(p, 0, 0, r * 0.94, 1, 0.8, fade * 0.48, palette,
    angle => Math.cos(20 * angle) > 0.6);
}
