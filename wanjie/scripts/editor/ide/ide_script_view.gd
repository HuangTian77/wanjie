## IDE脚本视图 - 复刻 Godot 4.7.1 脚本编辑器中央区域
## 脚本TabBar(可关闭/修改标记) + CodeEdit(GDScript高亮/补全) + 内嵌查找/替换栏
extends VBoxContainer

signal text_changed
signal cursor_moved(line: int, column: int)
signal tab_close_requested(tab_index: int)

const IDETheme = preload("res://scripts/editor/ide/ide_theme.gd")

# === 节点引用 ===
var _tab_bar: TabBar
var _code_edit: CodeEdit
var _find_bar: HBoxContainer
var _find_input: LineEdit
var _replace_input: LineEdit
var _replace_bar: HBoxContainer
var _match_label: Label

# === 状态 ===
var _modified: bool = false
var _last_search: String = ""

func _ready() -> void:
	add_theme_constant_override("separation", 0)
	_build_ui()

func _build_ui() -> void:
	# === 脚本标签栏 ===
	_tab_bar = TabBar.new()
	_tab_bar.tab_close_display_policy = TabBar.CLOSE_BUTTON_SHOW_ACTIVE_ONLY
	_tab_bar.drag_to_rearrange_enabled = true
	_tab_bar.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_UI)
	_tab_bar.add_theme_color_override("font_color", IDETheme.C_TEXT_DIM)
	_tab_bar.add_theme_color_override("font_selected_color", IDETheme.C_TEXT)
	var tab_sb := StyleBoxFlat.new()
	tab_sb.bg_color = IDETheme.C_BG_TAB
	_tab_bar.add_theme_stylebox_override("tab_selected", IDETheme.create_flat_style(IDETheme.C_BG_TAB_ACTIVE))
	_tab_bar.add_theme_stylebox_override("tab_unselected", IDETheme.create_flat_style(IDETheme.C_BG_TAB))
	_tab_bar.add_theme_stylebox_override("panel", tab_sb)
	_tab_bar.tab_close_pressed.connect(func(idx: int): tab_close_requested.emit(idx))
	add_child(_tab_bar)

	# === CodeEdit ===
	_code_edit = _make_code_edit()
	add_child(_code_edit)

	# === 查找栏 (默认隐藏) ===
	_build_find_bar()

func _make_code_edit() -> CodeEdit:
	var ce := CodeEdit.new()
	ce.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ce.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ce.wrap_mode = TextEdit.LINE_WRAPPING_NONE
	ce.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_CODE)
	ce.add_theme_color_override("font_color", IDETheme.C_TEXT)
	ce.add_theme_color_override("background_color", IDETheme.C_BG)
	ce.add_theme_color_override("caret_color", IDETheme.C_CARET)
	ce.add_theme_color_override("selection_color", IDETheme.C_SELECTION)
	ce.add_theme_color_override("current_line_color", IDETheme.C_CURRENT_LINE)
	ce.add_theme_color_override("line_number_color", IDETheme.C_LINE_NUM)
	ce.add_theme_color_override("brace_mismatch_color", IDETheme.C_RED)
	ce.indent_size = 4
	ce.indent_use_spaces = true
	ce.draw_tabs = true
	ce.gutters_draw_line_numbers = true
	ce.gutters_draw_fold_gutter = true
	ce.highlight_current_line = true
	ce.highlight_all_occurrences = true
	ce.code_completion_enabled = true
	ce.auto_brace_completion_enabled = true
	ce.auto_brace_completion_highlight_matching = true
	ce.auto_brace_completion_pairs = {
		"(": ")", "[": "]", "{": "}", "\"": "\"", "'": "'"
	}

	# GDScript语法高亮
	var hl := CodeHighlighter.new()
	_configure_highlighting(hl)
	ce.syntax_highlighter = hl

	ce.text_changed.connect(func():
		_modified = true
		text_changed.emit()
	)
	ce.caret_changed.connect(func():
		cursor_moved.emit(ce.get_caret_line(), ce.get_caret_column())
	)
	ce.code_completion_requested.connect(_on_code_completion_requested)
	return ce

# === 查找/替换栏 ===

