## MUD编辑器 - 导入（export 格式反解析 + 版本兼容）
## 将 ME export.lua 产出的导出格式（Citys/Goods/CityWays 等 JSON txt）
## 尽力反解析回内部 SQLite 模式层（28 表）。导出是有损的（丢弃部分字段），
## 故导入为"尽力映射"，用于向后兼容旧数据与从 mud_engine/data 加载。
class_name MudImport
extends RefCounted

## 导出格式的全部文件名（不含 .txt）
const EXPORT_FILES: Array = [
	"CityObjects", "Citys", "CityWays", "GoodsAction", "Goods",
	"Property", "PropertyAction", "PropertyValue", "PropertyTagName",
	"GoodsTagName", "GoodsUse", "Question", "Story", "Drop", "NPC", "NPCCombat",
	"Skill", "SkillTagName", "Slot", "CombatProperty", "MapEnter", "RandomAction",
	"Navigation", "Exchange", "ObjectAutoRun", "Pay", "OnlineFunc", "SharePrize",
	"CommonAction", "GameInfo", "Setting", "customdata", "LuaExport",
]

var _data: MudData = null

func _init(target: MudData = null) -> void:
	_data = target if target != null else MudData.new()

func get_data() -> MudData:
	return _data

# ===================== 入口 =====================

## 从导出目录（res://mud_engine/data）导入，返回填充后的 MudData
static func from_dir(dir: String) -> MudData:
	var imp := MudImport.new()
	imp._import_dir(dir)
	return imp.get_data()

## 从内存中的导出格式字典 {Citys:[...], Goods:[...], ...} 导入
static func from_dict(export_dict: Dictionary) -> MudData:
	var imp := MudImport.new()
	imp._import_dict(export_dict)
	return imp.get_data()

## 判断一个字典是否为导出格式（含 Citys/Goods 等导出表名键）
static func is_export_format(d: Variant) -> bool:
	if not (d is Dictionary):
		return false
	var dd: Dictionary = d as Dictionary
	for k in dd:
		if EXPORT_FILES.has(k as String):
			return true
	return false

func _import_dir(dir: String) -> void:
	_data.clear_all(false)
	var base: String = dir
	if not base.ends_with("/"):
		base += "/"
	for name in EXPORT_FILES:
		var v: Variant = _read_json(base + (name as String) + ".txt")
		_import_table(name as String, v)
	# PropertyValue/PropertyAction 需要合并进 property（在 _import_table 内已处理）
	_data.data_reset.emit()

func _import_dict(export_dict: Dictionary) -> void:
	_data.clear_all(false)
	# 先处理 Property 主表，再处理 Action/Value 合并
	for name in EXPORT_FILES:
		if export_dict.has(name):
			_import_table(name as String, export_dict[name])
	_data.data_reset.emit()

func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var text: String = f.get_as_text().strip_edges()
	f.close()
	if text == "" or text == "null":
		return null
	return JSON.parse_string(text)

# ===================== 反解析辅助 =====================

## 反解析 need/visible {ops, need, needFunc} → {type, cond, ops}
func _rev_need(v: Variant) -> Dictionary:
	var r: Dictionary = {"type": 0, "cond": "", "ops": 0}
	if v == null or not (v is Dictionary):
		return r
	var d: Dictionary = v as Dictionary
	if d.get("ops") != null:
		r["ops"] = d["ops"]
	if d.get("needFunc") != null:
		r["type"] = 2
		r["cond"] = d["needFunc"]
	elif d.get("need") != null and d["need"] is Array:
		r["type"] = 1
		var conds: Array = []
		for item_v in d["need"]:
			if not (item_v is Dictionary):
				continue
			var item: Dictionary = item_v as Dictionary
			var c: Dictionary = {"subtype": item.get("id"), "type": item.get("type")}
			var mn: Variant = item.get("min")
			var mx: Variant = item.get("max")
			if mn != null and mx != null and mn == mx:
				c["condition"] = "eq"
				c["value"] = mn
			elif mn != null:
				c["condition"] = "gt"
				c["value"] = mn
			elif mx != null:
				c["condition"] = "lt"
				c["value"] = mx
			conds.append(c)
		r["cond"] = JSON.stringify(conds)
	return r

