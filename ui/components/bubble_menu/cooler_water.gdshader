shader_type canvas_item;
render_mode unshaded;

uniform vec4 water_top : source_color = vec4(0.055, 0.38, 0.50, 1.0);
uniform vec4 water_bottom : source_color = vec4(0.018, 0.16, 0.25, 1.0);
uniform vec4 caustic_color : source_color = vec4(0.66, 0.91, 0.95, 1.0);
uniform vec2 pattern_density = vec2(38.0, 21.0);
uniform vec2 pattern_drift = vec2(0.012, 0.018);
uniform float mark_opacity_min : hint_range(0.0, 0.1) = 0.022;
uniform float mark_opacity_max : hint_range(0.0, 0.1) = 0.065;
uniform sampler2D decorative_bubble_1 : source_color, filter_nearest, repeat_disable;
uniform sampler2D decorative_bubble_2 : source_color, filter_nearest, repeat_disable;
uniform sampler2D decorative_bubble_3 : source_color, filter_nearest, repeat_disable;
uniform float decorative_bubble_opacity : hint_range(0.0, 1.0) = 0.48;
uniform vec2 rendered_size = vec2(784.0, 394.0);
uniform float corner_radius : hint_range(0.0, 96.0) = 29.0;
uniform float corner_softness : hint_range(0.0, 3.0) = 0.75;


float cell_hash(vec2 cell) {
	return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
}


float block_mark(vec2 point, vec2 half_size) {
	return (
		step(abs(point.x), half_size.x)
		* step(abs(point.y), half_size.y)
	);
}


vec4 sample_decorative_bubble(
	sampler2D artwork,
	vec2 uv,
	vec2 rect_size,
	vec2 center,
	float logical_size
) {
	vec2 artwork_uv = (
		(uv - center) * rect_size / logical_size
		+ vec2(0.5)
	);
	float inside = (
		step(0.0, artwork_uv.x)
		* step(artwork_uv.x, 1.0)
		* step(0.0, artwork_uv.y)
		* step(artwork_uv.y, 1.0)
	);
	return texture(artwork, clamp(artwork_uv, vec2(0.0), vec2(1.0))) * inside;
}


vec2 decorative_bubble_center(
	float base_x,
	float phase,
	float speed,
	float drift_phase
) {
	float progress = fract(phase + TIME * speed);
	return vec2(
		base_x + sin(TIME * 0.21 + drift_phase) * 0.012,
		1.10 - progress * 1.24
	);
}


void fragment() {
	vec2 uv = UV;
	vec3 base = mix(water_top.rgb, water_bottom.rgb, smoothstep(0.0, 1.0, uv.y));

	vec2 flowing_grid = (uv + TIME * pattern_drift) * pattern_density;
	float row = floor(flowing_grid.y);
	flowing_grid.x += mod(row, 2.0) * 0.43;
	vec2 cell = floor(flowing_grid);
	vec2 local = fract(flowing_grid) - vec2(0.5);
	vec2 jitter = vec2(
		cell_hash(cell + vec2(3.7, 9.1)),
		cell_hash(cell + vec2(7.3, 2.9))
	) - vec2(0.5);
	local -= jitter * vec2(0.52, 0.46);
	vec2 stepped_local = (
		floor((local + vec2(0.5)) * 8.0) / 8.0
		- vec2(0.5)
	);
	float shape_key = cell_hash(cell + vec2(13.1, 5.7));
	float size_key = cell_hash(cell + vec2(1.9, 17.3));
	vec2 mark_half_size = mix(
		vec2(0.10, 0.07),
		vec2(0.18, 0.12),
		size_key
	);
	float mark = block_mark(stepped_local, mark_half_size);
	if (shape_key < 0.34) {
		mark = max(
			mark,
			block_mark(
				stepped_local - vec2(mark_half_size.x * 0.8, -0.11),
				vec2(mark_half_size.x * 0.52, 0.045)
			)
		);
	} else if (shape_key < 0.67) {
		mark *= 1.0 - block_mark(
			stepped_local - vec2(mark_half_size.x * 0.7, 0.0),
			vec2(0.045, 0.045)
		);
	} else {
		mark = max(
			mark,
			block_mark(
				stepped_local + vec2(mark_half_size.x * 0.75, 0.10),
				vec2(0.055, 0.04)
			)
		);
	}
	float occupancy = step(
		0.22,
		cell_hash(cell + vec2(19.7, 23.3))
	);
	float mark_opacity = mix(
		mark_opacity_min,
		mark_opacity_max,
		cell_hash(cell + vec2(29.9, 11.5))
	);
	base += caustic_color.rgb * mark * occupancy * mark_opacity;

	float sheen = (1.0 - smoothstep(0.0, 0.12, uv.y)) * 0.11;
	base += caustic_color.rgb * sheen;

	vec2 rect_size = max(rendered_size, vec2(1.0));
	float desktop_bubble_slots = step(260.0, rect_size.y);
	vec4 authored_bubbles = vec4(0.0);
	authored_bubbles += sample_decorative_bubble(
		decorative_bubble_1,
		uv,
		rect_size,
		decorative_bubble_center(0.12, 0.05, 0.020, 0.4),
		22.0
	);
	authored_bubbles += sample_decorative_bubble(
		decorative_bubble_2,
		uv,
		rect_size,
		decorative_bubble_center(0.27, 0.42, 0.016, 2.1),
		28.0
	);
	authored_bubbles += sample_decorative_bubble(
		decorative_bubble_3,
		uv,
		rect_size,
		decorative_bubble_center(0.41, 0.76, 0.018, 4.0),
		19.0
	);
	authored_bubbles += sample_decorative_bubble(
		decorative_bubble_1,
		uv,
		rect_size,
		decorative_bubble_center(0.56, 0.22, 0.015, 5.2),
		25.0
	);
	authored_bubbles += sample_decorative_bubble(
		decorative_bubble_3,
		uv,
		rect_size,
		decorative_bubble_center(0.69, 0.58, 0.019, 1.3),
		30.0
	);
	authored_bubbles += sample_decorative_bubble(
		decorative_bubble_2,
		uv,
		rect_size,
		decorative_bubble_center(0.82, 0.89, 0.017, 3.1),
		21.0
	) * desktop_bubble_slots;
	authored_bubbles += sample_decorative_bubble(
		decorative_bubble_1,
		uv,
		rect_size,
		decorative_bubble_center(0.92, 0.34, 0.014, 6.0),
		24.0
	) * desktop_bubble_slots;
	float authored_alpha = clamp(
		authored_bubbles.a * decorative_bubble_opacity,
		0.0,
		0.72
	);
	vec3 authored_color = (
		authored_bubbles.rgb
		/ max(authored_bubbles.a, 0.001)
	);
	base = mix(base, authored_color, authored_alpha);

	vec2 half_size = rect_size * 0.5;
	float radius = min(corner_radius, min(half_size.x, half_size.y));
	vec2 rounded_offset = (
		abs(uv * rect_size - half_size)
		- (half_size - vec2(radius))
	);
	float edge_distance = (
		length(max(rounded_offset, vec2(0.0)))
		+ min(max(rounded_offset.x, rounded_offset.y), 0.0)
		- radius
	);
	float softness = max(corner_softness, 0.001);
	float rounded_alpha = 1.0 - smoothstep(-softness, softness, edge_distance);
	COLOR = vec4(base, rounded_alpha);
}
