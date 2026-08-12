## 蓝图节点注册表
## 定义所有蓝图节点的元数据: 分类/中文名/引脚/参数/数据源/执行方式
## 供编辑器(创建菜单/属性面板/校验)和运行时(执行器/代码生成)统一使用
class_name BlueprintNodeRegistry
extends RefCounted

# === 引脚类型常量(与BlueprintData.PinDataType保持一致, 避免循环依赖) ===
const _EXEC: int = 0
const _BOOL: int = 1
const _INT: int = 2
const _FLOAT: int = 3
const _STRING: int = 4
const _ANY: int = 5

# === 编辑模式分级（与 EditorMode 常量数值一致）===
# core=0 简易可见 / advanced=1 详细可见 / expert=2 仅详尽可见
const _MODE_CORE: int = 0
const _MODE_ADVANCED: int = 1
const _MODE_EXPERT: int = 2

# === 分类定义 ===
const CATEGORIES: Dictionary = {
	"flow": {"name": "流程控制", "icon": "⚙", "color": Color(0.4, 0.4, 0.5)},
	"economy": {"name": "经济交易", "icon": "💰", "color": Color(0.2, 0.6, 0.3)},
	"story": {"name": "剧情事件", "icon": "📖", "color": Color(0.2, 0.4, 0.8)},
	"ability": {"name": "技能能力", "icon": "✨", "color": Color(0.6, 0.3, 0.7)},
	"combat": {"name": "战斗系统", "icon": "⚔", "color": Color(0.7, 0.2, 0.2)},
	"world": {"name": "世界势力", "icon": "🌍", "color": Color(0.2, 0.5, 0.6)},
	"player": {"name": "角色玩家", "icon": "🧑", "color": Color(0.5, 0.5, 0.2)},
	"quest": {"name": "任务系统", "icon": "📋", "color": Color(0.6, 0.5, 0.1)},
}

# === 注册表 ===
static var _registry: Dictionary = {}
static var _initialized: bool = false

## 确保注册表已初始化(懒加载)
static func ensure_init() -> void:
	if _initialized:
		return
	_initialized = true
	_register_flow_nodes()
	_register_economy_nodes()
	_register_story_nodes()
	_register_ability_nodes()
	_register_combat_nodes()
	_register_world_nodes()
	_register_player_nodes()
	_register_quest_nodes()

# === 公共API ===

## 获取所有已注册节点类型（可按编辑模式过滤）
static func get_all_types(mode: int = -1) -> Array[String]:
	ensure_init()
	var result: Array[String] = []
	for k in _registry:
		if mode >= 0 and int(_registry[k].get("min_mode", _MODE_ADVANCED)) > mode:
			continue
		result.append(k)
	return result

## 按分类获取节点类型（可按编辑模式过滤）
static func get_types_by_category(category: String, mode: int = -1) -> Array[String]:
	ensure_init()
	var result: Array[String] = []
	for k in _registry:
		if _registry[k]["category"] == category:
			if mode >= 0 and int(_registry[k].get("min_mode", _MODE_ADVANCED)) > mode:
				continue
			result.append(k)
	return result

## 获取分类信息（按模式过滤空分类）
static func get_categories(mode: int = -1) -> Dictionary:
	if mode < 0:
		return CATEGORIES
	var result: Dictionary = {}
	for cat in CATEGORIES:
		if not get_types_by_category(cat, mode).is_empty():
			result[cat] = CATEGORIES[cat]
	return result

## 获取节点定义
static func get_definition(node_type: String) -> Dictionary:
	ensure_init()
	return _registry.get(node_type, {})

## 获取节点中文名（无 title 时显示）
static func get_display_name(node_type: String) -> String:
	ensure_init()
	var def: Dictionary = _registry.get(node_type, {})
	return def.get("name", node_type)

## 中文搜索节点(模糊匹配名称/描述/类型)
static func search_nodes(keyword: String) -> Array[String]:
	ensure_init()
	var result: Array[String] = []
	var kw := keyword.to_lower()
	for k in _registry:
		var def: Dictionary = _registry[k]
		if def["name"].to_lower().contains(kw) or def.get("description", "").to_lower().contains(kw) or k.to_lower().contains(kw):
			result.append(k)
	return result

## 注册表驱动创建节点(生成与BlueprintData.create_node兼容的结构)
## 节点 id 唯一计数器（避免同毫秒同类型节点 id 冲突）
static var _id_counter: int = 0

static func _unique_id(node_type: String) -> String:
	_id_counter += 1
	return "bp_%s_%d_%d" % [node_type, Time.get_ticks_msec(), _id_counter]

