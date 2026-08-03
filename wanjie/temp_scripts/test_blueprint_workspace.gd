## 统一蓝图工作区测试: 图列表/多图管理/画布节点操作/编译/持久化
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
	ws.id = "bp_ws"
	ws.ensure_subsystems()
	ws.event_system.add_story_event("evt_a", "事件A", "chain")
	ws.event_system.add_story_event("evt_b", "事件B", "chain")
	var mock := MockHost.new()
	mock.current_script = ws
	root.add_child(mock)

	var mod = load("res://scripts/editor/visual/visual_blueprint_workspace.gd").new(mock)
	var ui_root = mod.create("blueprint_workspace", {})
	assert(ui_root != null, "workspace 应创建 UI")
	mock.add_child(ui_root)

	# === 1. 默认图与图列表 ===
	assert(mod._current_key == "sys:global", "默认应创建 sys:global 图, 实际: %s" % mod._current_key)
	assert(GraphStore.has_graph(ws, "sys:global"), "默认图应持久化到 GraphStore")
	var keys: Array = GraphStore.list_graphs(ws)
	assert(keys.has("sys:global"), "图列表应包含默认图")
	print("PASS default graph & graph list")

	# === 2. 画布节点操作（复用 VisualEventBlueprint） ===
	var graph: Dictionary = mod._workspace_get_graph()
	assert(graph.get("nodes", {}).is_empty() == false, "默认图应含 start 节点")
	# 通过 _bp_mod 添加节点（走 workspace 模式）
	mod._bp_mod._add_blueprint_node("set_var")
	mod._bp_mod._add_blueprint_node("print")
	var g2: Dictionary = mod._workspace_get_graph()
	assert(g2["nodes"].size() >= 3, "应含 start+set_var+print 节点")
	assert(GraphStore.get_graph(ws, "sys:global").get("nodes", {}).size() >= 3, "节点应持久化到 GraphStore")
	print("PASS canvas node ops via _bp_mod (workspace mode)")

	# === 3. 新建图 + 切换 ===
	var new_count_before: int = GraphStore.list_graphs(ws).size()
	mod._on_new_graph_pressed()
	# 对话框是异步的（需用户输入）, 直接测试底层逻辑: 手动模拟建图
	var key2 := "sys:economy_loop"
	GraphStore.set_graph(ws, key2, BlueprintData.make_graph())
	mod._current_key = key2
	mod._on_graph_switched()
	var g3: Dictionary = mod._workspace_get_graph()
	assert(not g3.is_empty(), "切换后的图应可获取")
	assert(GraphStore.list_graphs(ws).size() == new_count_before + 1, "图列表应新增")
	print("PASS new & switch graph")

	# === 4. 编译（workspace 模式: 产物写入图 _compiled_code） ===
	# 给 economy_loop 图加 start 节点后再编译
	var g4: Dictionary = mod._workspace_get_graph()
	var st := BlueprintData.create_node("start", Vector2(60, 60))
	g4["nodes"][st["id"]] = st
	mod._bp_mod._compile_blueprint()
	var g5: Dictionary = mod._workspace_get_graph()
	assert(g5.has("_compiled_code"), "编译产物应写入图")
	assert(str(g5["_compiled_code"]).find("_blueprint_entry") >= 0, "编译代码应含入口函数")
	print("PASS compile (workspace mode)")

	# === 5. 删除图 ===
	mod._current_key = key2
	mod._on_delete_graph_pressed()
	assert(not GraphStore.has_graph(ws, key2), "删除后图应不存在")
	print("PASS delete graph")

	# === 6. workspace 宿主接口完整性（_bp_mod 依赖） ===
	assert(mod._bp_view == "workspace", "bp_view 应为 workspace")
	assert(mod._editor_container().find_child("EventGraphCanvas", true, false) != null, "画布应按名称可寻")
	assert(mod._editor_container().find_child("EventDetail", true, false) != null, "详情应按名称可寻")
	print("PASS host interface for VisualEventBlueprint")

	print("ALL_TESTS_PASSED")
	quit(0)
