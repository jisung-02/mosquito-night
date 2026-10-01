shader_type canvas_item;
uniform float room_time = 0.0;
uniform float fan_power = 0.0;

float band(float x, float a, float b, float feather) {
	return smoothstep(a, a + feather, x) * (1.0 - smoothstep(b - feather, b, x));
}

void fragment() {
	vec2 uv = UV;
	float curtain = band(uv.x, 0.331, 0.441, 0.008) + band(uv.x, 0.682, 0.792, 0.008);
	float pinned = smoothstep(0.04, 0.52, uv.y) * (1.0 - smoothstep(0.61, 0.65, uv.y));
	uv.x += curtain * pinned * (sin(room_time * 0.91 + uv.y * 5.0) + sin(room_time * 0.57 + uv.y * 8.0) * 0.35) * 0.0017;
	vec4 colour = texture(TEXTURE, uv);
	// Only the fan disk changes; its frame and the furniture stay rigid.
	vec2 fan = (UV - vec2(0.895, 0.346)) / vec2(0.039, 0.059);
	float radius = length(fan);
	float disk = smoothstep(0.17, 0.28, radius) * (1.0 - smoothstep(0.78, 0.92, radius));
	float blade = sin(atan(fan.y, fan.x) * 3.0 - room_time * 24.0 * fan_power);
	colour.rgb *= 1.0 + blade * disk * 0.06 * min(1.0, fan_power);
	COLOR = colour;
}
