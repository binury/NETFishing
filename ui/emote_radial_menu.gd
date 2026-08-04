class_name EmoteRadialMenu
extends Control

signal emote_selected(emote_id: StringName)

const BubbleButtonScene: PackedScene = preload(
	"res://ui/components/bubble_menu/bubble_button.tscn"
)
const BubbleProfile: BubbleMenuProfile = preload(
	"res://ui/components/bubble_menu/bubble_menu_profile.tres"
)
const SECTOR_COUNT: int = 8
const SIT_SECTOR: int = 0
const RING_RADIUS: float = 172.0
const BUBBLE_SIZE: Vector2 = Vector2(92.0, 88.0)
const CONTROLLER_SELECTION_DEADZONE: float = 0.35
const ControllerMappingManagerType = preload(
	"res://settings/controller_mapping_manager.gd"
)

var _buttons: Array[BubbleButton] = []
var _is_open: bool = false
var _selected_sector: int = SIT_SECTOR
var _controller_selection_mode: bool = false
var _controller_mapping_manager: ControllerMappingManagerType


func setup_controller_mapping(
	mapping_manager: ControllerMappingManagerType,
) -> void:
	_controller_mapping_manager = mapping_manager


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for sector: int in SECTOR_COUNT:
		var bubble: BubbleButton = BubbleButtonScene.instantiate() as BubbleButton
		bubble.profile = BubbleProfile
		bubble.focus_mode = Control.FOCUS_NONE
		bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bubble.text = "Sit" if sector == SIT_SECTOR else ""
		add_child(bubble)
		_buttons.append(bubble)
	_apply_selection_styles()


func handle_input(event: InputEvent, can_open: bool) -> bool:
	if not event.is_action("open_emotes"):
		return false
	var key_event: InputEventKey = event as InputEventKey
	if key_event != null and key_event.echo:
		return false
	if event.is_pressed():
		if _is_open or not can_open:
			return _is_open
		open_menu(event is InputEventJoypadButton)
		return true
	if not _is_open:
		return false
	var selected: int = _selected_sector
	close_menu()
	if selected == SIT_SECTOR:
		emote_selected.emit(&"sit")
	return true


func open_menu(controller_selection: bool = false) -> void:
	_is_open = true
	_selected_sector = SIT_SECTOR
	_controller_selection_mode = controller_selection
	visible = true
	_layout_bubbles()
	_apply_selection_styles()


func close_menu() -> void:
	_is_open = false
	visible = false


func is_open() -> bool:
	return _is_open


func _process(_delta: float) -> void:
	if not _is_open:
		return
	_layout_bubbles()
	_update_selection()


func _layout_bubbles() -> void:
	var center: Vector2 = size * 0.5
	for sector: int in SECTOR_COUNT:
		var angle: float = -PI * 0.5 + TAU * float(sector) / float(SECTOR_COUNT)
		var bubble_center: Vector2 = center + Vector2.from_angle(angle) * RING_RADIUS
		var bubble: BubbleButton = _buttons[sector]
		bubble.position = bubble_center - BUBBLE_SIZE * 0.5
		bubble.size = BUBBLE_SIZE
		bubble.pivot_offset = BUBBLE_SIZE * 0.5


func _update_selection() -> void:
	var stick: Vector2 = _get_selection_stick()
	if stick.length() >= CONTROLLER_SELECTION_DEADZONE:
		_select_sector_from_offset(stick)
		return
	if _controller_selection_mode:
		return
	_update_mouse_selection()


func _get_selection_stick() -> Vector2:
	if (
		_controller_mapping_manager != null
		and _controller_mapping_manager.has_custom_mapping()
	):
		return Vector2(
			_controller_mapping_manager.get_role_axis(
				ControllerMappingManagerType.ROLE_RIGHT_STICK_X
			),
			_controller_mapping_manager.get_role_axis(
				ControllerMappingManagerType.ROLE_RIGHT_STICK_Y
			),
		)
	return Vector2(
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_X),
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y),
	)


func _update_mouse_selection() -> void:
	var offset: Vector2 = get_local_mouse_position() - size * 0.5
	if offset.length() < 24.0:
		return
	_select_sector_from_offset(offset)


func _select_sector_from_offset(offset: Vector2) -> void:
	var angle: float = fposmod(offset.angle() + PI * 0.5 + PI / 8.0, TAU)
	var sector: int = int(floor(angle / (TAU / float(SECTOR_COUNT))))
	if sector == _selected_sector:
		return
	_selected_sector = sector
	_apply_selection_styles()


func _apply_selection_styles() -> void:
	for sector: int in _buttons.size():
		var bubble: BubbleButton = _buttons[sector]
		bubble.apply_profile()
		if sector == _selected_sector:
			bubble.add_theme_stylebox_override(
				"normal", BubbleProfile.make_hover_style()
			)
