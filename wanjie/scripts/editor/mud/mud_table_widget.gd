## MUD编辑器 - 数据表控件（复刻 res/behavior/querytable.lua 的显示映射）
## Tree 表格 + 中文标签映射(CASE) + FCOLOR 字色 / BCOLOR 背景 + 关联列(JOIN)。
## 显示规则权威来源：querytable.lua 的 table_sql（已从 LuaJIT 字节码提取字符串常量重建）。
## 颜色已按暗色主题适配（保留语义：绿=条件 蓝=脚本 红=临时属性 灰底=隐藏）。
class_name MudTableWidget
extends VBoxContainer

signal row_selected(id: Variant)
signal row_activated(id: Variant)   # 双击（高级编辑入口）

# ===================== 暗色主题适配色（对应 querytable FCOLOR/BCOLOR 语义） =====================
const COL_TEXT := Color(0.86, 0.86, 0.90, 1)      # 默认字色（0x000000 黑 → 暗色主题浅字）
const COL_COND := Color(0.42, 0.85, 0.48, 1)      # 条件（0x00AA00 绿）
const COL_SCRIPT := Color(0.50, 0.65, 1.0, 1)     # 脚本（0x0000AA 蓝）
const COL_TEMP_PROP := Color(1.0, 0.52, 0.52, 1)  # 临时属性（0xAA0000 红）
const COL_UNSET := Color(0.55, 0.62, 0.82, 1)     # 未配置（0x0000ff 蓝）
const BCOL_HIDDEN := Color(0.235, 0.235, 0.27, 1) # 隐藏行背景（0xd8d8d8 灰 → 暗色）
const C_PANEL := Color(0.165, 0.165, 0.195, 1)
const C_SELECTED := Color(0.28, 0.47, 0.78, 1)
const C_BORDER := Color(0.30, 0.30, 0.36, 1)

