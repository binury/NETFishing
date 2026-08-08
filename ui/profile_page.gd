class_name ProfilePage
extends Control

const CHECK_DEBOUNCE_SECONDS: float = 0.4
const OPTION_GRID_COLUMNS: int = 6
const FEATURE_DRAWER_ANIMATION_SECONDS: float = 0.16
const ControllerMappingManagerType = preload(
	"res://settings/controller_mapping_manager.gd"
)
const AnimaleseVoiceType = preload("res://ui/animalese_voice.gd")
const TypewriterRevealType = preload("res://ui/typewriter_reveal.gd")
const VoiceProfilesType = preload(
	"res://player/animalese_voice_profiles.gd"
)
const VOICE_CATEGORY_ID: String = "voice"

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
var _category_id: String = "species"
var _dirty: bool = false
var _allow_duplicate: bool = false

var _name_edit: LineEdit
var _name_status: Label
var _suggestions: HBoxContainer
var _category_list: VBoxContainer
var _option_list: VBoxContainer
var _preview: ProfilePreview
var _apply_button: Button
var _revert_button: Button
var _discard_confirmation: PanelContainer
var _confirmation_label: Label
var _confirmation_confirm: Button
var _keep_editing_button: Button
var _confirmation_action: String = ""
var _debounce: Timer
var _experience_level: Label
var _experience_progress: ProgressBar
var _experience_value: Label
var _feature_preview_cache: Dictionary = {}
var _expanded_feature_drawers: Dictionary = {}
var _feature_drawer_animation_key: String = ""
var _scale_value_label: Label
var _voice_preview: AnimaleseVoiceType
var _voice_preview_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build_ui()
	_debounce = Timer.new()
	_debounce.one_shot = true
	_debounce.wait_time = CHECK_DEBOUNCE_SECONDS
	_debounce.timeout.connect(_request_conflict_check)
	add_child(_debounce)


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
	if _preview != null:
		_preview.setup_controller_mapping(mapping_manager)


func set_world_pixel_size(pixel_size: int) -> void:
	if _preview != null:
		_preview.set_world_pixel_size(pixel_size)


func activate() -> void:
	visible = true
	UtilityPageStyle.animate_in(self)
	if _service != null:
		_load_persisted()
	# Keep controller page switches on the Profile navigation bubble. Focusing
	# the name field here summons the Android keyboard during LB/RB traversal.


func deactivate() -> void:
	visible = false
	_debounce.stop()
	if _voice_preview_tween != null and _voice_preview_tween.is_valid():
		_voice_preview_tween.kill()
	_preview.reset_view()


func set_interactive(interactive: bool) -> void:
	mouse_filter = (
		Control.MOUSE_FILTER_PASS if interactive else Control.MOUSE_FILTER_IGNORE
	)


