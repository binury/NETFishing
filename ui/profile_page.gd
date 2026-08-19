class_name ProfilePage
extends Control

const CHECK_DEBOUNCE_SECONDS: float = 0.4
const APPEARANCE_PREVIEW_INTERVAL_SECONDS: float = 0.08
const OPTION_GRID_COLUMNS: int = 3
const FUR_PALETTE_GRID_COLUMNS: int = 6
const FUR_PATTERN_GRID_COLUMNS: int = 2
const FUR_CHANNEL_GRID_COLUMNS: int = 2
const FUR_PALETTE_SWATCH_SIZE: float = 38.0
const FUR_CHANNEL_SWATCH_SIZE: float = 22.0
const FUR_PART_TAB_WIDTH: float = 58.0
const FUR_COLOR_PICKER_POPUP_SIZE: Vector2i = Vector2i(720, 560)
const FUR_COLOR_PICKER_SV_SIZE: Vector2i = Vector2i(520, 300)
const VOICE_OPTION_BUTTON_SIZE: Vector2 = Vector2(68.0, 32.0)
const HEADER_ACTION_FONT_SIZE: int = 18
const BODY_COLUMN_SEPARATION: int = 12
const SIZE_ENDPOINT_FONT_SIZE: int = 18
const SIZE_SLIDER_MIN_WIDTH: float = 180.0
const FUR_SECTION_PATTERNS: String = "patterns"
const FUR_SECTION_COLORS: String = "colors"
const FEATURE_DRAWER_ANIMATION_SECONDS: float = 0.16
const FEATURE_PREVIEW_SCAN_MAX_SIZE: int = 256
const FEATURE_PREVIEW_TEXTURE_MAX_SIZE: int = 128
const FEATURE_PREVIEW_PADDING: int = 3
const ControllerMappingManagerType = preload(
	"res://settings/controller_mapping_manager.gd"
)
const OrganizerTabType = preload("res://ui/components/organizer_tab.gd")
const GameTheme: Theme = preload("res://ui/game_theme.tres")
const AnimaleseVoiceType = preload("res://ui/animalese_voice.gd")
const TypewriterRevealType = preload("res://ui/typewriter_reveal.gd")
const VoiceProfilesType = preload(
	"res://player/animalese_voice_profiles.gd"
)
const VOICE_CATEGORY_ID: String = "voice"

enum ControllerZone {
	ACCOUNT,
	CATEGORIES,
	OPTIONS,
	COLOR_PICKER,
}

var _service: NetworkProfileService
var _experience: PlayerExperience
var _draft_name: String = ""
var _draft_appearance: Dictionary = {}
var _persisted_name: String = ""
var _persisted_appearance: Dictionary = {}
var _draft_voice_id: String = VoiceProfilesType.DEFAULT_ID
var _persisted_voice_id: String = VoiceProfilesType.DEFAULT_ID
var _draft_speech_speed_id: String = VoiceProfilesType.DEFAULT_SPEED_ID
var _persisted_speech_speed_id: String = VoiceProfilesType.DEFAULT_SPEED_ID
var _draft_call_id: String = VoiceProfilesType.DEFAULT_CALL_ID
var _persisted_call_id: String = VoiceProfilesType.DEFAULT_CALL_ID
var _draft_sample_set_id: String = VoiceProfilesType.DEFAULT_SAMPLE_SET_ID
var _persisted_sample_set_id: String = VoiceProfilesType.DEFAULT_SAMPLE_SET_ID
var _category_id: String = "species"
var _dirty: bool = false
var _allow_duplicate: bool = false

var _name_edit: LineEdit
var _name_status: Label
var _suggestions: HBoxContainer
var _category_list: VBoxContainer
var _option_list: VBoxContainer
var _preview: ProfilePreview
var _customize_button: Button
var _apply_button: Button
var _revert_button: Button
var _defaults_button: Button
var _reset_view_button: Button
var _reset_view_controller_hint: Label
var _discard_confirmation: PanelContainer
var _confirmation_label: Label
var _confirmation_confirm: Button
var _keep_editing_button: Button
var _confirmation_action: String = ""
var _debounce: Timer
var _appearance_preview_timer: Timer
var _experience_level: Label
var _experience_progress: ProgressBar
var _experience_value: Label
var _feature_preview_cache: Dictionary = {}
var _feature_preview_requests: Array[Dictionary] = []
var _feature_preview_generation: int = 0
var _feature_preview_worker_active: bool = false
var _expanded_feature_drawers: Dictionary = {}
var _feature_drawer_animation_key: String = ""
var _scale_value_label: Label
var _voice_preview: AnimaleseVoiceType
var _voice_preview_tween: Tween
var _active_fur_section: String = FUR_SECTION_PATTERNS
var _active_fur_pattern_id: String = CharacterCustomizationCatalog.FUR_STYLE_ID
var _active_fur_color_id: String = "fur_pattern"
var _fur_color_channel_buttons: Dictionary[String, Button] = {}
var _fur_color_channel_swatches: Dictionary[String, Panel] = {}
var _fur_custom_color_display: Panel
var _fur_custom_color_label: Label
var _controller_mapping_manager: ControllerMappingManagerType
var _controller_zone: ControllerZone = ControllerZone.ACCOUNT
var _controller_option_depth: int = 0
var _active_color_picker_button: ColorPickerButton
var _active_color_picker_return_depth: int = 0
var _profile_active: bool = false
var _profile_interactive: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build_ui()
	_debounce = Timer.new()
	_debounce.one_shot = true
	_debounce.wait_time = CHECK_DEBOUNCE_SECONDS
	_debounce.timeout.connect(_request_conflict_check)
	add_child(_debounce)
	_appearance_preview_timer = Timer.new()
	_appearance_preview_timer.one_shot = true
	_appearance_preview_timer.wait_time = APPEARANCE_PREVIEW_INTERVAL_SECONDS
	_appearance_preview_timer.timeout.connect(_publish_draft_appearance)
	add_child(_appearance_preview_timer)


func _exit_tree() -> void:
	_cancel_feature_preview_requests()
	if _service != null:
		_service.restore_persisted_appearance()


func setup(
	service: NetworkProfileService,
	experience: PlayerExperience,
	world_environment: WorldEnvironment,
	world_sun: DirectionalLight3D,
) -> void:
	_service = service
	_experience = experience
	if not _service.conflict_result.is_connected(_on_conflict_result):
		_service.conflict_result.connect(_on_conflict_result)
		_service.apply_finished.connect(_on_apply_finished)
	if (
		_experience != null
		and not _experience.experience_changed.is_connected(
			_on_experience_changed
		)
	):
		_experience.experience_changed.connect(_on_experience_changed)
	_load_persisted()
	_refresh_experience()
	_preview.setup_world_lighting(world_environment, world_sun)
	var identity_value := find_child("IdentityFingerprint", true, false) as Label
	if identity_value != null:
		var fingerprint := _service.get_identity_fingerprint()
		identity_value.text = "Identity • %s • Stored on this device" % (
			NetworkIdentityCrypto.compact_suffix(fingerprint)
		)
		identity_value.tooltip_text = (
			NetworkIdentityCrypto.format_fingerprint(fingerprint)
		)


func setup_controller_mapping(
	mapping_manager: ControllerMappingManagerType,
) -> void:
	_controller_mapping_manager = mapping_manager
	if _preview != null:
		_preview.setup_controller_mapping(mapping_manager)


func set_world_pixel_size(pixel_size: int) -> void:
	if _preview != null:
		_preview.set_world_pixel_size(pixel_size)


func activate() -> void:
	_profile_active = true
	visible = true
	if _service != null:
		_load_persisted()
	# Keep controller page switches on the Profile navigation bubble. Focusing
	# the name field here summons the Android keyboard during LB/RB traversal.


func deactivate() -> void:
	_profile_active = false
	visible = false
	_debounce.stop()
	_appearance_preview_timer.stop()
	if _service != null:
		_service.restore_persisted_appearance()
	_cancel_feature_preview_requests()
	if _voice_preview_tween != null and _voice_preview_tween.is_valid():
		_voice_preview_tween.kill()
	_preview.reset_view()


func set_interactive(interactive: bool) -> void:
	_profile_interactive = interactive and _profile_active
	mouse_filter = (
		Control.MOUSE_FILTER_PASS
		if _profile_interactive else Control.MOUSE_FILTER_IGNORE
	)
	_apply_controller_zone_focus()


func reset_controller_zone() -> void:
	_controller_zone = ControllerZone.ACCOUNT
	_controller_option_depth = 0
	_apply_controller_zone_focus()
	call_deferred("_focus_controller_zone")


func consume_escape() -> bool:
	if _discard_confirmation.visible:
		_close_discard_confirmation()
		return true
	if _name_edit.has_focus():
		_name_edit.release_focus()
		return true
	if _dirty:
		_show_confirmation("discard")
		return true
	return false


func handle_controller_input(event: InputEvent) -> bool:
	if not _profile_active or not _profile_interactive:
		return false
	var reset_view_pressed := _event_matches_controller_press(
		event,
		&"sneak",
		ControllerMappingManagerType.ROLE_RIGHT_STICK_CLICK,
		JOY_BUTTON_RIGHT_STICK,
	)
	if reset_view_pressed:
		_preview.reset_view()
		return true
	if (
		event.is_action_pressed(&"ui_up")
		or event.is_action_pressed(&"ui_down")
		or event.is_action_pressed(&"ui_left")
		or event.is_action_pressed(&"ui_right")
	):
		_ensure_controller_zone_focus()
	var cancel_pressed := _event_matches_controller_press(
		event,
		&"ui_cancel",
		ControllerMappingManagerType.ROLE_B,
		JOY_BUTTON_B,
	)
	if cancel_pressed:
		if _discard_confirmation.visible:
			_close_discard_confirmation()
			return true
		match _controller_zone:
			ControllerZone.COLOR_PICKER:
				_close_controller_color_picker()
			ControllerZone.OPTIONS:
				if _controller_option_depth > 0:
					_controller_option_depth -= 1
					_apply_controller_zone_focus()
					call_deferred("_focus_controller_zone")
				else:
					_controller_zone = ControllerZone.CATEGORIES
					_apply_controller_zone_focus()
					call_deferred("_focus_controller_zone")
			ControllerZone.CATEGORIES:
				_controller_zone = ControllerZone.ACCOUNT
				_apply_controller_zone_focus()
				call_deferred("_focus_controller_zone")
			ControllerZone.ACCOUNT:
				return false
		return true
	if _controller_zone == ControllerZone.ACCOUNT:
		return false
	var accept_pressed := _event_matches_controller_press(
		event,
		&"ui_accept",
		ControllerMappingManagerType.ROLE_A,
		JOY_BUTTON_A,
	)
	if (
		_controller_zone == ControllerZone.CATEGORIES
		and accept_pressed
	):
		var focused_category := get_viewport().gui_get_focus_owner() as Button
		if focused_category != null and _category_list.is_ancestor_of(
			focused_category
		):
			focused_category.pressed.emit()
		_controller_zone = ControllerZone.OPTIONS
		_controller_option_depth = 0
		_apply_controller_zone_focus.call_deferred()
		_focus_controller_zone.call_deferred()
		return true
	if (
		_controller_zone == ControllerZone.OPTIONS
		and accept_pressed
	):
		var groups: Array = _controller_option_groups()
		if _controller_option_depth < groups.size() - 1:
			var focused_option := get_viewport().gui_get_focus_owner() as BaseButton
			_controller_option_depth += 1
			if focused_option != null:
				focused_option.pressed.emit()
			_apply_controller_zone_focus.call_deferred()
			_focus_controller_zone.call_deferred()
			return true
	return false


