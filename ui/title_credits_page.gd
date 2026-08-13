class_name TitleCreditsPage
extends Control

signal back_requested(restore_navigation_focus: bool)

@onready var _paper: PanelContainer = %Paper
@onready var _back_button: Button = %CreditsBackButton

var _navigation_focus_active: bool = false


func _ready() -> void:
	UtilityPageStyle.apply_page(self)
	_paper.add_theme_stylebox_override(
		"panel", UtilityPageStyle.panel_style()
	)
	UtilityPageStyle.apply_ocean_button(_back_button)
	_back_button.pressed.connect(_request_back)
	hide()


func open_page(use_navigation_focus: bool) -> void:
	_navigation_focus_active = use_navigation_focus
	show()
	UtilityPageStyle.animate_in(self)
	if use_navigation_focus:
		call_deferred("_focus_back")
	else:
		_release_page_focus()


func close_page() -> void:
	_navigation_focus_active = false
	_release_page_focus()
	hide()
	scale = Vector2.ONE
	modulate.a = 1.0


func handle_input(event: InputEvent) -> bool:
	if not visible:
		return false
	if event is InputEventMouseMotion:
		_navigation_focus_active = false
		_release_page_focus()
		return false
	if event is InputEventKey and (event as InputEventKey).echo:
		return false
	var moves_focus: bool = (
		event.is_action_pressed("ui_up")
		or event.is_action_pressed("ui_down")
		or event.is_action_pressed("ui_left")
		or event.is_action_pressed("ui_right")
	)
	if moves_focus:
		_navigation_focus_active = true
		if not _page_has_focus():
			_back_button.grab_focus()
		return true
	if event.is_action_pressed("ui_cancel"):
		_request_back()
		return true
	return false


func get_back_button() -> Button:
	return _back_button


func _focus_back() -> void:
	if visible and _navigation_focus_active:
		_back_button.grab_focus()


func _request_back() -> void:
	back_requested.emit(_navigation_focus_active)


func _page_has_focus() -> bool:
	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	return focus_owner != null and is_ancestor_of(focus_owner)


func _release_page_focus() -> void:
	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	if focus_owner != null and is_ancestor_of(focus_owner):
		focus_owner.release_focus()
