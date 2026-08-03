## 临时验证脚本: 执行器补全测试（flow_for_loop / story_choice / 未知节点）
extends SceneTree

func _initialize() -> void:
	var exe = load("res://scripts/player/blueprint_executor.gd").new()
	var ws := WorldScriptData.new()
	ws.ensure_subsystems()
	exe.init_engines(null, null, null, null, {"hp": 10}, ws)

	# === 1. flow_for_loop: 循环体执行 count 次 ===
	var g := BlueprintData.make_graph()
	var start := BlueprintData.create_node("start", Vector2(0, 0))
	start["id"] = "start_loop"
	var loop := BlueprintData.create_node("flow_for_loop", Vector2(200, 0))
	loop["id"] = "loop_node"
	loop["inputs"][1]["default_value"] = 3  # count = 3
	var body := BlueprintData.create_node("print", Vector2(400, 0))
	body["id"] = "body_print"
	var done := BlueprintData.create_node("print", Vector2(400, 200))
	done["id"] = "done_print"
	for n in [start, loop, body, done]:
		g["nodes"][n["id"]] = n
	BlueprintData.add_connection(g, start["id"], 0, loop["id"], 0, true)
	BlueprintData.add_connection(g, loop["id"], 0, body["id"], 0, true)   # body 输出
	BlueprintData.add_connection(g, body["id"], 0, loop["id"], 0, true)   # 回边
	BlueprintData.add_connection(g, loop["id"], 1, done["id"], 0, true)   # done 输出
	var r: Dictionary = exe.execute_graph(g)
	assert(r.get("success", false), "循环执行应成功")
	var log_text: String = "\n".join(r.get("log", []))
	assert(log_text.count("循环 ") >= 3, "应记录循环开始与 2 次回边")
	print("PASS flow_for_loop body executed (log lines: ", log_text.split("\n").size(), ")")

	# === 2. story_choice: 等待玩家输入并恢复 ===
	var g2 := BlueprintData.make_graph()
	var s2 := BlueprintData.create_node("start", Vector2(0, 0))
	var choice := BlueprintData.create_node("story_choice", Vector2(200, 0))
	choice["properties"]["choice_0_text"] = "去左边"
	choice["properties"]["choice_1_text"] = "去右边"
	var pa := BlueprintData.create_node("print", Vector2(400, 0))
	pa["id"] = "pa_print"
	var pb := BlueprintData.create_node("print", Vector2(400, 150))
	pb["id"] = "pb_print"
	for n in [s2, choice, pa, pb]:
		g2["nodes"][n["id"]] = n
	BlueprintData.add_connection(g2, s2["id"], 0, choice["id"], 0, true)
	BlueprintData.add_connection(g2, choice["id"], 0, pa["id"], 0, true)  # choice_0
	BlueprintData.add_connection(g2, choice["id"], 1, pb["id"], 0, true)  # choice_1
	var r2: Dictionary = exe.execute_graph(g2)
	assert(r2.get("success", false) == false, "等待选择时应暂停")
	assert(r2.get("halted", false), "应标记 halted")
	var pc: Dictionary = r2.get("pending_choice", {})
	assert(not pc.is_empty(), "应记录 pending_choice")
	assert(pc.get("options", []).size() == 2, "应有 2 个选项")
	# 恢复: 选 1（去右边）
	var r2b: Dictionary = exe.resume_choice(g2, 1)
	assert(r2b.get("success", false), "恢复后应执行成功")
	assert(r2b.get("steps", 0) >= 1, "恢复后应继续执行到选择分支")
	assert(not r2b.has("pending_choice"), "恢复后不应再有待选")
	print("PASS story_choice pause & resume")

	# === 3. 未知节点: 明确报错 ===
	var g3 := BlueprintData.make_graph()
	var s3 := BlueprintData.create_node("start", Vector2(0, 0))
	s3["id"] = "start_unknown"
	var unknown := BlueprintData.create_node("start", Vector2(200, 0))
	unknown["id"] = "unknown_node"
	unknown["node_type"] = "unknown_node_xyz"
	g3["nodes"][s3["id"]] = s3
	g3["nodes"][unknown["id"]] = unknown
	BlueprintData.add_connection(g3, s3["id"], 0, unknown["id"], 0, true)
	var r3: Dictionary = exe.execute_graph(g3)
	assert(r3.get("success", false) == false, "未知节点应失败")
	assert(r3.get("error", "").find("unknown_node_xyz") >= 0, "错误信息应含节点类型")
	print("PASS unknown node error: ", r3.get("error", ""))

	# === 4. 回归: 普通流程仍正常 ===
	var g4 := BlueprintData.make_graph()
	var s4 := BlueprintData.create_node("start", Vector2(0, 0))
	s4["id"] = "start_reg"
	var sv := BlueprintData.create_node("set_var", Vector2(200, 0))
	sv["id"] = "setvar_node"
	sv["properties"]["var_name"] = "x"
	sv["inputs"][1]["default_value"] = 7
	g4["nodes"][s4["id"]] = s4
	g4["nodes"][sv["id"]] = sv
	BlueprintData.add_connection(g4, s4["id"], 0, sv["id"], 0, true)
	var r4: Dictionary = exe.execute_graph(g4)
	assert(r4.get("success", false), "普通流程应成功")
	assert(exe._variables.get("x") == 7, "set_var 应写入")
	print("PASS normal flow regression")

	print("ALL_TESTS_PASSED")
	quit(0)
