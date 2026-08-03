## 临时验证脚本: 三模式切换回归（visual/code/mud 共享 WorldScriptData, 数据不丢）
extends SceneTree

func _initialize() -> void:
	var mock := MockHost.new()
	var ws := WorldScriptData.new()
	ws.id = "test"
	ws.name = "三模式测试"
	ws.ensure_subsystems()
	ws.event_system.add_story_event("evt_1", "初始事件", "chain")
	ws.economy_system.add_currency("gold", "金币", "universal")
	mock.current_script = ws

	# === 1. visual 模式: 创建模块并编辑 ===
	var mod = load("res://scripts/editor/visual/visual_event.gd").new(mock)
	var control = mod.create("event", {})
	assert(control != null)
	mod._add_story_event_node(control)
	# 在 L1 表单添加一个条件, 模拟用户编辑
	mod._switch_event_layer("l1")
	mod._l1_mod._l1_ensure_all_structured()
	var first_event: Dictionary = ws.event_system.story_events[0]
	if not first_event.has("conditions_structured"):
		first_event["conditions_structured"] = ConditionCompiler.decompile_conditions(first_event.get("conditions", []))
	first_event["conditions_structured"].append(ConditionCompiler.make_condition("player", "level", ">=", 5))
	mod._l1_mod._l1_sync_event_to_runtime(first_event)
	mod._switch_event_layer("l3")
	assert(ws.event_system.story_events.size() == 2, "visual 编辑应新增 1 个事件")
	assert(first_event.get("conditions", []).size() == 1, "L1 条件应写入运行时")
	print("PASS visual mode edit")

	# === 2. code 模式: generate -> parse 回写, 数据不丢 ===
	var ScriptCodeGenClass = load("res://scripts/editor/script_codegen.gd")
	var code: String = ScriptCodeGenClass.generate(ws)
	assert(code.find("初始事件") >= 0, "code 文本应包含 visual 编辑的数据")
	assert(code.find("evt_") >= 0, "code 文本应包含新增事件")
	# 模拟用户在 code 模式追加一个 quest
	var edited_code: String = code + "\nfunc quest(\"q_code\", \"代码任务\", \"main\"):\n\tdescription = \"来自代码模式\"\n"
	var ws2 := WorldScriptData.new()
	ws2.name = "回写"
	ws2.ensure_subsystems()
	var parse_result: Dictionary = ScriptCodeGenClass.parse(edited_code, ws2)
	assert(parse_result.get("success", false), "parse 应成功")
	assert(ws2.event_system.story_events.size() == 2, "parse 后事件应保留")
	var q: Dictionary = ws2.quest_system.get_quest("q_code")
	assert(not q.is_empty(), "parse 后 quest 应存在")
	assert(q.get("name") == "代码任务", "quest 名称应正确")
	# 条件也回写
	var ev: Dictionary = ws2.event_system.get_story_event("evt_1")
	assert(ev.get("conditions", []).size() == 1, "条件应随代码回写")
	print("PASS code mode roundtrip")

	# === 3. mud 模式: load_data/save_data, 数据不丢 ===
	var mud_editor = load("res://scripts/editor/mud_editor.gd").new()
	mud_editor.load_data(ws2)
	mud_editor.save_data()
	assert(ws2.metadata.has("mud_data"), "mud 数据应写入 metadata")
	var mud_dict: Dictionary = ws2.metadata["mud_data"]
	assert(not mud_dict.is_empty(), "mud 数据不应为空")
	# 重新加载 mud 数据, 验证往返
	var mud_editor2 = load("res://scripts/editor/mud_editor.gd").new()
	mud_editor2.load_data(ws2)
	mud_editor2.save_data()
	assert(ws2.metadata["mud_data"].size() == mud_dict.size(), "mud 往返后数据量应一致")
	# mud 模式不应破坏其他子系统
	assert(ws2.event_system.story_events.size() == 2, "mud 切换后事件数据不丢")
	assert(ws2.quest_system.quests.size() == 1, "mud 切换后任务数据不丢")
	print("PASS mud mode roundtrip")

	# === 4. 三模式共用同一 WorldScriptData 引用 ===
	assert(ws2.event_system.get_story_event("evt_1").get("name") == "初始事件", "事件名应保持")
	print("PASS data preserved across modes")

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