## 反解析 result {addValue, func, desc} → {type, trigger}
func _rev_result(v: Variant) -> Dictionary:
	var r: Dictionary = {"type": 0, "trigger": ""}
	if v == null or not (v is Dictionary):
		return r
	var d: Dictionary = v as Dictionary
	if d.get("func") != null and d.get("func") != "":
		r["type"] = 2
		r["trigger"] = d["func"]
	elif d.get("addValue") != null and d["addValue"] is Array:
		r["type"] = 1
		var results: Array = []
		for item_v in d["addValue"]:
			if not (item_v is Dictionary):
				continue
			var item: Dictionary = item_v as Dictionary
			results.append({"type": item.get("type"), "subtype": item.get("id"), "value": item.get("value"), "ops": item.get("ops")})
		r["trigger"] = JSON.stringify(results)
	return r

## 反解析 handleEffect 输出 {addFunc/addValue, need} → {trigger_type, effect, cond, cond_ops}
## 注意此处 trigger_type 为 0-配置 1-脚本
func _rev_effect(v: Variant) -> Dictionary:
	var r: Dictionary = {"trigger_type": 0, "effect": "", "cond": "", "cond_ops": 0}
	if v == null or not (v is Dictionary):
		return r
	var d: Dictionary = v as Dictionary
	if d.get("addFunc") != null:
		r["trigger_type"] = 1
		r["effect"] = d["addFunc"]
	elif d.get("addValue") != null and d["addValue"] is Array:
		r["trigger_type"] = 0
		var items: Array = []
		for item_v in d["addValue"]:
			if not (item_v is Dictionary):
				continue
			var item: Dictionary = item_v as Dictionary
			items.append({"type": item.get("type"), "subtype": item.get("id"), "value": item.get("value"), "ops": item.get("ops", 1)})
		r["effect"] = JSON.stringify(items)
	if d.get("need") != null:
		var n: Dictionary = _rev_need(d["need"])
		r["cond"] = n["cond"]
		r["cond_ops"] = n["ops"]
	return r

## 反解析交互按钮 btns（GoodsUse/Question 共用）→ alternation data 数组
func _rev_btns(btns: Variant) -> String:
	if btns == null or not (btns is Array):
		return ""
	var out: Array = []
	for b_v in btns:
		if not (b_v is Dictionary):
			continue
		var b: Dictionary = b_v as Dictionary
		var item: Dictionary = {"name": b.get("text")}
		if b.get("visible") != null:
			var vd: Dictionary = b["visible"] as Dictionary
			item["visible"] = {"type": _need_type(vd), "value": _need_value(vd), "ops": vd.get("ops", 0)}
		if b.get("need") != null:
			var vd: Dictionary = b["need"] as Dictionary
			item["trigger_cond"] = {"type": _need_type(vd), "value": _need_value(vd), "ops": vd.get("ops", 0)}
		if b.get("success") != null and b["success"] is Dictionary:
			var sd: Dictionary = b["success"] as Dictionary
			item["trigger_succ"] = {"type": _result_type(sd), "value": _result_value(sd)}
			item["desc"] = sd.get("desc", "")
		if b.get("fail") != null and b["fail"] is Dictionary:
			var fd: Dictionary = b["fail"] as Dictionary
			item["trigger_fail"] = {"type": _result_type(fd), "value": _result_value(fd)}
			item["fail_desc"] = fd.get("desc", "")
		out.append(item)
	return JSON.stringify(out) if out.size() > 0 else ""

func _need_type(vd: Dictionary) -> int:
	if vd.get("needFunc") != null:
		return 2
	if vd.get("need") != null:
		return 1
	return 0

func _need_value(vd: Dictionary) -> Variant:
	if vd.get("needFunc") != null:
		return vd["needFunc"]
	if vd.get("need") != null:
		return JSON.stringify(vd["need"])
	return ""

func _result_type(d: Dictionary) -> int:
	if d.get("func") != null and d.get("func") != "":
		return 2
	if d.get("addValue") != null:
		return 1
	return 0

func _result_value(d: Dictionary) -> Variant:
	if d.get("func") != null and d.get("func") != "":
		return d["func"]
	if d.get("addValue") != null:
		return JSON.stringify(d["addValue"])
	return ""

# ===================== 各表反解析 =====================

