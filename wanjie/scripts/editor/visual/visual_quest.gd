## 可视化编辑器 - 任务系统模块
extends "res://scripts/editor/visual/visual_module_base.gd"

func get_nav_title() -> String:
	return "📋 任务系统"

func get_nav_items() -> Array:
	return [
		["📊 概览", "quest_overview"],
		["📜 任务列表", "quest_list"],
		["🔗 任务链", "quest_chains"],
	]

func create(_sub_type: String = "", _meta: Dictionary = {}) -> Control:
	return build_standard_layout(_sub_type, _meta)

func _build_content(content: VBoxContainer, sub_type: String, meta: Dictionary = {}) -> void:
	_clear(content)
	var qs := _ws().quest_system
	match sub_type:
		"quest_overview":
			_ui().add_section_label(content, "📋 任务系统概览")
			_ui().add_stat_card(content, [
				["任务", "%d 个" % qs.quests.size()],
				["任务链", "%d 条" % qs.quest_chains.size()],
				["主线", "%d" % qs.get_quests_by_type("main").size()],
				["支线", "%d" % qs.get_quests_by_type("side").size()],
			])
			_ui().add_hseparator(content)
			_ui().add_info_label(content, "从左侧模块树选择具体任务进行详细编辑")
		"quest_list":
			_ui().add_section_label(content, "📜 任务列表")
			_ui().add_list_editor(content, qs.quests, ["name", "type", "level_req"],
				func(): qs.add_quest("quest_%d" % qs.quests.size(), "新任务", "main", ""))
		"quest_chains":
			_ui().add_section_label(content, "🔗 任务链")
			_ui().add_list_editor(content, qs.quest_chains, ["name", "description"],
				func(): qs.add_quest_chain("chain_%d" % qs.quest_chains.size(), "新任务链", [], ""))
		"quest_detail":
			var quest_id: String = meta.get("quest_id", "")
			var quest: Dictionary = qs.get_quest(quest_id)
			if quest.is_empty():
				_ui().add_section_label(content, "任务未找到")
			else:
				_build_quest_detail_form(content, quest)
	content.queue_sort()

## 任务详情编辑表单
func _build_quest_detail_form(content: VBoxContainer, quest: Dictionary) -> void:
	_ui().add_section_label(content, "📜 任务: %s" % quest.get("name", ""))
	_ui().add_text_field(content, "名称", quest.get("name", ""), func(v): quest["name"] = v; _sync())
	# 任务类型下拉
	var type_hbox := HBoxContainer.new()
	type_hbox.add_theme_constant_override("separation", 8)
	content.add_child(type_hbox)
	var type_lbl := Label.new()
	type_lbl.text = "类型"
	type_lbl.custom_minimum_size.x = 110
	type_lbl.add_theme_color_override("font_color", EditorUIFactory.C_LABEL)
	type_lbl.add_theme_font_size_override("font_size", 13)
	type_hbox.add_child(type_lbl)
	var type_opt := OptionButton.new()
	var type_names := ["main", "side", "daily", "hidden"]
	var type_labels := ["主线", "支线", "日常", "隐藏"]
	for i in type_names.size():
		type_opt.add_item("%s (%s)" % [type_labels[i], type_names[i]], i)
		if type_names[i] == quest.get("type", "main"):
			type_opt.selected = i
	type_opt.item_selected.connect(func(idx: int): quest["type"] = type_names[idx]; _sync())
	type_hbox.add_child(type_opt)
	_ui().add_multiline_field(content, quest.get("description", ""), func(v): quest["description"] = v; _sync())
	_ui().add_spin_field(content, "等级要求", float(quest.get("level_req", 1)), 1, 999, func(v): quest["level_req"] = int(v); _sync())
	_ui().add_spin_field(content, "时限(-1无限)", float(quest.get("time_limit", -1)), -1, 99999, func(v): quest["time_limit"] = int(v); _sync())
	# 目标
	_ui().add_section_label(content, "任务目标", 2)
	var objectives: Array = quest.get("objectives", [])
	quest["objectives"] = objectives
	_ui().add_list_editor(content, objectives, ["description", "target_type", "target_id", "required_count"],
		func(): objectives.append({"description": "新目标", "target_type": "kill", "target_id": "", "required_count": 1, "current_count": 0}))
	# 奖励
	_ui().add_section_label(content, "任务奖励", 2)
	var rewards: Dictionary = quest.get("rewards", {})
	quest["rewards"] = rewards
	_ui().add_spin_field(content, "经验", float(rewards.get("exp", 0)), 0, 999999, func(v): rewards["exp"] = int(v); _sync())
	_ui().add_spin_field(content, "金币", float(rewards.get("gold", 0)), 0, 999999, func(v): rewards["gold"] = int(v); _sync())
