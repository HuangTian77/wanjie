## 任务系统数据模型
## 对应蓝图节点体系 §3.8 任务系统
class_name QuestSystemData
extends Resource

## 任务定义
@export var quests: Array[Dictionary] = []
# 每个quest: {id, name, description, type, prerequisites, level_req,
#   objectives: [{description, target_type, target_id, required_count, current_count}],
#   rewards: {exp, gold, items: [{id, qty}], unlock_quests: []},
#   fail_condition: {}, time_limit, repeatable}
# type: main / side / daily / hidden

## 任务链
@export var quest_chains: Array[Dictionary] = []
# 每个chain: {id, name, quests: [quest_id], description}

## 任务类型常量
const TYPE_MAIN := "main"
const TYPE_SIDE := "side"
const TYPE_DAILY := "daily"
const TYPE_HIDDEN := "hidden"

## 添加任务
func add_quest(quest_id: String, quest_name: String, quest_type: String = "main", desc: String = "") -> Dictionary:
	var quest := {
		"id": quest_id,
		"name": quest_name,
		"description": desc,
		"type": quest_type,
		"prerequisites": [],
		"level_req": 1,
		"objectives": [],
		"rewards": {"exp": 0, "gold": 0, "items": [], "unlock_quests": []},
		"fail_condition": {},
		"time_limit": -1,
		"repeatable": false,
	}
	quests.append(quest)
	return quest

## 为任务添加目标
func add_objective(quest_id: String, desc: String, target_type: String = "kill",
		target_id: String = "", required_count: int = 1) -> void:
	for q in quests:
		if q["id"] == quest_id:
			q["objectives"].append({
				"description": desc,
				"target_type": target_type,
				"target_id": target_id,
				"required_count": required_count,
				"current_count": 0,
			})
			return

## 设置任务奖励
func set_rewards(quest_id: String, exp: int = 0, gold: int = 0,
		items: Array = [], unlock_quests: Array = []) -> void:
	for q in quests:
		if q["id"] == quest_id:
			q["rewards"] = {
				"exp": exp,
				"gold": gold,
				"items": items,
				"unlock_quests": unlock_quests,
			}
			return

## 添加任务链
func add_quest_chain(chain_id: String, chain_name: String, quest_ids: Array = [], desc: String = "") -> void:
	quest_chains.append({
		"id": chain_id,
		"name": chain_name,
		"quests": quest_ids,
		"description": desc,
	})

## 获取任务
func get_quest(quest_id: String) -> Dictionary:
	for q in quests:
		if q["id"] == quest_id:
			return q
	return {}

## 获取任务名称
func get_quest_name(quest_id: String) -> String:
	for q in quests:
		if q["id"] == quest_id:
			return q["name"]
	return quest_id

## 按类型获取任务列表
func get_quests_by_type(quest_type: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for q in quests:
		if q["type"] == quest_type:
			result.append(q)
	return result

## 获取所有任务ID列表
func get_all_quest_ids() -> Array[String]:
	var result: Array[String] = []
	for q in quests:
		result.append(q["id"])
	return result
