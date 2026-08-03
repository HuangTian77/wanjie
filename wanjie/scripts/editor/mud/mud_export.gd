## MUD编辑器 - 导出管道（逐函数移植 ME export/export.lua）
## 将内部 SQLite 模式层数据（MudData）转换为客户消费的 JSON txt（33个文件）。
## 输出目录默认 res://mud_engine/data/（游戏客户端读取处）。
## 内置 Lua 兼容 JSON 编码器：空表→[]、省略 null 值、整值浮点→整数、非转义中文，
## 以保证与 ME export.lua 输出在字段结构上完全一致。
class_name MudExport
extends RefCounted

## 默认导出目录（res:// = wanjie/）
const DEFAULT_OUT_DIR: String = "res://mud_engine/data"

var _data: MudData = null
## 最近一次导出的结果 {文件名(不含.txt): Variant}
var last_output: Dictionary = {}

func _init(data: MudData) -> void:
	_data = data

# ===================== Lua 兼容 JSON 编码 =====================

## 模拟 LuaJIT json.encode 的行为：
## - null 值在对象中被省略
## - 空 Dictionary/Array 都编码为 []
## - 整值浮点编码为整数（1.0 -> 1）
## - 中文等非 ASCII 字符原样输出（UTF-8）
static func lua_json_encode(v: Variant) -> String:
	return _enc(v)

static func _enc(v: Variant) -> String:
	if v == null:
		return "null"
	if v is bool:
		return "true" if (v as bool) else "false"
	if v is int:
		return str(v as int)
	if v is float:
		var f: float = v as float
		if f == floor(f) and abs(f) < 9007199254740992.0:
			return str(int(f))
		return str(f)
	if v is String:
		return _enc_string(v as String)
	if v is Array:
		var parts: PackedStringArray = []
		for item in v:
			parts.append(_enc(item))
		return "[" + ",".join(parts) + "]"
	if v is Dictionary:
		var d: Dictionary = v as Dictionary
		var parts2: PackedStringArray = []
		for k in d:
			var val: Variant = d[k]
			if val == null:
				continue  # Lua 省略 nil 值
			parts2.append(_enc_string(str(k)) + ":" + _enc(val))
		if parts2.is_empty():
			return "[]"  # Lua 空表 -> []
		return "{" + ",".join(parts2) + "}"
	return "\"" + str(v) + "\""

static func _enc_string(s: String) -> String:
	var out: String = "\""
	for i in s.length():
		var c: String = s[i]
		match c:
			"\"": out += "\\\""
			"\\": out += "\\\\"
			"\n": out += "\\n"
			"\r": out += "\\r"
			"\t": out += "\\t"
			"\b": out += "\\b"
			"\f": out += "\\f"
			_:
				var code: int = c.unicode_at(0)
				if code < 32:
					out += "\\u%04x" % code
				else:
					out += c
	out += "\""
	return out

# ===================== 类型辅助 =====================

static func _to_int(v: Variant) -> int:
	if v is int:
		return v as int
	if v is float:
		return int(v as float)
	if v is String:
		var s: String = (v as String).strip_edges()
		if s.is_valid_int():
			return s.to_int()
		if s.is_valid_float():
			return int(s.to_float())
	return 0

## tonumber(v)：成功返回数值，失败返回 null
static func _to_number(v: Variant) -> Variant:
	if v == null:
		return null
	if v is int or v is float:
		return v
	if v is String:
		var s: String = (v as String).strip_edges()
		if s.is_valid_int():
			return s.to_int()
		if s.is_valid_float():
			return s.to_float()
	return null

## 判断字符串是否为"空"（null 或 去空白后为空）
static func _is_blank(v: Variant) -> bool:
	if v == null:
		return true
	if v is String and (v as String).strip_edges() == "":
		return true
	return false

## 解析 JSON 字符串为 Variant（空串返回 null）
static func _json_parse(v: Variant) -> Variant:
	if v == null:
		return null
	if v is String:
		var s: String = (v as String).strip_edges()
		if s == "":
			return null
		return JSON.parse_string(s)
	return v

# ===================== 核心辅助函数（移植 export.lua） =====================

## 解析条件到配置 parseCondition
func parse_condition(cond: Variant) -> Variant:
	var arr: Variant = cond
	if cond is String:
		if _is_blank(cond):
			return null
		arr = JSON.parse_string(cond as String)
	if not (arr is Array):
		return null
	var c: Array = []
	for item_v in arr:
		if not (item_v is Dictionary):
			continue
		var item: Dictionary = item_v as Dictionary
		var t: Dictionary = {}
		t["id"] = item.get("subtype")
		t["type"] = item.get("type")
		var value: Variant = _to_number(item.get("value"))
		var condition: Variant = item.get("condition")
		if condition == "gt":
			t["min"] = value
		elif condition == "lt":
			t["max"] = value
		elif condition == "eq":
			t["min"] = value
			t["max"] = value
		c.append(t)
	return c if c.size() > 0 else null

## 获取触发结果数据 getResult
func get_result(item: Dictionary) -> Dictionary:
	var r: Dictionary = {}
	r["type"] = item.get("type")
	r["id"] = item.get("subtype")
	var v: Variant = item.get("value")
	var num: Variant = _to_number(v)
	r["value"] = num if num != null else v
	r["ops"] = item.get("ops")
	return r

