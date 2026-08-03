## MUD编辑器 - 内存数据层（对应 ME app/libs/gamedata.lua）
## 用 GDScript 内存 Dictionary 模拟 SQLite 存储（不引入二进制 SQLite 依赖）。
## 存储结构: _tables = {表名: Array[Dictionary]}，每行是带全部字段的 Dictionary。
## 提供 gamedata.lua 的 CRUD 方法与业务规则（唯一约束/级联删除/双向路径等）。
class_name MudData
extends RefCounted

## 单表数据变化信号
signal table_changed(table_name: String)
## 整体数据变化信号（加载/清空/导入）
signal data_reset()

## 内部模式版本号
const SCHEMA_VERSION: int = MudSchemaInternal.SCHEMA_VERSION

## {表名: Array[Dictionary]}
var _tables: Dictionary = {}

func _init() -> void:
	clear_all(false)

# ===================== 核心存储 =====================

## 清空全部表（重建空表结构）
func clear_all(emit_signal: bool = true) -> void:
	_tables.clear()
	for t in MudSchemaInternal.TABLE_ORDER:
		_tables[t] = []
	if emit_signal:
		data_reset.emit()

## 清空单表所有行（保留表结构）
func clear_table(table_name: String) -> void:
	if _tables.has(table_name):
		_tables[table_name] = []
		table_changed.emit(table_name)

## 获取整张表（Array[Dictionary]），表不存在则返回空数组
func get_table(table_name: String) -> Array:
	if _tables.has(table_name):
		var v: Variant = _tables[table_name]
		if v is Array:
			return v as Array
	return []

## 获取表中行数
func get_count(table_name: String) -> int:
	return get_table(table_name).size()

## 按 id 获取单行（找不到返回空 Dictionary）
func get_row_by_id(table_name: String, id: Variant) -> Dictionary:
	for row in get_table(table_name):
		if row is Dictionary and (row as Dictionary).get("id") == id:
			return row as Dictionary
	return {}

## 按字段值筛选行
func rows_where(table_name: String, field: String, value: Variant) -> Array:
	var out: Array = []
	for row in get_table(table_name):
		if row is Dictionary and (row as Dictionary).get(field) == value:
			out.append(row)
	return out

## 计算下一个自增 id（现有最大 id + 1）
func next_id(table_name: String) -> int:
	var max_id: int = 0
	for row in get_table(table_name):
		if row is Dictionary:
			var v: Variant = (row as Dictionary).get("id")
			if v is int:
				max_id = maxi(max_id, v as int)
			elif v is float:
				max_id = maxi(max_id, int(v as float))
	return max_id + 1

## 规范化一行：补齐缺失字段为默认值
func _normalize_row(table_name: String, data: Dictionary) -> Dictionary:
	var row: Dictionary = MudSchemaInternal.create_default_entry(table_name)
	for k in data:
		row[k] = data[k]
	return row

## 通用新增（自动分配 id，除非 data 已指定）
## 返回插入后的行；若违反唯一约束返回空 Dictionary
func add_row(table_name: String, data: Dictionary) -> Dictionary:
	if not MudSchemaInternal.has_table(table_name):
		return {}
	var row: Dictionary = _normalize_row(table_name, data)
	# 分配 id（仅当表有 id 字段且未指定有效 id）
	if MudSchemaInternal.get_field_names(table_name).has("id"):
		var cur_id: Variant = row.get("id")
		if cur_id == null or cur_id == 0 or not (cur_id is int or cur_id is float):
			row["id"] = next_id(table_name)
		else:
			row["id"] = int(cur_id)
	# 唯一约束检查
	var conflict: Dictionary = MudSchemaInternal.find_unique_conflict(table_name, get_table(table_name), row)
	if not conflict.is_empty():
		return {}
	get_table(table_name).append(row)
	table_changed.emit(table_name)
	return row

