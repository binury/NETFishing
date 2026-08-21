class_name NewGameSetupPage
extends Control

signal start_requested(world_layout: StringName, world_seed: int)
signal back_requested

const WorldLayoutType = preload("res://world/world_layout.gd")
const SaveManagerType = preload("res://save/player_save_manager.gd")
const ControllerFocusNavigationType = preload(
	"res://ui/controller_focus_navigation.gd"
)

enum SeedMode {
	RANDOM,
	CUSTOM,
}

@onready var _paper: PanelContainer = %Paper
@onready var _generated_button: Button = %GeneratedButton
@onready var _starter_button: Button = %StarterButton
@onready var _world_description: Label = %WorldDescription
@onready var _seed_section: VBoxContainer = %SeedSection
@onready var _random_seed_button: Button = %RandomSeedButton
@onready var _custom_seed_button: Button = %CustomSeedButton
@onready var _seed_edit: LineEdit = %SeedEdit
@onready var _seed_help: Label = %SeedHelp
@onready var _overwrite_warning: Label = %OverwriteWarning
@onready var _status: Label = %Status
@onready var _start_button: Button = %StartButton
@onready var _back_button: Button = %BackButton

var _world_layout: StringName = WorldLayoutType.GENERATED
var _seed_mode: SeedMode = SeedMode.RANDOM
var _random_seed: int = SaveManagerType.DEFAULT_WORLD_SEED


func _ready() -> void:
	UtilityPageStyle.apply_page(self)
	_paper.add_theme_stylebox_override(
		"panel", UtilityPageStyle.panel_style()
	)
	for button: Button in [
		_generated_button,
		_starter_button,
		_random_seed_button,
		_custom_seed_button,
		_start_button,
		_back_button,
	]:
		UtilityPageStyle.apply_ocean_button(button)
	UtilityPageStyle.apply_ocean_line_edit(_seed_edit)
	_generated_button.pressed.connect(
		_set_world_layout.bind(WorldLayoutType.GENERATED)
	)
	_starter_button.pressed.connect(
		_set_world_layout.bind(WorldLayoutType.STARTER_ISLAND)
	)
	_random_seed_button.pressed.connect(_choose_random_seed)
	_custom_seed_button.pressed.connect(_choose_custom_seed)
	_seed_edit.text_changed.connect(_on_seed_text_changed)
	_seed_edit.text_submitted.connect(_on_seed_submitted)
	_start_button.pressed.connect(_request_start)
	_back_button.pressed.connect(back_requested.emit)
	hide()


func open_page(has_existing_progression: bool) -> void:
	_world_layout = WorldLayoutType.GENERATED
	_seed_mode = SeedMode.RANDOM
	_roll_random_seed()
	_overwrite_warning.visible = has_existing_progression
	_status.text = ""
	_refresh_presentation()
	show()
	UtilityPageStyle.animate_in(self)
	_generated_button.grab_focus.call_deferred()


func close_page() -> void:
	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	if focus_owner != null and is_ancestor_of(focus_owner):
		focus_owner.release_focus()
	hide()


func request_back() -> void:
	back_requested.emit()


func get_selected_world_layout() -> StringName:
	return _world_layout


func get_selected_world_seed() -> int:
	return (
		_random_seed
		if _seed_mode == SeedMode.RANDOM
		else parse_seed_text(_seed_edit.text)
	)


static func parse_seed_text(text: String) -> int:
	var normalized: String = text.strip_edges()
	if normalized.is_empty():
		return 0
	if normalized.is_valid_int():
		var numeric_seed: int = int(normalized)
		if (
			numeric_seed <= 0
			or numeric_seed > SaveManagerType.MAX_WORLD_SEED
		):
			return 0
		return numeric_seed
	var digest: PackedByteArray = normalized.sha256_buffer()
	var hashed_seed: int = (
		(int(digest[0]) << 24)
		| (int(digest[1]) << 16)
		| (int(digest[2]) << 8)
		| int(digest[3])
	) & 0x7fffffff
	return (hashed_seed % SaveManagerType.MAX_WORLD_SEED) + 1


func _set_world_layout(layout: StringName) -> void:
	if not WorldLayoutType.is_valid(layout):
		return
	_world_layout = layout
	_status.text = ""
	_refresh_presentation()
	if layout == WorldLayoutType.GENERATED:
		_random_seed_button.grab_focus.call_deferred()
	else:
		_start_button.grab_focus.call_deferred()


func _choose_random_seed() -> void:
	_seed_mode = SeedMode.RANDOM
	_roll_random_seed()
	_status.text = ""
	_refresh_presentation()


