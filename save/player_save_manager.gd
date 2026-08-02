class_name PlayerSaveManager
extends Node

const FishCatchType = preload("res://fish/fish_catch.gd")
const FishInventoryType = preload("res://inventory/fish_inventory.gd")
const CollectionLogType = preload("res://collection/collection_log.gd")
const PlayerWalletType = preload("res://economy/player_wallet.gd")
const FishPoolType = preload("res://fish/fish_pool.gd")
const SaveInspectionType = preload("res://save/player_save_inspection.gd")
const ItemCatalogType = preload("res://items/item_catalog.gd")
const OwnedItemType = preload("res://items/owned_item.gd")
const PlayerBagType = preload("res://inventory/player_bag.gd")
const PlayerHotbarType = preload("res://inventory/player_hotbar.gd")
const PlayerFishingUpgradesType = preload(
	"res://progression/player_fishing_upgrades.gd"
)
const PlayerCoolerCapacityType = preload(
	"res://progression/player_cooler_capacity.gd"
)
const PlayerArtUnlocksType = preload(
	"res://progression/player_art_unlocks.gd"
)

const SAVE_VERSION: int = 4
const BASIC_ROD_ID: StringName = &"basic_fishing_rod"
const MAX_SAFE_BALANCE: int = 1000000000000

class LoadSnapshot:
	extends RefCounted

	var catches: Array[FishCatchType] = []
	var discovered_ids: Array[StringName] = []
	var wallet_balance: int = 0
	var next_catch_sequence: int = 1
	var bag_items: Array[OwnedItemType] = []
	var hotbar_slots: Array[StringName] = []
	var fish_hotbar_slots: Array[StringName] = []
	var selected_hotbar_slot: int = 0
	var reel_speed_level: int = 0
	var barrier_power_level: int = 0
	var cooler_capacity_level: int = 0
	var art_unlock_mask: int = 0


@export_range(0.05, 5.0, 0.05) var autosave_delay: float = 0.5

var _inventory: FishInventoryType
var _collection_log: CollectionLogType
var _wallet: PlayerWalletType
var _catalog: FishPoolType
var _bag: PlayerBagType
var _hotbar: PlayerHotbarType
var _item_catalog: ItemCatalogType
var _fishing_upgrades: PlayerFishingUpgradesType
var _cooler_capacity: PlayerCoolerCapacityType
var _art_unlocks: PlayerArtUnlocksType
var _autosave_timer: Timer
var _is_configured: bool = false
var _is_restoring: bool = false
var _is_dirty: bool = false
var _automatic_saving_blocked: bool = false
var _autosave_enabled: bool = false
var _save_path := ""
var _expected_hash := ""
var _data_root: PlayerDataRoot


func configure_storage(path: String, data_root: PlayerDataRoot) -> void:
	_save_path = path
	_data_root = data_root


func _temp_path() -> String:
	return _save_path + ".tmp"


func _backup_path() -> String:
	return _save_path + ".backup"


func _ready() -> void:
	_autosave_timer = Timer.new()
	_autosave_timer.one_shot = true
	_autosave_timer.timeout.connect(_on_autosave_timeout)
	add_child(_autosave_timer)


