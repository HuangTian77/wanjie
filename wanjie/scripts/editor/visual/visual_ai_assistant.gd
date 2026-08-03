## AI辅助创作面板
## 嵌入剧本编辑器的AI助手UI，提供世界观生成、事件编排、经济分析、能力设计等功能
## 继承VisualModuleBase，通过_host访问主编辑器
extends "res://scripts/editor/visual/visual_module_base.gd"

const AIServiceClass = preload("res://scripts/editor/ai_service.gd")
const AIPromptsClass = preload("res://scripts/editor/ai_prompts.gd")

var _ai_service: RefCounted = null
var _chat_log: RichTextLabel = null
var _input_edit: TextEdit = null
var _status_label: Label = null
var _is_busy: bool = false

## 入口
func create(_sub_type: String = "", _meta: Dictionary = {}) -> Control:
	# 初始化AI服务
	_ai_service = AIServiceClass.new()
	_ai_service.init(_host, _load_ai_config())
	_ai_service.request_completed.connect(_on_ai_completed)
	_ai_service.request_failed.connect(_on_ai_failed)
	# 构建UI
	return _build_panel()

## 构建AI助手面板
func _build_panel() -> Control:
	var root := PanelContainer.new()
	root.add_theme_stylebox_override("panel", _ui().make_bg_style())
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 4)
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(main_vbox)
	# === 标题栏 ===
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	main_vbox.add_child(header)
	var title := Label.new()
	title.text = "🤖 AI创作助手"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	header.add_child(title)
	_status_label = Label.new()
	_status_label.text = _ai_service.get_config_summary()
	_status_label.add_theme_font_size_override("font_size", 10)
	_status_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_status_label)
	# 设置按钮
	var settings_btn := Button.new()
	settings_btn.text = "⚙"
	settings_btn.add_theme_font_size_override("font_size", 12)
	settings_btn.tooltip_text = "AI服务设置"
	settings_btn.pressed.connect(_show_settings)
	header.add_child(settings_btn)
	# === 快捷功能按钮栏 ===
	var actions_bar := HBoxContainer.new()
	actions_bar.add_theme_constant_override("separation", 4)
	main_vbox.add_child(actions_bar)
	_add_action_btn(actions_bar, "🌍 世界观", func(): _quick_action("worldview_gen"))
	_add_action_btn(actions_bar, "📖 事件", func(): _quick_action("event_gen"))
	_add_action_btn(actions_bar, "💰 经济分析", func(): _quick_action("economy_analysis"))
	_add_action_btn(actions_bar, "✨ 能力", func(): _quick_action("ability_gen"))
	_add_action_btn(actions_bar, "📋 任务", func(): _quick_action("quest_gen"))
	_add_action_btn(actions_bar, "⚔ 战斗/NPC", func(): _quick_action("combat_gen"))
	_add_action_btn(actions_bar, "🔗 事件链", func(): _quick_action("chain_gen"))
	_add_action_btn(actions_bar, "🗑 清空", func(): _clear_chat())
	# === 聊天日志 ===
	_chat_log = RichTextLabel.new()
	_chat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chat_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_log.bbcode_enabled = true
	_chat_log.scroll_following = true
	_chat_log.add_theme_font_size_override("normal_font_size", 12)
	main_vbox.add_child(_chat_log)
	# 欢迎信息
	_chat_log.append_text("[color=#88aacc]欢迎使用AI创作助手！[/color]\n")
	_chat_log.append_text("你可以：\n")
	_chat_log.append_text("  • 点击上方快捷按钮使用预设功能\n")
	_chat_log.append_text("  • 在下方输入框自由提问\n")
	_chat_log.append_text("  • AI将基于当前剧本上下文提供建议\n\n")
	if not _ai_service.is_real_backend():
		_chat_log.append_text("[color=#aa8844]当前为模拟模式，点击⚙配置真实AI后端[/color]\n\n")
	# === 输入区 ===
	var input_hbox := HBoxContainer.new()
	input_hbox.add_theme_constant_override("separation", 4)
	main_vbox.add_child(input_hbox)
	_input_edit = TextEdit.new()
	_input_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input_edit.custom_minimum_size.y = 60
	_input_edit.placeholder_text = "描述你的创作需求... (Ctrl+Enter发送)"
	_input_edit.add_theme_font_size_override("font_size", 12)
	_input_edit.gui_input.connect(_on_input_gui_input)
	input_hbox.add_child(_input_edit)
	var send_btn := Button.new()
	send_btn.text = "发送"
	send_btn.custom_minimum_size.x = 60
	send_btn.add_theme_font_size_override("font_size", 12)
	send_btn.pressed.connect(_send_message)
	input_hbox.add_child(send_btn)
	return root

## === 快捷功能 ===

