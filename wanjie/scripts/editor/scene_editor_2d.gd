## 2D场景可视化编辑器 - 类似Godot的2D编辑器
## 支持可视化创建和编辑UI控件
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
const C_GRID := IDETheme.C_SCENE_GRID
const C_SELECT := IDETheme.C_SCENE_SELECT
const C_HANDLE := IDETheme.C_SCENE_HANDLE

# === 数据 ===
var _scene_root: Dictionary = {"type": "Control", "name": "Root", "children": [], "props": {}}
var _selected_nodes: Array[Dictionary] = []
var _undo_stack: Array[Dictionary] = []
var _redo_stack: Array[Dictionary] = []
var _clipboard: Array[Dictionary] = []
var _dragging: bool = false
var _drag_moved: bool = false
var _drag_start: Vector2 = Vector2.ZERO
var _drag_node_starts: Dictionary = {}
var _resizing: bool = false
var _resize_handle: String = ""
var _resize_start: Vector2 = Vector2.ZERO
var _resize_orig: Dictionary = {}
var _selecting: bool = false
var _select_rect: Rect2 = Rect2()
var _panning: bool = false
var _last_pan_mouse: Vector2 = Vector2.ZERO
var _grid_size: int = 8
var _grid_snap: bool = false
var _zoom: float = 1.0
var _pan_offset: Vector2 = Vector2.ZERO
var _tool_mode: String = "select"
const HANDLE_SIZE := 6.0

# === UI节点 ===
var _canvas: Control
var _canvas_panel: PanelContainer
var _scene_tree: Tree
var _inspector: Tree
var _toolbox: VBoxContainer
var _toolbar: HBoxContainer
var _status_label: Label
var _zoom_label: Label
var _create_dialog: AcceptDialog
var _tree_menu: PopupMenu
var _tree_menu_target: Dictionary = {}
var _renaming_node: Dictionary = {}

func _ready() -> void:
	pass

func build_into(parent: Node) -> void:
	_build_ui(parent)
	_save_undo_state()

# === 公共接口 ===

func get_scene_data() -> Dictionary:
	return _scene_root

func get_selected_nodes() -> Array[Dictionary]:
	return _selected_nodes

func load_scene_data(data: Dictionary) -> void:
	_scene_root = data.duplicate(true)
	_selected_nodes.clear()
	_refresh_all()
	scene_modified.emit()

func reload_scene(data: Dictionary) -> void:
	_scene_root = data.duplicate(true)
	_selected_nodes.clear()
	_refresh_all()

func export_json() -> String:
	return JSON.stringify(_scene_root, "  ")

func import_json(json_str: String) -> bool:
	var result: Variant = JSON.parse_string(json_str)
	if result is Dictionary:
		load_scene_data(result as Dictionary)
		return true
	return false

func export_tscn() -> String:
	var tscn := "[gd_scene format=3]\n\n"
	tscn += _node_to_tscn(_scene_root, 0)
	return tscn

# === UI构建 ===

