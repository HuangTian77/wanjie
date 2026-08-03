## 蓝图图往返保真测试: 保存/加载 Vector2·Color 不丢失、null 损坏数据可修复、分支操作链路不崩
extends SceneTree

func _initialize() -> void:
	var SDM = load("res://scripts/autoload/script_data_manager.gd")
	var sdm = SDM.new()

	# === 1. 保存侧: Vector2/Color → JSON 安全格式（数组/html） ===
	var ws := WorldScriptData.new()
	ws.ensure_subsystems()
	var graph := BlueprintData.make_graph()
	var s := BlueprintData.create_node("start", Vector2(120, 80))
	var b := BlueprintData.create_node("branch", Vector2(360, 160))
	b["properties"]["condition"] = "level >= 5"
	graph["nodes"][s["id"]] = s
	graph["nodes"][b["id"]] = b
	BlueprintData.add_connection(graph, s["id"], 0, b["id"], 0, true)
	ws.event_system.blueprint_graphs["evt:test"] = graph

	var res_dict: Dictionary = sdm._resource_to_dict(ws.event_system)
	var safe: Dictionary = sdm._graphs_to_json_safe(res_dict["blueprint_graphs"])
	var safe_node: Dictionary = safe["evt:test"]["nodes"][b["id"]] as Dictionary
	assert(safe_node["pos"] is Array, "pos 应转为数组")
	assert(safe_node["color"] is String, "color 应转为 html 串")
	# JSON 序列化往返（模拟落盘+读回）
	var json_str: String = JSON.stringify(safe)
	var parsed: Variant = JSON.parse_string(json_str)
	assert(parsed is Dictionary, "JSON 往返应成功")
	# 加载侧还原
	var restored: Dictionary = sdm._graph_from_json(parsed["evt:test"] as Dictionary)
	var rb: Dictionary = restored["nodes"][b["id"]] as Dictionary
	assert(rb["pos"] is Vector2 and (rb["pos"] as Vector2) == Vector2(360, 160), "pos 应还原为 Vector2")
	assert(rb["color"] is Color, "color 应还原为 Color")
	assert(rb["inputs"] is Array and rb["outputs"] is Array, "引脚应还原")
	print("PASS roundtrip preserve pos/color")

	# === 2. null 损坏数据（旧版本 JSON 写坏）可修复 ===
	var bad := BlueprintData.make_graph()
	var bn := BlueprintData.create_node("branch", Vector2(10, 10))
	bad["nodes"][bn["id"]] = bn
	bad["nodes"][bn["id"]]["pos"] = null
	bad["nodes"][bn["id"]]["color"] = null
	bad["nodes"][bn["id"]]["inputs"] = null
	bad["nodes"][bn["id"]]["outputs"] = null
	var fixed: Dictionary = sdm._graph_from_json(bad)
	var fb: Dictionary = fixed["nodes"][bn["id"]] as Dictionary
	assert(fb["pos"] is Vector2, "null pos 应修复为默认 Vector2")
	assert(fb["color"] is Color, "null color 应修复为默认 Color")
	assert(fb["inputs"] is Array and fb["outputs"] is Array, "null 引脚应修复为空数组")
	# 绘制不崩
	var canvas := Control.new()
	root.add_child(canvas)
	VisualBlueprintDraw.draw_bp_node(canvas, fb, false, Vector2.ZERO, 1.0)
	VisualBlueprintDraw.draw_bp_pins(canvas, fb, Vector2.ZERO, 1.0)
	# 命中测试不崩
	var hit: Variant = VisualBlueprintDraw.hit_test_bp_pins(Vector2(200, 200), fixed, Vector2.ZERO, 1.0)
	print("PASS null data repair & draw & hit-test")

	# === 3. 分支操作链路: 新建图→加分支→undo 快照→恢复→重绘 ===
	var g2 := BlueprintData.make_graph()
	var s2 := BlueprintData.create_node("start", Vector2(0, 0))
	var b2 := BlueprintData.create_node("branch", Vector2(200, 100))
	g2["nodes"][s2["id"]] = s2
	g2["nodes"][b2["id"]] = b2
	BlueprintData.add_connection(g2, s2["id"], 0, b2["id"], 0, true)
	var snap: Dictionary = g2.duplicate(true)  # undo 快照（保留 Vector2）
	var restored2: Dictionary = snap.duplicate(true)
	var rb2: Dictionary = restored2["nodes"][b2["id"]] as Dictionary
	assert((rb2["pos"] as Vector2) == Vector2(200, 100), "undo 快照应保留 pos")
	VisualBlueprintDraw.draw_bp_node(canvas, rb2, false, Vector2.ZERO, 1.0)
	VisualBlueprintDraw.draw_bp_pins(canvas, rb2, Vector2.ZERO, 1.0)
	# 连线释放路径: 模拟引脚命中 + 节点存在检查
	assert(restored2["nodes"].has(b2["id"]), "连线释放前应可查节点存在")
	print("PASS branch add+undo+redraw chain")

	print("ALL_TESTS_PASSED")
	quit(0)