func setup(
	inventory: FishInventoryType,
	collection_log: CollectionLogType,
	wallet: PlayerWalletType,
	catalog: FishPoolType,
	bag: PlayerBagType,
	hotbar: PlayerHotbarType,
	item_catalog: ItemCatalogType,
	fishing_upgrades: PlayerFishingUpgradesType,
	cooler_capacity: PlayerCoolerCapacityType,
	art_unlocks: PlayerArtUnlocksType,
) -> void:
	_inventory = inventory
	_collection_log = collection_log
	_wallet = wallet
	_catalog = catalog
	_bag = bag
	_hotbar = hotbar
	_item_catalog = item_catalog
	_fishing_upgrades = fishing_upgrades
	_cooler_capacity = cooler_capacity
	_art_unlocks = art_unlocks
	_is_configured = (
		_inventory != null
		and _collection_log != null
		and _wallet != null
		and _catalog != null
		and _bag != null
		and _hotbar != null
		and _item_catalog != null
		and _fishing_upgrades != null
		and _cooler_capacity != null
		and _art_unlocks != null
	)
	if not _is_configured:
		push_error("PlayerSaveManager setup is missing required references.")
		return
	if not _inventory.catches_changed.is_connected(_mark_dirty):
		_inventory.catches_changed.connect(_mark_dirty)
	if not _collection_log.fish_discovered.is_connected(
		_on_fish_discovered
	):
		_collection_log.fish_discovered.connect(_on_fish_discovered)
	if not _wallet.balance_changed.is_connected(_on_balance_changed):
		_wallet.balance_changed.connect(_on_balance_changed)
	if not _bag.contents_changed.is_connected(_mark_dirty):
		_bag.contents_changed.connect(_mark_dirty)
	if not _hotbar.slots_changed.is_connected(_mark_dirty):
		_hotbar.slots_changed.connect(_mark_dirty)
	if not _hotbar.selected_slot_changed.is_connected(
		_on_selected_hotbar_slot_changed
	):
		_hotbar.selected_slot_changed.connect(
			_on_selected_hotbar_slot_changed
		)
	if not _fishing_upgrades.upgrades_changed.is_connected(
		_on_upgrades_changed
	):
		_fishing_upgrades.upgrades_changed.connect(_on_upgrades_changed)
	if not _cooler_capacity.capacity_changed.is_connected(
		_on_cooler_capacity_changed
	):
		_cooler_capacity.capacity_changed.connect(
			_on_cooler_capacity_changed
		)
	if not _art_unlocks.unlocks_changed.is_connected(_on_art_unlocks_changed):
		_art_unlocks.unlocks_changed.connect(_on_art_unlocks_changed)


func load_player_data() -> bool:
	if not _is_configured:
		return false
	_automatic_saving_blocked = false
	_recover_interrupted_write()
	if _save_path.is_empty() or not FileAccess.file_exists(_save_path):
		_is_dirty = false
		return true

	var save_file := FileAccess.open(_save_path, FileAccess.READ)
	if save_file == null:
		_handle_corrupt_save("Unable to open player save.")
		return false
	var json_text: String = save_file.get_as_text()
	save_file.close()
	_expected_hash = PortableFileGuard.hash_file(_save_path)

	var json := JSON.new()
	var parse_error: Error = json.parse(json_text)
	if parse_error != OK or typeof(json.data) != TYPE_DICTIONARY:
		_handle_corrupt_save("Player save contains malformed JSON.")
		return false
	var save_data: Dictionary = json.data
	var version: int = _read_integer(save_data.get("save_version"), -1)
	if version > SAVE_VERSION:
		_automatic_saving_blocked = true
		push_warning(
			(
				"Player save version %d is newer than supported "
				+ "version %d; the file was left untouched."
			)
			% [version, SAVE_VERSION]
		)
		_restore_defaults()
		return false
	if version != SAVE_VERSION:
		save_data = _migrate_save(save_data, version)
		if save_data.is_empty():
			_handle_corrupt_save(
				"Player save version %d is unsupported." % version
			)
			return false

	var snapshot: LoadSnapshot = _build_load_snapshot(save_data)
	if snapshot == null:
		_handle_corrupt_save("Player save failed structural validation.")
		return false

	_is_restoring = true
	var inventory_restored: bool = _inventory.replace_all_catches(
		snapshot.catches,
		snapshot.next_catch_sequence
	)
	var collection_restored: bool = (
		_collection_log.replace_discovered_ids(snapshot.discovered_ids)
	)
	var wallet_restored: bool = _wallet.restore_balance(
		snapshot.wallet_balance
	)
	var bag_restored: bool = _bag.replace_all_items(snapshot.bag_items)
	var hotbar_restored: bool = _hotbar.replace_state(
		snapshot.hotbar_slots,
		snapshot.selected_hotbar_slot,
		snapshot.fish_hotbar_slots,
	)
	var upgrades_restored: bool = _fishing_upgrades.restore_levels(
		snapshot.reel_speed_level,
		snapshot.barrier_power_level
	)
	var cooler_restored: bool = _cooler_capacity.restore_level(
		snapshot.cooler_capacity_level
	)
	var art_restored: bool = _art_unlocks.restore_mask(
		snapshot.art_unlock_mask
	)
	_is_restoring = false
	if (
		not inventory_restored
		or not collection_restored
		or not wallet_restored
		or not bag_restored
		or not hotbar_restored
		or not upgrades_restored
		or not cooler_restored
		or not art_restored
	):
		push_error("Validated player save could not be restored.")
		return false

	_is_dirty = false
	print(
		"Loaded player save version %d with %d catches."
		% [SAVE_VERSION, snapshot.catches.size()]
	)
	return true


