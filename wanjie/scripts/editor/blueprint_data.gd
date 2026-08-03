## 蓝图脚本数据模型
## 定义节点/引脚/连线的核心数据结构，以及节点注册表和图操作工具
class_name BlueprintData
extends RefCounted

# === 引脚数据类型枚举 ===
enum PinDataType { EXEC, BOOL, INT, FLOAT, STRING, ANY }

# === 引脚颜色常量 ===
const PIN_COLORS: Dictionary = {
	PinDataType.EXEC: Color(1.0, 1.0, 1.0, 0.9),
	PinDataType.BOOL: Color(0.8, 0.2, 0.2, 1.0),
	PinDataType.INT: Color(0.2, 0.6, 0.8, 1.0),
	PinDataType.FLOAT: Color(0.3, 0.7, 0.3, 1.0),
	PinDataType.STRING: Color(0.8, 0.5, 0.2, 1.0),
	PinDataType.ANY: Color(0.5, 0.5, 0.5, 1.0),
}

# === 节点类型配色 ===
const NODE_COLORS: Dictionary = {
	"start": Color(0.6, 0.15, 0.15, 1.0),
	"branch": Color(0.6, 0.4, 0.1, 1.0),
	"sequence": Color(0.15, 0.35, 0.6, 1.0),
	"get_var": Color(0.2, 0.5, 0.2, 1.0),
	"set_var": Color(0.2, 0.45, 0.55, 1.0),
	"story_event": Color(0.2, 0.4, 0.8, 1.0),
	"print": Color(0.35, 0.35, 0.35, 1.0),
	"expression": Color(0.5, 0.3, 0.5, 1.0),
	"comment": Color(0.25, 0.25, 0.2, 0.6),
	"random_event": Color(0.2, 0.65, 0.3, 1.0),
}

# === 引脚类型名称 ===
const PIN_TYPE_NAMES: Dictionary = {
	PinDataType.EXEC: "Exec",
	PinDataType.BOOL: "bool",
	PinDataType.INT: "int",
	PinDataType.FLOAT: "float",
	PinDataType.STRING: "String",
	PinDataType.ANY: "any",
}

# === 核心数据结构工厂方法 ===

## 创建一个引脚
static func make_pin(p_name: String, p_type: int, p_is_output: bool, p_default: Variant = null) -> Dictionary:
	return {
		"name": p_name,
		"data_type": p_type,
		"is_output": p_is_output,
		"default_value": p_default,
	}

## 创建一个空蓝图图
static func make_graph() -> Dictionary:
	return {
		"nodes": {},
		"connections": [],
		"local_variables": {},
	}

# === 节点注册表 ===

## 根据类型创建预定义节点
static func create_node(node_type: String, pos: Vector2, id_override: String = "") -> Dictionary:
	# 先尝试注册表驱动创建(新节点体系)
	var reg_node: Dictionary = BlueprintNodeRegistry.create_node(node_type, pos, id_override)
	if not reg_node.is_empty():
		return reg_node
	# 回退: 原有基础节点
	var nid: String = id_override if id_override != "" else "bp_%s_%d" % [node_type, Time.get_ticks_msec()]
	var node: Dictionary = {
		"id": nid,
		"node_type": node_type,
		"pos": pos,
		"title": "",
		"color": NODE_COLORS.get(node_type, Color(0.4, 0.4, 0.4, 1.0)),
		"inputs": [],
		"outputs": [],
		"properties": {},
		"comment": "",
	}
	match node_type:
		"start":
			node["title"] = "Event Begin"
			node["outputs"] = [make_pin("exec", PinDataType.EXEC, true)]
		"branch":
			node["title"] = "Branch"
			node["inputs"] = [
				make_pin("exec", PinDataType.EXEC, false),
				make_pin("condition", PinDataType.BOOL, false),
			]
			node["outputs"] = [
				make_pin("True", PinDataType.EXEC, true),
				make_pin("False", PinDataType.EXEC, true),
			]
		"sequence":
			node["title"] = "Sequence"
			node["inputs"] = [make_pin("exec", PinDataType.EXEC, false)]
			node["outputs"] = [
				make_pin("then_0", PinDataType.EXEC, true),
				make_pin("then_1", PinDataType.EXEC, true),
			]
			node["properties"] = { "pin_count": 2 }
		"get_var":
			node["title"] = "Get Variable"
			node["outputs"] = [make_pin("value", PinDataType.ANY, true)]
			node["properties"] = { "var_name": "" }
		"set_var":
			node["title"] = "Set Variable"
			node["inputs"] = [
				make_pin("exec", PinDataType.EXEC, false),
				make_pin("value", PinDataType.ANY, false),
			]
			node["outputs"] = [make_pin("exec", PinDataType.EXEC, true)]
			node["properties"] = { "var_name": "" }
		"story_event":
			node["title"] = "Story Event"
			node["inputs"] = [make_pin("exec", PinDataType.EXEC, false)]
			node["outputs"] = [make_pin("exec", PinDataType.EXEC, true)]
			node["properties"] = { "event_id": "", "event_name": "New Event" }
		"print":
			node["title"] = "Print"
			node["inputs"] = [
				make_pin("exec", PinDataType.EXEC, false),
				make_pin("message", PinDataType.STRING, false),
			]
			node["outputs"] = [make_pin("exec", PinDataType.EXEC, true)]
		"expression":
			node["title"] = "Expression"
			node["inputs"] = [make_pin("exec", PinDataType.EXEC, false)]
			node["outputs"] = [
				make_pin("result", PinDataType.ANY, true),
				make_pin("exec", PinDataType.EXEC, true),
			]
			node["properties"] = { "code": "" }
		"comment":
			node["title"] = "Comment"
			node["color"] = NODE_COLORS["comment"]
			node["properties"] = { "text": "Comment", "size": Vector2(300, 200) }
		"random_event":
			node["title"] = "Random Event"
			node["inputs"] = [make_pin("exec", PinDataType.EXEC, false)]
			node["outputs"] = [make_pin("exec", PinDataType.EXEC, true)]
			node["properties"] = { "event_id": "", "event_name": "New Random Event", "probability": 0.1 }
	return node

