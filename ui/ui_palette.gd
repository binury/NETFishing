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

const QUALITY_BORING := Color("e8eef0")
const QUALITY_AVERAGE := Color("64c87c")
const QUALITY_IMPRESSIVE := Color("6098dd")
const QUALITY_EXCEPTIONAL := Color("a979cf")
const QUALITY_SHINY := Color("db78a7")


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


static func get_quality_color(quality: int) -> Color:
	match quality:
		1:
			return QUALITY_AVERAGE
		2:
			return QUALITY_IMPRESSIVE
		3:
			return QUALITY_EXCEPTIONAL
		4:
			return QUALITY_SHINY
		_:
			return QUALITY_BORING
