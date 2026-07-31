class_name InterfaceFontController
extends Node

const STANDARD_FONT: Font = preload("res://ui/fonts/Tuffy_Bold.otf")

var _game_theme: Theme = preload("res://ui/game_theme.tres")
var _utility_theme: Theme


func _ready() -> void:
	enforce_standard_font()
	_utility_theme = _game_theme.duplicate(true)
	_utility_theme.default_font = STANDARD_FONT


func enforce_standard_font() -> void:
	_game_theme.default_font = STANDARD_FONT
	if _utility_theme != null:
		_utility_theme.default_font = STANDARD_FONT


func set_readable_font_enabled(_enabled: bool) -> void:
	# Compatibility seam for callers compiled against the old setting.
	enforce_standard_font()


func is_readable_font_enabled() -> bool:
	return true


func apply_utility_theme(themed_node: Node) -> void:
	if themed_node == null:
		return
	if _utility_theme == null:
		_utility_theme = _game_theme.duplicate(true)
		_utility_theme.default_font = STANDARD_FONT
	if themed_node is Control:
		(themed_node as Control).theme = _utility_theme
	elif themed_node is Window:
		(themed_node as Window).theme = _utility_theme


func readable_font() -> Font:
	return STANDARD_FONT
