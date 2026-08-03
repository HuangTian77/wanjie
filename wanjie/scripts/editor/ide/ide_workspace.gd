## IDE工作区容器 - 复刻 Godot 4.7.1 中央工作区
## 4个工作区视图: 2D | 3D | 脚本 | 游戏
## 脚本视图完整实现; 2D集成scene_editor_2d; 3D集成scene_editor_3d; 游戏视图带运行按钮
extends Control

signal run_requested
signal workspace_changed(workspace_name: String)
## 2D/3D编辑器选中变化: domain="2d"/"3d", nodes=选中节点数组, scene_root=场景根
signal editor_selection_changed(domain: String, nodes: Array[Dictionary], scene_root: Dictionary)
## 2D/3D场景被修改: domain="2d"/"3d"
signal editor_scene_modified(domain: String)
## 2D/3D编辑器撤销/重做请求
signal editor_undo_requested(domain: String)
signal editor_redo_requested(domain: String)
## 2D/3D编辑器保存请求
signal editor_save_requested(domain: String)

const IDETheme = preload("res://scripts/editor/ide/ide_theme.gd")
const IDEScriptViewClass = preload("res://scripts/editor/ide/ide_script_view.gd")
const IDEScriptPanelClass = preload("res://scripts/editor/ide/ide_script_panel.gd")
const SceneEditor2DClass = preload("res://scripts/editor/scene_editor_2d.gd")
const SceneEditor3DClass = preload("res://scripts/editor/scene_editor_3d.gd")

var _script_hsplit: HSplitContainer
var _script_panel: VBoxContainer
var _script_view: VBoxContainer
var _2d_editor: Control
var _3d_editor: Control
var _game_view: Control
var _current_workspace: String = "script"

func _ready() -> void:
	_build_ui()
	switch_workspace("script")

func _build_ui() -> void:
	# 注意: _workspace 是纯 Control(非容器)，子节点的 size_flags 不生效，
	# 必须用锚点 PRESET_FULL_RECT 让每个视图填满整个工作区。
	# === 脚本工作区 (Phase 1 默认): HSplit(脚本面板 | 代码区) ===
	# 复刻 Godot 4.7.1 脚本编辑器: 左侧脚本面板(筛选脚本+筛选方法)，右侧代码区
	_script_hsplit = HSplitContainer.new()
	_script_hsplit.dragger_visibility = SplitContainer.DRAGGER_VISIBLE
	add_child(_script_hsplit)
	_script_hsplit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_script_panel = IDEScriptPanelClass.new()
	_script_hsplit.add_child(_script_panel)

	_script_view = IDEScriptViewClass.new()
	_script_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_script_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_script_hsplit.add_child(_script_view)
	_script_hsplit.split_offset = IDETheme.SCRIPT_PANEL_WIDTH

	# === 2D场景编辑器 (集成 scene_editor_2d.gd) ===
	_2d_editor = SceneEditor2DClass.new()
	add_child(_2d_editor)
	_2d_editor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_2d_editor.build_into(_2d_editor)
	_2d_editor.selection_changed.connect(_on_2d_selection_changed)
	_2d_editor.scene_modified.connect(_on_2d_scene_modified)
	_2d_editor.undo_requested.connect(func(): editor_undo_requested.emit("2d"))
	_2d_editor.redo_requested.connect(func(): editor_redo_requested.emit("2d"))
	_2d_editor.save_requested.connect(func(): editor_save_requested.emit("2d"))

	# === 3D场景编辑器 (集成 scene_editor_3d.gd) ===
	_3d_editor = SceneEditor3DClass.new()
	add_child(_3d_editor)
	_3d_editor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_3d_editor.build_into(_3d_editor)
	_3d_editor.selection_changed.connect(_on_3d_selection_changed)
	_3d_editor.scene_modified.connect(_on_3d_scene_modified)
	_3d_editor.undo_requested.connect(func(): editor_undo_requested.emit("3d"))
	_3d_editor.redo_requested.connect(func(): editor_redo_requested.emit("3d"))
	_3d_editor.save_requested.connect(func(): editor_save_requested.emit("3d"))

	# === 游戏视图 ===
	_game_view = _build_game_view()
	add_child(_game_view)
	_game_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _build_game_view() -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = IDETheme.C_BG_CANVAS
	panel.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	var icon_lbl := Label.new()
	icon_lbl.text = "🎮"
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 36)
	vbox.add_child(icon_lbl)

	var title := Label.new()
	title.text = "游戏预览"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", IDETheme.C_TEXT)
	vbox.add_child(title)

	var run_btn := Button.new()
	run_btn.text = "▶ 运行剧本"
	run_btn.custom_minimum_size = Vector2(160, 36)
	run_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var run_sb := StyleBoxFlat.new()
	run_sb.bg_color = IDETheme.C_ACCENT
	run_sb.corner_radius_top_left = 5
	run_sb.corner_radius_top_right = 5
	run_sb.corner_radius_bottom_left = 5
	run_sb.corner_radius_bottom_right = 5
	run_btn.add_theme_stylebox_override("normal", run_sb)
	var run_hover := run_sb.duplicate()
	run_hover.bg_color = IDETheme.C_ACCENT.lightened(0.15)
	run_btn.add_theme_stylebox_override("hover", run_hover)
	run_btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	run_btn.add_theme_font_size_override("font_size", 14)
	run_btn.pressed.connect(func(): run_requested.emit())
	vbox.add_child(run_btn)

	var hint := Label.new()
	hint.text = "应用代码后运行剧本 (F7)"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_SMALL)
	hint.add_theme_color_override("font_color", IDETheme.C_TEXT_DIM)
	vbox.add_child(hint)

	return panel

