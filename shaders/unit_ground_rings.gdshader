shader_type spatial;
render_mode unshaded, depth_draw_never;

uniform float extent = 40.0;
uniform vec4 team_color : source_color;
uniform float team_radius = 0.0;
uniform float selection_radius = 0.0;
uniform float selection_time = 0.0;
uniform float attack_radius = 0.0;
uniform float skill_radius = 0.0;

float stroke(float distance_to_center, float radius, float width, float aa) {
	return 1.0 - smoothstep(width * 0.5 - aa, width * 0.5 + aa, abs(distance_to_center - radius));
}

vec4 over(vec4 bottom, vec4 top) {
	return vec4(top.rgb * top.a + bottom.rgb * (1.0 - top.a), top.a + bottom.a * (1.0 - top.a));
}

void fragment() {
	vec2 point = (UV * 2.0 - 1.0) * extent;
	float distance_to_center = length(point);
	float aa = max(fwidth(distance_to_center) * 0.65, 0.3);
	float angle = atan(point.y, point.x);
	vec4 color = vec4(0.0);

	if (attack_radius > 0.0) {
		color = over(color, vec4(0.45, 0.72, 1.0, stroke(distance_to_center, attack_radius, 1.6, aa) * 0.26));
	}
	if (skill_radius > 0.0) {
		float dash = step(0.5, fract(angle / TAU * 14.0));
		color = over(color, vec4(1.0, 0.58, 0.22, stroke(distance_to_center, skill_radius, 1.8, aa) * dash * 0.3));
	}
	if (team_radius > 0.0) {
		float fill = (1.0 - smoothstep(team_radius - aa, team_radius + aa, distance_to_center)) * 0.1;
		float outer = stroke(distance_to_center, team_radius, 2.0, aa) * 0.34;
		float inner = stroke(distance_to_center, team_radius * 0.78, 1.0, aa) * 0.14;
		color = over(color, vec4(team_color.rgb, max(outer, fill + inner)));
	}
	if (selection_radius > 0.0) {
		float dash = step(fract((angle - selection_time * 1.4) / TAU * 8.0), 0.26 * 8.0 / TAU);
		float line = stroke(distance_to_center, selection_radius, 1.5, aa) * 0.16;
		line = max(line, stroke(distance_to_center, selection_radius, 2.5, aa) * dash * 0.85);
		color = over(color, vec4(0.906, 0.769, 0.42, line));
	}

	ALBEDO = color.rgb / max(color.a, 0.001);
	ALPHA = color.a;
}
