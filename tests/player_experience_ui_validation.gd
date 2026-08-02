extends SceneTree

const GameUIScene: PackedScene = preload("res://ui/game_ui.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_ui := GameUIScene.instantiate() as GameUI
	root.add_child(game_ui)
	await process_frame
	game_ui.set("_gameplay_ui_enabled", true)
	game_ui.call(
		"_on_experience_awarded",
		50,
		0,
		50,
		1,
		1,
	)
	var panel := game_ui.get_node("%ExperienceProgressPanel") as PanelContainer
	var bubble := game_ui.get_node("%ExperienceBubble") as PanelContainer
	var bubble_label := game_ui.get_node("%ExperienceBubbleLabel") as Label
	var award_label := game_ui.get_node("%ExperienceAwardLabel") as Label
	assert(panel != null and bubble != null)
	assert(not panel.visible and not bubble.visible)
	game_ui.call("_on_showcase_changed", "bluegill", "common", 1.0, 0, true)
	await process_frame
	assert(not panel.visible and not bubble.visible)
	game_ui.call("_on_showcase_changed", "", "", 0.0, 0, false)
	await process_frame
	await process_frame
	assert(panel.visible and bubble.visible)
	assert(award_label.text == "+50 xp")
	assert(bubble_label.text == "+50 xp!")
	await create_timer(1.6).timeout
	var progress := game_ui.get_node("%ExperienceProgress") as ProgressBar
	var level_label := game_ui.get_node("%ExperienceLevelLabel") as Label
	assert(is_equal_approx(progress.value, 50.0))
	assert(level_label.text == "level 1")
	await create_timer(1.2).timeout
	assert(not panel.visible and not bubble.visible)
	game_ui.queue_free()
	print("Player experience UI validation: PASS")
	quit()
