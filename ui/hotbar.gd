class_name HotbarUI
extends Control

const ItemCatalogType = preload("res://items/item_catalog.gd")
const PlayerBagType = preload("res://inventory/player_bag.gd")
const PlayerHotbarType = preload("res://inventory/player_hotbar.gd")
const BubbleHotbarSlotType = preload(
	"res://ui/components/bubble_hotbar/bubble_hotbar_slot.gd"
)
const FishingSpotType = preload("res://fishing/fishing_spot.gd")

const DESKTOP_REFERENCE_SIZE := Vector2(1280.0, 720.0)
const COMPACT_REFERENCE_SIZE := Vector2(640.0, 480.0)
const HOTBAR_PRESENTATION_SCALE: float = 0.60
const HOTBAR_CANONICAL_POSITION := Vector2(256.0, 288.0)
const HOTBAR_MENU_POSITION := Vector2(80.0, 198.0)

@onready var _presentation_scale_root: Control = %HotbarPresentationScaleRoot
@onready var _bubble_field: Control = %BubbleField
@onready var _selected_item_label: Label = %SelectedItemLabel
@onready var _item_name_timer: Timer = %ItemNameTimer

var _hotbar: PlayerHotbarType
var _bag: PlayerBagType
var _catalog: ItemCatalogType
var _fishing_spot: FishingSpotType
var _slots: Array[BubbleHotbarSlotType] = []
var _gameplay_input_enabled: bool = false
var _drag_enabled: bool = false
var _hovered_slot_index: int = -1
var _item_name_suppressed: bool = false
var _motion_elapsed: float = 0.0
var _compact_layout: bool = false
var _player_menu_context: bool = false
var _visibility_tween: Tween
var _visibility_generation: int = 0


func _ready() -> void:
	_item_name_timer.timeout.connect(_on_item_name_timer_timeout)
	resized.connect(_apply_layout)
	_collect_slots()
	_apply_layout()


func _process(delta: float) -> void:
	_motion_elapsed += delta
	for slot: BubbleHotbarSlotType in _slots:
		slot.advance_presentation(delta, _motion_elapsed)


func setup(
	hotbar: PlayerHotbarType,
	bag: PlayerBagType,
	catalog: ItemCatalogType,
	fishing_spot: FishingSpotType,
) -> void:
	_hotbar = hotbar
	_bag = bag
	_catalog = catalog
	_fishing_spot = fishing_spot
	if not _hotbar.slots_changed.is_connected(_refresh):
		_hotbar.slots_changed.connect(_refresh)
	if not _hotbar.selected_slot_changed.is_connected(
		_on_selected_slot_changed
	):
		_hotbar.selected_slot_changed.connect(_on_selected_slot_changed)
	if not _bag.contents_changed.is_connected(_refresh):
		_bag.contents_changed.connect(_refresh)
	for slot: BubbleHotbarSlotType in _slots:
		slot.setup(_hotbar, _bag, _catalog)
		slot.set_drag_enabled(_drag_enabled)
	_refresh()


func set_gameplay_input_enabled(enabled: bool) -> void:
	_gameplay_input_enabled = enabled


func set_drag_enabled(enabled: bool) -> void:
	_drag_enabled = enabled
	for slot: BubbleHotbarSlotType in _slots:
		slot.set_drag_enabled(enabled)
	if not enabled:
		_hovered_slot_index = -1
		_hide_item_name()


func set_player_menu_context(enabled: bool) -> void:
	if _player_menu_context == enabled:
		return
	_player_menu_context = enabled
	_presentation_scale_root.position = (
		HOTBAR_MENU_POSITION if enabled else HOTBAR_CANONICAL_POSITION
	)


func set_presentation_visible(should_show: bool, animate: bool = true) -> void:
	_visibility_generation += 1
	var generation: int = _visibility_generation
	if _visibility_tween != null:
		_visibility_tween.kill()
		_visibility_tween = null
	if should_show:
		visible = true
		if not animate:
			modulate.a = 1.0
			return
		_visibility_tween = create_tween()
		_visibility_tween.tween_property(
			self,
			"modulate:a",
			1.0,
			UIMotion.UTILITY_ENTER_DURATION,
		)
	else:
		if not visible:
			return
		if not animate:
			visible = false
			modulate.a = 1.0
			return
		_visibility_tween = create_tween()
		_visibility_tween.tween_property(
			self,
			"modulate:a",
			0.0,
			UIMotion.UTILITY_EXIT_DURATION,
		)
		_visibility_tween.finished.connect(
			func() -> void:
				if generation != _visibility_generation:
					return
				visible = false
				modulate.a = 1.0
				_visibility_tween = null
		)


