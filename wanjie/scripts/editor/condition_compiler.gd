## 结构化条件/动作编译器
## 可视化编辑器(L1表单/L2规则)与运行时(event_engine)之间的双向投影层
##
## 设计目标(见《可视化编辑器深度研究与设计方案》§5.3/§5.4/§7):
##   - 结构化条件(StructuredCondition): 主体+字段+运算符+值, 可被表单/卡片渲染, 零基础可编辑
##   - 运行时条件: event_engine 消费的 {type, check} 格式 (check 为 "left op right" 字符串)
##   - 双向编译: 结构化 -> 运行时(compile), 运行时 -> 结构化(decompile, 失败则 raw 透传不丢数据)
##
## 数据均为 Dictionary(JSON 可序列化), 与项目其余数据模型(events/blueprint)风格一致
class_name ConditionCompiler
extends RefCounted

# ============================================================
# 一、Schema(供 L1/L2 下拉框与校验使用)
# ============================================================

## 条件主体类型 -> 中文标签
const SUBJECT_TYPES: Dictionary = {
	"player": "玩家",
	"world": "世界",
	"faction": "势力",
	"time": "时间",
	"location": "位置",
	"history": "历史事件",
}

## 玩家常用字段 -> {label, type} (world/faction 字段可由用户自定义, 此处为常见预设)
const PLAYER_FIELDS: Dictionary = {
	"level": {"label": "等级", "type": "int"},
	"gold": {"label": "金币", "type": "int"},
	"hp": {"label": "生命值", "type": "int"},
	"mp": {"label": "法力值", "type": "int"},
	"exp": {"label": "经验值", "type": "int"},
	"region": {"label": "所在区域", "type": "string"},
}

## 时间字段(game_time 的键)
const TIME_FIELDS: Dictionary = {
	"year": {"label": "年", "type": "int"},
	"month": {"label": "月", "type": "int"},
	"day": {"label": "日", "type": "int"},
	"hour": {"label": "时", "type": "int"},
	"minute": {"label": "分", "type": "int"},
}

## 势力常用字段
const FACTION_FIELDS: Dictionary = {
	"power_level": {"label": "综合实力", "type": "int"},
	"treasury": {"label": "国库", "type": "int"},
	"relationship": {"label": "与玩家关系", "type": "float"},
}

## 比较运算符 -> 中文标签
const OPERATORS: Dictionary = {
	">=": "≥",
	"<=": "≤",
	">": ">",
	"<": "<",
	"==": "=",
	"!=": "≠",
	"contains": "包含",
}

## 动作类型 -> 中文标签
const ACTION_TYPES: Dictionary = {
	"modify_stat": "修改数值",
	"give_item": "给予物品",
	"trigger_event": "触发事件",
	"change_relation": "改变关系",
	"set_variable": "设置世界变量",
	"play_dialog": "播放对话",
	"custom": "自定义",
}

## 动作目标类型 -> 中文标签
const TARGET_TYPES: Dictionary = {
	"player": "玩家",
	"world": "世界",
	"faction": "势力",
	"npc": "NPC",
	"market": "市场",
}

# ============================================================
# 二、工厂方法(构造合法的结构化条件/动作)
# ============================================================

## 创建一个叶子条件(原子条件)
static func make_condition(p_subject_type: String, p_field: String, p_operator: String, p_value: Variant, p_subject_id: String = "") -> Dictionary:
	return {
		"cond_version": 1,
		"logic": "leaf",
		"subject_type": p_subject_type,
		"subject_id": p_subject_id,
		"field": p_field,
		"operator": p_operator,
		"value": p_value,
		"structured": true,
		"raw_type": "",
		"raw": "",
	}

## 创建一个逻辑分支条件(and/or/not), children 为子条件数组
static func make_branch(p_logic: String, p_children: Array = []) -> Dictionary:
	return {
		"cond_version": 1,
		"logic": p_logic,
		"children": p_children,
		"structured": true,
	}

