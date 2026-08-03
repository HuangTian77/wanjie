## 能力系统数据模型
## 对应GDD §3.5 能力系统
## 技能分类体系:
##   category: active / passive / ultimate
##   sub_type: attack / defense / support / special
##   school: elemental_fire / elemental_water / elemental_earth / elemental_wind
##           holy_light / shadow_dark / physical_melee / physical_ranged
##           support_buff / support_heal / ultimate_strategic / passive_combat / passive_magic
class_name AbilitySystemData
extends Resource

## 技能定义
@export var skills: Array[Dictionary] = []
# 每个skill: {id, name, description, category, sub_type, school,
#   requirements: {level, attributes, prerequisites},
#   cost: {mana, cooldown, hp_cost},
#   effect: {type, formula, base_value, aoe_radius, status_effect,
#            heal_value, buff_stats, debuff_stats, duration},
#   scaling: {max_level, level_bonus}}
# category: active / passive / ultimate
# sub_type: attack / defense / support / special

## 成长路线
@export var growth_paths: Array[Dictionary] = []

## 战斗机制定义
@export var combat_definition: Dictionary = {}

## 状态效果定义
@export var status_effects: Array[Dictionary] = []

## 元素相克表
@export var element_matrix: Dictionary = {}

## 技能分类常量
const CATEGORY_ACTIVE := "active"
const CATEGORY_PASSIVE := "passive"
const CATEGORY_ULTIMATE := "ultimate"

const SUB_TYPE_ATTACK := "attack"
const SUB_TYPE_DEFENSE := "defense"
const SUB_TYPE_SUPPORT := "support"
const SUB_TYPE_SPECIAL := "special"

const SCHOOL_FIRE := "elemental_fire"
const SCHOOL_WATER := "elemental_water"
const SCHOOL_EARTH := "elemental_earth"
const SCHOOL_WIND := "elemental_wind"
const SCHOOL_LIGHT := "holy_light"
const SCHOOL_DARK := "shadow_dark"
const SCHOOL_MELEE := "physical_melee"
const SCHOOL_RANGED := "physical_ranged"
const SCHOOL_BUFF := "support_buff"
const SCHOOL_HEAL := "support_heal"
const SCHOOL_ULTIMATE := "ultimate_strategic"
const SCHOOL_PASSIVE_COMBAT := "passive_combat"
const SCHOOL_PASSIVE_MAGIC := "passive_magic"

## 添加技能（完整参数）
func add_skill(skill_id: String, skill_name: String, category: String, sub_type: String,
		school: String, desc: String, req_level: int = 1, req_attrs: Dictionary = {},
		req_prereqs: Array = [], mana_cost: int = 0, cooldown: String = "0s",
		hp_cost: int = 0, effect_type: String = "damage", base_value: int = 0,
		formula: String = "", aoe_radius: int = 0, status_effect: Dictionary = {},
		heal_value: int = 0, buff_stats: Dictionary = {}, debuff_stats: Dictionary = {},
		duration: String = "0s", max_level: int = 10, level_bonus: Array = []) -> void:
	skills.append({
		"id": skill_id,
		"name": skill_name,
		"description": desc,
		"category": category,
		"sub_type": sub_type,
		"school": school,
		"requirements": {"level": req_level, "attributes": req_attrs, "prerequisites": req_prereqs},
		"cost": {"mana": mana_cost, "cooldown": cooldown, "hp_cost": hp_cost},
		"effect": {
			"type": effect_type,
			"formula": formula,
			"base_value": base_value,
			"aoe_radius": aoe_radius,
			"status_effect": status_effect,
			"heal_value": heal_value,
			"buff_stats": buff_stats,
			"debuff_stats": debuff_stats,
			"duration": duration
		},
		"scaling": {"max_level": max_level, "level_bonus": level_bonus}
	})

## 简化添加技能
func add_skill_simple(skill_id: String, skill_name: String, category: String, sub_type: String,
		school: String, desc: String, mana: int = 0, cd: String = "0s",
		effect_type: String = "damage", base_val: int = 0) -> void:
	add_skill(skill_id, skill_name, category, sub_type, school, desc,
		1, {}, [], mana, cd, 0, effect_type, base_val)