func set_item_name_suppressed(suppressed: bool) -> void:
	_item_name_suppressed = suppressed
	if suppressed:
		_hovered_slot_index = -1
		_hide_item_name()


func _unhandled_input(event: InputEvent) -> void:
	if (
		not _gameplay_input_enabled
		or _hotbar == null
		or _fishing_spot == null
		or not _fishing_spot.can_change_hotbar_selection()
	):
		return
	if event is InputEventKey and event.pressed and not event.echo:
		for index: int in range(PlayerHotbarType.SLOT_COUNT):
			if event.is_action_pressed("hotbar_%d" % (index + 1)):
				_hotbar.select_slot(index)
				get_viewport().set_input_as_handled()
				return
	if (
		event is InputEventMouseButton
		and event.pressed
		and not event.shift_pressed
	):
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_hotbar.cycle_selection(-1)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_hotbar.cycle_selection(1)
			get_viewport().set_input_as_handled()


func _collect_slots() -> void:
	_slots.clear()
	for child: Node in _bubble_field.get_children():
		var slot := child as BubbleHotbarSlotType
		if slot == null:
			continue
		slot.item_hovered.connect(_on_slot_item_hovered)
		slot.item_hover_ended.connect(_on_slot_item_hover_ended)
		slot.item_drag_started.connect(_on_slot_drag_started)
		slot.item_drag_finished.connect(_on_slot_drag_finished)
		_slots.append(slot)
	_slots.sort_custom(
		func(
			left: BubbleHotbarSlotType,
			right: BubbleHotbarSlotType,
		) -> bool:
			return left.slot_index < right.slot_index
	)


func _apply_layout() -> void:
	if not is_node_ready():
		return
	_compact_layout = false
	var reference_size := DESKTOP_REFERENCE_SIZE
	_presentation_scale_root.size = reference_size
	_presentation_scale_root.scale = (
		Vector2.ONE * HOTBAR_PRESENTATION_SCALE
	)
	_presentation_scale_root.position = (
		HOTBAR_MENU_POSITION
		if _player_menu_context
		else HOTBAR_CANONICAL_POSITION
	)
	var field_size := (
		Vector2(580.0, 82.0)
		if _compact_layout
		else Vector2(790.0, 104.0)
	)
	_bubble_field.size = field_size
	_bubble_field.position = Vector2(
		(reference_size.x - field_size.x) * 0.5,
		reference_size.y - 8.0 - field_size.y
	)
	for slot: BubbleHotbarSlotType in _slots:
		slot.apply_layout(_compact_layout)


func _refresh() -> void:
	for slot: BubbleHotbarSlotType in _slots:
		slot.refresh()


func _on_selected_slot_changed(
	_slot_index: int,
	_item_id: StringName,
) -> void:
	_refresh()
	if _hovered_slot_index < 0:
		_show_selected_item_briefly()


func _on_slot_item_hovered(
	slot_index: int,
	item_id: StringName,
) -> void:
	if _item_name_suppressed:
		return
	_hovered_slot_index = slot_index
	_item_name_timer.stop()
	_show_item_name(item_id)


func _on_slot_item_hover_ended(slot_index: int) -> void:
	if slot_index != _hovered_slot_index:
		return
	_hovered_slot_index = -1
	_show_selected_item_briefly()


func _on_slot_drag_started() -> void:
	_hovered_slot_index = -1
	_hide_item_name()


func _on_slot_drag_finished() -> void:
	_show_selected_item_briefly()


func _show_selected_item_briefly() -> void:
	if _item_name_suppressed or _hotbar == null:
		_hide_item_name()
		return
	_show_item_name(_hotbar.get_selected_item_id())
	if _selected_item_label.visible:
		_item_name_timer.start()


func _show_item_name(item_id: StringName) -> void:
	if item_id.is_empty() or _catalog == null:
		_hide_item_name()
		return
	var item := _catalog.get_item_by_id(item_id)
	if item == null:
		_hide_item_name()
		return
	_selected_item_label.text = item.display_name
	_selected_item_label.visible = true


func _hide_item_name() -> void:
	_item_name_timer.stop()
	_selected_item_label.text = ""
	_selected_item_label.visible = false


func _on_item_name_timer_timeout() -> void:
	if _hovered_slot_index < 0:
		_hide_item_name()
