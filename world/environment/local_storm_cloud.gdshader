shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, unshaded, fog_disabled, shadows_disabled;

uniform vec4 cloud_color : source_color = vec4(0.07, 0.10, 0.12, 1.0);
uniform float weather_opacity : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float maximum_opacity : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float distance_fade_start : hint_range(50.0, 500.0, 1.0) = 240.0;
uniform float distance_fade_end : hint_range(50.0, 500.0, 1.0) = 300.0;

varying float world_normal_height;
varying float camera_distance;


void vertex() {
	world_normal_height = normalize(MODEL_NORMAL_MATRIX * NORMAL).y;
	vec3 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	camera_distance = distance(
		world_position.xz,
		CAMERA_POSITION_WORLD.xz
	);
}


void fragment() {
	float facet_light = mix(
		0.68,
		1.06,
		clamp(world_normal_height * 0.5 + 0.5, 0.0, 1.0)
	);
	ALBEDO = cloud_color.rgb * facet_light;
	float distance_fade = 1.0 - smoothstep(
		distance_fade_start,
		distance_fade_end,
		camera_distance
	);
	ALPHA = weather_opacity * maximum_opacity * distance_fade * cloud_color.a;
}
