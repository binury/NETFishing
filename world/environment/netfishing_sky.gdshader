shader_type sky;

#include "res://world/environment/netfishing_sky_clouds.gdshaderinc"

uniform vec4 sky_top_color : source_color = vec4(0.204, 0.498, 0.643, 1.0);
uniform vec4 sky_horizon_color : source_color = vec4(0.663, 0.843, 0.847, 1.0);
uniform vec4 ground_bottom_color : source_color = vec4(0.157, 0.361, 0.439, 1.0);
uniform vec4 ground_horizon_color : source_color = vec4(0.549, 0.749, 0.765, 1.0);
uniform float horizon_blend_width : hint_range(0.005, 0.15, 0.005) = 0.01;
uniform vec4 fog_horizon_color : source_color = vec4(0.13, 0.21, 0.32, 1.0);
uniform float fog_horizon_occlusion : hint_range(0.0, 1.0) = 0.0;

uniform vec3 sun_direction = vec3(0.0, 1.0, 0.0);
uniform vec4 sun_color : source_color = vec4(1.0, 0.86, 0.46, 1.0);
uniform float sun_visibility : hint_range(0.0, 1.0) = 1.0;
uniform float sun_radius : hint_range(0.005, 0.15) = 0.055;
uniform float sun_edge_softness : hint_range(0.001, 0.03) = 0.003;
uniform float sun_halo_radius : hint_range(0.02, 0.35) = 0.14;
uniform float sun_halo_strength : hint_range(0.0, 1.0) = 0.16;

uniform vec3 moon_direction = vec3(0.0, -1.0, 0.0);
uniform vec4 moon_color : source_color = vec4(0.78, 0.88, 1.0, 1.0);
uniform float moon_visibility : hint_range(0.0, 1.0) = 0.0;
uniform float moon_radius : hint_range(0.005, 0.15) = 0.045;
uniform float moon_edge_softness : hint_range(0.001, 0.03) = 0.003;
uniform float moon_halo_radius : hint_range(0.02, 0.35) = 0.11;
uniform float moon_halo_strength : hint_range(0.0, 1.0) = 0.12;

uniform vec4 star_color : source_color = vec4(0.72, 0.82, 0.96, 1.0);
uniform float star_visibility : hint_range(0.0, 1.0) = 0.0;
uniform float star_strength : hint_range(0.0, 1.0) = 0.72;


float star_hash(vec2 point) {
	vec3 value = fract(vec3(point.xyx) * vec3(0.1031, 0.1030, 0.0973));
	value += dot(value, value.yzx + 33.33);
	return fract((value.x + value.y) * value.z);
}


vec2 star_hash2(vec2 point) {
	return vec2(
		star_hash(point),
		star_hash(point + vec2(19.19, 7.73))
	);
}


float procedural_star_field(vec3 view_direction) {
	// Map the upper hemisphere to one stable world-direction diamond. This
	// avoids a longitude seam and keeps the stars fixed as the camera moves.
	float direction_sum = max(
		abs(view_direction.x)
		+ abs(view_direction.y)
		+ abs(view_direction.z),
		0.0001
	);
	vec2 star_uv = view_direction.xz / direction_sum * 0.5 + 0.5;
	vec2 star_point = star_uv * 190.0;
	vec2 cell = floor(star_point);
	vec2 local_point = fract(star_point);
	float spawn_roll = star_hash(cell + vec2(3.17, 11.83));
	vec2 point_center = mix(
		vec2(0.18),
		vec2(0.82),
		star_hash2(cell + vec2(41.0, 73.0))
	);
	float point_radius = mix(
		0.065,
		0.13,
		star_hash(cell + vec2(89.0, 17.0))
	);
	float point_shape = 1.0 - smoothstep(
		point_radius,
		point_radius + 0.045,
		distance(local_point, point_center)
	);
	float point_exists = step(0.965, spawn_roll);
	float point_brightness = mix(
		0.42,
		1.0,
		smoothstep(0.965, 1.0, spawn_roll)
	);
	float upper_sky_fade = smoothstep(0.055, 0.22, view_direction.y);
	return point_shape * point_exists * point_brightness * upper_sky_fade;
}


void sky() {
	vec3 view_direction = normalize(EYEDIR);
	float above_horizon = max(view_direction.y, 0.0);
	float below_horizon = max(-view_direction.y, 0.0);
	vec3 sky_color = mix(
		sky_horizon_color.rgb,
		sky_top_color.rgb,
		pow(above_horizon, 0.72)
	);
	vec3 ground_color = mix(
		ground_horizon_color.rgb,
		ground_bottom_color.rgb,
		pow(below_horizon, 0.16)
	);
	vec3 base_color = mix(
		ground_color,
		sky_color,
		smoothstep(
			-horizon_blend_width,
			horizon_blend_width,
			view_direction.y
		)
	);
	float stars = procedural_star_field(view_direction);
	base_color = mix(
		base_color,
		star_color.rgb,
		stars * star_visibility * star_strength
	);

	float alignment = dot(view_direction, normalize(sun_direction));
	float disc_outer = cos(sun_radius + sun_edge_softness);
	float disc_inner = cos(sun_radius);
	float halo_outer = cos(sun_halo_radius);
	float sun_disc = smoothstep(disc_outer, disc_inner, alignment);
	float sun_halo = smoothstep(halo_outer, disc_outer, alignment);
	float horizon_visibility = smoothstep(-0.035, 0.02, sun_direction.y);
	float visible_strength = sun_visibility * horizon_visibility;
	base_color += sun_color.rgb * sun_halo * sun_halo_strength * visible_strength;
	base_color = mix(base_color, sun_color.rgb, sun_disc * visible_strength);

	float moon_alignment = dot(view_direction, normalize(moon_direction));
	float moon_disc_outer = cos(moon_radius + moon_edge_softness);
	float moon_disc_inner = cos(moon_radius);
	float moon_halo_outer = cos(moon_halo_radius);
	float moon_disc = smoothstep(
		moon_disc_outer, moon_disc_inner, moon_alignment
	);
	float moon_halo = smoothstep(
		moon_halo_outer, moon_disc_outer, moon_alignment
	);
	float moon_horizon_visibility = smoothstep(
		-0.035, 0.02, moon_direction.y
	);
	float moon_visible_strength = (
		moon_visibility * moon_horizon_visibility
	);
	base_color += (
		moon_color.rgb
		* moon_halo
		* moon_halo_strength
		* moon_visible_strength
	);
	base_color = mix(
		base_color, moon_color.rgb, moon_disc * moon_visible_strength
	);
	base_color = apply_weather_clouds(base_color, view_direction);
	// Compatibility fog does not fully erase the color split between a custom
	// sky's upper and lower hemispheres. Dense low-light fog supplies one
	// uniform sky color here so that split cannot masquerade as an ocean edge.
	base_color = mix(
		base_color,
		fog_horizon_color.rgb,
		fog_horizon_occlusion
	);

	COLOR = base_color;
}
