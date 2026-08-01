@tool
class_name WaterBodyAuthoring
extends Node3D

const FishPoolType = preload("res://fish/fish_pool.gd")

@export_group("Surface")
## Visible water footprint in meters.
@export_custom(
	PROPERTY_HINT_RANGE,
	"0.1,200.0,0.1,or_greater,suffix:m",
)
var surface_size: Vector2 = Vector2(10.0, 10.0):
	set(value):
		surface_size = Vector2(maxf(value.x, 0.1), maxf(value.y, 0.1))
		_sync_owned_nodes()
## Material applied to the visible water surface.
@export var water_material: Material:
	set(value):
		water_material = value
		_sync_owned_nodes()

@export_group("Fishing Coverage")
@export_range(0.1, 20.0, 0.1, "or_greater", "suffix:m")
var fishing_depth: float = 4.0:
	set(value):
		fishing_depth = maxf(value, 0.1)
		_sync_owned_nodes()
@export var fish_pool: FishPoolType:
	set(value):
		fish_pool = value
		_sync_owned_nodes()
@export var water_type: WaterType.Type = WaterType.Type.FRESH_WATER:
	set(value):
		water_type = value
		_sync_owned_nodes()
@export var location_tags: Array[StringName] = []:
	set(value):
		location_tags = value
		_sync_owned_nodes()
@export var selection_priority: int = 0:
	set(value):
		selection_priority = value
		_sync_owned_nodes()

@export_group("Recovery Coverage")
@export_range(0.1, 20.0, 0.1, "or_greater", "suffix:m")
var recovery_depth: float = 4.8:
	set(value):
		recovery_depth = maxf(value, 0.1)
		_sync_owned_nodes()

@export_group("Owned Nodes")
@export_node_path("MeshInstance3D")
var visual_water_path: NodePath = ^"VisualWater"
@export_node_path("CollisionShape3D")
var fishing_shape_path: NodePath = ^"FishingRegion/Shape"
@export_node_path("Area3D")
var fishing_region_path: NodePath = ^"FishingRegion"
@export_node_path("Area3D")
var recovery_region_path: NodePath = ^"RecoveryRegion"
@export_node_path("CollisionShape3D")
var recovery_shape_path: NodePath = ^"RecoveryRegion/Shape"


func _ready() -> void:
	_sync_owned_nodes()
	if Engine.is_editor_hint():
		update_configuration_warnings()


func _sync_owned_nodes() -> void:
	if not is_inside_tree():
		return
	var visual_water := get_node_or_null(visual_water_path) as MeshInstance3D
	if visual_water != null:
		var plane_mesh := visual_water.mesh as PlaneMesh
		if plane_mesh != null:
			plane_mesh.size = surface_size
		visual_water.material_override = water_material

	var fishing_shape_node := (
		get_node_or_null(fishing_shape_path) as CollisionShape3D
	)
	var fishing_region := (
		get_node_or_null(fishing_region_path) as FishableWaterRegion
	)
	if fishing_region != null:
		fishing_region.fish_pool = fish_pool
		fishing_region.water_type = water_type
		fishing_region.location_tags = location_tags.duplicate()
		fishing_region.selection_priority = selection_priority
		fishing_region.surface_height_mode = (
			FishableWaterRegion.SurfaceHeightMode.PARENT_GLOBAL_Y
		)
	if fishing_shape_node != null:
		var fishing_shape := fishing_shape_node.shape as BoxShape3D
		if fishing_shape != null:
			# The authored root is the one water-surface height. Keep the fishable
			# volume entirely below that plane so visible water and interaction
			# can be moved together without a second height to tune.
			fishing_shape_node.position.y = -fishing_depth * 0.5
			fishing_shape.size = Vector3(
				surface_size.x,
				fishing_depth,
				surface_size.y
			)

	var recovery_region := (
		get_node_or_null(recovery_region_path) as Area3D
	)
	if recovery_region != null:
		recovery_region.position.y = -recovery_depth * 0.5
	var recovery_shape_node := (
		get_node_or_null(recovery_shape_path) as CollisionShape3D
	)
	if recovery_shape_node != null:
		var recovery_shape := recovery_shape_node.shape as BoxShape3D
		if recovery_shape != null:
			recovery_shape.size = Vector3(
				surface_size.x,
				recovery_depth,
				surface_size.y
			)

	if Engine.is_editor_hint():
		update_configuration_warnings()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if not scale.is_equal_approx(Vector3.ONE):
		warnings.append(
			"Keep root scale at 1; resize water with Surface Size."
		)
	var visual_water := get_node_or_null(visual_water_path) as MeshInstance3D
	if visual_water == null or not visual_water.mesh is PlaneMesh:
		warnings.append("VisualWater must provide a PlaneMesh.")
	var fishing_shape := get_node_or_null(fishing_shape_path) as CollisionShape3D
	if fishing_shape == null or not fishing_shape.shape is BoxShape3D:
		warnings.append("FishingRegion must provide a BoxShape3D.")
	var recovery_region := (
		get_node_or_null(recovery_region_path) as PlayerWaterTrigger
	)
	if recovery_region == null:
		warnings.append("RecoveryRegion must use PlayerWaterTrigger.")
	elif (
		recovery_region.surface_height_mode
		!= PlayerWaterTrigger.SurfaceHeightMode.PARENT_GLOBAL_Y
	):
		warnings.append(
			"RecoveryRegion must derive surface height from its parent."
		)
	var recovery_shape := (
		get_node_or_null(recovery_shape_path) as CollisionShape3D
	)
	if recovery_shape == null or not recovery_shape.shape is BoxShape3D:
		warnings.append("RecoveryRegion must provide a BoxShape3D.")
	var fishing_region := get_node_or_null(
		fishing_region_path
	) as FishableWaterRegion
	if fishing_region == null:
		warnings.append("FishingRegion must use FishableWaterRegion.")
	elif (
		fishing_region.surface_height_mode
		!= FishableWaterRegion.SurfaceHeightMode.PARENT_GLOBAL_Y
	):
		warnings.append(
			"FishingRegion must derive surface height from its parent."
		)
	if water_material == null:
		warnings.append("Assign a water material.")
	if fish_pool == null:
		warnings.append("Assign a fish pool.")
	return warnings
