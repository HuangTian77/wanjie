## IDE底部面板 - 复刻 Godot 4.7.1 Bottom Panel
## 标签按钮行: 输出 | 调试器 | 音频 | 动画 + 折叠按钮
## 错误计数badge(红色数字)、可折叠
extends VBoxContainer

signal error_clicked(line: int)

const IDETheme = preload("res://scripts/editor/ide/ide_theme.gd")

var _tab_buttons: Array[Button] = []
var _output_log: RichTextLabel
var _debugger_tree: Tree
var _audio_placeholder: Control
var _anim_placeholder: Control
var _panels: Array[Control] = []
var _content_container: PanelContainer
var _current_tab: int = 0
var _collapsed: bool = false
var _error_count: int = 0
var _warning_count: int = 0
var _badge_labels: Dictionary = {}  # tab_index -> Label
var _collapse_btn: Button

func _ready() -> void:
	add_theme_constant_override("separation", 0)
	_build_ui()

func _build_ui() -> void:
	# === 标签按钮行 (Godot风格: 底部面板标签在上方) ===
	var tab_bar_panel := PanelContainer.new()
	var tab_sb := StyleBoxFlat.new()
	tab_sb.bg_color = IDETheme.C_BG_TOOL
	tab_sb.border_width_top = 1
	tab_sb.border_color = IDETheme.C_BORDER
	tab_sb.content_margin_left = 4.0
	tab_sb.content_margin_top = 2.0
	tab_sb.content_margin_right = 4.0
	tab_sb.content_margin_bottom = 0.0
	tab_bar_panel.add_theme_stylebox_override("panel", tab_sb)
	tab_bar_panel.custom_minimum_size.y = 28
	add_child(tab_bar_panel)

	var tab_hbox := HBoxContainer.new()
	tab_hbox.add_theme_constant_override("separation", 0)
	tab_bar_panel.add_child(tab_hbox)

	# 标签按钮
	_add_tab_button(tab_hbox, "📄 输出", 0)
	_add_tab_button(tab_hbox, "🐞 调试器", 1)
	_add_tab_button(tab_hbox, "🔊 音频", 2)
	_add_tab_button(tab_hbox, "🎞 动画", 3)

	# 弹性间隔
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_hbox.add_child(spacer)

	# 清除按钮
	var clear_btn := Button.new()
	clear_btn.text = "清除"
	clear_btn.tooltip_text = "清除当前面板内容"
	clear_btn.flat = true
	clear_btn.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_SMALL)
	clear_btn.add_theme_color_override("font_color", IDETheme.C_TEXT_DIM)
	clear_btn.pressed.connect(_on_clear_pressed)
	tab_hbox.add_child(clear_btn)

	# 折叠/展开按钮
	_collapse_btn = Button.new()
	_collapse_btn.text = "▼"
	_collapse_btn.tooltip_text = "折叠面板 (Ctrl+Shift+X)"
	_collapse_btn.flat = true
	_collapse_btn.add_theme_color_override("font_color", IDETheme.C_TEXT_DIM)
	_collapse_btn.pressed.connect(toggle_collapse)
	tab_hbox.add_child(_collapse_btn)

	# === 内容区域 ===
	_content_container = PanelContainer.new()
	_content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var content_sb := StyleBoxFlat.new()
	content_sb.bg_color = IDETheme.C_BG_BASE
	content_sb.content_margin_left = 4.0
	content_sb.content_margin_top = 2.0
	content_sb.content_margin_right = 4.0
	content_sb.content_margin_bottom = 2.0
	_content_container.add_theme_stylebox_override("panel", content_sb)
	add_child(_content_container)

	# 输出面板
	_output_log = RichTextLabel.new()
	_output_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_output_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_output_log.scroll_following = true
	_output_log.bbcode_enabled = true
	_output_log.add_theme_font_size_override("normal_font_size", IDETheme.FONT_SIZE_UI)
	_output_log.add_theme_color_override("default_color", IDETheme.C_TEXT)
	_content_container.add_child(_output_log)
	_panels.append(_output_log)

	# 调试器面板 (错误/警告Tree)
	_debugger_tree = Tree.new()
	_debugger_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_debugger_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_debugger_tree.hide_root = true
	_debugger_tree.columns = 3
	_debugger_tree.column_titles_visible = true
	_debugger_tree.set_column_title(0, "行号")
	_debugger_tree.set_column_title(1, "类型")
	_debugger_tree.set_column_title(2, "描述")
	_debugger_tree.set_column_custom_minimum_width(0, 50)
	_debugger_tree.set_column_custom_minimum_width(1, 60)
	_debugger_tree.set_column_expand(0, false)
	_debugger_tree.set_column_expand(1, false)
	_debugger_tree.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_SMALL)
	_debugger_tree.add_theme_color_override("font_color", IDETheme.C_TEXT)
	var tree_sb := StyleBoxFlat.new()
	tree_sb.bg_color = IDETheme.C_BG_BASE
	_debugger_tree.add_theme_stylebox_override("panel", tree_sb)
	_debugger_tree.item_selected.connect(_on_error_selected)
	_debugger_tree.visible = false
	_content_container.add_child(_debugger_tree)
	_panels.append(_debugger_tree)

	# 音频面板（资源扫描: res://assets/audio）
	_audio_placeholder = _make_resource_panel("🔊 音频资源", "res://assets/audio")
	_content_container.add_child(_audio_placeholder)
	_panels.append(_audio_placeholder)

	# 动画面板（资源扫描: res://assets/animations）
	_anim_placeholder = _make_resource_panel("🎬 动画资源", "res://assets/animations")
	_content_container.add_child(_anim_placeholder)
	_panels.append(_anim_placeholder)

	_select_tab(0)