func inspect_save() -> SaveInspectionType:
	var result := SaveInspectionType.new()
	_recover_interrupted_write()
	result.has_primary_file = FileAccess.file_exists(_save_path)
	if not result.has_primary_file:
		result.status = SaveInspectionType.Status.MISSING
		result.message = "no save found."
		return result
	var save_file := FileAccess.open(_save_path, FileAccess.READ)
	if save_file == null:
		result.status = SaveInspectionType.Status.IO_ERROR
		result.message = "the save could not be read."
		return result
	var json := JSON.new()
	var parse_error: Error = json.parse(save_file.get_as_text())
	save_file.close()
	if parse_error != OK or typeof(json.data) != TYPE_DICTIONARY:
		result.status = SaveInspectionType.Status.MALFORMED
		result.message = "the save is corrupt and was preserved."
		return result
	var save_data: Dictionary = json.data
	result.detected_version = _read_integer(save_data.get("save_version"), -1)
	if result.detected_version > SAVE_VERSION:
		result.status = SaveInspectionType.Status.UNSUPPORTED_VERSION
		result.message = "this save belongs to a newer game version."
		return result
	if result.detected_version < 1:
		result.status = SaveInspectionType.Status.MALFORMED
		result.message = "the save version is unsupported."
		return result
	if result.detected_version != SAVE_VERSION:
		save_data = _migrate_save(save_data, result.detected_version)
		if save_data.is_empty():
			result.status = SaveInspectionType.Status.MALFORMED
			result.message = "the save version is unsupported."
			return result
	var snapshot: LoadSnapshot = _build_load_snapshot(save_data)
	if snapshot == null:
		result.status = SaveInspectionType.Status.MALFORMED
		result.message = "the save is structurally invalid and was preserved."
		return result
	result.status = SaveInspectionType.Status.VALID_SUPPORTED
	result.catch_count = snapshot.catches.size()
	result.wallet_balance = snapshot.wallet_balance
	result.discovered_species_count = snapshot.discovered_ids.size()
	result.message = "save ready."
	return result


func initialize_new_game() -> bool:
	if not _is_configured:
		return false
	_automatic_saving_blocked = false
	_restore_defaults()
	return true


func delete_progression_save() -> bool:
	if FileAccess.file_exists(_save_path) and not _remove_if_present(_save_path):
		return false
	for path: String in [_temp_path(), _backup_path()]:
		if FileAccess.file_exists(path) and not _remove_if_present(path):
			push_warning("Unable to remove stale player-save auxiliary file.")
	if _autosave_timer != null:
		_autosave_timer.stop()
	_is_dirty = false
	_automatic_saving_blocked = false
	_expected_hash = ""
	return true


func set_autosave_enabled(enabled: bool) -> void:
	_autosave_enabled = enabled
	if not enabled and _autosave_timer != null:
		_autosave_timer.stop()


