// A high-pressure water round goes off at contact: a white heart, a torn radial crown of water, broken pressure
// rings, a short burst of spray and a rain of heavy drops onto the floor.
import { Rng, fit, clamp, smooth, ease, noise2, rand, TAU, WHITE } from "../../core/index.js";
import { WATER, bead, Mist, ring } from "./_lib.js";

export const meta = {
  name: "Hydro shock",
  desc: "A high-pressure water round bursts at contact: a white heart, a torn radial crown of water, broken pressure rings, a burst of spray and heavy drops raining onto the floor.",
  tags: ["water", "pressure", "impact", "burst", "shockwave", "spray", "one-shot"],
  size: [232, 188],
  origin: [116, 133],
  duration: 1.18,
  loop: false,
  fps: 30,
  bg: "dark",
  options: { palette: WATER, radius: 42, seed: 8 },
};

const FLOOR = 48, HIT = 0.045, G = 860, CY = -14;

export function create(o) {
  const C = fit(o.palette, 8), R = new Rng(o.seed), S = o.seed, RAD = o.radius;
  const mist = new Mist(), lights = [], ripples = [];
  const blades = Array.from({ length: 12 }, (_, i) => ({ a: (i / 12) * TAU + R.range(-0.12, 0.12), L: R.range(0.55, 1.15), w: R.range(3.2, 6.4), ph: R.range(0, TAU) }));
  const chunks = Array.from({ length: 9 }, (_, i) => ({ a: R.range(0, TAU), v: R.range(20, 70), r: R.range(1.2, 2.6), delay: R.range(0, 0.08) }));
  const drops = [], puffs = [], shellBubbles = [];
  for (let i = 0; i < 72; i++) {
    const a = R.range(0, TAU), v = R.range(55, 275);
    drops.push({ a, v, s: R.chance(0.16) ? 3 : R.chance(0.4) ? 2 : 1, t0: HIT + R.range(0, 0.12), life: R.range(0.3, 0.95), ph: R.range(0, TAU) });
  }
  for (let i = 0; i < 20; i++) puffs.push({ a: R.range(0, TAU), d: R.range(0, 0.7), r: R.range(4, 10), life: R.range(0.3, 0.7), t0: HIT + R.range(0, 0.08), c: R.chance(0.5) ? C[4] : C[5] });
  for (let i = 0; i < 12; i++) shellBubbles.push({ a: R.range(0, TAU), d: R.range(0.35, 0.86), r: R.range(0.8, 2), ph: R.range(0, TAU) });
  let t = 0;

  return {
    update(dt) {
      t += dt;
      mist.update(dt);
      if (Math.abs(t - HIT) < dt * 0.5) lights.push({ c: C[5], t0: t, life: 0.35, big: true }, { c: WHITE, t0: t, life: 0.1 });
    },
    draw(p) {
      if (t >= meta.duration - 0.02) return;
      const age = t - HIT, fade = 1 - smooth(meta.duration - 0.24, meta.duration - 0.03, t);
      const punch = ease.outCubic(clamp(age / 0.13)), die = 1 - smooth(0.22, 0.82, age);
      const Rr = RAD * punch * die;
      // a short white jet still arriving before the burst
      if (age < 0) {
        const u = clamp((t + 0.07) / (HIT + 0.07));
        for (let x = -78 * u; x < -2; x += 1) {
          const w = 1 + 1.4 * u, q = Math.abs(x + 78 * u) / 30;
          p.px(x, CY, q < 0.5 ? WHITE : C[6]);
          p.dot(x, CY - w, C[5], 0.7 * (1 - q));
          p.dot(x, CY + w, C[5], 0.7 * (1 - q));
        }
        p.glow(-78 * u, CY, 12, C[5], 0.7);
      }
      if (age >= 0 && age < 0.82) {
        // the white foam heart at the centre of the burst
        if (age < 0.5) {
          const ck = 1 - age / 0.5;
          p.circle(0, CY, 5 + 6 * ck, C[5], 0.9 * ck);
          p.circle(0, CY, 2.5 + 3.5 * ck, C[6], 0.95 * ck);
          p.circle(0, CY, 1.2 + 1.8 * ck, WHITE, ck);
          p.glow(0, CY, 16, C[6], 0.25 * ck);
        }
        // the water shell: a translucent dome with a torn rim
        if (Rr > 1) {
          p.disc(0, CY, Rr * 1.04, (d, ang) => (d > 0.78 ? C[5] : d > 0.46 ? C[4] : d < 0.22 ? C[6] : C[5]), (d) => 0.42 * die * (1 - d * d));
          // a torn blue shell, broken into arcs rather than a clean ring
          for (let i = 0; i < 40; i++) {
            const a = (i / 40) * TAU, rr = Rr * (0.9 + 0.12 * noise2(a * 3.1, 1.7, S));
            if (noise2(a * 4.2 + age * 2, 3.3, S) < -0.25) continue;
            p.dot(Math.cos(a) * rr, CY + Math.sin(a) * rr, i % 4 ? C[5] : C[6], 0.75 * die);
          }
          // foam welts on the shell
          for (let i = 0; i < 4; i++) {
            const a = i * 1.7 + age * 1.2, d = Rr * (0.4 + 0.22 * i % 1);
            p.circle(Math.cos(a) * d, CY + Math.sin(a) * d, 3 + i, C[5], 0.8 * die);
            p.dot(Math.cos(a) * d - 1, CY + Math.sin(a) * d - 1, WHITE, 0.8 * die);
          }
          // bubbles caught in the shell
          for (const b of shellBubbles) {
            const a = b.a + age * 0.5;
            p.circle(Math.cos(a) * Rr * b.d, CY + Math.sin(a) * Rr * b.d, b.r, C[6], 0.5 * die);
            p.dot(Math.cos(a) * Rr * b.d - 0.4, CY + Math.sin(a) * Rr * b.d - 0.5, WHITE, 0.6 * die);
          }
        }
        // the crown: broad blades of water thrown out, sagging as they lose their push
        if (age < 0.78) for (const b of blades) {
          const L = Rr * b.L + 6 * die, w = b.w * (0.45 + 0.55 * die) * 1.45;
          if (L < 4) continue;
          const ca = Math.cos(b.a), sa = Math.sin(b.a), droop = 5 * Math.max(0, age - 0.15);
          const bx = ca * 4, by = CY + sa * 4, tx = ca * L, ty = CY + sa * L + droop;
          p.poly([
            [bx - sa * w, by + ca * w],
            [bx + ca * L * 0.45 - sa * w * 0.6, by + sa * L * 0.45 + ca * w * 0.6],
            [tx, ty],
            [bx + ca * L * 0.55 + sa * w * 0.2, by + sa * L * 0.55 + droop * 0.4],
            [bx + sa * w, by - ca * w],
          ], (x, y) => {
            const d = Math.hypot(x, y - CY) / Math.max(1, L);
            return d > 0.72 ? C[5] : d > 0.38 ? C[4] : C[3];
          }, 1);
          p.line(bx - sa * w, by + ca * w, tx, ty, (v) => (v > 0.55 ? WHITE : v > 0.25 ? C[6] : C[5]), 0.85 * die);
          if (L > 24) {
            p.circle(tx, ty, 2 + w * 0.22, (d) => (d > 0.7 ? C[4] : C[6]), 0.85 * die);
            p.dot(tx - 0.6, ty - 0.6, WHITE, 0.85 * die);
            if (sa > 0.2) p.line(tx, ty, tx + ca * 5, ty + 7 + 5 * rand(b.a, 5, S), (v) => (v > 0.4 ? C[6] : C[5]), 0.5 * die);
          }
        }
        // broken pressure rings leave the burst
        if (age < 0.62) {
          for (let j = 0; j < 3; j++) {
            const u = clamp((age - j * 0.055) / 0.42);
            if (u <= 0 || u >= 1) continue;
            const rr = 7 + (RAD + 28) * u, n = 30, k = 1 - u;
            for (let i = 0; i < n; i++) {
              const a = (i / n) * TAU, gap = noise2(a * 3.2 + j * 4, 2.2, S);
              if (gap < -0.45 + u * 0.3) continue;
              p.dot(Math.cos(a) * rr, CY + Math.sin(a) * rr * 0.94, u < 0.35 ? WHITE : C[5], 0.7 * k);
            }
          }
        }
        // the white core sits over the blade roots so the burst never reads as a hole
        if (age < 0.5) {
          const ck = 1 - age / 0.5;
          p.circle(0, CY, 4 + 4.2 * ck, C[5], 1);
          p.circle(0, CY, 2 + 2.5 * ck, C[6], 1);
          p.circle(0, CY, 0.8 + 1.5 * ck, WHITE, 1);
        }
        // water thrown out, then falling
        for (const d of drops) {
          const a = d.a + age * 0.15, v = d.v * (0.7 + 0.3 * d.s) * 0.8, t0 = d.t0 - HIT;
          const aa = age - t0;
          if (aa < 0 || aa > d.life) continue;
          const x = Math.cos(a) * v * aa, y = CY + Math.sin(a) * v * aa + 0.5 * G * aa * aa;
          if (y > FLOOR || x < -95 || x > 95) continue;
          bead(p, x, y, Math.cos(a) * v, Math.sin(a) * v + G * aa, d.s, C, Math.min(1, (d.life - aa) / 0.2));
        }
        // chunks of foam tear off the crown
        for (const q of chunks) {
          const aa = age - q.delay;
          if (aa < 0) continue;
          const x = Math.cos(q.a) * q.v * aa, y = CY + Math.sin(q.a) * q.v * aa + 0.5 * G * aa * aa;
          if (y > FLOOR || x < -95 || x > 95) continue;
          p.circle(x, y, q.r, (d, ang) => (d > 0.7 ? C[4] : ang > 0.2 ? C[5] : C[6]), 0.9 * (1 - smooth(0.4, 1.0, aa)));
          p.dot(x - q.r * 0.4, y - q.r * 0.4, WHITE, 0.7);
        }
        // mist blooms out and sinks
        for (const q of puffs) {
          const aa = age - (q.t0 - HIT);
          if (aa < 0 || aa > q.life) continue;
          const u = aa / q.life, d = (q.d * 20 + aa * 46) * (0.5 + 0.5 * die);
          const x = Math.cos(q.a) * d, y = CY + Math.sin(q.a) * d * 0.8 + aa * 14;
          const rr = q.r * (0.7 + u * 1.3);
          if (y + rr > FLOOR + 2 || x < -95 || x > 95) continue;
          p.disc(x, y, rr, q.c, (dd) => 0.12 * (1 - dd * dd) * (1 - u));
        }
        // flash
        if (age < 0.055) {
          const k = 1 - age / 0.055;
          p.circle(0, CY, 10 + 10 * k, C[6], 0.9 * k);
          p.circle(0, CY, 5 + 6 * k, WHITE, k);
          p.glow(0, CY, 52, C[5], 0.8 * k);
        }
        p.glow(0, CY, RAD * 0.9 + 16, C[4], 0.25 * die);
        p.glow(0, CY, 14, WHITE, 0.2 * die);
      }
      // floor: the burst's rain gathers, rings where it plinks
      const fk = smooth(0.06, 0.3, age) * (1 - smooth(0.9, 1.35, age));
      if (fk > 0) {
        const puddle = smooth(0.16, 0.4, age) * fk;
        if (puddle > 0) {
          p.ellipse(0, FLOOR, 12 + 16 * punch, 2 + 2.4 * punch, (d, a) => (d < 0.5 ? C[2] : C[3]), 0.85 * puddle);
          const prx = 12 + 16 * punch, pry = 2 + 2.4 * punch;
          for (let i = 0; i <= 12; i++) { const a = (i / 12) * Math.PI; p.dot(Math.cos(a) * prx, FLOOR + Math.sin(a) * pry, i % 2 ? C[4] : C[5], 0.6 * puddle); }
          p.ellipse(-2, FLOOR - 0.4, 3 + 4 * punch, 0.6, C[5], 0.45 * puddle);
        }
        for (let i = 0; i < 3; i++) {
          const u = (age * 0.9 + i * 0.3) % 1;
          ring(p, (i - 1) * 15 + Math.sin(i * 2 + age) * 8, FLOOR, 2 + 18 * u, 0.2, 0.45 * (1 - u), C, { n: 1, hot: u < 0.1, glint: 0.2 });
        }
        p.glow(0, FLOOR - 2, 34, C[3], 0.12 * fk);
      }
      for (const l of lights) {
        const u = (t - l.t0) / l.life;
        if (u >= 0 && u < 1) p.glow(0, CY, (l.big ? 34 : 12) * (1 - u * 0.5), l.c, (l.big ? 0.35 : 0.4) * (1 - u));
      }
    },
  };
}
