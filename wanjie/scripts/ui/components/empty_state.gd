## 空状态占位组件
## 图标 + 描述文字 + 可选操作按钮
class_name EmptyState
extends VBoxContainer

signal action_pressed

@onready var icon_label: Label = %EmptyIcon
@onready var desc_label: Label = %EmptyDesc
@onready var action_btn: Button = %EmptyAction

@export var icon: String = "📜":
	set(value):
		icon = value
		if is_node_ready():
			icon_label.text = value

@export var description: String = "这里还没有内容":
	set(value):
		description = value
		if is_node_ready():
			desc_label.text = value

@export var show_action: bool = false:
	set(value):
		show_action = value
		if is_node_ready():
			action_btn.visible = value

@export var action_text: String = "去创建":
	set(value):
		action_text = value
		if is_node_ready():
			action_btn.text = value

func _ready() -> void:
	icon_label.text = icon
	desc_label.text = description
	action_btn.text = action_text
	action_btn.visible = show_action
	action_btn.pressed.connect(func(): action_pressed.emit())

## 快捷设置
func setup(desc: String, icon_text: String = "📜", btn_text: String = "", show_btn: bool = false) -> void:
	description = desc
	icon = icon_text
	show_action = show_btn
	action_text = btn_text
