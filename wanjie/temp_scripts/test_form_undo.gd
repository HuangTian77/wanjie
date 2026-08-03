## 临时验证脚本: L1 表单撤销/重做测试
extends SceneTree

func _initialize() -> void:
	var mock := MockHost.new()
	var ws := WorldScriptData.new()
	ws.id = "test"
	ws.name = "撤销测试"
	ws.ensure_subsystems()
	ws.event_system.add_story_event("evt_1", "事件一", "chain")
	mock.current_script = ws

	var mod = load("res://scripts/editor/visual/visual_event.gd").new(mock)
	var control = mod.create("event", {})
	mod._switch_event_layer("l1")
	var l1 = mod._l1_mod

	# 初始快照基准
	var event: Dictionary = ws.event_system.story_events[0]
	event["conditions_structured"] = ConditionCompiler.decompile_conditions([])
	var initial_conditions: int = event["conditions_structured"].size()

	# 1. 模拟 UI 添加条件（数据变更 + 重建, 触发差分提交）
	var section := VBoxContainer.new()
	l1._rebuild_conditions_section(section, event)
	event["conditions_structured"].append(ConditionCompiler.make_condition("player", "level", ">=", 1))
	l1._rebuild_conditions_section(section, event)
	assert(event["conditions_structured"].size() == initial_conditions + 1, "添加后应有 1 个条件")
	assert(l1.can_undo_form(), "应可撤销")
	print("PASS add condition committed")

	# 2. 再添加一个条件（第二条历史）
	event["conditions_structured"].append(ConditionCompiler.make_condition("world", "flag", "==", true))
	l1._rebuild_conditions_section(section, event)
	assert(event["conditions_structured"].size() == initial_conditions + 2, "应有 2 个条件")

	# 3. 撤销一次 -> 回到 1 个条件
	var ok: bool = l1.undo_form()
	assert(ok, "撤销应成功")
	assert(ws.event_system.story_events[0]["conditions_structured"].size() == initial_conditions + 1, "撤销后应剩 1 个条件")
	print("PASS undo")

	# 4. 再撤销 -> 回到 0 个条件
	ok = l1.undo_form()
	assert(ok, "二次撤销应成功")
	assert(ws.event_system.story_events[0]["conditions_structured"].size() == initial_conditions, "撤销后应回到初始")
	assert(l1.can_redo_form(), "应可重做")
	print("PASS undo to initial")

	# 5. 重做 -> 1 个条件
	ok = l1.redo_form()
	assert(ok, "重做应成功")
	assert(ws.event_system.story_events[0]["conditions_structured"].size() == initial_conditions + 1, "重做后应恢复 1 个条件")
	print("PASS redo")

	# 6. 撤销后无变化时不产生新历史（重建不污染快照）
	var before_count: int = l1._form_undo.get_action_count()
	l1._build_l1_form_view(l1._event_l1_container)
	assert(l1._form_undo.get_action_count() == before_count, "无变化重建不应新增历史")
	print("PASS no-op rebuild keeps history")

	# 7. 切 L3 再切回 L1, 快照基准重新初始化不报错
	mod._switch_event_layer("l3")
	mod._switch_event_layer("l1")
	print("PASS layer switch with form undo")

	control.free()
	print("ALL_TESTS_PASSED")
	quit(0)

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