func _event_matches_controller_press(
	event: InputEvent,
	action: StringName,
	role: StringName,
	fallback_button: JoyButton,
) -> bool:
	if event.is_action_pressed(action):
		return true
	var button_event := event as InputEventJoypadButton
	if button_event == null or not button_event.pressed:
		return false
	if _controller_mapping_manager != null:
		return _controller_mapping_manager.event_matches_role(event, role)
	return button_event.button_index == fallback_button


func _process(delta: float) -> void:
	if (
		not _profile_active
		or not _profile_interactive
	):
		return
	var right_stick := Vector2(
		_controller_mapping_manager.get_role_axis(
			ControllerMappingManagerType.ROLE_RIGHT_STICK_X
		)
		if _controller_mapping_manager != null
		else Input.get_joy_axis(0, JOY_AXIS_RIGHT_X),
		_controller_mapping_manager.get_role_axis(
			ControllerMappingManagerType.ROLE_RIGHT_STICK_Y
		)
		if _controller_mapping_manager != null
		else Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y),
	)
	if right_stick.length() < 0.16:
		return
	if _controller_zone == ControllerZone.COLOR_PICKER:
		_adjust_controller_color_gamut(right_stick, delta)
	else:
		_preview.apply_controller_orbit(right_stick, delta)


func _apply_controller_zone_focus() -> void:
	if not is_node_ready():
		return
	var account_controls: Array[Control] = _account_controller_controls()
	var category_controls: Array[Control] = _controls_under(_category_list)
	var option_groups: Array = _controller_option_groups()
	var all_option_controls: Array[Control] = []
	for group_value: Variant in option_groups:
		var group := group_value as Array
		for item: Variant in group:
			var control := item as Control
			if control != null and control not in all_option_controls:
				all_option_controls.append(control)
	for control: Control in account_controls + category_controls + all_option_controls:
		control.focus_mode = Control.FOCUS_NONE
	for control: Control in [_confirmation_confirm, _keep_editing_button]:
		if control != null:
			control.focus_mode = Control.FOCUS_NONE
	if _preview != null:
		_preview.focus_mode = Control.FOCUS_NONE
	if _reset_view_button != null:
		_reset_view_button.focus_mode = Control.FOCUS_NONE
	if not _profile_interactive:
		return
	if _discard_confirmation != null and _discard_confirmation.visible:
		var confirmation_controls: Array[Control] = [
			_confirmation_confirm,
			_keep_editing_button,
		]
		for control: Control in confirmation_controls:
			control.focus_mode = Control.FOCUS_ALL
		ControllerFocusNavigation.configure_spatial_neighbors(
			confirmation_controls
		)
		return
	var active_controls: Array[Control] = []
	match _controller_zone:
		ControllerZone.ACCOUNT:
			active_controls = account_controls
		ControllerZone.CATEGORIES:
			active_controls = category_controls
		ControllerZone.OPTIONS:
			if not option_groups.is_empty():
				_controller_option_depth = clampi(
					_controller_option_depth,
					0,
					option_groups.size() - 1,
				)
				for item: Variant in option_groups[_controller_option_depth]:
					var control := item as Control
					if control != null:
						active_controls.append(control)
		ControllerZone.COLOR_PICKER:
			active_controls = _color_picker_controller_controls()
	for control: Control in active_controls:
		var button := control as BaseButton
		control.focus_mode = (
			Control.FOCUS_ALL
			if button == null or not button.disabled
			else Control.FOCUS_NONE
		)
	ControllerFocusNavigation.configure_spatial_neighbors(active_controls)


func _focus_controller_zone() -> void:
	if not _profile_interactive:
		return
	var controls: Array[Control] = _active_controller_zone_controls()
	for control: Control in controls:
		var button := control as BaseButton
		if (
			button != null
			and button.button_pressed
			and button.focus_mode != Control.FOCUS_NONE
			and button.is_visible_in_tree()
			and not button.disabled
		):
			button.grab_focus()
			return
	for control: Control in controls:
		if control.focus_mode != Control.FOCUS_NONE:
			control.grab_focus()
			return


func _ensure_controller_zone_focus() -> void:
	var controls: Array[Control] = _active_controller_zone_controls()
	if controls.is_empty():
		if _controller_zone == ControllerZone.OPTIONS:
			_controller_zone = ControllerZone.CATEGORIES
			_controller_option_depth = 0
			controls = _active_controller_zone_controls()
		if controls.is_empty():
			return
	var focused: Control = get_viewport().gui_get_focus_owner()
	if (
		focused != null
		and focused in controls
		and focused.is_visible_in_tree()
		and focused.focus_mode != Control.FOCUS_NONE
	):
		return
	_apply_controller_zone_focus()
	_focus_controller_zone()


func _active_controller_zone_controls() -> Array[Control]:
	if (
		_discard_confirmation != null
		and _discard_confirmation.visible
	):
		return [_confirmation_confirm, _keep_editing_button]
	match _controller_zone:
		ControllerZone.ACCOUNT:
			return _account_controller_controls()
		ControllerZone.CATEGORIES:
			return _controls_under(_category_list)
		ControllerZone.OPTIONS:
			var groups: Array = _controller_option_groups()
			if groups.is_empty():
				return []
			var controls: Array[Control] = []
			for item: Variant in groups[clampi(
				_controller_option_depth, 0, groups.size() - 1
			)]:
				var option_control := item as Control
				if option_control != null:
					controls.append(option_control)
			return controls
		ControllerZone.COLOR_PICKER:
			return _color_picker_controller_controls()
	return []


func _account_controller_controls() -> Array[Control]:
	var controls: Array[Control] = []
	for control: Control in [
		_name_edit,
		_customize_button,
		_apply_button,
		_revert_button,
		_defaults_button,
	]:
		if control != null and control.is_visible_in_tree():
			controls.append(control)
	for control: Control in _controls_under(_suggestions):
		if control not in controls:
			controls.append(control)
	return controls


func _controller_option_groups() -> Array:
	var groups: Array = []
	if _option_list == null:
		return groups
	if _category_id != "fur_pattern":
		var option_controls: Array[Control] = _controls_under(_option_list)
		if not option_controls.is_empty():
			groups.append(option_controls)
		return groups
	var section_tabs := _option_list.find_child(
		"FurSectionTabs", true, false
	) as Node
	_append_controller_group(groups, _controls_under(section_tabs))
	if _active_fur_section == FUR_SECTION_PATTERNS:
		_append_controller_group(groups, _controls_under(_option_list.find_child(
			"FurPatternPartTabs", true, false
		)))
		_append_controller_group(groups, _controls_under(_option_list.find_child(
			"FurPatternGrid", true, false
		)))
	else:
		_append_controller_group(groups, _controls_under(_option_list.find_child(
			"FurColorChannelGrid", true, false
		)))
		var palette_controls: Array[Control] = _controls_under(
			_option_list.find_child("FurPaletteGrid", true, false)
		)
		var custom_picker := _option_list.find_child(
			"FurCustomColorPicker", true, false
		) as Control
		if custom_picker != null:
			palette_controls.append(custom_picker)
		_append_controller_group(groups, palette_controls)
	return groups


func _append_controller_group(groups: Array, controls: Array[Control]) -> void:
	if not controls.is_empty():
		groups.append(controls)


func _controls_under(root: Node) -> Array[Control]:
	var controls: Array[Control] = []
	if root == null:
		return controls
	_collect_controller_controls(root, controls)
	return controls


func _collect_controller_controls(
	root: Node,
	output: Array[Control],
) -> void:
	for child: Node in root.get_children():
		var control := child as Control
		if control != null and not control.is_visible_in_tree():
			continue
		if control is BaseButton or control is Slider or control is LineEdit:
			output.append(control)
		_collect_controller_controls(child, output)


func has_unsaved_changes() -> bool:
	return _dirty


func request_close_confirmation() -> bool:
	if not _dirty:
		return false
	_show_confirmation("discard")
	return true


func has_modal_confirmation() -> bool:
	return (
		_discard_confirmation != null
		and _discard_confirmation.visible
	)


