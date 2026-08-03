## IDE检查器 - 复刻 Godot 4.7.1 Inspector 面板
## 属性分组折叠、类型着色、数值拖拽调整(Godot特色)、多种编辑控件
extends VBoxContainer

signal property_changed(node: Dictionary, property: String, new_value: Variant)

const IDETheme = preload("res://scripts/editor/ide/ide_theme.gd")
const Registry = preload("res://scripts/editor/editor_node_registry.gd")

# Godot 4.7.1 向量分量颜色
const C_AXIS_X := Color(0.87, 0.31, 0.35, 1)   # 红
const C_AXIS_Y := Color(0.55, 0.85, 0.55, 1)   # 绿
const C_AXIS_Z := Color(0.51, 0.83, 1.0, 1)    # 蓝

var _scroll: ScrollContainer
var _vbox: VBoxContainer
var _selected_nodes: Array[Dictionary] = []
var _collapsed_sections: Dictionary = {}  # section_name -> bool
var _node_name_edit: LineEdit

func _ready() -> void:
	add_theme_constant_override("separation", 0)
	_build_ui()

func _build_ui() -> void:
	# === 标题工具栏 ===
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 4)
	var header_sb := StyleBoxFlat.new()
	header_sb.bg_color = IDETheme.C_BG_TOOL
	header_sb.border_width_bottom = 1
	header_sb.border_color = IDETheme.C_BORDER
	header_sb.content_margin_left = 8.0
	header_sb.content_margin_top = 3.0
	header_sb.content_margin_right = 4.0
	header_sb.content_margin_bottom = 3.0
	var header_panel := PanelContainer.new()
	header_panel.add_theme_stylebox_override("panel", header_sb)
	header_panel.add_child(header)
	add_child(header_panel)

	var title := Label.new()
	title.text = "检查器"
	title.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_UI)
	title.add_theme_color_override("font_color", IDETheme.C_TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	# === 滚动区域 ===
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var scroll_sb := StyleBoxFlat.new()
	scroll_sb.bg_color = IDETheme.C_BG_BASE
	_scroll.add_theme_stylebox_override("panel", scroll_sb)
	add_child(_scroll)

	_vbox = VBoxContainer.new()
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.add_theme_constant_override("separation", 0)
	_scroll.add_child(_vbox)
	# UI就绪后渲染预设选中(防御: set_selected_nodes可能早于_ready)
	_refresh_inspector()

# === 公共接口 ===

func set_selected_nodes(nodes: Array[Dictionary]) -> void:
	_selected_nodes = nodes
	_refresh_inspector()

func _refresh_inspector() -> void:
	if _vbox == null:
		return
	for child in _vbox.get_children():
		child.queue_free()

	if _selected_nodes.is_empty():
		_add_placeholder("未选中节点\n在场景树中选择节点以编辑属性")
		return

	if _selected_nodes.size() > 1:
		_add_placeholder("已选中 %d 个节点" % _selected_nodes.size())
		_add_batch_section()
		return

	var node: Dictionary = _selected_nodes[0]
	var props: Dictionary = node.get("props", {})

	# === 节点头部 (Godot风格: 类型图标 + 名称编辑) ===
	_add_node_header(node)

	# === Transform 分组 (自适应2D/3D: Vector2/Vector3/float) ===
	_add_section("Transform", func():
		for key in ["position", "rotation", "scale", "size"]:
			if props.has(key):
				_add_typed_row(_transform_label(key), key, props[key], node)
	)

	# === 属性分组 ===
	_add_section("属性", func():
		_add_bool_row("Visible", "visible", props.get("visible", true), node)
		_add_bool_row("Locked", "locked", props.get("locked", false), node)
		if props.has("color"):
			_add_color_row("Color", "color", Registry.parse_value(props["color"]) as Color, node)
		if node.get("type", "") in ["Label", "Button", "LineEdit", "TextEdit", "RichTextLabel"]:
			_add_string_row("Text", "text", props.get("text", ""), node)
	)

	# === 节点分组 (Godot Groups) ===
	_add_section("分组", func():
		var groups: Array = props.get("groups", [])
		if groups.is_empty():
			_add_readonly_row("分组", "(无)")
		else:
			for g in groups:
				_add_readonly_row("🏷", str(g))
		_add_readonly_row("分组数", str(groups.size()))
	)

	# === 信号连接概览 (Godot Signals) ===
	_add_section("信号", func():
		var conns: Array = props.get("connections", [])
		_add_readonly_row("连接数", str(conns.size()))
		for c in conns:
			var cd: Dictionary = c
			var sig: String = str(cd.get("signal", "?"))
			var tgt: String = str(cd.get("target_name", cd.get("target_path", "?")))
			var mth: String = str(cd.get("method", "?"))
			_add_readonly_row("⚡ " + sig, "%s::%s" % [tgt, mth])
	)

	# === 元数据分组 ===
	_add_section("元数据", func():
		_add_readonly_row("类型", node.get("type", "Unknown"))
		_add_readonly_row("子节点数", str(node.get("children", []).size()))
		var meta: Dictionary = props.get("metadata", {})
		for key in meta:
			_add_readonly_row(str(key), str(meta[key]))
	)

	# === 自定义属性分组 ===
	var custom_keys := _get_custom_properties(props)
	if not custom_keys.is_empty():
		_add_section("自定义属性", func():
			for key in custom_keys:
				_add_typed_row(str(key), str(key), props[key], node)
		)

# === 节点头部 ===

func _transform_label(key: String) -> String:
	match key:
		"position": return "Position"
		"rotation": return "Rotation"
		"scale": return "Scale"
		"size": return "Size"
		_: return key.capitalize()

func _add_node_header(node: Dictionary) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	var sb := StyleBoxFlat.new()
	sb.bg_color = IDETheme.C_BG_HIGHLIGHT
	sb.content_margin_left = 8.0
	sb.content_margin_top = 5.0
	sb.content_margin_right = 8.0
	sb.content_margin_bottom = 5.0
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", sb)
	panel.add_child(hbox)
	_vbox.add_child(panel)

	var type_icon := Label.new()
	var def: Dictionary = Registry.get_type(node.get("type", ""))
	type_icon.text = def.get("icon", "◆")
	type_icon.add_theme_color_override("font_color", IDETheme.C_ACCENT)
	type_icon.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_UI)
	hbox.add_child(type_icon)

	_node_name_edit = LineEdit.new()
	_node_name_edit.text = node.get("name", "")
	_node_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_node_name_edit.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_UI)
	_node_name_edit.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	var edit_sb := StyleBoxFlat.new()
	edit_sb.bg_color = Color(0, 0, 0, 0)
	_node_name_edit.add_theme_stylebox_override("normal", edit_sb)
	_node_name_edit.add_theme_stylebox_override("focus", IDETheme.create_flat_style(IDETheme.C_BG_DARKER))
	_node_name_edit.text_submitted.connect(func(new_text: String):
		node["name"] = new_text
		property_changed.emit(node, "name", new_text)
	)
	hbox.add_child(_node_name_edit)

	var type_label := Label.new()
	type_label.text = node.get("type", "?")
	type_label.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_SMALL)
	type_label.add_theme_color_override("font_color", IDETheme.C_TEXT_DIM)
	hbox.add_child(type_label)

