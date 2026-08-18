extends SceneTree

const TitleScreenScene := preload("res://ui/title_screen.tscn")
const TitleCreditsPageType = preload("res://ui/title_credits_page.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var original_size: Vector2i = root.size
	root.size = Vector2i(1280, 720)
	var title_screen := TitleScreenScene.instantiate() as TitleScreen
	root.add_child(title_screen)
	await process_frame
	await process_frame

	var credits_button := title_screen.get_node(
		"%CreditsButton"
	) as BubbleButton
	var credits_page := title_screen.get_node(
		"%CreditsPage"
	) as TitleCreditsPageType
	var back_button: Button = credits_page.get_back_button()
	var presentation := title_screen.get_node("%Center") as Control
	var bubble_field := title_screen.get_node("%BubbleField") as Control
	title_screen.call("_update_title_layout")
	(title_screen.get_node("%ButtonCenter") as Control).show()
	bubble_field.show()
	title_screen.call("_set_title_bubbles_interactive", true)
	await process_frame

	_expect(credits_button != null, "title menu exposes a credits button")
	_expect(
		credits_button.icon != null and credits_button.text.is_empty(),
		"credits bubble uses its authored icon",
	)
	_expect(credits_page != null, "title screen contains the credits page")
	_expect(not credits_page.visible, "credits page starts closed")
	_expect(
		Rect2(Vector2.ZERO, bubble_field.size).encloses(
			Rect2(credits_button.position, credits_button.size)
		),
		"credits bubble stays inside the authored title field",
	)
	_expect(
		credits_button.mouse_filter == Control.MOUSE_FILTER_STOP,
		"credits bubble accepts pointer input",
	)
	if OS.has_environment("NETFISHING_TITLE_MENU_CAPTURE"):
		(title_screen.get_node("%StartPromptCenter") as Control).hide()
		title_screen.set_process(true)
		await create_timer(0.5).timeout
		_expect(
			_save_capture(
				OS.get_environment("NETFISHING_TITLE_MENU_CAPTURE")
			) == OK,
			"title menu validation capture saves successfully",
		)
		title_screen.set_process(false)

	title_screen.set("_navigation_focus_active", false)
	credits_button.pressed.emit()
	await process_frame
	_expect(credits_page.visible, "pointer activation opens credits")
	_expect(not presentation.visible, "credits replace the primary title menu")
	_expect(
		root.gui_get_focus_owner() != back_button,
		"pointer activation does not pseudo-select back",
	)
	await create_timer(0.25).timeout
	_expect(
		credits_page.mouse_filter == Control.MOUSE_FILTER_PASS,
		"credits page becomes pointer-interactive after entry motion",
	)
	_expect(
		back_button.mouse_filter == Control.MOUSE_FILTER_STOP,
		"credits back button accepts pointer clicks",
	)
	if OS.has_environment("NETFISHING_CREDITS_CAPTURE"):
		await process_frame
		_expect(
			_save_capture(
				OS.get_environment("NETFISHING_CREDITS_CAPTURE")
			) == OK,
			"credits validation capture saves successfully",
		)
	back_button.pressed.emit()
	await process_frame
	_expect(not credits_page.visible, "pointer back closes credits")
	_expect(presentation.visible, "closing credits restores the title menu")
	_expect(
		root.gui_get_focus_owner() == null,
		"pointer return leaves the title menu unfocused",
	)

	title_screen.set("_navigation_focus_active", true)
	credits_button.grab_focus()
	credits_button.pressed.emit()
	await process_frame
	await process_frame
	_expect(
		root.gui_get_focus_owner() == back_button,
		"keyboard or controller activation focuses the credits back button",
	)

	var pointer_motion := InputEventMouseMotion.new()
	pointer_motion.position = Vector2(640.0, 360.0)
	title_screen._input(pointer_motion)
	await process_frame
	_expect(
		root.gui_get_focus_owner() == null,
		"pointer motion clears credits navigation focus",
	)

	var navigate := InputEventAction.new()
	navigate.action = &"ui_down"
	navigate.pressed = true
	title_screen._input(navigate)
	await process_frame
	_expect(
		root.gui_get_focus_owner() == back_button,
		"navigation input restores credits focus",
	)

	var cancel := InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	title_screen._input(cancel)
	await process_frame
	_expect(not credits_page.visible, "ui cancel closes credits")
	_expect(
		root.gui_get_focus_owner() == credits_button,
		"navigation return restores focus to the credits bubble",
	)

	var chillnfill_name := credits_page.get_node(
		"Paper/Margin/Layout/Columns/CreativeCredits/ChillnfillName"
	) as Label
	var voyager_name := credits_page.get_node(
		"Paper/Margin/Layout/Columns/CreativeCredits/VoyagerName"
	) as Label
	var endeavour_name := credits_page.get_node(
		"Paper/Margin/Layout/Columns/CreativeCredits/EndeavourName"
	) as Label
	var chillnfill_credit := credits_page.get_node(
		"Paper/Margin/Layout/Columns/CreativeCredits/ChillnfillCredit"
	) as Label
	var adamantris_name := credits_page.get_node(
		"Paper/Margin/Layout/Columns/CreativeCredits/AdamantrisName"
	) as Label
	var adamantris_credit := credits_page.get_node(
		"Paper/Margin/Layout/Columns/CreativeCredits/AdamantrisCredit"
	) as Label
	var tekgator_name := credits_page.get_node(
		"Paper/Margin/Layout/Columns/CreativeCredits/TekgatorName"
	) as Label
	var tekgator_credit := credits_page.get_node(
		"Paper/Margin/Layout/Columns/CreativeCredits/TekgatorCredit"
	) as Label
	var credits_paper := credits_page.get_node("Paper") as PanelContainer
	var audio_credits := credits_page.get_node(
		"Paper/Margin/Layout/Columns/AdditionalCredits/AudioCredits"
	) as Label
	_expect(voyager_name.text == "Voyager", "in-game credits use Voyager")
	_expect(
		endeavour_name.text == "Endeavour",
		"in-game credits use Endeavour",
	)
	_expect(
		chillnfill_name.text == "chillnfill",
		"in-game credits name chillnfill",
	)
	_expect(
		"trees and bridges" in chillnfill_credit.text.to_lower(),
		"in-game credits describe the supplied model families",
	)
	_expect(
		adamantris_name.text == "adamantris",
		"in-game credits name adamantris",
	)
	_expect(
		"hand-net model" in adamantris_credit.text.to_lower()
		and "texture artwork" in adamantris_credit.text.to_lower(),
		"in-game credits describe adamantris's hand-net contribution",
	)
	_expect(
		tekgator_name.text == "Tekgator",
		"in-game credits name Tekgator",
	)
	_expect(
		"shop icon" in tekgator_credit.text.to_lower(),
		"in-game credits describe Tekgator's shop icon artwork",
	)
	_expect(
		"kat • animalese voice sample" in audio_credits.text,
		"in-game credits name kat's animalese voice contribution",
	)
	_expect(
		"kim • animalese voice sample" in audio_credits.text,
		"in-game credits name kim's animalese voice contribution",
	)
	_expect(
		credits_paper.get_global_rect().encloses(
			tekgator_credit.get_global_rect()
		),
		"contributor credits stay inside the authored credits panel",
	)

	title_screen.queue_free()
	root.size = original_size
	await process_frame
	await process_frame
	if _failures.is_empty():
		print("Title credits validation: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _save_capture(path: String) -> Error:
	var viewport_texture: Texture2D = root.get_texture()
	if viewport_texture == null:
		return ERR_UNAVAILABLE
	return viewport_texture.get_image().save_png(path)
