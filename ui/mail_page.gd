class_name MailPage
extends Control

const GREETING_LABELS := {
	"dear": "Dear",
	"to": "To",
	"hey": "Hey",
	"greetings": "Greetings",
}
const SALUTATION_LABELS := {
	"love": "Love",
	"from": "From",
	"cheers": "Cheers",
	"salutations": "Salutations",
	"good_luck_have_fun": "Good Luck Have Fun",
}
const FishQualityType = preload("res://fish/fish_quality.gd")
const CurrencyPresentationType = preload(
	"res://ui/currency_presentation.gd"
)
const INBOX_ENTRY_WIDTH: float = 742.0
const ATTACHMENT_COLUMN_X: float = 516.0
const ATTACHMENT_COLUMN_WIDTH: float = 266.0
const AMOUNT_FIELD_X_WITH_CURRENCY: float = 594.0
const AMOUNT_FIELD_X_PLAIN: float = 570.0
const AMOUNT_FIELD_WIDTH_WITH_CURRENCY: float = 130.0
const AMOUNT_FIELD_WIDTH_PLAIN: float = 154.0

var _service: NetworkMailService
var _reservations: PlayerAssetReservationService
var _inventory: FishInventory
var _wallet: PlayerWallet
var _bag: PlayerBag
var _catalog: ItemCatalog

var _inbox: Control
var _compose: Control
var _letter: Control
var _inbox_list: VBoxContainer
var _empty_label: Label
var _send_mail_button: Button
var _archive_view_button: Button
var _recipient: OptionButton
var _greeting: OptionButton
var _body: TextEdit
var _salutation: OptionButton
var _signature: Label
var _attachment_kind: OptionButton
var _attachment_choice: OptionButton
var _attachment_amount: LineEdit
var _coin_available_heading: Label
var _coin_available: CurrencyAmount
var _attachment_amount_currency_icon: TextureRect
var _amount_minus: Button
var _amount_plus: Button
var _attachment_summary: RichTextLabel
var _compose_cancel: Button
var _send_button: Button
var _status: Label
var _letter_text: Label
var _letter_gift: RichTextLabel
var _letter_close: Button
var _accept: Button
var _decline: Button
var _archive: Button
var _delete: Button
var _current_mail_id := ""
var _showing_archive := false
var _active: bool = false
var _interactive: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UtilityPageStyle.apply_page(self)
	_build_ui()


func setup(
	service: NetworkMailService,
	reservations: PlayerAssetReservationService,
	inventory: FishInventory,
	wallet: PlayerWallet,
	bag: PlayerBag,
	catalog: ItemCatalog,
) -> void:
	_service = service
	_reservations = reservations
	_inventory = inventory
	_wallet = wallet
	_bag = bag
	_catalog = catalog
	_service.mailbox_changed.connect(_refresh_inbox)
	_service.peers_changed.connect(_refresh_recipients)
	_service.operation_finished.connect(_on_operation_finished)
	_refresh_inbox()
	_refresh_recipients()


func activate() -> void:
	_active = true
	_show_inbox()
	call_deferred("_refresh_controller_navigation")


func deactivate() -> void:
	_active = false
	_current_mail_id = ""
	_show_inbox()
	set_interactive(false)


func consume_escape() -> bool:
	if _compose.visible or _letter.visible:
		_show_inbox()
		return true
	return false


func is_composing_letter() -> bool:
	return _compose != null and _compose.visible


func set_interactive(value: bool) -> void:
	_interactive = value and _active
	mouse_filter = (
		Control.MOUSE_FILTER_PASS
		if _interactive else Control.MOUSE_FILTER_IGNORE
	)
	_refresh_controller_navigation()


func reset_controller_zone() -> void:
	_show_inbox()
	call_deferred("_refresh_controller_navigation")


func handle_controller_input(event: InputEvent) -> bool:
	if not _active or not _interactive:
		return false
	if event.is_action_pressed("ui_cancel"):
		return consume_escape()
	return false


func _refresh_controller_navigation() -> void:
	var active_controls: Array[Control] = _active_controller_controls()
	for control: Control in _all_controller_controls():
		var button := control as BaseButton
		control.focus_mode = (
			Control.FOCUS_ALL
			if (
				_interactive
				and control in active_controls
				and control.is_visible_in_tree()
				and (button == null or not button.disabled)
			)
			else Control.FOCUS_NONE
		)
	ControllerFocusNavigation.configure_spatial_neighbors(active_controls)
	if _compose != null and _compose.visible:
		_configure_compose_controller_navigation()
	elif _inbox != null and _inbox.visible:
		_configure_inbox_controller_navigation()
	elif _letter != null and _letter.visible:
		_configure_letter_controller_navigation()
	if not _interactive or active_controls.is_empty():
		return
	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	if focus_owner == null or not is_ancestor_of(focus_owner):
		active_controls.front().grab_focus()


