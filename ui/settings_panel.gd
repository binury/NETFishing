class_name SettingsPanel
extends Control

const MAX_PANEL_SIZE: Vector2 = Vector2(960.0, 700.0)
const PANEL_EDGE_MARGIN: float = 16.0
const PAGE_ROOT: StringName = &"root"
const PAGE_DISPLAY: StringName = &"display"
const PAGE_SOUND: StringName = &"sound"
const PAGE_CONTROLS: StringName = &"controls"
const PAGE_ACCESSIBILITY: StringName = &"accessibility"
const PAGE_DATA: StringName = &"data"
const PIXELATION_NAMES: PackedStringArray = [
	"legible",
	"cute",
	"retro",
	"hardcore",
	"wtf",
]
const SettingsManagerType = preload(
	"res://settings/player_settings_manager.gd"
)
const ControllerMappingManagerType = preload(
	"res://settings/controller_mapping_manager.gd"
)
const ControllerMappingPanelType = preload(
	"res://ui/controller_mapping_panel.gd"
)
const KeyboardMouseMappingManagerType = preload(
	"res://settings/keyboard_mouse_mapping_manager.gd"
)
const KeyboardMouseMappingPanelType = preload(
	"res://ui/keyboard_mouse_mapping_panel.gd"
)
const DialogControllerNavigationType = preload(
	"res://ui/file_dialog_controller_navigation.gd"
)

signal applied
signal closed
signal closing
signal opened
signal crisp_reset_focus_requested
signal panel_visibility_changed(is_visible: bool)
signal navigation_transition_started

enum PresentationMode {
	TITLE_EMBEDDED,
	GAMEPLAY_MODAL,
}

@onready var _root_page: SettingsBubblePage = %RootPage
@onready var _display_page: SettingsBubblePage = %DisplayPage
@onready var _sound_page: SettingsBubblePage = %SoundPage
@onready var _controls_page: SettingsBubblePage = %ControlsPage
@onready var _accessibility_page: SettingsBubblePage = %AccessibilityPage
@onready var _data_page: SettingsBubblePage = %DataPage
@onready var _feedback: Label = %SettingsFeedback

@onready var _world_value: BubbleButton = %WorldValue
@onready var _ui_value: BubbleButton = %UIValue
@onready var _chat_dock: BubbleButton = %ChatDock
@onready var _chat_mode: BubbleButton = %ChatMode
@onready var _paint_dock: BubbleButton = %PaintDock
@onready var _fullscreen_toggle: BubbleButton = %FullscreenToggle
@onready var _mouse_value: BubbleButton = %MouseValue
@onready var _controller_value: BubbleButton = %ControllerValue
@onready var _invert_y_toggle: BubbleButton = %InvertYToggle
@onready var _on_screen_keyboard_toggle: BubbleButton = %OnScreenKeyboardToggle
@onready var _auto_click_toggle: BubbleButton = %AutoClickToggle
@onready var _auto_click_interval: BubbleButton = %AutoClickIntervalValue
@onready var _master_volume_slider: HSlider = %MasterVolumeSlider
@onready var _music_volume_slider: HSlider = %MusicVolumeSlider
@onready var _effects_volume_slider: HSlider = %EffectsVolumeSlider
@onready var _environment_volume_slider: HSlider = %EnvironmentVolumeSlider
@onready var _master_volume_value: Label = %MasterVolumeValue
@onready var _music_volume_value: Label = %MusicVolumeValue
@onready var _effects_volume_value: Label = %EffectsVolumeValue
@onready var _environment_volume_value: Label = %EnvironmentVolumeValue

@onready var _world_options: Array[BubbleButton] = [
	%WorldLegible,
	%WorldCute,
	%WorldRetro,
	%WorldHardcore,
	%WorldWtf,
]
@onready var _ui_options: Array[BubbleButton] = [
	%UILegible,
	%UICute,
	%UIRetro,
	%UIHardcore,
	%UIWtf,
]

var _settings_manager: SettingsManagerType
var _effective_ui_pixel_size: int = PlayerSettings.DEFAULT_UI_PIXEL_SIZE
var _page_stack: Array[StringName] = []
var _pages: Dictionary[StringName, SettingsBubblePage] = {}
var _page_transition_generation: int = 0
var _page_transition_active: bool = false
var _presentation_mode: PresentationMode = PresentationMode.GAMEPLAY_MODAL
var _animate_gameplay_host_transitions: bool = false
var _auto_click_enabled: bool = false
var _auto_click_interval_value: float = 0.20
var _mouse_sensitivity: float = 0.005
var _controller_sensitivity: float = 2.5
var _invert_camera_y: bool = false
var _on_screen_keyboard_enabled: bool = false
var _master_volume: float = 1.0
var _music_volume: float = 1.0
var _effects_volume: float = 1.0
var _environment_volume: float = 1.0
var _network_profile: NetworkProfilePreferences
var _network_session: NetworkSession
var _data_root: PlayerDataRoot
var _identity_backups: IdentityBackupService
var _player_identity: PlayerIdentityStore
var _host_identity: HostIdentityStore
var _interface_fonts: InterfaceFontController
var _controller_mapping_manager: ControllerMappingManagerType
var _controller_mapping_panel: ControllerMappingPanelType
var _keyboard_mouse_mapping_manager: KeyboardMouseMappingManagerType
var _keyboard_mouse_mapping_panel: KeyboardMouseMappingPanelType
var _data_folder_dialog: FileDialog
var _backup_file_dialog: FileDialog
var _export_file_dialog: FileDialog
var _passphrase_dialog: ConfirmationDialog
var _passphrase_entry: LineEdit
var _passphrase_confirm: LineEdit
var _pending_identity_operation := ""
var _pending_identity_type := ""
var _pending_identity_path := ""
var _pending_import_data: Dictionary = {}


