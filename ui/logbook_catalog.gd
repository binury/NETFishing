class_name LogbookCatalog
extends RefCounted

const FishDataType = preload("res://fish/fish_data.gd")

enum Category {
	FRESH_WATER,
	SALT_WATER,
	OTHER,
}

# Catalog numbers are a presentation contract. Add future species deliberately;
# filtering and display order must not redefine an existing number.
const CATALOG_ORDER: Array[StringName] = [
	&"bluegill",
	&"bass",
	&"carp",
	&"sunfish",
]

# These maps remain explicit until fish resources gain authored habitat fields.
const FRESH_WATER_IDS: Array[StringName] = []
const SALT_WATER_IDS: Array[StringName] = []


static func category_for(fish: FishDataType) -> Category:
	if fish == null:
		return Category.OTHER
	if fish.id in FRESH_WATER_IDS:
		return Category.FRESH_WATER
	if fish.id in SALT_WATER_IDS:
		return Category.SALT_WATER
	return Category.OTHER


static func category_label(category: Category) -> String:
	match category:
		Category.FRESH_WATER:
			return "Fresh Water"
		Category.SALT_WATER:
			return "Salt Water"
		_:
			return "Other"


static func empty_state(category: Category) -> String:
	match category:
		Category.FRESH_WATER:
			return "No freshwater catches cataloged yet."
		Category.SALT_WATER:
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