## 解析触发结果 getResultData
func get_result_data(result: Variant) -> Variant:
	var arr: Variant = result
	if result is String:
		if _is_blank(result):
			arr = null
		else:
			arr = JSON.parse_string(result as String)
	var rt: Array = []
	if arr is Array:
		for item_v in arr:
			if item_v is Dictionary:
				rt.append(get_result(item_v as Dictionary))
	return rt if rt.size() > 0 else null

## 生成 need 或者 visible 的条件数据（带 ops）generateNeedOrVisibleData
func generate_need_or_visible_data(tp: Variant, cond: Variant, ops: Variant) -> Variant:
	if _is_blank(cond):
		return null
	var r: Dictionary = {}
	r["ops"] = ops if ops != null else 0
	if _to_int(tp) == 1:
		r["need"] = parse_condition(cond)
	elif _to_int(tp) == 2:
		r["needFunc"] = cond
	if r.get("need") != null or r.get("needFunc") != null:
		return r
	return null

## 生成结果数据 generateResultData
func generate_result_data(tp: Variant, result: Variant, desc: Variant = null) -> Variant:
	if _is_blank(result) and _is_blank(desc):
		return null
	var r: Dictionary = {}
	if _to_int(tp) == 1:
		r["addValue"] = get_result_data(result)
	elif _to_int(tp) == 2:
		r["func"] = result
	r["desc"] = desc
	if r.get("addValue") != null or r.get("func") != null or not _is_blank(r.get("desc")):
		return r
	return null

## 处理三大效果的数据 handleEffect（物品装备/携带/消耗）
## 注意：此处 trigger 为 0-配置 1-脚本（与通用 1-配置 2-脚本 不同）
func handle_effect(trigger: Variant, effect: Variant, cond: Variant, cond_ops: Variant) -> Variant:
	var r: Variant = null
	if not _is_blank(effect):
		r = {}
		if _to_int(trigger) == 1:
			(r as Dictionary)["addFunc"] = effect
		else:
			var data: Variant = _json_parse(effect)
			if data is Array:
				for v_v in data:
					if v_v is Dictionary:
						var v: Dictionary = v_v as Dictionary
						v["id"] = v.get("subtype")
						v.erase("subtype")
						if not v.has("ops") or v.get("ops") == null:
							v["ops"] = 1
				(r as Dictionary)["addValue"] = data
	if not _is_blank(cond):
		if r == null:
			r = {}
		(r as Dictionary)["need"] = generate_need_or_visible_data(1, cond, cond_ops)
	return r

## 获取属性计算依赖 getPropertyDependent
## 提取 getProperty('name') 与 getProperty(123)，返回 JSON 字符串数组或 null
func get_property_dependent(script: Variant) -> Variant:
	if _is_blank(script):
		return null
	var s: String = script as String
	var pkey: Dictionary = {}
	var names: Array = []
	var re1 := RegEx.new()
	re1.compile("getProperty\\(['\"]([^'\"]+)['\"]\\)")
	for m in re1.search_all(s):
		var prop: String = m.get_string(1)
		if prop.is_valid_int() or prop.is_valid_float():
			pkey[prop] = true
		else:
			if not names.has(prop):
				names.append(prop)
	# 属性名称 -> id
	for nm in names:
		var row: Dictionary = _data.get_property_by_name(nm as String)
		if not row.is_empty():
			pkey[str(row.get("id"))] = true
	# 纯数字 key
	var re2 := RegEx.new()
	re2.compile("getProperty\\((\\d+)\\)")
	for m in re2.search_all(s):
		pkey[m.get_string(1)] = true
	var dependent: Array = []
	for k in pkey:
		dependent.append(str(k))
	if dependent.size() > 0:
		return JSON.stringify(dependent)
	return null

## 生成随机事件数据 generateRandomEventData（就地修改 t）
func generate_random_event_data(t: Dictionary, rdata: Variant) -> void:
	if _is_blank(rdata):
		return
	var data: Variant = _json_parse(rdata)
	if not (data is Dictionary):
		return
	var dd: Dictionary = data as Dictionary
	if dd.has("data") and dd["data"] is Array:
		for v_v in dd["data"]:
			if v_v is Dictionary:
				var v: Dictionary = v_v as Dictionary
				v["id"] = v.get("subtype")
				v.erase("subtype")
	var tp: int = _to_int(t.get("type"))
	if tp == 1:
		t["data"] = dd.get("data")
	elif tp == 2:
		t["data"] = dd.get("data")
		t["selType"] = 1 if dd.get("duplicate") else 2
		t["selNum"] = dd.get("count")
	elif tp == 3:
		t["func"] = dd.get("data")

