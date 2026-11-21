// A needle of water under pressure: it whips out of the muzzle, punches a slab and keeps going as a spray on the
// far side. Water beads, ropes and mist keep it liquid rather than a laser.
import { Particles, Lights, P, Rng, fit, clamp, smooth, ease, rand, noise2, scale, TAU, WHITE, mix, hex } from "../../core/index.js";
import { WATER, bead, Mist, ring } from "./_lib.js";

export const meta = {
  name: "Pressure lance",
  desc: "A needle-thin jet punches through a stone slab: a white-hot line, pressure hoops racing along it, a spray sheet off the entry hole and a burst of water out the far side.",
  tags: ["water", "jet", "pressure", "pierce", "punch", "wall", "impact", "directional", "one-shot"],
  size: [306, 104],
  origin: [22, 52],
  duration: 1.14,
  loop: false,
  fps: 30,
  bg: "dark",
  options: { palette: WATER, stone: "#52627c", length: 200, seed: 4 },
};

const FLOOR = 36, T = 26, HIT = 0.085, FIRE = 0.5, G = 760, NZ = 17;

export function create(o) {
  const C = fit(o.palette, 8), X = o.length, HY = -8, R = new Rng(o.seed);
  const sb = hex(o.stone);
  const ST = ["#060a10", "#0d1622", "#172333", "#263649", "#3d556d", "#6d8ba3"].map(hex);
  const MT = ["#070a10", "#101720", "#1c2632", "#2f3e50", "#4e637a", "#93a8bb"].map(hex);
  const ps = new Particles({ rng: R, ground: () => FLOOR, sparks: [WHITE, C[6], C[5], C[3]] });
  const mist = new Mist(), lights = new Lights();
  const drops = [], back = [], drips = [], bits = [], rays = [], fall = [], ripples = [];
  for (let i = 0; i < 15; i++) rays.push({ a: Math.PI + (i / 14 - 0.5) * 2.3 + R.range(-0.07, 0.07), L: R.range(13, 34), w: R.range(1.1, 2.6) });
  for (let i = 0; i < 8; i++) fall.push({ x: X + R.range(1, T - 2), y0: HY + R.range(2, 13), t0: 0.4 + i * 0.09 + R.range(0, 0.06), landed: false });
  const S = o.seed;

  // the wall face is chipped and wet: one block with a lit left lip, a dark back edge and old water stains
  const chips = Array.from({ length: 10 }, () => [R.range(-2, 2), R.range(-30, 34), R.range(1, 3)]);
  const stains = Array.from({ length: 13 }, (_, i) => ({ x: R.range(1, T - 2), y: R.range(-38, 34), w: R.range(0.5, 1.4), l: R.range(3, 16), a: R.range(0.15, 0.5) }));
  const hole = Array.from({ length: 16 }, () => {
    const a = R.range(0, TAU), r = R.range(1.2, 4.4);
    return [Math.cos(a) * r, Math.sin(a) * r * 1.35];
  });

  // spray back off the entry hole: fast at first, then heavier drops falling out of it
  const shed = Array.from({ length: 26 }, () => ({ x: R.range(8, 148), y: R.range(-2, 2), v: R.range(15, 65), a: R.sign() * R.range(0.1, 0.9), s: R.chance(0.3) ? 2 : 1 }));
  for (let i = 0; i < 28; i++) {
    const a = Math.PI + R.range(-1.15, 1.15), v = R.range(40, 220);
    drops.push({ x: X - 1, y: HY + R.range(-1, 1), vx: Math.cos(a) * v, vy: Math.sin(a) * v - R.range(0, 50), s: R.chance(0.22) ? 3 : R.chance(0.5) ? 2 : 1, t0: HIT + R.range(0, 0.18), life: R.range(0.5, 1.1) });
  }
  // spray out the far side: finer, faster, flatter, with a couple of ropes in it
  for (let i = 0; i < 58; i++) {
    const a = R.range(-0.62, 0.62), v = R.range(95, 260);
    back.push({ x: X + T, y: HY + R.range(-1, 1), vx: Math.cos(a) * v, vy: Math.sin(a) * v + R.range(-4, 12), s: R.chance(0.3) ? 2 : 1, t0: 0.115 + R.range(0, 0.5), life: R.range(0.25, 0.7) });
  }
  // water running down the face from the hole
  for (let i = 0; i < 16; i++) drips.push({ x: X + R.range(0.4, T - 1), y: HY + R.range(0, 9), delay: R.range(0.06, 0.75), v: R.range(22, 65), w: R.range(0.5, 1.3), len: R.range(2, 12) });
  // stone chips torn off the entry face and the far lip
  for (let i = 0; i < 13; i++) {
    const a = Math.PI + R.range(-0.9, 0.9), v = R.range(42, 160);
    bits.push({ x: X - 1, y: HY + R.range(-2, 2), vx: Math.cos(a) * v, vy: Math.sin(a) * v - R.range(20, 75), s: R.range(0.6, 1.4), a: R.range(0, TAU), va: R.sign() * R.range(3, 11), t0: HIT + R.range(0, 0.035) });
  }

  function wall(p, fade) {
    if (fade <= 0) return;
    // a dark wet block: flat cut faces, a lit near lip and a chipped top edge; quiet enough for the water to read
    p.shade(X, -45, X + T + 1, FLOOR + 1, (x, y, out) => {
      if (y > FLOOR) return;
      const top = -44 + (rand(x, 3, S) > 0.72 ? 1 : 0) - (rand(x, 4, S) > 0.93 ? 2 : 0);
      if (y < top) return;
      let c = x < X + 3 ? ST[4] : x > X + T - 3 ? ST[2] : ST[3];
      if (y > 22) c = x < X + 3 ? ST[3] : ST[2];
      if (y === top) c = ST[5];
      out.c = c;
      out.a = fade;
    });
    // joints and a few nicks, not a grid
    for (const yy of [-33, -21, -9, 3, 15, 27]) {
      p.line(X + 3, yy, X + T - 2, yy, ST[2], fade);
      const jx = X + 7 + ((yy * 7 + 30) % 13);
      p.line(jx, yy, jx, Math.min(FLOOR, yy + 11), ST[2], fade);
    }
    for (const c of chips) if (c[1] > -40 && c[1] < FLOOR) p.dot(X + Math.max(0, c[0] + 1), c[1], ST[5], fade * 0.6);
    // wet sheen down the face, old channels and fresh wash from the hole
    for (const s of stains) {
      if (s.y + s.l > FLOOR) continue;
      for (let k = 0; k < s.l; k++) p.dot(X + s.x + Math.sin(k * 0.4 + s.y) * 0.35, s.y + k, C[3], fade * s.a * 0.45 * (1 - k / s.l));
    }
    for (let i = 0; i < 6; i++) {
      const sx = X + 3 + rand(i * 7, 5, S) * (T - 6), top = HY + 2 + rand(i, 6, S) * 5;
      const len = 5 + rand(i, 7, S) * 15;
      for (let k = 0; k < len; k++) p.dot(sx + Math.sin(k * 0.6 + i) * 0.4, top + k, k < 2 ? C[5] : C[3], fade * (0.4 - k / len * 0.3));
    }
    // the entry hole: a dark torn mouth, broken pale stone around it, the far hole a small wet pinhole
    const u = clamp((t - HIT) / 0.07), holeLife = 1 - smooth(0.45, 1.0, t);
    if (u > 0) {
      p.ellipse(X + 2, HY, 4.1 * u, 5.4 * u, (d) => (d < 0.7 ? hex("#02050b") : d < 0.92 ? ST[1] : ST[4]), fade * holeLife);
      for (const [hx, hy] of hole) {
        if (Math.hypot(hx, hy) < 2.8) continue;
        p.dot(X + hx * u, HY + hy * u, Math.hypot(hx, hy) > 3.7 ? ST[5] : ST[0], fade * 0.8);
      }
      if (t < 0.4) for (let i = 0; i < 3; i++) {
        const a = 0.55 + i * 0.2, rr = 4.7 * u;
        p.dot(X + 1 + Math.cos(a) * rr, HY + Math.sin(a) * rr * 1.35, i === 0 ? C[6] : C[4], fade * 0.5 * holeLife);
      }
      p.glow(X, HY, 7, C[4], 0.16 * fade * u);
    }
    // water clings to the face below the hole and gathers at the foot
    const wf = smooth(0.02, 0.5, t) * fade;
    if (wf > 0) {
      p.ellipse(X + 13, FLOOR + 0.4, 7 + wf * 21, 1.4 + wf * 1.7, (d, a) => (Math.sin(a) < 0 ? C[2] : C[3]), 0.42 * wf);
      p.ellipse(X + 19, FLOOR + 0.3, 2 + wf * 10, 0.6 + wf * 0.9, (d) => (d < 0.5 ? C[6] : C[4]), 0.32 * wf);
    }
  }

  function nozzle(p) {
    // a short tapered pressure lance: a blued barrel widening into a collar behind a white-hot seal
    if (t > meta.duration - 0.14) return;
    p.poly([[-NZ - 3, -5.4], [-4, -3.7], [-4, 3.7], [-NZ - 3, 5.4]], MT[2]);
    p.poly([[-NZ - 3, -5.4], [-4, -3.7], [-4, -1.8], [-NZ - 3, -2.8]], MT[4]);
    p.poly([[-NZ - 3, 5.4], [-4, 3.7], [-4, 2.2], [-NZ - 3, 3.2]], MT[1]);
    p.rect(-5, -5.2, 4, 10.4, MT[3]);
    p.rect(-4, -4.4, 2.2, 8.8, hex("#080e17"));
    for (const bx of [-15, -11]) p.line(bx, -4.4, bx, 4.4, MT[1]);
    p.line(-NZ - 3, -5, -4, -3.5, MT[5]);
    p.line(-NZ - 3, 5, -4, 3.5, MT[0]);
    p.arc(-0.4, 0, 4.2, 1.2, 0.3, TAU - 0.3, (v) => (v > 0.45 ? C[6] : C[3]), 0.85);
    if (t > FIRE) {
      const u = t - FIRE;
      for (let i = 0; i < 3; i++) {
        const y = 5 + ((u * (18 + i * 6) + i * 3) % 26);
        if (y < FLOOR) p.dot(-1.5 + i * 0.6, y, C[5], 0.55);
      }
    }
  }

  function stream(p) {
    if (t < HIT) {
      // the first frames: a white pin at the mouth, then the needle snaps out to the wall
      const u = clamp(t / HIT), end = X * ease.outExpo(u);
      for (let x = 0; x <= end; x++) {
        const w = 1.1 + 1.9 * u - Math.max(0, (x - end + 8) / 8) * 1.2;
        for (let y = -w; y <= w; y += 0.5) {
          const q = Math.abs(y) / Math.max(0.6, w);
          p.px(x, y - 0.2, q < 0.3 ? WHITE : q < 0.6 ? C[6] : q < 0.85 ? C[5] : C[3]);
        }
        if (x % 6 === 0) p.light(x, 0, C[5], 0.2);
      }
      p.glow(end, 0, 13, C[6], 0.8);
      p.glow(end, 0, 4, WHITE, 0.7);
      return;
    }
    if (t > FIRE + 0.34) return;
    const life = 1 - smooth(FIRE, FIRE + 0.34, t);
    // a taut rope of water: a white core, a cyan shoulder, a cold underside and a haze of torn spray along it
    const broken = t > FIRE ? smooth(FIRE, FIRE + 0.2, t) : 0;
    const end = X - 1 - (t > FIRE ? (t - FIRE) * 120 * broken : 0);
    for (let x = 0; x <= end; x++) {
      const u = x / X, surge = Math.exp(-Math.pow(((x - (t * 610 + 10)) % 36) / 8, 2));
      const rough = u > 0.7 ? smooth(0.5, FIRE + 0.24, t) * 0.9 : 0;
      const body = (2.2 + 1.7 * surge) * (0.72 + 0.28 * life) + 0.5 * noise2(x * 0.24, t * 15, S);
      const yc = Math.sin(x * 0.15 + t * 26) * 0.35;
      // a soft sleeve of spray hangs around the rod
      if (x % 3 === 0) p.disc(x, yc, body + 1.2, C[4], (d) => 0.09 * life * (1 - d * d));
      const cut = broken > 0 && noise2(x * 0.13 - t * 20, 2.2, S) < -1.1 + 2.2 * broken;
      if (cut) continue;
      for (let y = -Math.ceil(body); y <= Math.ceil(body); y++) {
        const q = Math.abs(y - yc) / Math.max(0.6, body);
        if (q > 1) continue;
        let col = q < 0.25 ? WHITE : q < 0.56 ? C[6] : q < 0.8 ? C[5] : C[3];
        if (y > 0 && q > 0.58) col = C[2];
        p.px(x, y, col);
      }
      if (x % 10 < 2) {
        p.dot(x, -body - 0.7, C[6], 0.8 * (1 - rough));
        p.dot(x, body + 0.7, C[5], 0.7 * (1 - rough));
      }
      if (x % 8 === 0) p.light(x, 0, C[4], 0.23 * life);
    }
    // hoops of pressure race down the rod, each a thin bright ellipse standing on the jet
    for (let k = 0; k < 4; k++) {
      const hx = ((t * 460 + k * 38) % (X - 8)) + 4;
      if (hx > end) continue;
      const hw = 3.1 + 1.7 * Math.sin((hx + k * 9) * 0.3);
      p.arc(hx, 0, hw, 0.9, -2.5, 2.5, (u) => (u > 0.2 && u < 0.8 ? C[6] : C[5]), 0.7 * life);
    }
    // drops shed off the stream's belly and fly on with the jet
    for (const s of shed) {
      if (s.x > end) continue;
      const x = s.x + t * s.v, y = s.y + Math.sin(t * 8 + s.x) * 0.5 + Math.tan(s.a) * (x - s.x);
      if (x > end || y > FLOOR) continue;
      bead(p, x, y, s.v, 20, s.s, C, 0.7 * life);
    }
    // the nozzle: a hot ring and a little backblast that never quite lets go
    p.ring(0, 0, 4.3 + Math.sin(t * 60) * 0.25, 1.4, C[5], 0.55 * life * (1 - broken * 0.5));
    p.circle(0, 0, 1.9, WHITE, 1 - broken * 0.5);
    p.glow(0, 0, 18, C[5], 0.6 * life);
    p.glow(0, 0, 6, WHITE, 0.5 * life);
    if (t < FIRE) {
      for (let i = 0; i < 3; i++) {
        const x = -2 - ((t * 45 + i * 9) % 22), y = Math.sin(i * 2 + t * 18) * 2;
        p.dot(x, y, C[3], 0.35 * life);
      }
    }
    // once the pressure dies the rod breaks into beads that fall away
    if (t > FIRE + 0.08) {
      const u = t - FIRE;
      for (let i = 0; i < 7; i++) {
        const x = end - 4 - ((u * (55 + i * 9) + i * 14) % 80), y = 1.5 + (u * u * 210) * (0.2 + i * 0.11);
        if (y < FLOOR && x > -4) bead(p, x, y, 40, 80, i % 3 === 0 ? 2 : 1, C, 0.8 * life);
      }
    }
  }

  function impact(p) {
    const u = t - HIT;
    if (u < 0) return;
    const k = 1 - smooth(0.12, 0.62, u) * 0.96, hit = Math.exp(-u / 0.045);
    const shr = 1 - smooth(0.16, 0.58, u) * 0.96;
    // a crown of water flares off the face: three broad, sagging sheets and a handful of torn blades
    if (k > 0 && u < 0.55) {
      const grow = ease.outCubic(clamp(u / 0.1)), Rr = (11 + 25 * grow) * shr;
      const cx = X - 1.5, cy = HY;
      // the volume: a few soft lobes that make the sheet hold together instead of reading as a starburst
      for (let i = 0; i < 6; i++) {
        const a = Math.PI + (i / 5 - 0.5) * 2.0, d = Rr * (0.28 + 0.28 * rand(i, 1, S));
        p.disc(cx + Math.cos(a) * d, cy + Math.sin(a) * d * 0.92, Rr * (0.26 + 0.16 * rand(i, 2, S)), (dd) => (dd < 0.35 ? C[5] : C[4]), (dd) => 0.3 * k * (1 - dd * dd));
      }
      // broad blades that curve as they lose their push: a bright crest, a cyan belly, foam at the tip
      for (let i = 0; i < 7; i++) {
        const a = Math.PI + (i / 6 - 0.5) * 2.25 + Math.sin(i * 2.1) * 0.07;
        const keep = 1 - smooth(0.24, 0.85, u) * (0.35 + 0.6 * rand(i, 12, S));
        const L = (Rr * 0.8 + 16 * rand(i, 9, S)) * (0.72 + k * 0.35) * keep, w = (2.2 + 2.1 * rand(i, 10, S)) * Math.sqrt(keep);
        if (L < 2.5) continue;
        const ca = Math.cos(a), sa = Math.sin(a), droop = (2.5 + 6 * rand(i, 11, S)) * (0.4 + u * 1.4);
        const bx = cx + ca * 2, by = cy + sa * 2, tx = cx + ca * L, ty = cy + sa * L + droop;
        const mx = cx + ca * (L * 0.55) - sa * w * 0.5, my = cy + sa * (L * 0.55) + ca * w * 0.5 + droop * 0.25;
        p.poly([
          [bx - sa * w, by + ca * w],
          [mx - sa * w * 0.35, my + ca * w * 0.35],
          [tx, ty],
          [mx + sa * w * 0.2, my - ca * w * 0.2 + 1.5],
          [bx + sa * w, by - ca * w],
        ], (x, y) => {
          const d = Math.hypot(x - cx, y - cy) / Math.max(1, L);
          return d > 0.64 ? C[6] : d > 0.32 ? C[5] : C[4];
        }, 1);
        p.line(bx - sa * w, by + ca * w, mx - sa * w * 0.35, my + ca * w * 0.35, C[6]);
        p.line(mx - sa * w * 0.35, my + ca * w * 0.35, tx, ty, (v) => (v > 0.35 ? WHITE : C[6]));
        p.line(bx + sa * w, by - ca * w, mx + sa * w * 0.2, my - ca * w * 0.2 + 1.5, C[3]);
        if (L > 25) {
          const fa = 1 - clamp(u / 0.5);
          if (fa > 0) {
            p.circle(tx, ty, 1.2, C[5], 0.7 * fa);
            p.dot(tx - 0.4, ty - 0.5, WHITE, 0.8 * fa);
          }
        }
      }
      // the outer lip is scalloped and throws beads
      for (let i = 0; i < 20; i++) {
        const a = Math.PI + (i / 19 - 0.5) * 2.3, L = Rr * (0.78 + 0.3 * rand(i, 8, S));
        p.dot(cx + Math.cos(a) * L, cy + Math.sin(a) * L + 2.4, i % 3 ? C[6] : WHITE, 0.52 * k);
        if (i % 3 === 0) bead(p, cx + Math.cos(a) * (L + 3), cy + Math.sin(a) * (L + 3) + 2.4, Math.cos(a) * 40, Math.sin(a) * 40, 1, C, 0.45 * k);
      }
      // a shock ring leaves the face, only the half facing back into the air
      if (u > 0.02 && u < 0.3) {
        const rr = 8 + 43 * ease.outCubic((u - 0.02) / 0.28), aa = 0.32 * (1 - (u - 0.02) / 0.28);
        p.arc(cx, cy, rr, 1.1, Math.PI - 1.15, Math.PI + 1.15, (v) => (v > 0.45 ? WHITE : C[5]), aa);
      }
      // a sheet of water runs down the slab face, so the splash has weight and a destination
      if (u > 0.04) {
        const f2 = (1 - smooth(0.3, 1.15, u)) * 0.8 + 0.2;
        p.disc(X - 4, HY + 18, 6 + grow * 3, C[4], (d) => 0.16 * k * f2 * (1 - d * d));
        p.disc(X - 7, FLOOR - 6, 5 + grow * 2, C[4], (d) => 0.14 * k * f2 * (1 - d * d));
        for (let i = 0; i < 7; i++) {
          const sx = X - 1 - i * 2.2, sy = HY + 5 + ((u * (42 + i * 9) + i * 7) % (FLOOR - HY - 5));
          p.line(sx, sy, sx - 1, Math.min(FLOOR, sy + 8 + i * 2), (v) => (v < 0.3 ? WHITE : C[5]), 0.5 * k * f2);
        }
        // the wash breaks over the foot of the block in a little white furrow
        const rr = 4 + 13 * ease.outCubic(clamp((u - 0.05) / 0.2));
        p.ellipse(X + 1, FLOOR, rr, rr * 0.18 + 0.5, (d, a) => (Math.sin(a) < 0 ? C[5] : C[6]), 0.45 * k);
      }
    }
    if (hit > 0.02) {
      p.circle(X - 1, HY, 3.5 + 4.5 * hit, C[6], 0.85 * hit);
      p.circle(X - 1, HY, 2 + 2 * hit, WHITE, hit);
      p.glow(X - 1, HY, 32, C[5], 0.8 * hit);
      p.glow(X - 1, HY, 9, WHITE, 0.65 * hit);
    }
    // water runs off the hole in ropes, then beads
    for (const d of drips) {
      if (u < d.delay) continue;
      const y0 = d.y + (u - d.delay) * d.v;
      if (y0 > FLOOR) continue;
      const L = Math.min(d.len, FLOOR - y0), f = Math.min(1, (1 - (u - d.delay) / 1.4) * 1.6);
      p.line(d.x, y0, d.x + Math.sin((y0 + d.y) * 0.5) * 0.45, y0 + L, (v) => (v < 0.2 ? WHITE : C[5]), 0.42 * k * f);
      p.dot(d.x, y0 + L, C[6], 0.6 * k * f);
    }
  }

  function outSpray(p) {
    if (t < 0.105) return;
    const k = 1 - smooth(0.5, 0.9, t);
    // the jet is smaller after the slab but it still has teeth; a loose cone of mist carries the volume
    for (let i = 0; i < 7; i++) {
      const d = 4 + i * 6 + (i % 3) * 2, wob = Math.sin(i * 2.7 + t * 2.4) * (3 + i * 0.8);
      p.disc(X + T + d, HY + wob - 1 - (i % 2) * 2, 4.2 + i * 1.1, C[4], (q) => 0.075 * k * (1 - q * q));
    }
    for (let x = X + T; x < X + T + 13; x++) {
      const u = (x - X - T) / 13, w = (2.3 - u * 1.5) * (0.65 + 0.35 * k);
      for (let y = -Math.ceil(w); y <= Math.ceil(w); y++) {
        const q = Math.abs(y) / Math.max(0.5, w);
        p.dot(x, HY + y, q < 0.3 ? C[6] : q < 0.7 ? C[5] : C[3], 0.9 * k);
      }
      if (x % 5 === 0) p.light(x, HY, C[4], 0.25 * k);
    }
    // three fine jets fan out of the hole and drag the eye to the right
    for (let i = 0; i < 4; i++) {
      const a = (i / 3 - 0.5) * 0.5, L = 17 + i * 4;
      p.line(X + T + 4, HY, X + T + 4 + Math.cos(a) * L, HY + Math.sin(a) * L, (v) => (v > 0.4 ? C[6] : C[5]), 0.75 * k);
    }
    for (const d of back) {
      const a = t - d.t0;
      if (a < 0 || a > d.life) continue;
      const x = d.x + d.vx * a, y = d.y + d.vy * a + 0.5 * G * a * a;
      if (x > meta.size[0] - meta.origin[0] - 2 || y > FLOOR) continue;
      bead(p, x, y, d.vx, d.vy + G * a, d.s, C, Math.min(1, (d.life - a) / 0.18) * k);
    }
    // mist fans out past the slab, thinning as it goes
    if (k > 0) {
      for (let i = 0; i < 8; i++) {
        const x = X + T + 5 + ((t * 55 + i * 13) % 44), y = HY + Math.sin(i * 2.1 + t * 3) * (5 + i * 1.3);
        p.disc(x, y, 3.5 + i * 0.5, C[5], (d) => 0.1 * k * (1 - d * d));
      }
      p.glow(X + T + 6, HY, 16, C[5], 0.3 * k);
    }
  }

  function floorSplash(p) {
    // the sheet hits the puddle at the foot of the slab and throws a little crown back up
    const u = t - 0.15;
    if (u < 0 || u > 0.8) return;
    const k = 1 - smooth(0.18, 0.7, u), r = 3 + 15 * ease.outCubic(clamp(u / 0.22));
    p.ellipse(X + 5, FLOOR, r, r * 0.18 + 0.7, (d, a) => (Math.sin(a) < 0 ? C[4] : C[5]), 0.55 * k);
    if (u < 0.16) for (let i = 0; i < 9; i++) {
      const a = -Math.PI * (0.15 + 0.7 * rand(i, 5, S)), v = 45 + 70 * rand(i, 6, S), age = u;
      const x = X + 5 + Math.cos(a) * v * age, y = FLOOR + Math.sin(a) * v * age + 320 * age * age;
      p.dot(x, y, i % 3 ? C[6] : WHITE, k);
    }
  }

  let t = 0;
  return {
    update(dt) {
      t += dt;
      ps.update(dt);
      mist.update(dt);
      lights.update(dt);
      if (Math.abs(t - HIT) < dt * 0.5) {
        lights.add(X - 2, HY, 34, C[5], 0.7, 0.2);
        lights.add(X - 2, HY, 12, WHITE, 0.5, 0.06);
      }
    },
    drawBack(p) {
      if (t >= meta.duration - 0.02) return;
      ps.draw(p, "back");
    },
    draw(p) {
      if (t >= meta.duration - 0.02) return;
      const fade = 1 - smooth(meta.duration - 0.2, meta.duration - 0.025, t);
      wall(p, fade);
      // the far spray sits behind the slab silhouette
      outSpray(p);
      nozzle(p);
      impact(p);
      stream(p);
      floorSplash(p);
      for (const b of bits) {
        const a = t - b.t0;
        if (a < 0 || a > 1.1) continue;
        const x = b.x + b.vx * a, y = b.y + b.vy * a + 0.5 * 950 * a * a;
        if (y > FLOOR) continue;
        const s = b.s, ca = Math.cos(b.a + b.va * a), sa = Math.sin(b.a + b.va * a), f = Math.min(1, (1.1 - a) / 0.2);
        p.px(x, y, ST[4], f); p.px(x + ca * s, y + sa * s, ST[5], f);
      }
      for (const d of drops) {
        const a = t - d.t0;
        if (a < 0 || a > d.life) continue;
        const x = d.x + d.vx * a, y = d.y + d.vy * a + 0.5 * G * a * a;
        if (y > FLOOR) continue;
        bead(p, x, y, d.vx, d.vy + G * a, d.s, C, Math.min(1, (d.life - a) / 0.2));
      }
      // late drips fall from the torn lip and ring the puddle
      for (const f of fall) {
        if (t < f.t0 || t > f.t0 + 0.7) continue;
        const a = t - f.t0, y = f.y0 + 0.5 * 820 * a * a;
        if (y < FLOOR) bead(p, f.x, y, 0, 820 * a, a < 0.1 ? 1 : 2, C, 0.8);
        else if (!f.landed) {
          f.landed = true;
          ripples.push({ x: f.x, t0: t, s: 1 + (f.x - X) * 0.08 });
        }
      }
      for (const q of ripples) {
        const u = (t - q.t0) / 0.55;
        if (u < 0 || u > 1) continue;
        ring(p, q.x, FLOOR, 1 + 17 * ease.outCubic(u), 0.22, (1 - u) * 0.85, C, { n: 1, hot: u < 0.12, glint: 0.4 * (1 - u) });
      }
      ps.draw(p, "front");
      mist.draw(p, C[5]);
      lights.draw(p);
      // a cold pool of light in front of the slab for as long as the jet is running
      if (t < FIRE + 0.35) p.glow(X - 15, HY + 2, 32, C[4], 0.18 * (1 - smooth(FIRE, FIRE + 0.35, t)));
    },
  };
}