# === 折叠分组 (Godot Inspector Section) ===

func _add_section(section_name: String, content_builder: Callable) -> void:
	var is_collapsed: bool = _collapsed_sections.get(section_name, false)

	# 分组头
	var header_btn := Button.new()
	header_btn.text = ("▸ " if is_collapsed else "▾ ") + section_name
	header_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header_btn.flat = true
	header_btn.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_UI)
	header_btn.add_theme_color_override("font_color", IDETheme.C_TEXT)
	header_btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 0.9))
	var header_sb := StyleBoxFlat.new()
	header_sb.bg_color = IDETheme.C_BG_TOOL
	header_sb.content_margin_left = 6.0
	header_sb.content_margin_top = 4.0
	header_sb.content_margin_bottom = 4.0
	header_btn.add_theme_stylebox_override("normal", header_sb)
	var header_hover := header_sb.duplicate()
	header_hover.bg_color = IDETheme.C_BG_HIGHLIGHT
	header_btn.add_theme_stylebox_override("hover", header_hover)
	header_btn.add_theme_stylebox_override("pressed", header_hover)
	_vbox.add_child(header_btn)

	# 内容容器
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 0)
	content.visible = not is_collapsed
	_vbox.add_child(content)

	header_btn.pressed.connect(func():
		_collapsed_sections[section_name] = not _collapsed_sections.get(section_name, false)
		_refresh_inspector()
	)

	if not is_collapsed:
		# 临时将_vbox指向content来构建内容
		var old_vbox := _vbox
		_vbox = content
		content_builder.call()
		_vbox = old_vbox