func _active_controller_controls() -> Array[Control]:
	if _compose != null and _compose.visible:
		return _compose_controller_controls()
	if _letter != null and _letter.visible:
		return _letter_controller_controls()
	return _inbox_controller_controls()


func _all_controller_controls() -> Array[Control]:
	var controls: Array[Control] = _inbox_controller_controls()
	controls.append_array(_compose_controller_controls())
	controls.append_array(_letter_controller_controls())
	return controls


func _inbox_controller_controls() -> Array[Control]:
	var controls: Array[Control] = []
	_append_controller_control(controls, _archive_view_button)
	_append_controller_control(controls, _send_mail_button)
	if _inbox_list != null:
		for child: Node in _inbox_list.get_children():
			_append_controller_control(controls, child as Button)
	return controls


func _compose_controller_controls() -> Array[Control]:
	var controls: Array[Control] = []
	for control: Control in [
		_greeting,
		_recipient,
		_attachment_kind,
		_body,
		_attachment_choice,
		_salutation,
		_amount_minus,
		_attachment_amount,
		_amount_plus,
		_compose_cancel,
		_send_button,
	]:
		_append_controller_control(controls, control)
	return controls


func _letter_controller_controls() -> Array[Control]:
	var controls: Array[Control] = []
	for control: Control in [
		_accept,
		_decline,
		_letter_close,
		_archive,
		_delete,
	]:
		_append_controller_control(controls, control)
	return controls


func _append_controller_control(
	controls: Array[Control],
	control: Control,
) -> void:
	if control != null and control.is_visible_in_tree():
		controls.append(control)


func _configure_inbox_controller_navigation() -> void:
	if not _interactive:
		return
	var entries: Array[Control] = []
	for child: Node in _inbox_list.get_children():
		var button := child as Button
		if button != null and _controller_focus_eligible(button):
			entries.append(button)
	var first_entry: Control = (
		entries.front() if not entries.is_empty() else _archive_view_button
	)
	_set_compose_neighbors(
		_archive_view_button,
		_archive_view_button,
		_send_mail_button,
		_archive_view_button,
		first_entry,
	)
	_set_compose_neighbors(
		_send_mail_button,
		_archive_view_button,
		_send_mail_button,
		_send_mail_button,
		entries.front() if not entries.is_empty() else _send_mail_button,
	)
	for index: int in entries.size():
		var entry: Control = entries[index]
		_set_compose_neighbors(
			entry,
			entry,
			entry,
			entries[index - 1] if index > 0 else _archive_view_button,
			entries[index + 1] if index < entries.size() - 1 else entry,
		)
	var traversal: Array[Control] = [
		_archive_view_button,
		_send_mail_button,
	]
	traversal.append_array(entries)
	ControllerFocusNavigation.configure_traversal(traversal)


func _configure_letter_controller_navigation() -> void:
	if not _interactive:
		return
	var pending_gift: bool = (
		_accept != null
		and _accept.is_visible_in_tree()
		and _decline != null
		and _decline.is_visible_in_tree()
	)
	if pending_gift:
		_set_compose_neighbors(
			_accept, _accept, _accept, _accept, _decline
		)
		_set_compose_neighbors(
			_decline, _decline, _decline, _accept, _delete
		)
	_set_compose_neighbors(
		_letter_close,
		_letter_close,
		_archive,
		_letter_close,
		_letter_close,
	)
	_set_compose_neighbors(
		_archive,
		_letter_close,
		_delete,
		_archive,
		_archive,
	)
	_set_compose_neighbors(
		_delete,
		_archive,
		_delete,
		_decline if pending_gift else _delete,
		_delete,
	)
	var traversal: Array[Control] = [_letter_close, _archive, _delete]
	if pending_gift:
		traversal = [_accept, _decline, _letter_close, _archive, _delete]
	ControllerFocusNavigation.configure_traversal(traversal)


