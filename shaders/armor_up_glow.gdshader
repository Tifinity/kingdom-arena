shader_type canvas_item;
render_mode unshaded;

// 重甲斧兵「盔甲护身」：在单位精灵外侧生成一圈会呼吸的金色轮廓与暖光。
// 直接挂在单位 Body 的 AnimatedSprite2D 上，因此会跟随当前动作帧、翻转与受击闪烁。

uniform vec4 rim_color : source_color = vec4(1.0, 0.80, 0.36, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.60, 0.16, 1.0);
uniform float rim_width = 1.0;
uniform float glow_width = 7.0;
uniform float pulse_speed = 4.0;
uniform float body_tint = 0.16;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	// Godot 4 的 fragment COLOR 输入已经包含 TEXTURE 与顶点色，直接用作身体颜色。
	vec4 base = COLOR;
	vec2 texel = TEXTURE_PIXEL_SIZE;
	float pulse = 0.82 + 0.18 * sin(TIME * pulse_speed);

	// 内圈保持清晰的像素轮廓，外圈用多半径采样叠出柔和的暖光。
	float rim = 0.0;
	float halo = 0.0;
	for (int i = 0; i < 8; i++) {
		float angle = float(i) * 0.7853981634;
		vec2 dir = vec2(cos(angle), sin(angle));
		rim = max(rim, texture(TEXTURE, UV + dir * texel * rim_width).a);
		halo += texture(TEXTURE, UV + dir * texel * glow_width * 0.32).a * 0.55;
		halo += texture(TEXTURE, UV + dir * texel * glow_width * 0.62).a * 0.30;
		halo += texture(TEXTURE, UV + dir * texel * glow_width).a * 0.15;
	}
	halo /= 8.0;

	// 只在轮廓外侧生成光环，避免把身体内部糊成一块金色。
	float outside = 1.0 - tex.a;
	float rim_mask = smoothstep(0.0, 0.35, rim) * outside;
	float halo_mask = smoothstep(0.0, 0.55, halo) * outside;

	// 高光绕身体转一圈，让护甲看起来在被“点亮”。
	float body_center = atan(UV.y - 0.47, UV.x - 0.5);
	float sweep = 0.60 + 0.40 * cos(body_center - TIME * 2.0);
	rim_mask *= 0.70 + 0.45 * sweep * pulse;

	vec3 rgb = mix(base.rgb, rim_color.rgb, base.a * body_tint * pulse);
	rgb = mix(rgb, rim_color.rgb, clamp(rim_mask * 0.85, 0.0, 1.0));
	rgb += glow_color.rgb * halo_mask * 0.85 * pulse;

	float alpha = max(base.a, max(rim_mask * 0.95, halo_mask * 0.65));
	COLOR = vec4(rgb, alpha);
}