## 通用更新（按 id 合并字段）
func update_row(table_name: String, id: Variant, data: Dictionary) -> bool:
	var rows: Array = get_table(table_name)
	for i in rows.size():
		var row: Variant = rows[i]
		if row is Dictionary and (row as Dictionary).get("id") == id:
			var merged: Dictionary = (row as Dictionary).duplicate(true)
			for k in data:
				if k == "id":
					continue
				merged[k] = data[k]
			# 唯一约束检查（排除自身）
			var conflict: Dictionary = MudSchemaInternal.find_unique_conflict(table_name, rows, merged, id)
			if not conflict.is_empty():
				return false
			rows[i] = merged
			table_changed.emit(table_name)
			return true
	return false

## 通用删除（按 id）
func delete_row(table_name: String, id: Variant) -> bool:
	var rows: Array = get_table(table_name)
	for i in rows.size():
		var row: Variant = rows[i]
		if row is Dictionary and (row as Dictionary).get("id") == id:
			rows.remove_at(i)
			table_changed.emit(table_name)
			return true
	return false

## 删除满足 field==value 的所有行，返回删除数量
func delete_rows_where(table_name: String, field: String, value: Variant) -> int:
	var rows: Array = get_table(table_name)
	var removed: int = 0
	var i: int = rows.size() - 1
	while i >= 0:
		var row: Variant = rows[i]
		if row is Dictionary and (row as Dictionary).get(field) == value:
			rows.remove_at(i)
			removed += 1
		i -= 1
	if removed > 0:
		table_changed.emit(table_name)
	return removed

# ===================== config 键值 =====================

## 读取配置值（对应 configGet），不存在返回 default_val
func config_get(name: String, default_val: Variant = null) -> Variant:
	for row in get_table("config"):
		if row is Dictionary and (row as Dictionary).get("name") == name:
			return (row as Dictionary).get("value", default_val)
	return default_val

## 写入配置值（对应 configSet，存在则更新，不存在则插入）
func config_set(name: String, value: Variant) -> void:
	var rows: Array = get_table("config")
	for i in rows.size():
		var row: Variant = rows[i]
		if row is Dictionary and (row as Dictionary).get("name") == name:
			(row as Dictionary)["value"] = value
			table_changed.emit("config")
			return
	rows.append({"name": name, "value": value})
	table_changed.emit("config")

# ===================== 场景 scene =====================

func add_scene(data: Dictionary) -> Dictionary:
	return add_row("scene", data)

func get_all_scene() -> Array:
	return get_table("scene")

func get_scene(id: Variant) -> Dictionary:
	return get_row_by_id("scene", id)

func update_scene(id: Variant, data: Dictionary) -> bool:
	return update_row("scene", id, data)

## 删除场景并级联删除相关 linkpath 与 scene_object（对应 deleteSceneRelative）
func del_scene(id: Variant) -> bool:
	var ok: bool = delete_row("scene", id)
	if ok:
		# 级联：删除起点或终点为该场景的路径
		var paths: Array = get_table("linkpath")
		var i: int = paths.size() - 1
		while i >= 0:
			var row: Variant = paths[i]
			if row is Dictionary:
				var r: Dictionary = row as Dictionary
				if r.get("startpot") == id or r.get("endpot") == id:
					paths.remove_at(i)
			i -= 1
		# 级联：删除该场景下的场景对象
		delete_rows_where("scene_object", "sceneid", id)
		table_changed.emit("linkpath")
	return ok

# ===================== 地图 map =====================

func add_map(data: Dictionary) -> Dictionary:
	return add_row("map", data)

func get_map(id: Variant) -> Dictionary:
	return get_row_by_id("map", id)

func get_all_map() -> Array:
	return get_table("map")

func delete_map(id: Variant) -> bool:
	return delete_row("map", id)

# ===================== 路径 linkpath =====================