func _build_find_bar() -> void:
	_find_bar = HBoxContainer.new()
	_find_bar.add_theme_constant_override("separation", 4)
	var fb_sb := StyleBoxFlat.new()
	fb_sb.bg_color = IDETheme.C_BG_TOOL
	fb_sb.border_width_top = 1
	fb_sb.border_color = IDETheme.C_BORDER
	fb_sb.content_margin_left = 8.0
	fb_sb.content_margin_top = 4.0
	fb_sb.content_margin_right = 8.0
	fb_sb.content_margin_bottom = 4.0
	var fb_panel := PanelContainer.new()
	fb_panel.add_theme_stylebox_override("panel", fb_sb)
	fb_panel.add_child(_find_bar)
	fb_panel.visible = false
	add_child(fb_panel)

	# 查找输入
	var find_lbl := Label.new()
	find_lbl.text = "查找:"
	find_lbl.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_SMALL)
	find_lbl.add_theme_color_override("font_color", IDETheme.C_TEXT_DIM)
	_find_bar.add_child(find_lbl)

	_find_input = LineEdit.new()
	_find_input.custom_minimum_size.x = 200
	_find_input.placeholder_text = "搜索..."
	_find_input.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_UI)
	var input_sb := StyleBoxFlat.new()
	input_sb.bg_color = IDETheme.C_BG_DARKER
	input_sb.content_margin_left = 6.0
	input_sb.content_margin_right = 6.0
	input_sb.content_margin_top = 2.0
	input_sb.content_margin_bottom = 2.0
	_find_input.add_theme_stylebox_override("normal", input_sb)
	_find_input.add_theme_color_override("font_color", IDETheme.C_TEXT)
	_find_input.text_changed.connect(func(_t: String): _find_next(true))
	_find_input.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventKey and ev.pressed:
			if ev.keycode == KEY_ENTER:
				_find_next(ev.shift_pressed == false)
			elif ev.keycode == KEY_ESCAPE:
				hide_find_bar()
	)
	_find_bar.add_child(_find_input)

	# 上一个/下一个
	var btn_prev := Button.new()
	btn_prev.text = "↑"
	btn_prev.tooltip_text = "上一个 (Shift+Enter)"
	btn_prev.flat = true
	IDETheme.style_button(btn_prev)
	btn_prev.pressed.connect(func(): _find_next(false))
	_find_bar.add_child(btn_prev)

	var btn_next := Button.new()
	btn_next.text = "↓"
	btn_next.tooltip_text = "下一个 (Enter)"
	btn_next.flat = true
	IDETheme.style_button(btn_next)
	btn_next.pressed.connect(func(): _find_next(true))
	_find_bar.add_child(btn_next)

	_match_label = Label.new()
	_match_label.text = ""
	_match_label.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_SMALL)
	_match_label.add_theme_color_override("font_color", IDETheme.C_TEXT_DIM)
	_find_bar.add_child(_match_label)

	# 替换切换
	var btn_replace_toggle := Button.new()
	btn_replace_toggle.text = "替换"
	btn_replace_toggle.tooltip_text = "显示替换栏 (Ctrl+H)"
	btn_replace_toggle.flat = true
	IDETheme.style_button(btn_replace_toggle)
	btn_replace_toggle.pressed.connect(func(): _toggle_replace_bar())
	_find_bar.add_child(btn_replace_toggle)

	# 关闭按钮
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_find_bar.add_child(spacer)

	var btn_close := Button.new()
	btn_close.text = "✕"
	btn_close.tooltip_text = "关闭 (Esc)"
	btn_close.flat = true
	IDETheme.style_button(btn_close)
	btn_close.pressed.connect(hide_find_bar)
	_find_bar.add_child(btn_close)

	# === 替换行 ===
	_replace_bar = HBoxContainer.new()
	_replace_bar.add_theme_constant_override("separation", 4)
	_replace_bar.visible = false
	_find_bar.add_child(_replace_bar)

	var replace_lbl := Label.new()
	replace_lbl.text = "替换:"
	replace_lbl.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_SMALL)
	replace_lbl.add_theme_color_override("font_color", IDETheme.C_TEXT_DIM)
	_replace_bar.add_child(replace_lbl)

	_replace_input = LineEdit.new()
	_replace_input.custom_minimum_size.x = 150
	_replace_input.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_UI)
	_replace_input.add_theme_stylebox_override("normal", input_sb.duplicate())
	_replace_input.add_theme_color_override("font_color", IDETheme.C_TEXT)
	_replace_bar.add_child(_replace_input)

	var btn_replace_one := Button.new()
	btn_replace_one.text = "替换"
	btn_replace_one.flat = true
	IDETheme.style_button(btn_replace_one)
	btn_replace_one.pressed.connect(_replace_current)
	_replace_bar.add_child(btn_replace_one)

	var btn_replace_all := Button.new()
	btn_replace_all.text = "全部"
	btn_replace_all.flat = true
	IDETheme.style_button(btn_replace_all)
	btn_replace_all.pressed.connect(_replace_all)
	_replace_bar.add_child(btn_replace_all)

# === 公共接口 ===

func get_code_edit() -> CodeEdit:
	return _code_edit

func get_tab_bar() -> TabBar:
	return _tab_bar

func get_text() -> String:
	if _code_edit == null:
		return ""
	return _code_edit.text

func set_text(text: String) -> void:
	if _code_edit == null:
		return
	_code_edit.text = text
	_modified = false

