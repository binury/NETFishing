class_name PlayerJobService
extends Node

const FishCatchType = preload("res://fish/fish_catch.gd")
const FishDataType = preload("res://fish/fish_data.gd")
const FishPoolType = preload("res://fish/fish_pool.gd")

const FORMAT_VERSION: int = 1
const MAX_PROGRESS_VALUE: int = 1000000000
const MAX_PENDING_REWARDS: int = 64
const DAILY_REFRESH_HOUR: float = WorldTimeService.DAY_START_HOUR

signal changed
signal board_changed
signal reward_claimed(title: String, fish_coin: int, experience: int)
signal status_changed(message: String)

var _wallet: PlayerWallet
var _experience: PlayerExperience
var _collection: CollectionLog
var _catalog: FishPoolType
var _world_time: WorldTimeService
var _world_weather: WorldWeatherService
var _session: NetworkSession
var _save_manager: PlayerSaveManager
var _network_fishing: NetworkFishingService
var _network_sale: NetworkSaleService

var _progression_ready: bool = false
var _host_board: Dictionary = {}
var _active_board: Dictionary = {}
var _active_plan_id: String = ""
var _daily_progress: Dictionary[String, int] = {}
var _daily_completions: Dictionary[String, int] = {}
var _pending_rewards: Array[Dictionary] = []
var _lifetime_claimed: Array[String] = []
var _total_catches: int = 0
var _total_sold: int = 0
var _daily_clock_hour: float = WorldTimeService.DEFAULT_START_HOUR


func setup(
	wallet: PlayerWallet,
	experience: PlayerExperience,
	collection: CollectionLog,
	catalog: FishPoolType,
	world_time: WorldTimeService,
	world_weather: WorldWeatherService,
	session: NetworkSession,
) -> void:
	_wallet = wallet
	_experience = experience
	_collection = collection
	_catalog = catalog
	_world_time = world_time
	_world_weather = world_weather
	_session = session
	_daily_clock_hour = _world_time.get_time_hours()
	_world_time.natural_time_advanced.connect(_on_natural_time_advanced)
	_session.state_changed.connect(_on_session_state_changed)
	_collection.collection_changed.connect(_on_current_state_changed)
	_experience.experience_changed.connect(_on_experience_changed)


func bind_authoritative_services(
	network_fishing: NetworkFishingService,
	network_sale: NetworkSaleService,
) -> void:
	_network_fishing = network_fishing
	_network_sale = network_sale
	if not _network_fishing.local_catch_received.is_connected(
		_on_authoritative_catch
	):
		_network_fishing.local_catch_received.connect(_on_authoritative_catch)
	if not _network_sale.local_sale_finished.is_connected(
		_on_authoritative_sale_finished
	):
		_network_sale.local_sale_finished.connect(
			_on_authoritative_sale_finished
		)


func set_save_manager(save_manager: PlayerSaveManager) -> void:
	_save_manager = save_manager


func begin_progression_session() -> void:
	_progression_ready = true
	if _session.is_host():
		_activate_host_board()
	changed.emit()


func end_progression_session() -> void:
	_progression_ready = false
	_active_board = {}
	changed.emit()


func get_daily_jobs() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var jobs: Array = _active_board.get("jobs", [])
	for value: Variant in jobs:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var job: Dictionary = (value as Dictionary).duplicate(true)
		var job_id: String = str(job.get("id", ""))
		job["progress"] = mini(
			int(_daily_progress.get(job_id, 0)), int(job.get("target", 1))
		)
		job["completed_count"] = int(_daily_completions.get(job_id, 0))
		var pending: Array[Dictionary] = _pending_for_job(
			_active_plan_id, job_id
		)
		job["pending_count"] = pending.size()
		job["claim_id"] = (
			str(pending[0].get("claim_id", "")) if not pending.is_empty() else ""
		)
		job["claimable"] = not pending.is_empty()
		result.append(job)
	return result


