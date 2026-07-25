class_name PlayerMenu
extends Control

const CollectionLogType = preload("res://collection/collection_log.gd")
const FishCatchType = preload("res://fish/fish_catch.gd")
const FishDataType = preload("res://fish/fish_data.gd")
const FishInventoryType = preload("res://inventory/fish_inventory.gd")
const FishPoolType = preload("res://fish/fish_pool.gd")
const FishingSpotType = preload("res://fishing/fishing_spot.gd")
const PlayerType = preload("res://player/player.gd")

signal menu_visibility_changed(is_open: bool)

enum Section {
	INVENTORY,
	LOGBOOK,
}

enum SortMode {
	CATCH_ORDER,
	NAME,
	RARITY,
}

@onready var _inventory_tab: Button = %InventoryTab
@onready var _logbook_tab: Button = %LogbookTab
@onready var _close_button: Button = %CloseButton
@onready var _inventory_section: Control = %InventorySection
@onready var _logbook_section: Control = %LogbookSection
@onready var _sort_option: OptionButton = %SortOption
@onready var _sort_direction: Button = %SortDirection
@onready var _inventory_empty: Label = %InventoryEmpty
@onready var _inventory_grid: GridContainer = %InventoryGrid
@onready var _detail_texture: TextureRect = %DetailTexture
@onready var _detail_name: Label = %DetailName
@onready var _detail_data: Label = %DetailData
@onready var _logbook_empty: Label = %LogbookEmpty
@onready var _logbook_grid: GridContainer = %LogbookGrid

var _player: PlayerType
var _inventory: FishInventoryType
var _collection_log: CollectionLogType
var _catalog: FishPoolType
var _fishing_spot: FishingSpotType
var _current_section: Section = Section.INVENTORY
var _sort_mode: SortMode = SortMode.CATCH_ORDER
var _sort_descending: bool = true
var _selected_catch_id: StringName
var _prior_movement_enabled: bool = true
var _prior_camera_input_enabled: bool = true
var _control_snapshot_stored: bool = false
var _menu_generation: int = 0


func _ready() -> void:
	_inventory_tab.pressed.connect(
		_show_section.bind(Section.INVENTORY)
	)
	_logbook_tab.pressed.connect(
		_show_section.bind(Section.LOGBOOK)
	)
	_close_button.pressed.connect(close_menu)
	_sort_option.item_selected.connect(_on_sort_selected)
	_sort_direction.pressed.connect(_on_sort_direction_pressed)
	_sort_option.add_item("Catch order", SortMode.CATCH_ORDER)
	_sort_option.add_item("Name", SortMode.NAME)
	_sort_option.add_item("Rarity", SortMode.RARITY)
	_sort_option.select(SortMode.CATCH_ORDER)
	_update_sort_direction_text()
	_show_section(_current_section)


func setup(
	player: PlayerType,
	inventory: FishInventoryType,
	collection_log: CollectionLogType,
	catalog: FishPoolType,
	fishing_spot: FishingSpotType,
) -> void:
	_player = player
	_inventory = inventory
	_collection_log = collection_log
	_catalog = catalog
	_fishing_spot = fishing_spot
	if not _inventory.catches_changed.is_connected(_on_inventory_changed):
		_inventory.catches_changed.connect(_on_inventory_changed)
	if not _collection_log.fish_discovered.is_connected(_on_fish_discovered):
		_collection_log.fish_discovered.connect(_on_fish_discovered)
	if not _fishing_spot.bite_activated.is_connected(_on_bite_activated):
		_fishing_spot.bite_activated.connect(_on_bite_activated)
	_refresh_all()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if visible:
		if (
			event.is_action_pressed("open_backpack")
			or event.is_action_pressed("ui_cancel")
		):
			close_menu()
			get_viewport().set_input_as_handled()
		return
	if (
		event.is_action_pressed("open_backpack")
		and _fishing_spot != null
		and _fishing_spot.can_open_player_menu()
	):
		open_menu()
		get_viewport().set_input_as_handled()


