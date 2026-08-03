## mud_trigger_editor.gd
## 条件 / 触发 / 结果 共享编辑组件（对应 ME res/behavior/trigger_ui.lua）
##
## ME 中一个"触发块"由三部分构成：
##   类型选择(0无/1配置/2脚本) → 配置容器(条件/结果行列表) 或 脚本容器(scintilla)
## 本组件复刻该结构，并区分两种模式：
##   COND   条件模式：行 = [type][subtype][条件 gt/lt/eq][条件值]，块顶部带 全与/全或 选择
##   RESULT 结果模式：行 = [type][subtype][操作 增量/重置][数值]（仅 属性/物品/技能 显示操作与数值）
##
## 行数据格式与 export.lua 的 parseCondition/getResult 输入完全一致：
##   条件行 {type:int, subtype:int, condition:"gt"/"lt"/"eq", value:num}
##   结果行 {type:int, subtype:int, ops:int, value:num}
## type 取值 1~13，对应 datacache.lua 的 ALL 列表（property..logic）。
class_name MudTriggerEditor
extends VBoxContainer

enum Mode { COND, RESULT }

## 类型 → 内部数据表（对应 ME datacache.lua ALL 列表顺序）
const TYPE_TABLES := {
	1: "property", 2: "item", 3: "alternation", 4: "story",
	5: "reward", 6: "campaign", 7: "skill", 8: "random",
	9: "trade", 10: "generator", 11: "payment", 12: "scene", 13: "logic",
}
## 类型 → 中文标签（对应 trigger_ui.lua generateOpitons 的选项文本）
const TYPE_LABELS := {
	1: "属性", 2: "物品", 3: "交互", 4: "剧情", 5: "奖励",
	6: "战役", 7: "技能", 8: "概率", 9: "交易", 10: "生产",
	11: "充值", 12: "传送", 13: "逻辑",
}
## 结果行中显示"操作/数值"的类型：属性(1) 物品(2) 技能(7)（对应 v<3 or v==7）
const RESULT_VALUE_TYPES := [1, 2, 7]

signal changed()

# ---- 配置 ----
var _mode: int = Mode.COND
var _data: MudData = null
var _none_label: String = "无条件"

# ---- 子节点 ----
var _type_select: OptionButton        # 0无 / 1配置 / 2脚本
var _type_label: Label
var _ops_select: OptionButton         # 全与/全或（仅 COND）
var _add_btn: Button
var _clear_btn: Button
var _rows_box: VBoxContainer          # 行列表
var _config_box: VBoxContainer        # 配置容器
var _script_edit: TextEdit            # 脚本容器
var _script_box: VBoxContainer

# ---- 暗色主题 ----
const C_PANEL := Color(0.165, 0.165, 0.195, 1)
const C_PANEL2 := Color(0.20, 0.20, 0.24, 1)
const C_BORDER := Color(0.30, 0.30, 0.36, 1)
const C_TEXT := Color(0.86, 0.86, 0.90, 1)
const C_LABEL := Color(0.58, 0.58, 0.66, 1)


func _init(p_mode: int = Mode.COND, none_label: String = "无条件") -> void:
	_mode = p_mode
	_none_label = none_label
	_build_ui()


## 设置类型标签文本（如"路径通过类型触发："）
func set_type_label(text: String) -> void:
	if _type_label != null:
		_type_label.text = text


## 设置数据源（用于填充 subtype 下拉选项）
func set_data_source(data: MudData) -> void:
	_data = data
	# 刷新所有行的 subtype 选项
	for row in _rows_box.get_children():
		if row.has_method("refresh_subtype"):
			row.refresh_subtype()


## 构建整个触发块
## type: 0无 / 1配置 / 2脚本
## config: JSON 字符串 或 Array（行数据列表）
## script_text: 脚本内容
## ops: 条件策略 0全与 / 1全或（仅 COND 模式有效）
func set_block(type: int, config: Variant, script_text: String = "", ops: int = 0) -> void:
	_type_select.select(clampi(type, 0, 2))
	_ops_select.select(clampi(ops, 0, 1))
	_script_edit.text = script_text
	_rebuild_rows(config)
	_sync_visibility()


## 读取整个触发块
## 返回 {type:int, config:String(JSON), script:String, ops:int}
func get_block() -> Dictionary:
	var type: int = _type_select.get_selected_id()
	var rows: Array = _collect_rows()
	var config_str: String = ""
	if rows.size() > 0:
		config_str = JSON.stringify(rows)
	return {
		"type": type,
		"config": config_str,
		"script": _script_edit.text,
		"ops": _ops_select.get_selected_id(),
	}


## 仅设置配置行列表（不影响 type/script）
func set_config(config: Variant, ops: int = 0) -> void:
	_ops_select.select(clampi(ops, 0, 1))
	_rebuild_rows(config)


