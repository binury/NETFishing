class_name FishingSurfaceSample
extends RefCounted

const FishableWaterRegionType = preload(
	"res://world/fishable_water_region.gd"
)
const WaterSurfaceMotionType = preload(
	"res://world/water_surface_motion.gd"
)

var has_surface: bool = false
var position: Vector3 = Vector3.ZERO
var normal: Vector3 = Vector3.UP
var water_region: FishableWaterRegionType
var is_water_surface: bool = false


func is_fishable() -> bool:
	return is_water_surface and water_region != null and water_region.fish_pool != null


func get_marker_position(vertical_offset: float) -> Vector3:
	if not has_surface:
		return position
	var presentation_offset := vertical_offset
	if is_water_surface:
		presentation_offset += (
			WaterSurfaceMotionType.get_default_height_offset()
		)
	return position + normal.normalized() * presentation_offset


func get_bobber_position(solid_clearance: float) -> Vector3:
	if not has_surface or is_water_surface:
		return position
	return position + normal.normalized() * solid_clearance
