## 战斗引擎（简化版）- 回合制战斗
extends RefCounted

signal combat_started(enemies: Array)
signal combat_round_started(round_num: int)
signal action_taken(actor: Dictionary, action: Dictionary)
signal combat_ended(result: String)  # "victory" / "defeat" / "flee"

var ability_data: AbilitySystemData = null
var player_combat_stats: Dictionary = {}
var enemies: Array[Dictionary] = []
var current_round: int = 0
## 最近一次逃跑成功率（UI 显示用）
var last_flee_chance: float = 0.5
var is_active: bool = false
var combat_log: Array[String] = []

func _init(ad: AbilitySystemData = null) -> void:
	ability_data = ad

## 外部初始化接口
func init(ad: AbilitySystemData) -> void:
	ability_data = ad

## 初始化玩家战斗属性
func set_player_stats(stats: Dictionary) -> void:
	player_combat_stats = {
		"name": stats.get("name", "旅者"),
		"hp": stats.get("hp", 100),
		"max_hp": stats.get("max_hp", 100),
		"mp": stats.get("mp", 50),
		"max_mp": stats.get("max_mp", 50),
		"atk": stats.get("atk", 15),
		"def": stats.get("def", 10),
		"matk": stats.get("matk", 12),
		"mdef": stats.get("mdef", 8),
		"speed": stats.get("speed", 10),
		"agility": stats.get("agility", 10),
		"level": stats.get("level", 1),
		"skills": stats.get("skills", []),
		"status_effects": [],
		"element": ""
	}

## 添加敌人（按全局难度缩放数值）
func add_enemy(enemy: Dictionary) -> void:
	var scale := _difficulty_scale()
	var max_hp: int = maxi(1, int(enemy.get("max_hp", 50) * scale))
	enemies.append({
		"name": enemy.get("name", "未知敌人"),
		"hp": max_hp,
		"max_hp": max_hp,
		"atk": maxi(1, int(enemy.get("atk", 10) * scale)),
		"def": maxi(0, int(enemy.get("def", 5) * scale)),
		"matk": maxi(1, int(enemy.get("matk", 8) * scale)),
		"mdef": maxi(0, int(enemy.get("mdef", 5) * scale)),
		"speed": maxi(1, int(enemy.get("speed", 8) * scale)),
		"element": enemy.get("element", ""),
		"skills": enemy.get("skills", []),
		"status_effects": [],
		"is_alive": true
	})

## 全局难度系数（normal 1.0 / hard 1.35 / easy 0.8 / adaptive 1.0）
func _difficulty_scale() -> float:
	var mode := "adaptive"
	var gm: Node = Engine.get_main_loop().root.get_node_or_null("GameManager")
	if gm != null and gm.user_data != null:
		mode = gm.user_data.difficulty_mode
	match mode:
		"easy":
			return 0.8
		"hard":
			return 1.35
	return 1.0

## 开始战斗
func start_combat() -> void:
	is_active = true
	current_round = 0
	combat_log.clear()
	combat_log.append("战斗开始！")
	combat_started.emit(enemies)
	_next_round()

## 下一回合
func _next_round() -> void:
	current_round += 1
	combat_round_started.emit(current_round)
	# 检查战斗是否结束
	if _check_combat_end():
		return
	# 处理状态效果
	_tick_status_effects()

## 玩家使用普通攻击（自动选择第一个存活敌人）
func player_attack(target_idx: int = -1) -> Dictionary:
	if not is_active:
		return {}
	if target_idx < 0:
		target_idx = _first_alive_enemy_index()
	if target_idx >= enemies.size():
		return {}
	var result := _calculate_physical_damage(player_combat_stats, enemies[target_idx])
	enemies[target_idx]["hp"] -= result["damage"]
	combat_log.append("%s 攻击 %s，造成 %d 点伤害" % [player_combat_stats["name"], enemies[target_idx]["name"], result["damage"]])
	if enemies[target_idx]["hp"] <= 0:
		enemies[target_idx]["hp"] = 0
		enemies[target_idx]["is_alive"] = false
		combat_log.append("%s 被击败！" % enemies[target_idx]["name"])
	action_taken.emit(player_combat_stats, {"type": "attack", "target": target_idx, "damage": result["damage"]})
	# 敌人回合
	_enemy_turn()
	_next_round()
	return result

## 第一个存活敌人索引（无则 -1）
func _first_alive_enemy_index() -> int:
	for i in enemies.size():
		if enemies[i].get("is_alive", true):
			return i
	return -1

