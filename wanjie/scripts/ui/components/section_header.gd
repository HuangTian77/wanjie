## 分区标题组件
## 标题文字 + 可选右侧操作按钮 + 分隔线
class_name SectionHeader
extends VBoxContainer

signal action_pressed

@onready var title_label: Label = %SectionTitle
@onready var action_btn: Button = %SectionAction
@onready var separator: HSeparator = %SectionSeparator

@export var title: String = "分区标题":
	set(value):
		title = value
		if is_node_ready():
			title_label.text = value

@export var show_action: bool = false:
	set(value):
		show_action = value
		if is_node_ready():
			action_btn.visible = value

@export var action_text: String = "更多":
	set(value):
		action_text = value
		if is_node_ready():
			action_btn.text = value

@export var show_separator: bool = true:
	set(value):
		show_separator = value
		if is_node_ready():
			separator.visible = value

func _ready() -> void:
	title_label.text = title
	action_btn.text = action_text
	action_btn.visible = show_action
	separator.visible = show_separator
	action_btn.pressed.connect(func(): action_pressed.emit())
