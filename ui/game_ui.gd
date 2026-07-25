class_name GameUI
extends CanvasLayer

const FishInventoryType = preload("res://inventory/fish_inventory.gd")
const FishingSpotType = preload("res://fishing/fishing_spot.gd")

@onready var _status_label: Label = %StatusLabel
@onready var _bluegill_count_label: Label = %BluegillCountLabel
@onready var _catch_track: Control = %CatchTrack
@onready var _green_catch_progress: ProgressBar = %GreenCatchProgress
@onready var _red_chase_progress: ProgressBar = %RedChaseProgress
@onready var _barrier_markers: Control = %BarrierMarkers
@onready var _barrier_summary: Label = %BarrierSummary
@onready var _barrier_health: Label = %BarrierHealth


func setup(inventory: FishInventoryType, fishing_spot: FishingSpotType) -> void:
	inventory.contents_changed.connect(_on_inventory_contents_changed)
	fishing_spot.status_changed.connect(_on_fishing_status_changed)
	fishing_spot.catch_display_changed.connect(_on_catch_display_changed)
	_update_bluegill_count(inventory.get_count(&"bluegill"))


func _on_inventory_contents_changed(fish_id: StringName, count: int) -> void:
	if fish_id == &"bluegill":
		_update_bluegill_count(count)


func _on_fishing_status_changed(status: String) -> void:
	_status_label.text = status
	_status_label.visible = not status.is_empty()


func _on_catch_display_changed(
	progress: float,
	chase_progress: float,
	barrier_positions: PackedFloat32Array,
	barrier_health: PackedInt32Array,
	barrier_max_health: PackedInt32Array,
	active_barrier_index: int,
	visible: bool,
) -> void:
	_green_catch_progress.value = progress * 100.0
	_red_chase_progress.value = maxf(chase_progress, 0.0) * 100.0
	_catch_track.visible = visible
	_barrier_summary.visible = visible
	if not visible:
		_barrier_health.visible = false
		_clear_barrier_markers()
		_barrier_summary.text = ""
		_barrier_health.text = ""
		return

	_update_barrier_markers(
		barrier_positions,
		barrier_health,
		active_barrier_index
	)
	var barrier_labels: PackedStringArray = []
	for barrier_index: int in range(barrier_positions.size()):
		var defeated: bool = (
			barrier_index < barrier_health.size()
			and barrier_health[barrier_index] <= 0
		)
		var marker: String = "✓" if defeated else "●"
		if barrier_index == active_barrier_index:
			marker = "[%s]" % marker
		barrier_labels.append(
			"%d%% %s"
			% [roundi(barrier_positions[barrier_index] * 100.0), marker]
		)
	_barrier_summary.text = "Barriers: %s" % "  ".join(barrier_labels)

	if (
		active_barrier_index >= 0
		and active_barrier_index < barrier_health.size()
		and active_barrier_index < barrier_max_health.size()
	):
		_barrier_health.text = (
			"Barrier: %d / %d"
			% [
				barrier_health[active_barrier_index],
				barrier_max_health[active_barrier_index],
			]
		)
	else:
		_barrier_health.text = ""

	var chase_gap: float = progress - chase_progress
	if chase_gap <= 0.05:
		_barrier_health.text = (
			"%s%s"
			% [
				_barrier_health.text,
				"\nRed is closing in!",
			]
		).strip_edges()
	_barrier_health.visible = (
		visible
		and (active_barrier_index >= 0 or chase_gap <= 0.05)
	)


func _update_barrier_markers(
	positions: PackedFloat32Array,
	health: PackedInt32Array,
	active_index: int,
) -> void:
	_clear_barrier_markers()
	for barrier_index: int in range(positions.size()):
		var marker := ColorRect.new()
		var defeated: bool = (
			barrier_index < health.size()
			and health[barrier_index] <= 0
		)
		marker.color = Color(0.35, 0.38, 0.42, 0.8) if defeated else Color(1.0, 0.82, 0.2, 1.0)
		if barrier_index == active_index:
			marker.color = Color(1.0, 1.0, 1.0, 1.0)
		marker.set_anchors_preset(Control.PRESET_TOP_LEFT)
		marker.anchor_left = positions[barrier_index]
		marker.anchor_right = positions[barrier_index]
		marker.offset_left = -2.0
		marker.offset_right = 2.0
		marker.offset_top = 0.0
		marker.offset_bottom = 18.0
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_barrier_markers.add_child(marker)


func _clear_barrier_markers() -> void:
	for marker: Node in _barrier_markers.get_children():
		marker.queue_free()


func _update_bluegill_count(count: int) -> void:
	_bluegill_count_label.text = "Bluegill: %d" % count
