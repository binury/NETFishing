shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;


void fragment() {
	vec3 surface_color = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
	vec3 inverted_color = vec3(1.0) - surface_color;
	ALBEDO = inverted_color;
	EMISSION = inverted_color;
}
