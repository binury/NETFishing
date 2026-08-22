extends SceneTree

const FINGERPRINT_A: String = (
	"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
)
const FINGERPRINT_B: String = (
	"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_validate_palette()
	_validate_art_unlocks()
	_validate_protocol_bounds()
	_validate_grid_snapping()
	await _validate_canvas_geometry_and_collaboration()
	await _validate_blocked_author_visibility()
	_validate_peer_capability_tracking()
	print("Surface drawing validation: PASS")
	for _frame: int in 4:
		await process_frame
	quit()


func _validate_palette() -> void:
	var ids: Array[StringName] = SurfaceDrawingPalette.get_color_ids()
	assert(ids.size() == 8)
	assert(ids.front() == SurfaceDrawingPalette.DEFAULT_COLOR_ID)
	for color_id: StringName in ids:
		assert(SurfaceDrawingPalette.has_color(color_id))
		assert(not SurfaceDrawingPalette.get_display_name(color_id).is_empty())
	assert(
		SurfaceDrawingPalette.filter_unlocked_ids([])
		== [SurfaceDrawingPalette.DEFAULT_COLOR_ID]
	)


func _validate_protocol_bounds() -> void:
	assert(SurfaceDrawingProtocol.GRID_WIDTH == 16)
	assert(SurfaceDrawingProtocol.GRID_HEIGHT == 16)
	assert(SurfaceDrawingProtocol.GRID_SIZES == [16, 32, 64, 128])
	assert(is_equal_approx(SurfaceDrawingProtocol.CELL_SIZE, 0.075))
	assert(is_equal_approx(
		float(SurfaceDrawingProtocol.GRID_WIDTH)
			* SurfaceDrawingProtocol.CELL_SIZE,
		1.2,
	))
	var canvas_request: Dictionary = {
		"request_id": "canvas-1",
		"session_id": "session",
		"origin": [0.0, 1.0, 2.0],
		"normal": [0.0, 1.0, 0.0],
		"tangent": [1.0, 0.0, 0.0],
		"width": SurfaceDrawingProtocol.GRID_WIDTH,
		"height": SurfaceDrawingProtocol.GRID_HEIGHT,
		"cell_size": SurfaceDrawingProtocol.CELL_SIZE,
	}
	assert(SurfaceDrawingProtocol.validate_canvas_request(canvas_request))
	var malformed: Dictionary = canvas_request.duplicate(true)
	malformed["origin"] = [INF, 0.0, 0.0]
	assert(not SurfaceDrawingProtocol.validate_canvas_request(malformed))
	var edit_request: Dictionary = {
		"request_id": "edit-1",
		"session_id": "session",
		"canvas_id": "canvas-1",
		"stroke_id": "stroke-1",
		"brush_size": 1,
		"edits": [{"x": 0, "y": 0, "color_id": "ocean_teal"}],
	}
	assert(SurfaceDrawingProtocol.validate_edit_request(edit_request))
	edit_request["edits"] = [{
		"x": SurfaceDrawingProtocol.MAX_GRID_SIZE,
		"y": 0,
		"color_id": "ocean_teal",
	}]
	assert(not SurfaceDrawingProtocol.validate_edit_request(edit_request))
	edit_request["edits"] = [{"x": 0, "y": 0, "color_id": "ocean_teal"}]
	edit_request["brush_size"] = 5
	assert(not SurfaceDrawingProtocol.validate_edit_request(edit_request))
	for grid_size: int in SurfaceDrawingProtocol.GRID_SIZES:
		var sized_request: Dictionary = canvas_request.duplicate(true)
		sized_request["width"] = grid_size
		sized_request["height"] = grid_size
		assert(SurfaceDrawingProtocol.validate_canvas_request(sized_request))
	var unsupported_size: Dictionary = canvas_request.duplicate(true)
	unsupported_size["width"] = 48
	unsupported_size["height"] = 48
	assert(not SurfaceDrawingProtocol.validate_canvas_request(unsupported_size))
	var stamp_pixels := PackedByteArray()
	stamp_pixels.resize(16 * 16)
	stamp_pixels[0] = 1
	var stamp_request: Dictionary = canvas_request.duplicate(true)
	stamp_request["request_id"] = "stamp-1"
	stamp_request["pixels"] = stamp_pixels
	assert(SurfaceDrawingProtocol.validate_stamp_request(stamp_request))
	var invalid_stamp: Dictionary = stamp_request.duplicate(true)
	var invalid_pixels: PackedByteArray = invalid_stamp["pixels"]
	invalid_pixels[0] = SurfaceDrawingPalette.COLORS.size() + 1
	invalid_stamp["pixels"] = invalid_pixels
	assert(not SurfaceDrawingProtocol.validate_stamp_request(invalid_stamp))
	var empty_stamp: Dictionary = stamp_request.duplicate(true)
	empty_stamp["pixels"] = PackedByteArray()
	assert(not SurfaceDrawingProtocol.validate_stamp_request(empty_stamp))
	var guide_request: Dictionary = {
		"request_id": "guide-1",
		"session_id": "session",
		"canvas_id": "canvas-1",
		"guide_visible": false,
		"finalized": false,
	}
	assert(SurfaceDrawingProtocol.validate_guide_request(guide_request))
	guide_request["guide_visible"] = 0
	assert(not SurfaceDrawingProtocol.validate_guide_request(guide_request))
	var undo_request: Dictionary = {
		"request_id": "undo-1",
		"session_id": "session",
		"stroke_id": "stroke-1",
	}
	assert(SurfaceDrawingProtocol.validate_undo_request(undo_request))


func _validate_art_unlocks() -> void:
	var unlocks := PlayerArtUnlocks.new()
	assert(unlocks.get_unlocked_color_ids() == [&"chalk_white"])
	assert(unlocks.get_unlocked_brush_sizes() == [1])
	assert(unlocks.get_unlocked_grid_sizes() == [16])
	assert(unlocks.unlock_product(&"marker_ocean_teal"))
	assert(unlocks.unlock_product(&"brush_4x"))
	assert(unlocks.unlock_product(&"grid_128x"))
	assert(unlocks.unlock_product(PlayerArtUnlocks.STAMP_PRODUCT_ID))
	assert(unlocks.is_color_unlocked(&"ocean_teal"))
	assert(unlocks.is_brush_size_unlocked(4))
	assert(unlocks.is_grid_size_unlocked(128))
	assert(unlocks.is_stamp_unlocked())
	assert(not unlocks.restore_mask(PlayerArtUnlocks.ALL_UNLOCK_MASK + 1))
	unlocks.free()


func _validate_grid_snapping() -> void:
	var anchor: Dictionary = {
		"session_id": "session",
		"canvas_id": "anchor",
		"origin": [0.0, 0.0, 0.0],
		"normal": [0.0, 1.0, 0.0],
		"tangent": [1.0, 0.0, 0.0],
		"width": SurfaceDrawingProtocol.GRID_WIDTH,
		"height": SurfaceDrawingProtocol.GRID_HEIGHT,
		"cell_size": SurfaceDrawingProtocol.CELL_SIZE,
		"revision": 0,
		"guide_visible": false,
		"finalized": true,
		"layer": 1,
		"creator_fingerprint": FINGERPRINT_A,
		"cells": [],
	}
	var snapped: Dictionary = SurfaceDrawingPlacement.resolve(
		Vector3(1.08, 0.02, 0.08),
		Vector3.UP,
		Vector3.RIGHT,
		[anchor],
	)
	assert(bool(snapped["snapped"]))
	var snapped_origin: Vector3 = snapped["origin"]
	assert(snapped_origin.is_equal_approx(Vector3(1.2, 0.0, 0.0)))
	var unsnapped: Dictionary = SurfaceDrawingPlacement.resolve(
		Vector3(0.6, 0.0, 0.0),
		Vector3.UP,
		Vector3.RIGHT,
		[anchor],
	)
	assert(not bool(unsnapped["snapped"]))


func _validate_canvas_geometry_and_collaboration() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var canvas := SurfaceDrawingCanvas.new()
	world.add_child(canvas)
	var state: Dictionary = {
		"session_id": "session",
		"canvas_id": "canvas-1",
		"origin": [0.0, 0.0, 0.0],
		"normal": [0.0, 1.0, 0.0],
		"tangent": [1.0, 0.0, 0.0],
		"width": SurfaceDrawingProtocol.GRID_WIDTH,
		"height": SurfaceDrawingProtocol.GRID_HEIGHT,
		"cell_size": SurfaceDrawingProtocol.CELL_SIZE,
		"revision": 0,
		"creator_fingerprint": FINGERPRINT_A,
		"cells": [],
	}
	assert(canvas.setup(state, null))
	var pixel_instance := canvas.get("_pixel_instance") as MeshInstance3D
	assert(pixel_instance != null)
	assert(pixel_instance.name == "ArtworkTexture")
	var persistent_mesh: Mesh = pixel_instance.mesh
	var pixel_material := persistent_mesh.surface_get_material(
		0
	) as StandardMaterial3D
	assert(pixel_material != null)
	var persistent_texture: Texture2D = pixel_material.albedo_texture
	assert(persistent_texture is ImageTexture)
	var first_center: Vector3 = canvas.get_cell_world_position(0, 0)
	assert(canvas.cell_at_world_point(first_center) == Vector2i(0, 0))
	assert(canvas.contains_world_point(first_center))
	var first_update: Dictionary = {
		"session_id": "session",
		"canvas_id": "canvas-1",
		"revision": 1,
		"edits": [{
			"x": 3,
			"y": 4,
			"color_id": "coral",
			"author_fingerprint": FINGERPRINT_A,
		}],
	}
	assert(canvas.apply_update(first_update))
	assert(pixel_instance.mesh == persistent_mesh)
	assert(pixel_material.albedo_texture == persistent_texture)
	assert(canvas.get_rendered_pixel_count() == 1)
	var export_image: Image = canvas.get_export_image()
	assert(export_image.get_size() == Vector2i(16, 16))
	assert(export_image.get_pixel(3, 11).is_equal_approx(
		SurfaceDrawingPalette.get_color(&"coral")
	))
	assert(export_image.get_pixel(0, 0).is_equal_approx(Color.TRANSPARENT))
	var finish_update: Dictionary = {
		"session_id": "session",
		"canvas_id": "canvas-1",
		"revision": 2,
		"guide_visible": false,
		"finalized": true,
	}
	assert(canvas.apply_guide_update(finish_update))
	assert(not canvas.is_guide_visible())
	assert(canvas.is_finalized())
	assert(not canvas.has_guide_geometry())
	assert(pixel_instance.mesh == persistent_mesh)
	assert(pixel_material.albedo_texture == persistent_texture)
	await process_frame
	var finished_pixel_scale: float = canvas.get_rendered_pixel_size()
	assert(
		is_equal_approx(
			finished_pixel_scale, SurfaceDrawingProtocol.CELL_SIZE
		),
		"finished pixel scale %f does not match cell size %f"
		% [finished_pixel_scale, SurfaceDrawingProtocol.CELL_SIZE],
	)
	var second_update: Dictionary = {
		"session_id": "session",
		"canvas_id": "canvas-1",
		"revision": 3,
		"edits": [{
			"x": 3,
			"y": 4,
			"color_id": "blue",
			"author_fingerprint": FINGERPRINT_B,
		}],
	}
	assert(canvas.apply_update(second_update))
	assert(pixel_instance.mesh == persistent_mesh)
	assert(pixel_material.albedo_texture == persistent_texture)
	var cells: Array[Dictionary] = canvas.get_authoritative_cells()
	assert(cells.size() == 1)
	assert(cells[0]["color_id"] == "blue")
	assert(cells[0]["author_fingerprint"] == FINGERPRINT_B)
	var erase_update: Dictionary = {
		"session_id": "session",
		"canvas_id": "canvas-1",
		"revision": 4,
		"edits": [{
			"x": 3,
			"y": 4,
			"color_id": "",
			"author_fingerprint": "",
		}],
	}
	assert(canvas.apply_update(erase_update))
	assert(canvas.get_authoritative_cells().is_empty())
	assert(canvas.get_rendered_pixel_count() == 0)
	assert(canvas.get_export_image().get_pixel(3, 11).is_equal_approx(
		Color.TRANSPARENT
	))
	world.queue_free()
	await process_frame


func _validate_peer_capability_tracking() -> void:
	var registry := PeerRegistry.new()
	assert(registry.add_peer(
		1,
		"profile",
		"Voyager",
		NetworkProtocol.PROTOCOL_VERSION,
		FINGERPRINT_A,
		"public key fixture",
		PackedStringArray([str(SurfaceDrawingProtocol.CAPABILITY)]),
	))
	var record: PeerRegistry.PeerRecord = registry.get_peer(1)
	assert(record != null)
	assert(str(SurfaceDrawingProtocol.CAPABILITY) in record.capability_flags)


func _validate_blocked_author_visibility() -> void:
	var relationships := PlayerRelationshipStore.new()
	relationships.set("_loaded", true)
	relationships.set("_records", {
		FINGERPRINT_B: {"blocked": true, "muted": true},
	})
	var world := Node3D.new()
	root.add_child(world)
	world.add_child(relationships)
	var canvas := SurfaceDrawingCanvas.new()
	world.add_child(canvas)
	var state: Dictionary = {
		"session_id": "session",
		"canvas_id": "blocked-author-canvas",
		"origin": [0.0, 0.0, 0.0],
		"normal": [0.0, 1.0, 0.0],
		"tangent": [1.0, 0.0, 0.0],
		"width": SurfaceDrawingProtocol.GRID_WIDTH,
		"height": SurfaceDrawingProtocol.GRID_HEIGHT,
		"cell_size": SurfaceDrawingProtocol.CELL_SIZE,
		"revision": 1,
		"creator_fingerprint": FINGERPRINT_A,
		"participant_fingerprints": [FINGERPRINT_A, FINGERPRINT_B],
		"cells": [
			{
				"x": 1,
				"y": 1,
				"color_id": "coral",
				"author_fingerprint": FINGERPRINT_A,
			},
			{
				"x": 2,
				"y": 1,
				"color_id": "blue",
				"author_fingerprint": FINGERPRINT_B,
			},
		],
	}
	assert(canvas.setup(state, relationships))
	assert(canvas.is_hidden_by_relationship())
	assert(canvas.get_rendered_pixel_count() == 0)
	relationships.set("_records", {})
	canvas.refresh_relationship_visibility()
	await process_frame
	assert(not canvas.is_hidden_by_relationship())
	assert(canvas.get_rendered_pixel_count() == 2)
	relationships.set("_records", {
		FINGERPRINT_B: {"blocked": true, "muted": true},
	})
	assert(canvas.apply_update({
		"session_id": "session",
		"canvas_id": "blocked-author-canvas",
		"revision": 2,
		"participant_fingerprints": [FINGERPRINT_A, FINGERPRINT_B],
		"edits": [{
			"x": 2,
			"y": 1,
			"color_id": "",
			"author_fingerprint": "",
		}],
	}))
	canvas.refresh_relationship_visibility()
	assert(canvas.is_hidden_by_relationship())
	assert(canvas.get_rendered_pixel_count() == 0)
	world.queue_free()
	await process_frame
