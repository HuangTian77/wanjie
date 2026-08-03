## 剧本设置对话框（纯代码动态构建）
## 用户创建新剧本前配置：名称、题材、编辑器模式、运行类型、标签
class_name ScriptSetupDialog
extends Control

## 用户点击"开始编辑"后发出，携带完整配置
signal setup_completed(config: Dictionary)
signal cancelled

## === 内部节点引用 ===
var _name_input: LineEdit
var _template_option: OptionButton
var _mode_group: Array[CheckBox] = []  # visual / code / mud
var _run_group: Array[CheckBox] = []   # local / online / server
var _tags_container: HBoxContainer
var _tag_input: LineEdit
var _start_btn: Button
var _cancel_btn: Button
var _desc_label: RichTextLabel

## 当前标签列表
var _tags: Array[String] = []
## 模板数据缓存
var _templates: Array[Dictionary] = []

func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	_templates = ScriptDataManager.get_templates()
	_populate_templates()

## === UI 构建 ===
func _build_ui() -> void:
	# 半透明遮罩
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.5)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	# 居中容器（铺满全屏，自动居中子节点）
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	# 主面板
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 560)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = ThemeManager.C_BG_SECONDARY
	panel_style.border_color = ThemeManager.C_ACCENT
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(12)
	panel_style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(480, 520)
	panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(vbox)

	# 标题
	var title := Label.new()
	title.text = "📜 新建剧本设置"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", ThemeManager.C_ACCENT)
	vbox.add_child(title)

	_add_separator(vbox)

	# 1. 剧本名称
	_add_section_label(vbox, "剧本名称")
	_name_input = LineEdit.new()
	_name_input.text = "未命名剧本"
	_name_input.placeholder_text = "输入剧本名称..."
	_name_input.custom_minimum_size.x = 300
	vbox.add_child(_name_input)

	# 2. 剧本题材
	_add_section_label(vbox, "剧本题材")
	_template_option = OptionButton.new()
	_template_option.item_selected.connect(_on_template_changed)
	vbox.add_child(_template_option)
	_desc_label = RichTextLabel.new()
	_desc_label.bbcode_enabled = true
	_desc_label.custom_minimum_size = Vector2(0, 48)
	_desc_label.fit_content = true
	_desc_label.add_theme_color_override("default_color", ThemeManager.C_TEXT_SECONDARY)
	vbox.add_child(_desc_label)

	_add_separator(vbox)

	# 3. 编辑器模式
	_add_section_label(vbox, "编辑器模式")
	var mode_box := VBoxContainer.new()
	mode_box.add_theme_constant_override("separation", 4)
	vbox.add_child(mode_box)
	var mode_defs: Array[Array] = [
		["📊 可视化编辑器", "表单式拖拽编辑，适合新手"],
		["💻 核心编辑器", "IDE 代码模式，GDScript 风格全功能编辑"],
		["🖥 MUD编辑器", "MUD 数据表编辑，适合传统文字游戏"],
	]
	for i in mode_defs.size():
		var cb := CheckBox.new()
		cb.text = mode_defs[i][0]
		cb.tooltip_text = mode_defs[i][1]
		cb.button_pressed = (i == 0)
		cb.toggled.connect(_on_mode_toggled.bind(i))
		mode_box.add_child(cb)
		_mode_group.append(cb)

	_add_separator(vbox)

	# 4. 剧本运行类型
	_add_section_label(vbox, "剧本运行类型")
	var run_box := VBoxContainer.new()
	run_box.add_theme_constant_override("separation", 4)
	vbox.add_child(run_box)
	var run_defs: Array[Array] = [
		["单机剧本", "本地运行，无需网络"],
		["在线游戏剧本", "标记为在线，支持多人体验"],
		["服务器游戏剧本", "关联 MUD 数据导出，服务器驱动"],
	]
	for i in run_defs.size():
		var cb := CheckBox.new()
		cb.text = run_defs[i][0]
		cb.tooltip_text = run_defs[i][1]
		cb.button_pressed = (i == 0)
		cb.toggled.connect(_on_run_toggled.bind(i))
		run_box.add_child(cb)
		_run_group.append(cb)

	_add_separator(vbox)

	# 5. 剧本标签
	_add_section_label(vbox, "剧本标签")
	var tag_hbox := HBoxContainer.new()
	tag_hbox.add_theme_constant_override("separation", 6)
	vbox.add_child(tag_hbox)
	_tag_input = LineEdit.new()
	_tag_input.placeholder_text = "输入标签后按回车添加..."
	_tag_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tag_input.text_submitted.connect(_on_tag_submitted)
	tag_hbox.add_child(_tag_input)
	var add_tag_btn := Button.new()
	add_tag_btn.text = "添加"
	add_tag_btn.pressed.connect(func(): _on_tag_submitted(_tag_input.text))
	tag_hbox.add_child(add_tag_btn)
	# 标签显示容器（FlowContainer 效果用 HBox + 自动换行）
	_tags_container = HBoxContainer.new()
	_tags_container.add_theme_constant_override("separation", 6)
	vbox.add_child(_tags_container)

	_add_separator(vbox)

	# 底部按钮
	var btn_box := HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_box)
	_cancel_btn = Button.new()
	_cancel_btn.text = "取消"
	_cancel_btn.custom_minimum_size = Vector2(100, 38)
	_cancel_btn.pressed.connect(_on_cancel_pressed)
	btn_box.add_child(_cancel_btn)
	_start_btn = Button.new()
	_start_btn.text = "🚀 创建剧本"
	_start_btn.custom_minimum_size = Vector2(140, 38)
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = ThemeManager.C_ACCENT
	btn_style.set_corner_radius_all(6)
	btn_style.set_content_margin_all(8)
	_start_btn.add_theme_stylebox_override("normal", btn_style)
	var btn_hover := btn_style.duplicate()
	btn_hover.bg_color = ThemeManager.C_ACCENT_DARK
	_start_btn.add_theme_stylebox_override("hover", btn_hover)
	_start_btn.pressed.connect(_on_start_pressed)
	btn_box.add_child(_start_btn)

