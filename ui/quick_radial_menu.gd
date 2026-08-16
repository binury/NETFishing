class_name QuickRadialMenu
extends RadialActionMenu

signal action_selected(action_id: StringName)

const ACTIONS: Array[StringName] = [
	&"chat",
	&"freecam",
	&"hud",
]
const LABELS: Array[String] = [
	"chat",
	"freecam",
	"hide hud",
]
const SECTOR_COUNT: int = 3

var _hud_hidden: bool = false


func set_hud_hidden(hidden: bool) -> void:
	_hud_hidden = hidden
	_refresh_labels()


func _input_action_name() -> StringName:
	return &"open_quick_actions"


func _sector_count() -> int:
	return SECTOR_COUNT


func _label_for_sector(sector: int) -> String:
	if ACTIONS[sector] == &"hud":
		return "show hud" if _hud_hidden else "hide hud"
	return LABELS[sector]


func _emit_selected_sector(sector: int) -> void:
	call_deferred("_emit_selected_action", ACTIONS[sector])


func _emit_selected_action(action_id: StringName) -> void:
	action_selected.emit(action_id)
