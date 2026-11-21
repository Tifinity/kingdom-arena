// Three high-pressure slugs hit a wooden target in quick succession: each shot leaves the muzzle as a white
// comet, slams the planks and blooms into a crown of water; the board gets wetter and more broken each time.
import { Rng, fit, clamp, smooth, ease, noise2, rand, TAU, WHITE, hex, mix, scale } from "../../core/index.js";
import { WATER, bead, Mist } from "./_lib.js";

export const meta = {
  name: "Pressure volley",
  desc: "Three high-pressure water slugs hit a wooden target in quick succession: each leaves as a white comet, slams the planks and blooms into a crown of water as the board gets wetter.",
  tags: ["water", "pressure", "volley", "gun", "projectile", "impact", "wood", "directional", "one-shot"],
  size: [268, 126],
  origin: [26, 82],
  duration: 1.5,
  loop: false,
  fps: 30,
  bg: "dark",
  options: { palette: WATER, wood: "#7a4c24", target: 204, seed: 19 },
};

const FLOOR = 42, G = 900, HIT_X = 204;
const SHOTS = [
  { t0: 0.035, y: -12, sp: 1900, s: 1, dmg: 1 },
  { t0: 0.265, y: -2, sp: 2000, s: 1.08, dmg: 1 },
  { t0: 0.495, y: -19, sp: 2100, s: 1.4, dmg: 1.6 },
];