func save_if_dirty() -> bool:
	return not _is_dirty or save_now()


func is_dirty() -> bool:
	return _is_dirty


func cancel_pending_autosave() -> void:
	if _autosave_timer != null:
		_autosave_timer.stop()
	_is_dirty = false


func save_now() -> bool:
	if (
		not _is_configured
		or _automatic_saving_blocked
		or not _autosave_enabled
	):
		return false
	var save_data: Dictionary = _build_save_dictionary()
	if save_data.is_empty():
		return false
	var json_text: String = JSON.stringify(save_data, "\t")
	if json_text.is_empty():
		return false

	var result := PortableFileGuard.write_guarded(
		_save_path,
		json_text.to_utf8_buffer(),
		_expected_hash,
		_data_root.conflict_directory(),
		_data_root.device_id,
	)
	if bool(result.get("conflict", false)):
		_data_root.report_conflict(
			str(result.get("message", "")),
			str(result.get("conflict_path", "")),
		)
	if not bool(result.get("ok", false)):
		push_warning("Unable to safely write the player save.")
		return false
	_expected_hash = str(result["hash"])
	_is_dirty = false
	return true


func delete_save_for_debug() -> bool:
	return delete_progression_save()


func _exit_tree() -> void:
	if _is_dirty and _autosave_enabled and not _automatic_saving_blocked:
		save_now()


func _build_save_dictionary() -> Dictionary:
	var serialized_catches: Array[Dictionary] = []
	for fish_catch: FishCatchType in _inventory.get_all_catches():
		if fish_catch == null or not fish_catch.is_valid():
			push_warning(
				"Player save aborted because inventory contains an "
				+ "invalid runtime catch."
			)
			return {}
		serialized_catches.append(fish_catch.to_save_dict())

	var discovered_strings: Array[String] = []
	for fish_id: StringName in _collection_log.get_discovered_ids():
		if fish_id.is_empty():
			return {}
		discovered_strings.append(String(fish_id))
	var serialized_items: Array[Dictionary] = []
	for owned: OwnedItemType in _bag.get_all_items():
		if owned == null or not owned.is_valid():
			return {}
		serialized_items.append(owned.to_save_dict())
	var serialized_slots: Array[String] = []
	for item_id: StringName in _hotbar.get_slots():
		serialized_slots.append(String(item_id))
	var serialized_fish_slots: Array[String] = []
	for catch_id: StringName in _hotbar.get_fish_slots():
		serialized_fish_slots.append(String(catch_id))
	if (
		_wallet.get_balance() < 0
		or _wallet.get_balance() > MAX_SAFE_BALANCE
		or _inventory.get_next_catch_sequence() < 1
		or (
			_inventory.get_next_catch_sequence()
			> FishCatchType.MAX_SAFE_SEQUENCE
		)
	):
		return {}

	return {
		"save_version": SAVE_VERSION,
		"wallet": {
			"balance": _wallet.get_balance(),
		},
		"collection": {
			"discovered_fish_ids": discovered_strings,
		},
		"inventory": {
			"next_catch_sequence": _inventory.get_next_catch_sequence(),
			"catches": serialized_catches,
		},
		"bag": {
			"items": serialized_items,
		},
		"hotbar": {
			"selected_slot": _hotbar.get_selected_slot(),
			"slots": serialized_slots,
			"fish_slots": serialized_fish_slots,
		},
		"upgrades": _fishing_upgrades.to_save_data(),
		"cooler": _cooler_capacity.to_save_data(),
		"art": _art_unlocks.to_save_data(),
	}


