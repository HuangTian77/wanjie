## MUD编辑器 - 通用标签页构建器（配置驱动，复刻 ME loader/inner 标签逻辑）
## 从 MudTabConfigs.TABS 构建 15 个标签页（含子标签），每个子标签 =
## MudTableWidget(数据表) + 操作按钮行 + 编辑表单。接通增/删/改/复制/刷新，
## 高级编辑/CSV导入导出 通过信号上抛给主编辑器（后续阶段接通）。
class_name MudTabBuilder
extends RefCounted

signal status_message(msg: String)
## 高级编辑请求（打开对应编辑对话框，阶段4/5接通）
signal advanced_edit_requested(table: String, id: Variant)
## CSV 导入/导出请求（阶段6接通）
signal csv_export_requested(table: String, noun: String)
signal csv_import_requested(table: String, noun: String)

# ===================== 暗色主题配色（与 mud_editor 一致） =====================
const C_PANEL := Color(0.165, 0.165, 0.195, 1)
const C_PANEL2 := Color(0.20, 0.20, 0.24, 1)
const C_BORDER := Color(0.30, 0.30, 0.36, 1)
const C_TEXT := Color(0.86, 0.86, 0.90, 1)
const C_LABEL := Color(0.58, 0.58, 0.66, 1)
const C_SELECTED := Color(0.28, 0.47, 0.78, 1)

var data: MudData = null
var _tab_container: TabContainer = null
## table -> {"widget": MudTableWidget, "form": VBoxContainer, "form_cfg": Array}
var _rt: Dictionary = {}
## table -> {field: Control}（可编辑控件）
var _editors: Dictionary = {}
## table -> {field: Label}（只读显示）
var _ro_labels: Dictionary = {}
## table -> 选中行 id
var _selected: Dictionary = {}

func _init(p_data: MudData) -> void:
	data = p_data

## 更换数据层引用（load_data 可能重建 MudData 对象）
func set_data(p_data: MudData) -> void:
	data = p_data
	for t in _rt:
		var w: Variant = (_rt[t] as Dictionary).get("widget")
		if w is MudTableWidget:
			(w as MudTableWidget).data = p_data

func get_tab_container() -> TabContainer:
	return _tab_container

func get_selected_id(table: String) -> Variant:
	return _selected.get(table, null)

# ===================== 构建 =====================

func build(parent: Node) -> TabContainer:
	_tab_container = TabContainer.new()
	_tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab_container.add_theme_font_size_override("font_size", 12)
	_style_tab_container(_tab_container)
	parent.add_child(_tab_container)
	for tab_cfg_v in MudTabConfigs.TABS:
		if tab_cfg_v is Dictionary:
			_build_tab(tab_cfg_v as Dictionary)
	return _tab_container

func _build_tab(tab_cfg: Dictionary) -> void:
	var tab_name: String = str(tab_cfg.get("name", ""))
	var subtabs: Array = tab_cfg.get("subtabs", [])
	var page := VBoxContainer.new()
	page.name = tab_name
	page.add_theme_constant_override("separation", 0)
	_tab_container.add_child(page)
	if subtabs.size() <= 1:
		if subtabs.size() == 1 and subtabs[0] is Dictionary:
			_build_subtab(subtabs[0] as Dictionary, page)
		return
	# 多子标签：嵌套 TabContainer
	var sub_tc := TabContainer.new()
	sub_tc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub_tc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sub_tc.add_theme_font_size_override("font_size", 11)
	_style_tab_container(sub_tc)
	page.add_child(sub_tc)
	for st_v in subtabs:
		if not (st_v is Dictionary):
			continue
		var st: Dictionary = st_v as Dictionary
		var st_page := VBoxContainer.new()
		st_page.name = str(st.get("label", ""))
		st_page.add_theme_constant_override("separation", 0)
		sub_tc.add_child(st_page)
		_build_subtab(st, st_page)