func open_menu() -> void:
	if (
		visible
		or _player == null
		or _fishing_spot == null
		or not _fishing_spot.can_open_player_menu()
	):
		return
	_menu_generation += 1
	_prior_movement_enabled = _player.is_movement_enabled()
	_prior_camera_input_enabled = _player.is_camera_input_enabled()
	_control_snapshot_stored = true
	_player.set_movement_enabled(false)
	_player.set_camera_input_enabled(false)
	visible = true
	_refresh_all()
	_show_section(_current_section)
	_focus_current_section()
	menu_visibility_changed.emit(true)


func close_menu() -> void:
	if not visible:
		return
	var closing_generation: int = _menu_generation
	visible = false
	get_viewport().gui_release_focus()
	_restore_player_controls(closing_generation)
	_menu_generation += 1
	menu_visibility_changed.emit(false)


func _exit_tree() -> void:
	if visible:
		visible = false
		_restore_player_controls(_menu_generation)
		_selected_catch_id = StringName()
	_menu_generation += 1


func _restore_player_controls(generation: int) -> void:
	if (
		generation != _menu_generation
		or not _control_snapshot_stored
	):
		return
	if _player != null and is_instance_valid(_player):
		_player.set_movement_enabled(_prior_movement_enabled)
		_player.set_camera_input_enabled(_prior_camera_input_enabled)
	_control_snapshot_stored = false


func _on_bite_activated() -> void:
	if visible:
		close_menu()


func _show_section(section: Section) -> void:
	_current_section = section
	if not is_node_ready():
		return
	_inventory_section.visible = section == Section.INVENTORY
	_logbook_section.visible = section == Section.LOGBOOK
	_inventory_tab.button_pressed = section == Section.INVENTORY
	_logbook_tab.button_pressed = section == Section.LOGBOOK
	if visible:
		_focus_current_section()


func _focus_current_section() -> void:
	if _current_section == Section.INVENTORY:
		_inventory_tab.grab_focus()
	else:
		_logbook_tab.grab_focus()


func _on_sort_selected(index: int) -> void:
	_sort_mode = _sort_option.get_item_id(index)
	_refresh_inventory()


func _on_sort_direction_pressed() -> void:
	_sort_descending = not _sort_descending
	_update_sort_direction_text()
	_refresh_inventory()


func _update_sort_direction_text() -> void:
	match _sort_mode:
		SortMode.CATCH_ORDER:
			_sort_direction.text = "Newest first" if _sort_descending else "Oldest first"
		SortMode.NAME:
			_sort_direction.text = "Z–A" if _sort_descending else "A–Z"
		SortMode.RARITY:
			_sort_direction.text = "High to low" if _sort_descending else "Low to high"


func _refresh_all() -> void:
	_refresh_inventory()
	_refresh_logbook()


func _on_inventory_changed() -> void:
	_refresh_inventory()
	_refresh_logbook()


func _on_fish_discovered(_fish_id: StringName) -> void:
	_refresh_logbook()


func _refresh_inventory() -> void:
	if not is_node_ready():
		return
	_clear_container(_inventory_grid)
	var catches: Array[FishCatchType] = []
	if _inventory != null:
		for fish_catch: FishCatchType in _inventory.get_all_catches():
			if fish_catch != null and fish_catch.is_valid():
				catches.append(fish_catch)
	catches.sort_custom(_compare_catches)
	_inventory_empty.visible = catches.is_empty()

	var selected: FishCatchType
	if _inventory != null:
		selected = _inventory.get_catch(_selected_catch_id)
	if selected == null and not catches.is_empty():
		selected = catches.front()
		_selected_catch_id = selected.catch_id
	for fish_catch: FishCatchType in catches:
		_inventory_grid.add_child(_create_inventory_card(fish_catch))
	_update_inventory_detail(selected)
	_update_sort_direction_text()


func _compare_catches(left: FishCatchType, right: FishCatchType) -> bool:
	var comparison: int = 0
	match _sort_mode:
		SortMode.CATCH_ORDER:
			comparison = left.catch_sequence - right.catch_sequence
		SortMode.NAME:
			comparison = left.fish.display_name.naturalnocasecmp_to(
				right.fish.display_name
			)
		SortMode.RARITY:
			comparison = left.fish.rarity - right.fish.rarity
	if comparison == 0:
		comparison = left.catch_sequence - right.catch_sequence
	return comparison > 0 if _sort_descending else comparison < 0