## 仅读取配置行列表 → {config:String(JSON), ops:int}
func get_config() -> Dictionary:
	var rows: Array = _collect_rows()
	var config_str: String = ""
	if rows.size() > 0:
		config_str = JSON.stringify(rows)
	return {"config": config_str, "ops": _ops_select.get_selected_id()}


# ===================== UI 构建 =====================

func _build_ui() -> void:
	# --- 顶部：类型选择 ---
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	_type_label = Label.new()
	_type_label.text = "条件类型：" if _mode == Mode.COND else "触发类型："
	_type_label.add_theme_color_override("font_color", C_LABEL)
	top.add_child(_type_label)

	_type_select = OptionButton.new()
	_type_select.add_item(_none_label, 0)
	_type_select.add_item("配置", 1)
	_type_select.add_item("脚本", 2)
	_type_select.select(0)
	_type_select.item_selected.connect(_on_type_selected)
	top.add_child(_type_select)
	add_child(top)

	# --- 配置容器 ---
	_config_box = VBoxContainer.new()
	_config_box.add_theme_constant_override("separation", 4)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	_add_btn = Button.new()
	_add_btn.text = "增加条件" if _mode == Mode.COND else "增加触发"
	_add_btn.pressed.connect(_on_add_row)
	bar.add_child(_add_btn)

	if _mode == Mode.COND:
		_ops_select = OptionButton.new()
		_ops_select.add_item("全部满足（与）", 0)
		_ops_select.add_item("满足一个（或）", 1)
		_ops_select.select(0)
		_ops_select.item_selected.connect(func(_i): changed.emit())
		bar.add_child(_ops_select)
	else:
		_ops_select = OptionButton.new()
		_ops_select.add_item("全部满足（与）", 0)
		_ops_select.add_item("满足一个（或）", 1)
		_ops_select.visible = false

	_clear_btn = Button.new()
	_clear_btn.text = "清空"
	_clear_btn.pressed.connect(_on_clear_rows)
	bar.add_child(_clear_btn)
	_config_box.add_child(bar)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 90)
	_rows_box = VBoxContainer.new()
	_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_box.add_theme_constant_override("separation", 3)
	scroll.add_child(_rows_box)
	_config_box.add_child(scroll)
	add_child(_config_box)

	# --- 脚本容器 ---
	_script_box = VBoxContainer.new()
	_script_edit = TextEdit.new()
	_script_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_script_edit.custom_minimum_size = Vector2(0, 110)
	_script_edit.placeholder_text = "-- 在此输入 Lua 脚本"
	_script_edit.text_changed.connect(func(): changed.emit())
	_apply_dark_textedit(_script_edit)
	_script_box.add_child(_script_edit)
	add_child(_script_box)

	_sync_visibility()


func _sync_visibility() -> void:
	var sel: int = _type_select.get_selected_id()
	_config_box.visible = (sel == 1)
	_script_box.visible = (sel == 2)


func _on_type_selected(_idx: int) -> void:
	_sync_visibility()
	changed.emit()


# ===================== 行管理 =====================

func _on_add_row() -> void:
	var row: Control = _make_row({})
	_rows_box.add_child(row)
	changed.emit()


func _on_clear_rows() -> void:
	for c in _rows_box.get_children():
		c.queue_free()
	changed.emit()


func _rebuild_rows(config: Variant) -> void:
	for c in _rows_box.get_children():
		c.queue_free()
	var arr: Array = _to_array(config)
	for item in arr:
		if item is Dictionary:
			_rows_box.add_child(_make_row(item))


func _collect_rows() -> Array:
	var rt: Array = []
	for row in _rows_box.get_children():
		if row.has_method("get_data"):
			rt.append(row.get_data())
	return rt


func _to_array(config: Variant) -> Array:
	if config is Array:
		return config
	if config is String:
		var s: String = config.strip_edges()
		if s.is_empty():
			return []
		var parsed: Variant = JSON.parse_string(s)
		if parsed is Array:
			return parsed
	return []


func _make_row(item: Dictionary) -> Control:
	var row: Control
	if _mode == Mode.COND:
		row = CondRow.new(self)
	else:
		row = ResultRow.new(self)
	row.set_data(item)
	row.removed.connect(_on_row_removed.bind(row))
	row.row_changed.connect(func(): changed.emit())
	return row


func _on_row_removed(row: Control) -> void:
	row.queue_free()
	changed.emit()