static func create_node(node_type: String, pos: Vector2, id_override: String = "") -> Dictionary:
	ensure_init()
	var def: Dictionary = _registry.get(node_type, {})
	if def.is_empty():
		return {}
	var nid: String = id_override if id_override != "" else _unique_id(node_type)
	var inputs: Array = []
	for p in def.get("inputs", []):
		inputs.append(_make_pin(p["name"], p["type"], false, p.get("default", null)))
	var outputs: Array = []
	for p in def.get("outputs", []):
		outputs.append(_make_pin(p["name"], p["type"], true, p.get("default", null)))
	# 构建properties默认值
	var props: Dictionary = {}
	for param in def.get("params", []):
		props[param["key"]] = param.get("default", null)
	return {
		"id": nid,
		"node_type": node_type,
		"pos": pos,
		"title": def["name"],
		"color": def.get("color", CATEGORIES.get(def["category"], {}).get("color", Color(0.4, 0.4, 0.4))),
		"inputs": inputs,
		"outputs": outputs,
		"properties": props,
		"comment": "",
	}

## 获取参数的动态下拉选项(从剧本数据池)
## 返回 [{id, label}] 数组
static func get_param_options(param_def: Dictionary, ws) -> Array:
	var pool_name: String = param_def.get("ref_pool", param_def.get("options_source", ""))
	if pool_name == "" or ws == null:
		# 静态enum选项
		var opts: Array = param_def.get("options", [])
		var result: Array = []
		for o in opts:
			if o is Dictionary:
				result.append(o)
			else:
				result.append({"id": str(o), "label": str(o)})
		return result
	return _query_data_pool(pool_name, ws)

## 查询数据池
static func _query_data_pool(pool_name: String, ws) -> Array:
	var result: Array = []
	match pool_name:
		"economy_resources":
			if ws.economy_system:
				for r in ws.economy_system.resources:
					result.append({"id": r["id"], "label": r.get("name", r["id"])})
		"economy_currencies":
			if ws.economy_system:
				for c in ws.economy_system.currencies:
					result.append({"id": c["id"], "label": c.get("name", c["id"])})
		"economy_markets":
			if ws.economy_system:
				for m in ws.economy_system.markets:
					result.append({"id": m["id"], "label": m.get("name", m["id"])})
		"ability_skills":
			if ws.ability_system:
				for s in ws.ability_system.skills:
					result.append({"id": s["id"], "label": s.get("name", s["id"])})
		"ability_status_effects":
			if ws.ability_system:
				for e in ws.ability_system.status_effects:
					result.append({"id": e["id"], "label": e.get("name", e["id"])})
		"event_story_events":
			if ws.event_system:
				for e in ws.event_system.story_events:
					result.append({"id": e["id"], "label": e.get("name", e["id"])})
		"event_random_events":
			if ws.event_system:
				for e in ws.event_system.random_events:
					result.append({"id": e["id"], "label": e.get("name", e["id"])})
		"event_chains":
			if ws.event_system:
				for c in ws.event_system.event_chains:
					result.append({"id": c["id"], "label": c.get("name", c["id"])})
		"worldview_factions":
			if ws.worldview:
				for f in ws.worldview.factions:
					result.append({"id": f["id"], "label": f.get("name", f["id"])})
		"worldview_regions":
			if ws.worldview:
				for r in ws.worldview.geography.get("regions", []):
					result.append({"id": r["id"], "label": r.get("name", r["id"])})
		"worldview_lore":
			if ws.worldview:
				for l in ws.worldview.lore_entries:
					result.append({"id": l["id"], "label": l.get("title", l["id"])})
		"quest_pool":
			if ws.quest_system:
				for q in ws.quest_system.quests:
					result.append({"id": q["id"], "label": q.get("name", q["id"])})
		"combat_enemies":
			if ws.combat_system:
				for e in ws.combat_system.enemy_templates:
					result.append({"id": e["id"], "label": e.get("name", e["id"])})
		"combat_battles":
			if ws.combat_system:
				for b in ws.combat_system.battle_configs:
					result.append({"id": b["id"], "label": b.get("name", b["id"])})
		"combat_npcs":
			if ws.combat_system:
				for n in ws.combat_system.npc_pool:
					result.append({"id": n["id"], "label": n.get("name", n["id"])})
		"blueprint_graphs":
			# 蓝图图列表（flow_sub_graph 子图选图用）
			if ws.event_system:
				for key in ws.event_system.blueprint_graphs:
					result.append({"id": key, "label": key})
	return result

# === 内部注册辅助 ===

static func _reg(type: String, category: String, cname: String, desc: String,
		inputs: Array, outputs: Array, params: Array, priority: String = "P1", min_mode: int = _MODE_ADVANCED) -> void:
	_registry[type] = {
		"type": type, "category": category, "name": cname, "description": desc,
		"priority": priority, "color": CATEGORIES.get(category, {}).get("color", Color(0.4, 0.4, 0.4)),
		"inputs": inputs, "outputs": outputs, "params": params,
		"min_mode": min_mode,
	}

