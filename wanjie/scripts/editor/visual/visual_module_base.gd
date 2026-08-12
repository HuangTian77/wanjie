## 可视化编辑器模块基类
## 所有可视化子模块继承此基类，通过 _host 访问主编辑器
class_name VisualModuleBase
extends RefCounted

var _host  # script_editor.gd 实例 (duck-typed)

func _init(host) -> void:
	_host = host

## 获取当前剧本数据
func _ws() -> WorldScriptData:
	return _host.current_script

## 获取UI工厂
func _ui() -> RefCounted:
	return _host._ui

## 日志输出
func _log(msg: String) -> void:
	_host._log_output(msg)

## 同步到代码编辑器
func _sync() -> void:
	_host._sync_to_code_editor()

## 标记脏数据
func _dirty() -> void:
	_host._mark_dirty()

## 重建模块树
func _rebuild_tree() -> void:
	_host._build_module_tree()

## 清空容器子控件（各模块 _build_content 复用）
func _clear(container: Control) -> void:
	for child in container.get_children():
		child.queue_free()

## === 标准布局构建 ===
## 所有标准模块（左导航 + 右内容）共享此布局
## 子类需实现: get_nav_title(), get_nav_items(), _build_content()

## 构建标准布局: 左导航 + 右内容区
func build_standard_layout(sub_type: String, meta: Dictionary = {}) -> Control:
	var root := PanelContainer.new()
	root.add_theme_stylebox_override("panel", _ui().make_bg_style())
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var main_hbox := HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", 0)
	main_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(main_hbox)
	# 左侧导航
	var nav_bg := PanelContainer.new()
	nav_bg.custom_minimum_size.x = 150
	nav_bg.add_theme_stylebox_override("panel", _ui().make_nav_style())
	main_hbox.add_child(nav_bg)
	var nav_scroll := ScrollContainer.new()
	nav_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	nav_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	nav_bg.add_child(nav_scroll)
	var nav := VBoxContainer.new()
	nav.add_theme_constant_override("separation", 2)
	nav.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav_scroll.add_child(nav)
	# 简易模式：导航顶部模式徽标
	if EditorMode.is_simple():
		var mode_badge := Label.new()
		mode_badge.text = "🌱 简易模式"
		mode_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mode_badge.add_theme_font_size_override("font_size", 11)
		mode_badge.add_theme_color_override("font_color", Color(0.5, 0.8, 0.55, 0.9))
		nav.add_child(mode_badge)
	_ui().add_nav_title(nav, get_nav_title())
	# 右侧内容区
	var content_scroll := ScrollContainer.new()
	content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var content_bg := PanelContainer.new()
	content_bg.add_theme_stylebox_override("panel", _ui().make_content_style())
	content_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_bg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_scroll.add_child(content_bg)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	content_bg.add_child(content)
	main_hbox.add_child(content_scroll)
	# 导航按钮
	var nav_items := get_nav_items()
	for item in nav_items:
		_ui().add_nav_btn(nav, item[0], item[1], sub_type, func(t):
			_build_content(content, t, meta)
		)
	# 初始内容
	_build_content(content, sub_type, meta)
	return root

## === 子类必须重写的方法 ===

## 导航标题
func get_nav_title() -> String:
	return ""

## 导航项列表，每项为 [label, key]
func get_nav_items() -> Array:
	return []

## 构建右侧内容区
func _build_content(_content: VBoxContainer, _sub_type: String, _meta: Dictionary = {}) -> void:
	pass
