class_name CatchDifficultyProfile
extends Resource

@export_range(0, 12, 1) var barrier_count_min: int = 2
@export_range(0, 12, 1) var barrier_count_max: int = 4
@export_range(1, 100, 1) var barrier_health_min: int = 3
@export_range(1, 100, 1) var barrier_health_max: int = 7
@export_range(0.0, 0.45, 0.01) var first_barrier_margin: float = 0.15
@export_range(0.0, 0.45, 0.01) var final_barrier_margin: float = 0.10
@export_range(0.01, 1.0, 0.01) var minimum_barrier_spacing: float = 0.15


func get_barrier_count_range() -> Vector2i:
	var minimum: int = maxi(0, barrier_count_min)
	return Vector2i(minimum, maxi(minimum, barrier_count_max))


func get_barrier_health_range() -> Vector2i:
	var minimum: int = maxi(1, barrier_health_min)
	return Vector2i(minimum, maxi(minimum, barrier_health_max))


func get_generation_interval() -> Vector2:
	var start: float = clampf(first_barrier_margin, 0.0, 0.95)
	var finish: float = clampf(1.0 - final_barrier_margin, start, 1.0)
	return Vector2(start, finish)
