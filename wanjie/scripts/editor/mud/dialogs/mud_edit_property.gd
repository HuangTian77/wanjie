## mud_edit_property.gd
## 属性高级编辑对话框（对应 ME loader/dialogs/editproperty.html/.lua）
##
## 3 子页：
##   基本配置：取值范围(range{min,max}) + 临时属性(master/link_prop) + 计算公式(calc)
##   触发配置：trigger 数组（主从列表：触发类型0临界值/1变化 + 临界值tvalue + 结果块result）
##   属性字典：dict {default, data:[{min,max,desc}]}
## 字段格式与 mud_export.load_property() / mud_import 完全兼容。
class_name MudEditProperty
extends MudEditDialogBase

# ---- 基本配置 ----
var _range_select: OptionButton
var _min_edit: LineEdit
var _max_edit: LineEdit
var _master_select: OptionButton
var _link_label: Label
var _calc_edit: TextEdit

# ---- 触发配置 ----
var _trigger_items: Array = []        # [{type,tvalue,result_type,result}]
var _trigger_list: ItemList
var _trig_cur: int = -1
var _trig_type: OptionButton          # 0临界值触发 / 1变化触发
var _trig_tvalue: LineEdit
var _trig_result: MudTriggerEditor    # RESULT 块（result_type/result）

# ---- 属性字典 ----
var _dict_default: LineEdit
var _dict_rows_box: VBoxContainer
var _dict_rows: Array = []            # [{box,min,max,desc}]


func _build_body() -> void:
	var tc := make_tabs()
	_body.add_child(tc)
	_build_basic(make_tab_page(tc, "基本配置"))
	_build_trigger(make_tab_page(tc, "触发配置"))
	_build_dict(make_tab_page(tc, "属性字典"))


# ===================== 基本配置 =====================

func _build_basic(page: VBoxContainer) -> void:
	# 取值范围
	_range_select = field_select(page, "取值范围：", "_range_en", [["不启用", 0], ["启用", 1]], 0)
	_range_select.item_selected.connect(func(_i): _sync_range())
	var range_box := VBoxContainer.new()
	range_box.add_theme_constant_override("separation", 4)
	page.add_child(range_box)
	_min_edit = LineEdit.new()
	_max_edit = LineEdit.new()
	_add_labeled(range_box, "最小值：", _min_edit)
	_add_labeled(range_box, "最大值：", _max_edit)
	page.add_child(make_comment("不启用表示范围默认为 0 ～ 21 亿。"))

	# 临时属性
	_master_select = field_select(page, "临时属性：", "_master_en", [["不启用", 0], ["启用", 1]], 0)
	_link_label = make_label("临时属性名称：（无）")
	page.add_child(_link_label)
	page.add_child(make_comment("临时属性启用后表示当前属性有一个可变动的值（类似生命值）。临时属性名称可在属性表中修改 link_prop。"))

	# 计算公式
	page.add_child(make_label("属性计算公式：（可依赖其他属性参与计算）"))
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	page.add_child(bar)
	var chk := Button.new()
	chk.text = "语法检查"
	chk.pressed.connect(_on_calc_check)
	bar.add_child(chk)
	_calc_edit = MudCodeTheme.make_code_edit("lua", 140)
	_calc_edit.placeholder_text = "-- 例如：return getProperty('力量') * 2 + 10"
	bar.add_child(MudCodeTheme.make_template_button(_calc_edit, "property"))
	page.add_child(_calc_edit)


func _sync_range() -> void:
	var en: bool = _range_select.get_selected_id() == 1
	_min_edit.editable = en
	_max_edit.editable = en


func _on_calc_check() -> void:
	var s: String = _calc_edit.text
	var ok: bool = _check_lua_balance(s)
	_calc_edit.placeholder_text = "语法检查：" + ("括号/关键字配对正常 ✓" if ok else "存在未配对的括号或关键字 ✗")
	# 简单提示：用标题闪烁不便，直接改 placeholder 即可


func _check_lua_balance(s: String) -> bool:
	var paren: int = 0
	for ch in s:
		if ch == "(":
			paren += 1
		elif ch == ")":
			paren -= 1
		if paren < 0:
			return false
	if paren != 0:
		return false
	# 简单关键字配对：function/end、if/then/end、do/end
	var fns: int = _count_word(s, "function") + _count_word(s, "if") + _count_word(s, "for") + _count_word(s, "while")
	var ends: int = _count_word(s, "end")
	return ends <= fns + 1


func _count_word(s: String, w: String) -> int:
	var c: int = 0
	var i: int = s.find(w)
	while i >= 0:
		c += 1
		i = s.find(w, i + w.length())
	return c


## 数值显示格式化：JSON 解析出的整数 float（如 1.0）显示为 "1"。
func _fmt_num(v: Variant) -> String:
	if v is float:
		var f: float = v as float
		if f == floor(f):
			return str(int(f))
		return str(f)
	return "" if v == null else str(v)