static func _exec_in() -> Dictionary:
	return {"name": "exec", "type": _EXEC}

static func _exec_out(p_name: String = "exec") -> Dictionary:
	return {"name": p_name, "type": _EXEC}

static func _make_pin(p_name: String, p_type: int, p_is_output: bool, p_default: Variant = null) -> Dictionary:
	return {"name": p_name, "data_type": p_type, "is_output": p_is_output, "default_value": p_default}

static func _pin(p_name: String, p_type: int, _is_out: bool = false) -> Dictionary:
	return {"name": p_name, "type": p_type}

static func _param(key: String, label: String, p_type: String, default: Variant = null, extra: Dictionary = {}) -> Dictionary:
	var p := {"key": key, "label": label, "type": p_type, "default": default}
	p.merge(extra)
	return p

static func _ref_param(key: String, label: String, pool: String, default: String = "") -> Dictionary:
	return {"key": key, "label": label, "type": "ref", "ref_pool": pool, "default": default}

static func _enum_param(key: String, label: String, options: Array, default: String = "") -> Dictionary:
	return {"key": key, "label": label, "type": "enum", "options": options, "default": default}

# === 1. 通用流程控制 (flow) ===
static func _register_flow_nodes() -> void:
	var E := _EXEC
	var B := _BOOL
	var I := _INT
	var F := _FLOAT
	var S := _STRING
	var A := _ANY

	_reg("flow_start", "flow", "开始", "蓝图入口点,执行流的起点",
		[], [_exec_out()],
		[_enum_param("trigger_type", "触发方式", ["manual", "auto", "event"], "manual")], "P0", _MODE_CORE)
	_reg("flow_branch", "flow", "条件分支", "根据布尔条件选择执行路径",
		[_exec_in(), _pin("condition", B)], [_exec_out("true"), _exec_out("false")],
		[], "P0", _MODE_CORE)
	_reg("flow_sequence", "flow", "顺序执行", "依次执行多个输出分支",
		[_exec_in()], [_exec_out("then_0"), _exec_out("then_1")],
		[_param("pin_count", "输出数量", "int", 2, {"min": 2, "max": 8})], "P0", _MODE_CORE)
	_reg("flow_for_loop", "flow", "循环", "重复执行指定次数",
		[_exec_in(), _pin("count", I)], [_exec_out("body"), _exec_out("done"), _pin("index", I)],
		[], "P1")
	_reg("flow_random_select", "flow", "随机选择", "按权重随机选择一条路径执行",
		[_exec_in()], [_exec_out("out_0"), _exec_out("out_1")],
		[_param("branch_count", "分支数", "int", 2, {"min": 2, "max": 6})], "P1")
	_reg("flow_wait", "flow", "等待", "延迟指定秒数后继续执行",
		[_exec_in(), _pin("seconds", F)], [_exec_out()],
		[], "P1", _MODE_CORE)
	_reg("flow_print_log", "flow", "打印日志", "输出调试信息到日志",
		[_exec_in(), _pin("message", S)], [_exec_out()],
		[_enum_param("level", "级别", ["info", "warn", "error"], "info")], "P0", _MODE_CORE)
	_reg("flow_comment", "flow", "注释框", "视觉标注,不影响执行",
		[], [],
		[_param("text", "注释文本", "string", "注释"), _param("size_x", "宽度", "int", 300), _param("size_y", "高度", "int", 200)], "P0", _MODE_CORE)
	_reg("flow_get_var", "flow", "获取变量", "读取世界/局部变量的值",
		[], [_pin("value", A)],
		[_param("var_name", "变量名", "string", "")], "P0", _MODE_CORE)
	_reg("flow_set_var", "flow", "设置变量", "写入世界/局部变量",
		[_exec_in(), _pin("value", A)], [_exec_out()],
		[_param("var_name", "变量名", "string", "")], "P0", _MODE_CORE)
	_reg("flow_expression", "flow", "表达式", "执行自定义GDScript表达式",
		[_exec_in()], [_pin("result", A), _exec_out()],
		[_param("code", "代码", "string", "")], "P1")
	_reg("flow_sub_graph", "flow", "子蓝图", "调用另一张蓝图图",
		[_exec_in()], [_exec_out()],
		[_ref_param("graph_id", "目标图", "blueprint_graphs")], "P2")

