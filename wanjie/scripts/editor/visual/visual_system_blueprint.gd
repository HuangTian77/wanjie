## VisualSystemBlueprint - 子系统蓝图编辑器（子页蓝图化）
## 每个子系统子分支打开即蓝图界面（锁定 sys:<subsystem> 图）, 顶部可切换回原表单。
## 蓝图 = 用节点精确添加/移除/修改本子系统功能; 表单 = 传统数据编辑兜底。
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

## sub_type -> 子系统中文名
const SYSTEM_NAMES := {
	"worldview_blueprint": "世界观",
	"event_blueprint": "事件系统",
	"economy_blueprint": "经济系统",
	"ability_blueprint": "能力系统",
	"quest_blueprint": "任务系统",
	"combat_blueprint": "战斗系统",
	"map_blueprint": "地图",
}

## 表单模块映射: node_type 前缀 -> 表单模块文件名
const FORM_MODULE_BY_PREFIX := {
	"worldview": "visual_worldview", "event": "visual_event", "economy": "visual_economy",
	"ability": "visual_ability", "quest": "visual_quest", "combat": "visual_combat",
	"map": "visual_map",
}

var _bp_view: Control = null
var _form_view: Control = null
var _bp_mod = null
var _current_sub_type: String = ""

## 创建子系统蓝图编辑器（蓝图优先, 可切表单）
func create(sub_type: String = "", meta: Dictionary = {}) -> Control:
	_current_sub_type = sub_type
	var sys_name: String = SYSTEM_NAMES.get(sub_type, "子系统")
	var sys_key: String = SYSTEM_KEYS.get(sub_type, "")
	var form_module: String = meta.get("form_module", _form_module_for(sub_type))
	var form_sub: String = meta.get("form_sub", "")

	var root := PanelContainer.new()
	root.add_theme_stylebox_override("panel", _ui().make_bg_style())
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 0)
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(main_vbox)

	# === 顶部栏: 标题 + 蓝图/表单切换 ===
	var header := PanelContainer.new()
	header.custom_minimum_size.y = 34
	var hb := StyleBoxFlat.new()
	hb.bg_color = Color(0.129412, 0.149020, 0.180392, 1)
	hb.border_width_bottom = 1
	hb.border_color = Color(0.0, 0.0, 0.0, 0.4)
	hb.content_margin_left = 10.0
	hb.content_margin_right = 10.0
	header.add_theme_stylebox_override("panel", hb)
	main_vbox.add_child(header)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	header.add_child(hbox)
	var title := Label.new()
	title.text = "🔷 %s 蓝图" % sys_name
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.803922, 0.811765, 0.823529, 1))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(title)
	var bp_btn := Button.new()
	bp_btn.text = "🔷 蓝图"
	bp_btn.toggle_mode = true
	bp_btn.button_pressed = true
	hbox.add_child(bp_btn)
	var form_btn := Button.new()
	form_btn.text = "📝 表单"
	form_btn.toggle_mode = true
	hbox.add_child(form_btn)
	# 互斥切换
	bp_btn.pressed.connect(func():
		bp_btn.button_pressed = true
		form_btn.button_pressed = false
		_show_view(true, form_module, form_sub, main_vbox)
	)
	form_btn.pressed.connect(func():
		bp_btn.button_pressed = false
		form_btn.button_pressed = true
		_show_view(false, form_module, form_sub, main_vbox)
	)

	# === 蓝图视图（锁定 workspace） ===
	_bp_mod = load("res://scripts/editor/visual/visual_blueprint_workspace.gd").new(_host)
	_bp_mod._locked_key = sys_key
	_bp_view = _bp_mod.create(sub_type, meta)
	main_vbox.add_child(_bp_view)
	_bp_view.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# 表单视图（延迟构建）
	_form_view = VBoxContainer.new()
	_form_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_form_view.visible = false
	main_vbox.add_child(_form_view)

	return root

## 蓝图/表单视图切换
func _show_view(blueprint: bool, form_module: String, form_sub: String, main_vbox: VBoxContainer) -> void:
	if _bp_view:
		_bp_view.visible = blueprint
		_bp_view.size_flags_vertical = Control.SIZE_EXPAND_FILL if blueprint else Control.SIZE_SHRINK_BEGIN
	if _form_view == null:
		return
	_form_view.visible = not blueprint
	if not blueprint and _form_view.get_child_count() == 0:
		_build_form(form_module, form_sub)

## 构建表单视图（复用原 visual 模块的表单内容）
func _build_form(form_module: String, form_sub: String) -> void:
	var form_mod = load("res://scripts/editor/visual/%s.gd" % form_module).new(_host)
	# 表单模块用 build_standard_layout 或 _build_content; 这里取内容区
	if form_mod.has_method("build_standard_layout"):
		var ctrl: Control = form_mod.build_standard_layout(form_sub, {})
		_form_view.add_child(ctrl)
		ctrl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	elif form_mod.has_method("_build_content"):
		form_mod._build_content(_form_view, form_sub, {})
	# 移除原模块的导航（如果 build_standard_layout 带左侧导航, 接受即可）

## 由 sub_type 推导表单模块（默认对应子系统）
func _form_module_for(sub_type: String) -> String:
	var prefix := sub_type.trim_suffix("_blueprint")
	return FORM_MODULE_BY_PREFIX.get(prefix, "visual_worldview")
