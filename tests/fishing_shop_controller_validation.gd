extends SceneTree

const FishingShopScene: PackedScene = preload(
	"res://ui/fishing_shop.tscn"
)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var shop := FishingShopScene.instantiate() as FishingShop
	root.add_child(shop)
	shop.show()
	await process_frame

	var tabs: Array = shop.get("_shop_tabs") as Array
	assert(tabs.size() == FishingShop.ShopSection.size())
	var supplies_list := shop.get_node("%SuppliesList") as VBoxContainer
	var dummy_stock := Button.new()
	dummy_stock.name = "ControllerTestStock"
	dummy_stock.text = "test stock"
	supplies_list.add_child(dummy_stock)
	var activations: Array[int] = [0]
	dummy_stock.pressed.connect(
		func() -> void:
			activations[0] += 1
	)

	var accept := InputEventJoypadButton.new()
	accept.button_index = JOY_BUTTON_A
	accept.pressed = true
	var cancel := InputEventJoypadButton.new()
	cancel.button_index = JOY_BUTTON_B
	cancel.pressed = true

	for section_index: int in range(FishingShop.ShopSection.ART_SUPPLIES + 1):
		shop.set("_shop_section", section_index)
		shop.call("_select_shop_section", section_index, false)
		shop.call("_enter_shop_tabs_zone")
		for _frame: int in 2:
			await process_frame
		var tab := tabs[section_index] as Button
		assert(
			root.gui_get_focus_owner() == tab,
			"section %d tab focus mismatch: focused=%s tab=%s visible=%s mode=%d"
			% [
				section_index,
				root.gui_get_focus_owner(),
				tab,
				tab.is_visible_in_tree(),
				tab.focus_mode,
			],
		)
		assert(
			shop.get("_controller_zone")
			== FishingShop.ControllerZone.TABS
		)
		shop.call("_input", accept)
		for _frame: int in 2:
			await process_frame
		assert(int(shop.get("_shop_section")) == section_index)
		assert(
			shop.get("_controller_zone")
			== FishingShop.ControllerZone.CONTENT
		)
		assert(not _array_contains_control(
			tabs,
			root.gui_get_focus_owner(),
		))
		if section_index == FishingShop.ShopSection.BAIT:
			assert(root.gui_get_focus_owner() == dummy_stock)
			shop.call("_input", accept)
			assert(activations[0] == 1)
		shop.call("_input", cancel)
		for _frame: int in 2:
			await process_frame
		assert(shop.visible)
		assert(
			shop.get("_controller_zone")
			== FishingShop.ControllerZone.TABS
		)
		assert(root.gui_get_focus_owner() == tab)

	shop.hide()
	shop.queue_free()
	await process_frame
	print("Fishing shop controller validation: PASS")
	quit()


func _array_contains_control(values: Array, target: Control) -> bool:
	for value: Variant in values:
		var control := value as Control
		if control == target:
			return true
	return false
