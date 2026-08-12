extends SceneTree
## 编辑器三模式专项测试：EditorMode 单例 / 注册表分级过滤 / 持久化

var _fail := 0

func _check(name: String, cond: bool) -> void:
	if cond:
		print("PASS ", name)
	else:
		print("FAIL ", name)
		_fail += 1

func _initialize() -> void:
	var em: Node = null
	for c in root.get_children():
		if c.name == "EditorMode":
			em = c
			break
	_check("EditorMode autoload 存在", em != null)
	if em == null:
		print("ALL_TESTS_PASSED" if _fail == 0 else "TESTS_FAILED=%d" % _fail)
		quit(0)
		return
	# 三模式常量
	_check("SIMPLE=0", em.SIMPLE == 0)
	_check("DETAILED=1", em.DETAILED == 1)
	_check("EXHAUSTIVE=2", em.EXHAUSTIVE == 2)
	_check("模式名 3 个", em.MODE_NAMES.size() == 3)
	# 默认详细模式
	_check("默认详细", em.current_mode == em.DETAILED)
	# is_visible 过滤
	_check("简易不可见 advanced", em.is_visible(em.FIELD_ADVANCED) == false if em.current_mode == em.SIMPLE else true)
	em.set_mode(em.SIMPLE)
	_check("切简易 is_visible(core)", em.is_visible(em.FIELD_CORE))
	_check("切简易 隐藏 advanced", not em.is_visible(em.FIELD_ADVANCED))
	_check("切简易 is_simple", em.is_simple())
	# 注册表分级过滤（静态类）
	var flow_simple: Array = BlueprintNodeRegistry.get_types_by_category("flow", em.SIMPLE)
	_check("flow 简易含 start", flow_simple.has("flow_start"))
	_check("flow 简易不含 expression", not flow_simple.has("flow_expression"))
	var flow_all: Array = BlueprintNodeRegistry.get_types_by_category("flow", em.EXHAUSTIVE)
	_check("flow 详尽含 expression", flow_all.has("flow_expression"))
	_check("flow 详尽 > 简易", flow_all.size() >= flow_simple.size())
	var cats_simple: Dictionary = BlueprintNodeRegistry.get_categories(em.SIMPLE)
	_check("分类过滤后 flow 存在", cats_simple.has("flow"))
	# 持久化
	em.set_mode(em.EXHAUSTIVE)
	_check("切详尽 is_exhaustive", em.is_exhaustive())
	# 注册表全面分级断言
	var all_simple: Array = BlueprintNodeRegistry.get_all_types(em.SIMPLE)
	var all_full: Array = BlueprintNodeRegistry.get_all_types(em.EXHAUSTIVE)
	_check("简易类型数 < 详尽", all_simple.size() < all_full.size())
	_check("简易不含表达式", not all_simple.has("flow_expression"))
	_check("简易不含贸易规则", not all_simple.has("eco_set_trade_rule"))
	_check("简易不含战斗设值", not all_simple.has("combat_set_stats"))
	_check("简易不含势力关系", not all_simple.has("world_faction_relation"))
	_check("简易不含任务失败", not all_simple.has("quest_fail"))
	_check("简易含开始", all_simple.has("flow_start"))
	_check("简易含对话", all_simple.has("story_dialog"))
	_check("详尽含全部 expert", all_full.has("flow_expression") and all_full.has("eco_set_trade_rule"))
	# expert 节点数量（31 个标记）
	var expert_count := 0
	for t in BlueprintNodeRegistry.get_all_types(-1):
		var d: Dictionary = BlueprintNodeRegistry.get_definition(t)
		if int(d.get("min_mode", 1)) >= 2:
			expert_count += 1
	_check("expert 节点 >= 30", expert_count >= 30)
	em.set_mode(em.DETAILED)
	_check("恢复详细", em.current_mode == em.DETAILED)
	print("ALL_TESTS_PASSED" if _fail == 0 else "TESTS_FAILED=%d" % _fail)
	quit(0 if _fail == 0 else 1)
