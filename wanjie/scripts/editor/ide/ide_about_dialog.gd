## IDE关于对话框 - 复刻 Godot 4.7.1 About 弹窗
extends AcceptDialog

const IDETheme = preload("res://scripts/editor/ide/ide_theme.gd")

const VERSION := "1.1.0"
const ENGINE := "Godot 4.7.1"

func _ready() -> void:
	title = "关于 万界诗篇编辑器"
	size = Vector2i(440, 340)
	ok_button_text = "确定"
	_build_ui()

func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(vbox)

	var logo := Label.new()
	logo.text = "🌌"
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.add_theme_font_size_override("font_size", 40)
	vbox.add_child(logo)

	var title_label := Label.new()
	title_label.text = "万界诗篇 · 核心编辑器"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", IDETheme.C_ACCENT)
	vbox.add_child(title_label)

	var ver := Label.new()
	ver.text = "版本 %s  ·  对标 %s" % [VERSION, ENGINE]
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ver.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_UI)
	ver.add_theme_color_override("font_color", IDETheme.C_TEXT_DIM)
	vbox.add_child(ver)

	vbox.add_child(_separator())

	var desc := Label.new()
	desc.text = "IDE式剧本/场景一体化编辑器\n可视化2D/3D场景编辑 · 节点信号系统\n撤销重做历史 · 蓝图脚本代码生成"
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_UI)
	desc.add_theme_color_override("font_color", IDETheme.C_TEXT)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	vbox.add_child(_separator())

	var copy := Label.new()
	copy.text = "万界诗篇项目组"
	copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	copy.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_SMALL)
	copy.add_theme_color_override("font_color", IDETheme.C_TEXT_DISABLED)
	vbox.add_child(copy)

func _separator() -> HSeparator:
	var hs := HSeparator.new()
	hs.add_theme_color_override("separator", IDETheme.C_SEPARATOR)
	return hs

func open() -> void:
	popup_centered()
