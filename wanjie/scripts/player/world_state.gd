## 世界状态管理器
## 管理剧本运行时的世界状态
extends RefCounted

## 游戏时间
var game_time: Dictionary = {"year": 1, "month": 1, "day": 1, "hour": 8, "minute": 0}
## 全局世界变量
var world_variables: Dictionary = {}
## 势力状态 {faction_id: {power_level, territory, relationships, treasury}}
var faction_states: Dictionary = {}
## 活跃效果 {effect_id: {remaining_duration, data}}
var active_effects: Array[Dictionary] = []
## 已探索区域
var explored_regions: Array[String] = []

## 从存档数据初始化
func load_from_dict(data: Dictionary) -> void:
	game_time = data.get("game_time", {"year": 1, "month": 1, "day": 1, "hour": 8, "minute": 0})
	world_variables = data.get("world_variables", {})
	faction_states = data.get("faction_states", {})
	var effects: Array = data.get("active_effects", [])
	active_effects.assign(effects.map(func(e): return e if e is Dictionary else {}))
	explored_regions.assign(Array(data.get("explored_regions", []), TYPE_STRING, "", null))

## 序列化为字典
func to_dict() -> Dictionary:
	return {
		"game_time": game_time,
		"world_variables": world_variables,
		"faction_states": faction_states,
		"active_effects": active_effects,
		"explored_regions": explored_regions
	}

## 推进游戏时间
func advance_time(hours: int = 1) -> void:
	game_time["minute"] += hours * 60
	while game_time["minute"] >= 60:
		game_time["minute"] -= 60
		game_time["hour"] += 1
	while game_time["hour"] >= 24:
		game_time["hour"] -= 24
		game_time["day"] += 1
	while game_time["day"] > 30:
		game_time["day"] -= 30
		game_time["month"] += 1
	while game_time["month"] > 12:
		game_time["month"] -= 12
		game_time["year"] += 1

## 设置世界变量
func set_variable(key: String, value: Variant) -> void:
	world_variables[key] = value

## 获取世界变量
func get_variable(key: String, default_value: Variant = false) -> Variant:
	return world_variables.get(key, default_value)

## 初始化势力状态
func initialize_factions(worldview: WorldviewData) -> void:
	if worldview == null:
		return
	for f in worldview.factions:
		var fid: String = f.get("id", "")
		if not faction_states.has(fid):
			faction_states[fid] = {
				"power_level": f.get("power_level", 50),
				"territory": f.get("territory", []),
				"treasury": 10000,
				"relationships": {}
			}
	# 初始化关系
	for rel in worldview.faction_relationships:
		var from_id: String = rel.get("from_id", "")
		var to_id: String = rel.get("to_id", "")
		var intensity: float = float(rel.get("intensity", 0.0))
		if faction_states.has(from_id):
			faction_states[from_id]["relationships"][to_id] = intensity
		if faction_states.has(to_id):
			faction_states[to_id]["relationships"][from_id] = intensity

## 修改势力关系
func modify_faction_relationship(faction_a: String, faction_b: String, delta: float) -> void:
	if faction_states.has(faction_a):
		var rels: Dictionary = faction_states[faction_a]["relationships"]
		rels[faction_b] = rels.get(faction_b, 0.0) + delta
	if faction_states.has(faction_b):
		var rels: Dictionary = faction_states[faction_b]["relationships"]
		rels[faction_a] = rels.get(faction_a, 0.0) + delta

## 获取势力关系值
func get_faction_relationship(faction_a: String, faction_b: String) -> float:
	if faction_states.has(faction_a):
		return faction_states[faction_a]["relationships"].get(faction_b, 0.0)
	return 0.0

## 添加活跃效果
func add_effect(effect_id: String, duration: int, data: Dictionary = {}) -> void:
	active_effects.append({"id": effect_id, "remaining": duration, "data": data})

## 处理效果衰减（每时间单位调用）
func tick_effects() -> Array[String]:
	var expired: Array[String] = []
	for effect in active_effects:
		effect["remaining"] -= 1
		if effect["remaining"] <= 0:
			expired.append(effect["id"])
	# 移除过期效果
	active_effects = active_effects.filter(func(e): return e["remaining"] > 0)
	return expired

## 获取游戏时间显示文本
func get_time_display() -> String:
	return "第%d年 %d月 %d日 %d:00" % [
		game_time["year"], game_time["month"], game_time["day"], game_time["hour"]
	]

## 当前天数（1-30 循环）
func get_current_day() -> int:
	return int(game_time.get("day", 1))

## 当前小时（0-23）
func get_current_hour() -> int:
	return int(game_time.get("hour", 8))

## 时段名称（早晨/白天/傍晚/夜晚）
func get_period_name() -> String:
	var h := get_current_hour()
	if h >= 5 and h < 9:
		return "清晨"
	if h >= 9 and h < 17:
		return "白天"
	if h >= 17 and h < 20:
		return "傍晚"
	return "夜晚"
