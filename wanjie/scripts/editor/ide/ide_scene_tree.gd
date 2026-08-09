## IDE场景树 - 复刻 Godot 4.7.1 场景面板
## 支持：拖拽重排、右键菜单、多选、可见性眼睛图标、锁定图标、类型着色
extends VBoxContainer

signal node_selected(nodes: Array[Dictionary])
signal node_modified

const IDETheme = preload("res://scripts/editor/ide/ide_theme.gd")

## 可拖拽Tree子类：get_drag_data/can_drop_data/drop_data 是 Control 的虚方法
## （带下划线前缀），并非信号，不能直接 .connect()，必须通过子类重写。
class DragDropTree extends Tree:
	var get_drag_data_cb: Callable
	var can_drop_data_cb: Callable
	var drop_data_cb: Callable

	func _get_drag_data(at_position: Vector2) -> Variant:
		if get_drag_data_cb.is_valid():
			return get_drag_data_cb.call(at_position)
		return null

	func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
		if can_drop_data_cb.is_valid():
			return can_drop_data_cb.call(at_position, data)
		return false

	func _drop_data(at_position: Vector2, data: Variant) -> void:
		if drop_data_cb.is_valid():
			drop_data_cb.call(at_position, data)

# === 节点类型着色 (Godot 4.7.1 风格) ===
const TYPE_COLORS := {
	"WorldScript": Color(0.87, 0.31, 0.35, 1),     # 红色 - 根节点
	"Worldview": Color(0.55, 0.85, 0.55, 1),       # 绿色 - 世界观
	"EventSystem": Color(0.95, 0.75, 0.35, 1),     # 黄色 - 事件
	"EconomySystem": Color(0.95, 0.6, 0.35, 1),    # 橙色 - 经济
	"AbilitySystem": Color(0.55, 0.65, 1.0, 1),    # 蓝紫 - 能力
	"Scene": Color(0.51, 0.83, 1.0, 1),            # 浅蓝 - 场景
	"Character": Color(0.8, 0.55, 1.0, 1),         # 紫色 - 角色
	"Item": Color(0.6, 0.9, 0.7, 1),               # 淡绿 - 物品
	"Quest": Color(1.0, 0.85, 0.5, 1),             # 金色 - 任务
	"default": Color(0.8, 0.81, 0.82, 1),          # 默认灰白
}

const COL_NAME := 0
const COL_VISIBLE := 1
const COL_LOCK := 2

var _tree: DragDropTree
var _scene_root: Dictionary = {}
var _selected_nodes: Array[Dictionary] = []
var _clipboard: Array[Dictionary] = []
var _context_menu: PopupMenu
var _btn_new: Button
var _btn_collapse: Button
var _btn_expand: Button

func _ready() -> void:
	add_theme_constant_override("separation", 0)
	_build_ui()
	_build_context_menu()

func _build_ui() -> void:
	# === 标题工具栏 (Godot风格: "场景" + 工具按钮) ===
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 2)
	var header_sb := StyleBoxFlat.new()
	header_sb.bg_color = IDETheme.C_BG_TOOL
	header_sb.border_width_bottom = 1
	header_sb.border_color = IDETheme.C_BORDER
	header_sb.content_margin_left = 8.0
	header_sb.content_margin_top = 3.0
	header_sb.content_margin_right = 4.0
	header_sb.content_margin_bottom = 3.0
	header.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	var header_panel := PanelContainer.new()
	header_panel.add_theme_stylebox_override("panel", header_sb)
	header_panel.add_child(header)
	add_child(header_panel)

	var title := Label.new()
	title.name = "SceneTitle"
	title.text = "场景"
	title.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_UI)
	title.add_theme_color_override("font_color", IDETheme.C_TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	_btn_new = _make_tool_button("+", "添加子节点")
	_btn_new.pressed.connect(_add_child_node)
	header.add_child(_btn_new)

	_btn_collapse = _make_tool_button("⊟", "折叠全部")
	_btn_collapse.pressed.connect(_collapse_all)
	header.add_child(_btn_collapse)

	_btn_expand = _make_tool_button("⊞", "展开全部")
	_btn_expand.pressed.connect(_expand_all)
	header.add_child(_btn_expand)

	# === 场景树 ===
	_tree = DragDropTree.new()
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree.hide_root = false
	_tree.allow_reselect = true
	_tree.select_mode = Tree.SELECT_MULTI
	_tree.columns = 3
	_tree.set_column_expand(COL_NAME, true)
	_tree.set_column_expand(COL_VISIBLE, false)
	_tree.set_column_custom_minimum_width(COL_VISIBLE, 24)
	_tree.set_column_expand(COL_LOCK, false)
	_tree.set_column_custom_minimum_width(COL_LOCK, 24)
	_tree.hide_folding = false

	# Tree主题
	var tree_sb := StyleBoxFlat.new()
	tree_sb.bg_color = IDETheme.C_BG_BASE
	_tree.add_theme_stylebox_override("panel", tree_sb)
	_tree.add_theme_color_override("font_color", IDETheme.C_TEXT)
	_tree.add_theme_color_override("font_selected_color", Color(1, 1, 1, 1))
	_tree.add_theme_color_override("title_button_color", IDETheme.C_TEXT_DIM)
	_tree.add_theme_constant_override("draw_guides", 1)
	_tree.add_theme_constant_override("draw_relationship_lines", 1)
	_tree.add_theme_color_override("relationship_line_color", IDETheme.C_SEPARATOR)
	_tree.add_theme_color_override("guide_color", IDETheme.C_SEPARATOR)
	_tree.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_UI)

	_tree.item_selected.connect(_on_item_selected)
	_tree.multi_selected.connect(_on_multi_selected)
	_tree.gui_input.connect(_on_tree_input)
	# 拖拽通过子类虚方法回调实现（这些不是信号，不能connect）
	_tree.get_drag_data_cb = _on_get_drag_data
	_tree.can_drop_data_cb = _on_can_drop_data
	_tree.drop_data_cb = _on_drop_data
	add_child(_tree)

