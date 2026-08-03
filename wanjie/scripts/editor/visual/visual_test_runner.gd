## 可视化编辑器 - 测试运行器模块
## 注意: 测试运行器不适用标准导航布局
extends "res://scripts/editor/visual/visual_module_base.gd"

func create(_sub_type: String = "", _meta: Dictionary = {}) -> Control:
	var root := PanelContainer.new()
	root.add_theme_stylebox_override("panel", _ui().make_bg_style())
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(main_vbox)
	_ui().add_section_label(main_vbox, "▶ 测试运行器")
	# 工具栏
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 8)
	main_vbox.add_child(toolbar)
	# 事件选择
	var event_label := Label.new()
	event_label.text = "选择事件:"
	event_label.add_theme_color_override("font_color", EditorUIFactory.C_LABEL)
	event_label.add_theme_font_size_override("font_size", 12)
	toolbar.add_child(event_label)
	var event_select := OptionButton.new()
	event_select.name = "TestEventSelect"
	event_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	event_select.custom_minimum_size.x = 200
	var es := _ws().event_system
	event_select.add_item("-- 选择事件 --", 0)
	for i in es.story_events.size():
		var ev: Dictionary = es.story_events[i]
		event_select.add_item("📌 " + ev.get("name", ev.get("id", "?")), i + 1)
	for i in es.random_events.size():
		var ev: Dictionary = es.random_events[i]
		event_select.add_item("🎲 " + ev.get("name", ev.get("id", "?")), es.story_events.size() + i + 1)
	toolbar.add_child(event_select)
	_ui().add_toolbar_btn(toolbar, "▶ 触发事件", func(): _test_fire_event(main_vbox, event_select))
	_ui().add_toolbar_btn(toolbar, "🔄 校验剧本", func(): _test_validate(main_vbox))
	# 输出日志
	_ui().add_section_label(main_vbox, "输出日志", 2)
	var log_output := RichTextLabel.new()
	log_output.name = "TestOutput"
	log_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_output.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_output.bbcode_enabled = true
	log_output.add_theme_font_size_override("normal_font_size", 12)
	log_output.add_theme_color_override("default_color", Color(0.75, 0.78, 0.85, 1))
	log_output.custom_minimum_size.y = 200
	main_vbox.add_child(log_output)
	# 校验状态
	var status_bar := HBoxContainer.new()
	status_bar.add_theme_constant_override("separation", 8)
	main_vbox.add_child(status_bar)
	var status_lbl := Label.new()
	status_lbl.name = "TestStatus"
	status_lbl.text = "就绪"
	status_lbl.add_theme_color_override("font_color", EditorUIFactory.C_GREEN)
	status_lbl.add_theme_font_size_override("font_size", 11)
	status_bar.add_child(status_lbl)
	return root

func _test_fire_event(main_vbox: VBoxContainer, select: OptionButton) -> void:
	var output: RichTextLabel = main_vbox.find_child("TestOutput", true, false)
	if output == null:
		return
	var selected_id := select.get_selected_id()
	if selected_id == 0:
		output.text += "[color=yellow]请选择一个事件[/color]\n"
		return
	var es := _ws().event_system
	var event: Dictionary = {}
	if selected_id <= es.story_events.size():
		event = es.story_events[selected_id - 1]
	else:
		var idx := selected_id - es.story_events.size() - 1
		if idx >= 0 and idx < es.random_events.size():
			event = es.random_events[idx]
	if event.is_empty():
		output.text += "[color=red]事件未找到[/color]\n"
		return
	output.text += "[color=cyan]▶ 触发事件: %s[/color]\n" % event.get("name", "")
	output.text += "  ID: %s\n" % event.get("id", "")
	output.text += "  类型: %s\n" % event.get("trigger_type", "unknown")
	output.text += "  描述: %s\n" % event.get("description", "(无)")
	if event.has("conditions"):
		output.text += "  条件: %d 个\n" % event["conditions"].size()
	if event.has("choices"):
		output.text += "  选择: %d 个\n" % event["choices"].size()
	output.text += "\n"

func _test_validate(main_vbox: VBoxContainer) -> void:
	var output: RichTextLabel = main_vbox.find_child("TestOutput", true, false)
	var status_lbl: Label = main_vbox.find_child("TestStatus", true, false)
	if output == null:
		return
	var validator := ScriptValidator.new()
	var report := validator.validate(_ws())
	output.text += "[color=cyan]🔄 开始校验...[/color]\n"
	if report["is_valid"]:
		output.text += "[color=green]✅ 校验通过[/color]\n"
		if status_lbl:
			status_lbl.text = "✅ 校验通过"
			status_lbl.add_theme_color_override("font_color", EditorUIFactory.C_GREEN)
	else:
		output.text += "[color=red]❌ 发现 %d 个错误:[/color]\n" % report["error_count"]
		for e in report.get("errors", []):
			output.text += "  [color=red]• %s[/color]\n" % str(e)
		if status_lbl:
			status_lbl.text = "❌ %d错误 %d警告" % [report["error_count"], report["warning_count"]]
			status_lbl.add_theme_color_override("font_color", EditorUIFactory.C_DANGER)
	for w in report.get("warnings", []):
		output.text += "  [color=yellow]⚠ %s[/color]\n" % str(w)
	output.text += "\n"