func _build_subtab(st_cfg: Dictionary, parent: Control) -> void:
	var table: String = str(st_cfg.get("table", ""))
	var noun: String = str(st_cfg.get("noun", table))
	var form_cfg: Array = st_cfg.get("form", [])

	var split := VSplitContainer.new()
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.dragger_visibility = SplitContainer.DRAGGER_VISIBLE
	parent.add_child(split)

	# 上：搜索框 + 数据表
	var search_box := HBoxContainer.new()
	search_box.custom_minimum_size.y = 28
	parent.add_child(search_box)
	var search_input := LineEdit.new()
	search_input.placeholder_text = "搜索 %s..." % noun
	search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_box.add_child(search_input)
	var w := MudTableWidget.new()
	w.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	w.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(w)
	w.setup(data, table)
	w.row_selected.connect(_on_row_selected.bind(table))
	w.row_activated.connect(_on_row_activated.bind(table))
	search_input.text_changed.connect(func(_t: String): w.set_filter(search_input.text))

	# 下：按钮 + 表单
	var bottom := VBoxContainer.new()
	bottom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom.add_theme_constant_override("separation", 2)
	split.add_child(bottom)

	var btn_box := HBoxContainer.new()
	btn_box.add_theme_constant_override("separation", 4)
	btn_box.custom_minimum_size.y = 30
	bottom.add_child(btn_box)
	_build_buttons(st_cfg, btn_box, table, noun)

	var form_scroll := ScrollContainer.new()
	form_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom.add_child(form_scroll)

	var form := VBoxContainer.new()
	form.add_theme_constant_override("separation", 4)
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form_scroll.add_child(form)
	_build_form(table, form_cfg, form)

	_rt[table] = {"widget": w, "form": form, "form_cfg": form_cfg}

func _build_buttons(st_cfg: Dictionary, box: HBoxContainer, table: String, noun: String) -> void:
	var buttons: Array = st_cfg.get("buttons", [])
	for b_v in buttons:
		if not (b_v is Dictionary):
			continue
		var bd: Dictionary = b_v as Dictionary
		var action: String = str(bd.get("action", ""))
		# 更新/删除 靠右（复刻 ME 的 full-width 分隔）
		if action == "update":
			var spacer := Control.new()
			spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			box.add_child(spacer)
		var label: String = str(bd.get("label", ""))
		if label == "":
			label = _default_btn_label(action, noun)
		var btn := Button.new()
		btn.text = label
		btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(_make_handler(action, table, noun))
		box.add_child(btn)

func _default_btn_label(action: String, noun: String) -> String:
	match action:
		"add": return "新增" + noun
		"copy": return "复制" + noun
		"edit": return "高级编辑"
		"export": return "导出数据"
		"import": return "导入数据"
		"update": return "更新" + noun
		"delete": return "删除" + noun
	return action

func _make_handler(action: String, table: String, noun: String) -> Callable:
	match action:
		"add": return func(): _on_add(table, noun)
		"copy": return func(): _on_copy(table, noun)
		"edit": return func(): _on_edit(table)
		"export": return func(): csv_export_requested.emit(table, noun)
		"import": return func(): csv_import_requested.emit(table, noun)
		"update": return func(): _on_update(table, noun)
		"delete": return func(): _on_delete(table, noun)
	return func(): pass

# ===================== 表单构建 =====================