func _configure_compose_controller_navigation() -> void:
	if not _interactive:
		return
	var amount_visible: bool = (
		_attachment_amount != null
		and _attachment_amount.is_visible_in_tree()
	)
	var amount_left: Control = _amount_minus if amount_visible else _compose_cancel
	var amount_middle: Control = (
		_attachment_amount if amount_visible else _compose_cancel
	)
	var amount_right: Control = _amount_plus if amount_visible else _send_button
	_set_compose_neighbors(
		_greeting, _greeting, _recipient, _greeting, _body
	)
	_set_compose_neighbors(
		_recipient, _greeting, _attachment_kind, _recipient, _body
	)
	_set_compose_neighbors(
		_body, _body, _attachment_choice, _recipient, _salutation
	)
	_set_compose_neighbors(
		_salutation, _salutation, _compose_cancel, _body, _salutation
	)
	_set_compose_neighbors(
		_attachment_kind,
		_recipient,
		_attachment_kind,
		_attachment_kind,
		_attachment_choice,
	)
	_set_compose_neighbors(
		_attachment_choice,
		_body,
		_attachment_choice,
		_attachment_kind,
		amount_middle,
	)
	if amount_visible:
		_set_compose_neighbors(
			_amount_minus,
			_amount_minus,
			_attachment_amount,
			_attachment_choice,
			_compose_cancel,
		)
		_set_compose_neighbors(
			_attachment_amount,
			_amount_minus,
			_amount_plus,
			_attachment_choice,
			_compose_cancel,
		)
		_set_compose_neighbors(
			_amount_plus,
			_attachment_amount,
			_amount_plus,
			_attachment_choice,
			_send_button,
		)
	_set_compose_neighbors(
		_compose_cancel,
		_salutation,
		_send_button,
		amount_left,
		_compose_cancel,
	)
	_set_compose_neighbors(
		_send_button,
		_compose_cancel,
		_send_button,
		amount_right,
		_send_button,
	)


func _set_compose_neighbors(
	control: Control,
	left: Control,
	right: Control,
	top: Control,
	bottom: Control,
) -> void:
	if control == null or not control.is_visible_in_tree():
		return
	var safe_left: Control = left if _controller_focus_eligible(left) else control
	var safe_right: Control = right if _controller_focus_eligible(right) else control
	var safe_top: Control = top if _controller_focus_eligible(top) else control
	var safe_bottom: Control = (
		bottom if _controller_focus_eligible(bottom) else control
	)
	control.focus_neighbor_left = control.get_path_to(safe_left)
	control.focus_neighbor_right = control.get_path_to(safe_right)
	control.focus_neighbor_top = control.get_path_to(safe_top)
	control.focus_neighbor_bottom = control.get_path_to(safe_bottom)


func _controller_focus_eligible(control: Control) -> bool:
	if (
		control == null
		or not control.is_visible_in_tree()
		or control.focus_mode == Control.FOCUS_NONE
	):
		return false
	var button := control as BaseButton
	return button == null or not button.disabled


func _build_ui() -> void:
	var margin: MarginContainer = UtilityPageStyle.build_laptop_screen(self)
	var root := Control.new()
	margin.add_child(root)
	_inbox = _build_inbox()
	_compose = _build_compose()
	_letter = _build_letter()
	for page: Control in [_inbox, _compose, _letter]:
		page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root.add_child(page)
	_status = Label.new()
	_status.position = Vector2(18, 408)
	_status.size = Vector2(758, 28)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override(
		"font_color", UtilityPageStyle.OCEAN_TEXT_SECONDARY
	)
	root.add_child(_status)
	_style_controls(root)
	_show_inbox()


func _build_inbox() -> Control:
	var page := Control.new()
	var title := Label.new()
	title.text = "mail"
	title.position = Vector2(12, 0)
	title.size = Vector2(300, 42)
	title.add_theme_font_size_override("font_size", 30)
	page.add_child(title)
	_send_mail_button = Button.new()
	_send_mail_button.text = "send mail"
	_send_mail_button.position = Vector2(642, 0)
	_send_mail_button.size = Vector2(140, 48)
	_send_mail_button.pressed.connect(_show_compose)
	page.add_child(_send_mail_button)
	_archive_view_button = Button.new()
	_archive_view_button.text = "archive"
	_archive_view_button.position = Vector2(490, 0)
	_archive_view_button.size = Vector2(140, 48)
	_archive_view_button.pressed.connect(func() -> void:
		_showing_archive = not _showing_archive
		_archive_view_button.text = "inbox" if _showing_archive else "archive"
		_refresh_inbox()
	)
	page.add_child(_archive_view_button)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(12, 62)
	scroll.size = Vector2(770, 334)
	page.add_child(scroll)
	_inbox_list = VBoxContainer.new()
	_inbox_list.custom_minimum_size = Vector2(INBOX_ENTRY_WIDTH, 0)
	_inbox_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_inbox_list)
	_empty_label = Label.new()
	_empty_label.text = "No letters yet."
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.custom_minimum_size = Vector2(INBOX_ENTRY_WIDTH, 80)
	_inbox_list.add_child(_empty_label)
	return page


