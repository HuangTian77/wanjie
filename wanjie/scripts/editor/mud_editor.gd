## MUD编辑器模块 - 复刻 MUDEditor.exe
## 暗色/编辑器风格 + MudData 内部模式层 + 导出/导入管道。
## 公共 API 保持兼容：build_into(parent) / load_data(ws) / save_data()。
## 数据存于 world_script.metadata["mud_data"]（新内部格式 _schema_version=2，
## 兼容旧导出格式自动走 MudImport 转换）。
## 阶段2：15 标签页（含子标签/表单/按钮）由 MudTabBuilder 配置驱动构建。
extends Control

# ===================== 暗色主题配色 =====================
const C_BG := Color(0.125, 0.125, 0.145, 1)      # 主背景
const C_PANEL := Color(0.165, 0.165, 0.195, 1)   # 面板底色
const C_PANEL2 := Color(0.20, 0.20, 0.24, 1)     # 次级面板/表头
const C_BORDER := Color(0.30, 0.30, 0.36, 1)     # 边框
const C_TEXT := Color(0.86, 0.86, 0.90, 1)       # 主文本
const C_LABEL := Color(0.58, 0.58, 0.66, 1)      # 标签/次要文本
const C_SELECTED := Color(0.28, 0.47, 0.78, 1)   # 选中高亮
const C_HOVER := Color(0.23, 0.23, 0.29, 1)      # 悬停
const C_ACCENT := Color(0.95, 0.75, 0.35, 1)     # 强调色（MUD模式标识）

# ===================== 数据与状态 =====================
var world_script: WorldScriptData = null
var _data: MudData = MudData.new()
var _tab_builder: MudTabBuilder = null
## 当前画布显示的地图 id
var _cur_map_id: int = 0
## 点击空地后待新建场景的格子（1 基准）；(-1,-1) 表示无
var _pending_new_cell: Vector2i = Vector2i(-1, -1)

# ===================== UI 节点引用 =====================
var _status_label: Label = null
var _map_canvas: MudMapCanvas = null
var _map_select: OptionButton = null
var _map_w_label: Label = null
var _map_h_label: Label = null
var _scene_name_edit: LineEdit = null
var _scene_desc_edit: LineEdit = null
var _scene_uporadd_btn: Button = null
var _obj_list: ItemList = null

func _ready() -> void:
	pass

# ===================== 公共 API（保持集成兼容） =====================

func build_into(parent: Node) -> void:
	_build_ui(parent)
	if _tab_builder:
		_tab_builder.refresh_all()

func load_data(ws: WorldScriptData) -> void:
	world_script = ws
	if ws == null:
		return
	var meta: Dictionary = ws.metadata
	var mud_val: Variant = meta.get("mud_data", null)
	if mud_val is Dictionary:
		var d: Dictionary = mud_val as Dictionary
		if MudData.is_internal_format(d):
			# 新内部格式：直接加载
			_data.from_dict(d)
		elif MudImport.is_export_format(d):
			# 旧导出格式：反解析转换（向后兼容）
			_data = MudImport.from_dict(d)
		else:
			_data = _make_default_data()
	else:
		# 无保存数据：尝试从 mud_engine/data 导入
		_data = _load_from_engine_data()
	_sync_builder_data()

func save_data() -> void:
	if world_script == null:
		return
	world_script.metadata["mud_data"] = _data.to_dict()
	# 连接目标校验提示（linkpath 引用的场景不存在）
	_validate_links()

## 校验连接：linkpath 引用的场景是否存在于 room 表
func _validate_links() -> void:
	var missing: Array[String] = []
	for row in _data.rows.get("linkpath", []):
		var sp: Variant = row.get("startpot", null)
		var ep: Variant = row.get("endpot", null)
		if sp != null and not _data.rows.get("room", []).any(func(r): return r.get("id") == sp):
			missing.append("起点 %s" % str(sp))
		if ep != null and not _data.rows.get("room", []).any(func(r): return r.get("id") == ep):
			missing.append("终点 %s" % str(ep))
	if not missing.is_empty():
		ToastManager.warning("MUD 连接引用缺失：%s" % "、".join(missing))

## 数据层可能被替换（导入/新建），同步到构建器并刷新全部标签
func _sync_builder_data() -> void:
	if _tab_builder:
		_tab_builder.set_data(_data)
		_tab_builder.refresh_all()
	_connect_data_signals()
	_refresh_map_selector()
	_refresh_quickedit()
	_refresh_object_list()

