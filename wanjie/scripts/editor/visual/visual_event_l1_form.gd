## VisualEventL1Form - 事件编辑器 L1 表单模块（零基础填空式创作）
## 从 visual_event.gd 提取，通过 _host (duck-typed) 访问宿主 visual_event.gd。
## 宿主方法: _host._mark_dirty() / _host._sync_to_code_editor() / _host._rebuild_tree() / _host._ui() / _host._current_script()
class_name VisualEventL1Form
extends RefCounted

## 宿主 visual_event.gd 实例 (duck-typed)
var _host
## L1表单模式当前选中的事件ID
var _l1_current_event_id: String = ""
## L1 表单容器 (由宿主在 _create_event_editor 中设置)
var _event_l1_container: Control = null
## 表单撤销/重做（快照栈）
var _form_undo: EditorUndoRedo = null
## 上次表单数据快照（差分提交基准）
var _form_last_snapshot: Variant = null

func _init(host) -> void:
	_host = host

## === 表单撤销/重做（差分快照） ===

## 当前事件系统数据快照（JSON 深拷贝, 纯数据无 Vector2, 往返安全）
func _form_snapshot() -> Variant:
	if _host._current_script() == null or _host._current_script().event_system == null:
		return null
	return JSON.parse_string(JSON.stringify(_host._current_script().event_system.story_events))

## 表单重建前自动提交差异（首次仅记录基准, 无变化不提交）
func _auto_commit_form_changes() -> void:
	var current: Variant = _form_snapshot()
	if current == null:
		return
	if _form_undo == null:
		_form_undo = EditorUndoRedo.new()
		_form_last_snapshot = current
		return
	if JSON.stringify(current) != JSON.stringify(_form_last_snapshot):
		_form_undo.commit("表单编辑", _form_last_snapshot, current)
		_form_last_snapshot = current

## 撤销最近一次表单编辑; 返回是否执行
func undo_form() -> bool:
	if _form_undo == null or not _form_undo.can_undo():
		return false
	var res: Dictionary = _form_undo.undo()
	if res.get("valid", false):
		_apply_form_state(res["state"])
	return true

## 重做表单编辑; 返回是否执行
func redo_form() -> bool:
	if _form_undo == null or not _form_undo.can_redo():
		return false
	var res: Dictionary = _form_undo.redo()
	if res.get("valid", false):
		_apply_form_state(res["state"])
	return true

## 恢复事件数据并重建表单
func _apply_form_state(state: Variant) -> void:
	var ws: WorldScriptData = _host._current_script()
	if ws == null or ws.event_system == null:
		return
	# JSON 还原的 Array 元素为 Variant, 转回 Array[Dictionary]
	var evs: Array[Dictionary] = []
	if state is Array:
		for e in state:
			if e is Dictionary:
				evs.append(e)
	ws.event_system.story_events = evs
	_form_last_snapshot = _form_snapshot()
	_host._sync_to_code_editor()
	_host._mark_dirty()
	if _event_l1_container:
		_build_l1_form_view(_event_l1_container)

## 当前是否有可撤销/可重做的操作
func can_undo_form() -> bool:
	return _form_undo != null and _form_undo.can_undo()

func can_redo_form() -> bool:
	return _form_undo != null and _form_undo.can_redo()

## 确保所有事件有结构化条件/动作(缺少则从运行时格式反编译)
func _l1_ensure_all_structured() -> void:
	if _host._current_script() == null or _host._current_script().event_system == null:
		return
	for e in _host._current_script().event_system.story_events:
		_l1_ensure_event_structured(e)

## 确保单个事件有结构化数据
func _l1_ensure_event_structured(event: Dictionary) -> void:
	if not event.has("conditions_structured"):
		event["conditions_structured"] = ConditionCompiler.decompile_conditions(event.get("conditions", []))
	for choice in event.get("choices", []):
		if not choice.has("consequences_structured"):
			choice["consequences_structured"] = ConditionCompiler.decompile_actions(choice.get("consequences", []))

## 将所有事件的结构化数据编译为运行时格式
func _l1_sync_all_to_runtime() -> void:
	if _host._current_script() == null or _host._current_script().event_system == null:
		return
	for e in _host._current_script().event_system.story_events:
		_l1_sync_event_to_runtime(e)

## 将单个事件的结构化数据编译为运行时格式(双写兼容, 游玩器零改动)
func _l1_sync_event_to_runtime(event: Dictionary) -> void:
	if event.has("conditions_structured"):
		event["conditions"] = ConditionCompiler.compile_conditions(event["conditions_structured"])
	for choice in event.get("choices", []):
		if choice.has("consequences_structured"):
			choice["consequences"] = ConditionCompiler.compile_actions(choice["consequences_structured"])

