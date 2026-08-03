## IDE节点面板 - 对标 Godot 4.7.1 右侧 "节点" 面板
## 两个子标签: 信号(连接管理) | 分组(Groups标签管理)
## 数据模型: 节点 props["connections"] = [{signal, target_path, method, binds, flags}]
##          节点 props["groups"] = ["group1", "group2"]
extends VBoxContainer

signal connections_changed(node: Dictionary)
signal groups_changed(node: Dictionary)
signal open_script_requested(node: Dictionary, method: String)

const IDETheme = preload("res://scripts/editor/ide/ide_theme.gd")
const Registry = preload("res://scripts/editor/editor_node_registry.gd")
const SignalDialogClass = preload("res://scripts/editor/ide/ide_signal_dialog.gd")

var _selected_node: Dictionary = {}
var _scene_root: Dictionary = {}
var _signal_dialog: AcceptDialog

# UI
var _tab_bar: TabBar
var _signals_page: VBoxContainer
var _groups_page: VBoxContainer
var _signal_header: Label
var _signal_list_box: VBoxContainer
var _group_header: Label
var _group_list_box: VBoxContainer
var _group_edit: LineEdit

func _ready() -> void:
	add_theme_constant_override("separation", 0)
	_build_ui()

func _build_ui() -> void:
	# === 子标签栏: 信号 | 分组 ===
	_tab_bar = TabBar.new()
	_tab_bar.add_tab("信号")
	_tab_bar.add_tab("分组")
	_tab_bar.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_UI)
	_tab_bar.tab_changed.connect(_on_tab_changed)
	add_child(_tab_bar)

	# === 信号页 ===
	_signals_page = VBoxContainer.new()
	_signals_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_signals_page.add_theme_constant_override("separation", 2)
	add_child(_signals_page)

	var sig_toolbar := HBoxContainer.new()
	sig_toolbar.add_theme_constant_override("separation", 4)
	var sig_tb_sb := StyleBoxFlat.new()
	sig_tb_sb.bg_color = IDETheme.C_BG_TOOL
	sig_tb_sb.border_width_bottom = 1
	sig_tb_sb.border_color = IDETheme.C_BORDER
	sig_tb_sb.content_margin_left = 6.0
	sig_tb_sb.content_margin_top = 3.0
	sig_tb_sb.content_margin_bottom = 3.0
	var sig_tb_panel := PanelContainer.new()
	sig_tb_panel.add_theme_stylebox_override("panel", sig_tb_sb)
	sig_tb_panel.add_child(sig_toolbar)
	_signals_page.add_child(sig_tb_panel)

	_signal_header = Label.new()
	_signal_header.text = "信号"
	_signal_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_signal_header.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_UI)
	_signal_header.add_theme_color_override("font_color", IDETheme.C_TEXT)
	sig_toolbar.add_child(_signal_header)

	var btn_connect := Button.new()
	btn_connect.text = "连接..."
	btn_connect.tooltip_text = "连接信号到目标节点"
	btn_connect.custom_minimum_size = Vector2(64, 22)
	IDETheme.style_button(btn_connect, true)
	btn_connect.pressed.connect(_on_connect_pressed)
	sig_toolbar.add_child(btn_connect)

	# 信号列表滚动区
	var sig_scroll := ScrollContainer.new()
	sig_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sig_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_signals_page.add_child(sig_scroll)
	_signal_list_box = VBoxContainer.new()
	_signal_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_signal_list_box.add_theme_constant_override("separation", 2)
	sig_scroll.add_child(_signal_list_box)

	# === 分组页 ===
	_groups_page = VBoxContainer.new()
	_groups_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_groups_page.visible = false
	_groups_page.add_theme_constant_override("separation", 2)
	add_child(_groups_page)

	var grp_toolbar := HBoxContainer.new()
	grp_toolbar.add_theme_constant_override("separation", 4)
	var grp_tb_sb := StyleBoxFlat.new()
	grp_tb_sb.bg_color = IDETheme.C_BG_TOOL
	grp_tb_sb.border_width_bottom = 1
	grp_tb_sb.border_color = IDETheme.C_BORDER
	grp_tb_sb.content_margin_left = 6.0
	grp_tb_sb.content_margin_top = 3.0
	grp_tb_sb.content_margin_bottom = 3.0
	var grp_tb_panel := PanelContainer.new()
	grp_tb_panel.add_theme_stylebox_override("panel", grp_tb_sb)
	grp_tb_panel.add_child(grp_toolbar)
	_groups_page.add_child(grp_tb_panel)

	_group_header = Label.new()
	_group_header.text = "分组"
	_group_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_group_header.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_UI)
	_group_header.add_theme_color_override("font_color", IDETheme.C_TEXT)
	grp_toolbar.add_child(_group_header)

	# 添加分组行
	var grp_add_hbox := HBoxContainer.new()
	grp_add_hbox.add_theme_constant_override("separation", 4)
	var grp_add_sb := StyleBoxFlat.new()
	grp_add_sb.content_margin_left = 6.0
	grp_add_sb.content_margin_top = 4.0
	grp_add_sb.content_margin_right = 6.0
	grp_add_sb.content_margin_bottom = 4.0
	grp_add_hbox.add_theme_stylebox_override("normal", grp_add_sb)
	_groups_page.add_child(grp_add_hbox)

	_group_edit = LineEdit.new()
	_group_edit.placeholder_text = "输入分组名, 回车添加"
	_group_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_group_edit.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_UI)
	_group_edit.text_submitted.connect(_on_group_submitted)
	grp_add_hbox.add_child(_group_edit)

	var btn_add_group := Button.new()
	btn_add_group.text = "添加"
	btn_add_group.custom_minimum_size = Vector2(48, 22)
	IDETheme.style_button(btn_add_group)
	btn_add_group.pressed.connect(func(): _on_group_submitted(_group_edit.text))
	grp_add_hbox.add_child(btn_add_group)

	# 分组列表滚动区
	var grp_scroll := ScrollContainer.new()
	grp_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grp_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_groups_page.add_child(grp_scroll)
	_group_list_box = VBoxContainer.new()
	_group_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_group_list_box.add_theme_constant_override("separation", 2)
	grp_scroll.add_child(_group_list_box)

	# 常用分组提示
	var common_lbl := Label.new()
	common_lbl.text = "常用: " + ", ".join(Registry.get_common_groups())
	common_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	common_lbl.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_SMALL)
	common_lbl.add_theme_color_override("font_color", IDETheme.C_TEXT_DISABLED)
	var common_sb := StyleBoxFlat.new()
	common_sb.content_margin_left = 6.0
	common_sb.content_margin_top = 4.0
	common_lbl.add_theme_stylebox_override("normal", common_sb)
	_groups_page.add_child(common_lbl)

	# === 信号连接对话框 ===
	_signal_dialog = SignalDialogClass.new()
	_signal_dialog.connection_confirmed.connect(_on_connection_confirmed)
	add_child(_signal_dialog)
	# UI就绪后渲染预设节点(防御: set_node可能早于_ready)
	_refresh_all()

