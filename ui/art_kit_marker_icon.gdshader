shader_type canvas_item;

uniform vec4 marker_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);


void fragment() {
	vec4 source = texture(TEXTURE, UV) * COLOR;
	float red_dominance = source.r - max(source.g, source.b);
	float marker_mask = smoothstep(0.04, 0.18, red_dominance);
	vec3 colored_marker = marker_color.rgb * source.r;
	COLOR = vec4(
		mix(source.rgb, colored_marker, marker_mask),
		source.a * marker_color.a
	);
}
