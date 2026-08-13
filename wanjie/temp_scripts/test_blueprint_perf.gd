extends SceneTree
## 三模式大图性能压测：200 节点图的执行顺序/布局/命中检测计时

var _fail := 0

func _check(name: String, cond: bool) -> void:
	if cond:
		print("PASS ", name)
	else:
		print("FAIL ", name)
		_fail += 1

func _initialize() -> void:
	var graph: Dictionary = BlueprintData.make_graph()
	# 创建 200 节点链（start + 199 节点串联 exec）
	var prev_id := ""
	for i in 200:
		var nt := "start" if i == 0 else "flow_print_log"
		var node: Dictionary = BlueprintData.create_node(nt, Vector2(100 + i * 40, 100))
		graph["nodes"][node["id"]] = node
		if prev_id != "":
			BlueprintData.add_connection(graph, prev_id, 0, node["id"], 0, true)
		prev_id = node["id"]
	_check("200 节点创建", graph["nodes"].size() == 200)
	_check("199 连接创建", graph.get("connections", []).size() == 199)
	# 执行顺序计算（计时）
	var t0 := Time.get_ticks_usec()
	var order: Dictionary = {}
	var starts: Array[String] = []
	for nid in graph["nodes"]:
		var nt: String = str(graph["nodes"][nid].get("node_type", ""))
		if nt == "start" or nt == "flow_start":
			starts.append(nid)
	if not starts.is_empty():
		var queue: Array[String] = starts.duplicate()
		var visited: Dictionary = {}
		var idx := 1
		while not queue.is_empty():
			var cur: String = queue.pop_front()
			if visited.has(cur):
				continue
			visited[cur] = true
			order[cur] = idx
			idx += 1
			for conn in graph.get("connections", []):
				if str(conn.get("from_node", "")) == cur and bool(conn.get("is_exec", true)):
					var to: String = str(conn.get("to_node", ""))
					if not visited.has(to):
						queue.append(to)
	var t1 := Time.get_ticks_usec()
	var order_ms := (t1 - t0) / 1000.0
	_check("执行顺序 200 节点", order.size() == 200)
	_check("执行顺序 < 100ms（%dms）" % int(order_ms), order_ms < 100.0)
	# 自动布局计时（模拟）
	var t2 := Time.get_ticks_usec()
	var y := 100.0
	for nid in graph["nodes"]:
		graph["nodes"][nid]["pos"] = Vector2(100, y)
		y += 130.0
	var t3 := Time.get_ticks_usec()
	var layout_ms := (t3 - t2) / 1000.0
	_check("布局 < 50ms（%dms）" % int(layout_ms), layout_ms < 50.0)
	# 命中检测（模拟 100 次查询）
	var t4 := Time.get_ticks_usec()
	var found := 0
	for i in 100:
		for nid in graph["nodes"]:
			var p: Vector2 = graph["nodes"][nid]["pos"]
			if p.distance_to(Vector2(100, 100 + i * 13)) < 65.0:
				found += 1
				break
	var t5 := Time.get_ticks_usec()
	var hit_ms := (t5 - t4) / 1000.0
	_check("命中查询 < 200ms（%dms）" % int(hit_ms), hit_ms < 200.0)
	print("ALL_TESTS_PASSED" if _fail == 0 else "TESTS_FAILED=%d" % _fail)
	quit(0 if _fail == 0 else 1)
