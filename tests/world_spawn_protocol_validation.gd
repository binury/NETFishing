extends SceneTree

const Gatherables: GatherableCatalog = preload(
	"res://gathering/catalog/gatherable_catalog.tres"
)
const FishCatalog: FishPool = preload("res://fish/pools/fish_catalog.tres")


func _initialize() -> void:
	assert(NetworkProtocol.PROTOCOL_VERSION == 5)
	assert(
		NetworkWorldSpawnProtocol.CAPABILITY
		== NetworkProtocol.WORLD_SPAWN_CAPABILITY
	)
	assert(NetworkWorldSpawnProtocol.SNAPSHOT_ENTITIES_PER_ENVELOPE <= 4)
	_validate_catalog_statuses()
	_validate_envelopes()
	print("World spawn protocol validation: PASS")
	quit()


func _validate_catalog_statuses() -> void:
	var brown: GatherableData = Gatherables.get_entry(&"crab_brown")
	assert(brown != null and brown.is_available())
	assert(brown.catch_data.active)
	assert(brown.catch_data.collection_method == FishData.CollectionMethod.NET)
	assert(brown.catch_data.logbook_section == FishData.LogbookSection.SHELLFISH)
	assert(brown.population == 2)
	assert(is_equal_approx(brown.charge_duration, 2.0))
	assert(is_equal_approx(brown.capture_respawn_min_seconds, 480.0))
	assert(is_equal_approx(brown.capture_respawn_max_seconds, 720.0))
	assert(is_equal_approx(brown.scare_respawn_min_seconds, 45.0))
	assert(is_equal_approx(brown.scare_respawn_max_seconds, 90.0))
	assert(is_equal_approx(brown.minimum_respawn_spacing_seconds, 180.0))
	assert(brown.required_tool_id == &"crab_net")
	assert(FishCatalog.get_fish_by_id(&"crab_brown") == brown.catch_data)
	assert(not brown.catch_data.is_fishable())

	for type_id: StringName in [
		&"crab_ghost",
		&"crab_blue",
		&"crab_dungeness",
	]:
		var entry: GatherableData = Gatherables.get_entry(type_id)
		assert(entry != null)
		assert(entry.is_valid())
		assert(not entry.catch_data.active)
		assert(not entry.is_available())
		assert(entry.catch_data.collection_method == FishData.CollectionMethod.NET)
		assert(
			entry.catch_data.logbook_section
			== FishData.LogbookSection.SHELLFISH
		)

	var available: Array[GatherableData] = Gatherables.get_available_entries()
	assert(available.size() == 1)
	assert(available.front() == brown)
	var rng := RandomNumberGenerator.new()
	rng.seed = 24680
	var captured_delay: float = brown.get_respawn_delay(&"captured", rng)
	var scared_delay: float = brown.get_respawn_delay(&"scared", rng)
	assert(captured_delay >= 480.0 and captured_delay <= 720.0)
	assert(scared_delay >= 45.0 and scared_delay <= 90.0)


func _validate_envelopes() -> void:
	var entity: Dictionary = {
		"entity_id": "world:sample",
		"type_id": "future_shellfish",
		"position": [1.0, 2.0, 3.0],
		"yaw": 0.5,
		"revision": 7,
	}
	assert(NetworkWorldSpawnProtocol.validate_entity_state(entity))
	var future_entity: Dictionary = entity.duplicate(true)
	future_entity["future_state"] = {"buried": false}
	assert(NetworkWorldSpawnProtocol.validate_entity_state(future_entity))

	var envelope: Dictionary = NetworkWorldSpawnProtocol.make_envelope(
		"session-test",
		12,
		&"future_spawn_type",
		{"entity": entity, "future_payload": [1, 2, 3]},
	)
	assert(NetworkWorldSpawnProtocol.validate_envelope(envelope))

	var malformed_position: Dictionary = entity.duplicate(true)
	malformed_position["position"] = [1.0, "not-a-number", 3.0]
	assert(
		not NetworkWorldSpawnProtocol.validate_entity_state(
			malformed_position
		)
	)
	assert(
		not NetworkWorldSpawnProtocol.array_to_vector3(
			malformed_position["position"]
		).is_finite()
	)

	var invalid_envelope: Dictionary = envelope.duplicate(true)
	invalid_envelope["envelope_version"] = 0
	assert(not NetworkWorldSpawnProtocol.validate_envelope(invalid_envelope))
