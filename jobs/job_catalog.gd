class_name JobCatalog
extends RefCounted

const FishDataType = preload("res://fish/fish_data.gd")

enum Kind {
	CATCH_TOTAL,
	CATCH_WATER,
	SELL_TOTAL,
	CATCH_QUALITY,
	CATCH_PHASE,
	CATCH_WEATHER,
	CATCH_SPECIES,
	REACH_LEVEL,
	DISCOVER_SPECIES,
	MASTER_QUALITIES,
	CATCH_CREATURE_GROUP,
	DISCOVER_CREATURE_GROUP,
	MASTER_CREATURE_GROUP,
}

const DAILY_JOB_COUNT: int = 4
const WEATHER_SEGMENT_HOURS: float = (
	WorldWeatherService.DAILY_PLAN_SEGMENT_HOURS
)
const WEATHER_SEGMENT_COUNT: int = (
	WorldWeatherService.DAILY_PLAN_SEGMENT_COUNT
)
const LEGACY_WEATHER_SEGMENT_HOURS: float = 2.0
const LEGACY_WEATHER_SEGMENT_COUNT: int = 12
const MAX_JOB_REWARD_COINS: int = 100000
const MAX_JOB_REWARD_EXPERIENCE: int = 10000


static func generate_daily_jobs(
	plan_id: String,
	candidates: Array[FishDataType],
	allow_weather_jobs: bool = true,
) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = plan_id.hash()
	var jobs: Array[Dictionary] = [
		_job(
			"fresh_catches",
			"fresh catch delivery",
			"catch 5 fresh water fish",
			Kind.CATCH_WATER,
			5,
			35,
			50,
			{"water_type": int(WaterType.Type.FRESH_WATER)},
		),
		_job(
			"sell_fish",
			"market supply",
			"sell 5 fish",
			Kind.SELL_TOTAL,
			5,
			40,
			50,
		),
	]
	var optional: Array[Dictionary] = [
		_job(
			"quality_catch",
			"quality check",
			"catch an impressive fish or better",
			Kind.CATCH_QUALITY,
			1,
			55,
			75,
			{"minimum_quality": int(FishQuality.Tier.IMPRESSIVE)},
		),
		_job(
			"night_catch",
			"night shift",
			"catch 3 fish at night",
			Kind.CATCH_PHASE,
			3,
			35,
			50,
			{"phase": int(WorldTimeService.Phase.NIGHT)},
		),
	]
	if allow_weather_jobs:
		optional.append(_job(
			"fog_catch",
			"through the fog",
			"catch 2 fish in foggy weather",
			Kind.CATCH_WEATHER,
			2,
			65,
			75,
			{"weather": int(WorldWeatherService.Weather.FOGGY)},
		))
	var species: Array[FishDataType] = []
	for fish: FishDataType in candidates:
		if fish != null and fish.is_fishable():
			species.append(fish)
	if not species.is_empty():
		species.sort_custom(
			func(a: FishDataType, b: FishDataType) -> bool:
				return String(a.id) < String(b.id)
		)
		var species_index: int = rng.randi_range(0, species.size() - 1)
		var selected: FishDataType = species[species_index]
		optional.append(_job(
			"species_%s" % String(selected.id),
			"specific request",
			"catch 3 %s" % selected.display_name.to_lower(),
			Kind.CATCH_SPECIES,
			3,
			45,
			50,
			{"fish_id": String(selected.id)},
		))
	if _has_creature_group(candidates, FishDataType.CreatureGroup.INSECT):
		optional.append(_job(
			"insect_roundup",
			"bug hunt",
			"catch 3 insects",
			Kind.CATCH_CREATURE_GROUP,
			3,
			40,
			50,
			{"creature_group": int(FishDataType.CreatureGroup.INSECT)},
		))
	if _has_creature_group(candidates, FishDataType.CreatureGroup.SHELLFISH):
		optional.append(_job(
			"shellfish_search",
			"shore patrol",
			"catch 3 shellfish",
			Kind.CATCH_CREATURE_GROUP,
			3,
			45,
			50,
			{"creature_group": int(FishDataType.CreatureGroup.SHELLFISH)},
		))
	_shuffle(optional, rng)
	while jobs.size() < DAILY_JOB_COUNT and not optional.is_empty():
		jobs.append(optional.pop_back())
	return jobs