func get_lifetime_jobs() -> Array[Dictionary]:
	var result: Array[Dictionary] = JobCatalog.visible_lifetime_jobs(
		_registered_species_count(), _lifetime_claimed
	)
	for job: Dictionary in result:
		var progress: int = _lifetime_progress(job)
		job["progress"] = mini(progress, int(job.get("target", 1)))
		job["complete"] = progress >= int(job.get("target", 1))
		job["claimable"] = bool(job["complete"])
	return result


func get_pending_rewards() -> Array[Dictionary]:
	return _pending_rewards.duplicate(true)


func get_forecast() -> Array[Dictionary]:
	var schedule: Array = _active_board.get("weather_schedule", [])
	var result: Array[Dictionary] = []
	for value: Variant in schedule:
		if typeof(value) == TYPE_DICTIONARY:
			result.append((value as Dictionary).duplicate(true))
	return result


func get_plan_id() -> String:
	return _active_plan_id


func has_active_board() -> bool:
	return validate_board(_active_board)


func get_time_until_refresh_text() -> String:
	if _active_plan_id.is_empty() or _world_time == null:
		return "daily jobs unavailable"
	var elapsed: float = fposmod(
		_daily_clock_hour - DAILY_REFRESH_HOUR,
		WorldTimeService.HOURS_PER_DAY,
	)
	var hours_remaining: float = WorldTimeService.HOURS_PER_DAY - elapsed
	var real_seconds: int = ceili(
		hours_remaining / WorldTimeService.HOURS_PER_REAL_SECOND
	)
	return "refreshes in %d:%02d" % [
		floori(float(real_seconds) / 60.0), real_seconds % 60,
	]


func claim(claim_id: String) -> bool:
	if claim_id.is_empty() or _wallet == null or _experience == null:
		return false
	for index: int in _pending_rewards.size():
		var reward: Dictionary = _pending_rewards[index]
		if str(reward.get("claim_id", "")) != claim_id:
			continue
		return _claim_pending_reward(index, reward)
	for lifetime_job: Dictionary in get_lifetime_jobs():
		if str(lifetime_job.get("id", "")) != claim_id:
			continue
		if not bool(lifetime_job.get("claimable", false)):
			return false
		return _claim_lifetime_reward(lifetime_job)
	return false


func get_host_board_network_data() -> Dictionary:
	var board := _host_board.duplicate(true)
	if not board.is_empty():
		board["daily_clock_hour"] = _daily_clock_hour
	return board


func apply_remote_board(board: Dictionary) -> bool:
	if not validate_board(board) or not _matches_canonical_board(board):
		return false
	var plan_id: String = str(board.get("plan_id", ""))
	if plan_id != _active_plan_id:
		_expire_incomplete_daily_jobs()
		_active_plan_id = plan_id
		_daily_progress.clear()
		_daily_completions.clear()
	_active_board = board.duplicate(true)
	if board.has("daily_clock_hour"):
		_daily_clock_hour = float(board["daily_clock_hour"])
	changed.emit()
	return true


func clear_remote_board() -> void:
	if _session != null and _session.is_host():
		_activate_host_board()
		return
	_active_board = {}
	changed.emit()


func to_save_data() -> Dictionary:
	var progress: Dictionary = {}
	for job_id: String in _daily_progress:
		progress[job_id] = _daily_progress[job_id]
	var completions: Dictionary = {}
	for job_id: String in _daily_completions:
		completions[job_id] = _daily_completions[job_id]
	return {
		"format_version": FORMAT_VERSION,
		"host_board": _host_board.duplicate(true),
		"active_plan_id": _active_plan_id,
		"daily_progress": progress,
		"daily_completions": completions,
		"daily_clock_hour": _daily_clock_hour,
		"pending_rewards": _pending_rewards.duplicate(true),
		"lifetime_claimed": _lifetime_claimed.duplicate(),
		"statistics": {
			"fish_caught": _total_catches,
			"fish_sold": _total_sold,
		},
	}


