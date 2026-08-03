## 剧本编辑器 UI 构建工厂
## 从 script_editor.gd 提取的纯 UI 构建辅助方法
## 通过 _host 回调实现与编辑器的数据同步
class_name EditorUIFactory
extends RefCounted

## 宿主编辑器引用 (duck-typed, 需要 _sync_to_code_editor / _build_module_tree)
var _host: Object

func _init(host: Object) -> void:
	_host = host

## === 配色常量 ===
const C_BG_CARD := Color(0.19, 0.2, 0.25, 1)
const C_BG_ROW := Color(0.22, 0.23, 0.28, 1)
const C_BG_ROW_ALT := Color(0.2, 0.21, 0.26, 1)
const C_ACCENT := Color(0.35, 0.6, 1.0, 1)
const C_ACCENT_DIM := Color(0.25, 0.45, 0.75, 0.5)
const C_SECTION_TITLE := Color(0.95, 0.85, 0.55, 1)
const C_LABEL := Color(0.65, 0.7, 0.8, 1)
const C_TEXT := Color(0.88, 0.88, 0.92, 1)
const C_INFO := Color(0.6, 0.65, 0.75, 1)
const C_GREEN := Color(0.55, 0.85, 0.55, 1)
const C_BORDER := Color(0.3, 0.33, 0.4, 0.6)
const C_DANGER := Color(1.0, 0.45, 0.45, 1)
const C_EMPTY_HINT := Color(0.5, 0.55, 0.65, 0.7)

## === 字段友好标签映射 ===
const FIELD_LABELS := {
	# 世界观
	"era_name": "时代名称", "start_year": "起始年份", "end_year": "结束年份",
	"description": "描述", "year": "年份", "event": "事件", "impact": "影响",
	"category": "类别", "key": "键", "value": "值",
	"name": "名称", "power_level": "实力等级", "governance_type": "治理方式",
	"from_id": "起始势力", "to_id": "目标势力", "type": "类型", "intensity": "强度",
	"region_name": "区域名", "terrain": "地形", "climate": "气候",
	"lore_title": "条目标题", "content": "内容", "discovery_condition": "发现条件",
	# 事件
	"trigger_type": "触发类型", "prerequisite": "前置条件", "probability": "概率",
	"cooldown": "冷却时间", "start_event": "起始事件",
	# 经济
	"max_supply": "最大供应量", "inflation_rate": "通胀率",
	"stack_limit": "堆叠上限", "decay_enabled": "可衰减",
	"location": "位置", "barter_enabled": "允许以物易物", "barter_rate": "以物易物汇率",
	"smuggling_risk": "走私风险",
	# 能力
	"school": "学派", "cost_mana": "法力消耗", "effect_type": "效果类型",
	"duration": "持续时间", "damage_per_tick": "每秒伤害",
	"critical_rate": "暴击率", "critical_damage": "暴击伤害",
	# 通用
	"formula": "公式", "base_value": "基础值", "aoe_radius": "范围半径",
	"id": "ID",
}

## === 样式工厂 ===

func make_bg_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.15, 0.19, 1)
	sb.content_margin_left = 0.0
	sb.content_margin_top = 0.0
	sb.content_margin_right = 0.0
	sb.content_margin_bottom = 0.0
	return sb

func make_content_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.17, 0.21, 1)
	sb.content_margin_left = 12.0
	sb.content_margin_top = 8.0
	sb.content_margin_right = 12.0
	sb.content_margin_bottom = 8.0
	return sb

func make_nav_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.12, 0.15, 1)
	sb.border_width_right = 1
	sb.border_color = Color(0.2, 0.22, 0.28, 0.4)
	sb.content_margin_left = 4.0
	sb.content_margin_top = 4.0
	sb.content_margin_right = 4.0
	sb.content_margin_bottom = 4.0
	return sb