func _build_form(table: String, form_cfg: Array, form_box: VBoxContainer) -> void:
	_editors[table] = {}
	_ro_labels[table] = {}
	for fc_v in form_cfg:
		if not (fc_v is Dictionary):
			continue
		var fc: Dictionary = fc_v as Dictionary
		var field: String = str(fc.get("field", ""))
		var label: String = str(fc.get("label", field))
		var ftype: String = str(fc.get("type", "text"))

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 6)
		form_box.add_child(hbox)

		var lbl := Label.new()
		lbl.text = label + ":"
		lbl.custom_minimum_size.x = 110
		lbl.add_theme_color_override("font_color", C_LABEL)
		lbl.add_theme_font_size_override("font_size", 11)
		hbox.add_child(lbl)

		match ftype:
			"readonly":
				var val := Label.new()
				val.text = ""
				val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				val.add_theme_color_override("font_color", C_TEXT)
				val.add_theme_font_size_override("font_size", 11)
				hbox.add_child(val)
				_ro_labels[table][field] = val
			"text":
				var le := LineEdit.new()
				le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				le.add_theme_color_override("font_color", C_TEXT)
				hbox.add_child(le)
				_editors[table][field] = le
			"int":
				var sb := SpinBox.new()
				sb.min_value = -999999999
				sb.max_value = 999999999
				sb.step = 1
				sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				hbox.add_child(sb)
				_editors[table][field] = sb
			"decimal":
				var sb2 := SpinBox.new()
				sb2.min_value = -999999999
				sb2.max_value = 999999999
				sb2.step = 0.01
				sb2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				hbox.add_child(sb2)
				_editors[table][field] = sb2
			"textarea":
				var te := TextEdit.new()
				te.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				te.custom_minimum_size.y = 56
				te.add_theme_color_override("font_color", C_TEXT)
				hbox.add_child(te)
				_editors[table][field] = te
			"checkbox":
				var cb := CheckBox.new()
				hbox.add_child(cb)
				_editors[table][field] = cb
			"select":
				var ob := OptionButton.new()
				ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				ob.add_theme_font_size_override("font_size", 11)
				hbox.add_child(ob)
				_editors[table][field] = ob

# ===================== 表单填充 / 读取 =====================

func _populate_form(table: String, id: Variant) -> void:
	var rt: Variant = _rt.get(table)
	if not (rt is Dictionary):
		return
	var row: Dictionary = data.get_row_by_id(table, id)
	if row.is_empty():
		return
	var form_cfg: Array = (rt as Dictionary).get("form_cfg", [])
	for fc_v in form_cfg:
		if not (fc_v is Dictionary):
			continue
		var fc: Dictionary = fc_v as Dictionary
		var field: String = str(fc.get("field", ""))
		var ftype: String = str(fc.get("type", "text"))
		var v: Variant = row.get(field, "")
		if ftype == "readonly":
			var lbl: Variant = (_ro_labels[table] as Dictionary).get(field)
			if lbl is Label:
				(lbl as Label).text = _readonly_text(fc, row)
		else:
			var ctrl: Variant = (_editors[table] as Dictionary).get(field)
			if ctrl is Control:
				_set_editor(fc, ctrl as Control, v)

func _clear_form(table: String) -> void:
	var rt: Variant = _rt.get(table)
	if not (rt is Dictionary):
		return
	var form_cfg: Array = (rt as Dictionary).get("form_cfg", [])
	for fc_v in form_cfg:
		if not (fc_v is Dictionary):
			continue
		var fc: Dictionary = fc_v as Dictionary
		var field: String = str(fc.get("field", ""))
		var ftype: String = str(fc.get("type", "text"))
		if ftype == "readonly":
			var lbl: Variant = (_ro_labels[table] as Dictionary).get(field)
			if lbl is Label:
				(lbl as Label).text = ""
		else:
			var ctrl: Variant = (_editors[table] as Dictionary).get(field)
			if ctrl is Control:
				_set_editor(fc, ctrl as Control, null)

func _readonly_text(fc: Dictionary, row: Dictionary) -> String:
	var field: String = str(fc.get("field", ""))
	var v: Variant = row.get(field, "")
	if fc.has("join"):
		var jv: Variant = _resolve_join(str(fc["join"]), row)
		return "" if jv == null else str(jv)
	if fc.has("map"):
		return str(_map_value(fc["map"], v))
	return "" if v == null else str(v)

func _set_editor(fc: Dictionary, ctrl: Control, v: Variant) -> void:
	if ctrl is LineEdit:
		(ctrl as LineEdit).text = "" if v == null else str(v)
	elif ctrl is SpinBox:
		var sb: SpinBox = ctrl as SpinBox
		if v is int:
			sb.value = float(v as int)
		elif v is float:
			sb.value = v as float
		elif v is String and (v as String).is_valid_float():
			sb.value = (v as String).to_float()
		else:
			sb.value = 0.0
	elif ctrl is TextEdit:
		(ctrl as TextEdit).text = "" if v == null else str(v)
	elif ctrl is CheckBox:
		(ctrl as CheckBox).button_pressed = _to_int(v) != 0
	elif ctrl is OptionButton:
		var ob: OptionButton = ctrl as OptionButton
		_reload_options(fc, ob)
		_select_option(ob, v)