## 创建一个结构化动作
static func make_action(p_action_type: String, p_target_type: String, p_target_id: String, p_params: Dictionary) -> Dictionary:
	return {
		"action_version": 1,
		"action_type": p_action_type,
		"target_type": p_target_type,
		"target_id": p_target_id,
		"params": p_params,
		"structured": true,
		"raw_target": "",
		"raw_effect": "",
	}

# ============================================================
# 三、编译: 结构化 -> 运行时格式
# ============================================================

## 编译单个叶子条件为运行时 {type, check}
## 返回空 Dictionary 表示不可编译(逻辑分支/非法主体等)
static func compile_condition(cond: Dictionary) -> Dictionary:
	if cond.get("logic", "leaf") != "leaf":
		return {}
	var subject_type: String = cond.get("subject_type", "")
	var subject_id: String = cond.get("subject_id", "")
	var field: String = cond.get("field", "")
	var op: String = cond.get("operator", "==")
	var value: Variant = cond.get("value", "")
	var value_str: String = _value_to_string(value)

	match subject_type:
		"player":
			if field == "region":
				# 位置条件: engine 的 _check_location 读取 player_state.location.region
				return {"type": "location", "check": "region %s %s" % [op, value_str]}
			return {"type": "player_state", "check": "%s %s %s" % [field, op, value_str]}
		"world":
			return {"type": "world_state", "check": "%s %s %s" % [field, op, value_str]}
		"faction":
			# 势力属性: "faction_id.field" (需 event_engine 支持势力查找)
			return {"type": "world_state", "check": "%s.%s %s %s" % [subject_id, field, op, value_str]}
		"time":
			return {"type": "time", "check": "%s %s %s" % [field, op, value_str]}
		"location":
			return {"type": "location", "check": "region %s %s" % [op, value_str]}
		"history":
			# 历史事件: engine 的 _check_history 解析 event_history.contains("id")
			return {"type": "history", "check": "event_history.contains(\"%s\")" % subject_id}
		_:
			return {}

## 编译一组结构化条件(隐式 AND, 与 engine 的条件列表语义一致)为运行时数组
## 跳过不可编译的项(逻辑分支等); 每项为叶子或 and 分支(and 会被展平)
static func compile_conditions(conds: Array) -> Array:
	var result: Array = []
	for c in conds:
		if not (c is Dictionary):
			continue
		var logic: String = c.get("logic", "leaf")
		if logic == "and":
			# and 分支: 展平子条件
			for child in c.get("children", []):
				var compiled: Dictionary = compile_condition(child)
				if not compiled.is_empty():
					result.append(compiled)
		else:
			var compiled: Dictionary = compile_condition(c)
			if not compiled.is_empty():
				result.append(compiled)
	return result

## 编译单个结构化动作为运行时后果 {target, effect}
static func compile_action(action: Dictionary) -> Dictionary:
	var action_type: String = action.get("action_type", "")
	var target_type: String = action.get("target_type", "")
	var target_id: String = action.get("target_id", "")
	var params: Dictionary = action.get("params", {})

	match action_type:
		"modify_stat":
			# params: {field, op(+/-), value}
			var field: String = params.get("field", "")
			var op: String = params.get("op", "+")
			var value: Variant = params.get("value", 0)
			var target: String = target_id if target_id != "" else target_type
			return {"target": target, "effect": "%s %s%s" % [field, op, _value_to_string(value)]}
		"give_item":
			# params: {item_id, quantity}
			var item_id: String = params.get("item_id", "")
			var qty: int = int(params.get("quantity", 1))
			var target: String = target_id if target_id != "" else target_type
			if qty > 1:
				return {"target": target, "effect": "receive %s x%d" % [item_id, qty]}
			return {"target": target, "effect": "receive %s" % item_id}
		"trigger_event":
			# params: {event_id}
			return {"target": "world", "effect": "trigger %s" % params.get("event_id", "")}
		"change_relation":
			# params: {delta}; target_id 为势力ID
			var delta: Variant = params.get("delta", 0)
			var sign: String = "+" if float(delta) >= 0 else ""
			return {"target": target_id, "effect": "relationship %s%s" % [sign, _value_to_string(delta)]}
		"set_variable":
			# params: {var_name, value}
			return {"target": "world", "effect": "set %s = %s" % [params.get("var_name", ""), _value_to_string(params.get("value", ""))]}
		"play_dialog":
			# params: {dialog_id}
			return {"target": target_id if target_id != "" else "npc", "effect": "dialog %s" % params.get("dialog_id", "")}
		"custom":
			# params: {text}
			return {"target": target_id if target_id != "" else target_type, "effect": params.get("text", "")}
		_:
			return {}