func make_scroll_panel() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.15, 0.16, 0.2, 1)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_right = 6
	sb.corner_radius_bottom_left = 6
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.28, 0.32, 0.4, 0.5)
	sb.content_margin_left = 16.0
	sb.content_margin_top = 12.0
	sb.content_margin_right = 16.0
	sb.content_margin_bottom = 12.0
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return p

func make_vbox(parent: Control) -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(vb)
	return vb

## === 导航组件 ===

func add_nav_title(parent: Control, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0, 1))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.custom_minimum_size.y = 32
	parent.add_child(lbl)
	var sep := HSeparator.new()
	sep.add_theme_color_override("separator", Color(0.3, 0.4, 0.6, 0.3))
	sep.custom_minimum_size.y = 2
	parent.add_child(sep)

func add_nav_btn(parent: Control, text: String, key: String, active_key: String, on_select: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size.y = 30
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 12)
	btn.flat = true
	var is_active := key == active_key
	if is_active:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.22, 0.3, 0.45, 0.7)
		sb.corner_radius_top_left = 4
		sb.corner_radius_top_right = 4
		sb.corner_radius_bottom_right = 4
		sb.corner_radius_bottom_left = 4
		sb.content_margin_left = 10.0
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0, 1))
	else:
		btn.add_theme_color_override("font_color", C_TEXT)
		var hover_sb := StyleBoxFlat.new()
		hover_sb.bg_color = Color(0.2, 0.22, 0.3, 0.4)
		hover_sb.corner_radius_top_left = 4
		hover_sb.corner_radius_top_right = 4
		hover_sb.corner_radius_bottom_right = 4
		hover_sb.corner_radius_bottom_left = 4
		hover_sb.content_margin_left = 10.0
		btn.add_theme_stylebox_override("hover", hover_sb)
	btn.pressed.connect(func(): on_select.call(key))
	parent.add_child(btn)

func add_toolbar_btn(parent: Control, text: String, on_press: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size.y = 28
	btn.custom_minimum_size.x = 20
	btn.add_theme_font_size_override("font_size", 11)
	btn.add_theme_color_override("font_color", C_GREEN)
	btn.add_theme_color_override("font_hover_color", Color(0.7, 1.0, 0.7, 1))
	var normal_sb := StyleBoxFlat.new()
	normal_sb.bg_color = Color(0.18, 0.2, 0.26, 0.6)
	normal_sb.corner_radius_top_left = 3
	normal_sb.corner_radius_top_right = 3
	normal_sb.corner_radius_bottom_right = 3
	normal_sb.corner_radius_bottom_left = 3
	normal_sb.content_margin_left = 8.0
	normal_sb.content_margin_right = 8.0
	btn.add_theme_stylebox_override("normal", normal_sb)
	var hover_sb := StyleBoxFlat.new()
	hover_sb.bg_color = Color(0.25, 0.3, 0.38, 0.8)
	hover_sb.corner_radius_top_left = 3
	hover_sb.corner_radius_top_right = 3
	hover_sb.corner_radius_bottom_right = 3
	hover_sb.corner_radius_bottom_left = 3
	hover_sb.content_margin_left = 8.0
	hover_sb.content_margin_right = 8.0
	btn.add_theme_stylebox_override("hover", hover_sb)
	btn.pressed.connect(on_press)
	parent.add_child(btn)
	return btn

## === 布局组件 ===

func add_section_label(parent: Control, text: String, level: int = 1) -> void:
	add_hseparator(parent)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	hbox.custom_minimum_size.y = 24 if level == 1 else 20
	parent.add_child(hbox)
	var accent := ColorRect.new()
	var bar_width: float = 3.0 if level == 1 else 2.0
	var bar_height: float = 18.0 if level == 1 else 14.0
	accent.custom_minimum_size = Vector2(bar_width, bar_height)
	accent.color = C_ACCENT if level == 1 else C_ACCENT_DIM
	hbox.add_child(accent)
	var lbl := Label.new()
	lbl.text = text
	var font_size: int = 15 if level == 1 else (13 if level == 2 else 12)
	lbl.add_theme_font_size_override("font_size", font_size)
	var title_color: Color = C_SECTION_TITLE if level == 1 else (C_TEXT if level == 2 else C_LABEL)
	lbl.add_theme_color_override("font_color", title_color)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(lbl)

func add_hseparator(parent: Control) -> void:
	var sep := HSeparator.new()
	sep.add_theme_color_override("separator", Color(0.25, 0.3, 0.4, 0.25))
	sep.custom_minimum_size.y = 1
	parent.add_child(sep)

func add_info_label(parent: Control, text: String) -> void:
	var lbl := Label.new()
	lbl.text = "  " + text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", C_EMPTY_HINT)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	parent.add_child(lbl)

func add_stat_card(parent: Control, stats: Array) -> void:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.15, 0.2, 1)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_right = 6
	sb.corner_radius_bottom_left = 6
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.3, 0.35, 0.45, 0.4)
	sb.content_margin_left = 16.0
	sb.content_margin_top = 12.0
	sb.content_margin_right = 16.0
	sb.content_margin_bottom = 12.0
	card.add_theme_stylebox_override("panel", sb)
	parent.add_child(card)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 8)
	card.add_child(grid)
	for stat in stats:
		var k_lbl := Label.new()
		k_lbl.text = stat[0]
		k_lbl.add_theme_color_override("font_color", C_LABEL)
		k_lbl.add_theme_font_size_override("font_size", 13)
		grid.add_child(k_lbl)
		var v_lbl := Label.new()
		v_lbl.text = stat[1]
		v_lbl.add_theme_color_override("font_color", C_ACCENT)
		v_lbl.add_theme_font_size_override("font_size", 14)
		grid.add_child(v_lbl)

