shader_type spatial;
render_mode unshaded, depth_draw_never;

uniform float extent = 40.0;
uniform vec4 team_color : source_color;
uniform float team_radius = 0.0;
uniform float selection_radius = 0.0;
uniform float selection_time = 0.0;
uniform float attack_radius = 0.0;
uniform float skill_radius = 0.0;
uniform float foot_ring_depth = 1.0;

float stroke(float distance_to_center, float radius, float width) {
	return 1.0 - step(width * 0.5, abs(distance_to_center - radius));
}

vec4 over(vec4 bottom, vec4 top) {
	return vec4(top.rgb * top.a + bottom.rgb * (1.0 - top.a), top.a + bottom.a * (1.0 - top.a));
}

void fragment() {
	vec2 local = (UV * 2.0 - 1.0) * extent;
	vec2 offset = vec2(2.0) - mod(FRAGCOORD.xy, 4.0);
	vec2 point = local + dFdx(local) * offset.x + dFdy(local) * offset.y;
	float radius = length(point);
	float angle = atan(point.y, point.x);
	vec2 foot_scale = vec2(1.0, 1.0 / foot_ring_depth);
	float foot_distance = length(local * foot_scale);
	float foot_pixel = max(fwidth(foot_distance), 0.001);
	float line_width = max(fwidth(local.x) + fwidth(local.y), 1.0) * 3.2;
	vec4 color = vec4(0.0);

	if (attack_radius > 0.0) {
		color = over(color, vec4(0.49, 0.73, 0.85, stroke(radius, attack_radius, line_width) * 0.42));
	}
	if (skill_radius > 0.0) {
		float dash = step(0.5, fract(angle / TAU * 20.0));
		color = over(color, vec4(0.95, 0.63, 0.35, stroke(radius, skill_radius, line_width) * dash * 0.56));
	}
	if (team_radius > 0.0) {
		float edge = 1.0 - smoothstep(foot_pixel * 0.35, foot_pixel * 1.15, abs(foot_distance - team_radius));
		color = over(color, vec4(team_color.rgb, edge * 0.60));
	}
	if (selection_radius > 0.0) {
		float phase = floor(selection_time * 7.0) * 0.12;
		vec2 foot_point = point * foot_scale;
		float foot_angle = atan(foot_point.y, foot_point.x);
		float dash = step(0.62, fract((foot_angle - phase) / TAU * 8.0));
		float line = stroke(length(foot_point), selection_radius, max(foot_pixel, 1.0) * 3.2) * (0.28 + 0.68 * dash);
		color = over(color, vec4(0.95, 0.77, 0.49, line));
	}
	ALBEDO = color.rgb / max(color.a, 0.001);
	ALPHA = color.a;
}
