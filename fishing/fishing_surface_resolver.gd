class_name FishingSurfaceResolver
extends RefCounted

const FishableWaterRegionType = preload(
	"res://world/fishable_water_region.gd"
)
const FishingSurfaceSampleType = preload(
	"res://fishing/fishing_surface_sample.gd"
)

var fishable_surface_mask: int = 4
var solid_surface_mask: int = 1
var query_radius: float = 0.08
var ray_start_height: float = 100.0
var ray_length: float = 240.0
var water_occlusion_tolerance: float = 0.04
var arc_sample_spacing: float = 0.3

var _water_query_shape: CylinderShape3D = CylinderShape3D.new()


func resolve_surface(
	space_state: PhysicsDirectSpaceState3D,
	query_position: Vector3,
	reference_y: float,
	maximum_solid_rise: float = INF,
) -> FishingSurfaceSampleType:
	var sample := FishingSurfaceSampleType.new()
	var ray_top: float = maxf(query_position.y, reference_y) + ray_start_height
	var ray_bottom: float = ray_top - ray_length
	var water_region: FishableWaterRegionType = _find_highest_water_region(
		space_state,
		query_position,
		ray_top,
		ray_bottom,
	)
	var solid_ray_top: float = minf(
		ray_top,
		reference_y + maximum_solid_rise,
	)
	var solid_hit: Dictionary = {}
	if solid_ray_top > ray_bottom:
		solid_hit = _find_top_solid_surface(
			space_state,
			query_position,
			solid_ray_top,
			ray_bottom,
		)

	if water_region != null:
		var water_height: float = water_region.get_surface_height()
		var solid_is_above_water: bool = false
		if not solid_hit.is_empty():
			var solid_position: Vector3 = solid_hit["position"]
			solid_is_above_water = (
				solid_position.y >= water_height - water_occlusion_tolerance
			)
		if not solid_is_above_water:
			sample.has_surface = true
			sample.position = Vector3(
				query_position.x,
				water_height,
				query_position.z,
			)
			sample.normal = Vector3.UP
			sample.water_region = water_region
			sample.is_water_surface = true
			return sample

	if not solid_hit.is_empty():
		sample.has_surface = true
		sample.position = solid_hit["position"]
		var hit_normal: Vector3 = solid_hit.get("normal", Vector3.UP)
		sample.normal = (
			hit_normal.normalized()
			if not hit_normal.is_zero_approx()
			else Vector3.UP
		)

	return sample


func find_first_cast_collision(
	space_state: PhysicsDirectSpaceState3D,
	origin: Vector3,
	target: Vector3,
	arc_height: float,
) -> Dictionary:
	if origin.is_equal_approx(target):
		return {}
	var segment_count: int = maxi(
		12,
		ceili(origin.distance_to(target) / maxf(arc_sample_spacing, 0.05)),
	)
	var previous_position: Vector3 = origin
	for segment_index: int in range(1, segment_count + 1):
		var progress: float = float(segment_index) / float(segment_count)
		var next_position: Vector3 = origin.lerp(target, progress)
		next_position.y += sin(progress * PI) * arc_height
		var hit: Dictionary = _intersect_solid_segment(
			space_state,
			previous_position,
			next_position,
		)
		if not hit.is_empty():
			return hit
		previous_position = next_position
	return {}


func resolve_cast_arc(
	space_state: PhysicsDirectSpaceState3D,
	origin: Vector3,
	target: Vector3,
	preferred_arc_height: float,
) -> Dictionary:
	var raised_arc_height: float = maxf(preferred_arc_height, 0.0)
	var raised_collision := find_first_cast_collision(
		space_state,
		origin,
		target,
		raised_arc_height,
	)
	if raised_collision.is_empty() or is_zero_approx(raised_arc_height):
		return {
			"arc_height": raised_arc_height,
			"collision": raised_collision,
		}

	# A canopy or pier roof can intersect the decorative raised arc even when
	# the direct path out toward the water is unobstructed. Prefer that low cast
	# instead of visibly sending the bobber and line upward into the ceiling.
	var direct_collision := find_first_cast_collision(
		space_state,
		origin,
		target,
		0.0,
	)
	return {
		"arc_height": 0.0,
		"collision": direct_collision,
	}