func _ready() -> void:
	_pages = {
		PAGE_ROOT: _root_page,
		PAGE_DISPLAY: _display_page,
		PAGE_SOUND: _sound_page,
		PAGE_CONTROLS: _controls_page,
		PAGE_ACCESSIBILITY: _accessibility_page,
		PAGE_DATA: _data_page,
	}
	%DisplayCategory.pressed.connect(_push_page.bind(PAGE_DISPLAY))
	%SoundCategory.pressed.connect(_push_page.bind(PAGE_SOUND))
	%ControlsCategory.pressed.connect(_push_page.bind(PAGE_CONTROLS))
	%AccessibilityCategory.pressed.connect(
		_push_page.bind(PAGE_ACCESSIBILITY)
	)
	%DataCategory.pressed.connect(_push_page.bind(PAGE_DATA))
	%ApplySettingsButton.pressed.connect(_apply_settings)
	%RootBackButton.pressed.connect(close_panel)
	%DisplayBackButton.pressed.connect(handle_back)
	%SoundBackButton.pressed.connect(handle_back)
	%ControlsBackButton.pressed.connect(handle_back)
	%ControllerMapping.pressed.connect(_open_controller_mapping)
	%KeyboardMapping.pressed.connect(_open_keyboard_mouse_mapping)
	%AccessibilityBackButton.pressed.connect(handle_back)
	%DataBackButton.pressed.connect(handle_back)
	%RootBackButton.gui_input.connect(_on_back_bubble_gui_input)
	%DisplayBackButton.gui_input.connect(_on_back_bubble_gui_input)
	%SoundBackButton.gui_input.connect(_on_back_bubble_gui_input)
	%ControlsBackButton.gui_input.connect(_on_back_bubble_gui_input)
	%AccessibilityBackButton.gui_input.connect(_on_back_bubble_gui_input)
	%DataBackButton.gui_input.connect(_on_back_bubble_gui_input)
	%OpenDataFolder.pressed.connect(_open_data_folder)
	%ChangeDataFolder.pressed.connect(_choose_data_folder)
	%ExportPlayerIdentity.pressed.connect(_choose_identity_export.bind("player"))
	%ImportPlayerIdentity.pressed.connect(_choose_identity_import.bind("player"))
	%CopyPlayerFingerprint.pressed.connect(_copy_player_fingerprint)
	%ExportHostIdentity.pressed.connect(_choose_identity_export.bind("host"))
	%ImportHostIdentity.pressed.connect(_choose_identity_import.bind("host"))
	for index: int in _world_options.size():
		_world_options[index].pressed.connect(
			_set_world_pixelation.bind(index + 1)
		)
	for index: int in _ui_options.size():
		_ui_options[index].pressed.connect(
			_set_ui_pixelation.bind(index + 1)
		)
	_chat_dock.pressed.connect(_toggle_chat_dock)
	_chat_mode.pressed.connect(_toggle_chat_mode)
	_paint_dock.pressed.connect(_toggle_paint_dock)
	_fullscreen_toggle.pressed.connect(_toggle_fullscreen)
	%MouseDecrease.pressed.connect(_adjust_mouse_sensitivity.bind(-1))
	%MouseIncrease.pressed.connect(_adjust_mouse_sensitivity.bind(1))
	_mouse_value.pressed.connect(_adjust_mouse_sensitivity.bind(1))
	%ControllerDecrease.pressed.connect(
		_adjust_controller_sensitivity.bind(-1)
	)
	%ControllerIncrease.pressed.connect(
		_adjust_controller_sensitivity.bind(1)
	)
	_controller_value.pressed.connect(
		_adjust_controller_sensitivity.bind(1)
	)
	_invert_y_toggle.pressed.connect(_toggle_invert_y)
	_on_screen_keyboard_toggle.pressed.connect(_toggle_on_screen_keyboard)
	_auto_click_toggle.pressed.connect(_toggle_auto_click)
	for control: Control in [_auto_click_toggle, _auto_click_interval]:
		control.mouse_entered.connect(
			_show_accessibility_helper.bind(&"auto_click")
		)
		control.focus_entered.connect(
			_show_accessibility_helper.bind(&"auto_click")
		)
	%IntervalDecrease.pressed.connect(_adjust_auto_click_interval.bind(-1))
	%IntervalIncrease.pressed.connect(_adjust_auto_click_interval.bind(1))
	_auto_click_interval.pressed.connect(
		_adjust_auto_click_interval.bind(1)
	)
	_master_volume_slider.value_changed.connect(
		_on_audio_volume_changed.bind(&"master")
	)
	_music_volume_slider.value_changed.connect(
		_on_audio_volume_changed.bind(&"music")
	)
	_effects_volume_slider.value_changed.connect(
		_on_audio_volume_changed.bind(&"effects")
	)
	_environment_volume_slider.value_changed.connect(
		_on_audio_volume_changed.bind(&"environment")
	)
	_mouse_value.gui_input.connect(
		_on_continuous_value_input.bind(&"mouse")
	)
	_controller_value.gui_input.connect(
		_on_continuous_value_input.bind(&"controller")
	)
	_auto_click_interval.gui_input.connect(
		_on_continuous_value_input.bind(&"interval")
	)
	resized.connect(_refresh_panel_size)
	var parent_control := get_parent() as Control
	if parent_control != null:
		parent_control.resized.connect(_refresh_panel_size)
	for page: SettingsBubblePage in _pages.values():
		page.hide_page()
	_controller_mapping_panel = ControllerMappingPanelType.new()
	add_child(_controller_mapping_panel)
	_controller_mapping_panel.closed.connect(
		_on_controller_mapping_panel_closed
	)
	_keyboard_mouse_mapping_panel = KeyboardMouseMappingPanelType.new()
	add_child(_keyboard_mouse_mapping_panel)
	_keyboard_mouse_mapping_panel.closed.connect(
		_on_keyboard_mouse_mapping_panel_closed
	)
	_style_data_page()
	_style_sound_page()
	call_deferred("_refresh_panel_size")


