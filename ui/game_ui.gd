class_name GameUI
extends CanvasLayer

const CollectionLogType = preload("res://collection/collection_log.gd")
const FishBuyerProfileType = preload("res://economy/fish_buyer_profile.gd")
const FishSaleServiceType = preload("res://economy/fish_sale_service.gd")
const FishPoolType = preload("res://fish/fish_pool.gd")
const FishInventoryType = preload("res://inventory/fish_inventory.gd")
const FishingSpotType = preload("res://fishing/fishing_spot.gd")
const PlayerMenuType = preload("res://ui/player_menu.gd")
const PlayerType = preload("res://player/player.gd")
const PlayerWalletType = preload("res://economy/player_wallet.gd")

@onready var _status_label: Label = %StatusLabel
@onready var _catch_track: Control = %CatchTrack
@onready var _green_catch_progress: ProgressBar = %GreenCatchProgress
@onready var _red_chase_progress: ProgressBar = %RedChaseProgress
@onready var _barrier_markers: Control = %BarrierMarkers
@onready var _barrier_summary: Label = %BarrierSummary
@onready var _barrier_health: Label = %BarrierHealth
@onready var _showcase_details: Label = %ShowcaseDetails
@onready var _fishing_panel: PanelContainer = %FishingPanel
@onready var _player_menu: PlayerMenuType = %PlayerMenu

var _showcase_active: bool = false


func setup(
	player: PlayerType,
	inventory: FishInventoryType,
	collection_log: CollectionLogType,
	wallet: PlayerWalletType,
	sale_service: FishSaleServiceType,
	default_buyer: FishBuyerProfileType,
	catalog: FishPoolType,
	fishing_spot: FishingSpotType,
) -> void:
	fishing_spot.status_changed.connect(_on_fishing_status_changed)
	fishing_spot.catch_display_changed.connect(_on_catch_display_changed)
	fishing_spot.showcase_changed.connect(_on_showcase_changed)
	_player_menu.menu_visibility_changed.connect(
		_on_player_menu_visibility_changed
	)
	_player_menu.setup(
		player,
		inventory,
		collection_log,
		wallet,
		sale_service,
		default_buyer,
		catalog,
		fishing_spot
	)


func _on_fishing_status_changed(status: String) -> void:
	if _showcase_active:
		return
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


func _on_showcase_changed(
	fish_name: String,
	rarity_name: String,
	weight_lb: float,
	visible: bool,
) -> void:
	_showcase_active = visible
	if not visible:
		_status_label.text = ""
		_status_label.visible = false
		_showcase_details.text = ""
		_showcase_details.visible = false
		return
	_catch_track.visible = false
	_barrier_summary.visible = false
	_barrier_health.visible = false
	_clear_barrier_markers()
	_status_label.text = "You caught a %s!" % fish_name
	_status_label.visible = true
	_showcase_details.text = (
		"%.1f lb • %s\nLeft click or Escape to put away"
		% [weight_lb, rarity_name]
	)
	_showcase_details.visible = true


func _on_player_menu_visibility_changed(is_open: bool) -> void:
	_fishing_panel.visible = not is_open