# ===================== 触发配置 =====================

func _build_trigger(page: VBoxContainer) -> void:
	var add := Button.new()
	add.text = "增加触发配置"
	add.pressed.connect(_on_add_trigger_item)
	page.add_child(add)

	var hb := HBoxContainer.new()
	hb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hb.add_theme_constant_override("separation", 6)
	page.add_child(hb)

	_trigger_list = ItemList.new()
	_trigger_list.custom_minimum_size = Vector2(200, 0)
	_trigger_list.item_selected.connect(_on_trigger_selected)
	hb.add_child(_trigger_list)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	hb.add_child(right)
	_trig_type = field_select(right, "触发类型：", "_trig_type", [["临界值触发", 0], ["变化触发", 1]], 0)
	_trig_tvalue = field_line(right, "临界值：", "_trig_tvalue", "0")
	right.add_child(make_comment("临界值是监控的目标值，属性跨越该值时触发；变化触发则每次数值变化都触发。"))
	_trig_result = make_trigger(MudTriggerEditor.Mode.RESULT, "无触发")
	_trig_result.set_type_label("结果类型：")
	_trig_result.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_trig_result)
	page.add_child(make_comment("触发配置可有多个，按顺序执行。选中左侧条目后可编辑，切换会自动保存。"))


func _load_trigger_items(trigger_json: Variant) -> void:
	_trigger_items.clear()
	var s: String = "" if trigger_json == null else str(trigger_json)
	if not s.strip_edges().is_empty():
		var parsed: Variant = JSON.parse_string(s)
		if parsed is Array:
			for it_v in parsed:
				if it_v is Dictionary:
					var it: Dictionary = it_v as Dictionary
					_trigger_items.append({
						"type": int(it.get("type", 0)),
						"tvalue": it.get("tvalue", 0),
						"result_type": int(it.get("result_type", 0)),
						"result": it.get("result", ""),
					})
	_refresh_trigger_list()
	if _trigger_items.size() > 0:
		_trigger_list.select(0)
		_load_trigger_item(0)
	else:
		_trig_cur = -1
		_trig_type.select(0)
		_trig_tvalue.text = "0"
		_trig_result.set_block(0, "", "", 0)


func _refresh_trigger_list() -> void:
	_trigger_list.clear()
	for i in range(_trigger_items.size()):
		var it: Dictionary = _trigger_items[i]
		var label: String = "变化触发" if int(it.get("type", 0)) == 1 else ("临界值=" + str(it.get("tvalue", 0)))
		_trigger_list.add_item("#%d  %s" % [i + 1, label])


func _on_add_trigger_item() -> void:
	_save_current_trigger_item()
	_trigger_items.append({"type": 0, "tvalue": 0, "result_type": 0, "result": ""})
	_refresh_trigger_list()
	var idx: int = _trigger_items.size() - 1
	_trigger_list.select(idx)
	_load_trigger_item(idx)


func _on_trigger_selected(idx: int) -> void:
	_save_current_trigger_item()
	_load_trigger_item(idx)


func _load_trigger_item(idx: int) -> void:
	if idx < 0 or idx >= _trigger_items.size():
		_trig_cur = -1
		return
	_trig_cur = idx
	var it: Dictionary = _trigger_items[idx]
	_select_by_id(_trig_type, int(it.get("type", 0)))
	_trig_tvalue.text = _fmt_num(it.get("tvalue", 0))
	load_trigger(_trig_result, int(it.get("result_type", 0)), it.get("result", ""), 0)


func _save_current_trigger_item() -> void:
	if _trig_cur < 0 or _trig_cur >= _trigger_items.size():
		return
	var b: Dictionary = _trig_result.get_block()
	_trigger_items[_trig_cur] = {
		"type": _trig_type.get_selected_id(),
		"tvalue": _num(_trig_tvalue.text),
		"result_type": int(b["type"]),
		"result": b["script"] if int(b["type"]) == 2 else b["config"],
	}


# ===================== 属性字典 =====================

func _build_dict(page: VBoxContainer) -> void:
	_dict_default = field_line(page, "默认描述：", "_dict_default", "")
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	page.add_child(bar)
	var add := Button.new()
	add.text = "增加字典配置"
	add.pressed.connect(_on_add_dict_row)
	bar.add_child(add)
	var clr := Button.new()
	clr.text = "清空"
	clr.pressed.connect(_on_clear_dict)
	bar.add_child(clr)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 120)
	page.add_child(scroll)
	_dict_rows_box = VBoxContainer.new()
	_dict_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dict_rows_box.add_theme_constant_override("separation", 3)
	scroll.add_child(_dict_rows_box)
	page.add_child(make_comment("属性字典是属性值的枚举描述。支持范围（闭区间）；只填起始值时结束值默认相同。区间不要重叠。"))