# === 属性行构建 ===

func _make_row(label_text: String, label_color: Color = IDETheme.C_TEXT_DIM) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	var row_sb := StyleBoxFlat.new()
	row_sb.content_margin_left = 12.0
	row_sb.content_margin_right = 6.0
	row_sb.content_margin_top = 2.0
	row_sb.content_margin_bottom = 2.0
	hbox.add_theme_stylebox_override("normal", StyleBoxEmpty.new())

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 76
	label.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_SMALL)
	label.add_theme_color_override("font_color", label_color)
	label.mouse_default_cursor_shape = Control.CURSOR_ARROW
	hbox.add_child(label)
	return hbox

## Godot特色: 按住标签拖拽调整数值
func _make_drag_label(label_text: String, color: Color, get_value: Callable, set_value: Callable, step: float = 1.0) -> Label:
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 14
	label.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_SMALL)
	label.add_theme_color_override("font_color", color)
	label.mouse_default_cursor_shape = Control.CURSOR_HSIZE
	label.tooltip_text = "拖拽调整数值"

	var drag_state := {"dragging": false, "start_x": 0.0, "start_value": 0.0}

	label.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton:
			var mb: InputEventMouseButton = event
			if mb.button_index == MOUSE_BUTTON_LEFT:
				if mb.pressed:
					drag_state["dragging"] = true
					drag_state["start_x"] = mb.global_position.x
					drag_state["start_value"] = get_value.call()
				else:
					drag_state["dragging"] = false
		elif event is InputEventMouseMotion:
			if drag_state["dragging"]:
				var delta: float = (event.global_position.x - drag_state["start_x"]) * step
				set_value.call(snapped(drag_state["start_value"] + delta, step if step >= 1.0 else 0.01))
	)
	return label

func _add_placeholder(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_UI)
	label.add_theme_color_override("font_color", IDETheme.C_TEXT_DISABLED)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 20
	_vbox.add_child(spacer)
	_vbox.add_child(label)

func _add_readonly_row(label_text: String, value_text: String) -> void:
	var hbox := _make_row(label_text)
	_vbox.add_child(hbox)
	var value_label := Label.new()
	value_label.text = value_text
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_SMALL)
	value_label.add_theme_color_override("font_color", IDETheme.C_TEXT)
	value_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hbox.add_child(value_label)

func _add_string_row(label_text: String, prop_name: String, value: String, node: Dictionary) -> void:
	var hbox := _make_row(label_text)
	_vbox.add_child(hbox)
	var edit := LineEdit.new()
	edit.text = value
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_SMALL)
	edit.add_theme_color_override("font_color", IDETheme.C_TEXT)
	var edit_sb := StyleBoxFlat.new()
	edit_sb.bg_color = IDETheme.C_BG_DARKER
	edit_sb.corner_radius_top_left = 2
	edit_sb.corner_radius_top_right = 2
	edit_sb.corner_radius_bottom_left = 2
	edit_sb.corner_radius_bottom_right = 2
	edit_sb.content_margin_left = 4.0
	edit_sb.content_margin_right = 4.0
	edit.add_theme_stylebox_override("normal", edit_sb)
	edit.text_submitted.connect(func(new_text: String):
		node["props"][prop_name] = new_text
		property_changed.emit(node, prop_name, new_text)
	)
	hbox.add_child(edit)

