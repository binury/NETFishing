class_name ShopSellInventory
extends Control

const MAIN_SHOP_BUYER_ID: StringName = &"main_fishing_shop"

var _layout: PlayerInventoryLayout
var _bag: PlayerBag
var _fish_inventory: FishInventory
var _item_catalog: ItemCatalog
var _buyer: FishBuyerProfile
var _reservations: PlayerAssetReservationService
var _network_sale: NetworkSaleService
var _inventory_grid: GeneralInventoryGrid
var _tray_grid: GridContainer
var _total_label: Label
var _feedback: Label
var _sell_button: Button
var _staged: Dictionary[String, Dictionary] = {}


func _ready() -> void:
	UtilityPageStyle.apply_page(self)
	_build_ui()


func setup(
	layout: PlayerInventoryLayout,
	bag: PlayerBag,
	fish_inventory: FishInventory,
	hotbar: PlayerHotbar,
	item_catalog: ItemCatalog,
	buyer: FishBuyerProfile,
	reservations: PlayerAssetReservationService,
	network_sale: NetworkSaleService,
) -> void:
	_layout = layout
	_bag = bag
	_fish_inventory = fish_inventory
	_item_catalog = item_catalog
	_buyer = buyer
	_reservations = reservations
	_network_sale = network_sale
	_inventory_grid.setup(
		layout,
		bag,
		fish_inventory,
		hotbar,
		item_catalog,
		PlayerInventoryLayout.InventoryContainer.INVENTORY,
	)
	_inventory_grid.entry_selected.connect(_on_inventory_entry_selected)
	if _layout != null:
		_layout.layout_changed.connect(_refresh)
	if _network_sale != null:
		_network_sale.local_sale_pending.connect(_on_sale_pending)
		_network_sale.local_sale_finished.connect(_on_sale_finished)
	_refresh()


func activate() -> void:
	_feedback.text = "select or drag items into the sell tray"
	_refresh()
	var slot := _inventory_grid.get_first_occupied_slot()
	if slot != null:
		slot.grab_focus()


func clear_staged() -> void:
	_staged.clear()
	_refresh_tray()


func _on_inventory_entry_selected(kind: int, identity: StringName) -> void:
	_stage(kind, identity)


func _stage(kind: int, identity: StringName) -> void:
	if identity.is_empty():
		return
	var key := (
		PlayerInventoryLayout.catch_key(identity)
		if kind == PlayerInventoryLayout.EntryKind.CATCH
		else PlayerInventoryLayout.item_key(identity)
	)
	if _staged.has(key):
		_staged.erase(key)
		_refresh_tray()
		return
	if kind == PlayerInventoryLayout.EntryKind.CATCH:
		var fish_catch := _fish_inventory.get_catch_by_id(identity)
		if fish_catch == null:
			_feedback.text = "that catch is no longer available"
			return
		if fish_catch.is_favorited:
			_feedback.text = "favorite catches cannot be sold"
			return
		if _reservations != null and _reservations.is_fish_reserved(identity):
			_feedback.text = "reserved in a letter"
			return
		_staged[key] = {"kind": kind, "identity": identity, "quantity": 1}
	else:
		var item := _item_catalog.get_item_by_id(identity)
		if not ItemResalePolicy.is_sellable(item):
			_feedback.text = "equipment cannot be sold"
			return
		var available := _bag.get_quantity(identity)
		if _reservations != null:
			available = _reservations.get_available_item_quantity(identity)
		if available < 1:
			_feedback.text = "that item is reserved"
			return
		_staged[key] = {
			"kind": kind,
			"identity": identity,
			"quantity": available,
		}
	_feedback.text = ""
	_refresh_tray()


func _on_drop_payload(payload: Dictionary) -> void:
	var payload_kind := str(payload.get("kind", ""))
	_stage(
		PlayerInventoryLayout.EntryKind.CATCH
		if payload_kind == "cooler_fish"
		else PlayerInventoryLayout.EntryKind.ITEM,
		StringName(str(payload.get(
			"catch_id" if payload_kind == "cooler_fish" else "item_id", ""
		))),
	)


