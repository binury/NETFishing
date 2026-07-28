class_name BubbleStatusBubble
extends PanelContainer

@export var profile: BubbleMenuProfile

@onready var _heading: Label = %Heading
@onready var _value: Label = %Value


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if profile != null:
		add_theme_stylebox_override("panel", profile.make_normal_style())


func set_content(heading: String, value: String) -> void:
	_heading.text = heading
	_value.text = value
