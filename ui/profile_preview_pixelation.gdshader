shader_type canvas_item;
render_mode unshaded;

uniform vec2 logical_grid_size = vec2(160.0, 165.0);


void fragment() {
	vec2 safe_grid = max(logical_grid_size, vec2(1.0));
	vec2 snapped_uv = (floor(UV * safe_grid) + vec2(0.5)) / safe_grid;
	COLOR = texture(TEXTURE, snapped_uv);
}
