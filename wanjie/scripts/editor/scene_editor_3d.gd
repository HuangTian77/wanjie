## 3D场景可视化编辑器 - 类似Godot的3D编辑器
## 基于 SubViewport 真实3D渲染: 轨道相机 + 网格 + 射线选择 + 变换编辑
## 支持可视化创建和编辑3D节点 (MeshInstance3D/Node3D/Light/Camera)
## 数据模型: Dictionary树 {type, name, children, props{position/rotation/scale/visible}}
extends Control

const Registry = preload("res://scripts/editor/editor_node_registry.gd")
const CreateNodeDialogClass = preload("res://scripts/editor/ide/ide_create_node_dialog.gd")
const IDETheme = preload("res://scripts/editor/ide/ide_theme.gd")

# === 信号 ===
signal scene_modified
signal selection_changed
signal undo_requested
signal redo_requested
signal save_requested

# === 配色 (引用IDETheme集中定义) ===
const C_BG := IDETheme.C_SCENE_BG
const C_BG_TOOL := IDETheme.C_SCENE_BG_TOOL
const C_BG_PANEL := IDETheme.C_SCENE_BG_PANEL
const C_BG_CANVAS := IDETheme.C_SCENE_BG_CANVAS
const C_TEXT := IDETheme.C_SCENE_TEXT
const C_ACCENT := IDETheme.C_SCENE_ACCENT
const C_GREEN := IDETheme.C_SCENE_GREEN
const C_YELLOW := IDETheme.C_SCENE_YELLOW
const C_RED := IDETheme.C_SCENE_RED
const C_LABEL := IDETheme.C_SCENE_LABEL
const C_BORDER := IDETheme.C_SCENE_BORDER
const C_SELECT := IDETheme.C_SCENE_SELECT
const C_HIGHLIGHT := IDETheme.C_SCENE_HIGHLIGHT

# === 数据 ===
var _scene_root: Dictionary = {"type": "Node3D", "name": "Root", "children": [], "props": {}}
var _selected_nodes: Array[Dictionary] = []
var _undo_stack: Array[Dictionary] = []
var _redo_stack: Array[Dictionary] = []

# === 相机轨道状态 ===
var _orbit_yaw: float = 0.7
var _orbit_pitch: float = 0.45
var _orbit_distance: float = 12.0
var _orbit_target: Vector3 = Vector3.ZERO

# === 交互状态 ===
var _orbiting: bool = false
var _panning: bool = false
var _last_mouse: Vector2 = Vector2.ZERO
var _dragging_node: bool = false
var _drag_moved: bool = false
var _drag_plane_y: float = 0.0  # 拖动时节点所在水平面高度
var _drag_start_hit: Vector3 = Vector3.ZERO  # 拖动开始时射线与水平面的命中点
var _drag_orig_positions: Dictionary = {}  # {node_idx: Vector3} 拖动开始时各节点位置

# === UI节点 ===
var _viewport_container: SubViewportContainer
var _viewport: SubViewport
var _world_root: Node3D
var _content_root: Node3D
var _camera: Camera3D
var _scene_tree: Tree
var _inspector: Tree
var _toolbox: VBoxContainer
var _toolbar: HBoxContainer
var _status_label: Label
var _cam_label: Label
var _create_dialog: AcceptDialog  # 创建节点对话框
var _tree_menu: PopupMenu  # 场景树右键菜单
var _tree_menu_target: Dictionary = {}  # 右键菜单目标节点
var _renaming_node: Dictionary = {}  # 正在重命名的节点
var _clipboard: Array[Dictionary] = []  # 节点剪贴板
var _camera_established: bool = false  # 相机已确认为当前相机

func _ready() -> void:
	pass

func _process(_delta: float) -> void:
	# 仅在前几帧确保轨道相机为当前相机, 确认后不再每帧检测
	if _camera_established:
		return
	if _camera and _camera.is_inside_tree():
		if not _camera.current:
			_camera.make_current()
		_camera_established = true

## 构建完整的3D编辑器UI
func build_into(parent: Node) -> void:
	_build_ui(parent)
	_save_undo_state()
	_update_camera.call_deferred()

# === 公共接口 ===

## 获取场景数据
func get_scene_data() -> Dictionary:
	return _scene_root

## 获取当前选中节点列表
func get_selected_nodes() -> Array[Dictionary]:
	return _selected_nodes

## 加载场景数据
func load_scene_data(data: Dictionary) -> void:
	_scene_root = data.duplicate(true)
	_selected_nodes.clear()
	_rebuild_3d_scene()
	_refresh_all()
	scene_modified.emit()

## 恢复场景数据(撤销/重做用, 不触发scene_modified避免循环记录历史)
func reload_scene(data: Dictionary) -> void:
	_scene_root = data.duplicate(true)
	_selected_nodes.clear()
	_rebuild_3d_scene()
	_refresh_all()

## 导出为JSON
func export_json() -> String:
	return JSON.stringify(_scene_root, "  ")

## 从JSON导入
func import_json(json_str: String) -> bool:
	var result: Variant = JSON.parse_string(json_str)
	if result is Dictionary:
		load_scene_data(result as Dictionary)
		return true
	return false

# === UI构建 ===