# ===================== 显示配置（复刻 querytable.lua table_sql） =====================
## 列定义: {"field":源字段, "label":中文列名, "map":{值:显示文本}, "join":关联解析键}
## 颜色规则: "fcolor"/"bcolor" 为规则数组，首条命中生效。
##   规则A(按值): {"field":字段, "values":{值:Color}, "default":Color?}
##   规则B(非空): {"nonempty_any":[字段...], "color":Color, "else":Color}
const DISPLAY: Dictionary = {
	"scene": {
		"columns": [
			{"field": "id", "label": "ID"},
			{"field": "name", "label": "名称"},
			{"join": "map_name", "label": "地图"},
			{"join": "scene_objcnt", "label": "对象数"},
			{"field": "et_type", "label": "进入触发", "map": {0: "无", 1: "条件", 2: "脚本"}},
			{"field": "lt_type", "label": "离开触发", "map": {0: "无", 1: "条件", 2: "脚本"}},
		],
	},
	"linkpath": {
		"columns": [
			{"field": "id", "label": "ID"},
			{"join": "start_name", "label": "起点"},
			{"field": "direct", "label": "方向", "map": {
				"east": "东", "west": "西", "north": "北", "south": "南",
				"southeast": "东南", "southwest": "西南", "northeast": "东北", "northwest": "西北",
			}},
			{"join": "end_name", "label": "终点"},
			{"field": "status", "label": "状态", "map": {0: "正常", 1: "隐藏"}},
			{"field": "passcond_type", "label": "通过条件", "map": {0: "无", 1: "条件", 2: "脚本"}},
		],
		"fcolor": [{"field": "passcond_type", "values": {1: COL_COND, 2: COL_SCRIPT}}],
	},
	"object": {
		"columns": [
			{"field": "id", "label": "ID"},
			{"field": "name", "label": "名称"},
			{"field": "desc", "label": "描述"},
			{"field": "note", "label": "备注"},
		],
	},
	"scene_object": {
		"columns": [
			{"field": "id", "label": "ID"},
			{"field": "sceneid", "label": "场景ID"},
			{"join": "object_name", "label": "对象"},
			{"field": "ctrl", "label": "显示控制"},
		],
	},
	"module_talk": {
		"columns": [
			{"field": "id", "label": "ID"},
			{"join": "object_name", "label": "对象"},
			{"field": "name", "label": "互动名称"},
			{"field": "trigger_type", "label": "触发", "map": {0: "无", 1: "条件", 2: "脚本"}},
			{"field": "visible_cond_trigger_type", "label": "显示", "map": {0: "无", 1: "条件", 2: "脚本"}},
		],
	},
	"property": {
		"columns": [
			{"field": "id", "label": "ID"},
			{"join": "property_type_name", "label": "分类"},
			{"field": "name", "label": "属性名称"},
			{"field": "master", "label": "主从", "map": {0: "临时属性", 1: "主属性"}},
			{"join": "property_link_name", "label": "关联属性"},
		],
		"fcolor": [{"field": "master", "values": {0: COL_TEMP_PROP}}],
	},
	"property_type": {
		"columns": [
			{"field": "id", "label": "ID"},
			{"field": "name", "label": "分类名"},
			{"field": "priority", "label": "权重"},
			{"field": "visible", "label": "可见", "map": {0: "否", 1: "是"}},
		],
		"bcolor": [{"field": "visible", "values": {0: BCOL_HIDDEN}}],
	},
	"skill": {
		"columns": [
			{"field": "id", "label": "ID"},
			{"join": "skill_type_name", "label": "分类"},
			{"field": "name", "label": "名称"},
			{"field": "data_type", "label": "结算", "map": {0: "脚本", 1: "配置"}},
		],
		"fcolor": [{"nonempty_any": ["data"], "color": COL_TEXT, "else": COL_UNSET}],
	},
	"skill_type": {
		"columns": [
			{"field": "id", "label": "ID"},
			{"field": "name", "label": "分类名"},
			{"field": "priority", "label": "权重"},
			{"field": "visible", "label": "可见", "map": {0: "否", 1: "是"}},
		],
		"bcolor": [{"field": "visible", "values": {0: BCOL_HIDDEN}}],
	},
	"item": {
		"columns": [
			{"field": "id", "label": "ID"},
			{"join": "item_type_name", "label": "分类"},
			{"field": "name", "label": "名称"},
			{"field": "feature_equip", "label": "可装备", "map": {0: "否", 1: "是"}},
			{"field": "feature_destory", "label": "可销毁", "map": {0: "否", 1: "是"}},
			{"field": "feature_consume", "label": "可消耗", "map": {0: "否", 1: "是"}},
		],
	},
	"item_type": {
		"columns": [
			{"field": "typeid", "label": "ID"},
			{"field": "name", "label": "分类名"},
			{"field": "priority", "label": "权重"},
			{"field": "feature_equip", "label": "可装备", "map": {0: "否", 1: "是"}},
			{"field": "visible", "label": "可见", "map": {0: "否", 1: "是"}},
		],
		"bcolor": [{"field": "visible", "values": {0: BCOL_HIDDEN}}],
	},
	"alternation": {
		"columns": [
			{"field": "id", "label": "ID"},
			{"field": "name", "label": "名称"},
			{"field": "desc", "label": "描述"},
		],
	},
	"reward": {
		"columns": [
			{"field": "id", "label": "ID"},
			{"field": "type", "label": "类型", "map": {1: "随机概率", 2: "权重分配"}},
		],
	},
	"story": {
		"columns": [
			{"field": "id", "label": "ID"},
			{"field": "name", "label": "名称"},
			{"field": "dtype", "label": "类型", "map": {0: "配置", 1: "脚本"}},
		],
	},
	"enemy": {
		"columns": [
			{"field": "id", "label": "ID"},
			{"field": "name", "label": "名称"},
			{"field": "type", "label": "类型", "map": {0: "配置", 1: "脚本"}},
		],
		"fcolor": [{"nonempty_any": ["property", "script"], "color": COL_TEXT, "else": COL_UNSET}],
	},
	"enemy_template": {
		"columns": [
			{"field": "id", "label": "ID"},
			{"field": "name", "label": "名称"},
		],
		"fcolor": [{"nonempty_any": ["property"], "color": COL_TEXT, "else": COL_UNSET}],
	},
	"campaign": {
		"columns": [
			{"field": "id", "label": "ID"},
			{"field": "name", "label": "名称"},
			{"field": "desc", "label": "描述"},
		],
	},
	"slot": {
		"columns": [
			{"field": "id", "label": "ID"},
			{"field": "name", "label": "名称"},
			{"field": "cnt", "label": "插孔数量"},
		],
	},
	"slot_template": {
		"columns": [
			{"field": "id", "label": "ID"},
			{"field": "name", "label": "名称"},
		],
	},
	"random": {
		"columns": [
			{"field": "id", "label": "ID"},
			{"field": "name", "label": "名称"},
			{"field": "cond_type", "label": "条件", "map": {0: "无", 1: "配置", 2: "脚本"}},
			{"field": "success_type", "label": "满足触发", "map": {1: "概率随机", 2: "权重分配", 3: "脚本逻辑"}},
			{"field": "fail_type", "label": "不满足", "map": {1: "概率随机", 2: "权重分配", 3: "脚本逻辑"}},
		],
	},
	"trade": {
		"columns": [
			{"field": "id", "label": "ID"},
			{"field": "name", "label": "名称"},
			{"field": "type", "label": "类型", "map": {0: "普通", 1: "合成", 2: "分解"}},
		],
	},
	"generator": {
		"columns": [
			{"field": "id", "label": "ID"},
			{"field": "name", "label": "名称"},
			{"field": "type", "label": "类型", "map": {1: "采集", 2: "制造"}},
			{"field": "data_type", "label": "数据类型", "map": {1: "配置", 2: "脚本"}},
		],
	},
	"payment": {
		"columns": [
			{"field": "id", "label": "ID"},
			{"field": "name", "label": "名称"},
			{"field": "price", "label": "价格"},
		],
	},
	"logic": {
		"columns": [
			{"field": "id", "label": "ID"},
			{"field": "condition", "label": "条件"},
			{"field": "success", "label": "满足触发"},
		],
	},
	"custom_data": {
		"columns": [
			{"field": "kname", "label": "键名"},
			{"field": "type", "label": "类型", "map": {0: "文本", 1: "JSON"}},
			{"field": "name", "label": "名称"},
		],
	},
	"map": {
		"columns": [
			{"field": "id", "label": "ID"},
			{"field": "name", "label": "地图名称"},
			{"field": "width", "label": "宽"},
			{"field": "height", "label": "高"},
		],
	},
	"config": {
		"columns": [
			{"field": "name", "label": "配置键"},
			{"field": "value", "label": "配置值"},
		],
	},
}