## 构建L1表单主视图(左事件列表 + 右事件表单)
func _build_l1_form_view(container: Control) -> void:
	# 表单重建前自动提交未记录的编辑差异
	_auto_commit_form_changes()
	for child in container.get_children():
		child.queue_free()
	if _host._current_script() == null or _host._current_script().event_system == null:
		return
	var hsplit := HSplitContainer.new()
	hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hsplit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hsplit.add_theme_constant_override("separation", 4)
	container.add_child(hsplit)
	# 左侧: 事件列表
	var list_scroll := ScrollContainer.new()
	list_scroll.custom_minimum_size.x = 200
	list_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.size_flags_stretch_ratio = 0.6
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hsplit.add_child(list_scroll)
	var list_vbox := VBoxContainer.new()
	list_vbox.name = "L1EventList"
	list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_vbox.add_theme_constant_override("separation", 4)
	list_scroll.add_child(list_vbox)
	_build_l1_event_list(list_vbox)
	# 右侧: 事件表单
	var form_scroll := ScrollContainer.new()
	form_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form_scroll.size_flags_stretch_ratio = 1.4
	form_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hsplit.add_child(form_scroll)
	var form_vbox := VBoxContainer.new()
	form_vbox.name = "L1EventForm"
	form_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form_vbox.add_theme_constant_override("separation", 8)
	form_scroll.add_child(form_vbox)
	# 默认选中第一个事件
	if _l1_current_event_id.is_empty() and not _host._current_script().event_system.story_events.is_empty():
		_l1_current_event_id = _host._current_script().event_system.story_events[0].get("id", "")
	if _l1_current_event_id != "":
		_build_l1_event_form(form_vbox, _l1_current_event_id)
	else:
		_host._ui().add_section_label(form_vbox, "📝 事件表单编辑")
		_host._ui().add_info_label(form_vbox, "点击左侧 [+ 添加事件] 创建你的第一个事件")

## 构建L1事件列表
func _build_l1_event_list(list_vbox: VBoxContainer) -> void:
	for child in list_vbox.get_children():
		child.queue_free()
	var es = _host._current_script().event_system
	_host._ui().add_section_label(list_vbox, "▶ 剧情事件")
	var add_btn := Button.new()
	add_btn.text = "+ 添加事件"
	add_btn.add_theme_color_override("font_color", EditorUIFactory.C_GREEN)
	add_btn.add_theme_font_size_override("font_size", 12)
	add_btn.pressed.connect(func():
		var new_id := "event_%d" % es.story_events.size()
		es.add_story_event(new_id, "新事件", "")
		_l1_ensure_event_structured(es.get_story_event(new_id))
		_l1_current_event_id = new_id
		_host._mark_dirty()
		_host._sync_to_code_editor()
		_host._rebuild_tree()
		_build_l1_form_view(_event_l1_container)
	)
	list_vbox.add_child(add_btn)
	if es.story_events.is_empty():
		var hint := Label.new()
		hint.text = "（暂无事件，点击上方「+ 添加事件」创建第一个剧情事件）"
		hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55, 0.8))
		hint.add_theme_font_size_override("font_size", 12)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list_vbox.add_child(hint)
	for e in es.story_events:
		var eid: String = e.get("id", "")
		var row := HBoxContainer.new()
		var btn := Button.new()
		btn.text = e.get("name", eid)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 12)
		if eid == _l1_current_event_id:
			btn.add_theme_color_override("font_color", EditorUIFactory.C_ACCENT)
		btn.pressed.connect(func():
			_l1_current_event_id = eid
			_build_l1_form_view(_event_l1_container)
		)
		row.add_child(btn)
		# 复制事件
		var dup_btn := Button.new()
		dup_btn.text = "⧉"
		dup_btn.tooltip_text = "复制事件"
		dup_btn.custom_minimum_size.x = 28
		dup_btn.add_theme_font_size_override("font_size", 11)
		dup_btn.pressed.connect(func():
			var src: Dictionary = es.get_story_event(eid)
			if src.is_empty():
				return
			var new_id := "event_dup_%d" % Time.get_ticks_msec()
			var copy := src.duplicate(true)
			copy["id"] = new_id
			copy["name"] = str(src.get("name", "")) + " 副本"
			es.story_events.append(copy)
			_host._mark_dirty()
			_host._sync_to_code_editor()
			_build_l1_form_view(_event_l1_container))
		# 简易模式隐藏复制按钮（避免新手误操作）
		if not EditorMode.is_simple():
			row.add_child(dup_btn)
		# 删除事件
		var del_btn := Button.new()
		del_btn.text = "✕"
		del_btn.tooltip_text = "删除事件"
		del_btn.custom_minimum_size.x = 28
		del_btn.add_theme_color_override("font_color", IDETheme.C_RED)
		del_btn.add_theme_font_size_override("font_size", 11)
		del_btn.pressed.connect(func():
			for i in es.story_events.size():
				if es.story_events[i].get("id", "") == eid:
					es.story_events.remove_at(i)
					break
			if _l1_current_event_id == eid:
				_l1_current_event_id = ""
			_host._mark_dirty()
			_host._sync_to_code_editor()
			_build_l1_form_view(_event_l1_container))
		row.add_child(del_btn)
		list_vbox.add_child(row)

