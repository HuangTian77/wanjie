## IDE左侧Dock - 复刻 Godot 4.7.1 左侧面板
## VSplitContainer: 上栏场景面板 + 下栏文件系统面板
extends PanelContainer

const IDETheme = preload("res://scripts/editor/ide/ide_theme.gd")
const IDESceneTreeClass = preload("res://scripts/editor/ide/ide_scene_tree.gd")
const IDEFileSystemClass = preload("res://scripts/editor/ide/ide_file_system.gd")

var _split: VSplitContainer
var _scene_tree: VBoxContainer
var _file_system: VBoxContainer

func _ready() -> void:
	custom_minimum_size.x = IDETheme.DOCK_MIN_WIDTH
	# Dock面板背景
	var sb := StyleBoxFlat.new()
	sb.bg_color = IDETheme.C_BG_BASE
	sb.border_width_right = 1
	sb.border_color = IDETheme.C_BORDER
	sb.content_margin_left = 0.0
	sb.content_margin_top = 0.0
	sb.content_margin_right = 0.0
	sb.content_margin_bottom = 0.0
	add_theme_stylebox_override("panel", sb)
	_build_ui()

func _build_ui() -> void:
	_split = VSplitContainer.new()
	_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_split.dragger_visibility = SplitContainer.DRAGGER_VISIBLE
	add_child(_split)

	# 上栏: 场景面板
	_scene_tree = IDESceneTreeClass.new()
	_scene_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scene_tree.size_flags_stretch_ratio = 1.2
	_split.add_child(_scene_tree)

	# 下栏: 文件系统面板
	_file_system = IDEFileSystemClass.new()
	_file_system.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_split.add_child(_file_system)

	# 默认分栏位置: 场景占60%
	_split.split_offset = -160

# === 公共接口 ===

func get_scene_tree() -> VBoxContainer:
	return _scene_tree

func get_file_system() -> VBoxContainer:
	return _file_system

func set_scene_data(root: Dictionary) -> void:
	_scene_tree.set_scene_data(root)

func refresh_files() -> void:
	_file_system.refresh()