func _build_ui(target: Node) -> void:
	# 主布局: 工具栏 -> 主区域(左|中|右) -> 状态栏
	var main_vbox := VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", 0)
	target.add_child(main_vbox)
	# 锚点填满父级: 兼容纯Control父级(IDE工作区); 容器父级会接管布局不受影响
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# 1. 工具栏
	_build_toolbar(main_vbox)
	# 2. 主区域
	var main_hsplit := HSplitContainer.new()
	main_hsplit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_hsplit.dragger_visibility = SplitContainer.DRAGGER_VISIBLE
	main_vbox.add_child(main_hsplit)

	# 左侧: 场景树 + 工具箱
	var left_vsplit := VSplitContainer.new()
	left_vsplit.custom_minimum_size.x = 200
	left_vsplit.dragger_visibility = SplitContainer.DRAGGER_VISIBLE
	main_hsplit.add_child(left_vsplit)
	_build_scene_tree(left_vsplit)
	_build_toolbox(left_vsplit)
	# 初始分割偏移: 场景树占上方较大区域(分割条可拖动调节)
	left_vsplit.split_offset = 320

	# 中央: 3D视口
	_build_viewport(main_hsplit)

	# 右侧: 属性检查器
	var right_panel := PanelContainer.new()
	right_panel.custom_minimum_size.x = 230
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_BG_PANEL
	sb.border_width_left = 1
	sb.border_color = C_BORDER
	right_panel.add_theme_stylebox_override("panel", sb)
	main_hsplit.add_child(right_panel)
	_build_inspector(right_panel)

	# 3. 状态栏
	_build_statusbar(main_vbox)

func _build_toolbar(parent: VBoxContainer) -> void:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_BG_TOOL
	sb.border_width_bottom = 1
	sb.border_color = C_BORDER
	sb.content_margin_left = 6.0
	sb.content_margin_top = 3.0
	sb.content_margin_right = 6.0
	sb.content_margin_bottom = 3.0
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size.y = 34
	parent.add_child(panel)

	_toolbar = HBoxContainer.new()
	_toolbar.add_theme_constant_override("separation", 4)
	panel.add_child(_toolbar)

	# 基础操作
	_btn("📄 新建", C_TEXT).pressed.connect(func(): _on_new_scene())
	_btn("💾 保存", C_GREEN).pressed.connect(func(): save_requested.emit())
	_sep()
	_btn("↩ 撤销", C_ACCENT).pressed.connect(func(): _undo())
	_btn("↪ 重做", C_ACCENT).pressed.connect(func(): _redo())
	_sep()
	_btn("🗑 删除", C_RED).pressed.connect(func(): _delete_selected())
	_sep()

	# 视图控制
	_btn("🎯 聚焦", C_YELLOW).pressed.connect(func(): _focus_selection())
	_btn("🏠 复位视角", C_TEXT).pressed.connect(func(): _reset_camera())
	_btn("⬆ 顶视图", C_TEXT).pressed.connect(func(): _top_view())
	_btn("⬛ 前视图", C_TEXT).pressed.connect(func(): _front_view())

func _build_scene_tree(parent: VSplitContainer) -> void:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_BG_PANEL
	sb.border_width_right = 1
	sb.border_color = C_BORDER
	panel.add_theme_stylebox_override("panel", sb)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)

	var title := _title_label("📋 场景树")
	vbox.add_child(title)

	_scene_tree = Tree.new()
	_scene_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scene_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scene_tree.hide_root = false
	_scene_tree.item_selected.connect(_on_tree_selected)
	_scene_tree.gui_input.connect(_on_tree_input)
	_scene_tree.item_edited.connect(_on_tree_item_edited)
	vbox.add_child(_scene_tree)

	# 场景树右键菜单 (对标Godot: 创建子节点/重命名/复制路径/删除)
	_tree_menu = PopupMenu.new()
	_tree_menu.id_pressed.connect(_on_tree_menu_id)
	add_child(_tree_menu)

func _build_toolbox(parent: VSplitContainer) -> void:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_BG_PANEL
	sb.border_width_right = 1
	sb.border_color = C_BORDER
	panel.add_theme_stylebox_override("panel", sb)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)

	var title := _title_label("🧰 节点工具箱")
	vbox.add_child(title)

	# ScrollContainer包裹工具箱: 节点类型过多时可纵向滚动查看
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_toolbox = VBoxContainer.new()
	_toolbox.add_theme_constant_override("separation", 2)
	_toolbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_toolbox)

	# 新建节点对话框按钮
	var new_btn := Button.new()
	new_btn.text = "➕ 新建节点..."
	new_btn.tooltip_text = "打开创建节点对话框 (搜索+全类型)"
	new_btn.add_theme_color_override("font_color", C_ACCENT)
	new_btn.add_theme_font_size_override("font_size", 12)
	new_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	new_btn.pressed.connect(_open_create_dialog)
	_toolbox.add_child(new_btn)
	_toolbox.add_child(HSeparator.new())

	# 从节点注册表生成3D快捷创建按钮
	for type_name in Registry.get_types_by_domain("3d"):
		var def: Dictionary = Registry.get_type(type_name)
		var btn := Button.new()
		btn.text = "%s %s" % [def.get("icon", "◆"), type_name]
		btn.flat = true
		btn.add_theme_color_override("font_color", C_TEXT)
		btn.add_theme_font_size_override("font_size", 12)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var node_type: String = type_name
		btn.pressed.connect(func(): _add_node(node_type))
		_toolbox.add_child(btn)

	# 创建节点对话框
	_create_dialog = CreateNodeDialogClass.new()
	_create_dialog.node_type_confirmed.connect(_on_create_node_confirmed)
	add_child(_create_dialog)