## 生成交易数据 generateExchangeData
func generate_exchange_data(data: Variant, direction: int = 0) -> Array:
	var r: Array = []
	if data == null:
		return r
	var key1: String = "token"
	var key2: String = "target"
	if direction == 1:
		var tmp: String = key1
		key1 = key2
		key2 = tmp
	var arr: Variant = _json_parse(data)
	if not (arr is Array):
		return r
	for row_v in arr:
		if not (row_v is Dictionary):
			continue
		var row: Dictionary = row_v as Dictionary
		var t: Dictionary = {}
		if row.has(key1) and row[key1] is Array:
			for item_v in row[key1]:
				if item_v is Dictionary:
					var item: Dictionary = item_v as Dictionary
					item["id"] = item.get("subtype")
					item.erase("subtype")
			t["from"] = row[key1]
		if row.has(key2) and row[key2] is Array:
			for item_v in row[key2]:
				if item_v is Dictionary:
					var item: Dictionary = item_v as Dictionary
					item["id"] = item.get("subtype")
					item.erase("subtype")
			t["to"] = row[key2]
		r.append(t)
	return r

## 生成结果 generateResult（就地修改 t）
func generate_result(t: Dictionary, tp: Variant, data: Variant) -> void:
	if _to_int(tp) == 1:
		t["addValue"] = get_result_data("" if _is_blank(data) else data)
	elif _to_int(tp) == 2:
		t["addFunc"] = data

# ===================== 各表导出（load* 函数） =====================

## CityObjects <- scene_object
func load_city_objects() -> Array:
	var so: Array = []
	for v_v in _data.get_table("scene_object"):
		if not (v_v is Dictionary):
			continue
		var v: Dictionary = v_v as Dictionary
		if v.get("sceneid") != null:
			var ctrl: Variant = _json_parse(v.get("ctrl"))
			var visible: Variant = null
			if ctrl is Dictionary:
				var cd: Dictionary = ctrl as Dictionary
				visible = generate_need_or_visible_data(cd.get("trigger"), cd.get("cond"), cd.get("cond_ops"))
			so.append({"cityID": v.get("sceneid"), "objectID": v.get("objid"), "visible": visible})
	return so

## Citys <- scene
func load_citys() -> Array:
	var t: Array = []
	for row_v in _data.get_all_scene():
		if not (row_v is Dictionary):
			continue
		var row: Dictionary = row_v as Dictionary
		t.append({
			"id": row.get("id"),
			"name": row.get("name"),
			"desc": row.get("desc"),
			"enterNeed": generate_need_or_visible_data(row.get("et_cond_type"), row.get("enter_cond"), row.get("et_cond_ops")),
			"leaveNeed": generate_need_or_visible_data(row.get("lt_cond_type"), row.get("leave_cond"), row.get("lt_cond_ops")),
			"enterSuccess": generate_result_data(row.get("et_type"), row.get("enter_trigger")),
			"leaveSuccess": generate_result_data(row.get("lt_type"), row.get("leave_trigger")),
			"enterFail": generate_result_data(row.get("et_fail_type"), row.get("enter_trigger_fail")),
			"leaveFail": generate_result_data(row.get("lt_fail_type"), row.get("leave_trigger_fail")),
		})
	return t

## CityWays <- linkpath
func load_city_ways() -> Array:
	var t: Array = []
	for v_v in _data.get_table("linkpath"):
		if not (v_v is Dictionary):
			continue
		var v: Dictionary = v_v as Dictionary
		var fail_desc: Variant = v.get("passcond_fail_desc")
		if fail_desc is String and (fail_desc as String) == "":
			fail_desc = null
		t.append({
			"id": v.get("id"),
			"from": v.get("startpot"),
			"to": v.get("endpot"),
			"direct": v.get("direct"),
			"need": generate_need_or_visible_data(v.get("passcond_type"), v.get("passcond"), v.get("passcond_ops")),
			"visible": generate_need_or_visible_data(v.get("opencond_type"), v.get("opencond"), v.get("opencond_ops")),
			"failDesc": fail_desc,
		})
	return t

## GoodsAction <- module_talk
func load_goods_action() -> Array:
	var t: Array = []
	for v_v in _data.get_table("module_talk"):
		if not (v_v is Dictionary):
			continue
		var v: Dictionary = v_v as Dictionary
		t.append({
			"actionName": v.get("name"),
			"id": v.get("id"),
			"objectID": v.get("objid"),
			"need": generate_need_or_visible_data(v.get("trigger_type"), v.get("condition"), v.get("cond_ops")),
			"success": generate_result_data(v.get("succ_type"), v.get("succ_trigger"), v.get("content")),
			"fail": generate_result_data(v.get("fail_type"), v.get("fail_trigger"), v.get("fail_desc")),
			"actionCount": v.get("trigger_count"),
			"visible": generate_need_or_visible_data(v.get("visible_cond_trigger_type"), v.get("visible_cond"), v.get("visible_ops")),
		})
	return t

## Goods <- object（原始行）
func load_goods() -> Array:
	var out: Array = []
	for row_v in _data.get_table("object"):
		if row_v is Dictionary:
			out.append((row_v as Dictionary).duplicate(true))
	return out