func is_modified() -> bool:
	return _modified

func set_modified(value: bool) -> void:
	_modified = value

func show_find_bar(with_replace: bool = false) -> void:
	if _find_bar == null:
		return
	_find_bar.get_parent().visible = true
	_replace_bar.visible = with_replace
	_find_input.grab_focus()
	# 如果有选中文本，用它作为搜索词
	if _code_edit.has_selection():
		_find_input.text = _code_edit.get_selected_text()
		_find_next(true)

func hide_find_bar() -> void:
	if _find_bar == null:
		return
	_find_bar.get_parent().visible = false
	_code_edit.grab_focus()

func is_find_bar_visible() -> bool:
	if _find_bar == null:
		return false
	return _find_bar.get_parent().visible

func goto_line(line: int, select_line: bool = true) -> void:
	if _code_edit == null:
		return
	if line >= 0 and line < _code_edit.get_line_count():
		_code_edit.set_caret_line(line)
		_code_edit.set_caret_column(0)
		_code_edit.center_viewport_to_caret()
		if select_line:
			_code_edit.select(line, 0, line, _code_edit.get_line(line).length())

func set_error_lines(error_lines: Array) -> void:
	if _code_edit == null:
		return
	# 先清除所有行背景
	for i in _code_edit.get_line_count():
		_code_edit.set_line_background_color(i, Color(0, 0, 0, 0))
	# 标记错误行
	for line in error_lines:
		if line >= 0 and line < _code_edit.get_line_count():
			_code_edit.set_line_background_color(line, Color(0.9, 0.25, 0.2, 0.12))

func set_warning_lines(warning_lines: Array) -> void:
	if _code_edit == null:
		return
	for line in warning_lines:
		if line >= 0 and line < _code_edit.get_line_count():
			_code_edit.set_line_background_color(line, Color(0.9, 0.8, 0.3, 0.08))

# === 查找逻辑 ===

func _find_next(forward: bool) -> void:
	var search_text := _find_input.text
	if search_text.is_empty():
		_match_label.text = ""
		return
	_last_search = search_text
	var flags := 0  # 区分大小写
	var from_line := _code_edit.get_caret_line()
	var from_col := _code_edit.get_caret_column()
	if forward:
		from_col += 1
	var result := _code_edit.search(search_text, flags, from_line, from_col)
	if result.x == -1:
		# 环绕搜索
		if forward:
			result = _code_edit.search(search_text, flags, 0, 0)
		else:
			result = _code_edit.search(search_text, flags, _code_edit.get_line_count() - 1, _code_edit.get_line(_code_edit.get_line_count() - 1).length())
	if result.x != -1:
		_code_edit.set_caret_line(result.y)
		_code_edit.set_caret_column(result.x)
		_code_edit.select(result.y, result.x, result.y, result.x + search_text.length())
		_code_edit.center_viewport_to_caret()
		_match_label.text = "已定位"
		_match_label.add_theme_color_override("font_color", IDETheme.C_GREEN)
	else:
		_match_label.text = "无匹配"
		_match_label.add_theme_color_override("font_color", IDETheme.C_RED)

func _toggle_replace_bar() -> void:
	_replace_bar.visible = not _replace_bar.visible
	if _replace_bar.visible:
		_replace_input.grab_focus()

func _replace_current() -> void:
	if _code_edit.has_selection() and _code_edit.get_selected_text() == _last_search:
		_code_edit.insert_text_at_caret(_replace_input.text)
		_find_next(true)

func _replace_all() -> void:
	if _last_search.is_empty():
		return
	var original := _code_edit.text
	var replaced := original.replace(_last_search, _replace_input.text)
	if replaced != original:
		_code_edit.text = replaced
		_modified = true
		text_changed.emit()

# === GDScript语法高亮配置 (Godot 4.7.1) ===