## 构建L1单事件表单
func _build_l1_event_form(form_vbox: VBoxContainer, event_id: String) -> void:
	for child in form_vbox.get_children():
		child.queue_free()
	var es = _host._current_script().event_system
	var event: Dictionary = es.get_story_event(event_id)
	if event.is_empty():
		_host._ui().add_section_label(form_vbox, "事件未找到")
		return
	_l1_ensure_event_structured(event)
	_host._ui().add_section_label(form_vbox, "📝 %s" % event.get("name", event_id))
	# 基本信息
	_host._ui().add_text_field(form_vbox, "事件名称", event.get("name", ""), func(v):
		var name := str(v).strip_edges()
		if name.is_empty():
			ToastManager.warning("事件名称不能为空，已恢复为默认")
			name = "未命名事件"
		event["name"] = name
		_host._mark_dirty()
		var lv: Control = _event_l1_container.find_child("L1EventList", true, false)
		if lv:
			_build_l1_event_list(lv)
	, "玩家看到的剧情事件标题（必填）")
	_host._ui().add_multiline_field(form_vbox, event.get("description", ""), func(v):
		event["description"] = v
		_host._mark_dirty()
	)
	_add_l1_trigger_type_field(form_vbox, event)
	# 前置条件与触发条件为高级区块（简易模式隐藏）
	if EditorMode.is_visible(EditorMode.FIELD_ADVANCED):
		_add_l1_prereq_field(form_vbox, event)
		_host._ui().add_section_label(form_vbox, "🎯 触发条件 (满足什么时候才发生?)", 2)
		_build_l1_conditions_editor(form_vbox, event)
	else:
		_host._ui().add_info_label(form_vbox, "🛈 简易模式已隐藏「前置条件 / 触发条件」等高级设置，切换「详细/详尽」模式可编辑")
	# 玩家选择
	_host._ui().add_section_label(form_vbox, "🎮 玩家选择 (玩家可以做什么?)", 2)
	_build_l1_choices_editor(form_vbox, event)
	# 详尽模式额外显示调试信息
	if EditorMode.is_exhaustive():
		_host._ui().add_hseparator(form_vbox)
		_host._ui().add_info_label(form_vbox, "🔍 详尽模式：事件 ID「%s」· 结构化数据版本 %s" % [event_id, event.get("schema_version", "1")])

## 触发类型下拉
func _add_l1_trigger_type_field(form_vbox: VBoxContainer, event: Dictionary) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	form_vbox.add_child(hbox)
	var lbl := Label.new()
	lbl.text = "如何触发"
	lbl.custom_minimum_size.x = 110
	lbl.add_theme_color_override("font_color", EditorUIFactory.C_LABEL)
	lbl.add_theme_font_size_override("font_size", 13)
	hbox.add_child(lbl)
	var opt := OptionButton.new()
	var trigger_map := [
		["chain", "链式触发 (前置事件完成后)"],
		["time", "时间触发"],
		["condition", "条件触发 (满足下方条件后)"],
		["player_action", "玩家行为触发"],
	]
	var trigger_tips := {
		"chain": "依赖前置事件完成，按剧情顺序推进",
		"time": "到达指定游戏天数/时刻后自动触发",
		"condition": "满足设置的变量条件后触发",
		"player_action": "玩家做出特定行为（探索/对话等）时触发",
	}
	for t in trigger_map:
		opt.add_item(t[1])
		opt.set_item_tooltip(opt.item_count - 1, trigger_tips.get(t[0], ""))
	var cur: String = event.get("trigger_type", "chain")
	var sel := 0
	for i in trigger_map.size():
		if trigger_map[i][0] == cur:
			sel = i
			break
	opt.selected = sel
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.item_selected.connect(func(i):
		event["trigger_type"] = trigger_map[i][0]
		_host._mark_dirty()
		_host._sync_to_code_editor()
	)
	hbox.add_child(opt)
	# 时段约束下拉（随机/夜间事件可选）
	var period_hbox := HBoxContainer.new()
	period_hbox.add_theme_constant_override("separation", 8)
	form_vbox.add_child(period_hbox)
	var period_lbl := Label.new()
	period_lbl.text = "限定时段"
	period_lbl.custom_minimum_size.x = 110
	period_lbl.add_theme_color_override("font_color", EditorUIFactory.C_LABEL)
	period_lbl.add_theme_font_size_override("font_size", 13)
	period_hbox.add_child(period_lbl)
	var period_opt := OptionButton.new()
	var period_map := [
		["", "不限时段"],
		["清晨", "仅清晨"],
		["白天", "仅白天"],
		["傍晚", "仅傍晚"],
		["夜晚", "仅夜晚"],
	]
	for pm in period_map:
		period_opt.add_item(pm[1])
	var cur_period: String = str(event.get("period", ""))
	var period_sel := 0
	for pi in period_map.size():
		if period_map[pi][0] == cur_period:
			period_sel = pi
			break
	period_opt.selected = period_sel
	period_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	period_opt.tooltip_text = "随机事件仅在此时段触发（如「夜晚」限制夜间遭遇）"
	period_opt.item_selected.connect(func(pi):
		if period_map[pi][0] == "":
			event.erase("period")
		else:
			event["period"] = period_map[pi][0]
		_host._mark_dirty()
		_host._sync_to_code_editor()
	)
	period_hbox.add_child(period_opt)