## Property / PropertyAction / PropertyValue <- property
func load_property() -> Dictionary:
	var t: Array = []
	var t1: Array = []
	var t2: Array = []
	for v_v in _data.get_table("property"):
		if not (v_v is Dictionary):
			continue
		var v: Dictionary = v_v as Dictionary
		# 主从属性
		var mid: Variant = null
		if _to_int(v.get("master")) < 1:
			mid = v.get("link_prop")
		# 计算公式
		var calc_func: Variant = null
		if not _is_blank(v.get("calc")):
			calc_func = v.get("calc")
		var dependent: Variant = null
		if calc_func != null:
			dependent = get_property_dependent(calc_func)
		# 上下限
		var min_v: Variant = 0
		var max_v: Variant = 2147483648  # 2^31
		if not _is_blank(v.get("range")):
			var rng: Variant = _json_parse(v.get("range"))
			if rng is Dictionary:
				min_v = (rng as Dictionary).get("min")
				max_v = (rng as Dictionary).get("max")
		t.append({
			"id": v.get("id"),
			"tagID": v.get("typeid"),
			"name": v.get("name"),
			"weight": v.get("priority"),
			"desc": v.get("desc"),
			"func": calc_func,
			"min": min_v,
			"max": max_v,
			"preProperty": dependent,
			"maxProperty": mid,
		})
		# PropertyAction
		if not _is_blank(v.get("trigger")):
			var data_arr: Array = []
			var trigger: Variant = _json_parse(v.get("trigger"))
			if trigger is Array:
				for row_v2 in trigger:
					if not (row_v2 is Dictionary):
						continue
					var row: Dictionary = row_v2 as Dictionary
					var rt: int = _to_int(row.get("result_type"))
					var success: Dictionary = {}
					if rt == 1:
						var rd: Variant = get_result_data(row.get("result"))
						success["addValue"] = rd if rd != null else ""
					else:
						success["addValue"] = ""
					success["desc"] = ""
					success["func"] = row.get("result") if rt == 2 else ""
					data_arr.append({"value": row.get("tvalue"), "success": success})
			t1.append({"propertyID": v.get("id"), "data": data_arr})
		# PropertyValue
		if not _is_blank(v.get("dict")):
			var data: Variant = _json_parse(v.get("dict"))
			if data is Dictionary:
				var dd: Dictionary = data as Dictionary
				var vdata: Array = []
				if dd.has("data") and dd["data"] is Array:
					for row_v3 in dd["data"]:
						if not (row_v3 is Dictionary):
							continue
						var row3: Dictionary = (row_v3 as Dictionary).duplicate(true)
						var mn: Variant = row3.get("min")
						if not _is_blank(mn):
							if _is_blank(row3.get("max")):
								row3["max"] = mn
							vdata.append(row3)
				t2.append({"id": v.get("id"), "desc": dd.get("default"), "data": vdata})
	return {"Property": t, "PropertyAction": t1, "PropertyValue": t2}

## PropertyTagName <- property_type
func load_property_tag_name() -> Array:
	var out: Array = []
	for row_v in _data.get_table("property_type"):
		if not (row_v is Dictionary):
			continue
		var row: Dictionary = row_v as Dictionary
		out.append({"id": row.get("id"), "name": row.get("name"), "weight": row.get("priority"), "visible": row.get("visible")})
	return out

## GoodsTagName <- item_type
func load_goods_tag_name() -> Array:
	var out: Array = []
	for row_v in _data.get_table("item_type"):
		if not (row_v is Dictionary):
			continue
		var row: Dictionary = row_v as Dictionary
		out.append({"id": row.get("typeid"), "name": row.get("name"), "weight": row.get("priority"), "visible": row.get("visible")})
	return out

## GoodsUse <- item
func load_goods_use() -> Array:
	var t: Array = []
	for row_v in _data.get_table("item"):
		if not (row_v is Dictionary):
			continue
		var row: Dictionary = row_v as Dictionary
		# 物品插槽
		var slot: Variant = null
		if not _is_blank(row.get("slots")):
			slot = _json_parse(row.get("slots"))
			if slot is Array:
				for s_v in slot:
					if s_v is Dictionary:
						var s: Dictionary = s_v as Dictionary
						s["slotNum"] = s.get("cnt")
						s.erase("cnt")
		# 三大效果
		var equip_value: Variant = handle_effect(row.get("prop_equip_trigger_type"), row.get("prop_equip"), row.get("cond_equip"), row.get("cond_equip_ops"))
		var carry_value: Variant = handle_effect(row.get("prop_carry_trigger_type"), row.get("prop_carry"), row.get("cond_carry"), row.get("cond_carry_ops"))
		var consume_value: Variant = handle_effect(row.get("prop_consume_trigger_type"), row.get("prop_consume"), row.get("cond_consume"), row.get("cond_consume_ops"))
		# 交互按钮
		var btns: Variant = null
		if not _is_blank(row.get("alternation")):
			btns = []
			var data: Variant = _json_parse(row.get("alternation"))
			if data is Array:
				for vdata_v in data:
					if not (vdata_v is Dictionary):
						continue
					var vdata: Dictionary = vdata_v as Dictionary
					var btn: Dictionary = {}
					btn["text"] = vdata.get("name")
					if vdata.has("visible") and vdata["visible"] is Dictionary:
						var vd: Dictionary = vdata["visible"] as Dictionary
						btn["visible"] = generate_need_or_visible_data(vd.get("type"), vd.get("value"), vd.get("ops"))
					if vdata.has("trigger_cond") and vdata["trigger_cond"] is Dictionary:
						var vd: Dictionary = vdata["trigger_cond"] as Dictionary
						btn["need"] = generate_need_or_visible_data(vd.get("type"), vd.get("value"), vd.get("ops"))
					if vdata.has("trigger_succ") and vdata["trigger_succ"] is Dictionary:
						var vd: Dictionary = vdata["trigger_succ"] as Dictionary
						btn["success"] = generate_result_data(vd.get("type"), vd.get("value"))
					if vdata.has("trigger_fail") and vdata["trigger_fail"] is Dictionary:
						var vd: Dictionary = vdata["trigger_fail"] as Dictionary
						btn["fail"] = generate_result_data(vd.get("type"), vd.get("value"))
					if btn.get("success") == null:
						btn["success"] = {}
					(btn["success"] as Dictionary)["desc"] = vdata.get("desc") if vdata.get("desc") != null else ""
					if btn.get("fail") == null:
						btn["fail"] = {}
					(btn["fail"] as Dictionary)["desc"] = vdata.get("fail_desc") if vdata.get("fail_desc") != null else ""
					(btns as Array).append(btn)
		t.append({
			"id": row.get("id"),
			"name": row.get("name"),
			"desc": row.get("desc"),
			"tagID": row.get("typeid"),
			"weight": 100,
			"equip": row.get("feature_equip"),
			"destory": row.get("feature_destory"),
			"consume": row.get("feature_consume"),
			"equipValue": equip_value,
			"carryValue": carry_value,
			"consumeValue": consume_value,
			"btns": btns,
			"slot": slot,
		})
	return t

