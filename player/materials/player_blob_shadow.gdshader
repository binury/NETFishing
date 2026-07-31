shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

uniform vec4 shadow_color : source_color = vec4(0.035, 0.105, 0.125, 0.18);
uniform float inner_softness : hint_range(0.0, 0.8, 0.01) = 0.05;

void fragment() {
	vec2 centered_uv = (UV - vec2(0.5)) * 2.0;
	float radial_distance = dot(centered_uv, centered_uv);
	float falloff = 1.0 - smoothstep(inner_softness, 1.0, radial_distance);
	ALBEDO = shadow_color.rgb;
	ALPHA = shadow_color.a * falloff;
}