func _build_ui() -> void:
	UtilityPageStyle.apply_page(self)
	var margin: MarginContainer = UtilityPageStyle.build_laptop_screen(self)
	margin.name = "ProfileContentZone"
	var layout := VBoxContainer.new()
	layout.name = "ProfileLayout"
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)

	var account_row := HBoxContainer.new()
	account_row.name = "ProfileAccountRow"
	account_row.add_theme_constant_override("separation", 14)
	layout.add_child(account_row)
	var account_stack := VBoxContainer.new()
	account_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	account_stack.add_theme_constant_override("separation", 2)
	account_row.add_child(account_stack)
	var name_line := HBoxContainer.new()
	name_line.add_theme_constant_override("separation", 10)
	account_stack.add_child(name_line)
	var name_label := Label.new()
	name_label.text = "player name"
	name_label.custom_minimum_size.x = 98.0
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override(
		"font_color", UtilityPageStyle.OCEAN_TEXT_PRIMARY
	)
	name_line.add_child(name_label)
	_name_edit = LineEdit.new()
	_name_edit.max_length = NetworkProtocol.MAX_DISPLAY_NAME_LENGTH
	_name_edit.placeholder_text = "Player"
	_name_edit.custom_minimum_size = Vector2(280, 34)
	UtilityPageStyle.apply_ocean_line_edit(_name_edit)
	_name_edit.add_theme_stylebox_override(
		"normal", UtilityPageStyle.ocean_button_style(
			UtilityPageStyle.OCEAN_PANEL_MID
		)
	)
	_name_edit.text_changed.connect(_on_name_changed)
	name_line.add_child(_name_edit)
	var helper := Label.new()
	helper.text = "Shown to other players in multiplayer."
	helper.add_theme_font_size_override("font_size", 12)
	helper.add_theme_color_override(
		"font_color", UtilityPageStyle.OCEAN_TEXT_SECONDARY
	)
	account_stack.add_child(helper)
	_name_status = Label.new()
	_name_status.add_theme_font_size_override("font_size", 12)
	_name_status.add_theme_color_override(
		"font_color", UtilityPageStyle.OCEAN_TEXT_SECONDARY
	)
	account_stack.add_child(_name_status)
	_suggestions = HBoxContainer.new()
	_suggestions.add_theme_constant_override("separation", 6)
	account_stack.add_child(_suggestions)

	var identity_value := Label.new()
	identity_value.name = "IdentityFingerprint"
	identity_value.text = "identity • stored on this device"
	identity_value.tooltip_text = (
		"This identity helps other players recognize you between sessions."
	)
	identity_value.add_theme_font_size_override("font_size", 12)
	identity_value.add_theme_color_override(
		"font_color", UtilityPageStyle.OCEAN_TEXT_SECONDARY
	)
	account_stack.add_child(identity_value)

	var experience_row := HBoxContainer.new()
	experience_row.add_theme_constant_override("separation", 9)
	account_stack.add_child(experience_row)
	_experience_level = Label.new()
	_experience_level.custom_minimum_size.x = 64.0
	_experience_level.add_theme_font_size_override("font_size", 14)
	_experience_level.add_theme_color_override(
		"font_color", UtilityPageStyle.OCEAN_TEXT_PRIMARY
	)
	experience_row.add_child(_experience_level)
	_experience_progress = ProgressBar.new()
	_experience_progress.custom_minimum_size = Vector2(210.0, 14.0)
	_experience_progress.max_value = 1.0
	_experience_progress.show_percentage = false
	_experience_progress.add_theme_stylebox_override(
		"background", UtilityPageStyle.rounded_style(
			UtilityPageStyle.OCEAN_PANEL_MID, 7
		)
	)
	_experience_progress.add_theme_stylebox_override(
		"fill", UtilityPageStyle.rounded_style(
			UtilityPageStyle.OCEAN_SELECTED, 7
		)
	)
	experience_row.add_child(_experience_progress)
	_experience_value = Label.new()
	_experience_value.add_theme_font_size_override("font_size", 14)
	_experience_value.add_theme_color_override(
		"font_color", UtilityPageStyle.OCEAN_TEXT_SECONDARY
	)
	experience_row.add_child(_experience_value)

	var actions := HBoxContainer.new()
	actions.name = "ProfileActionRow"
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	actions.add_theme_constant_override("separation", 7)
	account_row.add_child(actions)
	_customize_button = Button.new()
	_customize_button.text = "customize"
	_customize_button.custom_minimum_size.x = 96.0
	UtilityPageStyle.apply_compact_ocean_button(_customize_button)
	_customize_button.add_theme_font_size_override(
		"font_size", HEADER_ACTION_FONT_SIZE
	)
	_customize_button.pressed.connect(_enter_controller_customization)
	actions.add_child(_customize_button)
	_apply_button = Button.new()
	_apply_button.text = "apply"
	_apply_button.custom_minimum_size.x = 72.0
	UtilityPageStyle.apply_compact_ocean_button(_apply_button)
	_apply_button.add_theme_font_size_override(
		"font_size", HEADER_ACTION_FONT_SIZE
	)
	_apply_button.pressed.connect(_apply)
	actions.add_child(_apply_button)
	_revert_button = Button.new()
	_revert_button.text = "revert"
	_revert_button.custom_minimum_size.x = 76.0
	UtilityPageStyle.apply_compact_ocean_button(_revert_button)
	_revert_button.add_theme_font_size_override(
		"font_size", HEADER_ACTION_FONT_SIZE
	)
	_revert_button.pressed.connect(_revert)
	actions.add_child(_revert_button)
	_defaults_button = Button.new()
	_defaults_button.text = "defaults"
	_defaults_button.custom_minimum_size.x = 82.0
	UtilityPageStyle.apply_compact_ocean_button(_defaults_button)
	_defaults_button.add_theme_font_size_override(
		"font_size", HEADER_ACTION_FONT_SIZE
	)
	_defaults_button.pressed.connect(_show_confirmation.bind("defaults"))
	actions.add_child(_defaults_button)

	var body_panel := PanelContainer.new()
	body_panel.name = "ProfileBodyPanel"
	body_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_panel.add_theme_stylebox_override(
		"panel", UtilityPageStyle.row_style(false)
	)
	layout.add_child(body_panel)
	var body_margin := MarginContainer.new()
	body_margin.add_theme_constant_override("margin_left", 14)
	body_margin.add_theme_constant_override("margin_top", 10)
	body_margin.add_theme_constant_override("margin_right", 14)
	body_margin.add_theme_constant_override("margin_bottom", 10)
	body_panel.add_child(body_margin)
	var body := HBoxContainer.new()
	body.alignment = BoxContainer.ALIGNMENT_BEGIN
	body.add_theme_constant_override(
		"separation", BODY_COLUMN_SEPARATION
	)
	body_margin.add_child(body)
	var category_scroll := ScrollContainer.new()
	category_scroll.name = "CategoryScroll"
	category_scroll.custom_minimum_size.x = 120.0
	category_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	category_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	category_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	body.add_child(category_scroll)
	_category_list = VBoxContainer.new()
	_category_list.custom_minimum_size = Vector2(120, 0)
	_category_list.add_theme_constant_override("separation", 5)
	category_scroll.add_child(_category_list)
	_option_list = VBoxContainer.new()
	_option_list.custom_minimum_size = Vector2(326, 0)
	_option_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_option_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_option_list.add_theme_constant_override("separation", 5)
	body.add_child(_option_list)
	var body_spacer := Control.new()
	body_spacer.custom_minimum_size.x = 12.0
	body_spacer.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(body_spacer)
	var preview_stack := VBoxContainer.new()
	preview_stack.custom_minimum_size.x = 240.0
	preview_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	preview_stack.add_theme_constant_override("separation", 7)
	body.add_child(preview_stack)
	var preview_frame := PanelContainer.new()
	preview_frame.custom_minimum_size = Vector2(240.0, 0.0)
	preview_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_frame.add_theme_stylebox_override(
		"panel", UtilityPageStyle.rounded_style(
			UtilityPageStyle.OCEAN_FIELD, 18
		)
	)
	preview_stack.add_child(preview_frame)
	var preview_layer := Control.new()
	preview_layer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_layer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_layer.mouse_filter = Control.MOUSE_FILTER_PASS
	preview_frame.add_child(preview_layer)
	_preview = preload("res://ui/profile_preview.tscn").instantiate()
	_preview.custom_minimum_size = Vector2(240.0, 0.0)
	_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_layer.add_child(_preview)
	_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_reset_view_button = Button.new()
	_reset_view_button.text = "↶"
	_reset_view_button.tooltip_text = "reset view"
	_reset_view_button.custom_minimum_size = Vector2(36.0, 36.0)
	_reset_view_button.position = Vector2(-8.0, -8.0)
	_reset_view_button.z_index = 2
	_reset_view_button.focus_mode = Control.FOCUS_NONE
	_reset_view_button.pressed.connect(_preview.reset_view)
	UtilityPageStyle.apply_compact_ocean_button(_reset_view_button)
	_reset_view_button.add_theme_font_size_override("font_size", 22)
	preview_layer.add_child(_reset_view_button)
	_reset_view_controller_hint = Label.new()
	_reset_view_controller_hint.name = "ResetViewControllerHint"
	_reset_view_controller_hint.text = "Reset View: RS"
	_reset_view_controller_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reset_view_controller_hint.focus_mode = Control.FOCUS_NONE
	_reset_view_controller_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reset_view_controller_hint.add_theme_font_size_override("font_size", 14)
	_reset_view_controller_hint.add_theme_color_override(
		"font_color", UtilityPageStyle.OCEAN_TEXT_SECONDARY
	)
	preview_stack.add_child(_reset_view_controller_hint)

	_discard_confirmation = PanelContainer.new()
	_discard_confirmation.visible = false
	_discard_confirmation.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_discard_confirmation.custom_minimum_size = Vector2(430, 190)
	_discard_confirmation.add_theme_stylebox_override(
		"panel", UtilityPageStyle.rounded_style(
			UtilityPageStyle.OCEAN_PANEL_MID, 14
		)
	)
	add_child(_discard_confirmation)
	var confirm_stack := VBoxContainer.new()
	confirm_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	confirm_stack.add_theme_constant_override("separation", 16)
	_discard_confirmation.add_child(confirm_stack)
	_confirmation_label = Label.new()
	_confirmation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirm_stack.add_child(_confirmation_label)
	var confirm_buttons := HBoxContainer.new()
	confirm_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	confirm_stack.add_child(confirm_buttons)
	_confirmation_confirm = Button.new()
	_confirmation_confirm.pressed.connect(_confirm_pending_action)
	UtilityPageStyle.apply_ocean_button(_confirmation_confirm)
	confirm_buttons.add_child(_confirmation_confirm)
	_keep_editing_button = Button.new()
	_keep_editing_button.text = "keep editing"
	_keep_editing_button.pressed.connect(_close_discard_confirmation)
	UtilityPageStyle.apply_ocean_button(_keep_editing_button)
	confirm_buttons.add_child(_keep_editing_button)

	_build_categories()


func _enter_controller_customization() -> void:
	if not _profile_active or not _profile_interactive:
		return
	_controller_zone = ControllerZone.CATEGORIES
	_controller_option_depth = 0
	_apply_controller_zone_focus.call_deferred()
	call_deferred("_focus_controller_zone")


