extends GdUnitTestSuite
## GdUnit4 迁移试点：蓝图运行时综合验收（原 temp_scripts/test_blueprint_runtime.gd）
## 覆盖：事件触发→蓝图驱动→子图调用→story_choice 暂停/恢复→传统事件回退→前置链

func _make_runtime() -> Dictionary:
	var ws = load("res://scripts/player/world_state.gd").new()
	var ee = load("res://scripts/player/event_engine.gd").new()
	ee.init(null, ws, {})
	var eco = load("res://scripts/player/economy_engine.gd").new()
	eco.init(null, {}, {"gold": 100})
	return {"world": ws, "event": ee, "economy": eco}

func _make_world() -> WorldScriptData:
	var ws_data := WorldScriptData.new()
	ws_data.id = "runtime_accept"
	ws_data.ensure_subsystems()
	return ws_data

func test_blueprint_event_full_chain() -> void:
	var ws_data := _make_world()
	# 子图 sys:economy_bonus
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
	# 事件蓝图图
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
	# 运行时
	var rt := _make_runtime()
	var ee: RefCounted = rt["event"]
	var eco: RefCounted = rt["economy"]
	var ws: RefCounted = rt["world"]
	ee.init(ws_data.event_system, ws, {})
	var executor = load("res://scripts/player/blueprint_executor.gd").new()
	executor.init_engines(ee, eco, null, ws, {}, ws_data)
	var ev: Dictionary = ws_data.event_system.get_story_event("evt_main")
	assert_that(ws_data.event_system.blueprint_graphs.has("evt:evt_main")).is_true()
	ee.mark_triggered(ev)
	var r1: Dictionary = executor.execute_graph(eg)
	assert_that(r1.get("pending_choice", {}).has("options")).is_true()
	assert_that(eco.player_inventory.get("herb", 0)).is_equal(2)
	assert_that(eco.player_currencies.get("gold", 0)).is_equal(115)
	var r2: Dictionary = executor.resume_choice(eg, 0)
	assert_that(r2.get("success", false)).is_true()
	assert_that(ws.get_variable("quest_advanced", false)).is_true()
	assert_that(ee.triggered_ids.has("evt_main")).is_true()

func test_traditional_event_fallback() -> void:
	var ws_data := _make_world()
	ws_data.event_system.add_story_event("evt_plain", "集市见闻", "chain")
	ws_data.event_system.story_events[0]["choices"] = [{"id": "c1", "text": "打听消息", "consequences": [{"target": "player", "effect": "gold +10"}]}]
	var rt := _make_runtime()
	var ee: RefCounted = rt["event"]
	var ws: RefCounted = rt["world"]
	ee.init(ws_data.event_system, ws, {})
	var plain: Dictionary = ws_data.event_system.get_story_event("evt_plain")
	ee.trigger_event(plain)
	assert_that(ee.pending_event.get("id", "")).is_equal("evt_plain")
	assert_that(ee.pending_event.get("choices", []).is_empty()).is_false()

func test_prerequisite_chain() -> void:
	var ws_data := _make_world()
	ws_data.event_system.add_story_event("evt_main", "主线", "chain")
	ws_data.event_system.add_story_event("evt_after", "后续事件", "chain")
	ws_data.event_system.story_events[1]["prerequisite"] = "evt_main"
	var rt := _make_runtime()
	var ee: RefCounted = rt["event"]
	var ws: RefCounted = rt["world"]
	ee.init(ws_data.event_system, ws, {})
	# 前置事件未触发: 后续不可触发
	var triggerable_before: Array = ee.check_triggerable_events()
	assert_that(triggerable_before.any(func(t): return t.get("id", "") == "evt_after")).is_false()
	# 触发前置后: 后续可触发
	var main_ev: Dictionary = ws_data.event_system.get_story_event("evt_main")
	ee.mark_triggered(main_ev)
	var triggerable_after: Array = ee.check_triggerable_events()
	assert_that(triggerable_after.any(func(t): return t.get("id", "") == "evt_after")).is_true()