## 前置事件下拉
func _add_l1_prereq_field(form_vbox: VBoxContainer, event: Dictionary) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	form_vbox.add_child(hbox)
	var lbl := Label.new()
	lbl.text = "前置事件"
	lbl.custom_minimum_size.x = 110
	lbl.add_theme_color_override("font_color", EditorUIFactory.C_LABEL)
	lbl.add_theme_font_size_override("font_size", 13)
	hbox.add_child(lbl)
	var opt := OptionButton.new()
	opt.add_item("(无)")
	var es = _host._current_script().event_system
	var ids: Array = []
	for e in es.story_events:
		var eid: String = e.get("id", "")
		if eid != event.get("id", ""):
			ids.append(eid)
			opt.add_item("%s (%s)" % [e.get("name", eid), eid])
	var cur: String = event.get("prerequisite", "")
	var sel := 0
	for i in ids.size():
		if ids[i] == cur:
			sel = i + 1
			break
	opt.selected = sel
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.item_selected.connect(func(i):
		event["prerequisite"] = "" if i == 0 else ids[i - 1]
		_host._mark_dirty()
		_host._sync_to_code_editor()
	)
	hbox.add_child(opt)

## === L1 触发条件编辑器(结构化条件下拉, 无需写代码) ===
func _build_l1_conditions_editor(form_vbox: VBoxContainer, event: Dictionary) -> void:
	var section := VBoxContainer.new()
	section.name = "L1ConditionsSection"
	section.add_theme_constant_override("separation", 4)
	form_vbox.add_child(section)
	_rebuild_conditions_section(section, event)

func _rebuild_conditions_section(section: VBoxContainer, event: Dictionary) -> void:
	# 编辑后重建前提交差异快照
	_auto_commit_form_changes()
	for child in section.get_children():
		child.queue_free()
	if not event.has("conditions_structured"):
		event["conditions_structured"] = ConditionCompiler.decompile_conditions(event.get("conditions", []))
	var conds: Array = event["conditions_structured"]
	if conds.is_empty():
		var hint := Label.new()
		hint.text = "  暂无触发条件 → 事件随时可被触发"
		hint.add_theme_font_size_override("font_size", 12)
		hint.add_theme_color_override("font_color", EditorUIFactory.C_EMPTY_HINT)
		section.add_child(hint)
	for i in conds.size():
		_build_l1_condition_row(section, conds, i, event, section)
	var add_btn := Button.new()
	add_btn.text = "+ 添加触发条件"
	add_btn.add_theme_color_override("font_color", EditorUIFactory.C_GREEN)
	add_btn.add_theme_font_size_override("font_size", 12)
	add_btn.pressed.connect(func():
		conds.append(ConditionCompiler.make_condition("player", "level", ">=", 1))
		_l1_sync_event_to_runtime(event)
		_host._mark_dirty()
		_host._sync_to_code_editor()
		_rebuild_conditions_section(section, event)
	)
	section.add_child(add_btn)

