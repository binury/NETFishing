@tool
extends EditorPlugin

const TERRAIN_RESOURCE := (
	"res://art/exported/environment/terrain/starter_island.glb"
)
const REGION_SCENE := "res://world/regions/starter_island_region.tscn"

var _bake_pending := false


func _enter_tree() -> void:
	var filesystem := get_editor_interface().get_resource_filesystem()
	if not filesystem.resources_reimported.is_connected(_on_resources_reimported):
		filesystem.resources_reimported.connect(_on_resources_reimported)


func _exit_tree() -> void:
	var filesystem := get_editor_interface().get_resource_filesystem()
	if filesystem.resources_reimported.is_connected(_on_resources_reimported):
		filesystem.resources_reimported.disconnect(_on_resources_reimported)


func _on_resources_reimported(resources: PackedStringArray) -> void:
	if not resources.has(TERRAIN_RESOURCE) or _bake_pending:
		return
	_bake_pending = true
	call_deferred("_bake_configured_shorelines")


func _bake_configured_shorelines() -> void:
	_bake_pending = false
	var packed_region := ResourceLoader.load(
		REGION_SCENE,
		"PackedScene",
		ResourceLoader.CACHE_MODE_REPLACE,
	) as PackedScene
	if packed_region == null:
		push_error("Shoreline auto-bake could not load %s." % REGION_SCENE)
		return
	var region := packed_region.instantiate() as Node3D
	add_child(region)
	var baker := region.get_node_or_null(
		"ShorelineRibbonBaker"
	) as ShorelineRibbonBaker
	if baker == null:
		push_error("Shoreline auto-bake found no configured baker.")
		region.queue_free()
		return
	var results := baker.rebuild_all()
	for result: Dictionary in results:
		if result.get("skipped", false):
			continue
		var output_path: String = result.get("output_path", "")
		if not output_path.is_empty():
			ResourceLoader.load(
				output_path,
				"ArrayMesh",
				ResourceLoader.CACHE_MODE_REPLACE,
			)
		print(
			"Shoreline auto-bake: %s, %d loops, %d triangles"
			% [output_path, result.loop_count, result.triangle_count]
		)
	region.queue_free()
	get_editor_interface().get_resource_filesystem().scan()
