class_name WaterType
extends RefCounted

enum Type {
	FRESH_WATER,
	SALT_WATER,
	OTHER,
}

const FRESH_WATER_MASK := 1 << Type.FRESH_WATER
const SALT_WATER_MASK := 1 << Type.SALT_WATER
const ALL_FISHABLE_MASK := FRESH_WATER_MASK | SALT_WATER_MASK


static func mask_for(type: Type) -> int:
	return 1 << int(type) if type != Type.OTHER else 0


static func label(type: Type) -> String:
	match type:
		Type.FRESH_WATER:
			return "Fresh Water"
		Type.SALT_WATER:
			return "Salt Water"
		_:
			return "Other"
