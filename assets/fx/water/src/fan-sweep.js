// A pressure fan sweeps a wall: a sheet of jets plays up and down, the impact point races across the stone,
// water sheets off it and the wall stays soaked. Everything is a function of the phase, so the loop is seamless.
import { fit, clamp, smooth, ease, noise2, rand, TAU, WHITE, hex, scale, mix } from "../../core/index.js";
import { WATER, bead, Mist, ring } from "./_lib.js";

export const meta = {
  name: "Fan sweep",
  desc: "A high-pressure fan sweeps a stone wall: a sheet of jets plays up and down, the bright impact point races across the stone, water sheets off it and the wall stays soaked.",
  tags: ["water", "pressure", "fan", "sweep", "wall", "spray", "directional", "loop"],
  size: [300, 154],
  origin: [20, 82],
  duration: 2.2,
  loop: true,
  fps: 30,
  bg: "dark",
  options: { palette: WATER, stone: "#52627c", wall: 210, sweep: 0.095, width: 0.17, seed: 21 },
};

const FLOOR = 52;

export function draw(p, t, o) {
  const C = fit(o.palette, 8), X = o.wall, S = o.seed, ph = t / meta.duration, T = ph * TAU;
  const aim = Math.sin(T) * o.sweep;
  const wallTop = -62, wallBot = FLOOR, wallW = 20;
  const sb = hex(o.stone);
  const ST = [scale(sb, 0.12), scale(sb, 0.2), scale(sb, 0.3), scale(sb, 0.44), scale(sb, 0.64), mix(scale(sb, 0.92), WHITE, 0.18)];
  const impactY = Math.tan(aim) * X;
  const hitFloor = impactY > FLOOR - 2;
  // the barrel and its collar
  p.rect(-18, -5, 17, 10, hex("#1b2532"));
  p.rect(-18, -5, 17, 2, hex("#3e5268"));
  p.rect(-18, 3, 17, 2, hex("#0c1219"));
  p.rect(-4, -6.5, 5, 13, hex("#2a3747"));
  p.rect(-3, -5.5, 2.6, 11, hex("#060b12"));
  p.arc(0, 0, 4.4, 1.3, 0.3, TAU - 0.3, (v) => (v > 0.4 ? C[6] : C[3]), 0.8);
  // stone wall: dark block, lit near lip, wet streaks and a bright splash band that tracks the fan
  p.shade(X, wallTop, X + wallW, wallBot, (x, y, out) => {
    if (y > wallBot) return;
    const seam = ((y + 54) % 13 === 0) || ((x - X + (Math.floor((y + 54) / 13) % 2) * 6) % 12 === 0);
    let c = x < X + 2 ? ST[4] : x > X + wallW - 2 ? ST[1] : ST[2];
    if (seam) c = ST[1];
    out.c = c;
  });
  // a wet near lip catches the fan's light
  for (let y = wallTop; y < wallBot; y++) {
    const near = 1 - smooth(4, 30, Math.abs(y - impactY));
    p.dot(X + 1, y, mix(ST[4], C[5], 0.2 + near * 0.6), 0.75);
    if (y % 13 === 0) p.line(X + 2, y, X + wallW - 2, y, ST[1]);
  }
  for (let i = 0; i < 18; i++) {
    const sy = wallTop + rand(i, 3, S) * (wallBot - wallTop), sx = X + 2 + rand(i, 4, S) * (wallW - 5);
    const near = 1 - smooth(4, 28, Math.abs(sy - impactY));
    const len = 5 + rand(i, 5, S) * 22;
    for (let k = 0; k < len; k++) p.dot(sx + Math.sin(k * 0.5 + i) * 0.5, sy + k, k < 2 ? C[5] : C[3], (0.25 + near * 0.5) * (1 - k / len));
  }
  // the fan: jets of different weight, all bowing to the same aim, with pulses running out along them
  const N = 9;
  for (let i = 0; i < N; i++) {
    const u = i / (N - 1) - 0.5, a = aim + u * o.width + Math.sin(T * 2 + i * 1.7) * 0.006;
    const ca = Math.cos(a), ta = Math.tan(a);
    const w0 = 1.5 + 3.2 * Math.exp(-(u * 4.4) * (u * 4.4)) + 0.45 * Math.sin(i * 2.3 + T * 5);
    const dim = 0.58 + 0.42 * Math.exp(-(u * 2.2) * (u * 2.2));
    for (let x = 2; x < X; x += 1) {
      const bendY = Math.sin(x * 0.024 + T * 2 + i * 0.8) * (1.4 + x * 0.007);
      const yc = ta * x + bendY, w = w0 * (0.72 + 0.28 * smooth(0, 30, x)) * (1 + 0.12 * noise2(x * 0.11, i + T * 4, S));
      const surge = Math.exp(-Math.pow(((x - ((ph * 640 + i * 17) % (X - 8))) / 16), 2));
      for (let dy = -Math.ceil(w); dy <= Math.ceil(w); dy++) {
        const q = Math.abs(dy) / Math.max(0.55, w);
        if (q > 1) continue;
        const yy = yc + dy;
        if (yy > FLOOR) continue;
        let lvl = q < 0.16 + surge * 0.16 ? 0 : q < 0.46 ? 1 : q < 0.76 ? 2 : 3;
        if (q > 0.55) lvl = Math.min(3, lvl + 1);
        if (dim < 0.72) lvl = Math.min(3, lvl + 1);
        const c = lvl === 0 ? WHITE : lvl === 1 ? C[6] : lvl === 2 ? C[5] : lvl === 3 ? C[4] : C[3];
        p.px(x, yy, c);
      }
      if (x % 14 === 0) p.light(x, yc, C[4], 0.14 * dim);
    }
    for (let k = 0; k < 3; k++) {
      const xx = X * (0.45 + 0.2 * k), yy = ta * xx + Math.sin(xx * 0.024 + T * 2 + i * 0.8) * (1.4 + xx * 0.007) + (k % 2 ? 1 : -1) * w0;
      bead(p, xx + (t * 30) % 10, yy + (t * 18) % 8, 30, 10, 1, C, 0.5);
    }
    p.dot(X + 1, impactY, WHITE, 0.8);
  }
  // a soft sheet between the jets so the fan reads as one curtain of water
  for (let i = 0; i < 20; i++) {
    const x = 18 + (i % 7) * 27, u = ((i * 3) % 9) / 8 - 0.5, a = aim + u * o.width;
    const y = Math.tan(a) * x + Math.sin(x * 0.024 + T * 2) * 1.5;
    p.disc(x, y, 7 + (i % 4) * 2.5, C[4], (d) => 0.04 * (1 - d * d));
  }
  // stray water falls out of the curtain
  for (let i = 0; i < 16; i++) {
    const x = 20 + ((i * 37 + ph * 260) % (X - 30));
    const a = aim + (rand(i, 18, S) - 0.5) * o.width * 1.4, y = Math.tan(a) * x + 6 + (t * 22 + i * 9) % 24;
    if (y > FLOOR) continue;
    bead(p, x, y, 0, 70, 1, C, 0.5);
  }
  // the impact: a bright palm of water on the wall, throwing spray back and up
  if (!hitFloor) {
    const kick = 0.82 + 0.18 * Math.sin(T * 4);
    p.disc(X - 2, impactY, 16 * kick, (d, ang) => (d < 0.25 ? WHITE : d < 0.55 ? C[6] : C[4]), (d) => 0.5 * (1 - d) * kick);
    for (let i = 0; i < 10; i++) {
      const a = Math.PI + (i / 9 - 0.5) * 2.0 + Math.sin(T * 3 + i) * 0.12, L = (8 + 16 * rand(i, 7, S)) * kick;
      p.line(X - 2, impactY, X - 2 + Math.cos(a) * L, impactY + Math.sin(a) * L, (v) => (v > 0.55 ? WHITE : v > 0.25 ? C[6] : C[5]), 0.8);
    }
    for (let i = 0; i < 14; i++) {
      const a = Math.PI + (i / 13 - 0.5) * 2.2, L = 14 + 24 * rand(i, 8, S);
      const age = (t * 0.7 + rand(i, 9, S)) % 1, x = X - 2 + Math.cos(a) * L * (0.4 + age * 0.7), y = impactY + Math.sin(a) * L * (0.4 + age * 0.7) + age * age * 16;
      if (y > FLOOR) continue;
      bead(p, x, y, Math.cos(a) * 60, Math.sin(a) * 60 + age * 80, i % 4 === 0 ? 2 : 1, C, 0.7 * (1 - age));
    }
    p.glow(X - 3, impactY, 18, C[5], 0.45 * kick);
    p.glow(X - 2, impactY, 7, WHITE, 0.35 * kick);
  }
  // runoff pours straight down from the impact
  if (!hitFloor) {
    for (let i = 0; i < 5; i++) {
      const sx = X + 1 + i * 2.2, top = impactY + 3 + rand(i, 13, S) * 5, L = FLOOR - top;
      if (L <= 0) continue;
      for (let k = 0; k < L; k++) {
        const f = k / L;
        p.dot(sx + Math.sin(k * 0.4 + i + T * 3) * 0.4, top + k, f < 0.15 ? WHITE : f < 0.55 ? C[5] : C[4], 0.5 * (1 - f * 0.7));
      }
    }
    p.ellipse(X + 3, FLOOR, 9 + 3 * Math.sin(T * 2), 2, (d) => (d < 0.4 ? C[6] : C[4]), 0.5);
  }
  // runoff and floor
  const wet = smooth(0.1, 0.4, 1 - Math.abs(aim) / Math.max(0.01, o.sweep));
  p.ellipse(X + 5, FLOOR, 26 + 10 * wet, 3.2, (d, a) => (Math.sin(a) < 0 ? C[2] : C[3]), 0.4 + 0.15 * wet);
  p.ellipse(X + 12, FLOOR - 0.6, 9 + 5 * wet, 1.1, (d) => (d < 0.5 ? C[5] : C[4]), 0.35);
  for (let i = 0; i < 12; i++) {
    const x = X - 15 + rand(i, 10, S) * 25, y = FLOOR - 1 - rand(i, 11, S) * 15;
    bead(p, x, y, 25, 60, 1, C, 0.45);
  }
  ring(p, X + 8, FLOOR, 5 + 12 * ((ph * 2) % 1), 0.2, 0.5 * (1 - (ph * 2) % 1), C, { n: 1, hot: false, seed: S });
  // fan light and mist
  p.glowLine(0, 0, X, impactY, 24, C[4], 0.16);
  p.glow(X - 3, impactY, 26, C[4], 0.2);
  for (let i = 0; i < 9; i++) {
    const x = 20 + i * 19, a = aim + Math.sin(i * 1.7 + T * 2) * 0.03, y = Math.tan(a) * x;
    p.disc(x, y - 2, 6 + (i % 3) * 3, C[4], (d) => 0.05 * (1 - d * d));
  }
}
