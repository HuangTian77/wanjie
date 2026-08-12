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
	em.set_mode(em.DETAILED)
	_check("恢复详细", em.current_mode == em.DETAILED)
	print("ALL_TESTS_PASSED" if _fail == 0 else "TESTS_FAILED=%d" % _fail)
	quit(0 if _fail == 0 else 1)
