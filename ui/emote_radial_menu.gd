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

var _buttons: Array[BubbleButton] = []
var _is_open: bool = false
var _selected_sector: int = SIT_SECTOR


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
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or key_event.echo:
		return false
	if key_event.physical_keycode != KEY_C:
		return false
	if key_event.pressed:
		if _is_open or not can_open:
			return _is_open
		open_menu()
		return true
	if not _is_open:
		return false
	var selected: int = _selected_sector
	close_menu()
	if selected == SIT_SECTOR:
		emote_selected.emit(&"sit")
	return true


func open_menu() -> void:
	_is_open = true
	_selected_sector = SIT_SECTOR
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
	_update_mouse_selection()


func _layout_bubbles() -> void:
	var center: Vector2 = size * 0.5
	for sector: int in SECTOR_COUNT:
		var angle: float = -PI * 0.5 + TAU * float(sector) / float(SECTOR_COUNT)
		var bubble_center: Vector2 = center + Vector2.from_angle(angle) * RING_RADIUS
		var bubble: BubbleButton = _buttons[sector]
		bubble.position = bubble_center - BUBBLE_SIZE * 0.5
		bubble.size = BUBBLE_SIZE
		bubble.pivot_offset = BUBBLE_SIZE * 0.5


func _update_mouse_selection() -> void:
	var offset: Vector2 = get_local_mouse_position() - size * 0.5
	if offset.length() < 24.0:
		return
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