func _on_add_dict_row() -> void:
	_add_dict_row({"min": "", "max": "", "desc": ""})


func _on_clear_dict() -> void:
	for r in _dict_rows:
		if is_instance_valid(r.get("box")):
			(r["box"] as Control).queue_free()
	_dict_rows.clear()


func _add_dict_row(item: Dictionary) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 5)
	var l1 := make_label("起:")
	hb.add_child(l1)
	var min_e := LineEdit.new()
	min_e.custom_minimum_size = Vector2(70, 0)
	min_e.text = _fmt_num(item.get("min", ""))
	hb.add_child(min_e)
	var l2 := make_label("止:")
	hb.add_child(l2)
	var max_e := LineEdit.new()
	max_e.custom_minimum_size = Vector2(70, 0)
	max_e.text = _fmt_num(item.get("max", ""))
	hb.add_child(max_e)
	var l3 := make_label("描述:")
	hb.add_child(l3)
	var desc_e := LineEdit.new()
	desc_e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_e.text = str(item.get("desc", ""))
	hb.add_child(desc_e)
	var del := Button.new()
	del.text = "-"
	del.custom_minimum_size = Vector2(26, 0)
	hb.add_child(del)
	_dict_rows_box.add_child(hb)
	var rec: Dictionary = {"box": hb, "min": min_e, "max": max_e, "desc": desc_e}
	del.pressed.connect(func():
		hb.queue_free()
		_dict_rows.erase(rec)
	)
	_dict_rows.append(rec)


func _load_dict(dict_json: Variant) -> void:
	_on_clear_dict()
	var s: String = "" if dict_json == null else str(dict_json)
	if s.strip_edges().is_empty():
		_dict_default.text = ""
		return
	var parsed: Variant = JSON.parse_string(s)
	if parsed is Dictionary:
		var dd: Dictionary = parsed as Dictionary
		_dict_default.text = str(dd.get("default", ""))
		if dd.get("data") is Array:
			for it_v in dd["data"]:
				if it_v is Dictionary:
					_add_dict_row(it_v as Dictionary)
	else:
		_dict_default.text = ""


# ===================== 加载 / 收集 =====================

func _load(row: Dictionary) -> void:
	clear_header()
	add_header("名称：", str(row.get("name", "")))
	add_header("ID：", str(row.get("id", "")))
	add_header("描述：", str(row.get("desc", "")))
	add_header("备注：", str(row.get("note", "")))

	# range
	var rng_str: String = str(row.get("range", ""))
	if rng_str.strip_edges().is_empty():
		_select_by_id(_range_select, 0)
		_min_edit.text = "0"
		_max_edit.text = "2147483648"
	else:
		var rng: Variant = JSON.parse_string(rng_str)
		_select_by_id(_range_select, 1)
		if rng is Dictionary:
			_min_edit.text = _fmt_num((rng as Dictionary).get("min", 0))
			_max_edit.text = _fmt_num((rng as Dictionary).get("max", 0))
	_sync_range()

	# master / link_prop
	var master: int = int(row.get("master", 1))
	_select_by_id(_master_select, 1 if master < 1 else 0)
	var lp: int = int(row.get("link_prop", 0))
	if master < 1 and lp > 0:
		var lprop: Dictionary = _data.get_row_by_id("property", lp)
		_link_label.text = "临时属性名称：%s(#%s)" % [str(lprop.get("name", "")), str(lp)]
	else:
		_link_label.text = "临时属性名称：（无）"

	# calc
	_calc_edit.text = str(row.get("calc", ""))

	# trigger
	_load_trigger_items(row.get("trigger", ""))

	# dict
	_load_dict(row.get("dict", ""))


func _collect() -> Dictionary:
	var out: Dictionary = {}

	# range
	if _range_select.get_selected_id() == 1:
		out["range"] = JSON.stringify({"min": _num(_min_edit.text), "max": _num(_max_edit.text)})
	else:
		out["range"] = ""

	# master
	out["master"] = 0 if _master_select.get_selected_id() == 1 else 1

	# calc
	out["calc"] = _calc_edit.text

	# trigger
	_save_current_trigger_item()
	if _trigger_items.size() > 0:
		out["trigger"] = JSON.stringify(_trigger_items)
	else:
		out["trigger"] = ""

	# dict
	var data: Array = []
	for r in _dict_rows:
		if not is_instance_valid(r.get("box")):
			continue
		var mn: Variant = _num((r["min"] as LineEdit).text)
		var mx: Variant = _num((r["max"] as LineEdit).text)
		var ds: String = (r["desc"] as LineEdit).text
		if str(mn) == "" and ds.is_empty():
			continue
		data.append({"min": mn, "max": mx, "desc": ds})
	if _dict_default.text.is_empty() and data.is_empty():
		out["dict"] = ""
	else:
		out["dict"] = JSON.stringify({"default": _dict_default.text, "data": data})

	return out