## Question <- alternation
func load_question() -> Array:
	var t: Array = []
	for row_v in _data.get_table("alternation"):
		if not (row_v is Dictionary):
			continue
		var row: Dictionary = row_v as Dictionary
		var data: Variant = _json_parse(row.get("data"))
		var btns: Array = []
		if data is Array:
			for item_v in data:
				if not (item_v is Dictionary):
					continue
				var item: Dictionary = item_v as Dictionary
				var btn: Dictionary = {}
				btn["text"] = item.get("name")
				if item.has("visible") and item["visible"] is Dictionary:
					var vd: Dictionary = item["visible"] as Dictionary
					btn["visible"] = generate_need_or_visible_data(vd.get("type"), vd.get("value"), vd.get("ops"))
				if item.has("trigger_cond") and item["trigger_cond"] is Dictionary:
					var vd: Dictionary = item["trigger_cond"] as Dictionary
					btn["need"] = generate_need_or_visible_data(vd.get("type"), vd.get("value"), vd.get("ops"))
				if item.has("trigger_succ") and item["trigger_succ"] is Dictionary:
					var vd: Dictionary = item["trigger_succ"] as Dictionary
					btn["success"] = generate_result_data(vd.get("type"), vd.get("value"))
				if item.has("trigger_fail") and item["trigger_fail"] is Dictionary:
					var vd: Dictionary = item["trigger_fail"] as Dictionary
					btn["fail"] = generate_result_data(vd.get("type"), vd.get("value"))
				if btn.get("success") == null:
					btn["success"] = {}
				(btn["success"] as Dictionary)["desc"] = item.get("desc") if item.get("desc") != null else ""
				if btn.get("fail") == null:
					btn["fail"] = {}
				(btn["fail"] as Dictionary)["desc"] = item.get("fail_desc") if item.get("fail_desc") != null else ""
				btns.append(btn)
		t.append({"id": row.get("id"), "title": row.get("name"), "content": row.get("desc"), "btns": btns})
	return t

## Story <- story
func load_story() -> Array:
	var t: Array = []
	for row_v in _data.get_table("story"):
		if not (row_v is Dictionary):
			continue
		var row: Dictionary = row_v as Dictionary
		var dtype: int = _to_int(row.get("dtype"))
		if dtype == 0:
			var data: Variant = _json_parse(row.get("data"))
			if data is Dictionary:
				var dd: Dictionary = (data as Dictionary).duplicate(true)
				if dd.has("story") and dd["story"] is String:
					var story_arr: Array = []
					for piece in (dd["story"] as String).split(" ", false):
						story_arr.append(piece)
					dd["story"] = story_arr
				dd["id"] = row.get("id")
				t.append(dd)
		elif dtype == 1:
			# 脚本类型：Godot 无法执行 Lua loadstring，原样保留 data（尽力兼容）
			var sd: Dictionary = {"id": row.get("id"), "story": [], "func": row.get("data")}
			t.append(sd)
	return t

## Drop <- reward
func load_drop() -> Array:
	var t: Array = []
	for item_v in _data.get_table("reward"):
		if not (item_v is Dictionary):
			continue
		var item: Dictionary = item_v as Dictionary
		if not _is_blank(item.get("data")):
			var tp: Variant = item.get("type")
			var data: Variant = _json_parse(item.get("data"))
			if data is Dictionary:
				var dd: Dictionary = data as Dictionary
				if dd.has("reward") and dd["reward"] is Array:
					for config_v in dd["reward"]:
						if config_v is Dictionary:
							var config: Dictionary = config_v as Dictionary
							config["id"] = config.get("subtype")
							config.erase("subtype")
					t.append({
						"id": item.get("id"),
						"data": dd["reward"],
						"type": tp,
						"selNum": dd.get("count"),
						"selType": 1 if dd.get("duplicate") else 2,
					})
	return t