## 构建资源扫描面板（音频/动画占位升级: 标题 + 资源列表 + 空状态提示）
func _make_resource_panel(title: String, scan_dir: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)
	var header := Label.new()
	header.text = title
	header.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_SMALL)
	header.add_theme_color_override("font_color", IDETheme.C_ACCENT)
	vbox.add_child(header)
	var items := _scan_dir(scan_dir)
	if items.is_empty():
		var hint := Label.new()
		hint.text = "暂无资源\n将资源文件放入 %s 后自动显示" % scan_dir
		hint.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_SMALL)
		hint.add_theme_color_override("font_color", IDETheme.C_TEXT_DIM)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD
		vbox.add_child(hint)
	else:
		var list := ItemList.new()
		list.size_flags_vertical = Control.SIZE_EXPAND_FILL
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_SMALL)
		for it in items:
			list.add_item(it)
		vbox.add_child(list)
	return panel

## 扫描目录下的资源文件名
func _scan_dir(dir_path: String) -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return result
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry != "." and entry != ".." and not entry.ends_with(".import") and not entry.begins_with("."):
			result.append(entry)
		entry = dir.get_next()
	result.sort()
	return result

func _add_tab_button(parent: HBoxContainer, text: String, tab_index: int) -> void:
	var btn := Button.new()
	btn.text = text
	btn.toggle_mode = true
	btn.flat = true
	btn.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_UI)
	btn.add_theme_color_override("font_color", IDETheme.C_TEXT_DIM)
	btn.add_theme_color_override("font_pressed_color", IDETheme.C_TEXT)
	var btn_sb := StyleBoxFlat.new()
	btn_sb.bg_color = Color(0, 0, 0, 0)
	btn_sb.content_margin_left = 10.0
	btn_sb.content_margin_right = 10.0
	btn_sb.content_margin_top = 4.0
	btn_sb.content_margin_bottom = 4.0
	btn.add_theme_stylebox_override("normal", btn_sb)
	var pressed_sb := StyleBoxFlat.new()
	pressed_sb.bg_color = Color(0, 0, 0, 0)
	pressed_sb.border_width_bottom = 2
	pressed_sb.border_color = IDETheme.C_ACCENT
	pressed_sb.content_margin_left = 10.0
	pressed_sb.content_margin_right = 10.0
	pressed_sb.content_margin_top = 4.0
	pressed_sb.content_margin_bottom = 2.0
	btn.add_theme_stylebox_override("pressed", pressed_sb)
	btn.pressed.connect(func(): _select_tab(tab_index))
	parent.add_child(btn)
	_tab_buttons.append(btn)

	# Badge标签 (错误计数)
	var badge := Label.new()
	badge.text = ""
	badge.add_theme_font_size_override("font_size", 9)
	badge.add_theme_color_override("font_color", IDETheme.C_RED)
	badge.visible = false
	parent.add_child(badge)
	_badge_labels[tab_index] = badge