static func generate_weather_schedule(
	plan_id: String,
	jobs: Array[Dictionary],
	anchor_index: int = 0,
) -> Array[Dictionary]:
	anchor_index = clampi(anchor_index, 0, WEATHER_SEGMENT_COUNT - 1)
	var required: Array[int] = []
	for job: Dictionary in jobs:
		if int(job.get("kind", -1)) != Kind.CATCH_WEATHER:
			continue
		var weather: int = int(job.get("weather", -1))
		if WorldWeatherService.is_valid_weather(weather) and weather not in required:
			required.append(weather)
	var rng := RandomNumberGenerator.new()
	rng.seed = plan_id.hash() ^ 0x57454154
	var weather_values: Array[int] = []
	for index: int in WEATHER_SEGMENT_COUNT:
		var roll: float = rng.randf()
		var weather: int = int(WorldWeatherService.Weather.SUNNY)
		if roll >= 0.42 and roll < 0.70:
			weather = int(WorldWeatherService.Weather.CLOUDY)
		elif roll >= 0.70 and roll < 0.88:
			weather = int(WorldWeatherService.Weather.RAINY)
		elif roll >= 0.88:
			weather = int(WorldWeatherService.Weather.FOGGY)
		weather_values.append(weather)
	for requirement_index: int in required.size():
		var early_index: int = mini(
			anchor_index + requirement_index,
			WEATHER_SEGMENT_COUNT - 2,
		)
		var remaining_segments: int = WEATHER_SEGMENT_COUNT - early_index
		var later_index: int = mini(
			early_index + maxi(
				1, floori(float(remaining_segments) / 2.0)
			),
			WEATHER_SEGMENT_COUNT - 1,
		)
		weather_values[early_index] = required[requirement_index]
		weather_values[later_index] = required[requirement_index]
	var schedule: Array[Dictionary] = []
	for index: int in WEATHER_SEGMENT_COUNT:
		schedule.append({
			"start_hour": fposmod(
				WorldTimeService.DAY_START_HOUR
				+ float(index) * WEATHER_SEGMENT_HOURS,
				WorldTimeService.HOURS_PER_DAY,
			),
			"weather": weather_values[index],
		})
	return schedule


static func lifetime_chains(
	registered_species_count: int,
	registered_insect_count: int = 0,
	registered_shellfish_count: int = 0,
) -> Array[Dictionary]:
	var chains: Array[Dictionary] = [
		_chain("catch", Kind.CATCH_TOTAL, [100, 1000, 5000], [
			[150, 250], [700, 1000], [2500, 3000],
		]),
		_chain("sell", Kind.SELL_TOTAL, [50, 500, 2500], [
			[125, 200], [600, 800], [2200, 2400],
		]),
		_chain("level", Kind.REACH_LEVEL, [5, 10, 25, 50], [
			[100, 150], [250, 350], [1000, 1200], [3000, 3500],
		]),
	]
	if registered_species_count > 0:
		chains.append(_chain(
			"discover",
			Kind.DISCOVER_SPECIES,
			[registered_species_count],
			[[500, 750]],
		))
		chains.append(_chain(
			"master",
			Kind.MASTER_QUALITIES,
			[registered_species_count],
			[[1500, 2000]],
		))
	_append_creature_lifetime_chains(
		chains,
		"insect",
		FishDataType.CreatureGroup.INSECT,
		registered_insect_count,
	)
	_append_creature_lifetime_chains(
		chains,
		"shellfish",
		FishDataType.CreatureGroup.SHELLFISH,
		registered_shellfish_count,
	)
	return chains


static func visible_lifetime_jobs(
	registered_species_count: int,
	claimed_ids: Array[String],
	registered_insect_count: int = 0,
	registered_shellfish_count: int = 0,
) -> Array[Dictionary]:
	var visible: Array[Dictionary] = []
	for chain: Dictionary in lifetime_chains(
		registered_species_count,
		registered_insect_count,
		registered_shellfish_count,
	):
		var targets: Array = chain.get("targets", [])
		var rewards: Array = chain.get("rewards", [])
		for tier_index: int in targets.size():
			var job_id: String = "%s_%d" % [
				str(chain.get("id", "")),
				int(targets[tier_index]),
			]
			if job_id in claimed_ids:
				continue
			var reward: Array = rewards[tier_index]
			var extra: Dictionary = {}
			if chain.has("creature_group"):
				extra["creature_group"] = int(chain["creature_group"])
			visible.append(_job(
				job_id,
				_lifetime_title(str(chain.get("id", "")), int(targets[tier_index])),
				_lifetime_description(
					str(chain.get("id", "")), int(targets[tier_index])
				),
				int(chain.get("kind", Kind.CATCH_TOTAL)) as Kind,
				int(targets[tier_index]),
				int(reward[0]),
				int(reward[1]),
				extra,
			))
			break
	return visible