func _build_viewport(parent: HSplitContainer) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_BG_CANVAS
	panel.add_theme_stylebox_override("panel", sb)
	parent.add_child(panel)

	_viewport_container = SubViewportContainer.new()
	_viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewport_container.stretch = true
	_viewport_container.focus_mode = Control.FOCUS_ALL
	panel.add_child(_viewport_container)

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(800, 600)
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.world_3d = World3D.new()
	# 环境: 深色背景 + 环境光, 确保节点各个角度清晰可见
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.11, 0.12, 0.15)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.34, 0.4)
	env.ambient_light_energy = 1.0
	_viewport.world_3d.environment = env
	_viewport_container.add_child(_viewport)

	# 3D世界根节点
	_world_root = Node3D.new()
	_viewport.add_child(_world_root)

	# 网格地面
	_world_root.add_child(_make_grid())

	# 编辑器照明
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -45, 0)
	sun.light_energy = 0.9
	_world_root.add_child(sun)
	var ambient := DirectionalLight3D.new()
	ambient.rotation_degrees = Vector3(30, 135, 0)
	ambient.light_energy = 0.35
	_world_root.add_child(ambient)

	# 轨道相机
	_camera = Camera3D.new()
	_camera.fov = 60.0
	_world_root.add_child(_camera)
	_camera.make_current()

	# 用户内容根节点
	_content_root = Node3D.new()
	_world_root.add_child(_content_root)

	# 输入
	_viewport_container.gui_input.connect(_on_viewport_input)
	_viewport_container.mouse_entered.connect(func(): _viewport_container.grab_focus())

	_update_camera()
	_rebuild_3d_scene()

func _build_inspector(parent: PanelContainer) -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	parent.add_child(vbox)

	var title := _title_label("🔍 属性检查器")
	vbox.add_child(title)

	_inspector = Tree.new()
	_inspector.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inspector.hide_root = true
	_inspector.columns = 2
	_inspector.column_titles_visible = true
	_inspector.set_column_title(0, "属性")
	_inspector.set_column_title(1, "值")
	_inspector.set_column_custom_minimum_width(0, 80)
	_inspector.set_column_custom_minimum_width(1, 120)
	_inspector.item_edited.connect(_on_inspector_edited)
	vbox.add_child(_inspector)