func restore_from_save_data(data: Dictionary) -> bool:
	if not validate_save_data(data):
		return false
	var received_board: Dictionary = _active_board.duplicate(true)
	_host_board = (data.get("host_board", {}) as Dictionary).duplicate(true)
	_active_plan_id = str(data.get("active_plan_id", ""))
	_daily_progress.clear()
	var progress: Dictionary = data.get("daily_progress", {})
	for key: Variant in progress:
		_daily_progress[str(key)] = int(progress[key])
	_daily_completions.clear()
	var completions: Dictionary = data.get("daily_completions", {})
	for key: Variant in completions:
		_daily_completions[str(key)] = mini(int(completions[key]), 1)
	_daily_clock_hour = float(data.get(
		"daily_clock_hour",
		_world_time.get_time_hours()
		if _world_time != null
		else WorldTimeService.DEFAULT_START_HOUR,
	))
	_pending_rewards.clear()
	var rewards: Array = data.get("pending_rewards", [])
	var restored_daily_rewards: Dictionary[String, bool] = {}
	for value: Variant in rewards:
		var reward: Dictionary = value
		var reward_key: String = "%s/%s" % [
			str(reward.get("source_plan_id", "")),
			str(reward.get("source_job_id", "")),
		]
		if restored_daily_rewards.has(reward_key):
			continue
		restored_daily_rewards[reward_key] = true
		_pending_rewards.append(reward.duplicate(true))
	_lifetime_claimed.clear()
	var claimed: Array = data.get("lifetime_claimed", [])
	for value: Variant in claimed:
		_lifetime_claimed.append(str(value))
	var statistics: Dictionary = data.get("statistics", {})
	_total_catches = int(statistics.get("fish_caught", 0))
	_total_sold = int(statistics.get("fish_sold", 0))
	if _session != null and _session.is_host():
		_active_board = _host_board.duplicate(true)
		_active_plan_id = str(_host_board.get("plan_id", ""))
	elif (
		_session != null
		and _session.is_joined_client()
		and not received_board.is_empty()
	):
		apply_remote_board(received_board)
	_apply_host_weather_plan()
	changed.emit()
	return true


func reset_to_defaults() -> void:
	_host_board = {}
	_active_board = {}
	_active_plan_id = ""
	_daily_progress.clear()
	_daily_completions.clear()
	_pending_rewards.clear()
	_lifetime_claimed.clear()
	_total_catches = 0
	_total_sold = 0
	_daily_clock_hour = WorldTimeService.DEFAULT_START_HOUR
	changed.emit()


static func default_save_data() -> Dictionary:
	return {
		"format_version": FORMAT_VERSION,
		"host_board": {},
		"active_plan_id": "",
		"daily_progress": {},
		"daily_completions": {},
		"daily_clock_hour": WorldTimeService.DEFAULT_START_HOUR,
		"pending_rewards": [],
		"lifetime_claimed": [],
		"statistics": {"fish_caught": 0, "fish_sold": 0},
	}


static func validate_board(value: Variant) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false
	var board: Dictionary = value
	if (
		typeof(board.get("plan_id")) != TYPE_STRING
		or str(board.get("plan_id", "")).is_empty()
		or str(board.get("plan_id", "")).length() > 96
		or not JobCatalog.is_bounded_integer(
			board.get("cycle"), 0, MAX_PROGRESS_VALUE
		)
		or not JobCatalog.is_bounded_integer(
			board.get("schedule_anchor_index"),
			0,
			JobCatalog.WEATHER_SEGMENT_COUNT - 1,
		)
		or typeof(board.get("jobs")) != TYPE_ARRAY
		or not JobCatalog.is_valid_weather_schedule(
			board.get("weather_schedule", [])
		)
	):
		return false
	var jobs: Array = board.get("jobs", [])
	if jobs.is_empty() or jobs.size() > 8:
		return false
	var seen: Dictionary[String, bool] = {}
	for job_value: Variant in jobs:
		if not JobCatalog.is_valid_job(job_value):
			return false
		var job: Dictionary = job_value
		var job_id: String = str(job.get("id", ""))
		if seen.has(job_id):
			return false
		seen[job_id] = true
	return true


