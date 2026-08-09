## 事件引擎
## 管理剧本运行中的事件触发、选择处理和因果追踪
extends RefCounted

## 信号
signal event_triggered(event_data: Dictionary)
signal choices_presented(choices: Array)
signal choice_made(event_id: String, choice_id: String)

## 引用
var event_system: EventSystemData = null
var world_state: RefCounted = null  # WorldState
var player_state: Dictionary = {}

## 事件历史
var triggered_events: Array[Dictionary] = []
var choices_history: Array[Dictionary] = []
## 因果标记
var causal_marks: Array[Dictionary] = []
## 当前等待选择的事件
var pending_event: Dictionary = {}
## 已触发事件ID集合（防止重复）
var triggered_ids: Dictionary = {}
## 冷却中的随机事件 {event_id: remaining_cooldown}
var cooldowns: Dictionary = {}

func _init(es: EventSystemData = null, ws: RefCounted = null, ps: Dictionary = {}) -> void:
	event_system = es
	world_state = ws
	player_state = ps

## 外部初始化接口
func init(es: EventSystemData, ws: RefCounted, ps: Dictionary) -> void:
	event_system = es
	world_state = ws
	player_state = ps

## 从存档恢复
func load_history(history: Dictionary) -> void:
	triggered_events.assign(Array(history.get("events_triggered", []), TYPE_DICTIONARY, "", null))
	choices_history.assign(Array(history.get("choices_history", []), TYPE_DICTIONARY, "", null))
	causal_marks.assign(Array(history.get("causal_marks", []), TYPE_DICTIONARY, "", null))
	for te in triggered_events:
		triggered_ids[te.get("event_id", "")] = true

## 序列化为字典
func to_dict() -> Dictionary:
	return {
		"events_triggered": triggered_events,
		"choices_history": choices_history,
		"causal_marks": causal_marks,
		"branch_points": []
	}

## 检查所有可触发事件
func check_triggerable_events() -> Array[Dictionary]:
	if event_system == null:
		return []
	var result: Array[Dictionary] = []
	for e in event_system.story_events:
		if not e.get("is_active", true):
			continue
		if triggered_ids.has(e["id"]):
			continue
		if _check_conditions(e):
			result.append(e)
	return result

## 触发一个事件
func trigger_event(event: Dictionary) -> void:
	pending_event = event
	triggered_ids[event["id"]] = true
	triggered_events.append({
		"event_id": event["id"],
		"triggered_at": world_state.get_time_display() if world_state else "",
		"choice_made": "",
		"consequences_applied": []
	})
	event_triggered.emit(event)
	var choices: Array = event.get("choices", [])
	if not choices.is_empty():
		choices_presented.emit(choices)

## 标记事件已触发（蓝图驱动路径使用: 记录触发历史供条件依赖, 不 emit 传统信号）
func mark_triggered(event: Dictionary) -> void:
	triggered_ids[event["id"]] = true
	triggered_events.append({
		"event_id": event["id"],
		"triggered_at": world_state.get_time_display() if world_state else "",
		"choice_made": "",
		"consequences_applied": []
	})

## 玩家做出选择
func make_choice(choice_id: String) -> Array[Dictionary]:
	if pending_event.is_empty():
		return []
	var consequences: Array[Dictionary] = []
	for c in pending_event.get("choices", []):
		if c["id"] == choice_id:
			consequences.assign(Array(c.get("consequences", []), TYPE_DICTIONARY, "", null))
			break

	# 记录选择
	choices_history.append({
		"event_id": pending_event["id"],
		"choice_id": choice_id,
		"timestamp": world_state.get_time_display() if world_state else "",
		"day": world_state.get_current_day() if world_state else 1
	})

	# 添加因果标记
	causal_marks.append({
		"id": "chose_%s_%s" % [pending_event["id"], choice_id],
		"from_event": pending_event["id"],
		"intensity": 1.0
	})

	# 更新触发记录
	for te in triggered_events:
		if te.get("event_id", "") == pending_event["id"]:
			te["choice_made"] = choice_id
			te["consequences_applied"] = consequences
			break

	choice_made.emit(pending_event["id"], choice_id)
	pending_event = {}
	return consequences

## 检查事件条件是否满足
func _check_conditions(event: Dictionary) -> bool:
	# 检查前置事件
	var prereq: String = event.get("prerequisite", "")
	if not prereq.is_empty() and not triggered_ids.has(prereq):
		return false

	# 检查条件列表
	for cond in event.get("conditions", []):
		if not _evaluate_condition(cond):
			return false
	return true

