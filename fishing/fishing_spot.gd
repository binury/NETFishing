class_name FishingSpot
extends Node3D

const FishDataType = preload("res://fish/fish_data.gd")
const FishCatchType = preload("res://fish/fish_catch.gd")
const FishSelectorType = preload("res://fish/fish_selector.gd")
const CollectionLogType = preload("res://collection/collection_log.gd")
const CatchControllerType = preload("res://fishing/catch_controller.gd")
const FishingContextType = preload("res://fishing/fishing_context.gd")
const FishingPresentationType = preload("res://fishing/fishing_presentation.gd")
const FishInventoryType = preload("res://inventory/fish_inventory.gd")
const ItemCatalogType = preload("res://items/item_catalog.gd")
const ItemDataType = preload("res://items/item_data.gd")
const PlayerBagType = preload("res://inventory/player_bag.gd")
const PlayerHotbarType = preload("res://inventory/player_hotbar.gd")
const PlayerFishingUpgradesType = preload(
	"res://progression/player_fishing_upgrades.gd"
)
const PlayerItemEffectsType = preload(
	"res://progression/player_item_effects.gd"
)
const PlayerCoolerCapacityType = preload(
	"res://progression/player_cooler_capacity.gd"
)
const PlayerType = preload("res://player/player.gd")
const FishableWaterRegionType = preload(
	"res://world/fishable_water_region.gd"
)
const NetworkSessionType = preload("res://network/network_session.gd")
const NetworkFishingServiceType = preload(
	"res://network/network_fishing_service.gd"
)
const FishingSurfaceSampleType = preload(
	"res://fishing/fishing_surface_sample.gd"
)
const FishingSurfaceResolverType = preload(
	"res://fishing/fishing_surface_resolver.gd"
)

signal status_changed(status: String)
signal catch_display_changed(
	progress: float,
	chase_progress: float,
	barrier_positions: PackedFloat32Array,
	barrier_health: PackedInt32Array,
	barrier_max_health: PackedInt32Array,
	active_barrier_index: int,
	visible: bool,
)
signal showcase_changed(
	fish_name: String,
	rarity_name: String,
	weight_lb: float,
	visible: bool,
)
signal bite_activated
signal ready_for_equipment_refresh
signal fish_showcase_toggle_requested

enum FishingState {
	READY,
	AIMING_CAST,
	CASTING,
	WAITING_FOR_BITE,
	FIGHTING,
	SHOWING_CATCH,
	RETURNING,
	COOLDOWN,
}

@export_category("Cast")
@export_range(0.1, 30.0, 0.05) var minimum_cast_distance: float = 0.5
@export_range(0.1, 30.0, 0.1) var maximum_cast_distance: float = 14.0
@export_range(0.1, 10.0, 0.1) var cast_charge_duration: float = 2.75
@export_flags_3d_physics var fishable_surface_mask: int = 4
@export_range(0.01, 1.0, 0.01) var fishable_query_radius: float = 0.08

@export_category("Target Preview")
@export_flags_3d_physics var preview_surface_mask: int = 5
@export_range(1.0, 200.0, 1.0) var preview_ray_start_height: float = 100.0
@export_range(1.0, 400.0, 1.0) var preview_surface_ray_length: float = 240.0
@export_range(0.01, 1.0, 0.01) var preview_marker_vertical_offset: float = 0.06
@export_range(0.0, 0.5, 0.01) var water_occlusion_tolerance: float = 0.04
@export_range(0.01, 0.5, 0.01) var solid_bobber_clearance: float = 0.13

@export_category("Withdrawal")
@export_range(0.1, 20.0, 0.1) var withdrawal_rate: float = 4.9
@export_range(0.1, 10.0, 0.1) var withdrawal_cancel_distance: float = 1.0
@export_range(0.0, 1.0, 0.01) var withdrawal_surface_clearance: float = 0.4

@export_category("Timing")
const BITE_QUICK_MIN_SECONDS: float = 10.0
const BITE_QUICK_MAX_SECONDS: float = 30.0
const BITE_TYPICAL_MAX_SECONDS: float = 90.0
const BITE_LONG_MAX_SECONDS: float = 180.0
const BITE_MAX_SECONDS: float = 240.0
const BITE_QUICK_PROBABILITY: float = 0.15
const BITE_TYPICAL_PROBABILITY: float = 0.55
const BITE_LONG_PROBABILITY: float = 0.25
const NETWORK_INPUT_RESEND_INTERVAL_SECONDS: float = 0.1
@export_range(0.1, 10.0, 0.1) var cooldown_duration: float = 1.0

@export_category("Selection")
@export_range(0.0, 10.0, 0.05) var undiscovered_weight_multiplier: float = 1.5
@export var use_deterministic_selection_seed: bool = false
@export var deterministic_selection_seed: int = 24680

@export_category("Context Testing")
@export var context_is_night: bool = false
@export var context_is_raining: bool = false
@export var context_event_tags: Array[StringName] = []
@export var context_bait_tags: Array[StringName] = []

@onready var _catch_controller: CatchControllerType = %CatchController
@onready var _presentation: FishingPresentationType = %FishingPresentation