static func weather_requirements(jobs: Array[Dictionary]) -> Array[int]:
	var result: Array[int] = []
	for job: Dictionary in jobs:
		if int(job.get("kind", -1)) != Kind.CATCH_WEATHER:
			continue
		var weather: int = int(job.get("weather", -1))
		if WorldWeatherService.is_valid_weather(weather) and weather not in result:
			result.append(weather)
	return result


static func is_valid_job(value: Variant) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false
	var job: Dictionary = value
	var kind: int = int(job.get("kind", -1))
	if not (
		typeof(job.get("id")) == TYPE_STRING
		and not str(job["id"]).is_empty()
		and str(job["id"]).length() <= 96
		and typeof(job.get("title")) == TYPE_STRING
		and str(job["title"]).length() <= 96
		and typeof(job.get("description")) == TYPE_STRING
		and str(job["description"]).length() <= 160
		and is_bounded_integer(
			job.get("kind"), Kind.CATCH_TOTAL, Kind.MASTER_CREATURE_GROUP
		)
		and kind >= Kind.CATCH_TOTAL
		and kind <= Kind.MASTER_CREATURE_GROUP
		and is_bounded_integer(job.get("target"), 1, 1000000000)
		and is_bounded_integer(
			job.get("fish_coin"), 0, MAX_JOB_REWARD_COINS
		)
		and is_bounded_integer(
			job.get("experience"), 0, MAX_JOB_REWARD_EXPERIENCE
		)
	):
		return false
	match kind:
		Kind.CATCH_WATER:
			var water_type: int = int(job.get("water_type", -1))
			return (
				is_bounded_integer(
					job.get("water_type"),
					WaterType.Type.FRESH_WATER,
					WaterType.Type.OTHER,
				)
				and water_type >= WaterType.Type.FRESH_WATER
				and water_type <= WaterType.Type.OTHER
			)
		Kind.CATCH_QUALITY:
			return (
				is_bounded_integer(
					job.get("minimum_quality"),
					FishQuality.Tier.BORING,
					FishQuality.Tier.SHINY,
				)
				and FishQuality.is_valid(int(job.get("minimum_quality", -1)))
			)
		Kind.CATCH_PHASE:
			var phase: int = int(job.get("phase", -1))
			return (
				is_bounded_integer(
					job.get("phase"),
					WorldTimeService.Phase.DAWN,
					WorldTimeService.Phase.NIGHT,
				)
				and phase >= WorldTimeService.Phase.DAWN
				and phase <= WorldTimeService.Phase.NIGHT
			)
		Kind.CATCH_WEATHER:
			return (
				is_bounded_integer(
					job.get("weather"),
					WorldWeatherService.Weather.SUNNY,
					WorldWeatherService.Weather.FOGGY,
				)
				and WorldWeatherService.is_valid_weather(
					int(job.get("weather", -1))
				)
			)
		Kind.CATCH_SPECIES:
			return (
				typeof(job.get("fish_id")) == TYPE_STRING
				and not str(job.get("fish_id", "")).is_empty()
				and str(job.get("fish_id", "")).length() <= 96
			)
		Kind.CATCH_CREATURE_GROUP, Kind.DISCOVER_CREATURE_GROUP, Kind.MASTER_CREATURE_GROUP:
			return is_bounded_integer(
				job.get("creature_group"),
				FishDataType.CreatureGroup.FISH,
				FishDataType.CreatureGroup.SHELLFISH,
			)
	return true


static func is_bounded_integer(
	value: Variant,
	minimum: int,
	maximum: int,
) -> bool:
	if typeof(value) == TYPE_INT:
		return int(value) >= minimum and int(value) <= maximum
	if typeof(value) != TYPE_FLOAT:
		return false
	var number: float = float(value)
	return (
		is_finite(number)
		and number >= float(minimum)
		and number <= float(maximum)
		and is_equal_approx(number, round(number))
	)


static func is_valid_weather_schedule(value: Variant) -> bool:
	return WorldWeatherService.is_valid_daily_plan_schedule(value)


