shader_type spatial;
render_mode cull_back;

uniform sampler2D albedo_texture : source_color, repeat_enable, filter_nearest;
uniform vec4 albedo_tint : source_color = vec4(1.0);
uniform float tile_world_size : hint_range(0.1, 20.0, 0.05) = 2.5;
uniform float blend_sharpness : hint_range(1.0, 16.0, 0.25) = 6.0;
uniform float top_projection_bias : hint_range(1.0, 8.0, 0.05) = 2.0;
uniform float roughness : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform float specular : hint_range(0.0, 1.0, 0.01) = 0.5;

varying vec3 world_position;
varying vec3 world_normal;


void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}


void fragment() {
	vec3 normal = normalize(world_normal);
	vec3 weights = pow(abs(normal), vec3(max(blend_sharpness, 1.0)));
	float upward_amount = smoothstep(0.0, 0.8, normal.y);
	weights.y *= mix(1.0, max(top_projection_bias, 1.0), upward_amount);
	weights /= max(weights.x + weights.y + weights.z, 0.00001);

	float world_scale = 1.0 / max(tile_world_size, 0.001);
	vec2 x_uv = world_position.zy * vec2(sign(normal.x), 1.0) * world_scale;
	vec2 y_uv = world_position.xz * vec2(sign(normal.y), 1.0) * world_scale;
	vec2 z_uv = world_position.xy * vec2(-sign(normal.z), 1.0) * world_scale;
	vec4 x_sample = texture(albedo_texture, x_uv);
	vec4 y_sample = texture(albedo_texture, y_uv);
	vec4 z_sample = texture(albedo_texture, z_uv);
	vec4 projected = (
		x_sample * weights.x
		+ y_sample * weights.y
		+ z_sample * weights.z
	);

	ALBEDO = projected.rgb * albedo_tint.rgb;
	ROUGHNESS = roughness;
	SPECULAR = specular;
	METALLIC = 0.0;
}
