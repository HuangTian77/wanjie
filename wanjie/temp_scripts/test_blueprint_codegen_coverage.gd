## 编译覆盖测试: 8 大分类节点均生成真实 GDScript 调用（而非注释占位）
extends SceneTree

func _add_chain(graph: Dictionary, from_id: String, to_id: String) -> void:
	BlueprintData.add_connection(graph, from_id, 0, to_id, 0, true)

func _initialize() -> void:
	var ws := WorldScriptData.new()
	ws.ensure_subsystems()
	var ScriptCodeGenClass = load("res://scripts/editor/script_codegen.gd")

	# === 构造覆盖 8 分类的执行链图 ===
	var graph := BlueprintData.make_graph()
	var n_start := BlueprintData.create_node("start", Vector2(0, 0))
	var n_for := BlueprintData.create_node("flow_for_loop", Vector2(200, 0))
	n_for["properties"]["iterations"] = 3
	var n_buy := BlueprintData.create_node("eco_buy", Vector2(400, 0))
	n_buy["properties"]["market_id"] = "m1"
	n_buy["properties"]["item_id"] = "sword"
	n_buy["properties"]["quantity"] = 1
	var n_choice := BlueprintData.create_node("story_choice", Vector2(600, 0))
	n_choice["properties"]["choice_0_text"] = "买"
	n_choice["properties"]["choice_1_text"] = "不买"
	var n_dialog := BlueprintData.create_node("story_dialog", Vector2(800, 0))
	n_dialog["properties"]["speaker"] = "商人"
	n_dialog["properties"]["text"] = "欢迎光临"
	var n_wmod := BlueprintData.create_node("world_modify_var", Vector2(1000, 0))
	n_wmod["properties"]["var_name"] = "reputation"
	n_wmod["properties"]["op"] = "+"
	n_wmod["properties"]["value"] = 5
	var n_level := BlueprintData.create_node("player_level_exp", Vector2(1200, 0))
	n_level["properties"]["mode"] = "add_exp"
	n_level["properties"]["value"] = 50
	var n_enemy := BlueprintData.create_node("combat_spawn_enemy", Vector2(1400, 0))
	n_enemy["properties"]["enemy_template"] = "goblin"
	n_enemy["properties"]["custom_name"] = "哥布林"
	n_enemy["properties"]["hp"] = 30
	var n_learn := BlueprintData.create_node("ability_learn", Vector2(1600, 0))
	n_learn["properties"]["skill_id"] = "fireball"
	var n_quest := BlueprintData.create_node("quest_accept", Vector2(1800, 0))
	n_quest["properties"]["quest_id"] = "q1"
	var n_quest_done := BlueprintData.create_node("quest_complete", Vector2(2000, 0))
	n_quest_done["properties"]["quest_id"] = "q1"
	var n_end := BlueprintData.create_node("print", Vector2(2200, 0))
	n_end["properties"]["text"] = "完成"
	for n in [n_start, n_for, n_buy, n_choice, n_dialog, n_wmod, n_level, n_enemy, n_learn, n_quest, n_quest_done, n_end]:
		graph["nodes"][n["id"]] = n
	# 执行链: start -> for -> buy -> choice -> dialog -> wmod -> level -> enemy -> learn -> quest -> quest_done -> print
	var chain := [n_start, n_for, n_buy, n_choice, n_dialog, n_wmod, n_level, n_enemy, n_learn, n_quest, n_quest_done, n_end]
	for i in chain.size() - 1:
		_add_chain(graph, chain[i]["id"], chain[i + 1]["id"])
	# choice 两个分支都连 dialog
	BlueprintData.add_connection(graph, n_choice["id"], 1, n_dialog["id"], 0, true)

	var code: String = ScriptCodeGenClass.generate_blueprint_code(graph, ws)
	# === 断言各分类节点生成了真实调用 ===
	var checks := {
		"flow_for_loop": "for _loop_i in range(3):",
		"economy_buy": "economy_engine.buy(\"m1\", \"sword\", 1)",
		"story_choice": "剧情选择（运行时暂停等待输入）",
		"story_dialog": "print(\"[商人] 欢迎光临\")",
		"world_modify_var": "world_state.set_variable(\"reputation\", float(_cur) + 5)",
		"player_level_exp": "player_state[\"exp\"] = int(player_state.get(\"exp\", 0)) + 50",
		"combat_spawn_enemy": "combat_engine.add_enemy({\"name\": \"哥布林\"",
		"ability_learn": "player_state[\"skills\"].append(\"fireball\")",
		"quest_accept": "quest_state[\"q1\"] = \"active\"",
		"quest_complete": "quest_state[\"q1\"] = \"completed\"",
	}
	var missing: Array[String] = []
	for label in checks:
		if code.find(checks[label]) < 0:
			missing.append("%s (期望: %s)" % [label, checks[label]])
	if missing.is_empty():
		print("PASS all 8 categories generate real code")
	else:
		print("FAIL missing: ", missing)
		assert(false, "编译覆盖缺失: %s" % str(missing))
	# 不应出现 Unknown node
	assert(code.find("Unknown node") < 0, "不应有 Unknown node 占位")
	assert(code.find("# 未实现") < 0, "不应有未实现占位")
	print("PASS no unknown-node placeholders")
	print("ALL_TESTS_PASSED")
	quit(0)