var state: FishingState = FishingState.READY
var _external_input_blocked: bool = false
var _gameplay_input_enabled: bool = false
var _local_menu_input_owners: Dictionary[StringName, bool] = {}
var _local_player: PlayerType
var _local_inventory: FishInventoryType
var _local_collection_log: CollectionLogType
var _local_bag: PlayerBagType
var _local_hotbar: PlayerHotbarType
var _item_catalog: ItemCatalogType
var _fishing_upgrades: PlayerFishingUpgradesType
var _item_effects: PlayerItemEffectsType
var _network_item_use: NetworkItemUseService
var _cooler_capacity: PlayerCoolerCapacityType
var _network_session: NetworkSessionType
var _network_fishing: NetworkFishingServiceType
var _active_player: PlayerType
var _state_time_remaining: float = 0.0
var _cast_charge: float = 0.0
var _cast_direction: Vector3 = Vector3.FORWARD
var _cast_origin_position: Vector3
var _cast_target: Vector3
var _withdrawal_endpoint: Vector3
var _withdrawal_progress: float = 0.0
var _withdrawal_input_held: bool = false
var _network_primary_input_held: bool = false
var _network_input_resend_elapsed: float = 0.0
var _new_cast_press_armed: bool = true
var _bobber_water_position: Vector3
var _cooldown_status: String = ""
var _fish_selector: FishSelectorType = FishSelectorType.new()
var _surface_resolver: FishingSurfaceResolverType = FishingSurfaceResolverType.new()
var _aim_surface_sample: FishingSurfaceSampleType = FishingSurfaceSampleType.new()
var _cast_path_is_clear: bool = false
var _selected_water_region: FishableWaterRegionType
var _selection_context: FishingContextType
var _selected_fish: FishDataType
var _pending_catch: FishCatchType
var _showcase_ready: bool = false
var _put_away_press_armed: bool = false
var _showcase_restore_generation: int = 0
var _showcase_outcome_completed: bool = false
var _network_auto_click_accumulator: float = 0.0
var _network_active_barrier_index: int = -1
var _bite_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _pending_cleanup_message: String = ""


func _ready() -> void:
	_bite_rng.randomize()
	_configure_surface_resolver()
	_catch_controller.encounter_updated.connect(_on_catch_encounter_updated)
	_catch_controller.caught.connect(_on_catch_completed)
	_catch_controller.escaped.connect(_on_catch_escaped)
	_presentation.cast_completed.connect(_on_cast_completed)
	_presentation.outcome_completed.connect(_on_outcome_completed)
	_presentation.presentation_interrupted.connect(
		_on_presentation_interrupted
	)


func setup(
	local_player: PlayerType,
	local_inventory: FishInventoryType,
	local_collection_log: CollectionLogType,
	local_bag: PlayerBagType,
	local_hotbar: PlayerHotbarType,
	item_catalog: ItemCatalogType,
	fishing_upgrades: PlayerFishingUpgradesType,
	item_effects: PlayerItemEffectsType,
	network_item_use: NetworkItemUseService,
	cooler_capacity: PlayerCoolerCapacityType,
	network_session: NetworkSessionType = null,
	network_fishing: NetworkFishingServiceType = null,
) -> void:
	_local_player = local_player
	_local_inventory = local_inventory
	_local_collection_log = local_collection_log
	_local_bag = local_bag
	_local_hotbar = local_hotbar
	_item_catalog = item_catalog
	_fishing_upgrades = fishing_upgrades
	_item_effects = item_effects
	_network_item_use = network_item_use
	if _network_item_use != null:
		_network_item_use.local_item_use_finished.connect(
			_on_network_item_use_finished
		)
	_cooler_capacity = cooler_capacity
	_network_session = network_session
	_network_fishing = network_fishing
	if _network_fishing != null:
		_network_fishing.local_cast_accepted.connect(
			_on_network_cast_accepted
		)
		_network_fishing.local_cast_rejected.connect(
			_on_network_cast_rejected
		)
		_network_fishing.local_bite_started.connect(
			_on_network_bite_started
		)
		_network_fishing.local_snapshot_received.connect(
			_on_network_fishing_snapshot
		)
		_network_fishing.local_catch_received.connect(
			_on_network_catch_received
		)
		_network_fishing.local_attempt_ended.connect(
			_on_network_attempt_ended
		)
	if not _local_inventory.catches_changed.is_connected(
		_on_cooler_availability_changed
	):
		_local_inventory.catches_changed.connect(
			_on_cooler_availability_changed
		)
	if not _cooler_capacity.capacity_changed.is_connected(
		_on_cooler_capacity_changed
	):
		_cooler_capacity.capacity_changed.connect(_on_cooler_capacity_changed)


func can_open_player_menu() -> bool:
	return (
		_gameplay_input_enabled
		and not _external_input_blocked
		and _local_menu_input_owners.is_empty()
		and state in [
		FishingState.READY,
		FishingState.WAITING_FOR_BITE,
		]
	)


func can_open_system_menu() -> bool:
	return (
		_gameplay_input_enabled
		and not _external_input_blocked
		and _local_menu_input_owners.is_empty()
		and state in [
			FishingState.READY,
			FishingState.WAITING_FOR_BITE,
		]
	)


func can_open_fishing_shop() -> bool:
	return (
		_can_use_shop_gameplay()
		and
		_gameplay_input_enabled
		and not _external_input_blocked
		and _local_menu_input_owners.is_empty()
		and state == FishingState.READY
	)


func is_ready_for_shop_transaction() -> bool:
	return (
		_can_use_shop_gameplay()
		and
		_gameplay_input_enabled
		and not _external_input_blocked
		and state == FishingState.READY
	)


func can_change_hotbar_selection() -> bool:
	return (
		_gameplay_input_enabled
		and not _external_input_blocked
		and _local_menu_input_owners.is_empty()
		and state == FishingState.READY
	)


func handle_escape_action() -> bool:
	if not _gameplay_input_enabled or _external_input_blocked:
		return false
	if state == FishingState.SHOWING_CATCH:
		_put_away_catch()
		return true
	if (
		_active_player != null
		and state in [
			FishingState.AIMING_CAST,
			FishingState.CASTING,
			FishingState.FIGHTING,
		]
	):
		_cancel_attempt()
		return true
	return false


func set_local_menu_input_suppressed(
	owner: StringName,
	suppressed: bool,
) -> void:
	if owner.is_empty():
		return
	if suppressed:
		_local_menu_input_owners[owner] = true
	else:
		_local_menu_input_owners.erase(owner)
	if suppressed and state == FishingState.WAITING_FOR_BITE:
		_withdrawal_input_held = false
		_presentation.set_line_mode(
			FishingPresentationType.LineMode.SLACK
		)


func set_gameplay_input_enabled(enabled: bool) -> void:
	_gameplay_input_enabled = enabled
	if not enabled:
		_local_menu_input_owners.clear()


func configure_accessibility_auto_click(
	enabled: bool,
	interval: float,
) -> void:
	_catch_controller.configure_accessibility(enabled, interval)


