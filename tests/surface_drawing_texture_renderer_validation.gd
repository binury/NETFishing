extends SceneTree

const CANVAS_COUNT: int = 5
const GRID_SIZE: int = 32
const FINGERPRINT: String = (
	"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var color_ids: Array[StringName] = SurfaceDrawingPalette.get_color_ids()
	var cells: Array[Dictionary] = []
	for y: int in range(GRID_SIZE):
		for x: int in range(GRID_SIZE):
			cells.append({
				"x": x,
				"y": y,
				"color_id": str(color_ids[(x + y) % color_ids.size()]),
				"author_fingerprint": FINGERPRINT,
			})
	var canvases: Array[SurfaceDrawingCanvas] = []
	var persistent_meshes: Array[Mesh] = []
	var persistent_textures: Array[Texture2D] = []
	for canvas_index: int in range(CANVAS_COUNT):
		var canvas := SurfaceDrawingCanvas.new()
		world.add_child(canvas)
		assert(canvas.setup({
			"session_id": "texture-renderer-session",
			"canvas_id": "canvas-%d" % canvas_index,
			"origin": [float(canvas_index) * 3.0, 0.0, 0.0],
			"normal": [0.0, 1.0, 0.0],
			"tangent": [1.0, 0.0, 0.0],
			"width": GRID_SIZE,
			"height": GRID_SIZE,
			"cell_size": SurfaceDrawingProtocol.CELL_SIZE,
			"revision": 0,
			"guide_visible": true,
			"finalized": false,
			"layer": canvas_index,
			"creator_fingerprint": FINGERPRINT,
			"cells": cells,
		}, null))
		assert(canvas.get_rendered_pixel_count() == GRID_SIZE * GRID_SIZE)
		var pixel_instance := canvas.get("_pixel_instance") as MeshInstance3D
		assert(pixel_instance != null)
		assert(pixel_instance.mesh.get_surface_count() == 1)
		var material := pixel_instance.mesh.surface_get_material(
			0
		) as StandardMaterial3D
		assert(material != null)
		assert(material.albedo_texture is ImageTexture)
		canvases.append(canvas)
		persistent_meshes.append(pixel_instance.mesh)
		persistent_textures.append(material.albedo_texture)
	for canvas_index: int in range(CANVAS_COUNT):
		var canvas: SurfaceDrawingCanvas = canvases[canvas_index]
		assert(canvas.apply_update({
			"session_id": "texture-renderer-session",
			"canvas_id": "canvas-%d" % canvas_index,
			"revision": 1,
			"edits": [{
				"x": canvas_index,
				"y": canvas_index,
				"color_id": "coral",
				"author_fingerprint": FINGERPRINT,
			}],
		}))
		var pixel_instance := canvas.get("_pixel_instance") as MeshInstance3D
		var material := pixel_instance.mesh.surface_get_material(
			0
		) as StandardMaterial3D
		assert(pixel_instance.mesh == persistent_meshes[canvas_index])
		assert(material.albedo_texture == persistent_textures[canvas_index])
		assert(canvas.apply_guide_update({
			"session_id": "texture-renderer-session",
			"canvas_id": "canvas-%d" % canvas_index,
			"revision": 2,
			"guide_visible": false,
			"finalized": true,
		}))
		assert(not canvas.has_guide_geometry())
	await process_frame
	for canvas: SurfaceDrawingCanvas in canvases:
		var artwork_mesh_count: int = 0
		for child: Node in canvas.get_children():
			if child is MultiMeshInstance3D:
				assert(false, "Art Kit pixels regressed to per-color MultiMeshes.")
			if child is MeshInstance3D:
				artwork_mesh_count += 1
		assert(artwork_mesh_count == 1)
		assert(canvas.get_export_image().get_size() == Vector2i(32, 32))
	world.queue_free()
	await process_frame
	print("Surface drawing texture renderer validation: PASS")
	quit()
