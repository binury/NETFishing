class_name PlayerSaveManager
extends Node

const FishCatchType = preload("res://fish/fish_catch.gd")
const FishQualityType = preload("res://fish/fish_quality.gd")
const FishInventoryType = preload("res://inventory/fish_inventory.gd")
const CollectionLogType = preload("res://collection/collection_log.gd")
const PlayerWalletType = preload("res://economy/player_wallet.gd")
const FishPoolType = preload("res://fish/fish_pool.gd")
const SaveInspectionType = preload("res://save/player_save_inspection.gd")
const ItemCatalogType = preload("res://items/item_catalog.gd")
const OwnedItemType = preload("res://items/owned_item.gd")
const PlayerBagType = preload("res://inventory/player_bag.gd")
const PlayerHotbarType = preload("res://inventory/player_hotbar.gd")
const PlayerInventoryLayoutType = preload(
	"res://inventory/player_inventory_layout.gd"
)
const PlayerFishingUpgradesType = preload(
	"res://progression/player_fishing_upgrades.gd"
)
const PlayerCoolerCapacityType = preload(
	"res://progression/player_cooler_capacity.gd"
)
const PlayerArtUnlocksType = preload(
	"res://progression/player_art_unlocks.gd"
)
const PlayerExperienceType = preload(
	"res://progression/player_experience.gd"
)
const WorldTimeServiceType = preload("res://world/world_time_service.gd")
const WorldWeatherServiceType = preload(
	"res://world/world_weather_service.gd"
)
const WorldLayoutType = preload("res://world/world_layout.gd")
const PlayerJobServiceType = preload("res://jobs/player_job_service.gd")
const PlayerType = preload("res://player/player.gd")

const SAVE_VERSION: int = 10
const LEGACY_SAVE_FILENAME := "player_save.json"
const ARCHIVE_EXTENSION := ".nfsave"
const BASIC_ROD_ID: StringName = &"basic_fishing_rod"
const MAX_SAFE_BALANCE: int = 1000000000000
const DEFAULT_WORLD_SEED: int = 13001
const MAX_WORLD_SEED: int = 2147483646

class LoadSnapshot:
	extends RefCounted

	var catches: Array[FishCatchType] = []
	var discovered_ids: Array[StringName] = []
	var discovered_quality_masks: Dictionary[StringName, int] = {}
	var wallet_balance: int = 0
	var next_catch_sequence: int = 1
	var bag_items: Array[OwnedItemType] = []
	var unlocked_bait_ids: Array[StringName] = []
	var active_bait_id: StringName
	var active_lure_id: StringName
	var hotbar_slots: Array[StringName] = []
	var fish_hotbar_slots: Array[StringName] = []
	var selected_hotbar_slot: int = 0
	var inventory_layout_data: Dictionary = {}
	var reel_speed_level: int = 0
	var barrier_power_level: int = 0
	var cooler_capacity_level: int = 0
	var art_unlock_mask: int = 0
	var total_experience: int = 0
	var world_layout: StringName = WorldLayoutType.GENERATED
	var world_seed: int = DEFAULT_WORLD_SEED
	var world_time_hours: float = WorldTimeServiceType.DEFAULT_START_HOUR
	var has_world_weather_state: bool = false
	var world_weather: WorldWeatherServiceType.Weather = (
		WorldWeatherServiceType.DEFAULT_WEATHER
	)
	var world_weather_seconds_remaining: float = (
		WorldWeatherServiceType.SUNNY_DURATION_RANGE.x
	)
	var jobs_data: Dictionary = PlayerJobServiceType.default_save_data()


@export_range(0.05, 5.0, 0.05) var autosave_delay: float = 0.5

var _inventory: FishInventoryType
var _collection_log: CollectionLogType
var _wallet: PlayerWalletType
var _catalog: FishPoolType
var _bag: PlayerBagType
var _hotbar: PlayerHotbarType
var _inventory_layout: PlayerInventoryLayoutType
var _item_catalog: ItemCatalogType
var _fishing_upgrades: PlayerFishingUpgradesType
var _cooler_capacity: PlayerCoolerCapacityType
var _art_unlocks: PlayerArtUnlocksType
var _experience: PlayerExperienceType
var _world_time: WorldTimeServiceType
var _world_weather: WorldWeatherServiceType
var _jobs: PlayerJobServiceType
var _player: PlayerType
var _autosave_timer: Timer
var _is_configured: bool = false
var _is_restoring: bool = false
var _is_dirty: bool = false
var _automatic_saving_blocked: bool = false
var _autosave_enabled: bool = false
var _save_path := ""
var _expected_hash := ""
var _data_root: PlayerDataRoot
var _world_layout: StringName = WorldLayoutType.GENERATED
var _world_seed: int = DEFAULT_WORLD_SEED


func configure_storage(path: String, data_root: PlayerDataRoot) -> void:
	_save_path = path
	_data_root = data_root


func _temp_path() -> String:
	return _save_path + ".tmp"


func _backup_path() -> String:
	return _save_path + ".backup"


func _codec_scratch_path() -> String:
	return _save_path + ".codec.tmp"


func _legacy_save_path() -> String:
	return _save_path.get_base_dir().path_join(LEGACY_SAVE_FILENAME)