## 连接数据层信号（_data 被替换后重新连接；同一实例不重复连）
func _connect_data_signals() -> void:
	if not _data.table_changed.is_connected(_on_data_table_changed):
		_data.table_changed.connect(_on_data_table_changed)
	if not _data.data_reset.is_connected(_on_data_reset):
		_data.data_reset.connect(_on_data_reset)

func _on_data_table_changed(table: String) -> void:
	match table:
		"scene", "linkpath":
			if _map_canvas:
				_map_canvas.queue_redraw()
		"map":
			_refresh_map_selector()

func _on_data_reset() -> void:
	_refresh_map_selector()
	_refresh_quickedit()
	_refresh_object_list()

# ===================== 默认数据 =====================

func _make_default_data() -> MudData:
	var d := MudData.new()
	d.add_row("map", {"name": "主地图", "width": 10, "height": 10, "desc": ""})
	d.add_row("scene", {"name": "初始之地", "desc": "旅程开始的地方。", "x": 5, "y": 5, "mapid": 1})
	d.config_set("game_born_point", 1)
	d.config_set("map_move_time", 300)
	return d

func _load_from_engine_data() -> MudData:
	var dir: String = MudExport.DEFAULT_OUT_DIR
	if DirAccess.dir_exists_absolute(dir):
		return MudImport.from_dir(dir)
	return _make_default_data()

# ===================== UI 构建 =====================

func _build_ui(parent: Node) -> void:
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 0)
	parent.add_child(root)

	_build_toolbar(root)

	var hsplit := HSplitContainer.new()
	hsplit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hsplit.dragger_visibility = SplitContainer.DRAGGER_VISIBLE
	hsplit.split_offset = 480
	root.add_child(hsplit)

	_build_left_panel(hsplit)
	_build_right_panel(hsplit)

	_build_status_bar(root)
	_set_status("MUD 数据编辑器就绪：15 个数据表标签页（地图/物品/NPC/技能等），修改自动保存")

func _build_toolbar(parent: VBoxContainer) -> void:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_PANEL
	sb.border_width_bottom = 1
	sb.border_color = C_BORDER
	sb.content_margin_left = 6.0
	sb.content_margin_top = 3.0
	sb.content_margin_right = 6.0
	sb.content_margin_bottom = 3.0
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size.y = 42
	parent.add_child(panel)

	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 4)
	panel.add_child(toolbar)

	# 左侧：文件操作
	_tb_btn(toolbar, "新建", Color(0.55, 0.8, 0.55), _on_new)
	_tb_btn(toolbar, "打开", Color(0.55, 0.7, 0.95), _on_open)
	_tb_btn(toolbar, "保存", Color(0.9, 0.8, 0.5), _on_save)
	_tb_btn(toolbar, "另存为", Color(0.7, 0.7, 0.75), _on_save_as)

	var sep1 := VSeparator.new()
	toolbar.add_child(sep1)

	_tb_btn(toolbar, "导出", C_ACCENT, _on_export)
	_tb_btn(toolbar, "自动排列", Color(0.6, 0.8, 0.6), _on_auto_arrange)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(spacer)

	# 右侧：功能入口（后续阶段接通）
	_tb_btn(toolbar, "清空数据", Color(0.85, 0.5, 0.5), _on_clear_data)
	_tb_btn(toolbar, "全局配置", Color(0.75, 0.75, 0.55), _on_global_config)