## 获取节点类型的可用列表（用于右键菜单）
static func get_available_node_types() -> Array[String]:
	var base: Array[String] = [
		"start", "branch", "sequence",
		"get_var", "set_var",
		"story_event", "random_event", "print", "expression", "comment",
	]
	# 追加注册表中的所有新节点类型
	var reg_types := BlueprintNodeRegistry.get_all_types()
	for rt in reg_types:
		if not base.has(rt):
			base.append(rt)
	return base

## 获取节点类型的中文描述
static func get_node_type_label(node_type: String) -> String:
	match node_type:
		"start": return "事件入口"
		"branch": return "条件分支"
		"sequence": return "序列执行"
		"get_var": return "获取变量"
		"set_var": return "设置变量"
		"story_event": return "剧情事件"
		"print": return "打印输出"
		"expression": return "代码表达式"
		"comment": return "注释框"
		"random_event": return "随机事件"
	# 注册表节点: 返回中文名称
	var def: Dictionary = BlueprintNodeRegistry.get_definition(node_type)
	if not def.is_empty():
		return def["name"]
	return node_type

# === 图操作工具方法 ===

## 添加连线到图
static func add_connection(graph: Dictionary, from_node: String, from_port: int, to_node: String, to_port: int, is_exec: bool) -> void:
	var conn: Dictionary = {
		"from_node": from_node,
		"from_port": from_port,
		"to_node": to_node,
		"to_port": to_port,
		"is_exec": is_exec,
	}
	# 检查是否已存在相同连线
	for existing in graph["connections"]:
		if existing["from_node"] == from_node and existing["from_port"] == from_port and existing["to_node"] == to_node and existing["to_port"] == to_port:
			return
	graph["connections"].append(conn)

## 移除图的连线
static func remove_connection(graph: Dictionary, from_node: String, from_port: int, to_node: String, to_port: int) -> void:
	var to_remove: int = -1
	for i in graph["connections"].size():
		var c: Dictionary = graph["connections"][i]
		if c["from_node"] == from_node and c["from_port"] == from_port and c["to_node"] == to_node and c["to_port"] == to_port:
			to_remove = i
			break
	if to_remove >= 0:
		graph["connections"].remove_at(to_remove)

## 移除涉及指定节点的所有连线
static func remove_node_connections(graph: Dictionary, node_id: String) -> void:
	var to_remove: Array[int] = []
	for i in graph["connections"].size():
		var c: Dictionary = graph["connections"][i]
		if c["from_node"] == node_id or c["to_node"] == node_id:
			to_remove.append(i)
	# 从后往前删除避免索引偏移
	for i in range(to_remove.size() - 1, -1, -1):
		graph["connections"].remove_at(to_remove[i])

## 验证连线是否合法（类型兼容性检查）
static func validate_connection(graph: Dictionary, from_node: String, from_port: int, to_node: String, to_port: int) -> bool:
	if from_node == to_node:
		return false
	if not graph["nodes"].has(from_node) or not graph["nodes"].has(to_node):
		return false
	var fn: Dictionary = graph["nodes"][from_node]
	var tn: Dictionary = graph["nodes"][to_node]
	if from_port < 0 or from_port >= fn["outputs"].size():
		return false
	if to_port < 0 or to_port >= tn["inputs"].size():
		return false
	var out_pin: Dictionary = fn["outputs"][from_port]
	var in_pin: Dictionary = tn["inputs"][to_port]
	# 执行引脚只能连执行引脚
	if out_pin["data_type"] == PinDataType.EXEC:
		return in_pin["data_type"] == PinDataType.EXEC
	if in_pin["data_type"] == PinDataType.EXEC:
		return out_pin["data_type"] == PinDataType.EXEC
	# 数据引脚: ANY 兼容所有类型
	if out_pin["data_type"] == PinDataType.ANY or in_pin["data_type"] == PinDataType.ANY:
		return true
	# 同类型才能连
	return out_pin["data_type"] == in_pin["data_type"]