func _create_inventory_card(fish_catch: FishCatchType) -> Button:
	var card := Button.new()
	card.custom_minimum_size = Vector2(170.0, 160.0)
	card.toggle_mode = true
	card.button_pressed = fish_catch.catch_id == _selected_catch_id
	card.tooltip_text = String(fish_catch.catch_id)
	card.pressed.connect(_select_catch.bind(fish_catch.catch_id))

	var content := VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(content)
	content.add_child(_create_texture_frame(fish_catch.fish.display_texture, Vector2(138.0, 82.0)))
	var name_label := Label.new()
	name_label.text = fish_catch.fish.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(name_label)
	var data_label := Label.new()
	data_label.text = "%.2f lb • %s\nCatch #%d" % [
		fish_catch.weight_lb,
		fish_catch.fish.get_rarity_name(),
		fish_catch.catch_sequence,
	]
	data_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	data_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(data_label)
	return card


func _select_catch(catch_id: StringName) -> void:
	if _inventory == null:
		return
	var selected: FishCatchType = _inventory.get_catch(catch_id)
	if selected == null:
		return
	_selected_catch_id = catch_id
	_refresh_inventory()


func _update_inventory_detail(fish_catch: FishCatchType) -> void:
	if fish_catch == null:
		_detail_texture.texture = null
		_detail_texture.visible = false
		_detail_name.text = ""
		_detail_data.text = ""
		return
	_detail_texture.texture = fish_catch.fish.display_texture
	_detail_texture.visible = fish_catch.fish.display_texture != null
	_detail_name.text = fish_catch.fish.display_name
	_detail_data.text = "%.2f lb\n%s\nCatch #%d\n%s" % [
		fish_catch.weight_lb,
		fish_catch.fish.get_rarity_name(),
		fish_catch.catch_sequence,
		String(fish_catch.catch_id),
	]


func _refresh_logbook() -> void:
	if not is_node_ready():
		return
	_clear_container(_logbook_grid)
	var valid_species: Array[FishDataType] = []
	if _catalog != null:
		for fish: FishDataType in _catalog.candidates:
			if fish != null and not fish.id.is_empty():
				valid_species.append(fish)
	_logbook_empty.visible = valid_species.is_empty()
	_logbook_empty.text = (
		"No fish catalog configured."
		if valid_species.is_empty()
		else "No species discovered yet."
	)
	if not valid_species.is_empty() and _collection_log != null:
		var any_discovered: bool = false
		for fish: FishDataType in valid_species:
			if _collection_log.has_discovered(fish.id):
				any_discovered = true
				break
		_logbook_empty.visible = not any_discovered
	for fish: FishDataType in valid_species:
		_logbook_grid.add_child(_create_logbook_card(fish))


func _create_logbook_card(fish: FishDataType) -> Control:
	var discovered: bool = (
		_collection_log != null
		and _collection_log.has_discovered(fish.id)
	)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(190.0, 170.0)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	card.add_child(content)
	var texture_frame: TextureRect = _create_texture_frame(
		fish.display_texture,
		Vector2(170.0, 92.0)
	)
	if not discovered:
		texture_frame.modulate = Color(0.08, 0.1, 0.12, 1.0)
	content.add_child(texture_frame)
	var name_label := Label.new()
	name_label.text = fish.display_name if discovered else "???"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(name_label)
	var details := Label.new()
	if discovered:
		var owned_count: int = (
			_inventory.get_count(fish.id) if _inventory != null else 0
		)
		details.text = "%s\nOwned: %d" % [
			fish.get_rarity_name(),
			owned_count,
		]
	else:
		details.text = "Undiscovered"
	details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(details)
	return card


func _create_texture_frame(
	texture: Texture2D,
	minimum_size: Vector2,
) -> TextureRect:
	var texture_frame := TextureRect.new()
	texture_frame.custom_minimum_size = minimum_size
	texture_frame.texture = texture
	texture_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if texture == null:
		texture_frame.tooltip_text = "Display texture unavailable"
	return texture_frame


func _clear_container(container: Container) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()
