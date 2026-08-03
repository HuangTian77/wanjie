## 战斗/NPC系统数据模型
## 对应蓝图节点体系 §3.5 战斗系统
class_name CombatSystemData
extends Resource

## 敌人模板
@export var enemy_templates: Array[Dictionary] = []
# 每个enemy: {id, name, hp, atk, def, matk, mdef, speed, element,
#   skills: [skill_id], loot: [{item_id, chance, qty}], description}

## NPC池
@export var npc_pool: Array[Dictionary] = []
# 每个npc: {id, name, role, location, dialog_id, faction, disposition, description}
# role: merchant / quest_giver / guard / villager / boss
# disposition: friendly / neutral / hostile

## 战斗配置(预设战斗场景)
@export var battle_configs: Array[Dictionary] = []
# 每个battle: {id, name, enemies: [template_id], rewards: {exp, gold, items},
#   flee_allowed, terrain, description}

## 添加敌人模板
func add_enemy_template(template_id: String, enemy_name: String, hp: int = 50,
		atk: int = 10, def_val: int = 5, element: String = "") -> Dictionary:
	var enemy := {
		"id": template_id,
		"name": enemy_name,
		"hp": hp,
		"atk": atk,
		"def": def_val,
		"matk": atk,
		"mdef": def_val,
		"speed": 8,
		"element": element,
		"skills": [],
		"loot": [],
		"description": "",
	}
	enemy_templates.append(enemy)
	return enemy

## 添加NPC
func add_npc(npc_id: String, npc_name: String, role: String = "villager",
		location: String = "", faction: String = "") -> Dictionary:
	var npc := {
		"id": npc_id,
		"name": npc_name,
		"role": role,
		"location": location,
		"dialog_id": "",
		"faction": faction,
		"disposition": "neutral",
		"description": "",
	}
	npc_pool.append(npc)
	return npc

## 添加战斗配置
func add_battle_config(battle_id: String, battle_name: String,
		enemy_ids: Array = [], flee_allowed: bool = true) -> Dictionary:
	var battle := {
		"id": battle_id,
		"name": battle_name,
		"enemies": enemy_ids,
		"rewards": {"exp": 0, "gold": 0, "items": []},
		"flee_allowed": flee_allowed,
		"terrain": "plain",
		"description": "",
	}
	battle_configs.append(battle)
	return battle

## 获取敌人模板
func get_enemy_template(template_id: String) -> Dictionary:
	for e in enemy_templates:
		if e["id"] == template_id:
			return e
	return {}

## 获取敌人名称
func get_enemy_name(template_id: String) -> String:
	for e in enemy_templates:
		if e["id"] == template_id:
			return e["name"]
	return template_id

## 获取NPC
func get_npc(npc_id: String) -> Dictionary:
	for n in npc_pool:
		if n["id"] == npc_id:
			return n
	return {}

## 获取NPC名称
func get_npc_name(npc_id: String) -> String:
	for n in npc_pool:
		if n["id"] == npc_id:
			return n["name"]
	return npc_id

## 获取战斗配置
func get_battle_config(battle_id: String) -> Dictionary:
	for b in battle_configs:
		if b["id"] == battle_id:
			return b
	return {}

## 获取所有敌人模板ID
func get_all_enemy_ids() -> Array[String]:
	var result: Array[String] = []
	for e in enemy_templates:
		result.append(e["id"])
	return result

## 获取所有NPC ID
func get_all_npc_ids() -> Array[String]:
	var result: Array[String] = []
	for n in npc_pool:
		result.append(n["id"])
	return result