func _build_load_snapshot(save_data: Dictionary) -> LoadSnapshot:
	if (
		typeof(save_data.get("wallet")) != TYPE_DICTIONARY
		or typeof(save_data.get("collection")) != TYPE_DICTIONARY
		or typeof(save_data.get("inventory")) != TYPE_DICTIONARY
		or typeof(save_data.get("bag")) != TYPE_DICTIONARY
		or typeof(save_data.get("hotbar")) != TYPE_DICTIONARY
	):
		return null
	var wallet_data: Dictionary = save_data["wallet"]
	var collection_data: Dictionary = save_data["collection"]
	var inventory_data: Dictionary = save_data["inventory"]
	var bag_data: Dictionary = save_data["bag"]
	var hotbar_data: Dictionary = save_data["hotbar"]
	var upgrades_data: Dictionary = {}
	var cooler_data: Dictionary = {}
	var art_data: Dictionary = {}
	if typeof(save_data.get("upgrades")) == TYPE_DICTIONARY:
		upgrades_data = save_data["upgrades"]
	else:
		push_warning(
			"Saved fishing upgrades were missing or invalid; using defaults."
		)
	if typeof(save_data.get("cooler")) == TYPE_DICTIONARY:
		cooler_data = save_data["cooler"]
	else:
		push_warning("Saved Cooler data was missing or invalid; using defaults.")
	if typeof(save_data.get("art")) == TYPE_DICTIONARY:
		art_data = save_data["art"]
	if (
		not wallet_data.has("balance")
		or typeof(collection_data.get("discovered_fish_ids")) != TYPE_ARRAY
		or typeof(inventory_data.get("catches")) != TYPE_ARRAY
		or not inventory_data.has("next_catch_sequence")
		or typeof(bag_data.get("items")) != TYPE_ARRAY
		or typeof(hotbar_data.get("slots")) != TYPE_ARRAY
		or not hotbar_data.has("selected_slot")
	):
		return null

	var balance: int = _read_integer(
		wallet_data["balance"],
		-1,
		MAX_SAFE_BALANCE
	)
	var requested_next_sequence: int = _read_integer(
		inventory_data["next_catch_sequence"],
		-1,
		FishCatchType.MAX_SAFE_SEQUENCE
	)
	if balance < 0 or requested_next_sequence < 1:
		return null

	var snapshot := LoadSnapshot.new()
	snapshot.wallet_balance = balance
	var discovered_values: Array = collection_data["discovered_fish_ids"]
	var seen_discoveries: Dictionary[StringName, bool] = {}
	for value: Variant in discovered_values:
		if typeof(value) != TYPE_STRING and typeof(value) != TYPE_STRING_NAME:
			continue
		var fish_id: StringName = StringName(str(value))
		if fish_id.is_empty() or seen_discoveries.has(fish_id):
			continue
		seen_discoveries[fish_id] = true
		snapshot.discovered_ids.append(fish_id)

	var seen_ids: Dictionary[StringName, bool] = {}
	var seen_sequences: Dictionary[int, bool] = {}
	var maximum_sequence: int = 0
	var catch_values: Array = inventory_data["catches"]
	for catch_index: int in range(catch_values.size()):
		var catch_value: Variant = catch_values[catch_index]
		if typeof(catch_value) != TYPE_DICTIONARY:
			push_warning(
				"Skipped invalid saved catch at index %d." % catch_index
			)
			continue
		var catch_data: Dictionary = catch_value
		var fish_id: StringName = StringName(str(catch_data.get("fish_id", "")))
		var fish_data = _catalog.get_fish_by_id(fish_id)
		if fish_data == null:
			push_warning(
				"Skipped saved catch with missing fish ID '%s'."
				% String(fish_id)
			)
			continue
		var fish_catch: FishCatchType = FishCatchType.from_save_dict(
			catch_data,
			fish_data
		)
		if fish_catch == null:
			push_warning(
				"Skipped structurally invalid saved catch at index %d."
				% catch_index
			)
			continue
		if seen_ids.has(fish_catch.catch_id):
			push_warning(
				"Skipped duplicate saved catch ID '%s'."
				% String(fish_catch.catch_id)
			)
			continue
		if seen_sequences.has(fish_catch.catch_sequence):
			push_warning(
				"Skipped duplicate saved catch sequence %d."
				% fish_catch.catch_sequence
			)
			continue
		seen_ids[fish_catch.catch_id] = true
		seen_sequences[fish_catch.catch_sequence] = true
		maximum_sequence = maxi(
			maximum_sequence,
			fish_catch.catch_sequence
		)
		snapshot.catches.append(fish_catch)

	snapshot.next_catch_sequence = maxi(
		requested_next_sequence,
		maximum_sequence + 1
	)

	var seen_items: Dictionary[StringName, bool] = {}
	var item_values: Array = bag_data["items"]
	for item_index: int in range(item_values.size()):
		var value: Variant = item_values[item_index]
		if typeof(value) != TYPE_DICTIONARY:
			push_warning("Skipped invalid saved Bag item.")
			continue
		var item_record: Dictionary = value
		var item_id: StringName = StringName(
			str(item_record.get("item_id", ""))
		)
		var item_data = _item_catalog.get_item_by_id(item_id)
		var quantity: int = _read_integer(
			item_record.get("quantity"),
			-1,
			999
		)
		if (
			item_id.is_empty()
			or item_data == null
			or not item_data.is_valid()
			or quantity <= 0
			or seen_items.has(item_id)
		):
			push_warning(
				"Skipped invalid or unknown saved Bag item '%s'."
				% String(item_id)
			)
			continue
		var maximum: int = (
			item_data.max_stack if item_data.stackable else 1
		)
		if quantity > maximum:
			push_warning(
				"Skipped saved Bag item with invalid quantity '%s'."
				% String(item_id)
			)
			continue
		var owned := OwnedItemType.new()
		owned.item_id = item_id
		owned.quantity = quantity
		seen_items[item_id] = true
		snapshot.bag_items.append(owned)

	var slot_values: Array = hotbar_data["slots"]
	snapshot.hotbar_slots.resize(PlayerHotbarType.SLOT_COUNT)
	snapshot.hotbar_slots.fill(StringName())
	for slot_index: int in range(
		mini(slot_values.size(), PlayerHotbarType.SLOT_COUNT)
	):
		var slot_value: Variant = slot_values[slot_index]
		if typeof(slot_value) not in [TYPE_STRING, TYPE_STRING_NAME]:
			continue
		var slot_item_id: StringName = StringName(str(slot_value))
		if slot_item_id.is_empty():
			continue
		var slot_item = _item_catalog.get_item_by_id(slot_item_id)
		if (
			slot_item != null
			and slot_item.is_valid()
			and slot_item.hotbar_allowed
			and seen_items.has(slot_item_id)
		):
			snapshot.hotbar_slots[slot_index] = slot_item_id
	var fish_slot_values: Array = []
	if typeof(hotbar_data.get("fish_slots")) == TYPE_ARRAY:
		fish_slot_values = hotbar_data["fish_slots"]
	snapshot.fish_hotbar_slots.resize(PlayerHotbarType.SLOT_COUNT)
	snapshot.fish_hotbar_slots.fill(StringName())
	for slot_index: int in range(
		mini(fish_slot_values.size(), PlayerHotbarType.SLOT_COUNT)
	):
		if not snapshot.hotbar_slots[slot_index].is_empty():
			continue
		var slot_value: Variant = fish_slot_values[slot_index]
		if typeof(slot_value) not in [TYPE_STRING, TYPE_STRING_NAME]:
			continue
		var catch_id: StringName = StringName(str(slot_value))
		if not catch_id.is_empty() and seen_ids.has(catch_id):
			snapshot.fish_hotbar_slots[slot_index] = catch_id
	var selected_slot: int = _read_integer(
		hotbar_data["selected_slot"],
		0,
		PlayerHotbarType.SLOT_COUNT - 1
	)
	snapshot.selected_hotbar_slot = clampi(
		selected_slot,
		0,
		PlayerHotbarType.SLOT_COUNT - 1
	)
	snapshot.reel_speed_level = _read_upgrade_level(
		upgrades_data.get("reel_speed_level"),
		PlayerFishingUpgradesType.MAX_REEL_SPEED_LEVEL,
		"reel_speed_level"
	)
	snapshot.barrier_power_level = _read_upgrade_level(
		upgrades_data.get("barrier_power_level"),
		PlayerFishingUpgradesType.MAX_BARRIER_POWER_LEVEL,
		"barrier_power_level"
	)
	snapshot.cooler_capacity_level = _read_upgrade_level(
		cooler_data.get("capacity_level"),
		PlayerCoolerCapacityType.MAX_LEVEL,
		"cooler.capacity_level"
	)
	snapshot.art_unlock_mask = _read_integer(
		art_data.get("unlock_mask"),
		0,
		PlayerArtUnlocksType.ALL_UNLOCK_MASK,
	)
	return snapshot


