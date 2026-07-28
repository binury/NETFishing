shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture
	: hint_screen_texture, filter_nearest, repeat_disable;
uniform vec2 logical_grid_size = vec2(640.0, 360.0);


void fragment() {
	vec2 safe_grid = max(logical_grid_size, vec2(1.0));
	vec2 snapped_uv = (
		floor(SCREEN_UV * safe_grid) + vec2(0.5)
	) / safe_grid;
	COLOR = texture(screen_texture, snapped_uv);
}
