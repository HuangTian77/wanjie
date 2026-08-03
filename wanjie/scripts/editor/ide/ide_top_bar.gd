## IDE顶栏 - 复刻 Godot 4.7.1 顶栏三段式结构
## 左侧: 场景标签页 | 中间: 工作区切换(2D|3D|脚本|游戏) | 右侧: 运行按钮组+布局
extends HBoxContainer

signal workspace_selected(workspace_name: String)
signal run_pressed
signal stop_pressed
signal layout_pressed

const IDETheme = preload("res://scripts/editor/ide/ide_theme.gd")

var _workspace_buttons: Dictionary = {}  # name -> Button
var _scene_label: Label
var _btn_play: Button
var _btn_stop: Button
var _current_workspace: String = "script"

func _ready() -> void:
	custom_minimum_size.y = IDETheme.TOP_BAR_HEIGHT
	add_theme_constant_override("separation", 0)
	# 尺寸变化时重绘背景
	resized.connect(func(): queue_redraw())
	_build_ui()

## 自绘背景（HBoxContainer 无 panel stylebox, 用 _draw 避免 top_level 不随父 resize 的坑）
func _draw() -> void:
	if size == Vector2.ZERO:
		return
	draw_rect(Rect2(Vector2.ZERO, size), IDETheme.C_BG_TOOL)
	draw_line(Vector2(0, size.y - 1), Vector2(size.x, size.y - 1), IDETheme.C_BORDER, 1.0)

func _build_ui() -> void:
	# === 左侧: 当前场景/文件标签 ===
	_scene_label = Label.new()
	_scene_label.text = "main.gd"
	_scene_label.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_UI)
	_scene_label.add_theme_color_override("font_color", IDETheme.C_TEXT)
	_scene_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scene_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(_scene_label)

	# === 中间: 工作区切换按钮组 (Godot: 2D 3D 脚本 游戏) ===
	var ws_container := HBoxContainer.new()
	ws_container.add_theme_constant_override("separation", 0)
	ws_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ws_container.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(ws_container)

	_add_workspace_button(ws_container, "2D", "2d")
	_add_workspace_button(ws_container, "3D", "3d")
	_add_workspace_button(ws_container, "脚本", "script")
	_add_workspace_button(ws_container, "游戏", "game")

	# === 右侧: 运行按钮组 ===
	var run_container := HBoxContainer.new()
	run_container.add_theme_constant_override("separation", 2)
	run_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	run_container.alignment = BoxContainer.ALIGNMENT_END
	add_child(run_container)

	_btn_play = Button.new()
	_btn_play.text = "▶"
	_btn_play.tooltip_text = "运行剧本 (F7)"
	_btn_play.flat = true
	_btn_play.custom_minimum_size = Vector2(30, 26)
	_btn_play.add_theme_font_size_override("font_size", 13)
	_btn_play.add_theme_color_override("font_color", IDETheme.C_GREEN)
	_btn_play.add_theme_color_override("font_hover_color", IDETheme.C_GREEN.lightened(0.3))
	var play_sb := StyleBoxFlat.new()
	play_sb.bg_color = Color(0, 0, 0, 0)
	play_sb.corner_radius_top_left = 3
	play_sb.corner_radius_top_right = 3
	play_sb.corner_radius_bottom_left = 3
	play_sb.corner_radius_bottom_right = 3
	_btn_play.add_theme_stylebox_override("normal", play_sb)
	var play_hover := play_sb.duplicate()
	play_hover.bg_color = Color(1, 1, 1, 0.08)
	_btn_play.add_theme_stylebox_override("hover", play_hover)
	_btn_play.add_theme_stylebox_override("pressed", play_hover)
	_btn_play.pressed.connect(func(): run_pressed.emit())
	run_container.add_child(_btn_play)

	_btn_stop = Button.new()
	_btn_stop.text = "■"
	_btn_stop.tooltip_text = "停止运行 (F8)"
	_btn_stop.flat = true
	_btn_stop.custom_minimum_size = Vector2(30, 26)
	_btn_stop.add_theme_font_size_override("font_size", 13)
	_btn_stop.add_theme_color_override("font_color", IDETheme.C_RED)
	_btn_stop.add_theme_color_override("font_hover_color", IDETheme.C_RED.lightened(0.3))
	_btn_stop.add_theme_stylebox_override("normal", play_sb.duplicate())
	_btn_stop.add_theme_stylebox_override("hover", play_hover.duplicate())
	_btn_stop.add_theme_stylebox_override("pressed", play_hover.duplicate())
	_btn_stop.pressed.connect(func(): stop_pressed.emit())
	run_container.add_child(_btn_stop)

	add_child(IDETheme.make_vseparator())

	# 布局按钮
	var btn_layout := Button.new()
	btn_layout.text = "⊞"
	btn_layout.tooltip_text = "布局管理"
	btn_layout.flat = true
	btn_layout.custom_minimum_size = Vector2(30, 26)
	IDETheme.style_button(btn_layout)
	btn_layout.pressed.connect(func(): layout_pressed.emit())
	run_container.add_child(btn_layout)

func _add_workspace_button(parent: HBoxContainer, text: String, workspace_id: String) -> void:
	var btn := Button.new()
	btn.text = text
	btn.toggle_mode = true
	btn.flat = true
	btn.custom_minimum_size = Vector2(48, 28)
	btn.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_MENU)
	btn.add_theme_color_override("font_color", IDETheme.C_TEXT_DIM)
	btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))

	# 普通状态
	var normal_sb := StyleBoxFlat.new()
	normal_sb.bg_color = Color(0, 0, 0, 0)
	normal_sb.content_margin_left = 8.0
	normal_sb.content_margin_right = 8.0
	btn.add_theme_stylebox_override("normal", normal_sb)

	# 悬停
	var hover_sb := StyleBoxFlat.new()
	hover_sb.bg_color = Color(1, 1, 1, 0.08)
	hover_sb.content_margin_left = 8.0
	hover_sb.content_margin_right = 8.0
	btn.add_theme_stylebox_override("hover", hover_sb)

	# 按下(选中): Godot风格蓝色下划线
	var pressed_sb := StyleBoxFlat.new()
	pressed_sb.bg_color = Color(0, 0, 0, 0)
	pressed_sb.border_width_bottom = 2
	pressed_sb.border_color = IDETheme.C_ACCENT
	pressed_sb.content_margin_left = 8.0
	pressed_sb.content_margin_right = 8.0
	pressed_sb.content_margin_bottom = 2.0
	btn.add_theme_stylebox_override("pressed", pressed_sb)

	btn.pressed.connect(func():
		set_active_workspace(workspace_id)
		workspace_selected.emit(workspace_id)
	)
	parent.add_child(btn)
	_workspace_buttons[workspace_id] = btn

# === 公共接口 ===

func set_active_workspace(workspace_id: String) -> void:
	_current_workspace = workspace_id
	for id in _workspace_buttons:
		var btn: Button = _workspace_buttons[id]
		btn.set_pressed_no_signal(id == workspace_id)

func set_scene_title(title_text: String) -> void:
	_scene_label.text = title_text

func get_active_workspace() -> String:
	return _current_workspace
