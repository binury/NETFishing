class_name TheNetPage
extends Control

const CurrencyPresentationType = preload(
	"res://ui/currency_presentation.gd"
)

enum View {
	DAILY,
	LIFETIME,
	PAYMENTS,
}

enum ControllerZone {
	TABS,
	CLAIMS,
}

var _jobs: PlayerJobService
var _world_time: WorldTimeService
var _header: Label
var _refresh_label: Label
var _forecast_list: HBoxContainer
var _tabs: HBoxContainer
var _list: VBoxContainer
var _jobs_scroll: ScrollContainer
var _status: Label
var _current_view: View = View.DAILY
var _forecast_start_index: int = -1
var _active: bool = false
var _interactive: bool = false
var _controller_zone: ControllerZone = ControllerZone.TABS
var _claim_buttons: Array[Button] = []
var _controller_mapping_manager: ControllerMappingManager


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UtilityPageStyle.apply_page(self)
	_build_laptop()
	set_process(false)


func setup(jobs: PlayerJobService, world_time: WorldTimeService) -> void:
	_jobs = jobs
	_world_time = world_time
	_jobs.changed.connect(_refresh)
	_jobs.status_changed.connect(_on_status_changed)
	_refresh()


func setup_controller_mapping(mapping_manager: ControllerMappingManager) -> void:
	_controller_mapping_manager = mapping_manager


func activate() -> void:
	_active = true
	set_process(true)
	_refresh()
	focus_initial()


func deactivate() -> void:
	_active = false
	set_process(false)
	set_interactive(false)
	_status.text = ""


func set_interactive(interactive: bool) -> void:
	_interactive = interactive
	mouse_filter = (
		Control.MOUSE_FILTER_PASS
		if interactive
		else Control.MOUSE_FILTER_IGNORE
	)
	if _tabs != null:
		for child: Node in _tabs.get_children():
			var button := child as Button
			if button != null:
				button.focus_mode = (
					Control.FOCUS_ALL
					if interactive
					and _controller_zone == ControllerZone.TABS
					else Control.FOCUS_NONE
				)
				button.mouse_filter = (
					Control.MOUSE_FILTER_STOP
					if interactive
					else Control.MOUSE_FILTER_IGNORE
				)
	for claim_button: Button in _claim_buttons:
		if not is_instance_valid(claim_button):
			continue
		claim_button.disabled = not interactive
		claim_button.focus_mode = (
			Control.FOCUS_ALL
			if interactive
			and _controller_zone == ControllerZone.CLAIMS
			and not claim_button.disabled
			else Control.FOCUS_NONE
		)
		claim_button.mouse_filter = (
			Control.MOUSE_FILTER_STOP
			if interactive else Control.MOUSE_FILTER_IGNORE
		)


func focus_initial() -> void:
	if not _interactive:
		return
	if _controller_zone == ControllerZone.CLAIMS:
		if not _claim_buttons.is_empty():
			_claim_buttons.front().grab_focus()
		return
	if _tabs != null and _tabs.get_child_count() > 0:
		var button := _tabs.get_child(int(_current_view)) as Button
		if button != null:
			button.grab_focus()


func reset_controller_zone() -> void:
	_controller_zone = ControllerZone.TABS
	set_interactive(_interactive)
	call_deferred("focus_initial")


func handle_controller_input(event: InputEvent) -> bool:
	if not _active or not _interactive:
		return false
	if _handle_controller_scroll(event):
		return true
	if event.is_action_pressed("ui_cancel"):
		if _controller_zone == ControllerZone.CLAIMS:
			_controller_zone = ControllerZone.TABS
			set_interactive(_interactive)
			call_deferred("focus_initial")
			return true
		return false
	if _controller_zone == ControllerZone.TABS:
		var direction: int = 0
		if event.is_action_pressed("ui_left"):
			direction = -1
		elif event.is_action_pressed("ui_right"):
			direction = 1
		if direction != 0:
			var target_index: int = clampi(
				int(_current_view) + direction,
				0,
				View.size() - 1,
			)
			if target_index != int(_current_view):
				_select_view(target_index as View)
			return true
		if event.is_action_pressed("ui_accept"):
			if not _claim_buttons.is_empty():
				_controller_zone = ControllerZone.CLAIMS
				set_interactive(_interactive)
				call_deferred("focus_initial")
			return true
	return false