func _add_bool_row(label_text: String, prop_name: String, value: bool, node: Dictionary) -> void:
	var hbox := _make_row(label_text)
	_vbox.add_child(hbox)
	var check := CheckBox.new()
	check.button_pressed = value
	check.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_SMALL)
	check.toggled.connect(func(pressed: bool):
		node["props"][prop_name] = pressed
		property_changed.emit(node, prop_name, pressed)
	)
	hbox.add_child(check)

func _add_int_row(label_text: String, prop_name: String, value: int, node: Dictionary) -> void:
	var hbox := _make_row(label_text)
	_vbox.add_child(hbox)
	var spin := SpinBox.new()
	spin.min_value = -999999
	spin.max_value = 999999
	spin.step = 1
	spin.value = value
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_SMALL)
	spin.value_changed.connect(func(new_val: float):
		node["props"][prop_name] = int(new_val)
		property_changed.emit(node, prop_name, int(new_val))
	)
	hbox.add_child(spin)

func _add_float_row(label_text: String, prop_name: String, value: float, node: Dictionary) -> void:
	var hbox := _make_row(label_text)
	_vbox.add_child(hbox)
	var spin := SpinBox.new()
	spin.min_value = -999999
	spin.max_value = 999999
	spin.step = 0.01
	spin.value = value
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_SMALL)
	spin.value_changed.connect(func(new_val: float):
		node["props"][prop_name] = new_val
		property_changed.emit(node, prop_name, new_val)
	)
	hbox.add_child(spin)

func _add_color_row(label_text: String, prop_name: String, value: Color, node: Dictionary) -> void:
	var hbox := _make_row(label_text)
	_vbox.add_child(hbox)
	var color_btn := ColorPickerButton.new()
	color_btn.color = value
	color_btn.custom_minimum_size = Vector2(80, 20)
	color_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	color_btn.color_changed.connect(func(new_color: Color):
		node["props"][prop_name] = new_color
		property_changed.emit(node, prop_name, new_color)
	)
	hbox.add_child(color_btn)

## Vector2行: Godot风格 X/Y 彩色标签 + 可拖拽
func _add_vector2_row(label_text: String, prop_name: String, value: Vector2, node: Dictionary) -> void:
	var hbox := _make_row(label_text)
	_vbox.add_child(hbox)

	var fields := HBoxContainer.new()
	fields.add_theme_constant_override("separation", 2)
	fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(fields)

	# X 分量
	var x_spin := SpinBox.new()
	x_spin.min_value = -999999
	x_spin.max_value = 999999
	x_spin.value = value.x
	x_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	x_spin.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_SMALL)
	x_spin.custom_minimum_size.x = 50

	var x_label := _make_drag_label("X", C_AXIS_X,
		func() -> float: return x_spin.value,
		func(v: float): x_spin.value = v
	)
	fields.add_child(x_label)
	fields.add_child(x_spin)

	# Y 分量
	var y_spin := SpinBox.new()
	y_spin.min_value = -999999
	y_spin.max_value = 999999
	y_spin.value = value.y
	y_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	y_spin.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_SMALL)
	y_spin.custom_minimum_size.x = 50

	var y_label := _make_drag_label("Y", C_AXIS_Y,
		func() -> float: return y_spin.value,
		func(v: float): y_spin.value = v
	)
	fields.add_child(y_label)
	fields.add_child(y_spin)

	# 值变更提交
	var commit := func(_v: float):
		var new_val := Vector2(x_spin.value, y_spin.value)
		node["props"][prop_name] = new_val
		property_changed.emit(node, prop_name, new_val)
	x_spin.value_changed.connect(commit)
	y_spin.value_changed.connect(commit)