func _choose_custom_seed() -> void:
	_seed_mode = SeedMode.CUSTOM
	if parse_seed_text(_seed_edit.text) == _random_seed:
		_seed_edit.text = ""
	_status.text = ""
	_refresh_presentation()
	_seed_edit.grab_focus.call_deferred()
	_seed_edit.select_all.call_deferred()


func _roll_random_seed() -> void:
	_random_seed = SaveManagerType.roll_world_seed()
	_seed_edit.text = str(_random_seed)


func _on_seed_text_changed(_text: String) -> void:
	if _seed_mode != SeedMode.CUSTOM:
		return
	_status.text = ""
	_refresh_start_state()


func _on_seed_submitted(_text: String) -> void:
	_request_start()


func _request_start() -> void:
	var seed: int = get_selected_world_seed()
	if _world_layout == WorldLayoutType.GENERATED and seed == 0:
		_status.text = (
			"enter some text or a whole number from 1 to %d."
			% SaveManagerType.MAX_WORLD_SEED
		)
		_seed_edit.grab_focus()
		_seed_edit.select_all()
		return
	if seed == 0:
		seed = SaveManagerType.roll_world_seed()
	_start_button.disabled = true
	start_requested.emit(_world_layout, seed)


func _refresh_presentation() -> void:
	var generated: bool = _world_layout == WorldLayoutType.GENERATED
	_generated_button.set_pressed_no_signal(generated)
	_starter_button.set_pressed_no_signal(not generated)
	_world_description.text = (
		"build a new island from terrain chunks. the same seed always "
		+ "builds the same world."
		if generated
		else "play on the authored starter island."
	)
	_seed_section.visible = generated
	_random_seed_button.set_pressed_no_signal(
		_seed_mode == SeedMode.RANDOM
	)
	_custom_seed_button.set_pressed_no_signal(
		_seed_mode == SeedMode.CUSTOM
	)
	_seed_edit.editable = _seed_mode == SeedMode.CUSTOM
	_seed_edit.focus_mode = (
		Control.FOCUS_ALL
		if _seed_mode == SeedMode.CUSTOM
		else Control.FOCUS_NONE
	)
	_seed_help.text = (
		"press random seed again to roll another world."
		if _seed_mode == SeedMode.RANDOM
		else "enter text or a number from 1 to %d. the same entry makes the same world."
		% SaveManagerType.MAX_WORLD_SEED
	)
	_refresh_start_state()
	_configure_controller_focus()


func _refresh_start_state() -> void:
	_start_button.disabled = (
		_world_layout == WorldLayoutType.GENERATED
		and _seed_mode == SeedMode.CUSTOM
		and parse_seed_text(_seed_edit.text) == 0
	)


func _configure_controller_focus() -> void:
	var generated: bool = _world_layout == WorldLayoutType.GENERATED
	var custom: bool = generated and _seed_mode == SeedMode.CUSTOM
	_set_neighbors(
		_generated_button,
		_generated_button,
		_starter_button,
		_generated_button,
		_random_seed_button if generated else _start_button,
	)
	_set_neighbors(
		_starter_button,
		_generated_button,
		_starter_button,
		_starter_button,
		_custom_seed_button if generated else _back_button,
	)
	_set_neighbors(
		_random_seed_button,
		_random_seed_button,
		_custom_seed_button,
		_generated_button,
		_seed_edit if custom else _start_button,
	)
	_set_neighbors(
		_custom_seed_button,
		_random_seed_button,
		_custom_seed_button,
		_starter_button,
		_seed_edit if custom else _back_button,
	)
	_set_neighbors(
		_seed_edit,
		_seed_edit,
		_seed_edit,
		_custom_seed_button,
		_start_button,
	)
	var action_top: Control = (
		_seed_edit
		if custom
		else _random_seed_button
		if generated
		else _generated_button
	)
	_set_neighbors(
		_start_button,
		_start_button,
		_back_button,
		action_top,
		_start_button,
	)
	_set_neighbors(
		_back_button,
		_start_button,
		_back_button,
		action_top,
		_back_button,
	)
	var traversal: Array[Control] = [
		_generated_button,
		_starter_button,
	]
	if generated:
		traversal.append(_random_seed_button)
		traversal.append(_custom_seed_button)
		if custom:
			traversal.append(_seed_edit)
	traversal.append(_start_button)
	traversal.append(_back_button)
	ControllerFocusNavigationType.configure_traversal(traversal)


func _set_neighbors(
	control: Control,
	left: Control,
	right: Control,
	top: Control,
	bottom: Control,
) -> void:
	control.focus_neighbor_left = control.get_path_to(left)
	control.focus_neighbor_right = control.get_path_to(right)
	control.focus_neighbor_top = control.get_path_to(top)
	control.focus_neighbor_bottom = control.get_path_to(bottom)
