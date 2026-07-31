class_name UtilityPageStyle
extends RefCounted

const TuffyFont: Font = preload("res://ui/fonts/Tuffy_Bold.otf")
const PAPER: Color = Color("eee2bd")
const PAPER_ALT: Color = Color("f3ecd7")
const INK: Color = Color("28251f")
const MUTED_INK: Color = Color("5f5547")
const BORDER: Color = Color("473d2e")
# PAPER/INK remain available only for intentionally paper-like content such as
# a letter body. Technical surfaces use this shared ocean palette.
const OCEAN_PANEL_DEEP: Color = Color("0d2c3a")
const OCEAN_PANEL_MID: Color = Color("123f4e")
const OCEAN_FIELD: Color = Color("081f2b")
const OCEAN_BUTTON: Color = Color("123f4e")
const OCEAN_BUTTON_HOVER: Color = Color("196072")
const OCEAN_BUTTON_PRESSED: Color = Color("0b3341")
const OCEAN_SELECTED: Color = Color("238697")
const OCEAN_TEXT_PRIMARY: Color = Color("e6f7f7")
const OCEAN_TEXT_SECONDARY: Color = Color("9fcfd2")
const OCEAN_DISABLED: Color = Color("38535b")
const OCEAN_DANGER: Color = Color("9e4550")
const NAVY: Color = Color("092b3d")
const NAVY_HOVER: Color = Color("12465b")
const GREEN: Color = Color("31594d")
const LIGHT_TEXT: Color = Color("f5eed9")
const DISABLED_TEXT: Color = Color(0.33, 0.36, 0.35, 0.72)
const MOTION_TWEEN_META: StringName = &"utility_page_motion_tween"


static func apply_page(root: Control) -> void:
	root.add_theme_font_override("font", TuffyFont)


static func panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = OCEAN_PANEL_DEEP
	style.set_border_width_all(0)
	style.set_corner_radius_all(16)
	style.content_margin_left = 26
	style.content_margin_right = 26
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	return style


static func row_style(selected: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = OCEAN_SELECTED if selected else OCEAN_PANEL_MID
	style.set_border_width_all(0)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


static func button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.76, 0.86, 0.78, 0.72)
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


static func apply_button(button: BaseButton) -> void:
	button.add_theme_font_override("font", TuffyFont)
	button.add_theme_color_override("font_color", LIGHT_TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", DISABLED_TEXT)
	button.add_theme_stylebox_override("normal", button_style(NAVY))
	button.add_theme_stylebox_override("hover", button_style(NAVY_HOVER))
	button.add_theme_stylebox_override("pressed", button_style(GREEN))
	button.add_theme_stylebox_override("focus", button_style(NAVY_HOVER))
	button.add_theme_stylebox_override(
		"disabled", button_style(Color(0.37, 0.42, 0.40, 0.55))
	)
	button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, 40.0)


static func ocean_button_style(color: Color) -> StyleBoxFlat:
	var style := button_style(color)
	style.set_border_width_all(0)
	return style


static func apply_ocean_button(button: BaseButton) -> void:
	button.add_theme_font_override("font", TuffyFont)
	button.add_theme_color_override("font_color", OCEAN_TEXT_PRIMARY)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_color_override(
		"font_disabled_color",
		Color(OCEAN_TEXT_SECONDARY, 0.52),
	)
	button.add_theme_stylebox_override(
		"normal", ocean_button_style(OCEAN_BUTTON)
	)
	button.add_theme_stylebox_override(
		"hover", ocean_button_style(OCEAN_BUTTON_HOVER)
	)
	button.add_theme_stylebox_override(
		"pressed", ocean_button_style(OCEAN_SELECTED)
	)
	button.add_theme_stylebox_override(
		"focus", ocean_button_style(OCEAN_SELECTED)
	)
	button.add_theme_stylebox_override(
		"disabled", ocean_button_style(OCEAN_DISABLED)
	)
	button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, 40.0)