func begin_water_recovery() -> void:
	_external_input_blocked = true
	if state in [
		FishingState.AIMING_CAST,
		FishingState.CASTING,
		FishingState.WAITING_FOR_BITE,
		FishingState.FIGHTING,
	]:
		_cancel_attempt()
	elif state == FishingState.SHOWING_CATCH:
		_secure_showcase_catch_for_recovery()


func end_water_recovery() -> void:
	_external_input_blocked = false


func _secure_showcase_catch_for_recovery() -> void:
	if (
		_pending_catch != null
		and _local_inventory != null
		and _local_collection_log != null
	):
		_local_inventory.add_catch(_pending_catch)
		_local_collection_log.mark_discovered(_pending_catch.fish_id)
	_pending_catch = null
	_showcase_ready = false
	_put_away_press_armed = false
	showcase_changed.emit("", "", 0.0, false)
	if _active_player != null:
		_active_player.end_catch_showcase(Callable(), true)
	_cleanup_attempt()


func _exit_tree() -> void:
	_showcase_restore_generation += 1
	if (
		state == FishingState.SHOWING_CATCH
		and _pending_catch != null
		and _local_inventory != null
		and is_instance_valid(_local_inventory)
		and _local_collection_log != null
		and is_instance_valid(_local_collection_log)
	):
		_local_inventory.add_catch(_pending_catch)
		_local_collection_log.mark_discovered(_pending_catch.fish_id)
		_pending_catch = null
	if _active_player != null and is_instance_valid(_active_player):
		_active_player.end_catch_showcase(Callable(), true)
		_active_player.set_movement_enabled(true)
	_active_player = null
	_selected_water_region = null
	_selection_context = null
	_selected_fish = null
	_showcase_ready = false
	_put_away_press_armed = false


func _process(delta: float) -> void:
	if state == FishingState.READY and not Input.is_action_pressed("fish_primary"):
		_new_cast_press_armed = true
	if (
		state == FishingState.SHOWING_CATCH
		and _showcase_ready
		and not Input.is_action_pressed("fish_primary")
	):
		_put_away_press_armed = true

	match state:
		FishingState.AIMING_CAST:
			_update_cast_charge(delta)
			if not Input.is_action_pressed("fish_primary"):
				_confirm_cast()
		FishingState.WAITING_FOR_BITE:
			if _network_fishing == null:
				_update_waiting_for_bite(delta)
			else:
				_resend_network_input_state(delta)
		FishingState.FIGHTING:
			if _network_fishing == null:
				_catch_controller.set_effective_stats(
					_get_effective_reel_speed(),
					_get_effective_barrier_damage()
				)
				if not Input.is_action_pressed("fish_primary"):
					_catch_controller.set_reel_input(false)
			else:
				_resend_network_input_state(delta)
				_update_network_auto_click(delta)
		FishingState.COOLDOWN:
			_state_time_remaining -= delta
			if _state_time_remaining <= 0.0:
				_return_to_ready()


func _unhandled_input(event: InputEvent) -> void:
	if (
		not _gameplay_input_enabled
		or _external_input_blocked
		or not _local_menu_input_owners.is_empty()
	):
		return
	if _local_player == null or not _local_player.is_local_control_enabled():
		return
	if not event.is_action("fish_primary"):
		return
	if event.is_pressed():
		match state:
			FishingState.READY:
				if not _new_cast_press_armed:
					return
				if (
					_local_hotbar != null
					and not _local_hotbar.get_selected_fish_catch_id().is_empty()
				):
					fish_showcase_toggle_requested.emit()
					get_viewport().set_input_as_handled()
					return
				var active_item: ItemDataType = _get_active_item()
				if (
					active_item != null
					and active_item.category == ItemDataType.Category.CONSUMABLE
				):
					if _network_item_use != null:
						_network_item_use.request_use(active_item.item_id)
					elif _item_effects.use_consumable(active_item, _local_bag):
						status_changed.emit(_item_effects.get_feedback(
							active_item.item_id
						))
					get_viewport().set_input_as_handled()
					return
				if not has_active_fishing_rod():
					get_viewport().set_input_as_handled()
					return
				if (
					_is_cooler_full()
				):
					status_changed.emit(
						"cooler full. sell fish before casting again."
					)
					get_viewport().set_input_as_handled()
					return
				_begin_aiming(_local_player)
			FishingState.FIGHTING:
				if _network_fishing != null:
					_network_primary_input_held = true
					_network_input_resend_elapsed = 0.0
					_network_fishing.submit_local_input(true, true)
				else:
					_catch_controller.handle_primary_pressed()
				_presentation.set_line_mode(
					FishingPresentationType.LineMode.TAUT
				)
			FishingState.SHOWING_CATCH:
				if _showcase_ready and _put_away_press_armed:
					_put_away_catch()
				else:
					return
			FishingState.WAITING_FOR_BITE:
				_withdrawal_input_held = true
				if _network_fishing != null:
					_network_primary_input_held = true
					_network_input_resend_elapsed = 0.0
					_network_fishing.submit_local_input(true, true)
				_presentation.set_line_mode(
					FishingPresentationType.LineMode.TAUT
				)
			_:
				return
		get_viewport().set_input_as_handled()
	elif state == FishingState.AIMING_CAST:
		_confirm_cast()
		get_viewport().set_input_as_handled()
	elif state == FishingState.WAITING_FOR_BITE:
		_withdrawal_input_held = false
		if _network_fishing != null:
			_network_primary_input_held = false
			_network_input_resend_elapsed = 0.0
			_network_fishing.submit_local_input(false, false)
		_presentation.set_line_mode(FishingPresentationType.LineMode.SLACK)
		get_viewport().set_input_as_handled()
	elif state == FishingState.FIGHTING:
		if _network_fishing != null:
			_network_primary_input_held = false
			_network_input_resend_elapsed = 0.0
			_network_fishing.submit_local_input(false, false)
		else:
			_catch_controller.set_reel_input(false)
		get_viewport().set_input_as_handled()