func _import_table(name: String, v: Variant) -> void:
	match name:
		"Citys": _import_citys(v)
		"CityObjects": _import_city_objects(v)
		"CityWays": _import_city_ways(v)
		"Goods": _import_goods(v)
		"GoodsAction": _import_goods_action(v)
		"GoodsUse": _import_goods_use(v)
		"GoodsTagName": _import_goods_tag_name(v)
		"Property": _import_property(v)
		"PropertyAction": _import_property_action(v)
		"PropertyValue": _import_property_value(v)
		"PropertyTagName": _import_property_tag_name(v)
		"Skill": _import_skill(v)
		"SkillTagName": _import_skill_tag_name(v)
		"Slot": _import_slot(v)
		"NPC": _import_npc(v)
		"NPCCombat": _import_npc_combat(v)
		"Question": _import_question(v)
		"Story": _import_story(v)
		"Drop": _import_drop(v)
		"RandomAction": _import_random_action(v)
		"Exchange": _import_exchange(v)
		"ObjectAutoRun": _import_object_auto_run(v)
		"Pay": _import_pay(v)
		"CommonAction": _import_common_action(v)
		"CombatProperty": _import_combat_property(v)
		"MapEnter": _import_map_enter(v)
		"Navigation": _import_navigation(v)
		"OnlineFunc": _import_online_func(v)
		"SharePrize": _import_share_prize(v)
		"GameInfo": _import_game_info(v)
		"Setting": _import_setting(v)
		"customdata": _import_custom_data(v)
		"LuaExport": _import_lua_export(v)

func _import_citys(v: Variant) -> void:
	if not (v is Array):
		return
	for row_v in v:
		if not (row_v is Dictionary):
			continue
		var row: Dictionary = row_v as Dictionary
		var scene: Dictionary = {"id": row.get("id"), "name": row.get("name"), "desc": row.get("desc")}
		var en: Dictionary = _rev_need(row.get("enterNeed"))
		scene["et_cond_type"] = en["type"]; scene["enter_cond"] = en["cond"]; scene["et_cond_ops"] = en["ops"]
		var ln: Dictionary = _rev_need(row.get("leaveNeed"))
		scene["lt_cond_type"] = ln["type"]; scene["leave_cond"] = ln["cond"]; scene["lt_cond_ops"] = ln["ops"]
		var es: Dictionary = _rev_result(row.get("enterSuccess"))
		scene["et_type"] = es["type"]; scene["enter_trigger"] = es["trigger"]
		var ls: Dictionary = _rev_result(row.get("leaveSuccess"))
		scene["lt_type"] = ls["type"]; scene["leave_trigger"] = ls["trigger"]
		var ef: Dictionary = _rev_result(row.get("enterFail"))
		scene["et_fail_type"] = ef["type"]; scene["enter_trigger_fail"] = ef["trigger"]
		var lf: Dictionary = _rev_result(row.get("leaveFail"))
		scene["lt_fail_type"] = lf["type"]; scene["leave_trigger_fail"] = lf["trigger"]
		_data.add_row("scene", scene)

func _import_city_objects(v: Variant) -> void:
	if not (v is Array):
		return
	for row_v in v:
		if not (row_v is Dictionary):
			continue
		var row: Dictionary = row_v as Dictionary
		var so: Dictionary = {"sceneid": row.get("cityID"), "objid": row.get("objectID")}
		if row.get("visible") != null:
			var n: Dictionary = _rev_need(row.get("visible"))
			so["ctrl"] = JSON.stringify({"trigger": n["type"], "cond": n["cond"], "cond_ops": n["ops"]})
		_data.add_row("scene_object", so)

func _import_city_ways(v: Variant) -> void:
	if not (v is Array):
		return
	for row_v in v:
		if not (row_v is Dictionary):
			continue
		var row: Dictionary = row_v as Dictionary
		var lp: Dictionary = {"id": row.get("id"), "startpot": row.get("from"), "endpot": row.get("to"), "direct": row.get("direct")}
		var need: Dictionary = _rev_need(row.get("need"))
		lp["passcond_type"] = need["type"]; lp["passcond"] = need["cond"]; lp["passcond_ops"] = need["ops"]
		var vis: Dictionary = _rev_need(row.get("visible"))
		lp["opencond_type"] = vis["type"]; lp["opencond"] = vis["cond"]; lp["opencond_ops"] = vis["ops"]
		if row.get("failDesc") != null:
			lp["passcond_fail_desc"] = row["failDesc"]
		_data.add_row("linkpath", lp)

func _import_goods(v: Variant) -> void:
	if not (v is Array):
		return
	for row_v in v:
		if not (row_v is Dictionary):
			continue
		var row: Dictionary = row_v as Dictionary
		_data.add_row("object", {"id": row.get("id"), "name": row.get("name"), "desc": row.get("desc"), "note": row.get("note", "")})

