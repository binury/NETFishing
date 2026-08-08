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
uniform float shoreline_horizontal_reach : hint_range(0.05, 1.5, 0.01) = 0.32;
uniform float contact_fade_depth : hint_range(0.0, 0.1, 0.001) = 0.018;
uniform float open_water_drift_scale : hint_range(0.001, 0.3, 0.001) = 0.018;
uniform vec2 open_water_drift_speed = vec2(0.010, -0.007);
uniform float open_water_drift_strength : hint_range(0.0, 0.08, 0.001) = 0.045;
uniform vec4 surface_mark_color : source_color = vec4(0.580, 0.850, 0.860, 1.0);
uniform vec2 surface_mark_density = vec2(1.30, 0.90);
uniform vec2 surface_mark_drift = vec2(0.045, -0.032);
uniform float surface_mark_strength : hint_range(0.0, 0.3, 0.005) = 0.12;
uniform float surface_mottle_scale : hint_range(0.01, 1.0, 0.01) = 0.11;
uniform vec2 surface_mottle_speed = vec2(-0.018, 0.013);
uniform float surface_mottle_strength : hint_range(0.0, 0.2, 0.005) = 0.07;
uniform vec2 shoreline_mark_density = vec2(4.60, 3.20);
uniform vec2 shoreline_mark_drift = vec2(0.085, -0.060);
uniform float shoreline_mark_depth : hint_range(0.1, 2.0, 0.01) = 0.95;
uniform float shoreline_mark_strength : hint_range(0.0, 1.0, 0.01) = 0.82;
uniform float shoreline_base_fill : hint_range(0.0, 1.0, 0.01) = 0.32;
uniform float shoreline_opacity_boost : hint_range(0.0, 0.5, 0.01) = 0.26;
uniform float surface_highlight_night_floor : hint_range(0.0, 1.0, 0.01) = 0.72;
uniform float shoreline_minimum_reach : hint_range(0.1, 1.0, 0.01) = 0.48;
uniform float shoreline_crest_width : hint_range(0.02, 0.5, 0.01) = 0.13;
uniform float shoreline_trail_spacing : hint_range(0.05, 0.8, 0.01) = 0.28;
uniform float shoreline_trail_strength : hint_range(0.0, 1.0, 0.01) = 0.55;

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


float block_mark(vec2 point, vec2 half_size) {
	return (
		step(abs(point.x), half_size.x)
		* step(abs(point.y), half_size.y)
	);
}


float blocky_mark_layer(
	vec2 flowing_grid,
	float seed,
	float occupancy_threshold
) {
	float row = floor(flowing_grid.y);
	flowing_grid.x += mod(row, 2.0) * 0.43;
	vec2 cell = floor(flowing_grid);
	vec2 local = fract(flowing_grid) - vec2(0.5);
	vec2 jitter = vec2(
		hash_21(cell + vec2(3.7 + seed, 9.1)),
		hash_21(cell + vec2(7.3, 2.9 + seed))
	) - vec2(0.5);
	local -= jitter * vec2(0.52, 0.46);
	local = floor((local + vec2(0.5)) * 8.0) / 8.0 - vec2(0.5);
	float shape_key = hash_21(cell + vec2(13.1 + seed, 5.7));
	float size_key = hash_21(cell + vec2(1.9, 17.3 + seed));
	vec2 half_size = mix(vec2(0.10, 0.07), vec2(0.18, 0.12), size_key);
	float mark = block_mark(local, half_size);
	if (shape_key < 0.34) {
		mark = max(
			mark,
			block_mark(
				local - vec2(half_size.x * 0.8, -0.11),
				vec2(half_size.x * 0.52, 0.045)
			)
		);
	} else if (shape_key < 0.67) {
		mark *= 1.0 - block_mark(
			local - vec2(half_size.x * 0.7, 0.0),
			vec2(0.045)
		);
	} else {
		mark = max(
			mark,
			block_mark(
				local + vec2(half_size.x * 0.75, 0.10),
				vec2(0.055, 0.04)
			)
		);
	}
	return mark * step(
		occupancy_threshold,
		hash_21(cell + vec2(19.7 + seed, 23.3))
	);
}