func _read_editor(fc: Dictionary, ctrl: Control) -> Variant:
	var ftype: String = str(fc.get("type", "text"))
	if ctrl is LineEdit:
		return (ctrl as LineEdit).text
	if ctrl is SpinBox:
		var f: float = (ctrl as SpinBox).value
		if ftype == "decimal":
			return f
		return int(round(f))
	if ctrl is TextEdit:
		return (ctrl as TextEdit).text
	if ctrl is CheckBox:
		return 1 if (ctrl as CheckBox).button_pressed else 0
	if ctrl is OptionButton:
		var ob: OptionButton = ctrl as OptionButton
		if ob.selected >= 0:
			return ob.get_item_id(ob.selected)
		return 0
	return null

func _reload_options(fc: Dictionary, ob: OptionButton) -> void:
	ob.clear()
	if fc.has("options") and fc["options"] is Dictionary:
		var m: Dictionary = fc["options"] as Dictionary
		for k in m:
			ob.add_item(str(m[k]), _to_int(k))
	elif fc.has("from_table"):
		var ft: String = str(fc["from_table"])
		var vf: String = str(fc.get("value_field", "id"))
		var lf: String = str(fc.get("label_field", "name"))
		for r_v in data.get_table(ft):
			if r_v is Dictionary:
				var rd: Dictionary = r_v as Dictionary
				ob.add_item(str(rd.get(lf, "")), _to_int(rd.get(vf, 0)))

func _select_option(ob: OptionButton, v: Variant) -> void:
	var target: int = _to_int(v)
	for i in ob.item_count:
		if ob.get_item_id(i) == target:
			ob.select(i)
			return
	# 未找到：补充选项以保留原值
	ob.add_item(str(target), target)
	ob.select(ob.item_count - 1)

# ===================== 行选择 =====================

func _on_row_selected(id: Variant, table: String) -> void:
	_selected[table] = id
	_populate_form(table, id)

func _on_row_activated(id: Variant, table: String) -> void:
	_selected[table] = id
	advanced_edit_requested.emit(table, id)

# ===================== CRUD =====================

func _on_add(table: String, noun: String) -> void:
	var entry: Dictionary = MudSchemaInternal.create_default_entry(table)
	var added: Dictionary = data.add_row(table, entry)
	if added.is_empty():
		status_message.emit("新增失败（可能存在唯一性冲突）")
		return
	_selected[table] = added.get("id")
	_refresh_table(table)
	_populate_form(table, added.get("id"))
	status_message.emit("已新增 %s #%s" % [noun, str(added.get("id"))])

func _on_copy(table: String, noun: String) -> void:
	var id: Variant = _selected.get(table, null)
	if id == null:
		status_message.emit("请先选中要复制的行")
		return
	var src: Dictionary = data.get_row_by_id(table, id)
	if src.is_empty():
		return
	var copy: Dictionary = src.duplicate(true)
	copy.erase("id")
	if copy.has("name"):
		copy["name"] = str(copy["name"]) + "副本"
	var added: Dictionary = data.add_row(table, copy)
	if added.is_empty():
		status_message.emit("复制失败（可能存在唯一性冲突）")
		return
	_selected[table] = added.get("id")
	_refresh_table(table)
	_populate_form(table, added.get("id"))
	status_message.emit("已复制 %s → #%s" % [noun, str(added.get("id"))])

