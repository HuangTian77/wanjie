## GraphStore - 蓝图图注册表（运行时与编辑器共用）
## 图以 key 存储在 WorldScriptData.event_system.blueprint_graphs:
##   - "evt:<event_id>"  事件蓝图图（每个事件一个图, 由事件触发驱动）
##   - "sys:<name>"      剧本级系统图（global 全局入口 / economy 经济 / combat 战斗 / quest 任务 / world 世界）
## key 可任意扩展, 供 flow_sub_graph 子图节点按 key 查找调用
class_name GraphStore
extends RefCounted

const KEY_EVENT := "evt:"
const KEY_SYSTEM := "sys:"

## 事件图 key
static func event_key(event_id: String) -> String:
	return KEY_EVENT + event_id

## 系统图 key
static func system_key(name: String) -> String:
	return KEY_SYSTEM + name

## 判断 key 是否为事件图
static func is_event_key(key: String) -> bool:
	return key.begins_with(KEY_EVENT)

## 从 key 提取事件 id（事件图专用）
static func event_id_from_key(key: String) -> String:
	return key.trim_prefix(KEY_EVENT)

## 取图（不存在返回空字典）
static func get_graph(ws: WorldScriptData, key: String) -> Dictionary:
	if ws == null or ws.event_system == null:
		return {}
	return ws.event_system.blueprint_graphs.get(key, {})

## 存图
static func set_graph(ws: WorldScriptData, key: String, graph: Dictionary) -> void:
	if ws == null or ws.event_system == null:
		return
	ws.event_system.blueprint_graphs[key] = graph

## 是否有图
static func has_graph(ws: WorldScriptData, key: String) -> bool:
	return ws != null and ws.event_system != null and ws.event_system.blueprint_graphs.has(key)

## 删图
static func remove_graph(ws: WorldScriptData, key: String) -> void:
	if ws != null and ws.event_system != null:
		ws.event_system.blueprint_graphs.erase(key)

## 列出全部图 key
static func list_graphs(ws: WorldScriptData) -> Array[String]:
	var result: Array[String] = []
	if ws == null or ws.event_system == null:
		return result
	for key in ws.event_system.blueprint_graphs:
		result.append(key)
	return result

## 列出系统图 key（按名字排序）
static func list_system_keys(ws: WorldScriptData) -> Array[String]:
	var result: Array[String] = []
	for key in list_graphs(ws):
		if is_event_key(key):
			continue
		result.append(key)
	result.sort()
	return result