func _read_path() -> String:
	if FileAccess.file_exists(_save_path):
		return _save_path
	var legacy: String = _legacy_save_path()
	return legacy if FileAccess.file_exists(legacy) else ""


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
	inventory_layout: PlayerInventoryLayoutType,
	item_catalog: ItemCatalogType,
	fishing_upgrades: PlayerFishingUpgradesType,
	cooler_capacity: PlayerCoolerCapacityType,
	art_unlocks: PlayerArtUnlocksType,
	experience: PlayerExperienceType,
	world_time: WorldTimeServiceType,
	world_weather: WorldWeatherServiceType,
	jobs: PlayerJobServiceType,
	player: PlayerType,
) -> void:
	_inventory = inventory
	_collection_log = collection_log
	_wallet = wallet
	_catalog = catalog
	_bag = bag
	_hotbar = hotbar
	_inventory_layout = inventory_layout
	_item_catalog = item_catalog
	_fishing_upgrades = fishing_upgrades
	_cooler_capacity = cooler_capacity
	_art_unlocks = art_unlocks
	_experience = experience
	_world_time = world_time
	_world_weather = world_weather
	_jobs = jobs
	_player = player
	_is_configured = (
		_inventory != null
		and _collection_log != null
		and _wallet != null
		and _catalog != null
		and _bag != null
		and _hotbar != null
		and _inventory_layout != null
		and _item_catalog != null
		and _fishing_upgrades != null
		and _cooler_capacity != null
		and _art_unlocks != null
		and _experience != null
		and _world_time != null
		and _world_weather != null
		and _jobs != null
		and _player != null
	)
	if not _is_configured:
		push_error("PlayerSaveManager setup is missing required references.")
		return
	if not _inventory.catches_changed.is_connected(_mark_dirty):
		_inventory.catches_changed.connect(_mark_dirty)
	if not _collection_log.collection_changed.is_connected(
		_on_collection_changed
	):
		_collection_log.collection_changed.connect(_on_collection_changed)
	if not _wallet.balance_changed.is_connected(_on_balance_changed):
		_wallet.balance_changed.connect(_on_balance_changed)
	if not _bag.contents_changed.is_connected(_mark_dirty):
		_bag.contents_changed.connect(_mark_dirty)
	if not _hotbar.slots_changed.is_connected(_mark_dirty):
		_hotbar.slots_changed.connect(_mark_dirty)
	if not _inventory_layout.layout_changed.is_connected(_mark_dirty):
		_inventory_layout.layout_changed.connect(_mark_dirty)
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
	if not _experience.experience_changed.is_connected(
		_on_experience_changed
	):
		_experience.experience_changed.connect(_on_experience_changed)
	if not _jobs.changed.is_connected(_mark_dirty):
		_jobs.changed.connect(_mark_dirty)
	if not _player.active_bait_changed.is_connected(_on_active_tackle_changed):
		_player.active_bait_changed.connect(_on_active_tackle_changed)
	if not _player.active_lure_changed.is_connected(_on_active_tackle_changed):
		_player.active_lure_changed.connect(_on_active_tackle_changed)


func load_player_data() -> bool:
	if not _is_configured:
		return false
	_automatic_saving_blocked = false
	_recover_interrupted_write()
	var read_path: String = _read_path()
	if _save_path.is_empty() or read_path.is_empty():
		_is_dirty = false
		return true
	var decoded: Dictionary = ProgressionSaveCodec.read_local_save(
		read_path,
		read_path == _legacy_save_path(),
	)
	if not bool(decoded.get("ok", false)):
		_handle_corrupt_save("Player save could not be decoded.", read_path)
		return false
	_expected_hash = (
		PortableFileGuard.hash_file(_save_path)
		if read_path == _save_path else ""
	)
	var save_data: Dictionary = decoded["data"]
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
				"Player save version %d is unsupported." % version,
				read_path,
			)
			return false

	var snapshot: LoadSnapshot = _build_load_snapshot(save_data)
	if snapshot == null:
		_handle_corrupt_save(
			"Player save failed structural validation.", read_path
		)
		return false

	_is_restoring = true
	var inventory_restored: bool = _inventory.replace_all_catches(
		snapshot.catches,
		snapshot.next_catch_sequence
	)
	var collection_restored: bool = (
		_collection_log.replace_discovery_state(
			snapshot.discovered_ids,
			snapshot.discovered_quality_masks,
		)
	)
	var wallet_restored: bool = _wallet.restore_balance(
		snapshot.wallet_balance
	)
	var bag_restored: bool = (
		_bag.replace_all_items(snapshot.bag_items)
		and _bag.replace_unlocked_bait_ids(snapshot.unlocked_bait_ids)
	)
	var tackle_restored: bool = _restore_tackle_selection(snapshot)
	var upgrades_restored: bool = _fishing_upgrades.restore_levels(
		snapshot.reel_speed_level,
		snapshot.barrier_power_level
	)
	var cooler_restored: bool = _cooler_capacity.restore_level(
		snapshot.cooler_capacity_level
	)
	var layout_restored: bool = _inventory_layout.restore_from_save_data(
		snapshot.inventory_layout_data
	)
	var hotbar_restored: bool = _hotbar.replace_state(
		snapshot.hotbar_slots,
		snapshot.selected_hotbar_slot,
		snapshot.fish_hotbar_slots,
		false,
	)
	var art_restored: bool = _art_unlocks.restore_mask(
		snapshot.art_unlock_mask
	)
	var experience_restored: bool = _experience.restore_total_experience(
		snapshot.total_experience
	)
	var world_time_restored: bool = (
		_world_time.restore_persistent_time_hours(snapshot.world_time_hours)
	)
	_world_layout = snapshot.world_layout
	_world_seed = snapshot.world_seed
	var world_weather_restored: bool = true
	if snapshot.has_world_weather_state:
		world_weather_restored = _world_weather.restore_persistent_state(
			snapshot.world_weather,
			snapshot.world_weather_seconds_remaining,
		)
	var jobs_restored: bool = _jobs.restore_from_save_data(snapshot.jobs_data)
	_is_restoring = false
	if (
		not inventory_restored
		or not collection_restored
		or not wallet_restored
		or not bag_restored
		or not tackle_restored
		or not hotbar_restored
		or not upgrades_restored
		or not cooler_restored
		or not layout_restored
		or not art_restored
		or not experience_restored
		or not world_time_restored
		or not world_weather_restored
		or not jobs_restored
	):
		push_error(
			(
				"Validated player save could not be restored: "
				+ "inventory=%s collection=%s wallet=%s bag=%s tackle=%s hotbar=%s "
				+ "upgrades=%s cooler=%s layout=%s art=%s experience=%s "
				+ "time=%s weather=%s jobs=%s"
			)
			% [
				inventory_restored,
				collection_restored,
				wallet_restored,
				bag_restored,
				tackle_restored,
				hotbar_restored,
				upgrades_restored,
				cooler_restored,
				layout_restored,
				art_restored,
				experience_restored,
				world_time_restored,
				world_weather_restored,
				jobs_restored,
			]
		)
		return false

	_is_dirty = false
	if read_path == _legacy_save_path():
		_migrate_legacy_plaintext_save(save_data, read_path)
	print(
		"Loaded player save version %d with %d catches."
		% [SAVE_VERSION, snapshot.catches.size()]
	)
	return true