## 构建单个条件行(主体+字段+运算符+值下拉, 改主体类型时重建本区)
func _build_l1_condition_row(parent: Control, conds: Array, idx: int, event: Dictionary, section: VBoxContainer) -> void:
	var cond: Dictionary = conds[idx]
	# raw透传条件(高级模式下创建、无法反编译): 只读展示, 保护数据不被表单误改
	if not cond.get("structured", true):
		var ro_lbl := Label.new()
		ro_lbl.text = "  🔒 [高级] %s  (此条件在高级模式创建, 表单不可编辑; 切换L3节点图可保留)" % cond.get("raw", "")
		ro_lbl.add_theme_font_size_override("font_size", 12)
		ro_lbl.add_theme_color_override("font_color", EditorUIFactory.C_EMPTY_HINT)
		ro_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		parent.add_child(ro_lbl)
		return
	var row := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.15, 0.2, 1)
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_right = 4
	sb.corner_radius_bottom_left = 4
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.28, 0.32, 0.42, 0.4)
	sb.content_margin_left = 8.0
	sb.content_margin_top = 6.0
	sb.content_margin_right = 8.0
	sb.content_margin_bottom = 6.0
	row.add_theme_stylebox_override("panel", sb)
	parent.add_child(row)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	row.add_child(vbox)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	vbox.add_child(hbox)
	# 当/且标签
	var when_lbl := Label.new()
	when_lbl.text = "当" if idx == 0 else "且"
	when_lbl.add_theme_color_override("font_color", EditorUIFactory.C_ACCENT)
	when_lbl.add_theme_font_size_override("font_size", 13)
	when_lbl.custom_minimum_size.x = 24
	hbox.add_child(when_lbl)
	var subject_type: String = cond.get("subject_type", "player")
	# 主体类型下拉
	var subject_opt := OptionButton.new()
	var subject_keys: Array = ConditionCompiler.SUBJECT_TYPES.keys()
	for k in subject_keys:
		subject_opt.add_item(ConditionCompiler.SUBJECT_TYPES[k])
	var s_idx: int = subject_keys.find(subject_type)
	subject_opt.selected = s_idx if s_idx >= 0 else 0
	subject_opt.custom_minimum_size.x = 80
	subject_opt.add_theme_font_size_override("font_size", 12)
	hbox.add_child(subject_opt)
	# 主体ID (势力/历史需要)
	if subject_type == "faction" or subject_type == "history":
		var id_edit := LineEdit.new()
		id_edit.text = cond.get("subject_id", "")
		id_edit.placeholder_text = "势力ID" if subject_type == "faction" else "事件ID"
		id_edit.custom_minimum_size.x = 110
		id_edit.add_theme_font_size_override("font_size", 12)
		id_edit.text_changed.connect(func(v):
			cond["subject_id"] = v
			_l1_sync_event_to_runtime(event)
			_host._mark_dirty()
			_host._sync_to_code_editor()
		)
		hbox.add_child(id_edit)
	# 字段 (player/time/faction用下拉, world用输入框, location/history固定)
	if subject_type == "player" or subject_type == "time" or subject_type == "faction":
		var field_opt := OptionButton.new()
		var fields: Dictionary = {}
		match subject_type:
			"player": fields = ConditionCompiler.PLAYER_FIELDS
			"time": fields = ConditionCompiler.TIME_FIELDS
			"faction": fields = ConditionCompiler.FACTION_FIELDS
		var field_keys: Array = fields.keys()
		for fk in field_keys:
			field_opt.add_item(fields[fk]["label"])
		var f_idx: int = field_keys.find(cond.get("field", ""))
		field_opt.selected = f_idx if f_idx >= 0 else 0
		field_opt.custom_minimum_size.x = 80
		field_opt.add_theme_font_size_override("font_size", 12)
		field_opt.item_selected.connect(func(fi):
			cond["field"] = field_keys[fi]
			_l1_sync_event_to_runtime(event)
			_host._mark_dirty()
			_host._sync_to_code_editor()
		)
		hbox.add_child(field_opt)
	elif subject_type == "world":
		var field_edit := LineEdit.new()
		field_edit.text = cond.get("field", "")
		field_edit.placeholder_text = "世界变量名"
		field_edit.custom_minimum_size.x = 110
		field_edit.add_theme_font_size_override("font_size", 12)
		field_edit.text_changed.connect(func(v):
			cond["field"] = v
			_l1_sync_event_to_runtime(event)
			_host._mark_dirty()
			_host._sync_to_code_editor()
		)
		hbox.add_child(field_edit)
	# 运算符(history固定为contains, 不显示)
	if subject_type != "history":
		var op_opt := OptionButton.new()
		var op_keys: Array = ConditionCompiler.OPERATORS.keys()
		for ok in op_keys:
			op_opt.add_item(ConditionCompiler.OPERATORS[ok])
		var o_idx: int = op_keys.find(cond.get("operator", ">="))
		op_opt.selected = o_idx if o_idx >= 0 else 0
		op_opt.custom_minimum_size.x = 56
		op_opt.add_theme_font_size_override("font_size", 12)
		op_opt.item_selected.connect(func(oi):
			cond["operator"] = op_keys[oi]
			_l1_sync_event_to_runtime(event)
			_host._mark_dirty()
			_host._sync_to_code_editor()
		)
		hbox.add_child(op_opt)
		# 值
		var value_edit := LineEdit.new()
		value_edit.text = str(cond.get("value", ""))
		value_edit.placeholder_text = "值"
		value_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value_edit.add_theme_font_size_override("font_size", 12)
		value_edit.text_changed.connect(func(v):
			cond["value"] = ConditionCompiler._string_to_value(v)
			_l1_sync_event_to_runtime(event)
			_host._mark_dirty()
			_host._sync_to_code_editor()
		)
		hbox.add_child(value_edit)
	# 删除按钮
	var del_btn := Button.new()
	del_btn.text = "✕"
	del_btn.custom_minimum_size.x = 28
	del_btn.add_theme_font_size_override("font_size", 12)
	del_btn.pressed.connect(func():
		conds.remove_at(idx)
		_l1_sync_event_to_runtime(event)
		_host._mark_dirty()
		_host._sync_to_code_editor()
		_rebuild_conditions_section(section, event)
	)
	hbox.add_child(del_btn)
	# 中文描述预览
	var desc_lbl := Label.new()
	desc_lbl.text = "  →" + ConditionCompiler.describe_condition(cond)
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", EditorUIFactory.C_INFO)
	vbox.add_child(desc_lbl)
	# 主体类型变更 -> 重置字段并重建本行
	subject_opt.item_selected.connect(func(si):
		cond["subject_type"] = subject_keys[si]
		cond["field"] = _l1_default_field(cond["subject_type"])
		if cond["subject_type"] == "history":
			cond["operator"] = "contains"
		_l1_sync_event_to_runtime(event)
		_host._mark_dirty()
		_host._sync_to_code_editor()
		_rebuild_conditions_section(section, event)
	)