func _begin_aiming(player: PlayerType) -> void:
	if state != FishingState.READY or _active_player != null:
		return

	_active_player = player
	_cast_direction = _capture_cast_direction(_active_player)
	_cast_origin_position = _active_player.get_cast_origin_position()
	_cast_charge = 0.0
	_cast_target = _calculate_cast_target(minimum_cast_distance)
	state = FishingState.AIMING_CAST
	status_changed.emit("")
	_cast_path_is_clear = is_cast_path_clear(_cast_origin_position, _cast_target)
	var target_is_fishable: bool = (
		_aim_surface_sample.is_fishable() and _cast_path_is_clear
	)
	var preview_position: Vector3 = _aim_surface_sample.get_marker_position(
		preview_marker_vertical_offset
	)
	_presentation.begin_aim(
		_active_player.get_fishing_rod_tip(),
		_active_player.get_fishing_rod(),
		preview_position,
		_aim_surface_sample.normal,
		target_is_fishable
	)


func _can_use_shared_gameplay() -> bool:
	return _network_session == null or _network_session.can_use_host_gameplay()


func _can_use_shop_gameplay() -> bool:
	return (
		_network_session == null
		or _network_session.is_host()
		or (
			_network_session.is_joined_client()
			and _network_session.supports_server_capability(&"shop_v1")
		)
	)


func has_active_fishing_rod() -> bool:
	if (
		_local_bag == null
		or _local_hotbar == null
		or _item_catalog == null
	):
		return false
	var item: ItemDataType = _get_active_item()
	return (
		item != null
		and item.is_valid()
		and item.category == ItemDataType.Category.ROD
		and item.usable
		and item.equippable
	)


func _get_active_item() -> ItemDataType:
	if (
		_local_bag == null
		or _local_hotbar == null
		or _item_catalog == null
	):
		return null
	var item_id: StringName = _local_hotbar.get_selected_item_id()
	if item_id.is_empty() or not _local_bag.owns_item(item_id):
		return null
	var item: ItemDataType = _item_catalog.get_item_by_id(item_id)
	return item if item != null and item.is_valid() else null


func _is_cooler_full() -> bool:
	return (
		_cooler_capacity != null
		and _local_inventory != null
		and _local_inventory.get_all_catches().size()
		>= _cooler_capacity.get_capacity()
	)


func _on_cooler_availability_changed() -> void:
	if state == FishingState.READY and not _is_cooler_full():
		refresh_active_item_status()


func _on_cooler_capacity_changed(_level: int, _capacity: int) -> void:
	_on_cooler_availability_changed()


func is_fighting() -> bool:
	return state == FishingState.FIGHTING


func is_returning() -> bool:
	return state == FishingState.RETURNING


func refresh_active_item_status() -> void:
	if state == FishingState.READY and has_active_fishing_rod():
		status_changed.emit("")


func _update_cast_charge(delta: float) -> void:
	if state != FishingState.AIMING_CAST:
		return

	# Movement remains available during aiming. Re-sample the player transform
	# so the cast origin and facing follow the player until release.
	_cast_origin_position = _active_player.get_cast_origin_position()
	_cast_direction = _capture_cast_direction(_active_player)
	_cast_charge = minf(_cast_charge + delta / cast_charge_duration, 1.0)
	var maximum_distance: float = maxf(minimum_cast_distance, maximum_cast_distance)
	var distance: float = lerpf(minimum_cast_distance, maximum_distance, _cast_charge)
	_cast_target = _calculate_cast_target(distance)
	_cast_path_is_clear = is_cast_path_clear(_cast_origin_position, _cast_target)
	var target_is_fishable: bool = (
		_aim_surface_sample.is_fishable() and _cast_path_is_clear
	)
	var preview_position: Vector3 = _aim_surface_sample.get_marker_position(
		preview_marker_vertical_offset
	)
	_presentation.update_aim_target(
		preview_position,
		_aim_surface_sample.normal,
		_cast_charge,
		target_is_fishable
	)
	_presentation.update_rod_charge(_cast_charge)


func _confirm_cast() -> void:
	if state != FishingState.AIMING_CAST:
		return

	_cast_path_is_clear = is_cast_path_clear(
		_cast_origin_position,
		_cast_target,
	)
	var cast_is_invalid: bool = (
		not _aim_surface_sample.is_fishable() or not _cast_path_is_clear
	)
	var arrival_position: Vector3 = _cast_target
	if not _cast_path_is_clear:
		arrival_position = _resolve_cast_impact_position(
			_cast_origin_position,
			_cast_target,
		)
	if _active_player != null:
		# Movement is available while aiming, then locks once the cast is
		# released so the active bobber/fishing event remains anchored.
		_active_player.set_movement_enabled(false)
	state = FishingState.CASTING
	status_changed.emit("")
	_presentation.begin_cast(
		_cast_target,
		arrival_position,
		cast_is_invalid,
	)
	_presentation.set_line_mode(FishingPresentationType.LineMode.TAUT)


func _on_cast_completed() -> void:
	if state != FishingState.CASTING:
		return
	if not _is_cast_target_valid(_cast_target):
		_cleanup_attempt("", &"invalid")
		return
	if _network_fishing != null:
		_network_fishing.request_local_cast(
			_cast_origin_position,
			_cast_target,
			_cast_charge,
			_build_network_evidence()
		)
		status_changed.emit("")
		return

	_selected_water_region = get_fishable_water_region(_cast_target)
	_selection_context = _build_fishing_context(_selected_water_region)
	_fish_selector.undiscovered_weight_multiplier = undiscovered_weight_multiplier
	_fish_selector.rarity_weight_multipliers = []
	for rarity: int in range(FishDataType.Rarity.size()):
		_fish_selector.rarity_weight_multipliers.append(
			_item_effects.get_rarity_weight_multiplier(rarity)
			if _item_effects != null
			else 1.0
		)
	_fish_selector.use_deterministic_test_seed = use_deterministic_selection_seed
	_fish_selector.deterministic_test_seed = deterministic_selection_seed
	_fish_selector.begin_roll()
	_selected_fish = _fish_selector.select_fish(
		_selected_water_region.fish_pool,
		_selection_context,
		_local_collection_log
	)
	if _selected_fish == null:
		_cleanup_attempt("nothing is biting here.", &"invalid")
		return

	state = FishingState.WAITING_FOR_BITE
	_state_time_remaining = roll_bite_wait_time() * (
		_item_effects.get_bite_time_multiplier()
		if _item_effects != null
		else 1.0
	)
	_withdrawal_progress = 0.0
	_withdrawal_input_held = false
	_network_auto_click_accumulator = 0.0
	_network_active_barrier_index = -1
	_bobber_water_position = _cast_target
	_withdrawal_endpoint = Vector3(
		_cast_origin_position.x + _cast_direction.x * withdrawal_cancel_distance,
		_cast_target.y,
		_cast_origin_position.z + _cast_direction.z * withdrawal_cancel_distance
	)
	_presentation.set_line_mode(FishingPresentationType.LineMode.SLACK)
	status_changed.emit("waiting for a bite...")


