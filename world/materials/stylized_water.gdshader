shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, unshaded, fog_disabled;

uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;

uniform vec4 shore_color : source_color = vec4(0.475, 0.788, 0.796, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.227, 0.604, 0.663, 1.0);
uniform vec4 deep_color : source_color = vec4(0.110, 0.345, 0.435, 1.0);
uniform vec4 tide_wash_color : source_color = vec4(0.360, 0.720, 0.735, 1.0);

uniform float shallow_depth : hint_range(0.1, 3.0, 0.01) = 0.70;
uniform float deep_depth : hint_range(0.5, 12.0, 0.05) = 3.60;
uniform float shore_depth_width : hint_range(0.02, 1.0, 0.01) = 0.16;

uniform float shore_alpha : hint_range(0.1, 1.0, 0.01) = 0.44;
uniform float shallow_alpha : hint_range(0.1, 1.0, 0.01) = 0.60;
uniform float deep_alpha : hint_range(0.1, 1.0, 0.01) = 0.82;

uniform bool tide_effect_enabled = true;
uniform float tide_speed : hint_range(0.1, 3.0, 0.01) = 1.42;
uniform float tide_distance : hint_range(0.0, 0.6, 0.01) = 0.30;
uniform float tide_wash_width : hint_range(0.05, 1.0, 0.01) = 0.38;
uniform float tide_wash_strength : hint_range(0.0, 0.3, 0.01) = 0.11;
uniform float tide_wash_alpha_shift : hint_range(0.0, 0.15, 0.005) = 0.045;

uniform float phase_noise_scale : hint_range(0.001, 0.5, 0.001) = 0.055;
uniform float phase_noise_strength : hint_range(0.0, 2.0, 0.01) = 0.68;
uniform float contour_corner_variation : hint_range(0.0, 0.15, 0.005) = 0.045;
uniform float contour_smoothing_pixels : hint_range(0.0, 2.5, 0.05) = 1.0;
uniform float contour_smoothing_strength : hint_range(0.0, 1.0, 0.01) = 0.72;
uniform float contour_depth_reject : hint_range(0.05, 2.0, 0.01) = 0.60;
uniform float open_water_drift_scale : hint_range(0.001, 0.3, 0.001) = 0.018;
uniform vec2 open_water_drift_speed = vec2(0.010, -0.007);
uniform float open_water_drift_strength : hint_range(0.0, 0.08, 0.001) = 0.045;

uniform float distant_alpha_start : hint_range(10.0, 2000.0, 1.0) = 260.0;
uniform float distant_alpha_end : hint_range(20.0, 5000.0, 1.0) = 1400.0;
uniform vec4 environment_tint : source_color = vec4(1.0);
uniform float environment_brightness : hint_range(0.1, 1.2, 0.01) = 1.0;

varying vec3 world_position;
varying float surface_view_depth;


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


float reconstruct_view_depth(
	vec2 screen_uv,
	float raw_depth,
	mat4 inverse_projection
) {
	#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(screen_uv, raw_depth) * 2.0 - 1.0;
	#else
	vec3 ndc = vec3(screen_uv * 2.0 - 1.0, raw_depth);
	#endif
	vec4 view_position = inverse_projection * vec4(ndc, 1.0);
	return -view_position.z / max(abs(view_position.w), 0.00001);
}


float sample_water_depth(
	vec2 screen_uv,
	float water_surface_depth,
	mat4 inverse_projection
) {
	float raw_depth = texture(depth_texture, screen_uv).r;
	float scene_depth = reconstruct_view_depth(
		screen_uv,
		raw_depth,
		inverse_projection
	);
	return scene_depth - water_surface_depth;
}


float contour_neighbor_weight(
	float center_depth,
	float neighbor_depth,
	float rejection_distance
) {
	if (neighbor_depth <= 0.0) {
		return 0.0;
	}
	float safe_rejection = max(rejection_distance, 0.001);
	return 1.0 - smoothstep(
		safe_rejection * 0.35,
		safe_rejection,
		abs(neighbor_depth - center_depth)
	);
}


void vertex() {
	vec4 world_vertex = MODEL_MATRIX * vec4(VERTEX, 1.0);
	vec4 view_vertex = VIEW_MATRIX * world_vertex;
	world_position = world_vertex.xyz;
	surface_view_depth = -view_vertex.z;
}


