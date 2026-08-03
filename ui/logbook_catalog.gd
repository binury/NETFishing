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
	&"tuna_albacore",
	&"tuna_bigeye",
	&"tuna_bluefin",
	&"tuna_skipjack",
	&"tuna_yellowfin",
	&"goby_round",
	&"salmon_atlantic",
	&"salmon_chum",
	&"salmon_coho",
	&"salmon_pink",
	&"salmon_sockeye",
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
	&"tuna_albacore": (
		"albacore have unusually long pectoral fins. their warm muscles help "
		+ "them cruise across wide stretches of open ocean."
	),
	&"tuna_bigeye": (
		"bigeye tuna make daily trips between deep, cool water and warmer "
		+ "surface layers. their large eyes suit those dim depths."
	),
	&"tuna_bluefin": (
		"bluefin tuna are powerful ocean travelers. heat retained in their "
		+ "swimming muscles lets them thrive in surprisingly cold seas."
	),
	&"tuna_skipjack": (
		"skipjack travel in fast-moving schools and have dark stripes along "
		+ "their lower sides. they rarely stop swimming."
	),
	&"tuna_yellowfin": (
		"yellowfin are named for their bright yellow fins and finlets. large "
		+ "schools often gather with other open-ocean hunters."
	),
	&"goby_round": (
		"round gobies use fused pelvic fins like a suction cup to hold onto "
		+ "rocks. they are small fish with a famously large appetite."
	),
	&"salmon_atlantic": (
		"atlantic salmon can return from the ocean to the river where they "
		+ "hatched. unlike many salmon, some survive to make the trip again."
	),
	&"salmon_chum": (
		"chum salmon travel immense distances and develop striking bars when "
		+ "they return to fresh water to spawn."
	),
	&"salmon_coho": (
		"coho salmon are agile hunters known for powerful leaps. young coho "
		+ "may spend more than a year growing in streams."
	),
	&"salmon_pink": (
		"pink salmon usually follow a strict two-year life cycle. spawning "
		+ "males develop the hump that inspired their nickname."
	),
	&"salmon_sockeye": (
		"sockeye salmon feed heavily on plankton at sea. adults turn vivid red "
		+ "as they return inland to spawn."
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