func roll_bite_wait_time() -> float:
	var bucket: float = _bite_rng.randf()
	if bucket < BITE_QUICK_PROBABILITY:
		return _bite_rng.randf_range(
			BITE_QUICK_MIN_SECONDS,
			BITE_QUICK_MAX_SECONDS,
		)
	if bucket < BITE_QUICK_PROBABILITY + BITE_TYPICAL_PROBABILITY:
		return _bite_rng.randf_range(
			BITE_QUICK_MAX_SECONDS,
			BITE_TYPICAL_MAX_SECONDS,
		)
	if bucket < (
		BITE_QUICK_PROBABILITY
		+ BITE_TYPICAL_PROBABILITY
		+ BITE_LONG_PROBABILITY
	):
		return _bite_rng.randf_range(
			BITE_TYPICAL_MAX_SECONDS,
			BITE_LONG_MAX_SECONDS,
		)
	return _bite_rng.randf_range(
		BITE_LONG_MAX_SECONDS,
		BITE_MAX_SECONDS,
	)


func _update_waiting_for_bite(delta: float) -> void:
	if (
		_withdrawal_input_held
		and not Input.is_action_pressed("fish_primary")
	):
		_withdrawal_input_held = false
		_presentation.set_line_mode(FishingPresentationType.LineMode.SLACK)

	if not _withdrawal_input_held:
		_state_time_remaining -= delta
		if _state_time_remaining <= 0.0:
			_activate_bite()
		return

	var completion_time: float = _get_withdrawal_completion_time(delta)
	if _state_time_remaining <= delta and _state_time_remaining <= completion_time:
		_update_withdrawal(maxf(_state_time_remaining, 0.0))
		if state == FishingState.WAITING_FOR_BITE:
			_activate_bite()
		return

	_update_withdrawal(delta)
	if state != FishingState.WAITING_FOR_BITE:
		return
	_state_time_remaining -= delta
	if _state_time_remaining <= 0.0:
		_activate_bite()


func _update_withdrawal(delta: float) -> void:
	if state != FishingState.WAITING_FOR_BITE:
		return

	var withdrawable_distance: float = _get_withdrawable_distance()
	if withdrawable_distance <= 0.0:
		_cancel_from_withdrawal()
		return

	var next_progress: float = minf(
		_withdrawal_progress + withdrawal_rate * delta / withdrawable_distance,
		1.0
	)
	var desired_position: Vector3 = _cast_target.lerp(
		_withdrawal_endpoint,
		next_progress
	)
	var withdrawal_surface: FishingSurfaceSampleType = (
		resolve_safe_withdrawal_surface(
			_bobber_water_position,
			desired_position,
		)
	)
	if not withdrawal_surface.is_fishable():
		_resolve_withdrawal_at_shore()
		return
	_withdrawal_progress = next_progress
	_bobber_water_position = withdrawal_surface.position
	_presentation.show_withdrawal_position(_bobber_water_position)
	if is_equal_approx(_withdrawal_progress, 1.0):
		_cancel_from_withdrawal()


func _get_withdrawal_completion_time(delta: float) -> float:
	var withdrawable_distance: float = _get_withdrawable_distance()
	if withdrawable_distance <= 0.0:
		return 0.0

	var progress_step: float = withdrawal_rate * delta / withdrawable_distance
	if progress_step <= 0.0:
		return INF
	var next_progress: float = minf(_withdrawal_progress + progress_step, 1.0)
	var desired_position: Vector3 = _cast_target.lerp(
		_withdrawal_endpoint,
		next_progress
	)
	var withdrawal_surface: FishingSurfaceSampleType = (
		resolve_safe_withdrawal_surface(
			_bobber_water_position,
			desired_position,
		)
	)
	if not withdrawal_surface.is_fishable():
		return 0.0
	if is_equal_approx(next_progress, 1.0):
		return delta * (1.0 - _withdrawal_progress) / progress_step
	return INF


func _get_withdrawable_distance() -> float:
	var landing_offset: Vector3 = _cast_target - _cast_origin_position
	landing_offset.y = 0.0
	return landing_offset.length() - withdrawal_cancel_distance


func _activate_bite() -> void:
	if state != FishingState.WAITING_FOR_BITE:
		return

	if (
		_active_player == null
		or _selected_fish == null
		or _selected_fish.catch_profile == null
	):
		_cancel_attempt()
		return

	state = FishingState.FIGHTING
	_state_time_remaining = 0.0
	_withdrawal_input_held = false
	bite_activated.emit()
	status_changed.emit("fish on!")
	_presentation.set_line_mode(FishingPresentationType.LineMode.TAUT)
	_presentation.begin_fight()
	_catch_controller.start_encounter(
		_selected_fish.catch_profile,
		_get_effective_reel_speed(),
		_get_effective_barrier_damage()
	)
	_catch_controller.set_reel_input(
		Input.is_action_pressed("fish_primary")
	)
	_presentation.show_bite()


func _get_effective_reel_speed() -> float:
	if _active_player == null:
		return 0.0
	return _active_player.reel_speed * (
		_fishing_upgrades.get_reel_speed_multiplier()
		if _fishing_upgrades != null
		else 1.0
	) * (
		_item_effects.get_reel_multiplier()
		if _item_effects != null
		else 1.0
	)