func _tb_btn(toolbar: HBoxContainer, text: String, color: Color, handler: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.flat = true
	btn.add_theme_font_size_override("font_size", 12)
	btn.add_theme_color_override("font_color", color)
	btn.add_theme_color_override("font_hover_color", color.lightened(0.25))
	btn.custom_minimum_size = Vector2(56, 34)
	btn.pressed.connect(handler)
	toolbar.add_child(btn)
	return btn

func _build_left_panel(parent: HSplitContainer) -> void:
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(left)

	_build_map_selector_bar(left)

	# 地图画布（滚动容器内）
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var scroll_sb := StyleBoxFlat.new()
	scroll_sb.bg_color = C_PANEL
	scroll_sb.border_width_top = 1
	scroll_sb.border_width_right = 1
	scroll_sb.border_color = C_BORDER
	scroll.add_theme_stylebox_override("panel", scroll_sb)
	left.add_child(scroll)

	_map_canvas = MudMapCanvas.new()
	_map_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map_canvas.set_data(_data, _cur_map_id)
	_map_canvas.scene_selected.connect(_on_canvas_scene_selected)
	_map_canvas.scene_activated.connect(_on_canvas_scene_activated)
	_map_canvas.empty_cell_clicked.connect(_on_canvas_empty_cell)
	_map_canvas.scene_move_requested.connect(_on_canvas_move)
	_map_canvas.scene_swap_requested.connect(_on_canvas_swap)
	_map_canvas.link_target_chosen.connect(_on_canvas_link_target)
	_map_canvas.node_context_requested.connect(_on_canvas_node_context)
	_map_canvas.blank_context_requested.connect(_on_canvas_blank_context)
	_map_canvas.hint_message.connect(_set_status)
	scroll.add_child(_map_canvas)

	_build_scene_quickedit(left)

func _build_map_selector_bar(parent: VBoxContainer) -> void:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_PANEL
	sb.border_width_bottom = 1
	sb.border_width_right = 1
	sb.border_color = C_BORDER
	sb.content_margin_left = 8.0
	sb.content_margin_top = 4.0
	sb.content_margin_right = 8.0
	sb.content_margin_bottom = 4.0
	panel.add_theme_stylebox_override("panel", sb)
	parent.add_child(panel)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	panel.add_child(bar)

	var lbl := Label.new()
	lbl.text = "当前地图:"
	lbl.add_theme_color_override("font_color", C_LABEL)
	lbl.add_theme_font_size_override("font_size", 12)
	bar.add_child(lbl)

	_map_select = OptionButton.new()
	_map_select.custom_minimum_size.x = 180
	_map_select.item_selected.connect(_on_map_selected)
	bar.add_child(_map_select)

	_map_w_label = Label.new()
	_map_w_label.text = "宽: -"
	_map_w_label.add_theme_color_override("font_color", C_LABEL)
	_map_w_label.add_theme_font_size_override("font_size", 12)
	bar.add_child(_map_w_label)

	_map_h_label = Label.new()
	_map_h_label.text = "高: -"
	_map_h_label.add_theme_color_override("font_color", C_LABEL)
	_map_h_label.add_theme_font_size_override("font_size", 12)
	bar.add_child(_map_h_label)

func _build_scene_quickedit(parent: VBoxContainer) -> void:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_PANEL
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_color = C_BORDER
	sb.content_margin_left = 8.0
	sb.content_margin_top = 6.0
	sb.content_margin_right = 8.0
	sb.content_margin_bottom = 6.0
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size.y = 150
	parent.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	# 第一行：地点名称 + 描述 + 新建/更新
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 6)
	vbox.add_child(row1)

	var lbl_name := Label.new()
	lbl_name.text = "地点名称:"
	lbl_name.add_theme_color_override("font_color", C_LABEL)
	lbl_name.add_theme_font_size_override("font_size", 12)
	row1.add_child(lbl_name)

	_scene_name_edit = LineEdit.new()
	_scene_name_edit.custom_minimum_size.x = 120
	row1.add_child(_scene_name_edit)

	var lbl_desc := Label.new()
	lbl_desc.text = "描述:"
	lbl_desc.add_theme_color_override("font_color", C_LABEL)
	lbl_desc.add_theme_font_size_override("font_size", 12)
	row1.add_child(lbl_desc)

	_scene_desc_edit = LineEdit.new()
	_scene_desc_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_child(_scene_desc_edit)

	_scene_uporadd_btn = Button.new()
	_scene_uporadd_btn.text = "新建"
	_scene_uporadd_btn.pressed.connect(_on_uporadd)
	row1.add_child(_scene_uporadd_btn)

	vbox.add_child(HSeparator.new())

	# 第二行：场景内对象 + 按钮
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 6)
	vbox.add_child(row2)

	var lbl_obj := Label.new()
	lbl_obj.text = "场景内对象"
	lbl_obj.add_theme_color_override("font_color", C_LABEL)
	lbl_obj.add_theme_font_size_override("font_size", 12)
	row2.add_child(lbl_obj)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row2.add_child(spacer)

	var btn_add_obj := Button.new()
	btn_add_obj.text = "新建对象"
	btn_add_obj.pressed.connect(_on_add_object_to_scene)
	row2.add_child(btn_add_obj)

	var btn_rm_obj := Button.new()
	btn_rm_obj.text = "移除选中"
	btn_rm_obj.pressed.connect(_on_remove_object_from_scene)
	row2.add_child(btn_rm_obj)

	_obj_list = ItemList.new()
	_obj_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_obj_list.custom_minimum_size.y = 56
	vbox.add_child(_obj_list)