func _build_ui(target: Node) -> void:
	var main_vbox := VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", 0)
	target.add_child(main_vbox)
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_toolbar(main_vbox)
	var main_hsplit := HSplitContainer.new()
	main_hsplit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_hsplit.dragger_visibility = SplitContainer.DRAGGER_VISIBLE
	main_vbox.add_child(main_hsplit)
	var left_vsplit := VSplitContainer.new()
	left_vsplit.custom_minimum_size.x = 200
	left_vsplit.dragger_visibility = SplitContainer.DRAGGER_VISIBLE
	main_hsplit.add_child(left_vsplit)
	_build_scene_tree(left_vsplit)
	_build_toolbox(left_vsplit)
	left_vsplit.split_offset = 320
	_build_canvas(main_hsplit)
	var right_panel := PanelContainer.new()
	right_panel.custom_minimum_size.x = 220
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_BG_PANEL
	sb.border_width_left = 1
	sb.border_color = C_BORDER
	right_panel.add_theme_stylebox_override("panel", sb)
	main_hsplit.add_child(right_panel)
	_build_inspector(right_panel)
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
	_btn("🔍 选择", C_ACCENT).pressed.connect(func(): _tool_mode = "select"; _status("选择模式", C_ACCENT))
	_btn("✋ 移动", C_TEXT).pressed.connect(func(): _tool_mode = "move"; _status("移动模式", C_TEXT))
	_btn("🔄 旋转", C_TEXT).pressed.connect(func(): _tool_mode = "rotate"; _status("旋转模式", C_TEXT))
	_btn("📐 缩放", C_TEXT).pressed.connect(func(): _tool_mode = "scale"; _status("缩放模式", C_TEXT))
	_sep()
	_btn("📄 新建", C_TEXT).pressed.connect(func(): _on_new_scene())
	_btn("💾 保存", C_GREEN).pressed.connect(func(): save_requested.emit())
	_sep()
	_btn("↩ 撤销", C_ACCENT).pressed.connect(func(): _undo())
	_btn("↪ 重做", C_ACCENT).pressed.connect(func(): _redo())
	_sep()
	_btn("📋 复制", C_TEXT).pressed.connect(func(): _copy_selected())
	_btn("📋 粘贴", C_TEXT).pressed.connect(func(): _paste())
	_btn("🗑 删除", C_RED).pressed.connect(func(): _delete_selected())
	_sep()
	_btn("⬅ 左对齐", C_TEXT).pressed.connect(func(): _align_left())
	_btn("➡ 右对齐", C_TEXT).pressed.connect(func(): _align_right())
	_btn("⬆ 上对齐", C_TEXT).pressed.connect(func(): _align_top())
	_btn("⬇ 下对齐", C_TEXT).pressed.connect(func(): _align_bottom())
	_btn("↔ 水平中", C_TEXT).pressed.connect(func(): _align_hcenter())
	_btn("↕ 垂直中", C_TEXT).pressed.connect(func(): _align_vcenter())
	_btn("⇔ 分布H", C_TEXT).pressed.connect(func(): _distribute_h())
	_btn("⇕ 分布V", C_TEXT).pressed.connect(func(): _distribute_v())
	_sep()
	_btn("↖ 锚左上", C_TEXT).pressed.connect(func(): _apply_anchor_preset("top_left"))
	_btn("⊙ 锚居中", C_TEXT).pressed.connect(func(): _apply_anchor_preset("center"))
	_btn("▭ 锚全屏", C_TEXT).pressed.connect(func(): _apply_anchor_preset("full_rect"))
	_sep()
	_btn("📐 网格", C_YELLOW).pressed.connect(func():
		_grid_snap = not _grid_snap
		_status("网格吸附: %s" % ("开" if _grid_snap else "关"), C_YELLOW)
	)
	_btn("🔍+", C_TEXT).pressed.connect(func(): _set_zoom(_zoom * 1.2))
	_btn("🔍-", C_TEXT).pressed.connect(func(): _set_zoom(_zoom / 1.2))
	_btn("🔍 重置", C_TEXT).pressed.connect(func(): _set_zoom(1.0); _pan_offset = Vector2.ZERO; _canvas.queue_redraw())

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
	var title := _title_label("🧰 控件工具箱")
	vbox.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	_toolbox = VBoxContainer.new()
	_toolbox.add_theme_constant_override("separation", 2)
	_toolbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_toolbox)
	var new_btn := Button.new()
	new_btn.text = "➕ 新建节点..."
	new_btn.tooltip_text = "打开创建节点对话框 (搜索+全类型)"
	new_btn.add_theme_color_override("font_color", C_ACCENT)
	new_btn.add_theme_font_size_override("font_size", 12)
	new_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	new_btn.pressed.connect(_open_create_dialog)
	_toolbox.add_child(new_btn)
	_toolbox.add_child(HSeparator.new())
	for type_name in Registry.get_types_by_domain("2d"):
		if type_name == "Control":
			continue
		var def: Dictionary = Registry.get_type(type_name)
		var btn := Button.new()
		btn.text = "%s %s" % [def.get("icon", "◆"), type_name]
		btn.flat = true
		btn.add_theme_color_override("font_color", C_TEXT)
		btn.add_theme_font_size_override("font_size", 12)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var ctrl_type: String = type_name
		btn.pressed.connect(func(): _add_control(ctrl_type))
		_toolbox.add_child(btn)
	_create_dialog = CreateNodeDialogClass.new()
	_create_dialog.node_type_confirmed.connect(_on_create_node_confirmed)
	add_child(_create_dialog)