## NPC <- enemy
func load_npc() -> Array:
	var enemy_default_skill: int = _to_int(_data.config_get("skill_default_enemy_skill", -1))
	var t: Array = []
	for item_v in _data.get_table("enemy"):
		if not (item_v is Dictionary):
			continue
		var item: Dictionary = item_v as Dictionary
		var property: Variant = null
		var script: Variant = null
		var skill_id: Variant = null
		if _to_int(item.get("type")) == 0:
			if not _is_blank(item.get("property")):
				property = _json_parse(item.get("property"))
				if property is Array:
					for prop_v in property:
						if prop_v is Dictionary:
							var prop: Dictionary = prop_v as Dictionary
							prop["id"] = prop.get("subtype")
							prop.erase("class")
							prop.erase("subtype")
				if not _is_blank(item.get("skill")):
					var s: Variant = _json_parse(item.get("skill"))
					if s is Array and (s as Array).size() > 0:
						skill_id = (s as Array)[0]
				elif enemy_default_skill > 0:
					skill_id = enemy_default_skill
		else:
			script = item.get("script")
		t.append({"id": item.get("id"), "name": item.get("name"), "property": property, "skillID": skill_id, "func": script})
	return t

## NPCCombat <- campaign
func load_npc_combat() -> Array:
	var default_fail_trigger: Variant = _data.config_get("campaign_default_fail_trigger")
	var t: Array = []
	for item_v in _data.get_table("campaign"):
		if not (item_v is Dictionary):
			continue
		var item: Dictionary = item_v as Dictionary
		var trigger: Variant = _json_parse(item.get("trigger"))
		var enemies: Variant = _json_parse(item.get("enemies"))
		var npc_list: Array = []
		if enemies is Array:
			for e in enemies:
				npc_list.append(e)
		# 胜利触发
		var success: Variant = null
		var fail: Variant = null
		if trigger is Dictionary:
			var td: Dictionary = trigger as Dictionary
			if td.has("win") and td["win"] is Dictionary:
				var win: Dictionary = td["win"] as Dictionary
				success = {}
				(success as Dictionary)["desc"] = win.get("desc") if win.get("desc") != null else ""
				if _to_int(win.get("control")) == 1:
					(success as Dictionary)["addValue"] = get_result_data(win.get("data"))
				elif _to_int(win.get("control")) == 2:
					(success as Dictionary)["func"] = win.get("data")
			# 失败触发
			if td.has("lose") and td["lose"] is Dictionary:
				var lose: Dictionary = td["lose"] as Dictionary
				fail = {}
				(fail as Dictionary)["desc"] = lose.get("desc")
				if _to_int(lose.get("control")) == 1:
					(fail as Dictionary)["addValue"] = get_result_data(lose.get("data"))
				elif _to_int(lose.get("control")) == 2:
					(fail as Dictionary)["func"] = lose.get("data")
				elif not _is_blank(default_fail_trigger):
					(fail as Dictionary)["addValue"] = get_result_data(default_fail_trigger)
			elif not _is_blank(default_fail_trigger):
				fail = {"desc": "", "addValue": get_result_data(default_fail_trigger)}
		t.append({
			"id": item.get("id"),
			"name": item.get("name"),
			"desc": item.get("desc"),
			"npcList": npc_list,
			"success": success,
			"fail": fail,
		})
	return t

## Skill <- skill
func load_skill() -> Array:
	var t: Array = []
	for row_v in _data.get_table("skill"):
		if not (row_v is Dictionary):
			continue
		var row: Dictionary = row_v as Dictionary
		# 插槽 cnt -> slotNum
		var slot: Variant = null
		if not _is_blank(row.get("slots")):
			var slot_data: String = (row.get("slots") as String).replace("cnt", "slotNum")
			slot = JSON.parse_string(slot_data)
		# 消耗
		var consume: Variant = generate_result_data(row.get("consume_type"), row.get("consume_data"))
		if _to_int(row.get("consume_type")) == 1:
			if not _is_blank(row.get("consume_data")):
				var data: Variant = _json_parse(row.get("consume_data"))
				var need: Array = []
				if data is Array:
					for con_v in data:
						if not (con_v is Dictionary):
							continue
						var con: Dictionary = con_v as Dictionary
						var v: Variant = _to_number(con.get("value"))
						if v != null and (v is int and (v as int) < 0 or v is float and (v as float) < 0.0):
							need.append({"ops": 0, "type": con.get("type"), "id": con.get("subtype"), "min": abs(v as float) if v is float else abs(v as int)})
				if need.size() > 0 and consume is Dictionary:
					(consume as Dictionary)["need"] = need
		t.append({
			"id": row.get("id"),
			"name": row.get("name"),
			"desc": row.get("desc"),
			"func": row.get("data"),
			"need": generate_need_or_visible_data(row.get("equip_type"), row.get("equip_data"), row.get("equip_cond_ops")),
			"consume": consume,
			"tagID": row.get("typeid"),
			"slot": slot,
		})
	return t

## SkillTagName <- skill_type
func load_skill_tag_name() -> Array:
	var out: Array = []
	for row_v in _data.get_table("skill_type"):
		if not (row_v is Dictionary):
			continue
		var row: Dictionary = row_v as Dictionary
		out.append({"id": row.get("id"), "name": row.get("name"), "weight": row.get("priority"), "visible": row.get("visible")})
	return out