## 连接两个场景（对应 linkScene）。bidirectional=true 时同时建立反向路径。
## direct 为 startpot->endpot 的方向；反向路径方向取反。
func link_scene(startpot: Variant, endpot: Variant, direct: String, bidirectional: bool = true) -> Dictionary:
	var row: Dictionary = add_row("linkpath", {"startpot": startpot, "endpot": endpot, "direct": direct})
	if bidirectional and not row.is_empty():
		var rev: String = reverse_direction(direct)
		add_row("linkpath", {"startpot": endpot, "endpot": startpot, "direct": rev})
	return row

## 方向取反
static func reverse_direction(direct: String) -> String:
	match direct:
		"east": return "west"
		"west": return "east"
		"south": return "north"
		"north": return "south"
		"southeast": return "northwest"
		"northwest": return "southeast"
		"southwest": return "northeast"
		"northeast": return "southwest"
		_: return direct

func del_link_path(id: Variant) -> bool:
	return delete_row("linkpath", id)

func update_link_path(id: Variant, data: Dictionary) -> bool:
	return update_row("linkpath", id, data)

func get_link_path(id: Variant) -> Dictionary:
	return get_row_by_id("linkpath", id)

func get_all_link_path() -> Array:
	return get_table("linkpath")

# ===================== 对象 object =====================

func add_object(data: Dictionary) -> Dictionary:
	return add_row("object", data)

func get_all_object() -> Array:
	return get_table("object")

func get_object(id: Variant) -> Dictionary:
	return get_row_by_id("object", id)

func update_object(id: Variant, data: Dictionary) -> bool:
	return update_row("object", id, data)

func delete_object(id: Variant) -> bool:
	var ok: bool = delete_row("object", id)
	if ok:
		# 级联：删除该对象的所有场景绑定
		delete_rows_where("scene_object", "objid", id)
	return ok

# ===================== 场景对象 scene_object =====================

## 把对象加入场景（对应 addObject2Scene）。同一场景同一对象只允许一次（唯一索引）。
func add_object_to_scene(sceneid: Variant, objid: Variant, ctrl: String = "") -> Dictionary:
	return add_row("scene_object", {"sceneid": sceneid, "objid": objid, "ctrl": ctrl})

## 从场景移除对象绑定
func del_object_from_scene(sceneid: Variant, objid: Variant) -> bool:
	var rows: Array = get_table("scene_object")
	for i in rows.size():
		var row: Variant = rows[i]
		if row is Dictionary:
			var r: Dictionary = row as Dictionary
			if r.get("sceneid") == sceneid and r.get("objid") == objid:
				rows.remove_at(i)
				table_changed.emit("scene_object")
				return true
	return false

## 获取场景内全部对象绑定
func get_objects_by_scene(sceneid: Variant) -> Array:
	return rows_where("scene_object", "sceneid", sceneid)

func update_object_in_scene(id: Variant, data: Dictionary) -> bool:
	return update_row("scene_object", id, data)

# ===================== 交谈 module_talk =====================

func module_talk_add(data: Dictionary) -> Dictionary:
	return add_row("module_talk", data)

func module_talk_delete(id: Variant) -> bool:
	return delete_row("module_talk", id)

func module_talk_query(id: Variant) -> Dictionary:
	return get_row_by_id("module_talk", id)

func module_talk_query_with_objid(objid: Variant) -> Array:
	return rows_where("module_talk", "objid", objid)

func module_talk_update(id: Variant, data: Dictionary) -> bool:
	return update_row("module_talk", id, data)

# ===================== 属性 property =====================

func add_property(data: Dictionary) -> Dictionary:
	return add_row("property", data)

func get_property(id: Variant) -> Dictionary:
	return get_row_by_id("property", id)

## 按名称查属性（property.name 唯一索引）
func get_property_by_name(pname: String) -> Dictionary:
	var rows: Array = rows_where("property", "name", pname)
	if rows.size() > 0 and rows[0] is Dictionary:
		return rows[0] as Dictionary
	return {}