func inspect_save() -> SaveInspectionType:
	var result := SaveInspectionType.new()
	_recover_interrupted_write()
	var read_path: String = _read_path()
	result.has_primary_file = not read_path.is_empty()
	if not result.has_primary_file:
		result.status = SaveInspectionType.Status.MISSING
		result.message = "no save found."
		return result
	var decoded: Dictionary = ProgressionSaveCodec.read_local_save(
		read_path,
		read_path == _legacy_save_path(),
	)
	if not bool(decoded.get("ok", false)):
		result.status = SaveInspectionType.Status.IO_ERROR
		result.message = "the save could not be read."
		return result
	var save_data: Dictionary = decoded["data"]
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


func export_progression_archive(path: String) -> Dictionary:
	if not _is_configured or path.is_empty():
		return {"ok": false, "message": "progression export is unavailable."}
	if _is_dirty and not save_if_dirty():
		return {"ok": false, "message": "progression could not be saved first."}
	var source_path: String = _read_path()
	if source_path.is_empty():
		return {"ok": false, "message": "there is no progression to export."}
	var decoded: Dictionary = ProgressionSaveCodec.read_local_save(
		source_path,
		source_path == _legacy_save_path(),
	)
	if not bool(decoded.get("ok", false)):
		return {"ok": false, "message": "the active progression could not be read."}
	var prepared: Dictionary = _prepare_external_save_data(decoded["data"])
	if not bool(prepared.get("ok", false)):
		return prepared
	var bytes: PackedByteArray = ProgressionSaveCodec.encode_archive(
		prepared["data"],
		path + ".codec.tmp",
	)
	if bytes.is_empty():
		return {"ok": false, "message": "the progression archive could not be encoded."}
	var result: Dictionary = PortableFileGuard.write_guarded(
		path,
		bytes,
		PortableFileGuard.hash_file(path),
		_data_root.conflict_directory(),
		_data_root.device_id,
	)
	if not bool(result.get("ok", false)):
		return {"ok": false, "message": "the progression archive could not be written."}
	var verified: Dictionary = inspect_progression_archive(path)
	if not bool(verified.get("ok", false)):
		return {"ok": false, "message": "the progression archive could not be verified."}
	verified["message"] = "progression archive created."
	return verified


func inspect_progression_archive(path: String) -> Dictionary:
	var decoded: Dictionary = ProgressionSaveCodec.read_archive(path)
	if not bool(decoded.get("ok", false)):
		return {
			"ok": false,
			"message": str(decoded.get("message", "could not open progression archive.")),
		}
	var prepared: Dictionary = _prepare_external_save_data(decoded["data"])
	if not bool(prepared.get("ok", false)):
		return prepared
	prepared["game_version"] = str(decoded.get("game_version", ""))
	prepared["created_at_unix"] = int(decoded.get("created_at_unix", 0))
	return prepared


func import_progression_archive(path: String) -> Dictionary:
	if not _is_configured:
		return {"ok": false, "message": "progression import is unavailable."}
	var inspected: Dictionary = inspect_progression_archive(path)
	if not bool(inspected.get("ok", false)):
		return inspected
	var current_path: String = _read_path()
	if not current_path.is_empty() and not _archive_replaced_save(current_path):
		return {"ok": false, "message": "the current progression could not be backed up."}
	var expected_hash: String = PortableFileGuard.hash_file(_save_path)
	var result: Dictionary = _write_current_save_data(
		inspected["data"], expected_hash
	)
	if not bool(result.get("ok", false)):
		return {"ok": false, "message": "the imported progression could not be installed."}
	_expected_hash = str(result.get("hash", ""))
	_remove_legacy_save_files()
	_is_dirty = false
	_automatic_saving_blocked = false
	return {
		"ok": true,
		"message": "progression imported.",
		"catch_count": inspected["catch_count"],
		"wallet_balance": inspected["wallet_balance"],
		"discovered_species_count": inspected["discovered_species_count"],
	}


func initialize_new_game(
	world_seed: int = DEFAULT_WORLD_SEED,
	world_layout: StringName = WorldLayoutType.GENERATED,
) -> bool:
	if not _is_configured:
		return false
	if (
		world_seed <= 0
		or world_seed > MAX_WORLD_SEED
		or not WorldLayoutType.is_valid(world_layout)
	):
		return false
	_automatic_saving_blocked = false
	_restore_defaults()
	_world_layout = world_layout
	_world_seed = world_seed
	_is_dirty = true
	return true


