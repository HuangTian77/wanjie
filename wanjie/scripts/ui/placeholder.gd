## 占位场景通用脚本
extends Control

func _on_back_pressed() -> void:
	SceneManager.go_back_to_hub()