func _migrate_save(
	data: Dictionary,
	from_version: int,
) -> Dictionary:
	if from_version == SAVE_VERSION:
		return data
	if from_version < 1 or from_version > SAVE_VERSION:
		return {}
	var migrated: Dictionary = data.duplicate(true)
	var current_version: int = from_version
	while current_version < SAVE_VERSION:
		match current_version:
			1:
				migrated = _migrate_version_1_to_2(migrated)
			2:
				migrated = _migrate_version_2_to_3(migrated)
			3:
				migrated = _migrate_version_3_to_4(migrated)
			_:
				return {}
		if migrated.is_empty():
			return {}
		current_version += 1
	return migrated


func _migrate_version_1_to_2(data: Dictionary) -> Dictionary:
	var migrated: Dictionary = data.duplicate(true)
	migrated["save_version"] = 2
	migrated["bag"] = {
			"items": [
				{
					"item_id": String(BASIC_ROD_ID),
					"quantity": 1,
				},
			],
		}
	var slots: Array[String] = []
	slots.resize(PlayerHotbarType.SLOT_COUNT)
	slots.fill("")
	slots[0] = String(BASIC_ROD_ID)
	migrated["hotbar"] = {
		"selected_slot": 0,
		"slots": slots,
	}
	return migrated


func _migrate_version_2_to_3(data: Dictionary) -> Dictionary:
	var migrated: Dictionary = data.duplicate(true)
	migrated["save_version"] = 3
	migrated["upgrades"] = {
		"reel_speed_level": 0,
		"barrier_power_level": 0,
	}
	return migrated


