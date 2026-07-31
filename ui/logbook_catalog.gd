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