func _configure_highlighting(hl: CodeHighlighter) -> void:
	hl.number_color = IDETheme.C_NUMBER
	hl.symbol_color = IDETheme.C_SYMBOL
	hl.function_color = IDETheme.C_FUNCTION
	hl.member_variable_color = IDETheme.C_MEMBER_VAR
	# 控制流
	for kw in ["if", "elif", "else", "for", "while", "break", "continue", "pass", "return", "match", "when"]:
		hl.add_keyword_color(kw, IDETheme.C_CONTROL_FLOW)
	# 声明关键字
	for kw in ["as", "assert", "await", "breakpoint", "class", "class_name", "const", "enum", "extends", "func", "in", "is", "namespace", "preload", "self", "signal", "static", "super", "trait", "var", "void", "yield"]:
		hl.add_keyword_color(kw, IDETheme.C_KEYWORD)
	# 逻辑运算符
	for kw in ["and", "or", "not"]:
		hl.add_keyword_color(kw, IDETheme.C_CONTROL_FLOW)
	# 字面量
	for kw in ["true", "false", "null", "INF", "NAN", "PI", "TAU"]:
		hl.add_keyword_color(kw, IDETheme.C_NUMBER)
	# 基础类型
	for kw in ["int", "float", "bool", "String", "StringName", "NodePath", "Array", "Dictionary", "Variant", "Callable", "Signal"]:
		hl.add_keyword_color(kw, IDETheme.C_BASE_TYPE)
	# 引擎类型
	for kw in ["Vector2", "Vector2i", "Vector3", "Vector3i", "Color", "Node", "Node2D", "Node3D", "Control", "Object", "Resource", "RefCounted", "PackedScene", "Timer", "Area2D", "CharacterBody2D", "RigidBody2D", "Sprite2D", "Label", "Button", "CodeEdit", "TextEdit", "Tree", "ItemList"]:
		hl.add_keyword_color(kw, IDETheme.C_ENGINE_TYPE)
	# 内置函数
	for kw in ["print", "printerr", "push_error", "push_warning", "range", "str", "len", "abs", "min", "max", "clamp", "load", "preload", "typeof", "randi", "randf", "randf_range", "lerp", "snapped"]:
		hl.add_keyword_color(kw, IDETheme.C_FUNCTION)
	# 剧本API关键字
	for kw in ["worldview", "story_event", "random_event", "skill", "currency", "resource", "market", "quest", "dialogue", "battle", "npc", "item", "scene", "trigger", "condition", "effect", "reward"]:
		hl.add_keyword_color(kw, IDETheme.C_API_KEYWORD)
	# 颜色区域
	hl.add_color_region("##", "", IDETheme.C_DOC_COMMENT, true)
	hl.add_color_region("#", "", IDETheme.C_COMMENT, true)
	hl.add_color_region("\"", "\"", IDETheme.C_STRING)
	hl.add_color_region("'", "'", IDETheme.C_STRING)
	hl.add_color_region("&\"", "\"", IDETheme.C_STRING)

# === 自动补全 ===

func _on_code_completion_requested() -> void:
	var word := _get_word_before_caret()
	if word.is_empty():
		return
	var suggestions: Array[String] = []
	# GDScript关键字
	for kw in ["func", "var", "const", "if", "elif", "else", "for", "while", "return", "pass", "break", "continue", "true", "false", "null", "and", "or", "not", "in", "is", "as", "void", "int", "float", "bool", "String", "Array", "Dictionary", "Vector2", "Vector3", "self", "super", "signal", "enum", "class", "extends", "static", "await", "match", "preload", "assert", "class_name"]:
		if kw.begins_with(word.to_lower()) and kw != word:
			suggestions.append(kw)
	# 内置函数
	for kw in ["print", "printerr", "range", "str", "len", "abs", "min", "max", "clamp", "load", "preload", "typeof", "randi", "randf", "lerp"]:
		if kw.begins_with(word.to_lower()) and kw != word:
			suggestions.append(kw)
	# 剧本API
	for kw in ["worldview", "story_event", "random_event", "skill", "currency", "resource", "market", "quest", "dialogue", "battle", "npc", "item", "scene", "trigger", "condition", "effect", "reward"]:
		if kw.begins_with(word.to_lower()) and kw != word:
			suggestions.append(kw)
	# 当前文件中已定义的函数和变量
	var text := _code_edit.text
	for line_text in text.split("\n"):
		var stripped := line_text.strip_edges()
		if stripped.begins_with("func "):
			var fname := stripped.substr(5).split("(")[0].strip_edges()
			if fname.begins_with(word) and fname != word and not suggestions.has(fname):
				suggestions.append(fname)
		elif stripped.begins_with("var "):
			var vname := stripped.substr(4).split(":")[0].split("=")[0].strip_edges()
			if vname.begins_with(word) and vname != word and not suggestions.has(vname):
				suggestions.append(vname)
	suggestions.sort()
	for s in suggestions:
		_code_edit.add_code_completion_option(CodeEdit.KIND_PLAIN_TEXT, s, s)
	_code_edit.update_code_completion_options(true)

func _get_word_before_caret() -> String:
	var line: int = _code_edit.get_caret_line()
	var col: int = _code_edit.get_caret_column()
	var line_text: String = _code_edit.get_line(line)
	var start: int = col
	while start > 0 and (line_text[start - 1].is_valid_identifier() or line_text[start - 1] == "_"):
		start -= 1
	return line_text.substr(start, col - start)

# === 快捷键处理 ===

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.ctrl_pressed:
			match event.keycode:
				KEY_F:
					show_find_bar(false)
					get_viewport().set_input_as_handled()
				KEY_H:
					show_find_bar(true)
					get_viewport().set_input_as_handled()
