shader_type canvas_item;
render_mode unshaded;

uniform vec4 water_top : source_color = vec4(0.055, 0.38, 0.50, 1.0);
uniform vec4 water_bottom : source_color = vec4(0.018, 0.16, 0.25, 1.0);
uniform vec4 caustic_color : source_color = vec4(0.66, 0.91, 0.95, 1.0);
uniform float caustic_opacity : hint_range(0.0, 0.2) = 0.055;
uniform float caustic_speed : hint_range(0.0, 0.2) = 0.045;
uniform float bubble_opacity : hint_range(0.0, 0.25) = 0.11;

float hash(float value) {
	return fract(sin(value * 91.713) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	vec3 base = mix(water_top.rgb, water_bottom.rgb, smoothstep(0.0, 1.0, uv.y));
	float slow_time = TIME * caustic_speed;
	float broad_wave = sin((uv.x * 8.0 + uv.y * 5.0 + slow_time) * 6.28318);
	float crossing_wave = sin((uv.x * 5.5 - uv.y * 7.0 - slow_time * 0.73) * 6.28318);
	float caustic = smoothstep(1.46, 1.88, broad_wave + crossing_wave);
	base += caustic_color.rgb * caustic * caustic_opacity;
	float sheen = (1.0 - smoothstep(0.0, 0.12, uv.y)) * 0.11;
	base += caustic_color.rgb * sheen;

	float bubbles = 0.0;
	for (int index = 0; index < 8; index++) {
		float key = float(index) + 1.0;
		float x = 0.08 + hash(key * 2.13) * 0.84;
		float phase = hash(key * 4.71);
		float y = 1.08 - mod(slow_time * (0.42 + hash(key) * 0.34) + phase, 1.18);
		float radius = 0.005 + hash(key * 8.23) * 0.008;
		vec2 delta = uv - vec2(x, y);
		delta.x *= 0.62;
		float distance_to_edge = abs(length(delta) - radius);
		bubbles += 1.0 - smoothstep(0.0015, 0.004, distance_to_edge);
	}
	base += caustic_color.rgb * min(bubbles, 1.0) * bubble_opacity;
	COLOR = vec4(base, 1.0);
}