static func validate_save_data(value: Variant) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false
	var data: Dictionary = value
	if (
		not JobCatalog.is_bounded_integer(
			data.get("format_version"), FORMAT_VERSION, FORMAT_VERSION
		)
		or typeof(data.get("host_board")) != TYPE_DICTIONARY
		or typeof(data.get("active_plan_id")) != TYPE_STRING
		or typeof(data.get("daily_progress")) != TYPE_DICTIONARY
		or typeof(data.get("daily_completions")) != TYPE_DICTIONARY
		or typeof(data.get("pending_rewards")) != TYPE_ARRAY
		or typeof(data.get("lifetime_claimed")) != TYPE_ARRAY
		or typeof(data.get("statistics")) != TYPE_DICTIONARY
	):
		return false
	var host_board: Dictionary = data.get("host_board", {})
	if not host_board.is_empty() and not validate_board(host_board):
		return false
	if (
		data.has("daily_clock_hour")
		and (
			typeof(data["daily_clock_hour"]) not in [TYPE_FLOAT, TYPE_INT]
			or not is_finite(float(data["daily_clock_hour"]))
			or float(data["daily_clock_hour"]) < 0.0
			or float(data["daily_clock_hour"]) >= WorldTimeService.HOURS_PER_DAY
		)
	):
		return false
	var progress: Dictionary = data.get("daily_progress", {})
	if progress.size() > 8:
		return false
	for key: Variant in progress:
		if (
			typeof(key) != TYPE_STRING
			or str(key).is_empty()
			or str(key).length() > 96
			or not JobCatalog.is_bounded_integer(
				progress[key], 0, MAX_PROGRESS_VALUE
			)
		):
			return false
	var completions: Dictionary = data.get("daily_completions", {})
	if completions.size() > 8:
		return false
	for key: Variant in completions:
		if (
			typeof(key) != TYPE_STRING
			or str(key).is_empty()
			or str(key).length() > 96
			or not JobCatalog.is_bounded_integer(
				completions[key], 0, MAX_PROGRESS_VALUE
			)
		):
			return false
	var rewards: Array = data.get("pending_rewards", [])
	if rewards.size() > MAX_PENDING_REWARDS:
		return false
	for reward: Variant in rewards:
		if not _valid_reward(reward):
			return false
	var claimed: Array = data.get("lifetime_claimed", [])
	if claimed.size() > 64 or not _valid_string_array(claimed, 96):
		return false
	var statistics: Dictionary = data.get("statistics", {})
	return (
		JobCatalog.is_bounded_integer(
			statistics.get("fish_caught"), 0, MAX_PROGRESS_VALUE
		)
		and JobCatalog.is_bounded_integer(
			statistics.get("fish_sold"), 0, MAX_PROGRESS_VALUE
		)
	)


func _activate_host_board() -> void:
	if _host_board.is_empty():
		_generate_host_board(0)
	else:
		_active_board = _host_board.duplicate(true)
		_switch_plan(str(_host_board.get("plan_id", "")))
		_apply_host_weather_plan()
	board_changed.emit()
	changed.emit()


func _generate_host_board(cycle: int) -> void:
	_expire_incomplete_daily_jobs()
	var random_suffix: String = Crypto.new().generate_random_bytes(12).hex_encode()
	var plan_id: String = "daily:%d:%s" % [cycle, random_suffix]
	var candidates: Array[FishDataType] = []
	if _catalog != null:
		for fish: FishDataType in _catalog.candidates:
			if fish != null and fish.is_selectable():
				candidates.append(fish)
	var schedule_anchor_index: int = _current_weather_segment()
	var allow_weather_jobs: bool = (
		JobCatalog.WEATHER_SEGMENT_COUNT - schedule_anchor_index >= 2
	)
	var jobs: Array[Dictionary] = JobCatalog.generate_daily_jobs(
		plan_id, candidates, allow_weather_jobs
	)
	_host_board = {
		"plan_id": plan_id,
		"cycle": cycle,
		"schedule_anchor_index": schedule_anchor_index,
		"jobs": jobs,
		"weather_schedule": JobCatalog.generate_weather_schedule(
			plan_id, jobs, schedule_anchor_index
		),
	}
	_active_board = _host_board.duplicate(true)
	_switch_plan(plan_id)
	_apply_host_weather_plan()
	board_changed.emit()
	changed.emit()


