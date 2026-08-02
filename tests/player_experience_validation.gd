extends SceneTree

const FishCatchType = preload("res://fish/fish_catch.gd")
const FishExperienceType = preload("res://fish/fish_experience.gd")
const FishQualityType = preload("res://fish/fish_quality.gd")
const PlayerExperienceType = preload(
	"res://progression/player_experience.gd"
)
const Catalog: FishPool = preload("res://fish/pools/fish_catalog.tres")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_validate_level_curve()
	_validate_catch_awards()
	_validate_player_experience_state()
	_validate_save_migration()
	print("Player experience validation: PASS")
	quit()


func _validate_level_curve() -> void:
	assert(PlayerExperienceType.experience_required_for_next_level(1) == 100)
	assert(PlayerExperienceType.experience_required_for_next_level(2) == 130)
	assert(PlayerExperienceType.experience_required_for_next_level(3) == 170)
	assert(PlayerExperienceType.total_experience_for_level(1) == 0)
	assert(PlayerExperienceType.total_experience_for_level(2) == 100)
	assert(PlayerExperienceType.total_experience_for_level(3) == 230)
	assert(PlayerExperienceType.total_experience_for_level(4) == 400)
	assert(PlayerExperienceType.level_for_total_experience(99) == 1)
	assert(PlayerExperienceType.level_for_total_experience(100) == 2)
	assert(PlayerExperienceType.level_for_total_experience(399) == 3)
	assert(PlayerExperienceType.level_for_total_experience(400) == 4)
	assert(
		is_equal_approx(
			PlayerExperienceType.progress_for_total_experience(50),
			0.5,
		)
	)


func _validate_catch_awards() -> void:
	var minimum_boring: FishCatch = _make_catch(
		FishQualityType.Tier.BORING,
		false,
	)
	assert(
		FishExperienceType.calculate_catch_experience(
			minimum_boring,
			false,
			0,
		) == 50
	)
	var maximum_shiny: FishCatch = _make_catch(
		FishQualityType.Tier.SHINY,
		true,
	)
	var boring_mask: int = FishQualityType.bit_for(
		FishQualityType.Tier.BORING
	)
	assert(
		FishExperienceType.calculate_catch_experience(
			maximum_shiny,
			true,
			boring_mask,
		) == 46
	)
	var almost_mastered: int = (
		FishQualityType.ALL_TIERS_MASK
		& ~FishQualityType.bit_for(FishQualityType.Tier.SHINY)
	)
	assert(
		FishExperienceType.calculate_catch_experience(
			maximum_shiny,
			true,
			almost_mastered,
		) == 146
	)
	assert(
		FishExperienceType.calculate_catch_experience(
			maximum_shiny,
			true,
			FishQualityType.ALL_TIERS_MASK,
		) == 31
	)


func _validate_player_experience_state() -> void:
	var experience := PlayerExperienceType.new()
	root.add_child(experience)
	var awards: Array[Array] = []
	experience.experience_awarded.connect(
		func(
			amount: int,
			previous_total: int,
			new_total: int,
			previous_level: int,
			new_level: int,
		) -> void:
			awards.append([
				amount,
				previous_total,
				new_total,
				previous_level,
				new_level,
			])
	)
	assert(experience.get_level() == 1)
	assert(experience.award_experience(125))
	assert(experience.get_total_experience() == 125)
	assert(experience.get_level() == 2)
	assert(experience.get_experience_in_level() == 25)
	assert(awards.size() == 1)
	assert(awards[0] == [125, 0, 125, 1, 2])
	assert(experience.restore_total_experience(400))
	assert(experience.get_level() == 4)
	assert(not experience.restore_total_experience(-1))
	experience.queue_free()


func _validate_save_migration() -> void:
	var manager := PlayerSaveManager.new()
	root.add_child(manager)
	var version_five: Dictionary = {
		"save_version": 5,
		"wallet": {"balance": 0},
		"collection": {
			"discovered_fish_ids": [],
			"discovered_quality_masks": {},
		},
		"inventory": {"next_catch_sequence": 1, "catches": []},
		"bag": {"items": []},
		"hotbar": {"selected_slot": 0, "slots": []},
		"upgrades": {"reel_speed_level": 0, "barrier_power_level": 0},
		"cooler": {"capacity_level": 0},
		"art": {"unlock_mask": 0},
	}
	var migrated: Dictionary = manager.call(
		"_migrate_save",
		version_five,
		5,
	)
	assert(int(migrated.get("save_version", -1)) == 6)
	var experience_data: Dictionary = migrated.get("experience", {})
	assert(int(experience_data.get("total_experience", -1)) == 0)
	var world_data: Dictionary = migrated.get("world", {})
	assert(is_equal_approx(float(world_data.get("time_hours", -1.0)), 8.0))
	manager.queue_free()


func _make_catch(quality: int, maximum_weight: bool) -> FishCatch:
	var fish: FishData = Catalog.get_fish_by_id(&"bluegill")
	assert(fish != null)
	var fish_catch := FishCatchType.new()
	fish_catch.fish = fish
	fish_catch.fish_id = fish.id
	fish_catch.catch_id = StringName("bluegill:xp-%d-%s" % [
		quality,
		"max" if maximum_weight else "min",
	])
	fish_catch.catch_sequence = 1
	fish_catch.weight_lb = (
		fish.get_maximum_weight()
		if maximum_weight
		else fish.get_minimum_weight()
	)
	fish_catch.display_scale = fish.get_display_scale_for_weight(
		fish_catch.weight_lb
	)
	fish_catch.quality = quality
	fish_catch.sale_value = FishQualityType.apply_sale_value(
		fish.get_sale_value_for_weight(fish_catch.weight_lb),
		quality,
	)
	return fish_catch
