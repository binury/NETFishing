class_name MailPage
extends Control

signal focus_requested

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
var _recipient: OptionButton
var _greeting: OptionButton
var _body: TextEdit
var _salutation: OptionButton
var _signature: Label
var _attachment_kind: OptionButton
var _attachment_choice: OptionButton
var _attachment_amount: LineEdit
var _coin_available: Label
var _amount_minus: Button
var _amount_plus: Button
var _attachment_summary: Label
var _send_button: Button
var _status: Label
var _letter_text: Label
var _letter_gift: Label
var _accept: Button
var _decline: Button
var _archive: Button
var _delete: Button
var _current_mail_id := ""
var _showing_archive := false


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
	_show_inbox()
	UtilityPageStyle.animate_in(self)
	call_deferred("_focus_first")


func deactivate() -> void:
	_current_mail_id = ""
	_show_inbox()


func consume_escape() -> bool:
	if _compose.visible or _letter.visible:
		_show_inbox()
		return true
	return false


func is_composing_letter() -> bool:
	return _compose != null and _compose.visible


func set_interactive(value: bool) -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS if value else Control.MOUSE_FILTER_IGNORE
	for node: Node in find_children("*", "BaseButton", true, false):
		(node as BaseButton).focus_mode = (
			Control.FOCUS_ALL if value and node.is_visible_in_tree()
			else Control.FOCUS_NONE
		)


func _build_ui() -> void:
	var paper := PanelContainer.new()
	paper.position = Vector2(116, 126)
	paper.size = Vector2(1048, 540)
	paper.add_theme_stylebox_override("panel", UtilityPageStyle.panel_style())
	add_child(paper)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	paper.add_child(margin)
	var root := Control.new()
	margin.add_child(root)
	_inbox = _build_inbox()
	_compose = _build_compose()
	_letter = _build_letter()
	for page: Control in [_inbox, _compose, _letter]:
		page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root.add_child(page)
	_status = Label.new()
	_status.position = Vector2(18, 448)
	_status.size = Vector2(900, 28)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", Color("4a3f31"))
	root.add_child(_status)
	_style_controls(root)
	_show_inbox()


func _build_inbox() -> Control:
	var page := Control.new()
	var title := Label.new()
	title.text = "Mail"
	title.position = Vector2(12, 0)
	title.size = Vector2(500, 42)
	title.add_theme_font_size_override("font_size", 30)
	page.add_child(title)
	var send := Button.new()
	send.text = "send mail"
	send.position = Vector2(820, 0)
	send.size = Vector2(150, 48)
	send.pressed.connect(_show_compose)
	page.add_child(send)
	var archive_view := Button.new()
	archive_view.text = "archive"
	archive_view.position = Vector2(654, 0)
	archive_view.size = Vector2(154, 48)
	archive_view.pressed.connect(func() -> void:
		_showing_archive = not _showing_archive
		archive_view.text = "inbox" if _showing_archive else "archive"
		_refresh_inbox()
	)
	page.add_child(archive_view)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(12, 62)
	scroll.size = Vector2(958, 374)
	page.add_child(scroll)
	_inbox_list = VBoxContainer.new()
	_inbox_list.custom_minimum_size = Vector2(930, 0)
	_inbox_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_inbox_list)
	_empty_label = Label.new()
	_empty_label.text = "No letters yet."
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.custom_minimum_size = Vector2(930, 80)
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
	_greeting.size = Vector2(180, 46)
	for id: String in NetworkMailProtocol.GREETINGS:
		_greeting.add_item(GREETING_LABELS[id])
		_greeting.set_item_metadata(_greeting.item_count - 1, id)
	page.add_child(_greeting)
	_recipient = OptionButton.new()
	_recipient.position = Vector2(204, 48)
	_recipient.size = Vector2(330, 46)
	page.add_child(_recipient)
	_body = TextEdit.new()
	_body.position = Vector2(12, 106)
	_body.size = Vector2(650, 218)
	_body.placeholder_text = "write your letter…"
	_body.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_body.text_changed.connect(_update_send_state)
	page.add_child(_body)
	_salutation = OptionButton.new()
	_salutation.position = Vector2(12, 336)
	_salutation.size = Vector2(250, 46)
	for id: String in NetworkMailProtocol.SALUTATIONS:
		_salutation.add_item(SALUTATION_LABELS[id])
		_salutation.set_item_metadata(_salutation.item_count - 1, id)
	page.add_child(_salutation)
	_signature = Label.new()
	_signature.position = Vector2(274, 342)
	_signature.size = Vector2(360, 36)
	page.add_child(_signature)
	_attachment_kind = OptionButton.new()
	_attachment_kind.position = Vector2(688, 48)
	_attachment_kind.size = Vector2(280, 46)
	for label: String in ["No gift", "Fish coin", "Fish", "Consumable"]:
		_attachment_kind.add_item(label)
	_attachment_kind.item_selected.connect(_refresh_attachment_choices)
	page.add_child(_attachment_kind)
	_attachment_choice = OptionButton.new()
	_attachment_choice.position = Vector2(688, 106)
	_attachment_choice.size = Vector2(280, 46)
	_attachment_choice.item_selected.connect(
		func(_index: int) -> void:
			_update_attachment_amount_limit()
			_update_attachment_summary()
	)
	page.add_child(_attachment_choice)
	_coin_available = Label.new()
	_coin_available.position = Vector2(688, 158)
	_coin_available.size = Vector2(280, 28)
	page.add_child(_coin_available)
	_attachment_amount = LineEdit.new()
	_attachment_amount.position = Vector2(746, 190)
	_attachment_amount.size = Vector2(164, 46)
	_attachment_amount.placeholder_text = "0"
	_attachment_amount.text = "0"
	_attachment_amount.text_changed.connect(_on_attachment_amount_changed)
	page.add_child(_attachment_amount)
	_amount_minus = Button.new()
	_amount_minus.text = "−"
	_amount_minus.position = Vector2(688, 190)
	_amount_minus.size = Vector2(48, 46)
	_amount_minus.pressed.connect(_step_attachment_amount.bind(-1))
	page.add_child(_amount_minus)
	_amount_plus = Button.new()
	_amount_plus.text = "+"
	_amount_plus.position = Vector2(920, 190)
	_amount_plus.size = Vector2(48, 46)
	_amount_plus.pressed.connect(_step_attachment_amount.bind(1))
	page.add_child(_amount_plus)
	_attachment_summary = Label.new()
	_attachment_summary.position = Vector2(688, 246)
	_attachment_summary.size = Vector2(280, 78)
	_attachment_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(_attachment_summary)
	var cancel := Button.new()
	cancel.text = "cancel"
	cancel.position = Vector2(688, 342)
	cancel.size = Vector2(126, 48)
	cancel.pressed.connect(_show_inbox)
	page.add_child(cancel)
	_send_button = Button.new()
	_send_button.text = "send letter"
	_send_button.position = Vector2(826, 342)
	_send_button.size = Vector2(142, 48)
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
	_letter_text.size = Vector2(680, 350)
	_letter_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_letter_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	page.add_child(_letter_text)
	_letter_gift = Label.new()
	_letter_gift.position = Vector2(730, 46)
	_letter_gift.size = Vector2(230, 180)
	_letter_gift.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(_letter_gift)
	_accept = Button.new()
	_accept.text = "accept gift"
	_accept.position = Vector2(730, 250)
	_accept.size = Vector2(230, 48)
	_accept.pressed.connect(func() -> void:
		_service.accept_gift(_current_mail_id)
	)
	page.add_child(_accept)
	_decline = Button.new()
	_decline.text = "decline gift"
	_decline.position = Vector2(730, 308)
	_decline.size = Vector2(230, 48)
	_decline.pressed.connect(func() -> void:
		_service.decline_gift(_current_mail_id)
	)
	page.add_child(_decline)
	var close := Button.new()
	close.text = "close"
	close.position = Vector2(26, 370)
	close.size = Vector2(150, 48)
	close.pressed.connect(_show_inbox)
	page.add_child(close)
	_archive = Button.new()
	_archive.text = "archive"
	_archive.position = Vector2(550, 370)
	_archive.size = Vector2(150, 48)
	_archive.pressed.connect(_archive_current)
	page.add_child(_archive)
	_delete = Button.new()
	_delete.text = "delete"
	_delete.position = Vector2(710, 370)
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