func _switch_plan(plan_id: String) -> void:
	if plan_id == _active_plan_id:
		return
	_active_plan_id = plan_id
	_daily_progress.clear()
	_daily_completions.clear()


func _apply_host_weather_plan() -> void:
	if (
		_world_weather == null
		or _world_time == null
		or _session == null
		or not _session.is_host()
		or _host_board.is_empty()
	):
		return
	var schedule: Array = _host_board.get("weather_schedule", [])
	_world_weather.configure_daily_plan(
		str(_host_board.get("plan_id", "")), schedule, _world_time
	)


func _on_natural_time_advanced(hours: float) -> void:
	if not is_finite(hours) or hours <= 0.0:
		return
	var previous_hour := _daily_clock_hour
	_daily_clock_hour = fposmod(
		_daily_clock_hour + hours,
		WorldTimeService.HOURS_PER_DAY,
	)
	if (
		_progression_ready
		and _session != null
		and _session.is_host()
		and _crossed_daily_refresh(previous_hour, _daily_clock_hour)
	):
		var cycle: int = int(_host_board.get("cycle", -1)) + 1
		_generate_host_board(maxi(cycle, 0))


func _on_session_state_changed(state: NetworkSession.State) -> void:
	if not _progression_ready:
		return
	if state in [NetworkSession.State.PRIVATE_HOST, NetworkSession.State.OPEN_HOST]:
		_activate_host_board()
	elif state == NetworkSession.State.JOINED_CLIENT:
		_active_board = {}
		changed.emit()
	elif state in [
		NetworkSession.State.INACTIVE,
		NetworkSession.State.DISCONNECTING,
		NetworkSession.State.CONNECTION_FAILED,
		NetworkSession.State.SERVER_LOST,
	]:
		clear_remote_board()


func _on_authoritative_catch(fish_catch: FishCatchType) -> void:
	if not _progression_ready or fish_catch == null or not fish_catch.is_valid():
		return
	_total_catches = mini(_total_catches + 1, MAX_PROGRESS_VALUE)
	_update_daily_for_catch(fish_catch)
	changed.emit()


func _on_authoritative_sale_finished(
	_request_id: String,
	accepted: bool,
	_message: String,
	catch_ids: Array[StringName],
	_payout: int,
) -> void:
	if not _progression_ready or not accepted or catch_ids.is_empty():
		return
	_total_sold = mini(_total_sold + catch_ids.size(), MAX_PROGRESS_VALUE)
	for job: Dictionary in get_daily_jobs():
		if int(job.get("kind", -1)) == JobCatalog.Kind.SELL_TOTAL:
			_advance_daily(job, catch_ids.size())
	changed.emit()


func _update_daily_for_catch(fish_catch: FishCatchType) -> void:
	for job: Dictionary in get_daily_jobs():
		var matches: bool = false
		match int(job.get("kind", -1)):
			JobCatalog.Kind.CATCH_TOTAL:
				matches = true
			JobCatalog.Kind.CATCH_WATER:
				matches = fish_catch.fish.is_allowed_in_water(
					int(job.get("water_type", WaterType.Type.OTHER)) as WaterType.Type
				)
			JobCatalog.Kind.CATCH_QUALITY:
				matches = fish_catch.quality >= int(job.get("minimum_quality", 0))
			JobCatalog.Kind.CATCH_PHASE:
				matches = int(_world_time.get_phase()) == int(job.get("phase", -1))
			JobCatalog.Kind.CATCH_WEATHER:
				matches = int(_world_weather.get_weather()) == int(job.get("weather", -1))
			JobCatalog.Kind.CATCH_SPECIES:
				matches = String(fish_catch.fish_id) == str(job.get("fish_id", ""))
		if matches:
			_advance_daily(job, 1)