func _build_right_panel(parent: HSplitContainer) -> void:
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(right)

	# 配置驱动构建 15 标签页（含子标签/表单/按钮/CRUD）
	_tab_builder = MudTabBuilder.new(_data)
	_tab_builder.status_message.connect(_set_status)
	_tab_builder.advanced_edit_requested.connect(_on_advanced_edit)
	_tab_builder.csv_export_requested.connect(_on_csv_export)
	_tab_builder.csv_import_requested.connect(_on_csv_import)
	_tab_builder.build(right)

func _build_status_bar(parent: VBoxContainer) -> void:
	var bar := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_PANEL
	sb.border_width_top = 1
	sb.border_color = C_BORDER
	sb.content_margin_left = 8.0
	sb.content_margin_top = 3.0
	sb.content_margin_bottom = 3.0
	bar.add_theme_stylebox_override("panel", sb)
	bar.custom_minimum_size.y = 24
	parent.add_child(bar)

	_status_label = Label.new()
	_status_label.text = "就绪"
	_status_label.add_theme_color_override("font_color", C_LABEL)
	_status_label.add_theme_font_size_override("font_size", 11)
	bar.add_child(_status_label)

func _set_status(msg: String) -> void:
	if _status_label:
		_status_label.text = msg

# ===================== 构建器信号处理（高级编辑对话框派发） =====================

## 高级编辑派发：按表名打开对应的编辑对话框（阶段4核心7表，其余阶段5）
func _on_advanced_edit(table: String, id: Variant) -> void:
	var rid: int = int(id)
	match table:
		"scene":
			_open_edit_dialog(MudEditScene.new(), table, rid)
		"linkpath":
			_open_edit_dialog(MudEditPath.new(), table, rid)
		"property":
			_open_edit_dialog(MudEditProperty.new(), table, rid)
		"skill":
			_open_edit_dialog(MudEditSkill.new(), table, rid)
		"item":
			_open_edit_dialog(MudEditItem.new(), table, rid)
		"module_talk":
			_open_edit_dialog(MudEditTalk.new(), table, rid)
		"scene_object":
			_open_scene_object_dialog(rid)
		_:
			if MudSchemaInternal.has_table(table):
				_open_edit_dialog(MudEditGeneric.new(), table, rid)
			else:
				_set_status("未知表「%s」" % table)


## 打开通用编辑对话框（独立顶层类），接通 saved 信号刷新视图
func _open_edit_dialog(dlg: MudEditDialogBase, table: String, rid: int) -> void:
	add_child(dlg)
	dlg.saved.connect(_on_dialog_saved)
	_auto_free_on_close(dlg)
	dlg.open_dialog(_data, table, rid, _dialog_title(table, rid))


## 场景对象编辑：从 scene_object 行 id 反查 sceneid，打开场景对象面板
func _open_scene_object_dialog(so_id: int) -> void:
	var so: Dictionary = _data.get_row_by_id("scene_object", so_id)
	if so.is_empty():
		_set_status("未找到场景对象 #%d" % so_id)
		return
	var scene_id: int = int(so.get("sceneid", 0))
	var dlg := MudEditSceneObject.new()
	add_child(dlg)
	dlg.saved.connect(_on_dialog_saved)
	_auto_free_on_close(dlg)
	var sc: Dictionary = _data.get_row_by_id("scene", scene_id)
	dlg.open_for_scene(_data, scene_id, "编辑场景对象「%s」" % str(sc.get("name", "")))


## 窗口关闭后自动释放（本构建无 popup_hide 信号，用 visibility_changed 代替）
func _auto_free_on_close(win: Window) -> void:
	win.visibility_changed.connect(func():
		if not win.visible:
			win.queue_free()
	)