func _import_goods_action(v: Variant) -> void:
	if not (v is Array):
		return
	for row_v in v:
		if not (row_v is Dictionary):
			continue
		var row: Dictionary = row_v as Dictionary
		var talk: Dictionary = {"id": row.get("id"), "objid": row.get("objectID"), "name": row.get("actionName"), "trigger_count": row.get("actionCount", 0)}
		var need: Dictionary = _rev_need(row.get("need"))
		talk["trigger_type"] = need["type"]; talk["condition"] = need["cond"]; talk["cond_ops"] = need["ops"]
		var vis: Dictionary = _rev_need(row.get("visible"))
		talk["visible_cond_trigger_type"] = vis["type"]; talk["visible_cond"] = vis["cond"]; talk["visible_cond_ops"] = vis["ops"]
		if row.get("success") != null and row["success"] is Dictionary:
			var sd: Dictionary = row["success"] as Dictionary
			var sr: Dictionary = _rev_result(row["success"])
			talk["succ_type"] = sr["type"]; talk["succ_trigger"] = sr["trigger"]
			talk["content"] = sd.get("desc", "")
		if row.get("fail") != null and row["fail"] is Dictionary:
			var fd: Dictionary = row["fail"] as Dictionary
			var fr: Dictionary = _rev_result(row["fail"])
			talk["fail_type"] = fr["type"]; talk["fail_trigger"] = fr["trigger"]
			talk["fail_desc"] = fd.get("desc", "")
		_data.add_row("module_talk", talk)

func _import_goods_use(v: Variant) -> void:
	if not (v is Array):
		return
	for row_v in v:
		if not (row_v is Dictionary):
			continue
		var row: Dictionary = row_v as Dictionary
		var item: Dictionary = {
			"id": row.get("id"), "name": row.get("name"), "desc": row.get("desc"),
			"typeid": row.get("tagID"), "feature_equip": row.get("equip", 0),
			"feature_destory": row.get("destory", 0), "feature_consume": row.get("consume", 0),
		}
		var eq: Dictionary = _rev_effect(row.get("equipValue"))
		item["prop_equip_trigger_type"] = eq["trigger_type"]; item["prop_equip"] = eq["effect"]
		item["cond_equip"] = eq["cond"]; item["cond_equip_ops"] = eq["cond_ops"]
		var cy: Dictionary = _rev_effect(row.get("carryValue"))
		item["prop_carry"] = cy["effect"]; item["cond_carry"] = cy["cond"]; item["cond_carry_ops"] = cy["cond_ops"]
		var cs: Dictionary = _rev_effect(row.get("consumeValue"))
		item["prop_consume"] = cs["effect"]; item["cond_consume"] = cs["cond"]; item["cond_consume_ops"] = cs["cond_ops"]
		item["alternation"] = _rev_btns(row.get("btns"))
		if row.get("slot") != null and row["slot"] is Array:
			var slots: Array = []
			for s_v in row["slot"]:
				if s_v is Dictionary:
					var s: Dictionary = (s_v as Dictionary).duplicate(true)
					s["cnt"] = s.get("slotNum")
					s.erase("slotNum")
					slots.append(s)
			item["slots"] = JSON.stringify(slots)
		_data.add_row("item", item)

func _import_goods_tag_name(v: Variant) -> void:
	if not (v is Array):
		return
	for row_v in v:
		if not (row_v is Dictionary):
			continue
		var row: Dictionary = row_v as Dictionary
		_data.add_row("item_type", {"typeid": row.get("id"), "name": row.get("name"), "priority": row.get("weight", 100), "visible": row.get("visible", 1)})

func _import_property(v: Variant) -> void:
	if not (v is Array):
		return
	for row_v in v:
		if not (row_v is Dictionary):
			continue
		var row: Dictionary = row_v as Dictionary
		var prop: Dictionary = {
			"id": row.get("id"), "typeid": row.get("tagID", 1), "name": row.get("name"),
			"priority": row.get("weight", 100), "desc": row.get("desc"),
		}
		if row.get("func") != null and row.get("func") != "":
			prop["calc"] = row["func"]
		# range
		var mn: Variant = row.get("min")
		var mx: Variant = row.get("max")
		if mn != null or mx != null:
			prop["range"] = JSON.stringify({"min": mn if mn != null else 0, "max": mx if mx != null else 2147483648})
		# 主从
		if row.get("maxProperty") != null:
			prop["master"] = 0
			prop["link_prop"] = row["maxProperty"]
		else:
			prop["master"] = 1
		_data.add_row("property", prop)

