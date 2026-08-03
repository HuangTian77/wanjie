## 蓝图运行时执行器
## 遍历蓝图图的执行流, 将节点操作映射到运行时引擎调用
## 对接: event_engine / economy_engine / combat_engine / world_state
class_name BlueprintExecutor
extends RefCounted

## 执行日志
signal log_message(level: String, text: String)
signal execution_finished(result: Dictionary)

## 运行时引擎引用
var event_engine: RefCounted = null     # EventEngine
var economy_engine: RefCounted = null   # EconomyEngine
var combat_engine: RefCounted = null    # CombatEngine
var world_state: RefCounted = null      # WorldState
var player_state: Dictionary = {}
var ws_data: RefCounted = null          # WorldScriptData (静态数据)

## 执行上下文
var _variables: Dictionary = {}         # 局部变量
var _halted: bool = false
var _exec_log: Array[String] = []
var _quest_state: Dictionary = {}       # {quest_id: "active"/"completed"/"failed"}
var _quest_progress: Dictionary = {}    # {quest_id: {obj_idx: current_count}}
var _max_steps: int = 10000             # 防无限循环
## 循环栈帧: node_id -> {remaining: int, index: int}（flow_for_loop 支持）
var _loop_frames: Dictionary = {}
## 未实现节点错误信息（执行遇到未知节点时设置）
var _last_error: String = ""
## 待处理玩家选择（story_choice 等待输入时设置）
var _pending_choice: Dictionary = {}
## 子图调用栈: Array[{variables, halted, pending_choice, last_error}]（flow_sub_graph 支持）
var _sub_graph_stack: Array = []

## 初始化
func init_engines(ee: RefCounted, eco: RefCounted, ce: RefCounted, ws: RefCounted, ps: Dictionary, wsd: RefCounted = null) -> void:
	event_engine = ee
	economy_engine = eco
	combat_engine = ce
	world_state = ws
	player_state = ps
	ws_data = wsd

## 执行整张蓝图图, 返回执行结果摘要
func execute_graph(graph: Dictionary) -> Dictionary:
	return execute_from(graph, "", 0)

## 从指定节点继续执行（start_id 为空则从入口开始）
func execute_from(graph: Dictionary, start_id: String, start_port: int) -> Dictionary:
	_halted = false
	_last_error = ""
	_pending_choice = {}
	_exec_log.clear()
	_variables = graph.get("local_variables", {}).duplicate(true)
	var start_nid: String = start_id
	var steps: int = 0
	if start_nid == "":
		var entry_nodes := BlueprintData.find_entry_nodes(graph)
		if entry_nodes.is_empty():
			_log("warn", "蓝图中没有开始节点")
			return {"success": false, "error": "no_entry_node", "log": _exec_log}
		start_nid = entry_nodes[0]
	# 从入口开始执行
	var current_id: String = start_nid
	var current_port: int = start_port  # 从哪个输出端口进入
	while current_id != "" and not _halted and steps < _max_steps:
		steps += 1
		if not graph["nodes"].has(current_id):
			break
		var node: Dictionary = graph["nodes"][current_id]
		var next_port: int = _execute_node(node, graph)
		# 找下一个exec后继
		var next := _find_exec_successor(graph, current_id, next_port)
		current_id = next.get("node_id", "")
		current_port = next.get("port", 0)
	if steps >= _max_steps:
		_log("error", "执行超过最大步数(%d), 可能存在无限循环" % _max_steps)
	var result := {
		"success": not _halted and _last_error == "",
		"steps": steps, "log": _exec_log, "variables": _variables,
	}
	if _last_error != "":
		result["error"] = _last_error
	if not _pending_choice.is_empty():
		result["pending_choice"] = _pending_choice
		result["halted"] = true
	execution_finished.emit(result)
	return result

## 响应玩家选择后继续执行（story_choice 暂停后调用）
## choice_index: 0 或 1（对应 story_choice 的 choice_0/choice_1 输出端口）
## 暂停可能发生在子图内: 使用 _pending_choice 记录的图（而非调用方传入的图）
func resume_choice(_caller_graph: Dictionary, choice_index: int) -> Dictionary:
	if _pending_choice.is_empty():
		return {"success": false, "error": "no_pending_choice", "log": _exec_log}
	var graph: Dictionary = _pending_choice.get("graph", _caller_graph)
	var node_id: String = _pending_choice.get("node_id", "")
	_pending_choice = {}
	# 从选择节点对应输出端口的后继开始执行（不重新执行选择节点本身）
	var next := _find_exec_successor(graph, node_id, choice_index)
	var start_id: String = next.get("node_id", "")
	var start_port: int = next.get("port", 0)
	_log("info", "玩家选择 %d 继续执行" % choice_index)
	return execute_from(graph, start_id, start_port)

