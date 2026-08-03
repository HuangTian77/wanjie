## 性能基准 v2（可靠测量: 结果必须被消费, 避免 headless 无副作用退化）
## 输出: BENCH {key}={ms} 行
extends SceneTree

var _sink: Array = []

func _initialize() -> void:
	# === 1. 大剧本数据构造 ===
	var t0 := Time.get_ticks_usec()
	var ws := WorldScriptData.new()
	ws.id = "bench"
	ws.name = "基准剧本"
	ws.ensure_subsystems()
	for i in 200:
		ws.event_system.add_story_event("evt_%d" % i, "事件%d" % i, "chain")
		ws.event_system.story_events[i]["conditions"] = [{"type": "player_state", "check": "level >= %d" % (i % 20)}]
		ws.event_system.story_events[i]["choices"] = [
			{"id": "c1", "text": "选项一", "consequences": [{"target": "player", "effect": "gold +10"}]},
			{"id": "c2", "text": "选项二", "consequences": [{"target": "world", "effect": "flag"}]},
		]
	for i in 100:
		ws.ability_system.add_skill_simple("sk_%d" % i, "技能%d" % i, "active", "elemental", "fire", "")
	for i in 50:
		ws.economy_system.add_currency("cur_%d" % i, "货币%d" % i, "universal")
		ws.economy_system.add_resource("res_%d" % i, "资源%d" % i, "material")
	var t1 := Time.get_ticks_usec()
	print("BENCH data_build_ms=", (t1 - t0) / 1000.0)

	# === 2. ScriptCodeGen.generate（结果消费: 累计行数到 _sink） ===
	var ScriptCodeGenClass = load("res://scripts/editor/script_codegen.gd")
	var t2 := Time.get_ticks_usec()
	var code: String = ScriptCodeGenClass.generate(ws)
	var t3 := Time.get_ticks_usec()
	var line_count: int = code.count("\n") + 1
	_sink.append(line_count)
	print("BENCH codegen_ms=", (t3 - t2) / 1000.0, " lines=", line_count)

	# === 3. ScriptCodeGen.parse（结果消费） ===
	var ws2 := WorldScriptData.new()
	ws2.name = "x"
	ws2.ensure_subsystems()
	var t4 := Time.get_ticks_usec()
	var pr: Dictionary = ScriptCodeGenClass.parse(code, ws2)
	var t5 := Time.get_ticks_usec()
	_sink.append(pr.get("success", false))
	print("BENCH code_parse_ms=", (t5 - t4) / 1000.0, " success=", pr.get("success", false))

	# === 4. visual_event 模块创建 ===
	var mock := MockHost.new()
	root.add_child(mock)
	mock.current_script = ws
	var t6 := Time.get_ticks_usec()
	var mod = load("res://scripts/editor/visual/visual_event.gd").new(mock)
	var control = mod.create("event", {})
	var t7 := Time.get_ticks_usec()
	_sink.append(control)
	print("BENCH visual_create_ms=", (t7 - t6) / 1000.0)

	# === 5. 事件列表图同步 + 首帧绘制 ===
	var t8 := Time.get_ticks_usec()
	mod._sync_event_list_graph()
	mock.canvas.draw.connect(func(): mod._draw_event_graph(mock.canvas))
	mock.canvas.queue_redraw()
	await process_frame
	await process_frame
	var t9 := Time.get_ticks_usec()
	print("BENCH event_graph_sync_draw_ms=", (t9 - t8) / 1000.0)

	# === 6. 第二次同步(增量场景) ===
	var t10 := Time.get_ticks_usec()
	mod._sync_event_list_graph()
	var t11 := Time.get_ticks_usec()
	print("BENCH event_graph_resync_ms=", (t11 - t10) / 1000.0)

	print("BENCH_DONE sink=", _sink.size())
	quit(0)

class MockHost extends Node:
	var current_script = null
	var editor_container = null
	var _ui = null
	var canvas = null
	var log_lines: Array = []
	func _init():
		editor_container = Node.new()
		_ui = load("res://scripts/editor/editor_ui_factory.gd").new(self)
		canvas = Control.new()
		canvas.size = Vector2(800, 600)
		add_child(canvas)
	func _log_output(msg: String) -> void:
		log_lines.append(msg)
	func _sync_to_code_editor() -> void:
		pass
	func _mark_dirty() -> void:
		pass
	func _build_module_tree() -> void:
		pass