func _get_effective_barrier_damage() -> int:
	if _active_player == null:
		return 1
	return (
		_fishing_upgrades.get_barrier_damage()
		if _fishing_upgrades != null
		else _active_player.click_power
	) + (
		_item_effects.get_barrier_bonus()
		if _item_effects != null
		else 0
	)


func _on_catch_encounter_updated(
	progress: float,
	chase_progress: float,
	barrier_positions: PackedFloat32Array,
	barrier_health: PackedInt32Array,
	barrier_max_health: PackedInt32Array,
	active_barrier_index: int,
	visible: bool,
) -> void:
	catch_display_changed.emit(
		progress,
		chase_progress,
		barrier_positions,
		barrier_health,
		barrier_max_health,
		active_barrier_index,
		visible
	)
	if state != FishingState.FIGHTING or not visible:
		return


func _on_catch_completed() -> void:
	if (
		state != FishingState.FIGHTING
		or _active_player == null
		or _selected_fish == null
	):
		_cancel_attempt()
		return

	_pending_catch = _fish_selector.create_catch(_selected_fish)
	if _pending_catch == null or not _pending_catch.is_valid():
		_cancel_attempt()
		return
	state = FishingState.SHOWING_CATCH
	_showcase_ready = false
	_showcase_outcome_completed = false
	_put_away_press_armed = false
	_catch_controller.reset()
	_presentation.set_line_mode(FishingPresentationType.LineMode.TAUT)
	_presentation.play_outcome(&"catch")


func _on_catch_escaped() -> void:
	if state != FishingState.FIGHTING:
		return

	var fish_name: String = "the fish"
	if _selected_fish != null and not _selected_fish.display_name.is_empty():
		fish_name = "the %s" % _selected_fish.display_name
	_cleanup_attempt("%s got away!" % fish_name, &"escape")


func _on_outcome_completed(outcome: StringName) -> void:
	if state == FishingState.RETURNING:
		var cleanup_message: String = _pending_cleanup_message
		_pending_cleanup_message = ""
		_finalize_attempt_cleanup(cleanup_message)
		return
	if (
		outcome != &"catch"
		or state != FishingState.SHOWING_CATCH
		or _active_player == null
		or _pending_catch == null
		or _showcase_outcome_completed
	):
		return
	_showcase_outcome_completed = true
	_showcase_ready = true
	_active_player.begin_catch_showcase(_pending_catch)
	showcase_changed.emit(
		_pending_catch.fish.display_name,
		_pending_catch.fish.get_rarity_name(),
		_pending_catch.weight_lb,
		true
	)


func _on_presentation_interrupted() -> void:
	if state in [FishingState.READY, FishingState.COOLDOWN]:
		return
	if _network_fishing != null and _network_fishing.has_local_attempt():
		_network_fishing.cancel_local_attempt("")
		return
	_finalize_attempt_cleanup("")


func _put_away_catch() -> void:
	if (
		state != FishingState.SHOWING_CATCH
		or _active_player == null
		or _local_inventory == null
		or _local_collection_log == null
		or _pending_catch == null
	):
		return
	_local_inventory.add_catch(_pending_catch)
	_local_collection_log.mark_discovered(_pending_catch.fish_id)
	_pending_catch = null
	_showcase_ready = false
	_showcase_outcome_completed = false
	_put_away_press_armed = false
	showcase_changed.emit("", "", 0.0, false)
	_showcase_restore_generation += 1
	var restore_generation: int = _showcase_restore_generation
	_active_player.end_catch_showcase(
		_finish_showcase_put_away.bind(
			restore_generation,
			""
		)
	)


func _finish_showcase_put_away(
	restore_generation: int,
	cooldown_message: String,
) -> void:
	if (
		restore_generation != _showcase_restore_generation
		or state != FishingState.SHOWING_CATCH
		or _active_player == null
	):
		return
	_cleanup_attempt(cooldown_message)


func _cleanup_attempt(
	cooldown_message: String = "",
	visual_outcome: StringName = &"",
) -> void:
	if not visual_outcome.is_empty():
		if state == FishingState.RETURNING:
			return
		_showcase_restore_generation += 1
		_pending_cleanup_message = cooldown_message
		_showcase_ready = false
		_showcase_outcome_completed = false
		_put_away_press_armed = false
		showcase_changed.emit("", "", 0.0, false)
		_catch_controller.reset()
		state = FishingState.RETURNING
		status_changed.emit("")
		if visual_outcome in [&"invalid", &"withdrawal", &"escape"]:
			_presentation.set_line_mode(
				FishingPresentationType.LineMode.TAUT
			)
		else:
			_presentation.set_line_mode(
				FishingPresentationType.LineMode.HIDDEN
			)
		_presentation.play_outcome(visual_outcome)
		return
	_finalize_attempt_cleanup(cooldown_message)


func _finalize_attempt_cleanup(cooldown_message: String) -> void:
	_showcase_restore_generation += 1
	if _active_player != null:
		_active_player.end_catch_showcase()
		_active_player.set_movement_enabled(true)
	_active_player = null
	_state_time_remaining = 0.0
	_cast_charge = 0.0
	_cast_direction = Vector3.FORWARD
	_cast_origin_position = Vector3.ZERO
	_cast_target = Vector3.ZERO
	_aim_surface_sample = FishingSurfaceSampleType.new()
	_cast_path_is_clear = false
	_withdrawal_endpoint = Vector3.ZERO
	_withdrawal_progress = 0.0
	_withdrawal_input_held = false
	_network_primary_input_held = false
	_network_input_resend_elapsed = 0.0
	_bobber_water_position = Vector3.ZERO
	_selected_water_region = null
	_selection_context = null
	_selected_fish = null
	_pending_catch = null
	_showcase_ready = false
	_showcase_outcome_completed = false
	_put_away_press_armed = false
	showcase_changed.emit("", "", 0.0, false)
	_catch_controller.reset()
	_presentation.cleanup()
	_pending_cleanup_message = ""

	if cooldown_message.is_empty():
		state = FishingState.READY
		_cooldown_status = ""
		status_changed.emit("")
		ready_for_equipment_refresh.emit()
	else:
		state = FishingState.COOLDOWN
		_state_time_remaining = cooldown_duration
		_cooldown_status = cooldown_message
		status_changed.emit(_cooldown_status)


