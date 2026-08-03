## 模态遮罩层组件
## 半透明背景 + 居中面板，支持弹出/收起动画、焦点捕获
class_name ModalOverlay
extends Control

signal opened
signal closed

@onready var background: ColorRect = %ModalBackground
@onready var panel: PanelContainer = %ModalPanel

## 点击遮罩是否可关闭
@export var close_on_bg_click: bool = true

var _is_open: bool = false

func _ready() -> void:
	visible = false
	background.gui_input.connect(_on_bg_gui_input)

## 打开模态框
func open() -> void:
	if _is_open:
		return
	_is_open = true
	visible = true
	# 动画
	background.modulate.a = 0.0
	panel.scale = Vector2(0.9, 0.9)
	panel.modulate.a = 0.0
	var tween := ThemeManager.create_anim(self)
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.set_parallel(true)
	tween.tween_property(background, "modulate:a", 1.0, 0.2)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.25)
	tween.tween_property(panel, "modulate:a", 1.0, 0.2)
	tween.chain().tween_callback(func(): opened.emit())
	# 焦点捕获
	set_process_input(true)

## 关闭模态框
func close() -> void:
	if not _is_open:
		return
	_is_open = false
	var tween := ThemeManager.create_anim(self)
	tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.set_parallel(true)
	tween.tween_property(background, "modulate:a", 0.0, 0.15)
	tween.tween_property(panel, "scale", Vector2(0.95, 0.95), 0.15)
	tween.tween_property(panel, "modulate:a", 0.0, 0.15)
	tween.chain().tween_callback(func():
		visible = false
		set_process_input(false)
		closed.emit()
	)

func _on_bg_gui_input(event: InputEvent) -> void:
	if close_on_bg_click and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()

func _input(event: InputEvent) -> void:
	if not _is_open:
		return
	# Escape 关闭
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
