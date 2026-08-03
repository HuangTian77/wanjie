## IDE脚本面板 - 复刻 Godot 4.7.1 脚本编辑器左侧面板
## 上半: 筛选脚本(打开的脚本列表, 模糊匹配) | 下半: 筛选方法(当前脚本方法大纲, 点击跳转)
## Godot行为: 大小写不敏感 + 子序列模糊匹配(输入"btn"匹配"button.gd")
extends VBoxContainer

signal script_selected(index: int)   # 选中某脚本(真实tab索引)
signal method_selected(line: int)    # 选中某方法(跳转到该行)

const IDETheme = preload("res://scripts/editor/ide/ide_theme.gd")

# === 节点引用 ===
var _filter_scripts: LineEdit
var _script_list: ItemList
var _current_file_label: Label
var _btn_sort: Button
var _filter_methods: LineEdit
var _method_list: ItemList

# === 数据 ===
var _scripts: Array = []    # [{"name": String, "modified": bool}]
var _methods: Array = []    # [{"name": String, "line": int}]
var _current_script: String = ""
var _sort_alphabetical: bool = false   # false=按出现顺序(Godot默认)

func _ready() -> void:
	add_theme_constant_override("separation", 0)
	custom_minimum_size.x = IDETheme.SCRIPT_PANEL_MIN_WIDTH
	_build_ui()

func _build_ui() -> void:
	# 面板背景
	var sb := StyleBoxFlat.new()
	sb.bg_color = IDETheme.C_BG_BASE
	sb.border_width_right = 1
	sb.border_color = IDETheme.C_BORDER
	add_theme_stylebox_override("panel", sb)

	# ===== 上半: 筛选脚本 =====
	_filter_scripts = _make_filter_input("筛选脚本...")
	_filter_scripts.text_changed.connect(func(_t: String): _refresh_script_list())
	add_child(_wrap_in_panel(_filter_scripts))

	_script_list = ItemList.new()
	_script_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_script_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_script_list.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_UI)
	_script_list.add_theme_color_override("font_color", IDETheme.C_TEXT)
	_script_list.add_theme_color_override("font_selected_color", Color(1, 1, 1, 1))
	_script_list.add_theme_stylebox_override("selected", IDETheme.create_flat_style(IDETheme.C_BG_HIGHLIGHT, 0))
	_script_list.add_theme_stylebox_override("selected_focus", IDETheme.create_flat_style(IDETheme.C_BG_HIGHLIGHT, 0))
	_script_list.item_selected.connect(_on_script_item_selected)
	add_child(_script_list)

	# ===== 分隔: 当前文件名 + 排序按钮 =====
	var file_bar := HBoxContainer.new()
	file_bar.add_theme_constant_override("separation", 4)
	var fb_sb := StyleBoxFlat.new()
	fb_sb.bg_color = IDETheme.C_BG_TOOL
	fb_sb.border_width_top = 1
	fb_sb.border_width_bottom = 1
	fb_sb.border_color = IDETheme.C_BORDER
	fb_sb.content_margin_left = 6.0
	fb_sb.content_margin_top = 3.0
	fb_sb.content_margin_right = 4.0
	fb_sb.content_margin_bottom = 3.0
	var fb_panel := PanelContainer.new()
	fb_panel.add_theme_stylebox_override("panel", fb_sb)
	fb_panel.add_child(file_bar)
	add_child(fb_panel)

	_current_file_label = Label.new()
	_current_file_label.text = ""
	_current_file_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_current_file_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_current_file_label.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_SMALL)
	_current_file_label.add_theme_color_override("font_color", IDETheme.C_TEXT_DIM)
	file_bar.add_child(_current_file_label)

	_btn_sort = Button.new()
	_btn_sort.text = "⇅"
	_btn_sort.tooltip_text = "切换方法排序 (按出现顺序/按字母顺序)"
	_btn_sort.flat = true
	_btn_sort.custom_minimum_size = Vector2(22, 20)
	IDETheme.style_button(_btn_sort)
	_btn_sort.pressed.connect(_on_sort_pressed)
	file_bar.add_child(_btn_sort)

	# ===== 下半: 筛选方法 =====
	_filter_methods = _make_filter_input("筛选方法...")
	_filter_methods.text_changed.connect(func(_t: String): _refresh_method_list())
	add_child(_wrap_in_panel(_filter_methods))

	_method_list = ItemList.new()
	_method_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_method_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_method_list.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_UI)
	_method_list.add_theme_color_override("font_color", IDETheme.C_FUNCTION)
	_method_list.add_theme_color_override("font_selected_color", Color(1, 1, 1, 1))
	_method_list.add_theme_stylebox_override("selected", IDETheme.create_flat_style(IDETheme.C_BG_HIGHLIGHT, 0))
	_method_list.add_theme_stylebox_override("selected_focus", IDETheme.create_flat_style(IDETheme.C_BG_HIGHLIGHT, 0))
	_method_list.item_selected.connect(_on_method_item_selected)
	add_child(_method_list)