func delete_property(id: Variant) -> bool:
	return delete_row("property", id)

func update_property(id: Variant, data: Dictionary) -> bool:
	return update_row("property", id, data)

func add_property_type(data: Dictionary) -> Dictionary:
	return add_row("property_type", data)

func get_property_type(id: Variant) -> Dictionary:
	return get_row_by_id("property_type", id)

func delete_property_type(id: Variant) -> bool:
	return delete_row("property_type", id)

# ===================== 物品 item =====================

func add_item(data: Dictionary) -> Dictionary:
	return add_row("item", data)

func get_item(id: Variant = null) -> Variant:
	if id == null:
		return get_table("item")
	return get_row_by_id("item", id)

func delete_item(id: Variant) -> bool:
	return delete_row("item", id)

func update_item(id: Variant, data: Dictionary) -> bool:
	return update_row("item", id, data)

func add_item_type(data: Dictionary) -> Dictionary:
	return add_row("item_type", data)

func get_item_type(id: Variant = null) -> Variant:
	if id == null:
		return get_table("item_type")
	return get_row_by_id("item_type", id)

func delete_item_type(id: Variant) -> bool:
	return delete_row("item_type", id)

# ===================== 技能 skill =====================

func add_skill(data: Dictionary) -> Dictionary:
	return add_row("skill", data)

func get_skill(id: Variant = null) -> Variant:
	if id == null:
		return get_table("skill")
	return get_row_by_id("skill", id)

func delete_skill(id: Variant) -> bool:
	return delete_row("skill", id)

func add_skill_type(data: Dictionary) -> Dictionary:
	return add_row("skill_type", data)

func get_skill_type(id: Variant = null) -> Variant:
	if id == null:
		return get_table("skill_type")
	return get_row_by_id("skill_type", id)

func delete_skill_type(id: Variant) -> bool:
	return delete_row("skill_type", id)

# ===================== 通用 add/get/del（其余各表） =====================

func add_alternation(data: Dictionary) -> Dictionary: return add_row("alternation", data)
func get_alternation(id: Variant = null) -> Variant: return _g("alternation", id)
func delete_alternation(id: Variant) -> bool: return delete_row("alternation", id)

func add_reward(data: Dictionary) -> Dictionary: return add_row("reward", data)
func get_reward(id: Variant = null) -> Variant: return _g("reward", id)
func delete_reward(id: Variant) -> bool: return delete_row("reward", id)

func add_story(data: Dictionary) -> Dictionary: return add_row("story", data)
func get_story(id: Variant = null) -> Variant: return _g("story", id)
func delete_story(id: Variant) -> bool: return delete_row("story", id)

func add_enemy(data: Dictionary) -> Dictionary: return add_row("enemy", data)
func get_enemy(id: Variant = null) -> Variant: return _g("enemy", id)
func delete_enemy(id: Variant) -> bool: return delete_row("enemy", id)

func add_enemy_template(data: Dictionary) -> Dictionary: return add_row("enemy_template", data)
func get_enemy_template(id: Variant = null) -> Variant: return _g("enemy_template", id)
func delete_enemy_template(id: Variant) -> bool: return delete_row("enemy_template", id)

func add_campaign(data: Dictionary) -> Dictionary: return add_row("campaign", data)
func get_campaign(id: Variant = null) -> Variant: return _g("campaign", id)
func delete_campaign(id: Variant) -> bool: return delete_row("campaign", id)

func add_slot(data: Dictionary) -> Dictionary: return add_row("slot", data)
func get_slot(id: Variant = null) -> Variant: return _g("slot", id)
func delete_slot(id: Variant) -> bool: return delete_row("slot", id)

func add_slot_template(data: Dictionary) -> Dictionary: return add_row("slot_template", data)
func get_slot_template(id: Variant = null) -> Variant: return _g("slot_template", id)
func delete_slot_template(id: Variant) -> bool: return delete_row("slot_template", id)

