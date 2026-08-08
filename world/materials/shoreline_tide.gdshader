shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

uniform vec4 lead_color : source_color = vec4(0.780, 0.960, 0.930, 1.0);
uniform vec4 trail_color : source_color = vec4(0.500, 0.840, 0.820, 1.0);
uniform float ribbon_width : hint_range(0.2, 2.0, 0.01) = 1.35;
uniform float land_inset : hint_range(0.0, 0.4, 0.01) = 0.12;
uniform float tide_speed : hint_range(0.1, 3.0, 0.01) = 1.42;
uniform float tide_distance : hint_range(0.0, 0.6, 0.01) = 0.42;
uniform float lead_width : hint_range(0.01, 0.2, 0.005) = 0.14;
uniform float trail_width : hint_range(0.02, 0.4, 0.005) = 0.32;
uniform float lead_strength : hint_range(0.0, 1.0, 0.01) = 0.88;
uniform float trail_strength : hint_range(0.0, 1.0, 0.01) = 0.52;
uniform float phase_scale : hint_range(0.001, 0.2, 0.001) = 0.035;
uniform float phase_strength : hint_range(0.0, 2.0, 0.01) = 0.55;

varying vec3 world_position;


float hash_21(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}


float value_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 local = fract(point);
	vec2 blend = local * local * (3.0 - 2.0 * local);
	float bottom = mix(hash_21(cell), hash_21(cell + vec2(1.0, 0.0)), blend.x);
	float top = mix(
		hash_21(cell + vec2(0.0, 1.0)),
		hash_21(cell + vec2(1.0, 1.0)),
		blend.x
	);
	return mix(bottom, top, blend.y);
}


float soft_line(float coordinate, float center, float width) {
	float normalized_width = max(width / ribbon_width, 0.001);
	float derivative_width = min(fwidth(coordinate) * 1.25, normalized_width * 0.65);
	return 1.0 - smoothstep(
		max(normalized_width * 0.25 - derivative_width, 0.0),
		normalized_width + derivative_width,
		abs(coordinate - center)
	);
}


void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}


void fragment() {
	float phase = (
		value_noise(world_position.xz * phase_scale) * 2.0 - 1.0
	) * phase_strength;
	float ebb = sin(TIME * tide_speed + phase) * 0.5 + 0.5;
	float shoreline = land_inset / ribbon_width;
	float lead_position = shoreline + ebb * tide_distance / ribbon_width;
	float trail_position = lead_position + max(tide_distance * 0.72, 0.10) / ribbon_width;
	float lead = soft_line(UV.y, lead_position, lead_width);
	float trail = soft_line(UV.y, trail_position, trail_width);
	float edge_fade = smoothstep(0.0, 0.055, UV.y) * (1.0 - smoothstep(0.90, 1.0, UV.y));
	float lead_alpha = lead * lead_strength;
	float trail_alpha = trail * trail_strength;
	float combined_alpha = max(lead_alpha, trail_alpha) * edge_fade;
	ALBEDO = mix(trail_color.rgb, lead_color.rgb, lead_alpha);
	ALPHA = combined_alpha;
}
