## 模板系统测试: 6 个游戏类型模板完整骨架 + 蓝图图可执行 + quest/combat 序列化
extends SceneTree

func _exec_global_graph(ws: WorldScriptData) -> Dictionary:
	# 用运行时引擎执行模板的 sys:global 图, 验证骨架可运行
	var mocks := {}
	var ws_rt = load("res://scripts/player/world_state.gd").new()
	var ee = load("res://scripts/player/event_engine.gd").new()
	ee.init(ws.event_system, ws_rt, {})
	var eco = load("res://scripts/player/economy_engine.gd").new()
	eco.init(ws.economy_system, {}, {"gold": 100})
	var executor = load("res://scripts/player/blueprint_executor.gd").new()
	executor.init_engines(ee, eco, null, ws_rt, {}, ws)
	var graph: Dictionary = GraphStore.get_graph(ws, "sys:global")
	if graph.is_empty():
		return {"skipped": true}
	return executor.execute_graph(graph)

func _initialize() -> void:
	var ScriptTemplatesClass = load("res://scripts/autoload/script_templates.gd")
	var defs: Array = ScriptTemplatesClass.get_template_defs()
	assert(defs.size() == 6, "应有 6 个游戏类型模板, 实际 %d" % defs.size())
	print("PASS 6 template defs")

	var template_ids := ["rpg_adventure", "visual_novel", "simulation_tycoon", "turn_strategy", "combat_arena", "explore_puzzle"]
	for tid in template_ids:
		var ws := WorldScriptData.new()
		ws.id = "tpl_%s" % tid
		ws.ensure_subsystems()
		assert(ScriptTemplatesClass.apply_template(ws, tid), "模板 %s 应应用成功" % tid)
		# 四子系统非空
		assert(not ws.name.is_empty(), "%s: 应有名称" % tid)
		assert(not ws.worldview.background_story.is_empty(), "%s: 应有世界观背景" % tid)
		assert(not ws.event_system.story_events.is_empty(), "%s: 应有剧情事件" % tid)
		assert(not ws.economy_system.currencies.is_empty(), "%s: 应有货币" % tid)
		assert(not ws.ability_system.skills.is_empty(), "%s: 应有技能" % tid)
		assert(not ws.quest_system.quests.is_empty(), "%s: 应有任务" % tid)
		# 蓝图图存在
		assert(GraphStore.has_graph(ws, "sys:global"), "%s: 应有 sys:global 图" % tid)
		# 图可执行（无错误或正常暂停等待选择）
		var r: Dictionary = _exec_global_graph(ws)
		if not r.get("skipped", false):
			var err: String = r.get("error", "")
			assert(err == "" or err == "no_entry_node" or r.has("pending_choice"), "%s: 图执行不应硬错误, err=%s" % [tid, err])
		print("PASS template %s (worldview/events/economy/ability/quest/blueprint)" % tid)

	# === 序列化: quest/combat 纳入 SUBSYSTEM_FILES ===
	var SDMClass = load("res://scripts/autoload/script_data_manager.gd")
	var sdm = SDMClass.new()
	assert(sdm.SUBSYSTEM_FILES.has("quest_system"), "SUBSYSTEM_FILES 应含 quest_system")
	assert(sdm.SUBSYSTEM_FILES.has("combat_system"), "SUBSYSTEM_FILES 应含 combat_system")
	# quest/combat Resource 往返
	var ws2 := WorldScriptData.new()
	ws2.ensure_subsystems()
	ws2.quest_system.add_quest("q1", "任务一", "main")
	ws2.quest_system.quests[0]["rewards"] = {"exp": 10}
	ws2.combat_system.add_enemy_template("e1", "敌人一", 30, 8, 3)
	var qd: Dictionary = sdm._resource_to_dict(ws2.quest_system)
	var cd: Dictionary = sdm._resource_to_dict(ws2.combat_system)
	var ws3 := WorldScriptData.new()
	ws3.ensure_subsystems()
	sdm._dict_to_resource(qd, ws3.quest_system)
	sdm._dict_to_resource(cd, ws3.combat_system)
	assert(ws3.quest_system.quests.size() == 1, "quest 序列化往返应保留")
	assert(ws3.combat_system.enemy_templates.size() == 1, "combat 序列化往返应保留")
	assert(ws3.quest_system.quests[0].get("rewards", {}).get("exp", 0) == 10, "quest 嵌套字段应保留")
	print("PASS quest/combat serialization roundtrip")

	# === get_templates 含 dragonflame 与游戏类型 ===
	var all_ids: Array = []
	for t in sdm.get_templates():
		all_ids.append(t.get("id", ""))
	assert(all_ids.has("dragonflame_era"), "模板列表应含 dragonflame_era")
	assert(all_ids.has("rpg_adventure"), "模板列表应含游戏类型模板")
	print("PASS get_templates includes game-type & dragonflame")

	print("ALL_TESTS_PASSED")
	quit(0)
