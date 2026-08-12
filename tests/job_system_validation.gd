extends SceneTree

const MainScene: PackedScene = preload("res://main/main.tscn")
const Catalog: FishPool = preload("res://fish/pools/fish_catalog.tres")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var main: Node = MainScene.instantiate()
	root.add_child(main)
	for _frame: int in 4:
		await process_frame
	if not bool(main.get("_application_initialized")):
		main.call("_activate_selected_data_path", "", true)
	for _frame: int in 8:
		await process_frame
	assert(bool(main.get("_application_initialized")))
	var session := main.get_node("%NetworkSession") as NetworkSession
	assert(session != null)
	var occupied_port := PacketPeerUDP.new()
	assert(occupied_port.bind(18137, "127.0.0.1") == OK)
	assert(session.start_private_host(18137, 3))
	assert(session.get_host_port() == 18138)
	occupied_port.close()
	var save_manager := main.get("_save_manager") as PlayerSaveManager
	assert(save_manager.initialize_new_game())
	main.call("_enter_gameplay")
	await physics_frame
	await physics_frame

	var jobs := main.get_node("%PlayerJobService") as PlayerJobService
	var weather := main.get_node("%WorldWeatherService") as WorldWeatherService
	var network_fishing := main.get(
		"_network_fishing"
	) as NetworkFishingService
	var network_sale := main.get("_network_sale") as NetworkSaleService
	var player := main.get("_player") as Player
	assert(jobs != null and weather != null and player != null)
	assert(network_fishing != null and network_sale != null)

	var board: Dictionary = jobs.get_host_board_network_data()
	assert(PlayerJobService.validate_board(board))
	assert(jobs.get_daily_jobs().size() == JobCatalog.DAILY_JOB_COUNT)
	assert(weather.get_daily_plan_id() == jobs.get_plan_id())
	_validate_weather_guarantees(board)
	_validate_late_board_weather_fallback()
	_validate_remote_tamper_rejection(jobs, board)

	var sell_job: Dictionary = _find_job(
		jobs.get_daily_jobs(), JobCatalog.Kind.SELL_TOTAL
	)
	assert(not sell_job.is_empty())
	var sell_target: int = int(sell_job.get("target", 0))
	var sold_ids: Array[StringName] = []
	for index: int in sell_target * 2:
		sold_ids.append(StringName("job-sale-%d" % index))
	network_sale.local_sale_finished.emit(
		"job-test", true, "sold", sold_ids, 1
	)
	await process_frame
	var pending: Array[Dictionary] = jobs.get_pending_rewards()
	assert(pending.size() == 1)
	var refreshed_sell: Dictionary = _find_job(
		jobs.get_daily_jobs(), JobCatalog.Kind.SELL_TOTAL
	)
	assert(int(refreshed_sell.get("progress", -1)) == sell_target)
	assert(int(refreshed_sell.get("completed_count", 0)) == 1)

	var game_ui := main.get_node("%GameUI") as GameUI
	var player_menu := game_ui.get("_player_menu") as PlayerMenu
	assert(player_menu != null)
	player_menu.open_menu()
	for _frame: int in 24:
		await process_frame
	assert(player_menu.visible)
	player_menu.call("_show_section_immediate", PlayerMenu.Section.NET)
	var net_page := player_menu.get_node("%TheNetPage") as TheNetPage
	assert(net_page.visible)
	assert((player_menu.get_node("%TheNetTab") as Button).button_pressed)
	assert(
		(player_menu.get_node("%NavigationCluster") as Control).get_child_count()
		== 7
	)

	var wallet_before: int = player.wallet.get_balance()
	var experience_before: int = player.experience.get_total_experience()
	var first_claim_id: String = str(pending[0].get("claim_id", ""))
	net_page.call("_claim", first_claim_id)
	await process_frame
	await process_frame
	assert(bool(game_ui.get("_experience_animation_active")))
	var experience_presentation := (
		game_ui.get_node("%ExperiencePresentation") as Control
	)
	assert(experience_presentation.visible)
	assert((game_ui.get_node("%ExperienceProgressPanel") as Control).visible)
	assert((game_ui.get_node("%ExperienceBubble") as Control).visible)
	assert(
		experience_presentation.get_index()
		== experience_presentation.get_parent().get_child_count() - 1
	)
	assert(not (game_ui.get_node("%GameplayTransientHUD") as Control).visible)
	assert(player_menu.visible)
	assert(not jobs.claim(first_claim_id))
	assert(
		player.wallet.get_balance()
		== wallet_before + int(pending[0].get("fish_coin", 0))
	)
	assert(
		player.experience.get_total_experience()
		== experience_before + int(pending[0].get("experience", 0))
	)
	refreshed_sell = _find_job(
		jobs.get_daily_jobs(), JobCatalog.Kind.SELL_TOTAL
	)
	assert(int(refreshed_sell.get("progress", -1)) == sell_target)
	assert(int(refreshed_sell.get("completed_count", 0)) == 1)
	assert(not bool(refreshed_sell.get("claimable", true)))
	network_sale.local_sale_finished.emit(
		"job-test-repeat", true, "sold", sold_ids, 1
	)
	await process_frame
	assert(jobs.get_pending_rewards().is_empty())
	refreshed_sell = _find_job(
		jobs.get_daily_jobs(), JobCatalog.Kind.SELL_TOTAL
	)
	assert(int(refreshed_sell.get("progress", -1)) == sell_target)
	assert(int(refreshed_sell.get("completed_count", 0)) == 1)

	var fresh_job: Dictionary = _find_job(
		jobs.get_daily_jobs(), JobCatalog.Kind.CATCH_WATER
	)
	assert(not fresh_job.is_empty())
	var bluegill: FishData = Catalog.get_fish_by_id(&"bluegill")
	assert(bluegill != null)
	for index: int in int(fresh_job.get("target", 0)):
		var fish_catch := FishCatch.new()
		fish_catch.fish = bluegill
		fish_catch.fish_id = bluegill.id
		fish_catch.catch_id = StringName("job-catch-%d" % index)
		fish_catch.catch_sequence = index + 1
		fish_catch.weight_lb = bluegill.get_minimum_weight()
		fish_catch.display_scale = bluegill.get_display_scale_for_weight(
			fish_catch.weight_lb
		)
		fish_catch.quality = FishQuality.Tier.BORING
		fish_catch.sale_value = bluegill.get_sale_value_for_weight(
			fish_catch.weight_lb
		)
		assert(fish_catch.is_valid())
		network_fishing.local_catch_received.emit(fish_catch)
	await process_frame
	var refreshed_fresh: Dictionary = _find_job(
		jobs.get_daily_jobs(), JobCatalog.Kind.CATCH_WATER
	)
	assert(int(refreshed_fresh.get("completed_count", 0)) == 1)

	var pause_menu := game_ui.get_pause_menu()
	var join_page := pause_menu.get_node("%JoinGamePage") as JoinGamePage
	assert(join_page != null)
	join_page.call("_refresh")
	var session_summary := (
		join_page.get_node("%SessionSummary") as Label
	)
	assert(not join_page.has_node(
		"Paper/Margin/Layout/Actions/OpenCloseButton"
	))
	assert("UDP 18138" in session_summary.text)
	assert(session.set_host_open(true))
	await process_frame
	assert("UDP 18138" in session_summary.text)
	assert(session.set_host_open(false))

	assert(save_manager.save_now())
	var save_file := FileAccess.open(
		str(save_manager.get("_save_path")), FileAccess.READ
	)
	assert(save_file != null)
	var parsed: Variant = JSON.parse_string(save_file.get_as_text())
	save_file.close()
	assert(typeof(parsed) == TYPE_DICTIONARY)
	var save_data: Dictionary = parsed
	assert(int(save_data.get("save_version", -1)) == 7)
	assert(PlayerJobService.validate_save_data(save_data.get("jobs", {})))

	session.disconnect_session("Job system validation complete.")
	main.queue_free()
	for _frame: int in 4:
		await process_frame
	print("Job system validation: PASS")
	quit()


