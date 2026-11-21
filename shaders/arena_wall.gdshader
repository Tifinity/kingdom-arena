shader_type spatial;
render_mode unshaded;

varying vec3 world;
varying vec3 facing;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	facing = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 offset_x = dFdx(world);
	vec3 offset_y = dFdy(world);
	vec2 offset = vec2(2.0) - mod(FRAGCOORD.xy, 4.0);
	vec3 point = world + offset_x * offset.x + offset_y * offset.y;
	vec2 face = abs(facing.y) > 0.5 ? point.xz : vec2(point.x + point.z, point.y);
	float row = floor(face.y / 24.0);
	vec2 t = mod(vec2(face.x + mod(row, 2.0) * 28.0, face.y), vec2(56.0, 24.0));
	float block = step(4.0, t.x) * step(4.0, t.y);
	float lip = block * (1.0 - step(8.0, t.y));
	float light = 0.93 + facing.y * 0.14 + facing.z * 0.05;
	vec3 mortar = vec3(0.104, 0.105, 0.150);
	vec3 stone = vec3(0.184, 0.184, 0.242) + vec3(0.050, 0.041, 0.042) * lip;
	ALBEDO = mix(mortar, stone, block) * light;
}
