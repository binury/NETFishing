class_name GeneralInventoryGrid
extends Control

signal entry_selected(kind: int, identity: StringName)
signal slot_activated(slot: GeneralInventorySlot)
signal context_requested(slot: GeneralInventorySlot)
signal context_changed(slot: GeneralInventorySlot, text: String, active: bool)

const DEFAULT_SLOT_SIZE := Vector2(52.0, 52.0)
const DEFAULT_SLOT_SEPARATION: int = 5
const COLUMNS: int = PlayerInventoryLayout.INVENTORY_COLUMNS

var _layout: PlayerInventoryLayout
var _bag: PlayerBag
var _fish_inventory: FishInventory
var _hotbar: PlayerHotbar
var _item_catalog: ItemCatalog
var _container: int = PlayerInventoryLayout.InventoryContainer.INVENTORY
var _grid: GridContainer
var _slots: Array[GeneralInventorySlot] = []
var _slot_size: Vector2 = DEFAULT_SLOT_SIZE
var _slot_separation: int = DEFAULT_SLOT_SEPARATION


func _ready() -> void:
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_apply_grid_separation()
	add_child(_grid)


func set_slot_presentation(slot_size: Vector2, separation: int) -> void:
	_slot_size = Vector2(maxf(1.0, slot_size.x), maxf(1.0, slot_size.y))
	_slot_separation = maxi(0, separation)
	if _grid != null:
		_apply_grid_separation()
	if is_node_ready() and _layout != null:
		var active_capacity := (
			_layout.get_inventory_capacity()
			if _container == PlayerInventoryLayout.InventoryContainer.INVENTORY
			else _layout.get_storage_capacity()
		)
		_rebuild(
			PlayerInventoryLayout.MAX_INVENTORY_SLOT_COUNT
			if _container == PlayerInventoryLayout.InventoryContainer.INVENTORY
			else PlayerInventoryLayout.MAX_STORAGE_SLOT_COUNT,
			active_capacity,
		)


func setup(
	layout: PlayerInventoryLayout,
	bag: PlayerBag,
	fish_inventory: FishInventory,
	hotbar: PlayerHotbar,
	item_catalog: ItemCatalog,
	container: int,
) -> void:
	_layout = layout
	_bag = bag
	_fish_inventory = fish_inventory
	_hotbar = hotbar
	_item_catalog = item_catalog
	_container = container
	if _layout != null and not _layout.layout_changed.is_connected(refresh):
		_layout.layout_changed.connect(refresh)
	refresh()


func refresh() -> void:
	if not is_node_ready() or _layout == null:
		return
	var active_capacity := (
		_layout.get_inventory_capacity()
		if _container == PlayerInventoryLayout.InventoryContainer.INVENTORY
		else _layout.get_storage_capacity()
	)
	var visible_capacity := (
		PlayerInventoryLayout.MAX_INVENTORY_SLOT_COUNT
		if _container == PlayerInventoryLayout.InventoryContainer.INVENTORY
		else PlayerInventoryLayout.MAX_STORAGE_SLOT_COUNT
	)
	if _slots.size() != visible_capacity:
		_rebuild(visible_capacity, active_capacity)
	else:
		for index: int in _slots.size():
			_slots[index].set_locked(index >= active_capacity)
	for slot: GeneralInventorySlot in _slots:
		slot.refresh()


func get_slots() -> Array[GeneralInventorySlot]:
	var active: Array[GeneralInventorySlot] = []
	for slot: GeneralInventorySlot in _slots:
		if not slot.disabled:
			active.append(slot)
	return active


func get_first_occupied_slot() -> GeneralInventorySlot:
	for slot: GeneralInventorySlot in _slots:
		if not slot.entry_identity.is_empty():
			return slot
	return _slots.front() if not _slots.is_empty() else null


func _rebuild(visible_capacity: int, active_capacity: int) -> void:
	for child: Node in _grid.get_children():
		child.queue_free()
	_slots.clear()
	for slot_index: int in visible_capacity:
		var slot := GeneralInventorySlot.new()
		slot.custom_minimum_size = _slot_size
		slot.entry_selected.connect(
			func(kind: int, identity: StringName) -> void:
				entry_selected.emit(kind, identity)
		)
		slot.pressed.connect(func() -> void: slot_activated.emit(slot))
		slot.context_requested.connect(
			func(source: GeneralInventorySlot) -> void:
				context_requested.emit(source)
		)
		slot.context_changed.connect(
			func(
				source: GeneralInventorySlot,
				text: String,
				active: bool,
			) -> void:
				context_changed.emit(source, text, active)
		)
		_grid.add_child(slot)
		slot.set_presentation_size(_slot_size)
		slot.configure(
			slot_index,
			_container,
			slot_index >= active_capacity,
			_layout,
			_bag,
			_fish_inventory,
			_hotbar,
			_item_catalog,
		)
		_slots.append(slot)
	custom_minimum_size = Vector2(
		float(COLUMNS) * _slot_size.x
		+ float(COLUMNS - 1) * _slot_separation,
		ceilf(float(visible_capacity) / float(COLUMNS)) * _slot_size.y
		+ maxf(
			0.0,
			ceilf(float(visible_capacity) / float(COLUMNS)) - 1.0,
		) * _slot_separation,
	)
	size = custom_minimum_size
	ControllerFocusNavigation.configure_spatial_neighbors(_slots)


func _apply_grid_separation() -> void:
	_grid.add_theme_constant_override("h_separation", _slot_separation)
	_grid.add_theme_constant_override("v_separation", _slot_separation)
