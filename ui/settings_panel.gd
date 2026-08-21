class_name SettingsPanel
extends Control

const PANEL_SIZE: Vector2 = Vector2(880.0, 660.0)
const PANEL_EDGE_MARGIN: float = 16.0
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

@onready var _main_panel: PanelContainer = %MainPanel
@onready var _content_panel: PanelContainer = %ContentPanel
@onready var _feedback: Label = %SettingsFeedback
@onready var _display_page: Control = %DisplayPage
@onready var _sound_page: Control = %SoundPage
@onready var _controls_page: Control = %ControlsPage
@onready var _accessibility_page: Control = %AccessibilityPage
@onready var _data_page: Control = %DataPage

@onready var _display_tab: OrganizerTab = %DisplayTab
@onready var _sound_tab: OrganizerTab = %SoundTab
@onready var _controls_tab: OrganizerTab = %ControlsTab
@onready var _accessibility_tab: OrganizerTab = %AccessibilityTab
@onready var _data_tab: OrganizerTab = %DataTab

@onready var _world_pixelation: OptionButton = %WorldPixelationSelector
@onready var _ui_pixelation: OptionButton = %UIPixelationSelector
@onready var _chat_dock: OptionButton = %ChatDockSelector
@onready var _chat_mode: OptionButton = %ChatModeSelector
@onready var _paint_dock: OptionButton = %PaintDockSelector
@onready var _fullscreen_toggle: Button = %FullscreenToggle

@onready var _master_volume_slider: HSlider = %MasterVolumeSlider
@onready var _music_volume_slider: HSlider = %MusicVolumeSlider
@onready var _effects_volume_slider: HSlider = %EffectsVolumeSlider
@onready var _environment_volume_slider: HSlider = %EnvironmentVolumeSlider
@onready var _master_volume_value: Label = %MasterVolumeValue
@onready var _music_volume_value: Label = %MusicVolumeValue
@onready var _effects_volume_value: Label = %EffectsVolumeValue
@onready var _environment_volume_value: Label = %EnvironmentVolumeValue

@onready var _mouse_sensitivity_slider: HSlider = %MouseSensitivitySlider
@onready var _controller_sensitivity_slider: HSlider = (
	%ControllerSensitivitySlider
)
@onready var _mouse_sensitivity_value: Label = %MouseSensitivityValue
@onready var _controller_sensitivity_value: Label = (
	%ControllerSensitivityValue
)
@onready var _invert_y_toggle: Button = %InvertYToggle
@onready var _on_screen_keyboard_toggle: Button = %OnScreenKeyboardToggle
@onready var _auto_click_toggle: Button = %AutoClickToggle
@onready var _auto_click_interval_slider: HSlider = (
	%AutoClickIntervalSlider
)
@onready var _auto_click_interval_value_label: Label = (
	%AutoClickIntervalValue
)
@onready var _apply_button: Button = %ApplySettingsButton
@onready var _back_button: Button = %SettingsBackButton

var _settings_manager: SettingsManagerType
var _effective_ui_pixel_size: int = PlayerSettings.DEFAULT_UI_PIXEL_SIZE
var _pages: Dictionary[StringName, Control] = {}
var _tabs: Dictionary[StringName, OrganizerTab] = {}
var _active_page_id: StringName = PAGE_DISPLAY
var _presentation_mode: PresentationMode = PresentationMode.GAMEPLAY_MODAL
var _animate_gameplay_host_transitions: bool = false
var _panel_tween: Tween
var _transition_generation: int = 0
var _transition_active: bool = false
var _auto_click_enabled: bool = false
var _auto_click_interval_value: float = 0.20
var _mouse_sensitivity: float = 0.005
var _controller_sensitivity: float = 2.5
var _invert_camera_y: bool = false
var _on_screen_keyboard_enabled: bool = false
var _chat_dock_right: bool = false
var _chat_mobile_mode: bool = false
var _paint_dock_right: bool = true
var _presentation_layout_edited: bool = false
var _fullscreen_enabled: bool = false
var _master_volume: float = 1.0
var _music_volume: float = 1.0
var _effects_volume: float = 1.0
var _environment_volume: float = 1.0
var _network_profile: NetworkProfilePreferences
var _network_session: NetworkSession
var _data_root: PlayerDataRoot
var _progression_saves: PlayerSaveManager
var _identity_backups: IdentityBackupService
var _player_identity: PlayerIdentityStore
var _host_identity: HostIdentityStore
var _interface_fonts: InterfaceFontController
var _controller_mapping_manager: ControllerMappingManagerType
var _controller_mapping_panel: ControllerMappingPanelType
var _keyboard_mouse_mapping_manager: KeyboardMouseMappingManagerType
var _keyboard_mouse_mapping_panel: KeyboardMouseMappingPanelType
var _data_folder_dialog: FileDialog
var _progression_import_dialog: FileDialog
var _progression_export_dialog: FileDialog
var _backup_file_dialog: FileDialog
var _export_file_dialog: FileDialog
var _passphrase_dialog: ConfirmationDialog
var _passphrase_entry: LineEdit
var _passphrase_confirm: LineEdit
var _pending_identity_operation := ""
var _pending_identity_type := ""
var _pending_identity_path := ""
var _pending_import_data: Dictionary = {}
var _pending_progression_path := ""


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not visible:
		_release_owned_focus()


