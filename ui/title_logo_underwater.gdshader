shader_type canvas_item;

uniform float horizontal_displacement_pixels : hint_range(0.0, 2.0, 0.25) = 1.5;
uniform float wave_speed : hint_range(0.0, 2.0, 0.05) = 0.55;
uniform float wave_scale : hint_range(0.0, 0.20, 0.005) = 0.055;
uniform vec3 underwater_tint : source_color = vec3(0.78, 0.96, 1.08);
uniform float tint_strength : hint_range(0.0, 0.35, 0.01) = 0.18;
uniform float highlight_strength : hint_range(0.0, 0.15, 0.01) = 0.06;
uniform float bob_amount_pixels : hint_range(0.0, 4.0, 1.0) = 4.0;
uniform float bob_speed : hint_range(0.0, 2.0, 0.05) = 0.65;

void vertex() {
	VERTEX.y += round(
		sin(TIME * bob_speed) * bob_amount_pixels
	);
}

void fragment() {
	float stepped_time = floor(TIME * 12.0) / 12.0;
	float source_row = floor(UV.y / max(TEXTURE_PIXEL_SIZE.y, 0.000001));
	float wave = sin(
		source_row * wave_scale + stepped_time * wave_speed
	);
	float pixel_offset = clamp(
		round(wave * horizontal_displacement_pixels),
		-2.0,
		2.0
	);
	vec2 sample_uv = UV + vec2(pixel_offset * TEXTURE_PIXEL_SIZE.x, 0.0);
	vec4 source = texture(TEXTURE, sample_uv);

	vec3 treated_color = mix(
		source.rgb,
		source.rgb * underwater_tint,
		tint_strength
	);
	float highlight_wave = sin(
		UV.y * 26.0 - stepped_time * wave_speed * 0.8
	) * 0.5 + 0.5;
	float highlight_level = floor(highlight_wave * 3.0) / 3.0;
	treated_color += (
		vec3(0.12, 0.30, 0.34)
		* highlight_level
		* highlight_strength
		* source.a
	);
	COLOR = vec4(treated_color, source.a);
}