func _show_compose() -> void:
	_inbox.hide()
	_compose.show()
	_letter.hide()
	_reset_compose()
	_signature.text = _service.get_local_display_name()
	_refresh_recipients()
	_update_send_state()
	_greeting.grab_focus()


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
		_accept.grab_focus()


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
		empty.custom_minimum_size = Vector2(930, 80)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_inbox_list.add_child(empty)
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
		button.custom_minimum_size = Vector2(930, 54)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_open_letter.bind(str(letter["mail_id"])))
		UtilityPageStyle.apply_button(button)
		_inbox_list.add_child(button)


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
	_coin_available.visible = _attachment_kind.selected == 1
	match _attachment_kind.selected:
		0:
			_attachment_choice.add_item("No attachment")
		1:
			_attachment_choice.add_item("Fish coin")
			_coin_available.text = "Available: %d fish coin" % (
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
							fish_catch.fish.display_name, fish_catch.weight_lb,
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
			return "%d fish coin" % int(attachment.get("amount", 0))
		PlayerAssetReservationService.AttachmentType.FISH:
			var fish_catch := _inventory.get_catch_by_id(
				StringName(str(attachment.get("catch_id", "")))
			)
			if fish_catch != null:
				return "%s — %.1f lb" % [
					fish_catch.fish.display_name, fish_catch.weight_lb,
				]
			var data: Dictionary = attachment.get("catch", {})
			return "%s — %.1f lb" % [
				str(data.get("fish_id", "fish")).capitalize(),
				float(data.get("weight_lb", 0.0)),
			]
		PlayerAssetReservationService.AttachmentType.CONSUMABLE:
			var item := _catalog.get_item_by_id(
				StringName(str(attachment.get("item_id", "")))
			)
			return "%s ×%d" % [
				item.display_name if item != null else "Consumable",
				int(attachment.get("quantity", 0)),
			]
	return "Invalid gift."


func _focus_first() -> void:
	var buttons := _inbox_list.find_children("*", "Button", true, false)
	if not buttons.is_empty():
		(buttons.front() as Button).grab_focus()


func _style_controls(root: Node) -> void:
	for node: Node in root.find_children("*", "", true, false):
		if node is BaseButton:
			UtilityPageStyle.apply_button(node)
		elif node is LineEdit:
			UtilityPageStyle.apply_line_edit(node)
		elif node is Label:
			node.add_theme_color_override(
				"font_color", UtilityPageStyle.INK
			)
		elif node is TextEdit:
			node.add_theme_font_override("font", UtilityPageStyle.TuffyFont)
			node.add_theme_color_override(
				"font_color", UtilityPageStyle.LIGHT_TEXT
			)
			node.add_theme_color_override(
				"font_placeholder_color",
				Color(0.82, 0.80, 0.71, 0.84)
			)