func _build_canvas(parent: HSplitContainer) -> void:
	_canvas_panel = PanelContainer.new()
	_canvas_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_BG_CANVAS
	_canvas_panel.add_theme_stylebox_override("panel", sb)
	parent.add_child(_canvas_panel)
	_canvas = Control.new()
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.clip_contents = true
	_canvas_panel.add_child(_canvas)
	_canvas.draw.connect(_draw_canvas)
	_canvas.gui_input.connect(_on_canvas_input)
	_canvas.mouse_entered.connect(func(): _canvas.grab_focus())

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
	_inspector.set_column_custom_minimum_width(0, 90)
	_inspector.set_column_custom_minimum_width(1, 110)
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
	_status_label.text = "就绪"
	_status_label.add_theme_font_size_override("font_size", 11)
	_status_label.add_theme_color_override("font_color", C_LABEL)
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(_status_label)
	_zoom_label = Label.new()
	_zoom_label.text = "100%"
	_zoom_label.add_theme_font_size_override("font_size", 11)
	_zoom_label.add_theme_color_override("font_color", C_ACCENT)
	hbox.add_child(_zoom_label)

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

# === 画布绘制 ===

func _draw_canvas() -> void:
	if _canvas == null:
		return
	var canvas_size: Vector2 = _canvas.size
	if _grid_snap:
		var step: float = _grid_size * _zoom
		var x: float = fmod(_pan_offset.x, step)
		while x < canvas_size.x:
			_canvas.draw_line(Vector2(x, 0), Vector2(x, canvas_size.y), C_GRID, 1.0)
			x += step
		var y: float = fmod(_pan_offset.y, step)
		while y < canvas_size.y:
			_canvas.draw_line(Vector2(0, y), Vector2(canvas_size.x, y), C_GRID, 1.0)
			y += step
	_draw_node_tree(_scene_root, _pan_offset, true)
	if _selecting:
		_canvas.draw_rect(_select_rect, C_SELECT, false, 2.0)

func _draw_node_tree(node: Dictionary, offset: Vector2, is_root: bool) -> void:
	var pos: Vector2 = offset + _get_node_pos(node) * _zoom
	var sz: Vector2 = _get_node_size(node) * _zoom
	var rect := Rect2(pos, sz)
	if not is_root:
		var color: Color = C_HANDLE if _selected_nodes.has(node) else C_BORDER
		_canvas.draw_rect(rect, color, false, 2.0)
		var name_text: String = "%s (%s)" % [node.get("name", "?"), node.get("type", "?")]
		_canvas.draw_string(ThemeDB.fallback_font, pos + Vector2(4, 14), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, C_TEXT)
		if _selected_nodes.has(node) and sz.x > 4 and sz.y > 4:
			var hs: float = HANDLE_SIZE
			_canvas.draw_rect(Rect2(pos + sz - Vector2(hs, hs), Vector2(hs, hs)), C_HANDLE, true)
			_canvas.draw_rect(Rect2(pos, Vector2(hs, hs)), C_HANDLE, true)
			_canvas.draw_rect(Rect2(pos + Vector2(sz.x - hs, 0), Vector2(hs, hs)), C_HANDLE, true)
			_canvas.draw_rect(Rect2(pos + Vector2(0, sz.y - hs), Vector2(hs, hs)), C_HANDLE, true)
	var children: Array = node.get("children", [])
	for child in children:
		var child_dict: Dictionary = child as Dictionary
		_draw_node_tree(child_dict, pos, false)

# === 节点操作 ===

func _add_control(type: String) -> void:
	_create_node_under_selected(type, "")

func _open_create_dialog() -> void:
	_create_dialog.open_for_domain("2d")

func _on_create_node_confirmed(type_name: String, node_name: String) -> void:
	_create_node_under_selected(type_name, node_name)

func _create_node_under_selected(type_name: String, node_name: String) -> void:
	var parent_node: Dictionary = _selected_nodes[0] if not _selected_nodes.is_empty() else _scene_root
	if not parent_node.has("children"):
		parent_node["children"] = []
	var final_name: String = node_name if not node_name.is_empty() else Registry.get_default_name(type_name)
	final_name = _unique_name(parent_node, final_name)
	var node: Dictionary = Registry.create_node(type_name, final_name)
	parent_node["children"].append(node)
	_selected_nodes = [node]
	_save_undo_state()
	_refresh_all()
	_status("已添加 %s" % final_name, C_GREEN)
	scene_modified.emit()

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

func _find_parent_node(parent_node: Dictionary, target: Dictionary) -> Variant:
	var children: Array = parent_node.get("children", [])
	if children.has(target):
		return parent_node
	for child in children:
		var found: Variant = _find_parent_node(child, target)
		if found:
			return found
	return null

func _create_node(type: String, node_name: String) -> Dictionary:
	return {"type": type, "name": node_name, "children": [], "props": {"position": Vector2(20, 20), "size": Vector2(100, 40), "text": "" if type != "Label" else "NewLabel", "visible": true}}

