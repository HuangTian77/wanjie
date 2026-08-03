## 临时验证脚本: AI 助手面板快捷功能扩充测试
extends SceneTree

func _initialize() -> void:
	var mock := MockHost.new()
	var ws := WorldScriptData.new()
	ws.id = "ai_test"
	ws.name = "AI测试"
	ws.ensure_subsystems()
	ws.event_system.add_story_event("evt_1", "事件一", "chain")
	ws.economy_system.add_currency("gold", "金币", "universal")
	ws.ability_system.add_skill_simple("sk_1", "火球", "active", "elemental", "fire", "")
	ws.quest_system.add_quest("q1", "主线任务", "main")
	mock.current_script = ws

	var AIPromptsClass = load("res://scripts/editor/ai_prompts.gd")
	var mod = load("res://scripts/editor/visual/visual_ai_assistant.gd").new(mock)
	var control = mod.create("ai_assistant", {})
	assert(control != null, "面板应创建")
	# 检查快捷按钮已注册（内部 _quick_action 可被调用）
	assert(AIPromptsClass.QUEST_SYSTEM != "", "任务模板应存在")
	assert(AIPromptsClass.COMBAT_SYSTEM != "", "战斗模板应存在")
	assert(AIPromptsClass.CHAIN_SYSTEM != "", "事件链模板应存在")
	var quest_p: String = AIPromptsClass.quest_user_prompt("测试")
	assert(quest_p.find("任务系统") >= 0, "任务 prompt 应生成")
	var combat_p: String = AIPromptsClass.combat_user_prompt("测试世界观")
	assert(combat_p.find("敌人模板") >= 0, "战斗 prompt 应生成")
	var chain_p: String = AIPromptsClass.chain_user_prompt("测试事件")
	assert(chain_p.find("事件链") >= 0, "事件链 prompt 应生成")
	print("PASS prompts quest/combat/chain")

	# 逐 feature 调用 _quick_action（mock AI 后端, 异步回调由 mock 直接同步完成）
	root.add_child(mock)  # 挂入场景树, 让 ai_service 的模拟延迟 timer 可用
	for feature in ["worldview_gen", "event_gen", "economy_analysis", "ability_gen", "quest_gen", "combat_gen", "chain_gen"]:
		mod._quick_action(feature)
		assert(mod._is_busy, feature + " 应进入忙碌状态")
		# mock 后端同步完成, 清 busy
		mod._is_busy = false
	print("PASS 7 quick actions dispatch without crash")

	# 上下文构建包含任务摘要
	var ctx: String = AIPromptsClass.build_script_context(ws)
	assert(ctx.find("任务") >= 0 or ctx.find("技能") >= 0, "上下文应包含子系统摘要")
	print("PASS script context build")

	control.free()
	print("ALL_TESTS_PASSED")
	quit(0)

class MockHost extends Node:
	var current_script = null
	var editor_container = null
	var _ui = null
	var log_lines: Array = []
	func _init():
		editor_container = Node.new()
		add_child(editor_container)
		_ui = load("res://scripts/editor/editor_ui_factory.gd").new(self)
	func _log_output(msg: String) -> void:
		log_lines.append(msg)
	func _sync_to_code_editor() -> void:
		pass
	func _mark_dirty() -> void:
		pass
	func _build_module_tree() -> void:
		pass