func setup_network_profile(
	profile: NetworkProfilePreferences,
	session: NetworkSession,
) -> void:
	_network_profile = profile
	_network_session = session


func setup_controller_mapping(
	mapping_manager: ControllerMappingManagerType,
) -> void:
	_controller_mapping_manager = mapping_manager
	_controller_mapping_panel.setup(_controller_mapping_manager)


func setup_keyboard_mouse_mapping(
	mapping_manager: KeyboardMouseMappingManagerType,
) -> void:
	_keyboard_mouse_mapping_manager = mapping_manager
	_keyboard_mouse_mapping_panel.setup(_keyboard_mouse_mapping_manager)


func setup_data_and_identity(
	data_root: PlayerDataRoot,
	identity_backups: IdentityBackupService,
	player_identity: PlayerIdentityStore,
	host_identity: HostIdentityStore,
	session: NetworkSession,
	interface_fonts: InterfaceFontController,
) -> void:
	_data_root = data_root
	_identity_backups = identity_backups
	_player_identity = player_identity
	_host_identity = host_identity
	_network_session = session
	_interface_fonts = interface_fonts
	_identity_backups.operation_finished.connect(_on_identity_operation_finished)
	_interface_fonts.apply_utility_theme(_data_page)
	_refresh_data_page()


func open_panel(
	settings_manager: SettingsManagerType,
	presentation_mode: PresentationMode = PresentationMode.GAMEPLAY_MODAL,
	animate_gameplay_host_transitions: bool = false,
) -> void:
	_cancel_page_transition()
	_presentation_mode = presentation_mode
	_animate_gameplay_host_transitions = animate_gameplay_host_transitions
	_settings_manager = settings_manager
	_load_controls()
	_feedback.text = ""
	_refresh_data_page()
	show()
	_page_stack.clear()
	_page_stack.append(PAGE_ROOT)
	panel_visibility_changed.emit(true)
	if (
		presentation_mode == PresentationMode.TITLE_EMBEDDED
		or _animate_gameplay_host_transitions
	):
		for page: SettingsBubblePage in _pages.values():
			page.hide_page()
		_page_transition_generation += 1
		_page_transition_active = true
		var generation: int = _page_transition_generation
		_root_page.transition_in(
			true,
			_finish_animated_open.bind(generation),
			0.0
		)
	else:
		_show_active_page(true)
		opened.emit()


func close_panel(immediate: bool = false) -> void:
	if not visible:
		return
	if immediate:
		_finish_panel_close(false)
		return
	if (
		_presentation_mode == PresentationMode.TITLE_EMBEDDED
		or _animate_gameplay_host_transitions
	):
		if _page_transition_active:
			return
		_begin_animated_close(false)
		return
	_finish_panel_close(false)


func _finish_panel_close(applied_result: bool) -> void:
	_cancel_page_transition()
	if (
		_controller_mapping_panel != null
		and _controller_mapping_panel.is_open()
	):
		_controller_mapping_panel.close_panel()
	if (
		_keyboard_mouse_mapping_panel != null
		and _keyboard_mouse_mapping_panel.is_open()
	):
		_keyboard_mouse_mapping_panel.close_panel()
	for page: SettingsBubblePage in _pages.values():
		page.hide_page()
	_page_stack.clear()
	hide()
	panel_visibility_changed.emit(false)
	if applied_result:
		applied.emit()
	else:
		_load_controls()
		closed.emit()


func handle_back() -> void:
	if (
		_keyboard_mouse_mapping_panel != null
		and _keyboard_mouse_mapping_panel.is_open()
	):
		_keyboard_mouse_mapping_panel.request_back()
		return
	if (
		_controller_mapping_panel != null
		and _controller_mapping_panel.is_open()
	):
		_controller_mapping_panel.request_back()
		return
	if _page_transition_active:
		return
	if _page_stack.size() > 1:
		_start_page_transition(_page_stack[-2], false)
		return
	close_panel()


func _open_controller_mapping() -> void:
	if _controller_mapping_manager == null:
		_feedback.text = "no controller mapping service is available"
		return
	_controller_mapping_panel.open_panel()