func _quick_action(feature: String) -> void:
	if _is_busy:
		_append_system("请等待当前请求完成...")
		return
	var context_info: String = AIPromptsClass.build_script_context(_host.current_script)
	match feature:
		"worldview_gen":
			_append_user("[世界观生成] 基于当前剧本生成/补充世界观设定")
			_ai_service.structured_completion(
				AIPromptsClass.WORLDVIEW_SYSTEM,
				AIPromptsClass.worldview_user_prompt("基于现有剧本扩展", "", context_info),
				'{"era":"","timeline":[],"factions":[],"rules":"","geography":{},"conflicts":[],"tone":""}',
				{"feature": "worldview_gen"}
			)
		"event_gen":
			_append_user("[事件生成] 为当前剧本建议新的剧情事件")
			_ai_service.structured_completion(
				AIPromptsClass.EVENT_SYSTEM,
				AIPromptsClass.event_user_prompt("与现有剧情相关的新冲突", context_info, "single"),
				'{"name":"","trigger_type":"","description":"","conditions":[],"choices":[],"tags":[]}',
				{"feature": "event_gen"}
			)
		"economy_analysis":
			_append_user("[经济分析] 分析当前经济系统平衡性")
			var eco_json := ""
			if _host.current_script and _host.current_script.economy_system:
				eco_json = JSON.stringify({
					"resources": _host.current_script.economy_system.resources,
					"currencies": _host.current_script.economy_system.currencies,
					"markets": _host.current_script.economy_system.markets,
				}, "  ")
			else:
				eco_json = "(无经济系统数据)"
			_ai_service.structured_completion(
				AIPromptsClass.ECONOMY_SYSTEM,
				AIPromptsClass.economy_user_prompt(eco_json),
				'{"overall_score":0,"issues":[],"summary":""}',
				{"feature": "economy_analysis"}
			)
		"ability_gen":
			_append_user("[能力生成] 基于世界规则生成技能体系")
			var world_rules := ""
			if _host.current_script and _host.current_script.worldview:
				world_rules = str(_host.current_script.worldview.world_rules)
			_ai_service.structured_completion(
				AIPromptsClass.ABILITY_SYSTEM,
				AIPromptsClass.ability_user_prompt(world_rules, ""),
				'{"schools":[],"growth_paths":[]}',
				{"feature": "ability_gen"}
			)
		"quest_gen":
			_append_user("[任务生成] 为当前剧本设计任务系统")
			var quest_json := ""
			if _host.current_script and _host.current_script.quest_system:
				quest_json = JSON.stringify(_host.current_script.quest_system.quests, "  ")
			else:
				quest_json = "(无任务数据)"
			_ai_service.structured_completion(
				AIPromptsClass.QUEST_SYSTEM,
				AIPromptsClass.quest_user_prompt(quest_json),
				'{"quests":[],"quest_chains":[]}',
				{"feature": "quest_gen"}
			)
		"combat_gen":
			_append_user("[战斗/NPC] 生成敌人模板与NPC体系")
			var wv_json := ""
			if _host.current_script and _host.current_script.worldview:
				wv_json = JSON.stringify({
					"factions": _host.current_script.worldview.factions,
					"geography": _host.current_script.worldview.geography,
				}, "  ")
			else:
				wv_json = "(无世界观数据)"
			_ai_service.structured_completion(
				AIPromptsClass.COMBAT_SYSTEM,
				AIPromptsClass.combat_user_prompt(wv_json),
				'{"enemies":[],"npcs":[],"battles":[]}',
				{"feature": "combat_gen"}
			)
		"chain_gen":
			_append_user("[事件链] 编排剧情事件链")
			var event_json := ""
			if _host.current_script and _host.current_script.event_system:
				event_json = JSON.stringify(
					_host.current_script.event_system.story_events.map(func(e): return {"id": e.get("id", ""), "name": e.get("name", "")}),
					"  ")
			else:
				event_json = "(无事件数据)"
			_ai_service.structured_completion(
				AIPromptsClass.CHAIN_SYSTEM,
				AIPromptsClass.chain_user_prompt(event_json),
				'{"chains":[]}',
				{"feature": "chain_gen"}
			)
	_set_busy(true)

## === 自由对话 ===

func _send_message() -> void:
	if _is_busy:
		return
	var text: String = _input_edit.text.strip_edges()
	if text.is_empty():
		return
	_input_edit.text = ""
	_append_user(text)
	var context_info: String = AIPromptsClass.build_script_context(_host.current_script)
	var messages: Array = [
		{"role": "system", "content": AIPromptsClass.SYSTEM_BASE},
		{"role": "user", "content": AIPromptsClass.general_user_prompt(text, context_info)},
	]
	_ai_service.chat_completion(messages, {"feature": "general"})
	_set_busy(true)

## === 信号处理 ===

func _on_ai_completed(result: Dictionary) -> void:
	_set_busy(false)
	var content: String = result.get("content", "")
	var usage: Dictionary = result.get("usage", {})
	_append_ai(content)
	if usage.get("total_tokens", 0) > 0:
		_append_system("tokens: %d" % usage.get("total_tokens", 0))

