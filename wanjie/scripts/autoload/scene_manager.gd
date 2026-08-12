## 场景切换管理器（Autoload单例）
## 管理场景过渡动画和导航
extends Node

## 当前场景的容器节点（在main_hub中设置）
var scene_container: Control = null
## 当前正在操作的剧本ID（传递给编辑器/体验器）
var current_script_id: String = ""
## 场景路径常量
const SCENE_MAIN_HUB := "res://scenes/main/main_hub.tscn"
const SCENE_SCRIPT_EDITOR := "res://scenes/editor/script_editor.tscn"
const SCENE_SCRIPT_PLAYER := "res://scenes/player/script_player.tscn"
const SCENE_SETTINGS := "res://scenes/settings/settings.tscn"

## 信号：场景切换开始
signal scene_change_started(target_scene: String)
## 信号：场景切换完成
signal scene_change_completed(target_scene: String)

## 切换到指定场景（带淡入淡出动画）
func change_scene(scene_path: String) -> void:
	scene_change_started.emit(scene_path)
	# 如果动效关闭，直接切换
	if not ThemeManager.animations_enabled:
		_do_scene_switch(scene_path)
		scene_change_completed.emit(scene_path)
		return
	# 创建遮罩用于淡入淡出
	var overlay := ColorRect.new()
	overlay.color = Color(0.1, 0.09, 0.08, 0.0)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 100
	get_tree().root.add_child(overlay)

	var tween := create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(overlay, "color:a", 1.0, 0.25)
	tween.tween_callback(_do_scene_switch.bind(scene_path))
	tween.tween_interval(0.08)
	tween.tween_property(overlay, "color:a", 0.0, 0.3)
	tween.tween_callback(overlay.queue_free)
	tween.tween_callback(func(): scene_change_completed.emit(scene_path))

## 执行场景切换
func _do_scene_switch(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)

## 返回主界面
func go_back_to_hub() -> void:
	# 返回大厅前刷新剧本库（进度/评分即时生效）
	var gm: Node = get_tree().root.get_node_or_null("GameManager")
	if gm != null and gm.has_method("refresh_scripts"):
		gm.call("refresh_scripts")
	change_scene(SCENE_MAIN_HUB)

## 打开剧本编辑器
func open_script_editor(script_id: String = "") -> void:
	current_script_id = script_id
	change_scene(SCENE_SCRIPT_EDITOR)

## 进入剧本体验
func enter_script(script_id: String) -> void:
	current_script_id = script_id
	if GameManager.user_data.consume_inspiration():
		GameManager.save_user_data()
		change_scene(SCENE_SCRIPT_PLAYER)
	else:
		if Engine.has_singleton("ToastManager") or has_node("/root/ToastManager"):
			get_node("/root/ToastManager").warning("灵感点不足，无法进入剧本")
		else:
			push_warning("灵感点不足，无法进入剧本")

## 打开设置
func open_settings() -> void:
	change_scene(SCENE_SETTINGS)
