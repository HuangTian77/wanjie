## 可视化编辑器 - 能力系统模块
extends "res://scripts/editor/visual/visual_module_base.gd"

func get_nav_title() -> String:
	return "⚔ 能力系统"

func get_nav_items() -> Array:
	return [
		["📊 概览", "ability_overview"],
		["✦ 技能", "ability_skills"],
		["📈 成长路线", "ability_growth"],
		["💫 状态效果", "ability_fx"],
		["⚔ 战斗机制", "ability_combat"],
		["🔥 元素相克", "ability_elem"],
	]

func create(_sub_type: String = "", _meta: Dictionary = {}) -> Control:
	return build_standard_layout(_sub_type, _meta)

func _build_content(content: VBoxContainer, sub_type: String, meta: Dictionary = {}) -> void:
	_clear(content)
	var ab := _ws().ability_system
	match sub_type:
		"ability_overview":
			_ui().add_section_label(content, "⚔ 能力系统概览")
			_ui().add_stat_card(content, [
				["技能", "%d 个" % ab.skills.size()],
				["成长路线", "%d 条" % ab.growth_paths.size()],
				["状态效果", "%d 个" % ab.status_effects.size()],
			])
			_ui().add_button(content, "初始化默认战斗机制", func(): ab.initialize_combat_defaults())
		"ability_skills":
			_ui().add_section_label(content, "✦ 技能列表")
			_ui().add_list_editor(content, ab.skills, ["name", "category", "school"],
				func(): ab.add_skill("skill_%d" % ab.skills.size(), "新技能", "active", "magic", "none", ""))
		"ability_growth":
			_ui().add_section_label(content, "📈 成长路线")
			_ui().add_list_editor(content, ab.growth_paths, ["name", "description"],
				func(): ab.add_growth_path("path_%d" % ab.growth_paths.size(), "新路线", ""))
		"ability_fx":
			_ui().add_section_label(content, "💫 状态效果")
			_ui().add_list_editor(content, ab.status_effects, ["name", "type", "duration", "damage_per_tick"],
				func(): ab.add_status_effect("fx_%d" % ab.status_effects.size(), "新效果", "buff"))
		"ability_combat":
			_ui().add_section_label(content, "⚔ 战斗机制配置")
			_ui().add_dict_editor(content, ab.combat_definition, ["type", "critical_rate", "critical_damage"])
		"ability_elem":
			_ui().add_section_label(content, "🔥 元素相克表")
			_ui().add_dict_editor(content, ab.element_matrix, ab.element_matrix.keys())
		"skill_detail":
			var skill_id: String = meta.get("skill_id", "")
			var skill: Dictionary = {}
			for s in ab.skills:
				if s.get("id", "") == skill_id:
					skill = s
					break
			if skill.is_empty():
				_ui().add_section_label(content, "技能未找到")
			else:
				_ui().add_section_label(content, "✦ 技能: %s" % skill.get("name", ""))
				_ui().add_text_field(content, "名称", skill.get("name", ""), func(v): skill["name"] = v; _sync())
				_ui().add_text_field(content, "类别", skill.get("category", "active"), func(v): skill["category"] = v; _sync())
				_ui().add_text_field(content, "学派", skill.get("school", ""), func(v): skill["school"] = v; _sync())
				_ui().add_multiline_field(content, skill.get("description", ""), func(v): skill["description"] = v; _sync())
				var cost: Dictionary = skill.get("cost", {})
				_ui().add_section_label(content, "消耗", 2)
				_ui().add_spin_field(content, "法力", float(cost.get("mana", 0)), 0, 9999, func(v): cost["mana"] = int(v); _sync())
				_ui().add_text_field(content, "冷却", cost.get("cooldown", "0s"), func(v): cost["cooldown"] = v; _sync())
	content.queue_sort()
