## 蓝图校验器
## 校验蓝图图的参数合法性、引用存在性、连接兼容性
class_name BlueprintValidator
extends RefCounted

## 校验级别
const LEVEL_ERROR := "error"
const LEVEL_WARN := "warn"

## 校验整张图, 返回问题列表 [{node_id, level, message}]
static func validate_graph(graph: Dictionary, ws: RefCounted = null) -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	var nodes: Dictionary = graph.get("nodes", {})
	var connections: Array = graph.get("connections", [])

	# 1. 逐节点校验
	for nid in nodes:
		var node: Dictionary = nodes[nid]
		var node_issues := validate_node(node, ws)
		for issue in node_issues:
			issue["node_id"] = nid
			issues.append(issue)

	# 2. 连接校验
	for conn in connections:
		var from_nid: String = conn.get("from_node", "")
		var to_nid: String = conn.get("to_node", "")
		if not nodes.has(from_nid) or not nodes.has(to_nid):
			issues.append({"node_id": from_nid, "level": LEVEL_ERROR, "message": "连线引用了不存在的节点"})
			continue
		var valid: bool = BlueprintData.validate_connection(graph, from_nid, conn["from_port"], to_nid, conn["to_port"])
		if not valid:
			issues.append({"node_id": from_nid, "level": LEVEL_ERROR, "message": "引脚类型不兼容的连线"})

	# 3. 孤立节点检测(无入无出的非start/comment节点)
	for nid in nodes:
		var node: Dictionary = nodes[nid]
		var ntype: String = node["node_type"]
		if ntype == "comment" or ntype == "flow_comment":
			continue
		var has_connection: bool = false
		for conn in connections:
			if conn["from_node"] == nid or conn["to_node"] == nid:
				has_connection = true
				break
		if not has_connection:
			# start/入口节点允许孤立（新建图只有入口是正常状态）
			if ntype == "start" or ntype == "flow_start":
				continue
			issues.append({"node_id": nid, "level": LEVEL_WARN, "message": "孤立节点(未连接任何连线)"})

	# 4. 入口节点检测
	var has_start: bool = false
	for nid in nodes:
		var ntype: String = nodes[nid]["node_type"]
		if ntype == "start" or ntype == "flow_start":
			has_start = true
			break
	if not has_start and not nodes.is_empty():
		issues.append({"node_id": "", "level": LEVEL_WARN, "message": "蓝图中缺少开始节点"})

	return issues

## 校验单个节点, 返回问题列表
static func validate_node(node: Dictionary, ws: RefCounted = null) -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	var node_type: String = node.get("node_type", "")
	var props: Dictionary = node.get("properties", {})

	# 从注册表获取定义
	var def: Dictionary = BlueprintNodeRegistry.get_definition(node_type)
	if def.is_empty():
		# 旧基础节点不做参数校验
		return issues

	# 遍历参数定义进行校验
	for param in def.get("params", []):
		var key: String = param["key"]
		var ptype: String = param.get("type", "string")
		var value: Variant = props.get(key, param.get("default", null))

		# ref类型: 检查引用是否存在于数据池
		if ptype == "ref" and ws != null:
			var ref_id: String = str(value) if value != null else ""
			if ref_id != "":
				var pool_name: String = param.get("ref_pool", "")
				if not _ref_exists(pool_name, ref_id, ws):
					issues.append({"node_id": "", "level": LEVEL_ERROR,
						"message": "%s: 引用 \"%s\" 在数据池中不存在" % [param.get("label", key), ref_id]})

		# int/float类型: 检查范围
		if ptype == "int" and value != null:
			var num_val: int = int(value)
			var min_v: int = int(param.get("min", -999999))
			var max_v: int = int(param.get("max", 999999))
			if num_val < min_v or num_val > max_v:
				issues.append({"node_id": "", "level": LEVEL_ERROR,
					"message": "%s: 值 %d 超出范围 [%d, %d]" % [param.get("label", key), num_val, min_v, max_v]})
			# 数量类参数特殊校验: 不能<=0
			if key.contains("quantity") or key.contains("qty") or key.contains("amount"):
				if num_val <= 0:
					issues.append({"node_id": "", "level": LEVEL_ERROR,
						"message": "%s: 数量必须大于0" % param.get("label", key)})

		if ptype == "float" and value != null:
			var num_val: float = float(value)
			var min_v: float = float(param.get("min", -999999.0))
			var max_v: float = float(param.get("max", 999999.0))
			if num_val < min_v or num_val > max_v:
				issues.append({"node_id": "", "level": LEVEL_ERROR,
					"message": "%s: 值 %.2f 超出范围 [%.2f, %.2f]" % [param.get("label", key), num_val, min_v, max_v]})

	# exec输出引脚无后继(警告)
	var outputs: Array = node.get("outputs", [])
	# 这个需要graph上下文, 在validate_graph中处理更合适

	return issues

## 检查引用ID是否存在于指定数据池
static func _ref_exists(pool_name: String, ref_id: String, ws: RefCounted) -> bool:
	if ws == null:
		return true  # 无数据时跳过校验
	match pool_name:
		"economy_resources":
			if ws.economy_system:
				for r in ws.economy_system.resources:
					if r["id"] == ref_id:
						return true
		"economy_currencies":
			if ws.economy_system:
				for c in ws.economy_system.currencies:
					if c["id"] == ref_id:
						return true
		"economy_markets":
			if ws.economy_system:
				for m in ws.economy_system.markets:
					if m["id"] == ref_id:
						return true
		"ability_skills":
			if ws.ability_system:
				for s in ws.ability_system.skills:
					if s["id"] == ref_id:
						return true
		"ability_status_effects":
			if ws.ability_system:
				for e in ws.ability_system.status_effects:
					if e["id"] == ref_id:
						return true
		"event_story_events":
			if ws.event_system:
				for e in ws.event_system.story_events:
					if e["id"] == ref_id:
						return true
		"event_random_events":
			if ws.event_system:
				for e in ws.event_system.random_events:
					if e["id"] == ref_id:
						return true
		"event_chains":
			if ws.event_system:
				for c in ws.event_system.event_chains:
					if c["id"] == ref_id:
						return true
		"worldview_factions":
			if ws.worldview:
				for f in ws.worldview.factions:
					if f["id"] == ref_id:
						return true
		"worldview_regions":
			if ws.worldview:
				for r in ws.worldview.geography.get("regions", []):
					if r["id"] == ref_id:
						return true
		"worldview_lore":
			if ws.worldview:
				for l in ws.worldview.lore_entries:
					if l["id"] == ref_id:
						return true
		"quest_pool":
			if ws.quest_system:
				for q in ws.quest_system.quests:
					if q["id"] == ref_id:
						return true
		"combat_enemies":
			if ws.combat_system:
				for e in ws.combat_system.enemy_templates:
					if e["id"] == ref_id:
						return true
		"combat_battles":
			if ws.combat_system:
				for b in ws.combat_system.battle_configs:
					if b["id"] == ref_id:
						return true
		"combat_npcs":
			if ws.combat_system:
				for n in ws.combat_system.npc_pool:
					if n["id"] == ref_id:
						return true
		_:
			return true  # 未知池不校验
	return false

## 获取问题的简短摘要(用于状态栏)
static func get_summary(issues: Array[Dictionary]) -> String:
	var errors: int = 0
	var warns: int = 0
	for issue in issues:
		if issue["level"] == LEVEL_ERROR:
			errors += 1
		else:
			warns += 1
	if errors == 0 and warns == 0:
		return "校验通过"
	return "%d 错误, %d 警告" % [errors, warns]