## 对话框保存后刷新相关视图
func _on_dialog_saved(table: String, id: int) -> void:
	if _tab_builder:
		_tab_builder.refresh_table(table)
		if table == "scene":
			_tab_builder.refresh_table("scene_object")
	match table:
		"scene", "linkpath", "scene_object":
			if _map_canvas:
				_map_canvas.queue_redraw()
			_refresh_quickedit()
			_refresh_object_list()
	_set_status("已保存 [%s] #%s" % [table, str(id)])


## 生成对话框标题：编辑{表描述}「名称」
func _dialog_title(table: String, rid: int) -> String:
	var desc: String = str(MudSchemaInternal.get_table(table).get("desc", table))
	var row: Dictionary = _data.get_row_by_id(table, rid)
	var nm: String = str(row.get("name", ""))
	if nm.is_empty():
		return "编辑 %s #%d" % [desc, rid]
	return "编辑 %s「%s」" % [desc, nm]


func _on_csv_export(table: String, noun: String) -> void:
	var fd := FileDialog.new()
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	fd.title = "导出 %s 到 CSV" % noun
	fd.add_filter("*.csv", "CSV 文件")
	fd.current_file = "%s.csv" % table
	fd.min_size = Vector2(720, 480)
	add_child(fd)
	_auto_free_on_close(fd)
	fd.file_selected.connect(func(path: String):
		var ok: bool = MudCsv.export_to_file(_data, table, path)
		_set_status(("已导出 %s → %s" % [noun, path]) if ok else ("导出 %s 失败" % noun))
	)
	fd.popup_centered()


func _on_csv_import(table: String, noun: String) -> void:
	var fd := FileDialog.new()
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.title = "从 CSV 导入 %s" % noun
	fd.add_filter("*.csv", "CSV 文件")
	fd.min_size = Vector2(720, 480)
	add_child(fd)
	_auto_free_on_close(fd)
	fd.file_selected.connect(func(path: String):
		var cnt: int = MudCsv.import_from_file(_data, table, path)
		if cnt < 0:
			_set_status("导入 %s 失败（无法读取 %s）" % [noun, path])
		else:
			if _tab_builder:
				_tab_builder.refresh_table(table)
			_set_status("已导入 %s 条记录 ← %s" % [str(cnt), path])
			# 导入后校验连接引用
			_validate_links()
	)
	fd.popup_centered()

# ===================== 地图画布 =====================

## 刷新地图选择器（保持当前选中地图，无效则选第一个）并同步画布
func _refresh_map_selector() -> void:
	if _map_select == null:
		return
	var maps: Array = _data.get_table("map")
	var prev_id: int = _cur_map_id
	_map_select.clear()
	var found: bool = false
	for m in maps:
		var mid: int = int((m as Dictionary).get("id", 0))
		_map_select.add_item("%s (#%d)" % [str((m as Dictionary).get("name", "")), mid], mid)
		if mid == prev_id:
			found = true
	if maps.size() > 0:
		if not found:
			_cur_map_id = int((maps[0] as Dictionary).get("id", 0))
		for i in _map_select.item_count:
			if _map_select.get_item_id(i) == _cur_map_id:
				_map_select.select(i)
				break
	else:
		_cur_map_id = 0
	_update_map_size_labels()
	if _map_canvas:
		_map_canvas.set_data(_data, _cur_map_id)

func _update_map_size_labels() -> void:
	var m: Dictionary = _data.get_row_by_id("map", _cur_map_id)
	if m.is_empty():
		_map_w_label.text = "宽: -"
		_map_h_label.text = "高: -"
	else:
		_map_w_label.text = "宽: %d" % int(m.get("width", 0))
		_map_h_label.text = "高: %d" % int(m.get("height", 0))

func _on_map_selected(idx: int) -> void:
	if idx < 0:
		return
	_cur_map_id = _map_select.get_item_id(idx)
	_update_map_size_labels()
	if _map_canvas:
		_map_canvas.set_map(_cur_map_id)
	_refresh_quickedit()
	_refresh_object_list()

func _on_canvas_scene_selected(id: int) -> void:
	_pending_new_cell = Vector2i(-1, -1)
	_refresh_quickedit()
	_refresh_object_list()
	_set_status("选中场景 #%d" % id)

func _on_canvas_scene_activated(id: int) -> void:
	_on_advanced_edit("scene", id)