## Slot <- slot
func load_slot() -> Array:
	var out: Array = []
	for row_v in _data.get_table("slot"):
		if not (row_v is Dictionary):
			continue
		var row: Dictionary = row_v as Dictionary
		out.append({"id": row.get("id"), "name": row.get("name"), "slotNum": row.get("cnt")})
	return out

## CombatProperty <- config(campaign_property)
func load_combat_property() -> Variant:
	var r: Variant = _data.config_get("campaign_property")
	if not _is_blank(r):
		var arr: Variant = _json_parse(r)
		if arr is Array:
			for idx in arr.size():
				var row_v: Variant = arr[idx]
				if row_v is Dictionary:
					var row: Dictionary = row_v as Dictionary
					row["weight"] = idx + 1
					row["propertyID"] = row.get("id")
			return arr
	return null

## MapEnter <- config(game_born_point)
func load_map_enter() -> Array:
	var r: Variant = _data.config_get("game_born_point")
	var city_id: Variant = r if r != null else 1
	return [{"mapID": 1, "cityID": city_id}]

## RandomAction <- random
func load_random_action() -> Array:
	var t: Array = []
	for row_v in _data.get_table("random"):
		if not (row_v is Dictionary):
			continue
		var row: Dictionary = row_v as Dictionary
		var success: Dictionary = {"type": row.get("success_type")}
		generate_random_event_data(success, row.get("success"))
		var fail: Dictionary = {"type": row.get("fail_type")}
		generate_random_event_data(fail, row.get("fail"))
		t.append({
			"id": row.get("id"),
			"name": row.get("name"),
			"need": generate_need_or_visible_data(row.get("cond_type"), row.get("cond"), row.get("cond_ops")),
			"success": success,
			"fail": fail,
		})
	return t

## Navigation <- config(navigation)
func load_navigation() -> Array:
	var r: Variant = _data.config_get("navigation")
	if _is_blank(r):
		r = '[{"type":1,"weight":1,"name":"角色","id":1},{"type":2,"weight":2,"name":"道具","id":2},{"type":3,"weight":3,"name":"技能","id":3}]'
	var arr: Variant = _json_parse(r)
	return arr if arr is Array else []

## Exchange <- trade
func load_exchange() -> Array:
	var t: Array = []
	for row_v in _data.get_table("trade"):
		if not (row_v is Dictionary):
			continue
		var row: Dictionary = row_v as Dictionary
		var buy: Variant = null
		var sale: Variant = null
		if _to_int(row.get("type")) == 0:
			buy = generate_exchange_data(row.get("tradeout"))
			sale = generate_exchange_data(row.get("tradein"), 1)
		t.append({
			"id": row.get("id"),
			"name": row.get("name"),
			"desc": row.get("desc"),
			"type": _to_int(row.get("type")) + 1,
			"buy": buy,
			"sale": sale,
		})
	return t

## ObjectAutoRun <- generator
func load_object_auto_run() -> Array:
	var t: Array = []
	for row_v in _data.get_table("generator"):
		if not (row_v is Dictionary):
			continue
		var row: Dictionary = row_v as Dictionary
		var data: Variant = _json_parse(row.get("data"))
		var dd: Dictionary = data if data is Dictionary else {}
		var start: Dictionary = {}
		start["need"] = generate_need_or_visible_data(row.get("cond_open_type"), row.get("cond_open"), row.get("cond_open_ops"))
		var prize: Dictionary = {}
		prize["need"] = generate_need_or_visible_data(row.get("cond_get_type"), row.get("cond_get"), row.get("cond_get_ops"))
		generate_result(start, row.get("trigger_open_type"), row.get("trigger_open"))
		generate_result(prize, row.get("trigger_get_type"), row.get("trigger_get"))
		var product_time: Variant = null
		var time_num: Variant = _to_number(dd.get("time"))
		if time_num != null:
			product_time = float(time_num) * 60.0
		t.append({
			"id": row.get("id"),
			"name": row.get("name"),
			"desc": row.get("desc"),
			"type": row.get("type"),
			"autoStart": row.get("auto_start"),
			"productID": dd.get("subtype"),
			"goodsType": dd.get("type"),
			"productCount": dd.get("count"),
			"productTime": product_time,
			"countMax": dd.get("volume"),
			"getCount": dd.get("gain"),
			"start": start,
			"prize": prize,
		})
	return t

## Pay <- payment
func load_pay() -> Array:
	var t: Array = []
	for row_v in _data.get_table("payment"):
		if not (row_v is Dictionary):
			continue
		var row: Dictionary = row_v as Dictionary
		t.append({
			"id": row.get("id"),
			"name": row.get("name"),
			"price": row.get("price"),
			"desc": row.get("desc"),
			"addValue": get_result_data(row.get("content")),
		})
	return t

## OnlineFunc <- config(multiple_script)
func load_online_func() -> Array:
	return [{"id": 1, "func": _data.config_get("multiple_script")}]

## SharePrize <- config(share_reward)（仅非空时导出）
func load_share_prize() -> Variant:
	var sr: Variant = _data.config_get("share_reward")
	if not _is_blank(sr):
		return [{"id": 1, "addValue": get_result_data(sr)}]
	return null

