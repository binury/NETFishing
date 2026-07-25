class_name UIPalette
extends RefCounted

const PRIMARY := Color("35b9c7")
const SECONDARY := Color("ffd166")
const SUCCESS := Color("46c878")
const WARNING := Color("ffb347")
const DANGER := Color("ef5b62")
const TEXT := Color("f4f7f8")
const MUTED_TEXT := Color("aebbc2")
const DISABLED := Color("66747b")
const PANEL := Color("19313a")
const ELEVATED_PANEL := Color("244550")

const RARITY_COMMON := Color("e8eef0")
const RARITY_UNCOMMON := Color("58d279")
const RARITY_RARE := Color("5596f6")
const RARITY_EPIC := Color("b176e8")
const RARITY_LEGENDARY := Color("f276b3")


static func get_rarity_color(rarity: int) -> Color:
	match rarity:
		1:
			return RARITY_UNCOMMON
		2:
			return RARITY_RARE
		3:
			return RARITY_EPIC
		4:
			return RARITY_LEGENDARY
		_:
			return RARITY_COMMON
