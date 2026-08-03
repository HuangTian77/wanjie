## 临时验证脚本: 拆分后的 visual_event 模块运行时测试
extends SceneTree

func _initialize() -> void:
	var mock := MockHost.new()
	var ws: WorldScriptData = WorldScriptData.new()
	ws.id = "test"
	ws.name = "测试剧本"
	ws.ensure_subsystems()
	ws.event_system.add_story_event("evt_1", "第一个事件", "chain")
	ws.event_system.add_story_event("evt_2", "第二个事件", "chain")
	ws.event_system.add_random_event("revt_1", "随机事件", 0.1)
	ws.event_system.event_chains.append({"id": "chain_1", "name": "链", "events": ["evt_1", "evt_2"]})
	mock.current_script = ws

	var mod = load("res://scripts/editor/visual/visual_event.gd").new(mock)
	var control = mod.create("event", {})
	assert(control != null)
	print("PASS create root ok")

	# L1 切换
	mod._switch_event_layer("l1")
	assert(mod._l1_mod._event_l1_container.visible)
	assert(not mod._event_l3_container.visible)
	print("PASS switch to L1")

	# L1 表单构建（应无运行时错误）
	mod._l1_mod._build_l1_form_view(mod._l1_mod._event_l1_container)
	assert(mod._l1_mod._l1_current_event_id == "evt_1")
	print("PASS L1 form build, current=", mod._l1_mod._l1_current_event_id)

	# 切回 L3
	mod._switch_event_layer("l3")
	assert(mod._event_l3_container.visible)
	print("PASS switch back to L3")

	# 事件列表图同步
	mod._sync_event_list_graph()
	assert(mod._event_list_graph["nodes"].size() == 3)
	assert(mod._event_list_graph["connections"].size() == 1)
	print("PASS event list graph sync")

	# 进入蓝图编辑
	mod._enter_event_blueprint("evt_1")
	assert(mod._bp_view == "event_blueprint")
	var graph = mod._bp_mod._get_active_graph()
	assert(graph["nodes"].size() == 1)
	print("PASS enter blueprint")

	# 添加蓝图节点（走蓝图模块）
	mod._bp_mod._add_blueprint_node("set_var")
	assert(mod._bp_mod._get_active_graph()["nodes"].size() == 2)
	mod._bp_mod._bp_undo()
	assert(mod._bp_mod._get_active_graph()["nodes"].size() == 1)
	mod._bp_mod._bp_redo()
	assert(mod._bp_mod._get_active_graph()["nodes"].size() == 2)
	print("PASS blueprint add/undo/redo")

	# 编译蓝图（验证到 ScriptCodeGen 的链路）
	mod._bp_mod._compile_blueprint()
	print("PASS blueprint compile (no crash)")

	# 返回事件列表
	mod._back_to_event_list()
	assert(mod._bp_view == "event_list")
	print("PASS back to list")

	# 蓝图绘制委托（事件列表视图）
	var canvas: Control = _find_canvas(control)
	assert(canvas != null)
	mod._draw_event_graph(canvas)
	print("PASS draw event graph (list view)")
	# 蓝图视图绘制
	mod._enter_event_blueprint("evt_1")
	mod._draw_event_graph(canvas)
	print("PASS draw event graph (blueprint view)")
	mod._bp_mod._on_blueprint_canvas_input(_make_scroll_event(), canvas)
	print("PASS blueprint canvas input (scroll)")

	control.free()
	print("ALL_TESTS_PASSED")
	quit(0)

## 模拟滚轮事件
func _make_scroll_event() -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_WHEEL_UP
	ev.pressed = true
	ev.position = Vector2(100, 100)
	return ev

## 递归查找画布节点
func _find_canvas(root: Control) -> Control:
	return root.find_child("EventGraphCanvas", true, false)

## 模拟 script_editor host（duck-typed 契约）
class MockHost:
	var current_script = null
	var editor_container = null
	var _ui = null
	var log_lines: Array = []
	func _init():
		editor_container = Node.new()
		_ui = load("res://scripts/editor/editor_ui_factory.gd").new(self)
	func _log_output(msg: String) -> void:
		log_lines.append(msg)
	func _sync_to_code_editor() -> void:
		pass
	func _mark_dirty() -> void:
		pass
	func _build_module_tree() -> void:
		pass
