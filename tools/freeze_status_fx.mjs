// Adapts pixelfx ice/freeze (which credits Hugo Duprez's Sprite Fusion ice, MIT).
// The actual game unit remains visible through the panes.
export function freezeStatusEffect(source, core, inPoly) {
  const freezeDuration = 1.5;
  const shatterDuration = 0.6;
  const meta = {
    ...source.meta,
    name: "Arena Freeze",
    desc: "Cold races up from the feet, seals into faceted ice, and shatters as the target thaws.",
    duration: freezeDuration + shatterDuration,
    size: [176, 144],
    actor: 0,
    options: {
      ...source.meta.options,
      palette: ["#101d40", "#20366c", "#285f9e", "#3889cb", "#65c9ef", "#abeafa", "#d7faff", "#f5ffff"],
    },
  };

  const glass = [[-14, 0], [-16, -10], [-16, -30], [-12, -44], [-6, -41], [0, -51],
    [6, -42], [12, -46], [16, -30], [15, -9], [13, 0]];
  const glaze = core.hex("#55b2e8");
  const glassRows = Array.from({ length: 52 }, (_, row) => {
    const y = row - 52;
    const pixels = [];
    for (let x = -16; x <= 16; x++) {
      if (inPoly(glass, x + 0.5, y + 0.5)) pixels.push(x);
    }
    return pixels;
  });

  function create(options) {
    const actor = core.stockActor(2);
    const mask = { ...actor.mask, data: new Uint8Array(actor.w * actor.h) };
    const reference = source.create({ ...options, actor: { ...actor, mask } });
    const cues = [
      [0, 0],
      [0.20, 0.96],
      [1.36, 2.20],
      [freezeDuration, 2.521],
      [meta.duration, source.meta.duration],
    ];
    let elapsed = 0;
    let simulated = 0;

    return {
      update(delta) {
        elapsed = Math.min(meta.duration, elapsed + delta);
        const next = cues.findIndex(([time]) => elapsed <= time);
        const [start, from] = cues[Math.max(0, next - 1)];
        const [finish, to] = cues[Math.max(1, next)];
        const target = from + (to - from) * (elapsed - start) / (finish - start);
        while (simulated < target) {
          const step = Math.min(1 / 120, target - simulated);
          reference.update(step);
          simulated += step;
        }
      },
      draw(painter) {
        if (elapsed >= meta.duration) return;
        if (elapsed >= 0.07 && elapsed < freezeDuration) {
          const top = -Math.round(52 * core.smooth(0.07, 0.21, elapsed));
          for (let y = top; y < 0; y++) {
            for (const x of glassRows[y + 52]) painter.blend(x, y, glaze, x < -5 ? 0.25 : 0.36);
          }
        }
        reference.draw(painter);
      },
    };
  }

  return { meta, create, freezeDuration };
}