func _advance_daily(job: Dictionary, amount: int) -> void:
	var job_id: String = str(job.get("id", ""))
	if job_id.is_empty() or amount <= 0:
		return
	if int(_daily_completions.get(job_id, 0)) > 0:
		return
	var target: int = int(job.get("target", 1))
	var progress: int = mini(
		int(_daily_progress.get(job_id, 0)) + amount,
		target,
	)
	if progress >= target and _pending_rewards.size() < MAX_PENDING_REWARDS:
		_daily_completions[job_id] = 1
		var reward: Dictionary = {
			"claim_id": _daily_claim_id(_active_plan_id, job_id),
			"source_plan_id": _active_plan_id,
			"source_job_id": job_id,
			"title": str(job.get("title", "daily job")),
			"fish_coin": int(job.get("fish_coin", 0)),
			"experience": int(job.get("experience", 0)),
		}
		_pending_rewards.append(reward)
		status_changed.emit("job complete — payment ready on the net")
	_daily_progress[job_id] = progress


func _claim_pending_reward(index: int, reward: Dictionary) -> bool:
	var state_snapshot: Dictionary = to_save_data()
	var wallet_snapshot: int = _wallet.get_balance()
	var experience_snapshot: int = _experience.get_total_experience()
	_pending_rewards.remove_at(index)
	if not _apply_reward(reward) or not _save_claim_transaction():
		_wallet.restore_balance(wallet_snapshot)
		_experience.restore_total_experience(experience_snapshot)
		restore_from_save_data(state_snapshot)
		return false
	_reward_claimed(reward)
	return true


func _claim_lifetime_reward(job: Dictionary) -> bool:
	var job_id: String = str(job.get("id", ""))
	if job_id.is_empty() or job_id in _lifetime_claimed:
		return false
	var state_snapshot: Dictionary = to_save_data()
	var wallet_snapshot: int = _wallet.get_balance()
	var experience_snapshot: int = _experience.get_total_experience()
	_lifetime_claimed.append(job_id)
	if not _apply_reward(job) or not _save_claim_transaction():
		_wallet.restore_balance(wallet_snapshot)
		_experience.restore_total_experience(experience_snapshot)
		restore_from_save_data(state_snapshot)
		return false
	_reward_claimed(job)
	return true


func _apply_reward(reward: Dictionary) -> bool:
	var fish_coin: int = int(reward.get("fish_coin", 0))
	var experience: int = int(reward.get("experience", 0))
	if fish_coin > 0 and not _wallet.credit(fish_coin):
		return false
	if experience > 0 and not _experience.award_experience(experience):
		return false
	changed.emit()
	return true


func _save_claim_transaction() -> bool:
	return _save_manager != null and _save_manager.save_if_dirty()


func _reward_claimed(reward: Dictionary) -> void:
	var title: String = str(reward.get("title", "job"))
	var fish_coin: int = int(reward.get("fish_coin", 0))
	var experience: int = int(reward.get("experience", 0))
	reward_claimed.emit(title, fish_coin, experience)
	status_changed.emit("payment received — %d xp" % experience)
	changed.emit()


func _lifetime_progress(job: Dictionary) -> int:
	match int(job.get("kind", -1)):
		JobCatalog.Kind.CATCH_TOTAL:
			return _total_catches
		JobCatalog.Kind.SELL_TOTAL:
			return _total_sold
		JobCatalog.Kind.REACH_LEVEL:
			return _experience.get_level() if _experience != null else 0
		JobCatalog.Kind.DISCOVER_SPECIES:
			return _collection.get_discovered_ids().size() if _collection != null else 0
		JobCatalog.Kind.MASTER_QUALITIES:
			var mastered: int = 0
			if _collection != null and _catalog != null:
				for fish: FishDataType in _catalog.candidates:
					if fish != null and _collection.has_mastered(fish.id):
						mastered += 1
			return mastered
	return 0


func _registered_species_count() -> int:
	var count: int = 0
	if _catalog != null:
		for fish: FishDataType in _catalog.candidates:
			if fish != null and fish.is_selectable():
				count += 1
	return count