## 玩家使用技能
func player_use_skill(skill_id: String, target_idx: int = -1) -> Dictionary:
	if not is_active or ability_data == null:
		return {}
	if target_idx < 0:
		target_idx = _first_alive_enemy_index()
	var skill := ability_data.get_skill(skill_id)
	if skill.is_empty():
		return {}
	var mana_cost: int = int(skill.get("cost", {}).get("mana", 0))
	if player_combat_stats["mp"] < mana_cost:
		combat_log.append("魔力不足！")
		return {}
	player_combat_stats["mp"] -= mana_cost
	var effect_type: String = skill.get("effect", {}).get("type", "damage")
	var result := {}
	match effect_type:
		"damage":
			result = _calculate_skill_damage(skill, player_combat_stats, enemies[target_idx] if target_idx < enemies.size() else {})
			if target_idx < enemies.size():
				enemies[target_idx]["hp"] -= result["damage"]
				if enemies[target_idx]["hp"] <= 0:
					enemies[target_idx]["hp"] = 0
					enemies[target_idx]["is_alive"] = false
			combat_log.append("%s 使用 %s，造成 %d 点伤害" % [player_combat_stats["name"], skill.get("name", ""), result.get("damage", 0)])
			# 应用状态效果(Debuff)
			var se: Dictionary = skill.get("effect", {}).get("status_effect", {})
			if not se.is_empty() and target_idx < enemies.size():
				_apply_status_effect(enemies[target_idx], se)
		"heal":
			var heal_val: int = int(skill.get("effect", {}).get("heal_value", 0))
			var matk_bonus: float = float(player_combat_stats.get("matk", 10)) * 0.5
			heal_val += int(matk_bonus)
			player_combat_stats["hp"] = mini(player_combat_stats["hp"] + heal_val, player_combat_stats["max_hp"])
			result = {"healed": heal_val, "hp_now": player_combat_stats["hp"]}
			combat_log.append("%s 使用 %s，恢复 %d 点生命" % [player_combat_stats["name"], skill.get("name", ""), heal_val])
		"buff":
			var buffs: Dictionary = skill.get("effect", {}).get("buff_stats", {})
			var dur: String = skill.get("effect", {}).get("duration", "5s")
			_apply_buff(player_combat_stats, buffs, dur, skill.get("name", ""))
			result = {"buffed": true, "stats": buffs, "duration": dur}
			combat_log.append("%s 使用 %s，获得增益效果" % [player_combat_stats["name"], skill.get("name", "")])
		"debuff":
			var debuffs: Dictionary = skill.get("effect", {}).get("debuff_stats", {})
			var dur: String = skill.get("effect", {}).get("duration", "5s")
			if target_idx < enemies.size():
				_apply_buff(enemies[target_idx], debuffs, dur, skill.get("name", ""), true)
				result = {"debuffed": true, "stats": debuffs, "duration": dur}
				combat_log.append("%s 使用 %s，对 %s 施加减益" % [player_combat_stats["name"], skill.get("name", ""), enemies[target_idx]["name"]])
		"shield":
			var shield_val: int = int(skill.get("effect", {}).get("base_value", 0))
			player_combat_stats["shield"] = player_combat_stats.get("shield", 0) + shield_val
			result = {"shield": shield_val}
			combat_log.append("%s 使用 %s，获得 %d 点护盾" % [player_combat_stats["name"], skill.get("name", ""), shield_val])
		_:
			result = _calculate_skill_damage(skill, player_combat_stats, enemies[target_idx] if target_idx < enemies.size() else {})
			if target_idx < enemies.size():
				enemies[target_idx]["hp"] -= result["damage"]
				if enemies[target_idx]["hp"] <= 0:
					enemies[target_idx]["hp"] = 0
					enemies[target_idx]["is_alive"] = false
			combat_log.append("%s 使用 %s" % [player_combat_stats["name"], skill.get("name", "")])
	action_taken.emit(player_combat_stats, {"type": effect_type, "skill_id": skill_id, "result": result})
	_enemy_turn()
	_next_round()
	return result

## 敌人回合
func _enemy_turn() -> void:
	for enemy in enemies:
		if not enemy.get("is_alive", false):
			continue
		var result := _calculate_physical_damage(enemy, player_combat_stats)
		player_combat_stats["hp"] -= result["damage"]
		combat_log.append("%s 攻击 %s，造成 %d 点伤害" % [enemy["name"], player_combat_stats["name"], result["damage"]])
		# 玩家受击信号（飘字用）
		action_taken.emit(enemy, {"type": "enemy_attack", "damage": result["damage"], "target": player_combat_stats["name"]})
		if player_combat_stats["hp"] <= 0:
			player_combat_stats["hp"] = 0
			break

## 检查战斗结束
func _check_combat_end() -> bool:
	if player_combat_stats["hp"] <= 0:
		is_active = false
		combat_log.append("战斗失败...")
		combat_ended.emit("defeat")
		return true
	var all_dead := true
	for e in enemies:
		if e.get("is_alive", true):
			all_dead = false
			break
	if all_dead:
		is_active = false
		combat_log.append("战斗胜利！")
		combat_ended.emit("victory")
		return true
	return false

## 逃跑
func try_flee() -> bool:
	var chance: float = 0.5 + float(player_combat_stats.get("agility", 10)) * 0.02
	last_flee_chance = chance
	if randf() < chance:
		is_active = false
		combat_log.append("成功逃跑！")
		combat_ended.emit("flee")
		return true
	combat_log.append("逃跑失败！")
	_enemy_turn()
	_next_round()
	return false