func _on_remove_requested(key: String) -> void:
	_staged.erase(key)
	_refresh_tray()


func _submit_sale() -> void:
	if _staged.is_empty() or _network_sale == null:
		return
	var catch_ids: Array[StringName] = []
	var items: Dictionary[StringName, int] = {}
	for record: Dictionary in _staged.values():
		var identity := StringName(str(record.get("identity", "")))
		if int(record.get("kind", -1)) == PlayerInventoryLayout.EntryKind.CATCH:
			catch_ids.append(identity)
		else:
			items[identity] = int(record.get("quantity", 0))
	if _network_sale.request_local_mixed_sale(
		catch_ids, items, MAIN_SHOP_BUYER_ID
	).is_empty():
		_feedback.text = "sale could not be started"


func _on_sale_pending(_request_id: String) -> void:
	_sell_button.disabled = true
	_feedback.text = "selling…"


func _on_sale_finished(
	_request_id: String,
	accepted: bool,
	message: String,
	_catch_ids: Array[StringName],
	_payout: int,
) -> void:
	if accepted:
		_staged.clear()
	_feedback.text = message.to_lower()
	_refresh()


func _refresh() -> void:
	_validate_staged()
	_inventory_grid.refresh()
	_refresh_tray()


func _validate_staged() -> void:
	for key: String in _staged.keys():
		var record: Dictionary = _staged[key]
		var identity := StringName(str(record.get("identity", "")))
		if int(record.get("kind", -1)) == PlayerInventoryLayout.EntryKind.CATCH:
			if (
				_fish_inventory.get_catch_by_id(identity) == null
				or not _layout.is_catch_in_inventory(identity)
			):
				_staged.erase(key)
		elif (
			_bag.get_quantity(identity) < int(record.get("quantity", 0))
			or not _layout.is_item_in_inventory(identity)
		):
			_staged.erase(key)


func _refresh_tray() -> void:
	_refresh_inventory_staged_highlights()
	for child: Node in _tray_grid.get_children():
		child.queue_free()
	var keys: Array[String] = []
	keys.assign(_staged.keys())
	keys.sort()
	for key: String in keys:
		var record: Dictionary = _staged[key]
		var identity := StringName(str(record["identity"]))
		var icon: Texture2D
		var label: String
		if int(record["kind"]) == PlayerInventoryLayout.EntryKind.CATCH:
			var fish_catch := _fish_inventory.get_catch_by_id(identity)
			if fish_catch == null:
				continue
			icon = fish_catch.fish.display_texture
			label = fish_catch.fish.display_name
		else:
			var item := _item_catalog.get_item_by_id(identity)
			if item == null:
				continue
			icon = item.icon
			label = item.display_name
		var slot := ShopSaleTraySlot.new()
		_tray_grid.add_child(slot)
		slot.configure(key, icon, label, int(record.get("quantity", 1)))
		slot.remove_requested.connect(_on_remove_requested)
		slot.drop_requested.connect(_on_drop_payload)
	var drop_slot := ShopSaleTraySlot.new()
	_tray_grid.add_child(drop_slot)
	drop_slot.configure("", null, "drop an item here")
	drop_slot.disabled = false
	drop_slot.drop_requested.connect(_on_drop_payload)
	var total := _calculate_total()
	_total_label.text = str(total)
	_sell_button.disabled = (
		_staged.is_empty()
		or total < 0
		or _network_sale == null
		or _network_sale.is_local_sale_pending()
	)
	call_deferred("_configure_focus")


func _refresh_inventory_staged_highlights() -> void:
	if _inventory_grid == null:
		return
	for slot: GeneralInventorySlot in _inventory_grid.get_slots():
		var key: String = ""
		if not slot.entry_identity.is_empty():
			key = (
				PlayerInventoryLayout.catch_key(slot.entry_identity)
				if slot.entry_kind == PlayerInventoryLayout.EntryKind.CATCH
				else PlayerInventoryLayout.item_key(slot.entry_identity)
			)
		slot.set_staged(not key.is_empty() and _staged.has(key))