func _on_controller_mapping_panel_closed() -> void:
	%ControllerMapping.grab_focus()


func _open_keyboard_mouse_mapping() -> void:
	if _keyboard_mouse_mapping_manager == null:
		_feedback.text = "no keyboard binding service is available"
		return
	_keyboard_mouse_mapping_panel.open_panel()


func _on_keyboard_mouse_mapping_panel_closed() -> void:
	%KeyboardMapping.grab_focus()


func get_active_page_id() -> StringName:
	return _page_stack.back() if not _page_stack.is_empty() else StringName()


func is_controller_mapping_capturing() -> bool:
	return (
		_controller_mapping_panel != null
		and _controller_mapping_panel.is_capturing()
	)


func is_input_mapping_capturing() -> bool:
	return (
		is_controller_mapping_capturing()
		or (
			_keyboard_mouse_mapping_panel != null
			and _keyboard_mouse_mapping_panel.is_capturing()
		)
	)


func _push_page(page_id: StringName) -> void:
	if (
		_page_transition_active
		or not _pages.has(page_id)
		or get_active_page_id() == page_id
	):
		return
	_start_page_transition(page_id, true)


func _start_page_transition(page_id: StringName, push_page: bool) -> void:
	var outgoing_page: SettingsBubblePage = _get_active_page()
	var incoming_page: SettingsBubblePage = _pages.get(page_id)
	if outgoing_page == null or incoming_page == null:
		return
	_page_transition_generation += 1
	_page_transition_active = true
	navigation_transition_started.emit()
	var generation: int = _page_transition_generation
	if push_page:
		_page_stack.append(page_id)
	else:
		_page_stack.pop_back()
	for page: SettingsBubblePage in _pages.values():
		if page != outgoing_page and page != incoming_page:
			page.hide_page()
	outgoing_page.transition_out(
		Callable()
	)
	get_tree().create_timer(
		UIMotion.BUBBLE_TRANSITION_OVERLAP_DELAY
	).timeout.connect(
		func() -> void:
			if (
				generation == _page_transition_generation
				and _page_transition_active
			):
				incoming_page.transition_in(
					true,
					_finish_incoming_page.bind(generation)
				),
		CONNECT_ONE_SHOT
	)


func _finish_incoming_page(generation: int) -> void:
	if generation != _page_transition_generation or not _page_transition_active:
		return
	_page_transition_active = false


func _finish_animated_open(generation: int) -> void:
	if generation != _page_transition_generation or not _page_transition_active:
		return
	_page_transition_active = false
	opened.emit()


func _begin_animated_close(applied_result: bool) -> void:
	var active_page: SettingsBubblePage = _get_active_page()
	if active_page == null:
		return
	_page_transition_generation += 1
	_page_transition_active = true
	navigation_transition_started.emit()
	closing.emit()
	var generation: int = _page_transition_generation
	active_page.transition_out(
		_finish_animated_close.bind(generation, applied_result),
		0.0
	)


func _finish_animated_close(
	generation: int,
	applied_result: bool,
) -> void:
	if generation != _page_transition_generation or not _page_transition_active:
		return
	_finish_panel_close(applied_result)


func _cancel_page_transition() -> void:
	_page_transition_generation += 1
	_page_transition_active = false


func _show_active_page(should_focus: bool) -> void:
	for page_id: StringName in _pages:
		var page: SettingsBubblePage = _pages[page_id]
		if page_id == get_active_page_id():
			page.show_page(should_focus)
		else:
			page.hide_page()
	if get_active_page_id() == PAGE_DATA:
		_refresh_data_page()
		if should_focus:
			%OpenDataFolder.call_deferred("grab_focus")


func _refresh_data_page() -> void:
	if not is_node_ready() or _data_root == null:
		return
	%DataFolderPath.text = _data_root.root_path
	%DataStorageMode.text = "Storage Mode: " + _data_root.storage_mode_text()
	%ChangeDataFolder.disabled = (
		_data_root.override_active
		or (_network_session != null and _network_session.is_session_active())
	)
	var fingerprint: String = (
		_player_identity.fingerprint if _player_identity != null else ""
	)
	%CopyPlayerFingerprint.disabled = not NetworkIdentityCrypto.valid_fingerprint(
		fingerprint
	)
	%CopyPlayerFingerprint.text = (
		"Copy Player Fingerprint · %s"
		% NetworkIdentityCrypto.compact_suffix(fingerprint)
	)


func _open_data_folder() -> void:
	if _data_root == null or not _data_root.open_folder():
		_feedback.text = "Could not open the data folder."


func _copy_player_fingerprint() -> void:
	var fingerprint: String = (
		_player_identity.fingerprint if _player_identity != null else ""
	)
	if not NetworkIdentityCrypto.valid_fingerprint(fingerprint):
		_feedback.text = "Player identity is unavailable."
		return
	DisplayServer.clipboard_set(fingerprint)
	_feedback.text = "Full player fingerprint copied for server operator setup."