func _import_property_action(v: Variant) -> void:
	if not (v is Array):
		return
	for row_v in v:
		if not (row_v is Dictionary):
			continue
		var row: Dictionary = row_v as Dictionary
		var pid: Variant = row.get("propertyID")
		var prop: Dictionary = _data.get_property(pid)
		if prop.is_empty():
			continue
		var triggers: Array = []
		if row.get("data") is Array:
			for d_v in row["data"]:
				if not (d_v is Dictionary):
					continue
				var d: Dictionary = d_v as Dictionary
				var t: Dictionary = {"tvalue": d.get("value")}
				if d.get("success") is Dictionary:
					var sd: Dictionary = d["success"] as Dictionary
					var sr: Dictionary = _rev_result(sd)
					t["result_type"] = sr["type"]
					t["result"] = sr["trigger"]
				triggers.append(t)
		prop["trigger"] = JSON.stringify(triggers)

func _import_property_value(v: Variant) -> void:
	if not (v is Array):
		return
	for row_v in v:
		if not (row_v is Dictionary):
			continue
		var row: Dictionary = row_v as Dictionary
		var pid: Variant = row.get("id")
		var prop: Dictionary = _data.get_property(pid)
		if prop.is_empty():
			continue
		prop["dict"] = JSON.stringify({"default": row.get("desc"), "data": row.get("data", [])})

func _import_property_tag_name(v: Variant) -> void:
	if not (v is Array):
		return
	for row_v in v:
		if not (row_v is Dictionary):
			continue
		var row: Dictionary = row_v as Dictionary
		_data.add_row("property_type", {"id": row.get("id"), "name": row.get("name"), "priority": row.get("weight", 100), "visible": row.get("visible", 1)})

func _import_skill(v: Variant) -> void:
	if not (v is Array):
		return
	for row_v in v:
		if not (row_v is Dictionary):
			continue
		var row: Dictionary = row_v as Dictionary
		var skill: Dictionary = {
			"id": row.get("id"), "name": row.get("name"), "desc": row.get("desc"),
			"typeid": row.get("tagID"), "data": row.get("func", ""),
		}
		var need: Dictionary = _rev_need(row.get("need"))
		skill["equip_type"] = need["type"]; skill["equip_data"] = need["cond"]; skill["equip_cond_ops"] = need["ops"]
		if row.get("consume") != null and row["consume"] is Dictionary:
			var cd: Dictionary = row["consume"] as Dictionary
			var cr: Dictionary = _rev_result(row["consume"])
			skill["consume_type"] = cr["type"]; skill["consume_data"] = cr["trigger"]
		if row.get("slot") != null and row["slot"] is Array:
			var slots: Array = []
			for s_v in row["slot"]:
				if s_v is Dictionary:
					var s: Dictionary = (s_v as Dictionary).duplicate(true)
					s["cnt"] = s.get("slotNum")
					s.erase("slotNum")
					slots.append(s)
			skill["slots"] = JSON.stringify(slots)
		_data.add_row("skill", skill)

func _import_skill_tag_name(v: Variant) -> void:
	if not (v is Array):
		return
	for row_v in v:
		if not (row_v is Dictionary):
			continue
		var row: Dictionary = row_v as Dictionary
		_data.add_row("skill_type", {"id": row.get("id"), "name": row.get("name"), "priority": row.get("weight", 100), "visible": row.get("visible", 1)})

func _import_slot(v: Variant) -> void:
	if not (v is Array):
		return
	for row_v in v:
		if not (row_v is Dictionary):
			continue
		var row: Dictionary = row_v as Dictionary
		_data.add_row("slot", {"id": row.get("id"), "name": row.get("name"), "cnt": row.get("slotNum", 0)})

func _import_npc(v: Variant) -> void:
	if not (v is Array):
		return
	for row_v in v:
		if not (row_v is Dictionary):
			continue
		var row: Dictionary = row_v as Dictionary
		var enemy: Dictionary = {"id": row.get("id"), "name": row.get("name")}
		if row.get("func") != null and row.get("func") != "":
			enemy["type"] = 1
			enemy["script"] = row["func"]
		else:
			enemy["type"] = 0
			if row.get("property") != null:
				var props: Array = []
				if row["property"] is Array:
					for p_v in row["property"]:
						if p_v is Dictionary:
							var p: Dictionary = (p_v as Dictionary).duplicate(true)
							p["subtype"] = p.get("id")
							p.erase("id")
							props.append(p)
				enemy["property"] = JSON.stringify(props)
			if row.get("skillID") != null:
				enemy["skill"] = JSON.stringify([row["skillID"]])
		_data.add_row("enemy", enemy)

