class_name InterfaceFontController
extends Node

const FileDialogControllerNavigationType = preload(
	"res://ui/file_dialog_controller_navigation.gd"
)
const STANDARD_FONT: Font = preload("res://ui/fonts/Tuffy_Bold.otf")
const COMPACT_FILE_DIALOG_LIMIT := Vector2i(800, 600)
const COMPACT_FILE_DIALOG_MARGIN := Vector2i(12, 12)
const COMPACT_FILE_DIALOG_FONT_SIZE: int = 17

var _controller_text_entry_request: Callable
var _controller_text_entry_is_open: Callable
var _game_theme: Theme = preload("res://ui/game_theme.tres")
var _utility_theme: Theme
var _compact_file_dialog_theme: Theme
var _tracked_file_dialogs: Dictionary[int, WeakRef] = {}


func _ready() -> void:
	enforce_standard_font()
	_utility_theme = _game_theme.duplicate(true)
	_utility_theme.default_font = STANDARD_FONT


func enforce_standard_font() -> void:
	_game_theme.default_font = STANDARD_FONT
	if _utility_theme != null:
		_utility_theme.default_font = STANDARD_FONT


func set_controller_text_entry_request(
	request: Callable,
	is_open: Callable = Callable(),
) -> void:
	_controller_text_entry_request = request
	_controller_text_entry_is_open = is_open


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


func popup_file_dialog(dialog: FileDialog) -> void:
	if dialog == null or not dialog.is_inside_tree():
		return
	_tracked_file_dialogs[dialog.get_instance_id()] = weakref(dialog)
	var host_window: Window = dialog.get_parent().get_window()
	var host_size: Vector2i = host_window.size
	var compact: bool = (
		host_size.x <= COMPACT_FILE_DIALOG_LIMIT.x
		or host_size.y <= COMPACT_FILE_DIALOG_LIMIT.y
	)
	if not compact:
		apply_utility_theme(dialog)
		dialog.min_size = Vector2i(200, 70)
		dialog.max_size = Vector2i.ZERO
		dialog.popup_centered_ratio(0.75)
		return
	if _compact_file_dialog_theme == null:
		_compact_file_dialog_theme = _utility_theme.duplicate(true)
		_compact_file_dialog_theme.default_font_size = (
			COMPACT_FILE_DIALOG_FONT_SIZE
		)
	dialog.theme = _compact_file_dialog_theme
	var available_size := Vector2i(
		maxi(1, host_size.x - COMPACT_FILE_DIALOG_MARGIN.x * 2),
		maxi(1, host_size.y - COMPACT_FILE_DIALOG_MARGIN.y * 2),
	)
	dialog.min_size = Vector2i.ZERO
	dialog.max_size = available_size
	dialog.popup_centered(available_size)
	# FileDialog's desktop-oriented intrinsic minimum can exceed a compact
	# 4:3 display. The compact font keeps its controls usable while this final
	# clamp guarantees the embedded window cannot escape the physical screen.
	dialog.size = available_size
	if dialog.get_viewport().gui_embed_subwindows:
		dialog.position = (host_size - available_size) / 2
		_finalize_compact_file_dialog.call_deferred(
			dialog, host_size, available_size
		)


func _process(_delta: float) -> void:
	if (
		_controller_text_entry_is_open.is_valid()
		and bool(_controller_text_entry_is_open.call())
	):
		return
	for instance_id: int in _tracked_file_dialogs.keys():
		var reference: WeakRef = _tracked_file_dialogs[instance_id]
		var dialog := reference.get_ref() as FileDialog
		if dialog == null or not is_instance_valid(dialog):
			_tracked_file_dialogs.erase(instance_id)
			continue
		if not dialog.visible:
			continue
		FileDialogControllerNavigationType.configure(dialog)
		_connect_file_dialog_text_controls(dialog)


func _connect_file_dialog_text_controls(dialog: FileDialog) -> void:
	var scope: Window = FileDialogControllerNavigationType.active_scope(dialog)
	for control: Control in (
		FileDialogControllerNavigationType.interactive_controls(scope)
	):
		if not (control is LineEdit or control is TextEdit):
			continue
		var callback := _on_file_dialog_text_gui_input.bind(control)
		if not control.gui_input.is_connected(callback):
			control.gui_input.connect(callback)


func _on_file_dialog_text_gui_input(
	event: InputEvent,
	control: Control,
) -> void:
	var button_event := event as InputEventJoypadButton
	if (
		button_event == null
		or not button_event.pressed
		or (
			button_event.button_index != JOY_BUTTON_A
			and not event.is_action_pressed("ui_accept")
		)
		or not _controller_text_entry_request.is_valid()
	):
		return
	if bool(_controller_text_entry_request.call(control)):
		control.accept_event()


func _finalize_compact_file_dialog(
	dialog: FileDialog,
	host_size: Vector2i,
	requested_size: Vector2i,
) -> void:
	await get_tree().process_frame
	if dialog == null or not dialog.visible:
		return
	# Embedded windows report their content origin below the title bar. Account
	# for that inset after Godot has laid the window out so its bottom and right
	# edges retain the same safe margin as its decorated top and left edges.
	var safe_bottom_right: Vector2i = host_size - COMPACT_FILE_DIALOG_MARGIN
	var fitted_size: Vector2i = requested_size
	fitted_size.x -= maxi(
		0, dialog.position.x + fitted_size.x - safe_bottom_right.x
	)
	fitted_size.y -= maxi(
		0, dialog.position.y + fitted_size.y - safe_bottom_right.y
	)
	dialog.size = Vector2i(maxi(1, fitted_size.x), maxi(1, fitted_size.y))


func readable_font() -> Font:
	return STANDARD_FONT