func _build_statusbar(parent: VBoxContainer) -> void:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_BG_TOOL
	sb.border_width_top = 1
	sb.border_color = C_BORDER
	sb.content_margin_left = 10.0
	sb.content_margin_top = 1.0
	sb.content_margin_right = 10.0
	sb.content_margin_bottom = 1.0
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size.y = 22
	parent.add_child(panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	panel.add_child(hbox)

	_status_label = Label.new()
	_status_label.text = "就绪 | 左键选择/拖动 · 右键轨道旋转 · 中键平移 · 滚轮缩放"
	_status_label.add_theme_font_size_override("font_size", 11)
	_status_label.add_theme_color_override("font_color", C_LABEL)
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(_status_label)

	_cam_label = Label.new()
	_cam_label.text = "距离 12.0"
	_cam_label.add_theme_font_size_override("font_size", 11)
	_cam_label.add_theme_color_override("font_color", C_ACCENT)
	hbox.add_child(_cam_label)

# === UI辅助 ===

func _btn(text: String, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_color_override("font_color", color)
	b.add_theme_font_size_override("font_size", 12)
	b.flat = true
	_toolbar.add_child(b)
	return b

func _sep() -> void:
	var s := VSeparator.new()
	s.add_theme_color_override("separator", C_BORDER)
	_toolbar.add_child(s)

func _title_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", C_ACCENT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.14, 0.19, 1)
	sb.content_margin_left = 6.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	l.add_theme_stylebox_override("normal", sb)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

func _status(msg: String, color: Color = C_LABEL) -> void:
	if _status_label:
		_status_label.text = msg
		_status_label.add_theme_color_override("font_color", color)

# === 网格 ===

func _make_grid() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.35, 0.38, 0.45, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	im.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	var n := 12
	for i in range(-n, n + 1):
		var c: Color = Color(0.45, 0.5, 0.6, 0.8) if i == 0 else Color(0.3, 0.33, 0.4, 0.4)
		im.surface_set_color(c)
		im.surface_add_vertex(Vector3(float(i), 0.0, float(-n)))
		im.surface_add_vertex(Vector3(float(i), 0.0, float(n)))
		im.surface_add_vertex(Vector3(float(-n), 0.0, float(i)))
		im.surface_add_vertex(Vector3(float(n), 0.0, float(i)))
	im.surface_end()
	mi.mesh = im
	return mi

# === 相机控制 ===

func _update_camera() -> void:
	if _camera == null:
		return
	var offset := Vector3(
		_orbit_distance * cos(_orbit_pitch) * sin(_orbit_yaw),
		_orbit_distance * sin(_orbit_pitch),
		_orbit_distance * cos(_orbit_pitch) * cos(_orbit_yaw)
	)
	_camera.position = _orbit_target + offset
	# look_at/make_current要求节点已在场景树内 (构建期可能尚未入树, 入树后由延迟调用生效)
	if _camera.is_inside_tree():
		_camera.look_at(_orbit_target, Vector3.UP)
		if not _camera.current:
			_camera.make_current()
	if _cam_label:
		_cam_label.text = "距离 %.1f" % _orbit_distance

func _reset_camera() -> void:
	_orbit_yaw = 0.7
	_orbit_pitch = 0.45
	_orbit_distance = 12.0
	_orbit_target = Vector3.ZERO
	_update_camera()
	_status("视角已复位", C_GREEN)

func _top_view() -> void:
	_orbit_yaw = 0.0
	_orbit_pitch = 1.55
	_update_camera()
	_status("顶视图", C_GREEN)

func _front_view() -> void:
	_orbit_yaw = 0.0
	_orbit_pitch = 0.05
	_update_camera()
	_status("前视图", C_GREEN)

func _focus_selection() -> void:
	if _selected_nodes.is_empty():
		_orbit_target = Vector3.ZERO
	else:
		var p: Variant = _selected_nodes[0].get("props", {}).get("position", Vector3.ZERO)
		_orbit_target = _to_vec3(p)
	_update_camera()
	_status("已聚焦选中节点", C_GREEN)

# === 节点创建 ===

func _add_node(type: String) -> void:
	_create_node_under_selected(type, "")

## 打开创建节点对话框
func _open_create_dialog() -> void:
	_create_dialog.open_for_domain("3d")

## 对话框确认 → 在选中父节点下创建
func _on_create_node_confirmed(type_name: String, node_name: String) -> void:
	_create_node_under_selected(type_name, node_name)

## 在选中父节点下创建节点 (无选中则加到根)
func _create_node_under_selected(type_name: String, node_name: String) -> void:
	var parent_node: Dictionary = _selected_nodes[0] if not _selected_nodes.is_empty() else _scene_root
	if not parent_node.has("children"):
		parent_node["children"] = []
	var final_name: String = node_name if not node_name.is_empty() else Registry.get_default_name(type_name)
	final_name = _unique_name(parent_node, final_name)
	var node: Dictionary = Registry.create_node(type_name, final_name)
	# 网格/灯光默认抬高一点避免与地面重叠
	var props: Dictionary = node["props"]
	if props.get("position", Vector3.ZERO) == Vector3.ZERO and type_name != "Plane":
		props["position"] = Vector3(0, 0.5, 0)
	parent_node["children"].append(node)
	_selected_nodes = [node]
	_save_undo_state()
	_rebuild_3d_scene()
	_refresh_all()
	_status("已添加 %s" % final_name, C_GREEN)
	scene_modified.emit()

## 生成唯一节点名
func _unique_name(parent_node: Dictionary, base_name: String) -> String:
	var existing: Dictionary = {}
	_collect_names(parent_node, existing)
	if not existing.has(base_name):
		return base_name
	var i := 2
	while existing.has("%s%d" % [base_name, i]):
		i += 1
	return "%s%d" % [base_name, i]

func _collect_names(node: Dictionary, out: Dictionary) -> void:
	out[node.get("name", "")] = true
	for child in node.get("children", []):
		_collect_names(child, out)

## 查找节点的父节点
func _find_parent_node(parent_node: Dictionary, target: Dictionary) -> Variant:
	var children: Array = parent_node.get("children", [])
	if children.has(target):
		return parent_node
	for child in children:
		var found: Variant = _find_parent_node(child, target)
		if found:
			return found
	return null

func _create_data_node(type: String, node_name: String) -> Dictionary:
	return {
		"type": type,
		"name": node_name,
		"children": [],
		"props": {
			"position": Vector3(0, 0.5 if type != "Plane" else 0.01, 0),
			"rotation": Vector3.ZERO,
			"scale": Vector3.ONE,
			"visible": true,
		}
	}

func _delete_selected() -> void:
	if _selected_nodes.is_empty():
		return
	for sel in _selected_nodes:
		_remove_node_from_tree(_scene_root, sel)
	_selected_nodes.clear()
	_save_undo_state()
	_rebuild_3d_scene()
	_refresh_all()
	_status("已删除选中节点", C_RED)
	scene_modified.emit()

func _remove_node_from_tree(parent: Dictionary, target: Dictionary) -> bool:
	var children: Array = parent.get("children", [])
	if children.has(target):
		children.erase(target)
		return true
	for child in children:
		if _remove_node_from_tree(child, target):
			return true
	return false

# === 3D场景重建 ===

func _rebuild_3d_scene() -> void:
	if _content_root == null:
		return
	# 清空现有内容 (free会连带删除子树)
	var existing := _content_root.get_children()
	for c in existing:
		_content_root.remove_child(c)
		c.queue_free()
	# 从数据重建
	_build_3d_children(_scene_root, _content_root)
	_update_selection_highlight()

func _build_3d_children(data: Dictionary, parent3d: Node3D) -> void:
	for child_data in data.get("children", []):
		var cd: Dictionary = child_data as Dictionary
		var node3d := _create_3d_node(cd)
		node3d.set_meta("data", cd)
		_apply_transform(node3d, cd)
		parent3d.add_child(node3d)
		_build_3d_children(cd, node3d)

func _apply_transform(node3d: Node3D, data: Dictionary) -> void:
	var props: Dictionary = data.get("props", {})
	var pos: Variant = props.get("position", Vector3.ZERO)
	var rot: Variant = props.get("rotation", Vector3.ZERO)
	var scl: Variant = props.get("scale", Vector3.ONE)
	node3d.position = _to_vec3(pos)
	node3d.rotation_degrees = _to_vec3(rot)
	node3d.scale = _to_vec3(scl)
	node3d.visible = bool(props.get("visible", true))

func _create_3d_node(data: Dictionary) -> MeshInstance3D:
	var type: String = data.get("type", "Node3D")
	match type:
		"Cube":
			return _make_mesh_node(BoxMesh.new(), Color(0.72, 0.7, 0.76))
		"Sphere":
			return _make_mesh_node(SphereMesh.new(), Color(0.58, 0.74, 0.86))
		"Cylinder":
			return _make_mesh_node(CylinderMesh.new(), Color(0.76, 0.7, 0.58))
		"Capsule":
			return _make_mesh_node(CapsuleMesh.new(), Color(0.7, 0.6, 0.8))
		"Plane":
			return _make_mesh_node(PlaneMesh.new(), Color(0.5, 0.7, 0.6))
		"Torus":
			return _make_mesh_node(TorusMesh.new(), Color(0.8, 0.64, 0.7))
		"Prism":
			return _make_mesh_node(PrismMesh.new(), Color(0.64, 0.8, 0.7))
		"Light":
			return _make_gizmo_node(Color(1.0, 0.88, 0.35))
		"Camera":
			return _make_gizmo_node(Color(0.5, 0.7, 1.0))
		_:
			return _make_gizmo_node(Color(0.9, 0.9, 0.95))

func _make_mesh_node(mesh: Mesh, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	return mi

func _make_gizmo_node(color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.18
	sm.height = 0.36
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.mesh = sm
	mi.material_override = mat
	return mi

func _update_selection_highlight() -> void:
	var meshes: Array = []
	_collect_content_meshes(_content_root, meshes)
	for mi in meshes:
		var data: Variant = mi.get_meta("data", null)
		var selected: bool = data != null and _selected_nodes.has(data)
		var mat := (mi as MeshInstance3D).material_override as StandardMaterial3D
		if mat:
			if selected:
				mat.emission_enabled = true
				mat.emission = C_HIGHLIGHT
				mat.emission_energy_multiplier = 0.6
			else:
				mat.emission_enabled = false

## 收集内容树中所有可选中的 MeshInstance3D (避免lambda按值捕获导致的结果丢失)
func _collect_content_meshes(node: Node3D, out: Array) -> void:
	for c in node.get_children():
		if c is MeshInstance3D and c.has_meta("data"):
			out.append(c)
		_collect_content_meshes(c, out)

# === 视口输入 ===

func _on_viewport_input(event: InputEvent) -> void:
	# 键盘快捷键：Del 删除 / Ctrl+C 复制 / Ctrl+V 粘贴（对齐 2D）
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_DELETE:
			_delete_selected()
			return
		if event.ctrl_pressed:
			match event.keycode:
				KEY_C:
					_copy_selected()
				KEY_V:
					_paste()
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_orbit_distance = clampf(_orbit_distance * 0.9, 1.5, 80.0)
			_update_camera()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_orbit_distance = clampf(_orbit_distance * 1.1, 1.5, 80.0)
			_update_camera()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_orbiting = mb.pressed
			_last_mouse = mb.position
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = mb.pressed
			_last_mouse = mb.position
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_on_left_pressed(mb.position, mb.shift_pressed)
			else:
				_on_left_released()

	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		if _orbiting:
			var delta: Vector2 = mm.position - _last_mouse
			_last_mouse = mm.position
			_orbit_yaw -= delta.x * 0.008
			_orbit_pitch = clampf(_orbit_pitch + delta.y * 0.008, -1.5, 1.55)
			_update_camera()
		elif _panning:
			var delta: Vector2 = mm.position - _last_mouse
			_last_mouse = mm.position
			_pan_camera(delta)
		elif _dragging_node:
			_drag_node_to(mm.position)

	elif event is InputEventKey:
		var k: InputEventKey = event
		if k.pressed:
			if k.keycode == KEY_DELETE:
				_delete_selected()
			elif k.keycode == KEY_Z and k.ctrl_pressed:
				_undo()
			elif k.keycode == KEY_Y and k.ctrl_pressed:
				_redo()
			elif k.keycode == KEY_F:
				_focus_selection()

func _on_left_pressed(pos: Vector2, shift: bool) -> void:
	var hit: Dictionary = _pick_node_at(pos)
	if hit.is_empty():
		# 空白处: 非Shift清空选择
		if not shift:
			_selected_nodes.clear()
		_dragging_node = false
	else:
		# Shift: 切换选中状态(多选); 普通点击: 未选中则单选
		if shift:
			if _selected_nodes.has(hit):
				_selected_nodes.erase(hit)
			else:
				_selected_nodes.append(hit)
		elif not _selected_nodes.has(hit):
			_selected_nodes = [hit]
		# 只要点击的节点在选中集中, 就进入拖拽准备
		if _selected_nodes.has(hit):
			_dragging_node = true
			_drag_moved = false
			# 记录拖动平面(命中节点的Y高度)与各节点原始位置, 用于相对拖动
			var hit_props: Dictionary = hit.get("props", {})
			_drag_plane_y = _to_vec3(hit_props.get("position", Vector3.ZERO)).y
			_drag_start_hit = _compute_plane_hit(pos, _drag_plane_y)
			_drag_orig_positions.clear()
			for i in _selected_nodes.size():
				var p: Dictionary = _selected_nodes[i].get("props", {})
				_drag_orig_positions[i] = _to_vec3(p.get("position", Vector3.ZERO))
		else:
			_dragging_node = false
	_update_selection_highlight()
	_refresh_all()

func _on_left_released() -> void:
	if _dragging_node and _drag_moved:
		# 网格吸附: 位置取整到 1.0 单位
		for i in _selected_nodes.size():
			var props: Dictionary = _selected_nodes[i].get("props", {})
			if props.has("position"):
				var p: Vector3 = props["position"] as Vector3
				props["position"] = Vector3(roundf(p.x), roundf(p.y), roundf(p.z))
		_save_undo_state()
		scene_modified.emit()
	_dragging_node = false
	_drag_moved = false
	_drag_orig_positions.clear()

## 兼容 JSON 往返: 字符串 "(x, y, z)" 解析为 Vector3（JSON 不原生支持 Vector3）
func _to_vec3(v: Variant) -> Vector3:
	if v is Vector3:
		return v as Vector3
	if v is String:
		var nums := (v as String).trim_prefix("(").trim_suffix(")").split(",")
		if nums.size() == 3:
			return Vector3(float(nums[0].strip_edges()), float(nums[1].strip_edges()), float(nums[2].strip_edges()))
		if nums.size() == 2:
			return Vector3(float(nums[0].strip_edges()), float(nums[1].strip_edges()), 0.0)
	return Vector3.ZERO

## 计算屏幕坐标对应射线与指定高度水平面的交点 (XZ拖动基准)
func _compute_plane_hit(screen_pos: Vector2, plane_y: float) -> Vector3:
	var from: Vector3 = _camera.project_ray_origin(screen_pos)
	var dir: Vector3 = _camera.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.0001:
		return from
	var t: float = (plane_y - from.y) / dir.y
	return from + dir * t

func _drag_node_to(pos: Vector2) -> void:
	if _selected_nodes.is_empty():
		return
	# 射线与拖动平面求交, 计算相对起始命中点的XZ位移, 同步移动所有选中节点(跟手)
	var hit_point: Vector3 = _compute_plane_hit(pos, _drag_plane_y)
	var delta := Vector3(hit_point.x - _drag_start_hit.x, 0.0, hit_point.z - _drag_start_hit.z)
	for i in _selected_nodes.size():
		if _drag_orig_positions.has(i):
			var orig: Vector3 = _drag_orig_positions[i]
			var props: Dictionary = _selected_nodes[i].get("props", {})
			props["position"] = Vector3(orig.x + delta.x, orig.y, orig.z + delta.z)
	_drag_moved = true
	_rebuild_3d_scene()
	_refresh_inspector()

func _pan_camera(delta: Vector2) -> void:
	# 沿相机右向量和上向量平移目标点
	var right: Vector3 = -_camera.global_transform.basis.x
	var up: Vector3 = _camera.global_transform.basis.y
	var speed: float = _orbit_distance * 0.0015
	_orbit_target += right * delta.x * speed + up * delta.y * speed
	_update_camera()

# === 射线拾取 ===

func _pick_node_at(pos: Vector2) -> Dictionary:
	if _camera == null:
		return {}
	var from: Vector3 = _camera.project_ray_origin(pos)
	var dir: Vector3 = _camera.project_ray_normal(pos)
	var best: Dictionary = {}
	var best_dist: float = INF
	# 先收集再遍历: GDScript lambda按值捕获局部变量, 在回调内赋值best/best_dist不会传回外层
	var meshes: Array = []
	_collect_content_meshes(_content_root, meshes)
	for mi in meshes:
		var data: Variant = mi.get_meta("data", null)
		if data == null:
			continue
		var aabb: AABB = _transform_aabb((mi as MeshInstance3D).get_aabb(), (mi as MeshInstance3D).global_transform)
		var t: float = _ray_aabb_intersect(from, dir, aabb)
		if t >= 0.0 and t < best_dist:
			best_dist = t
			best = data
	return best

## 变换AABB到全局空间 (变换8个角点后取包围盒; Godot 4的AABB无内置transformed)
func _transform_aabb(aabb: AABB, xform: Transform3D) -> AABB:
	var p0: Vector3 = aabb.position
	var p1: Vector3 = aabb.position + aabb.size
	var corners := [
		Vector3(p0.x, p0.y, p0.z), Vector3(p1.x, p0.y, p0.z),
		Vector3(p0.x, p1.y, p0.z), Vector3(p1.x, p1.y, p0.z),
		Vector3(p0.x, p0.y, p1.z), Vector3(p1.x, p0.y, p1.z),
		Vector3(p0.x, p1.y, p1.z), Vector3(p1.x, p1.y, p1.z),
	]
	var min_pt: Vector3 = xform * corners[0]
	var max_pt: Vector3 = min_pt
	for i in range(1, 8):
		var p: Vector3 = xform * corners[i]
		min_pt = min_pt.min(p)
		max_pt = max_pt.max(p)
	return AABB(min_pt, max_pt - min_pt)

## 射线与AABB相交 (slab法), 返回距离t, 无交点返回-1
func _ray_aabb_intersect(from: Vector3, dir: Vector3, aabb: AABB) -> float:
	var tmin: float = -INF
	var tmax: float = INF
	for i in range(3):
		var origin: float = from[i]
		var direction: float = dir[i]
		var bmin: float = aabb.position[i]
		var bmax: float = aabb.position[i] + aabb.size[i]
		if absf(direction) < 0.000001:
			if origin < bmin or origin > bmax:
				return -1.0
		else:
			var inv: float = 1.0 / direction
			var t1: float = (bmin - origin) * inv
			var t2: float = (bmax - origin) * inv
			if t1 > t2:
				var tmp: float = t1
				t1 = t2
				t2 = tmp
			tmin = maxf(tmin, t1)
			tmax = minf(tmax, t2)
			if tmin > tmax:
				return -1.0
	if tmax < 0.0:
		return -1.0
	return tmin if tmin >= 0.0 else tmax

# === 撤销/重做 (统一由IDE层EditorUndoRedo管理) ===

func _save_undo_state() -> void:
	pass  # IDE层通过scene_modified信号自动记录快照

func _undo() -> void:
	undo_requested.emit()

func _redo() -> void:
	redo_requested.emit()

# === 场景树 ===

func _refresh_all() -> void:
	_refresh_scene_tree()
	_refresh_inspector()
	selection_changed.emit()

func _refresh_scene_tree() -> void:
	if _scene_tree == null:
		return
	_scene_tree.clear()
	_build_tree_item(_scene_root, null)

func _build_tree_item(node: Dictionary, parent_item: TreeItem) -> void:
	var item: TreeItem
	if parent_item == null:
		item = _scene_tree.create_item()
	else:
		item = _scene_tree.create_item(parent_item)
	# 信号/分组指示图标 (对标Godot场景树信号连接标记)
	var props: Dictionary = node.get("props", {})
	var has_signals: bool = not props.get("connections", []).is_empty()
	var has_groups: bool = not props.get("groups", []).is_empty()
	var badge: String = ""
	if has_signals:
		badge += "⚡"
	if has_groups:
		badge += "🏷"
	if not badge.is_empty():
		badge += " "
	item.set_text(0, "%s%s (%s)" % [badge, node.get("name", "?"), node.get("type", "?")])
	item.set_metadata(0, node)
	if has_signals:
		item.set_tooltip_text(0, "%s\n已连接 %d 个信号" % [node.get("name", "?"), props.get("connections", []).size()])
	if _selected_nodes.has(node):
		item.set_custom_bg_color(0, C_SELECT)
	for child in node.get("children", []):
		_build_tree_item(child, item)

func _on_tree_selected() -> void:
	var item := _scene_tree.get_selected()
	if item == null:
		return
	var meta: Variant = item.get_metadata(0)
	if meta is Dictionary:
		_selected_nodes = [meta]
		_update_selection_highlight()
		_refresh_inspector()
		selection_changed.emit()

# === 场景树右键菜单 / 键盘快捷键 ===

func _on_tree_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			var item := _scene_tree.get_item_at_position(mb.position)
			if item != null:
				var meta: Variant = item.get_metadata(0)
				if meta is Dictionary and not (meta as Dictionary).is_empty():
					_tree_menu_target = meta
					_selected_nodes = [meta]
					_update_selection_highlight()
					_refresh_inspector()
					selection_changed.emit()
					_popup_tree_menu(mb.global_position)
	elif event is InputEventKey and event.pressed and not event.echo:
		var k: InputEventKey = event
		match k.keycode:
			KEY_F2:
				_start_rename_selected()
				get_viewport().set_input_as_handled()
			KEY_DELETE:
				_delete_selected()
				get_viewport().set_input_as_handled()
			KEY_C:
				if k.ctrl_pressed:
					_copy_selected()
					get_viewport().set_input_as_handled()
			KEY_V:
				if k.ctrl_pressed:
					_paste()
					get_viewport().set_input_as_handled()

func _popup_tree_menu(at: Vector2) -> void:
	_tree_menu.clear()
	_tree_menu.add_item("➕ 创建子节点...", 1)
	_tree_menu.add_separator()
	_tree_menu.add_item("✏️ 重命名  (F2)", 2)
	_tree_menu.add_item("📋 复制节点路径", 3)
	_tree_menu.add_item("复制  (Ctrl+C)", 4)
	_tree_menu.add_item("粘贴  (Ctrl+V)", 5)
	_tree_menu.add_separator()
	_tree_menu.add_item("🗑 删除  (Del)", 6)
	_tree_menu.position = Vector2i(at)
	_tree_menu.popup()

func _on_tree_menu_id(id: int) -> void:
	match id:
		1:
			_selected_nodes = [_tree_menu_target]
			_open_create_dialog()
		2:
			_selected_nodes = [_tree_menu_target]
			_start_rename_selected()
		3:
			_copy_node_path(_tree_menu_target)
		4:
			_copy_selected()
		5:
			_paste()
		6:
			_selected_nodes = [_tree_menu_target]
			_delete_selected()

func _start_rename_selected() -> void:
	if _selected_nodes.is_empty():
		return
	_renaming_node = _selected_nodes[0]
	var item := _scene_tree.get_selected()
	if item == null:
		return
	item.set_text(0, _renaming_node.get("name", ""))
	item.set_editable(0, true)
	item.select(0)
	_scene_tree.edit_selected()

func _on_tree_item_edited() -> void:
	if _renaming_node.is_empty():
		return
	var item := _scene_tree.get_selected()
	if item == null:
		_renaming_node = {}
		return
	var new_name: String = item.get_text(0).strip_edges()
	var orig: String = _renaming_node.get("name", "")
	if not new_name.is_empty() and new_name != orig:
		var parent: Variant = _find_parent_node(_scene_root, _renaming_node)
		if parent:
			new_name = _unique_name(parent, new_name)
		_renaming_node["name"] = new_name
		_save_undo_state()
		scene_modified.emit()
	_renaming_node = {}
	_refresh_all()

func _node_path(node: Dictionary) -> String:
	var parts: Array[String] = [node.get("name", "?")]
	var cur: Variant = _find_parent_node(_scene_root, node)
	while cur != null:
		parts.push_front((cur as Dictionary).get("name", "?"))
		cur = _find_parent_node(_scene_root, cur)
	return "/" + "/".join(parts)

func _copy_node_path(node: Dictionary) -> void:
	var path: String = _node_path(node)
	DisplayServer.clipboard_set(path)
	_status("已复制节点路径: %s" % path, C_YELLOW)

func _copy_selected() -> void:
	_clipboard = _selected_nodes.duplicate(true)
	_status("已复制 %d 个节点" % _clipboard.size(), C_YELLOW)

func _paste() -> void:
	if _clipboard.is_empty():
		return
	# 粘贴为选中节点的兄弟(同级), 无选中则粘贴到根
	var target_parent: Dictionary = _scene_root
	if not _selected_nodes.is_empty():
		var found: Variant = _find_parent_node(_scene_root, _selected_nodes[0])
		if found:
			target_parent = found
	if not target_parent.has("children"):
		target_parent["children"] = []
	for item in _clipboard:
		var copy: Dictionary = item.duplicate(true)
		copy["name"] = _unique_name(target_parent, copy["name"] + "_copy")
		var props: Dictionary = copy.get("props", {})
		var pos: Variant = props.get("position", Vector3.ZERO)
		if pos is Vector3:
			props["position"] = (pos as Vector3) + Vector3(0.5, 0, 0.5)
		target_parent["children"].append(copy)
	_save_undo_state()
	_rebuild_3d_scene()
	_refresh_all()
	_status("已粘贴 %d 个节点" % _clipboard.size(), C_GREEN)
	scene_modified.emit()

# === 属性检查器 ===

func _refresh_inspector() -> void:
	if _inspector == null:
		return
	_inspector.clear()
	if _selected_nodes.is_empty():
		return
	var node: Dictionary = _selected_nodes[0]
	var root := _inspector.create_item()
	# 类型 (只读)
	var type_item := _inspector.create_item(root)
	type_item.set_text(0, "类型")
	type_item.set_text(1, str(node.get("type", "")))
	type_item.set_editable(1, false)
	# 名称 (可编辑)
	var name_item := _inspector.create_item(root)
	name_item.set_text(0, "名称")
	name_item.set_text(1, str(node.get("name", "")))
	name_item.set_editable(1, true)
	name_item.set_metadata(0, "__name__")
	# 变换属性
	var props: Dictionary = node.get("props", {})
	for key in ["position", "rotation", "scale"]:
		if not props.has(key):
			continue
		var item := _inspector.create_item(root)
		item.set_text(0, str(key))
		var v3: Vector3 = props[key] as Vector3
		item.set_text(1, "(%.2f, %.2f, %.2f)" % [v3.x, v3.y, v3.z])
		item.set_editable(1, true)
		item.set_metadata(0, str(key))
	# 可见性
	if props.has("visible"):
		var vis_item := _inspector.create_item(root)
		vis_item.set_text(0, "visible")
		vis_item.set_text(1, "✓" if bool(props["visible"]) else "✗")
		vis_item.set_editable(1, true)
		vis_item.set_metadata(0, "visible")

func _on_inspector_edited() -> void:
	if _selected_nodes.is_empty():
		return
	var item := _inspector.get_edited()
	if item == null:
		return
	var key: String = str(item.get_metadata(0))
	var new_val: String = item.get_text(1)
	var node: Dictionary = _selected_nodes[0]
	var props: Dictionary = node.get("props", {})
	if key == "__name__":
		node["name"] = new_val
		_refresh_scene_tree()
	elif key in ["position", "rotation", "scale"]:
		var parsed: Variant = _parse_vector3(new_val)
		if parsed != null:
			props[key] = parsed as Vector3
		else:
			_status("Vector3格式错误, 使用 (x, y, z)", C_RED)
			var v3: Vector3 = props.get(key, Vector3.ZERO) as Vector3
			item.set_text(1, "(%.2f, %.2f, %.2f)" % [v3.x, v3.y, v3.z])
			return
	elif key == "visible":
		props["visible"] = (new_val == "✓" or new_val.to_lower() == "true" or new_val == "1")
		item.set_text(1, "✓" if bool(props["visible"]) else "✗")
	_save_undo_state()
	_rebuild_3d_scene()
	_refresh_scene_tree()
	scene_modified.emit()

func _parse_vector3(text: String) -> Variant:
	var cleaned: String = text.replace("(", "").replace(")", "").replace(" ", "")
	var parts: PackedStringArray = cleaned.split(",")
	if parts.size() != 3:
		return null
	if not parts[0].is_valid_float() or not parts[1].is_valid_float() or not parts[2].is_valid_float():
		return null
	return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))

# === 场景操作 ===

func _on_new_scene() -> void:
	_scene_root = {"type": "Node3D", "name": "Root", "children": [], "props": {}}
	_selected_nodes.clear()
	_undo_stack.clear()
	_redo_stack.clear()
	_save_undo_state()
	_rebuild_3d_scene()
	_refresh_all()
	_status("新建场景", C_GREEN)