# ===================== 实例状态 =====================
var data: MudData = null
var table_name: String = ""
var _tree: Tree = null
var _selected_id: Variant = null
## 搜索过滤文本（空显示全部）
var _filter_text: String = ""

func _ready() -> void:
	pass

## 初始化：绑定数据层与表名，构建 Tree
func setup(p_data: MudData, p_table: String) -> void:
	data = p_data
	table_name = p_table
	_build_tree()
	refresh()

func _build_tree() -> void:
	if _tree != null:
		return
	_tree = Tree.new()
	_tree.hide_root = true
	_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var cols: Array = _get_columns()
	_tree.columns = maxi(cols.size(), 1)
	_tree.set_column_expand(0, false)
	_tree.set_column_custom_minimum_width(0, 48)
	_style_tree()
	_tree.item_selected.connect(_on_item_selected)
	_tree.item_activated.connect(_on_item_activated)
	add_child(_tree)

func _style_tree() -> void:
	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color = C_PANEL
	_tree.add_theme_stylebox_override("panel", panel_sb)
	_tree.add_theme_color_override("font_color", COL_TEXT)
	_tree.add_theme_color_override("font_selected_color", Color(1, 1, 1, 1))
	var sel_sb := StyleBoxFlat.new()
	sel_sb.bg_color = C_SELECTED
	_tree.add_theme_stylebox_override("selected", sel_sb)
	_tree.add_theme_color_override("guide_color", Color(C_BORDER.r, C_BORDER.g, C_BORDER.b, 0.35))
	_tree.add_theme_font_size_override("font_size", 12)