func _choose_data_folder() -> void:
	if _data_root == null or _data_root.override_active:
		_feedback.text = "The data folder is externally managed."
		return
	if _network_session != null and _network_session.is_session_active():
		_feedback.text = "Return to title to change the data folder."
		return
	if _data_folder_dialog == null:
		_data_folder_dialog = FileDialog.new()
		_data_folder_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
		_data_folder_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_data_folder_dialog.use_native_dialog = false
		_data_folder_dialog.dir_selected.connect(_change_data_folder)
		_interface_fonts.apply_utility_theme(_data_folder_dialog)
		add_child(_data_folder_dialog)
	_data_folder_dialog.current_dir = _data_root.root_path.get_base_dir()
	_interface_fonts.popup_file_dialog(_data_folder_dialog)


func _change_data_folder(path: String) -> void:
	var result: Dictionary = PortableDataMigration.migrate_active_to(
		_data_root, path
	)
	if bool(result.get("requires_existing_root_decision", false)):
		_show_existing_data_folder_choice(path)
		return
	if bool(result.get("ok", false)):
		_feedback.text = "Data folder changed. NETfishing will close safely."
		_refresh_data_page()
		get_tree().call_deferred("quit")
	else:
		_feedback.text = str(result.get("message", "Could not change the data folder."))


func _show_existing_data_folder_choice(path: String) -> void:
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.title = "Existing NETfishing data"
	dialog.ok_button_text = "Use Selected Data"
	dialog.dialog_text = (
		"The selected folder contains different NETfishing data.\n\n"
		+ "Choose one complete data set. Data will not be merged."
	)
	dialog.add_button("Replace Selected Data", false, "replace")
	dialog.confirmed.connect(func() -> void:
		if _data_root.use_existing_root(path):
			_feedback.text = "Data folder changed. NETfishing will close safely."
			get_tree().call_deferred("quit")
		else:
			_feedback.text = _data_root.error_message
		dialog.queue_free()
	)
	dialog.custom_action.connect(func(action: StringName) -> void:
		if action != &"replace":
			return
		var result: Dictionary = PortableDataMigration.replace_existing_with_active(
			_data_root, path
		)
		_feedback.text = str(result.get("message", "Could not replace selected data."))
		if bool(result.get("ok", false)):
			get_tree().call_deferred("quit")
		dialog.queue_free()
	)
	_interface_fonts.apply_utility_theme(dialog)
	add_child(dialog)
	dialog.popup_centered(Vector2i(620, 340))
	_configure_confirmation_dialog.call_deferred(
		dialog, dialog.get_cancel_button()
	)


func _choose_identity_export(identity_type: String) -> void:
	if not _identity_operation_allowed():
		return
	_pending_identity_operation = "export"
	_pending_identity_type = identity_type
	var suggested: String = _identity_backups.default_export_path(identity_type)
	if _export_file_dialog == null:
		_export_file_dialog = FileDialog.new()
		_export_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		_export_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_export_file_dialog.use_native_dialog = false
		_export_file_dialog.filters = PackedStringArray(["*.nfidentity ; NETfishing identity backup"])
		_export_file_dialog.file_selected.connect(_identity_export_file_selected)
		_interface_fonts.apply_utility_theme(_export_file_dialog)
		add_child(_export_file_dialog)
	_export_file_dialog.current_dir = suggested.get_base_dir()
	_export_file_dialog.current_file = suggested.get_file()
	_interface_fonts.popup_file_dialog(_export_file_dialog)


func _identity_export_file_selected(path: String) -> void:
	_pending_identity_path = (
		path if path.ends_with(".nfidentity") else path + ".nfidentity"
	)
	_show_passphrase_dialog(true)


func _choose_identity_import(identity_type: String) -> void:
	if not _identity_operation_allowed():
		return
	_pending_identity_operation = "import"
	_pending_identity_type = identity_type
	if _backup_file_dialog == null:
		_backup_file_dialog = FileDialog.new()
		_backup_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_backup_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_backup_file_dialog.use_native_dialog = false
		_backup_file_dialog.filters = PackedStringArray(["*.nfidentity ; NETfishing identity backup"])
		_backup_file_dialog.file_selected.connect(_identity_import_file_selected)
		_interface_fonts.apply_utility_theme(_backup_file_dialog)
		add_child(_backup_file_dialog)
	_backup_file_dialog.current_dir = _data_root.identity_backup_directory()
	_interface_fonts.popup_file_dialog(_backup_file_dialog)


func _identity_import_file_selected(path: String) -> void:
	_pending_identity_path = path
	_show_passphrase_dialog(false)


func _show_passphrase_dialog(exporting: bool) -> void:
	if _passphrase_dialog == null:
		_passphrase_dialog = ConfirmationDialog.new()
		_passphrase_dialog.title = "Encrypted identity backup"
		_passphrase_dialog.confirmed.connect(_submit_identity_passphrase)
		var fields: VBoxContainer = VBoxContainer.new()
		var warning: Label = Label.new()
		warning.text = (
			"Anyone with this backup and passphrase can use your identity."
		)
		warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		fields.add_child(warning)
		_passphrase_entry = LineEdit.new()
		_passphrase_entry.placeholder_text = "Passphrase (12 characters minimum)"
		_passphrase_entry.secret = true
		fields.add_child(_passphrase_entry)
		_passphrase_confirm = LineEdit.new()
		_passphrase_confirm.placeholder_text = "Confirm passphrase"
		_passphrase_confirm.secret = true
		fields.add_child(_passphrase_confirm)
		_passphrase_dialog.add_child(fields)
		_interface_fonts.apply_utility_theme(_passphrase_dialog)
		add_child(_passphrase_dialog)
	_passphrase_confirm.visible = exporting
	_passphrase_entry.clear()
	_passphrase_confirm.clear()
	_passphrase_dialog.dialog_text = (
		"Create a passphrase-encrypted backup."
		if exporting else "Enter the backup passphrase."
	)
	_passphrase_dialog.popup_centered(Vector2i(560, 300))
	_configure_confirmation_dialog.call_deferred(
		_passphrase_dialog, _passphrase_entry
	)