# === 2. 经济交易 (economy) ===
static func _register_economy_nodes() -> void:
	var E := _EXEC
	var B := _BOOL
	var I := _INT
	var F := _FLOAT

	_reg("eco_give_item", "economy", "获得物品", "给予玩家指定数量的物品",
		[_exec_in()], [_exec_out(), _pin("success", B)],
		[_ref_param("item_id", "物品", "economy_resources"),
		_param("quantity", "数量", "int", 1, {"min": 1, "max": 9999}),
		_param("to_inventory", "进入背包", "bool", true)], "P0")
	_reg("eco_remove_item", "economy", "付出物品", "从玩家处移除物品",
		[_exec_in()], [_exec_out(), _pin("success", B)],
		[_ref_param("item_id", "物品", "economy_resources"),
		_param("quantity", "数量", "int", 1, {"min": 1, "max": 9999}),
		_param("consume", "是否消耗", "bool", true),
		_param("bind", "是否绑定", "bool", false)], "P0")
	_reg("eco_give_currency", "economy", "获得货币", "给予玩家货币",
		[_exec_in()], [_exec_out()],
		[_ref_param("currency_id", "货币", "economy_currencies"),
		_param("amount", "数量", "int", 10, {"min": 1, "max": 999999})], "P0")
	_reg("eco_spend_currency", "economy", "消耗货币", "扣减玩家货币",
		[_exec_in()], [_exec_out(), _pin("success", B)],
		[_ref_param("currency_id", "货币", "economy_currencies"),
		_param("amount", "数量", "int", 10, {"min": 1, "max": 999999})], "P0")
	_reg("eco_buy", "economy", "市场购买", "在市场中购买物品",
		[_exec_in()], [_exec_out(), _pin("success", B)],
		[_ref_param("market_id", "市场", "economy_markets"),
		_ref_param("item_id", "物品", "economy_resources"),
		_param("quantity", "数量", "int", 1, {"min": 1, "max": 999}),
		_ref_param("currency_id", "支付货币", "economy_currencies")], "P0")
	_reg("eco_sell", "economy", "市场出售", "在市场中出售物品",
		[_exec_in()], [_exec_out(), _pin("success", B)],
		[_ref_param("market_id", "市场", "economy_markets"),
		_ref_param("item_id", "物品", "economy_resources"),
		_param("quantity", "数量", "int", 1, {"min": 1, "max": 999}),
		_ref_param("currency_id", "收入货币", "economy_currencies")], "P1")
	_reg("eco_barter", "economy", "以物易物", "用物品交换另一种物品",
		[_exec_in()], [_exec_out(), _pin("success", B)],
		[_ref_param("give_item", "付出物品", "economy_resources"),
		_param("give_qty", "付出数量", "int", 1, {"min": 1, "max": 999}),
		_ref_param("get_item", "获得物品", "economy_resources"),
		_param("get_qty", "获得数量", "int", 1, {"min": 1, "max": 999}),
		_ref_param("market_id", "市场", "economy_markets")], "P1")
	_reg("eco_set_trade_rule", "economy", "设定交易规则", "修改全局交易规则",
		[_exec_in()], [_exec_out()],
		[_enum_param("rule_key", "规则", ["barter_enabled", "barter_rate", "faction_discount"], "barter_enabled"),
		_param("rule_value", "值", "string", "")], "P2")
	_reg("eco_refresh_price", "economy", "刷新市场价格", "触发市场价格波动",
		[_exec_in()], [_exec_out()],
		[_ref_param("market_id", "市场", "economy_markets")], "P1")
	_reg("eco_adjust_supply", "economy", "调整供需", "修改市场商品的供需参数",
		[_exec_in()], [_exec_out()],
		[_ref_param("market_id", "市场", "economy_markets"),
		_ref_param("item_id", "物品", "economy_resources"),
		_param("demand_delta", "需求变化", "float", 0.0, {"min": -1.0, "max": 1.0}),
		_param("supply_delta", "供给变化", "float", 0.0, {"min": -1.0, "max": 1.0})], "P2")
	_reg("eco_discount", "economy", "给予折扣", "为商品设置临时折扣",
		[_exec_in()], [_exec_out()],
		[_ref_param("market_id", "市场", "economy_markets"),
		_ref_param("item_id", "物品", "economy_resources"),
		_param("discount_pct", "折扣百分比", "float", 10.0, {"min": 1.0, "max": 100.0}),
		_param("duration", "持续回合", "int", 3, {"min": 1, "max": 99})], "P2")
	_reg("eco_get_price", "economy", "查询价格", "获取物品在市场的当前价格",
		[], [_pin("price", F)],
		[_ref_param("market_id", "市场", "economy_markets"),
		_ref_param("item_id", "物品", "economy_resources")], "P1")

