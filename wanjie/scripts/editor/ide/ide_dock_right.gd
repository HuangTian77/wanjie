## IDE右侧Dock - 复刻 Godot 4.7.1 右侧面板
## TabContainer: 检查器 | 节点(信号/分组) | 历史(撤销重做)
extends PanelContainer

signal node_connections_changed(node: Dictionary)
signal node_groups_changed(node: Dictionary)
signal open_script_requested(node: Dictionary, method: String)
signal history_entry_clicked(index: int)

const IDETheme = preload("res://scripts/editor/ide/ide_theme.gd")
const IDEInspectorClass = preload("res://scripts/editor/ide/ide_inspector.gd")
const IDENodePanelClass = preload("res://scripts/editor/ide/ide_node_panel.gd")
const IDEHistoryPanelClass = preload("res://scripts/editor/ide/ide_history_panel.gd")

var _tabs: TabContainer
var _inspector: VBoxContainer
var _node_panel: VBoxContainer
var _history_panel: VBoxContainer

func _ready() -> void:
	custom_minimum_size.x = IDETheme.DOCK_MIN_WIDTH
	# Dock面板背景
	var sb := StyleBoxFlat.new()
	sb.bg_color = IDETheme.C_BG_BASE
	sb.border_width_left = 1
	sb.border_color = IDETheme.C_BORDER
	sb.content_margin_left = 0.0
	sb.content_margin_top = 0.0
	sb.content_margin_right = 0.0
	sb.content_margin_bottom = 0.0
	add_theme_stylebox_override("panel", sb)
	_build_ui()

func _build_ui() -> void:
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_UI)
	_tabs.add_theme_color_override("font_color", IDETheme.C_TEXT_DIM)
	_tabs.add_theme_color_override("font_selected_color", IDETheme.C_TEXT)
	var tab_panel_sb := StyleBoxFlat.new()
	tab_panel_sb.bg_color = IDETheme.C_BG_BASE
	_tabs.add_theme_stylebox_override("panel", tab_panel_sb)
	_tabs.add_theme_stylebox_override("tab_selected", IDETheme.create_flat_style(IDETheme.C_BG_TAB_ACTIVE))
	_tabs.add_theme_stylebox_override("tab_unselected", IDETheme.create_flat_style(IDETheme.C_BG_TAB))
	add_child(_tabs)

	# === 检查器标签 ===
	_inspector = IDEInspectorClass.new()
	_inspector.name = "检查器"
	_tabs.add_child(_inspector)

	# === 节点标签 (信号 + 分组) ===
	_node_panel = IDENodePanelClass.new()
	_node_panel.name = "节点"
	_node_panel.connections_changed.connect(func(n: Dictionary): node_connections_changed.emit(n))
	_node_panel.groups_changed.connect(func(n: Dictionary): node_groups_changed.emit(n))
	_node_panel.open_script_requested.connect(func(n: Dictionary, m: String): open_script_requested.emit(n, m))
	_tabs.add_child(_node_panel)

	# === 历史标签 (撤销重做历史) ===
	_history_panel = IDEHistoryPanelClass.new()
	_history_panel.name = "历史"
	_history_panel.history_entry_clicked.connect(func(i: int): history_entry_clicked.emit(i))
	_tabs.add_child(_history_panel)

# === 公共接口 ===

func get_inspector() -> VBoxContainer:
	return _inspector

func get_node_panel() -> VBoxContainer:
	return _node_panel

func get_history_panel() -> VBoxContainer:
	return _history_panel

func set_selected_nodes(nodes: Array[Dictionary]) -> void:
	if _inspector != null:
		_inspector.set_selected_nodes(nodes)

## 设置节点面板的当前节点 + 场景根(用于信号连接目标树)
func set_node_panel_target(node: Dictionary, scene_root: Dictionary) -> void:
	if _node_panel != null:
		_node_panel.set_node(node, scene_root)

## 更新历史面板条目
func set_history(entries: Array) -> void:
	if _history_panel != null:
		_history_panel.set_history(entries)