func _ready() -> void:
	_pages = {
		PAGE_DISPLAY: _display_page,
		PAGE_SOUND: _sound_page,
		PAGE_CONTROLS: _controls_page,
		PAGE_ACCESSIBILITY: _accessibility_page,
		PAGE_DATA: _data_page,
	}
	_tabs = {
		PAGE_DISPLAY: _display_tab,
		PAGE_SOUND: _sound_tab,
		PAGE_CONTROLS: _controls_tab,
		PAGE_ACCESSIBILITY: _accessibility_tab,
		PAGE_DATA: _data_tab,
	}
	for page_id: StringName in _tabs:
		_tabs[page_id].pressed.connect(_select_page.bind(page_id, true))
	_populate_option_buttons()
	_connect_controls()
	_configure_style()
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
	resized.connect(_refresh_panel_size)
	var parent_control := get_parent() as Control
	if parent_control != null:
		parent_control.resized.connect(_refresh_panel_size)
	_select_page(PAGE_DISPLAY, false)
	call_deferred("_refresh_panel_size")


func _populate_option_buttons() -> void:
	for selector: OptionButton in [_world_pixelation, _ui_pixelation]:
		selector.clear()
		for index: int in PIXELATION_NAMES.size():
			selector.add_item(PIXELATION_NAMES[index], index + 1)
	_chat_dock.clear()
	_chat_dock.add_item("left", 0)
	_chat_dock.add_item("right", 1)
	_chat_mode.clear()
	_chat_mode.add_item("desktop", 0)
	_chat_mode.add_item("mobile", 1)
	_paint_dock.clear()
	_paint_dock.add_item("left", 0)
	_paint_dock.add_item("right", 1)


func _connect_controls() -> void:
	_apply_button.pressed.connect(_apply_settings)
	_back_button.pressed.connect(close_panel)
	_back_button.gui_input.connect(_on_back_button_gui_input)
	_world_pixelation.item_selected.connect(
		_on_world_pixelation_selected
	)
	_ui_pixelation.item_selected.connect(_on_ui_pixelation_selected)
	_chat_dock.item_selected.connect(_on_chat_dock_selected)
	_chat_mode.item_selected.connect(_on_chat_mode_selected)
	_paint_dock.item_selected.connect(_on_paint_dock_selected)
	_fullscreen_toggle.toggled.connect(_set_fullscreen)
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
	_mouse_sensitivity_slider.value_changed.connect(
		_on_mouse_sensitivity_changed
	)
	_controller_sensitivity_slider.value_changed.connect(
		_on_controller_sensitivity_changed
	)
	_invert_y_toggle.toggled.connect(_set_invert_y)
	_on_screen_keyboard_toggle.toggled.connect(_set_on_screen_keyboard)
	_auto_click_toggle.toggled.connect(_set_auto_click)
	_auto_click_interval_slider.value_changed.connect(
		_on_auto_click_interval_changed
	)
	%ControllerMapping.pressed.connect(_open_controller_mapping)
	%KeyboardMapping.pressed.connect(_open_keyboard_mouse_mapping)
	%OpenDataFolder.pressed.connect(_open_data_folder)
	%ChangeDataFolder.pressed.connect(_choose_data_folder)
	%ExportProgression.pressed.connect(_choose_progression_export)
	%ImportProgression.pressed.connect(_choose_progression_import)
	%ExportPlayerIdentity.pressed.connect(
		_choose_identity_export.bind("player")
	)
	%ImportPlayerIdentity.pressed.connect(
		_choose_identity_import.bind("player")
	)
	%CopyPlayerFingerprint.pressed.connect(_copy_player_fingerprint)
	%ExportHostIdentity.pressed.connect(
		_choose_identity_export.bind("host")
	)
	%ImportHostIdentity.pressed.connect(
		_choose_identity_import.bind("host")
	)


