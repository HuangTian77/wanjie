## 临时验证脚本: blueprint_executor 拆分后的执行链路测试
extends SceneTree

func _initialize() -> void:
	# 构造一个简单蓝图: start -> set_var -> branch -> (true) print
	var graph := BlueprintData.make_graph()
	var start := BlueprintData.create_node("start", Vector2(0, 0))
	var set_var := BlueprintData.create_node("set_var", Vector2(200, 0))
	set_var["properties"]["var_name"] = "test_var"
	set_var["inputs"][1]["default_value"] = 42
	var branch := BlueprintData.create_node("branch", Vector2(400, 0))
	var print_node := BlueprintData.create_node("print", Vector2(600, 0))
	for n in [start, set_var, branch, print_node]:
		graph["nodes"][n["id"]] = n
	BlueprintData.add_connection(graph, start["id"], 0, set_var["id"], 0, true)
	BlueprintData.add_connection(graph, set_var["id"], 0, branch["id"], 0, true)
	BlueprintData.add_connection(graph, branch["id"], 0, print_node["id"], 0, true)
	# print 的输入引脚 port1 接 get_var 数据源
	var get_var := BlueprintData.create_node("get_var", Vector2(550, 150))
	get_var["properties"]["var_name"] = "test_var"
	graph["nodes"][get_var["id"]] = get_var
	BlueprintData.add_connection(graph, get_var["id"], 0, print_node["id"], 1, false)

	# 初始化执行器
	var exe = load("res://scripts/player/blueprint_executor.gd").new()
	var ws := WorldScriptData.new()
	ws.ensure_subsystems()
	exe.init_engines(null, null, null, null, {"hp": 10}, ws)

	# 执行蓝图
	var result: Dictionary = exe.execute_graph(graph)
	assert(result.get("success", false))
	assert(exe._variables.get("test_var") == 42)
	var log_text: String = "\n".join(result.get("log", []))
	assert(log_text.find("蓝图开始执行") >= 0)
	print("PASS executor flow chain (start/set_var/branch/print/get_var)")
	print("LOG: ", log_text.replace("\n", " | "))

	# 验证 economy 分类节点
	var graph2 := BlueprintData.make_graph()
	var start2 := BlueprintData.create_node("start", Vector2(0, 0))
	var give := BlueprintData.create_node("eco_give_item", Vector2(200, 0))
	give["properties"]["item_id"] = "sword"
	give["properties"]["quantity"] = 1
	graph2["nodes"][start2["id"]] = start2
	graph2["nodes"][give["id"]] = give
	BlueprintData.add_connection(graph2, start2["id"], 0, give["id"], 0, true)
	var eco := EconomyEngineStub.new()
	exe.init_engines(null, eco, null, null, {}, ws)
	var result2: Dictionary = exe.execute_graph(graph2)
	assert(result2.get("success", false))
	assert(eco.inventory.get("sword", 0) == 1)
	print("PASS executor economy node (eco_give_item)")

	# 验证 quest 分类节点
	var graph3 := BlueprintData.make_graph()
	var start3 := BlueprintData.create_node("start", Vector2(0, 0))
	var qa := BlueprintData.create_node("quest_accept", Vector2(200, 0))
	qa["properties"]["quest_id"] = "q1"
	graph3["nodes"][start3["id"]] = start3
	graph3["nodes"][qa["id"]] = qa
	BlueprintData.add_connection(graph3, start3["id"], 0, qa["id"], 0, true)
	exe.init_engines(null, null, null, null, {}, ws)
	var result3: Dictionary = exe.execute_graph(graph3)
	assert(result3.get("success", false))
	assert(exe._quest_state.get("q1") == "active")
	print("PASS executor quest node (quest_accept)")

	# 验证代码生成链路（ScriptCodeGen -> BlueprintCodeGen）
	var ScriptCodeGenClass = load("res://scripts/editor/script_codegen.gd")
	var code: String = ScriptCodeGenClass.generate_blueprint_code(graph, ws)
	assert(code.find("test_var = 42") >= 0)
	assert(code.find("if ") >= 0)
	assert(code.find("func _blueprint_entry") >= 0)
	print("PASS blueprint codegen via BlueprintCodeGen")
	print("CODE:\n", code)

	print("ALL_TESTS_PASSED")
	quit(0)

## 经济引擎桩（最小实现）
class EconomyEngineStub:
	var inventory: Dictionary = {}
	var player_currencies: Dictionary = {"gold": 100}
	func add_item(item_id: String, quantity: int = 1) -> void:
		inventory[item_id] = int(inventory.get(item_id, 0)) + quantity
	func remove_item(item_id: String, quantity: int = 1) -> bool:
		if int(inventory.get(item_id, 0)) >= quantity:
			inventory[item_id] = int(inventory.get(item_id, 0)) - quantity
			return true
		return false
	func add_currency(cur_id: String, amount: int) -> void:
		player_currencies[cur_id] = int(player_currencies.get(cur_id, 0)) + amount
	func buy(_mid: String, _iid: String, _qty: int, _cid: String) -> bool:
		return true
	func sell(_mid: String, _iid: String, _qty: int, _cid: String) -> bool:
		return true
	func update_market_prices() -> void:
		pass
	func get_price(_mid: String, _iid: String) -> float:
		return 10.0
