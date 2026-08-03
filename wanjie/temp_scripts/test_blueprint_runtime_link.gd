## 蓝图运行时接入链路测试: 事件带蓝图图时由蓝图驱动（对应 script_player._run_blueprint_event 逻辑）
extends SceneTree

var _signal_flag: bool = false

func _make_engine_mocks() -> Dictionary:
	# 简化引擎桩: 记录调用
	var ws = load("res://scripts/player/world_state.gd").new()
	ws.set_variable("gold_start", 0)
	var ee = load("res://scripts/player/event_engine.gd").new()
	ee.init(null, ws, {})
	var eco = load("res://scripts/player/economy_engine.gd").new()
	eco.init(null, {"gold": 100}, {})
	return {"world": ws, "event": ee, "economy": eco}

func _initialize() -> void:
	# === 1. 构造剧本: 一个事件 + 蓝图图(start → eco_give_item → story_choice) ===
	var ws_data := WorldScriptData.new()
	ws_data.id = "rt_test"
	ws_data.ensure_subsystems()
	ws_data.event_system.add_story_event("evt_bp_1", "蓝图事件", "chain")
	ws_data.event_system.story_events[0]["description"] = "这是蓝图驱动的事件"
	var graph := BlueprintData.make_graph()
	var start := BlueprintData.create_node("start", Vector2(0, 0))
	var give := BlueprintData.create_node("eco_give_item", Vector2(200, 0))
	give["properties"]["item_id"] = "iron_ore"
	give["properties"]["quantity"] = 5
	var choice := BlueprintData.create_node("story_choice", Vector2(400, 0))
	choice["properties"]["choice_0_text"] = "接受奖励"
	choice["properties"]["choice_1_text"] = "拒绝"
	var done := BlueprintData.create_node("print", Vector2(600, 0))
	done["properties"]["text"] = "蓝图流程结束"
	for n in [start, give, choice, done]:
		graph["nodes"][n["id"]] = n
	BlueprintData.add_connection(graph, start["id"], 0, give["id"], 0, true)
	BlueprintData.add_connection(graph, give["id"], 0, choice["id"], 0, true)
	# choice_0 -> done, choice_1 -> done
	BlueprintData.add_connection(graph, choice["id"], 0, done["id"], 0, true)
	BlueprintData.add_connection(graph, choice["id"], 1, done["id"], 0, true)
	ws_data.event_system.blueprint_graphs["evt_bp_1"] = graph

	# === 2. 模拟 script_player 的 _run_blueprint_event 链路 ===
	var mocks := _make_engine_mocks()
	var ee: RefCounted = mocks["event"]
	var eco: RefCounted = mocks["economy"]
	var ws: RefCounted = mocks["world"]
	var executor = load("res://scripts/player/blueprint_executor.gd").new()
	executor.init_engines(ee, eco, null, ws, {}, ws_data)

	var ev: Dictionary = ws_data.event_system.get_story_event("evt_bp_1")
	assert(not ev.is_empty(), "事件应存在")

	# 蓝图驱动: mark_triggered + execute_graph
	ee.mark_triggered(ev)
	assert(ee.triggered_ids.has("evt_bp_1"), "蓝图事件应标记已触发")
	assert(ee.triggered_events.size() == 1, "触发历史应记录")

	var result: Dictionary = executor.execute_graph(graph)
	assert(result.get("pending_choice", {}).has("options"), "应暂停等待选择")
	var options: Array = result.get("pending_choice", {}).get("options", [])
	assert(options.size() == 2 and options[0] == "接受奖励", "选项文本应来自节点属性")
	# 暂停前 eco_give_item 已执行
	assert(eco.player_inventory.has("iron_ore"), "give_item 应在暂停前生效")

	# resume: 选择 0 (接受) → 走到 done
	var resume: Dictionary = executor.resume_choice(graph, 0)
	assert(resume.get("success", false), "resume 应成功完成")
	assert(not resume.has("pending_choice"), "完成后不应再有暂停")

	# 无蓝图事件回退: trigger_event 传统路径
	ws_data.event_system.add_story_event("evt_plain", "传统事件", "chain")
	ws_data.event_system.story_events[1]["choices"] = [{"id": "c1", "text": "选项", "consequences": []}]
	var plain: Dictionary = ws_data.event_system.get_story_event("evt_plain")
	assert(not ws_data.event_system.blueprint_graphs.has("evt_plain"), "传统事件无图")
	var triggered_signal: bool = false
	_signal_flag = false
	ee.event_triggered.connect(func(_e): _signal_flag = true)
	ee.trigger_event(plain)
	assert(_signal_flag, "传统事件应 emit event_triggered")
	assert(ee.pending_event.get("id", "") == "evt_plain", "传统事件应走 pending_event 流程")

	print("PASS mark_triggered + blueprint event flow")
	print("PASS story_choice pause & resume")
	print("PASS fallback to traditional event flow")
	print("ALL_TESTS_PASSED")
	quit(0)