func _on_back_button_gui_input(event: InputEvent) -> void:
	if (
		event.is_action_pressed("ui_right")
		or event.is_action_pressed("ui_down")
		or event.is_action_pressed("ui_focus_next")
	):
		crisp_reset_focus_requested.emit()
		get_viewport().set_input_as_handled()


func _configure_style() -> void:
	UtilityPageStyle.apply_page(self)
	_main_panel.add_theme_stylebox_override(
		"panel",
		UtilityPageStyle.rounded_style(
			UtilityPageStyle.OCEAN_PANEL_MID,
			28,
		),
	)
	_content_panel.add_theme_stylebox_override(
		"panel",
		UtilityPageStyle.rounded_style(
			UtilityPageStyle.OCEAN_FIELD,
			20,
		),
	)
	for node: Node in find_children("*", "Label", true, false):
		var label := node as Label
		label.add_theme_color_override(
			"font_color",
			UtilityPageStyle.OCEAN_TEXT_PRIMARY,
		)
	for node: Node in find_children("*", "Button", true, false):
		if node is OrganizerTab:
			continue
		UtilityPageStyle.apply_ocean_button(node as BaseButton)
	for node: Node in find_children("*", "OptionButton", true, false):
		UtilityPageStyle.apply_ocean_button(node as BaseButton)
	_apply_button.add_theme_stylebox_override(
		"normal",
		UtilityPageStyle.ocean_button_style(Color("31594d")),
	)
	_back_button.add_theme_stylebox_override(
		"normal",
		UtilityPageStyle.ocean_button_style(
			UtilityPageStyle.OCEAN_PANEL_DEEP,
		),
	)
	_feedback.add_theme_color_override(
		"font_color",
		UtilityPageStyle.OCEAN_TEXT_SECONDARY,
	)


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
	progression_saves: PlayerSaveManager,
	identity_backups: IdentityBackupService,
	player_identity: PlayerIdentityStore,
	host_identity: HostIdentityStore,
	session: NetworkSession,
	interface_fonts: InterfaceFontController,
) -> void:
	_data_root = data_root
	_progression_saves = progression_saves
	_identity_backups = identity_backups
	_player_identity = player_identity
	_host_identity = host_identity
	_network_session = session
	_interface_fonts = interface_fonts
	if not _identity_backups.operation_finished.is_connected(
		_on_identity_operation_finished
	):
		_identity_backups.operation_finished.connect(
			_on_identity_operation_finished
		)
	_interface_fonts.apply_utility_theme(_data_page)
	_refresh_data_page()


func open_panel(
	settings_manager: SettingsManagerType,
	presentation_mode: PresentationMode = PresentationMode.GAMEPLAY_MODAL,
	animate_gameplay_host_transitions: bool = false,
) -> void:
	_cancel_panel_transition()
	_release_owned_focus()
	_presentation_mode = presentation_mode
	_animate_gameplay_host_transitions = animate_gameplay_host_transitions
	_settings_manager = settings_manager
	_load_controls()
	_feedback.text = ""
	_refresh_data_page()
	_select_page(PAGE_DISPLAY, false)
	show()
	panel_visibility_changed.emit(true)
	_main_panel.modulate.a = 1.0
	_main_panel.scale = Vector2.ONE
	call_deferred("_focus_active_tab")
	if (
		presentation_mode == PresentationMode.TITLE_EMBEDDED
		or _animate_gameplay_host_transitions
	):
		_animate_panel_open()
	else:
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
		_animate_panel_close(false)
		return
	_finish_panel_close(false)


