uniform float cloud_coverage : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float cloud_opacity : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform vec4 cloud_light_color : source_color = vec4(0.70, 0.76, 0.77, 1.0);
uniform vec4 cloud_shadow_color : source_color = vec4(0.31, 0.38, 0.40, 1.0);
uniform vec2 cloud_wind = vec2(0.010, -0.006);
uniform float cloud_scale : hint_range(0.1, 3.0, 0.05) = 0.72;


float cloud_hash(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}


float cloud_value_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 local = fract(point);
	vec2 blend = local * local * (3.0 - 2.0 * local);
	float bottom = mix(
		cloud_hash(cell),
		cloud_hash(cell + vec2(1.0, 0.0)),
		blend.x
	);
	float top = mix(
		cloud_hash(cell + vec2(0.0, 1.0)),
		cloud_hash(cell + vec2(1.0, 1.0)),
		blend.x
	);
	return mix(bottom, top, blend.y);
}


float cloud_shape(vec2 point) {
	vec2 broad_point = floor(point * 5.0) / 5.0;
	vec2 detail_point = floor(point * 13.0) / 13.0;
	float broad = cloud_value_noise(broad_point * 0.62);
	float detail = cloud_value_noise(detail_point * 1.55 + vec2(17.3, 9.1));
	float combined = broad * 0.72 + detail * 0.28;
	return floor(combined * 7.0 + 0.5) / 7.0;
}


vec3 apply_weather_clouds(vec3 base_color, vec3 view_direction) {
	if (cloud_opacity <= 0.001 || view_direction.y <= 0.0) {
		return base_color;
	}
	float safe_height = max(view_direction.y, 0.08);
	vec2 cloud_plane = view_direction.xz / safe_height;
	vec2 cloud_point = (
		cloud_plane + cloud_wind * TIME
	) * cloud_scale;
	float shape = cloud_shape(cloud_point);
	float threshold = mix(0.82, 0.27, cloud_coverage);
	float mask = smoothstep(threshold - 0.08, threshold + 0.08, shape);
	mask = floor(mask * 4.0 + 0.5) / 4.0;
	mask *= smoothstep(0.025, 0.14, view_direction.y);
	mask *= cloud_opacity;
	float body_depth = smoothstep(threshold, 1.0, shape);
	float underside = clamp(
		(1.0 - smoothstep(0.08, 0.72, view_direction.y)) * 0.35
		+ body_depth * 0.65,
		0.0,
		1.0
	);
	vec3 cloud_color = mix(
		cloud_light_color.rgb,
		cloud_shadow_color.rgb,
		underside
	);
	return mix(base_color, cloud_color, mask);
}