## 编译一组结构化动作为运行时后果数组
static func compile_actions(actions: Array) -> Array:
	var result: Array = []
	for a in actions:
		if a is Dictionary:
			var compiled: Dictionary = compile_action(a)
			if not compiled.is_empty():
				result.append(compiled)
	return result

# ============================================================
# 四、反编译: 运行时格式 -> 结构化 (失败则 raw 透传)
# ============================================================

## 反编译运行时条件 {type, check} 为结构化条件
## 解析失败时返回 structured=false 的透传条件(保留 raw, 不丢数据)
static func decompile_condition(runtime: Dictionary) -> Dictionary:
	var cond_type: String = runtime.get("type", "")
	var check: String = runtime.get("check", "")

	# 历史事件: event_history.contains("id")
	if cond_type == "history" and check.begins_with("event_history.contains("):
		var event_id: String = check.trim_prefix("event_history.contains(\"").trim_suffix("\")")
		var cond := make_condition("history", "", "contains", "", event_id)
		return cond

	# 其余类型: 解析 "left op right"
	var parts: Array = _parse_check(check)
	if parts.is_empty():
		return _raw_condition(cond_type, check)

	var left: String = parts[0]
	var op: String = parts[1]
	var right: String = parts[2]
	var value: Variant = _string_to_value(right)

	match cond_type:
		"player_state":
			return make_condition("player", left, op, value)
		"world_state":
			# 势力属性: "faction_id.field"
			if left.contains("."):
				var dot: int = left.find(".")
				var fid: String = left.substr(0, dot)
				var fkey: String = left.substr(dot + 1)
				return make_condition("faction", fkey, op, value, fid)
			return make_condition("world", left, op, value)
		"time":
			return make_condition("time", left, op, value)
		"location":
			return make_condition("location", "region", op, value)
		_:
			return _raw_condition(cond_type, check)

## 反编译一组运行时条件为结构化条件数组
static func decompile_conditions(runtime_conds: Array) -> Array:
	var result: Array = []
	for rc in runtime_conds:
		if rc is Dictionary:
			result.append(decompile_condition(rc))
	return result

