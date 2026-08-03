## IDE状态栏 - 复刻 Godot 4.7.1 底部状态栏
extends HBoxContainer

const IDETheme = preload("res://scripts/editor/ide/ide_theme.gd")

var _cursor_label: Label
var _indent_label: Label
var _lang_label: Label
var _validate_icon: Label
var _validate_label: Label
var _zoom_label: Label

func _ready() -> void:
	add_theme_constant_override("separation", 0)
	custom_minimum_size.y = IDETheme.STATUS_BAR_HEIGHT
	_build_ui()

func _build_ui() -> void:
	# 左侧区域
	_cursor_label = _make_label("行 1, 列 1")
	add_child(_cursor_label)
	add_child(IDETheme.make_vseparator())

	_indent_label = _make_label("缩进: 制表符")
	add_child(_indent_label)
	add_child(IDETheme.make_vseparator())

	_lang_label = _make_label("GDScript")
	_lang_label.add_theme_color_override("font_color", IDETheme.C_ACCENT)
	add_child(_lang_label)

	# 弹性间隔
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(spacer)

	# 右侧区域：验证状态
	_validate_icon = _make_label("●")
	_validate_icon.add_theme_color_override("font_color", IDETheme.C_GREEN)
	add_child(_validate_icon)

	_validate_label = _make_label("就绪")
	add_child(_validate_label)
	add_child(IDETheme.make_vseparator())

	_zoom_label = _make_label("100%")
	add_child(_zoom_label)

func _make_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_SMALL)
	l.add_theme_color_override("font_color", IDETheme.C_TEXT_DIM)
	return l

# === 公共接口 ===

func set_cursor_position(line: int, column: int) -> void:
	_cursor_label.text = "行 %d, 列 %d" % [line + 1, column + 1]

func set_validation_state(state: String) -> void:
	match state:
		"ok":
			_validate_icon.text = "●"
			_validate_icon.add_theme_color_override("font_color", IDETheme.C_GREEN)
			_validate_label.text = "无错误"
		"warning":
			_validate_icon.text = "▲"
			_validate_icon.add_theme_color_override("font_color", IDETheme.C_YELLOW)
			_validate_label.text = "有警告"
		"error":
			_validate_icon.text = "■"
			_validate_icon.add_theme_color_override("font_color", IDETheme.C_RED)
			_validate_label.text = "有错误"
		_:
			_validate_icon.text = "●"
			_validate_icon.add_theme_color_override("font_color", IDETheme.C_TEXT_DIM)
			_validate_label.text = "就绪"

func set_zoom(percent: int) -> void:
	_zoom_label.text = "%d%%" % percent