func _delete_selected() -> void:
	if _selected_nodes.is_empty():
		return
	for sel in _selected_nodes:
		_remove_node_from_tree(_scene_root, sel)
	_selected_nodes.clear()
	_save_undo_state()
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

func _copy_selected() -> void:
	_clipboard = _selected_nodes.duplicate(true)
	_status("已复制 %d 个节点" % _clipboard.size(), C_YELLOW)

func _paste() -> void:
	if _clipboard.is_empty():
		return
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
		var pos: Variant = props.get("position", Vector2.ZERO)
		props["position"] = (pos as Vector2) + Vector2(20, 20)
		target_parent["children"].append(copy)
	_save_undo_state()
	_refresh_all()
	_status("已粘贴 %d 个节点" % _clipboard.size(), C_GREEN)
	scene_modified.emit()

# === 撤销/重做 ===

func _save_undo_state() -> void:
	pass

func _undo() -> void:
	undo_requested.emit()

func _redo() -> void:
	redo_requested.emit()

# === 画布交互 ===

func _on_canvas_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_drag_start = mb.position
				if not _selected_nodes.is_empty():
					var handle_hit := _find_handle_at(mb.position)
					if not handle_hit.is_empty():
						_resizing = true
						_resize_handle = handle_hit["handle"]
						_resize_start = mb.position
						_resize_orig.clear()
						for i in _selected_nodes.size():
							_resize_orig[i] = {"size": _get_node_size(_selected_nodes[i]), "pos": _get_node_pos(_selected_nodes[i])}
						return
				var clicked := _find_node_at(mb.position)
				if not clicked.is_empty():
					if mb.shift_pressed:
						if _selected_nodes.has(clicked):
							_selected_nodes.erase(clicked)
						else:
							_selected_nodes.append(clicked)
					elif not _selected_nodes.has(clicked):
						_selected_nodes = [clicked]
					if _selected_nodes.has(clicked):
						_dragging = true
						_drag_moved = false
						_drag_node_starts.clear()
						for i in _selected_nodes.size():
							_drag_node_starts[i] = _get_node_pos(_selected_nodes[i])
				else:
					if not mb.shift_pressed:
						_selected_nodes.clear()
					_selecting = true
					_select_rect = Rect2(mb.position, Vector2.ZERO)
				_refresh_all()
			else:
				if _dragging:
					_dragging = false
					if _drag_moved:
						if _grid_snap:
							for sel in _selected_nodes:
								var cur_pos: Vector2 = _get_node_pos(sel)
								sel["props"]["position"] = (cur_pos / _grid_size).round() * _grid_size
						_save_undo_state()
						scene_modified.emit()
					_drag_node_starts.clear()
					_drag_moved = false
				if _resizing:
					_resizing = false
					if _grid_snap:
						for i in _resize_orig:
							var n: Dictionary = _selected_nodes[i]
							var cur_sz: Vector2 = _get_node_size(n)
							var snapped_sz: Vector2 = (cur_sz / _grid_size).round() * _grid_size
							if snapped_sz.x < _grid_size:
								snapped_sz.x = _grid_size
							if snapped_sz.y < _grid_size:
								snapped_sz.y = _grid_size
							n["props"]["size"] = snapped_sz
					_save_undo_state()
					scene_modified.emit()
					_resize_orig.clear()
					_resize_handle = ""
				if _selecting:
					_selecting = false
					var found := _find_nodes_in_rect(_select_rect)
					if mb.shift_pressed:
						for n in found:
							if not _selected_nodes.has(n):
								_selected_nodes.append(n)
					else:
						_selected_nodes = found
					_select_rect = Rect2()
				_refresh_all()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_zoom(_zoom * 1.1)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_zoom(_zoom / 1.1)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = mb.pressed
			if mb.pressed:
				_last_pan_mouse = mb.position
	elif event is InputEventMouseMotion:
		if _resizing and not _resize_orig.is_empty():
			var delta: Vector2 = (event.position - _resize_start) / _zoom
			for i in _resize_orig:
				var orig: Dictionary = _resize_orig[i]
				var os: Vector2 = orig["size"]
				var op: Vector2 = orig["pos"]
				var ns: Vector2 = os
				var np: Vector2 = op
				match _resize_handle:
					"br": ns = os + delta
					"bl": ns = Vector2(os.x - delta.x, os.y + delta.y); np = Vector2(op.x + delta.x, op.y)
					"tr": ns = Vector2(os.x + delta.x, os.y - delta.y); np = Vector2(op.x, op.y + delta.y)
					"tl": ns = os - delta; np = op + delta
				if ns.x < 10:
					if _resize_handle == "bl" or _resize_handle == "tl":
						np.x = op.x + (os.x - 10)
					ns.x = 10
				if ns.y < 10:
					if _resize_handle == "tr" or _resize_handle == "tl":
						np.y = op.y + (os.y - 10)
					ns.y = 10
				var n: Dictionary = _selected_nodes[i]
				n["props"]["size"] = ns
				n["props"]["position"] = np
			_canvas.queue_redraw()
			_refresh_inspector()
		elif _dragging and not _selected_nodes.is_empty():
			var delta: Vector2 = (event.position - _drag_start) / _zoom
			for i in _selected_nodes.size():
				if _drag_node_starts.has(i):
					_selected_nodes[i]["props"]["position"] = _drag_node_starts[i] + delta
			_drag_moved = true
			_canvas.queue_redraw()
			_refresh_inspector()
		elif _panning:
			_pan_offset += event.position - _last_pan_mouse
			_last_pan_mouse = event.position
			_canvas.queue_redraw()
		elif _selecting:
			_select_rect = Rect2(_drag_start, event.position - _drag_start).abs()
			_canvas.queue_redraw()
	elif event is InputEventKey:
		var k: InputEventKey = event
		if k.pressed:
			if k.keycode == KEY_DELETE:
				_delete_selected()
			elif k.keycode == KEY_C and k.ctrl_pressed:
				_copy_selected()
			elif k.keycode == KEY_V and k.ctrl_pressed:
				_paste()
			elif k.keycode == KEY_Z and k.ctrl_pressed:
				_undo()
			elif k.keycode == KEY_Y and k.ctrl_pressed:
				_redo()

