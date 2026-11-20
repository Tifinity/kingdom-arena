shader_type spatial;
// 地板先铺色。保留深度测试，让墙面挡住地板，同时让角色脚点以下的像素完整显示。
render_mode unshaded, depth_draw_never;

uniform vec2 field_min;
uniform vec2 field_max;
varying vec2 ground;

void vertex() {
	ground = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 tile = floor(ground / vec2(82.0, 54.0));
	float variation = fract(sin(dot(tile, vec2(31.21, 17.35))) * 43758.5453);
	vec2 seam = mod(ground, vec2(82.0, 54.0));
	float grout = step(1.25, min(seam.x, seam.y));
	vec2 center = (field_min + field_max) * 0.5;
	vec2 edge_dist = min(ground - field_min, field_max - ground);
	float edge = min(edge_dist.x, edge_dist.y);
	float inside = step(0.0, edge);
	vec3 paving = vec3(0.076, 0.096, 0.135) + variation * 0.023;
	paving *= mix(0.67, 1.0, grout);
	paving *= mix(0.67, 1.0, inside);
	float border = inside * (1.0 - smoothstep(1.0, 3.0, abs(edge - 3.0)));

	vec2 from_center = ground - center;
	float radius = length(from_center);
	float circle = 1.0 - smoothstep(1.0, 2.8, min(abs(radius - 104.0), abs(radius - 117.0)));
	float diamond = 1.0 - smoothstep(1.0, 2.8, abs(abs(from_center.x) + abs(from_center.y) - 70.0));
	float center_line = (1.0 - smoothstep(0.8, 2.0, abs(from_center.x))) * step(122.0, radius);
	vec3 team_tint = mix(vec3(0.016, 0.040, 0.067), vec3(0.054, 0.020, 0.032), smoothstep(-610.0, 610.0, from_center.x));
	ALBEDO = paving + inside * team_tint + vec3(0.23, 0.18, 0.115) * (border + 0.62 * max(circle, diamond) + 0.27 * inside * center_line);
	// 进入按 render_priority 绘制的通道，地板仍完全不透明。
	ALPHA = 1.0;
}