func _make_tool_button(text: String, tooltip: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.tooltip_text = tooltip
	btn.flat = true
	btn.custom_minimum_size = Vector2(22, 22)
	IDETheme.style_button(btn)
	return btn

func _build_context_menu() -> void:
	_context_menu = PopupMenu.new()
	_context_menu.add_item("添加子节点", 0)
	_context_menu.add_item("复制", 1)
	_context_menu.add_item("粘贴", 2)
	_context_menu.add_item("重复", 3)
	_context_menu.add_separator()
	_context_menu.add_item("重命名", 5)
	_context_menu.add_item("删除", 6)
	_context_menu.add_separator()
	_context_menu.add_item("向上移动", 8)
	_context_menu.add_item("向下移动", 9)
	_context_menu.add_separator()
	_context_menu.add_item("展开全部", 11)
	_context_menu.add_item("折叠全部", 12)
	_context_menu.id_pressed.connect(_on_context_menu)
	add_child(_context_menu)

# === 公共接口 ===

func set_scene_data(root: Dictionary) -> void:
	_scene_root = root
	_refresh_tree()

func get_selected_nodes() -> Array[Dictionary]:
	return _selected_nodes

func clear_selection() -> void:
	_selected_nodes.clear()
	_refresh_tree()

# === 树构建 ===

func _refresh_tree() -> void:
	if _tree == null:
		return  # UI尚未构建
	_tree.clear()
	# 对象计数标题
	var title_lbl := get_node_or_null("HeaderPanel/Header/SceneTitle")
	if title_lbl is Label:
		var count := 0
		if not _scene_root.is_empty():
			count = _count_nodes(_scene_root)
		(title_lbl as Label).text = "场景（%d）" % count if not _scene_root.is_empty() else "场景"
	if _scene_root.is_empty():
		return
	_build_tree_item(_scene_root, null)

## 递归统计节点数
func _count_nodes(node: Dictionary) -> int:
	var total := 1
	for c in node.get("children", []):
		total += _count_nodes(c)
	return total

func _build_tree_item(node: Dictionary, parent_item: TreeItem) -> TreeItem:
	var item: TreeItem
	if parent_item == null:
		item = _tree.create_item()
	else:
		item = _tree.create_item(parent_item)

	var node_name: String = node.get("name", "?")
	var node_type: String = node.get("type", "?")
	var is_visible: bool = node.get("props", {}).get("visible", true)
	var is_locked: bool = node.get("props", {}).get("locked", false)

	# 列0: 节点名（类型着色）
	item.set_text(COL_NAME, node_name)
	var type_color: Color = TYPE_COLORS.get(node_type, TYPE_COLORS["default"])
	item.set_custom_color(COL_NAME, type_color)
	item.set_tooltip_text(COL_NAME, "%s (%s)" % [node_name, node_type])
	item.set_metadata(COL_NAME, node)

	# 列1: 可见性指示器 (整格可点击切换, 见 _on_tree_input)
	item.set_text(COL_VISIBLE, "👁" if is_visible else "—")
	item.set_custom_color(COL_VISIBLE, IDETheme.C_ACCENT if is_visible else IDETheme.C_TEXT_DISABLED)
	item.set_tooltip_text(COL_VISIBLE, "切换可见性")

	# 列2: 锁定指示器
	item.set_text(COL_LOCK, "🔒" if is_locked else "")
	item.set_custom_color(COL_LOCK, IDETheme.C_YELLOW if is_locked else IDETheme.C_TEXT_DISABLED)
	item.set_tooltip_text(COL_LOCK, "切换锁定")

	# 子节点
	var children: Array = node.get("children", [])
	for child in children:
		_build_tree_item(child, item)
	return item

# === 选择处理 ===

func _on_item_selected() -> void:
	var item := _tree.get_selected()
	if item == null:
		return
	var node: Dictionary = item.get_metadata(COL_NAME)
	if not _selected_nodes.has(node):
		_selected_nodes = [node]
	node_selected.emit(_selected_nodes)

func _on_multi_selected(item: TreeItem, _column: int, selected: bool) -> void:
	var node: Dictionary = item.get_metadata(COL_NAME)
	if node.is_empty():
		return
	if selected and not _selected_nodes.has(node):
		_selected_nodes.append(node)
	elif not selected:
		_selected_nodes.erase(node)
	if not _selected_nodes.is_empty():
		node_selected.emit(_selected_nodes)

# === 列点击 (眼睛/锁定) ===

func _toggle_item_prop(item: TreeItem, column: int) -> void:
	var node: Dictionary = item.get_metadata(COL_NAME)
	if node.is_empty():
		return
	var props: Dictionary = node.get("props", {})
	node["props"] = props
	match column:
		COL_VISIBLE:
			props["visible"] = not props.get("visible", true)
			var vis: bool = props["visible"]
			item.set_text(COL_VISIBLE, "👁" if vis else "—")
			item.set_custom_color(COL_VISIBLE, IDETheme.C_ACCENT if vis else IDETheme.C_TEXT_DISABLED)
			node_modified.emit()
		COL_LOCK:
			props["locked"] = not props.get("locked", false)
			var locked: bool = props["locked"]
			item.set_text(COL_LOCK, "🔒" if locked else "")
			item.set_custom_color(COL_LOCK, IDETheme.C_YELLOW if locked else IDETheme.C_TEXT_DISABLED)
			node_modified.emit()

# === 右键菜单 ===

func _on_tree_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if not mb.pressed:
			return
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_show_context_menu(mb.position)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			var col: int = _tree.get_column_at_position(mb.position)
			if col == COL_VISIBLE or col == COL_LOCK:
				var item: TreeItem = _tree.get_item_at_position(mb.position)
				if item:
					_toggle_item_prop(item, col)

func _show_context_menu(pos: Vector2) -> void:
	var item := _tree.get_item_at_position(pos)
	if item:
		_tree.set_selected(item, COL_NAME)
		var node: Dictionary = item.get_metadata(COL_NAME)
		if not node.is_empty() and not _selected_nodes.has(node):
			_selected_nodes = [node]
	_context_menu.popup(Rect2i(Vector2i(get_screen_position()) + Vector2i(pos), Vector2i(180, 320)))

func _on_context_menu(id: int) -> void:
	match id:
		0: _add_child_node()
		1: _copy_nodes()
		2: _paste_nodes()
		3: _duplicate_nodes()
		5: _rename_node()
		6: _delete_nodes()
		8: _move_node_up()
		9: _move_node_down()
		11: _expand_all()
		12: _collapse_all()

# === 节点操作 ===

func _add_child_node() -> void:
	if _selected_nodes.is_empty():
		return
	var parent_node: Dictionary = _selected_nodes[0]
	if not parent_node.has("children"):
		parent_node["children"] = []
	var new_node := {
		"type": "Node",
		"name": "NewNode%d" % (randi() % 1000),
		"children": [],
		"props": {"visible": true, "locked": false}
	}
	parent_node["children"].append(new_node)
	_refresh_tree()
	node_modified.emit()

func _copy_nodes() -> void:
	_clipboard = _selected_nodes.duplicate(true)

func _paste_nodes() -> void:
	if _clipboard.is_empty() or _selected_nodes.is_empty():
		return
	var parent_node: Dictionary = _selected_nodes[0]
	if not parent_node.has("children"):
		parent_node["children"] = []
	for clip in _clipboard:
		var copy: Dictionary = clip.duplicate(true)
		copy["name"] = str(copy.get("name", "Node")) + "_copy"
		parent_node["children"].append(copy)
	_refresh_tree()
	node_modified.emit()

func _duplicate_nodes() -> void:
	if _selected_nodes.is_empty():
		return
	var node: Dictionary = _selected_nodes[0]
	var parent_node: Variant = _find_parent_node(_scene_root, node)
	if parent_node == null:
		return
	var copy: Dictionary = node.duplicate(true)
	copy["name"] = str(copy.get("name", "Node")) + "2"
	parent_node["children"].append(copy)
	_refresh_tree()
	node_modified.emit()

func _delete_nodes() -> void:
	if _selected_nodes.is_empty():
		return
	for node in _selected_nodes:
		_remove_node_from_tree(_scene_root, node)
	_selected_nodes.clear()
	_refresh_tree()
	node_modified.emit()

func _rename_node() -> void:
	if _selected_nodes.is_empty():
		return
	# 使用内联编辑：选中树项进入编辑模式
	var item := _tree.get_selected()
	if item:
		item.set_editable(COL_NAME, true)
		_tree.set_selected(item, COL_NAME)
		_tree.edit_selected(true)
		_tree.item_edited.connect(_on_item_renamed, CONNECT_ONE_SHOT)

func _on_item_renamed() -> void:
	var item := _tree.get_edited()
	if item == null:
		return
	var node: Dictionary = item.get_metadata(COL_NAME)
	if not node.is_empty():
		node["name"] = item.get_text(COL_NAME)
		node_modified.emit()
	item.set_editable(COL_NAME, false)

func _move_node_up() -> void:
	_move_node(-1)

func _move_node_down() -> void:
	_move_node(1)

func _move_node(direction: int) -> void:
	if _selected_nodes.is_empty():
		return
	var node: Dictionary = _selected_nodes[0]
	var parent_node: Variant = _find_parent_node(_scene_root, node)
	if parent_node == null:
		return
	var children: Array = parent_node.get("children", [])
	var idx: int = children.find(node)
	var new_idx: int = idx + direction
	if new_idx >= 0 and new_idx < children.size():
		children.remove_at(idx)
		children.insert(new_idx, node)
		_refresh_tree()
		node_modified.emit()

func _expand_all() -> void:
	var root_item := _tree.get_root()
	if root_item:
		_set_collapsed_recursive(root_item, false)

func _collapse_all() -> void:
	var root_item := _tree.get_root()
	if root_item:
		_set_collapsed_recursive(root_item, true)
		root_item.collapsed = false  # 根节点保持展开

func _set_collapsed_recursive(item: TreeItem, collapsed: bool) -> void:
	item.collapsed = collapsed
	var child := item.get_first_child()
	while child:
		_set_collapsed_recursive(child, collapsed)
		child = child.get_next()

# === 辅助查找 ===

func _remove_node_from_tree(parent_node: Dictionary, target: Dictionary) -> bool:
	var children: Array = parent_node.get("children", [])
	if children.has(target):
		children.erase(target)
		return true
	for child in children:
		if _remove_node_from_tree(child, target):
			return true
	return false

func _find_parent_node(parent_node: Dictionary, target: Dictionary) -> Variant:
	var children: Array = parent_node.get("children", [])
	if children.has(target):
		return parent_node
	for child in children:
		var found = _find_parent_node(child, target)
		if found:
			return found
	return null

# === 拖拽支持 ===

func _on_get_drag_data(at_position: Vector2) -> Variant:
	var item := _tree.get_item_at_position(at_position)
	if item == null:
		return null
	var node: Dictionary = item.get_metadata(COL_NAME)
	if node.is_empty():
		return null
	# Godot风格拖拽预览
	var preview := Label.new()
	preview.text = "  " + node.get("name", "?") + "  "
	var preview_sb := StyleBoxFlat.new()
	preview_sb.bg_color = IDETheme.C_BG_HIGHLIGHT
	preview_sb.corner_radius_top_left = 3
	preview_sb.corner_radius_top_right = 3
	preview_sb.corner_radius_bottom_left = 3
	preview_sb.corner_radius_bottom_right = 3
	preview.add_theme_stylebox_override("normal", preview_sb)
	preview.add_theme_color_override("font_color", IDETheme.C_TEXT)
	set_drag_preview(preview)
	return {"type": "scene_node", "node": node}

func _on_can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if data is Dictionary and data.get("type") == "scene_node":
		var item := _tree.get_item_at_position(at_position)
		return item != null
	return false

func _on_drop_data(at_position: Vector2, data: Variant) -> void:
	if not (data is Dictionary and data.get("type") == "scene_node"):
		return
	var dragged_node: Dictionary = data["node"]
	var target_item := _tree.get_item_at_position(at_position)
	if target_item == null:
		return
	var target_node: Dictionary = target_item.get_metadata(COL_NAME)
	if target_node.is_empty() or target_node == dragged_node:
		return
	# 防止拖入自己的子节点
	if _is_descendant(dragged_node, target_node):
		return
	# 移除原位置
	var old_parent: Variant = _find_parent_node(_scene_root, dragged_node)
	if old_parent:
		old_parent["children"].erase(dragged_node)
	# 添加到新父节点
	if not target_node.has("children"):
		target_node["children"] = []
	target_node["children"].append(dragged_node)
	_refresh_tree()
	node_modified.emit()

func _is_descendant(ancestor: Dictionary, check: Dictionary) -> bool:
	var children: Array = ancestor.get("children", [])
	for child in children:
		if child == check:
			return true
		if _is_descendant(child, check):
			return true
	return false