## 执行子图（flow_sub_graph 节点调用）: 按 key 从剧本取图, 隔离局部变量, 子图内暂停向上传播
func execute_sub_graph(graph_key: String) -> Dictionary:
	if ws_data == null or ws_data.event_system == null:
		_log("error", "子图 %s 无法执行: 无剧本数据" % graph_key)
		return {"success": false, "error": "no_ws_data"}
	var sub: Dictionary = GraphStore.get_graph(ws_data, graph_key)
	if sub.is_empty():
		_log("error", "子图不存在: %s" % graph_key)
		return {"success": false, "error": "graph_not_found:%s" % graph_key}
	# 保存父上下文（变量隔离; 暂停/错误状态共享以便向上传播）
	_sub_graph_stack.append({"variables": _variables})
	var result := execute_graph(sub)
	var saved: Dictionary = _sub_graph_stack.pop_back()
	_variables = saved["variables"]
	return result

## 暂停执行（等待玩家输入或遇到错误）
func halt(level: String, text: String) -> void:
	_log(level, text)
	_halted = true

## 执行单个节点, 返回应走的输出exec端口索引
func _execute_node(node: Dictionary, graph: Dictionary) -> int:
	var node_type: String = node["node_type"]
	# 按 8 大分类分发到 BlueprintNodeHandlers（拆分自本文件的巨型 match）
	var category: int = BlueprintNodeHandlers.dispatch(self, node_type)
	return BlueprintNodeHandlers.run(self, category, node, graph)

# === 内部辅助 ===

## 找执行流后继节点
func _find_exec_successor(graph: Dictionary, node_id: String, port: int) -> Dictionary:
	for conn in graph["connections"]:
		if conn["is_exec"] and conn["from_node"] == node_id and conn["from_port"] == port:
			return {"node_id": conn["to_node"], "port": conn["to_port"]}
	return {}

## 解析数据引脚的布尔输入
func _resolve_input_bool(graph: Dictionary, node: Dictionary, port: int) -> bool:
	var val = _resolve_input_variant(graph, node, port)
	if val is bool:
		return val
	if val is String:
		return val == "true"
	if val is float or val is int:
		return float(val) != 0.0
	return false

## 解析数据引脚的字符串输入
func _resolve_input_string(graph: Dictionary, node: Dictionary, port: int) -> String:
	var val = _resolve_input_variant(graph, node, port)
	return str(val) if val != null else ""

## 解析数据引脚的浮点输入
func _resolve_input_float(graph: Dictionary, node: Dictionary, port: int) -> float:
	var val = _resolve_input_variant(graph, node, port)
	if val is float or val is int:
		return float(val)
	if val is String and str(val).is_valid_float():
		return float(val)
	return 0.0

## 解析数据引脚的Variant输入(沿连线回溯)
func _resolve_input_variant(graph: Dictionary, node: Dictionary, port: int) -> Variant:
	var node_id: String = node["id"]
	# 查找连接到该端口的数据源
	for conn in graph["connections"]:
		if not conn["is_exec"] and conn["to_node"] == node_id and conn["to_port"] == port:
			var src_nid: String = conn["from_node"]
			if not graph["nodes"].has(src_nid):
				continue
			var src_node: Dictionary = graph["nodes"][src_nid]
			match src_node["node_type"]:
				"get_var", "flow_get_var":
					var vname: String = src_node.get("properties", {}).get("var_name", "")
					if _variables.has(vname):
						return _variables[vname]
					if world_state:
						return world_state.get_variable(vname, null)
					return null
				"flow_expression", "expression":
					return src_node.get("properties", {}).get("code", null)
				"eco_get_price":
					var mid: String = src_node.get("properties", {}).get("market_id", "")
					var iid: String = src_node.get("properties", {}).get("item_id", "")
					if economy_engine:
						return economy_engine.get_price(mid, iid)
					return 0.0
				"world_get_faction":
					var fid: String = src_node.get("properties", {}).get("faction_id", "")
					if world_state and world_state.faction_states.has(fid):
						return world_state.faction_states[fid]
					return {}
				"ability_get_info":
					var sid: String = src_node.get("properties", {}).get("skill_id", "")
					if ws_data and ws_data.ability_system:
						return ws_data.ability_system.get_skill(sid)
					return {}
				"ability_calc_damage":
					# 数据源节点: 根据技能公式计算伤害/治疗数值
					var sid: String = src_node.get("properties", {}).get("skill_id", "")
					if ws_data and ws_data.ability_system:
						var skill: Dictionary = ws_data.ability_system.get_skill(sid)
						if not skill.is_empty():
							var base: float = float(skill.get("effect", {}).get("base_value", 0))
							# 按玩家攻击力加成
							var atk: float = float(player_state.get("atk", player_state.get("attack", 0)))
							return base + atk * 0.5
					return 0.0
				"quest_check":
					var qid: String = src_node.get("properties", {}).get("quest_id", "")
					return _quest_state.get(qid, "not_started")
	# 没有连接: 返回引脚默认值
	var inputs: Array = node.get("inputs", [])
	if port < inputs.size():
		return inputs[port].get("default_value", null)
	return null

## 记录日志
func _log(level: String, text: String) -> void:
	_exec_log.append("[%s] %s" % [level, text])
	log_message.emit(level, text)