## 获取节点的执行流后继节点ID列表
static func get_exec_successors(graph: Dictionary, node_id: String) -> Array[String]:
	var result: Array[String] = []
	for conn in graph["connections"]:
		if conn["is_exec"] and conn["from_node"] == node_id:
			result.append(conn["to_node"])
	return result

## 获取节点指定引脚的连接目标
static func get_connected_pin(graph: Dictionary, node_id: String, port: int, is_output: bool) -> Dictionary:
	for conn in graph["connections"]:
		if is_output and conn["from_node"] == node_id and conn["from_port"] == port:
			return { "node_id": conn["to_node"], "port": conn["to_port"] }
		if not is_output and conn["to_node"] == node_id and conn["to_port"] == port:
			return { "node_id": conn["from_node"], "port": conn["from_port"] }
	return {}

## 获取连接到指定节点指定引脚的来源节点
static func get_exec_predecessor(graph: Dictionary, node_id: String) -> String:
	for conn in graph["connections"]:
		if conn["is_exec"] and conn["to_node"] == node_id:
			return conn["from_node"]
	return ""

## 计算节点的动态高度（基于引脚数量）
static func calc_node_height(node: Dictionary) -> float:
	var input_count: int = node["inputs"].size()
	var output_count: int = node["outputs"].size()
	var max_pins: int = maxi(input_count, output_count)
	if node["node_type"] == "comment":
		return float(node["properties"].get("size", Vector2(300, 200)).y)
	# 标题高度 24 + 每个引脚 20px + 底部间距 8
	return 24.0 + max_pins * 20.0 + 8.0

## 获取节点指定引脚的世界坐标位置
static func get_pin_world_pos(node: Dictionary, is_output: bool, port_index: int) -> Vector2:
	var node_pos: Vector2 = node["pos"]
	var _node_height: float = calc_node_height(node)
	var pin_y: float = node_pos.y + 24.0 + 10.0 + port_index * 20.0
	if is_output:
		return Vector2(node_pos.x + 180.0, pin_y)
	else:
		return Vector2(node_pos.x, pin_y)

## 查找所有 start 节点（入口点）
static func find_entry_nodes(graph: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for nid in graph["nodes"]:
		if graph["nodes"][nid]["node_type"] == "start":
			result.append(nid)
	return result

## 声明一个局部变量
static func declare_variable(graph: Dictionary, var_name: String, var_type: int, default_value: Variant = null) -> void:
	graph["local_variables"][var_name] = { "type": var_type, "value": default_value }

## 获取变量声明的GDScript类型字符串
static func get_var_type_string(var_type: int) -> String:
	match var_type:
		PinDataType.BOOL: return "bool"
		PinDataType.INT: return "int"
		PinDataType.FLOAT: return "float"
		PinDataType.STRING: return "String"
		_: return "Variant"

## 获取引脚数据类型的GDScript类型字符串
static func get_pin_type_string(data_type: int) -> String:
	match data_type:
		PinDataType.BOOL: return "bool"
		PinDataType.INT: return "int"
		PinDataType.FLOAT: return "float"
		PinDataType.STRING: return "String"
		_: return "Variant"

## 根据引脚类型过滤兼容的节点类型
## drag_is_output=true 表示从输出引脚拖出，需要找有兼容输入引脚的节点
## drag_is_output=false 表示从输入引脚拖出，需要找有兼容输出引脚的节点
static func get_compatible_node_types(_graph: Dictionary, drag_data_type: int, drag_is_output: bool) -> Array[String]:
	var all_types := get_available_node_types()
	if drag_data_type < 0:
		return all_types
	var result: Array[String] = []
	for nt in all_types:
		var temp := create_node(nt, Vector2.ZERO, "__temp__")
		var compatible := false
		if drag_is_output:
			# 从输出引脚拖出，需要目标节点有兼容的输入引脚
			for inp in temp["inputs"]:
				if _pin_types_compatible(drag_data_type, inp["data_type"]):
					compatible = true
					break
		else:
			# 从输入引脚拖出，需要目标节点有兼容的输出引脚
			for outp in temp["outputs"]:
				if _pin_types_compatible(outp["data_type"], drag_data_type):
					compatible = true
					break
		if compatible:
			result.append(nt)
	return result

## 检查两个引脚类型是否兼容
static func _pin_types_compatible(out_type: int, in_type: int) -> bool:
	if out_type == PinDataType.EXEC:
		return in_type == PinDataType.EXEC
	if in_type == PinDataType.EXEC:
		return out_type == PinDataType.EXEC
	if out_type == PinDataType.ANY or in_type == PinDataType.ANY:
		return true
	return out_type == in_type
