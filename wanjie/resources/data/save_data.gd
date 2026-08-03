## 存档数据模型
## 对应GDD §5 存档与数据管理系统
class_name SaveData
extends Resource

## 存档元数据
@export var save_id: String = ""
@export var script_id: String = ""
@export var script_version: String = "1.0.0"
@export var slot_index: int = 0
@export var is_autosave: bool = false
@export var saved_at: String = ""  # ISO格式时间戳
@export var play_time_seconds: float = 0.0

## 玩家角色状态
@export var player_state: Dictionary = {}
# {name, level, experience, attributes: {}, skills: {}, growth_path, current_stage,
#  inventory: {gold, items: []}, location: {region, coordinates},
#  status_effects: [], causal_marks: []}

## 世界状态
@export var world_state: Dictionary = {}
# {game_time: {year, month, day, hour, minute}, world_variables: {},
#  faction_states: {}, active_effects: []}

## 事件历史
@export var event_history: Dictionary = {}
# {events_triggered: [], choices_history: [], branch_points: []}

## 经济状态
@export var economy_state: Dictionary = {}
# {currencies: {}, resources: {}, market_prices: {}}

## 游戏进度 (0.0 - 1.0)
@export var progress: float = 0.0

## 获取存档显示信息
func get_display_info() -> Dictionary:
	var info := {}
	info["player_name"] = player_state.get("name", "未知")
	info["level"] = player_state.get("level", 1)
	info["play_time"] = _format_time(play_time_seconds)
	info["saved_at"] = saved_at
	info["progress"] = progress
	info["is_autosave"] = is_autosave
	return info

## 格式化时间
func _format_time(seconds: float) -> String:
	var total_seconds := int(seconds)
	var h := int(total_seconds / 3600.0)
	var m := int((total_seconds % 3600) / 60.0)
	var s := total_seconds % 60
	return "%02d:%02d:%02d" % [h, m, s]

## 获取游戏内时间显示
func get_game_time_display() -> String:
	var gt: Dictionary = world_state.get("game_time", {})
	if gt.is_empty():
		return "未知"
	return "第%d年 %d月 %d日 %d:00" % [
		gt.get("year", 1),
		gt.get("month", 1),
		gt.get("day", 1),
		gt.get("hour", 0)
	]

## 创建新的存档数据
static func create_new(script_id_val: String, slot: int, autosave: bool = false) -> SaveData:
	var sd := SaveData.new()
	sd.save_id = "save_%s_%d_%d" % [script_id_val, slot, int(Time.get_unix_time_from_system())]
	sd.script_id = script_id_val
	sd.slot_index = slot
	sd.is_autosave = autosave
	sd.saved_at = Time.get_datetime_string_from_system()
	sd.player_state = {
		"name": "旅者",
		"level": 1,
		"experience": 0,
		"attributes": {"strength": 10, "agility": 10, "intelligence": 10, "charisma": 10},
		"skills": {},
		"growth_path": "",
		"current_stage": 0,
		"inventory": {"gold": 100, "items": []},
		"location": {"region": "start", "coordinates": [0, 0]},
		"status_effects": [],
		"causal_marks": []
	}
	sd.world_state = {
		"game_time": {"year": 1, "month": 1, "day": 1, "hour": 8, "minute": 0},
		"world_variables": {},
		"faction_states": {},
		"active_effects": []
	}
	sd.event_history = {
		"events_triggered": [],
		"choices_history": [],
		"branch_points": []
	}
	sd.economy_state = {
		"currencies": {},
		"resources": {},
		"market_prices": {}
	}
	return sd