func _on_canvas_empty_cell(x: int, y: int) -> void:
	_pending_new_cell = Vector2i(x, y)
	if _map_canvas:
		_map_canvas.set_selected(0)
	_refresh_quickedit()
	_refresh_object_list()
	if _scene_name_edit and _scene_name_edit.is_inside_tree():
		_scene_name_edit.grab_focus()
	_set_status("点击空地 (%d,%d)：输入名称后点「新建」" % [x, y])

func _on_canvas_move(id: int, x: int, y: int) -> void:
	_data.update_row("scene", id, {"x": x, "y": y})
	if _map_canvas:
		_map_canvas.queue_redraw()
	_set_status("场景 #%d 移动到 (%d,%d)" % [id, x, y])

func _on_canvas_swap(id1: int, id2: int) -> void:
	var s1: Dictionary = _data.get_row_by_id("scene", id1)
	var s2: Dictionary = _data.get_row_by_id("scene", id2)
	if s1.is_empty() or s2.is_empty():
		return
	var x1: Variant = s1.get("x")
	var y1: Variant = s1.get("y")
	_data.update_row("scene", id1, {"x": s2.get("x"), "y": s2.get("y")})
	_data.update_row("scene", id2, {"x": x1, "y": y1})
	if _map_canvas:
		_map_canvas.queue_redraw()
	_set_status("交换场景 #%d 与 #%d 的位置" % [id1, id2])

func _on_canvas_link_target(start_id: int, target_id: int, direct: String, bidir: bool) -> void:
	_data.link_scene(start_id, target_id, direct, bidir)
	if _map_canvas:
		_map_canvas.queue_redraw()
	if _tab_builder:
		_tab_builder.refresh_table("linkpath")
	_set_status("已建立 #%d → #%d [%s] 路径（%s）" % [
		start_id, target_id,
		MudSchemaInternal.DIRECTION_NAMES.get(direct, direct),
		"双向" if bidir else "单向"])

func _on_canvas_node_context(id: int, global_pos: Vector2) -> void:
	if _map_canvas:
		_map_canvas.set_selected(id)
	_refresh_quickedit()
	_refresh_object_list()

	var menu := PopupMenu.new()
	menu.name = "NodeCtxMenu"
	add_child(menu)

	var sub_b := PopupMenu.new()
	sub_b.name = "SubBidir"
	menu.add_child(sub_b)
	var sub_u := PopupMenu.new()
	sub_u.name = "SubUnidir"
	menu.add_child(sub_u)

	for i in MudSchemaInternal.DIRECTIONS.size():
		var dn: String = MudSchemaInternal.DIRECTION_NAMES.get(MudSchemaInternal.DIRECTIONS[i], "")
		sub_b.add_item(dn, 100 + i)
		sub_u.add_item(dn, 200 + i)

	sub_b.id_pressed.connect(func(item_id: int):
		var d: String = MudSchemaInternal.DIRECTIONS[item_id - 100]
		if _map_canvas:
			_map_canvas.enter_link_mode(id, d, true)
	)
	sub_u.id_pressed.connect(func(item_id: int):
		var d: String = MudSchemaInternal.DIRECTIONS[item_id - 200]
		if _map_canvas:
			_map_canvas.enter_link_mode(id, d, false)
	)

	menu.add_submenu_item("增加双向路径 ▸", "SubBidir")
	menu.add_submenu_item("增加单向路径 ▸", "SubUnidir")
	menu.add_separator()
	menu.add_item("编辑场景", 1)
	menu.add_item("删除场景", 2)
	menu.add_separator()
	menu.add_item("新建对象到场景", 3)

	menu.id_pressed.connect(func(item_id: int):
		_on_node_ctx_action(id, item_id)
	)
	_auto_free_on_close(menu)
	menu.popup(Rect2i(Vector2i(global_pos), Vector2i(190, 170)))

func _on_node_ctx_action(id: int, item_id: int) -> void:
	match item_id:
		1:
			_on_advanced_edit("scene", id)
		2:
			_confirm_delete_scene(id)
		3:
			_open_add_object_dialog(id)

func _on_canvas_blank_context(x: int, y: int, global_pos: Vector2) -> void:
	var menu := PopupMenu.new()
	menu.name = "BlankCtxMenu"
	add_child(menu)
	menu.add_item("新建地点", 1)
	menu.id_pressed.connect(func(_item_id: int):
		_on_canvas_empty_cell(x, y)
	)
	_auto_free_on_close(menu)
	menu.popup(Rect2i(Vector2i(global_pos), Vector2i(140, 40)))