static func apply_line_edit(edit: LineEdit) -> void:
	edit.add_theme_font_override("font", TuffyFont)
	edit.add_theme_color_override("font_color", LIGHT_TEXT)
	edit.add_theme_color_override(
		"font_placeholder_color", Color(0.82, 0.80, 0.71, 0.84)
	)
	edit.add_theme_color_override("font_selected_color", Color.WHITE)
	edit.add_theme_color_override("caret_color", Color("fff0b6"))
	edit.add_theme_color_override("selection_color", Color("2f7186"))
	edit.add_theme_color_override("font_uneditable_color", Color("c9c2ae"))
	edit.add_theme_stylebox_override("normal", button_style(NAVY))
	edit.add_theme_stylebox_override("focus", button_style(NAVY_HOVER))
	edit.add_theme_stylebox_override(
		"read_only", button_style(Color(NAVY, 0.82))
	)


static func apply_ocean_line_edit(edit: LineEdit) -> void:
	edit.add_theme_font_override("font", TuffyFont)
	edit.add_theme_color_override("font_color", OCEAN_TEXT_PRIMARY)
	edit.add_theme_color_override(
		"font_placeholder_color", Color(OCEAN_TEXT_SECONDARY, 0.78)
	)
	edit.add_theme_color_override("font_selected_color", Color.WHITE)
	edit.add_theme_color_override("caret_color", OCEAN_TEXT_PRIMARY)
	edit.add_theme_color_override("selection_color", OCEAN_SELECTED)
	edit.add_theme_color_override("font_uneditable_color", OCEAN_TEXT_SECONDARY)
	edit.add_theme_stylebox_override(
		"normal", ocean_button_style(OCEAN_FIELD)
	)
	edit.add_theme_stylebox_override(
		"focus", ocean_button_style(OCEAN_SELECTED)
	)
	edit.add_theme_stylebox_override(
		"read_only", ocean_button_style(Color(OCEAN_FIELD, 0.82))
	)


static func apply_text_edit(edit: TextEdit) -> void:
	edit.add_theme_font_override("font", TuffyFont)
	edit.add_theme_color_override("font_color", OCEAN_TEXT_PRIMARY)
	edit.add_theme_color_override(
		"font_placeholder_color", Color(OCEAN_TEXT_SECONDARY, 0.78)
	)
	edit.add_theme_color_override("font_selected_color", Color.WHITE)
	edit.add_theme_color_override("caret_color", OCEAN_TEXT_PRIMARY)
	edit.add_theme_color_override("selection_color", OCEAN_SELECTED)
	edit.add_theme_stylebox_override("normal", ocean_button_style(OCEAN_FIELD))
	edit.add_theme_stylebox_override("focus", ocean_button_style(OCEAN_SELECTED))


static func animate_in(control: Control) -> void:
	_cancel_motion(control)
	control.pivot_offset = control.size * 0.5
	control.scale = Vector2.ONE * UIMotion.UTILITY_ENTER_SCALE
	control.modulate.a = 0.0
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tween := control.create_tween()
	control.set_meta(MOTION_TWEEN_META, tween)
	tween.set_parallel(true)
	tween.tween_property(
		control, "scale", Vector2.ONE, UIMotion.UTILITY_ENTER_DURATION
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(
		control, "modulate:a", 1.0, UIMotion.UTILITY_ENTER_DURATION
	)
	tween.finished.connect(func() -> void:
		if is_instance_valid(control):
			control.mouse_filter = Control.MOUSE_FILTER_PASS
			control.remove_meta(MOTION_TWEEN_META)
	)


static func animate_out(control: Control, completed: Callable) -> void:
	_cancel_motion(control)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.pivot_offset = control.size * 0.5
	var tween := control.create_tween()
	control.set_meta(MOTION_TWEEN_META, tween)
	tween.set_parallel(true)
	tween.tween_property(
		control,
		"scale",
		Vector2.ONE * UIMotion.UTILITY_ENTER_SCALE,
		UIMotion.UTILITY_EXIT_DURATION
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(
		control, "modulate:a", 0.0, UIMotion.UTILITY_EXIT_DURATION
	)
	if completed.is_valid():
		tween.finished.connect(completed, CONNECT_ONE_SHOT)
	tween.finished.connect(func() -> void:
		if is_instance_valid(control):
			control.remove_meta(MOTION_TWEEN_META)
	)


static func _cancel_motion(control: Control) -> void:
	if not control.has_meta(MOTION_TWEEN_META):
		return
	var existing := control.get_meta(MOTION_TWEEN_META) as Tween
	if existing != null and existing.is_valid():
		existing.kill()
	control.remove_meta(MOTION_TWEEN_META)