## 供行调用：按类型填充 subtype 下拉选项（name(id) 格式，对应 datacache 的 SQL 拼接）
func fill_subtype_options(subtype: OptionButton, type_id: int, keep_id: int = -1) -> void:
	subtype.clear()
	var table: String = TYPE_TABLES.get(type_id, "")
	if table.is_empty() or _data == null:
		# 无数据源：若需保留引用 id 则加占位项，否则显示(无)
		if keep_id > 0:
			subtype.add_item("(#%d)" % keep_id, keep_id)
		else:
			subtype.add_item("(无)", 0)
		subtype.select(0)
		return
	var rows: Array = _data.get_table(table)
	# 按 id 排序
	var sorted: Array = rows.duplicate()
	sorted.sort_custom(func(a, b): return int(a.get("id", 0)) < int(b.get("id", 0)))
	var sel_idx: int = -1
	var idx: int = 0
	for r in sorted:
		var rid: int = int(r.get("id", 0))
		var rname: String = str(r.get("name", ""))
		subtype.add_item("%s(%d)" % [rname, rid], rid)
		if rid == keep_id:
			sel_idx = idx
		idx += 1
	# 若 keep_id 未在表中找到（如引用对象已删除），添加占位项以保留引用，避免静默改为 0
	if keep_id > 0 and sel_idx < 0:
		subtype.add_item("(#%d)" % keep_id, keep_id)
		sel_idx = subtype.item_count - 1
	if subtype.item_count > 0:
		subtype.select(sel_idx if sel_idx >= 0 else 0)


# ===================== 样式辅助 =====================

func _apply_dark_textedit(te: TextEdit) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.10, 0.125, 1)
	sb.border_width_bottom = 1
	sb.border_width_top = 1
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_color = C_BORDER
	te.add_theme_stylebox_override("normal", sb)
	te.add_theme_color_override("font_color", C_TEXT)
	te.add_theme_color_override("caret_color", C_TEXT)


# ===================== 条件行 =====================
## 条件行：[删除] [type] ：[subtype] 条件：[gt/lt/eq] 条件值：[value]
class CondRow:
	extends HBoxContainer

	signal removed()
	signal row_changed()

	var _editor: MudTriggerEditor
	var _type_select: OptionButton
	var _subtype_select: OptionButton
	var _cond_select: OptionButton
	var _value_edit: LineEdit

	func _init(editor: MudTriggerEditor) -> void:
		_editor = editor
		add_theme_constant_override("separation", 5)

		var del := Button.new()
		del.text = "-"
		del.custom_minimum_size = Vector2(26, 0)
		del.pressed.connect(func(): removed.emit())
		add_child(del)

		_type_select = OptionButton.new()
		_type_select.custom_minimum_size = Vector2(70, 0)
		for tid in range(1, 14):
			_type_select.add_item(MudTriggerEditor.TYPE_LABELS.get(tid, "?"), tid)
		_type_select.select(0)
		_type_select.item_selected.connect(_on_type_selected)
		add_child(_type_select)

		var colon := Label.new()
		colon.text = "："
		colon.add_theme_color_override("font_color", MudTriggerEditor.C_LABEL)
		add_child(colon)

		_subtype_select = OptionButton.new()
		_subtype_select.custom_minimum_size = Vector2(150, 0)
		_subtype_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_subtype_select.item_selected.connect(func(_i): row_changed.emit())
		add_child(_subtype_select)

		var cond_lbl := Label.new()
		cond_lbl.text = "条件："
		cond_lbl.add_theme_color_override("font_color", MudTriggerEditor.C_LABEL)
		add_child(cond_lbl)

		_cond_select = OptionButton.new()
		_cond_select.add_item("≥", 0)   # gt
		_cond_select.add_item("≤", 1)   # lt
		_cond_select.add_item("=", 2)   # eq
		_cond_select.select(0)
		_cond_select.item_selected.connect(func(_i): row_changed.emit())
		add_child(_cond_select)

		var val_lbl := Label.new()
		val_lbl.text = "条件值："
		val_lbl.add_theme_color_override("font_color", MudTriggerEditor.C_LABEL)
		add_child(val_lbl)

		_value_edit = LineEdit.new()
		_value_edit.custom_minimum_size = Vector2(60, 0)
		_value_edit.text = "1"
		_value_edit.text_changed.connect(func(_t): row_changed.emit())
		add_child(_value_edit)

	func _on_type_selected(_idx: int) -> void:
		refresh_subtype()
		row_changed.emit()

	func refresh_subtype() -> void:
		var keep: int = _subtype_select.get_selected_id()
		_editor.fill_subtype_options(_subtype_select, _type_select.get_selected_id(), keep)

	func set_data(item: Dictionary) -> void:
		var tid: int = int(item.get("type", 1))
		_select_by_id(_type_select, tid)
		_editor.fill_subtype_options(_subtype_select, tid, int(item.get("subtype", -1)))
		var cond: String = str(item.get("condition", "gt"))
		_cond_select.select(0 if cond == "gt" else (1 if cond == "lt" else 2))
		_value_edit.text = str(item.get("value", 1))

	func get_data() -> Dictionary:
		return {
			"type": _type_select.get_selected_id(),
			"subtype": _subtype_select.get_selected_id(),
			"condition": ["gt", "lt", "eq"][_cond_select.selected],
			"value": _num(_value_edit.text),
		}

	func _select_by_id(ob: OptionButton, id: int) -> void:
		for i in range(ob.item_count):
			if ob.get_item_id(i) == id:
				ob.select(i)
				return
		if ob.item_count > 0:
			ob.select(0)

	func _num(s: String) -> Variant:
		var f: float = s.strip_edges().to_float()
		if f == floor(f):
			return int(f)
		return f