func _import_npc_combat(v: Variant) -> void:
	if not (v is Array):
		return
	for row_v in v:
		if not (row_v is Dictionary):
			continue
		var row: Dictionary = row_v as Dictionary
		var camp: Dictionary = {"id": row.get("id"), "name": row.get("name"), "desc": row.get("desc")}
		if row.get("npcList") is Array:
			camp["enemies"] = JSON.stringify(row["npcList"])
		var trigger: Dictionary = {}
		if row.get("success") != null and row["success"] is Dictionary:
			var sd: Dictionary = row["success"] as Dictionary
			var win: Dictionary = {"desc": sd.get("desc", "")}
			if sd.get("func") != null:
				win["control"] = 2; win["data"] = sd["func"]
			elif sd.get("addValue") != null:
				win["control"] = 1; win["data"] = JSON.stringify(sd["addValue"])
			trigger["win"] = win
		if row.get("fail") != null and row["fail"] is Dictionary:
			var fd: Dictionary = row["fail"] as Dictionary
			var lose: Dictionary = {"desc": fd.get("desc", "")}
			if fd.get("func") != null:
				lose["control"] = 2; lose["data"] = fd["func"]
			elif fd.get("addValue") != null:
				lose["control"] = 1; lose["data"] = JSON.stringify(fd["addValue"])
			trigger["lose"] = lose
		if not trigger.is_empty():
			camp["trigger"] = JSON.stringify(trigger)
		_data.add_row("campaign", camp)

func _import_question(v: Variant) -> void:
	if not (v is Array):
		return
	for row_v in v:
		if not (row_v is Dictionary):
			continue
		var row: Dictionary = row_v as Dictionary
		_data.add_row("alternation", {"id": row.get("id"), "name": row.get("title"), "desc": row.get("content"), "data": _rev_btns(row.get("btns"))})

func _import_story(v: Variant) -> void:
	if not (v is Array):
		return
	for row_v in v:
		if not (row_v is Dictionary):
			continue
		var row: Dictionary = row_v as Dictionary
		var story: Dictionary = {"id": row.get("id"), "dtype": 0}
		var dd: Dictionary = (row as Dictionary).duplicate(true)
		if dd.has("story") and dd["story"] is Array:
			dd["story"] = " ".join(dd["story"] as Array)
		dd.erase("id")
		story["data"] = JSON.stringify(dd)
		story["name"] = row.get("name", row.get("title", ""))
		_data.add_row("story", story)

func _import_drop(v: Variant) -> void:
	if not (v is Array):
		return
	for row_v in v:
		if not (row_v is Dictionary):
			continue
		var row: Dictionary = row_v as Dictionary
		var reward_items: Array = []
		if row.get("data") is Array:
			for item_v in row["data"]:
				if item_v is Dictionary:
					var item: Dictionary = (item_v as Dictionary).duplicate(true)
					item["subtype"] = item.get("id")
					item.erase("id")
					reward_items.append(item)
		var data: Dictionary = {"reward": reward_items, "count": row.get("selNum"), "duplicate": row.get("selType") == 1}
		_data.add_row("reward", {"id": row.get("id"), "type": row.get("type", 1), "data": JSON.stringify(data)})

func _import_random_action(v: Variant) -> void:
	if not (v is Array):
		return
	for row_v in v:
		if not (row_v is Dictionary):
			continue
		var row: Dictionary = row_v as Dictionary
		var rnd: Dictionary = {"id": row.get("id"), "name": row.get("name")}
		var need: Dictionary = _rev_need(row.get("need"))
		rnd["cond_type"] = need["type"]; rnd["cond"] = need["cond"]; rnd["cond_ops"] = need["ops"]
		if row.get("success") is Dictionary:
			var sd: Dictionary = row["success"] as Dictionary
			rnd["success_type"] = sd.get("type", 1)
			rnd["success"] = _rev_random_event(sd)
		if row.get("fail") is Dictionary:
			var fd: Dictionary = row["fail"] as Dictionary
			rnd["fail_type"] = fd.get("type", 1)
			rnd["fail"] = _rev_random_event(fd)
		_data.add_row("random", rnd)

