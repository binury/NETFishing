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
	LURE,
}

@export var item_id: StringName
@export var display_name: String
@export_multiline var description: String
@export_category("Developer Catalog")
## Inactive items remain resolvable for existing saves, but cannot be newly
## acquired, equipped, used, or presented in shops.
@export var active: bool = true
@export_category("Item")
@export var category: Category = Category.UTILITY
@export var bait_tags: Array[StringName] = []
@export var lure_effects: Array[StringName] = []
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


func is_available() -> bool:
	return active and is_valid()


func get_category_name() -> String:
	return Category.keys()[category].to_lower()


func is_bait() -> bool:
	return category == Category.BAIT and not bait_tags.is_empty()


func is_lure() -> bool:
	return category == Category.LURE and equippable
