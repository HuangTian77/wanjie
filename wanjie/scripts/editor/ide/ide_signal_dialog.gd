## 信号连接对话框 - 对标 Godot 4.7.1 "连接信号" 对话框
## 左侧: 信号列表(可选) | 右侧: 目标节点树 + 方法名 + 绑定参数
## 确认后生成连接: {signal, target_path, method, binds, flags}
extends AcceptDialog

const IDETheme = preload("res://scripts/editor/ide/ide_theme.gd")
const Registry = preload("res://scripts/editor/editor_node_registry.gd")

signal connection_confirmed(connection: Dictionary)

var _source_node: Dictionary = {}
var _scene_root: Dictionary = {}
var _signal_defs: Array = []

# UI
var _signal_list: ItemList
var _node_tree: Tree
var _method_edit: LineEdit
var _binds_edit: LineEdit
var _deferred_check: CheckBox
var _oneshot_check: CheckBox
var _connect_btn: Button
var _hint_label: Label

func _ready() -> void:
	title = "连接信号"
	min_size = Vector2i(720, 480)
	size = Vector2i(760, 520)
	_build_ui()
	about_to_popup.connect(_on_about_to_popup)

func _build_ui() -> void:
	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", 6)
	add_child(root_vbox)

	# === 源节点信息 ===
	_hint_label = Label.new()
	_hint_label.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_UI)
	_hint_label.add_theme_color_override("font_color", IDETheme.C_ACCENT)
	root_vbox.add_child(_hint_label)

	# === 主体: HSplit(信号列表 | 目标节点树) ===
	var hsplit := HSplitContainer.new()
	hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hsplit.dragger_visibility = SplitContainer.DRAGGER_VISIBLE
	root_vbox.add_child(hsplit)

	# 左: 信号列表
	var left_vbox := VBoxContainer.new()
	left_vbox.custom_minimum_size.x = 240
	left_vbox.add_theme_constant_override("separation", 2)
	hsplit.add_child(left_vbox)

	var sig_title := Label.new()
	sig_title.text = "信号"
	sig_title.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_UI)
	sig_title.add_theme_color_override("font_color", IDETheme.C_TEXT_DIM)
	left_vbox.add_child(sig_title)

	_signal_list = ItemList.new()
	_signal_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_signal_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_signal_list.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_UI)
	_signal_list.item_selected.connect(_on_signal_selected)
	left_vbox.add_child(_signal_list)

	# 右: 目标节点树
	var right_vbox := VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", 2)
	hsplit.add_child(right_vbox)

	var node_title := Label.new()
	node_title.text = "连接到节点 (选择目标)"
	node_title.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_UI)
	node_title.add_theme_color_override("font_color", IDETheme.C_TEXT_DIM)
	right_vbox.add_child(node_title)

	_node_tree = Tree.new()
	_node_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_node_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_node_tree.hide_root = false
	_node_tree.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_UI)
	_node_tree.item_selected.connect(_on_target_selected)
	right_vbox.add_child(_node_tree)

	# === 方法名 ===
	var method_hbox := HBoxContainer.new()
	method_hbox.add_theme_constant_override("separation", 6)
	root_vbox.add_child(method_hbox)
	var method_lbl := Label.new()
	method_lbl.text = "方法名:"
	method_lbl.custom_minimum_size.x = 64
	method_lbl.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_UI)
	method_lbl.add_theme_color_override("font_color", IDETheme.C_TEXT_DIM)
	method_hbox.add_child(method_lbl)
	_method_edit = LineEdit.new()
	_method_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_method_edit.placeholder_text = "_on_node_signal"
	_method_edit.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_UI)
	method_hbox.add_child(_method_edit)

	# === 绑定参数 ===
	var binds_hbox := HBoxContainer.new()
	binds_hbox.add_theme_constant_override("separation", 6)
	root_vbox.add_child(binds_hbox)
	var binds_lbl := Label.new()
	binds_lbl.text = "绑定参数:"
	binds_lbl.custom_minimum_size.x = 64
	binds_lbl.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_UI)
	binds_lbl.add_theme_color_override("font_color", IDETheme.C_TEXT_DIM)
	binds_hbox.add_child(binds_lbl)
	_binds_edit = LineEdit.new()
	_binds_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_binds_edit.placeholder_text = "逗号分隔, 如: 1, hello, true (可选)"
	_binds_edit.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_UI)
	binds_hbox.add_child(_binds_edit)

	# === 标志 ===
	var flags_hbox := HBoxContainer.new()
	flags_hbox.add_theme_constant_override("separation", 16)
	root_vbox.add_child(flags_hbox)
	_deferred_check = CheckBox.new()
	_deferred_check.text = "延迟连接 (CONNECT_DEFERRED)"
	_deferred_check.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_SMALL)
	flags_hbox.add_child(_deferred_check)
	_oneshot_check = CheckBox.new()
	_oneshot_check.text = "仅触发一次 (CONNECT_ONE_SHOT)"
	_oneshot_check.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_SMALL)
	flags_hbox.add_child(_oneshot_check)

	# === 按钮 ===
	var btn_hbox := HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_END
	btn_hbox.add_theme_constant_override("separation", 8)
	root_vbox.add_child(btn_hbox)
	var cancel_btn := Button.new()
	cancel_btn.text = "取消"
	cancel_btn.custom_minimum_size = Vector2(80, 28)
	IDETheme.style_button(cancel_btn)
	cancel_btn.pressed.connect(hide)
	btn_hbox.add_child(cancel_btn)
	_connect_btn = Button.new()
	_connect_btn.text = "连接"
	_connect_btn.custom_minimum_size = Vector2(80, 28)
	IDETheme.style_button(_connect_btn, true)
	_connect_btn.pressed.connect(_on_connect_pressed)
	btn_hbox.add_child(_connect_btn)

	hsplit.split_offset = 260

