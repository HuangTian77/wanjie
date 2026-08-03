## VisualSystemBlueprint - 子系统蓝图编辑器
## 为各子系统（世界观/事件/经济/能力/任务/战斗/地图）提供专属蓝图图:
## 用户可在各子系统模块下"🎨 蓝图"分支, 用蓝图节点精确添加/移除/修改该子系统功能。
## 复用 visual_blueprint_workspace 的锁定模式（固定编辑 sys:<subsystem> 图）。
extends "res://scripts/editor/visual/visual_module_base.gd"

## sub_type -> 子系统图 key 映射
const SYSTEM_KEYS := {
	"worldview_blueprint": "sys:worldview",
	"event_blueprint": "sys:event",
	"economy_blueprint": "sys:economy",
	"ability_blueprint": "sys:ability",
	"quest_blueprint": "sys:quest",
	"combat_blueprint": "sys:combat",
	"map_blueprint": "sys:map",
}

## 子系统的中文名（工具栏提示用）
const SYSTEM_NAMES := {
	"worldview_blueprint": "世界观",
	"event_blueprint": "事件系统",
	"economy_blueprint": "经济系统",
	"ability_blueprint": "能力系统",
	"quest_blueprint": "任务系统",
	"combat_blueprint": "战斗系统",
	"map_blueprint": "地图",
}

## 创建子系统蓝图编辑器
func create(sub_type: String = "", _meta: Dictionary = {}) -> Control:
	var sys_name: String = SYSTEM_NAMES.get(sub_type, "子系统")
	var sys_key: String = SYSTEM_KEYS.get(sub_type, "")
	# 复用蓝图工作区（锁定模式: 固定编辑本子系统图）
	var ws_mod = load("res://scripts/editor/visual/visual_blueprint_workspace.gd").new(_host)
	ws_mod._locked_key = sys_key
	var root: Control = ws_mod.create(sub_type, {})
	# 顶部覆盖提示（在根控件前插入标题不易, 工具栏已显示图 key; 这里在根上加个顶部条）
	var header := PanelContainer.new()
	header.custom_minimum_size.y = 30
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.129412, 0.149020, 0.180392, 1)
	sb.border_width_bottom = 1
	sb.border_color = Color(0.0, 0.0, 0.0, 0.4)
	sb.content_margin_left = 12.0
	header.add_theme_stylebox_override("panel", sb)
	var title := Label.new()
	title.text = "🔷 %s 蓝图 — 在此用节点精确添加/移除/修改本子系统功能" % sys_name
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.803922, 0.811765, 0.823529, 1))
	header.add_child(title)
	# 把 header 插到 root 最前面（root 是 PanelContainer, 其子为 main_vbox）
	if root.get_child_count() > 0:
		root.add_child(header)
		root.move_child(header, 0)
	else:
		root.add_child(header)
	return root
