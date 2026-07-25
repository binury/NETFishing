class_name GameUI
extends CanvasLayer

const FishInventoryType = preload("res://inventory/fish_inventory.gd")
const FishingSpotType = preload("res://fishing/fishing_spot.gd")

@onready var _status_label: Label = %StatusLabel
@onready var _bluegill_count_label: Label = %BluegillCountLabel
@onready var _reel_progress: ProgressBar = %ReelProgress


func setup(inventory: FishInventoryType, fishing_spot: FishingSpotType) -> void:
	inventory.contents_changed.connect(_on_inventory_contents_changed)
	fishing_spot.status_changed.connect(_on_fishing_status_changed)
	fishing_spot.reel_progress_changed.connect(_on_reel_progress_changed)
	_update_bluegill_count(inventory.get_count(&"bluegill"))


func _on_inventory_contents_changed(fish_id: StringName, count: int) -> void:
	if fish_id == &"bluegill":
		_update_bluegill_count(count)


func _on_fishing_status_changed(status: String) -> void:
	_status_label.text = status
	_status_label.visible = not status.is_empty()


func _on_reel_progress_changed(progress: float, visible: bool) -> void:
	_reel_progress.value = progress * 100.0
	_reel_progress.visible = visible


func _update_bluegill_count(count: int) -> void:
	_bluegill_count_label.text = "Bluegill: %d" % count