static func is_valid_legacy_weather_schedule(value: Variant) -> bool:
	if typeof(value) != TYPE_ARRAY:
		return false
	var schedule: Array = value
	if schedule.size() != LEGACY_WEATHER_SEGMENT_COUNT:
		return false
	for index: int in schedule.size():
		if typeof(schedule[index]) != TYPE_DICTIONARY:
			return false
		var entry: Dictionary = schedule[index]
		var expected_hour: float = fposmod(
			WorldTimeService.DAY_START_HOUR
				+ float(index) * LEGACY_WEATHER_SEGMENT_HOURS,
			WorldTimeService.HOURS_PER_DAY,
		)
		if (
			typeof(entry.get("start_hour")) not in [TYPE_FLOAT, TYPE_INT]
			or not is_equal_approx(
				float(entry.get("start_hour", -1.0)), expected_hour
			)
			or not is_bounded_integer(
				entry.get("weather"),
				WorldWeatherService.Weather.SUNNY,
				WorldWeatherService.Weather.FOGGY,
			)
		):
			return false
	return true


static func _job(
	id: String,
	title: String,
	description: String,
	kind: Kind,
	target: int,
	fish_coin: int,
	experience: int,
	extra: Dictionary = {},
) -> Dictionary:
	var result: Dictionary = {
		"id": id,
		"title": title,
		"description": description,
		"kind": int(kind),
		"target": target,
		"fish_coin": fish_coin,
		"experience": experience,
	}
	result.merge(extra, true)
	return result


static func _chain(
	id: String,
	kind: Kind,
	targets: Array[int],
	rewards: Array,
	extra: Dictionary = {},
) -> Dictionary:
	var result: Dictionary = {
		"id": id,
		"kind": int(kind),
		"targets": targets,
		"rewards": rewards,
	}
	result.merge(extra, true)
	return result


static func _lifetime_title(chain_id: String, target: int) -> String:
	match chain_id:
		"catch":
			return "seasoned angler"
		"sell":
			return "market regular"
		"level":
			return "reach level %d" % target
		"discover":
			return "complete the catalog"
		"master":
			return "quality master"
		"insect_catch":
			return "seasoned bug catcher"
		"insect_discover":
			return "complete the insect catalog"
		"insect_master":
			return "insect quality master"
		"shellfish_catch":
			return "seasoned beachcomber"
		"shellfish_discover":
			return "complete the shellfish catalog"
		"shellfish_master":
			return "shellfish quality master"
	return "long-term job"


static func _lifetime_description(chain_id: String, target: int) -> String:
	match chain_id:
		"catch":
			return "catch %d fish" % target
		"sell":
			return "sell %d fish" % target
		"level":
			return "reach player level %d" % target
		"discover":
			return "discover all %d cataloged fish" % target
		"master":
			return "collect every quality of all %d fish" % target
		"insect_catch":
			return "catch %d insects" % target
		"insect_discover":
			return "discover all %d cataloged insects" % target
		"insect_master":
			return "collect every quality of all %d insects" % target
		"shellfish_catch":
			return "catch %d shellfish" % target
		"shellfish_discover":
			return "discover all %d cataloged shellfish" % target
		"shellfish_master":
			return "collect every quality of all %d shellfish" % target
	return "keep fishing"


static func _has_creature_group(
	candidates: Array[FishDataType],
	creature_group: FishDataType.CreatureGroup,
) -> bool:
	for fish: FishDataType in candidates:
		if (
			fish != null
			and fish.is_selectable()
			and fish.get_creature_group() == creature_group
		):
			return true
	return false


static func _append_creature_lifetime_chains(
	chains: Array[Dictionary],
	id_prefix: String,
	creature_group: FishDataType.CreatureGroup,
	registered_count: int,
) -> void:
	if registered_count <= 0:
		return
	var group_data := {"creature_group": int(creature_group)}
	chains.append(_chain(
		"%s_catch" % id_prefix,
		Kind.CATCH_CREATURE_GROUP,
		[10, 50, 250],
		[[75, 100], [250, 350], [900, 1100]],
		group_data,
	))
	chains.append(_chain(
		"%s_discover" % id_prefix,
		Kind.DISCOVER_CREATURE_GROUP,
		[registered_count],
		[[250, 350]],
		group_data,
	))
	chains.append(_chain(
		"%s_master" % id_prefix,
		Kind.MASTER_CREATURE_GROUP,
		[registered_count],
		[[750, 1000]],
		group_data,
	))


static func _shuffle(values: Array[Dictionary], rng: RandomNumberGenerator) -> void:
	for index: int in range(values.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var value: Dictionary = values[index]
		values[index] = values[swap_index]
		values[swap_index] = value
