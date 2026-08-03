class_name ProfilePage
extends Control

const CHECK_DEBOUNCE_SECONDS: float = 0.4

var _service: NetworkProfileService
var _experience: PlayerExperience
var _draft_name: String = ""
var _draft_appearance: Dictionary = {}
var _persisted_name: String = ""
var _persisted_appearance: Dictionary = {}
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
var _confirmation_action: String = ""
var _debounce: Timer
var _experience_level: Label
var _experience_progress: ProgressBar
var _experience_value: Label


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
	var identity_value := find_child("IdentityFingerprint", true, false) as Label
	if identity_value != null:
		var fingerprint := _service.get_identity_fingerprint()
		identity_value.text = "Identity • %s • Stored on this device" % (
			NetworkIdentityCrypto.compact_suffix(fingerprint)
		)
		identity_value.tooltip_text = (
			NetworkIdentityCrypto.format_fingerprint(fingerprint)
		)


func activate() -> void:
	visible = true
	UtilityPageStyle.animate_in(self)
	if _service != null:
		_load_persisted()
	_name_edit.grab_focus()


func deactivate() -> void:
	visible = false
	_debounce.stop()
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
	_option_list.custom_minimum_size = Vector2(170, 0)
	_option_list.add_theme_constant_override("separation", 5)
	body.add_child(_option_list)
	var body_spacer := Control.new()
	body_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(body_spacer)
	var preview_stack := VBoxContainer.new()
	preview_stack.custom_minimum_size.x = 180.0
	preview_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	preview_stack.add_theme_constant_override("separation", 7)
	body.add_child(preview_stack)
	var preview_frame := PanelContainer.new()
	preview_frame.custom_minimum_size = Vector2(180.0, 220.0)
	preview_frame.add_theme_stylebox_override(
		"panel", UtilityPageStyle.rounded_style(
			UtilityPageStyle.OCEAN_FIELD, 18
		)
	)
	preview_stack.add_child(preview_frame)
	_preview = preload("res://ui/profile_preview.tscn").instantiate()
	_preview.custom_minimum_size = Vector2(180.0, 220.0)
	preview_frame.add_child(_preview)
	var preview_actions := VBoxContainer.new()
	preview_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	preview_actions.add_theme_constant_override("separation", 4)
	preview_stack.add_child(preview_actions)
	var preview_note := Label.new()
	preview_note.text = "drag or use left / right"
	preview_note.custom_minimum_size.x = 180.0
	preview_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_note.add_theme_font_size_override("font_size", 12)
	preview_note.add_theme_color_override(
		"font_color", UtilityPageStyle.OCEAN_TEXT_SECONDARY
	)
	preview_actions.add_child(preview_note)
	var reset_view := Button.new()
	reset_view.text = "reset view"
	reset_view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	reset_view.pressed.connect(_preview.reset_view)
	UtilityPageStyle.apply_compact_ocean_button(reset_view)
	preview_actions.add_child(reset_view)

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
	var keep := Button.new()
	keep.name = "KeepEditing"
	keep.unique_name_in_owner = true
	keep.text = "keep editing"
	keep.pressed.connect(func() -> void:
		_discard_confirmation.visible = false
		_name_edit.grab_focus()
	)
	UtilityPageStyle.apply_ocean_button(keep)
	confirm_buttons.add_child(keep)

	_build_categories()


func _build_categories() -> void:
	for child: Node in _category_list.get_children():
		child.queue_free()
	for category_id: String in CharacterCustomizationCatalog.CATEGORY_IDS:
		var button := Button.new()
		button.text = CharacterCustomizationCatalog.category_label(category_id)
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
				CharacterCustomizationCatalog.category_label(category_id)
			)
	_refresh_options()


func _refresh_options() -> void:
	for child: Node in _option_list.get_children():
		child.queue_free()
	var title := Label.new()
	title.text = CharacterCustomizationCatalog.category_label(_category_id)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override(
		"font_color", UtilityPageStyle.OCEAN_TEXT_PRIMARY
	)
	_option_list.add_child(title)
	var options := CharacterCustomizationCatalog.options_for(_category_id)
	if options.is_empty():
		var empty := Label.new()
		empty.text = "More options coming later."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_option_list.add_child(empty)
		return
	for option: Dictionary in options:
		var option_id := str(option["id"])
		var button := Button.new()
		button.text = str(option["label"])
		button.toggle_mode = true
		button.custom_minimum_size.x = 170.0
		button.button_pressed = _draft_appearance.get(_category_id) == option_id
		button.pressed.connect(_select_option.bind(_category_id, option_id))
		UtilityPageStyle.apply_compact_ocean_button(button)
		_option_list.add_child(button)


func _select_option(category_id: String, option_id: String) -> void:
	_draft_appearance[category_id] = option_id
	_preview.apply_appearance_profile(_draft_appearance)
	_dirty = _draft_differs()
	_refresh_options()
	_refresh_actions()


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
	_service.apply_profile(_draft_name, _draft_appearance, _allow_duplicate)


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
	_draft_name = _persisted_name
	_draft_appearance = _persisted_appearance.duplicate(true)
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
	_discard_confirmation.get_node("%KeepEditing").grab_focus()


func _confirm_pending_action() -> void:
	_discard_confirmation.visible = false
	if _confirmation_action == "defaults":
		_draft_appearance = CharacterCustomizationCatalog.default_snapshot()
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
