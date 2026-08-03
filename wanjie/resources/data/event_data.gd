## 事件系统数据模型
## 对应GDD §3.3 事件系统
class_name EventSystemData
extends Resource

## 剧情事件列表
@export var story_events: Array[Dictionary] = []
# 每个event: {id, name, description, trigger_type, prerequisite, delay,
#   conditions: [{type, check}], choices: [{id, text, consequences: [{target, effect}]}],
#   branches: [{condition, next_event}]}

## 随机事件列表
@export var random_events: Array[Dictionary] = []
# 每个event: {id, name, trigger_type, probability, cooldown,
#   weight_table: [{event, weight, conditions}], scaling: {type, formula}}

## 事件链定义
@export var event_chains: Array[Dictionary] = []
# 每个chain: {id, name, start_event, description, nodes: [{event_id, x, y}], links: [{from, to}]}

## 全局触发条件池
@export var condition_pool: Array[Dictionary] = []

## 每个事件的蓝图画布数据: event_id -> BlueprintGraph(Dictionary)
@export var blueprint_graphs: Dictionary = {}

## 添加一个剧情事件
func add_story_event(event_id: String, event_name: String, desc: String = "") -> Dictionary:
	var event := {
		"id": event_id,
		"name": event_name,
		"description": desc,
		"trigger_type": "chain",
		"prerequisite": "",
		"delay": "",
		"conditions": [],
		"choices": [],
		"branches": [],
		"is_active": true
	}
	story_events.append(event)
	return event

## 为事件添加选择
func add_choice(event_id: String, choice_id: String, choice_text: String, consequences: Array = []) -> void:
	for e in story_events:
		if e["id"] == event_id:
			e["choices"].append({
				"id": choice_id,
				"text": choice_text,
				"consequences": consequences
			})
			return

## 为事件添加触发条件
func add_condition(event_id: String, cond_type: String, check_expr: String) -> void:
	for e in story_events:
		if e["id"] == event_id:
			e["conditions"].append({"type": cond_type, "check": check_expr})
			return

## 添加一个随机事件
func add_random_event(event_id: String, event_name: String, probability: float = 0.05) -> void:
	random_events.append({
		"id": event_id,
		"name": event_name,
		"trigger_type": "random",
		"probability": probability,
		"cooldown": "3d",
		"weight_table": [],
		"scaling": {"type": "player_level", "formula": "base * (1 + level * 0.1)"},
		"is_active": true
	})

## 添加事件链
func add_event_chain(chain_id: String, chain_name: String, start_event_id: String) -> void:
	event_chains.append({
		"id": chain_id,
		"name": chain_name,
		"start_event": start_event_id,
		"description": "",
		"nodes": [],
		"links": []
	})

## 根据ID获取剧情事件
func get_story_event(event_id: String) -> Dictionary:
	for e in story_events:
		if e["id"] == event_id:
			return e
	return {}

## 获取所有事件ID列表
func get_all_event_ids() -> Array[String]:
	var ids: Array[String] = []
	for e in story_events:
		ids.append(e["id"])
	return ids

## 检查事件是否有前置事件依赖
func has_prerequisite(event_id: String) -> bool:
	for e in story_events:
		if e["id"] == event_id:
			return e.get("prerequisite", "") != ""
	return false