func resolve_withdrawal_surface(
	space_state: PhysicsDirectSpaceState3D,
	current_position: Vector3,
	desired_position: Vector3,
	toward_player: Vector3,
	reference_y: float,
	shore_clearance: float,
) -> FishingSurfaceSampleType:
	var desired_sample: FishingSurfaceSampleType = resolve_surface(
		space_state,
		desired_position,
		reference_y,
	)
	if not desired_sample.is_fishable():
		return _blocked_withdrawal_sample(current_position)

	var horizontal_direction: Vector3 = toward_player
	horizontal_direction.y = 0.0
	if not horizontal_direction.is_zero_approx() and shore_clearance > 0.0:
		horizontal_direction = horizontal_direction.normalized()
		var lookahead_position: Vector3 = (
			desired_sample.position + horizontal_direction * shore_clearance
		)
		var lookahead_sample: FishingSurfaceSampleType = resolve_surface(
			space_state,
			lookahead_position,
			reference_y,
		)
		if not lookahead_sample.is_fishable():
			return _blocked_withdrawal_sample(current_position)

	return desired_sample


func _blocked_withdrawal_sample(
	current_position: Vector3,
) -> FishingSurfaceSampleType:
	var sample := FishingSurfaceSampleType.new()
	sample.position = current_position
	return sample


func _find_highest_water_region(
	space_state: PhysicsDirectSpaceState3D,
	query_position: Vector3,
	ray_top: float,
	ray_bottom: float,
) -> FishableWaterRegionType:
	_water_query_shape.radius = maxf(query_radius, 0.01)
	_water_query_shape.height = maxf(ray_top - ray_bottom, 0.1)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _water_query_shape
	query.transform = Transform3D(
		Basis.IDENTITY,
		Vector3(
			query_position.x,
			(ray_top + ray_bottom) * 0.5,
			query_position.z,
		),
	)
	query.collision_mask = fishable_surface_mask
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var results: Array[Dictionary] = space_state.intersect_shape(query, 64)
	var selected_region: FishableWaterRegionType = null
	for result: Dictionary in results:
		var region: FishableWaterRegionType = (
			result.get("collider") as FishableWaterRegionType
		)
		# A water surface remains the visible top surface even when it has no
		# fish pool. Fishability is a separate policy checked by the sample.
		if region == null:
			continue
		var surface_height: float = region.get_surface_height()
		if surface_height < ray_bottom or surface_height > ray_top:
			continue
		if selected_region == null:
			selected_region = region
			continue
		var selected_height: float = selected_region.get_surface_height()
		if (
			surface_height > selected_height + 0.001
			or (
				is_equal_approx(surface_height, selected_height)
				and (
					region.selection_priority > selected_region.selection_priority
					or (
						region.selection_priority
						== selected_region.selection_priority
						and region.get_instance_id()
						< selected_region.get_instance_id()
					)
				)
			)
		):
			selected_region = region
	return selected_region


func _find_top_solid_surface(
	space_state: PhysicsDirectSpaceState3D,
	query_position: Vector3,
	ray_top: float,
	ray_bottom: float,
) -> Dictionary:
	return _intersect_solid_segment(
		space_state,
		Vector3(query_position.x, ray_top, query_position.z),
		Vector3(query_position.x, ray_bottom, query_position.z),
	)


func _intersect_solid_segment(
	space_state: PhysicsDirectSpaceState3D,
	from: Vector3,
	to: Vector3,
) -> Dictionary:
	if from.is_equal_approx(to) or solid_surface_mask == 0:
		return {}
	var query := PhysicsRayQueryParameters3D.create(
		from,
		to,
		solid_surface_mask,
	)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return space_state.intersect_ray(query)