func _handle_controller_scroll(event: InputEvent) -> bool:
	var motion := event as InputEventJoypadMotion
	if motion == null or _jobs_scroll == null:
		return false
	var uses_right_y: bool = (
		_controller_mapping_manager.event_uses_role(
			event,
			ControllerMappingManager.ROLE_RIGHT_STICK_Y,
		)
		if _controller_mapping_manager != null
		else motion.axis == JOY_AXIS_RIGHT_Y
	)
	if not uses_right_y:
		return false
	return true


func _process(delta: float) -> void:
	if _active and _jobs != null:
		_refresh_label.text = _daily_refresh_text()
		_refresh_forecast(false)
		var right_y: float = (
			_controller_mapping_manager.get_role_axis(
				ControllerMappingManager.ROLE_RIGHT_STICK_Y
			)
			if _controller_mapping_manager != null
			else Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
		)
		if _jobs_scroll != null and absf(right_y) >= 0.18:
			_jobs_scroll.scroll_vertical += roundi(right_y * 320.0 * delta)


func _build_laptop() -> void:
	var margin: MarginContainer = UtilityPageStyle.build_laptop_screen(self)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 9)
	margin.add_child(layout)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 16)
	layout.add_child(title_row)
	var header_left := VBoxContainer.new()
	header_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_left.add_theme_constant_override("separation", 0)
	title_row.add_child(header_left)
	_header = Label.new()
	_header.text = "fishnet"
	_header.add_theme_font_size_override("font_size", 32)
	_header.add_theme_color_override(
		"font_color", UtilityPageStyle.OCEAN_TEXT_PRIMARY
	)
	header_left.add_child(_header)
	var header_spacer := Control.new()
	header_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	header_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_left.add_child(header_spacer)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 8)
	header_left.add_child(_tabs)
	for view_index: int in 3:
		var tab := Button.new()
		tab.text = ["daily jobs", "lifetime jobs", "payments"][view_index]
		tab.toggle_mode = true
		tab.pressed.connect(_select_view.bind(view_index as View))
		UtilityPageStyle.apply_ocean_button(tab)
		_tabs.add_child(tab)
	var refresh_alignment_spacer := Control.new()
	refresh_alignment_spacer.custom_minimum_size.y = 20.0
	refresh_alignment_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_left.add_child(refresh_alignment_spacer)
	var forecast_column := VBoxContainer.new()
	forecast_column.custom_minimum_size.x = 292.0
	forecast_column.size_flags_horizontal = Control.SIZE_SHRINK_END
	forecast_column.add_theme_constant_override("separation", 3)
	title_row.add_child(forecast_column)
	var forecast_panel := PanelContainer.new()
	forecast_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	forecast_panel.add_theme_stylebox_override(
		"panel", UtilityPageStyle.row_style(false)
	)
	forecast_column.add_child(forecast_panel)
	var forecast_margin := MarginContainer.new()
	forecast_margin.add_theme_constant_override("margin_left", 10)
	forecast_margin.add_theme_constant_override("margin_top", 8)
	forecast_margin.add_theme_constant_override("margin_right", 10)
	forecast_margin.add_theme_constant_override("margin_bottom", 8)
	forecast_panel.add_child(forecast_margin)
	var forecast_stack := VBoxContainer.new()
	forecast_stack.add_theme_constant_override("separation", 7)
	forecast_margin.add_child(forecast_stack)
	var forecast_heading := Label.new()
	forecast_heading.text = "weather forecast"
	forecast_heading.add_theme_font_size_override("font_size", 20)
	forecast_heading.add_theme_color_override(
		"font_color", UtilityPageStyle.OCEAN_TEXT_PRIMARY
	)
	forecast_stack.add_child(forecast_heading)
	_forecast_list = HBoxContainer.new()
	_forecast_list.custom_minimum_size = Vector2(272.0, 66.0)
	_forecast_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_forecast_list.alignment = BoxContainer.ALIGNMENT_CENTER
	_forecast_list.add_theme_constant_override("separation", 6)
	forecast_stack.add_child(_forecast_list)
	_refresh_label = Label.new()
	_refresh_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_refresh_label.add_theme_font_size_override("font_size", 14)
	_refresh_label.add_theme_color_override(
		"font_color", UtilityPageStyle.OCEAN_TEXT_SECONDARY
	)
	forecast_column.add_child(_refresh_label)

	var jobs_column := VBoxContainer.new()
	jobs_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	jobs_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	jobs_column.add_theme_constant_override("separation", 8)
	layout.add_child(jobs_column)

	_jobs_scroll = ScrollContainer.new()
	_jobs_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_jobs_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_jobs_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	jobs_column.add_child(_jobs_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 7)
	_jobs_scroll.add_child(_list)

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 16)
	_status.add_theme_color_override(
		"font_color", UtilityPageStyle.OCEAN_TEXT_SECONDARY
	)
	jobs_column.add_child(_status)