func _build_categories() -> void:
	for child: Node in _category_list.get_children():
		child.queue_free()
	var category_ids: Array[String] = []
	for appearance_category: String in CharacterCustomizationCatalog.CATEGORY_IDS:
		category_ids.append(appearance_category)
	category_ids.append(VOICE_CATEGORY_ID)
	for category_id: String in category_ids:
		var button := Button.new()
		button.text = _category_label(category_id)
		button.toggle_mode = true
		button.custom_minimum_size.x = 120.0
		button.button_pressed = category_id == _category_id
		button.pressed.connect(_select_category.bind(category_id))
		UtilityPageStyle.apply_compact_ocean_button(button)
		_category_list.add_child(button)
	_refresh_options()


func _select_category(category_id: String) -> void:
	_category_id = category_id
	for child: Node in _category_list.get_children():
		var button := child as Button
		if button != null:
			button.button_pressed = button.text == (
				_category_label(category_id)
			)
	_refresh_options()


func _refresh_options() -> void:
	_cancel_feature_preview_requests()
	_fur_color_channel_buttons.clear()
	_fur_color_channel_swatches.clear()
	_fur_custom_color_display = null
	_fur_custom_color_label = null
	for child: Node in _option_list.get_children():
		_option_list.remove_child(child)
		child.queue_free()
	_refresh_controller_zone_after_options.call_deferred()
	if _category_id == VOICE_CATEGORY_ID:
		_build_voice_options()
		return
	if _category_id == CharacterCustomizationCatalog.SCALE_CATEGORY_ID:
		_build_scale_option()
		return
	var options: Array = CharacterCustomizationCatalog.options_for(_category_id)
	if options.is_empty():
		var empty := Label.new()
		empty.text = "More options coming later."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_option_list.add_child(empty)
		return
	if _category_id == "fur_pattern":
		_build_fur_options(options)
		return
	if _category_id in CharacterCustomizationCatalog.FEATURE_CATEGORIES:
		_build_feature_preview_options(options)
		return
	for option: Dictionary in options:
		var option_id := str(option["id"])
		var button := Button.new()
		button.text = "×" if option_id == "none" else str(option["label"])
		button.tooltip_text = "none" if option_id == "none" else str(
			option["label"]
		)
		button.toggle_mode = true
		button.custom_minimum_size.x = 170.0
		button.button_pressed = _draft_appearance.get(_category_id) == option_id
		button.pressed.connect(_select_option.bind(_category_id, option_id))
		UtilityPageStyle.apply_compact_ocean_button(button)
		if option_id == "none":
			button.add_theme_font_size_override("font_size", 24)
		_option_list.add_child(button)


func _category_label(category_id: String) -> String:
	return (
		"voice"
		if category_id == VOICE_CATEGORY_ID
		else CharacterCustomizationCatalog.category_label(category_id)
	)


func _build_voice_options() -> void:
	var description := Label.new()
	description.text = (
		"Choose how your character sounds. "
		+ "Playback speed affects this device only."
	)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description.add_theme_font_size_override("font_size", 12)
	description.add_theme_color_override(
		"font_color", UtilityPageStyle.OCEAN_TEXT_SECONDARY
	)
	_option_list.add_child(description)
	var settings_grid := GridContainer.new()
	settings_grid.name = "VoiceSettingsGrid"
	settings_grid.columns = 2
	settings_grid.add_theme_constant_override("h_separation", 8)
	settings_grid.add_theme_constant_override("v_separation", 8)
	settings_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_option_list.add_child(settings_grid)
	var sample_set_title := Label.new()
	sample_set_title.text = "voice set"
	sample_set_title.custom_minimum_size.x = 92.0
	sample_set_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sample_set_title.add_theme_font_size_override("font_size", 13)
	sample_set_title.add_theme_color_override(
		"font_color", UtilityPageStyle.OCEAN_TEXT_PRIMARY
	)
	settings_grid.add_child(sample_set_title)
	var sample_set_grid := GridContainer.new()
	sample_set_grid.name = "VoiceSampleSetGrid"
	sample_set_grid.columns = mini(
		3,
		VoiceProfilesType.SAMPLE_SET_OPTIONS.size(),
	)
	sample_set_grid.add_theme_constant_override("h_separation", 8)
	sample_set_grid.add_theme_constant_override("v_separation", 4)
	sample_set_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_grid.add_child(sample_set_grid)
	var sample_set_group := ButtonGroup.new()
	sample_set_group.allow_unpress = false
	for option: Dictionary in VoiceProfilesType.SAMPLE_SET_OPTIONS:
		var sample_set_id := str(option.get("id", ""))
		var sample_set_button := Button.new()
		sample_set_button.name = "VoiceSet_%s" % sample_set_id
		sample_set_button.text = str(option.get("label", sample_set_id))
		sample_set_button.toggle_mode = true
		sample_set_button.button_group = sample_set_group
		sample_set_button.custom_minimum_size = VOICE_OPTION_BUTTON_SIZE
		sample_set_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sample_set_button.button_pressed = (
			_draft_sample_set_id == sample_set_id
		)
		sample_set_button.pressed.connect(
			_select_sample_set_option.bind(sample_set_id)
		)
		_apply_voice_option_button(sample_set_button)
		sample_set_grid.add_child(sample_set_button)
	var pitch_title := Label.new()
	pitch_title.text = "pitch"
	pitch_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pitch_title.add_theme_font_size_override("font_size", 13)
	pitch_title.add_theme_color_override(
		"font_color", UtilityPageStyle.OCEAN_TEXT_PRIMARY
	)
	settings_grid.add_child(pitch_title)
	var grid := GridContainer.new()
	grid.name = "VoicePitchGrid"
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_grid.add_child(grid)
	var pitch_group := ButtonGroup.new()
	pitch_group.allow_unpress = false
	for option: Dictionary in VoiceProfilesType.OPTIONS:
		var option_id := str(option.get("id", ""))
		var button := Button.new()
		button.text = str(option.get("label", option_id))
		button.toggle_mode = true
		button.button_group = pitch_group
		button.custom_minimum_size = VOICE_OPTION_BUTTON_SIZE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.button_pressed = _draft_voice_id == option_id
		button.pressed.connect(_select_voice_option.bind(option_id))
		_apply_voice_option_button(button)
		grid.add_child(button)
	var speed_title := Label.new()
	speed_title.text = "playback speed"
	speed_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	speed_title.add_theme_font_size_override("font_size", 13)
	speed_title.add_theme_color_override(
		"font_color", UtilityPageStyle.OCEAN_TEXT_PRIMARY
	)
	settings_grid.add_child(speed_title)
	var speed_grid := GridContainer.new()
	speed_grid.name = "VoiceSpeedGrid"
	speed_grid.columns = 3
	speed_grid.add_theme_constant_override("h_separation", 6)
	speed_grid.add_theme_constant_override("v_separation", 4)
	speed_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_grid.add_child(speed_grid)
	var speed_group := ButtonGroup.new()
	speed_group.allow_unpress = false
	for option: Dictionary in VoiceProfilesType.SPEED_OPTIONS:
		var speed_id := str(option.get("id", ""))
		var speed_button := Button.new()
		speed_button.text = str(option.get("label", speed_id))
		speed_button.tooltip_text = "%d characters per second" % roundi(
			float(option.get("characters_per_second", 28.0))
		)
		speed_button.toggle_mode = true
		speed_button.button_group = speed_group
		speed_button.custom_minimum_size = VOICE_OPTION_BUTTON_SIZE
		speed_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		speed_button.button_pressed = _draft_speech_speed_id == speed_id
		speed_button.pressed.connect(
			_select_speech_speed_option.bind(speed_id)
		)
		_apply_voice_option_button(speed_button)
		speed_grid.add_child(speed_button)
	var call_title := Label.new()
	call_title.text = "call (G)"
	call_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	call_title.add_theme_font_size_override("font_size", 13)
	call_title.add_theme_color_override(
		"font_color", UtilityPageStyle.OCEAN_TEXT_PRIMARY
	)
	settings_grid.add_child(call_title)
	var call_grid := GridContainer.new()
	call_grid.name = "VoiceCallGrid"
	call_grid.columns = 2
	call_grid.add_theme_constant_override("h_separation", 8)
	call_grid.add_theme_constant_override("v_separation", 8)
	call_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_grid.add_child(call_grid)
	var call_group := ButtonGroup.new()
	call_group.allow_unpress = false
	for option: Dictionary in VoiceProfilesType.CALL_OPTIONS:
		var call_id := str(option.get("id", ""))
		var call_button := Button.new()
		call_button.text = str(option.get("label", call_id))
		call_button.toggle_mode = true
		call_button.button_group = call_group
		call_button.custom_minimum_size = VOICE_OPTION_BUTTON_SIZE
		call_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		call_button.button_pressed = _draft_call_id == call_id
		call_button.pressed.connect(_select_call_option.bind(call_id))
		_apply_voice_option_button(call_button)
		call_grid.add_child(call_button)


func _apply_voice_option_button(button: Button) -> void:
	UtilityPageStyle.apply_compact_ocean_button(button)
	button.custom_minimum_size = VOICE_OPTION_BUTTON_SIZE
	button.add_theme_font_size_override("font_size", 12)
	for state: StringName in [
		&"normal", &"hover", &"pressed", &"focus", &"disabled",
	]:
		var style := button.get_theme_stylebox(state).duplicate() as StyleBoxFlat
		if style == null:
			continue
		style.content_margin_left = 6.0
		style.content_margin_right = 6.0
		button.add_theme_stylebox_override(state, style)


func _select_sample_set_option(sample_set_id: String) -> void:
	if not VoiceProfilesType.is_valid_sample_set(sample_set_id):
		return
	_draft_sample_set_id = sample_set_id
	_dirty = _draft_differs()
	_refresh_actions()
	_play_voice_preview()


func _select_voice_option(voice_id: String) -> void:
	if not VoiceProfilesType.is_valid(voice_id):
		return
	_draft_voice_id = voice_id
	_dirty = _draft_differs()
	_refresh_actions()
	_play_voice_preview()


func _select_speech_speed_option(speed_id: String) -> void:
	if not VoiceProfilesType.is_valid_speed(speed_id):
		return
	_draft_speech_speed_id = speed_id
	_dirty = _draft_differs()
	_refresh_actions()
	_play_voice_preview()


func _select_call_option(call_id: String) -> void:
	if not VoiceProfilesType.is_valid_call(call_id):
		return
	_draft_call_id = call_id
	_dirty = _draft_differs()
	_refresh_actions()