# ===================== 结果行 =====================
## 结果行：[删除] [type] ：[subtype] 操作：[增量/重置] 数值：[value]
## 仅 属性(1)/物品(2)/技能(7) 显示 操作 与 数值（对应 trigger_ui v<3 or v==7）
class ResultRow:
	extends HBoxContainer

	signal removed()
	signal row_changed()

	var _editor: MudTriggerEditor
	var _type_select: OptionButton
	var _subtype_select: OptionButton
	var _ops_label: Label
	var _ops_select: OptionButton
	var _value_label: Label
	var _value_edit: LineEdit

	func _init(editor: MudTriggerEditor) -> void:
		_editor = editor
		add_theme_constant_override("separation", 5)

		var del := Button.new()
		del.text = "-"
		del.custom_minimum_size = Vector2(26, 0)
		del.pressed.connect(func(): removed.emit())
		add_child(del)

		_type_select = OptionButton.new()
		_type_select.custom_minimum_size = Vector2(70, 0)
		for tid in range(1, 14):
			_type_select.add_item(MudTriggerEditor.TYPE_LABELS.get(tid, "?"), tid)
		_type_select.select(0)
		_type_select.item_selected.connect(_on_type_selected)
		add_child(_type_select)

		var colon := Label.new()
		colon.text = "："
		colon.add_theme_color_override("font_color", MudTriggerEditor.C_LABEL)
		add_child(colon)

		_subtype_select = OptionButton.new()
		_subtype_select.custom_minimum_size = Vector2(170, 0)
		_subtype_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_subtype_select.item_selected.connect(func(_i): row_changed.emit())
		add_child(_subtype_select)

		_ops_label = Label.new()
		_ops_label.text = "操作："
		_ops_label.add_theme_color_override("font_color", MudTriggerEditor.C_LABEL)
		add_child(_ops_label)

		_ops_select = OptionButton.new()
		_ops_select.add_item("增量", 1)
		_ops_select.add_item("重置", 3)
		_ops_select.select(0)
		_ops_select.item_selected.connect(func(_i): row_changed.emit())
		add_child(_ops_select)

		_value_label = Label.new()
		_value_label.text = "数值："
		_value_label.add_theme_color_override("font_color", MudTriggerEditor.C_LABEL)
		add_child(_value_label)

		_value_edit = LineEdit.new()
		_value_edit.custom_minimum_size = Vector2(60, 0)
		_value_edit.text = "1"
		_value_edit.text_changed.connect(func(_t): row_changed.emit())
		add_child(_value_edit)

		_sync_value_visibility()

	func _on_type_selected(_idx: int) -> void:
		_sync_value_visibility()
		refresh_subtype()
		row_changed.emit()

	func _sync_value_visibility() -> void:
		var show: bool = MudTriggerEditor.RESULT_VALUE_TYPES.has(_type_select.get_selected_id())
		_ops_label.visible = show
		_ops_select.visible = show
		_value_label.visible = show
		_value_edit.visible = show

	func refresh_subtype() -> void:
		var keep: int = _subtype_select.get_selected_id()
		_editor.fill_subtype_options(_subtype_select, _type_select.get_selected_id(), keep)

	func set_data(item: Dictionary) -> void:
		var tid: int = int(item.get("type", 1))
		_select_by_id(_type_select, tid)
		_editor.fill_subtype_options(_subtype_select, tid, int(item.get("subtype", -1)))
		_select_by_id(_ops_select, int(item.get("ops", 1)))
		_value_edit.text = str(item.get("value", 1))
		_sync_value_visibility()

	func get_data() -> Dictionary:
		return {
			"type": _type_select.get_selected_id(),
			"subtype": _subtype_select.get_selected_id(),
			"ops": _ops_select.get_selected_id(),
			"value": _num(_value_edit.text),
		}

	func _select_by_id(ob: OptionButton, id: int) -> void:
		for i in range(ob.item_count):
			if ob.get_item_id(i) == id:
				ob.select(i)
				return
		if ob.item_count > 0:
			ob.select(0)

	func _num(s: String) -> Variant:
		var f: float = s.strip_edges().to_float()
		if f == floor(f):
			return int(f)
		return f