vec3 reconstruct_view_position(
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
	return view_position.xyz / max(abs(view_position.w), 0.00001);
}


vec3 reconstruct_world_position(
	vec2 screen_uv,
	float raw_depth,
	mat4 inverse_projection,
	mat4 inverse_view
) {
	vec3 view_position = reconstruct_view_position(
		screen_uv,
		raw_depth,
		inverse_projection
	);
	return (inverse_view * vec4(view_position, 1.0)).xyz;
}


float sample_water_depth(
	vec2 screen_uv,
	float water_surface_height,
	mat4 inverse_projection,
	mat4 inverse_view
) {
	float raw_depth = texture(depth_texture, screen_uv).r;
	vec3 scene_world_position = reconstruct_world_position(
		screen_uv,
		raw_depth,
		inverse_projection,
		inverse_view
	);
	return water_surface_height - scene_world_position.y;
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
	vec3 scene_world_position = reconstruct_world_position(
		SCREEN_UV,
		raw_depth,
		INV_PROJECTION_MATRIX,
		INV_VIEW_MATRIX
	);
	float water_depth = max(world_position.y - scene_world_position.y, 0.0);
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
		world_position.y,
		INV_PROJECTION_MATRIX,
		INV_VIEW_MATRIX
	);
	float right_depth = sample_water_depth(
		SCREEN_UV + vec2(contour_texel.x, 0.0),
		world_position.y,
		INV_PROJECTION_MATRIX,
		INV_VIEW_MATRIX
	);
	float upper_depth = sample_water_depth(
		SCREEN_UV - vec2(0.0, contour_texel.y),
		world_position.y,
		INV_PROJECTION_MATRIX,
		INV_VIEW_MATRIX
	);
	float lower_depth = sample_water_depth(
		SCREEN_UV + vec2(0.0, contour_texel.y),
		world_position.y,
		INV_PROJECTION_MATRIX,
		INV_VIEW_MATRIX
	);
	float upper_left_depth = sample_water_depth(
		SCREEN_UV - contour_texel,
		world_position.y,
		INV_PROJECTION_MATRIX,
		INV_VIEW_MATRIX
	);
	float upper_right_depth = sample_water_depth(
		SCREEN_UV + vec2(contour_texel.x, -contour_texel.y),
		world_position.y,
		INV_PROJECTION_MATRIX,
		INV_VIEW_MATRIX
	);
	float lower_left_depth = sample_water_depth(
		SCREEN_UV + vec2(-contour_texel.x, contour_texel.y),
		world_position.y,
		INV_PROJECTION_MATRIX,
		INV_VIEW_MATRIX
	);
	float lower_right_depth = sample_water_depth(
		SCREEN_UV + contour_texel,
		world_position.y,
		INV_PROJECTION_MATRIX,
		INV_VIEW_MATRIX
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
	float diagonal_scale = 0.70710678;
	float upper_left_weight = contour_neighbor_weight(
		water_depth, upper_left_depth, contour_depth_reject
	) * diagonal_scale;
	float upper_right_weight = contour_neighbor_weight(
		water_depth, upper_right_depth, contour_depth_reject
	) * diagonal_scale;
	float lower_left_weight = contour_neighbor_weight(
		water_depth, lower_left_depth, contour_depth_reject
	) * diagonal_scale;
	float lower_right_weight = contour_neighbor_weight(
		water_depth, lower_right_depth, contour_depth_reject
	) * diagonal_scale;
	contour_depth_sum += left_depth * left_weight;
	contour_depth_sum += right_depth * right_weight;
	contour_depth_sum += upper_depth * upper_weight;
	contour_depth_sum += lower_depth * lower_weight;
	contour_depth_sum += upper_left_depth * upper_left_weight;
	contour_depth_sum += upper_right_depth * upper_right_weight;
	contour_depth_sum += lower_left_depth * lower_left_weight;
	contour_depth_sum += lower_right_depth * lower_right_weight;
	float neighbor_support = (
		left_weight
		+ right_weight
		+ upper_weight
		+ lower_weight
		+ upper_left_weight
		+ upper_right_weight
		+ lower_left_weight
		+ lower_right_weight
	);
	contour_weight_sum += neighbor_support;
	float smoothed_contour_depth = contour_depth_sum / contour_weight_sum;
	contour_depth = mix(
		water_depth,
		smoothed_contour_depth,
		contour_smoothing_strength
	);
	contour_feature_support = smoothstep(0.75, 1.75, neighbor_support);
	}

	vec2 scene_world_dx = dFdx(scene_world_position.xz);
	vec2 scene_world_dy = dFdy(scene_world_position.xz);
	float horizontal_dx = max(length(scene_world_dx), 0.0001);
	float horizontal_dy = max(length(scene_world_dy), 0.0001);
	float depth_gradient = length(vec2(
		dFdx(water_depth) / horizontal_dx,
		dFdy(water_depth) / horizontal_dy
	));
	float estimated_shore_distance = min(
		water_depth / max(depth_gradient, 0.001),
		shoreline_horizontal_reach * 4.0
	);
	float proximity_center = shoreline_horizontal_reach * 0.86;
	float proximity_filter_width = max(
		fwidth(estimated_shore_distance) * 1.5,
		shoreline_horizontal_reach * 0.12
	);
	float shoreline_proximity = 1.0 - smoothstep(
		max(proximity_center - proximity_filter_width, 0.0),
		proximity_center + proximity_filter_width,
		estimated_shore_distance
	);
	float contact_filter_width = max(fwidth(water_depth) * 1.5, 0.004);
	float contact_stability = smoothstep(
		max(contact_fade_depth - contact_filter_width, 0.0),
		contact_fade_depth + contact_filter_width,
		water_depth
	);

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
	tide_wash *= shoreline_proximity;
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

	vec2 flowing_grid = (
		world_position.xz * surface_mark_density
		+ TIME * surface_mark_drift
	);
	float surface_row = floor(flowing_grid.y);
	flowing_grid.x += mod(surface_row, 2.0) * 0.43;
	vec2 surface_cell = floor(flowing_grid);
	vec2 surface_local = fract(flowing_grid) - vec2(0.5);
	vec2 surface_jitter = vec2(
		hash_21(surface_cell + vec2(3.7, 9.1)),
		hash_21(surface_cell + vec2(7.3, 2.9))
	) - vec2(0.5);
	surface_local -= surface_jitter * vec2(0.52, 0.46);
	surface_local = (
		floor((surface_local + vec2(0.5)) * 8.0) / 8.0
		- vec2(0.5)
	);
	float surface_shape = hash_21(surface_cell + vec2(13.1, 5.7));
	float surface_size = hash_21(surface_cell + vec2(1.9, 17.3));
	vec2 surface_half_size = mix(
		vec2(0.10, 0.07),
		vec2(0.18, 0.12),
		surface_size
	);
	float surface_mark = block_mark(surface_local, surface_half_size);
	if (surface_shape < 0.34) {
		surface_mark = max(
			surface_mark,
			block_mark(
				surface_local - vec2(surface_half_size.x * 0.8, -0.11),
				vec2(surface_half_size.x * 0.52, 0.045)
			)
		);
	} else if (surface_shape < 0.67) {
		surface_mark *= 1.0 - block_mark(
			surface_local - vec2(surface_half_size.x * 0.7, 0.0),
			vec2(0.045)
		);
	} else {
		surface_mark = max(
			surface_mark,
			block_mark(
				surface_local + vec2(surface_half_size.x * 0.75, 0.10),
				vec2(0.055, 0.04)
			)
		);
	}
	surface_mark *= step(
		0.22,
		hash_21(surface_cell + vec2(19.7, 23.3))
	);
	float mark_visibility = mix(1.0, 0.68, deep_mix);
	float surface_highlight = (
		surface_mark * surface_mark_strength * mark_visibility
	);

	vec2 shoreline_phase_coordinates = world_position.xz * phase_noise_scale;
	float shoreline_phase = (
		value_noise(shoreline_phase_coordinates)
		+ value_noise(
			shoreline_phase_coordinates * 0.47 + vec2(9.7, 3.1)
		) * 0.5
		- 0.75
	) * phase_noise_strength;
	float shoreline_cycle = (
		sin(TIME * tide_speed + shoreline_phase) * 0.5 + 0.5
	);
	float animated_shoreline_depth = shoreline_mark_depth * mix(
		shoreline_minimum_reach,
		1.0,
		shoreline_cycle
	);
	float shoreline_mask = 1.0 - smoothstep(
		max(animated_shoreline_depth * 0.08, 0.01),
		max(animated_shoreline_depth, 0.02),
		contour_depth
	);
	float shoreline_depth_visibility = 1.0 - smoothstep(
		shallow_depth,
		deep_depth,
		water_depth
	);
	shoreline_mask *= shoreline_depth_visibility;
	float shoreline_lead_depth = animated_shoreline_depth * 0.82;
	float shoreline_lead_crest = 1.0 - smoothstep(
		shoreline_crest_width * 0.25,
		shoreline_crest_width,
		abs(contour_depth - shoreline_lead_depth)
	);
	float shoreline_trail_depth = max(
		shoreline_lead_depth - shoreline_trail_spacing,
		shoreline_crest_width
	);
	float shoreline_trail_crest = 1.0 - smoothstep(
		shoreline_crest_width * 0.40,
		shoreline_crest_width * 1.45,
		abs(contour_depth - shoreline_trail_depth)
	);
	shoreline_lead_crest *= shoreline_depth_visibility;
	shoreline_trail_crest *= (
		shoreline_depth_visibility * shoreline_trail_strength
	);
	float shoreline_marks = max(
		blocky_mark_layer(
			world_position.xz * shoreline_mark_density
			+ TIME * shoreline_mark_drift,
			17.0,
			0.04
		),
		blocky_mark_layer(
			world_position.xz * shoreline_mark_density * 1.37
			- TIME * shoreline_mark_drift.yx * 0.73,
			41.0,
			0.08
		)
	);
	float shoreline_foam = shoreline_mask * mix(
		shoreline_base_fill,
		1.0,
		shoreline_marks
	);
	float moving_crests = max(
		shoreline_lead_crest,
		shoreline_trail_crest
	) * mix(0.68, 1.0, shoreline_marks);
	shoreline_foam = max(shoreline_foam, moving_crests);
	shoreline_foam *= shoreline_proximity;
	water_alpha = min(
		water_alpha + shoreline_foam * shoreline_opacity_boost,
		0.98
	);
	water_alpha *= contact_stability;

	float surface_mottle = value_noise(
		world_position.xz * surface_mottle_scale
		+ TIME * surface_mottle_speed
	);
	surface_mottle = floor(surface_mottle * 6.0) / 5.0;
	water_color *= 1.0 + (
		surface_mottle * 2.0 - 1.0
	) * surface_mottle_strength;

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
	vec3 visible_highlight_color = surface_mark_color.rgb * max(
		environment_tint.rgb * environment_brightness,
		vec3(surface_highlight_night_floor)
	);
	float visible_highlight = max(
		surface_highlight,
		shoreline_foam * shoreline_mark_strength
	);
	water_color = mix(
		water_color,
		visible_highlight_color,
		clamp(visible_highlight, 0.0, 1.0)
	);

	ALBEDO = water_color;
	ALPHA = clamp(water_alpha, 0.1, 0.96);
	METALLIC = 0.0;
	SPECULAR = 0.0;
	ROUGHNESS = 1.0;
}