func _return_to_ready() -> void:
	state = FishingState.READY
	_state_time_remaining = 0.0
	_cooldown_status = ""
	status_changed.emit("")
	ready_for_equipment_refresh.emit()


func _cancel_attempt() -> void:
	if _network_fishing != null and _network_fishing.has_local_attempt():
		_network_fishing.cancel_local_attempt("")
		return
	_cleanup_attempt("", &"cancel")


func _cancel_from_withdrawal() -> void:
	if state != FishingState.WAITING_FOR_BITE:
		return
	_new_cast_press_armed = false
	if _network_fishing != null and _network_fishing.has_local_attempt():
		_network_fishing.cancel_local_attempt("")
		return
	_cleanup_attempt("", &"withdrawal")


func _resolve_withdrawal_at_shore() -> void:
	if state != FishingState.WAITING_FOR_BITE:
		return
	_cancel_from_withdrawal()


func _capture_cast_direction(player: PlayerType) -> Vector3:
	var direction: Vector3 = player.get_facing_direction()
	direction.y = 0.0
	if direction.is_zero_approx():
		direction = -player.global_basis.z
		direction.y = 0.0
	if direction.is_zero_approx():
		return Vector3.FORWARD
	return direction.normalized()


func _calculate_cast_target(distance: float) -> Vector3:
	var query_position := Vector3(
		_cast_origin_position.x + _cast_direction.x * distance,
		_cast_origin_position.y,
		_cast_origin_position.z + _cast_direction.z * distance
	)
	_aim_surface_sample = resolve_fishing_surface(
		query_position,
		_cast_origin_position.y,
	)
	if _aim_surface_sample.has_surface:
		return _aim_surface_sample.get_bobber_position(solid_bobber_clearance)
	return query_position


func _configure_surface_resolver() -> void:
	_surface_resolver.fishable_surface_mask = fishable_surface_mask
	_surface_resolver.solid_surface_mask = (
		preview_surface_mask & ~fishable_surface_mask
	)
	_surface_resolver.query_radius = fishable_query_radius
	_surface_resolver.ray_start_height = preview_ray_start_height
	_surface_resolver.ray_length = preview_surface_ray_length
	_surface_resolver.water_occlusion_tolerance = water_occlusion_tolerance


func resolve_fishing_surface(
	target: Vector3,
	reference_y: float = NAN,
) -> FishingSurfaceSampleType:
	if not is_inside_tree():
		var empty_sample := FishingSurfaceSampleType.new()
		empty_sample.position = target
		return empty_sample
	var resolved_reference_y: float = reference_y
	if is_nan(resolved_reference_y):
		resolved_reference_y = (
			_active_player.global_position.y
			if _active_player != null
			else target.y
		)
	return _surface_resolver.resolve_surface(
		get_world_3d().direct_space_state,
		target,
		resolved_reference_y,
	)


func is_target_fishable(target: Vector3) -> bool:
	return resolve_fishing_surface(target).is_fishable()


func _is_cast_target_valid(target: Vector3) -> bool:
	return (
		is_target_fishable(target)
		and is_cast_path_clear(_cast_origin_position, target)
	)


func is_cast_path_clear(origin: Vector3, target: Vector3) -> bool:
	return _surface_resolver.find_first_cast_collision(
		get_world_3d().direct_space_state,
		origin,
		target,
		_presentation.cast_arc_height,
	).is_empty()


func _resolve_cast_impact_position(origin: Vector3, target: Vector3) -> Vector3:
	var result: Dictionary = _surface_resolver.find_first_cast_collision(
		get_world_3d().direct_space_state,
		origin,
		target,
		_presentation.cast_arc_height,
	)
	if result.is_empty():
		return target
	var hit_position: Vector3 = result["position"]
	var hit_normal: Vector3 = result.get("normal", Vector3.UP)
	if hit_normal.is_zero_approx():
		hit_normal = Vector3.UP
	return hit_position + hit_normal.normalized() * 0.12


func get_fishable_water_region(
	target: Vector3,
) -> FishableWaterRegionType:
	var reference_y: float = (
		_active_player.global_position.y
		if _active_player != null
		else target.y
	)
	var surface: FishingSurfaceSampleType = resolve_fishing_surface(
		target,
		reference_y,
	)
	return surface.water_region if surface.is_fishable() else null


func _build_fishing_context(
	region: FishableWaterRegionType,
) -> FishingContextType:
	var context := FishingContextType.new()
	context.location_tags = region.location_tags.duplicate()
	context.water_type = region.water_type
	context.active_event_tags = context_event_tags.duplicate()
	context.active_bait_tags = context_bait_tags.duplicate()
	context.is_night = context_is_night
	context.is_raining = context_is_raining
	return context


func build_network_context(
	region: FishableWaterRegionType,
) -> FishingContextType:
	return _build_fishing_context(region)


func _build_network_evidence() -> Dictionary:
	var rarity_multipliers: Array[float] = []
	for rarity: int in range(FishDataType.Rarity.size()):
		rarity_multipliers.append(1.0)
	var discovered_ids: Array[String] = []
	if _local_collection_log != null:
		for fish_id: StringName in _local_collection_log.get_discovered_ids():
			discovered_ids.append(str(fish_id))
	var item: ItemDataType = _get_active_item()
	return {
		"rod_id": str(item.item_id) if item != null else "",
		"reel_speed": _active_player.reel_speed * (
			_fishing_upgrades.get_reel_speed_multiplier()
			if _fishing_upgrades != null else 1.0
		),
		"barrier_damage": (
			_fishing_upgrades.get_barrier_damage()
			if _fishing_upgrades != null else _active_player.click_power
		),
		"bite_multiplier": 1.0,
		"rarity_multipliers": rarity_multipliers,
		"discovered_fish_ids": discovered_ids,
		"capacity_available": not _is_cooler_full(),
	}