func _submit_identity_passphrase() -> void:
	var passphrase: String = _passphrase_entry.text
	if _pending_identity_operation == "export":
		_identity_backups.export_backup(
			_pending_identity_type,
			_pending_identity_path,
			passphrase,
			_passphrase_confirm.text,
		)
		return
	var inspected: Dictionary = _identity_backups.import_backup(
		_pending_identity_type,
		_pending_identity_path,
		passphrase,
		false,
	)
	if bool(inspected.get("requires_confirmation", false)):
		_pending_import_data = {
			"passphrase": passphrase,
			"current": inspected["current_fingerprint"],
			"incoming": inspected["incoming_fingerprint"],
		}
		_show_identity_replacement_confirmation()


func _show_identity_replacement_confirmation() -> void:
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.title = "Replace active identity?"
	dialog.ok_button_text = "Review Replacement"
	dialog.dialog_text = (
		"Current:\n%s\n\nIncoming:\n%s\n\n"
		+ "Other players will recognize this device as the imported identity."
	) % [
		NetworkIdentityCrypto.format_fingerprint(_pending_import_data["current"]),
		NetworkIdentityCrypto.format_fingerprint(_pending_import_data["incoming"]),
	]
	dialog.set_meta("confirmation_step", 1)
	dialog.confirmed.connect(_advance_identity_replacement.bind(dialog))
	dialog.canceled.connect(dialog.queue_free)
	_interface_fonts.apply_utility_theme(dialog)
	add_child(dialog)
	dialog.popup_centered(Vector2i(620, 360))
	_configure_confirmation_dialog.call_deferred(
		dialog, dialog.get_cancel_button()
	)


func _advance_identity_replacement(dialog: ConfirmationDialog) -> void:
	if int(dialog.get_meta("confirmation_step", 1)) == 1:
		dialog.set_meta("confirmation_step", 2)
		dialog.ok_button_text = "Replace Identity"
		dialog.dialog_text = (
			"Replace the active identity and archive the current key locally?"
		)
		dialog.call_deferred("popup_centered", Vector2i(560, 280))
		_configure_confirmation_dialog.call_deferred(
			dialog, dialog.get_cancel_button()
		)
		return
	_confirm_identity_replacement(dialog)


func _confirm_identity_replacement(dialog: ConfirmationDialog) -> void:
	_identity_backups.import_backup(
		_pending_identity_type,
		_pending_identity_path,
		str(_pending_import_data["passphrase"]),
		true,
	)
	_pending_import_data.clear()
	dialog.queue_free()


func _configure_confirmation_dialog(
	dialog: ConfirmationDialog,
	preferred_control: Control,
) -> void:
	if dialog != null and is_instance_valid(dialog) and dialog.visible:
		DialogControllerNavigationType.configure_scope(
			dialog, preferred_control
		)


func _identity_operation_allowed() -> bool:
	if _identity_backups == null:
		_feedback.text = "Identity backup is unavailable."
		return false
	if _network_session != null and _network_session.is_session_active():
		_feedback.text = "Return to title to change an identity."
		return false
	return true


func _on_identity_operation_finished(_success: bool, message: String) -> void:
	_feedback.text = message


func _get_active_page() -> SettingsBubblePage:
	return _pages.get(get_active_page_id()) as SettingsBubblePage


func _apply_settings() -> void:
	if _page_transition_active:
		return
	if _settings_manager == null:
		_feedback.text = "settings are unavailable."
		return
	var edited: PlayerSettings = _settings_manager.current_settings.copy()
	edited.auto_click_enabled = _auto_click_enabled
	edited.auto_click_interval = _auto_click_interval_value
	edited.mouse_camera_sensitivity = _mouse_sensitivity
	edited.controller_camera_sensitivity = _controller_sensitivity
	edited.invert_camera_y = _invert_camera_y
	edited.on_screen_keyboard_enabled = _on_screen_keyboard_enabled
	edited.master_volume = _master_volume
	edited.music_volume = _music_volume
	edited.effects_volume = _effects_volume
	edited.environment_volume = _environment_volume
	if _settings_manager.apply_settings(edited):
		if (
			_presentation_mode == PresentationMode.TITLE_EMBEDDED
			or _animate_gameplay_host_transitions
		):
			_begin_animated_close(true)
		else:
			_finish_panel_close(true)
	else:
		_feedback.text = "failed to save settings."