func _build_compose() -> Control:
	var page := Control.new()
	var title := Label.new()
	title.text = "write a letter"
	title.position = Vector2(12, 0)
	title.size = Vector2(300, 36)
	title.add_theme_font_size_override("font_size", 26)
	page.add_child(title)
	_greeting = OptionButton.new()
	_greeting.position = Vector2(12, 48)
	_greeting.size = Vector2(140, 46)
	for id: String in NetworkMailProtocol.GREETINGS:
		_greeting.add_item(GREETING_LABELS[id])
		_greeting.set_item_metadata(_greeting.item_count - 1, id)
	page.add_child(_greeting)
	_recipient = OptionButton.new()
	_recipient.position = Vector2(164, 48)
	_recipient.size = Vector2(328, 46)
	page.add_child(_recipient)
	_body = TextEdit.new()
	_body.position = Vector2(12, 106)
	_body.size = Vector2(480, 218)
	_body.placeholder_text = "write your letter…"
	_body.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_body.text_changed.connect(_update_send_state)
	page.add_child(_body)
	_salutation = OptionButton.new()
	_salutation.position = Vector2(12, 336)
	_salutation.size = Vector2(230, 46)
	_salutation.alignment = HORIZONTAL_ALIGNMENT_CENTER
	for id: String in NetworkMailProtocol.SALUTATIONS:
		_salutation.add_item(SALUTATION_LABELS[id])
		_salutation.set_item_metadata(_salutation.item_count - 1, id)
	page.add_child(_salutation)
	_signature = Label.new()
	_signature.position = Vector2(262, 336)
	_signature.size = Vector2(230, 46)
	_signature.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_signature.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	page.add_child(_signature)
	_attachment_kind = OptionButton.new()
	_attachment_kind.position = Vector2(ATTACHMENT_COLUMN_X, 48)
	_attachment_kind.size = Vector2(ATTACHMENT_COLUMN_WIDTH, 46)
	for label: String in ["No gift", "Currency", "Fish", "Item"]:
		_attachment_kind.add_item(label)
	_attachment_kind.item_selected.connect(_refresh_attachment_choices)
	page.add_child(_attachment_kind)
	_attachment_choice = OptionButton.new()
	_attachment_choice.position = Vector2(ATTACHMENT_COLUMN_X, 106)
	_attachment_choice.size = Vector2(ATTACHMENT_COLUMN_WIDTH, 46)
	_attachment_choice.item_selected.connect(
		func(_index: int) -> void:
			_update_attachment_amount_limit()
			_update_attachment_summary()
	)
	page.add_child(_attachment_choice)
	_coin_available_heading = Label.new()
	_coin_available_heading.text = "Available"
	_coin_available_heading.position = Vector2(ATTACHMENT_COLUMN_X, 158)
	_coin_available_heading.size = Vector2(80, 28)
	page.add_child(_coin_available_heading)
	_coin_available = CurrencyPresentationType.instantiate_amount(0, 18.0)
	_coin_available.position = Vector2(598, 158)
	_coin_available.size = Vector2(184, 28)
	_coin_available.alignment = BoxContainer.ALIGNMENT_BEGIN
	page.add_child(_coin_available)
	_attachment_amount_currency_icon = TextureRect.new()
	_attachment_amount_currency_icon.position = Vector2(570, 204)
	_attachment_amount_currency_icon.size = Vector2(18, 18)
	_attachment_amount_currency_icon.texture = preload(
		"res://items/icons/shop/32_currency.png"
	)
	_attachment_amount_currency_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_attachment_amount_currency_icon.stretch_mode = (
		TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	)
	_attachment_amount_currency_icon.texture_filter = (
		CanvasItem.TEXTURE_FILTER_NEAREST
	)
	_attachment_amount_currency_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(_attachment_amount_currency_icon)
	_attachment_amount = LineEdit.new()
	_attachment_amount.position = Vector2(AMOUNT_FIELD_X_WITH_CURRENCY, 190)
	_attachment_amount.size = Vector2(AMOUNT_FIELD_WIDTH_WITH_CURRENCY, 46)
	_attachment_amount.placeholder_text = "0"
	_attachment_amount.text = "0"
	_attachment_amount.text_changed.connect(_on_attachment_amount_changed)
	page.add_child(_attachment_amount)
	_amount_minus = Button.new()
	_amount_minus.text = "−"
	_amount_minus.position = Vector2(ATTACHMENT_COLUMN_X, 190)
	_amount_minus.size = Vector2(44, 46)
	_amount_minus.pressed.connect(_step_attachment_amount.bind(-1))
	page.add_child(_amount_minus)
	_amount_plus = Button.new()
	_amount_plus.text = "+"
	_amount_plus.position = Vector2(734, 190)
	_amount_plus.size = Vector2(48, 46)
	_amount_plus.pressed.connect(_step_attachment_amount.bind(1))
	page.add_child(_amount_plus)
	_attachment_summary = RichTextLabel.new()
	_attachment_summary.position = Vector2(ATTACHMENT_COLUMN_X, 246)
	_attachment_summary.size = Vector2(ATTACHMENT_COLUMN_WIDTH, 78)
	_attachment_summary.bbcode_enabled = true
	_attachment_summary.fit_content = true
	_attachment_summary.scroll_active = false
	_attachment_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(_attachment_summary)
	_compose_cancel = Button.new()
	_compose_cancel.text = "cancel"
	_compose_cancel.position = Vector2(ATTACHMENT_COLUMN_X, 342)
	_compose_cancel.size = Vector2(122, 48)
	_compose_cancel.pressed.connect(_show_inbox)
	page.add_child(_compose_cancel)
	_send_button = Button.new()
	_send_button.text = "send letter"
	_send_button.position = Vector2(646, 342)
	_send_button.size = Vector2(136, 48)
	_send_button.pressed.connect(_send)
	page.add_child(_send_button)
	_recipient.item_selected.connect(func(_i: int) -> void:
		_reset_attachment_controls()
		_update_send_state()
	)
	_refresh_attachment_choices(0)
	return page