func _on_update(table: String, noun: String) -> void:
	var id: Variant = _selected.get(table, null)
	if id == null:
		status_message.emit("请先选中要更新的行")
		return
	var rt: Variant = _rt.get(table)
	if not (rt is Dictionary):
		return
	var form_cfg: Array = (rt as Dictionary).get("form_cfg", [])
	var changes: Dictionary = {}
	for fc_v in form_cfg:
		if not (fc_v is Dictionary):
			continue
		var fc: Dictionary = fc_v as Dictionary
		var ftype: String = str(fc.get("type", "text"))
		if ftype == "readonly":
			continue
		var field: String = str(fc.get("field", ""))
		var ctrl: Variant = (_editors[table] as Dictionary).get(field)
		if ctrl is Control:
			changes[field] = _read_editor(fc, ctrl as Control)
	var ok: bool = data.update_row(table, id, changes)
	if ok:
		_refresh_table(table)
		_populate_form(table, id)
		status_message.emit("已更新 %s #%s" % [noun, str(id)])
	else:
		status_message.emit("更新失败（可能存在唯一性冲突）")

func _on_delete(table: String, noun: String) -> void:
	var id: Variant = _selected.get(table, null)
	if id == null:
		status_message.emit("请先选中要删除的行")
		return
	var ok: bool = false
	if table == "scene":
		ok = data.del_scene(id)   # 级联删除路径/场景对象
	elif table == "object":
		ok = data.delete_object(id)   # 级联删除场景绑定
	else:
		ok = data.delete_row(table, id)
	if ok:
		_selected.erase(table)
		_clear_form(table)
		_refresh_table(table)
		status_message.emit("已删除 %s #%s" % [noun, str(id)])
	else:
		status_message.emit("删除失败")

func _on_edit(table: String) -> void:
	var id: Variant = _selected.get(table, null)
	if id == null:
		status_message.emit("请先选中一行")
		return
	advanced_edit_requested.emit(table, id)

# ===================== 刷新 =====================

func refresh_all() -> void:
	for t in _rt:
		_refresh_table(t)
		var id: Variant = _selected.get(t, null)
		if id != null:
			_populate_form(t, id)

func refresh_table(table: String) -> void:
	_refresh_table(table)

func _refresh_table(table: String) -> void:
	var rt: Variant = _rt.get(table)
	if not (rt is Dictionary):
		return
	var w: Variant = (rt as Dictionary).get("widget")
	if w is MudTableWidget:
		(w as MudTableWidget).refresh()

# ===================== 工具 =====================

func _resolve_join(join_key: String, row: Dictionary) -> Variant:
	if data == null:
		return null
	match join_key:
		"start_name":
			return data.get_row_by_id("scene", row.get("startpot")).get("name", "")
		"end_name":
			return data.get_row_by_id("scene", row.get("endpot")).get("name", "")
		"object_name":
			return data.get_row_by_id("object", row.get("objid")).get("name", "")
	return null

func _map_value(map_v: Variant, v: Variant) -> Variant:
	if not (map_v is Dictionary):
		return v
	var m: Dictionary = map_v as Dictionary
	var key: Variant = v
	if v is float:
		key = int(v as float)
	elif v is String and (v as String).is_valid_int():
		key = (v as String).to_int()
	if m.has(key):
		return m[key]
	if m.has(str(v)):
		return m[str(v)]
	return v

func _to_int(v: Variant) -> int:
	if v is int:
		return v as int
	if v is float:
		return int(v as float)
	if v is String:
		var s: String = v as String
		if s.is_valid_int():
			return s.to_int()
	return 0

func _style_tab_container(tc: TabContainer) -> void:
	var sel := StyleBoxFlat.new()
	sel.bg_color = C_SELECTED
	sel.corner_radius_top_left = 4
	sel.corner_radius_top_right = 4
	tc.add_theme_stylebox_override("tab_selected", sel)
	var unsel := StyleBoxFlat.new()
	unsel.bg_color = C_PANEL2
	unsel.corner_radius_top_left = 4
	unsel.corner_radius_top_right = 4
	tc.add_theme_stylebox_override("tab_unselected", unsel)
	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color = C_PANEL
	panel_sb.border_color = C_BORDER
	panel_sb.border_width_top = 1
	tc.add_theme_stylebox_override("panel", panel_sb)
	tc.add_theme_color_override("font_selected_color", Color(1, 1, 1, 1))
	tc.add_theme_color_override("font_unselected_color", C_LABEL)