func consume_escape() -> bool:
	if _discard_confirmation.visible:
		_discard_confirmation.visible = false
		_confirmation_action = ""
		_name_edit.grab_focus()
		return true
	if _name_edit.has_focus():
		_name_edit.release_focus()
		return true
	if _dirty:
		_show_confirmation("discard")
		return true
	return false


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
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)

	var account_row := HBoxContainer.new()
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
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	actions.add_theme_constant_override("separation", 7)
	account_row.add_child(actions)
	_apply_button = Button.new()
	_apply_button.text = "apply"
	_apply_button.custom_minimum_size.x = 72.0
	UtilityPageStyle.apply_compact_ocean_button(_apply_button)
	_apply_button.pressed.connect(_apply)
	actions.add_child(_apply_button)
	_revert_button = Button.new()
	_revert_button.text = "revert"
	_revert_button.custom_minimum_size.x = 76.0
	UtilityPageStyle.apply_compact_ocean_button(_revert_button)
	_revert_button.pressed.connect(_revert)
	actions.add_child(_revert_button)
	var defaults_button := Button.new()
	defaults_button.text = "defaults"
	defaults_button.custom_minimum_size.x = 82.0
	UtilityPageStyle.apply_compact_ocean_button(defaults_button)
	defaults_button.pressed.connect(_show_confirmation.bind("defaults"))
	actions.add_child(defaults_button)

	var body_panel := PanelContainer.new()
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
	body.add_theme_constant_override("separation", 16)
	body_margin.add_child(body)
	_category_list = VBoxContainer.new()
	_category_list.custom_minimum_size = Vector2(120, 0)
	_category_list.add_theme_constant_override("separation", 5)
	body.add_child(_category_list)
	_option_list = VBoxContainer.new()
	_option_list.custom_minimum_size = Vector2(360, 0)
	_option_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_option_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_option_list.add_theme_constant_override("separation", 5)
	body.add_child(_option_list)
	var body_spacer := Control.new()
	body_spacer.custom_minimum_size.x = 12.0
	body_spacer.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(body_spacer)
	var preview_stack := VBoxContainer.new()
	preview_stack.custom_minimum_size.x = 260.0
	preview_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	preview_stack.add_theme_constant_override("separation", 7)
	body.add_child(preview_stack)
	var preview_frame := PanelContainer.new()
	preview_frame.custom_minimum_size = Vector2(260.0, 0.0)
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
	_preview.custom_minimum_size = Vector2(260.0, 0.0)
	_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_layer.add_child(_preview)
	_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var reset_view := Button.new()
	reset_view.text = "↶"
	reset_view.tooltip_text = "reset view"
	reset_view.custom_minimum_size = Vector2(36.0, 36.0)
	reset_view.position = Vector2(-8.0, -8.0)
	reset_view.z_index = 2
	reset_view.pressed.connect(_preview.reset_view)
	UtilityPageStyle.apply_compact_ocean_button(reset_view)
	reset_view.add_theme_font_size_override("font_size", 22)
	preview_layer.add_child(reset_view)

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
	_keep_editing_button.pressed.connect(func() -> void:
		_discard_confirmation.visible = false
		_name_edit.grab_focus()
	)
	UtilityPageStyle.apply_ocean_button(_keep_editing_button)
	confirm_buttons.add_child(_keep_editing_button)

	_voice_preview = AnimaleseVoiceType.new()
	_voice_preview.name = "ProfileVoicePreview"
	add_child(_voice_preview)
	_build_categories()


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
	for child: Node in _option_list.get_children():
		child.queue_free()
	var title := Label.new()
	title.text = _category_label(_category_id)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override(
		"font_color", UtilityPageStyle.OCEAN_TEXT_PRIMARY
	)
	_option_list.add_child(title)
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
		_build_fur_color_options(options)
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
	description.text = "Choose how your character sounds in chat."
	description.add_theme_color_override(
		"font_color", UtilityPageStyle.OCEAN_TEXT_SECONDARY
	)
	_option_list.add_child(description)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_option_list.add_child(grid)
	for option: Dictionary in VoiceProfilesType.OPTIONS:
		var option_id := str(option.get("id", ""))
		var button := Button.new()
		button.text = str(option.get("label", option_id))
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(170.0, 42.0)
		button.button_pressed = _draft_voice_id == option_id
		button.pressed.connect(_select_voice_option.bind(option_id))
		UtilityPageStyle.apply_compact_ocean_button(button)
		grid.add_child(button)
	var divider := HSeparator.new()
	divider.custom_minimum_size.y = 8.0
	_option_list.add_child(divider)
	var speed_title := Label.new()
	speed_title.text = "speech speed"
	speed_title.add_theme_font_size_override("font_size", 16)
	speed_title.add_theme_color_override(
		"font_color", UtilityPageStyle.OCEAN_TEXT_PRIMARY
	)
	_option_list.add_child(speed_title)
	var speed_description := Label.new()
	speed_description.text = "Controls player chat speech on this device only."
	speed_description.add_theme_color_override(
		"font_color", UtilityPageStyle.OCEAN_TEXT_SECONDARY
	)
	_option_list.add_child(speed_description)
	var speed_grid := GridContainer.new()
	speed_grid.columns = 2
	speed_grid.add_theme_constant_override("h_separation", 8)
	speed_grid.add_theme_constant_override("v_separation", 8)
	_option_list.add_child(speed_grid)
	for option: Dictionary in VoiceProfilesType.SPEED_OPTIONS:
		var speed_id := str(option.get("id", ""))
		var speed_button := Button.new()
		speed_button.text = str(option.get("label", speed_id))
		speed_button.tooltip_text = "%d characters per second" % roundi(
			float(option.get("characters_per_second", 28.0))
		)
		speed_button.toggle_mode = true
		speed_button.custom_minimum_size = Vector2(170.0, 38.0)
		speed_button.button_pressed = _draft_speech_speed_id == speed_id
		speed_button.pressed.connect(
			_select_speech_speed_option.bind(speed_id)
		)
		UtilityPageStyle.apply_compact_ocean_button(speed_button)
		speed_grid.add_child(speed_button)


func _select_voice_option(voice_id: String) -> void:
	if not VoiceProfilesType.is_valid(voice_id):
		return
	_draft_voice_id = voice_id
	_dirty = _draft_differs()
	_refresh_options()
	_refresh_actions()
	_play_voice_preview()


func _select_speech_speed_option(speed_id: String) -> void:
	if not VoiceProfilesType.is_valid_speed(speed_id):
		return
	_draft_speech_speed_id = speed_id
	_dirty = _draft_differs()
	_refresh_options()
	_refresh_actions()
	_play_voice_preview()