func _build_letter() -> Control:
	var page := Control.new()
	_letter_text = Label.new()
	_letter_text.position = Vector2(26, 20)
	_letter_text.size = Vector2(500, 350)
	_letter_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_letter_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	page.add_child(_letter_text)
	_letter_gift = RichTextLabel.new()
	_letter_gift.position = Vector2(552, 46)
	_letter_gift.size = Vector2(230, 180)
	_letter_gift.bbcode_enabled = true
	_letter_gift.fit_content = true
	_letter_gift.scroll_active = false
	_letter_gift.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(_letter_gift)
	_accept = Button.new()
	_accept.text = "accept gift"
	_accept.position = Vector2(552, 250)
	_accept.size = Vector2(230, 48)
	_accept.pressed.connect(func() -> void:
		_service.accept_gift(_current_mail_id)
	)
	page.add_child(_accept)
	_decline = Button.new()
	_decline.text = "decline gift"
	_decline.position = Vector2(552, 308)
	_decline.size = Vector2(230, 48)
	_decline.pressed.connect(func() -> void:
		_service.decline_gift(_current_mail_id)
	)
	page.add_child(_decline)
	_letter_close = Button.new()
	_letter_close.text = "close"
	_letter_close.position = Vector2(26, 370)
	_letter_close.size = Vector2(150, 48)
	_letter_close.pressed.connect(_show_inbox)
	page.add_child(_letter_close)
	_archive = Button.new()
	_archive.text = "archive"
	_archive.position = Vector2(466, 370)
	_archive.size = Vector2(150, 48)
	_archive.pressed.connect(_archive_current)
	page.add_child(_archive)
	_delete = Button.new()
	_delete.text = "delete"
	_delete.position = Vector2(626, 370)
	_delete.size = Vector2(150, 48)
	_delete.pressed.connect(_delete_current)
	page.add_child(_delete)
	return page


func _show_inbox() -> void:
	_inbox.show()
	_compose.hide()
	_letter.hide()
	_current_mail_id = ""
	_refresh_inbox()
	call_deferred("_refresh_controller_navigation")


func _show_compose() -> void:
	_inbox.hide()
	_compose.show()
	_letter.hide()
	_reset_compose()
	_signature.text = _service.get_local_display_name()
	_refresh_recipients()
	_update_send_state()
	call_deferred("_refresh_controller_navigation")


func _reset_compose() -> void:
	_recipient.select(0)
	_greeting.select(0)
	_body.clear()
	_salutation.select(0)
	_status.text = ""
	_reset_attachment_controls()


func _reset_attachment_controls() -> void:
	_attachment_kind.select(0)
	_attachment_choice.clear()
	_attachment_choice.add_item("No attachment")
	_attachment_amount.text = "0"
	_refresh_attachment_choices(0)


