## 子图机制测试: flow_sub_graph 按 key 调用子图, 变量隔离, 子图内 story_choice 暂停可 resume
extends SceneTree

func _make_engine_mocks() -> Dictionary:
	var ws = load("res://scripts/player/world_state.gd").new()
	var ee = load("res://scripts/player/event_engine.gd").new()
	ee.init(null, ws, {})
	var eco = load("res://scripts/player/economy_engine.gd").new()
	eco.init(null, {}, {"gold": 100})
	return {"world": ws, "event": ee, "economy": eco}

func _initialize() -> void:
	var ws_data := WorldScriptData.new()
	ws_data.id = "sub_test"
	ws_data.ensure_subsystems()

	# === 子图 sys:economic_bonus: start → eco_give_item(iron_ore x3) → eco_give_currency(gold +20) ===
	var sub := BlueprintData.make_graph()
	var s_start := BlueprintData.create_node("start", Vector2(0, 0))
	var s_give := BlueprintData.create_node("eco_give_item", Vector2(200, 0))
	s_give["properties"]["item_id"] = "iron_ore"
	s_give["properties"]["quantity"] = 3
	var s_cur := BlueprintData.create_node("eco_give_currency", Vector2(400, 0))
	s_cur["properties"]["currency_id"] = "gold"
	s_cur["properties"]["amount"] = 20
	var s_print := BlueprintData.create_node("print", Vector2(600, 0))
	s_print["properties"]["text"] = "子图完成"
	for n in [s_start, s_give, s_cur, s_print]:
		sub["nodes"][n["id"]] = n
	BlueprintData.add_connection(sub, s_start["id"], 0, s_give["id"], 0, true)
	BlueprintData.add_connection(sub, s_give["id"], 0, s_cur["id"], 0, true)
	BlueprintData.add_connection(sub, s_cur["id"], 0, s_print["id"], 0, true)
	GraphStore.set_graph(ws_data, "sys:economic_bonus", sub)

	# === 主图 sys:main: start → flow_sub_graph(sys:economic_bonus) → world_set_var(sub_called=true) ===
	var main := BlueprintData.make_graph()
	var m_start := BlueprintData.create_node("start", Vector2(0, 0))
	var m_sub := BlueprintData.create_node("flow_sub_graph", Vector2(200, 0))
	m_sub["properties"]["graph_id"] = "sys:economic_bonus"
	var m_var := BlueprintData.create_node("world_set_var", Vector2(400, 0))
	m_var["properties"]["var_name"] = "sub_called"
	m_var["inputs"][1]["default_value"] = true
	for n in [m_start, m_sub, m_var]:
		main["nodes"][n["id"]] = n
	BlueprintData.add_connection(main, m_start["id"], 0, m_sub["id"], 0, true)
	BlueprintData.add_connection(main, m_sub["id"], 0, m_var["id"], 0, true)
	GraphStore.set_graph(ws_data, "sys:main", main)

	# === 执行主图 ===
	var mocks := _make_engine_mocks()
	var eco: RefCounted = mocks["economy"]
	var ws: RefCounted = mocks["world"]
	var executor = load("res://scripts/player/blueprint_executor.gd").new()
	executor.init_engines(mocks["event"], eco, null, ws, {}, ws_data)

	var result: Dictionary = executor.execute_graph(main)
	assert(result.get("success", false), "主图执行应成功: %s" % result.get("error", ""))
	assert(eco.player_inventory.get("iron_ore", 0) == 3, "子图 eco_give_item 应生效")
	assert(eco.player_currencies.get("gold", 0) == 120, "子图 eco_give_currency 应生效 (100+20)")
	assert(ws.get_variable("sub_called", false) == true, "子图返回后父图应继续执行")
	print("PASS sub_graph execution & parent continuation")

	# === 子图内 story_choice 暂停 → resume ===
	var sub2 := BlueprintData.make_graph()
	var s2_start := BlueprintData.create_node("start", Vector2(0, 0))
	var s2_choice := BlueprintData.create_node("story_choice", Vector2(200, 0))
	s2_choice["properties"]["choice_0_text"] = "好"
	s2_choice["properties"]["choice_1_text"] = "不好"
	var s2_var := BlueprintData.create_node("world_set_var", Vector2(400, 0))
	s2_var["properties"]["var_name"] = "sub2_done"
	s2_var["inputs"][1]["default_value"] = true
	for n in [s2_start, s2_choice, s2_var]:
		sub2["nodes"][n["id"]] = n
	BlueprintData.add_connection(sub2, s2_start["id"], 0, s2_choice["id"], 0, true)
	BlueprintData.add_connection(sub2, s2_choice["id"], 0, s2_var["id"], 0, true)
	BlueprintData.add_connection(sub2, s2_choice["id"], 1, s2_var["id"], 0, true)
	var main2 := BlueprintData.make_graph()
	var m2_start := BlueprintData.create_node("start", Vector2(0, 0))
	var m2_sub := BlueprintData.create_node("flow_sub_graph", Vector2(200, 0))
	m2_sub["properties"]["graph_id"] = "sys:sub_with_choice"
	var m2_end := BlueprintData.create_node("print", Vector2(400, 0))
	m2_end["properties"]["text"] = "主图收尾"
	for n in [m2_start, m2_sub, m2_end]:
		main2["nodes"][n["id"]] = n
	BlueprintData.add_connection(main2, m2_start["id"], 0, m2_sub["id"], 0, true)
	BlueprintData.add_connection(main2, m2_sub["id"], 0, m2_end["id"], 0, true)
	GraphStore.set_graph(ws_data, "sys:sub_with_choice", sub2)
	GraphStore.set_graph(ws_data, "sys:main2", main2)

	var ws2 = load("res://scripts/player/world_state.gd").new()
	var ee2 = load("res://scripts/player/event_engine.gd").new()
	ee2.init(null, ws2, {})
	var eco2 = load("res://scripts/player/economy_engine.gd").new()
	eco2.init(null, {}, {"gold": 0})
	var exec2 = load("res://scripts/player/blueprint_executor.gd").new()
	exec2.init_engines(ee2, eco2, null, ws2, {}, ws_data)
	var r2: Dictionary = exec2.execute_graph(main2)
	assert(r2.get("pending_choice", {}).has("options"), "子图内 story_choice 应暂停并上传")
	assert(r2.get("halted", false), "子图暂停应传播到主图")
	var resume: Dictionary = exec2.resume_choice(main2, 0)
	assert(resume.get("success", false), "resume 应在子图内继续完成")
	assert(ws2.get_variable("sub2_done", false) == true, "子图选择后应继续执行子图剩余节点")
	print("PASS sub_graph story_choice pause & resume")

	print("ALL_TESTS_PASSED")
	quit(0)
