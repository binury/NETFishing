extends SceneTree

const DEFAULT_PROFILE: Dictionary = {
	"params": {
		"compress/mode": 2,
		"compress/high_quality": false,
		"compress/lossy_quality": 0.7,
		"compress/uastc_level": 0,
		"compress/rdo_quality_loss": 0.0,
		"compress/hdr_compression": 1,
		"compress/normal_map": 0,
		"compress/channel_pack": 0,
		"mipmaps/generate": false,
		"mipmaps/limit": -1,
		"roughness/mode": 0,
		"roughness/src_normal": "",
		"process/channel_remap/red": 0,
		"process/channel_remap/green": 1,
		"process/channel_remap/blue": 2,
		"process/channel_remap/alpha": 3,
		"process/fix_alpha_border": true,
		"process/premult_alpha": false,
		"process/normal_map_invert_y": false,
		"process/hdr_as_srgb": false,
		"process/hdr_clamp_exposure": false,
		"process/size_limit": 0,
		"detect_3d/compress_to": 0,
	},
}

var apply_changes: bool = false
var verbose: bool = false
var roots: PackedStringArray = PackedStringArray()
var should_exit: bool = false

var errors: int = 0
var skipped_non_texture: int = 0
var updated: int = 0
var unchanged: int = 0

func _initialize() -> void:
	_parse_args()
	if should_exit:
		return
	if roots.is_empty():
		printerr("At least one --root path is required.")
		quit(2)
		return

	for root: String in roots:
		var normalized_root := root
		if not normalized_root.ends_with("/"):
			normalized_root += "/"
		if not normalized_root.begins_with("res://") and not normalized_root.is_absolute_path():
			if normalized_root.begins_with("./"):
				normalized_root = "res://%s" % normalized_root.trim_prefix("./")
			else:
				normalized_root = "res://%s" % normalized_root
		_print("Scanning %s" % normalized_root)
		_scan_directory(normalized_root)

	print_summary()
	quit(1 if errors > 0 else 0)


func _parse_args() -> void:
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		var arg := args[i]
		if arg == "--help" or arg == "-h":
			_print_usage()
			should_exit = true
			quit(0)
			return
		elif arg == "--apply":
			apply_changes = true
			i += 1
		elif arg == "--verbose" or arg == "-v":
			verbose = true
			i += 1
		elif arg == "--root":
			if i + 1 >= args.size():
				printerr("--root requires a path value")
				should_exit = true
				quit(1)
				return
			i += 1
				roots.append(args[i])
				i += 1
			elif arg.begins_with("--root="):
				roots.append(arg.trim_prefix("--root="))
				i += 1
		else:
			printerr("Unknown argument: ", arg)
			should_exit = true
			quit(2)
			return


func _scan_directory(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		printerr("Failed to open root: ", path)
		errors += 1
		return

	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name.is_empty():
			break
		if name == "." or name == "..":
			continue
		if name == ".godot":
			continue

		var candidate := path.path_join(name)
		if dir.current_is_dir():
			_scan_directory(candidate)
			continue

		if name.get_extension().to_lower() != "import":
			continue

		_handle_import_file(candidate)


func _handle_import_file(import_path: String) -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(import_path)
	if err != OK:
		printerr("Could not load import settings: ", import_path, " (", err, ")")
		errors += 1
		return

	if not cfg.has_section("remap") or not cfg.has_section_key("remap", "importer"):
		skipped_non_texture += 1
		return

	if str(cfg.get_value("remap", "importer")) != "texture":
		skipped_non_texture += 1
		return

	var changed := false
	for section_name: String in DEFAULT_PROFILE.keys():
		var section_data: Dictionary = DEFAULT_PROFILE[section_name]
		for section_key: String in section_data.keys():
			var desired: Variant = section_data[section_key]
			var existing: Variant = null
			if cfg.has_section(section_name) and cfg.has_section_key(section_name, section_key):
				existing = cfg.get_value(section_name, section_key)
			if existing != desired:
				cfg.set_value(section_name, section_key, desired)
				changed = true

	if not changed:
		unchanged += 1
		if verbose:
			_print("Unchanged: %s" % import_path)
		return

	if apply_changes:
		err = cfg.save(import_path)
		if err != OK:
			printerr("Could not save import settings: ", import_path, " (", err, ")")
			errors += 1
			return
		if verbose:
			_print("Updated: %s" % import_path)
	else:
		_print("Would update: %s" % import_path)

	updated += 1


func print_summary() -> void:
	if apply_changes:
		_print(
			"Texture import normalization complete: "
			+ "updated=%d unchanged=%d skipped_non_texture=%d errors=%d"
			% [updated, unchanged, skipped_non_texture, errors]
		)
	else:
		_print(
			"Dry-run complete: "
			+ "would-update=%d unchanged=%d skipped_non_texture=%d errors=%d"
			% [updated, unchanged, skipped_non_texture, errors]
		)
		_print("Pass --apply to write normalized settings into .import files.")


func _print(msg: String) -> void:
	print(msg)


func _print_usage() -> void:
	print("Usage:")
	print("  godot --headless --path . --script scripts/normalize_texture_imports.gd [--apply] [--verbose] [--root <path>] [--root=<path>] [--help]")
	print()
	print("Defaults:")
	print("- Dry-run only unless --apply is provided")
	print("- Requires at least one explicit --root path")
	print("- Skips .godot")
