## 通用确认对话框
extends Control

signal confirmed
signal cancelled

@onready var title_label: Label = %DialogTitle
@onready var message_label: Label = %DialogMessage
@onready var confirm_btn: Button = %ConfirmBtn
@onready var cancel_btn: Button = %CancelBtn

## 显示对话框
func show_dialog(title: String, message: String, confirm_text: String = "确认", cancel_text: String = "取消") -> void:
	title_label.text = title
	message_label.text = message
	confirm_btn.text = confirm_text
	cancel_btn.text = cancel_text
	visible = true

func _on_confirm_pressed() -> void:
	visible = false
	confirmed.emit()

func _on_cancel_pressed() -> void:
	visible = false
	cancelled.emit()