func _animate_panel_open() -> void:
	_transition_generation += 1
	_transition_active = true
	var generation: int = _transition_generation
	_main_panel.pivot_offset = _main_panel.size * 0.5
	_main_panel.scale = Vector2.ONE * UIMotion.UTILITY_ENTER_SCALE
	_main_panel.modulate.a = 0.0
	_panel_tween = create_tween()
	_panel_tween.set_parallel(true)
	_panel_tween.tween_property(
		_main_panel,
		"scale",
		Vector2.ONE,
		UIMotion.UTILITY_ENTER_DURATION,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_panel_tween.tween_property(
		_main_panel,
		"modulate:a",
		1.0,
		UIMotion.UTILITY_ENTER_DURATION,
	)
	_panel_tween.finished.connect(
		_finish_panel_open.bind(generation),
		CONNECT_ONE_SHOT,
	)


func _finish_panel_open(generation: int) -> void:
	if generation != _transition_generation or not visible:
		return
	_transition_active = false
	_panel_tween = null
	opened.emit()


func _animate_panel_close(applied_result: bool) -> void:
	if _transition_active:
		return
	_transition_generation += 1
	_transition_active = true
	var generation: int = _transition_generation
	navigation_transition_started.emit()
	closing.emit()
	_main_panel.pivot_offset = _main_panel.size * 0.5
	_panel_tween = create_tween()
	_panel_tween.set_parallel(true)
	_panel_tween.tween_property(
		_main_panel,
		"scale",
		Vector2.ONE * UIMotion.UTILITY_ENTER_SCALE,
		UIMotion.UTILITY_EXIT_DURATION,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_panel_tween.tween_property(
		_main_panel,
		"modulate:a",
		0.0,
		UIMotion.UTILITY_EXIT_DURATION,
	)
	_panel_tween.finished.connect(
		_finish_animated_close.bind(generation, applied_result),
		CONNECT_ONE_SHOT,
	)


func _finish_animated_close(
	generation: int,
	applied_result: bool,
) -> void:
	if generation != _transition_generation or not visible:
		return
	_finish_panel_close(applied_result)


func _finish_panel_close(applied_result: bool) -> void:
	_cancel_panel_transition()
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
	_main_panel.modulate.a = 1.0
	_main_panel.scale = Vector2.ONE
	_release_owned_focus()
	hide()
	panel_visibility_changed.emit(false)
	if applied_result:
		applied.emit()
	else:
		_load_controls()
		closed.emit()


func _cancel_panel_transition() -> void:
	_transition_generation += 1
	_transition_active = false
	if _panel_tween != null:
		_panel_tween.kill()
		_panel_tween = null


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
	for selector: OptionButton in [
		_world_pixelation,
		_ui_pixelation,
		_chat_dock,
		_chat_mode,
		_paint_dock,
	]:
		if selector.get_popup().visible:
			selector.get_popup().hide()
			selector.grab_focus()
			return
	if _transition_active:
		return
	close_panel()


func _select_page(page_id: StringName, focus_tab: bool = true) -> void:
	if not _pages.has(page_id):
		return
	var target_tab: OrganizerTab = _tabs.get(page_id)
	_active_page_id = page_id
	for candidate_id: StringName in _pages:
		_pages[candidate_id].visible = candidate_id == page_id
		_tabs[candidate_id].set_selected(
			candidate_id == page_id,
			is_inside_tree(),
		)
	if page_id == PAGE_DATA:
		_refresh_data_page()
	if focus_tab and target_tab != null:
		target_tab.grab_focus()


func _focus_active_tab() -> void:
	var tab: OrganizerTab = _tabs.get(_active_page_id)
	if tab != null:
		tab.grab_focus()


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
	return _active_page_id if visible else StringName()


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


func _refresh_data_page() -> void:
	if not is_node_ready() or _data_root == null:
		return
	%DataFolderPath.text = _data_root.root_path
	%DataStorageMode.text = "storage mode: " + _data_root.storage_mode_text()
	%ChangeDataFolder.disabled = (
		_data_root.override_active
		or (_network_session != null and _network_session.is_session_active())
	)
	%ExportProgression.disabled = _progression_saves == null
	%ImportProgression.disabled = (
		_progression_saves == null
		or (_network_session != null and _network_session.is_session_active())
	)
	var fingerprint: String = (
		_player_identity.fingerprint if _player_identity != null else ""
	)
	%CopyPlayerFingerprint.disabled = not NetworkIdentityCrypto.valid_fingerprint(
		fingerprint
	)
	%CopyPlayerFingerprint.text = (
		"copy player fingerprint · %s"
		% NetworkIdentityCrypto.compact_suffix(fingerprint)
	)


func _open_data_folder() -> void:
	if (
		not is_visible_in_tree()
		or _active_page_id != PAGE_DATA
		or not _data_page.is_visible_in_tree()
		or not %OpenDataFolder.is_visible_in_tree()
		or get_viewport().gui_get_focus_owner() != %OpenDataFolder
	):
		return
	if _data_root == null:
		_feedback.text = "the data folder is unavailable."
		return
	if (
		_data_root.root_path.is_empty()
		or OS.shell_open(_data_root.root_path) != OK
	):
		_feedback.text = "could not open the data folder."


func _release_owned_focus() -> void:
	if not is_inside_tree():
		return
	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	if focus_owner != null and is_ancestor_of(focus_owner):
		focus_owner.release_focus()


func _copy_player_fingerprint() -> void:
	var fingerprint: String = (
		_player_identity.fingerprint if _player_identity != null else ""
	)
	if not NetworkIdentityCrypto.valid_fingerprint(fingerprint):
		_feedback.text = "player identity is unavailable."
		return
	DisplayServer.clipboard_set(fingerprint)
	_feedback.text = "full player fingerprint copied for server operator setup."


func _choose_progression_export() -> void:
	if _progression_saves == null or _data_root == null:
		_feedback.text = "progression export is unavailable."
		return
	var timestamp: String = Time.get_datetime_string_from_system().replace(
		":", "-"
	)
	var suggested: String = _data_root.progression_backup_directory().path_join(
		"NETfishing-progression-%s%s"
		% [timestamp, PlayerSaveManager.ARCHIVE_EXTENSION]
	)
	if _progression_export_dialog == null:
		_progression_export_dialog = FileDialog.new()
		_progression_export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		_progression_export_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_progression_export_dialog.use_native_dialog = false
		_progression_export_dialog.filters = PackedStringArray([
			"*.nfsave ; NETfishing progression archive",
		])
		_progression_export_dialog.file_selected.connect(
			_progression_export_file_selected
		)
		_interface_fonts.apply_utility_theme(_progression_export_dialog)
		add_child(_progression_export_dialog)
	_progression_export_dialog.current_dir = suggested.get_base_dir()
	_progression_export_dialog.current_file = suggested.get_file()
	_interface_fonts.popup_file_dialog(_progression_export_dialog)


func _progression_export_file_selected(path: String) -> void:
	var destination: String = (
		path
		if path.ends_with(PlayerSaveManager.ARCHIVE_EXTENSION)
		else path + PlayerSaveManager.ARCHIVE_EXTENSION
	)
	var result: Dictionary = _progression_saves.export_progression_archive(
		destination
	)
	_feedback.text = str(
		result.get("message", "progression export failed.")
	)


func _choose_progression_import() -> void:
	if _progression_saves == null or _data_root == null:
		_feedback.text = "progression import is unavailable."
		return
	if _network_session != null and _network_session.is_session_active():
		_feedback.text = "return to title before importing progression."
		return
	if _progression_import_dialog == null:
		_progression_import_dialog = FileDialog.new()
		_progression_import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_progression_import_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_progression_import_dialog.use_native_dialog = false
		_progression_import_dialog.filters = PackedStringArray([
			"*.nfsave ; NETfishing progression archive",
		])
		_progression_import_dialog.file_selected.connect(
			_progression_import_file_selected
		)
		_interface_fonts.apply_utility_theme(_progression_import_dialog)
		add_child(_progression_import_dialog)
	_progression_import_dialog.current_dir = (
		_data_root.progression_backup_directory()
	)
	_interface_fonts.popup_file_dialog(_progression_import_dialog)


func _progression_import_file_selected(path: String) -> void:
	var inspected: Dictionary = (
		_progression_saves.inspect_progression_archive(path)
	)
	if not bool(inspected.get("ok", false)):
		_feedback.text = str(
			inspected.get("message", "progression archive could not be opened.")
		)
		return
	_pending_progression_path = path
	var dialog := ConfirmationDialog.new()
	dialog.title = "replace saved progression?"
	dialog.ok_button_text = "import progression"
	dialog.dialog_text = (
		"this will replace the current progression after making a backup.\n\n"
		+ "fish: %d\ndiscovered: %d\nworld: %s\nworld seed: %d\n\n"
		+ "identities, settings, friends, bans, and trusted servers are unchanged."
	) % [
		int(inspected.get("catch_count", 0)),
		int(inspected.get("discovered_species_count", 0)),
		WorldLayout.display_name(inspected.get(
			"world_layout",
			String(WorldLayout.GENERATED),
		)),
		int(inspected.get("world_seed", 0)),
	]
	dialog.confirmed.connect(_confirm_progression_import.bind(dialog))
	dialog.canceled.connect(dialog.queue_free)
	_interface_fonts.apply_utility_theme(dialog)
	add_child(dialog)
	dialog.popup_centered(Vector2i(640, 390))
	_configure_confirmation_dialog.call_deferred(
		dialog, dialog.get_cancel_button()
	)


func _confirm_progression_import(dialog: ConfirmationDialog) -> void:
	var result: Dictionary = _progression_saves.import_progression_archive(
		_pending_progression_path
	)
	_feedback.text = str(
		result.get("message", "progression import failed.")
	)
	_pending_progression_path = ""
	dialog.queue_free()


func _choose_data_folder() -> void:
	if _data_root == null or _data_root.override_active:
		_feedback.text = "the data folder is externally managed."
		return
	if _network_session != null and _network_session.is_session_active():
		_feedback.text = "return to title to change the data folder."
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
		_feedback.text = "data folder changed. NETfishing will close safely."
		_refresh_data_page()
		get_tree().call_deferred("quit")
	else:
		_feedback.text = str(
			result.get("message", "could not change the data folder.")
		)


func _show_existing_data_folder_choice(path: String) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "existing NETfishing data"
	dialog.ok_button_text = "use selected data"
	dialog.dialog_text = (
		"the selected folder contains different NETfishing data.\n\n"
		+ "choose one complete data set. data will not be merged."
	)
	dialog.add_button("replace selected data", false, "replace")
	dialog.confirmed.connect(func() -> void:
		if _data_root.use_existing_root(path):
			_feedback.text = "data folder changed. NETfishing will close safely."
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
		_feedback.text = str(
			result.get("message", "could not replace selected data.")
		)
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
		_export_file_dialog.filters = PackedStringArray([
			"*.nfidentity ; NETfishing identity backup",
		])
		_export_file_dialog.file_selected.connect(
			_identity_export_file_selected
		)
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
		_backup_file_dialog.filters = PackedStringArray([
			"*.nfidentity ; NETfishing identity backup",
		])
		_backup_file_dialog.file_selected.connect(
			_identity_import_file_selected
		)
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
		_passphrase_dialog.title = "encrypted identity backup"
		_passphrase_dialog.confirmed.connect(_submit_identity_passphrase)
		var fields := VBoxContainer.new()
		var warning := Label.new()
		warning.text = (
			"anyone with this backup and passphrase can use your identity."
		)
		warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		fields.add_child(warning)
		_passphrase_entry = LineEdit.new()
		_passphrase_entry.placeholder_text = "passphrase (12 characters minimum)"
		_passphrase_entry.secret = true
		fields.add_child(_passphrase_entry)
		_passphrase_confirm = LineEdit.new()
		_passphrase_confirm.placeholder_text = "confirm passphrase"
		_passphrase_confirm.secret = true
		fields.add_child(_passphrase_confirm)
		_passphrase_dialog.add_child(fields)
		_interface_fonts.apply_utility_theme(_passphrase_dialog)
		add_child(_passphrase_dialog)
	_passphrase_confirm.visible = exporting
	_passphrase_entry.clear()
	_passphrase_confirm.clear()
	_passphrase_dialog.dialog_text = (
		"create a passphrase-encrypted backup."
		if exporting else "enter the backup passphrase."
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
	var dialog := ConfirmationDialog.new()
	dialog.title = "replace active identity?"
	dialog.ok_button_text = "review replacement"
	dialog.dialog_text = (
		"current:\n%s\n\nincoming:\n%s\n\n"
		+ "other players will recognize this device as the imported identity."
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
		dialog.ok_button_text = "replace identity"
		dialog.dialog_text = (
			"replace the active identity and archive the current key locally?"
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
		_feedback.text = "identity backup is unavailable."
		return false
	if _network_session != null and _network_session.is_session_active():
		_feedback.text = "return to title to change an identity."
		return false
	return true


func _on_identity_operation_finished(_success: bool, message: String) -> void:
	_feedback.text = message


func _apply_settings() -> void:
	if _transition_active:
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
	edited.chat_dock_right = _chat_dock_right
	edited.chat_mobile_mode = _chat_mobile_mode
	edited.paint_dock_right = _paint_dock_right
	if _presentation_layout_edited:
		edited.presentation_layout_customized = true
	edited.fullscreen_enabled = _fullscreen_enabled
	edited.master_volume = _master_volume
	edited.music_volume = _music_volume
	edited.effects_volume = _effects_volume
	edited.environment_volume = _environment_volume
	if _settings_manager.apply_settings(edited):
		if (
			_presentation_mode == PresentationMode.TITLE_EMBEDDED
			or _animate_gameplay_host_transitions
		):
			_animate_panel_close(true)
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
	_chat_dock_right = settings.chat_dock_right
	_chat_mobile_mode = settings.chat_mobile_mode
	_paint_dock_right = settings.paint_dock_right
	_fullscreen_enabled = settings.fullscreen_enabled
	_master_volume = settings.master_volume
	_music_volume = settings.music_volume
	_effects_volume = settings.effects_volume
	_environment_volume = settings.environment_volume
	_world_pixelation.select(settings.world_pixel_size - 1)
	_ui_pixelation.select(settings.ui_pixel_size - 1)
	_chat_dock.select(1 if _chat_dock_right else 0)
	_chat_mode.select(1 if _chat_mobile_mode else 0)
	_paint_dock.select(1 if _paint_dock_right else 0)
	_fullscreen_toggle.set_pressed_no_signal(_fullscreen_enabled)
	_master_volume_slider.set_value_no_signal(_master_volume * 100.0)
	_music_volume_slider.set_value_no_signal(_music_volume * 100.0)
	_effects_volume_slider.set_value_no_signal(_effects_volume * 100.0)
	_environment_volume_slider.set_value_no_signal(
		_environment_volume * 100.0
	)
	_mouse_sensitivity_slider.set_value_no_signal(_mouse_sensitivity)
	_controller_sensitivity_slider.set_value_no_signal(
		_controller_sensitivity
	)
	_invert_y_toggle.set_pressed_no_signal(_invert_camera_y)
	_on_screen_keyboard_toggle.set_pressed_no_signal(
		_on_screen_keyboard_enabled
	)
	_auto_click_toggle.set_pressed_no_signal(_auto_click_enabled)
	_auto_click_interval_slider.set_value_no_signal(
		_auto_click_interval_value
	)
	_presentation_layout_edited = false
	_settings_manager.restore_audio_levels()
	_refresh_value_labels()


func _refresh_value_labels() -> void:
	_fullscreen_toggle.text = (
		"on" if _fullscreen_toggle.button_pressed else "off"
	)
	_invert_y_toggle.text = "on" if _invert_camera_y else "off"
	_on_screen_keyboard_toggle.text = (
		"on" if _on_screen_keyboard_enabled else "off"
	)
	_auto_click_toggle.text = "on" if _auto_click_enabled else "off"
	_mouse_sensitivity_value.text = "%.4f" % _mouse_sensitivity
	_controller_sensitivity_value.text = "%.1f" % _controller_sensitivity
	_auto_click_interval_value_label.text = (
		"%.2f s" % _auto_click_interval_value
	)
	_refresh_audio_value_labels()


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


func _on_world_pixelation_selected(index: int) -> void:
	_set_world_pixelation(_world_pixelation.get_item_id(index))


func _on_ui_pixelation_selected(index: int) -> void:
	_set_ui_pixelation(_ui_pixelation.get_item_id(index))


func _set_world_pixelation(pixel_size: int) -> void:
	if _settings_manager == null:
		return
	if not _settings_manager.apply_pixelation(
		pixel_size,
		_settings_manager.current_settings.ui_pixel_size,
	):
		_feedback.text = "failed to save pixelation settings."


func _set_ui_pixelation(pixel_size: int) -> void:
	if _settings_manager == null:
		return
	if not _settings_manager.apply_pixelation(
		_settings_manager.current_settings.world_pixel_size,
		pixel_size,
	):
		_feedback.text = "failed to save pixelation settings."


func _on_chat_dock_selected(index: int) -> void:
	_chat_dock_right = _chat_dock.get_item_id(index) == 1
	_presentation_layout_edited = true


func _on_chat_mode_selected(index: int) -> void:
	_chat_mobile_mode = _chat_mode.get_item_id(index) == 1
	_presentation_layout_edited = true


func _on_paint_dock_selected(index: int) -> void:
	_paint_dock_right = _paint_dock.get_item_id(index) == 1
	_presentation_layout_edited = true


func _set_fullscreen(enabled: bool) -> void:
	_fullscreen_enabled = enabled
	_refresh_value_labels()


func _on_mouse_sensitivity_changed(value: float) -> void:
	_mouse_sensitivity = clampf(
		value,
		PlayerSettings.MIN_MOUSE_SENSITIVITY,
		PlayerSettings.MAX_MOUSE_SENSITIVITY,
	)
	_refresh_value_labels()


func _on_controller_sensitivity_changed(value: float) -> void:
	_controller_sensitivity = clampf(
		value,
		PlayerSettings.MIN_CONTROLLER_SENSITIVITY,
		PlayerSettings.MAX_CONTROLLER_SENSITIVITY,
	)
	_refresh_value_labels()


func _set_invert_y(enabled: bool) -> void:
	_invert_camera_y = enabled
	_refresh_value_labels()


func _set_on_screen_keyboard(enabled: bool) -> void:
	_on_screen_keyboard_enabled = enabled
	_refresh_value_labels()


func _set_auto_click(enabled: bool) -> void:
	_auto_click_enabled = enabled
	_refresh_value_labels()


func _on_auto_click_interval_changed(value: float) -> void:
	_auto_click_interval_value = clampf(
		value,
		PlayerSettings.MIN_AUTO_CLICK_INTERVAL,
		PlayerSettings.MAX_AUTO_CLICK_INTERVAL,
	)
	_refresh_value_labels()


func set_effective_ui_pixel_size(pixel_size: int) -> void:
	_effective_ui_pixel_size = clampi(
		pixel_size,
		PlayerSettings.MIN_UI_PIXEL_SIZE,
		PlayerSettings.MAX_UI_PIXEL_SIZE,
	)


func focus_back_button() -> void:
	_back_button.grab_focus()


func refresh_open_panel() -> void:
	if visible:
		_load_controls()


func _refresh_panel_size() -> void:
	if not is_node_ready():
		return
	custom_minimum_size = PANEL_SIZE
	var parent_control := get_parent() as Control
	if parent_control == null or parent_control is CenterContainer:
		return
	var available_size: Vector2 = parent_control.size - Vector2.ONE * (
		PANEL_EDGE_MARGIN * 2.0
	)
	var scale_factor: float = minf(
		1.0,
		minf(
			available_size.x / PANEL_SIZE.x,
			available_size.y / PANEL_SIZE.y,
		),
	)
	var target_size: Vector2 = PANEL_SIZE * maxf(scale_factor, 0.1)
	set_anchors_preset(Control.PRESET_CENTER)
	position = (parent_control.size - target_size) * 0.5
	size = target_size