## Vector3行: Godot风格 X/Y/Z 彩色标签 + 可拖拽 (3D节点Transform)
func _add_vector3_row(label_text: String, prop_name: String, value: Vector3, node: Dictionary) -> void:
	var hbox := _make_row(label_text)
	_vbox.add_child(hbox)

	var fields := HBoxContainer.new()
	fields.add_theme_constant_override("separation", 2)
	fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(fields)

	var x_spin := SpinBox.new()
	x_spin.min_value = -999999
	x_spin.max_value = 999999
	x_spin.step = 0.01
	x_spin.value = value.x
	x_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	x_spin.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_SMALL)
	x_spin.custom_minimum_size.x = 40

	var x_label := _make_drag_label("X", C_AXIS_X,
		func() -> float: return x_spin.value,
		func(v: float): x_spin.value = v
	)
	fields.add_child(x_label)
	fields.add_child(x_spin)

	var y_spin := SpinBox.new()
	y_spin.min_value = -999999
	y_spin.max_value = 999999
	y_spin.step = 0.01
	y_spin.value = value.y
	y_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	y_spin.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_SMALL)
	y_spin.custom_minimum_size.x = 40

	var y_label := _make_drag_label("Y", C_AXIS_Y,
		func() -> float: return y_spin.value,
		func(v: float): y_spin.value = v
	)
	fields.add_child(y_label)
	fields.add_child(y_spin)

	var z_spin := SpinBox.new()
	z_spin.min_value = -999999
	z_spin.max_value = 999999
	z_spin.step = 0.01
	z_spin.value = value.z
	z_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	z_spin.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_SMALL)
	z_spin.custom_minimum_size.x = 40

	var z_label := _make_drag_label("Z", C_AXIS_Z,
		func() -> float: return z_spin.value,
		func(v: float): z_spin.value = v
	)
	fields.add_child(z_label)
	fields.add_child(z_spin)

	var commit := func(_v: float):
		var new_val := Vector3(x_spin.value, y_spin.value, z_spin.value)
		node["props"][prop_name] = new_val
		property_changed.emit(node, prop_name, new_val)
	x_spin.value_changed.connect(commit)
	y_spin.value_changed.connect(commit)
	z_spin.value_changed.connect(commit)

func _add_typed_row(label_text: String, prop_name: String, value: Variant, node: Dictionary) -> void:
	if value is bool:
		_add_bool_row(label_text, prop_name, value, node)
	elif value is int:
		_add_int_row(label_text, prop_name, value, node)
	elif value is float:
		_add_float_row(label_text, prop_name, value, node)
	elif value is String:
		_add_string_row(label_text, prop_name, value, node)
	elif value is Color:
		_add_color_row(label_text, prop_name, value, node)
	elif value is Vector2:
		_add_vector2_row(label_text, prop_name, value, node)
	elif value is Vector3:
		_add_vector3_row(label_text, prop_name, value, node)
	else:
		_add_readonly_row(label_text, str(value))

# === 多选批量编辑 ===

func _add_batch_section() -> void:
	var common := _get_common_properties()
	if common.is_empty():
		_add_placeholder("所选节点没有共同属性")
		return
	_add_section("共同属性", func():
		for key in common:
			_add_typed_row(str(key), str(key), common[key], _selected_nodes[0])
	)

func _get_common_properties() -> Dictionary:
	if _selected_nodes.is_empty():
		return {}
	var common: Dictionary = {}
	var first_props: Dictionary = _selected_nodes[0].get("props", {})
	for key in first_props:
		var all_same := true
		var first_val: Variant = first_props[key]
		for i in range(1, _selected_nodes.size()):
			var other_props: Dictionary = _selected_nodes[i].get("props", {})
			if not other_props.has(key) or other_props[key] != first_val:
				all_same = false
				break
		if all_same:
			common[key] = first_val
	return common

func _get_custom_properties(props: Dictionary) -> Array[String]:
	var custom: Array[String] = []
	var standard := ["position", "size", "rotation", "scale", "text", "visible", "locked", "color", "metadata", "groups", "connections"]
	for key in props:
		if not standard.has(key):
			custom.append(str(key))
	return custom