# === 公共接口 ===

func switch_workspace(workspace: String) -> void:
	_current_workspace = workspace
	_script_hsplit.visible = (workspace == "script")
	_2d_editor.visible = (workspace == "2d")
	_3d_editor.visible = (workspace == "3d")
	_game_view.visible = (workspace == "game")
	workspace_changed.emit(workspace)

func get_current_workspace() -> String:
	return _current_workspace

func get_script_view() -> VBoxContainer:
	return _script_view

func get_script_panel() -> VBoxContainer:
	return _script_panel

## === 2D场景编辑器接口 ===
func get_2d_editor() -> Control:
	return _2d_editor

## 加载2D场景数据 (Dictionary树)
func load_scene_2d(data: Dictionary) -> void:
	if _2d_editor and not data.is_empty():
		_2d_editor.load_scene_data(data)

## 获取2D场景数据 (Dictionary树)
func get_scene_2d() -> Dictionary:
	if _2d_editor:
		return _2d_editor.get_scene_data()
	return {}

## === 3D场景编辑器接口 ===
func get_3d_editor() -> Control:
	return _3d_editor

## 加载3D场景数据 (Dictionary树)
func load_scene_3d(data: Dictionary) -> void:
	if _3d_editor and not data.is_empty():
		_3d_editor.load_scene_data(data)

## 获取3D场景数据 (Dictionary树)
func get_scene_3d() -> Dictionary:
	if _3d_editor:
		return _3d_editor.get_scene_data()
	return {}

## 切换脚本面板显示/隐藏 (Godot状态栏箭头行为)
func toggle_script_panel() -> void:
	_script_panel.visible = not _script_panel.visible

# === 2D/3D编辑器选中/修改 转发 ===

func _on_2d_selection_changed() -> void:
	var nodes: Array[Dictionary] = _2d_editor.get_selected_nodes()
	editor_selection_changed.emit("2d", nodes, _2d_editor.get_scene_data())

func _on_3d_selection_changed() -> void:
	var nodes: Array[Dictionary] = _3d_editor.get_selected_nodes()
	editor_selection_changed.emit("3d", nodes, _3d_editor.get_scene_data())

func _on_2d_scene_modified() -> void:
	editor_scene_modified.emit("2d")

func _on_3d_scene_modified() -> void:
	editor_scene_modified.emit("3d")

## 获取当前活动场景编辑器域 ("2d"/"3d"), 非场景工作区返回""
func get_active_editor_domain() -> String:
	match _current_workspace:
		"2d": return "2d"
		"3d": return "3d"
	return ""

## 恢复指定域编辑器的场景数据 (撤销/重做用)
func reload_editor_scene(domain: String, data: Dictionary) -> void:
	if domain == "2d" and _2d_editor:
		_2d_editor.reload_scene(data)
	elif domain == "3d" and _3d_editor:
		_3d_editor.reload_scene(data)