func _validate_weather_guarantees(board: Dictionary) -> void:
	var jobs: Array = board.get("jobs", [])
	var schedule: Array = board.get("weather_schedule", [])
	var anchor_index: int = int(board.get("schedule_anchor_index", 0))
	for required_weather: int in JobCatalog.weather_requirements(jobs):
		var occurrences: int = 0
		var has_later_window: bool = false
		for index: int in schedule.size():
			var entry: Dictionary = schedule[index]
			if int(entry.get("weather", -1)) != required_weather:
				continue
			occurrences += 1
			if index > anchor_index:
				has_later_window = true
		assert(occurrences >= 2)
		assert(has_later_window)


func _validate_late_board_weather_fallback() -> void:
	var late_jobs: Array[Dictionary] = JobCatalog.generate_daily_jobs(
		"late-board-validation", [], false
	)
	assert(JobCatalog.weather_requirements(late_jobs).is_empty())
	var anchored_jobs: Array[Dictionary] = JobCatalog.generate_daily_jobs(
		"anchored-board-validation", [], true
	)
	var anchored_schedule: Array[Dictionary] = (
		JobCatalog.generate_weather_schedule(
			"anchored-board-validation", anchored_jobs, 9
		)
	)
	for required_weather: int in JobCatalog.weather_requirements(anchored_jobs):
		var occurrence_indices: Array[int] = []
		for index: int in anchored_schedule.size():
			var entry: Dictionary = anchored_schedule[index]
			if (
				index >= 9
				and int(entry.get("weather", -1)) == required_weather
			):
				occurrence_indices.append(index)
		assert(occurrence_indices.size() >= 2)
		assert(occurrence_indices[0] >= 9)
		assert(occurrence_indices[-1] > 9)


func _validate_remote_tamper_rejection(
	jobs: PlayerJobService,
	board: Dictionary,
) -> void:
	var tampered: Dictionary = board.duplicate(true)
	var tampered_jobs: Array = tampered.get("jobs", [])
	var first_job: Dictionary = tampered_jobs[0]
	first_job["fish_coin"] = int(first_job.get("fish_coin", 0)) + 1
	tampered_jobs[0] = first_job
	tampered["jobs"] = tampered_jobs
	assert(PlayerJobService.validate_board(tampered))
	assert(not jobs.apply_remote_board(tampered))


func _find_job(jobs: Array[Dictionary], kind: JobCatalog.Kind) -> Dictionary:
	for job: Dictionary in jobs:
		if int(job.get("kind", -1)) == int(kind):
			return job
	return {}