func _confirm_delete_scene(id: int) -> void:
	var scene: Dictionary = _data.get_row_by_id("scene", id)
	var confirm := ConfirmationDialog.new()
	confirm.title = "删除场景"
	confirm.dialog_text = "删除场景「%s」会同时删除所有相关路径和场景对象绑定，确认删除？" % str(scene.get("name", ""))
	confirm.confirmed.connect(func():
		_data.del_scene(id)
		if _map_canvas:
			_map_canvas.queue_redraw()
		if _tab_builder:
			_tab_builder.refresh_table("scene")
			_tab_builder.refresh_table("linkpath")
			_tab_builder.refresh_table("scene_object")
		_refresh_quickedit()
		_refresh_object_list()
		_set_status("已删除场景 #%d（级联删除路径/对象绑定）" % id)
	)
	_auto_free_on_close(confirm)
	add_child(confirm)
	confirm.popup_centered()

func _open_add_object_dialog(scene_id: int) -> void:
	# 注意：本项目 Godot 构建的 ClassDB 中无 AcceptanceDialog，用 ConfirmationDialog 代替
	var dlg := ConfirmationDialog.new()
	dlg.title = "新建互动对象到场景"
	dlg.ok_button_text = "新建"
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	var l1 := Label.new()
	l1.text = "对象名称:"
	vb.add_child(l1)
	var name_edit := LineEdit.new()
	name_edit.custom_minimum_size.x = 240
	vb.add_child(name_edit)
	var l2 := Label.new()
	l2.text = "对象描述:"
	vb.add_child(l2)
	var desc_edit := TextEdit.new()
	desc_edit.custom_minimum_size = Vector2(240, 80)
	vb.add_child(desc_edit)
	dlg.add_child(vb)
	dlg.confirmed.connect(func():
		var n: String = name_edit.text.strip_edges()
		if n == "":
			n = "未命名对象"
		var obj: Dictionary = _data.add_object({"name": n, "desc": desc_edit.text})
		if not obj.is_empty():
			_data.add_object_to_scene(scene_id, obj.get("id"))
			if _tab_builder:
				_tab_builder.refresh_table("object")
				_tab_builder.refresh_table("scene_object")
			_refresh_object_list()
			_set_status("已新建对象「%s」并加入场景 #%d" % [n, scene_id])
	)
	_auto_free_on_close(dlg)
	add_child(dlg)
	dlg.popup_centered(Vector2i(320, 250))

# ---- 场景快捷编辑面板 ----

func _refresh_quickedit() -> void:
	if _scene_name_edit == null:
		return
	var sel_id: int = _map_canvas.get_selected_id() if _map_canvas else 0
	if sel_id != 0:
		var scene: Dictionary = _data.get_row_by_id("scene", sel_id)
		if not scene.is_empty():
			_scene_name_edit.text = str(scene.get("name", ""))
			_scene_desc_edit.text = str(scene.get("desc", ""))
			_scene_uporadd_btn.text = "更新"
			_pending_new_cell = Vector2i(-1, -1)
			return
	_scene_name_edit.text = ""
	_scene_desc_edit.text = ""
	_scene_uporadd_btn.text = "新建"

func _on_uporadd() -> void:
	var sel_id: int = _map_canvas.get_selected_id() if _map_canvas else 0
	var n: String = _scene_name_edit.text.strip_edges()
	var d: String = _scene_desc_edit.text
	if sel_id != 0:
		_data.update_row("scene", sel_id, {"name": n, "desc": d})
		if _map_canvas:
			_map_canvas.queue_redraw()
		if _tab_builder:
			_tab_builder.refresh_table("scene")
		_set_status("已更新场景 #%d" % sel_id)
	elif _pending_new_cell.x >= 0:
		if n == "":
			n = "未命名地点"
		var scene: Dictionary = _data.add_row("scene", {
			"name": n, "desc": d,
			"x": _pending_new_cell.x, "y": _pending_new_cell.y,
			"mapid": _cur_map_id,
		})
		if not scene.is_empty():
			var nid: int = int(scene.get("id", 0))
			if _map_canvas:
				_map_canvas.set_selected(nid)
				_map_canvas.queue_redraw()
			if _tab_builder:
				_tab_builder.refresh_table("scene")
			_refresh_quickedit()
			_refresh_object_list()
			_set_status("已新建场景「%s」于 (%d,%d)" % [n, _pending_new_cell.x, _pending_new_cell.y])
	else:
		_set_status("请先在地图上点选场景或空地")

