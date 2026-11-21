// The column shading is adapted from Sprite Fusion's open-source holy-light
// (https://www.spritefusion.com/pixel-art-vfx/holy-light), MIT License, Copyright (c) 2026 Hugo Duprez.
// A short, brutal cannon of water: a thick, ragged column with a white core and a churning foam head, pressure
// hoops running down it, spray torn off its flanks, and the gun kicked back in its own blowback. The column
// shading follows the same recipe as the geyser's rising column, turned on its side.
import { Rng, fit, clamp, smooth, ease, noise, noise2, rand, TAU, WHITE, hex, mix, scale } from "../../core/index.js";
import { WATER, bead, billow } from "./_lib.js";

export const meta = {
  name: "Pressure blast",
  desc: "A high-pressure water cannon lets go: a thick, ragged column with a white core and a churning foam head, spray torn off its flanks and the gun kicked back in its blowback.",
  tags: ["water", "pressure", "blast", "cannon", "muzzle", "recoil", "spray", "directional", "one-shot"],
  size: [250, 150],
  origin: [33, 100],
  duration: 1.28,
  loop: false,
  fps: 30,
  bg: "dark",
  options: { palette: WATER, metal: "#40536b", reach: 112, seed: 15 },
};

const FLOOR = 44, FIRE = 0.035, G = 900, KICK = 7;