func _load_controls() -> void:
	if _settings_manager == null or not is_node_ready():
		return
	var settings: PlayerSettings = _settings_manager.current_settings
	_auto_click_enabled = settings.auto_click_enabled
	_auto_click_interval_value = settings.auto_click_interval
	_mouse_sensitivity = settings.mouse_camera_sensitivity
	_controller_sensitivity = settings.controller_camera_sensitivity
	_invert_camera_y = settings.invert_camera_y
	_on_screen_keyboard_enabled = settings.on_screen_keyboard_enabled
	_master_volume = settings.master_volume
	_music_volume = settings.music_volume
	_effects_volume = settings.effects_volume
	_environment_volume = settings.environment_volume
	_master_volume_slider.set_value_no_signal(_master_volume * 100.0)
	_music_volume_slider.set_value_no_signal(_music_volume * 100.0)
	_effects_volume_slider.set_value_no_signal(_effects_volume * 100.0)
	_environment_volume_slider.set_value_no_signal(
		_environment_volume * 100.0
	)
	_settings_manager.restore_audio_levels()
	_refresh_value_labels()


func _refresh_value_labels() -> void:
	if _settings_manager == null:
		return
	var settings: PlayerSettings = _settings_manager.current_settings
	_world_value.text = (
		"world\npixelation\n"
		+ _pixel_size_label(settings.world_pixel_size)
	)
	_ui_value.text = (
		"ui\npixelation\n"
		+ _pixel_size_label(settings.ui_pixel_size)
	)
	_chat_dock.text = "chat dock\n" + ("right" if settings.chat_dock_right else "left")
	_chat_mode.text = (
		"chat mode\n" + ("mobile" if settings.chat_mobile_mode else "desktop")
	)
	_paint_dock.text = (
		"paint dock\n" + ("right" if settings.paint_dock_right else "left")
	)
	_fullscreen_toggle.text = (
		"fullscreen\n" + ("on" if settings.fullscreen_enabled else "off")
	)
	_mouse_value.text = "mouse\nsensitivity\n%.4f" % _mouse_sensitivity
	_controller_value.text = (
		"controller\nsensitivity\n%.1f" % _controller_sensitivity
	)
	_invert_y_toggle.text = (
		"invert\nvertical\ncamera\n"
		+ ("on" if _invert_camera_y else "off")
	)
	_on_screen_keyboard_toggle.text = (
		"on-screen\nkeyboard\n"
		+ ("on" if _on_screen_keyboard_enabled else "off")
	)
	_auto_click_toggle.text = (
		"accessibility\nauto-click\n"
		+ ("on" if _auto_click_enabled else "off")
	)
	_auto_click_interval.text = (
		"auto-click\ninterval\n%.2f s" % _auto_click_interval_value
	)
	_refresh_audio_value_labels()
	for index: int in _world_options.size():
		_world_options[index].button_pressed = (
			index + 1 == settings.world_pixel_size
		)
	for index: int in _ui_options.size():
		_ui_options[index].button_pressed = index + 1 == settings.ui_pixel_size


func _show_accessibility_helper(_kind: StringName) -> void:
	var helper := %IntervalHelp as BubbleButton
	helper.text = (
		"Lower intervals click\nbarriers faster\nwhile held."
	)


func _style_data_page() -> void:
	UtilityPageStyle.apply_page(_data_page)
	var paper := _data_page.get_node("Paper") as PanelContainer
	paper.add_theme_stylebox_override(
		"panel", UtilityPageStyle.panel_style()
	)
	var content := _data_page.get_node("Paper/Content") as VBoxContainer
	content.add_theme_constant_override("separation", 12)
	for node: Node in content.find_children("*", "", true, false):
		if node is BaseButton:
			UtilityPageStyle.apply_ocean_button(node)
		elif node is Label:
			node.add_theme_color_override(
				"font_color", UtilityPageStyle.OCEAN_TEXT_PRIMARY
			)


func _style_sound_page() -> void:
	UtilityPageStyle.apply_page(_sound_page)
	var paper := _sound_page.get_node("Paper") as PanelContainer
	paper.add_theme_stylebox_override(
		"panel", UtilityPageStyle.panel_style()
	)
	var content := _sound_page.get_node("Paper/Content") as VBoxContainer
	for node: Node in content.find_children("*", "Label", true, false):
		(node as Label).add_theme_color_override(
			"font_color", UtilityPageStyle.OCEAN_TEXT_PRIMARY
		)


func _on_audio_volume_changed(value: float, channel: StringName) -> void:
	var linear_volume: float = clampf(value / 100.0, 0.0, 1.0)
	match channel:
		&"master":
			_master_volume = linear_volume
		&"music":
			_music_volume = linear_volume
		&"effects":
			_effects_volume = linear_volume
		&"environment":
			_environment_volume = linear_volume
	_refresh_audio_value_labels()
	if _settings_manager != null:
		_settings_manager.preview_audio_levels(
			_master_volume,
			_music_volume,
			_effects_volume,
			_environment_volume,
		)


func _refresh_audio_value_labels() -> void:
	_master_volume_value.text = "%d%%" % roundi(_master_volume * 100.0)
	_music_volume_value.text = "%d%%" % roundi(_music_volume * 100.0)
	_effects_volume_value.text = "%d%%" % roundi(_effects_volume * 100.0)
	_environment_volume_value.text = (
		"%d%%" % roundi(_environment_volume * 100.0)
	)


func _set_world_pixelation(pixel_size: int) -> void:
	if _settings_manager == null:
		return
	if not _settings_manager.apply_pixelation(
		pixel_size,
		_settings_manager.current_settings.ui_pixel_size
	):
		_feedback.text = "failed to save pixelation settings."
		return
	_refresh_value_labels()