## CommonAction <- logic
func load_common_action() -> Array:
	var t: Array = []
	for item_v in _data.get_table("logic"):
		if not (item_v is Dictionary):
			continue
		var item: Dictionary = item_v as Dictionary
		var cond: Variant = _json_parse(item.get("condition"))
		var success: Variant = _json_parse(item.get("success"))
		var fail: Variant = _json_parse(item.get("fail"))
		var cd: Dictionary = cond if cond is Dictionary else {}
		var sd: Dictionary = success if success is Dictionary else {}
		var fd: Dictionary = fail if fail is Dictionary else {}
		t.append({
			"id": item.get("id"),
			"need": generate_need_or_visible_data(cd.get("type"), cd.get("data"), cd.get("ops")),
			"success": generate_result_data(sd.get("type"), sd.get("data")),
			"fail": generate_result_data(fd.get("type"), fd.get("data")),
		})
	return t

## GameInfo <- config(game_title/game_version)
func load_game_info() -> Array:
	return [{"name": _data.config_get("game_title"), "version": _data.config_get("game_version")}]

## Setting <- config
func load_setting() -> Array:
	var move_time: Variant = _to_number(_data.config_get("map_move_time", 300))
	if move_time == null:
		move_time = 300
	var show_move_log: Variant = _to_number(_data.config_get("map_move_show_log", 1))
	if show_move_log == null:
		show_move_log = 1
	var show_trace_log: Variant = _to_number(_data.config_get("game_debug_trace_log", 1))
	if show_trace_log == null:
		show_trace_log = 1
	var use_equip_tab: Variant = _to_number(_data.config_get("goods_use_equip_tab", 1))
	if use_equip_tab == null:
		use_equip_tab = 1
	return [
		{"key": "map_moveTime", "value": float(move_time) / 1000.0},
		{"key": "map_showMoveLog", "value": show_move_log},
		{"key": "log_showTraceLog", "value": show_trace_log},
		{"key": "goods_useEquipTab", "value": use_equip_tab},
	]

## customdata <- custom_data（输出为 [ {kname:value, ...} ]）
func load_custom_data() -> Array:
	var t: Dictionary = {}
	for row_v in _data.get_table("custom_data"):
		if not (row_v is Dictionary):
			continue
		var row: Dictionary = row_v as Dictionary
		var value: Variant = row.get("data")
		if _to_int(row.get("type")) == 1:
			value = _json_parse(row.get("data"))
		t[str(row.get("kname"))] = value
	return [t]

## LuaExport <- script_pluggin
func load_lua_export() -> Array:
	var t: Array = []
	var rows: Array = _data.get_table("script_pluggin")
	for i in rows.size():
		var row_v: Variant = rows[i]
		if row_v is Dictionary:
			t.append({"id": i + 1, "func": (row_v as Dictionary).get("data")})
	return t

# ===================== 编排 =====================

## 生成全部导出数据，返回 {文件名(不含.txt): Variant}
## 对应 export.lua 的 loadAll()，每个 load 用 pcall 包裹（这里逐个 try）
func export_all() -> Dictionary:
	last_output.clear()
	_put("CityObjects", load_city_objects())
	_put("Citys", load_citys())
	_put("CityWays", load_city_ways())
	_put("GoodsAction", load_goods_action())
	_put("Goods", load_goods())
	# Property 一次生成三个文件
	var prop: Dictionary = load_property()
	for k in prop:
		_put(k as String, prop[k])
	_put("PropertyTagName", load_property_tag_name())
	_put("GoodsTagName", load_goods_tag_name())
	_put("GoodsUse", load_goods_use())
	_put("Question", load_question())
	_put("Story", load_story())
	_put("Drop", load_drop())
	_put("NPC", load_npc())
	_put("NPCCombat", load_npc_combat())
	_put("Skill", load_skill())
	_put("SkillTagName", load_skill_tag_name())
	_put("Slot", load_slot())
	_put("CombatProperty", load_combat_property())
	_put("MapEnter", load_map_enter())
	_put("RandomAction", load_random_action())
	_put("Navigation", load_navigation())
	_put("Exchange", load_exchange())
	_put("ObjectAutoRun", load_object_auto_run())
	_put("Pay", load_pay())
	_put("OnlineFunc", load_online_func())
	# SharePrize 仅非空时导出
	var sp: Variant = load_share_prize()
	if sp != null:
		_put("SharePrize", sp)
	_put("CommonAction", load_common_action())
	_put("GameInfo", load_game_info())
	_put("Setting", load_setting())
	_put("customdata", load_custom_data())
	_put("LuaExport", load_lua_export())
	return last_output

func _put(name: String, data: Variant) -> void:
	last_output[name] = data

## 将全部导出文件写入目录（默认 res://mud_engine/data）
## 返回写入的文件数量
func write_all(out_dir: String = DEFAULT_OUT_DIR) -> int:
	if last_output.is_empty():
		export_all()
	if not out_dir.ends_with("/"):
		out_dir += "/"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var count: int = 0
	for name in last_output:
		var data: Variant = last_output[name]
		var json_str: String = lua_json_encode(data)
		var file := FileAccess.open(out_dir + (name as String) + ".txt", FileAccess.WRITE)
		if file != null:
			file.store_string(json_str)
			file.close()
			count += 1
	return count