func _find_handle_at(pos: Vector2) -> Dictionary:
	for node in _selected_nodes:
		var sp: Vector2 = _get_screen_pos(node)
		var sz: Vector2 = _get_node_size(node) * _zoom
		var hs: float = HANDLE_SIZE + 2.0
		if Rect2(sp + sz - Vector2(hs, hs), Vector2(hs * 2, hs * 2)).has_point(pos):
			return {"node": node, "handle": "br"}
		if Rect2(sp - Vector2(hs, hs), Vector2(hs * 2, hs * 2)).has_point(pos):
			return {"node": node, "handle": "tl"}
		if Rect2(sp + Vector2(sz.x - hs, -hs), Vector2(hs * 2, hs * 2)).has_point(pos):
			return {"node": node, "handle": "tr"}
		if Rect2(sp + Vector2(-hs, sz.y - hs), Vector2(hs * 2, hs * 2)).has_point(pos):
			return {"node": node, "handle": "bl"}
	return {}

func _find_node_at(pos: Vector2) -> Dictionary:
	return _find_node_at_recursive(_scene_root, pos, _pan_offset, true)

func _find_node_at_recursive(node: Dictionary, pos: Vector2, offset: Vector2, is_root: bool) -> Dictionary:
	var node_screen: Vector2 = offset + _get_node_pos(node) * _zoom
	var node_size: Vector2 = _get_node_size(node) * _zoom
	var rect := Rect2(node_screen, node_size)
	var children: Array = node.get("children", [])
	for i in range(children.size() - 1, -1, -1):
		var found := _find_node_at_recursive(children[i], pos, node_screen, false)
		if not found.is_empty():
			return found
	if not is_root and rect.has_point(pos):
		return node
	return {}

func _find_nodes_in_rect(rect: Rect2) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	_find_nodes_in_rect_recursive(_scene_root, rect, result, _pan_offset, true)
	return result

func _find_nodes_in_rect_recursive(node: Dictionary, rect: Rect2, result: Array[Dictionary], offset: Vector2, is_root: bool) -> void:
	var node_screen: Vector2 = offset + _get_node_pos(node) * _zoom
	var node_size: Vector2 = _get_node_size(node) * _zoom
	var node_rect := Rect2(node_screen, node_size)
	if not is_root and rect.intersects(node_rect):
		result.append(node)
	for child in node.get("children", []):
		_find_nodes_in_rect_recursive(child, rect, result, node_screen, false)

func _get_screen_pos(node: Dictionary) -> Vector2:
	var path: Array = []
	_find_path_to(_scene_root, node, path)
	var acc: Vector2 = _pan_offset
	for n in path:
		acc += _get_node_pos(n) * _zoom
	return acc

func _find_path_to(node: Dictionary, target: Dictionary, path: Array) -> bool:
	path.append(node)
	if node == target:
		return true
	for child in node.get("children", []):
		if _find_path_to(child, target, path):
			return true
	path.pop_back()
	return false

