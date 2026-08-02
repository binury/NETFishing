extends SceneTree

const WorldTimeServiceType = preload("res://world/world_time_service.gd")
const WorldTimeVisualControllerType = preload(
	"res://world/world_time_visual_controller.gd"
)
const NetworkWorldTimeServiceType = preload(
	"res://network/network_world_time_service.gd"
)
const FishingContextType = preload("res://fishing/fishing_context.gd")
const FishDataType = preload("res://fish/fish_data.gd")
const FishPoolType = preload("res://fish/fish_pool.gd")
const FishingSpotType = preload("res://fishing/fishing_spot.gd")
const FishableWaterRegionType = preload(
	"res://world/fishable_water_region.gd"
)

const Catalog: FishPoolType = preload("res://fish/pools/fish_catalog.tres")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_validate_clock_boundaries_and_duration()
	_validate_fishing_availability()
	_validate_fishing_spot_context()
	_validate_network_snapshot_bounds()
	_validate_environment_presentation()
	print("World time validation: PASS")
	quit()


func _validate_clock_boundaries_and_duration() -> void:
	assert(WorldTimeServiceType.REAL_SECONDS_PER_CYCLE == 3600.0)
	assert(
		WorldTimeServiceType.phase_for_hour(7.49)
		== WorldTimeServiceType.Phase.NIGHT
	)
	assert(
		WorldTimeServiceType.phase_for_hour(7.5)
		== WorldTimeServiceType.Phase.DAWN
	)
	assert(
		WorldTimeServiceType.phase_for_hour(8.49)
		== WorldTimeServiceType.Phase.DAWN
	)
	assert(
		WorldTimeServiceType.phase_for_hour(8.5)
		== WorldTimeServiceType.Phase.DAY
	)
	assert(
		WorldTimeServiceType.phase_for_hour(19.5)
		== WorldTimeServiceType.Phase.DUSK
	)
	assert(
		WorldTimeServiceType.phase_for_hour(20.5)
		== WorldTimeServiceType.Phase.NIGHT
	)
	assert(WorldTimeServiceType.format_clock_time(0.0) == "12:00 am")
	assert(WorldTimeServiceType.format_clock_time(8.0) == "8:00 am")
	assert(WorldTimeServiceType.format_clock_time(20.5) == "8:30 pm")

	var clock := WorldTimeServiceType.new()
	root.add_child(clock)
	clock.begin_session(8.0)
	clock.advance_time(1800.0)
	assert(is_equal_approx(clock.get_time_hours(), 20.0))
	assert(clock.is_night_period())
	assert(clock.is_transition())
	clock.advance_time(1800.0)
	assert(is_equal_approx(clock.get_time_hours(), 8.0))
	assert(not clock.is_night_period())
	assert(clock.is_transition())
	clock.queue_free()


func _validate_fishing_availability() -> void:
	var day_context := FishingContextType.new()
	day_context.location_tags = [&"starter_pond"]
	day_context.is_night = false
	var night_context := FishingContextType.new()
	night_context.location_tags = [&"starter_pond"]
	night_context.is_night = true
	var transition_context := FishingContextType.new()
	transition_context.location_tags = [&"starter_pond"]
	transition_context.is_night = true
	transition_context.is_day_night_transition = true

	for fish_id: StringName in [&"bluegill", &"sunfish"]:
		var day_fish: FishDataType = Catalog.get_fish_by_id(fish_id)
		assert(day_fish.availability.is_available(day_context))
		assert(not day_fish.availability.is_available(night_context))
		assert(day_fish.availability.is_available(transition_context))
	for fish_id: StringName in [
		&"catfish_blue",
		&"catfish_channel",
		&"catfish_flathead",
		&"catfish_white",
	]:
		var night_fish: FishDataType = Catalog.get_fish_by_id(fish_id)
		assert(not night_fish.availability.is_available(day_context))
		assert(night_fish.availability.is_available(night_context))
		assert(night_fish.availability.is_available(transition_context))
	for fish_id: StringName in [&"bass", &"carp"]:
		var all_time_fish: FishDataType = Catalog.get_fish_by_id(fish_id)
		assert(all_time_fish.availability.is_available(day_context))
		assert(all_time_fish.availability.is_available(night_context))
		assert(all_time_fish.availability.is_available(transition_context))


func _validate_fishing_spot_context() -> void:
	var clock := WorldTimeServiceType.new()
	clock.begin_session(20.25)
	var fishing_spot := FishingSpotType.new()
	fishing_spot.set("_world_time", clock)
	var region := FishableWaterRegionType.new()
	region.location_tags = [&"starter_pond"]
	region.water_type = WaterType.Type.FRESH_WATER
	var dusk_context: FishingContext = fishing_spot.build_network_context(region)
	assert(dusk_context.is_night)
	assert(dusk_context.is_day_night_transition)
	clock.synchronize_time(14.0)
	var day_context: FishingContext = fishing_spot.build_network_context(region)
	assert(not day_context.is_night)
	assert(not day_context.is_day_night_transition)
	region.free()
	fishing_spot.free()
	clock.free()


func _validate_network_snapshot_bounds() -> void:
	assert(NetworkWorldTimeServiceType.validate_snapshot({
		"session_id": "session",
		"time_hours": 8.25,
		"sequence": 1,
	}))
	assert(not NetworkWorldTimeServiceType.validate_snapshot({
		"session_id": "session",
		"time_hours": 24.0,
		"sequence": 1,
	}))
	assert(not NetworkWorldTimeServiceType.validate_snapshot({
		"session_id": "",
		"time_hours": 8.0,
		"sequence": 1,
	}))


func _validate_environment_presentation() -> void:
	var world_root := Node3D.new()
	root.add_child(world_root)
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	environment.sky = sky
	environment.adjustment_enabled = true
	environment.fog_enabled = true
	world_environment.environment = environment
	world_root.add_child(world_environment)
	var sun := DirectionalLight3D.new()
	world_root.add_child(sun)
	var clock := WorldTimeServiceType.new()
	world_root.add_child(clock)
	var visuals := WorldTimeVisualControllerType.new()
	world_root.add_child(visuals)
	visuals.setup(clock, world_environment, sun)
	visuals.apply_time_immediately(12.0)
	var runtime_environment: Environment = world_environment.environment
	var runtime_sky_material := (
		runtime_environment.sky.sky_material as ProceduralSkyMaterial
	)
	var day_horizon: Color = runtime_sky_material.sky_horizon_color
	var day_ambient_energy: float = runtime_environment.ambient_light_energy
	visuals.apply_time_immediately(0.0)
	assert(runtime_sky_material.sky_horizon_color != day_horizon)
	assert(runtime_environment.ambient_light_energy < day_ambient_energy)
	visuals.apply_time_immediately(20.0)
	assert(runtime_sky_material.sky_horizon_color.r > day_horizon.r)
	world_root.queue_free()