# === 3. 剧情事件 (story) ===
static func _register_story_nodes() -> void:
	var E := _EXEC
	var B := _BOOL
	var I := _INT
	var F := _FLOAT
	var S := _STRING
	var A := _ANY

	_reg("story_trigger", "story", "触发剧情事件", "触发指定的剧情事件",
		[_exec_in()], [_exec_out()],
		[_ref_param("event_id", "事件", "event_story_events")], "P0", _MODE_CORE)
	_reg("story_choice", "story", "显示玩家选择", "向玩家展示选项并等待选择",
		[_exec_in()], [_exec_out("choice_0"), _exec_out("choice_1"), _exec_out("choice_2"), _exec_out("choice_3")],
		[_param("choice_0_text", "选项1文本", "string", "选项A"),
		_param("choice_1_text", "选项2文本", "string", "选项B"),
		_param("choice_2_text", "选项3文本", "string", ""),
		_param("choice_3_text", "选项4文本", "string", "")], "P0", _MODE_CORE)
	_reg("story_branch", "story", "进入分支", "根据条件跳转到不同事件",
		[_exec_in(), _pin("condition", B)], [_exec_out("branch_true"), _exec_out("branch_false")],
		[_ref_param("true_event", "满足时事件", "event_story_events"),
		_ref_param("false_event", "不满足时事件", "event_story_events")], "P0")
	_reg("story_set_prereq", "story", "设置前置条件", "为事件设置前置事件要求",
		[_exec_in()], [_exec_out()],
		[_ref_param("event_id", "目标事件", "event_story_events"),
		_ref_param("prereq_event_id", "前置事件", "event_story_events")], "P1")
	_reg("story_record", "story", "记录事件历史", "将事件标记为已触发",
		[_exec_in()], [_exec_out()],
		[_ref_param("event_id", "事件", "event_story_events"),
		_param("mark_id", "标记ID", "string", "")], "P0")
	_reg("story_unlock_lore", "story", "解锁知识条目", "让玩家发现一条知识",
		[_exec_in()], [_exec_out()],
		[_ref_param("lore_id", "知识条目", "worldview_lore")], "P1")
	_reg("story_jump_chain", "story", "跳转事件链", "切换到指定事件链的某个事件",
		[_exec_in()], [_exec_out()],
		[_ref_param("chain_id", "事件链", "event_chains"),
		_ref_param("target_event", "目标事件", "event_story_events")], "P1")
	_reg("story_random", "story", "随机事件抽取", "从事件池中随机触发一个事件",
		[_exec_in()], [_exec_out(), _pin("event_id", S)],
		[_param("probability", "触发概率", "float", 0.3, {"min": 0.0, "max": 1.0})], "P1")
	_reg("story_add_condition", "story", "添加事件条件", "为事件追加触发条件",
		[_exec_in()], [_exec_out()],
		[_ref_param("event_id", "事件", "event_story_events"),
		_enum_param("subject", "主体", ["player", "world", "faction", "time", "location", "history"], "player"),
		_param("field", "字段", "string", "level"),
		_enum_param("operator", "运算符", [">=", "<=", ">", "<", "==", "!="], ">="),
		_param("value", "值", "string", "1")], "P0")
	_reg("story_add_consequence", "story", "添加选择后果", "为事件选项追加后果",
		[_exec_in()], [_exec_out()],
		[_ref_param("event_id", "事件", "event_story_events"),
		_param("choice_idx", "选项索引", "int", 0, {"min": 0, "max": 9}),
		_enum_param("action_type", "动作类型", ["modify_stat", "give_item", "trigger_event", "change_relation", "set_variable"], "modify_stat"),
		_param("target", "目标", "string", "player"),
		_param("effect", "效果", "string", "gold +10")], "P0")
	_reg("story_dialog", "story", "播放对话", "显示NPC对话内容",
		[_exec_in()], [_exec_out()],
		[_param("speaker", "说话者", "string", ""),
		_param("text", "对话文本", "string", ""),
		_param("portrait", "立绘", "string", "")], "P1", _MODE_CORE)
	_reg("story_causal_mark", "story", "添加因果标记", "记录因果关联标记",
		[_exec_in()], [_exec_out()],
		[_param("mark_id", "标记ID", "string", ""),
		_param("intensity", "强度", "float", 1.0, {"min": 0.0, "max": 10.0})], "P1")

