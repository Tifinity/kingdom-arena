// PIXELFX_DIR=../pixelfx node tools/export_roster_skill_fx.mjs [preview-directory]
import { mkdirSync, writeFileSync } from "node:fs";
import { join, resolve } from "node:path";
import { pathToFileURL } from "node:url";
import { parseArgs } from "node:util";
import * as holyBolt from "./holy_bolt_fx.mjs";
import * as rangePulse from "./roster_ground_pulse.mjs";
import * as sanctuary from "./sanctuary_fx.mjs";

const pixelfx = resolve(process.env.PIXELFX_DIR ?? "../pixelfx");
const fromPixelfx = path => import(pathToFileURL(join(pixelfx, path)));
const { loadEffect, renderFrames, contactSheet, spriteSheet, save, writeVideo } =
  await fromPixelfx("tools/lib/fxlib.mjs");
const { stockActor } = await fromPixelfx("src/core/index.js");

const gold = ["#442433", "#764131", "#9b6130", "#d89236", "#f6bc4f", "#ffd875", "#ffefa7", "#fffbe4"];
const mint = ["#12312a", "#245249", "#357358", "#58a671", "#84ca80", "#c1e99b", "#ecf5c4", "#fffbe1"];
const acid = ["#1f2530", "#314536", "#477b2b", "#77aa33", "#a2cf3d", "#d0ed67", "#e4f999", "#ffffcf"];
const bone = ["#251b35", "#453353", "#755e76", "#a9959b", "#cabbaf", "#e4d6b8", "#fff3d5"];
const frost = ["#14223f", "#20396b", "#325d9a", "#4895cb", "#77d7ef", "#b1edff", "#d9faff", "#ffffff"];
const fire = ["#451b20", "#9d3523", "#e85420", "#ff9b36", "#ffbf50", "#ffeb9b", "#fff9d5"];

const ground = { id: "skill-ground-pulse", meta: rangePulse.meta, mod: rangePulse };
const effects = [
  { name: "bone_arrow", id: "projectiles/arrow", flight: true, scale: 1.05,
    opts: { palette: bone, wood: ["#382e39", "#5f5055", "#9d8d7e", "#d4bfa0"], steel: ["#4c4455", "#8f7f8b", "#d3c3bb", "#fff3d5"], wind: "#c7b6cb", light: 0.78 } },
  { name: "bone_contact", id: "impacts/hit-spark", scale: 0.80,
    pivotY: 44, opts: { palette: bone, aim: -0.65, light: 0.50 } },
  { name: "acid_splash", id: "nature/acid-splash", scale: 1.45, start: 9, fps: 66,
    opts: { palette: acid, light: 0.65 } },
  { name: "acid_range", effect: ground, groundRadius: rangePulse.radius, burst: "acid_splash", opts: { palette: acid } },
  { name: "holy_bolt", effect: { id: "holy-missile", meta: holyBolt.meta, mod: holyBolt },
    flight: true, scale: 1.02 },
  { name: "holy_contact", id: "impacts/hit-spark", scale: 0.95, pivotY: 44,
    opts: { palette: gold, aim: -0.9, light: 0.8 } },
  // Heal uses the actor mask for sparks. Empty pixels keep the sprite sheet clean on older pixelfx versions.
  { name: "blessing", id: "holy/heal", scale: 1, start: 4, fps: 48,
    opts: { palette: mint, light: 0.65, actor: { ...stockActor(2), pixels: null } } },
  { name: "grace", id: "holy/feather-burst", scale: 0.60, stride: 2, fps: 58,
    opts: { palette: gold, glow: "#ffe29a", light: 0.46 } },
  { name: "sanctuary", effect: { id: "sanctuary-healing-ring", meta: sanctuary.meta, mod: sanctuary },
    groundRadius: sanctuary.radius, clipToTrainingFloor: true },
  { name: "fireball", id: "fire/fireball", flight: true, scale: 1.10,
    opts: { radius: 9, speed: 145, light: 0.92 } },
  { name: "fire_contact", id: "impacts/hit-spark", scale: 1.30, pivotY: 44,
    opts: { palette: fire, aim: -0.85, light: 0.88 } },
  { name: "fire_landing", effect: ground, groundRadius: rangePulse.radius, burst: "fire_contact",
    clipToTrainingFloor: true, opts: { palette: fire } },
  { name: "icebolt", id: "ice/ice-lance", flight: true, scale: 0.90,
    opts: { palette: frost, length: 37, light: 0.7 } },
  { name: "ice_contact", id: "ice/snowflake-burst", scale: 0.86, start: 5, fps: 88, pivotY: 58,
    opts: { palette: frost, count: 7, light: 0.78 } },
];

