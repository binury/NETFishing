shader_type canvas_item;

uniform vec4 surface_color : source_color = vec4(0.10, 0.45, 0.62, 1.0);
uniform vec4 middle_color : source_color = vec4(0.055, 0.285, 0.40, 1.0);
uniform vec4 depth_color : source_color = vec4(0.02, 0.16, 0.27, 1.0);
uniform vec2 virtual_pixel_density = vec2(320.0, 180.0);
uniform float color_step_count : hint_range(2.0, 16.0, 1.0) = 14.0;
uniform float continuous_depth_blend : hint_range(0.0, 0.25, 0.01) = 0.12;
uniform float wave_speed : hint_range(0.0, 0.5, 0.01) = 0.10;
uniform float wave_scale : hint_range(0.5, 8.0, 0.1) = 2.4;
uniform float wave_strength : hint_range(0.0, 0.05, 0.001) = 0.012;
uniform float caustic_strength : hint_range(0.0, 0.08, 0.001) = 0.018;

void fragment() {
	vec2 grid_size = max(virtual_pixel_density, vec2(1.0));
	vec2 pixel_uv = (floor(UV * grid_size) + vec2(0.5)) / grid_size;
	float motion = TIME * wave_speed;

	float broad_wave = sin(
		pixel_uv.x * wave_scale + motion
	);
	float secondary_wave = sin(
		pixel_uv.x * 1.1 + pixel_uv.y * 1.6 - motion * 0.65
	);
	float movement_falloff = 1.0 - pixel_uv.y * 0.75;
	float depth_displacement = (
		(broad_wave * 0.65 + secondary_wave * 0.35)
		* wave_strength
		* movement_falloff
	);
	float continuous_depth = clamp(
		pixel_uv.y
		+ depth_displacement,
		0.0,
		1.0
	);
	float depth_steps = max(2.0, floor(color_step_count));
	float band_index = floor(
		continuous_depth * (depth_steps - 1.0) + 0.5
	);
	float band_depth = band_index / (depth_steps - 1.0);
	float display_depth = mix(
		band_depth,
		continuous_depth,
		clamp(continuous_depth_blend, 0.0, 0.25)
	);

	vec3 water_color;
	if (display_depth < 0.5) {
		water_color = mix(
			surface_color.rgb,
			middle_color.rgb,
			display_depth * 2.0
		);
	} else {
		water_color = mix(
			middle_color.rgb,
			depth_color.rgb,
			(display_depth - 0.5) * 2.0
		);
	}

	float caustic_wave = clamp(
		(
		sin(
			pixel_uv.x * 4.0
			+ pixel_uv.y * 1.2
			+ motion * 0.7
		)
		* sin(
			pixel_uv.x * 1.7
			- pixel_uv.y * 2.2
			- motion * 0.55
		)
		- 0.25
		) / 0.75,
		0.0,
		1.0
	);
	float caustic_level = floor(
		caustic_wave * 3.0
	) / 3.0;
	float upper_water_mask = 1.0 - smoothstep(
		0.18,
		0.34,
		pixel_uv.y
	);
	water_color += (
		vec3(0.05, 0.12, 0.14)
		* caustic_level
		* upper_water_mask
		* caustic_strength
	);
	COLOR = vec4(clamp(water_color, vec3(0.0), vec3(1.0)), 1.0);
}