func get_world_layout() -> StringName:
	return _world_layout


func get_world_seed() -> int:
	return _world_seed


static func roll_world_seed() -> int:
	var random := RandomNumberGenerator.new()
	random.randomize()
	return random.randi_range(1, MAX_WORLD_SEED)


func delete_progression_save() -> bool:
	for primary_path: String in [_save_path, _legacy_save_path()]:
		if (
			FileAccess.file_exists(primary_path)
			and not _remove_if_present(primary_path)
		):
			return false
	for path: String in [
		_temp_path(),
		_backup_path(),
		_codec_scratch_path(),
		_legacy_save_path() + ".tmp",
		_legacy_save_path() + ".backup",
	]:
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


func save_world_time_checkpoint() -> bool:
	if (
		not _is_configured
		or _automatic_saving_blocked
		or not _autosave_enabled
	):
		return false
	_is_dirty = true
	return save_now()


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
	var result: Dictionary = _write_current_save_data(
		save_data, _expected_hash
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
	var serialized_quality_masks: Dictionary = {}
	var quality_masks: Dictionary[StringName, int] = (
		_collection_log.get_discovered_quality_masks()
	)
	for fish_id: StringName in quality_masks:
		var quality_mask: int = quality_masks[fish_id]
		if (
			fish_id.is_empty()
			or quality_mask <= 0
			or (quality_mask & ~FishQualityType.ALL_TIERS_MASK) != 0
		):
			return {}
		serialized_quality_masks[String(fish_id)] = quality_mask
	var serialized_items: Array[Dictionary] = []
	for owned: OwnedItemType in _bag.get_all_items():
		if owned == null or not owned.is_valid():
			return {}
		serialized_items.append(owned.to_save_dict())
	var serialized_unlocked_baits: Array[String] = []
	for item_id: StringName in _bag.get_unlocked_bait_ids():
		var item_data = _item_catalog.get_item_by_id(item_id)
		if item_data == null or not item_data.is_valid() or not item_data.is_bait():
			return {}
		serialized_unlocked_baits.append(String(item_id))
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
	var active_bait_id: StringName = _player.active_bait_id
	var active_lure_id: StringName = _player.active_lure_id
	if (
		(not active_bait_id.is_empty() and not _valid_active_tackle(
			active_bait_id, true
		))
		or (not active_lure_id.is_empty() and not _valid_active_tackle(
			active_lure_id, false
		))
	):
		return {}

	return {
		"save_version": SAVE_VERSION,
		"wallet": {
			"balance": _wallet.get_balance(),
		},
		"collection": {
			"discovered_fish_ids": discovered_strings,
			"discovered_quality_masks": serialized_quality_masks,
		},
		"inventory": {
			"next_catch_sequence": _inventory.get_next_catch_sequence(),
			"catches": serialized_catches,
		},
		"bag": {
			"items": serialized_items,
			"unlocked_bait_ids": serialized_unlocked_baits,
		},
		"tackle": {
			"active_bait_id": String(active_bait_id),
			"active_lure_id": String(active_lure_id),
		},
		"hotbar": {
			"selected_slot": _hotbar.get_selected_slot(),
			"slots": serialized_slots,
			"fish_slots": serialized_fish_slots,
		},
		"inventory_layout": _inventory_layout.to_save_data(),
		"upgrades": _fishing_upgrades.to_save_data(),
		"cooler": _cooler_capacity.to_save_data(),
		"art": _art_unlocks.to_save_data(),
		"experience": _experience.to_save_data(),
		"world": {
			"layout": String(_world_layout),
			"seed": _world_seed,
			"time_hours": _world_time.get_persistent_time_hours(),
			"weather": int(_world_weather.get_persistent_weather()),
			"weather_seconds_remaining": (
				_world_weather.get_persistent_seconds_remaining()
			),
		},
		"jobs": _jobs.to_save_data(),
	}


func _build_load_snapshot(save_data: Dictionary) -> LoadSnapshot:
	if (
		typeof(save_data.get("wallet")) != TYPE_DICTIONARY
		or typeof(save_data.get("collection")) != TYPE_DICTIONARY
		or typeof(save_data.get("inventory")) != TYPE_DICTIONARY
		or typeof(save_data.get("bag")) != TYPE_DICTIONARY
		or typeof(save_data.get("tackle")) != TYPE_DICTIONARY
		or typeof(save_data.get("hotbar")) != TYPE_DICTIONARY
		or typeof(save_data.get("inventory_layout")) != TYPE_DICTIONARY
		or typeof(save_data.get("experience")) != TYPE_DICTIONARY
		or typeof(save_data.get("jobs")) != TYPE_DICTIONARY
	):
		return null
	var wallet_data: Dictionary = save_data["wallet"]
	var collection_data: Dictionary = save_data["collection"]
	var inventory_data: Dictionary = save_data["inventory"]
	var bag_data: Dictionary = save_data["bag"]
	var tackle_data: Dictionary = save_data["tackle"]
	var hotbar_data: Dictionary = save_data["hotbar"]
	var inventory_layout_data: Dictionary = save_data["inventory_layout"]
	var experience_data: Dictionary = save_data["experience"]
	var jobs_data: Dictionary = save_data["jobs"]
	var world_data: Dictionary = {}
	if typeof(save_data.get("world")) == TYPE_DICTIONARY:
		world_data = save_data["world"]
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
		or typeof(collection_data.get("discovered_quality_masks"))
		!= TYPE_DICTIONARY
		or typeof(inventory_data.get("catches")) != TYPE_ARRAY
		or not inventory_data.has("next_catch_sequence")
		or typeof(bag_data.get("items")) != TYPE_ARRAY
		or (
			bag_data.has("unlocked_bait_ids")
			and typeof(bag_data.get("unlocked_bait_ids")) != TYPE_ARRAY
		)
		or typeof(hotbar_data.get("slots")) != TYPE_ARRAY
		or typeof(tackle_data.get("active_bait_id")) not in [
			TYPE_STRING, TYPE_STRING_NAME,
		]
		or typeof(tackle_data.get("active_lure_id")) not in [
			TYPE_STRING, TYPE_STRING_NAME,
		]
		or not hotbar_data.has("selected_slot")
		or not experience_data.has("total_experience")
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
	if world_data.has("layout"):
		if not WorldLayoutType.is_valid(world_data["layout"]):
			return null
		snapshot.world_layout = WorldLayoutType.normalized(
			world_data["layout"]
		)
	if world_data.has("seed"):
		snapshot.world_seed = _read_integer(
			world_data["seed"],
			-1,
			MAX_WORLD_SEED,
		)
		if snapshot.world_seed <= 0:
			return null
	snapshot.inventory_layout_data = inventory_layout_data.duplicate(true)
	snapshot.wallet_balance = balance
	snapshot.total_experience = _read_integer(
		experience_data["total_experience"],
		-1,
		PlayerExperienceType.MAX_TOTAL_EXPERIENCE,
	)
	if snapshot.total_experience < 0:
		return null
	if not PlayerJobServiceType.validate_save_data(jobs_data):
		return null
	snapshot.jobs_data = jobs_data.duplicate(true)
	if world_data.has("time_hours"):
		snapshot.world_time_hours = _read_world_time_hours(
			world_data["time_hours"]
		)
		if snapshot.world_time_hours < 0.0:
			return null
	var has_weather: bool = world_data.has("weather")
	var has_weather_seconds: bool = world_data.has(
		"weather_seconds_remaining"
	)
	if has_weather != has_weather_seconds:
		return null
	if has_weather:
		var weather_value: int = _read_integer(
			world_data["weather"],
			-1,
			WorldWeatherServiceType.Weather.FOGGY,
		)
		var weather_seconds: float = _read_world_weather_seconds(
			world_data["weather_seconds_remaining"]
		)
		if (
			not WorldWeatherServiceType.is_valid_weather(weather_value)
			or weather_seconds < 0.0
		):
			return null
		snapshot.has_world_weather_state = true
		snapshot.world_weather = (
			weather_value as WorldWeatherServiceType.Weather
		)
		snapshot.world_weather_seconds_remaining = weather_seconds
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
	var quality_mask_values: Dictionary = (
		collection_data["discovered_quality_masks"]
	)
	for key: Variant in quality_mask_values:
		if typeof(key) not in [TYPE_STRING, TYPE_STRING_NAME]:
			return null
		var fish_id: StringName = StringName(str(key))
		var mask: int = _read_integer(
			quality_mask_values[key],
			-1,
			FishQualityType.ALL_TIERS_MASK,
		)
		if (
			fish_id.is_empty()
			or not seen_discoveries.has(fish_id)
			or mask <= 0
			or (mask & ~FishQualityType.ALL_TIERS_MASK) != 0
		):
			return null
		snapshot.discovered_quality_masks[fish_id] = mask

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
		owned.storage_slot = _read_integer(
			item_record.get("storage_slot", -1),
			-1,
			PlayerBagType.MAX_STORAGE_SLOT_INDEX,
		)
		seen_items[item_id] = true
		snapshot.bag_items.append(owned)

	var seen_unlocked_baits: Dictionary[StringName, bool] = {}
	if bag_data.has("unlocked_bait_ids"):
		var unlocked_bait_values: Array = bag_data["unlocked_bait_ids"]
		for value: Variant in unlocked_bait_values:
			if typeof(value) not in [TYPE_STRING, TYPE_STRING_NAME]:
				continue
			var bait_id: StringName = StringName(str(value))
			var bait_data = _item_catalog.get_item_by_id(bait_id)
			if (
				bait_id.is_empty()
				or seen_unlocked_baits.has(bait_id)
				or bait_data == null
				or not bait_data.is_valid()
				or not bait_data.is_bait()
			):
				continue
			seen_unlocked_baits[bait_id] = true
			snapshot.unlocked_bait_ids.append(bait_id)
	for owned: OwnedItemType in snapshot.bag_items:
		var owned_item_data = _item_catalog.get_item_by_id(owned.item_id)
		if (
			owned_item_data != null
			and owned_item_data.is_bait()
			and not seen_unlocked_baits.has(owned.item_id)
		):
			seen_unlocked_baits[owned.item_id] = true
			snapshot.unlocked_bait_ids.append(owned.item_id)
	snapshot.active_bait_id = _validated_tackle_id(
		StringName(str(tackle_data.get("active_bait_id", ""))),
		true,
		seen_items,
	)
	snapshot.active_lure_id = _validated_tackle_id(
		StringName(str(tackle_data.get("active_lure_id", ""))),
		false,
		seen_items,
	)

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
			4:
				migrated = _migrate_version_4_to_5(migrated)
			5:
				migrated = _migrate_version_5_to_6(migrated)
			6:
				migrated = _migrate_version_6_to_7(migrated)
			7:
				migrated = _migrate_version_7_to_8(migrated)
			8:
				migrated = _migrate_version_8_to_9(migrated)
			9:
				migrated = _migrate_version_9_to_10(migrated)
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


func _migrate_version_4_to_5(data: Dictionary) -> Dictionary:
	var migrated: Dictionary = data.duplicate(true)
	if (
		typeof(migrated.get("inventory")) != TYPE_DICTIONARY
		or typeof(migrated.get("collection")) != TYPE_DICTIONARY
	):
		return {}
	var inventory_data: Dictionary = migrated["inventory"]
	var collection_data: Dictionary = migrated["collection"]
	if (
		typeof(inventory_data.get("catches")) != TYPE_ARRAY
		or typeof(collection_data.get("discovered_fish_ids")) != TYPE_ARRAY
	):
		return {}
	var catches: Array = inventory_data["catches"]
	var discovered_values: Array = collection_data["discovered_fish_ids"]
	var discovered_lookup: Dictionary[String, bool] = {}
	for value: Variant in discovered_values:
		if typeof(value) in [TYPE_STRING, TYPE_STRING_NAME]:
			var existing_id: String = str(value)
			if not existing_id.is_empty():
				discovered_lookup[existing_id] = true
	for index: int in catches.size():
		if typeof(catches[index]) != TYPE_DICTIONARY:
			continue
		var catch_data: Dictionary = catches[index]
		catch_data["quality"] = FishQualityType.Tier.BORING
		var catch_fish_id: String = str(catch_data.get("fish_id", ""))
		if not catch_fish_id.is_empty() and not discovered_lookup.has(
			catch_fish_id
		):
			discovered_values.append(catch_fish_id)
			discovered_lookup[catch_fish_id] = true
		catches[index] = catch_data
	inventory_data["catches"] = catches
	migrated["inventory"] = inventory_data
	var quality_masks: Dictionary = {}
	for value: Variant in discovered_values:
		if typeof(value) not in [TYPE_STRING, TYPE_STRING_NAME]:
			continue
		var fish_id: String = str(value)
		if not fish_id.is_empty():
			quality_masks[fish_id] = FishQualityType.bit_for(
				FishQualityType.Tier.BORING
			)
	collection_data["discovered_quality_masks"] = quality_masks
	collection_data["discovered_fish_ids"] = discovered_values
	migrated["collection"] = collection_data
	migrated["save_version"] = 5
	return migrated


func _migrate_version_5_to_6(data: Dictionary) -> Dictionary:
	var migrated: Dictionary = data.duplicate(true)
	migrated["save_version"] = 6
	migrated["experience"] = {"total_experience": 0}
	migrated["world"] = {
		"time_hours": WorldTimeServiceType.DEFAULT_START_HOUR,
	}
	return migrated


func _migrate_version_6_to_7(data: Dictionary) -> Dictionary:
	var migrated: Dictionary = data.duplicate(true)
	migrated["save_version"] = 7
	# Historical catch and sale totals cannot be reconstructed honestly from
	# current inventory. New cumulative counters begin at feature introduction.
	migrated["jobs"] = PlayerJobServiceType.default_save_data()
	return migrated


func _migrate_version_7_to_8(data: Dictionary) -> Dictionary:
	var migrated: Dictionary = data.duplicate(true)
	if (
		typeof(migrated.get("bag")) != TYPE_DICTIONARY
		or typeof(migrated.get("inventory")) != TYPE_DICTIONARY
		or typeof(migrated.get("hotbar")) != TYPE_DICTIONARY
	):
		return {}
	var bag_data: Dictionary = migrated["bag"]
	var inventory_data: Dictionary = migrated["inventory"]
	var hotbar_data: Dictionary = migrated["hotbar"]
	if (
		typeof(bag_data.get("items")) != TYPE_ARRAY
		or typeof(inventory_data.get("catches")) != TYPE_ARRAY
		or typeof(hotbar_data.get("slots")) != TYPE_ARRAY
	):
		return {}

	var placements: Array[Dictionary] = []
	var assigned: Dictionary[String, bool] = {}
	var item_slots: Array = hotbar_data["slots"]
	var fish_slots: Array = []
	if typeof(hotbar_data.get("fish_slots")) == TYPE_ARRAY:
		fish_slots = hotbar_data["fish_slots"]
	for slot: int in PlayerHotbarType.SLOT_COUNT:
		var item_id := StringName(
			str(item_slots[slot]) if slot < item_slots.size() else ""
		)
		if not item_id.is_empty():
			var item = _item_catalog.get_item_by_id(item_id)
			if item != null and not item.is_bait() and not item.is_lure():
				var key := PlayerInventoryLayoutType.item_key(item_id)
				if not assigned.has(key):
					placements.append({
						"kind": PlayerInventoryLayoutType.EntryKind.ITEM,
						"identity": String(item_id),
						"container": PlayerInventoryLayoutType.InventoryContainer.HOTBAR,
						"slot": slot,
					})
					assigned[key] = true
					continue
		var catch_id := StringName(
			str(fish_slots[slot]) if slot < fish_slots.size() else ""
		)
		if catch_id.is_empty():
			continue
		var catch_key := PlayerInventoryLayoutType.catch_key(catch_id)
		if assigned.has(catch_key):
			continue
		placements.append({
			"kind": PlayerInventoryLayoutType.EntryKind.CATCH,
			"identity": String(catch_id),
			"container": PlayerInventoryLayoutType.InventoryContainer.HOTBAR,
			"slot": slot,
		})
		assigned[catch_key] = true

	var next_inventory_slot: int = 0
	var next_storage_slot: int = 0
	for value: Variant in bag_data["items"] as Array:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var item_id := StringName(str((value as Dictionary).get("item_id", "")))
		var item = _item_catalog.get_item_by_id(item_id)
		if item == null or item.is_bait() or item.is_lure():
			continue
		var key := PlayerInventoryLayoutType.item_key(item_id)
		if assigned.has(key):
			continue
		var target := PlayerInventoryLayoutType.InventoryContainer.INVENTORY
		var target_slot := next_inventory_slot
		if next_inventory_slot < PlayerInventoryLayoutType.INVENTORY_CAPACITIES[0]:
			next_inventory_slot += 1
		else:
			target = PlayerInventoryLayoutType.InventoryContainer.STORAGE
			target_slot = next_storage_slot
			next_storage_slot += 1
		placements.append({
			"kind": PlayerInventoryLayoutType.EntryKind.ITEM,
			"identity": String(item_id),
			"container": target,
			"slot": target_slot,
		})
		assigned[key] = true
	for value: Variant in inventory_data["catches"] as Array:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var catch_id := StringName(
			str((value as Dictionary).get("catch_id", ""))
		)
		if catch_id.is_empty():
			continue
		var key := PlayerInventoryLayoutType.catch_key(catch_id)
		if assigned.has(key):
			continue
		var target := PlayerInventoryLayoutType.InventoryContainer.INVENTORY
		var target_slot := next_inventory_slot
		if next_inventory_slot < PlayerInventoryLayoutType.INVENTORY_CAPACITIES[0]:
			next_inventory_slot += 1
		else:
			target = PlayerInventoryLayoutType.InventoryContainer.STORAGE
			target_slot = next_storage_slot
			next_storage_slot += 1
		placements.append({
			"kind": PlayerInventoryLayoutType.EntryKind.CATCH,
			"identity": String(catch_id),
			"container": target,
			"slot": target_slot,
		})
		assigned[key] = true
	migrated["inventory_layout"] = {
		"backpack_level": 0,
		"placements": placements,
	}
	migrated["save_version"] = 8
	return migrated


func _migrate_version_8_to_9(data: Dictionary) -> Dictionary:
	var migrated: Dictionary = data.duplicate(true)
	var world_data: Dictionary = {}
	if typeof(migrated.get("world")) == TYPE_DICTIONARY:
		world_data = (migrated["world"] as Dictionary).duplicate(true)
	world_data["seed"] = DEFAULT_WORLD_SEED
	migrated["world"] = world_data
	migrated["save_version"] = 9
	return migrated


func _migrate_version_9_to_10(data: Dictionary) -> Dictionary:
	var migrated: Dictionary = data.duplicate(true)
	migrated["tackle"] = {
		"active_bait_id": "",
		"active_lure_id": "",
	}
	migrated["save_version"] = 10
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


func _on_collection_changed() -> void:
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


func _on_experience_changed(_total_experience: int, _level: int) -> void:
	_mark_dirty()


func _on_active_tackle_changed(_item_id: StringName) -> void:
	_mark_dirty()


func _on_autosave_timeout() -> void:
	if _is_dirty:
		save_now()


func _recover_interrupted_write() -> void:
	_remove_if_present(_codec_scratch_path())
	_recover_path_write(_save_path)
	_recover_path_write(_legacy_save_path())


func _recover_path_write(path: String) -> void:
	var temporary: String = path + ".tmp"
	var backup: String = path + ".backup"
	if FileAccess.file_exists(path):
		_remove_if_present(temporary)
		_remove_if_present(backup)
		return
	if FileAccess.file_exists(backup):
		_rename_file(backup, path)
	_remove_if_present(temporary)


func _write_current_save_data(
	save_data: Dictionary,
	expected_hash: String,
) -> Dictionary:
	var bytes: PackedByteArray = ProgressionSaveCodec.encode_local_save(
		save_data,
		_codec_scratch_path(),
	)
	if bytes.is_empty():
		return {"ok": false}
	return PortableFileGuard.write_guarded(
		_save_path,
		bytes,
		expected_hash,
		_data_root.conflict_directory(),
		_data_root.device_id,
	)


func _prepare_external_save_data(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {"ok": false, "message": "progression data is malformed."}
	var save_data: Dictionary = (value as Dictionary).duplicate(true)
	var version: int = _read_integer(save_data.get("save_version"), -1)
	if version > SAVE_VERSION:
		return {
			"ok": false,
			"message": "this progression belongs to a newer game version.",
		}
	if version < 1:
		return {"ok": false, "message": "the progression version is unsupported."}
	if version != SAVE_VERSION:
		save_data = _migrate_save(save_data, version)
		if save_data.is_empty():
			return {
				"ok": false,
				"message": "the progression version is unsupported.",
			}
	var snapshot: LoadSnapshot = _build_load_snapshot(save_data)
	if snapshot == null:
		return {"ok": false, "message": "the progression is structurally invalid."}
	return {
		"ok": true,
		"data": save_data,
		"catch_count": snapshot.catches.size(),
		"wallet_balance": snapshot.wallet_balance,
		"discovered_species_count": snapshot.discovered_ids.size(),
		"world_layout": String(snapshot.world_layout),
		"world_seed": snapshot.world_seed,
	}


func _migrate_legacy_plaintext_save(
	save_data: Dictionary,
	legacy_path: String,
) -> void:
	var result: Dictionary = _write_current_save_data(save_data, "")
	if not bool(result.get("ok", false)):
		push_warning("Legacy progression loaded but could not be encrypted yet.")
		return
	_expected_hash = str(result.get("hash", ""))
	if not _archive_replaced_save(legacy_path, "plaintext-migration"):
		push_warning(
			"Legacy progression was encrypted, but its migration backup failed."
		)
		return
	_remove_legacy_save_files()
	print("Upgraded legacy plaintext progression to the opaque save format.")


func _archive_replaced_save(
	source_path: String,
	reason: String = "before-import",
) -> bool:
	if source_path.is_empty() or not FileAccess.file_exists(source_path):
		return true
	var timestamp: String = Time.get_datetime_string_from_system().replace(
		":", "-"
	)
	var destination: String = _data_root.root_path.path_join(
		"backups/saves/player-save-%s-%s%s"
		% [reason, timestamp, ARCHIVE_EXTENSION]
	)
	if FileAccess.file_exists(destination):
		destination = destination.trim_suffix(ARCHIVE_EXTENSION) + (
			"-%s%s" % [Time.get_ticks_usec(), ARCHIVE_EXTENSION]
		)
	var decoded: Dictionary = ProgressionSaveCodec.read_local_save(
		source_path,
		source_path == _legacy_save_path(),
	)
	var bytes: PackedByteArray
	if bool(decoded.get("ok", false)):
		var prepared: Dictionary = _prepare_external_save_data(decoded["data"])
		if bool(prepared.get("ok", false)):
			bytes = ProgressionSaveCodec.encode_archive(
				prepared["data"], destination + ".codec.tmp"
			)
	if bytes.is_empty():
		bytes = PortableFileGuard.read_bytes(source_path)
		destination = (
			destination.trim_suffix(ARCHIVE_EXTENSION) + ".preserved"
		)
	if bytes.is_empty():
		return false
	var result: Dictionary = PortableFileGuard.write_guarded(
		destination,
		bytes,
		"",
		_data_root.conflict_directory(),
		_data_root.device_id,
	)
	return bool(result.get("ok", false))


func _remove_legacy_save_files() -> void:
	for path: String in [
		_legacy_save_path(),
		_legacy_save_path() + ".tmp",
		_legacy_save_path() + ".backup",
	]:
		_remove_if_present(path)


func _handle_corrupt_save(message: String, source_path: String) -> void:
	push_warning(message)
	_restore_defaults()
	if not FileAccess.file_exists(source_path):
		return
	var timestamp: int = int(Time.get_unix_time_from_system())
	var corrupt_path: String = (
		"%s.corrupt-%d" % [source_path, timestamp]
	)
	if FileAccess.file_exists(corrupt_path):
		corrupt_path += "-%d" % Time.get_ticks_usec()
	if not _rename_file(source_path, corrupt_path):
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
	var empty_quality_masks: Dictionary[StringName, int] = {}
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
	_collection_log.replace_discovery_state(
		empty_discoveries,
		empty_quality_masks,
	)
	_wallet.restore_balance(0)
	_bag.replace_all_items(default_items)
	var default_unlocked_baits: Array[StringName] = []
	_bag.replace_unlocked_bait_ids(default_unlocked_baits)
	_player.unequip_bait()
	_player.unequip_lure()
	_fishing_upgrades.reset_to_defaults()
	_cooler_capacity.reset_to_defaults()
	_inventory_layout.reset_to_defaults()
	_hotbar.replace_state(default_slots, 0)
	_art_unlocks.reset_to_defaults()
	_experience.reset_to_defaults()
	_world_time.restore_persistent_time_hours(
		WorldTimeServiceType.DEFAULT_START_HOUR
	)
	_world_weather.reset_persistent_state()
	_world_layout = WorldLayoutType.GENERATED
	_world_seed = DEFAULT_WORLD_SEED
	_jobs.reset_to_defaults()
	_is_restoring = false
	_is_dirty = false


func _valid_active_tackle(item_id: StringName, bait: bool) -> bool:
	var item = _item_catalog.get_item_by_id(item_id)
	return (
		item != null
		and item.is_available()
		and (item.is_bait() if bait else item.is_lure())
		and _bag.owns_item(item_id)
	)


func _validated_tackle_id(
	item_id: StringName,
	bait: bool,
	seen_items: Dictionary[StringName, bool],
) -> StringName:
	if item_id.is_empty():
		return StringName()
	var item = _item_catalog.get_item_by_id(item_id)
	if (
		item == null
		or not item.is_available()
		or not seen_items.has(item_id)
		or not (item.is_bait() if bait else item.is_lure())
	):
		push_warning("Skipped invalid saved active tackle '%s'." % String(item_id))
		return StringName()
	return item_id


func _restore_tackle_selection(snapshot: LoadSnapshot) -> bool:
	_player.unequip_bait()
	_player.unequip_lure()
	var bait_restored: bool = (
		snapshot.active_bait_id.is_empty()
		or _player.equip_bait(
			_item_catalog.get_item_by_id(snapshot.active_bait_id)
		)
	)
	var lure_restored: bool = (
		snapshot.active_lure_id.is_empty()
		or _player.equip_lure(
			_item_catalog.get_item_by_id(snapshot.active_lure_id)
		)
	)
	return bait_restored and lure_restored


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


func _read_world_time_hours(value: Variant) -> float:
	if typeof(value) not in [TYPE_FLOAT, TYPE_INT]:
		return -1.0
	var time_hours: float = float(value)
	if (
		not is_finite(time_hours)
		or time_hours < 0.0
		or time_hours >= WorldTimeServiceType.HOURS_PER_DAY
	):
		return -1.0
	return time_hours


func _read_world_weather_seconds(value: Variant) -> float:
	if typeof(value) not in [TYPE_FLOAT, TYPE_INT]:
		return -1.0
	var seconds_remaining: float = float(value)
	if (
		not is_finite(seconds_remaining)
		or seconds_remaining < 0.0
		or seconds_remaining > WorldWeatherServiceType.MAX_PERSISTED_SECONDS
	):
		return -1.0
	return seconds_remaining


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
