## 龙焰纪元世界观蓝图模板测试: 模板应用 → sys:worldview 图存在可执行 → 子页蓝图/表单切换
extends SceneTree

class MockHost extends Node:
	var current_script: WorldScriptData = null
	var _ui = null
	var log_lines: Array = []
	func _init():
		_ui = load("res://scripts/editor/editor_ui_factory.gd").new(self)
	func _log_output(msg: String) -> void:
		log_lines.append(msg)
	func _mark_dirty() -> void:
		pass
	func _sync_to_code_editor() -> void:
		pass
	func _build_module_tree() -> void:
		pass
	func _editor_container() -> Object:
		return self

func _initialize() -> void:
	var ScriptTemplatesClass = load("res://scripts/autoload/script_templates.gd")
	# === 1. 模板定义与分发 ===
	var defs: Array = ScriptTemplatesClass.get_template_defs()
	var ids: Array = defs.map(func(d): return d.get("id", ""))
	assert(ids.has("dragonflame_worldview"), "模板列表应含 dragonflame_worldview")

	var ws := WorldScriptData.new()
	ws.id = "dfw"
	ws.ensure_subsystems()
	assert(ScriptTemplatesClass.apply_template(ws, "dragonflame_worldview"), "模板应应用成功")
	assert(ws.name == "龙焰纪元·世界观蓝图", "模板名应正确")
	# 世界观数据
	assert(ws.worldview.factions.size() == 4, "应有 4 大王国势力")
	assert(ws.worldview.faction_relationships.size() >= 5, "应有势力关系")
	# sys:worldview 图存在且含节点
	assert(GraphStore.has_graph(ws, "sys:worldview"), "应创建 sys:worldview 图")
	var g: Dictionary = GraphStore.get_graph(ws, "sys:worldview")
	assert(g["nodes"].size() >= 15, "模板图应有足够节点, 实际 %d" % g["nodes"].size())
	print("PASS template apply & graph preset (%d nodes)" % g["nodes"].size())

	# === 2. 模板图可执行（初始化世界观） ===
	var ws_rt = load("res://scripts/player/world_state.gd").new()
	ws_rt.initialize_factions(ws.worldview)
	var ee = load("res://scripts/player/event_engine.gd").new()
	ee.init(ws.event_system, ws_rt, {})
	var eco = load("res://scripts/player/economy_engine.gd").new()
	eco.init(ws.economy_system, {}, {"gold": 0})
	var executor = load("res://scripts/player/blueprint_executor.gd").new()
	executor.init_engines(ee, eco, null, ws_rt, {}, ws)
	var result: Dictionary = executor.execute_graph(g)
	assert(result.get("success", false), "世界观蓝图应执行成功: %s" % result.get("error", ""))
	assert(ws_rt.get_variable("world_name", "") == "艾泽兰", "世界名变量应被设置")
	print("PASS blueprint executes (world_name=%s)" % ws_rt.get_variable("world_name", ""))

	# === 3. 子页蓝图化: visual_system_blueprint 蓝图/表单切换 ===
	var mock := MockHost.new()
	mock.current_script = ws
	root.add_child(mock)
	var VisualSystemBlueprintClass = load("res://scripts/editor/visual/visual_system_blueprint.gd")
	var mod = VisualSystemBlueprintClass.new(mock)
	var ctrl = mod.create("worldview_blueprint", {"form_module": "visual_worldview", "form_sub": "worldview_bg"})
	assert(ctrl != null, "蓝图编辑器应创建")
	mock.add_child(ctrl)
	# 蓝图视图默认可见, 表单视图隐藏
	assert(mod._bp_view != null and mod._bp_view.visible, "蓝图视图默认显示")
	assert(mod._form_view != null and not mod._form_view.visible, "表单视图默认隐藏")
	# 切到表单
	var btn: Button = null
	for b in ctrl.find_children("*", "Button", true, false):
		if (b as Button).text == "📝 表单":
			btn = b as Button
			break
	assert(btn != null, "应有表单切换按钮")
	btn.pressed.emit()
	assert(mod._form_view.visible, "切表单后应显示表单视图")
	# 蓝图视图应仍存在（隐藏）
	assert(not mod._bp_view.visible, "蓝图视图应隐藏")
	print("PASS blueprint/form view switch")
	print("ALL_TESTS_PASSED")
	quit(0)