# === 公共接口 ===

## 设置当前选中节点 + 场景根(用于目标树)
func set_node(node: Dictionary, scene_root: Dictionary) -> void:
	_selected_node = node
	_scene_root = scene_root
	_refresh_all()

func _on_tab_changed(tab: int) -> void:
	_signals_page.visible = (tab == 0)
	_groups_page.visible = (tab == 1)

func _refresh_all() -> void:
	if _signal_header == null:
		return  # UI尚未构建
	_refresh_signal_header()
	_refresh_signal_list()
	_refresh_group_header()
	_refresh_group_list()

# === 信号 ===

func _refresh_signal_header() -> void:
	if _signal_header == null:
		return
	if _selected_node.is_empty():
		_signal_header.text = "信号"
		return
	_signal_header.text = "%s 的信号" % _selected_node.get("name", "?")

func _refresh_signal_list() -> void:
	if _signal_list_box == null:
		return
	for child in _signal_list_box.get_children():
		child.queue_free()
	if _selected_node.is_empty():
		_signal_list_box.add_child(_make_hint("未选中节点\n在场景树或编辑器中选择节点"))
		return
	var connections: Array = _get_connections()
	if connections.is_empty():
		_signal_list_box.add_child(_make_hint("该节点暂无信号连接\n点击右上角 \"连接...\" 添加"))
		return
	for i in connections.size():
		var conn: Dictionary = connections[i]
		_signal_list_box.add_child(_make_connection_row(conn, i))

