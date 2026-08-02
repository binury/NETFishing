class_name LogbookCatalog
extends RefCounted

const FishDataType = preload("res://fish/fish_data.gd")

# Catalog numbers are a presentation contract. Add future species deliberately;
# filtering and display order must not redefine an existing number.
const CATALOG_ORDER: Array[StringName] = [
	&"bluegill",
	&"bass",
	&"carp",
	&"sunfish",
	&"catfish_blue",
	&"catfish_channel",
	&"catfish_flathead",
	&"catfish_white",
]

# Short presentation notes are kept here with the catalog contract rather
# than mixed into gameplay balance resources. Add facts deliberately when a
# species joins the catalog.
const FISH_FACTS: Dictionary[StringName, String] = {
	&"bluegill": (
		"bluegill fathers sweep shallow bowls into the bottom for nests, "
		+ "then stand guard. whole neighborhoods of nests can crowd together."
	),
	&"bass": (
		"striped bass split their lives between salt and fresh water, "
		+ "returning upriver to spawn. a long-lived striper may see three decades."
	),
	&"carp": (
		"whisker-like barbels help a common carp investigate the bottom. "
		+ "nosing through sediment can cloud the water and loosen plants."
	),
	&"sunfish": (
		"ocean sunfish are built more like enormous swimming heads than "
		+ "ordinary fish. they visit the surface and turn sideways to warm up."
	),
	&"catfish_blue": (
		"a deep fork in the tail inspired the blue catfish's scientific "
		+ "name. it rests deep by daylight and becomes more active after dark."
	),
	&"catfish_channel": (
		"a channel catfish can taste through skin all over its body, "
		+ "especially near its gills and whiskers. the male watches the eggs."
	),
	&"catfish_flathead": (
		"flatheads favor hideouts made by logs, rocks, ledges, and other "
		+ "underwater structure. as they grow, fish dominate their menu."
	),
	&"catfish_white": (
		"white catfish began along the atlantic coast between new york "
		+ "and florida. people later carried them far beyond that home range."
	),
}

static func category_for(fish: FishDataType) -> WaterType.Type:
	if fish == null:
		return WaterType.Type.OTHER
	return fish.get_primary_water_type()


static func category_label(category: WaterType.Type) -> String:
	return WaterType.label(category)


static func empty_state(category: WaterType.Type) -> String:
	match category:
		WaterType.Type.FRESH_WATER:
			return "No freshwater catches cataloged yet."
		WaterType.Type.SALT_WATER:
			return "No saltwater catches cataloged yet."
		_:
			return "No entries available."


static func catalog_number(fish_id: StringName) -> int:
	var index: int = CATALOG_ORDER.find(fish_id)
	return index + 1 if index >= 0 else 0


static func facts_for(fish_id: StringName) -> String:
	return str(FISH_FACTS.get(fish_id, "unknown"))


static func ordered_species(
	candidates: Array[FishDataType],
) -> Array[FishDataType]:
	var by_id: Dictionary[StringName, FishDataType] = {}
	for fish: FishDataType in candidates:
		if fish != null and not fish.id.is_empty():
			by_id[fish.id] = fish
	var ordered: Array[FishDataType] = []
	for fish_id: StringName in CATALOG_ORDER:
		if by_id.has(fish_id):
			ordered.append(by_id[fish_id])
	return ordered
