## 子系统蓝图测试: 7 个子系统的 🎨 蓝图分支打开、专属图自动创建、加节点/编译可用
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
	var ws := WorldScriptData.new()
	ws.id = "sysbp"
	ws.ensure_subsystems()
	ws.event_system.add_story_event("e1", "事件一", "chain")
	ws.ability_system.initialize_combat_defaults()
	var mock := MockHost.new()
	mock.current_script = ws
	root.add_child(mock)

	var VisualSystemBlueprintClass = load("res://scripts/editor/visual/visual_system_blueprint.gd")
	# 7 个子系统
	var systems := {
		"worldview_blueprint": "sys:worldview",
		"event_blueprint": "sys:event",
		"economy_blueprint": "sys:economy",
		"ability_blueprint": "sys:ability",
		"quest_blueprint": "sys:quest",
		"combat_blueprint": "sys:combat",
		"map_blueprint": "sys:map",
	}
	for sub in systems:
		var sys_key: String = systems[sub]
		var mod = VisualSystemBlueprintClass.new(mock)
		var ctrl = mod.create(sub, {})
		assert(ctrl != null, "%s 应创建控件" % sub)
		mock.add_child(ctrl)
		# 图应自动创建（含 start 节点）
		assert(GraphStore.has_graph(ws, sys_key), "%s 应创建 %s 图" % [sub, sys_key])
		var graph: Dictionary = GraphStore.get_graph(ws, sys_key)
		assert(not graph.get("nodes", {}).is_empty(), "%s 图应含 start 节点" % sub)
		# 加节点 + 编译
		var ws_mod = load("res://scripts/editor/visual/visual_blueprint_workspace.gd").new(mock)
		ws_mod._locked_key = sys_key
		var ws_ui = ws_mod.create(sub, {})
		mock.add_child(ws_ui)
		assert(ws_mod._current_key == sys_key, "锁定模式应固定当前图")
		ws_mod._bp_mod._add_blueprint_node("print")
		ws_mod._compile_current()
		var g2: Dictionary = GraphStore.get_graph(ws, sys_key)
		assert(g2.has("_compiled_code"), "%s 编译产物应写入" % sub)
		ws_ui.free()
		ctrl.free()
	print("PASS 7 个子系统蓝图分支全部可用")
	print("ALL_TESTS_PASSED")
	quit(0)