## === 公共接口 ===
func show_dialog() -> void:
	# 重置状态
	_name_input.text = "未命名剧本"
	_tags.clear()
	_refresh_tags_display()
	if _template_option.item_count > 0:
		_template_option.select(0)
		_on_template_changed(0)
	for i in _mode_group.size():
		_mode_group[i].button_pressed = (i == 0)
	for i in _run_group.size():
		_run_group[i].button_pressed = (i == 0)
	visible = true

## === 内部方法 ===
func _populate_templates() -> void:
	_template_option.clear()
	_template_option.add_item("空白剧本", 0)
	for t in _templates:
		# 有 icon 的游戏类型模板带图标显示
		var icon: String = str(t.get("icon", ""))
		_template_option.add_item(("%s %s" % [icon, t["name"]]) if icon != "" else t["name"])
	if _template_option.item_count > 0:
		_template_option.select(0)
		_desc_label.text = "从零开始，自由创作你的世界"

func _add_separator(parent: Control) -> void:
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	parent.add_child(sep)

func _add_section_label(parent: Control, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", ThemeManager.C_ACCENT)
	parent.add_child(lbl)

## === 信号处理 ===
func _on_template_changed(index: int) -> void:
	if index == 0:
		_desc_label.text = "从零开始，自由创作你的世界"
	elif index - 1 < _templates.size():
		var t: Dictionary = _templates[index - 1]
		_desc_label.text = t.get("description", "")
		# 自动添加模板推荐标签
		_tags.clear()
		var tpl_tags: Array = t.get("tags", [])
		for tag in tpl_tags:
			_tags.append(str(tag))
		_refresh_tags_display()

func _on_mode_toggled(_pressed: bool, index: int) -> void:
	# 单选互斥
	for i in _mode_group.size():
		if i != index:
			_mode_group[i].set_pressed_no_signal(false)
	_mode_group[index].set_pressed_no_signal(true)

func _on_run_toggled(_pressed: bool, index: int) -> void:
	# 单选互斥
	for i in _run_group.size():
		if i != index:
			_run_group[i].set_pressed_no_signal(false)
	_run_group[index].set_pressed_no_signal(true)

func _on_tag_submitted(text: String) -> void:
	var tag := text.strip_edges()
	if tag.is_empty():
		return
	if _tags.has(tag):
		ToastManager.warning("标签 \"%s\" 已存在" % tag)
		return
	if _tags.size() >= 10:
		ToastManager.warning("最多添加 10 个标签")
		return
	_tags.append(tag)
	_tag_input.text = ""
	_refresh_tags_display()

func _refresh_tags_display() -> void:
	for child in _tags_container.get_children():
		child.queue_free()
	for i in _tags.size():
		var tag_btn := Button.new()
		tag_btn.text = "× " + _tags[i]
		tag_btn.tooltip_text = "点击删除标签"
		tag_btn.add_theme_font_size_override("font_size", 12)
		var tag_style := StyleBoxFlat.new()
		tag_style.bg_color = ThemeManager.C_ACCENT * Color(1, 1, 1, 0.18)
		tag_style.set_corner_radius_all(4)
		tag_style.set_content_margin_all(4)
		tag_btn.add_theme_stylebox_override("normal", tag_style)
		tag_btn.pressed.connect(_on_remove_tag.bind(i))
		_tags_container.add_child(tag_btn)

func _on_remove_tag(index: int) -> void:
	if index < _tags.size():
		_tags.remove_at(index)
		_refresh_tags_display()

func _on_start_pressed() -> void:
	var script_name := _name_input.text.strip_edges()
	if script_name.is_empty():
		ToastManager.warning("请输入剧本名称")
		return
	# 收集配置
	var template_id := ""
	var template_idx := _template_option.selected
	if template_idx > 0 and template_idx - 1 < _templates.size():
		template_id = _templates[template_idx - 1]["id"]
	var mode_idx := 0
	for i in _mode_group.size():
		if _mode_group[i].button_pressed:
			mode_idx = i
			break
	var editor_modes: Array[String] = ["visual", "code", "mud"]
	var editor_mode := editor_modes[mode_idx]
	var run_idx := 0
	for i in _run_group.size():
		if _run_group[i].button_pressed:
			run_idx = i
			break
	var run_types: Array[String] = ["local", "online", "server"]
	var run_type := run_types[run_idx]

	var config := {
		"name": script_name,
		"template_id": template_id,
		"editor_mode": editor_mode,
		"run_type": run_type,
		"tags": _tags.duplicate(),
	}
	visible = false
	setup_completed.emit(config)

func _on_cancel_pressed() -> void:
	visible = false
	cancelled.emit()
