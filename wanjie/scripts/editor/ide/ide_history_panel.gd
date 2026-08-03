## IDE历史面板 - 对标 Godot 4.7.1 撤销历史
## 显示操作历史列表, 高亮当前位置, 灰显已撤销项
extends VBoxContainer

signal history_entry_clicked(index: int)

const IDETheme = preload("res://scripts/editor/ide/ide_theme.gd")

var _list_box: VBoxContainer
var _header: Label
var _entries: Array = []

func _ready() -> void:
	add_theme_constant_override("separation", 0)
	_build_ui()

func _build_ui() -> void:
	# 标题栏
	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 4)
	var header_sb := StyleBoxFlat.new()
	header_sb.bg_color = IDETheme.C_BG_TOOL
	header_sb.border_width_bottom = 1
	header_sb.border_color = IDETheme.C_BORDER
	header_sb.content_margin_left = 8.0
	header_sb.content_margin_top = 4.0
	header_sb.content_margin_bottom = 4.0
	var header_panel := PanelContainer.new()
	header_panel.add_theme_stylebox_override("panel", header_sb)
	header_panel.add_child(header_hbox)
	add_child(header_panel)

	_header = Label.new()
	_header.text = "操作历史"
	_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_UI)
	_header.add_theme_color_override("font_color", IDETheme.C_TEXT)
	header_hbox.add_child(_header)

	# 列表滚动区
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_list_box = VBoxContainer.new()
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_box.add_theme_constant_override("separation", 0)
	scroll.add_child(_list_box)

# === 公共接口 ===

## 设置历史条目 [{"action": String, "current": bool, "undone": bool}]
func set_history(entries: Array) -> void:
	_entries = entries
	_header.text = "操作历史 (%d)" % entries.size()
	_refresh()

func _refresh() -> void:
	for child in _list_box.get_children():
		child.queue_free()
	if _entries.is_empty():
		var hint := Label.new()
		hint.text = "暂无操作记录\n\n对场景的编辑操作\n(添加/删除/移动/属性修改)\n将显示在此处"
		hint.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_SMALL)
		hint.add_theme_color_override("font_color", IDETheme.C_TEXT_DISABLED)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var sb := StyleBoxFlat.new()
		sb.content_margin_top = 12.0
		hint.add_theme_stylebox_override("normal", sb)
		_list_box.add_child(hint)
		return
	# 从新到旧显示
	for i in range(_entries.size() - 1, -1, -1):
		_list_box.add_child(_make_entry_row(_entries[i], i))

func _make_entry_row(entry: Dictionary, index: int) -> Control:
	var btn := Button.new()
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.flat = true
	var is_current: bool = entry.get("current", false)
	var is_undone: bool = entry.get("undone", false)
	var prefix: String = "▶ " if is_current else "  "
	btn.text = prefix + str(entry.get("action", ""))
	btn.tooltip_text = "点击跳转: %s" % str(entry.get("action", ""))
	btn.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_SMALL)

	var sb := StyleBoxFlat.new()
	sb.content_margin_left = 6.0
	sb.content_margin_top = 2.0
	sb.content_margin_bottom = 2.0
	if is_current:
		sb.bg_color = IDETheme.C_BG_HIGHLIGHT
		btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	elif is_undone:
		btn.add_theme_color_override("font_color", IDETheme.C_TEXT_DISABLED)
	else:
		btn.add_theme_color_override("font_color", IDETheme.C_TEXT_DIM)
	btn.add_theme_stylebox_override("normal", sb)
	var hover := sb.duplicate()
	hover.bg_color = IDETheme.C_BG_HIGHLIGHT
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.pressed.connect(func(): history_entry_clicked.emit(index))
	return btn