void fragment() {
	float raw_depth = texture(depth_texture, SCREEN_UV).r;
	float scene_view_depth = reconstruct_view_depth(
		SCREEN_UV,
		raw_depth,
		INV_PROJECTION_MATRIX
	);
	float water_depth = max(scene_view_depth - surface_view_depth, 0.0);
	water_depth = min(water_depth, deep_depth * 4.0);

	float contour_depth = water_depth;
	float contour_feature_support = 1.0;
	if (tide_effect_enabled) {
	vec2 contour_texel = (
		vec2(1.0) / vec2(textureSize(depth_texture, 0))
		* contour_smoothing_pixels
	);
	float contour_depth_sum = water_depth;
	float contour_weight_sum = 1.0;
	float left_depth = sample_water_depth(
		SCREEN_UV - vec2(contour_texel.x, 0.0),
		surface_view_depth,
		INV_PROJECTION_MATRIX
	);
	float right_depth = sample_water_depth(
		SCREEN_UV + vec2(contour_texel.x, 0.0),
		surface_view_depth,
		INV_PROJECTION_MATRIX
	);
	float upper_depth = sample_water_depth(
		SCREEN_UV - vec2(0.0, contour_texel.y),
		surface_view_depth,
		INV_PROJECTION_MATRIX
	);
	float lower_depth = sample_water_depth(
		SCREEN_UV + vec2(0.0, contour_texel.y),
		surface_view_depth,
		INV_PROJECTION_MATRIX
	);
	float left_weight = contour_neighbor_weight(
		water_depth, left_depth, contour_depth_reject
	);
	float right_weight = contour_neighbor_weight(
		water_depth, right_depth, contour_depth_reject
	);
	float upper_weight = contour_neighbor_weight(
		water_depth, upper_depth, contour_depth_reject
	);
	float lower_weight = contour_neighbor_weight(
		water_depth, lower_depth, contour_depth_reject
	);
	contour_depth_sum += left_depth * left_weight;
	contour_depth_sum += right_depth * right_weight;
	contour_depth_sum += upper_depth * upper_weight;
	contour_depth_sum += lower_depth * lower_weight;
	float neighbor_support = left_weight + right_weight + upper_weight + lower_weight;
	contour_weight_sum += neighbor_support;
	float smoothed_contour_depth = contour_depth_sum / contour_weight_sum;
	contour_depth = mix(
		water_depth,
		smoothed_contour_depth,
		contour_smoothing_strength
	);
	contour_feature_support = smoothstep(0.75, 1.75, neighbor_support);
	}

	float shallow_mix = smoothstep(0.0, shallow_depth, water_depth);
	float deep_mix = smoothstep(shallow_depth, deep_depth, water_depth);
	vec3 water_color = mix(shore_color.rgb, shallow_color.rgb, shallow_mix);
	water_color = mix(water_color, deep_color.rgb, deep_mix);
	float water_alpha = mix(shore_alpha, shallow_alpha, shallow_mix);
	water_alpha = mix(water_alpha, deep_alpha, deep_mix);

	if (tide_effect_enabled) {
	vec2 phase_coordinates = world_position.xz * phase_noise_scale;
	float phase_variation = (
		value_noise(phase_coordinates)
		+ value_noise(phase_coordinates * 0.47 + vec2(9.7, 3.1)) * 0.5
		- 0.75
	) * phase_noise_strength;
	float corner_variation = (
		value_noise(phase_coordinates * 1.73 + vec2(4.2, 13.6)) * 2.0 - 1.0
	) * contour_corner_variation;
	float ebb = sin(TIME * tide_speed + phase_variation) * 0.5 + 0.5;
	float lead_threshold = shore_depth_width + ebb * tide_distance + corner_variation;
	float tide_wash = 1.0 - smoothstep(
		lead_threshold,
		lead_threshold + max(tide_wash_width, 0.001),
		contour_depth
	);
	tide_wash *= contour_feature_support;
	tide_wash *= 1.0 - smoothstep(shallow_depth, deep_depth, water_depth);
	water_color = mix(
		water_color,
		tide_wash_color.rgb,
		tide_wash * tide_wash_strength
	);
	water_alpha = min(
		water_alpha
		+ tide_wash * tide_wash_alpha_shift,
		0.96
	);
	}

	vec2 drift_coordinates = (
		world_position.xz * open_water_drift_scale
		+ TIME * open_water_drift_speed
	);
	float broad_drift = value_noise(drift_coordinates) * 2.0 - 1.0;
	water_color *= 1.0 + broad_drift * open_water_drift_strength * deep_mix;

	float distant_mix = smoothstep(
		distant_alpha_start,
		max(distant_alpha_end, distant_alpha_start + 1.0),
		surface_view_depth
	);
	water_color = mix(water_color, deep_color.rgb, distant_mix * 0.72);
	water_alpha = mix(water_alpha, 0.96, distant_mix);

	water_color *= environment_tint.rgb * environment_brightness;

	ALBEDO = water_color;
	ALPHA = clamp(water_alpha, 0.1, 0.96);
	METALLIC = 0.0;
	SPECULAR = 0.0;
	ROUGHNESS = 1.0;
}
