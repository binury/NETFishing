shader_type canvas_item;

uniform sampler2D pattern_texture : source_color, repeat_enable, filter_nearest;
uniform vec2 source_tile_size = vec2(128.0, 128.0);
uniform float display_scale : hint_range(0.5, 2.0, 0.05) = 0.85;
uniform vec2 scroll_velocity_pixels = vec2(-7.0, -5.0);
uniform bool animation_enabled = true;

void fragment() {
	vec2 viewport_pixels = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 display_tile_size = max(source_tile_size * display_scale, vec2(1.0));
	vec2 moving_pixels = UV * viewport_pixels;
	if (animation_enabled) {
		moving_pixels += TIME * scroll_velocity_pixels;
	}
	COLOR = texture(pattern_texture, moving_pixels / display_tile_size);
}