## === 表单字段 ===

func add_text_field(parent: Control, label_text: String, value: String, on_change: Callable) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	parent.add_child(hbox)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 110
	lbl.add_theme_color_override("font_color", C_LABEL)
	lbl.add_theme_font_size_override("font_size", 13)
	hbox.add_child(lbl)
	var edit := LineEdit.new()
	edit.text = value
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.text_changed.connect(func(v): on_change.call(v); _host._sync_to_code_editor())
	hbox.add_child(edit)

func add_labeled_field(parent: Control, label_text: String, value: String, on_change: Callable) -> void:
	add_text_field(parent, label_text, value, on_change)

func add_multiline_field(parent: Control, value: String, on_change: Callable) -> void:
	var edit := TextEdit.new()
	edit.text = value
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	edit.size_flags_stretch_ratio = 2.0
	edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	edit.add_theme_font_size_override("font_size", 13)
	var line_count: int = maxi(1, value.count("\n") + 1)
	edit.custom_minimum_size.y = clampi(line_count * 20, 120, 400)
	edit.text_changed.connect(func():
		on_change.call(edit.text)
		_host._sync_to_code_editor()
		var lc: int = maxi(1, edit.text.count("\n") + 1)
		edit.custom_minimum_size.y = clampi(lc * 20, 120, 400)
	)
	parent.add_child(edit)

func add_spin_field(parent: Control, label_text: String, value: float, min_val: float, max_val: float, on_change: Callable) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	parent.add_child(hbox)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 110
	lbl.add_theme_color_override("font_color", C_LABEL)
	lbl.add_theme_font_size_override("font_size", 13)
	hbox.add_child(lbl)
	var spin := SpinBox.new()
	spin.min_value = min_val
	spin.max_value = max_val
	spin.value = value
	spin.step = 0.01
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.value_changed.connect(func(v): on_change.call(v); _host._sync_to_code_editor())
	hbox.add_child(spin)