func _open_letter(mail_id: String) -> void:
	var letter := _service.get_letter(mail_id)
	if letter.is_empty():
		return
	_current_mail_id = mail_id
	_service.mark_read(mail_id)
	_inbox.hide()
	_compose.hide()
	_letter.show()
	_letter_text.text = "%s %s,\n\n%s\n\n%s,\n%s" % [
		GREETING_LABELS.get(letter["greeting_id"], "Dear"),
		letter.get("recipient_display_name", "you"),
		letter["body"],
		SALUTATION_LABELS.get(letter["salutation_id"], "From"),
		letter["sender_display_name"],
	]
	_letter_gift.text = _attachment_state_text(letter)
	var pending := (
		int(letter["attachment"].get("type", 0)) != 0
		and int(letter["state"]) in [
			NetworkMailProtocol.State.SENT_UNREAD,
			NetworkMailProtocol.State.READ,
		]
		and _service.is_local_recipient(letter)
	)
	_accept.visible = pending
	_decline.visible = pending
	_archive.text = (
		"restore to inbox"
		if _service.is_letter_archived(mail_id)
		else "archive"
	)
	_delete.disabled = pending
	_delete.tooltip_text = (
		"Resolve this gift before deleting the letter." if pending else ""
	)
	if pending:
		_accept.call_deferred("grab_focus")
	call_deferred("_refresh_controller_navigation")


func _refresh_inbox() -> void:
	if _service == null or _inbox_list == null:
		return
	for child: Node in _inbox_list.get_children():
		child.queue_free()
	var letters := _service.get_local_letters(_showing_archive)
	if letters.is_empty():
		var empty := Label.new()
		empty.text = (
			"No archived letters." if _showing_archive else "No letters yet."
		)
		empty.custom_minimum_size = Vector2(INBOX_ENTRY_WIDTH, 80)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_inbox_list.add_child(empty)
		call_deferred("_refresh_controller_navigation")
		return
	for letter: Dictionary in letters:
		var button := Button.new()
		var first_line: String = str(letter["body"]).split("\n", false)[0]
		var unread := (
			_service.is_local_recipient(letter)
			and int(letter["state"]) == NetworkMailProtocol.State.SENT_UNREAD
		)
		var gift := int(letter["attachment"].get("type", 0)) != 0
		var local_is_sender := (
			int(letter["sender_peer_id"]) != 0
			and not _service.is_local_recipient(letter)
		)
		button.text = "%s%s%s — %s%s" % [
			"new · " if unread else "",
			"to " if local_is_sender else "",
			(
				letter["recipient_display_name"]
				if local_is_sender
				else letter["sender_display_name"]
			),
			first_line.left(72),
			"  · gift enclosed" if gift else "",
		]
		button.custom_minimum_size = Vector2(INBOX_ENTRY_WIDTH, 54)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_open_letter.bind(str(letter["mail_id"])))
		UtilityPageStyle.apply_ocean_button(button)
		_inbox_list.add_child(button)
	call_deferred("_refresh_controller_navigation")


func _refresh_recipients() -> void:
	if _service == null or _recipient == null:
		return
	var selected_peer := (
		int(_recipient.get_selected_metadata())
		if _recipient.selected >= 0
		and _recipient.get_selected_metadata() != null else 0
	)
	_recipient.clear()
	_recipient.add_item("select a player")
	_recipient.set_item_metadata(0, 0)
	var retained := false
	for choice: Dictionary in _service.get_recipient_choices():
		_recipient.add_item(choice["label"])
		_recipient.set_item_metadata(
			_recipient.item_count - 1, choice["peer_id"]
		)
		if int(choice["peer_id"]) == selected_peer:
			_recipient.select(_recipient.item_count - 1)
			retained = true
	if selected_peer > 0 and not retained:
		_recipient.select(0)
		if _status != null:
			_status.text = "That player is no longer connected."
	_update_send_state()