# === 辅助构建 ===

func _make_filter_input(placeholder: String) -> LineEdit:
	var le := LineEdit.new()
	le.placeholder_text = placeholder
	le.clear_button_enabled = true
	le.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_UI)
	le.add_theme_color_override("font_color", IDETheme.C_TEXT)
	le.add_theme_color_override("placeholder_color", IDETheme.C_TEXT_DISABLED)
	var input_sb := StyleBoxFlat.new()
	input_sb.bg_color = IDETheme.C_BG_DARKER
	input_sb.content_margin_left = 6.0
	input_sb.content_margin_right = 6.0
	input_sb.content_margin_top = 3.0
	input_sb.content_margin_bottom = 3.0
	le.add_theme_stylebox_override("normal", input_sb)
	le.add_theme_stylebox_override("focus", input_sb.duplicate())
	return le

func _wrap_in_panel(control: Control) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = IDETheme.C_BG_BASE
	sb.content_margin_left = 4.0
	sb.content_margin_right = 4.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(control)
	return p

# ============================================================
# 公共接口
# ============================================================

## 设置打开的脚本列表 [{"name": String, "modified": bool}]
func set_scripts(scripts: Array) -> void:
	_scripts = scripts
	_refresh_script_list()

## 设置当前脚本的方法大纲 [{"name": String, "line": int}]
func set_methods(methods: Array) -> void:
	_methods = methods
	_refresh_method_list()

## 设置当前脚本名
func set_current_script(script_name: String) -> void:
	_current_script = script_name
	if _current_file_label == null:
		return
	_current_file_label.text = script_name
	# 在脚本列表中高亮当前脚本
	var filter := _filter_scripts.text
	for i in _script_list.item_count:
		var real_idx: int = _script_list.get_item_metadata(i)
		if real_idx >= 0 and real_idx < _scripts.size():
			if _scripts[real_idx].get("name", "") == script_name:
				_script_list.select(i, false)
				return

# ============================================================
# 列表刷新 (带模糊筛选)
# ============================================================

func _refresh_script_list() -> void:
	if _script_list == null:
		return
	_script_list.clear()
	var filter := _filter_scripts.text
	for i in _scripts.size():
		var s: Dictionary = _scripts[i]
		var sname: String = s.get("name", "")
		if _fuzzy_match(filter, sname):
			var display := sname
			if s.get("modified", false):
				display += " *"
			_script_list.add_item(display)
			_script_list.set_item_metadata(_script_list.item_count - 1, i)
	# 重新高亮当前脚本
	set_current_script(_current_script)

func _refresh_method_list() -> void:
	if _method_list == null:
		return
	_method_list.clear()
	var filter := _filter_methods.text
	var methods: Array = _methods.duplicate()
	if _sort_alphabetical:
		methods.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return a.get("name", "") < b.get("name", "")
		)
	for m in methods:
		var mname: String = m.get("name", "")
		if _fuzzy_match(filter, mname):
			_method_list.add_item(mname)
			_method_list.set_item_metadata(_method_list.item_count - 1, m.get("line", 0))

## Godot式模糊匹配: 大小写不敏感 + 子序列匹配 ("btn" 匹配 "button.gd")
func _fuzzy_match(pattern: String, text: String) -> bool:
	if pattern.is_empty():
		return true
	var p := pattern.to_lower()
	var t := text.to_lower()
	var pi := 0
	for ci in t.length():
		if t[ci] == p[pi]:
			pi += 1
			if pi >= p.length():
				return true
	return false

# ============================================================
# 交互回调
# ============================================================

func _on_script_item_selected(index: int) -> void:
	var real_idx: int = _script_list.get_item_metadata(index)
	script_selected.emit(real_idx)

func _on_method_item_selected(index: int) -> void:
	var line: int = _method_list.get_item_metadata(index)
	method_selected.emit(line)

func _on_sort_pressed() -> void:
	_sort_alphabetical = not _sort_alphabetical
	_btn_sort.text = "⇅" if _sort_alphabetical else "⇅"
	_btn_sort.tooltip_text = ("按字母顺序" if _sort_alphabetical else "按出现顺序") + " (点击切换)"
	_refresh_method_list()