func _play_voice_preview() -> void:
	if _voice_preview_tween != null and _voice_preview_tween.is_valid():
		_voice_preview_tween.kill()
	if not is_instance_valid(_voice_preview):
		_voice_preview = AnimaleseVoiceType.new()
		_voice_preview.name = "ProfileVoicePreview"
		add_child(_voice_preview)
	_voice_preview_tween = _voice_preview.speak_text(
		self,
		"hello there!",
		"profile-preview",
		_draft_voice_id,
		VoiceProfilesType.speed_for(_draft_speech_speed_id),
		_draft_sample_set_id,
	)


func _build_scale_option() -> void:
	var description := Label.new()
	description.text = "Adjust your character's visual size."
	description.add_theme_font_size_override("font_size", 14)
	description.add_theme_color_override(
		"font_color", UtilityPageStyle.OCEAN_TEXT_SECONDARY
	)
	_option_list.add_child(description)

	var value_row := HBoxContainer.new()
	value_row.add_theme_constant_override("separation", 10)
	value_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_option_list.add_child(value_row)

	var small_label := Label.new()
	small_label.text = "small"
	small_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	small_label.add_theme_font_size_override(
		"font_size", SIZE_ENDPOINT_FONT_SIZE
	)
	small_label.add_theme_color_override(
		"font_color", UtilityPageStyle.OCEAN_TEXT_SECONDARY
	)
	value_row.add_child(small_label)

	var slider := HSlider.new()
	slider.name = "CharacterScaleSlider"
	slider.min_value = CharacterCustomizationCatalog.MIN_CHARACTER_SCALE
	slider.max_value = CharacterCustomizationCatalog.MAX_CHARACTER_SCALE
	slider.step = CharacterCustomizationCatalog.CHARACTER_SCALE_STEP
	slider.custom_minimum_size = Vector2(SIZE_SLIDER_MIN_WIDTH, 40.0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.tooltip_text = "character size"
	slider.value = CharacterCustomizationCatalog.character_scale(
		_draft_appearance.get(
			CharacterCustomizationCatalog.SCALE_CATEGORY_ID,
			CharacterCustomizationCatalog.DEFAULT_CHARACTER_SCALE,
		)
	)
	slider.value_changed.connect(_select_scale)
	value_row.add_child(slider)

	var large_label := Label.new()
	large_label.text = "large"
	large_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	large_label.add_theme_font_size_override(
		"font_size", SIZE_ENDPOINT_FONT_SIZE
	)
	large_label.add_theme_color_override(
		"font_color", UtilityPageStyle.OCEAN_TEXT_SECONDARY
	)
	value_row.add_child(large_label)

	_scale_value_label = Label.new()
	_scale_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_scale_value_label.add_theme_font_size_override("font_size", 20)
	_scale_value_label.add_theme_color_override(
		"font_color", UtilityPageStyle.OCEAN_TEXT_PRIMARY
	)
	_option_list.add_child(_scale_value_label)
	_update_scale_value_label(float(slider.value))


func _build_feature_preview_options(_options: Array) -> void:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(190.0, 0.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_option_list.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = OPTION_GRID_COLUMNS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	var selected_id := CharacterCustomizationCatalog.canonical_option_id(
		_category_id, str(_draft_appearance.get(_category_id, ""))
	)
	var groups: Array = CharacterCustomizationCatalog.feature_option_groups(
		_category_id
	)
	var expanded_drawer_id := str(
		_expanded_feature_drawers.get(_category_id, "")
	)
	if expanded_drawer_id.is_empty():
		for group: Dictionary in groups:
			var group_options: Array = group.get("options", []) as Array
			if group_options.size() <= 1:
				continue
			var representative_id := str(
				(group_options[0] as Dictionary).get("id", "")
			)
			for option: Dictionary in group_options:
				if (
					str(option.get("id", "")) == selected_id
					and selected_id != representative_id
				):
					expanded_drawer_id = str(group.get("id", ""))
					_expanded_feature_drawers[_category_id] = (
						expanded_drawer_id
					)
					break
			if not expanded_drawer_id.is_empty():
				break

	var animation_key := _feature_drawer_animation_key
	for group: Dictionary in groups:
		var group_id := str(group.get("id", ""))
		var group_options: Array = group.get("options", []) as Array
		if group_options.is_empty():
			continue
		var has_variants := group_options.size() > 1
		var is_expanded := has_variants and group_id == expanded_drawer_id
		for option_index: int in range(group_options.size()):
			if option_index > 0 and not is_expanded:
				continue
			var option: Dictionary = group_options[option_index] as Dictionary
			var button := _build_feature_option_button(
				option,
				selected_id,
				group_id,
				option_index == 0,
				has_variants,
				is_expanded,
			)
			grid.add_child(button)
			if (
				option_index > 0
				and animation_key == "%s:%s" % [_category_id, group_id]
			):
				_animate_feature_drawer_button(button)
	_feature_drawer_animation_key = ""


func _build_feature_option_button(
	option: Dictionary,
	selected_id: String,
	drawer_id: String,
	is_representative: bool,
	has_variants: bool,
	is_expanded: bool,
) -> Button:
	var option_id := str(option.get("id", ""))
	var button := Button.new()
	var is_none := option_id == "none"
	button.text = "×" if is_none else ""
	button.tooltip_text = "none" if is_none else str(
		option.get("label", option_id)
	)
	if is_representative and has_variants:
		button.tooltip_text += (
			" (hide variants)" if is_expanded else " (show variants)"
		)
	button.toggle_mode = true
	button.button_pressed = selected_id == option_id
	button.custom_minimum_size = Vector2(84.0, 64.0)
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.clip_contents = true
	if is_representative and has_variants:
		button.pressed.connect(
			_select_feature_drawer.bind(_category_id, drawer_id, option_id)
		)
	else:
		button.pressed.connect(_select_option.bind(_category_id, option_id))
	UtilityPageStyle.apply_compact_ocean_button(button)
	button.custom_minimum_size = Vector2(84.0, 64.0)
	if is_none:
		button.add_theme_font_size_override("font_size", 28)
	else:
		var preview := TextureRect.new()
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var preview_height := 50.0
		var preview_width := clampf(
			preview_height * PlayerVisualPresenter.feature_uv_aspect(_category_id),
			32.0,
			74.0,
		)
		preview.custom_minimum_size = Vector2(preview_width, preview_height)
		preview.size = Vector2(preview_width, preview_height)
		preview.position = Vector2((84.0 - preview_width) * 0.5, 7.0)
		button.add_child(preview)
		var cached_preview := _cached_feature_preview_texture(
			_category_id, option_id
		)
		if cached_preview != null:
			preview.texture = cached_preview
		else:
			_queue_feature_preview(preview, _category_id, option_id)
	if is_representative and has_variants:
		var indicator := Label.new()
		indicator.text = "<" if is_expanded else ">"
		indicator.position = Vector2(66.0, 1.0)
		indicator.size = Vector2(14.0, 16.0)
		indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
		indicator.add_theme_font_size_override("font_size", 13)
		indicator.add_theme_color_override(
			"font_color", UtilityPageStyle.OCEAN_TEXT_PRIMARY
		)
		button.add_child(indicator)
	return button


func _select_feature_drawer(
	category_id: String,
	drawer_id: String,
	option_id: String,
) -> void:
	if str(_expanded_feature_drawers.get(category_id, "")) == drawer_id:
		_expanded_feature_drawers.erase(category_id)
	else:
		_expanded_feature_drawers[category_id] = drawer_id
		_feature_drawer_animation_key = "%s:%s" % [category_id, drawer_id]
	_select_option(category_id, option_id)


func _animate_feature_drawer_button(button: Button) -> void:
	button.scale = Vector2(0.05, 1.0)
	var faded := button.modulate
	faded.a = 0.0
	button.modulate = faded
	var tween := button.create_tween()
	tween.set_parallel(true)
	tween.tween_property(
		button, "scale", Vector2.ONE, FEATURE_DRAWER_ANIMATION_SECONDS
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(
		button, "modulate:a", 1.0, FEATURE_DRAWER_ANIMATION_SECONDS
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _cached_feature_preview_texture(
	category_id: String,
	option_id: String,
) -> Texture2D:
	var cache_key := "%s:%s" % [category_id, option_id]
	return _feature_preview_cache.get(cache_key) as Texture2D


func _queue_feature_preview(
	target: TextureRect,
	category_id: String,
	option_id: String,
) -> void:
	_feature_preview_requests.append({
		"generation": _feature_preview_generation,
		"target": weakref(target),
		"category_id": category_id,
		"option_id": option_id,
	})
	if _feature_preview_worker_active:
		return
	_feature_preview_worker_active = true
	_process_feature_preview_requests.call_deferred()


func _cancel_feature_preview_requests() -> void:
	_feature_preview_generation += 1
	_feature_preview_requests.clear()


func _process_feature_preview_requests() -> void:
	while not _feature_preview_requests.is_empty():
		var request: Dictionary = _feature_preview_requests.pop_front()
		await get_tree().process_frame
		if int(request.get("generation", -1)) != _feature_preview_generation:
			continue
		var target_reference := request.get("target") as WeakRef
		if target_reference == null:
			continue
		var target := target_reference.get_ref() as TextureRect
		if target == null or not is_instance_valid(target):
			continue
		var category_id := str(request.get("category_id", ""))
		var option_id := str(request.get("option_id", ""))
		var preview := _cached_feature_preview_texture(category_id, option_id)
		if preview == null:
			preview = _create_feature_preview_texture(category_id, option_id)
		if (
			preview != null
			and int(request.get("generation", -1)) == _feature_preview_generation
			and is_instance_valid(target)
		):
			target.texture = preview
	_feature_preview_worker_active = false


func _create_feature_preview_texture(
	category_id: String,
	option_id: String,
) -> Texture2D:
	var cache_key := "%s:%s" % [category_id, option_id]
	var resource_path := CharacterCustomizationCatalog.feature_texture_path(
		category_id, option_id
	)
	if resource_path.is_empty():
		return null
	var source := ResourceLoader.load(
		resource_path,
		"Texture2D",
		ResourceLoader.CACHE_MODE_IGNORE,
	) as Texture2D
	if source == null:
		return null
	var image := source.get_image()
	if image == null or image.is_empty():
		return null
	if image.is_compressed() and image.decompress() != OK:
		return null
	_resize_feature_preview_image(image, FEATURE_PREVIEW_SCAN_MAX_SIZE)
	var used := image.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return null
	used.position -= Vector2i(FEATURE_PREVIEW_PADDING, FEATURE_PREVIEW_PADDING)
	used.size += Vector2i(
		FEATURE_PREVIEW_PADDING * 2,
		FEATURE_PREVIEW_PADDING * 2,
	)
	used = used.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var cropped := image.get_region(used)
	_resize_feature_preview_image(cropped, FEATURE_PREVIEW_TEXTURE_MAX_SIZE)
	var preview := ImageTexture.create_from_image(cropped)
	_feature_preview_cache[cache_key] = preview
	return preview


func _resize_feature_preview_image(image: Image, max_dimension: int) -> void:
	var source_size := image.get_size()
	var largest_dimension := maxi(source_size.x, source_size.y)
	if largest_dimension <= max_dimension:
		return
	var scale := float(max_dimension) / float(largest_dimension)
	image.resize(
		maxi(roundi(float(source_size.x) * scale), 1),
		maxi(roundi(float(source_size.y) * scale), 1),
		Image.INTERPOLATE_NEAREST,
	)


func _build_fur_options(options: Array) -> void:
	var section_tabs := HBoxContainer.new()
	section_tabs.name = "FurSectionTabs"
	section_tabs.add_theme_constant_override("separation", 8)
	_option_list.add_child(section_tabs)
	for section_id: String in [FUR_SECTION_PATTERNS, FUR_SECTION_COLORS]:
		var section_button := Button.new()
		section_button.text = section_id
		section_button.toggle_mode = true
		section_button.button_pressed = _active_fur_section == section_id
		section_button.custom_minimum_size = Vector2(132.0, 34.0)
		section_button.pressed.connect(_select_fur_section.bind(section_id))
		UtilityPageStyle.apply_compact_ocean_button(section_button)
		section_tabs.add_child(section_button)

	if _active_fur_section == FUR_SECTION_COLORS:
		_build_fur_color_channels(options)
		return
	_build_fur_pattern_options()


func _build_fur_pattern_options() -> void:
	if _active_fur_pattern_id not in CharacterCustomizationCatalog.FUR_STYLE_IDS:
		_active_fur_pattern_id = CharacterCustomizationCatalog.FUR_STYLE_ID
	var pattern_stack := VBoxContainer.new()
	pattern_stack.name = "FurPatternStack"
	pattern_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pattern_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pattern_stack.add_theme_constant_override("separation", -10)
	_option_list.add_child(pattern_stack)
	var part_tab_margin := MarginContainer.new()
	part_tab_margin.name = "FurPatternPartTabMargin"
	part_tab_margin.custom_minimum_size.y = 38.0
	part_tab_margin.add_theme_constant_override("margin_left", 14)
	pattern_stack.add_child(part_tab_margin)
	var part_tabs := HBoxContainer.new()
	part_tabs.name = "FurPatternPartTabs"
	part_tabs.custom_minimum_size.y = 38.0
	part_tabs.add_theme_constant_override("separation", 2)
	part_tab_margin.add_child(part_tabs)
	for style_index: int in range(
		CharacterCustomizationCatalog.FUR_STYLE_IDS.size()
	):
		var style_field: String = (
			CharacterCustomizationCatalog.FUR_STYLE_IDS[style_index]
		)
		var part_tab: OrganizerTab = OrganizerTabType.new()
		part_tab.text = CharacterCustomizationCatalog.fur_style_label(
			style_field
		)
		part_tab.palette_index = mini(style_index, 2)
		part_tab.custom_minimum_size = Vector2(FUR_PART_TAB_WIDTH, 38.0)
		part_tab.focus_mode = Control.FOCUS_ALL
		part_tab.mouse_filter = Control.MOUSE_FILTER_STOP
		part_tab.pressed.connect(_select_fur_pattern_part.bind(style_field))
		part_tabs.add_child(part_tab)
		part_tab.set_selected(
			_active_fur_pattern_id == style_field,
			false,
		)

	var pattern_panel := PanelContainer.new()
	pattern_panel.name = "FurPatternOptionsPanel"
	pattern_panel.custom_minimum_size.y = 180.0
	pattern_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pattern_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pattern_panel.add_theme_stylebox_override(
		"panel",
		UtilityPageStyle.rounded_style(UtilityPageStyle.OCEAN_FIELD, 12),
	)
	pattern_stack.add_child(pattern_panel)
	var pattern_margin := MarginContainer.new()
	pattern_margin.add_theme_constant_override("margin_left", 12)
	pattern_margin.add_theme_constant_override("margin_top", 10)
	pattern_margin.add_theme_constant_override("margin_right", 12)
	pattern_margin.add_theme_constant_override("margin_bottom", 10)
	pattern_panel.add_child(pattern_margin)
	var pattern_scroll := ScrollContainer.new()
	pattern_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pattern_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pattern_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pattern_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	pattern_margin.add_child(pattern_scroll)
	var pattern_grid := GridContainer.new()
	pattern_grid.name = "FurPatternGrid"
	pattern_grid.columns = FUR_PATTERN_GRID_COLUMNS
	pattern_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pattern_grid.add_theme_constant_override("h_separation", 8)
	pattern_grid.add_theme_constant_override("v_separation", 8)
	pattern_scroll.add_child(pattern_grid)
	var selected_style_id := str(_draft_appearance.get(
		_active_fur_pattern_id,
		CharacterCustomizationCatalog.DEFAULT_FUR_STYLE,
	))
	var pattern_options := (
		CharacterCustomizationCatalog.fur_pattern_options_for_field(
			_active_fur_pattern_id,
			_draft_appearance,
		)
	)
	var selected_style_available := false
	for pattern_option: Dictionary in pattern_options:
		if str(pattern_option.get("id", "")) == selected_style_id:
			selected_style_available = true
			break
	var displayed_style_id := (
		selected_style_id
		if selected_style_available
		else CharacterCustomizationCatalog.DEFAULT_FUR_STYLE
	)
	for pattern_option: Dictionary in pattern_options:
		var pattern_id := str(pattern_option.get("id", ""))
		var pattern_button := Button.new()
		pattern_button.text = str(pattern_option.get("label", pattern_id))
		pattern_button.toggle_mode = true
		pattern_button.button_pressed = displayed_style_id == pattern_id
		pattern_button.custom_minimum_size = Vector2(118.0, 32.0)
		pattern_button.pressed.connect(_select_option.bind(
			_active_fur_pattern_id,
			pattern_id,
		))
		UtilityPageStyle.apply_compact_ocean_button(pattern_button)
		pattern_grid.add_child(pattern_button)


func _build_fur_color_channels(options: Array) -> void:
	var color_panel := PanelContainer.new()
	color_panel.name = "FurColorOptionsPanel"
	color_panel.custom_minimum_size.y = 180.0
	color_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	color_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	color_panel.add_theme_stylebox_override(
		"panel",
		UtilityPageStyle.rounded_style(UtilityPageStyle.OCEAN_FIELD, 12),
	)
	_option_list.add_child(color_panel)
	var color_margin := MarginContainer.new()
	color_margin.add_theme_constant_override("margin_left", 14)
	color_margin.add_theme_constant_override("margin_top", 12)
	color_margin.add_theme_constant_override("margin_right", 14)
	color_margin.add_theme_constant_override("margin_bottom", 12)
	color_panel.add_child(color_margin)
	var color_scroll := ScrollContainer.new()
	color_scroll.name = "FurColorScroll"
	color_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	color_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	color_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	color_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	color_margin.add_child(color_scroll)
	var color_stack := VBoxContainer.new()
	color_stack.name = "FurColorStack"
	color_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	color_stack.add_theme_constant_override("separation", 10)
	color_scroll.add_child(color_stack)

	var channel_grid := GridContainer.new()
	channel_grid.name = "FurColorChannelGrid"
	channel_grid.columns = FUR_CHANNEL_GRID_COLUMNS
	channel_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	channel_grid.add_theme_constant_override("h_separation", 10)
	channel_grid.add_theme_constant_override("v_separation", 8)
	color_stack.add_child(channel_grid)
	for color_index: int in range(
		CharacterCustomizationCatalog.FUR_COLOR_IDS.size()
	):
		var color_category_id: String = (
			CharacterCustomizationCatalog.FUR_COLOR_IDS[color_index]
		)
		var selected_color_id := str(_draft_appearance.get(
			color_category_id,
			"white",
		))
		var selected_color := CharacterCustomizationCatalog.option_color(
			color_category_id,
			selected_color_id,
		)
		var channel_button := Button.new()
		channel_button.name = "FurColorSlot%d" % (color_index + 1)
		channel_button.text = ""
		channel_button.accessibility_name = "fur color %d" % (color_index + 1)
		channel_button.tooltip_text = "Edit %s: %s" % [
			CharacterCustomizationCatalog.fur_color_label(color_category_id),
			_fur_option_label(options, selected_color_id),
		]
		channel_button.toggle_mode = true
		channel_button.custom_minimum_size = Vector2(104.0, 42.0)
		channel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		channel_button.button_pressed = (
			_active_fur_color_id == color_category_id
		)
		channel_button.pressed.connect(
			_select_fur_color_slot.bind(color_category_id)
		)
		UtilityPageStyle.apply_compact_ocean_button(channel_button)
		channel_grid.add_child(channel_button)
		var channel_contents := HBoxContainer.new()
		channel_contents.name = "ChannelContents"
		channel_contents.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		channel_contents.mouse_filter = Control.MOUSE_FILTER_IGNORE
		channel_contents.alignment = BoxContainer.ALIGNMENT_CENTER
		channel_contents.add_theme_constant_override("separation", 8)
		channel_button.add_child(channel_contents)
		var channel_label := Label.new()
		channel_label.name = "ChannelNumber"
		channel_label.text = str(color_index + 1)
		channel_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		channel_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		channel_label.add_theme_font_override(
			"font", UtilityPageStyle.TuffyFont
		)
		channel_label.add_theme_color_override(
			"font_color", UtilityPageStyle.OCEAN_TEXT_PRIMARY
		)
		channel_contents.add_child(channel_label)
		var channel_swatch := Panel.new()
		channel_swatch.name = "ActiveColorSwatch"
		channel_swatch.custom_minimum_size = (
			Vector2.ONE * FUR_CHANNEL_SWATCH_SIZE
		)
		channel_swatch.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		channel_swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		channel_swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_fur_color_swatch(channel_swatch, selected_color)
		channel_contents.add_child(channel_swatch)
		_fur_color_channel_buttons[color_category_id] = channel_button
		_fur_color_channel_swatches[color_category_id] = channel_swatch

	_build_fur_palette(_active_fur_color_id, options, color_stack)


func _build_fur_palette(
	category_id: String,
	options: Array,
	parent: VBoxContainer,
) -> void:
	var selected_id: String = CharacterCustomizationCatalog.canonical_option_id(
		category_id,
		str(_draft_appearance.get(category_id, "white")),
	)
	var palette_center := CenterContainer.new()
	palette_center.name = "FurPaletteCenter"
	palette_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	palette_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(palette_center)
	var grid := GridContainer.new()
	grid.name = "FurPaletteGrid"
	grid.columns = FUR_PALETTE_GRID_COLUMNS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	palette_center.add_child(grid)
	for option: Dictionary in options:
		var option_id: String = str(option.get("id", ""))
		var color: Color = CharacterCustomizationCatalog.option_color(
			category_id, option_id
		)
		var button := Button.new()
		button.text = ""
		button.tooltip_text = "%s: %s" % [
			CharacterCustomizationCatalog.fur_color_label(category_id),
			str(option.get("label", option_id)),
		]
		button.toggle_mode = true
		button.custom_minimum_size = (
			Vector2.ONE * FUR_PALETTE_SWATCH_SIZE
		)
		button.button_pressed = selected_id == option_id
		button.pressed.connect(_select_option.bind(category_id, option_id))
		_apply_fur_swatch_style(button, color, button.button_pressed)
		grid.add_child(button)

	var selected_color := CharacterCustomizationCatalog.option_color(
		category_id,
		selected_id,
	)
	var custom_picker := ColorPickerButton.new()
	custom_picker.name = "FurCustomColorPicker"
	custom_picker.text = ""
	custom_picker.accessibility_name = "custom color"
	custom_picker.color = selected_color
	custom_picker.edit_alpha = false
	custom_picker.edit_intensity = false
	custom_picker.custom_minimum_size = Vector2(0.0, 44.0)
	custom_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_picker.tooltip_text = "Choose a custom color for channel %d." % (
		CharacterCustomizationCatalog.FUR_COLOR_IDS.find(category_id) + 1
	)
	custom_picker.set_meta(&"fur_color_category_id", category_id)
	custom_picker.color_changed.connect(
		_select_custom_fur_color.bind(category_id)
	)
	# Custom colors update the channel, preview, and actions live. Rebuilding the
	# option tree from popup_closed destroys this button and its native popup
	# while Godot is still dispatching the hide operation, which can crash.
	UtilityPageStyle.apply_compact_ocean_button(custom_picker)
	_round_fur_color_picker_button(custom_picker)
	_theme_fur_color_picker_popup(custom_picker)
	parent.add_child(custom_picker)
	var picker_display := Panel.new()
	picker_display.name = "FurCustomColorDisplay"
	picker_display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picker_display.offset_left = 4.0
	picker_display.offset_top = 4.0
	picker_display.offset_right = -4.0
	picker_display.offset_bottom = -4.0
	picker_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picker_display.z_index = 1
	custom_picker.add_child(picker_display)
	var picker_label := Label.new()
	picker_label.name = "FurCustomColorLabel"
	picker_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picker_label.text = "custom color"
	picker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	picker_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	picker_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picker_label.add_theme_font_override("font", UtilityPageStyle.TuffyFont)
	picker_display.add_child(picker_label)
	_fur_custom_color_display = picker_display
	_fur_custom_color_label = picker_label
	_update_fur_custom_color_display(selected_color)


func _fur_option_label(options: Array, option_id: String) -> String:
	if CharacterCustomizationCatalog.is_custom_fur_color_id(option_id):
		return "custom #%s" % option_id.trim_prefix(
			CharacterCustomizationCatalog.CUSTOM_FUR_COLOR_PREFIX
		)
	for option: Dictionary in options:
		if str(option.get("id", "")) == option_id:
			return str(option.get("label", option_id))
	return option_id


func _select_fur_color_slot(category_id: String) -> void:
	if category_id not in CharacterCustomizationCatalog.FUR_COLOR_IDS:
		return
	_active_fur_color_id = category_id
	_refresh_options()


func _select_fur_section(section_id: String) -> void:
	if section_id not in [FUR_SECTION_PATTERNS, FUR_SECTION_COLORS]:
		return
	_active_fur_section = section_id
	_refresh_options()


func _select_custom_fur_color(color: Color, category_id: String) -> void:
	if category_id not in CharacterCustomizationCatalog.FUR_COLOR_IDS:
		return
	var option_id := CharacterCustomizationCatalog.custom_fur_color_id(color)
	_draft_appearance[category_id] = option_id
	_update_fur_channel_color(
		category_id,
		color,
		"custom #%s" % option_id.trim_prefix(
			CharacterCustomizationCatalog.CUSTOM_FUR_COLOR_PREFIX
		),
	)
	_update_fur_custom_color_display(color)
	_preview.apply_appearance_profile(_draft_appearance)
	_queue_draft_appearance_preview()
	_dirty = _draft_differs()
	_refresh_actions()


func _select_fur_pattern_part(category_id: String) -> void:
	if category_id not in CharacterCustomizationCatalog.FUR_STYLE_IDS:
		return
	_active_fur_pattern_id = category_id
	_refresh_options()


func _apply_fur_swatch_style(
	button: Button,
	color: Color,
	selected: bool,
) -> void:
	var normal: StyleBoxFlat = UtilityPageStyle.rounded_style(color, 999)
	var hover: StyleBoxFlat = UtilityPageStyle.rounded_style(
		color.lightened(0.12), 999
	)
	var selected_style: StyleBoxFlat = UtilityPageStyle.rounded_style(color, 999)
	selected_style.border_color = UtilityPageStyle.OCEAN_TEXT_PRIMARY
	selected_style.set_border_width_all(3 if selected else 2)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", selected_style)
	button.add_theme_stylebox_override("focus", selected_style)


func _set_fur_color_swatch(swatch: Panel, color: Color) -> void:
	var swatch_style := UtilityPageStyle.rounded_style(
		color,
		roundi(FUR_CHANNEL_SWATCH_SIZE * 0.5),
	)
	swatch_style.anti_aliasing = true
	swatch.add_theme_stylebox_override(
		"panel", swatch_style
	)


func _update_fur_channel_color(
	category_id: String,
	color: Color,
	option_label: String,
) -> void:
	var swatch: Panel = _fur_color_channel_swatches.get(category_id)
	if swatch != null and is_instance_valid(swatch):
		_set_fur_color_swatch(swatch, color)
	var button: Button = _fur_color_channel_buttons.get(category_id)
	if button != null and is_instance_valid(button):
		button.tooltip_text = "Edit %s: %s" % [
			CharacterCustomizationCatalog.fur_color_label(category_id),
			option_label,
		]


func _round_fur_color_picker_button(button: ColorPickerButton) -> void:
	for state: StringName in [
		&"normal", &"hover", &"pressed", &"focus", &"disabled",
	]:
		var style := button.get_theme_stylebox(state).duplicate() as StyleBoxFlat
		if style == null:
			continue
		style.set_corner_radius_all(14)
		style.content_margin_left = 14.0
		style.content_margin_top = 14.0
		style.content_margin_right = 14.0
		style.content_margin_bottom = 14.0
		button.add_theme_stylebox_override(state, style)


func _theme_fur_color_picker_popup(button: ColorPickerButton) -> void:
	var popup: PopupPanel = button.get_popup()
	var picker: ColorPicker = button.get_picker()
	popup.accessibility_name = "custom fur color picker"
	popup.theme = GameTheme
	_fit_color_picker_popup(button)
	var popup_style := UtilityPageStyle.rounded_style(
		UtilityPageStyle.OCEAN_PANEL_DEEP,
		20,
	)
	popup_style.content_margin_left = 24.0
	popup_style.content_margin_top = 24.0
	popup_style.content_margin_right = 24.0
	popup_style.content_margin_bottom = 24.0
	popup.add_theme_stylebox_override("panel", popup_style)
	picker.edit_alpha = false
	picker.edit_intensity = false
	picker.can_add_swatches = false
	picker.presets_visible = false
	picker.add_theme_constant_override("margin", 16)
	picker.add_theme_constant_override("h_width", 38)
	picker.add_theme_constant_override("label_width", 28)
	if not popup.about_to_popup.is_connected(
		_on_controller_color_picker_opened.bind(button)
	):
		popup.about_to_popup.connect(
			_on_controller_color_picker_opened.bind(button)
		)
	if not popup.popup_hide.is_connected(
		_on_controller_color_picker_closed.bind(button)
	):
		popup.popup_hide.connect(
			_on_controller_color_picker_closed.bind(button)
		)


func _fit_color_picker_popup(button: ColorPickerButton) -> void:
	var popup: PopupPanel = button.get_popup()
	var picker: ColorPicker = button.get_picker()
	var window_size: Vector2i = get_window().size
	var available := Vector2i(
		maxi(window_size.x - 32, 420),
		maxi(window_size.y - 32, 340),
	)
	var target := Vector2i(
		mini(FUR_COLOR_PICKER_POPUP_SIZE.x, available.x),
		mini(FUR_COLOR_PICKER_POPUP_SIZE.y, available.y),
	)
	popup.min_size = target
	popup.size = target
	picker.custom_minimum_size = Vector2(
		target.x - 48,
		target.y - 48,
	)
	picker.add_theme_constant_override(
		"sv_width",
		mini(FUR_COLOR_PICKER_SV_SIZE.x, target.x - 110),
	)
	picker.add_theme_constant_override(
		"sv_height",
		mini(FUR_COLOR_PICKER_SV_SIZE.y, target.y - 180),
	)


func _on_controller_color_picker_opened(button: ColorPickerButton) -> void:
	_active_color_picker_button = button
	_active_color_picker_return_depth = _controller_option_depth
	_controller_zone = ControllerZone.COLOR_PICKER
	_fit_color_picker_popup(button)
	_apply_controller_zone_focus.call_deferred()
	_focus_controller_zone.call_deferred()


func _on_controller_color_picker_closed(button: ColorPickerButton) -> void:
	if _active_color_picker_button != button:
		return
	_active_color_picker_button = null
	_controller_zone = ControllerZone.OPTIONS
	_controller_option_depth = _active_color_picker_return_depth
	_apply_controller_zone_focus.call_deferred()
	_focus_controller_zone.call_deferred()


func _close_controller_color_picker() -> void:
	if _active_color_picker_button != null:
		_active_color_picker_button.get_popup().hide()
	else:
		_controller_zone = ControllerZone.OPTIONS
		_controller_option_depth = _active_color_picker_return_depth
		_apply_controller_zone_focus()
		call_deferred("_focus_controller_zone")


func _color_picker_controller_controls() -> Array[Control]:
	if _active_color_picker_button == null:
		return []
	return _controls_under(_active_color_picker_button.get_picker())


func _adjust_controller_color_gamut(stick: Vector2, delta: float) -> void:
	if _active_color_picker_button == null:
		return
	var color: Color = _active_color_picker_button.color
	var saturation: float = clampf(color.s + stick.x * delta * 0.72, 0.0, 1.0)
	var value: float = clampf(color.v - stick.y * delta * 0.72, 0.0, 1.0)
	var adjusted := Color.from_hsv(color.h, saturation, value, 1.0)
	_active_color_picker_button.color = adjusted
	var category_id := str(_active_color_picker_button.get_meta(
		&"fur_color_category_id",
		_active_fur_color_id,
	))
	_select_custom_fur_color(adjusted, category_id)


func _refresh_controller_zone_after_options() -> void:
	if _controller_zone != ControllerZone.OPTIONS:
		return
	var groups: Array = _controller_option_groups()
	if groups.is_empty():
		_controller_zone = ControllerZone.CATEGORIES
	else:
		_controller_option_depth = clampi(
			_controller_option_depth,
			0,
			groups.size() - 1,
		)
	_apply_controller_zone_focus()
	_focus_controller_zone()


func _update_fur_custom_color_display(color: Color) -> void:
	if (
		_fur_custom_color_display == null
		or not is_instance_valid(_fur_custom_color_display)
		or _fur_custom_color_label == null
		or not is_instance_valid(_fur_custom_color_label)
	):
		return
	_fur_custom_color_display.add_theme_stylebox_override(
		"panel", UtilityPageStyle.rounded_style(color, 11)
	)
	_fur_custom_color_label.add_theme_color_override(
		"font_color",
		UtilityPageStyle.NAVY
		if color.get_luminance() >= 0.52
		else UtilityPageStyle.OCEAN_TEXT_PRIMARY,
	)


func _select_option(category_id: String, option_id: String) -> void:
	_draft_appearance[category_id] = option_id
	_preview.apply_appearance_profile(_draft_appearance)
	_queue_draft_appearance_preview()
	_dirty = _draft_differs()
	_refresh_options()
	_refresh_actions()


func _select_scale(value: float) -> void:
	var resolved_scale: float = CharacterCustomizationCatalog.character_scale(
		value
	)
	_draft_appearance[CharacterCustomizationCatalog.SCALE_CATEGORY_ID] = (
		resolved_scale
	)
	_update_scale_value_label(resolved_scale)
	_preview.apply_appearance_profile(_draft_appearance)
	_queue_draft_appearance_preview()
	_dirty = _draft_differs()
	_refresh_actions()


func _update_scale_value_label(value: float) -> void:
	if _scale_value_label != null:
		_scale_value_label.text = "%d%%" % (
			CharacterCustomizationCatalog.character_scale_percent(value)
		)


func _on_name_changed(value: String) -> void:
	_draft_name = value
	_allow_duplicate = false
	_dirty = _draft_differs()
	_refresh_actions()
	_clear_suggestions()
	if NetworkProfilePreferences.is_valid_display_name(value):
		_name_status.text = "Checking this game…"
		_debounce.start()
	else:
		_name_status.text = "Use 1–24 plain-text characters."


func _request_conflict_check() -> void:
	if _service != null:
		_service.request_name_check(_draft_name)


func _on_conflict_result(
	_request_id: String,
	has_conflict: bool,
	suggestion_names: PackedStringArray,
) -> void:
	_clear_suggestions()
	if not has_conflict:
		_name_status.text = "Name is available in this game."
		return
	_name_status.text = "That name is already in use in this game."
	for suggestion: String in suggestion_names:
		var button := Button.new()
		button.text = suggestion
		button.pressed.connect(_use_suggestion.bind(suggestion))
		UtilityPageStyle.apply_compact_ocean_button(button)
		_suggestions.add_child(button)
	var anyway := Button.new()
	anyway.text = "use anyway"
	anyway.pressed.connect(func() -> void:
		_allow_duplicate = true
		_name_status.text = "Duplicate name allowed for this apply."
	)
	UtilityPageStyle.apply_compact_ocean_button(anyway)
	_suggestions.add_child(anyway)
	_apply_controller_zone_focus()


func _on_experience_changed(_total_experience: int, _level: int) -> void:
	_refresh_experience()


func _refresh_experience() -> void:
	if _experience_level == null:
		return
	if _experience == null:
		_experience_level.text = "level 1"
		_experience_progress.value = 0.0
		_experience_value.text = "0 / 100 xp"
		return
	var level: int = _experience.get_level()
	var current: int = _experience.get_experience_in_level()
	var required: int = _experience.get_experience_for_next_level()
	_experience_level.text = "level %d" % level
	_experience_progress.value = _experience.get_level_progress()
	_experience_value.text = "%d / %d xp" % [current, required]
	_experience_value.tooltip_text = "%d total xp" % (
		_experience.get_total_experience()
	)


func _use_suggestion(value: String) -> void:
	_name_edit.text = value
	_draft_name = value
	_allow_duplicate = false
	_dirty = _draft_differs()
	_clear_suggestions()
	_request_conflict_check()


func _apply() -> void:
	if _service == null:
		return
	_apply_button.disabled = true
	_service.apply_profile(
		_draft_name,
		_draft_appearance,
		_allow_duplicate,
		_draft_voice_id,
		_draft_speech_speed_id,
		_draft_call_id,
		_draft_sample_set_id,
	)


func _on_apply_finished(accepted: bool, message: String) -> void:
	_apply_button.disabled = false
	_name_status.text = message
	if accepted:
		_load_persisted()


func _load_persisted() -> void:
	if _service == null:
		return
	_persisted_name = _service.get_persisted_name()
	_persisted_appearance = _service.get_persisted_appearance()
	_persisted_voice_id = _service.get_persisted_voice_id()
	_persisted_speech_speed_id = (
		_service.get_persisted_speech_speed_id()
	)
	_persisted_call_id = _service.get_persisted_call_id()
	_persisted_sample_set_id = _service.get_persisted_sample_set_id()
	_draft_name = _persisted_name
	_draft_appearance = _persisted_appearance.duplicate(true)
	_draft_voice_id = _persisted_voice_id
	_draft_speech_speed_id = _persisted_speech_speed_id
	_draft_call_id = _persisted_call_id
	_draft_sample_set_id = _persisted_sample_set_id
	TypewriterRevealType.set_characters_per_second(
		VoiceProfilesType.speed_for(_persisted_speech_speed_id)
	)
	_name_edit.text = _draft_name
	_preview.apply_appearance_profile(_draft_appearance)
	_appearance_preview_timer.stop()
	_service.preview_appearance(_persisted_appearance)
	_dirty = false
	_allow_duplicate = false
	_name_status.text = ""
	_clear_suggestions()
	_refresh_options()
	_refresh_actions()


func _revert() -> void:
	_load_persisted()


func _confirm_discard() -> void:
	_discard_confirmation.visible = false
	_load_persisted()


func _show_confirmation(action: String) -> void:
	_confirmation_action = action
	_discard_confirmation.visible = true
	if action == "defaults":
		_confirmation_label.text = "Reset the profile draft to defaults?"
		_confirmation_confirm.text = "reset draft"
	else:
		_confirmation_label.text = "Discard unsaved profile changes?"
		_confirmation_confirm.text = "discard changes"
	_apply_controller_zone_focus()
	_keep_editing_button.grab_focus()


func _close_discard_confirmation() -> void:
	_discard_confirmation.visible = false
	_confirmation_action = ""
	_apply_controller_zone_focus()
	call_deferred("_focus_controller_zone")


func _confirm_pending_action() -> void:
	_discard_confirmation.visible = false
	if _confirmation_action == "defaults":
		_draft_appearance = CharacterCustomizationCatalog.default_snapshot()
		_draft_voice_id = VoiceProfilesType.DEFAULT_ID
		_draft_speech_speed_id = VoiceProfilesType.DEFAULT_SPEED_ID
		_draft_call_id = VoiceProfilesType.DEFAULT_CALL_ID
		_draft_sample_set_id = VoiceProfilesType.DEFAULT_SAMPLE_SET_ID
		_preview.apply_appearance_profile(_draft_appearance)
		_queue_draft_appearance_preview()
		_dirty = _draft_differs()
		_refresh_options()
		_refresh_actions()
	else:
		_confirm_discard()
	_confirmation_action = ""
	_apply_controller_zone_focus()
	call_deferred("_focus_controller_zone")


func _queue_draft_appearance_preview() -> void:
	if _service == null or _appearance_preview_timer == null:
		return
	# Throttle continuous controls such as the custom color picker instead of
	# debouncing them. Remote players should see an in-progress drag, while the
	# reliable channel remains capped at one current snapshot per interval.
	if _appearance_preview_timer.is_stopped():
		_appearance_preview_timer.start()


func _publish_draft_appearance() -> void:
	if _service != null:
		_service.preview_appearance(_draft_appearance)


func _draft_differs() -> bool:
	return (
		_draft_name.strip_edges() != _persisted_name
		or _draft_appearance != _persisted_appearance
		or _draft_voice_id != _persisted_voice_id
		or _draft_speech_speed_id != _persisted_speech_speed_id
		or _draft_call_id != _persisted_call_id
		or _draft_sample_set_id != _persisted_sample_set_id
	)


func _refresh_actions() -> void:
	_apply_button.disabled = (
		not _dirty
		or not NetworkProfilePreferences.is_valid_display_name(_draft_name)
	)
	_revert_button.disabled = not _dirty


func _clear_suggestions() -> void:
	for child: Node in _suggestions.get_children():
		_suggestions.remove_child(child)
		child.queue_free()
	_apply_controller_zone_focus()