const { positionals: [preview], values: { effect: selected } } = parseArgs({
  allowPositionals: true,
  options: { effect: { type: "string" } },
});
if (selected && !effects.some(spec => spec.name === selected)) throw new Error(`Unknown effect: ${selected}`);
for (const spec of effects.filter(spec => !selected || spec.name === selected)) {
  const effect = spec.effect ?? await loadEffect(spec.id);
  const render = renderFrames(effect, { actor: false, options: spec.opts });
  render.frames = render.frames.slice(spec.start || 0).filter((_, index) => index % (spec.stride ?? 1) === 0);
  render.n = render.frames.length;
  render.fps = spec.fps ?? render.fps;
  if (preview) {
    mkdirSync(preview, { recursive: true });
    save(join(preview, spec.name + ".png"), contactSheet(effect, render, { max: 12, zoom: 1 }));
    writeVideo(join(preview, spec.name + ".gif"), render, 1);
    continue;
  }

  const name = "roster_" + spec.name;
  const sheet = spriteSheet(effect, render, name);
  save(join("assets/fx/pixelfx", name + ".png"), sheet.png);
  const { frameSize: [w, h], frames, columns, pivot: [x, y], fps } = sheet.json.meta.pixelfx;
  const rows = Math.ceil(frames / columns);
  const offset = [w / 2 - x, h / 2 - (spec.pivotY ?? y)];

  if (spec.groundRadius) {
    const burstResource = spec.burst
      ? `\n[ext_resource type="PackedScene" path="res://scenes/fx/roster_${spec.burst}.tscn" id="3"]`
      : "";
    const burstProperty = spec.burst ? '\nburst_scene = ExtResource("3")' : "";
    const clipProperty = spec.clipToTrainingFloor ? "\nclip_to_training_floor = true" : "";
    writeFileSync(join("scenes/fx", name + ".tscn"), `[gd_scene format=3]

[ext_resource type="Script" path="res://scripts/fx/roster_area_fx.gd" id="1"]
[ext_resource type="Texture2D" path="res://assets/fx/pixelfx/${name}.png" id="2"]${burstResource}

[node name="RosterAreaFx" type="Node2D"]
script = ExtResource("1")
frame_count = ${frames}
frames_per_second = ${fps}.0
sheet_radius = ${spec.groundRadius}.0${clipProperty}${burstProperty}

[node name="Ground" type="Sprite2D" parent="."]
texture_filter = 1
texture = ExtResource("2")
hframes = ${columns}
vframes = ${rows}
`);
    continue;
  }
  const atlasFrames = Array.from({ length: frames }, (_, frame) => `[sub_resource type="AtlasTexture" id="f${frame}"]
atlas = ExtResource("atlas")
region = Rect2(${frame % columns * w}, ${Math.floor(frame / columns) * h}, ${w}, ${h})
filter_clip = true
`).join("\n");
  const animation = `animations = [{
"frames": [${Array.from({ length: frames }, (_, frame) => `{"duration": 1.0, "texture": SubResource("f${frame}")}`).join(",\n")}],
"loop": ${Boolean(spec.flight)},
"name": &"default",
"speed": ${fps}.0
}]
`;
  const texture = `[ext_resource type="Texture2D" path="res://assets/fx/pixelfx/${name}.png" id="atlas"]`;
  if (spec.flight) {
    writeFileSync(join("resources/visuals", name + ".tres"), `[gd_resource type="SpriteFrames" format=3]

${texture}

${atlasFrames}
[resource]
${animation}`);
    console.log(`${name}: scale ${spec.scale}, offset Vector2(${offset.join(", ")})`);
  } else {
    const script = spec.name === "blessing" ? "roster_blessing_fx" : "arena_billboard_effect";
    writeFileSync(join("scenes/fx", name + ".tscn"), `[gd_scene format=3]

[ext_resource type="Script" path="res://scripts/fx/${script}.gd" id="script"]
${texture}

${atlasFrames}
[sub_resource type="SpriteFrames" id="frames"]
${animation}
[node name="RosterBillboardFx" type="AnimatedSprite2D"]
texture_filter = 1
scale = Vector2(${spec.scale}, ${spec.scale})
offset = Vector2(${offset.join(", ")})
sprite_frames = SubResource("frames")
script = ExtResource("script")
`);
  }
}