## 初始化默认战斗机制
func initialize_combat_defaults() -> void:
	combat_definition = {
		"type": "turn_based",
		"turn_order_formula": "speed * (1 + agility * 0.01) + random(0, 5)",
		"damage_formula": {
			"physical": "ATK * weapon_multiplier - DEF * armor_reduction",
			"magical": "spell_power * skill_multiplier - MDEF * resistance",
			"final": "base_damage * elemental_modifier * critical_modifier * random(0.9, 1.1)"
		},
		"elements": ["fire", "water", "earth", "wind", "light", "dark"],
		"critical_rate": 0.05,
		"critical_damage": 1.5
	}
	# 默认元素相克
	element_matrix = {
		"fire": {"water": 0.5, "earth": 1.5, "wind": 1.2, "light": 1.0, "dark": 1.0},
		"water": {"fire": 2.0, "earth": 0.8, "wind": 0.7, "light": 1.0, "dark": 1.0},
		"earth": {"fire": 0.7, "water": 1.3, "wind": 0.5, "light": 1.0, "dark": 1.0},
		"wind": {"fire": 0.8, "water": 1.5, "earth": 2.0, "light": 1.0, "dark": 1.0},
		"light": {"dark": 2.0, "fire": 1.0, "water": 1.0, "earth": 1.0, "wind": 1.0},
		"dark": {"light": 2.0, "fire": 1.0, "water": 1.0, "earth": 1.0, "wind": 1.0}
	}

## 添加成长路线
func add_growth_path(path_id: String, path_name: String, desc: String = "") -> void:
	growth_paths.append({
		"id": path_id,
		"name": path_name,
		"description": desc,
		"unlock_condition": {},
		"stages": [],
		"branch_points": []
	})

## 为成长路线添加阶段
func add_growth_stage(path_id: String, stage_num: int, stage_name: String, level_range: Array, bonuses: Dictionary = {}) -> void:
	for p in growth_paths:
		if p["id"] == path_id:
			p["stages"].append({
				"stage": stage_num,
				"name": stage_name,
				"level_range": level_range,
				"bonuses": bonuses,
				"skill_unlocks": [],
				"special_ability": ""
			})
			return

## 添加状态效果
func add_status_effect(effect_id: String, effect_name: String, effect_type: String = "buff",
		desc: String = "", duration: String = "5s", dot: int = 0,
		stackable: bool = false, max_stacks: int = 1) -> void:
	status_effects.append({
		"id": effect_id,
		"name": effect_name,
		"type": effect_type,
		"description": desc,
		"duration": duration,
		"damage_per_tick": dot,
		"stackable": stackable,
		"max_stacks": max_stacks
	})

## 按分类获取技能列表
func get_skills_by_category(category: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for s in skills:
		if s["category"] == category:
			result.append(s)
	return result

## 按子类型获取技能列表
func get_skills_by_sub_type(sub_type: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for s in skills:
		if s["sub_type"] == sub_type:
			result.append(s)
	return result

## 按学派获取技能列表
func get_skills_by_school(school: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for s in skills:
		if s["school"] == school:
			result.append(s)
	return result

## 获取技能详情
func get_skill(skill_id: String) -> Dictionary:
	for s in skills:
		if s["id"] == skill_id:
			return s
	return {}

## 获取技能名称
func get_skill_name(skill_id: String) -> String:
	for s in skills:
		if s["id"] == skill_id:
			return s["name"]
	return skill_id

## 获取元素相克系数
func get_element_modifier(attack_element: String, defense_element: String) -> float:
	if element_matrix.has(attack_element):
		if element_matrix[attack_element].has(defense_element):
			return element_matrix[attack_element][defense_element]
	return 1.0

## 获取技能统计摘要
func get_skill_summary() -> Dictionary:
	var summary := {"total": skills.size(), "by_category": {}, "by_sub_type": {}, "by_school": {}}
	for s in skills:
		var cat: String = s["category"]
		var st: String = s["sub_type"]
		var sch: String = s["school"]
		summary["by_category"][cat] = summary["by_category"].get(cat, 0) + 1
		summary["by_sub_type"][st] = summary["by_sub_type"].get(st, 0) + 1
		summary["by_school"][sch] = summary["by_school"].get(sch, 0) + 1
	return summary
