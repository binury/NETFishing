class_name BubbleCluster
extends Control

@export var profile: BubbleMenuProfile
@export var desktop_reference_size: Vector2 = Vector2(396.0, 318.0)
@export var compact_reference_size: Vector2 = Vector2(294.0, 200.0)
@export_range(0.0, 1.0, 0.01) var motion_scale: float = 1.0

var _bubbles: Array[BubbleButton] = []
var _elapsed: float = 0.0
var _layout_scale: float = 1.0


func configure(bubbles: Array[BubbleButton]) -> void:
	_bubbles = bubbles
	for index: int in _bubbles.size():
		var bubble: BubbleButton = _bubbles[index]
		if bubble.profile == null:
			bubble.profile = profile
			bubble.apply_profile()
		if index > 0:
			bubble.focus_neighbor_top = bubble.get_path_to(
				_bubbles[index - 1]
			)
		if index + 1 < _bubbles.size():
			bubble.focus_neighbor_bottom = bubble.get_path_to(
				_bubbles[index + 1]
			)


func apply_layout(field_size: Vector2, compact: bool) -> void:
	_layout_scale = minf(
		field_size.x / desktop_reference_size.x,
		field_size.y / desktop_reference_size.y
	)
	var authored_extent: Vector2 = desktop_reference_size * _layout_scale
	var layout_origin := Vector2(
		(field_size.x - authored_extent.x) * 0.5,
		(field_size.y - authored_extent.y) * 0.5
	)
	for bubble: BubbleButton in _bubbles:
		var bubble_size: Vector2 = bubble.get_layout_size(
			_layout_scale,
			compact
		)
		var center: Vector2 = (
			layout_origin
			+ bubble.get_authored_anchor(compact) * _layout_scale
		)
		bubble.apply_layout(
			center,
			bubble_size,
			profile.font_size_ratio
		)


func advance_motion(delta: float) -> void:
	_elapsed = fmod(_elapsed + delta, 120.0)
	var targets: Array[Vector2] = []
	var visual_radii: Array[float] = []
	var visual_scales: Array[Vector2] = []
	for bubble: BubbleButton in _bubbles:
		bubble.advance_emphasis(delta)
		var target: Vector2 = bubble.calculate_target(
			_elapsed,
			_layout_scale,
			motion_scale
		)
		var visual_scale: Vector2 = bubble.calculate_visual_scale(
			_elapsed,
			motion_scale
		)
		targets.append(target)
		visual_scales.append(visual_scale)
		visual_radii.append(bubble.get_visual_radius(visual_scale))
	for first_index: int in _bubbles.size():
		for second_index: int in range(first_index + 1, _bubbles.size()):
			var first_center: Vector2 = (
				targets[first_index]
				+ _bubbles[first_index].presented_size * 0.5
			)
			var second_center: Vector2 = (
				targets[second_index]
				+ _bubbles[second_index].presented_size * 0.5
			)
			var center_delta: Vector2 = second_center - first_center
			var distance: float = center_delta.length()
			var desired_distance: float = (
				visual_radii[first_index]
				+ visual_radii[second_index]
				+ profile.contact_gap * _layout_scale
			)
			if distance >= desired_distance:
				continue
			var direction := (
				center_delta / distance
				if distance > 0.001
				else Vector2.RIGHT.rotated(float(first_index + 1))
			)
			var correction: Vector2 = (
				direction
				* minf(
					(desired_distance - distance) * 0.5,
					profile.maximum_separation * _layout_scale
				)
			)
			targets[first_index] -= correction
			targets[second_index] += correction
	var position_weight: float = 1.0 - exp(
		-profile.position_response * delta
	)
	for index: int in _bubbles.size():
		_bubbles[index].apply_presentation(
			targets[index],
			visual_scales[index],
			position_weight
		)