func _rev_random_event(d: Dictionary) -> String:
	var items: Array = []
	if d.get("data") is Array:
		for item_v in d["data"]:
			if item_v is Dictionary:
				var item: Dictionary = (item_v as Dictionary).duplicate(true)
				item["subtype"] = item.get("id")
				item.erase("id")
				items.append(item)
	elif d.get("func") != null:
		return JSON.stringify({"data": d["func"]})
	var out: Dictionary = {"data": items, "count": d.get("selNum"), "duplicate": d.get("selType") == 1}
	return JSON.stringify(out)

func _import_exchange(v: Variant) -> void:
	if not (v is Array):
		return
	for row_v in v:
		if not (row_v is Dictionary):
			continue
		var row: Dictionary = row_v as Dictionary
		var trade: Dictionary = {"id": row.get("id"), "name": row.get("name"), "desc": row.get("desc"), "type": int(row.get("type", 1)) - 1}
		if row.get("buy") is Array:
			trade["tradeout"] = _rev_exchange_side(row["buy"])
		if row.get("sale") is Array:
			trade["tradein"] = _rev_exchange_side(row["sale"], true)
		_data.add_row("trade", trade)

func _rev_exchange_side(arr: Array, reverse: bool = false) -> String:
	var out: Array = []
	for row_v in arr:
		if not (row_v is Dictionary):
			continue
		var row: Dictionary = row_v as Dictionary
		var key1: String = "token"
		var key2: String = "target"
		if reverse:
			var tmp: String = key1
			key1 = key2
			key2 = tmp
		var item: Dictionary = {}
		if row.get("from") is Array:
			item[key1] = _rev_exchange_items(row["from"])
		if row.get("to") is Array:
			item[key2] = _rev_exchange_items(row["to"])
		out.append(item)
	return JSON.stringify(out)

func _rev_exchange_items(arr: Array) -> Array:
	var out: Array = []
	for item_v in arr:
		if item_v is Dictionary:
			var item: Dictionary = (item_v as Dictionary).duplicate(true)
			item["subtype"] = item.get("id")
			item.erase("id")
			out.append(item)
	return out

func _import_object_auto_run(v: Variant) -> void:
	if not (v is Array):
		return
	for row_v in v:
		if not (row_v is Dictionary):
			continue
		var row: Dictionary = row_v as Dictionary
		var gen: Dictionary = {
			"id": row.get("id"), "name": row.get("name"), "desc": row.get("desc"),
			"type": row.get("type", 1), "auto_start": row.get("autoStart", 0),
		}
		var time_val: Variant = row.get("productTime")
		var data: Dictionary = {
			"subtype": row.get("productID"), "type": row.get("goodsType"),
			"count": row.get("productCount"), "volume": row.get("countMax"), "gain": row.get("getCount"),
		}
		if time_val != null:
			data["time"] = float(time_val) / 60.0
		gen["data"] = JSON.stringify(data)
		if row.get("start") is Dictionary:
			var sd: Dictionary = row["start"] as Dictionary
			var n: Dictionary = _rev_need(sd.get("need"))
			gen["cond_open_type"] = n["type"]; gen["cond_open"] = n["cond"]; gen["cond_open_ops"] = n["ops"]
			var r: Dictionary = _rev_result_gen(sd)
			gen["trigger_open_type"] = r["type"]; gen["trigger_open"] = r["trigger"]
		if row.get("prize") is Dictionary:
			var pd: Dictionary = row["prize"] as Dictionary
			var n: Dictionary = _rev_need(pd.get("need"))
			gen["cond_get_type"] = n["type"]; gen["cond_get"] = n["cond"]; gen["cond_get_ops"] = n["ops"]
			var r: Dictionary = _rev_result_gen(pd)
			gen["trigger_get_type"] = r["type"]; gen["trigger_get"] = r["trigger"]
		_data.add_row("generator", gen)

## generator 的 trigger 反解析（addValue/addFunc 形式）
func _rev_result_gen(d: Dictionary) -> Dictionary:
	var r: Dictionary = {"type": 0, "trigger": ""}
	if d.get("addFunc") != null:
		r["type"] = 2
		r["trigger"] = d["addFunc"]
	elif d.get("addValue") != null and d["addValue"] is Array:
		r["type"] = 1
		r["trigger"] = JSON.stringify(d["addValue"])
	return r