func _select_view(view: View) -> void:
	_current_view = view
	_refresh()
	focus_initial()


func _refresh() -> void:
	if _jobs == null or _list == null:
		return
	_refresh_label.text = _daily_refresh_text()
	_refresh_forecast(true)
	for index: int in _tabs.get_child_count():
		var tab := _tabs.get_child(index) as Button
		if tab != null:
			tab.button_pressed = index == int(_current_view)
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_claim_buttons.clear()
	match _current_view:
		View.DAILY:
			_build_job_rows(_jobs.get_daily_jobs(), "no daily jobs available")
		View.LIFETIME:
			_build_job_rows(
				_jobs.get_lifetime_jobs(), "all lifetime jobs complete"
			)
		View.PAYMENTS:
			_build_payment_rows()
	if _controller_zone == ControllerZone.CLAIMS and _claim_buttons.is_empty():
		_controller_zone = ControllerZone.TABS
	set_interactive(_interactive)
	ControllerFocusNavigation.configure_spatial_neighbors(_claim_buttons)


func _build_job_rows(jobs: Array[Dictionary], empty_text: String) -> void:
	if jobs.is_empty():
		_add_empty(empty_text)
		return
	for job: Dictionary in jobs:
		var row := PanelContainer.new()
		row.add_theme_stylebox_override(
			"panel", UtilityPageStyle.row_style(false)
		)
		var content := HBoxContainer.new()
		content.add_theme_constant_override("separation", 14)
		row.add_child(content)

		var text_column := VBoxContainer.new()
		text_column.custom_minimum_size.x = 245.0
		text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.add_child(text_column)
		var title := Label.new()
		title.text = str(job.get("title", "job"))
		title.add_theme_font_size_override("font_size", 20)
		title.add_theme_color_override(
			"font_color", UtilityPageStyle.OCEAN_TEXT_PRIMARY
		)
		text_column.add_child(title)
		var description := Label.new()
		description.text = str(job.get("description", ""))
		description.add_theme_font_size_override("font_size", 16)
		description.add_theme_color_override(
			"font_color", UtilityPageStyle.OCEAN_TEXT_SECONDARY
		)
		text_column.add_child(description)

		var target: int = int(job.get("target", 1))
		var progress: int = int(job.get("progress", 0))
		var progress_bar := ProgressBar.new()
		progress_bar.custom_minimum_size = Vector2(100.0, 24.0)
		progress_bar.max_value = float(target)
		progress_bar.value = float(progress)
		progress_bar.show_percentage = false
		progress_bar.add_theme_stylebox_override(
			"background", UtilityPageStyle.rounded_style(
				UtilityPageStyle.OCEAN_PANEL_DEEP, 9
			)
		)
		progress_bar.add_theme_stylebox_override(
			"fill", UtilityPageStyle.rounded_style(
				UtilityPageStyle.OCEAN_SELECTED, 9
			)
		)
		content.add_child(progress_bar)

		var count := Label.new()
		count.custom_minimum_size.x = 54.0
		count.text = "%d / %d" % [progress, target]
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		count.add_theme_color_override(
			"font_color", UtilityPageStyle.OCEAN_TEXT_PRIMARY
		)
		content.add_child(count)

		var reward := _make_reward_display(
			int(job.get("fish_coin", 0)),
			int(job.get("experience", 0)),
		)
		reward.custom_minimum_size.x = 128.0
		content.add_child(reward)

		var claim := Button.new()
		claim.custom_minimum_size = Vector2(76.0, 36.0)
		var claimable: bool = bool(job.get("claimable", false))
		claim.text = "claim" if claimable else (
			"done" if int(job.get("completed_count", 0)) > 0 else "working"
		)
		claim.disabled = not claimable or not _interactive
		claim.focus_mode = (
			Control.FOCUS_ALL if not claim.disabled else Control.FOCUS_NONE
		)
		claim.mouse_filter = (
			Control.MOUSE_FILTER_STOP
			if not claim.disabled
			else Control.MOUSE_FILTER_IGNORE
		)
		var claim_id: String = str(
			job.get("claim_id", job.get("id", ""))
		)
		claim.pressed.connect(_claim.bind(claim_id))
		UtilityPageStyle.apply_compact_ocean_button(claim)
		if claimable:
			_claim_buttons.append(claim)
		content.add_child(claim)
		_list.add_child(row)