func _set_ui_pixelation(pixel_size: int) -> void:
	if _settings_manager == null:
		return
	if not _settings_manager.apply_pixelation(
		_settings_manager.current_settings.world_pixel_size,
		pixel_size
	):
		_feedback.text = "failed to save pixelation settings."
		return
	_refresh_value_labels()


func _toggle_chat_dock() -> void:
	if _settings_manager == null:
		return
	var edited: PlayerSettings = _settings_manager.current_settings.copy()
	edited.chat_dock_right = not edited.chat_dock_right
	if not _settings_manager.apply_settings(edited):
		_feedback.text = "failed to save chat dock setting."
		return
	_refresh_value_labels()


func _toggle_chat_mode() -> void:
	if _settings_manager == null:
		return
	var edited: PlayerSettings = _settings_manager.current_settings.copy()
	edited.chat_mobile_mode = not edited.chat_mobile_mode
	if not _settings_manager.apply_settings(edited):
		_feedback.text = "failed to save chat mode setting."
		return
	_refresh_value_labels()


func _toggle_fullscreen() -> void:
	if _settings_manager == null:
		return
	var edited: PlayerSettings = _settings_manager.current_settings.copy()
	edited.fullscreen_enabled = not edited.fullscreen_enabled
	if not _settings_manager.apply_settings(edited):
		_feedback.text = "failed to save fullscreen setting."
		return
	_refresh_value_labels()


func _toggle_paint_dock() -> void:
	if _settings_manager == null:
		return
	var edited: PlayerSettings = _settings_manager.current_settings.copy()
	edited.paint_dock_right = not edited.paint_dock_right
	if not _settings_manager.apply_settings(edited):
		_feedback.text = "failed to save paint dock setting."
		return
	_refresh_value_labels()


func _adjust_mouse_sensitivity(direction: int) -> void:
	_mouse_sensitivity = clampf(
		_mouse_sensitivity + float(direction) * 0.0005,
		PlayerSettings.MIN_MOUSE_SENSITIVITY,
		PlayerSettings.MAX_MOUSE_SENSITIVITY
	)
	_refresh_value_labels()


func _adjust_controller_sensitivity(direction: int) -> void:
	_controller_sensitivity = clampf(
		_controller_sensitivity + float(direction) * 0.1,
		PlayerSettings.MIN_CONTROLLER_SENSITIVITY,
		PlayerSettings.MAX_CONTROLLER_SENSITIVITY
	)
	_refresh_value_labels()


func _adjust_auto_click_interval(direction: int) -> void:
	_auto_click_interval_value = clampf(
		_auto_click_interval_value + float(direction) * 0.01,
		PlayerSettings.MIN_AUTO_CLICK_INTERVAL,
		PlayerSettings.MAX_AUTO_CLICK_INTERVAL
	)
	_refresh_value_labels()


func _toggle_invert_y() -> void:
	_invert_camera_y = not _invert_camera_y
	_refresh_value_labels()


func _toggle_on_screen_keyboard() -> void:
	_on_screen_keyboard_enabled = not _on_screen_keyboard_enabled
	_refresh_value_labels()


func _toggle_auto_click() -> void:
	_auto_click_enabled = not _auto_click_enabled
	_refresh_value_labels()


func _on_continuous_value_input(
	event: InputEvent,
	control_id: StringName,
) -> void:
	var direction: int = 0
	if event.is_action_pressed("ui_left"):
		direction = -1
	elif event.is_action_pressed("ui_right"):
		direction = 1
	if direction == 0:
		return
	match control_id:
		&"mouse":
			_adjust_mouse_sensitivity(direction)
		&"controller":
			_adjust_controller_sensitivity(direction)
		&"interval":
			_adjust_auto_click_interval(direction)
	accept_event()


func _pixel_size_label(pixel_size: int) -> String:
	var index: int = clampi(
		pixel_size - 1,
		0,
		PIXELATION_NAMES.size() - 1
	)
	return PIXELATION_NAMES[index]


func set_effective_ui_pixel_size(pixel_size: int) -> void:
	_effective_ui_pixel_size = clampi(
		pixel_size,
		PlayerSettings.MIN_UI_PIXEL_SIZE,
		PlayerSettings.MAX_UI_PIXEL_SIZE
	)
	if is_node_ready():
		_refresh_value_labels()


func focus_back_button() -> void:
	var active_page: SettingsBubblePage = _get_active_page()
	if active_page != null:
		active_page.focus_back()


func _on_back_bubble_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_down") or event.is_action_pressed("ui_focus_next"):
		crisp_reset_focus_requested.emit()
		accept_event()


func refresh_open_panel() -> void:
	if visible:
		_load_controls()


func _refresh_panel_size() -> void:
	if not is_node_ready():
		return
	var parent_control := get_parent() as Control
	if parent_control == null:
		return
	var available_size: Vector2 = parent_control.size - Vector2.ONE * (
		PANEL_EDGE_MARGIN * 2.0
	)
	var target_size := Vector2(
		minf(MAX_PANEL_SIZE.x, maxf(320.0, available_size.x)),
		minf(MAX_PANEL_SIZE.y, maxf(240.0, available_size.y))
	)
	custom_minimum_size = target_size
	if parent_control is CenterContainer:
		return
	set_anchors_preset(Control.PRESET_CENTER)
	position = (parent_control.size - target_size) * 0.5
	size = target_size
