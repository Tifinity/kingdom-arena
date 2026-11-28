// Billow field and lighting adapted from pixelfx lightning/storm-cloud (MIT).
export function arenaStormCloud(source, { clamp, fit, loopNoise, rng, tileNoise }, { crackle, zigzag }) {
  const meta = {
    ...source.meta,
    name: "Arena Storm Cloud",
    size: [176, 104],
    origin: [88, 104],
    fps: 20,
    desc: "Banked storm billows with a scalloped belly and short internal discharges.",
  };
  // Larger rising lobes sit behind staggered shoulders and smaller foreground lobes.
  const billows = [
    [-64, -36, 14, 0.80], [-48, -56, 17, 0.95], [-24, -73, 22, 0.98],
    [0, -59, 18, 0.98], [28, -67, 19, 0.98], [51, -53, 17, 0.91], [67, -38, 13, 0.89],
    [-43, -29, 18, 0.77], [-14, -25, 21, 0.80], [16, -30, 19, 0.74], [43, -26, 20, 0.77],
  ];
  const flashes = [[4, 8, 0.85], [19, 4, 0.7], [34, 10, 0.95], [47, 2, 0.65]];
  const threshold = 0.42;
  const radiusScale = Math.sqrt(1 - Math.cbrt(threshold));

  function draw(p, time, options) {
    const phase = (time % meta.duration) / meta.duration;
    const frame = Math.floor(phase * meta.duration * meta.fps + 1e-6);
    const colors = fit(options.cloud, 7);
    const bolts = fit(options.palette, 8);
    const clouds = billows.map(([x, y, radius, squash], index) => ({
      x: x + 2.4 * loopNoise(phase, 0.7, options.seed + index),
      y: y + 1.7 * loopNoise(phase, 0.7, options.seed + index + 30),
      radius: radius * (1 + 0.055 * loopNoise(phase, 0.8, options.seed + index + 60)) / radiusScale,
      squash,
    }));
    const flash = flashes.find(([start]) => frame >= start && frame <= start + 2);
    const litIndex = flash?.[1] ?? -1;
    const flashStrength = flash ? flash[2] * [1, 0.36, 0.57][frame - flash[0]] : 0;
    const field = new Float32Array(meta.size[0] * meta.size[1]);
    const slopeX = new Float32Array(field.length);
    const slopeY = new Float32Array(field.length);
    const light = new Float32Array(field.length);
    const [width, height] = meta.size;
    const [originX, originY] = meta.origin;
    for (const [index, cloud] of clouds.entries()) {
      const rx = cloud.radius, ry = rx * cloud.squash;
      for (let row = Math.max(0, Math.floor(cloud.y - ry + originY)); row < Math.min(height, cloud.y + ry + originY); row++) {
        for (let col = Math.max(0, Math.floor(cloud.x - rx + originX)); col < Math.min(width, cloud.x + rx + originX); col++) {
          const dx = (col - originX + 0.5 - cloud.x) / rx;
          const dy = (row - originY + 0.5 - cloud.y) / ry;
          const weight = 1 - dx * dx - dy * dy;
          if (weight <= 0) continue;
          const pixel = row * width + col;
          const density = weight ** 3;
          const slope = 6 * weight ** 2;
          field[pixel] += density;
          slopeX[pixel] -= slope * dx / rx;
          slopeY[pixel] -= slope * dy / ry;
          if (index === litIndex) light[pixel] = flashStrength * density;
        }
      }
    }
    for (let row = 0; row < height; row++) {
      for (let col = 0; col < width; col++) {
        const pixel = row * width + col;
        if (field[pixel] < threshold - 0.035) continue;
        const x = col - originX + 0.5, y = row - originY + 0.5;
        const texture = tileNoise(x * 0.19 + 12 * phase, y * 0.19, 12, 0, options.seed);
        if (field[pixel] + texture * 0.045 < threshold) continue;
        const gradient = Math.hypot(slopeX[pixel], slopeY[pixel]);
        const facing = (slopeX[pixel] * 0.42 + slopeY[pixel] * 0.9) / (gradient || 1);
        const depth = clamp((-y - 10) / 84);
        const shade = Math.round(0.75 + 3.25 * depth + 1.5 * facing * Math.min(1, gradient * 13) + 0.34 * texture);
        const rampIndex = clamp(shade, 0, colors.length - 1);
        const discharge = Math.round(light[pixel] * (0.7 + 0.3 * texture) * 5);
        const color = discharge >= 2 ? bolts[Math.min(5, discharge + 1)] :
          colors[Math.min(colors.length - 1, rampIndex + discharge)];
        p.px(x, y, color);
      }
    }
    if (flash) {
      const { x, y } = clouds[litIndex];
      const random = rng(options.seed, flash[0]);
      p.glow(x, y + 3, 28, bolts[4], flashStrength * 0.18);
      if (flashStrength > 0.6) {
        crackle(p, zigzag(random, x - 13, y + 5, x + 15, y + 11, 0.25, 0.42), flashStrength * 0.6, bolts, 0.2);
      }
    }
  }

  return { id: "lightning/arena-storm-cloud", meta, mod: { meta, draw } };
}
