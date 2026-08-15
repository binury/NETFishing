class_name LogbookCatalog
extends RefCounted

const FishDataType = preload("res://fish/fish_data.gd")

enum Category {
	FRESH_WATER,
	SALT_WATER,
	OTHER,
	SHELLFISH,
}


static func category_for(fish: FishDataType) -> Category:
	if fish == null:
		return Category.OTHER
	if fish.logbook_section == FishDataType.LogbookSection.SHELLFISH:
		return Category.SHELLFISH
	match fish.get_primary_water_type():
		WaterType.Type.FRESH_WATER:
			return Category.FRESH_WATER
		WaterType.Type.SALT_WATER:
			return Category.SALT_WATER
		_:
			return Category.OTHER


static func category_label(category: Category) -> String:
	match category:
		Category.FRESH_WATER:
			return "Fresh Water"
		Category.SALT_WATER:
			return "Salt Water"
		Category.SHELLFISH:
			return "Shellfish"
		_:
			return "Misc"


static func empty_state(category: Category) -> String:
	match category:
		Category.FRESH_WATER:
			return "No freshwater catches cataloged yet."
		Category.SALT_WATER:
			return "No saltwater catches cataloged yet."
		Category.SHELLFISH:
			return "No shellfish cataloged yet."
		_:
			return "No entries available."


static func catalog_number(fish: FishDataType) -> int:
	return fish.catalog_number if fish != null else 0


static func facts_for(fish: FishDataType) -> String:
	if fish == null or fish.logbook_fact.strip_edges().is_empty():
		return "unknown"
	return fish.logbook_fact


static func ordered_species(
	candidates: Array[FishDataType],
) -> Array[FishDataType]:
	var ordered: Array[FishDataType] = []
	for fish: FishDataType in candidates:
		if fish != null and fish.active and not fish.id.is_empty():
			ordered.append(fish)
	ordered.sort_custom(
		func(a: FishDataType, b: FishDataType) -> bool:
			if a.catalog_number == b.catalog_number:
				return String(a.id) < String(b.id)
			return a.catalog_number < b.catalog_number
	)
	return ordered