func _refresh_object_list() -> void:
	if _obj_list == null:
		return
	_obj_list.clear()
	var sel_id: int = _map_canvas.get_selected_id() if _map_canvas else 0
	if sel_id == 0:
		return
	for b in _data.get_objects_by_scene(sel_id):
		var bind: Dictionary = b as Dictionary
		var objid: int = int(bind.get("objid", 0))
		var obj: Dictionary = _data.get_row_by_id("object", objid)
		var oname: String = str(obj.get("name", ""))
		if oname == "":
			oname = "#%d" % objid
		_obj_list.add_item(oname)
		_obj_list.set_item_metadata(_obj_list.item_count - 1, {"objid": objid})

func _on_add_object_to_scene() -> void:
	var sel_id: int = _map_canvas.get_selected_id() if _map_canvas else 0
	if sel_id == 0:
		_set_status("请先选中场景")
		return
	_open_add_object_dialog(sel_id)

func _on_remove_object_from_scene() -> void:
	var sel_id: int = _map_canvas.get_selected_id() if _map_canvas else 0
	if sel_id == 0:
		_set_status("请先选中场景")
		return
	var idxs: PackedInt32Array = _obj_list.get_selected_items()
	if idxs.size() == 0:
		_set_status("请在对象列表中选中要移除的对象")
		return
	var meta: Dictionary = _obj_list.get_item_metadata(idxs[0])
	var objid: int = int(meta.get("objid", 0))
	_data.del_object_from_scene(sel_id, objid)
	if _tab_builder:
		_tab_builder.refresh_table("scene_object")
	_refresh_object_list()
	_set_status("已从场景 #%d 移除对象 #%d" % [sel_id, objid])

# ===================== 工具栏处理 =====================

func _on_new() -> void:
	_data = _make_default_data()
	_sync_builder_data()
	_set_status("已新建空白MUD数据")

func _on_open() -> void:
	_data = _load_from_engine_data()
	_sync_builder_data()
	_set_status("已从 %s 导入数据" % MudExport.DEFAULT_OUT_DIR)

func _on_save() -> void:
	save_data()
	_set_status("已保存到剧本 metadata")
	if has_node("/root/ToastManager"):
		get_node("/root/ToastManager").success("MUD 数据已保存")

func _on_save_as() -> void:
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.add_filter("*.json", "MUD内部数据")
	dialog.title = "另存为 MUD 内部数据"
	dialog.file_selected.connect(func(path: String):
		var json_str: String = JSON.stringify(_data.to_dict(), "  ")
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f:
			f.store_string(json_str)
			f.close()
			_set_status("已另存为: " + path)
		dialog.queue_free()
	)
	add_child(dialog)
	dialog.popup_centered(Vector2i(640, 480))

func _on_export() -> void:
	_validate_links()
	var exp := MudExport.new(_data)
	var count: int = exp.write_all(MudExport.DEFAULT_OUT_DIR)
	_set_status("已导出 %d 个文件到 %s" % [count, MudExport.DEFAULT_OUT_DIR])

## 自动排列地图场景（按 ID 网格排布，保持相对顺序）
func _on_auto_arrange() -> void:
	var scenes: Array = _data.get_table("scene")
	if scenes.is_empty():
		_set_status("无场景可排列")
		return
	var cols := 8
	for i in scenes.size():
		var s: Dictionary = scenes[i]
		s["x"] = (i % cols) + 1
		s["y"] = int(i / cols) + 1
	if _map_canvas:
		_map_canvas.queue_redraw()
	if _tab_builder:
		_tab_builder.refresh_table("scene")
	_set_status("已自动排列 %d 个场景（8 列网格）" % scenes.size())

func _on_clear_data() -> void:
	_data.clear_all()   # 原地清空，数据层引用不变
	if _tab_builder:
		_tab_builder.refresh_all()
	_set_status("已清空全部数据")

func _on_global_config() -> void:
	var dlg := MudGlobalConfig.new()
	add_child(dlg)
	dlg.saved.connect(_on_dialog_saved)
	_auto_free_on_close(dlg)
	dlg.open_config(_data)
