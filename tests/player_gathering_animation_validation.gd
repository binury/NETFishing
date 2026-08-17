extends SceneTree


const PlayerScene: PackedScene = preload("res://player/player.tscn")
const CrabBrown: FishData = preload(
	"res://fish/species/crab_brown/crab_brown.tres"
)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var player := PlayerScene.instantiate() as Player
	root.add_child(player)
	await process_frame
	player.set_process(false)
	player.set_physics_process(false)
	var animation_player := player.get_node(
		"Visuals/CharacterRig/AnimationPlayer"
	) as AnimationPlayer
	assert(animation_player != null)
	for required_animation: StringName in [
		&"draw",
		&"idle_sneak",
		&"sneaking",
		&"strike",
	]:
		assert(animation_player.has_animation(required_animation))

	Input.action_press(&"sneak")
	player.velocity = Vector3.ZERO
	player.call("_update_character_animation")
	assert(animation_player.current_animation == &"idle_sneak")

	player.velocity = Vector3(player.sneak_speed, 0.0, 0.0)
	player.call("_update_character_animation")
	assert(animation_player.current_animation == &"sneaking")

	player.velocity = Vector3.ZERO
	assert(player.begin_net_draw_visual())
	assert(animation_player.current_animation == &"draw")
	player.call("_on_character_animation_finished", &"draw")
	assert(StringName(player.get("_animation_action_id")) == &"draw")
	assert(animation_player.current_animation == &"draw")

	assert(player.play_net_strike_visual())
	assert(animation_player.current_animation == &"strike")
	player.call("_on_character_animation_finished", &"strike")
	assert(StringName(player.get("_animation_action_id")) == &"strike")
	assert(bool(player.get("_animation_action_paused")))
	assert(player.is_net_strike_held())
	assert(player.release_net_strike_hold())
	assert(StringName(player.get("_animation_action_id")).is_empty())
	assert(animation_player.current_animation == &"idle_sneak")

	Input.action_release(&"sneak")
	assert(player.begin_net_draw_visual())
	assert(animation_player.current_animation == &"casting")
	player.cancel_net_action_visual()
	assert(StringName(player.get("_animation_action_id")).is_empty())
	assert(animation_player.current_animation == &"idle")
	Input.action_press(&"sneak")

	assert(player.play_net_strike_visual())
	player.resolve_net_strike_visual(true)
	var crab_catch := FishCatch.new()
	crab_catch.fish = CrabBrown
	crab_catch.fish_id = CrabBrown.id
	crab_catch.weight_lb = CrabBrown.get_minimum_weight()
	crab_catch.display_scale = CrabBrown.get_display_scale_for_weight(
		crab_catch.weight_lb
	)
	crab_catch.sale_value = CrabBrown.get_sale_value_for_weight(
		crab_catch.weight_lb
	)
	crab_catch.ensure_identity()
	player.begin_catch_showcase(crab_catch)
	assert(not bool(player.get("_showcase_animation_active")))
	assert(player.get("_pending_net_showcase_catch") == crab_catch)
	player.call("_on_character_animation_finished", &"strike")
	assert(StringName(player.get("_animation_action_id")).is_empty())
	assert(bool(player.get("_showcase_animation_active")))
	var catch_display := player.get("_catch_display") as Node3D
	assert(catch_display != null and catch_display.visible)
	player.end_catch_showcase(Callable(), true)

	Input.action_release(&"sneak")
	player.queue_free()
	await process_frame
	print("Player gathering animation validation: PASS")
	quit()