## 主体类型对应的默认字段
func _l1_default_field(subject_type: String) -> String:
	match subject_type:
		"player": return "level"
		"time": return "day"
		"faction": return "power_level"
		"location": return "region"
		"world": return "variable"
	return ""

## === L1 玩家选择/动作编辑器 ===
func _build_l1_choices_editor(form_vbox: VBoxContainer, event: Dictionary) -> void:
	var section := VBoxContainer.new()
	section.name = "L1ChoicesSection"
	section.add_theme_constant_override("separation", 6)
	form_vbox.add_child(section)
	_rebuild_choices_section(section, event)

func _rebuild_choices_section(section: VBoxContainer, event: Dictionary) -> void:
	# 编辑后重建前提交差异快照
	_auto_commit_form_changes()
	for child in section.get_children():
		child.queue_free()
	if not event.has("choices"):
		event["choices"] = []
	var choices: Array = event["choices"]
	if choices.is_empty():
		var hint := Label.new()
		hint.text = "  暂无玩家选择"
		hint.add_theme_font_size_override("font_size", 12)
		hint.add_theme_color_override("font_color", EditorUIFactory.C_EMPTY_HINT)
		section.add_child(hint)
	for i in choices.size():
		_build_l1_choice_card(section, choices, i, event, section)
	var add_btn := Button.new()
	add_btn.text = "+ 添加玩家选择"
	add_btn.add_theme_color_override("font_color", EditorUIFactory.C_GREEN)
	add_btn.add_theme_font_size_override("font_size", 12)
	add_btn.pressed.connect(func():
		var choice_id := "choice_%s" % char(97 + choices.size())
		choices.append({"id": choice_id, "text": "新选择", "consequences": [], "consequences_structured": []})
		_l1_sync_event_to_runtime(event)
		_host._mark_dirty()
		_host._sync_to_code_editor()
		_rebuild_choices_section(section, event)
	)
	section.add_child(add_btn)

## 构建单个选择卡片 (选择文本 + 效果动作列表)
func _build_l1_choice_card(parent: Control, choices: Array, idx: int, event: Dictionary, section: VBoxContainer) -> void:
	var choice: Dictionary = choices[idx]
	if not choice.has("consequences_structured"):
		choice["consequences_structured"] = ConditionCompiler.decompile_actions(choice.get("consequences", []))
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.145, 0.19, 1)
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_right = 4
	sb.corner_radius_bottom_left = 4
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.3, 0.35, 0.45, 0.4)
	sb.content_margin_left = 10.0
	sb.content_margin_top = 8.0
	sb.content_margin_right = 10.0
	sb.content_margin_bottom = 8.0
	card.add_theme_stylebox_override("panel", sb)
	parent.add_child(card)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)
	# 选择文本 + 删除
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	vbox.add_child(hbox)
	var lbl := Label.new()
	lbl.text = "选择%d:" % (idx + 1)
	lbl.add_theme_color_override("font_color", EditorUIFactory.C_ACCENT)
	lbl.add_theme_font_size_override("font_size", 13)
	hbox.add_child(lbl)
	var text_edit := LineEdit.new()
	text_edit.text = choice.get("text", "")
	text_edit.placeholder_text = "玩家看到的选项文字"
	text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_edit.add_theme_font_size_override("font_size", 12)
	text_edit.text_changed.connect(func(v):
		choice["text"] = v
		_l1_sync_event_to_runtime(event)
		_host._mark_dirty()
		_host._sync_to_code_editor()
	)
	hbox.add_child(text_edit)
	var del_btn := Button.new()
	del_btn.text = "✕ 删除选择"
	del_btn.add_theme_font_size_override("font_size", 11)
	del_btn.pressed.connect(func():
		choices.remove_at(idx)
		_l1_sync_event_to_runtime(event)
		_host._mark_dirty()
		_host._sync_to_code_editor()
		_rebuild_choices_section(section, event)
	)
	hbox.add_child(del_btn)
	# 效果动作列表
	var actions: Array = choice["consequences_structured"]
	var actions_box := VBoxContainer.new()
	actions_box.add_theme_constant_override("separation", 2)
	vbox.add_child(actions_box)
	for j in actions.size():
		_build_l1_action_row(actions_box, actions, j, event, section, choice)
	var add_action_btn := Button.new()
	add_action_btn.text = "  + 添加效果 (选择后发生什么)"
	add_action_btn.add_theme_color_override("font_color", EditorUIFactory.C_GREEN)
	add_action_btn.add_theme_font_size_override("font_size", 11)
	add_action_btn.pressed.connect(func():
		actions.append(ConditionCompiler.make_action("modify_stat", "player", "", {"field": "gold", "op": "+", "value": 10}))
		choice["consequences_structured"] = actions
		_l1_sync_event_to_runtime(event)
		_host._mark_dirty()
		_host._sync_to_code_editor()
		_rebuild_choices_section(section, event)
	)
	vbox.add_child(add_action_btn)

