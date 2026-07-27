class_name ItemData
extends Resource

enum Category {
	ROD,
	TOOL,
	BAIT,
	CONSUMABLE,
	UTILITY,
	QUEST,
	COSMETIC,
}

@export var item_id: StringName
@export var display_name: String
@export_multiline var description: String
@export var category: Category = Category.UTILITY
@export var icon: Texture2D
@export var stackable: bool = false
@export_range(1, 999, 1) var max_stack: int = 1
@export var usable: bool = false
@export var equippable: bool = false
@export var hotbar_allowed: bool = false


func is_valid() -> bool:
	return (
		not item_id.is_empty()
		and not display_name.strip_edges().is_empty()
		and max_stack >= 1
		and (stackable or max_stack == 1)
	)


func get_category_name() -> String:
	return Category.keys()[category].to_lower()
