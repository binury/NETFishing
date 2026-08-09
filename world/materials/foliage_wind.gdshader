shader_type spatial;
render_mode cull_back, depth_draw_opaque;

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float material_roughness = 1.0;
uniform float material_metallic = 0.0;
uniform float local_min_y = 0.0;
uniform float local_height = 1.0;
uniform float local_wind_strength = 0.08;
uniform float wind_speed = 0.9;
uniform float wind_phase = 0.0;


void vertex() {
	float height_ratio = clamp(
		(VERTEX.y - local_min_y) / max(local_height, 0.001),
		0.0,
		1.0
	);
	float bend_mask = smoothstep(0.08, 1.0, height_ratio);
	vec3 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float broad_wave = sin(
		TIME * wind_speed
		+ dot(world_position.xz, vec2(0.23, 0.17))
		+ wind_phase
	);
	float leaf_flutter = sin(
		TIME * wind_speed * 2.17
		+ dot(world_position.xz, vec2(-0.41, 0.37))
		+ wind_phase * 1.7
	);
	float displacement = (
		broad_wave * 0.72 + leaf_flutter * 0.28
	) * local_wind_strength * bend_mask;
	VERTEX.x += displacement;
	VERTEX.z += displacement * 0.42;
}


void fragment() {
	ALBEDO = albedo_color.rgb;
	ROUGHNESS = material_roughness;
	METALLIC = material_metallic;
}
