## 蓝图运行时综合验收: 事件触发→蓝图驱动→子图调用→story_choice 暂停/恢复→传统事件回退
## 对应 script_player 的 _run_event 全链路（headless 下以引擎桩模拟）
extends SceneTree

func _make_runtime() -> Dictionary:
	var ws = load("res://scripts/player/world_state.gd").new()
	var ee = load("res://scripts/player/event_engine.gd").new()
	ee.init(null, ws, {})
	var eco = load("res://scripts/player/economy_engine.gd").new()
	eco.init(null, {}, {"gold": 100})
	return {"world": ws, "event": ee, "economy": eco}

func _initialize() -> void:
	var ws_data := WorldScriptData.new()
	ws_data.id = "runtime_accept"
	ws_data.ensure_subsystems()

	# === 子图 sys:economy_bonus（经济循环） ===
	var sub := BlueprintData.make_graph()
	var s0 := BlueprintData.create_node("start", Vector2(0, 0))
	var s1 := BlueprintData.create_node("eco_give_item", Vector2(180, 0))
	s1["properties"]["item_id"] = "herb"
	s1["properties"]["quantity"] = 2
	var s2 := BlueprintData.create_node("eco_give_currency", Vector2(360, 0))
	s2["properties"]["currency_id"] = "gold"
	s2["properties"]["amount"] = 15
	for n in [s0, s1, s2]:
		sub["nodes"][n["id"]] = n
	BlueprintData.add_connection(sub, s0["id"], 0, s1["id"], 0, true)
	BlueprintData.add_connection(sub, s1["id"], 0, s2["id"], 0, true)
	GraphStore.set_graph(ws_data, "sys:economy_bonus", sub)

	# === 事件蓝图图（evt:evt_main）: start→flow_sub_graph→story_choice→world_set_var ===
	var eg := BlueprintData.make_graph()
	var e0 := BlueprintData.create_node("start", Vector2(0, 0))
	var e1 := BlueprintData.create_node("flow_sub_graph", Vector2(200, 0))
	e1["properties"]["graph_id"] = "sys:economy_bonus"
	var e2 := BlueprintData.create_node("story_choice", Vector2(400, 0))
	e2["properties"]["choice_0_text"] = "继续前进"
	e2["properties"]["choice_1_text"] = "原地休息"
	var e3 := BlueprintData.create_node("world_set_var", Vector2(600, 0))
	e3["properties"]["var_name"] = "quest_advanced"
	e3["inputs"][1]["default_value"] = true
	for n in [e0, e1, e2, e3]:
		eg["nodes"][n["id"]] = n
	BlueprintData.add_connection(eg, e0["id"], 0, e1["id"], 0, true)
	BlueprintData.add_connection(eg, e1["id"], 0, e2["id"], 0, true)
	BlueprintData.add_connection(eg, e2["id"], 0, e3["id"], 0, true)
	BlueprintData.add_connection(eg, e2["id"], 1, e3["id"], 0, true)
	ws_data.event_system.blueprint_graphs["evt:evt_main"] = eg
	ws_data.event_system.add_story_event("evt_main", "主线推进", "chain")
	ws_data.event_system.story_events[0]["description"] = "你进入了旧城废墟。"
	# 传统事件（无图）
	ws_data.event_system.add_story_event("evt_plain", "集市见闻", "chain")
	ws_data.event_system.story_events[1]["choices"] = [{"id": "c1", "text": "打听消息", "consequences": [{"target": "player", "effect": "gold +10"}]}]

	var rt := _make_runtime()
	var ee: RefCounted = rt["event"]
	var eco: RefCounted = rt["economy"]
	var ws: RefCounted = rt["world"]
	# 绑定事件系统（事件数据在 add 之后才完整）
	ee.init(ws_data.event_system, ws, {})
	var executor = load("res://scripts/player/blueprint_executor.gd").new()
	executor.init_engines(ee, eco, null, ws, {}, ws_data)

	# === 1. 蓝图事件（evt_main）完整链路 ===
	var ev: Dictionary = ws_data.event_system.get_story_event("evt_main")
	assert(ws_data.event_system.blueprint_graphs.has("evt:evt_main"), "蓝图事件应有图")
	ee.mark_triggered(ev)
	var r1: Dictionary = executor.execute_graph(eg)
	assert(r1.get("pending_choice", {}).has("options"), "应暂停等待选择")
	assert(eco.player_inventory.get("herb", 0) == 2, "子图物品应已发放")
	assert(eco.player_currencies.get("gold", 0) == 115, "子图货币应已发放 (100+15)")
	var r2: Dictionary = executor.resume_choice(eg, 0)
	assert(r2.get("success", false), "resume 应完成")
	assert(ws.get_variable("quest_advanced", false) == true, "选择后应执行后续节点")
	assert(ee.triggered_ids.has("evt_main"), "蓝图事件应记录触发")
	print("PASS blueprint event full chain (sub_graph + choice + continue)")

	# === 2. 传统事件回退 ===
	var plain: Dictionary = ws_data.event_system.get_story_event("evt_plain")
	ee.trigger_event(plain)
	assert(ee.pending_event.get("id", "") == "evt_plain", "传统事件走 pending_event")
	assert(not ee.pending_event.get("choices", []).is_empty(), "传统事件应展示 choices")
	print("PASS traditional event fallback")

	# === 3. 多事件依赖: evt_main 触发后可触发后续事件（条件依赖触发历史） ===
	ws_data.event_system.add_story_event("evt_after", "后续事件", "chain")
	ws_data.event_system.story_events[2]["prerequisite"] = "evt_main"
	var after: Dictionary = ws_data.event_system.get_story_event("evt_after")
	var triggerable: Array = ee.check_triggerable_events()
	var has_after: bool = false
	for t in triggerable:
		if t.get("id", "") == "evt_after":
			has_after = true
	assert(has_after, "前置事件已触发, 后续事件应可触发")
	print("PASS prerequisite chain via triggered history")

	print("ALL_TESTS_PASSED")
	quit(0)