func add_button(parent: Control, text: String, on_press: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.pressed.connect(on_press)
	btn.add_theme_color_override("font_color", C_GREEN)
	parent.add_child(btn)

## 获取字段的友好标签
func field_label(field: String) -> String:
	return FIELD_LABELS.get(field, field)

## === 复合编辑器 ===

func add_list_editor(parent: Control, data_array: Array, fields: Array[String], on_add: Callable) -> void:
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 2)
	parent.add_child(container)

	var empty_hint := Label.new()
	empty_hint.text = "暂无数据，点击下方 [+ 添加] 按钮创建第一条记录"
	empty_hint.add_theme_font_size_override("font_size", 12)
	empty_hint.add_theme_color_override("font_color", C_EMPTY_HINT)
	empty_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_hint.add_theme_constant_override("margin_top", 12)
	empty_hint.add_theme_constant_override("margin_bottom", 12)
	container.add_child(empty_hint)

	var build_items: Callable
	build_items = func() -> void:
		for child in container.get_children():
			if child != empty_hint and not child is Button:
				child.queue_free()
		empty_hint.visible = data_array.is_empty()
		for i in data_array.size():
			var item_panel := PanelContainer.new()
			var sb := StyleBoxFlat.new()
			sb.bg_color = C_BG_ROW if i % 2 == 0 else C_BG_ROW_ALT
			sb.corner_radius_top_left = 4
			sb.corner_radius_top_right = 4
			sb.corner_radius_bottom_right = 4
			sb.corner_radius_bottom_left = 4
			sb.border_width_left = 1
			sb.border_width_top = 1
			sb.border_width_right = 1
			sb.border_width_bottom = 1
			sb.border_color = Color(0.25, 0.28, 0.35, 0.3)
			sb.content_margin_left = 10.0
			sb.content_margin_top = 6.0
			sb.content_margin_right = 10.0
			sb.content_margin_bottom = 6.0
			item_panel.add_theme_stylebox_override("panel", sb)
			container.add_child(item_panel)
			var main_vbox := VBoxContainer.new()
			main_vbox.add_theme_constant_override("separation", 4)
			item_panel.add_child(main_vbox)
			var header := HBoxContainer.new()
			header.add_theme_constant_override("separation", 8)
			main_vbox.add_child(header)
			var idx_lbl := Label.new()
			idx_lbl.text = "#%d" % (i + 1)
			idx_lbl.custom_minimum_size.x = 36
			idx_lbl.add_theme_color_override("font_color", C_ACCENT)
			idx_lbl.add_theme_font_size_override("font_size", 11)
			header.add_child(idx_lbl)
			var summary := Label.new()
			var first_val = data_array[i].get(fields[0], "") if fields.size() > 0 else ""
			var first_label_text := field_label(fields[0]) if fields.size() > 0 else ""
			summary.text = "%s: %s" % [first_label_text, str(first_val)] if first_val else "(未设置)"
			summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			summary.add_theme_color_override("font_color", C_TEXT)
			summary.add_theme_font_size_override("font_size", 12)
			summary.autowrap_mode = TextServer.AUTOWRAP_WORD
			header.add_child(summary)
			var toggle_btn := Button.new()
			toggle_btn.text = "▸"
			toggle_btn.custom_minimum_size = Vector2(28, 24)
			toggle_btn.add_theme_font_size_override("font_size", 11)
			toggle_btn.add_theme_color_override("font_color", C_ACCENT)
			toggle_btn.flat = true
			toggle_btn.tooltip_text = "展开编辑"
			header.add_child(toggle_btn)
			var del_btn := Button.new()
			del_btn.text = "删除"
			del_btn.custom_minimum_size = Vector2(44, 24)
			del_btn.add_theme_color_override("font_color", C_DANGER)
			del_btn.add_theme_font_size_override("font_size", 11)
			del_btn.flat = true
			del_btn.tooltip_text = "删除此条目"
			var item_idx := i
			del_btn.pressed.connect(func():
				if item_idx >= 0 and item_idx < data_array.size():
					data_array.remove_at(item_idx)
					build_items.call()
					_host._build_module_tree()
					_host._sync_to_code_editor()
			)
			header.add_child(del_btn)
			var edit_box := VBoxContainer.new()
			edit_box.add_theme_constant_override("separation", 6)
			edit_box.visible = false
			main_vbox.add_child(edit_box)
			for field in fields:
				if field == "id":
					continue
				var field_hbox := HBoxContainer.new()
				field_hbox.add_theme_constant_override("separation", 8)
				edit_box.add_child(field_hbox)
				var f_lbl := Label.new()
				f_lbl.text = field_label(field)
				f_lbl.custom_minimum_size.x = 100
				f_lbl.add_theme_color_override("font_color", C_LABEL)
				f_lbl.add_theme_font_size_override("font_size", 12)
				field_hbox.add_child(f_lbl)
				var val = data_array[i].get(field, "")
				if val is bool:
					var chk := CheckButton.new()
					chk.button_pressed = val
					chk.toggled.connect(func(p): data_array[i][field] = p; _host._sync_to_code_editor())
					field_hbox.add_child(chk)
				elif val is float or val is int:
					var spin := SpinBox.new()
					spin.value = float(val)
					spin.step = 0.01
					spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					spin.value_changed.connect(func(v): data_array[i][field] = v; _host._sync_to_code_editor())
					field_hbox.add_child(spin)
				else:
					var edit := LineEdit.new()
					edit.text = str(val)
					edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					edit.placeholder_text = field_label(field)
					edit.text_changed.connect(func(v): data_array[i][field] = v; _host._sync_to_code_editor())
					field_hbox.add_child(edit)
			toggle_btn.pressed.connect(func():
				edit_box.visible = not edit_box.visible
				toggle_btn.text = "▾" if edit_box.visible else "▸"
				toggle_btn.tooltip_text = "折叠" if edit_box.visible else "展开编辑"
				var fv = data_array[i].get(fields[0], "") if fields.size() > 0 else ""
				var fl := field_label(fields[0]) if fields.size() > 0 else ""
				summary.text = "%s: %s" % [fl, str(fv)] if fv else "(未设置)"
			)

	build_items.call()

	var add_btn := Button.new()
	add_btn.text = "+ 添加"
	add_btn.add_theme_color_override("font_color", C_GREEN)
	add_btn.add_theme_font_size_override("font_size", 12)
	add_btn.flat = true
	add_btn.custom_minimum_size = Vector2(0, 28)
	add_btn.pressed.connect(func():
		on_add.call()
		build_items.call()
		_host._build_module_tree()
		_host._sync_to_code_editor()
	)
	container.add_child(add_btn)

func add_dict_editor(parent: Control, data: Dictionary, keys: Array) -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	parent.add_child(vbox)
	for key in keys:
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		vbox.add_child(hbox)
		var lbl := Label.new()
		lbl.text = field_label(str(key))
		lbl.custom_minimum_size.x = 130
		lbl.add_theme_color_override("font_color", C_LABEL)
		lbl.add_theme_font_size_override("font_size", 13)
		hbox.add_child(lbl)
		var val = data.get(key, "")
		if val is bool:
			var chk := CheckButton.new()
			chk.button_pressed = val
			chk.toggled.connect(func(p): data[key] = p; _host._sync_to_code_editor())
			hbox.add_child(chk)
		elif val is float or val is int:
			var spin := SpinBox.new()
			spin.value = float(val)
			spin.step = 0.01
			spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			spin.value_changed.connect(func(v): data[key] = v; _host._sync_to_code_editor())
			hbox.add_child(spin)
		else:
			var edit := LineEdit.new()
			edit.text = str(val)
			edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			edit.text_changed.connect(func(v): data[key] = v; _host._sync_to_code_editor())
			hbox.add_child(edit)