func _make_connection_row(conn: Dictionary, index: int) -> Control:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = IDETheme.C_BG_HIGHLIGHT
	sb.corner_radius_top_left = 3
	sb.corner_radius_top_right = 3
	sb.corner_radius_bottom_left = 3
	sb.corner_radius_bottom_right = 3
	sb.content_margin_left = 6.0
	sb.content_margin_top = 3.0
	sb.content_margin_right = 4.0
	sb.content_margin_bottom = 3.0
	panel.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 1)
	panel.add_child(vbox)

	# 第一行: 信号名 + 删除按钮
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 4)
	vbox.add_child(top)
	var sig_icon := Label.new()
	sig_icon.text = "⚡"
	sig_icon.add_theme_color_override("font_color", IDETheme.C_YELLOW)
	sig_icon.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_SMALL)
	top.add_child(sig_icon)
	var sig_lbl := Label.new()
	sig_lbl.text = str(conn.get("signal", ""))
	sig_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sig_lbl.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_UI)
	sig_lbl.add_theme_color_override("font_color", IDETheme.C_TEXT)
	top.add_child(sig_lbl)
	# 跳转方法按钮
	var btn_goto := Button.new()
	btn_goto.text = "↗"
	btn_goto.tooltip_text = "在脚本中打开方法 %s" % str(conn.get("method", ""))
	btn_goto.flat = true
	btn_goto.custom_minimum_size = Vector2(20, 18)
	IDETheme.style_button(btn_goto)
	var method_name: String = conn.get("method", "")
	btn_goto.pressed.connect(func(): open_script_requested.emit(_selected_node, method_name))
	top.add_child(btn_goto)
	# 删除按钮
	var btn_del := Button.new()
	btn_del.text = "✕"
	btn_del.tooltip_text = "断开连接"
	btn_del.flat = true
	btn_del.custom_minimum_size = Vector2(20, 18)
	btn_del.add_theme_color_override("font_color", IDETheme.C_RED)
	btn_del.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_SMALL)
	btn_del.pressed.connect(func(): _remove_connection(index))
	top.add_child(btn_del)

	# 第二行: 目标 → 方法
	var detail := Label.new()
	var binds: Array = conn.get("binds", [])
	var bind_str: String = ""
	if not binds.is_empty():
		bind_str = "  binds=%s" % str(binds)
	detail.text = "→ %s :: %s()%s" % [conn.get("target_path", conn.get("target_name", "?")), conn.get("method", ""), bind_str]
	detail.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_SMALL)
	detail.add_theme_color_override("font_color", IDETheme.C_TEXT_DIM)
	detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	vbox.add_child(detail)

	# 标志
	var flags: int = int(conn.get("flags", 0))
	if flags != 0:
		var flag_lbl := Label.new()
		var flag_parts: Array[String] = []
		if flags & 1:
			flag_parts.append("DEFERRED")
		if flags & 2:
			flag_parts.append("ONE-SHOT")
		flag_lbl.text = "  [" + ", ".join(flag_parts) + "]"
		flag_lbl.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_SMALL)
		flag_lbl.add_theme_color_override("font_color", IDETheme.C_ORANGE)
		vbox.add_child(flag_lbl)

	return panel

func _on_connect_pressed() -> void:
	if _selected_node.is_empty():
		return
	_signal_dialog.open_for_node(_selected_node, _scene_root)

func _on_connection_confirmed(connection: Dictionary) -> void:
	if _selected_node.is_empty():
		return
	var props: Dictionary = _selected_node.get("props", {})
	_selected_node["props"] = props
	if not props.has("connections"):
		props["connections"] = []
	# 存储精简连接数据 (target存路径+名称, 避免循环引用)
	props["connections"].append({
		"signal": connection.get("signal", ""),
		"signal_args": connection.get("signal_args", []),
		"target_path": connection.get("target_path", ""),
		"target_name": connection.get("target_name", ""),
		"method": connection.get("method", ""),
		"binds": connection.get("binds", []),
		"flags": connection.get("flags", 0),
	})
	_refresh_signal_list()
	connections_changed.emit(_selected_node)

