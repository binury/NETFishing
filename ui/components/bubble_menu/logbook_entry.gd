class_name LogbookEntry
extends PanelContainer

var _discovered: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_paper_style(_discovered)


func configure(
	artwork: Texture2D,
	species_name: String,
	rarity_name: String,
	owned_count: int,
	discovered: bool,
) -> void:
	_discovered = discovered
	var artwork_control := get_node(
		^"Margin/Content/Artwork"
	) as TextureRect
	var name_control := get_node(
		^"Margin/Content/Text/NameLabel"
	) as Label
	var rarity_control := get_node(
		^"Margin/Content/Text/RarityLabel"
	) as Label
	var owned_control := get_node(
		^"Margin/Content/Text/OwnedLabel"
	) as Label
	artwork_control.texture = artwork
	artwork_control.modulate = (
		Color.WHITE
		if discovered
		else Color(0.20, 0.17, 0.13, 0.48)
	)
	name_control.text = species_name if discovered else "???"
	rarity_control.text = rarity_name if discovered else "undiscovered"
	owned_control.text = (
		"owned: %d" % owned_count if discovered else "not recorded"
	)
	owned_control.visible = true
	_apply_paper_style(discovered)


func apply_compact_layout(compact: bool) -> void:
	var artwork_control := get_node(
		^"Margin/Content/Artwork"
	) as TextureRect
	var name_control := get_node(
		^"Margin/Content/Text/NameLabel"
	) as Label
	var rarity_control := get_node(
		^"Margin/Content/Text/RarityLabel"
	) as Label
	var owned_control := get_node(
		^"Margin/Content/Text/OwnedLabel"
	) as Label
	custom_minimum_size = (
		Vector2(236.0, 108.0) if compact else Vector2(214.0, 150.0)
	)
	artwork_control.custom_minimum_size = (
		Vector2(92.0, 54.0) if compact else Vector2(128.0, 76.0)
	)
	name_control.add_theme_font_size_override(
		"font_size",
		16 if compact else 18,
	)
	rarity_control.add_theme_font_size_override(
		"font_size",
		11 if compact else 13,
	)
	owned_control.add_theme_font_size_override(
		"font_size",
		11 if compact else 13,
	)


func _apply_paper_style(discovered: bool) -> void:
	if not is_node_ready():
		return
	var style := StyleBoxFlat.new()
	style.bg_color = (
		Color(0.965, 0.925, 0.80, 0.78)
		if discovered
		else Color(0.89, 0.84, 0.72, 0.58)
	)
	style.border_color = (
		Color(0.50, 0.39, 0.25, 0.62)
		if discovered
		else Color(0.39, 0.34, 0.27, 0.42)
	)
	style.border_width_bottom = 2
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 16
	style.corner_radius_bottom_left = 10
	style.content_margin_left = 8.0
	style.content_margin_top = 6.0
	style.content_margin_right = 8.0
	style.content_margin_bottom = 6.0
	add_theme_stylebox_override("panel", style)