# === 4. 技能能力 (ability) ===
static func _register_ability_nodes() -> void:
	var E := _EXEC
	var B := _BOOL
	var I := _INT
	var A := _ANY

	_reg("ability_learn", "ability", "学习技能", "让玩家学会一个技能",
		[_exec_in()], [_exec_out(), _pin("success", B)],
		[_ref_param("skill_id", "技能", "ability_skills")], "P0")
	_reg("ability_upgrade", "ability", "升级技能", "提升技能等级",
		[_exec_in()], [_exec_out(), _pin("success", B)],
		[_ref_param("skill_id", "技能", "ability_skills")], "P1")
	_reg("ability_cast", "ability", "施放技能", "使用技能对目标生效",
		[_exec_in()], [_exec_out(), _pin("result", A)],
		[_ref_param("skill_id", "技能", "ability_skills"),
		_param("target_idx", "目标索引", "int", 0, {"min": 0, "max": 9})], "P0")
	_reg("ability_consume", "ability", "消耗资源", "扣减法力和/或体力",
		[_exec_in()], [_exec_out(), _pin("success", B)],
		[_enum_param("resource_type", "资源类型", ["mana", "stamina", "hp"], "mana"),
		_param("amount", "数量", "int", 10, {"min": 1, "max": 999})], "P1")
	_reg("ability_add_prereq", "ability", "添加技能前置", "为技能设置学习前置条件",
		[_exec_in()], [_exec_out()],
		[_ref_param("skill_id", "技能", "ability_skills"),
		_ref_param("prereq_skill", "前置技能", "ability_skills"),
		_param("req_level", "需求等级", "int", 1, {"min": 1, "max": 99})], "P2")
	_reg("ability_give_buff", "ability", "给予状态效果", "对目标施加状态效果",
		[_exec_in()], [_exec_out()],
		[_ref_param("effect_id", "状态效果", "ability_status_effects"),
		_enum_param("target", "目标", ["self", "enemy"], "self"),
		_param("duration", "持续回合", "int", 3, {"min": 1, "max": 99})], "P1")
	_reg("ability_remove_buff", "ability", "移除状态效果", "移除目标的状态效果",
		[_exec_in()], [_exec_out()],
		[_ref_param("effect_id", "状态效果", "ability_status_effects"),
		_enum_param("target", "目标", ["self", "enemy"], "self")], "P1")
	_reg("ability_calc_damage", "ability", "计算伤害/治疗", "根据技能公式计算数值",
		[], [_pin("value", I)],
		[_ref_param("skill_id", "技能", "ability_skills")], "P2")
	_reg("ability_get_info", "ability", "获取技能信息", "读取技能的详细数据",
		[], [_pin("skill_data", A)],
		[_ref_param("skill_id", "技能", "ability_skills")], "P1")
	_reg("ability_unlock_school", "ability", "解锁学派", "解锁一个技能学派",
		[_exec_in()], [_exec_out()],
		[_enum_param("school", "学派", ["elemental_fire", "elemental_water", "elemental_earth", "elemental_wind", "holy_light", "shadow_dark", "physical_melee", "physical_ranged"], "elemental_fire")], "P2")

# === 5. 战斗系统 (combat) ===
static func _register_combat_nodes() -> void:
	var E := _EXEC
	var B := _BOOL
	var I := _INT
	var F := _FLOAT
	var S := _STRING
	var A := _ANY

	_reg("combat_start", "combat", "开始战斗", "初始化并启动一场战斗",
		[_exec_in()], [_exec_out()],
		[_ref_param("battle_id", "战斗配置", "combat_battles")], "P0")
	_reg("combat_spawn_enemy", "combat", "生成敌人", "向战斗中添加一个敌人",
		[_exec_in()], [_exec_out()],
		[_ref_param("enemy_template", "敌人模板", "combat_enemies"),
		_param("custom_name", "自定义名称", "string", ""),
		_param("hp", "生命值", "int", 50, {"min": 1, "max": 99999}),
		_param("atk", "攻击力", "int", 10, {"min": 1, "max": 9999}),
		_param("def_val", "防御力", "int", 5, {"min": 0, "max": 9999}),
		_enum_param("element", "元素", ["", "fire", "water", "earth", "wind", "light", "dark"], "")], "P0")
	_reg("combat_damage", "combat", "造成伤害", "对目标造成固定伤害",
		[_exec_in()], [_exec_out(), _pin("actual", I)],
		[_enum_param("target", "目标", ["enemy_0", "enemy_1", "enemy_2", "player"], "enemy_0"),
		_param("amount", "伤害值", "int", 10, {"min": 1, "max": 99999}),
		_enum_param("element", "元素", ["", "fire", "water", "earth", "wind", "light", "dark"], "")], "P0")
	_reg("combat_heal", "combat", "治疗目标", "恢复目标生命值",
		[_exec_in()], [_exec_out(), _pin("actual", I)],
		[_enum_param("target", "目标", ["player", "enemy_0", "enemy_1"], "player"),
		_param("amount", "治疗值", "int", 20, {"min": 1, "max": 99999})], "P0")
	_reg("combat_add_buff", "combat", "添加增益/减益", "对目标施加属性修改",
		[_exec_in()], [_exec_out()],
		[_enum_param("target", "目标", ["player", "enemy_0", "enemy_1"], "player"),
		_enum_param("buff_type", "类型", ["buff", "debuff"], "buff"),
		_enum_param("stat", "属性", ["atk", "def", "matk", "mdef", "speed"], "atk"),
		_param("value", "变化值", "int", 5, {"min": 1, "max": 999}),
		_param("duration", "持续回合", "int", 3, {"min": 1, "max": 99})], "P1")
	_reg("combat_remove_buff", "combat", "移除增益/减益", "移除目标身上的效果",
		[_exec_in()], [_exec_out()],
		[_enum_param("target", "目标", ["player", "enemy_0", "enemy_1"], "player"),
		_param("buff_id", "效果ID", "string", "")], "P1")
	_reg("combat_check_end", "combat", "判定战斗胜负", "检查战斗是否结束",
		[_exec_in()], [_exec_out("victory"), _exec_out("defeat"), _exec_out("ongoing")],
		[], "P0")
	_reg("combat_reward", "combat", "战斗奖励", "发放战斗胜利奖励",
		[_exec_in()], [_exec_out()],
		[_param("exp", "经验值", "int", 50, {"min": 0, "max": 99999}),
		_param("gold", "金币", "int", 20, {"min": 0, "max": 99999}),
		_ref_param("item_id", "奖励物品", "economy_resources"),
		_param("item_qty", "物品数量", "int", 1, {"min": 0, "max": 99})], "P0")
	_reg("combat_flee", "combat", "逃跑判定", "尝试逃离战斗",
		[_exec_in()], [_exec_out("success"), _exec_out("fail")],
		[_param("base_chance", "基础概率", "float", 0.5, {"min": 0.0, "max": 1.0})], "P1")
	_reg("combat_set_stats", "combat", "设置战斗属性", "设置参战者的战斗数值",
		[_exec_in()], [_exec_out()],
		[_enum_param("target", "目标", ["player", "enemy_0", "enemy_1"], "player"),
		_param("hp", "HP", "int", 100, {"min": 1, "max": 99999}),
		_param("atk", "ATK", "int", 15, {"min": 1, "max": 9999}),
		_param("def_val", "DEF", "int", 10, {"min": 0, "max": 9999})], "P1")