func _migrate_version_3_to_4(data: Dictionary) -> Dictionary:
	var migrated: Dictionary = data.duplicate(true)
	migrated["save_version"] = 4
	migrated["cooler"] = {"capacity_level": 0}
	return migrated


func _mark_dirty() -> void:
	if (
		_is_restoring
		or _automatic_saving_blocked
		or not _autosave_enabled
	):
		return
	_is_dirty = true
	if _autosave_timer != null and _autosave_timer.is_stopped():
		_autosave_timer.start(maxf(autosave_delay, 0.05))


func _on_fish_discovered(_fish_id: StringName) -> void:
	_mark_dirty()


func _on_balance_changed(_new_balance: int, _delta: int) -> void:
	_mark_dirty()


func _on_selected_hotbar_slot_changed(
	_slot_index: int,
	_item_id: StringName,
) -> void:
	_mark_dirty()


func _on_upgrades_changed(
	_reel_speed_level: int,
	_barrier_power_level: int,
) -> void:
	_mark_dirty()


func _on_cooler_capacity_changed(
	_level: int,
	_capacity: int,
) -> void:
	_mark_dirty()


func _on_art_unlocks_changed(_unlock_mask: int) -> void:
	_mark_dirty()


func _on_autosave_timeout() -> void:
	if _is_dirty:
		save_now()


func _recover_interrupted_write() -> void:
	if FileAccess.file_exists(_save_path):
		_remove_if_present(_temp_path())
		_remove_if_present(_backup_path())
		return
	if FileAccess.file_exists(_backup_path()):
		_rename_file(_backup_path(), _save_path)
	_remove_if_present(_temp_path())