func _configure_focus() -> void:
	var controls: Array[Control] = []
	controls.assign(_inventory_grid.get_slots())
	for child: Node in _tray_grid.get_children():
		var control := child as Control
		if control != null and control.focus_mode != Control.FOCUS_NONE:
			controls.append(control)
	controls.append(_sell_button)
	ControllerFocusNavigation.configure_spatial_neighbors(controls)


func _calculate_total() -> int:
	var total: int = 0
	for record: Dictionary in _staged.values():
		var identity := StringName(str(record["identity"]))
		if int(record["kind"]) == PlayerInventoryLayout.EntryKind.CATCH:
			var fish_catch := _fish_inventory.get_catch_by_id(identity)
			if fish_catch == null:
				return -1
			total += _buyer.get_quality_offer(
				fish_catch.fish.get_sale_value_for_weight(fish_catch.weight_lb),
				fish_catch.quality,
			)
		else:
			var item := _item_catalog.get_item_by_id(identity)
			var unit_value := ItemResalePolicy.get_unit_value(item)
			if unit_value < 0:
				return -1
			total += unit_value * int(record.get("quantity", 0))
	return total


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var outer := MarginContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("margin_left", 68)
	outer.add_theme_constant_override("margin_top", 92)
	outer.add_theme_constant_override("margin_right", 68)
	outer.add_theme_constant_override("margin_bottom", 44)
	add_child(outer)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 20)
	outer.add_child(columns)

	var source := _build_panel(columns, "inventory")
	_inventory_grid = GeneralInventoryGrid.new()
	(source as VBoxContainer).add_child(_inventory_grid)
	var tray := _build_panel(columns, "sell tray")
	var tray_scroll := ScrollContainer.new()
	tray_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tray_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	(tray as VBoxContainer).add_child(tray_scroll)
	_tray_grid = GridContainer.new()
	_tray_grid.columns = PlayerInventoryLayout.INVENTORY_COLUMNS
	_tray_grid.add_theme_constant_override(
		"h_separation", GeneralInventoryGrid.DEFAULT_SLOT_SEPARATION
	)
	_tray_grid.add_theme_constant_override(
		"v_separation", GeneralInventoryGrid.DEFAULT_SLOT_SEPARATION
	)
	tray_scroll.add_child(_tray_grid)
	_feedback = Label.new()
	_feedback.text = "select or drag items into the sell tray"
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback.add_theme_color_override(
		"font_color", UtilityPageStyle.OCEAN_TEXT_SECONDARY
	)
	(tray as VBoxContainer).add_child(_feedback)
	var total_row := HBoxContainer.new()
	(tray as VBoxContainer).add_child(total_row)
	var total_title := Label.new()
	total_title.text = "total"
	total_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	total_row.add_child(total_title)
	var coin := TextureRect.new()
	coin.custom_minimum_size = Vector2(24.0, 24.0)
	coin.texture = preload("res://items/icons/shop/32_currency.png")
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	total_row.add_child(coin)
	_total_label = Label.new()
	_total_label.text = "0"
	total_row.add_child(_total_label)
	_sell_button = Button.new()
	_sell_button.text = "sell"
	UtilityPageStyle.apply_ocean_button(_sell_button)
	_sell_button.pressed.connect(_submit_sale)
	(tray as VBoxContainer).add_child(_sell_button)


func _build_panel(parent: HBoxContainer, title_text: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override(
		"panel",
		UtilityPageStyle.rounded_style(UtilityPageStyle.OCEAN_PANEL_MID, 16),
	)
	parent.add_child(panel)
	var margin := MarginContainer.new()
	for side: StringName in [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]:
		margin.add_theme_constant_override(side, 12)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 22)
	column.add_child(title)
	return column
