## IDE菜单栏 - 复刻 Godot 4.7.1 菜单结构
## 场景(S) / 项目(P) / 调试(D) / 编辑器(E) / 帮助(H)
extends HBoxContainer

signal menu_action(action_name: String)

const IDETheme = preload("res://scripts/editor/ide/ide_theme.gd")

var _menus: Dictionary = {}

func _ready() -> void:
	custom_minimum_size.y = IDETheme.MENU_BAR_HEIGHT
	add_theme_constant_override("separation", 0)
	# 尺寸变化时重绘背景
	resized.connect(func(): queue_redraw())
	_build_menus()

## 自绘背景（菜单栏层次用更深 C_BG, 底部 1px 分隔线）
func _draw() -> void:
	if size == Vector2.ZERO:
		return
	draw_rect(Rect2(Vector2.ZERO, size), IDETheme.C_BG)
	draw_line(Vector2(0, size.y - 1), Vector2(size.x, size.y - 1), IDETheme.C_BORDER, 1.0)

func _build_menus() -> void:
	# 场景(S) - 对应Godot的Scene菜单
	_create_menu("场景(S)", [
		{"id": "new_scene", "text": "新建场景", "shortcut": "Ctrl+N"},
		{"id": "new_script", "text": "新建脚本", "shortcut": "Ctrl+Shift+N"},
		{"type": "separator"},
		{"id": "open", "text": "打开...", "shortcut": "Ctrl+O"},
		{"id": "save", "text": "保存", "shortcut": "Ctrl+S"},
		{"id": "save_as", "text": "另存为...", "shortcut": "Ctrl+Shift+S"},
		{"type": "separator"},
		{"id": "export", "text": "导出代码..."},
		{"id": "import", "text": "导入代码..."},
	])

	# 项目(P) - 对应Godot的Project菜单
	_create_menu("项目(P)", [
		{"id": "project_settings", "text": "项目设置..."},
		{"type": "separator"},
		{"id": "tool_regenerate", "text": "重新生成代码"},
		{"id": "tool_format", "text": "格式化代码"},
	])

	# 调试(D) - 对应Godot的Debug菜单
	_create_menu("调试(D)", [
		{"id": "apply", "text": "应用代码", "shortcut": "F5"},
		{"id": "validate", "text": "验证语法", "shortcut": "F6"},
		{"type": "separator"},
		{"id": "run_script", "text": "运行剧本", "shortcut": "F7"},
		{"id": "stop_script", "text": "停止运行", "shortcut": "F8"},
	])

	# 编辑器(E) - 对应Godot的Editor菜单
	_create_menu("编辑器(E)", [
		{"id": "editor_settings", "text": "编辑器设置..."},
		{"type": "separator"},
		{"id": "toggle_left", "text": "切换左侧Dock", "shortcut": "Ctrl+1"},
		{"id": "toggle_right", "text": "切换右侧Dock", "shortcut": "Ctrl+2"},
		{"id": "toggle_bottom", "text": "切换底部面板", "shortcut": "Ctrl+3"},
		{"type": "separator"},
		{"id": "layout_default", "text": "管理布局"},
		{"id": "layout_reset", "text": "重置布局"},
	])

	# 帮助(H)
	_create_menu("帮助(H)", [
		{"id": "shortcuts", "text": "快捷键列表"},
		{"id": "about", "text": "关于..."},
	])

func _create_menu(menu_name: String, items: Array) -> void:
	var btn := MenuButton.new()
	btn.text = menu_name
	btn.flat = true
	btn.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_MENU)
	btn.add_theme_color_override("font_color", IDETheme.C_TEXT)
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 0.9))
	btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))

	var popup := btn.get_popup()
	popup.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_UI)

	for item in items:
		if item.has("type") and item["type"] == "separator":
			popup.add_separator()
		else:
			var id: int = popup.item_count
			var text: String = item["text"]
			if item.has("shortcut"):
				text += "\t" + item["shortcut"]
			popup.add_item(text, id)
			popup.set_item_metadata(id, item["id"])

	popup.id_pressed.connect(func(id: int):
		var meta = popup.get_item_metadata(id)
		if meta:
			menu_action.emit(meta)
	)

	add_child(btn)
	_menus[menu_name] = btn
