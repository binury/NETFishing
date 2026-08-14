extends SceneTree

const MainScene = preload("res://main/main.tscn")
const TEST_PORT: int = 18140
const FIRST_BANNED_FINGERPRINT: String = (
	"1111111111111111111111111111111111111111111111111111111111111111"
)
const SECOND_BANNED_FINGERPRINT: String = (
	"2222222222222222222222222222222222222222222222222222222222222222"
)

var _moderation_results: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.has("host"):
		await _run_host()
		return
	if arguments.has("client"):
		await _run_client()
		return
	push_error("Operator multiplayer validation needs host or client mode.")
	quit(1)


func _run_host() -> void:
	var main: Node = await _create_initialized_main()
	var session := main.get_node("%NetworkSession") as NetworkSession
	var service := (
		main.get_node("%NetworkPlayerListService")
		as NetworkPlayerListService
	)
	var bans := main.get_node("%HostBanStore") as HostBanStore
	assert(session.start_private_host(TEST_PORT))
	assert(session.set_host_open(true))

	var remote_peer_id: int = await _wait_for_remote_peer(session)
	assert(remote_peer_id > 1)
	var remote_record: PeerRegistry.PeerRecord = session.get_peer_record(
		remote_peer_id
	)
	assert(remote_record != null and remote_record.identity_authenticated)
	var host_fingerprint: String = session.get_host_identity_fingerprint()
	assert(bans.ban(
		host_fingerprint, FIRST_BANNED_FINGERPRINT, "First Banned Player"
	))

	var entry: PlayerListEntry = _entry_for_peer(service, remote_peer_id)
	assert(entry != null and entry.can_manage_operator)
	assert(service.set_operator(
		remote_peer_id,
		remote_record.identity_fingerprint,
		true,
		entry.revision,
	))
	assert(session.is_peer_operator(remote_peer_id))
	var players_page := main.find_child(
		"PlayersPage", true, false
	) as PlayersPage
	assert(players_page != null)
	players_page.call("_refresh")
	assert(_has_button_text(players_page, "deop"))

	var unban_deadline: int = Time.get_ticks_msec() + 12000
	while (
		Time.get_ticks_msec() < unban_deadline
		and bans.is_banned(host_fingerprint, FIRST_BANNED_FINGERPRINT)
	):
		await process_frame
	assert(not bans.is_banned(
		host_fingerprint, FIRST_BANNED_FINGERPRINT
	))
	assert(bans.ban(
		host_fingerprint, SECOND_BANNED_FINGERPRINT, "Second Banned Player"
	))

	entry = _entry_for_peer(service, remote_peer_id)
	assert(entry != null and entry.is_operator)
	assert(service.set_operator(
		remote_peer_id,
		remote_record.identity_fingerprint,
		false,
		entry.revision,
	))
	assert(not session.is_peer_operator(remote_peer_id))
	await create_timer(2.0).timeout
	assert(session.kick_authenticated_peer(
		remote_peer_id,
		remote_record.identity_fingerprint,
	))

	var disconnect_deadline: int = Time.get_ticks_msec() + 8000
	while (
		Time.get_ticks_msec() < disconnect_deadline
		and session.is_authenticated_peer(remote_peer_id)
	):
		await process_frame
	assert(not session.is_authenticated_peer(remote_peer_id))
	assert(bans.is_banned(host_fingerprint, SECOND_BANNED_FINGERPRINT))
	print("Operator multiplayer host validation: PASS")
	session.disconnect_session("")
	main.queue_free()
	for _frame: int in 4:
		await process_frame
	await create_timer(0.1).timeout
	quit()


