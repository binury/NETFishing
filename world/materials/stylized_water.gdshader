shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 deep_color : source_color = vec4(0.055, 0.31, 0.50, 1.0);
uniform vec4 wave_color : source_color = vec4(0.18, 0.59, 0.74, 1.0);
uniform vec4 highlight_color : source_color = vec4(0.64, 0.88, 0.93, 1.0);

uniform float primary_wave_scale : hint_range(0.01, 2.0, 0.01) = 0.52;
uniform float secondary_wave_scale : hint_range(0.01, 2.0, 0.01) = 0.29;
uniform vec2 primary_speed = vec2(0.16, 0.07);
uniform vec2 secondary_speed = vec2(-0.08, 0.12);
uniform float wave_strength : hint_range(0.0, 1.0, 0.01) = 0.42;

uniform float highlight_fresnel_strength : hint_range(0.0, 1.0, 0.01) = 0.22;
uniform float fresnel_power : hint_range(0.5, 12.0, 0.1) = 4.0;
uniform float roughness : hint_range(0.0, 1.0, 0.01) = 0.32;
uniform float specular_strength : hint_range(0.0, 1.0, 0.01) = 0.28;

varying vec3 world_position;


void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}


void fragment() {
	const vec2 primary_direction = vec2(0.835, 0.550);
	const vec2 secondary_direction = vec2(-0.485, 0.875);

	vec2 primary_coordinates = (
		world_position.xz * primary_wave_scale
		+ TIME * primary_speed
	);
	vec2 secondary_coordinates = (
		world_position.xz * secondary_wave_scale
		+ TIME * secondary_speed
	);
	float primary_phase = dot(primary_coordinates, primary_direction);
	float secondary_phase = dot(
		secondary_coordinates,
		secondary_direction
	);
	float primary_wave = sin(primary_phase);
	float secondary_wave = sin(secondary_phase);
	float combined_wave = (
		primary_wave * 0.62
		+ secondary_wave * 0.38
	);
	float wave_band = smoothstep(
		0.34,
		0.66,
		combined_wave * 0.5 + 0.5
	);

	vec2 wave_slope = (
		cos(primary_phase)
		* primary_direction
		* primary_wave_scale
		* 0.62
		+ cos(secondary_phase)
		* secondary_direction
		* secondary_wave_scale
		* 0.38
	);
	vec3 world_normal = normalize(
		vec3(
			-wave_slope.x * wave_strength * 0.34,
			1.0,
			-wave_slope.y * wave_strength * 0.34
		)
	);
	NORMAL = normalize(
		(VIEW_MATRIX * vec4(world_normal, 0.0)).xyz
	);

	float fresnel = pow(
		1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0),
		fresnel_power
	);
	vec3 water_color = mix(
		deep_color.rgb,
		wave_color.rgb,
		wave_band * wave_strength
	);
	ALBEDO = mix(
		water_color,
		highlight_color.rgb,
		fresnel * highlight_fresnel_strength
	);
	ROUGHNESS = roughness;
	SPECULAR = specular_strength;
}
