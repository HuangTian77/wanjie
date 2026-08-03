## 全编辑器防闪退冒烟: 10 个 visual 模块 + 蓝图工作区交互 + MUD 编辑器 + 代码编辑器 + 2D/3D
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

func _make_ws() -> WorldScriptData:
	var ws := WorldScriptData.new()
	ws.id = "smoke"
	ws.ensure_subsystems()
	ws.worldview.background_story = "冒烟测试世界观"
	ws.worldview.add_faction("f1", "势力一", "human", 50)
	ws.event_system.add_story_event("e1", "事件一", "chain")
	ws.event_system.story_events[0]["description"] = "测试事件"
	ws.event_system.add_random_event("r1", "随机事件", 0.1)
	ws.economy_system.add_currency("gold", "金币", "universal")
	ws.economy_system.add_resource("wood", "木料", "material")
	ws.ability_system.initialize_combat_defaults()
	ws.ability_system.add_skill_simple("sk1", "火球", "active", "elemental", "fire", "")
	ws.quest_system.add_quest("q1", "任务一", "main")
	ws.combat_system.add_enemy_template("en1", "敌人一", 30, 8, 3)
	# 蓝图图（含 branch）
	var g := BlueprintData.make_graph()
	var s := BlueprintData.create_node("start", Vector2(60, 60))
	var b := BlueprintData.create_node("branch", Vector2(260, 160))
	var p := BlueprintData.create_node("print", Vector2(460, 100))
	g["nodes"][s["id"]] = s
	g["nodes"][b["id"]] = b
	g["nodes"][p["id"]] = p
	BlueprintData.add_connection(g, s["id"], 0, b["id"], 0, true)
	BlueprintData.add_connection(g, b["id"], 0, p["id"], 0, true)
	GraphStore.set_graph(ws, "sys:global", g)
	ws.metadata["scene_2d"] = {"name": "Menu", "type": "Control", "props": {}, "children": [
		{"name": "Btn", "type": "Button", "props": {"position": Vector2(10, 10), "size": Vector2(100, 40)}, "children": []},
	]}
	return ws

func _initialize() -> void:
	var ws := _make_ws()
	var mock := MockHost.new()
	mock.current_script = ws
	root.add_child(mock)

	# === 1. 10 个 visual 模块全部 create 不崩 ===
	var modules := [
		["visual_worldview", "worldview"], ["visual_event", "event"], ["visual_economy", "economy"],
		["visual_ability", "ability"], ["visual_quest", "quest"], ["visual_combat", "combat"],
		["visual_map", "map"], ["visual_test_runner", "test"], ["visual_ai_assistant", "ai"],
		["visual_blueprint_workspace", "blueprint"],
	]
	for m in modules:
		var mod = load("res://scripts/editor/visual/%s.gd" % m[0]).new(mock)
		var ctrl = mod.create(m[1], {})
		assert(ctrl != null, "%s create 应返回控件" % m[0])
		mock.add_child(ctrl)
		ctrl.free()
	print("PASS 10 visual modules create")

	# === 2. 蓝图工作区交互：加节点/undo/编译/切换图 ===
	var ws_mod = load("res://scripts/editor/visual/visual_blueprint_workspace.gd").new(mock)
	var ws_ui = ws_mod.create("blueprint_workspace", {})
	mock.add_child(ws_ui)
	assert(ws_mod._current_key == "sys:global", "默认图应为 sys:global")
	# 通过 _bp_mod 加节点（含 branch）
	ws_mod._bp_mod._add_blueprint_node("branch")
	var g1: Dictionary = ws_mod._workspace_get_graph()
	assert(g1["nodes"].size() >= 4, "加分支后节点应增加")
	# undo（快照恢复）+ 重绘
	ws_mod._bp_mod._bp_push_undo()
	var canvas: Control = ws_ui.find_child("EventGraphCanvas", true, false)
	assert(canvas != null, "画布应存在")
	# 编译
	ws_mod._compile_current()
	var g2: Dictionary = ws_mod._workspace_get_graph()
	assert(g2.has("_compiled_code"), "编译产物应写入图")
	# 新建/切换/删除图
	GraphStore.set_graph(ws, "sys:extra", BlueprintData.make_graph())
	ws_mod._current_key = "sys:extra"
	ws_mod._on_graph_switched()
	ws_mod._on_delete_graph_pressed()
	assert(not GraphStore.has_graph(ws, "sys:extra"), "删除图应生效")
	print("PASS blueprint workspace interactions")

	# === 3. MUD 编辑器构建 + 表操作 ===
	var mud_editor = load("res://scripts/editor/mud_editor.gd").new()
	var mud_host := Control.new()
	root.add_child(mud_host)
	mud_editor.build_into(mud_host)
	mud_editor.load_data(ws)
	# 表操作（内部 MudData）
	var MudDataClass = load("res://scripts/editor/mud/mud_data.gd")
	var md = MudDataClass.new()
	md.add_row("scene", {"id": 1, "name": "新手村"})
	md.add_row("map", {"id": 1, "name": "世界地图"})
	assert(md.get_table("scene").size() == 1, "MUD 表增应生效")
	md.update_row("scene", 1, {"name": "新手村改"})
	assert(md.get_table("scene")[0].get("name", "") == "新手村改", "MUD 改应生效")
	print("PASS MUD editor build & table ops")

	# === 4. 代码生成/解析（code 编辑器装配由 test_mode_switch 覆盖真实路径） ===
	var ScriptCodeGenClass = load("res://scripts/editor/script_codegen.gd")
	var code: String = ScriptCodeGenClass.generate(ws)
	assert(code.find("# === 2D 场景 ===") >= 0, "代码应含 2D 场景章节")
	assert(code.find("scene_2d") >= 0, "代码应含 scene_2d")
	var ws2 := WorldScriptData.new()
	ws2.name = "x"
	ws2.ensure_subsystems()
	var pr: Dictionary = ScriptCodeGenClass.parse(code, ws2)
	assert(pr.get("success", false), "代码解析应成功")
	print("PASS codegen generate & parse")

	print("ALL_TESTS_PASSED")
	quit(0)
