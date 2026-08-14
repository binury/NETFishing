class_name LogbookCatalog
extends RefCounted

const FishDataType = preload("res://fish/fish_data.gd")


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