## 构建单个动作行(动作类型下拉 + 参数, 改类型时重建本区)
func _build_l1_action_row(parent: Control, actions: Array, idx: int, event: Dictionary, section: VBoxContainer, choice: Dictionary) -> void:
	var action: Dictionary = actions[idx]
	# raw透传动作: 只读展示, 保护数据
	if not action.get("structured", true):
		var ro_lbl := Label.new()
		ro_lbl.text = "    🔒 [高级] %s: %s" % [action.get("raw_target", ""), action.get("raw_effect", "")]
		ro_lbl.add_theme_font_size_override("font_size", 12)
		ro_lbl.add_theme_color_override("font_color", EditorUIFactory.C_EMPTY_HINT)
		ro_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		parent.add_child(ro_lbl)
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)
	var do_lbl := Label.new()
	do_lbl.text = "    →"
	do_lbl.add_theme_color_override("font_color", EditorUIFactory.C_ACCENT_DIM)
	do_lbl.add_theme_font_size_override("font_size", 12)
	row.add_child(do_lbl)
	# 动作类型下拉
	var type_opt := OptionButton.new()
	var type_keys: Array = ConditionCompiler.ACTION_TYPES.keys()
	for k in type_keys:
		type_opt.add_item(ConditionCompiler.ACTION_TYPES[k])
	var cur_type: String = action.get("action_type", "modify_stat")
	var t_idx: int = type_keys.find(cur_type)
	type_opt.selected = t_idx if t_idx >= 0 else 0
	type_opt.custom_minimum_size.x = 96
	type_opt.add_theme_font_size_override("font_size", 12)
	row.add_child(type_opt)
	var params: Dictionary = action.get("params", {})
	match cur_type:
		"modify_stat":
			_l1_action_field_opt(row, action, params, event)
			_l1_action_op_opt(row, action, params, event)
			_l1_action_value_edit(row, action, params, event)
		"give_item":
			_l1_action_text_param(row, action, params, "item_id", "物品ID", event)
			_l1_action_value_edit(row, action, params, event, "quantity", "数量")
		"trigger_event":
			_l1_action_event_opt(row, action, params, event)
		"change_relation":
			_l1_action_text_param(row, action, params, "_target_id", "势力ID", event)
			_l1_action_value_edit(row, action, params, event, "delta", "关系变化")
		"set_variable":
			_l1_action_text_param(row, action, params, "var_name", "变量名", event)
			_l1_action_value_edit(row, action, params, event, "value", "值")
		"play_dialog":
			_l1_action_text_param(row, action, params, "dialog_id", "对话ID", event)
		"custom":
			_l1_action_text_param(row, action, params, "text", "自定义效果文本", event)
	# 删除
	var del_btn := Button.new()
	del_btn.text = "✕"
	del_btn.custom_minimum_size.x = 28
	del_btn.add_theme_font_size_override("font_size", 12)
	del_btn.pressed.connect(func():
		actions.remove_at(idx)
		choice["consequences_structured"] = actions
		_l1_sync_event_to_runtime(event)
		_host._mark_dirty()
		_host._sync_to_code_editor()
		_rebuild_choices_section(section, event)
	)
	row.add_child(del_btn)
	# 动作类型变更 -> 重建
	type_opt.item_selected.connect(func(si):
		actions[idx] = _l1_default_action(type_keys[si])
		choice["consequences_structured"] = actions
		_l1_sync_event_to_runtime(event)
		_host._mark_dirty()
		_host._sync_to_code_editor()
		_rebuild_choices_section(section, event)
	)