## 计算物理伤害
func _calculate_physical_damage(attacker: Dictionary, defender: Dictionary) -> Dictionary:
	var base_damage: float = float(attacker.get("atk", 10)) * 1.0 - float(defender.get("def", 5)) * 0.5
	base_damage = maxf(base_damage, 1.0)
	var element_mod := 1.0
	if ability_data and attacker.get("element", "") != "":
		element_mod = ability_data.get_element_modifier(attacker["element"], defender.get("element", ""))
	var critical := 1.0
	if randf() < 0.05:
		critical = 1.5
	var random_mod := randf_range(0.9, 1.1)
	var final_damage := int(base_damage * element_mod * critical * random_mod)
	return {"damage": maxf(final_damage, 1), "critical": critical > 1.0, "element_modifier": element_mod}

## 计算技能伤害
func _calculate_skill_damage(skill: Dictionary, caster: Dictionary, target: Dictionary) -> Dictionary:
	var base: float = float(skill.get("effect", {}).get("base_value", 30))
	var _formula: String = skill.get("effect", {}).get("formula", "")
	var damage: float = base + float(caster.get("matk", 10)) * 1.2 - float(target.get("mdef", 5)) * 0.3
	damage = maxf(damage, 1.0)
	var element_mod := 1.0
	if ability_data:
		var school: String = skill.get("school", "")
		if not school.is_empty():
			element_mod = ability_data.get_element_modifier(school, target.get("element", ""))
	var random_mod := randf_range(0.9, 1.1)
	return {"damage": int(damage * element_mod * random_mod)}

## 处理状态效果衰减
func _tick_status_effects() -> void:
	# 处理玩家DOT/Hot
	for effect in player_combat_stats.get("status_effects", []):
		var dot_damage: int = int(effect.get("damage_per_tick", 0))
		if dot_damage > 0:
			player_combat_stats["hp"] -= dot_damage
			combat_log.append("%s 受到 %d 点持续伤害" % [player_combat_stats["name"], dot_damage])
		elif dot_damage < 0:
			player_combat_stats["hp"] = mini(player_combat_stats["hp"] - dot_damage, player_combat_stats["max_hp"])
			combat_log.append("%s 恢复 %d 点生命" % [player_combat_stats["name"], -dot_damage])
		# 衰减持续时间
		effect["remaining_turns"] = effect.get("remaining_turns", 1) - 1
	# 移除过期效果
	player_combat_stats["status_effects"] = player_combat_stats["status_effects"].filter(func(e): return e.get("remaining_turns", 0) > 0)
	# 处理敌人DOT/Hot
	for enemy in enemies:
		if not enemy.get("is_alive", false):
			continue
		for effect in enemy.get("status_effects", []):
			var dot_damage: int = int(effect.get("damage_per_tick", 0))
			if dot_damage > 0:
				enemy["hp"] -= dot_damage
				combat_log.append("%s 受到 %d 点持续伤害" % [enemy["name"], dot_damage])
				if enemy["hp"] <= 0:
					enemy["hp"] = 0
					enemy["is_alive"] = false
			elif dot_damage < 0:
				enemy["hp"] = mini(enemy["hp"] - dot_damage, enemy.get("max_hp", 999))
			effect["remaining_turns"] = effect.get("remaining_turns", 1) - 1
		enemy["status_effects"] = enemy["status_effects"].filter(func(e): return e.get("remaining_turns", 0) > 0)

## 应用状态效果到目标
func _apply_status_effect(target: Dictionary, se: Dictionary) -> void:
	var effect := {
		"id": se.get("id", ""),
		"damage_per_tick": se.get("damage_per_tick", 0),
		"remaining_turns": se.get("duration", "5s").replace("s", "").to_int(),
		"slow": se.get("slow", 0),
		"def_reduce": se.get("def_reduce", 0)
	}
	target.get("status_effects", []).append(effect)
	if not se.get("id", "").is_empty():
		combat_log.append("%s 被施加了 %s" % [target.get("name", "目标"), se["id"]])

## 应用Buff/Debuff
func _apply_buff(target: Dictionary, stats: Dictionary, duration: String, source_name: String, is_debuff: bool = false) -> void:
	if not target.has("status_effects"):
		target["status_effects"] = []
	var turns: int = max(duration.replace("s", "").to_int(), 1)
	var buff_effect := {
		"id": source_name,
		"type": "debuff" if is_debuff else "buff",
		"stats": stats,
		"remaining_turns": turns,
		"damage_per_tick": 0
	}
	target["status_effects"].append(buff_effect)
	# 应用属性变化
	for key in stats:
		if target.has(key):
			if is_debuff:
				target[key] -= int(stats[key])
			else:
				target[key] += int(stats[key])

## 获取战斗日志
func get_log() -> Array[String]:
	return combat_log

## 获取战斗结果奖励
func get_rewards() -> Dictionary:
	# 金币/经验 + 概率掉落物品（loot）
	var loot_items: Array = []
	if randf() < 0.35:
		loot_items.append("herb")
	if randf() < 0.15:
		loot_items.append("potion")
	return {
		"experience": 50 * enemies.size(),
		"gold": randi_range(10, 50) * enemies.size(),
		"loot": loot_items,
	}