# === 6. 世界势力 (world) ===
static func _register_world_nodes() -> void:
	var E := _EXEC
	var I := _INT
	var F := _FLOAT
	var A := _ANY

	_reg("world_set_var", "world", "设置世界变量", "将世界变量设为指定值",
		[_exec_in(), _pin("value", A)], [_exec_out()],
		[_param("var_name", "变量名", "string", "")], "P0")
	_reg("world_modify_var", "world", "修改世界变量", "对世界变量进行运算修改",
		[_exec_in()], [_exec_out()],
		[_param("var_name", "变量名", "string", ""),
		_enum_param("op", "运算", ["+", "-", "*", "set"], "+"),
		_param("value", "值", "string", "1")], "P0")
	_reg("world_faction_power", "world", "修改势力实力", "增减势力的综合实力值",
		[_exec_in()], [_exec_out()],
		[_ref_param("faction_id", "势力", "worldview_factions"),
		_param("delta", "变化量", "int", 10, {"min": -999, "max": 999})], "P0")
	_reg("world_faction_relation", "world", "修改势力关系", "修改两个势力间的关系值",
		[_exec_in()], [_exec_out()],
		[_ref_param("faction_a", "势力A", "worldview_factions"),
		_ref_param("faction_b", "势力B", "worldview_factions"),
		_param("delta", "变化量", "float", 0.1, {"min": -1.0, "max": 1.0})], "P0")
	_reg("world_switch_camp", "world", "切换阵营", "将玩家阵营切换到指定势力",
		[_exec_in()], [_exec_out()],
		[_ref_param("faction_id", "势力", "worldview_factions")], "P1")
	_reg("world_update_region", "world", "更新地区状态", "修改地区的状态属性",
		[_exec_in()], [_exec_out()],
		[_ref_param("region_id", "地区", "worldview_regions"),
		_param("state_key", "属性键", "string", ""),
		_param("state_value", "属性值", "string", "")], "P1")
	_reg("world_advance_time", "world", "推进时间", "让游戏世界时间前进",
		[_exec_in()], [_exec_out()],
		[_param("hours", "小时数", "int", 1, {"min": 1, "max": 8760})], "P0")
	_reg("world_add_effect", "world", "添加世界效果", "添加一个有时限的全局效果",
		[_exec_in()], [_exec_out()],
		[_param("effect_id", "效果ID", "string", ""),
		_param("duration", "持续回合", "int", 5, {"min": 1, "max": 999})], "P1")
	_reg("world_get_faction", "world", "获取势力信息", "读取势力的当前状态数据",
		[], [_pin("faction_data", A)],
		[_ref_param("faction_id", "势力", "worldview_factions")], "P1")
	_reg("world_explore_region", "world", "探索区域", "将区域标记为已探索",
		[_exec_in()], [_exec_out()],
		[_ref_param("region_id", "地区", "worldview_regions")], "P1")

