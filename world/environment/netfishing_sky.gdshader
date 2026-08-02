shader_type sky;

uniform vec4 sky_top_color : source_color = vec4(0.204, 0.498, 0.643, 1.0);
uniform vec4 sky_horizon_color : source_color = vec4(0.663, 0.843, 0.847, 1.0);
uniform vec4 ground_bottom_color : source_color = vec4(0.157, 0.361, 0.439, 1.0);
uniform vec4 ground_horizon_color : source_color = vec4(0.549, 0.749, 0.765, 1.0);

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
		smoothstep(-0.01, 0.01, view_direction.y)
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

	COLOR = base_color;
}