func _handle_corrupt_save(message: String) -> void:
	push_warning(message)
	_restore_defaults()
	if not FileAccess.file_exists(_save_path):
		return
	var timestamp: int = int(Time.get_unix_time_from_system())
	var corrupt_path: String = (
		"%s.corrupt-%d" % [_save_path, timestamp]
	)
	if FileAccess.file_exists(corrupt_path):
		corrupt_path += "-%d" % Time.get_ticks_usec()
	if not _rename_file(_save_path, corrupt_path):
		_automatic_saving_blocked = true
		push_warning(
			"Corrupt player save was left in place; automatic saving is "
			+ "disabled for this run."
		)


func _restore_defaults() -> void:
	if not _is_configured:
		return
	_is_restoring = true
	var empty_catches: Array[FishCatchType] = []
	var empty_discoveries: Array[StringName] = []
	var default_items: Array[OwnedItemType] = []
	var basic_rod := OwnedItemType.new()
	basic_rod.item_id = BASIC_ROD_ID
	basic_rod.quantity = 1
	default_items.append(basic_rod)
	var default_slots: Array[StringName] = []
	default_slots.resize(PlayerHotbarType.SLOT_COUNT)
	default_slots.fill(StringName())
	default_slots[0] = BASIC_ROD_ID
	_inventory.replace_all_catches(empty_catches, 1)
	_collection_log.replace_discovered_ids(empty_discoveries)
	_wallet.restore_balance(0)
	_bag.replace_all_items(default_items)
	_hotbar.replace_state(default_slots, 0)
	_fishing_upgrades.reset_to_defaults()
	_cooler_capacity.reset_to_defaults()
	_art_unlocks.reset_to_defaults()
	_is_restoring = false
	_is_dirty = false


func _read_integer(
	value: Variant,
	invalid_value: int,
	maximum_value: int = 2147483647,
) -> int:
	if typeof(value) == TYPE_INT:
		var integer_value: int = int(value)
		if integer_value >= 0 and integer_value <= maximum_value:
			return integer_value
	elif typeof(value) == TYPE_FLOAT:
		var float_value: float = float(value)
		if (
			is_finite(float_value)
			and float_value >= 0.0
			and float_value <= float(maximum_value)
			and is_equal_approx(float_value, round(float_value))
		):
			return int(round(float_value))
	return invalid_value


func _read_upgrade_level(
	value: Variant,
	maximum_level: int,
	field_name: String,
) -> int:
	var parsed_value: int = 0
	var value_is_integer_like: bool = false
	if typeof(value) == TYPE_INT:
		parsed_value = int(value)
		value_is_integer_like = true
	elif typeof(value) == TYPE_FLOAT:
		var float_value: float = float(value)
		if is_finite(float_value) and is_equal_approx(
			float_value,
			round(float_value)
		):
			parsed_value = int(round(float_value))
			value_is_integer_like = true
	if not value_is_integer_like:
		push_warning(
			"Saved upgrade '%s' was invalid; using level 0." % field_name
		)
		return 0
	if parsed_value < 0:
		push_warning(
			"Saved upgrade '%s' was below 0; clamped to 0." % field_name
		)
		return 0
	if parsed_value > maximum_level:
		push_warning(
			(
				"Saved upgrade '%s' exceeded the supported maximum; "
				+ "clamped to %d."
			)
			% [field_name, maximum_level]
		)
		return maximum_level
	return parsed_value


func _rename_file(from_path: String, to_path: String) -> bool:
	return DirAccess.rename_absolute(
		ProjectSettings.globalize_path(from_path),
		ProjectSettings.globalize_path(to_path)
	) == OK


func _remove_if_present(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return true
	return DirAccess.remove_absolute(
		ProjectSettings.globalize_path(path)
	) == OK