# === 7. 角色玩家 (player) ===
static func _register_player_nodes() -> void:
	var E := _EXEC
	var B := _BOOL
	var I := _INT
	var F := _FLOAT

	_reg("player_modify_stat", "player", "修改玩家属性", "增减或设置玩家的基础属性",
		[_exec_in()], [_exec_out()],
		[_enum_param("stat", "属性", ["hp", "mp", "atk", "def", "speed", "level", "exp", "gold"], "hp"),
		_enum_param("op", "操作", ["+", "-", "set"], "+"),
		_param("value", "数值", "int", 10, {"min": -99999, "max": 99999})], "P0")
	_reg("player_give_item", "player", "给予物品", "将物品放入玩家背包",
		[_exec_in()], [_exec_out()],
		[_ref_param("item_id", "物品", "economy_resources"),
		_param("quantity", "数量", "int", 1, {"min": 1, "max": 9999})], "P0")
	_reg("player_remove_item", "player", "移除物品", "从玩家背包移除物品",
		[_exec_in()], [_exec_out(), _pin("success", B)],
		[_ref_param("item_id", "物品", "economy_resources"),
		_param("quantity", "数量", "int", 1, {"min": 1, "max": 9999})], "P0")
	_reg("player_set_capacity", "player", "修改背包容量", "设置玩家背包最大容量",
		[_exec_in()], [_exec_out()],
		[_param("capacity", "容量", "int", 50, {"min": 1, "max": 999})], "P2")
	_reg("player_teleport", "player", "传送玩家", "将玩家传送到指定区域",
		[_exec_in()], [_exec_out()],
		[_ref_param("region_id", "目标区域", "worldview_regions")], "P0")
	_reg("player_set_position", "player", "设置位置", "精确设置玩家坐标",
		[_exec_in()], [_exec_out()],
		[_param("x", "X坐标", "int", 0), _param("y", "Y坐标", "int", 0),
		_ref_param("region_id", "区域", "worldview_regions")], "P1")
	_reg("player_level_exp", "player", "修改等级/经验", "增加经验或设置等级",
		[_exec_in()], [_exec_out(), _pin("leveled_up", B)],
		[_enum_param("mode", "模式", ["add_exp", "set_level", "add_level"], "add_exp"),
		_param("value", "数值", "int", 100, {"min": 1, "max": 999999})], "P0")
	_reg("player_causal_mark", "player", "添加因果标记", "为玩家添加因果关联标记",
		[_exec_in()], [_exec_out()],
		[_param("mark_id", "标记ID", "string", ""),
		_ref_param("from_event", "来源事件", "event_story_events"),
		_param("intensity", "强度", "float", 1.0, {"min": 0.0, "max": 10.0})], "P1")

# === 8. 任务系统 (quest) ===
static func _register_quest_nodes() -> void:
	var E := _EXEC
	var B := _BOOL
	var I := _INT
	var S := _STRING

	_reg("quest_accept", "quest", "接取任务", "让玩家接受一个任务",
		[_exec_in()], [_exec_out(), _pin("success", B)],
		[_ref_param("quest_id", "任务", "quest_pool")], "P0")
	_reg("quest_update_objective", "quest", "更新任务目标", "推进任务目标的进度",
		[_exec_in()], [_exec_out()],
		[_ref_param("quest_id", "任务", "quest_pool"),
		_param("objective_idx", "目标索引", "int", 0, {"min": 0, "max": 9}),
		_param("progress", "进度增量", "int", 1, {"min": 1, "max": 999})], "P0")
	_reg("quest_complete", "quest", "完成任务", "将任务标记为已完成",
		[_exec_in()], [_exec_out()],
		[_ref_param("quest_id", "任务", "quest_pool")], "P0")
	_reg("quest_fail", "quest", "失败任务", "将任务标记为失败",
		[_exec_in()], [_exec_out()],
		[_ref_param("quest_id", "任务", "quest_pool")], "P1")
	_reg("quest_reward", "quest", "发放任务奖励", "给予任务完成奖励",
		[_exec_in()], [_exec_out()],
		[_ref_param("quest_id", "任务", "quest_pool"),
		_param("exp", "经验", "int", 0, {"min": 0, "max": 99999}),
		_param("gold", "金币", "int", 0, {"min": 0, "max": 99999})], "P0")
	_reg("quest_check", "quest", "检查任务状态", "查询任务当前状态",
		[], [_pin("status", S)],
		[_ref_param("quest_id", "任务", "quest_pool")], "P1")
	_reg("quest_add_objective", "quest", "添加任务目标", "为任务追加一个目标",
		[_exec_in()], [_exec_out()],
		[_ref_param("quest_id", "任务", "quest_pool"),
		_param("description", "目标描述", "string", ""),
		_param("target_count", "需求数量", "int", 1, {"min": 1, "max": 999})], "P1")
	_reg("quest_track", "quest", "追踪任务", "将任务设为当前追踪",
		[_exec_in()], [_exec_out()],
		[_ref_param("quest_id", "任务", "quest_pool")], "P2")