func _run_client() -> void:
	var main: Node = await _create_initialized_main()
	main.call(
		"_on_title_join_game_requested", "127.0.0.1:%d" % TEST_PORT
	)
	var session := main.get_node("%NetworkSession") as NetworkSession
	var service := (
		main.get_node("%NetworkPlayerListService")
		as NetworkPlayerListService
	)
	service.moderation_finished.connect(
		func(success: bool, message: String) -> void:
			_moderation_results.append({
				"success": success,
				"message": message,
			})
	)
	var join_deadline: int = Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < join_deadline:
		await process_frame
		if session.state == NetworkSession.State.VERIFYING_SERVER_IDENTITY:
			main.call("_confirm_server_trust")
		if session.is_joined_client():
			break
	assert(session.is_joined_client())

	var operator_deadline: int = Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < operator_deadline and not session.is_local_operator():
		await process_frame
	assert(session.is_local_operator())
	assert(service.is_local_moderator())
	var players_page := main.find_child(
		"PlayersPage", true, false
	) as PlayersPage
	assert(players_page != null)
	players_page.call("_refresh")
	var tabs := players_page.get("_tabs") as HBoxContainer
	assert((tabs.get_child(2) as Button).visible)
	players_page.call("_select_tab", 2)
	assert(int(players_page.get("_current_tab")) == 2)
	var local_entry: PlayerListEntry = _entry_for_peer(
		service, session.get_local_peer_id()
	)
	assert(local_entry != null and local_entry.is_operator)

	var ban_deadline: int = Time.get_ticks_msec() + 10000
	while (
		Time.get_ticks_msec() < ban_deadline
		and not _has_ban(service.get_bans(), FIRST_BANNED_FINGERPRINT)
	):
		await process_frame
	assert(_has_ban(service.get_bans(), FIRST_BANNED_FINGERPRINT))
	assert(service.unban(FIRST_BANNED_FINGERPRINT))
	var result_deadline: int = Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < result_deadline and _moderation_results.is_empty():
		await process_frame
	assert(not _moderation_results.is_empty())
	assert(bool(_moderation_results.back().get("success", false)))

	var deop_deadline: int = Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deop_deadline and session.is_local_operator():
		await process_frame
	assert(not session.is_local_operator())
	assert(not service.is_local_moderator())
	assert(not (tabs.get_child(2) as Button).visible)
	assert(int(players_page.get("_current_tab")) == 0)
	service.request_unban.rpc_id(1, SECOND_BANNED_FINGERPRINT)
	var disconnect_deadline: int = Time.get_ticks_msec() + 10000
	while (
		Time.get_ticks_msec() < disconnect_deadline
		and session.state != NetworkSession.State.SERVER_LOST
	):
		await process_frame
	assert(session.state == NetworkSession.State.SERVER_LOST)
	assert(not bool(main.get("_gameplay_started")))
	var game_ui := main.get_node("%GameUI") as GameUI
	var title_screen := game_ui.get_title_screen()
	assert(title_screen.visible)
	assert(not title_screen.is_awaiting_start_input())
	assert((title_screen.get_node("%Center") as Control).visible)
	assert((title_screen.get_node("%ButtonCenter") as Control).visible)
	assert(not (title_screen.get_node("%JoinGamePage") as Control).visible)
	var feedback := title_screen.get_node("%FeedbackLabel") as RichTextLabel
	assert(feedback.visible)
	assert("removed by the host" in feedback.text.to_lower())
	print("Operator multiplayer client validation: PASS")
	main.queue_free()
	for _frame: int in 4:
		await process_frame
	await create_timer(0.1).timeout
	quit()


func _create_initialized_main() -> Node:
	root.size = Vector2i(1280, 720)
	var main: Node = MainScene.instantiate()
	root.add_child(main)
	for _frame: int in 4:
		await process_frame
	if not bool(main.get("_application_initialized")):
		main.call("_activate_selected_data_path", "", true)
	for _frame: int in 8:
		await process_frame
	assert(bool(main.get("_application_initialized")))
	return main


func _wait_for_remote_peer(session: NetworkSession) -> int:
	var deadline: int = Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		for peer_id: int in session.get_authenticated_peer_ids():
			if peer_id != session.get_local_peer_id():
				return peer_id
	return 0


func _entry_for_peer(
	service: NetworkPlayerListService,
	peer_id: int,
) -> PlayerListEntry:
	for entry: PlayerListEntry in service.get_entries():
		if entry.peer_id == peer_id:
			return entry
	return null


func _has_ban(records: Array[Dictionary], fingerprint: String) -> bool:
	for record: Dictionary in records:
		if str(record.get("target_fingerprint", "")) == fingerprint:
			return true
	return false


func _has_button_text(root_node: Node, text: String) -> bool:
	for node: Node in root_node.find_children("*", "Button", true, false):
		var button := node as Button
		if button != null and button.text == text:
			return true
	return false
