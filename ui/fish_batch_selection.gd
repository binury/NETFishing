class_name FishBatchSelection
extends RefCounted

var _selected_ids: Dictionary[StringName, bool] = {}
var _visible_ids: Array[StringName] = []
var _focused_id: StringName
var _anchor_id: StringName


func set_visible_order(visible_ids: Array[StringName]) -> void:
	_visible_ids = visible_ids.duplicate()
	var visible_set: Dictionary[StringName, bool] = {}
	for catch_id: StringName in _visible_ids:
		if not catch_id.is_empty():
			visible_set[catch_id] = true
	for catch_id: StringName in _selected_ids.keys():
		if not visible_set.has(catch_id):
			_selected_ids.erase(catch_id)
	if not visible_set.has(_focused_id):
		_focused_id = StringName()
	if not visible_set.has(_anchor_id):
		_anchor_id = StringName()


func apply_click(
	catch_id: StringName,
	ctrl_pressed: bool,
	shift_pressed: bool,
) -> void:
	if catch_id.is_empty() or not _visible_ids.has(catch_id):
		return
	if not shift_pressed or _anchor_id.is_empty():
		if ctrl_pressed:
			if _selected_ids.has(catch_id):
				_selected_ids.erase(catch_id)
			else:
				_selected_ids[catch_id] = true
		else:
			_selected_ids.clear()
			_selected_ids[catch_id] = true
		_focused_id = catch_id
		_anchor_id = catch_id
		return

	var anchor_index: int = _visible_ids.find(_anchor_id)
	var target_index: int = _visible_ids.find(catch_id)
	if anchor_index < 0 or target_index < 0:
		select_only(catch_id)
		return
	if not ctrl_pressed:
		_selected_ids.clear()
	var first_index: int = mini(anchor_index, target_index)
	var last_index: int = maxi(anchor_index, target_index)
	for index: int in range(first_index, last_index + 1):
		_selected_ids[_visible_ids[index]] = true
	_focused_id = catch_id


func select_only(catch_id: StringName) -> void:
	_selected_ids.clear()
	if catch_id.is_empty() or not _visible_ids.has(catch_id):
		_focused_id = StringName()
		_anchor_id = StringName()
		return
	_selected_ids[catch_id] = true
	_focused_id = catch_id
	_anchor_id = catch_id


func clear() -> void:
	_selected_ids.clear()
	_focused_id = StringName()
	_anchor_id = StringName()


func remove_ids(catch_ids: Array[StringName]) -> void:
	for catch_id: StringName in catch_ids:
		_selected_ids.erase(catch_id)
		if _focused_id == catch_id:
			_focused_id = StringName()
		if _anchor_id == catch_id:
			_anchor_id = StringName()


func get_selected_ids() -> Array[StringName]:
	var selected_in_order: Array[StringName] = []
	for catch_id: StringName in _visible_ids:
		if _selected_ids.has(catch_id):
			selected_in_order.append(catch_id)
	return selected_in_order


func is_selected(catch_id: StringName) -> bool:
	return _selected_ids.has(catch_id)


func get_selected_count() -> int:
	return _selected_ids.size()


func get_focused_id() -> StringName:
	return _focused_id


func get_anchor_id() -> StringName:
	return _anchor_id