## 评估单个条件
func _evaluate_condition(cond: Dictionary) -> bool:
	var cond_type: String = cond.get("type", "")
	var check: String = cond.get("check", "")

	match cond_type:
		"world_state":
			return _check_world_state(check)
		"player_state":
			return _check_player_state(check)
		"time":
			return _check_time_condition(check)
		"location":
			return _check_location(check)
		"history":
			return _check_history(check)
		_:
			return true  # 未知条件类型默认通过

## 条件评估辅助方法
func _check_world_state(check: String) -> bool:
	# 简单解析: "variable == value" 或 "variable > value"
	# 支持势力属性: "faction_id.field op value" (先查世界变量, 未命中再查势力状态)
	var parts := _parse_expression(check)
	if parts.is_empty():
		return true
	var var_name: String = parts[0]
	var op: String = parts[1]
	var value_str: String = parts[2]
	var actual = world_state.get_variable(var_name, null) if world_state else null
	if actual == null and var_name.contains(".") and world_state:
		var dot_pos := var_name.find(".")
		var faction_id := var_name.substr(0, dot_pos)
		var field_key := var_name.substr(dot_pos + 1)
		if world_state.faction_states.has(faction_id):
			actual = world_state.faction_states[faction_id].get(field_key, null)
	return _compare(actual, op, value_str)

func _check_player_state(check: String) -> bool:
	var parts := _parse_expression(check)
	if parts.is_empty():
		return true
	var var_name: String = parts[0]
	var op: String = parts[1]
	var value_str: String = parts[2]
	var actual = player_state.get(var_name, null)
	if actual == null:
		# 尝试嵌套属性
		var dot_pos := var_name.find(".")
		if dot_pos > 0:
			var parent_key := var_name.substr(0, dot_pos)
			var child_key := var_name.substr(dot_pos + 1)
			actual = player_state.get(parent_key, {}).get(child_key, null)
	return _compare(actual, op, value_str)

func _check_time_condition(check: String) -> bool:
	if world_state == null:
		return true
	var parts := _parse_expression(check)
	if parts.is_empty():
		return true
	var time_key: String = parts[0]
	var op: String = parts[1]
	var value: int = int(parts[2])
	var actual: int = int(world_state.game_time.get(time_key, 0))
	return _compare(actual, op, str(value))

func _check_location(check: String) -> bool:
	var parts := _parse_expression(check)
	if parts.is_empty():
		return true
	var actual = player_state.get("location", {}).get("region", "")
	return _compare(actual, parts[1], parts[2])

func _check_history(check: String) -> bool:
	# "event_history.contains(\"story_001\")"
	if check.begins_with("event_history.contains("):
		var event_id := check.trim_prefix("event_history.contains(\"").trim_suffix("\")")
		return triggered_ids.has(event_id)
	return true

func _parse_expression(expr: String) -> Array[String]:
	var result: Array[String] = []
	# 尝试分割 "left op right"
	for op in [">=", "<=", "!=", "==", ">", "<"]:
		var idx := expr.find(op)
		if idx > 0:
			result.append(expr.substr(0, idx).strip_edges())
			result.append(op)
			result.append(expr.substr(idx + op.length()).strip_edges())
			return result
	return result

func _compare(actual: Variant, op: String, expected_str: String) -> bool:
	if actual == null:
		return false
	# 尝试数值比较
	var expected_num := float(expected_str) if expected_str.is_valid_float() else 0.0
	var actual_num := float(actual) if str(actual).is_valid_float() else -99999.0
	if str(actual).is_valid_float() and expected_str.is_valid_float():
		match op:
			">": return actual_num > expected_num
			"<": return actual_num < expected_num
			">=": return actual_num >= expected_num
			"<=": return actual_num <= expected_num
			"==": return actual_num == expected_num
			"!=": return actual_num != expected_num
	# 字符串比较
	var actual_str := str(actual)
	match op:
		"==": return actual_str == expected_str
		"!=": return actual_str != expected_str
		"in": return expected_str in actual_str
	return false

## 处理随机事件冷却
func tick_cooldowns() -> void:
	var to_remove: Array[String] = []
	for key in cooldowns:
		cooldowns[key] -= 1
		if cooldowns[key] <= 0:
			to_remove.append(key)
	for key in to_remove:
		cooldowns.erase(key)

## 检查随机事件
func check_random_events() -> Dictionary:
	if event_system == null:
		return {}
	for re in event_system.random_events:
		if cooldowns.has(re["id"]):
			continue
		if randf() < re.get("probability", 0.05):
			cooldowns[re["id"]] = 3  # 3回合冷却
			return re
	return {}