func _select_tab(tab_index: int) -> void:
	_current_tab = tab_index
	for i in _panels.size():
		_panels[i].visible = (i == tab_index)
	for i in _tab_buttons.size():
		_tab_buttons[i].button_pressed = (i == tab_index)
	# 如果面板折叠了，选择标签时自动展开
	if _collapsed:
		toggle_collapse()

func _on_clear_pressed() -> void:
	match _current_tab:
		0: _output_log.clear()
		1:
			_debugger_tree.clear()
			_error_count = 0
			_warning_count = 0
			_update_badges()

# === 折叠 ===

func toggle_collapse() -> void:
	if _content_container == null:
		return
	_collapsed = not _collapsed
	_content_container.visible = not _collapsed
	_collapse_btn.text = "▲" if _collapsed else "▼"
	_collapse_btn.tooltip_text = "展开面板 (Ctrl+Shift+X)" if _collapsed else "折叠面板 (Ctrl+Shift+X)"

func is_collapsed() -> bool:
	return _collapsed

# === 公共接口 (保持兼容) ===

func log_message(msg: String, color: Color = IDETheme.C_TEXT) -> void:
	if _output_log == null:
		return
	var timestamp := Time.get_time_string_from_system()
	_output_log.push_color(Color(color.r, color.g, color.b, 0.5))
	_output_log.append_text("[%s] " % timestamp)
	_output_log.pop()
	_output_log.push_color(color)
	_output_log.append_text(msg + "\n")
	_output_log.pop()

func log_error(msg: String, line: int = -1) -> void:
	log_message("✖ " + msg, IDETheme.C_RED)
	_add_debugger_entry(msg, line, "错误")
	_error_count += 1
	_update_badges()

func log_warning(msg: String, line: int = -1) -> void:
	log_message("⚠ " + msg, IDETheme.C_YELLOW)
	_add_debugger_entry(msg, line, "警告")
	_warning_count += 1
	_update_badges()

func clear_errors() -> void:
	if _debugger_tree == null:
		return
	_debugger_tree.clear()
	_error_count = 0
	_warning_count = 0
	_update_badges()

func switch_to_tab(tab_index: int) -> void:
	if tab_index >= 0 and tab_index < _panels.size():
		_select_tab(tab_index)

# === 内部 ===

func _add_debugger_entry(msg: String, line: int, entry_type: String) -> void:
	var root := _debugger_tree.get_root()
	if root == null:
		root = _debugger_tree.create_item()
	var item := _debugger_tree.create_item(root)
	item.set_text(0, str(line + 1) if line >= 0 else "-")
	item.set_text(1, entry_type)
	item.set_text(2, msg)
	item.set_metadata(0, line)
	if entry_type == "错误":
		item.set_custom_color(0, IDETheme.C_RED)
		item.set_custom_color(1, IDETheme.C_RED)
		item.set_custom_color(2, IDETheme.C_RED)
	else:
		item.set_custom_color(0, IDETheme.C_YELLOW)
		item.set_custom_color(1, IDETheme.C_YELLOW)
		item.set_custom_color(2, IDETheme.C_YELLOW)

func _on_error_selected() -> void:
	var item := _debugger_tree.get_selected()
	if item == null:
		return
	var line = item.get_metadata(0)
	if line != null and line is int and line >= 0:
		error_clicked.emit(line)

func _update_badges() -> void:
	# 调试器标签badge: 错误数(红) + 警告数(黄)
	var badge: Label = _badge_labels.get(1)
	if badge:
		var total := _error_count + _warning_count
		if total > 0:
			var parts: Array[String] = []
			if _error_count > 0:
				parts.append("%d错误" % _error_count)
			if _warning_count > 0:
				parts.append("%d警告" % _warning_count)
			badge.text = " ".join(parts)
			badge.visible = true
			badge.add_theme_color_override("font_color", IDETheme.C_RED if _error_count > 0 else IDETheme.C_YELLOW)
		else:
			badge.text = ""
			badge.visible = false