func get_columns_config() -> Array:
	return _get_columns()

func _get_columns() -> Array:
	var cfg: Variant = DISPLAY.get(table_name)
	if cfg is Dictionary and (cfg as Dictionary).has("columns"):
		return (cfg as Dictionary)["columns"]
	# 回退：从 schema 自动推导
	return _auto_columns()

func _auto_columns() -> Array:
	var cols: Array = []
	var fields: Array = MudSchemaInternal.get_field_names(table_name)
	if fields.has("id"):
		cols.append({"field": "id", "label": "ID"})
	for fn in fields:
		if cols.size() >= 4:
			break
		var fn_s: String = fn as String
		if fn_s == "id":
			continue
		var fd: Dictionary = MudSchemaInternal.get_field(table_name, fn_s)
		var ftype: String = str(fd.get("type", ""))
		if ftype == "json" or ftype == "script" or ftype == "text":
			continue
		cols.append({"field": fn_s, "label": str(fd.get("desc", fn_s))})
	if cols.is_empty():
		cols.append({"field": "id", "label": "ID"})
	return cols

# ===================== 刷新渲染 =====================

func refresh() -> void:
	if _tree == null:
		_build_tree()
	if data == null:
		return
	var cols: Array = _get_columns()
	_tree.clear()
	var root := _tree.create_item()
	for ci in cols.size():
		_tree.set_column_title(ci, str((cols[ci] as Dictionary).get("label", "")))
		_tree.set_column_title_alignment(ci, HORIZONTAL_ALIGNMENT_LEFT)
	_tree.set_column_titles_visible(true)

	var fcolor_rules: Array = _get_color_rules("fcolor")
	var bcolor_rules: Array = _get_color_rules("bcolor")

	var rows: Array = data.get_table(table_name)
	for row_v in rows:
		if not (row_v is Dictionary):
			continue
		var row: Dictionary = row_v as Dictionary
		if not _filter_text.is_empty() and not _row_matches(row):
			continue
		var item := _tree.create_item(root)
		item.set_metadata(0, row.get("id", row.get("name", "")))
		for ci2 in cols.size():
			var col: Dictionary = cols[ci2] as Dictionary
			var text: String = _cell_text(col, row)
			item.set_text(ci2, text)
		_apply_colors(item, row, fcolor_rules, bcolor_rules)
		if _selected_id != null and item.get_metadata(0) == _selected_id:
			item.select(0)

## 设置过滤文本（按任意字段包含匹配, 空文本显示全部）
func set_filter(text: String) -> void:
	_filter_text = text.strip_edges()
	refresh()

func _row_matches(row: Dictionary) -> bool:
	for k in row:
		var v: Variant = row[k]
		if v != null and str(v).find(_filter_text) >= 0:
			return true
	return false

func _get_color_rules(key: String) -> Array:
	var cfg: Variant = DISPLAY.get(table_name)
	if cfg is Dictionary and (cfg as Dictionary).has(key):
		var v: Variant = (cfg as Dictionary)[key]
		if v is Array:
			return v as Array
	return []

func _cell_text(col: Dictionary, row: Dictionary) -> String:
	if col.has("join"):
		var jv: Variant = _resolve_join(str(col["join"]), row)
		return "" if jv == null else str(jv)
	var field: String = str(col.get("field", ""))
	var v: Variant = row.get(field, "")
	if v == null:
		v = ""
	if col.has("map"):
		return str(_map_value(col["map"], v))
	return str(v)

func _map_value(map_v: Variant, v: Variant) -> Variant:
	if not (map_v is Dictionary):
		return v
	var m: Dictionary = map_v as Dictionary
	# 归一化为 int 键查找（值可能是 int/float/String）
	var key: Variant = v
	if v is float:
		key = int(v as float)
	elif v is String and (v as String).is_valid_int():
		key = (v as String).to_int()
	if m.has(key):
		return m[key]
	# 字符串键（如方向）
	if m.has(str(v)):
		return m[str(v)]
	return v