# === 公共接口 ===

## 打开对话框: source=源节点Dictionary, scene_root=场景根(用于目标树)
func open_for_node(source: Dictionary, scene_root: Dictionary) -> void:
	_source_node = source
	_scene_root = scene_root
	_signal_defs = Registry.get_signals(source.get("type", ""))
	popup_centered()

func _on_about_to_popup() -> void:
	_refresh_signal_list()
	_refresh_node_tree()
	_method_edit.text = ""
	_binds_edit.text = ""
	_deferred_check.button_pressed = false
	_oneshot_check.button_pressed = false
	var src_name: String = _source_node.get("name", "?")
	var src_type: String = _source_node.get("type", "?")
	_hint_label.text = "源节点: %s (%s) — 选择信号与目标节点" % [src_name, src_type]

func _refresh_signal_list() -> void:
	_signal_list.clear()
	for sig in _signal_defs:
		var sname: String = sig.get("name", "")
		var args: Array = sig.get("args", [])
		var arg_str: String = "(" + ", ".join(args) + ")" if not args.is_empty() else "()"
		var idx: int = _signal_list.add_item("%s %s" % [sname, arg_str])
		_signal_list.set_item_tooltip(idx, sig.get("desc", ""))
		_signal_list.set_item_metadata(idx, sig)
	if _signal_list.item_count > 0:
		_signal_list.select(0)
		_on_signal_selected(0)

func _refresh_node_tree() -> void:
	_node_tree.clear()
	if _scene_root.is_empty():
		return
	_build_node_item(_scene_root, null, "")

func _build_node_item(node: Dictionary, parent_item: TreeItem, parent_path: String) -> void:
	var item: TreeItem
	if parent_item == null:
		item = _node_tree.create_item()
	else:
		item = _node_tree.create_item(parent_item)
	var node_name: String = node.get("name", "?")
	var node_type: String = node.get("type", "?")
	var path: String = node_name if parent_path.is_empty() else parent_path + "/" + node_name
	item.set_text(0, "%s %s" % [Registry.get_icon(node_type), node_name])
	item.set_tooltip_text(0, "%s (%s)\n路径: %s" % [node_name, node_type, path])
	item.set_metadata(0, {"node": node, "path": path})
	# 高亮源节点
	if node == _source_node:
		item.set_custom_color(0, IDETheme.C_ACCENT)
	for child in node.get("children", []):
		_build_node_item(child, item, path)

# === 交互 ===

func _on_signal_selected(index: int) -> void:
	var sig: Dictionary = _signal_list.get_item_metadata(index)
	if sig.is_empty():
		return
	# 自动生成默认方法名 (基于源节点名+信号名)
	var src_name: String = _source_node.get("name", "node")
	_method_edit.placeholder_text = Registry.make_default_callback(src_name, sig.get("name", "signal"))

func _on_target_selected() -> void:
	# 选中目标后刷新方法名占位提示
	pass

func _get_selected_target() -> Dictionary:
	var item := _node_tree.get_selected()
	if item == null:
		return {}
	return item.get_metadata(0)

func _on_connect_pressed() -> void:
	# 校验信号
	var sig_index: int = _signal_list.get_current()
	if sig_index < 0:
		_set_hint("请先选择一个信号", IDETheme.C_RED)
		return
	var sig: Dictionary = _signal_list.get_item_metadata(sig_index)
	# 校验目标
	var target_meta: Dictionary = _get_selected_target()
	if target_meta.is_empty():
		_set_hint("请在右侧选择目标节点", IDETheme.C_RED)
		return
	var target_node: Dictionary = target_meta.get("node", {})
	var target_path: String = target_meta.get("path", "")
	# 方法名 (空则用占位默认)
	var method: String = _method_edit.text.strip_edges()
	if method.is_empty():
		method = _method_edit.placeholder_text
	if method.is_empty():
		var src_name: String = _source_node.get("name", "node")
		method = Registry.make_default_callback(src_name, sig.get("name", "signal"))
	# 解析绑定参数
	var binds: Array = _parse_binds(_binds_edit.text)
	# 标志
	var flags: int = 0
	if _deferred_check.button_pressed:
		flags |= 1  # CONNECT_DEFERRED
	if _oneshot_check.button_pressed:
		flags |= 2  # CONNECT_ONE_SHOT
	var connection := {
		"signal": sig.get("name", ""),
		"signal_args": sig.get("args", []),
		"target": target_node,
		"target_path": target_path,
		"target_name": target_node.get("name", ""),
		"method": method,
		"binds": binds,
		"flags": flags,
	}
	connection_confirmed.emit(connection)
	hide()

## 解析绑定参数字符串 "1, hello, true" -> [1, "hello", true]
func _parse_binds(text: String) -> Array:
	var result: Array = []
	var stripped: String = text.strip_edges()
	if stripped.is_empty():
		return result
	for part in stripped.split(","):
		var p: String = part.strip_edges()
		if p.is_empty():
			continue
		# 布尔
		if p.to_lower() == "true":
			result.append(true)
			continue
		if p.to_lower() == "false":
			result.append(false)
			continue
		# 整数
		if p.is_valid_int():
			result.append(int(p))
			continue
		# 浮点
		if p.is_valid_float():
			result.append(float(p))
			continue
		# 去除引号的字符串
		if (p.begins_with("\"") and p.ends_with("\"")) or (p.begins_with("'") and p.ends_with("'")):
			result.append(p.substr(1, p.length() - 2))
			continue
		result.append(p)
	return result

func _set_hint(text: String, color: Color) -> void:
	_hint_label.text = text
	_hint_label.add_theme_color_override("font_color", color)
