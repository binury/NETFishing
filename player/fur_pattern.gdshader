shader_type spatial;
render_mode unshaded, cull_back;

// Pattern PNGs are data maps rather than colored artwork. Black selects the
// base color and the red, green, and blue channels select the three authored
// accent colors. Alpha is intentionally ignored so artists may leave unused
// UV space transparent.
uniform sampler2D pattern_texture : filter_nearest, repeat_disable;
uniform vec4 base_color : source_color = vec4(1.0);
uniform vec4 red_zone_color : source_color = vec4(0.9, 0.8, 0.6, 1.0);
uniform vec4 green_zone_color : source_color = vec4(0.4, 0.2, 0.1, 1.0);
uniform vec4 blue_zone_color : source_color = vec4(0.7, 0.2, 0.15, 1.0);

void fragment() {
	vec3 zone_weights = max(texture(pattern_texture, UV).rgb, vec3(0.0));
	float zone_total = zone_weights.r + zone_weights.g + zone_weights.b;
	// Filtering between two authored zone colors can produce a sum near one.
	// Normalize only an overfull sample, retaining smooth black-to-zone edges.
	zone_weights /= max(zone_total, 1.0);
	float base_weight = 1.0 - min(zone_total, 1.0);
	ALBEDO = (
		base_color.rgb * base_weight
		+ red_zone_color.rgb * zone_weights.r
		+ green_zone_color.rgb * zone_weights.g
		+ blue_zone_color.rgb * zone_weights.b
	);
}
