## 编辑器全子分支冒烟: 遍历所有 visual 模块的每个子分支 create 不崩（覆盖"点击子分支闪退"场景）
extends SceneTree

class MockHost extends Node:
	var current_script: WorldScriptData = null
	var _ui = null
	var log_lines: Array = []
	func _init():
		_ui = load("res://scripts/editor/editor_ui_factory.gd").new(self)
	func _log_output(msg: String) -> void:
		log_lines.append(msg)
	func _mark_dirty() -> void:
		pass
	func _sync_to_code_editor() -> void:
		pass
	func _build_module_tree() -> void:
		pass
	func _editor_container() -> Object:
		return self

func _initialize() -> void:
	var ws := WorldScriptData.new()
	ws.id = "panel"
	ws.ensure_subsystems()
	ws.worldview.background_story = "测试世界观"
	ws.worldview.add_faction("f1", "势力一", "human", 50)
	ws.worldview.add_era("时代一", 0, 100)
	ws.event_system.add_story_event("e1", "事件一", "chain")
	ws.event_system.story_events[0]["description"] = "测试"
	ws.event_system.add_random_event("r1", "随机", 0.1)
	ws.economy_system.add_currency("gold", "金币", "universal")
	ws.economy_system.add_resource("wood", "木料", "material")
	ws.economy_system.add_market("m1", "市场", "城镇")
	ws.ability_system.initialize_combat_defaults()
	ws.ability_system.add_skill_simple("sk1", "火球", "active", "elemental", "fire", "")
	ws.quest_system.add_quest("q1", "任务一", "main")
	ws.combat_system.add_enemy_template("en1", "敌人一", 30, 8, 3)
	ws.combat_system.add_battle_config("b1", "战斗一")
	var mock := MockHost.new()
	mock.current_script = ws
	root.add_child(mock)

	# 各模块与其子分支（sub_type）
	var panels := {
		"visual_worldview": ["worldview_overview", "worldview_bg", "worldview_eras", "worldview_timeline", "worldview_rules", "worldview_factions", "worldview_rels", "worldview_geo", "worldview_lore"],
		"visual_event": ["event_overview", "event_story", "event_random", "event_chains"],
		"visual_economy": ["economy_overview", "economy_curr", "economy_res", "economy_mkt", "economy_trade", "economy_prod"],
		"visual_ability": ["ability_overview", "ability_skills", "ability_growth", "ability_fx", "ability_combat", "ability_elem"],
		"visual_quest": ["quest_overview", "quest_list", "quest_chains"],
		"visual_combat": ["combat_overview", "combat_enemies", "combat_npcs", "combat_battles"],
		"visual_map": ["map_overview", "map_region", "map_location"],
		"visual_test_runner": [""],
		"visual_ai_assistant": [""],
	}
	var total := 0
	for m in panels:
		var mod = load("res://scripts/editor/visual/%s.gd" % m).new(mock)
		for sub in panels[m]:
			var ctrl = mod.create(sub, {})
			assert(ctrl != null, "%s/%s 应返回控件" % [m, sub])
			mock.add_child(ctrl)
			ctrl.free()
			total += 1
	print("PASS %d 个子分支全部构建成功" % total)
	print("ALL_TESTS_PASSED")
	quit(0)