func _get_node_pos(node: Dictionary) -> Vector2:
	var props: Dictionary = node.get("props", {})
	var pos: Variant = props.get("position", Vector2.ZERO)
	return _to_vec2(pos)

func _get_node_size(node: Dictionary) -> Vector2:
	var props: Dictionary = node.get("props", {})
	var sz: Variant = props.get("size", Vector2(100, 40))
	return _to_vec2(sz)

## 兼容 JSON 往返: 字符串 "(x, y)" 解析为 Vector2（JSON 不原生支持 Vector2）
func _to_vec2(v: Variant) -> Vector2:
	if v is Vector2:
		return v as Vector2
	if v is String:
		var nums := (v as String).trim_prefix("(").trim_suffix(")").split(",")
		if nums.size() == 2:
			return Vector2(float(nums[0].strip_edges()), float(nums[1].strip_edges()))
	return Vector2.ZERO

## 写回节点 X（兼容 position 为字符串的 JSON 往返数据）
func _set_pos_x(node: Dictionary, v: float) -> void:
	var pos: Vector2 = _get_node_pos(node)
	pos.x = v
	node["props"]["position"] = pos

## 写回节点 Y（兼容 JSON 往返）
func _set_pos_y(node: Dictionary, v: float) -> void:
	var pos: Vector2 = _get_node_pos(node)
	pos.y = v
	node["props"]["position"] = pos

func _set_zoom(z: float) -> void:
	_zoom = clampf(z, 0.1, 5.0)
	if _zoom_label:
		_zoom_label.text = "%d%%" % int(_zoom * 100)
	_canvas.queue_redraw()

# === 场景树交互 ===

func _refresh_all() -> void:
	_refresh_scene_tree()
	_refresh_inspector()
	_canvas.queue_redraw()
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
	var item := _tree_selected_item()
	if item == null:
		return
	var meta: Variant = item.get_metadata(0)
	if meta is Dictionary and not (meta as Dictionary).is_empty():
		_selected_nodes = [meta]
	else:
		var node := _find_node_by_name(_scene_root, item.get_text(0))
		if node:
			_selected_nodes = [node]
	_refresh_inspector()
	_canvas.queue_redraw()
	selection_changed.emit()

func _tree_selected_item() -> TreeItem:
	return _scene_tree.get_selected()

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
					_refresh_inspector()
					_canvas.queue_redraw()
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
		1: _selected_nodes = [_tree_menu_target]; _open_create_dialog()
		2: _selected_nodes = [_tree_menu_target]; _start_rename_selected()
		3: _copy_node_path(_tree_menu_target)
		4: _copy_selected()
		5: _paste()
		6: _selected_nodes = [_tree_menu_target]; _delete_selected()

func _start_rename_selected() -> void:
	if _selected_nodes.is_empty():
		return
	_renaming_node = _selected_nodes[0]
	var item := _tree_selected_item()
	if item == null:
		return
	item.set_text(0, _renaming_node.get("name", ""))
	item.set_editable(0, true)
	item.select(0)
	_scene_tree.edit_selected()

func _on_tree_item_edited() -> void:
	if _renaming_node.is_empty():
		return
	var item := _tree_selected_item()
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

func _find_node_by_name(node: Dictionary, search_text: String) -> Dictionary:
	var display: String = "%s (%s)" % [node.get("name", "?"), node.get("type", "?")]
	if display == search_text:
		return node
	for child in node.get("children", []):
		var found := _find_node_by_name(child, search_text)
		if found:
			return found
	return {}

# === 属性检查器 ===

func _refresh_inspector() -> void:
	if _inspector == null:
		return
	_inspector.clear()
	if _selected_nodes.is_empty():
		return
	var node: Dictionary = _selected_nodes[0]
	var root := _inspector.create_item()
	var type_item := _inspector.create_item(root)
	type_item.set_text(0, "类型")
	type_item.set_text(1, str(node.get("type", "")))
	type_item.set_editable(1, false)
	var name_item := _inspector.create_item(root)
	name_item.set_text(0, "名称")
	name_item.set_text(1, str(node.get("name", "")))
	name_item.set_editable(1, true)
	name_item.set_metadata(0, "__name__")
	var props: Dictionary = node.get("props", {})
	for key in props:
		var item := _inspector.create_item(root)
		item.set_text(0, str(key))
		var val: Variant = props[key]
		if val is Vector2:
			var v2: Vector2 = val as Vector2
			item.set_text(1, "(%d, %d)" % [int(v2.x), int(v2.y)])
		elif val is bool:
			item.set_text(1, "✓" if val else "✗")
		elif val is float:
			item.set_text(1, "%.2f" % val)
		elif val is int:
			item.set_text(1, str(val))
		else:
			item.set_text(1, str(val))
		item.set_editable(1, true)
		item.set_metadata(0, str(key))