## 动作参数: 字段下拉 (modify_stat)
func _l1_action_field_opt(row: Control, action: Dictionary, params: Dictionary, event: Dictionary) -> void:
	var field_opt := OptionButton.new()
	var fields: Dictionary = ConditionCompiler.PLAYER_FIELDS
	var field_keys: Array = fields.keys()
	for fk in field_keys:
		field_opt.add_item(fields[fk]["label"])
	var f_idx: int = field_keys.find(params.get("field", ""))
	field_opt.selected = f_idx if f_idx >= 0 else 0
	field_opt.custom_minimum_size.x = 80
	field_opt.add_theme_font_size_override("font_size", 12)
	field_opt.item_selected.connect(func(fi):
		params["field"] = field_keys[fi]
		action["params"] = params
		_l1_sync_event_to_runtime(event)
		_host._mark_dirty()
		_host._sync_to_code_editor()
	)
	row.add_child(field_opt)

## 动作参数: +/- 下拉 (modify_stat)
func _l1_action_op_opt(row: Control, action: Dictionary, params: Dictionary, event: Dictionary) -> void:
	var op_opt := OptionButton.new()
	op_opt.add_item("增加 (+)")
	op_opt.add_item("减少 (-)")
	op_opt.selected = 0 if params.get("op", "+") == "+" else 1
	op_opt.custom_minimum_size.x = 72
	op_opt.add_theme_font_size_override("font_size", 12)
	op_opt.item_selected.connect(func(oi):
		params["op"] = "+" if oi == 0 else "-"
		action["params"] = params
		_l1_sync_event_to_runtime(event)
		_host._mark_dirty()
		_host._sync_to_code_editor()
	)
	row.add_child(op_opt)

## 动作参数: 数值输入(通用, key默认value)
func _l1_action_value_edit(row: Control, action: Dictionary, params: Dictionary, event: Dictionary, key: String = "value", hint: String = "数值") -> void:
	var edit := LineEdit.new()
	edit.text = str(params.get(key, 0))
	edit.placeholder_text = hint
	edit.custom_minimum_size.x = 70
	edit.add_theme_font_size_override("font_size", 12)
	edit.text_changed.connect(func(v):
		params[key] = ConditionCompiler._string_to_value(v)
		action["params"] = params
		_l1_sync_event_to_runtime(event)
		_host._mark_dirty()
		_host._sync_to_code_editor()
	)
	row.add_child(edit)

## 动作参数: 文本输入 (通用)
func _l1_action_text_param(row: Control, action: Dictionary, params: Dictionary, key: String, hint: String, event: Dictionary) -> void:
	var edit := LineEdit.new()
	if key == "_target_id":
		edit.text = action.get("target_id", "")
	else:
		edit.text = str(params.get(key, ""))
	edit.placeholder_text = hint
	edit.custom_minimum_size.x = 110
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.add_theme_font_size_override("font_size", 12)
	edit.text_changed.connect(func(v):
		if key == "_target_id":
			action["target_id"] = v
		else:
			params[key] = v
			action["params"] = params
		_l1_sync_event_to_runtime(event)
		_host._mark_dirty()
		_host._sync_to_code_editor()
	)
	row.add_child(edit)

## 动作参数: 触发事件下拉 (列出现有事件)
func _l1_action_event_opt(row: Control, action: Dictionary, params: Dictionary, event: Dictionary) -> void:
	var opt := OptionButton.new()
	var es = _host._current_script().event_system
	var ids: Array = []
	for e in es.story_events:
		var eid: String = e.get("id", "")
		ids.append(eid)
		opt.add_item("%s (%s)" % [e.get("name", eid), eid])
	var cur: String = params.get("event_id", "")
	var sel: int = ids.find(cur)
	opt.selected = sel if sel >= 0 else (0 if not ids.is_empty() else -1)
	opt.custom_minimum_size.x = 140
	opt.add_theme_font_size_override("font_size", 12)
	opt.item_selected.connect(func(i):
		params["event_id"] = ids[i]
		action["params"] = params
		_l1_sync_event_to_runtime(event)
		_host._mark_dirty()
		_host._sync_to_code_editor()
	)
	row.add_child(opt)

## 动作类型对应的默认动作
func _l1_default_action(action_type: String) -> Dictionary:
	match action_type:
		"modify_stat":
			return ConditionCompiler.make_action("modify_stat", "player", "", {"field": "gold", "op": "+", "value": 10})
		"give_item":
			return ConditionCompiler.make_action("give_item", "player", "", {"item_id": "item_001", "quantity": 1})
		"trigger_event":
			return ConditionCompiler.make_action("trigger_event", "world", "", {"event_id": ""})
		"change_relation":
			return ConditionCompiler.make_action("change_relation", "faction", "faction_001", {"delta": 10})
		"set_variable":
			return ConditionCompiler.make_action("set_variable", "world", "", {"var_name": "var_name", "value": true})
		"play_dialog":
			return ConditionCompiler.make_action("play_dialog", "npc", "", {"dialog_id": ""})
		"custom":
			return ConditionCompiler.make_action("custom", "custom", "", {"text": ""})
	return ConditionCompiler.make_action("modify_stat", "player", "", {"field": "gold", "op": "+", "value": 10})