## 反编译运行时后果 {target, effect} 为结构化动作(尽力解析, 失败则 raw 透传)
static func decompile_action(consequence: Dictionary) -> Dictionary:
	var target: String = consequence.get("target", "")
	var effect: String = consequence.get("effect", "")

	# receive item [xN]
	if effect.begins_with("receive "):
		var rest: String = effect.trim_prefix("receive ")
		var item_id: String = rest
		var qty: int = 1
		var x_pos: int = rest.rfind(" x")
		if x_pos > 0:
			var qty_str: String = rest.substr(x_pos + 2)
			if qty_str.is_valid_int():
				qty = int(qty_str)
				item_id = rest.substr(0, x_pos)
		return make_action("give_item", "player", target, {"item_id": item_id, "quantity": qty})

	# trigger event_id
	if effect.begins_with("trigger "):
		return make_action("trigger_event", "world", "", {"event_id": effect.trim_prefix("trigger ")})

	# relationship +N / -N
	if effect.begins_with("relationship "):
		var delta_str: String = effect.trim_prefix("relationship ")
		return make_action("change_relation", "faction", target, {"delta": _string_to_value(delta_str)})

	# set var = value
	if effect.begins_with("set "):
		var rest: String = effect.trim_prefix("set ")
		var eq_pos: int = rest.find(" = ")
		if eq_pos > 0:
			var var_name: String = rest.substr(0, eq_pos)
			var value: Variant = _string_to_value(rest.substr(eq_pos + 3))
			return make_action("set_variable", "world", "", {"var_name": var_name, "value": value})

	# dialog id
	if effect.begins_with("dialog "):
		return make_action("play_dialog", "npc", target, {"dialog_id": effect.trim_prefix("dialog ")})

	# "field +N" / "field -N" (修改数值)
	for op in ["+", "-"]:
		var op_pos: int = effect.find(" " + op)
		if op_pos > 0:
			var field: String = effect.substr(0, op_pos).strip_edges()
			var value_str: String = effect.substr(op_pos + 2).strip_edges()
			if field != "" and (value_str.is_valid_float() or value_str.is_valid_int()):
				return make_action("modify_stat", "player", target, {"field": field, "op": op, "value": _string_to_value(value_str)})

	# 无法识别: raw 透传
	return {
		"action_version": 1,
		"action_type": "custom",
		"target_type": "custom",
		"target_id": target,
		"params": {"text": effect},
		"structured": false,
		"raw_target": target,
		"raw_effect": effect,
	}

## 反编译一组运行时后果为结构化动作数组
static func decompile_actions(consequences: Array) -> Array:
	var result: Array = []
	for c in consequences:
		if c is Dictionary:
			result.append(decompile_action(c))
	return result

# ============================================================
# 五、人类可读描述(L1/L2 UI 展示)与校验
# ============================================================

## 生成条件的中文描述, 如 "玩家 等级 ≥ 5" / "势力 faction_001 综合实力 > 70"
static func describe_condition(cond: Dictionary) -> String:
	if not cond.get("structured", true):
		return "[高级] %s" % cond.get("raw", "")
	if cond.get("logic", "leaf") != "leaf":
		var logic: String = cond.get("logic", "and")
		var parts: Array = []
		for child in cond.get("children", []):
			parts.append(describe_condition(child))
		var joiner: String = " 且 " if logic == "and" else (" 或 " if logic == "or" else " 非 ")
		return "(" + joiner.join(parts) + ")"

	var subject_type: String = cond.get("subject_type", "")
	var subject_id: String = cond.get("subject_id", "")
	var field: String = cond.get("field", "")
	var op: String = cond.get("operator", "==")
	var value: Variant = cond.get("value", "")
	var subject_label: String = SUBJECT_TYPES.get(subject_type, subject_type)
	var op_label: String = OPERATORS.get(op, op)
	var field_label: String = _field_label(subject_type, field)

	match subject_type:
		"faction":
			return "%s %s %s %s %s" % [subject_label, subject_id, field_label, op_label, str(value)]
		"history":
			return "已发生事件 \"%s\"" % subject_id
		_:
			return "%s %s %s %s" % [subject_label, field_label, op_label, str(value)]

## 生成动作的中文描述, 如 "玩家 金币 +50"
static func describe_action(action: Dictionary) -> String:
	if not action.get("structured", true):
		return "[高级] %s: %s" % [action.get("raw_target", ""), action.get("raw_effect", "")]
	var action_type: String = action.get("action_type", "")
	var target_type: String = action.get("target_type", "")
	var target_id: String = action.get("target_id", "")
	var params: Dictionary = action.get("params", {})
	var target_label: String = TARGET_TYPES.get(target_type, target_type)
	if target_id != "":
		target_label = target_id

	match action_type:
		"modify_stat":
			return "%s %s %s%s" % [target_label, _field_label("player", params.get("field", "")), params.get("op", "+"), str(params.get("value", 0))]
		"give_item":
			return "给予 %s ×%s" % [params.get("item_id", ""), str(params.get("quantity", 1))]
		"trigger_event":
			return "触发事件 %s" % params.get("event_id", "")
		"change_relation":
			return "%s 关系 %s%s" % [target_label, "+" if float(params.get("delta", 0)) >= 0 else "", str(params.get("delta", 0))]
		"set_variable":
			return "设置 %s = %s" % [params.get("var_name", ""), str(params.get("value", ""))]
		"play_dialog":
			return "播放对话 %s" % params.get("dialog_id", "")
		"custom":
			return params.get("text", "")
		_:
			return action_type