func _on_inspector_edited() -> void:
	if _selected_nodes.is_empty():
		return
	var item := _inspector.get_edited()
	if item == null:
		return
	var key: String = item.get_text(0)
	var new_val: String = item.get_text(1)
	var node: Dictionary = _selected_nodes[0]
	var props: Dictionary = node.get("props", {})
	var meta: Variant = item.get_metadata(0)
	if meta == "__name__" or key == "名称":
		node["name"] = new_val
		_refresh_scene_tree()
	elif props.has(key):
		var old_val: Variant = props[key]
		if old_val is Vector2:
			var parsed: Variant = _parse_vector2(new_val)
			if parsed != null:
				props[key] = parsed as Vector2
			else:
				_status("Vector2格式错误，使用 (x, y) 格式", C_RED)
				var v2: Vector2 = old_val as Vector2
				item.set_text(1, "(%d, %d)" % [int(v2.x), int(v2.y)])
				return
		elif old_val is bool:
			if new_val == "✓" or new_val.to_lower() == "true" or new_val == "1":
				props[key] = true
				item.set_text(1, "✓")
			else:
				props[key] = false
				item.set_text(1, "✗")
		elif old_val is float:
			props[key] = float(new_val)
		elif old_val is int:
			props[key] = int(new_val)
		else:
			props[key] = new_val
	_save_undo_state()
	_canvas.queue_redraw()
	_refresh_scene_tree()
	scene_modified.emit()

func _parse_vector2(text: String) -> Variant:
	var cleaned: String = text.replace("(", "").replace(")", "").replace(" ", "")
	var parts: PackedStringArray = cleaned.split(",")
	if parts.size() != 2:
		return null
	if not parts[0].is_valid_float() or not parts[1].is_valid_float():
		return null
	return Vector2(float(parts[0]), float(parts[1]))

# === 场景操作 ===

func _on_new_scene() -> void:
	_scene_root = {"type": "Control", "name": "Root", "children": [], "props": {}}
	_selected_nodes.clear()
	_undo_stack.clear()
	_redo_stack.clear()
	_save_undo_state()
	_refresh_all()
	_status("新建场景", C_GREEN)

# === tscn导出辅助 ===

func _node_to_tscn(node: Dictionary, indent: int) -> String:
	var result := ""
	var type: String = node.get("type", "Control")
	var node_name: String = str(node.get("name", "Node")).replace(" ", "_")
	var props: Dictionary = node.get("props", {})
	var pos_v: Variant = props.get("position", Vector2.ZERO)
	var sz_v: Variant = props.get("size", Vector2(100, 40))
	var pos: Vector2 = pos_v as Vector2
	var sz: Vector2 = sz_v as Vector2
	result += "[node name=\"%s\" type=\"%s\"]\n" % [node_name, type]
	result += "offset_left = %f\n" % pos.x
	result += "offset_top = %f\n" % pos.y
	result += "offset_right = %f\n" % (pos.x + sz.x)
	result += "offset_bottom = %f\n" % (pos.y + sz.y)
	var text_v: Variant = props.get("text", "")
	var text_str: String = str(text_v)
	if text_str != "":
		result += "text = \"%s\"\n" % text_str
	var children: Array = node.get("children", [])
	for child in children:
		var child_dict: Dictionary = child as Dictionary
		result += _node_to_tscn(child_dict, indent + 1)
	return result

# === 对齐工具 ===

func _align_left() -> void:
	if _selected_nodes.size() < 2:
		return
	var min_x: float = 999999.0
	for node in _selected_nodes:
		var pos: Vector2 = _get_node_pos(node)
		if pos.x < min_x:
			min_x = pos.x
	for node in _selected_nodes:
		_set_pos_x(node, min_x)
	_save_undo_state()
	_refresh_all()
	_status("已左对齐", C_GREEN)
	scene_modified.emit()

func _align_center() -> void:
	if _selected_nodes.size() < 2:
		return
	var sum_x: float = 0.0
	for node in _selected_nodes:
		sum_x += _get_node_pos(node).x
	var center_x: float = sum_x / _selected_nodes.size()
	for node in _selected_nodes:
		_set_pos_x(node, center_x)
	_save_undo_state()
	_refresh_all()
	_status("已居中对齐", C_GREEN)
	scene_modified.emit()

