class_name ProfilePage
extends Control

const CHECK_DEBOUNCE_SECONDS: float = 0.4

var _service: NetworkProfileService
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


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build_ui()
	_debounce = Timer.new()
	_debounce.one_shot = true
	_debounce.wait_time = CHECK_DEBOUNCE_SECONDS
	_debounce.timeout.connect(_request_conflict_check)
	add_child(_debounce)


func setup(service: NetworkProfileService) -> void:
	_service = service
	if not _service.conflict_result.is_connected(_on_conflict_result):
		_service.conflict_result.connect(_on_conflict_result)
		_service.apply_finished.connect(_on_apply_finished)
	_load_persisted()
	var identity_value := find_child("IdentityFingerprint", true, false) as Label
	if identity_value != null:
		identity_value.text = "%s  •  Stored on this device" % (
			NetworkIdentityCrypto.format_fingerprint(
				_service.get_identity_fingerprint()
			)
		)


func activate() -> void:
	visible = true
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


func _build_ui() -> void:
	var paper := PanelContainer.new()
	paper.set_anchors_preset(Control.PRESET_FULL_RECT)
	paper.offset_left = 42.0
	paper.offset_top = 14.0
	paper.offset_right = -42.0
	paper.offset_bottom = -14.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f2ead3")
	style.border_color = Color("4a4238")
	style.set_border_width_all(4)
	style.set_corner_radius_all(18)
	paper.add_theme_stylebox_override("panel", style)
	add_child(paper)

	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 28)
	paper.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)

	var heading := Label.new()
	heading.text = "player profile"
	heading.add_theme_font_size_override("font_size", 28)
	heading.add_theme_color_override("font_color", Color("302b27"))
	layout.add_child(heading)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 10)
	layout.add_child(name_row)
	var name_stack := VBoxContainer.new()
	name_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(name_stack)
	var name_label := Label.new()
	name_label.text = "player name"
	name_label.add_theme_color_override("font_color", Color("302b27"))
	name_stack.add_child(name_label)
	_name_edit = LineEdit.new()
	_name_edit.max_length = NetworkProtocol.MAX_DISPLAY_NAME_LENGTH
	_name_edit.placeholder_text = "Player"
	_name_edit.custom_minimum_size = Vector2(360, 42)
	_name_edit.text_changed.connect(_on_name_changed)
	name_stack.add_child(_name_edit)
	var helper := Label.new()
	helper.text = "Shown to other players in multiplayer."
	helper.add_theme_color_override("font_color", Color("665e52"))
	name_stack.add_child(helper)
	_apply_button = Button.new()
	_apply_button.text = "apply"
	_apply_button.custom_minimum_size = Vector2(118, 50)
	_apply_button.pressed.connect(_apply)
	name_row.add_child(_apply_button)
	_revert_button = Button.new()
	_revert_button.text = "revert"
	_revert_button.custom_minimum_size = Vector2(108, 50)
	_revert_button.pressed.connect(_revert)
	name_row.add_child(_revert_button)
	var defaults_button := Button.new()
	defaults_button.text = "defaults"
	defaults_button.custom_minimum_size = Vector2(108, 50)
	defaults_button.pressed.connect(_show_confirmation.bind("defaults"))
	name_row.add_child(defaults_button)

	_name_status = Label.new()
	_name_status.add_theme_color_override("font_color", Color("704c36"))
	layout.add_child(_name_status)
	_suggestions = HBoxContainer.new()
	_suggestions.add_theme_constant_override("separation", 8)
	layout.add_child(_suggestions)

	var identity_label := Label.new()
	identity_label.text = "identity"
	identity_label.add_theme_color_override("font_color", Color("302b27"))
	layout.add_child(identity_label)
	var identity_value := Label.new()
	identity_value.name = "IdentityFingerprint"
	identity_value.text = "Stored on this device"
	identity_value.tooltip_text = (
		"This identity helps other players recognize you between sessions."
	)
	identity_value.add_theme_color_override("font_color", Color("665e52"))
	layout.add_child(identity_value)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	layout.add_child(body)
	_category_list = VBoxContainer.new()
	_category_list.custom_minimum_size = Vector2(170, 0)
	body.add_child(_category_list)
	_option_list = VBoxContainer.new()
	_option_list.custom_minimum_size = Vector2(230, 0)
	body.add_child(_option_list)
	var preview_stack := VBoxContainer.new()
	preview_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(preview_stack)
	_preview = preload("res://ui/profile_preview.tscn").instantiate()
	preview_stack.add_child(_preview)
	var preview_note := Label.new()
	preview_note.text = "capsule preview • drag or use left / right"
	preview_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_note.add_theme_color_override("font_color", Color("514a42"))
	preview_stack.add_child(preview_note)
	var reset_view := Button.new()
	reset_view.text = "reset view"
	reset_view.pressed.connect(_preview.reset_view)
	preview_stack.add_child(reset_view)

	_discard_confirmation = PanelContainer.new()
	_discard_confirmation.visible = false
	_discard_confirmation.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_discard_confirmation.custom_minimum_size = Vector2(430, 190)
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
	confirm_buttons.add_child(_confirmation_confirm)
	var keep := Button.new()
	keep.name = "KeepEditing"
	keep.unique_name_in_owner = true
	keep.text = "keep editing"
	keep.pressed.connect(func() -> void:
		_discard_confirmation.visible = false
		_name_edit.grab_focus()
	)
	confirm_buttons.add_child(keep)

	_build_categories()


func _build_categories() -> void:
	for child: Node in _category_list.get_children():
		child.queue_free()
	for category_id: String in CharacterCustomizationCatalog.CATEGORY_IDS:
		var button := Button.new()
		button.text = CharacterCustomizationCatalog.category_label(category_id)
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(0, 34)
		button.button_pressed = category_id == _category_id
		button.pressed.connect(_select_category.bind(category_id))
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
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("302b27"))
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
		button.custom_minimum_size = Vector2(0, 34)
		button.button_pressed = _draft_appearance.get(_category_id) == option_id
		button.pressed.connect(_select_option.bind(_category_id, option_id))
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
		_suggestions.add_child(button)
	var anyway := Button.new()
	anyway.text = "use anyway"
	anyway.pressed.connect(func() -> void:
		_allow_duplicate = true
		_name_status.text = "Duplicate name allowed for this apply."
	)
	_suggestions.add_child(anyway)


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
