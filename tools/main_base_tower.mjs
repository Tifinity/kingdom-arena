// The source PNG is a lossless crop of row 3, column 2 from the supplied towers.png.
export const SOURCE_SIZE = [60, 94];

export const meta = {
  name: "Main base stone tower",
  desc: "The supplied round stone tower with alternating blue and red team palettes.",
  tags: ["prop", "tower", "stone"],
  size: [80, 112],
  origin: [40, 102],
  duration: 1,
  fps: 1,
  loop: true,
  bg: "ground",
  options: {
    palette: ["#181d2c", "#344763", "#517aa0", "#7eafd3", "#bad9e8", "#eaeada"],
  },
};

export const redPalette = ["#281a27", "#5f3543", "#9e5150", "#ce7968", "#eab090", "#f7e6ca"];

export function towerDrawing({ blend, hex, luma, mix, rgb }, source) {
  const [width, height] = SOURCE_SIZE;

  return function draw(p, _time, options) {
    const ramp = options.palette.map(hex);
    const colors = new Map();

    for (let y = 0; y < height; y++) {
      for (let x = 0; x < width; x++) {
        const offset = (y * width + x) * 4;
        // The translucent pixels belong to the source shadow. Godot supplies the ground shadow.
        if (source[offset + 3] !== 255) continue;

        const original = rgb(source[offset], source[offset + 1], source[offset + 2]);
        let color = colors.get(original);
        if (color === undefined) {
          const light = luma(original);
          const strength = 0.4 + 0.52 * Math.sin(Math.PI * light);
          color = mix(original, blend(ramp, light), strength);
          colors.set(original, color);
        }
        // The source arch faces left; the base sprite faces right before Godot mirrors it.
        p.px(width / 2 - 1 - x, y - height, color);
      }
    }
  };
}