func _refresh_attachment_choices(_index: int) -> void:
	if _attachment_choice == null:
		return
	_attachment_choice.clear()
	var amount_visible := _attachment_kind.selected in [1, 3]
	_attachment_amount.visible = amount_visible
	_amount_minus.visible = amount_visible
	_amount_plus.visible = amount_visible
	var currency_selected: bool = _attachment_kind.selected == 1
	_coin_available_heading.visible = currency_selected
	_coin_available.visible = currency_selected
	_attachment_amount_currency_icon.visible = currency_selected
	_attachment_amount.position.x = (
		AMOUNT_FIELD_X_WITH_CURRENCY
		if currency_selected else AMOUNT_FIELD_X_PLAIN
	)
	_attachment_amount.size.x = (
		AMOUNT_FIELD_WIDTH_WITH_CURRENCY
		if currency_selected else AMOUNT_FIELD_WIDTH_PLAIN
	)
	match _attachment_kind.selected:
		0:
			_attachment_choice.add_item("No attachment")
		1:
			_attachment_choice.add_item("Currency")
			_coin_available.set_amount(
				_reservations.get_available_fish_coin()
			)
		2:
			for fish_catch: FishCatch in _inventory.get_all_catches():
				if (
					not fish_catch.is_favorited
					and not _reservations.is_fish_reserved(fish_catch.catch_id)
				):
					_attachment_choice.add_item(
						"%s — %.1f lb" % [
							FishQualityType.qualified_name(
								fish_catch.fish.display_name,
								fish_catch.quality,
							),
							fish_catch.weight_lb,
						]
					)
					_attachment_choice.set_item_metadata(
						_attachment_choice.item_count - 1, str(fish_catch.catch_id)
					)
		3:
			for item: ItemData in _catalog.get_valid_items():
				var available := _reservations.get_available_item_quantity(
					item.item_id
				)
				if item.category == ItemData.Category.CONSUMABLE and available > 0:
					_attachment_choice.add_item(
						"%s ×%d" % [item.display_name, available]
					)
					_attachment_choice.set_item_metadata(
						_attachment_choice.item_count - 1, str(item.item_id)
					)
	_update_attachment_amount_limit()
	_update_attachment_summary()
	call_deferred("_refresh_controller_navigation")


func _update_attachment_amount_limit() -> void:
	_set_attachment_amount(_attachment_amount_value())


func _make_attachment() -> Dictionary:
	match _attachment_kind.selected:
		1:
			return {
				"type": PlayerAssetReservationService.AttachmentType.FISH_COIN,
				"amount": _attachment_amount_value(),
			}
		2:
			if _attachment_choice.selected < 0:
				return {}
			var catch_id := StringName(str(_attachment_choice.get_selected_metadata()))
			var fish_catch := _inventory.get_catch_by_id(catch_id)
			if fish_catch == null:
				return {}
			return {
				"type": PlayerAssetReservationService.AttachmentType.FISH,
				"catch_id": str(catch_id),
				"catch": fish_catch.to_network_dict(),
			}
		3:
			if _attachment_choice.selected < 0:
				return {}
			return {
				"type": PlayerAssetReservationService.AttachmentType.CONSUMABLE,
				"item_id": str(_attachment_choice.get_selected_metadata()),
				"quantity": _attachment_amount_value(),
			}
	return {"type": PlayerAssetReservationService.AttachmentType.NONE}


func _update_attachment_summary() -> void:
	if _attachment_summary == null:
		return
	var attachment := _make_attachment()
	_attachment_summary.text = _attachment_text(attachment)
	_update_send_state()


func _update_send_state() -> void:
	if _send_button == null:
		return
	var recipient_id := (
		int(_recipient.get_selected_metadata())
		if _recipient.selected >= 0 and _recipient.get_selected_metadata() != null
		else 0
	)
	var attachment := _make_attachment()
	_send_button.disabled = (
		recipient_id <= 0
		or NetworkMailProtocol.sanitize_body(_body.text).is_empty()
		or attachment.is_empty()
		or not _reservations.validate_attachment(attachment)
		or not _attachment_is_available(attachment)
	)
	call_deferred("_refresh_controller_navigation")


func _attachment_is_available(attachment: Dictionary) -> bool:
	match int(attachment.get("type", 0)):
		PlayerAssetReservationService.AttachmentType.NONE:
			return true
		PlayerAssetReservationService.AttachmentType.FISH_COIN:
			return (
				int(attachment["amount"])
				<= _reservations.get_available_fish_coin()
			)
		PlayerAssetReservationService.AttachmentType.FISH:
			return not _reservations.is_fish_reserved(
				StringName(str(attachment["catch_id"]))
			)
		PlayerAssetReservationService.AttachmentType.CONSUMABLE:
			return (
				int(attachment["quantity"])
				<= _reservations.get_available_item_quantity(
					StringName(str(attachment["item_id"]))
				)
			)
	return false


func _send() -> void:
	_set_attachment_amount(_attachment_amount_value())
	var recipient_id := int(_recipient.get_selected_metadata())
	var greeting_id := str(_greeting.get_selected_metadata())
	var salutation_id := str(_salutation.get_selected_metadata())
	if _service.send_letter(
		recipient_id, greeting_id, _body.text, salutation_id, _make_attachment()
	):
		_send_button.disabled = true
		_status.text = "Sending letter…"


func _on_operation_finished(success: bool, message: String) -> void:
	_status.text = message
	if success and _compose.visible:
		_show_inbox()
	elif _letter.visible and not _current_mail_id.is_empty():
		_open_letter(_current_mail_id)
	else:
		_update_send_state()


