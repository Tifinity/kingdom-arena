const palette = ["#2b2632", "#554050", "#82543c", "#b17849", "#d39a57", "#efc77f", "#ffe6ac", "#fffae8"];
const windup = 0.24;
const lock = 0.20;
const idle = { turn: 0.8, weapon: "hammer", fx: 7, fy: -16, sa: 0.25 };
const braced = { ...idle, crouch: 3, lean: -1, fx: 5, fy: -21, sa: -0.5 };

export function armorGuardEffects({ fit, rand, smooth, sparkle, TAU }) {
  const common = { size: [72, 60], origin: [36, 47], fps: 24, bg: "ground", actor: 2,
    tags: ["armor", "metal", "buff"], options: { palette, seed: 21 } };

  function plate(painter, x, y, width, height, colors, bright, side, back) {
    const point = (dx, dy) => [x + dx * width * side, y + dy * height];
    const contour = [point(-4, -4), point(1, -4), point(4, -1), point(3, 2), point(0, 4), point(-4, 2)];
    painter.poly(contour, colors[0]);
    painter.poly([point(-3, -3), point(1, -3), point(3, -1), point(0, 1), point(-3, 0)], colors[back ? 2 : 3]);
    painter.line(...point(-4, -4), ...point(1, -4), colors[bright ? 7 : back ? 4 : 5]);
    painter.line(...point(1, -4), ...point(4, -1), colors[back ? 3 : 4]);
    painter.line(...point(-3, 1), ...point(0, 3), colors[back ? 1 : 2]);
    painter.line(...point(0, 3), ...point(2, 1), colors[back ? 1 : 2]);
    painter.dot(...point(-2, -2), colors[back ? 4 : 6]);
  }

  function ignition(painter, time, options, back) {
    const colors = fit(options.palette, 8);
    const close = smooth(0, lock, time);
    const flash = smooth(lock - 0.048, lock, time) * (1 - smooth(lock + 0.035, lock + 0.22, time));
    const size = smooth(0, 0.08, time) * (1 - smooth(lock + 0.07, 0.43, time));
    const side = back ? -1 : 1;
    const outer = 8 + 11 * (1 - close) ** 2;
    const y = -13 + (back ? -2 : 1) - 4 * (1 - close);
    if (size > 0.13) {
      const trail = (1 - close) * size;
      painter.line(side * (outer + 4), y, side * (outer + 4 + trail * 10), y - 3 * trail, colors[4], trail);
      plate(painter, side * outer, y, 1.24 * size, size, colors, flash > 0.6, side, back);
      plate(painter, side * (outer + 1), y + 8, 0.78 * size, 0.7 * size, colors, flash > 0.8, side, back);
      if (flash > 0) {
        sparkle(painter, side * outer, y - 3, (back ? 2 : 3.6) * flash, colors[6], colors[5], flash * 0.42);
        painter.glow(side * outer, y, 8, colors[5], flash * 0.36);
      }
    }
    for (let index = 0; index < 9; index++) {
      const age = time - lock - rand(index, options.seed) * 0.08;
      const life = 0.18 + rand(index, options.seed, 1) * 0.18;
      if (age <= 0 || age >= life) continue;
      const x = side * (8 + (1 - Math.exp(-age * 9)) * (4 + rand(index, options.seed, 2) * 10));
      const sparkY = y + rand(index, options.seed, 3) * 10 - age * (12 + rand(index, options.seed, 4) * 35) + age ** 2 * 80;
      const opacity = 1 - smooth(0.05, life, age);
      painter.dot(x, sparkY, colors[age < 0.08 ? 7 : 4], opacity);
    }
  }

  function orbit(painter, time, options, back) {
    const colors = fit(options.palette, 8);
    for (let index = 0; index < 3; index++) {
      const angle = (time / 2.5 + index / 3 + 0.02) * TAU;
      const depth = Math.sin(angle);
      if ((depth < 0) !== back) continue;
      const x = Math.cos(angle) * 16;
      const y = -9 + depth * 5;
      const shine = smooth(0.86, 0.999, Math.cos(angle - 0.42));
      const width = 0.52 + Math.abs(depth) * 0.24;
      plate(painter, x, y, width, 0.64, colors, shine > 0.8, Math.cos(angle) < 0 ? -1 : 1, back);
      if (shine > 0.4) sparkle(painter, x, y - 3, 2 * shine, colors[7], colors[5], shine * 0.26);
    }
  }

  const intro = {
    meta: { ...common, name: "Armor guard: lock", desc: "Forged armour snaps into place and throws short sparks.", duration: 0.625, loop: false },
    act: { poses: [[-windup, idle], [0, braced], [lock, { ...braced, crouch: 5 }, "snap"], [0.625, idle]],
      hits: [{ t: lock, target: false, stop: 0.06, shake: 0.1, amp: 1 }] },
    drawBack: (painter, time, options) => ignition(painter, time, options, true),
    draw: (painter, time, options) => ignition(painter, time, options, false),
  };
  const hold = {
    meta: { ...common, name: "Armor guard: hold", desc: "Three small embossed plates revolve around the waist.", duration: 2.5, loop: true },
    act: { poses: [[0, idle], [2.5, idle]] },
    drawBack: (painter, time, options) => orbit(painter, time, options, true),
    draw: (painter, time, options) => orbit(painter, time, options, false),
  };
  return { intro, hold };
}