func _on_ai_failed(error_msg: String) -> void:
	_set_busy(false)
	_append_system("[错误] %s" % error_msg)

## === UI辅助 ===

func _append_user(text: String) -> void:
	_chat_log.append_text("\n[color=#66bb88]▶ 你：[/color]%s\n" % text.replace("\n", "\n  "))

func _append_ai(text: String) -> void:
	_chat_log.append_text("\n[color=#88aaff]◆ AI：[/color]\n%s\n" % text)

func _append_system(text: String) -> void:
	_chat_log.append_text("[color=#888888]  [%s][/color]\n" % text)

func _clear_chat() -> void:
	_chat_log.clear()
	_chat_log.append_text("[color=#88aacc]对话已清空[/color]\n\n")

func _set_busy(busy: bool) -> void:
	_is_busy = busy
	if busy:
		_append_system("AI思考中...")

func _add_action_btn(parent: Control, text: String, callback: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 11)
	btn.pressed.connect(callback)
	parent.add_child(btn)

func _on_input_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.ctrl_pressed and event.keycode == KEY_ENTER:
		_send_message()
		_host.editor_container.get_viewport().set_input_as_handled()

## === 设置 ===

func _show_settings() -> void:
	var popup := PopupPanel.new()
	popup.size = Vector2(400, 280)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	popup.add_child(vbox)
	var title := Label.new()
	title.text = "AI服务设置"
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)
	# API地址
	var url_hbox := HBoxContainer.new()
	vbox.add_child(url_hbox)
	var url_lbl := Label.new()
	url_lbl.text = "API地址:"
	url_lbl.add_theme_font_size_override("font_size", 12)
	url_hbox.add_child(url_lbl)
	var url_edit := LineEdit.new()
	url_edit.text = _ai_service._api_url
	url_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	url_edit.add_theme_font_size_override("font_size", 11)
	url_hbox.add_child(url_edit)
	# 模型
	var model_hbox := HBoxContainer.new()
	vbox.add_child(model_hbox)
	var model_lbl := Label.new()
	model_lbl.text = "模型名:"
	model_lbl.add_theme_font_size_override("font_size", 12)
	model_hbox.add_child(model_lbl)
	var model_edit := LineEdit.new()
	model_edit.text = _ai_service._model
	model_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	model_edit.add_theme_font_size_override("font_size", 11)
	model_hbox.add_child(model_edit)
	# API Key
	var key_hbox := HBoxContainer.new()
	vbox.add_child(key_hbox)
	var key_lbl := Label.new()
	key_lbl.text = "API Key:"
	key_lbl.add_theme_font_size_override("font_size", 12)
	key_hbox.add_child(key_lbl)
	var key_edit := LineEdit.new()
	key_edit.text = _ai_service._api_key
	key_edit.secret = true
	key_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	key_edit.add_theme_font_size_override("font_size", 11)
	key_hbox.add_child(key_edit)
	# 服务商选择
	var provider_hbox := HBoxContainer.new()
	vbox.add_child(provider_hbox)
	var prov_lbl := Label.new()
	prov_lbl.text = "服务商:"
	prov_lbl.add_theme_font_size_override("font_size", 12)
	provider_hbox.add_child(prov_lbl)
	var prov_opt := OptionButton.new()
	prov_opt.add_item("OpenAI兼容API")
	prov_opt.add_item("本地Ollama")
	prov_opt.add_item("模拟模式(测试)")
	prov_opt.selected = _ai_service._provider
	provider_hbox.add_child(prov_opt)
	# 保存按钮
	var save_btn := Button.new()
	save_btn.text = "保存并应用"
	save_btn.add_theme_font_size_override("font_size", 12)
	save_btn.pressed.connect(func():
		_ai_service.update_config({
			"provider": prov_opt.selected,
			"api_url": url_edit.text,
			"model": model_edit.text,
			"api_key": key_edit.text,
		})
		_save_ai_config({
			"provider": prov_opt.selected,
			"api_url": url_edit.text,
			"model": model_edit.text,
			"api_key": key_edit.text,
		})
		_status_label.text = _ai_service.get_config_summary()
		_append_system("AI设置已更新: %s" % _ai_service.get_config_summary())
		popup.hide()
		popup.queue_free()
	)
	vbox.add_child(save_btn)
	_host.editor_container.add_child(popup)
	popup.popup_centered(Vector2i(400, 280))

## === 配置持久化 ===

func _load_ai_config() -> Dictionary:
	var config_path := "user://ai_config.json"
	if FileAccess.file_exists(config_path):
		var file := FileAccess.open(config_path, FileAccess.READ)
		if file:
			var parsed = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				return parsed
	return {}

func _save_ai_config(config: Dictionary) -> void:
	var config_path := "user://ai_config.json"
	var file := FileAccess.open(config_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(config, "  "))