## 校验条件合法性, 返回 {"valid": bool, "error": String}
static func validate_condition(cond: Dictionary) -> Dictionary:
	if not cond.get("structured", true):
		return {"valid": true, "error": ""}  # raw 透传条件不校验
	if cond.get("logic", "leaf") != "leaf":
		var children: Array = cond.get("children", [])
		if children.is_empty():
			return {"valid": false, "error": "逻辑分支缺少子条件"}
		for child in children:
			var sub: Dictionary = validate_condition(child)
			if not sub["valid"]:
				return sub
		return {"valid": true, "error": ""}

	var subject_type: String = cond.get("subject_type", "")
	if not SUBJECT_TYPES.has(subject_type):
		return {"valid": false, "error": "未知的条件主体类型: %s" % subject_type}
	if subject_type == "history":
		if cond.get("subject_id", "") == "":
			return {"valid": false, "error": "历史条件缺少事件ID"}
		return {"valid": true, "error": ""}
	if subject_type == "faction" and cond.get("subject_id", "") == "":
		return {"valid": false, "error": "势力条件缺少势力ID"}
	if cond.get("field", "") == "":
		return {"valid": false, "error": "条件缺少字段"}
	if not OPERATORS.has(cond.get("operator", "")):
		return {"valid": false, "error": "未知的运算符: %s" % cond.get("operator", "")}
	return {"valid": true, "error": ""}

## 校验动作合法性, 返回 {"valid": bool, "error": String}
static func validate_action(action: Dictionary) -> Dictionary:
	if not action.get("structured", true):
		return {"valid": true, "error": ""}
	if not ACTION_TYPES.has(action.get("action_type", "")):
		return {"valid": false, "error": "未知的动作类型: %s" % action.get("action_type", "")}
	return {"valid": true, "error": ""}

# ============================================================
# 六、内部辅助
# ============================================================

## 构造 raw 透传条件(反编译失败时使用, 保证不丢数据)
static func _raw_condition(cond_type: String, check: String) -> Dictionary:
	return {
		"cond_version": 1,
		"logic": "leaf",
		"subject_type": "",
		"subject_id": "",
		"field": "",
		"operator": "",
		"value": null,
		"structured": false,
		"raw_type": cond_type,
		"raw": check,
	}

## 解析 "left op right" 字符串(与 event_engine._parse_expression 保持一致)
static func _parse_check(check: String) -> Array:
	for op in [">=", "<=", "!=", "==", ">", "<"]:
		var idx: int = check.find(op)
		if idx > 0:
			return [check.substr(0, idx).strip_edges(), op, check.substr(idx + op.length()).strip_edges()]
	return []

## Variant -> 表达式字符串
static func _value_to_string(value: Variant) -> String:
	if value is bool:
		return "true" if value else "false"
	return str(value)

## 表达式字符串 -> Variant (反编译时恢复类型)
static func _string_to_value(s: String) -> Variant:
	if s == "true":
		return true
	if s == "false":
		return false
	if s.is_valid_int():
		return int(s)
	if s.is_valid_float():
		return float(s)
	return s

## 获取字段的中文标签(未知字段原样返回)
static func _field_label(subject_type: String, field: String) -> String:
	var table: Dictionary = {}
	match subject_type:
		"player":
			table = PLAYER_FIELDS
		"time":
			table = TIME_FIELDS
		"faction":
			table = FACTION_FIELDS
	if table.has(field):
		return table[field]["label"]
	return field