func _attachment_amount_value() -> int:
	return int(_attachment_amount.text) if _attachment_amount.text.is_valid_int() else 0


func _attachment_amount_maximum() -> int:
	if _attachment_kind.selected == 1:
		return _reservations.get_available_fish_coin()
	if _attachment_kind.selected == 3 and _attachment_choice.selected >= 0:
		return _reservations.get_available_item_quantity(
			StringName(str(_attachment_choice.get_selected_metadata()))
		)
	return 0


func _set_attachment_amount(value: int) -> void:
	var clamped := clampi(value, 0, _attachment_amount_maximum())
	var text := str(clamped)
	if _attachment_amount.text != text:
		_attachment_amount.text = text
		_attachment_amount.caret_column = text.length()
	_amount_minus.disabled = clamped <= 0
	_amount_plus.disabled = clamped >= _attachment_amount_maximum()
	_update_attachment_summary()


func _on_attachment_amount_changed(value: String) -> void:
	var digits := ""
	for character: String in value:
		if character >= "0" and character <= "9":
			digits += character
	_set_attachment_amount(int(digits) if not digits.is_empty() else 0)


func _step_attachment_amount(delta: int) -> void:
	_set_attachment_amount(_attachment_amount_value() + delta)
	_attachment_amount.grab_focus()


func _archive_current() -> void:
	if _current_mail_id.is_empty():
		return
	var archived := not _service.is_letter_archived(_current_mail_id)
	if _service.archive_local_letter(_current_mail_id, archived):
		_status.text = "Letter archived." if archived else "Letter restored."
		_show_inbox()


func _delete_current() -> void:
	if _current_mail_id.is_empty():
		return
	if _service.delete_local_letter(_current_mail_id):
		_status.text = "Letter deleted locally."
		_show_inbox()
	else:
		_status.text = "Resolve the gift before deleting this letter."


func _attachment_state_text(letter: Dictionary) -> String:
	var attachment: Dictionary = letter["attachment"]
	if int(attachment.get("type", 0)) == 0:
		return ""
	match int(letter["state"]):
		NetworkMailProtocol.State.ACCEPTED:
			return "Gift accepted.\n\n%s" % _attachment_text(attachment)
		NetworkMailProtocol.State.DECLINED:
			return "Gift declined."
		NetworkMailProtocol.State.ATTACHMENT_RECALLED, NetworkMailProtocol.State.CANCELLED:
			return "Gift returned to sender."
		NetworkMailProtocol.State.ACCEPTANCE_PENDING:
			return "Transferring gift…"
	return "Gift enclosed\n\n%s" % _attachment_text(attachment)


func _attachment_text(attachment: Dictionary) -> String:
	match int(attachment.get("type", 0)):
		PlayerAssetReservationService.AttachmentType.NONE:
			return "No gift attached."
		PlayerAssetReservationService.AttachmentType.FISH_COIN:
			return CurrencyPresentationType.bbcode_amount(
				int(attachment.get("amount", 0)), 18
			)
		PlayerAssetReservationService.AttachmentType.FISH:
			var fish_catch := _inventory.get_catch_by_id(
				StringName(str(attachment.get("catch_id", "")))
			)
			if fish_catch != null:
				return "%s — %.1f lb" % [
					FishQualityType.qualified_name(
						fish_catch.fish.display_name,
						fish_catch.quality,
					),
					fish_catch.weight_lb,
				]
			var data: Dictionary = attachment.get("catch", {})
			return "%s — %.1f lb" % [
				FishQualityType.qualified_name(
					str(data.get("fish_id", "fish")).capitalize(),
					int(data.get("quality", FishQualityType.Tier.BORING)),
				),
				float(data.get("weight_lb", 0.0)),
			]
		PlayerAssetReservationService.AttachmentType.CONSUMABLE:
			var item := _catalog.get_item_by_id(
				StringName(str(attachment.get("item_id", "")))
			)
			return "%s ×%d" % [
				item.display_name if item != null else "Item",
				int(attachment.get("quantity", 0)),
			]
	return "Invalid gift."


func _style_controls(root: Node) -> void:
	for node: Node in root.find_children("*", "", true, false):
		if node is BaseButton:
			UtilityPageStyle.apply_ocean_button(node)
		elif node is LineEdit:
			UtilityPageStyle.apply_ocean_line_edit(node)
		elif node is Label:
			node.add_theme_color_override(
				"font_color", UtilityPageStyle.OCEAN_TEXT_PRIMARY
			)
		elif node is TextEdit:
			UtilityPageStyle.apply_text_edit(node)