func _import_pay(v: Variant) -> void:
	if not (v is Array):
		return
	for row_v in v:
		if not (row_v is Dictionary):
			continue
		var row: Dictionary = row_v as Dictionary
		var pay: Dictionary = {"id": row.get("id"), "name": row.get("name"), "price": row.get("price", 1), "desc": row.get("desc")}
		if row.get("addValue") != null and row["addValue"] is Array:
			pay["content"] = JSON.stringify(row["addValue"])
		_data.add_row("payment", pay)

func _import_common_action(v: Variant) -> void:
	if not (v is Array):
		return
	for row_v in v:
		if not (row_v is Dictionary):
			continue
		var row: Dictionary = row_v as Dictionary
		var logic: Dictionary = {"id": row.get("id")}
		var need: Dictionary = _rev_need(row.get("need"))
		logic["condition"] = JSON.stringify({"type": need["type"], "data": need["cond"], "ops": need["ops"]})
		var sr: Dictionary = _rev_result(row.get("success"))
		logic["success"] = JSON.stringify({"type": sr["type"], "data": sr["trigger"]})
		var fr: Dictionary = _rev_result(row.get("fail"))
		logic["fail"] = JSON.stringify({"type": fr["type"], "data": fr["trigger"]})
		_data.add_row("logic", logic)

# ---- config 类 ----

func _import_combat_property(v: Variant) -> void:
	if not (v is Array):
		return
	var items: Array = []
	for row_v in v:
		if row_v is Dictionary:
			var row: Dictionary = row_v as Dictionary
			items.append({"id": row.get("propertyID", row.get("id"))})
	_data.config_set("campaign_property", JSON.stringify(items))

func _import_map_enter(v: Variant) -> void:
	if v is Array and (v as Array).size() > 0:
		var first: Variant = (v as Array)[0]
		if first is Dictionary:
			_data.config_set("game_born_point", (first as Dictionary).get("cityID", 1))

func _import_navigation(v: Variant) -> void:
	if v is Array:
		_data.config_set("navigation", JSON.stringify(v))

func _import_online_func(v: Variant) -> void:
	if v is Array:
		for row_v in v:
			if row_v is Dictionary and (row_v as Dictionary).get("id") == 1:
				_data.config_set("multiple_script", (row_v as Dictionary).get("func"))

func _import_share_prize(v: Variant) -> void:
	if v is Array and (v as Array).size() > 0:
		var first: Variant = (v as Array)[0]
		if first is Dictionary and (first as Dictionary).get("addValue") != null:
			_data.config_set("share_reward", JSON.stringify((first as Dictionary)["addValue"]))

func _import_game_info(v: Variant) -> void:
	if not (v is Array) or (v as Array).is_empty():
		return
	var first: Variant = (v as Array)[0]
	if first is Dictionary:
		var d: Dictionary = first as Dictionary
		if d.get("name") != null:
			_data.config_set("game_title", d["name"])
		if d.get("version") != null:
			_data.config_set("game_version", d["version"])

func _import_setting(v: Variant) -> void:
	if not (v is Array):
		return
	for row_v in v:
		if not (row_v is Dictionary):
			continue
		var row: Dictionary = row_v as Dictionary
		var key: Variant = row.get("key")
		var value: Variant = row.get("value")
		match key:
			"map_moveTime":
				_data.config_set("map_move_time", int(float(value) * 1000.0) if value != null else 300)
			"map_showMoveLog":
				_data.config_set("map_move_show_log", value)
			"log_showTraceLog":
				_data.config_set("game_debug_trace_log", value)
			"goods_useEquipTab":
				_data.config_set("goods_use_equip_tab", value)

func _import_custom_data(v: Variant) -> void:
	# 导出格式为 [ {kname: value, ...} ]
	if not (v is Array) or (v as Array).is_empty():
		return
	var first: Variant = (v as Array)[0]
	if not (first is Dictionary):
		return
	var d: Dictionary = first as Dictionary
	for k in d:
		var value: Variant = d[k]
		var is_json: bool = value is Dictionary or value is Array
		_data.add_row("custom_data", {
			"kname": k, "name": k,
			"type": 1 if is_json else 0,
			"data": JSON.stringify(value) if is_json else str(value),
		})

func _import_lua_export(v: Variant) -> void:
	if not (v is Array):
		return
	for row_v in v:
		if not (row_v is Dictionary):
			continue
		var row: Dictionary = row_v as Dictionary
		_data.add_row("script_pluggin", {"name": "pluggin_" + str(row.get("id")), "data": row.get("func", "")})
