## 可视化编辑器 - 经济系统模块
extends "res://scripts/editor/visual/visual_module_base.gd"

func get_nav_title() -> String:
	return "💰 经济系统"

func get_nav_items() -> Array:
	return [
		["📊 概览", "economy_overview"],
		["💰 货币", "economy_curr"],
		["📦 资源", "economy_res"],
		["🏪 市场", "economy_mkt"],
		["📜 交易规则", "economy_trade"],
		["⚙ 产出规则", "economy_prod"],
	]

func create(_sub_type: String = "", _meta: Dictionary = {}) -> Control:
	return build_standard_layout(_sub_type, _meta)

func _build_content(content: VBoxContainer, sub_type: String, _meta: Dictionary = {}) -> void:
	_clear(content)
	var ec := _ws().economy_system
	match sub_type:
		"economy_overview":
			_ui().add_section_label(content, "💰 经济系统概览")
			_ui().add_stat_card(content, [
				["货币", "%d 种" % ec.currencies.size()],
				["资源", "%d 种" % ec.resources.size()],
				["市场", "%d 个" % ec.markets.size()],
				["产出规则", "%d 条" % ec.production_rules.size()],
			])
		"economy_curr":
			_ui().add_section_label(content, "💰 货币列表")
			_ui().add_list_editor(content, ec.currencies, ["name", "type", "max_supply", "inflation_rate"],
				func(): ec.add_currency("curr_%d" % ec.currencies.size(), "新货币", "universal"))
		"economy_res":
			_ui().add_section_label(content, "📦 资源列表")
			_ui().add_list_editor(content, ec.resources, ["name", "category", "stack_limit", "decay_enabled"],
				func(): ec.add_resource("res_%d" % ec.resources.size(), "新资源", "material"))
		"economy_mkt":
			_ui().add_section_label(content, "🏪 市场列表")
			_ui().add_list_editor(content, ec.markets, ["name", "location"],
				func(): ec.add_market("mkt_%d" % ec.markets.size(), "新市场", ""))
		"economy_trade":
			_ui().add_section_label(content, "📜 交易规则")
			_ui().add_dict_editor(content, ec.trade_rules, ["barter_enabled", "barter_rate", "smuggling_risk"])
		"economy_prod":
			_ui().add_section_label(content, "⚙ 产出规则")
			_ui().add_list_editor(content, ec.production_rules, ["resource"],
				func(): ec.production_rules.append({"resource": "", "sources": []}))
	content.queue_sort()