func _build_payment_rows() -> void:
	var rewards: Array[Dictionary] = _jobs.get_pending_rewards()
	if rewards.is_empty():
		_add_empty("no completed payments waiting")
		return
	for reward: Dictionary in rewards:
		var row := PanelContainer.new()
		row.add_theme_stylebox_override(
			"panel", UtilityPageStyle.row_style(false)
		)
		var content := HBoxContainer.new()
		content.add_theme_constant_override("separation", 14)
		row.add_child(content)
		var reward_details := VBoxContainer.new()
		reward_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var label := Label.new()
		label.text = str(reward.get("title", "completed job"))
		label.add_theme_color_override(
			"font_color", UtilityPageStyle.OCEAN_TEXT_PRIMARY
		)
		reward_details.add_child(label)
		reward_details.add_child(_make_reward_display(
			int(reward.get("fish_coin", 0)),
			int(reward.get("experience", 0)),
		))
		content.add_child(reward_details)
		var claim := Button.new()
		claim.text = "claim"
		claim.custom_minimum_size = Vector2(110.0, 42.0)
		claim.disabled = not _interactive
		claim.focus_mode = (
			Control.FOCUS_ALL if _interactive else Control.FOCUS_NONE
		)
		claim.mouse_filter = (
			Control.MOUSE_FILTER_STOP
			if _interactive
			else Control.MOUSE_FILTER_IGNORE
		)
		claim.pressed.connect(
			_claim.bind(str(reward.get("claim_id", "")))
		)
		UtilityPageStyle.apply_ocean_button(claim)
		_claim_buttons.append(claim)
		content.add_child(claim)
		_list.add_child(row)


func _claim(claim_id: String) -> void:
	if not _jobs.claim(claim_id):
		_status.text = "payment could not be completed"
	_refresh()


func _make_reward_display(fish_coin: int, experience: int) -> HBoxContainer:
	var reward := HBoxContainer.new()
	reward.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward.add_theme_constant_override("separation", 7)
	var currency: CurrencyAmount = (
		CurrencyPresentationType.instantiate_amount(fish_coin, 18.0)
	)
	currency.get_amount_label().add_theme_color_override(
		"font_color", UtilityPageStyle.OCEAN_TEXT_SECONDARY
	)
	reward.add_child(currency)
	var experience_label := Label.new()
	experience_label.text = "•  %d xp" % experience
	experience_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	experience_label.add_theme_color_override(
		"font_color", UtilityPageStyle.OCEAN_TEXT_SECONDARY
	)
	reward.add_child(experience_label)
	return reward


func _add_empty(message: String) -> void:
	var empty := Label.new()
	empty.text = message
	empty.custom_minimum_size = Vector2(0.0, 92.0)
	empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty.add_theme_font_size_override("font_size", 20)
	empty.add_theme_color_override(
		"font_color", UtilityPageStyle.OCEAN_TEXT_SECONDARY
	)
	_list.add_child(empty)


