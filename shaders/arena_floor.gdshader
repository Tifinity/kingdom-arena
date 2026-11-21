shader_type spatial;
// 地板先铺色。墙体参与深度测试，角色脚点以下的像素仍可显示。
render_mode unshaded, depth_draw_never;

uniform vec2 field_min;
uniform vec2 field_max;
varying vec2 ground;

void vertex() {
	ground = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

float hash_cell(vec2 cell) {
	return fract(dot(fract(cell * vec2(0.1031, 0.11369)), vec2(14.23, 41.87)));
}

void fragment() {
	vec2 offset = vec2(2.0) - mod(FRAGCOORD.xy, 4.0);
	vec2 point = ground + dFdx(ground) * offset.x + dFdy(ground) * offset.y;
	vec2 center = (field_min + field_max) * 0.5;
	vec2 mark = point - center;
	vec2 tile_size = vec2(72.0, 52.0);
	float row = floor(point.y / tile_size.y);
	vec2 staggered = point + vec2(mod(row, 2.0) * tile_size.x * 0.5, 0.0);
	vec2 tile = floor(staggered / tile_size);
	vec2 local = mod(staggered, tile_size);
	float vein = hash_cell(tile);

	vec3 mortar = vec3(0.080, 0.087, 0.128);
	vec3 stone = mix(vec3(0.139, 0.147, 0.205), vec3(0.182, 0.187, 0.241), floor(vein * 4.0) / 3.0);
	float seam = step(4.0, local.x) * step(5.0, local.y);
	float lit_edge = seam * (1.0 - step(10.0, local.y));
	float bevel = seam * max(step(68.0, local.x), step(47.0, local.y));
	float chips = step(0.68, vein) * step(14.0, local.x) * (1.0 - step(34.0, local.x)) * step(17.0, local.y) * (1.0 - step(23.0, local.y));
	vec3 color = mix(mortar, stone + lit_edge * 0.028 - bevel * 0.023 - chips * 0.022, seam);

	vec2 edge_dist = min(point - field_min, field_max - point);
	float edge = min(edge_dist.x, edge_dist.y);
	float inside = step(0.0, edge);
	vec3 team = mix(vec3(0.003, 0.020, 0.037), vec3(0.036, 0.006, 0.011), smoothstep(-360.0, 360.0, mark.x));
	color += team * mix(0.50, 1.0, inside);
	color *= mix(0.86, 1.0, inside);

	vec3 brass = vec3(0.410, 0.301, 0.208);
	vec3 dark_brass = vec3(0.252, 0.199, 0.175);
	float outer_edge = 1.0 - step(4.0, abs(edge));
	float inner_edge = 1.0 - step(3.0, abs(edge - 16.0));
	float edge_steps = step(0.5, fract((point.x + point.y) / 44.0));
	color = mix(color, dark_brass, max(outer_edge * 0.8, inner_edge * edge_steps * 0.46));

	// 嵌在石板中的八角徽记、菱纹与四枚铆钉。
	vec2 axes = abs(mark);
	float octagon = max(max(axes.x, axes.y), (axes.x + axes.y) * 0.72);
	float emblem = 1.0 - step(5.0, min(abs(octagon - 96.0), abs(octagon - 112.0)));
	float diamond = 1.0 - step(5.0, abs(axes.x + axes.y - 63.0));
	float studs = (1.0 - step(8.0, max(abs(axes.x - 120.0), abs(axes.y - 120.0))));
	float center_line = step(126.0, axes.y) * (1.0 - step(4.0, axes.x)) * step(0.46, fract(point.y / 40.0));
	color = mix(color, brass, max(max(emblem * 0.70, diamond * 0.75), max(studs * 0.85, center_line * 0.32)));

	ALBEDO = color;
	ALPHA = 1.0;
}
