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
	&"anchovy_european",
	&"anchovy_northern",
	&"chub_european",
	&"chub_flame",
	&"chub_lake",
	&"goldfish",
	&"goldfish_bubbleeye",
	&"grouper_gulf",
	&"grouper_red",
	&"mackerel_atlantic",
	&"mackerel_cero",
	&"mackerel_chub",
	&"mackerel_king",
	&"mackerel_spanish",
	&"marlin_black",
	&"marlin_blue",
	&"marlin_white",
	&"pomfret_black",
	&"pomfret_chinese",
	&"pomfret_golden",
	&"pomfret_white",
	&"sailfish",
	&"sauger",
	&"saugeye",
	&"snapper_lane",
	&"snapper_mangrove",
	&"snapper_mutton",
	&"snapper_red",
	&"swordfish",
	&"trout_cutthroat",
	&"trout_golden",
	&"trout_rainbow",
	&"trout_steelhead",
	&"walleye",
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
	&"anchovy_european": (
		"european anchovies form dense schools and feed by filtering tiny "
		+ "plankton from coastal water."
	),
	&"anchovy_northern": (
		"northern anchovies gather in huge schools along the pacific coast "
		+ "and filter plankton with their fine gill rakers."
	),
	&"chub_european": (
		"european chub are adaptable river fish. adults often patrol "
		+ "shallows and feed on insects, small fish, and fruit."
	),
	&"chub_flame": (
		"flame chubs prefer cool, clear streams. their bright breeding colors "
		+ "make a small fish easy to spot in spring water."
	),
	&"chub_lake": (
		"lake chubs school in cold northern water and use their small mouths "
		+ "to pick insects and other tiny prey from the current."
	),
	&"goldfish": (
		"goldfish can tolerate a surprisingly wide range of conditions. "
		+ "their wild relatives often live in slow, weedy water."
	),
	&"goldfish_bubbleeye": (
		"bubble-eye goldfish have delicate fluid-filled sacs beneath their "
		+ "eyes, making careful handling especially important."
	),
	&"grouper_gulf": (
		"gulf grouper are ambush predators that use a sudden gulp to pull "
		+ "prey into their cavernous mouths."
	),
	&"grouper_red": (
		"red grouper excavate shelters in reef rubble. the hollows they make "
		+ "can become hiding places for many smaller animals."
	),
	&"mackerel_atlantic": (
		"atlantic mackerel travel in fast schools across the north atlantic "
		+ "and feed on plankton and small schooling fish."
	),
	&"mackerel_cero": (
		"cero mackerel are streamlined coastal hunters. sharp teeth help "
		+ "them slash through schools of smaller fish."
	),
	&"mackerel_chub": (
		"chub mackerel school near the surface and follow plankton blooms. "
		+ "their dark wavy bars help identify them at a glance."
	),
	&"mackerel_king": (
		"king mackerel are swift coastal predators. their pointed teeth and "
		+ "long body are built for sudden bursts of speed."
	),
	&"mackerel_spanish": (
		"spanish mackerel hunt in warm coastal waters and often travel in "
		+ "loose schools while chasing baitfish."
	),
	&"marlin_black": (
		"black marlin are powerful billfish that spend much of their lives "
		+ "in warm open ocean and can make blistering runs."
	),
	&"marlin_blue": (
		"blue marlin are highly migratory open-ocean hunters. their long bill "
		+ "helps them stun prey before turning back to feed."
	),
	&"marlin_white": (
		"white marlin favor warm offshore water and use their rounded dorsal "
		+ "fin and bill to weave through schools of prey."
	),
	&"pomfret_black": (
		"black pomfret have a deep, laterally compressed body that lets them "
		+ "maneuver neatly through open water."
	),
	&"pomfret_chinese": (
		"chinese pomfret are silvery schooling fish with a tall, flattened "
		+ "body and long sickle-shaped fins."
	),
	&"pomfret_golden": (
		"golden pomfret are warm-water swimmers whose golden sheen is most "
		+ "noticeable along the fins and flanks."
	),
	&"pomfret_white": (
		"white pomfret gather over coastal grounds and use their compact, "
		+ "deep bodies to turn quickly while feeding."
	),
	&"sailfish": (
		"sailfish raise their enormous dorsal fin while herding baitfish. "
		+ "they are among the fastest fish in the sea."
	),
	&"sauger": (
		"sauger favor turbid rivers and reservoirs. their mottled backs "
		+ "blend into the dim, shifting light near the bottom."
	),
	&"saugeye": (
		"saugeye are a fertile hybrid of sauger and walleye. they combine "
		+ "traits from both parent species and often grow quickly."
	),
	&"snapper_lane": (
		"lane snapper use reef structure for cover and hunt small crustaceans "
		+ "and fish when the light begins to fade."
	),
	&"snapper_mangrove": (
		"mangrove snapper shelter among roots and docks when young, then "
		+ "move toward reefs as they grow."
	),
	&"snapper_mutton": (
		"mutton snapper have canine teeth that help them pick crabs, shrimp, "
		+ "and other hard-shelled prey from the reef."
	),
	&"snapper_red": (
		"red snapper gather around reefs, wrecks, and ledges. their diet "
		+ "includes small fish, shrimp, and squid."
	),
	&"swordfish": (
		"swordfish are fast, wide-ranging predators with a flattened bill. "
		+ "they can cross deep water and warm surface layers in one day."
	),
	&"trout_cutthroat": (
		"cutthroat trout take their name from the red slash beneath the jaw. "
		+ "many populations rely on cold, well-oxygenated streams."
	),
	&"trout_golden": (
		"golden trout evolved in clear, high-elevation california streams. "
		+ "their bright flanks stand out against rocky alpine water."
	),
	&"trout_rainbow": (
		"rainbow trout are adaptable stream hunters. the pink lateral stripe "
		+ "is especially vivid when the fish is in breeding condition."
	),
	&"trout_steelhead": (
		"steelhead are the ocean-going form of rainbow trout. adults can "
		+ "leave fresh water and later return to spawn."
	),
	&"walleye": (
		"walleye have light-sensitive eyes that help them hunt in murky water "
		+ "and around dusk. their reflective layer gives the eyes a pale glow."
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