func _refresh_forecast(force: bool) -> void:
	if _forecast_list == null:
		return
	var current_index: int = _current_forecast_index()
	if not force and current_index == _forecast_start_index:
		return
	_forecast_start_index = current_index
	for child: Node in _forecast_list.get_children():
		_forecast_list.remove_child(child)
		child.queue_free()
	if _jobs == null or _world_time == null:
		_add_forecast_empty("forecast unavailable")
		return
	var forecast: Array[Dictionary] = _jobs.get_forecast()
	if forecast.is_empty():
		_add_forecast_empty("forecast unavailable")
		return
	current_index = clampi(current_index, 0, forecast.size() - 1)
	var visible_count: int = mini(4, forecast.size())
	for offset: int in visible_count:
		var index: int = (current_index + offset) % forecast.size()
		var entry: Dictionary = forecast[index]
		var start_hour: float = float(entry.get("start_hour", 0.0))
		var weather: WorldWeatherService.Weather = (
			int(entry.get("weather", 0)) as WorldWeatherService.Weather
		)
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(63.0, 66.0)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_forecast_list.add_child(slot)
		var icon := WeatherIcon.new()
		icon.position = Vector2(10.5, 17.0)
		icon.size = Vector2(42.0, 42.0)
		icon.custom_minimum_size = Vector2(42.0, 42.0)
		icon.set_weather(weather)
		icon.set_nighttime(
			WorldTimeService.phase_for_hour(start_hour)
			== WorldTimeService.Phase.NIGHT
		)
		slot.add_child(icon)
		var time_label := Label.new()
		time_label.position = Vector2(27.0, 0.0)
		time_label.size = Vector2(36.0, 22.0)
		time_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		time_label.text = _forecast_exponent_time(start_hour)
		time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		time_label.add_theme_font_size_override("font_size", 13)
		time_label.add_theme_constant_override("outline_size", 3)
		time_label.add_theme_color_override(
			"font_color", UtilityPageStyle.OCEAN_TEXT_PRIMARY
		)
		time_label.add_theme_color_override(
			"font_outline_color", UtilityPageStyle.OCEAN_PANEL_DEEP
		)
		slot.add_child(time_label)


func _current_forecast_index() -> int:
	if _world_time == null:
		return -1
	var elapsed: float = fposmod(
		_world_time.get_time_hours() - WorldTimeService.DAY_START_HOUR,
		WorldTimeService.HOURS_PER_DAY,
	)
	return floori(elapsed / JobCatalog.WEATHER_SEGMENT_HOURS)


func _compact_clock_time(time_hours: float) -> String:
	var normalized: float = fposmod(
		time_hours, WorldTimeService.HOURS_PER_DAY
	)
	var total_minutes: int = floori(normalized * 60.0)
	var hour_24: int = floori(float(total_minutes) / 60.0)
	var minute: int = total_minutes % 60
	var hour_12: int = hour_24 % 12
	if hour_12 == 0:
		hour_12 = 12
	var suffix: String = "AM" if hour_24 < 12 else "PM"
	if minute == 0:
		return "%d%s" % [hour_12, suffix]
	return "%d:%02d%s" % [hour_12, minute, suffix]


func _forecast_exponent_time(time_hours: float) -> String:
	return _compact_clock_time(time_hours).to_lower()


func _daily_refresh_text() -> String:
	if _jobs == null:
		return "daily jobs unavailable"
	var countdown: String = _jobs.get_time_until_refresh_text()
	if countdown.begins_with("refreshes in "):
		return "daily jobs refresh in %s" % countdown.trim_prefix(
			"refreshes in "
		)
	return countdown


func _add_forecast_empty(message: String) -> void:
	var label := Label.new()
	label.text = message
	label.custom_minimum_size = Vector2(252.0, 66.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.add_theme_color_override(
		"font_color", UtilityPageStyle.OCEAN_TEXT_SECONDARY
	)
	_forecast_list.add_child(label)


func _on_status_changed(message: String) -> void:
	_status.text = message