func _on_network_item_use_finished(
	accepted: bool,
	message: String,
) -> void:
	status_changed.emit(message)
	if accepted:
		refresh_active_item_status()


func _on_network_cast_accepted(
	_attempt_id: String,
	target: Vector3,
) -> void:
	if state != FishingState.CASTING:
		return
	_cast_target = target
	_bobber_water_position = target
	state = FishingState.WAITING_FOR_BITE
	_network_primary_input_held = false
	_network_input_resend_elapsed = 0.0
	_presentation.show_withdrawal_position(_bobber_water_position)
	_presentation.set_line_mode(FishingPresentationType.LineMode.SLACK)
	status_changed.emit("waiting for a bite...")


func _on_network_cast_rejected(message: String) -> void:
	if state not in [FishingState.CASTING, FishingState.AIMING_CAST]:
		return
	var visible_message: String = message
	if message.strip_edges().to_lower() in [
		"cannot fish here.",
		"cannot fish here",
		"can't fish here.",
		"can't fish here",
		"can't fish there.",
		"can't fish there",
	]:
		visible_message = ""
	_cleanup_attempt(visible_message, &"invalid")


func _on_network_bite_started(_attempt_id: String) -> void:
	if state != FishingState.WAITING_FOR_BITE:
		return
	state = FishingState.FIGHTING
	_withdrawal_input_held = false
	_network_primary_input_held = Input.is_action_pressed("fish_primary")
	_network_input_resend_elapsed = 0.0
	_network_auto_click_accumulator = 0.0
	_network_active_barrier_index = -1
	bite_activated.emit()
	status_changed.emit("fish on!")
	_presentation.set_line_mode(FishingPresentationType.LineMode.TAUT)
	_presentation.begin_fight()
	_presentation.show_bite()
	_network_fishing.submit_local_input(
		_network_primary_input_held,
		false
	)


func _resend_network_input_state(delta: float) -> void:
	if _network_fishing == null or not _network_fishing.has_local_attempt():
		return
	_network_input_resend_elapsed += delta
	if _network_input_resend_elapsed < NETWORK_INPUT_RESEND_INTERVAL_SECONDS:
		return
	_network_input_resend_elapsed = fmod(
		_network_input_resend_elapsed,
		NETWORK_INPUT_RESEND_INTERVAL_SECONDS,
	)
	_network_fishing.submit_local_input(_network_primary_input_held, false)


func _on_network_fishing_snapshot(snapshot: Dictionary) -> void:
	if state not in [
		FishingState.WAITING_FOR_BITE,
		FishingState.FIGHTING,
	]:
		return
	var positions := PackedFloat32Array(snapshot.get("barrier_positions", []))
	var health := PackedInt32Array(snapshot.get("barrier_health", []))
	var maximum_health := PackedInt32Array(
		snapshot.get("barrier_max_health", [])
	)
	var progress: float = float(snapshot.get("progress", 0.0))
	var chase_progress: float = float(snapshot.get("chase_progress", 0.0))
	if state == FishingState.FIGHTING:
		_network_active_barrier_index = int(
			snapshot.get("active_barrier_index", -1)
		)
		catch_display_changed.emit(
			progress,
			chase_progress,
			positions,
			health,
			maximum_health,
			int(snapshot.get("active_barrier_index", -1)),
			bool(snapshot.get("visible", false))
		)
	var bobber_data: Array = snapshot.get("bobber_position", [])
	if bobber_data.size() == 3:
		_bobber_water_position = Vector3(
			float(bobber_data[0]),
			float(bobber_data[1]),
			float(bobber_data[2])
		)
		if state == FishingState.WAITING_FOR_BITE:
			_presentation.show_withdrawal_position(_bobber_water_position)


func _update_network_auto_click(delta: float) -> void:
	if (
		not _catch_controller.auto_click_enabled
		or not Input.is_action_pressed("fish_primary")
		or _network_active_barrier_index < 0
	):
		_network_auto_click_accumulator = 0.0
		return
	_network_auto_click_accumulator += delta
	var interval: float = maxf(
		_catch_controller.auto_click_interval,
		0.05
	)
	while _network_auto_click_accumulator >= interval:
		_network_auto_click_accumulator -= interval
		_network_fishing.submit_local_input(true, true)


func _on_network_catch_received(fish_catch: FishCatchType) -> void:
	if state != FishingState.FIGHTING or fish_catch == null:
		return
	_pending_catch = fish_catch
	state = FishingState.SHOWING_CATCH
	_showcase_ready = false
	_showcase_outcome_completed = false
	_put_away_press_armed = false
	catch_display_changed.emit(
		0.0, 0.0, PackedFloat32Array(), PackedInt32Array(),
		PackedInt32Array(), -1, false
	)
	_presentation.set_line_mode(FishingPresentationType.LineMode.TAUT)
	_presentation.play_outcome(&"catch")


func _on_network_attempt_ended(
	outcome: StringName,
	message: String,
) -> void:
	if state not in [
		FishingState.CASTING,
		FishingState.WAITING_FOR_BITE,
		FishingState.FIGHTING,
	]:
		return
	var visual_outcome: StringName = &"cancel"
	if outcome == &"escape":
		visual_outcome = &"escape"
	elif outcome == &"withdrawal":
		visual_outcome = &"withdrawal"
	_cleanup_attempt(message, visual_outcome)


func resolve_safe_withdrawal_surface(
	from: Vector3,
	to: Vector3,
	toward_player: Vector3 = Vector3.ZERO,
) -> FishingSurfaceSampleType:
	var direction_to_player: Vector3 = toward_player
	if direction_to_player.is_zero_approx():
		direction_to_player = to - from
	var reference_y: float = (
		_active_player.global_position.y
		if _active_player != null
		else maxf(from.y, to.y)
	)
	return _surface_resolver.resolve_withdrawal_surface(
		get_world_3d().direct_space_state,
		from,
		to,
		direction_to_player,
		reference_y,
		withdrawal_surface_clearance,
	)
