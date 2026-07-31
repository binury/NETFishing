extends SceneTree

const REGION_SCENE := preload("res://world/regions/starter_island_region.tscn")
func _initialize() -> void:
	call_deferred("_bake")


func _bake() -> void:
	var started := Time.get_ticks_usec()
	var region := REGION_SCENE.instantiate()
	root.add_child(region)
	var baker := region.get_node_or_null("ShorelineRibbonBaker") as ShorelineRibbonBaker
	if baker == null:
		push_error("The map does not contain a configured ShorelineRibbonBaker.")
		quit(1)
		return
	var results := baker.rebuild_all()
	if results.size() != baker.water_bodies.size():
		quit(1)
		return
	for result: Dictionary in results:
		if result.get("skipped", false):
			print(
				"Shoreline %s: type=%s skipped intentionally"
				% [result["output_path"], WaterType.label(result["water_type"])]
			)
			continue
		print(
			"Shoreline %s: type=%s segments=%d loops=%d raw=%d simplified=%d smoothed=%d triangles=%d"
			% [
				result["output_path"],
				WaterType.label(result["water_type"]),
				result["segment_count"],
				result["loop_count"],
				result["raw_point_count"],
				result["simplified_point_count"],
				result["smoothed_point_count"],
				result["triangle_count"],
			]
		)
	print("Shoreline bake completed in %.2f ms" % ((Time.get_ticks_usec() - started) / 1000.0))
	quit()
