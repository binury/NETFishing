class_name InterfaceFontController
extends Node

signal font_mode_changed(use_readable_font: bool)

const READABLE_FONT_PATH: String = "res://ui/fonts/Tuffy_Bold.otf"

var _game_theme: Theme = preload("res://ui/game_theme.tres")
var _game_font: Font = preload("res://ui/fonts/seattle_avenue.otf")
var _readable_font: Font
var _utility_theme: Theme
var _use_readable_font: bool = false


func _ready() -> void:
	if ResourceLoader.exists(READABLE_FONT_PATH):
		_readable_font = load(READABLE_FONT_PATH) as Font
	if _readable_font == null:
		push_error("Readable interface font resource is unavailable.")
	else:
		_readable_font.fallbacks = [_game_font]
	_utility_theme = _game_theme.duplicate(true)
	_utility_theme.default_font = readable_font()


func set_readable_font_enabled(enabled: bool) -> void:
	_use_readable_font = enabled
	_game_theme.default_font = (
		_readable_font
		if enabled and _readable_font != null
		else _game_font
	)
	font_mode_changed.emit(_use_readable_font)


func is_readable_font_enabled() -> bool:
	return _use_readable_font


func apply_utility_theme(themed_node: Node) -> void:
	if themed_node == null:
		return
	if _utility_theme == null:
		_utility_theme = _game_theme.duplicate(true)
		_utility_theme.default_font = (
			_readable_font if _readable_font != null else _game_font
		)
	if themed_node is Control:
		(themed_node as Control).theme = _utility_theme
	elif themed_node is Window:
		(themed_node as Window).theme = _utility_theme


func readable_font() -> Font:
	return _readable_font if _readable_font != null else _game_font
