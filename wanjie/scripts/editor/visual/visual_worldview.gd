## 可视化编辑器 - 世界观系统模块
extends "res://scripts/editor/visual/visual_module_base.gd"

func get_nav_title() -> String:
	return "📖 世界观"

func get_nav_items() -> Array:
	return [
		["📖 概览", "worldview_overview"],
		["📝 背景故事", "worldview_bg"],
		["🕐 时代定义", "worldview_eras"],
		["📅 时间线", "worldview_timeline"],
		["⚖ 世界规则", "worldview_rules"],
		["🏛 势力设定", "worldview_factions"],
		["🤝 势力关系", "worldview_rels"],
		["🗺 地理区域", "worldview_geo"],
		["📚 知识条目", "worldview_lore"],
	]

func create(_sub_type: String = "", _meta: Dictionary = {}) -> Control:
	return build_standard_layout(_sub_type, _meta)

func _build_content(content: VBoxContainer, sub_type: String, _meta: Dictionary = {}) -> void:
	_clear(content)
	var wv := _ws().worldview
	match sub_type:
		"worldview_overview":
			_ui().add_section_label(content, "📖 世界观概览")
			_ui().add_stat_card(content, [
				["时代", str(wv.era_definitions.size())],
				["规则", str(wv.world_rules.size())],
				["势力", str(wv.factions.size())],
				["时间线", str(wv.timeline.size())],
				["知识", str(wv.lore_entries.size())],
			])
			_ui().add_hseparator(content)
			_ui().add_section_label(content, "背景故事预览", 2)
			var preview := Label.new()
			preview.text = wv.background_story.substr(0, 200) + ("..." if wv.background_story.length() > 200 else "")
			preview.add_theme_color_override("font_color", EditorUIFactory.C_INFO)
			preview.add_theme_font_size_override("font_size", 12)
			preview.autowrap_mode = TextServer.AUTOWRAP_WORD
			content.add_child(preview)
		"worldview_bg":
			_ui().add_section_label(content, "📝 背景故事")
			_ui().add_multiline_field(content, wv.background_story, func(v): wv.background_story = v)
		"worldview_eras":
			_ui().add_section_label(content, "🕐 时代定义")
			_ui().add_list_editor(content, wv.era_definitions, ["era_name", "start_year", "end_year", "description"],
				func(): wv.add_era("新时代", 0, 100, ""))
		"worldview_timeline":
			_ui().add_section_label(content, "📅 时间线")
			_ui().add_list_editor(content, wv.timeline, ["year", "event", "impact"],
				func(): wv.add_timeline_entry(0, "新事件", ""))
		"worldview_rules":
			_ui().add_section_label(content, "⚖ 世界规则")
			_ui().add_list_editor(content, wv.world_rules, ["category", "key", "value", "description"],
				func(): wv.add_rule("physics", "新规则", "值", ""))
		"worldview_factions":
			_ui().add_section_label(content, "🏛 势力设定")
			_ui().add_list_editor(content, wv.factions, ["name", "power_level", "description", "governance_type"],
				func(): wv.add_faction("faction_%d" % wv.factions.size(), "新势力", "", 50))
		"worldview_rels":
			_ui().add_section_label(content, "🤝 势力关系")
			_ui().add_list_editor(content, wv.faction_relationships, ["from_id", "to_id", "type", "intensity"],
				func(): wv.faction_relationships.append({"from_id": "", "to_id": "", "type": "neutral", "intensity": 0.5}))
		"worldview_geo":
			_ui().add_section_label(content, "🗺 地理区域")
			if not wv.geography.has("regions"):
				wv.geography["regions"] = []
			var regions: Array = wv.geography["regions"]
			_ui().add_list_editor(content, regions, ["name", "description", "climate"],
				func():
					regions.append({"id": "region_%d" % regions.size(), "name": "新区域", "description": "", "climate": "temperate", "resources": [], "connections": []})
			)
		"worldview_lore":
			_ui().add_section_label(content, "📚 知识条目")
			_ui().add_list_editor(content, wv.lore_entries, ["title", "content", "discovery_condition"],
				func(): wv.lore_entries.append({"id": "lore_%d" % wv.lore_entries.size(), "title": "新知识", "content": "", "discovery_condition": ""}))
	content.queue_sort()