export function create(o) {
  const C = fit(o.palette, 8), R = new Rng(o.seed), S = o.seed, HMAX = o.reach;
  const mb = hex(o.metal), MT = [scale(mb, 0.32), scale(mb, 0.5), scale(mb, 0.7), scale(mb, 0.9), mix(scale(mb, 1.15), WHITE, 0.12), mix(scale(mb, 1.3), WHITE, 0.35)];
  const top = (tt) => {
    if (tt < FIRE) return 0;
    return HMAX * ease.outCubic(clamp((tt - FIRE) / 0.16)) * (0.96 + 0.04 * noise(tt * 2.2, S)) * (1 - ease.inQuad(clamp((tt - 0.55) / 0.5)));
  };
  const headK = (tt) => smooth(FIRE + 0.04, FIRE + 0.18, tt) * (1 - smooth(0.6, 0.95, tt));
  const spray = Array.from({ length: 32 }, () => ({ u: R.range(0.2, 1), off: R.sign() * R.range(0.8, 1.3), v: R.range(20, 90), s: R.chance(0.3) ? 2 : 1, ph: R.range(0, TAU) }));
  const drops = [], back = [], floorDrops = [];
  for (let i = 0; i < 52; i++) {
    const a = R.range(-0.7, 0.7), v = R.range(55, 240);
    drops.push({ x: R.range(20, 80), y: R.range(-4, 4), vx: Math.cos(a) * v, vy: Math.sin(a) * v * 0.8 + R.range(-15, 35), s: R.chance(0.18) ? 3 : R.chance(0.42) ? 2 : 1, t0: 0.07 + R.range(0, 0.35), life: R.range(0.25, 0.7) });
  }
  for (let i = 0; i < 24; i++) {
    const a = Math.PI + R.range(-0.82, 0.82), v = R.range(45, 200);
    back.push({ x: R.range(-7, 0), y: R.range(-2, 5), vx: Math.cos(a) * v, vy: Math.sin(a) * v - R.range(0, 45), s: R.chance(0.3) ? 2 : 1, t0: 0.035 + R.range(0, 0.09), life: R.range(0.3, 0.68) });
  }
  for (let i = 0; i < 18; i++) {
    const a = -Math.PI * R.range(0.15, 0.85), v = R.range(30, 115);
    floorDrops.push({ x: 92 + R.range(-22, 20), y: FLOOR - 1, vx: Math.cos(a) * v, vy: Math.sin(a) * v - R.range(35, 110), s: R.chance(0.3) ? 2 : 1, t0: 0.14 + R.range(0, 0.25), life: R.range(0.3, 0.68) });
  }
  let t = 0;

  function column(p, H, thin) {
    if (H < 1) return;
    // banded white core to blue flanks, shadowed underneath, water strands racing down its length
    p.shade(-4, -26, H + 4, 26, (x, y, out) => {
      const v = Math.max(0, x) / Math.max(1, H), sway = noise(t * 1.6 + x * 0.025, S + 5) * 2.2 * v;
      const rag = noise2(x * 0.2 - t * 11, y < sway ? 3 : 7, S + 6) * (0.6 + 1.8 * v);
      const taper = 1 - smooth(0.86, 1, v) * 0.9;
      const w = ((4.4 + 12 * Math.pow(v, 1.7)) * thin + rag) * taper;
      const q = (y - sway) / Math.max(1, w), aq = Math.abs(q);
      if (aq > 1) return;
      const streak = noise2(Math.floor(y + 40) * 1.618 + 0.3, (x * 0.018 - t) * 14, S);
      const body = noise2(Math.floor((y + 40) / 2) * 2.3, (x * 0.018 - t) * 5, S + 1);
      let lvl = aq < 0.16 ? 0 : aq < 0.42 ? 1 : aq < 0.7 ? 2 : aq < 0.9 ? 3 : 4;
      if (q > 0.35) lvl++;
      if (streak > 0.3) lvl--;
      if (body < -0.42) lvl++;
      out.c = [WHITE, C[6], C[5], C[4], C[3]][clamp(lvl, 0, 4)];
    });
    p.glowLine(0, 0, H, 0, 13 + 7 * thin, C[5], 0.12 * thin);
    // torn droplets hanging off the flanks
    for (const q of spray) {
      const x = q.u * H, w = (4.4 + 12 * Math.pow(q.u, 1.7)) * thin;
      const y = q.off * w + noise(t * 2 + q.ph, S + 8) * 2;
      const a = Math.max(0, t - FIRE - q.u * 0.07);
      const sx = x + q.v * a, sy = y + a * a * 70 * (q.off > 0 ? 1 : -0.15);
      if (sy > FLOOR || sx > H + 24) continue;
      bead(p, sx, sy, q.v, 0, q.s, C, 0.5 * thin);
    }
  }

  function head(p, H, k, backHalf) {
    if (k <= 0.01 || H < 3) return;
    // the umbrella: water pours off the crown and falls back along the column
    if (!backHalf) {
      for (let i = 0; i < 15; i++) {
        const side = i % 2 ? 1 : -1, y0 = side * (5 + 8 * rand(i, S + 20)) * k, len = (12 + 24 * rand(i, S + 21)) * k;
        const speed = 70 + 50 * rand(i, S + 22);
        for (let j = 0; j < 3; j++) {
          const f = (t * speed / len + j / 3 + rand(i, S + 23)) % 1;
          const x0 = H - 2 - f * len, y = y0 + side * f * f * 7;
          if (f < 0.88) p.line(x0, y, x0 - 1.2, y + side * 0.6, f < 0.4 ? C[6] : f < 0.7 ? C[5] : C[4]);
        }
      }
    }
    // a churning crown of foam billows round the end
    for (let i = 0; i < 15; i++) {
      const a = (i / 15) * TAU + t * (i % 2 ? 1.2 : -1), z = Math.sin(a);
      if (z < -0.35 !== backHalf) continue;
      const rho = (4 + 8 * rand(i, S)) * k;
      const x = H + Math.cos(a) * rho * 0.9 + noise(t * 3 + i, S + 8) * 2.5;
      const y = z * rho * 0.6 + noise(t * 3 + i + 50, S + 9) * 2.2;
      const r = (2.4 + 3.2 * rand(i, S + 2) + 0.7 * Math.sin(t * 7 + i)) * k;
      if (backHalf) billow(p, x, y, r, [C[0], C[1], C[2], C[3], C[3], C[4], C[5], C[5]]);
      else {
        p.circle(x + r * 0.12, y + r * 0.22, r, C[4]);
        p.circle(x, y, r * 0.82, rho > 7 * k ? C[5] : C[6]);
        p.circle(x - r * 0.25, y - r * 0.3, r * 0.5, WHITE);
      }
    }
    if (!backHalf) {
      // the head tears forward: short white spokes hide the cut and throw beads
      for (let i = 0; i < 11; i++) {
        const a = (i / 10 - 0.5) * 1.55 + noise(t * 2 + i, S + 30) * 0.08;
        const len = (7 + 20 * rand(i, S + 31)) * k, ca = Math.cos(a), sa = Math.sin(a);
        p.line(H - 2, noise(t * 3 + i, S + 32) * 3, H + ca * len, sa * len * 0.9, (v) => (v > 0.55 ? WHITE : v > 0.2 ? C[6] : C[5]), 0.9 * k);
        if (len > 16) bead(p, H + ca * (len + 2), sa * (len + 2) * 0.9, ca * 90, sa * 90, 1, C, 0.7 * k);
      }
      for (let i = 0; i < 4; i++) p.disc(H + 6 + i * 4, Math.sin(i * 2.3 + t * 2) * 6, 5 + i * 2, C[5], (d) => 0.08 * k * (1 - d * d));
      p.glow(H, -1, 34, C[5], 0.34 * k);
      p.glow(H + 2, 0, 10, WHITE, 0.28 * k);
    }
  }

  function splash(p, age) {
    const u = age - 0.1;
    if (u < 0) return;
    const k = 1 - smooth(0.18, 0.72, u), spread = 5 + 42 * ease.outCubic(clamp(u / 0.15));
    p.ellipse(92, FLOOR, spread, 2 + spread * 0.055, (d, a) => (Math.sin(a) < 0 ? C[2] : C[3]), 0.42 * k);
    const crown = 1 - smooth(0.1, 0.45, u);
    if (crown > 0) {
      for (let i = 0; i < 7; i++) {
        const a = -Math.PI * (0.12 + i * 0.11), L = 5 + 12 * rand(i, 4, S), x0 = 88 + rand(i, 5, S) * 12;
        p.circle(x0 + Math.cos(a) * L * 0.7, FLOOR + Math.sin(a) * L * crown, 1.3 + 1.8 * crown, i % 2 ? C[6] : WHITE, 0.8 * crown);
      }
      p.ellipse(90, FLOOR, 6 + 13 * crown, 2.1, (d) => (d < 0.5 ? WHITE : C[5]), 0.55 * crown);
    }
    p.glow(92, FLOOR - 2, 26, C[4], 0.14 * k);
  }

  function muzzle(p, age) {
    const kick = KICK * ease.outCubic(clamp(age / 0.04)) * (1 - smooth(0.05, 0.5, age));
    const kx = -kick, ky = -kick * 0.35;
    const nf = 1 - smooth(meta.duration - 0.16, meta.duration - 0.03, t);
    p.poly([[kx - 23, ky - 8], [kx - 4, ky - 5.5], [kx - 4, ky + 5.5], [kx - 23, ky + 8]], MT[2], nf);
    p.poly([[kx - 23, ky - 8], [kx - 4, ky - 5.5], [kx - 4, ky - 2], [kx - 23, ky - 3.4]], MT[4], nf);
    p.poly([[kx - 23, ky + 8], [kx - 4, ky + 5.5], [kx - 4, ky + 2], [kx - 23, ky + 3.4]], MT[1], nf);
    p.rect(kx - 7, ky - 8, 7, 16, MT[3], nf);
    p.rect(kx - 6, ky - 6.5, 3.5, 13, hex("#070d16"), nf);
    p.arc(kx, ky, 5.2, 1.6, -0.5, TAU + 0.5, (v) => (v > 0.45 ? C[6] : C[3]), 0.85 * nf);
    p.line(kx - 23, ky - 8, kx - 4, ky - 5.5, MT[5], nf);
    p.line(kx - 23, ky + 8, kx - 4, ky + 5.5, MT[0], nf);
    for (const bx of [-18, -12]) p.line(kx + bx, ky - 6.5, kx + bx, ky + 6.5, MT[1], nf);
    if (age >= 0) {
      const k = Math.exp(-age / 0.11);
      p.ring(kx, ky, 5.8, 1.4, C[6], 0.75 * k);
      p.glow(kx, ky, 17, C[5], 0.55 * k);
      p.glow(kx, ky, 6, WHITE, 0.45 * k);
    }
  }

  return {
    update(dt) {
      t += dt;
    },
    drawBack(p) {
      head(p, top(t), headK(t), true);
    },
    draw(p) {
      if (t >= meta.duration) return;
      const age = t - FIRE, H = top(t), hk = headK(t), thin = smooth(FIRE, FIRE + 0.14, t) * (1 - 0.55 * smooth(0.55, 0.95, t));
      column(p, H, thin);
      head(p, H, hk, false);
      splash(p, age);
      muzzle(p, age);
      if (age >= -0.005 && age < 0.06) {
        const k = 1 - clamp((age + 0.005) / 0.065);
        p.circle(3, 0, 9 + 9 * k, C[6], 0.9 * k);
        p.circle(3, 0, 5 + 5 * k, WHITE, k);
        p.glow(4, 0, 50, C[5], 0.8 * k);
      }
      for (const d of drops) {
        const a = t - d.t0;
        if (a < 0 || a > d.life) continue;
        const x = d.x + d.vx * a, y = d.y + d.vy * a + 0.5 * G * a * a;
        if (y > FLOOR || x > HMAX + 35) continue;
        bead(p, x, y, d.vx, d.vy + G * a, d.s, C, Math.min(1, (d.life - a) / 0.2));
      }
      for (const d of back) {
        const a = t - d.t0;
        if (a < 0 || a > d.life) continue;
        const x = d.x + d.vx * a, y = d.y + d.vy * a + 0.5 * G * a * a;
        if (y > FLOOR || x < -26) continue;
        bead(p, x, y, d.vx, d.vy + G * a, d.s, C, Math.min(1, (d.life - a) / 0.2));
      }
      for (const d of floorDrops) {
        const a = t - d.t0;
        if (a < 0 || a > d.life) continue;
        const x = d.x + d.vx * a, y = d.y + d.vy * a + 0.5 * G * a * a;
        if (y > FLOOR || x < -26) continue;
        bead(p, x, y, d.vx, d.vy + G * a, d.s, C, Math.min(1, (d.life - a) / 0.2));
      }
      p.glow(92, FLOOR - 2, 28, C[3], 0.12 * (1 - smooth(0.2, 0.8, age)));
      p.glow(4, 0, 32, C[4], 0.2 * Math.exp(-Math.max(0, age) / 0.16));
      p.glow(HMAX * 0.8, 0, 24, C[4], 0.12 * hk);
    },
  };
}