export function create(o) {
  const C = fit(o.palette, 8), R = new Rng(o.seed), S = o.seed, X = o.target;
  const wb = hex(o.wood), WD = [scale(wb, 0.22), scale(wb, 0.38), scale(wb, 0.55), scale(wb, 0.75), scale(wb, 1.0), mix(scale(wb, 1.22), WHITE, 0.14)];
  const MT = ["#1a1d24", "#2e3440", "#4a5361", "#6b7685"].map(hex);
  const mist = new Mist();
  const shots = SHOTS.map((q, i) => {
    const travel = (X - 3) / q.sp;
    return { ...q, hit: q.t0 + travel, i };
  });
  const drops = [], chips = [], back = [], ripples = [];
  // water thrown back off each hit
  for (const sh of shots) {
    for (let i = 0; i < 24 + Math.round(14 * sh.s); i++) {
      const a = Math.PI + R.range(-1.2, 1.2), v = R.range(45, 210) * sh.s;
      drops.push({ x: X - 2, y: sh.y + R.range(-1.5, 1.5), vx: Math.cos(a) * v, vy: Math.sin(a) * v, s: R.chance(0.2) ? 3 : R.chance(0.45) ? 2 : 1, t0: sh.hit + R.range(0, 0.1), life: R.range(0.3, 0.8) });
    }
    // splinters of the board
    for (let i = 0; i < 8 + Math.round(4 * sh.dmg); i++) {
      const a = Math.PI + R.range(-0.95, 0.95), v = R.range(55, 190) * sh.s;
      chips.push({ x: X - 1, y: sh.y + R.range(-2, 2), vx: Math.cos(a) * v, vy: Math.sin(a) * v - R.range(20, 90), s: R.range(0.7, 1.7), rot: R.range(0, TAU), t0: sh.hit + R.range(0, 0.04) });
    }
  }
  for (let i = 0; i < 20; i++) {
    const a = Math.PI + R.range(-0.8, 0.8), v = R.range(40, 150);
    back.push({ x: -5, y: R.range(-2, 4), vx: Math.cos(a) * v, vy: Math.sin(a) * v - R.range(0, 40), s: R.chance(0.3) ? 2 : 1, t0: 0.04 + R.range(0, 0.55), life: R.range(0.3, 0.65) });
  }
  const holes = shots.map((sh) => ({ x: X + 4, y: sh.y, r: 3 * sh.dmg, t0: sh.hit }));
  let t = 0;

  function nozzle(p) {
    // a short blued muzzle; each shot kicks it back a few pixels
    let kick = 0;
    for (const sh of shots) kick = Math.max(kick, 4 * Math.exp(-(t - sh.t0) / 0.05) * (t >= sh.t0 ? 1 : 0));
    const kx = -kick;
    p.poly([[kx - 20, -5], [kx - 3, -4], [kx - 3, 4], [kx - 20, 5]], MT[2]);
    p.poly([[kx - 20, -5], [kx - 3, -4], [kx - 3, -1.6], [kx - 20, -2.6]], MT[3]);
    p.line(kx - 20, -5, kx - 3, -4, MT[3]);
    p.line(kx - 20, 5, kx - 3, 4, MT[0]);
    p.rect(kx - 5, -5.5, 4, 11, MT[1]);
    p.rect(kx - 4, -4.5, 2, 9, hex("#070d16"));
    p.arc(kx, 0, 3.6, 1.1, 0.3, TAU - 0.3, (v) => (v > 0.45 ? C[6] : C[3]), 0.8);
  }

  function board(p, fade) {
    if (fade <= 0) return;
    // a plank target: vertical boards, dark seams, two iron bands, lit top edges
    p.shade(X, -44, X + 18, FLOOR, (x, y, out) => {
      if (y > FLOOR) return;
      const seam = (x - X) % 6 === 5;
      let c = x < X + 2 ? WD[4] : x > X + 16 ? WD[1] : WD[3];
      if (seam) c = WD[1];
      if (y > 18) c = x < X + 2 ? WD[3] : WD[2];
      out.c = c;
      out.a = fade;
    });
    for (let x = X + 2; x < X + 18; x += 6) p.line(x, -44, x, FLOOR, WD[0], fade);
    for (const by of [-24, 14]) {
      p.rect(X - 1, by, 20, 4, MT[1], fade);
      p.rect(X - 1, by, 20, 1, MT[2], fade);
      for (let x = X + 3; x < X + 18; x += 7) p.dot(x, by + 2, MT[3], fade);
    }
    // wet streaks and a growing dark stain round each hit
    for (const h of holes) {
      const a = smooth(h.t0, h.t0 + 0.12, t) * fade;
      if (a <= 0) continue;
      p.ellipse(X + 5, h.y, h.r * 1.4, h.r * 1.9, (d) => (d < 0.6 ? hex("#05080e") : WD[0]), a);
      p.disc(X + 1, h.y, 10, C[3], (d) => 0.16 * a * (1 - d * d));
      for (let i = 0; i < 4; i++) {
        const sx = X + 1 + i * 2.2, len = 10 + rand(i, 7, S) * 18;
        for (let k = 0; k < len; k++) p.dot(sx, h.y + 4 + k, k < 2 ? C[5] : C[3], 0.35 * a * (1 - k / len));
      }
    }
    // final shot tears a chunk off the top corner
    const last = shots[2], dmg = smooth(last.hit + 0.03, last.hit + 0.12, t) * fade;
    if (dmg > 0) {
      p.poly([[X + 12, -44], [X + 18, -44], [X + 18, -30], [X + 14, -34]], hex("#0a0c12"), 0.8 * dmg);
      p.line(X + 13, -39, X + 17, -36, WD[5], dmg);
    }
    // water gathers at the foot
    p.ellipse(X + 4, FLOOR, 15 + 9 * dmg, 2.4, (d, a) => (Math.sin(a) < 0 ? C[2] : C[3]), 0.42 * fade);
  }

  function slug(p, sh, x, u) {
    // a white-headed comet with a torn tail, a pressure collar and spray peeling off
    const tail = 26 * sh.s * (0.8 + 0.2 * Math.sin(t * 40 + sh.i));
    for (let d = tail; d >= 0; d -= 1) {
      const f = d / tail, xx = x - d, w = (0.7 + 3.8 * Math.pow(1 - f, 1.6)) * sh.s;
      for (let dy = -Math.ceil(w); dy <= Math.ceil(w); dy++) {
        const q = Math.abs(dy) / Math.max(0.6, w);
        if (q > 1) continue;
        p.px(xx, sh.y + dy, q < 0.22 ? WHITE : q < 0.55 ? C[6] : q < 0.84 ? C[5] : C[3]);
      }
      if (d % 5 === 0) p.light(xx, sh.y, C[4], 0.16);
    }
    p.ellipse(x, sh.y, 5.2 * sh.s, 4 * sh.s, (d, ang) => (d < 0.3 ? WHITE : d < 0.65 ? C[6] : ang < -0.2 ? C[5] : C[4]), 1);
    p.dot(x - 1, sh.y - 1, WHITE);
    p.glow(x, sh.y, 14 * sh.s, C[5], 0.45);
    for (let i = 0; i < 6; i++) {
      const a = R.range(-0.9, 0.9), d = R.range(2, 9);
      bead(p, x - d, sh.y + Math.sin(a) * d, 80, Math.sin(a) * 40, 1, C, 0.5);
    }
  }

  function splash(p, sh, age) {
    const u = age - sh.hit;
    if (u < 0) return;
    const k = 1 - smooth(0.03, 0.26 + 0.06 * sh.s, u), hit = Math.exp(-u / 0.035);
    if (k <= 0) return;
    // a palm of water on the board, then a crown of long blades thrown back
    p.disc(X - 1, sh.y, (7 + 12 * sh.s) * (0.5 + k), (d) => (d < 0.25 ? WHITE : d < 0.58 ? C[6] : C[4]), (d) => 0.4 * k * (1 - d));
    for (let i = 0; i < 11; i++) {
      const a = Math.PI + (i / 10 - 0.5) * 2.2 + Math.sin(i * 2.1) * 0.05;
      const L = (11 + 20 * rand(i, 3, S)) * sh.s * (0.4 + k * 0.8), w = (1.4 + 2.4 * rand(i, 4, S)) * sh.s;
      const ca = Math.cos(a), sa = Math.sin(a), droop = 7 * Math.max(0, u - 0.08);
      p.poly([
        [X - 1 - sa * w, sh.y + ca * w], [X - 1 + ca * L * 0.55 - sa * w * 0.4, sh.y + sa * L * 0.55 + ca * w * 0.4],
        [X - 1 + ca * L, sh.y + sa * L + droop], [X - 1 + ca * L * 0.6 + sa * w * 0.2, sh.y + sa * L * 0.6 + droop * 0.4],
        [X - 1 + sa * w, sh.y - ca * w],
      ], (x, y) => (Math.hypot(x - X, y - sh.y) / Math.max(1, L) > 0.62 ? C[6] : C[5]), 0.9 * k);
      p.line(X - 1 - sa * w, sh.y + ca * w, X - 1 + ca * L, sh.y + sa * L + droop, (v) => (v > 0.5 ? WHITE : C[6]), 0.8 * k);
    }
    if (hit > 0.02) {
      p.circle(X - 1, sh.y, (2.5 + 4 * sh.s) * hit, WHITE, hit);
      p.glow(X - 1, sh.y, 26 * sh.s, C[5], 0.6 * hit);
    }
  }

  return {
    update(dt) {
      t += dt;
      mist.update(dt);
    },
    draw(p) {
      if (t >= meta.duration - 0.03) return;
      const fade = 1 - smooth(meta.duration - 0.22, meta.duration - 0.03, t);
      board(p, fade);
      nozzle(p);
      for (const sh of shots) {
        if (t >= sh.t0 && t < sh.hit) {
          const x = 3 + sh.sp * (t - sh.t0);
          slug(p, sh, x, 0);
          // muzzle flash in the first two frames
          if (t - sh.t0 < 0.055) {
            const k = 1 - (t - sh.t0) / 0.055;
            p.circle(2, sh.y, 5 + 5 * k, C[6], 0.9 * k);
            p.circle(2, sh.y, 2 + 3 * k, WHITE, k);
            p.glow(2, sh.y, 22, C[5], 0.65 * k);
          }
        }
        splash(p, sh, t);
      }
      // water and splinters
      for (const d of drops) {
        const a = t - d.t0;
        if (a < 0 || a > d.life) continue;
        const x = d.x + d.vx * a, y = d.y + d.vy * a + 0.5 * G * a * a;
        if (y > FLOOR) continue;
        bead(p, x, y, d.vx, d.vy + G * a, d.s, C, Math.min(1, (d.life - a) / 0.2) * fade);
      }
      for (const b of chips) {
        const a = t - b.t0;
        if (a < 0 || a > 1.0) continue;
        const x = b.x + b.vx * a, y = b.y + b.vy * a + 0.5 * 950 * a * a;
        if (y > FLOOR) continue;
        const c = Math.cos(b.rot + a * 8), s = Math.sin(b.rot + a * 8), f = Math.min(1, (1 - a) * 3);
        p.line(x - c * b.s, y - s * b.s, x + c * b.s, y + s * b.s, WD[4], f);
        p.dot(x - c * b.s, y - s * b.s - 0.5, WD[5], f);
      }
      for (const d of back) {
        const a = t - d.t0;
        if (a < 0 || a > d.life) continue;
        const x = d.x + d.vx * a, y = d.y + d.vy * a + 0.5 * G * a * a;
        if (y > FLOOR || x < -22) continue;
        bead(p, x, y, d.vx, d.vy + G * a, d.s, C, Math.min(1, (d.life - a) / 0.2) * fade);
      }
      for (const h of holes) {
        const u = t - h.t0;
        if (u < 0 || u > 1.1) continue;
        for (let i = 0; i < 3; i++) {
          const k = (u * 0.8 + i / 3) % 1;
          p.dot(X + 3 + i * 2, h.y + 4 + k * 26, C[4], 0.4 * (1 - k));
        }
      }
      p.glow(X + 2, -10, 36, C[3], 0.14 * fade);
      p.glow(X + 2, 0, 20, C[4], 0.12 * fade);
    },
  };
}