func _remove_connection(index: int) -> void:
	var connections: Array = _get_connections()
	if index >= 0 and index < connections.size():
		connections.remove_at(index)
		_refresh_signal_list()
		connections_changed.emit(_selected_node)

func _get_connections() -> Array:
	if _selected_node.is_empty():
		return []
	var props: Dictionary = _selected_node.get("props", {})
	var conns: Variant = props.get("connections", [])
	if conns is Array:
		return conns
	return []

# === 分组 ===

func _refresh_group_header() -> void:
	if _group_header == null:
		return
	if _selected_node.is_empty():
		_group_header.text = "分组"
		return
	var groups: Array = _get_groups()
	_group_header.text = "%s 的分组 (%d)" % [_selected_node.get("name", "?"), groups.size()]

func _refresh_group_list() -> void:
	if _group_list_box == null:
		return
	for child in _group_list_box.get_children():
		child.queue_free()
	if _selected_node.is_empty():
		_group_list_box.add_child(_make_hint("未选中节点"))
		return
	var groups: Array = _get_groups()
	if groups.is_empty():
		_group_list_box.add_child(_make_hint("该节点暂无分组\n在上方输入分组名添加"))
		return
	for i in groups.size():
		_group_list_box.add_child(_make_group_row(str(groups[i]), i))

func _make_group_row(group_name: String, index: int) -> Control:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	var sb := StyleBoxFlat.new()
	sb.content_margin_left = 8.0
	sb.content_margin_top = 2.0
	sb.content_margin_bottom = 2.0
	hbox.add_theme_stylebox_override("normal", sb)

	var icon := Label.new()
	icon.text = "🏷"
	icon.add_theme_color_override("font_color", IDETheme.C_GREEN)
	icon.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_SMALL)
	hbox.add_child(icon)

	var lbl := Label.new()
	lbl.text = group_name
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_UI)
	lbl.add_theme_color_override("font_color", IDETheme.C_TEXT)
	hbox.add_child(lbl)

	var btn_del := Button.new()
	btn_del.text = "✕"
	btn_del.tooltip_text = "移除分组"
	btn_del.flat = true
	btn_del.custom_minimum_size = Vector2(20, 18)
	btn_del.add_theme_color_override("font_color", IDETheme.C_RED)
	btn_del.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_SMALL)
	btn_del.pressed.connect(func(): _remove_group(index))
	hbox.add_child(btn_del)
	return hbox

func _on_group_submitted(text: String) -> void:
	var group_name: String = text.strip_edges()
	if _group_edit != null:
		_group_edit.text = ""
	if group_name.is_empty() or _selected_node.is_empty():
		return
	var props: Dictionary = _selected_node.get("props", {})
	_selected_node["props"] = props
	if not props.has("groups"):
		props["groups"] = []
	var groups: Array = props["groups"]
	if groups.has(group_name):
		return  # 去重
	groups.append(group_name)
	_refresh_group_header()
	_refresh_group_list()
	groups_changed.emit(_selected_node)

func _remove_group(index: int) -> void:
	var groups: Array = _get_groups()
	if index >= 0 and index < groups.size():
		groups.remove_at(index)
		_refresh_group_header()
		_refresh_group_list()
		groups_changed.emit(_selected_node)

func _get_groups() -> Array:
	if _selected_node.is_empty():
		return []
	var props: Dictionary = _selected_node.get("props", {})
	var groups: Variant = props.get("groups", [])
	if groups is Array:
		return groups
	return []

# === 辅助 ===

func _make_hint(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_SMALL)
	label.add_theme_color_override("font_color", IDETheme.C_TEXT_DISABLED)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var sb := StyleBoxFlat.new()
	sb.content_margin_top = 12.0
	label.add_theme_stylebox_override("normal", sb)
	return label
