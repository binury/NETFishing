class_name EmoteRadialMenu
extends RadialActionMenu

signal emote_selected(emote_id: StringName)

const SECTOR_COUNT: int = 8
const SIT_SECTOR: int = 0


func _input_action_name() -> StringName:
	return &"open_emotes"


func _sector_count() -> int:
	return SECTOR_COUNT


func _initial_sector() -> int:
	return SIT_SECTOR


func _label_for_sector(sector: int) -> String:
	return "Sit" if sector == SIT_SECTOR else ""


func _emit_selected_sector(sector: int) -> void:
	if sector == SIT_SECTOR:
		emote_selected.emit(&"sit")
