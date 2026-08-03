## 可视化编辑器 - 战斗系统模块
extends "res://scripts/editor/visual/visual_module_base.gd"

func get_nav_title() -> String:
	return "⚔ 战斗系统"

func get_nav_items() -> Array:
	return [
		["📊 概览", "combat_overview"],
		["👹 敌人模板", "combat_enemies"],
		["🧑‍🤝‍🧑 NPC池", "combat_npcs"],
		["⚔ 战斗配置", "combat_battles"],
	]

func create(_sub_type: String = "", _meta: Dictionary = {}) -> Control:
	return build_standard_layout(_sub_type, _meta)

func _build_content(content: VBoxContainer, sub_type: String, _meta: Dictionary = {}) -> void:
	_clear(content)
	var cs := _ws().combat_system
	match sub_type:
		"combat_overview":
			_ui().add_section_label(content, "⚔ 战斗系统概览")
			_ui().add_stat_card(content, [
				["敌人模板", "%d 个" % cs.enemy_templates.size()],
				["NPC", "%d 个" % cs.npc_pool.size()],
				["战斗配置", "%d 场" % cs.battle_configs.size()],
			])
		"combat_enemies":
			_ui().add_section_label(content, "👹 敌人模板")
			_ui().add_list_editor(content, cs.enemy_templates, ["name", "hp", "atk", "def", "element"],
				func(): cs.add_enemy_template("enemy_%d" % cs.enemy_templates.size(), "新敌人", 50, 10, 5, ""))
		"combat_npcs":
			_ui().add_section_label(content, "🧑‍🤝‍🧑 NPC池")
			_ui().add_list_editor(content, cs.npc_pool, ["name", "role", "location", "disposition"],
				func(): cs.add_npc("npc_%d" % cs.npc_pool.size(), "新NPC", "villager", "", ""))
		"combat_battles":
			_ui().add_section_label(content, "⚔ 战斗配置")
			_ui().add_list_editor(content, cs.battle_configs, ["name", "terrain", "flee_allowed"],
				func(): cs.add_battle_config("battle_%d" % cs.battle_configs.size(), "新战斗", [], true))
	content.queue_sort()