func _play_voice_preview() -> void:
	if _voice_preview_tween != null and _voice_preview_tween.is_valid():
		_voice_preview_tween.kill()
	_voice_preview_tween = _voice_preview.speak_text(
		self,
		"hello there!",
		"profile-preview",
		_draft_voice_id,
		VoiceProfilesType.speed_for(_draft_speech_speed_id),
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
	small_label.add_theme_color_override(
		"font_color", UtilityPageStyle.OCEAN_TEXT_SECONDARY
	)
	value_row.add_child(small_label)

	var slider := HSlider.new()
	slider.name = "CharacterScaleSlider"
	slider.min_value = CharacterCustomizationCatalog.MIN_CHARACTER_SCALE
	slider.max_value = CharacterCustomizationCatalog.MAX_CHARACTER_SCALE
	slider.step = CharacterCustomizationCatalog.CHARACTER_SCALE_STEP
	slider.custom_minimum_size = Vector2(220.0, 40.0)
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

	var gameplay_note := Label.new()
	gameplay_note.text = "Movement and collision stay the same."
	gameplay_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gameplay_note.add_theme_font_size_override("font_size", 12)
	gameplay_note.add_theme_color_override(
		"font_color", UtilityPageStyle.OCEAN_TEXT_SECONDARY
	)
	_option_list.add_child(gameplay_note)


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
		preview.texture = _feature_preview_texture(_category_id, option_id)
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


func _feature_preview_texture(
	category_id: String,
	option_id: String,
) -> Texture2D:
	var cache_key := "%s:%s" % [category_id, option_id]
	if _feature_preview_cache.has(cache_key):
		return _feature_preview_cache[cache_key] as Texture2D
	var source := CharacterCustomizationCatalog.texture_for(
		category_id, option_id
	)
	if source == null:
		return null
	var image := source.get_image()
	var used := image.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		_feature_preview_cache[cache_key] = source
		return source
	var padding := 12
	used.position -= Vector2i(padding, padding)
	used.size += Vector2i(padding * 2, padding * 2)
	used = used.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var cropped := image.get_region(used)
	var preview := ImageTexture.create_from_image(cropped)
	_feature_preview_cache[cache_key] = preview
	return preview


func _build_fur_color_options(options: Array) -> void:
	var grid := GridContainer.new()
	grid.columns = OPTION_GRID_COLUMNS
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	_option_list.add_child(grid)
	var selected_id: String = CharacterCustomizationCatalog.canonical_option_id(
		"fur_pattern", str(_draft_appearance.get("fur_pattern", "white"))
	)
	for option: Dictionary in options:
		var option_id: String = str(option.get("id", ""))
		var color: Color = CharacterCustomizationCatalog.option_color(
			"fur_pattern", option_id
		)
		var button := Button.new()
		button.text = ""
		button.tooltip_text = str(option.get("label", option_id))
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(44.0, 44.0)
		button.button_pressed = selected_id == option_id
		button.pressed.connect(_select_option.bind("fur_pattern", option_id))
		_apply_fur_swatch_style(button, color, button.button_pressed)
		grid.add_child(button)


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


func _select_option(category_id: String, option_id: String) -> void:
	_draft_appearance[category_id] = option_id
	_preview.apply_appearance_profile(_draft_appearance)
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
	_draft_name = _persisted_name
	_draft_appearance = _persisted_appearance.duplicate(true)
	_draft_voice_id = _persisted_voice_id
	_draft_speech_speed_id = _persisted_speech_speed_id
	TypewriterRevealType.set_characters_per_second(
		VoiceProfilesType.speed_for(_persisted_speech_speed_id)
	)
	_name_edit.text = _draft_name
	_preview.apply_appearance_profile(_draft_appearance)
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
	_keep_editing_button.grab_focus()


func _confirm_pending_action() -> void:
	_discard_confirmation.visible = false
	if _confirmation_action == "defaults":
		_draft_appearance = CharacterCustomizationCatalog.default_snapshot()
		_draft_voice_id = VoiceProfilesType.DEFAULT_ID
		_draft_speech_speed_id = VoiceProfilesType.DEFAULT_SPEED_ID
		_preview.apply_appearance_profile(_draft_appearance)
		_dirty = _draft_differs()
		_refresh_options()
		_refresh_actions()
	else:
		_confirm_discard()
	_confirmation_action = ""


func _draft_differs() -> bool:
	return (
		_draft_name.strip_edges() != _persisted_name
		or _draft_appearance != _persisted_appearance
		or _draft_voice_id != _persisted_voice_id
		or _draft_speech_speed_id != _persisted_speech_speed_id
	)


func _refresh_actions() -> void:
	_apply_button.disabled = (
		not _dirty
		or not NetworkProfilePreferences.is_valid_display_name(_draft_name)
	)
	_revert_button.disabled = not _dirty


func _clear_suggestions() -> void:
	for child: Node in _suggestions.get_children():
		child.queue_free()