func _align_right() -> void:
	if _selected_nodes.size() < 2:
		return
	var max_x: float = -999999.0
	for node in _selected_nodes:
		var pos: Vector2 = _get_node_pos(node)
		var right: float = pos.x + _get_node_size(node).x
		if right > max_x:
			max_x = right
	for node in _selected_nodes:
		_set_pos_x(node, max_x - _get_node_size(node).x)
	_save_undo_state()
	_refresh_all()
	_status("已右对齐", C_GREEN)
	scene_modified.emit()

func _align_top() -> void:
	if _selected_nodes.size() < 2:
		return
	var min_y: float = 999999.0
	for node in _selected_nodes:
		if _get_node_pos(node).y < min_y:
			min_y = _get_node_pos(node).y
	for node in _selected_nodes:
		_set_pos_y(node, min_y)
	_save_undo_state()
	_refresh_all()
	_status("已上对齐", C_GREEN)
	scene_modified.emit()

func _align_bottom() -> void:
	if _selected_nodes.size() < 2:
		return
	var max_bottom: float = -999999.0
	for node in _selected_nodes:
		var bottom: float = _get_node_pos(node).y + _get_node_size(node).y
		if bottom > max_bottom:
			max_bottom = bottom
	for node in _selected_nodes:
		_set_pos_y(node, max_bottom - _get_node_size(node).y)
	_save_undo_state()
	_refresh_all()
	_status("已下对齐", C_GREEN)
	scene_modified.emit()

func _align_hcenter() -> void:
	if _selected_nodes.size() < 2:
		return
	var sum_x: float = 0.0
	for node in _selected_nodes:
		sum_x += _get_node_pos(node).x + _get_node_size(node).x / 2.0
	var center_x: float = sum_x / _selected_nodes.size()
	for node in _selected_nodes:
		_set_pos_x(node, center_x - _get_node_size(node).x / 2.0)
	_save_undo_state()
	_refresh_all()
	_status("已水平居中", C_GREEN)
	scene_modified.emit()

func _align_vcenter() -> void:
	if _selected_nodes.size() < 2:
		return
	var sum_y: float = 0.0
	for node in _selected_nodes:
		sum_y += _get_node_pos(node).y + _get_node_size(node).y / 2.0
	var center_y: float = sum_y / _selected_nodes.size()
	for node in _selected_nodes:
		_set_pos_y(node, center_y - _get_node_size(node).y / 2.0)
	_save_undo_state()
	_refresh_all()
	_status("已垂直居中", C_GREEN)
	scene_modified.emit()

func _distribute_h() -> void:
	if _selected_nodes.size() < 3:
		return
	var sorted := _selected_nodes.duplicate()
	sorted.sort_custom(func(a, b): return _get_node_pos(a).x < _get_node_pos(b).x)
	var first_x: float = _get_node_pos(sorted[0]).x
	var last_x: float = _get_node_pos(sorted[sorted.size() - 1]).x
	if last_x <= first_x:
		return
	var spacing: float = (last_x - first_x) / (sorted.size() - 1)
	for i in sorted.size():
		_set_pos_x(sorted[i], first_x + spacing * i)
	_save_undo_state()
	_refresh_all()
	_status("已水平分布", C_GREEN)
	scene_modified.emit()

func _distribute_v() -> void:
	if _selected_nodes.size() < 3:
		return
	var sorted := _selected_nodes.duplicate()
	sorted.sort_custom(func(a, b): return _get_node_pos(a).y < _get_node_pos(b).y)
	var first_y: float = _get_node_pos(sorted[0]).y
	var last_y: float = _get_node_pos(sorted[sorted.size() - 1]).y
	if last_y <= first_y:
		return
	var spacing: float = (last_y - first_y) / (sorted.size() - 1)
	for i in sorted.size():
		_set_pos_y(sorted[i], first_y + spacing * i)
	_save_undo_state()
	_refresh_all()
	_status("已垂直分布", C_GREEN)
	scene_modified.emit()

## 锚点预设: 应用 2D UI 九宫格锚点（写入 props.anchors_preset, 由场景代码生成使用）
func _apply_anchor_preset(preset: String) -> void:
	if _selected_nodes.is_empty():
		return
	for node in _selected_nodes:
		node["props"]["anchors_preset"] = preset
	_save_undo_state()
	_refresh_all()
	_status("锚点: %s" % preset, C_ACCENT)
	scene_modified.emit()