func _expire_incomplete_daily_jobs() -> void:
	_daily_progress.clear()
	_daily_completions.clear()


func _on_current_state_changed() -> void:
	if _progression_ready:
		changed.emit()


func _on_experience_changed(_total: int, _level: int) -> void:
	if _progression_ready:
		changed.emit()


func _pending_for_job(
	plan_id: String,
	job_id: String,
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for reward: Dictionary in _pending_rewards:
		if (
			str(reward.get("source_plan_id", "")) == plan_id
			and str(reward.get("source_job_id", "")) == job_id
		):
			result.append(reward)
	return result


func _matches_canonical_board(board: Dictionary) -> bool:
	var plan_id: String = str(board.get("plan_id", ""))
	var candidates: Array[FishDataType] = []
	if _catalog != null:
		for fish: FishDataType in _catalog.candidates:
			if fish != null and fish.is_selectable():
				candidates.append(fish)
	var anchor_index: int = int(board.get("schedule_anchor_index", -1))
	var allow_weather_jobs: bool = (
		JobCatalog.WEATHER_SEGMENT_COUNT - anchor_index >= 2
	)
	var jobs: Array[Dictionary] = JobCatalog.generate_daily_jobs(
		plan_id, candidates, allow_weather_jobs
	)
	var schedule: Array[Dictionary] = JobCatalog.generate_weather_schedule(
		plan_id, jobs, anchor_index
	)
	return (
		board.get("jobs", []) == jobs
		and board.get("weather_schedule", []) == schedule
	)


func _current_weather_segment() -> int:
	if _world_time == null:
		return 0
	var elapsed_hours: float = fposmod(
		_world_time.get_time_hours() - WorldTimeService.DAY_START_HOUR,
		WorldTimeService.HOURS_PER_DAY,
	)
	return clampi(
		floori(elapsed_hours / JobCatalog.WEATHER_SEGMENT_HOURS),
		0,
		JobCatalog.WEATHER_SEGMENT_COUNT - 1,
	)


static func _daily_claim_id(
	plan_id: String,
	job_id: String,
) -> String:
	return "%s/%s" % [plan_id, job_id]


static func _crossed_daily_refresh(previous: float, current: float) -> bool:
	if current >= previous:
		return previous < DAILY_REFRESH_HOUR and current >= DAILY_REFRESH_HOUR
	return (
		previous < DAILY_REFRESH_HOUR
		or current >= DAILY_REFRESH_HOUR
	)


static func _valid_string_array(values: Array, maximum_length: int) -> bool:
	var seen: Dictionary[String, bool] = {}
	for value: Variant in values:
		if typeof(value) != TYPE_STRING:
			return false
		var text: String = str(value)
		if text.is_empty() or text.length() > maximum_length or seen.has(text):
			return false
		seen[text] = true
	return true


static func _valid_reward(value: Variant) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false
	var reward: Dictionary = value
	return (
		typeof(reward.get("claim_id")) == TYPE_STRING
		and not str(reward.get("claim_id", "")).is_empty()
		and str(reward.get("claim_id", "")).length() <= 196
		and typeof(reward.get("source_plan_id")) == TYPE_STRING
		and not str(reward.get("source_plan_id", "")).is_empty()
		and str(reward.get("source_plan_id", "")).length() <= 96
		and typeof(reward.get("source_job_id")) == TYPE_STRING
		and not str(reward.get("source_job_id", "")).is_empty()
		and str(reward.get("source_job_id", "")).length() <= 96
		and typeof(reward.get("title")) == TYPE_STRING
		and str(reward.get("title", "")).length() <= 96
		and JobCatalog.is_bounded_integer(
			reward.get("fish_coin"), 0, JobCatalog.MAX_JOB_REWARD_COINS
		)
		and JobCatalog.is_bounded_integer(
			reward.get("experience"),
			0,
			JobCatalog.MAX_JOB_REWARD_EXPERIENCE,
		)
	)
