## 世界观数据模型
## 对应GDD §3.2 世界观设定系统
class_name WorldviewData
extends Resource

## 背景故事文本
@export var background_story: String = ""

## 世界类型（奇幻世界/科幻世界/历史架空/现代都市/末日废土/蒸汽朋克/自定义）
@export var world_type: String = "奇幻世界"

## 时代定义列表
@export var era_definitions: Array[Dictionary] = []
# 每个era: {era_name, start_year, end_year, description, key_events}

## 历史时间线
@export var timeline: Array[Dictionary] = []
# 每个entry: {year, event, impact}

## 知识条目（可被玩家发现的背景信息）
@export var lore_entries: Array[Dictionary] = []
# 每个entry: {id, title, content, discovery_condition}

## 世界规则
@export var world_rules: Array[Dictionary] = []
# 每个rule: {category, key, value, description}
# category: physics/magic/life/social/information

## 势力设定
@export var factions: Array[Dictionary] = []
# 每个faction: {id, name, description, power_level, territory, population,
#   governance_type, succession, primary_income, trade_goods, tax_rate,
#   total_forces, special_units, expansion_tendency, aggression_level}

## 势力间关系
@export var faction_relationships: Array[Dictionary] = []
# 每个relationship: {from_id, to_id, type, intensity}
# type: alliance/rivalry/neutral/war/trade

## 地理定义
@export var geography: Dictionary = {}
# {regions: [{id, name, description, climate, resources, connections}]}

## 添加一个时代
func add_era(era_name: String, start_year: int, end_year: int, desc: String = "") -> void:
	era_definitions.append({
		"era_name": era_name,
		"start_year": start_year,
		"end_year": end_year,
		"description": desc,
		"key_events": []
	})

## 添加一条时间线
func add_timeline_entry(year: int, event: String, impact: String = "") -> void:
	timeline.append({"year": year, "event": event, "impact": impact})

## 添加一条世界规则
func add_rule(category: String, key: String, value: String, desc: String = "") -> void:
	world_rules.append({"category": category, "key": key, "value": value, "description": desc})

## 添加一个势力
func add_faction(faction_id: String, faction_name: String, desc: String = "", power: int = 50) -> void:
	factions.append({
		"id": faction_id,
		"name": faction_name,
		"description": desc,
		"power_level": power,
		"territory": [],
		"population": 10000,
		"governance_type": "council",
		"succession": "election",
		"primary_income": "trade",
		"trade_goods": [],
		"tax_rate": 0.1,
		"total_forces": 1000,
		"special_units": [],
		"expansion_tendency": 0.5,
		"aggression_level": 0.5,
		"diplomacy_preference": "balanced"
	})

## 获取势力名称
func get_faction_name(faction_id: String) -> String:
	for f in factions:
		if f["id"] == faction_id:
			return f["name"]
	return faction_id
