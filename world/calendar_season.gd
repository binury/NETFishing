class_name CalendarSeason
extends RefCounted

enum Season {
	SPRING,
	SUMMER,
	FALL,
	WINTER,
}

const UNKNOWN: int = -1
const SPRING_MASK: int = 1 << Season.SPRING
const SUMMER_MASK: int = 1 << Season.SUMMER
const FALL_MASK: int = 1 << Season.FALL
const WINTER_MASK: int = 1 << Season.WINTER
const ALL_MASK: int = (
	SPRING_MASK | SUMMER_MASK | FALL_MASK | WINTER_MASK
)
const NAMES: Array[String] = [
	"spring",
	"summer",
	"fall",
	"winter",
]


static func from_date_id(date_id: String) -> int:
	if (
		date_id.length() != 10
		or date_id[4] != "-"
		or date_id[7] != "-"
	):
		return UNKNOWN
	var month_text: String = date_id.substr(5, 2)
	if not month_text.is_valid_int():
		return UNKNOWN
	return from_month(int(month_text))


static func from_month(month: int) -> int:
	match month:
		3, 4, 5:
			return Season.SPRING
		6, 7, 8:
			return Season.SUMMER
		9, 10, 11:
			return Season.FALL
		12, 1, 2:
			return Season.WINTER
		_:
			return UNKNOWN


static func mask_for(season: int) -> int:
	if season < 0 or season >= Season.size():
		return 0
	return 1 << season


static func is_valid_mask(mask: int) -> bool:
	return mask > 0 and (mask & ~ALL_MASK) == 0


static func includes(mask: int, season: int) -> bool:
	if season == UNKNOWN:
		return true
	return is_valid_mask(mask) and (mask & mask_for(season)) != 0


static func names_for_mask(mask: int) -> Array[String]:
	var names: Array[String] = []
	for season: int in Season.size():
		if includes(mask, season):
			names.append(NAMES[season])
	return names


static func format_mask(mask: int) -> String:
	if mask == ALL_MASK:
		return "year-round"
	var names: Array[String] = names_for_mask(mask)
	return ", ".join(names) if not names.is_empty() else "unavailable"
