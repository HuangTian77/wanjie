## IDE快捷键列表对话框 - 复刻 Godot 4.7.1 快捷键参考
extends AcceptDialog

const IDETheme = preload("res://scripts/editor/ide/ide_theme.gd")

const SHORTCUTS := [
	["Ctrl+N", "新建场景 (创建磁盘文件)"],
	["Ctrl+Shift+N", "新建脚本 (创建磁盘文件)"],
	["Ctrl+O", "打开文件/场景"],
	["Ctrl+S", "保存 (场景工作区保存场景文件)"],
	["Ctrl+Shift+S", "另存为"],
	["Ctrl+Z", "撤销"],
	["Ctrl+Y", "重做"],
	["Ctrl+C", "复制节点"],
	["Ctrl+V", "粘贴节点"],
	["F2", "重命名节点"],
	["Delete", "删除节点"],
	["F5", "应用代码"],
	["F6", "验证语法"],
	["F7", "运行剧本"],
	["F8", "停止运行"],
	["Ctrl+F", "查找"],
	["Ctrl+H", "替换"],
	["Ctrl+1", "切换左侧Dock"],
	["Ctrl+2", "切换右侧Dock"],
	["Ctrl+3", "切换底部面板"],
]

func _ready() -> void:
	title = "快捷键列表"
	size = Vector2i(380, 460)
	ok_button_text = "关闭"
	_build_ui()

func _build_ui() -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 4)
	scroll.add_child(grid)

	for row in SHORTCUTS:
		var key_label := Label.new()
		key_label.text = str(row[0])
		key_label.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_UI)
		key_label.add_theme_color_override("font_color", IDETheme.C_ACCENT)
		grid.add_child(key_label)

		var desc_label := Label.new()
		desc_label.text = str(row[1])
		desc_label.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_UI)
		desc_label.add_theme_color_override("font_color", IDETheme.C_TEXT)
		grid.add_child(desc_label)

func open() -> void:
	popup_centered()
