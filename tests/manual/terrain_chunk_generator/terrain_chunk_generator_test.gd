extends Node3D

@onready var _generator: TerrainChunkGenerator = $TerrainChunkGenerator
@onready var _status: Label = $Instructions/Status


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		get_tree().quit()
		return
	var key_event := event as InputEventKey
	if (
		key_event != null
		and key_event.pressed
		and not key_event.echo
		and key_event.physical_keycode == KEY_R
	):
		get_viewport().set_input_as_handled()
		_generator.generation_seed += 1
		_generator.generate()


func _on_generation_completed(summary: Dictionary) -> void:
	_status.text = (
		"Terrain generator diagnostic  •  seed %d  •  %d chunks  •  "
		+ "%d rotations / %d constraints  •  %d backtracks  •  "
		+ "%d repeated edges\nlayout %s  •  R: regenerate  •  Esc/B: close"
	) % [
		int(summary["seed"]),
		int(summary["chunk_count"]),
		int(summary["variant_count"]),
		int(summary["solver_variant_count"]),
		int(summary["backtracks"]),
		int(summary["adjacent_repeat_edges"]),
		str(summary["layout_fingerprint"]).substr(0, 12),
	]
