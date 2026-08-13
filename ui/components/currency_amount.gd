class_name CurrencyAmount
extends HBoxContainer

@export var amount: int = 0:
	set(value):
		amount = value
		_display_text = str(value)
		_refresh_amount()
@export_range(8.0, 64.0, 1.0) var icon_size: float = 18.0:
	set(value):
		icon_size = value
		_refresh_icon_size()

@onready var _icon: TextureRect = %Icon
@onready var _amount_label: Label = %Amount

var _display_text: String = "0"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh_icon_size()
	_refresh_amount()


func set_amount(value: int) -> void:
	amount = value


func set_amount_text(value: String) -> void:
	_display_text = value
	_refresh_amount()


func get_amount_label() -> Label:
	if _amount_label != null:
		return _amount_label
	return get_node_or_null("Amount") as Label


func _refresh_amount() -> void:
	if _amount_label != null:
		_amount_label.text = _display_text


func _refresh_icon_size() -> void:
	if _icon != null:
		_icon.custom_minimum_size = Vector2.ONE * icon_size