func add_random(data: Dictionary) -> Dictionary: return add_row("random", data)
func get_random(id: Variant = null) -> Variant: return _g("random", id)
func delete_random(id: Variant) -> bool: return delete_row("random", id)

func add_trade(data: Dictionary) -> Dictionary: return add_row("trade", data)
func get_trade(id: Variant = null) -> Variant: return _g("trade", id)
func delete_trade(id: Variant) -> bool: return delete_row("trade", id)

func add_generator(data: Dictionary) -> Dictionary: return add_row("generator", data)
func get_generator(id: Variant = null) -> Variant: return _g("generator", id)
func delete_generator(id: Variant) -> bool: return delete_row("generator", id)

func add_payment(data: Dictionary) -> Dictionary: return add_row("payment", data)
func get_payment(id: Variant = null) -> Variant: return _g("payment", id)
func delete_payment(id: Variant) -> bool: return delete_row("payment", id)

func add_logic(data: Dictionary) -> Dictionary: return add_row("logic", data)
func get_logic(id: Variant = null) -> Variant: return _g("logic", id)
func delete_logic(id: Variant) -> bool: return delete_row("logic", id)

func add_custom_data(data: Dictionary) -> Dictionary: return add_row("custom_data", data)
func get_custom_data(id: Variant = null) -> Variant: return _g("custom_data", id)
func delete_custom_data(id: Variant) -> bool: return delete_row("custom_data", id)

func add_script_pluggin(data: Dictionary) -> Dictionary: return add_row("script_pluggin", data)
func get_script_pluggin(id: Variant = null) -> Variant: return _g("script_pluggin", id)
func delete_script_pluggin(id: Variant) -> bool: return delete_row("script_pluggin", id)

## 内部：id==null 返回整表，否则按 id 查单行
func _g(table_name: String, id: Variant) -> Variant:
	if id == null:
		return get_table(table_name)
	return get_row_by_id(table_name, id)

# ===================== 序列化 =====================

## 导出为可存入 metadata 的 Dictionary（新格式，带版本标记）
func to_dict() -> Dictionary:
	var tables_out: Dictionary = {}
	for t in MudSchemaInternal.TABLE_ORDER:
		var rows: Array = get_table(t)
		var copy: Array = []
		for row in rows:
			if row is Dictionary:
				copy.append((row as Dictionary).duplicate(true))
		tables_out[t] = copy
	return {
		"_schema_version": SCHEMA_VERSION,
		"tables": tables_out,
	}

## 从 Dictionary 加载（新格式 {"_schema_version":2,"tables":{...}}）
## 也兼容直接传 {表名: Array} 的裸表结构。
func from_dict(d: Dictionary) -> void:
	clear_all(false)
	if not (d is Dictionary):
		data_reset.emit()
		return
	var dd: Dictionary = d as Dictionary
	var tables_src: Dictionary = {}
	if dd.has("tables") and dd["tables"] is Dictionary:
		tables_src = dd["tables"] as Dictionary
	else:
		# 裸表结构
		for k in dd:
			if k == "_schema_version":
				continue
			if dd[k] is Array:
				tables_src[k] = dd[k]
	for t in MudSchemaInternal.TABLE_ORDER:
		if tables_src.has(t) and tables_src[t] is Array:
			var src: Array = tables_src[t] as Array
			var rows: Array = get_table(t)
			for row in src:
				if row is Dictionary:
					rows.append(_normalize_row(t, row as Dictionary))
	data_reset.emit()

## 是否为新版内部格式（供编辑器判断是否需要走导入转换）
static func is_internal_format(d: Variant) -> bool:
	if d is Dictionary:
		var dd: Dictionary = d as Dictionary
		if dd.has("_schema_version"):
			return true
		# 裸表结构：只要有一个键是内部表名即认为是内部格式
		for k in dd:
			if MudSchemaInternal.has_table(k as String):
				return true
	return false
