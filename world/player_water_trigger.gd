@tool
class_name PlayerWaterTrigger
extends Area3D

signal recovery_requested(player: Player, surface_height: float)

enum SurfaceHeightMode {
	EXPLICIT,
	PARENT_GLOBAL_Y,
}

@export_group("Surface")
@export var surface_height_mode: SurfaceHeightMode = SurfaceHeightMode.EXPLICIT:
	set(value):
		surface_height_mode = value
		if Engine.is_editor_hint():
			notify_property_list_changed()
## Legacy explicit height used when Surface Height Mode is Explicit.
@export var surface_height: float = 0.2
@export_group("Recovery Trigger")
## Recovery begins when the player's body center reaches this depth.
@export_range(0.0, 2.0, 0.05) var entry_depth_threshold: float = 0.35

var _tracked_players: Array[Player] = []
var _triggered_players: Dictionary[StringName, bool] = {}


func _ready() -> void:
	if Engine.is_editor_hint():
		set_physics_process(false)
		return
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _physics_process(_delta: float) -> void:
	var active_surface_height: float = get_surface_height()
	for player: Player in _tracked_players.duplicate():
		if not is_instance_valid(player):
			_tracked_players.erase(player)
			continue
		var player_key: StringName = StringName(str(player.get_instance_id()))
		if _triggered_players.has(player_key):
			continue
		if (
			player.get_body_center_position().y
			<= active_surface_height - entry_depth_threshold
		):
			_triggered_players[player_key] = true
			recovery_requested.emit(player, active_surface_height)


func get_surface_height() -> float:
	if surface_height_mode == SurfaceHeightMode.PARENT_GLOBAL_Y:
		var surface_owner := get_parent() as Node3D
		if surface_owner != null:
			return surface_owner.global_position.y
	return surface_height


func _validate_property(property: Dictionary) -> void:
	if (
		property.name == "surface_height"
		and surface_height_mode == SurfaceHeightMode.PARENT_GLOBAL_Y
	):
		property.usage = int(property.usage) & ~PROPERTY_USAGE_EDITOR


func _on_body_entered(body: Node3D) -> void:
	var player: Player = body as Player
	if player == null or player in _tracked_players:
		return
	_tracked_players.append(player)


func _on_body_exited(body: Node3D) -> void:
	var player: Player = body as Player
	if player == null:
		return
	_tracked_players.erase(player)
	_triggered_players.erase(StringName(str(player.get_instance_id())))