# ===================== 关联列解析（复刻 querytable 的 JOIN） =====================

func _resolve_join(join_key: String, row: Dictionary) -> Variant:
	if data == null:
		return null
	match join_key:
		"map_name":
			var m: Dictionary = data.get_row_by_id("map", row.get("mapid"))
			return m.get("name", "")
		"scene_objcnt":
			return data.rows_where("scene_object", "sceneid", row.get("id")).size()
		"start_name":
			var s: Dictionary = data.get_row_by_id("scene", row.get("startpot"))
			return s.get("name", "")
		"end_name":
			var s2: Dictionary = data.get_row_by_id("scene", row.get("endpot"))
			return s2.get("name", "")
		"object_name":
			var o: Dictionary = data.get_row_by_id("object", row.get("objid"))
			return o.get("name", "")
		"skill_type_name":
			var st: Dictionary = data.get_row_by_id("skill_type", row.get("typeid"))
			return st.get("name", "")
		"item_type_name":
			# item_type 以 typeid 为键关联
			var matches: Array = data.rows_where("item_type", "typeid", row.get("typeid"))
			if matches.size() > 0 and matches[0] is Dictionary:
				return (matches[0] as Dictionary).get("name", "")
			return ""
		"property_type_name":
			var pt: Dictionary = data.get_row_by_id("property_type", row.get("typeid"))
			return pt.get("name", "")
		"property_link_name":
			var lp: Variant = row.get("link_prop")
			if lp == null:
				return ""
			if lp is String and (lp as String).strip_edges() == "":
				return ""
			if (lp is int or lp is float) and lp == 0:
				return ""
			var pl: Dictionary = data.get_row_by_id("property", lp)
			return pl.get("name", "")
	return null

# ===================== 颜色规则求值 =====================

func _apply_colors(item: TreeItem, row: Dictionary, fcolor_rules: Array, bcolor_rules: Array) -> void:
	var fc: Variant = _eval_color_rules(fcolor_rules, row)
	if fc is Color:
		for ci in item.get_tree().columns:
			item.set_custom_color(ci, fc as Color)
	var bc: Variant = _eval_color_rules(bcolor_rules, row)
	if bc is Color:
		for ci2 in item.get_tree().columns:
			item.set_custom_bg_color(ci2, bc as Color)

func _eval_color_rules(rules: Array, row: Dictionary) -> Variant:
	for rule_v in rules:
		if not (rule_v is Dictionary):
			continue
		var rule: Dictionary = rule_v as Dictionary
		if rule.has("field") and rule.has("values"):
			var field: String = str(rule["field"])
			var v: Variant = row.get(field)
			var key: Variant = v
			if v is float:
				key = int(v as float)
			var values: Dictionary = rule["values"]
			if values.has(key):
				return values[key]
			if values.has(str(v)):
				return values[str(v)]
			if rule.has("default"):
				return rule["default"]
		elif rule.has("nonempty_any"):
			var fields: Array = rule["nonempty_any"]
			var has_data: bool = false
			for f in fields:
				var fv: Variant = row.get(f, "")
				if fv != null and str(fv).strip_edges() != "":
					has_data = true
					break
			if has_data:
				return rule.get("color")
			return rule.get("else")
	return null

# ===================== 选择 =====================

func _on_item_selected() -> void:
	var item := _tree.get_selected()
	if item == null:
		return
	_selected_id = item.get_metadata(0)
	row_selected.emit(_selected_id)

func _on_item_activated() -> void:
	var item := _tree.get_selected()
	if item == null:
		return
	_selected_id = item.get_metadata(0)
	row_activated.emit(_selected_id)

func get_selected_id() -> Variant:
	return _selected_id

func select_by_id(id: Variant) -> void:
	_selected_id = id
	if _tree == null:
		return
	var root := _tree.get_root()
	if root == null:
		return
	var child := root.get_first_child()
	while child != null:
		if child.get_metadata(0) == id:
			child.select(0)
			return
		child = child.get_next()
