shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;
uniform vec2 floor_min;
uniform vec2 floor_max;
varying vec2 ground;

void vertex() {
	ground = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	if (any(lessThan(ground, floor_min)) || any(greaterThan(ground, floor_max))) {
		discard;
	}
	vec4 pixel = texture(atlas, UV);
	ALBEDO = pixel.rgb;
	ALPHA = pixel.a;
}
