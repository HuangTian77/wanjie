## Visual editor - Event system + Blueprint graph module
## 主文件: 入口/层切换/事件列表视图/概览详情
## 子模块(拆分自本文件):
##   - VisualEventL1Form   (visual_event_l1_form.gd):     L1 表单
##   - VisualEventBlueprint(visual_event_blueprint.gd):   L3 蓝图画布交互
##   - VisualBlueprintDraw (visual_blueprint_draw.gd):    纯绘制/几何静态工具
extends "res://scripts/editor/visual/visual_module_base.gd"

## L1 表单模块（懒实例化, 见 _create_event_editor）
var _l1_mod: VisualEventL1Form = null
## L3 蓝图模块（懒实例化, 见 _create_event_editor）
var _bp_mod: VisualEventBlueprint = null

## Entry: build event editor (corresponds to original _create_event_editor)
func create(_sub_type: String = "", _meta: Dictionary = {}) -> Control:
	return _create_event_editor(_sub_type, _meta)

func _create_event_editor(_sub_type: String, _meta: Dictionary) -> Control:
	# 实例化子模块（组合式拆分）
	_l1_mod = VisualEventL1Form.new(self)
	_bp_mod = VisualEventBlueprint.new(self)
	var root := PanelContainer.new()
	root.add_theme_stylebox_override("panel", _ui().make_bg_style())
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 0)
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(main_vbox)
	# === 层级切换器 (L1表单 / L3节点图) ===
	_build_layer_switcher(main_vbox)
	# === L3 节点图容器 ===
	var l3_container := VBoxContainer.new()
	l3_container.name = "L3GraphContainer"
	l3_container.add_theme_constant_override("separation", 0)
	l3_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	l3_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(l3_container)
	# === L1 表单容器 (默认隐藏) ===
	var l1_container := VBoxContainer.new()
	l1_container.name = "L1FormContainer"
	l1_container.add_theme_constant_override("separation", 0)
	l1_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	l1_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l1_container.visible = false
	main_vbox.add_child(l1_container)
	_l1_mod._event_l1_container = l1_container
	_event_l3_container = l3_container
	# 工具栏
	var toolbar_panel := PanelContainer.new()
	toolbar_panel.custom_minimum_size.y = 34
	var tb_sb := StyleBoxFlat.new()
	tb_sb.bg_color = Color(0.12, 0.13, 0.16, 1)
	tb_sb.border_width_bottom = 1
	tb_sb.border_color = Color(0.2, 0.25, 0.35, 0.4)
	tb_sb.content_margin_left = 8.0
	tb_sb.content_margin_right = 8.0
	toolbar_panel.add_theme_stylebox_override("panel", tb_sb)
	l3_container.add_child(toolbar_panel)
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 6)
	toolbar_panel.add_child(toolbar)
	_ui().add_toolbar_btn(toolbar, "+ 剧情事件", func(): _add_story_event_node(main_vbox))
	_ui().add_toolbar_btn(toolbar, "+ 随机事件", func(): _add_random_event_node(main_vbox))
	# 事件链为进阶功能（简易模式隐藏）
	if EditorMode.is_visible(EditorMode.FIELD_ADVANCED):
		_ui().add_toolbar_btn(toolbar, "+ 事件链", func(): _add_event_chain(main_vbox))
	_ui().add_toolbar_btn(toolbar, "🔄 自动布局", func(): _bp_mod._auto_layout_event_graph())
	_ui().add_toolbar_btn(toolbar, "🔍 适应画布", func(): _bp_mod._fit_canvas_to_nodes(main_vbox))
	# 蓝图导航
	_ui().add_toolbar_btn(toolbar, "|", func(): pass)
	_ui().add_toolbar_btn(toolbar, "← 返回事件列表", func(): _back_to_event_list())
	# 蓝图节点工具栏
	_ui().add_toolbar_btn(toolbar, "|", func(): pass)
	_ui().add_toolbar_btn(toolbar, "+Start", func(): _bp_mod._add_blueprint_node("start"))
	_ui().add_toolbar_btn(toolbar, "+Branch", func(): _bp_mod._add_blueprint_node("branch"))
	_ui().add_toolbar_btn(toolbar, "+Seq", func(): _bp_mod._add_blueprint_node("sequence"))
	_ui().add_toolbar_btn(toolbar, "+GetVar", func(): _bp_mod._add_blueprint_node("get_var"))
	_ui().add_toolbar_btn(toolbar, "+SetVar", func(): _bp_mod._add_blueprint_node("set_var"))
	_ui().add_toolbar_btn(toolbar, "+Print", func(): _bp_mod._add_blueprint_node("print"))
	_ui().add_toolbar_btn(toolbar, "+Expr", func(): _bp_mod._add_blueprint_node("expression"))
	_ui().add_toolbar_btn(toolbar, "编译", func(): _bp_mod._compile_blueprint())
	# 网格吸附切换
	_ui().add_toolbar_btn(toolbar, "|", func(): pass)
	var grid_btn: Button = _ui().add_toolbar_btn(toolbar, "📐 网格吸附", func(): pass)
	grid_btn.pressed.connect(func():
		_bp_mod._bp_grid_snap = not _bp_mod._bp_grid_snap
		grid_btn.text = "📐 网格吸附 ✓" if _bp_mod._bp_grid_snap else "📐 网格吸附"
	)
	grid_btn.text = "📐 网格吸附 ✓" if _bp_mod._bp_grid_snap else "📐 网格吸附"
	# 节点搜索
	_ui().add_toolbar_btn(toolbar, "|", func(): pass)
	_ui().add_toolbar_btn(toolbar, "🔍 搜索节点", func(): _bp_mod._open_node_search())
	# 主区域: 左 节点图 | 右 详情
	var hsplit := HSplitContainer.new()
	hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hsplit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hsplit.add_theme_constant_override("separation", 4)
	l3_container.add_child(hsplit)
	# 节点图画布
	var graph_panel := PanelContainer.new()
	graph_panel.custom_minimum_size.x = 400
	graph_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph_panel.size_flags_stretch_ratio = 2.0
	var graph_sb := StyleBoxFlat.new()
	graph_sb.bg_color = Color(0.1, 0.11, 0.14, 1)
	graph_sb.border_width_left = 1
	graph_sb.border_width_top = 1
	graph_sb.border_width_right = 1
	graph_sb.border_width_bottom = 1
	graph_sb.border_color = Color(0.2, 0.25, 0.35, 0.3)
	graph_sb.content_margin_left = 4.0
	graph_sb.content_margin_top = 4.0
	graph_sb.content_margin_right = 4.0
	graph_sb.content_margin_bottom = 4.0
	graph_panel.add_theme_stylebox_override("panel", graph_sb)
	hsplit.add_child(graph_panel)
	var graph_canvas := Control.new()
	graph_canvas.name = "EventGraphCanvas"
	graph_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph_canvas.clip_contents = false
	graph_panel.add_child(graph_canvas)
	graph_canvas.draw.connect(_draw_event_graph.bind(graph_canvas))
	graph_canvas.gui_input.connect(_on_event_graph_input.bind(graph_canvas))
	# 小地图（添加为canvas子控件，避免PanelContainer布局干扰）
	_bp_mod._create_minimap(graph_canvas)
	# 右侧详情编辑区
	var detail_scroll := ScrollContainer.new()
	detail_scroll.custom_minimum_size.x = 280
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.size_flags_stretch_ratio = 1.0
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var detail := VBoxContainer.new()
	detail.name = "EventDetail"
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 6)
	detail_scroll.add_child(detail)
	hsplit.add_child(detail_scroll)
	# 初始显示概览
	_build_event_overview(detail)
	graph_canvas.call_deferred("queue_redraw")
	# 重置层级状态(默认L3节点图, 保持现有行为)
	_event_edit_layer = "l3"
	_l1_mod._l1_current_event_id = ""
	return root

## ============================================================
## === L1/L3 层级切换系统 (三层渐进编辑模型, 见《设计方案》§7) ===
## ============================================================

## 当前事件编辑器层级: "l1"=表单模式(零基础), "l3"=节点图模式(进阶)
var _event_edit_layer: String = "l3"
## L3 容器引用 (在 _create_event_editor 中设置)
var _event_l3_container: Control = null

## 构建层级切换器栏
func _build_layer_switcher(parent: Control) -> void:
	var bar := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.14, 0.18, 1)
	sb.border_width_bottom = 1
	sb.border_color = Color(0.25, 0.3, 0.4, 0.4)
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	bar.add_theme_stylebox_override("panel", sb)
	parent.add_child(bar)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	bar.add_child(hbox)
	var hint := Label.new()
	hint.text = "编辑层级:"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", EditorUIFactory.C_LABEL)
	hbox.add_child(hint)
	var l1_btn := Button.new()
	l1_btn.text = "📝 L1 表单 (新手)"
	l1_btn.toggle_mode = true
	l1_btn.add_theme_font_size_override("font_size", 12)
	hbox.add_child(l1_btn)
	var l3_btn := Button.new()
	l3_btn.text = "🔗 L3 节点图(进阶)"
	l3_btn.toggle_mode = true
	l3_btn.button_pressed = true
	l3_btn.add_theme_font_size_override("font_size", 12)
	hbox.add_child(l3_btn)
	var desc := Label.new()
	desc.text = "  两种模式编辑同一份数据, 随时切换不丢失进度"
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", EditorUIFactory.C_EMPTY_HINT)
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(desc)
	l1_btn.pressed.connect(func():
		l3_btn.button_pressed = false
		l1_btn.button_pressed = true
		_switch_event_layer("l1")
	)
	l3_btn.pressed.connect(func():
		l1_btn.button_pressed = false
		l3_btn.button_pressed = true
		_switch_event_layer("l3")
	)

## 切换事件编辑器层级
func _switch_event_layer(layer: String) -> void:
	_event_edit_layer = layer
	if _l1_mod._event_l1_container == null or _event_l3_container == null:
		return
	if layer == "l1":
		# 进入L1层, 确保所有事件有结构化数据(从运行时格式反编译)
		_l1_mod._l1_ensure_all_structured()
		_event_l3_container.visible = false
		_l1_mod._event_l1_container.visible = true
		_l1_mod._build_l1_form_view(_l1_mod._event_l1_container)
	else:
		# 回到L3层, 把结构化数据编译回运行时格式(保持节点图, 游玩器一致)
		_l1_mod._l1_sync_all_to_runtime()
		_sync_to_code_editor()
		_l1_mod._event_l1_container.visible = false
		_event_l3_container.visible = true
		var canvas: Control = _host.editor_container.find_child("EventGraphCanvas", true, false)
		if canvas:
			canvas.queue_redraw()

## ============================================================
## === 辅助包装方法 (委托到 _host) ===
## ============================================================

func _log_output(msg: String) -> void:
	_host._log_output(msg)

func _sync_to_code_editor() -> void:
	_host._sync_to_code_editor()

func _mark_dirty() -> void:
	_host._mark_dirty()

## 获取当前剧本数据（代理到真正的宿主 script_editor, 供子模块使用）
func _current_script() -> WorldScriptData:
	return _host.current_script

## 获取编辑器容器（代理到真正的宿主 script_editor, 供子模块使用）
func _editor_container() -> Node:
	return _host.editor_container

## === 兼容委托（供 visual_map.gd / script_editor.gd 等外部调用） ===

## 蓝图节点尺寸常量（原视觉模块共享常量, 移入 VisualBlueprintDraw）
const BP_NODE_SIZE := VisualBlueprintDraw.BP_NODE_SIZE

## 适应画布（委托蓝图模块）
func _fit_canvas_to_nodes(canvas_or_parent: Control) -> void:
	_bp_mod._fit_canvas_to_nodes(canvas_or_parent)

## 绘制网格背景（委托绘制工具）
func _draw_bp_grid(canvas: Control) -> void:
	VisualBlueprintDraw.draw_grid(canvas, _bp_mod._bp_offset, _bp_mod._bp_zoom)

## 世界坐标 -> 屏幕坐标（委托绘制工具）
func _bp_world_to_screen(world_pos: Vector2) -> Vector2:
	return VisualBlueprintDraw.world_to_screen(world_pos, _bp_mod._bp_offset, _bp_mod._bp_zoom)

## 绘制贝塞尔连线（委托绘制工具）
func _draw_bp_connection(canvas: Control, from_pos: Vector2, to_pos: Vector2, color: Color, width: float = 2.0) -> void:
	VisualBlueprintDraw.draw_connection(canvas, from_pos, to_pos, color, width, _bp_mod._bp_offset, _bp_mod._bp_zoom)

## 地图节点引脚坐标（visual_map.gd 专用: pos/size 显式传入）
func _map_pin_world_pos(pos: Vector2, node_size: Vector2, is_output: bool, _port_index: int = 0) -> Vector2:
	if is_output:
		return pos + Vector2(node_size.x, node_size.y / 2.0)
	else:
		return pos + Vector2(0, node_size.y / 2.0)

## ============================================================
## === 事件列表视图状态 ===
## ============================================================

# 事件节点数据: id -> {"pos": Vector2, "type": String, "title": String, "body": Array[String]}
var _event_nodes: Dictionary = {}

# 地图节点数据: region_id -> {"pos": Vector2, "title": String, "body": Array[String]}
var _map_nodes: Dictionary = {}

# 每个事件的蓝图脚本图数据: event_id -> BlueprintGraph(Dictionary)
var _event_blueprint_graphs: Dictionary = {}
# 蓝图视图状态: "event_list" = 事件列表视图, "event_blueprint" = 单个事件蓝图编辑
var _bp_view: String = "event_list"
# 当前正在编辑蓝图的事件ID（仅 _bp_view == "event_blueprint" 时有效）
var _bp_current_event_id: String = ""
# 事件列表视图的临时图数据
var _event_list_graph: Dictionary = BlueprintData.make_graph()
# 事件列表视图是否已同步
var _event_list_synced := false

## ============================================================
## === 事件列表视图同步 ===
## ============================================================

## 同步事件列表图(将 current_script 中的事件映射为节点)
func _sync_event_list_graph() -> void:
	if _event_list_synced:
		return
	_event_list_synced = true
	_event_list_graph = BlueprintData.make_graph()
	if _host.current_script == null or _host.current_script.event_system == null:
		return
	var es = _host.current_script.event_system
	var y_offset := 100.0
	var x_col_story := 100.0
	var x_col_random := 400.0
	# 剧情事件节点
	for ev in es.story_events:
		var nid: String = "evt_%s" % ev["id"]
		var node: Dictionary = {
			"id": nid,
			"node_type": "story_event",
			"pos": Vector2(x_col_story, y_offset),
			"title": ev.get("name", ev["id"]),
			"color": Color(0.2, 0.4, 0.8, 1.0),
			"inputs": [BlueprintData.make_pin("in", BlueprintData.PinDataType.EXEC, false)],
			"outputs": [BlueprintData.make_pin("out", BlueprintData.PinDataType.EXEC, true)],
			"properties": {"event_id": ev["id"], "event_name": ev.get("name", "")},
			"comment": "",
		}
		_event_list_graph["nodes"][nid] = node
		y_offset += 120.0
	# 随机事件节点
	var ry_offset := 100.0
	for ev in es.random_events:
		var nid: String = "revt_%s" % ev["id"]
		var node: Dictionary = {
			"id": nid,
			"node_type": "random_event",
			"pos": Vector2(x_col_random, ry_offset),
			"title": ev.get("name", ev["id"]),
			"color": Color(0.2, 0.65, 0.3, 1.0),
			"inputs": [BlueprintData.make_pin("in", BlueprintData.PinDataType.EXEC, false)],
			"outputs": [BlueprintData.make_pin("out", BlueprintData.PinDataType.EXEC, true)],
			"properties": {"event_id": ev["id"], "event_name": ev.get("name", "")},
			"comment": "",
		}
		_event_list_graph["nodes"][nid] = node
		ry_offset += 120.0
	# 创建连线: 事件链
	for chain in es.event_chains:
		var events_in_chain: Array = chain.get("events", [])
		for i in range(events_in_chain.size() - 1):
			var from_id: String = "evt_%s" % str(events_in_chain[i])
			var to_id: String = "evt_%s" % str(events_in_chain[i + 1])
			if _event_list_graph["nodes"].has(from_id) and _event_list_graph["nodes"].has(to_id):
				BlueprintData.add_connection(_event_list_graph, from_id, 0, to_id, 0, true)

## 查找事件在事件列表图中的节点ID
func _find_event_list_node_id(event_id: String) -> String:
	var nid: String = "evt_%s" % event_id
	if _event_list_graph["nodes"].has(nid):
		return nid
	nid = "revt_%s" % event_id
	if _event_list_graph["nodes"].has(nid):
		return nid
	return ""

## 进入单个事件的蓝图编辑
func _enter_event_blueprint(event_id: String) -> void:
	_bp_view = "event_blueprint"
	_bp_current_event_id = event_id
	_bp_mod._bp_selected_ids.clear()
	_bp_mod._bp_undo_stack.clear()
	_bp_mod._bp_redo_stack.clear()
	_bp_mod._bp_offset = Vector2(200, 150)
	_bp_mod._bp_zoom = 1.0
	_update_toolbar_buttons()
	_bp_mod._bp_redraw_canvas()
	_log_output("[蓝图] 进入事件 '%s' 的蓝图编辑" % event_id)

## 返回事件列表视图
func _back_to_event_list() -> void:
	# 保存当前蓝图
	if _bp_view == "event_blueprint" and _bp_current_event_id != "":
		_bp_mod._save_event_graph(_bp_current_event_id)
	_bp_view = "event_list"
	_bp_current_event_id = ""
	_bp_mod._bp_selected_ids.clear()
	_event_list_synced = false
	_sync_event_list_graph()
	_host._mark_dirty()
	_host._sync_to_code_editor()
	_update_toolbar_buttons()
	_bp_mod._bp_redraw_canvas()
	# 恢复右侧概览
	var detail: Control = _host.editor_container.find_child("EventDetail", true, false)
	if detail:
		_build_event_overview(detail)
	_log_output("[蓝图] 返回事件列表视图")

## 更新工具栏按钮状态
func _update_toolbar_buttons() -> void:
	# 工具栏按钮不需要动态更新，画布会重新绘制
	pass

## ============================================================
## === 事件编辑器连接/删除操作 ===
## ============================================================

## 事件编辑器连接创建
func _create_event_connection(from_id: String, to_id: String) -> void:
	if from_id == to_id:
		return
	var graph := _event_list_graph
	BlueprintData.add_connection(graph, from_id, 0, to_id, 0, true)
	# 设置下一个事件
	if _host.current_script and _host.current_script.event_system:
		var es = _host.current_script.event_system
		var from_eid: String = graph["nodes"][from_id]["properties"].get("event_id", "")
		var to_eid: String = graph["nodes"][to_id]["properties"].get("event_id", "")
		for ev in es.story_events:
			if ev["id"] == from_eid:
				ev["next_event"] = to_eid
				break
	_sync_to_code_editor()
	_mark_dirty()
	_bp_mod._bp_redraw_canvas()
	_log_output("[事件] 连接: %s -> %s" % [from_id, to_id])

## 删除事件节点(仅从视图移除, 不删除数据)
func _delete_event_node(node_id: String) -> void:
	_event_list_graph["nodes"].erase(node_id)
	BlueprintData.remove_node_connections(_event_list_graph, node_id)
	_bp_mod._bp_redraw_canvas()

## ============================================================
## === 事件概览与详情 ===
## ============================================================

## 简易模式庆祝标记（内存级防重复）
var _simple_event_celebrated := false

## 构建事件系统概览(右侧面板默认内容)
func _build_event_overview(detail: Control) -> void:
	_clear(detail)
	_ui().add_section_label(detail, "▶ 事件系统概览")
	if _host.current_script == null or _host.current_script.event_system == null:
		_ui().add_info_label(detail, "无事件数据")
		return
	var es = _host.current_script.event_system
	var stats: Array = [
		["剧情事件", str(es.story_events.size())],
		["随机事件", str(es.random_events.size())],
		["事件链", str(es.event_chains.size())],
	]
	for s in stats:
		_ui().add_info_label(detail, "%s: %s" % [s[0], s[1]])
	# 简易模式：操作引导
	if EditorMode.is_simple():
		# 创建进度条（目标 5 个事件）
		var goal := 5
		var progress := ProgressBar.new()
		progress.max_value = goal
		progress.value = mini(es.story_events.size(), goal)
		progress.custom_minimum_size = Vector2(0, 14)
		progress.show_percentage = false
		progress.tooltip_text = "剧情事件进度（目标 %d 个）" % goal
		detail.add_child(progress)
		var goal_lbl := Label.new()
		goal_lbl.text = "📈 剧情事件：%d / %d（目标）" % [es.story_events.size(), goal]
		goal_lbl.add_theme_font_size_override("font_size", 11)
		goal_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 0.7))
		detail.add_child(goal_lbl)
		_ui().add_hseparator(detail)
		_ui().add_info_label(detail, "🌱 简易模式：")
		_ui().add_info_label(detail, "1. 点击左侧节点图中的「剧情事件」卡片")
		_ui().add_info_label(detail, "2. 在表单中填写事件内容与玩家选择")
		_ui().add_info_label(detail, "3. Ctrl+S 保存 / F5 试玩")
		# 已完成事件：庆祝提示（防重复）
		if not es.story_events.is_empty() and not _simple_event_celebrated:
			_simple_event_celebrated = true
			ToastManager.success("🎉 你已经创建了 %d 个剧情事件！做得很好，继续加油！" % es.story_events.size())
	_ui().add_info_label(detail, "点击左侧节点图中的事件卡片查看详情")
	_ui().add_info_label(detail, "双击事件卡片进入蓝图编辑")

## 构建事件详情(选中事件节点时)
func _build_event_detail(detail: Control, event_id: String) -> void:
	_clear(detail)
	if _host.current_script == null or _host.current_script.event_system == null:
		return
	var es = _host.current_script.event_system
	var event: Dictionary = {}
	for ev in es.story_events:
		if ev["id"] == event_id:
			event = ev
			break
	if event.is_empty():
		for ev in es.random_events:
			if ev["id"] == event_id:
				event = ev
				break
	if event.is_empty():
		_ui().add_section_label(detail, "事件未找到")
		return
	_ui().add_section_label(detail, "▶ %s" % event.get("name", event_id))
	_ui().add_info_label(detail, "ID: %s" % event_id)
	_ui().add_info_label(detail, "触发: %s" % event.get("trigger_type", "chain"))
	if event.get("prerequisite", "") != "":
		_ui().add_info_label(detail, "前置: %s" % event["prerequisite"])
	if event.has("probability"):
		_ui().add_info_label(detail, "概率: %.0f%%" % (event["probability"] * 100.0))
	if event.has("period") and str(event["period"]) != "":
		_ui().add_info_label(detail, "时段: %s" % event["period"])
	var choices: Array = event.get("choices", [])
	if not choices.is_empty():
		_ui().add_section_label(detail, "选项 (%d)" % choices.size(), 2)
		for i in choices.size():
			var c: Dictionary = choices[i]
			_ui().add_info_label(detail, "  %d. %s" % [i + 1, c.get("text", "")])
	# 双击进入蓝图编辑按钮
	var bp_btn := Button.new()
	bp_btn.text = "🔗 进入蓝图编辑"
	bp_btn.add_theme_font_size_override("font_size", 12)
	bp_btn.pressed.connect(func(): _enter_event_blueprint(event_id))
	detail.add_child(bp_btn)

## ============================================================
## === 工具栏操作: 添加节点/布局 ===
## ============================================================

## 添加剧情事件节点
func _add_story_event_node(_parent: Control) -> void:
	if _host.current_script == null or _host.current_script.event_system == null:
		return
	var es = _host.current_script.event_system
	var new_id: String = "evt_%d" % (Time.get_ticks_msec() % 100000)
	es.add_story_event(new_id, "新事件", "chain")
	_event_list_synced = false
	_sync_event_list_graph()
	_sync_to_code_editor()
	_mark_dirty()
	_bp_mod._bp_redraw_canvas()
	_log_output("[事件] 添加剧情事件: %s" % new_id)

## 添加随机事件节点
func _add_random_event_node(_parent: Control) -> void:
	if _host.current_script == null or _host.current_script.event_system == null:
		return
	var es = _host.current_script.event_system
	var new_id: String = "revt_%d" % (Time.get_ticks_msec() % 100000)
	es.add_random_event(new_id, "新随机事件", 0.1)
	_event_list_synced = false
	_sync_event_list_graph()
	_sync_to_code_editor()
	_mark_dirty()
	_bp_mod._bp_redraw_canvas()
	_log_output("[事件] 添加随机事件: %s" % new_id)

## 添加事件链
func _add_event_chain(_parent: Control) -> void:
	if _host.current_script == null or _host.current_script.event_system == null:
		return
	var es = _host.current_script.event_system
	var new_id: String = "chain_%d" % (Time.get_ticks_msec() % 100000)
	es.event_chains.append({"id": new_id, "name": "新事件链", "events": []})
	_sync_to_code_editor()
	_mark_dirty()
	_log_output("[事件] 添加事件链: %s" % new_id)

## ============================================================
## === 事件节点图绘制与交互 ===
## ============================================================

## 同步事件节点数据(从 current_script 构建节点图)
func _sync_event_nodes() -> void:
	_event_nodes.clear()
	if _host.current_script == null or _host.current_script.event_system == null:
		return
	var es = _host.current_script.event_system
	var y := 80.0
	for ev in es.story_events:
		var eid: String = ev["id"]
		var body: Array[String] = []
		body.append("触发: %s" % ev.get("trigger_type", "chain"))
		if ev.get("prerequisite", "") != "":
			body.append("前置: %s" % ev["prerequisite"])
		var choices_count: int = ev.get("choices", []).size()
		if choices_count > 0:
			body.append("选项: %d个" % choices_count)
		_event_nodes[eid] = {
			"pos": Vector2(120, y),
			"type": "story",
			"title": ev.get("name", eid),
			"body": body,
		}
		y += 130.0
	var ry := 80.0
	for ev in es.random_events:
		var eid: String = ev["id"]
		var body: Array[String] = []
		body.append("概率: %.0f%%" % (ev.get("probability", 0.1) * 100.0))
		_event_nodes[eid] = {
			"pos": Vector2(420, ry),
			"type": "random",
			"title": ev.get("name", eid),
			"body": body,
		}
		ry += 130.0

## 事件节点右键菜单（打开蓝图/复制/删除）
func _show_event_node_menu(canvas: Control, node_id: String, screen_pos: Vector2) -> void:
	var popup := PopupMenu.new()
	popup.name = "EventNodeMenu"
	popup.add_item("🔷 打开蓝图编辑", 1)
	# 复制/删除为进阶操作（简易模式隐藏复制）
	if not EditorMode.is_simple():
		popup.add_item("⧉ 复制事件", 2)
	popup.add_item("🗑 删除事件", 3)
	popup.id_pressed.connect(func(id: int):
		match id:
			1: _enter_event_blueprint(node_id)
			2: _duplicate_event(node_id)
			3: _delete_event_node(node_id)
		popup.queue_free())
	canvas.add_child(popup)
	popup.popup(Rect2i(Vector2i(screen_pos), Vector2i(180, 120)))

## 复制事件（创建副本）
func _duplicate_event(node_id: String) -> void:
	if _host.current_script == null or _host.current_script.event_system == null:
		return
	var es = _host.current_script.event_system
	var src: Dictionary = {}
	for ev in es.story_events:
		if ev.get("id", "") == node_id:
			src = ev
			break
	if src.is_empty():
		return
	var new_id := "event_dup_%d" % Time.get_ticks_msec()
	var copy := (src as Dictionary).duplicate(true)
	copy["id"] = new_id
	copy["name"] = str(src.get("name", "")) + " 副本"
	es.story_events.append(copy)
	_sync_to_code_editor()
	_mark_dirty()
	_sync_event_nodes()
	_log_output("[事件] 已复制: %s" % copy["name"])

## 获取事件节点颜色
func _get_event_node_color(event_type: String) -> Color:
	match event_type:
		"story": return Color(0.2, 0.4, 0.8, 1.0)
		"random": return Color(0.2, 0.65, 0.3, 1.0)
		"chain": return Color(0.6, 0.4, 0.1, 1.0)
	return Color(0.4, 0.4, 0.4, 1.0)

## 获取事件节点引脚(简化: 左输入+右输出+下方链)
func _get_event_node_pins(event_id: String) -> Dictionary:
	var left_pins: Array[String] = ["入"]
	var right_pins: Array[String] = ["出"]
	# 检查是否是事件链的一部分(输出)
	if _host.current_script and _host.current_script.event_system:
		var es = _host.current_script.event_system
		for chain in es.event_chains:
			var events_in_chain: Array = chain.get("events", [])
			if events_in_chain.has(event_id):
				var idx: int = events_in_chain.find(event_id)
				if idx < events_in_chain.size() - 1:
					right_pins.append("链")
	# 检查是否是其他事件的前置(输出)
	if _host.current_script and _host.current_script.event_system:
		for ev in _host.current_script.event_system.story_events:
			if ev.get("prerequisite", "") == event_id:
				if not right_pins.has("前置"):
					right_pins.append("前置")
	return {"left": left_pins, "right": right_pins}

## 事件图绘制入口(绑定到 canvas.draw 信号)
func _draw_event_graph(canvas: Control) -> void:
	if _bp_view == "event_blueprint":
		var graph := _bp_mod._get_active_graph()
		_bp_mod._draw_blueprint_graph(canvas, graph)
		return
	# 事件列表视图
	_sync_event_list_graph()
	VisualBlueprintDraw.draw_grid(canvas, _bp_mod._bp_offset, _bp_mod._bp_zoom)
	var graph := _event_list_graph
	# 视口裁剪: 只绘制可见范围内的节点与连线（长列表图 95% 节点在屏幕外）
	var world_view := Rect2(
		VisualBlueprintDraw.screen_to_world(Vector2.ZERO, _bp_mod._bp_offset, _bp_mod._bp_zoom),
		canvas.size / _bp_mod._bp_zoom
	).grow(80.0)
	# 绘制连线
	for conn in graph["connections"]:
		if not graph["nodes"].has(conn["from_node"]) or not graph["nodes"].has(conn["to_node"]):
			continue
		var from_node: Dictionary = graph["nodes"][conn["from_node"]]
		var to_node: Dictionary = graph["nodes"][conn["to_node"]]
		if not Rect2(from_node["pos"], VisualBlueprintDraw.BP_NODE_SIZE).intersects(world_view) \
			and not Rect2(to_node["pos"], VisualBlueprintDraw.BP_NODE_SIZE).intersects(world_view):
			continue
		var from_pos: Vector2 = VisualBlueprintDraw.get_pin_world_pos(from_node, true)
		var to_pos: Vector2 = VisualBlueprintDraw.get_pin_world_pos(to_node, false)
		VisualBlueprintDraw.draw_connection(canvas, from_pos, to_pos, Color(0.5, 0.6, 0.8, 0.7), 2.0 * _bp_mod._bp_zoom, _bp_mod._bp_offset, _bp_mod._bp_zoom)
	# 绘制节点
	for nid in graph["nodes"]:
		var node: Dictionary = graph["nodes"][nid]
		if not Rect2(node["pos"], VisualBlueprintDraw.BP_NODE_SIZE).intersects(world_view):
			continue
		var selected: bool = _bp_mod._bp_selected_ids.has(nid)
		VisualBlueprintDraw.draw_bp_node(canvas, node, selected, _bp_mod._bp_offset, _bp_mod._bp_zoom)
		VisualBlueprintDraw.draw_bp_pins(canvas, node, _bp_mod._bp_offset, _bp_mod._bp_zoom)
	# 框选
	if _bp_mod._bp_box_selecting:
		var rect := Rect2(_bp_mod._bp_box_start, _bp_mod._bp_box_end - _bp_mod._bp_box_start).abs()
		canvas.draw_rect(rect, Color(0.3, 0.5, 1.0, 0.15))
		canvas.draw_rect(rect, Color(0.3, 0.5, 1.0, 0.6), false, 1.0)
	# 重绘小地图
	if _bp_mod._bp_minimap:
		_bp_mod._bp_minimap.queue_redraw()

## 事件编辑器输入包装(绑定到 canvas.gui_input 信号)
func _on_event_graph_input(event: InputEvent, canvas: Control) -> void:
	if _bp_view == "event_blueprint":
		_bp_mod._on_blueprint_canvas_input(event, canvas)
		return
	# === 事件列表视图输入 ===
	var graph := _event_list_graph
	# 滚轮缩放
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			var old_zoom := _bp_mod._bp_zoom
			_bp_mod._bp_zoom = clampf(_bp_mod._bp_zoom * 1.1, 0.2, 3.0)
			_bp_mod._bp_offset = event.position - (event.position - _bp_mod._bp_offset) * (_bp_mod._bp_zoom / old_zoom)
			canvas.queue_redraw()
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var old_zoom := _bp_mod._bp_zoom
			_bp_mod._bp_zoom = clampf(_bp_mod._bp_zoom / 1.1, 0.2, 3.0)
			_bp_mod._bp_offset = event.position - (event.position - _bp_mod._bp_offset) * (_bp_mod._bp_zoom / old_zoom)
			canvas.queue_redraw()
			return
	# 鼠标按下
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# 双击检测
			if event.double_click:
				var hit_id := VisualBlueprintDraw.hit_test_node(event.position, graph, _bp_mod._bp_offset, _bp_mod._bp_zoom)
				if hit_id != "":
					# 双击事件节点进入其蓝图编辑
					var event_id: String = graph["nodes"][hit_id]["properties"].get("event_id", "")
					if event_id != "":
						_enter_event_blueprint(event_id)
						return
			# 选中节点并开始拖拽
			var hit_id := VisualBlueprintDraw.hit_test_node(event.position, graph, _bp_mod._bp_offset, _bp_mod._bp_zoom)
			if hit_id != "":
				_bp_mod._bp_selected_ids.clear()
				_bp_mod._bp_selected_ids.append(hit_id)
				_bp_mod._bp_node_dragging = true
				_bp_mod._bp_node_drag_id = hit_id
				_bp_mod._bp_node_drag_offset = VisualBlueprintDraw.screen_to_world(event.position, _bp_mod._bp_offset, _bp_mod._bp_zoom) - graph["nodes"][hit_id]["pos"]
				# 显示事件详情
				var detail: Control = _host.editor_container.find_child("EventDetail", true, false)
				if detail:
					var eid: String = graph["nodes"][hit_id]["properties"].get("event_id", "")
					_build_event_detail(detail, eid)
				canvas.queue_redraw()
				return
			# 点击空白处: 开始框选
			_bp_mod._bp_selected_ids.clear()
			_bp_mod._bp_box_selecting = true
			_bp_mod._bp_box_start = event.position
			_bp_mod._bp_box_end = event.position
			canvas.queue_redraw()
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_bp_mod._bp_dragging = true
			_bp_mod._bp_drag_start = event.position
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			# 右键: 事件节点操作菜单优先
			var node_hit := VisualBlueprintDraw.hit_test_bp_node(event.position, graph, _bp_mod._bp_offset, _bp_mod._bp_zoom)
			if node_hit != "" and graph["nodes"].has(node_hit):
				_show_event_node_menu(canvas, node_hit, event.position)
				return
			# 右键: 引脚拖拽连线 或 空白处菜单
			var pin_hit = VisualBlueprintDraw.hit_test_pins(event.position, graph, _bp_mod._bp_offset, _bp_mod._bp_zoom)
			if pin_hit != null:
				_bp_mod._bp_pin_dragging = true
				_bp_mod._bp_pin_drag_from_id = pin_hit[0]
				_bp_mod._bp_pin_drag_from_port = pin_hit[1]
				_bp_mod._bp_pin_drag_is_output = pin_hit[2]
				_bp_mod._bp_temp_connection_end = event.position
			else:
				# 空白处: 显示右键菜单
				_bp_mod._bp_ctx_menu_pos = VisualBlueprintDraw.screen_to_world(event.position, _bp_mod._bp_offset, _bp_mod._bp_zoom)
				_bp_mod._bp_ctx_from_pin_drag = false
				_bp_mod._show_bp_context_menu(canvas, event.position)
	# 鼠标释放
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if _bp_mod._bp_node_dragging:
				_bp_mod._bp_node_dragging = false
			elif _bp_mod._bp_box_selecting:
				_bp_mod._bp_box_selecting = false
				var sel_start := VisualBlueprintDraw.screen_to_world(_bp_mod._bp_box_start, _bp_mod._bp_offset, _bp_mod._bp_zoom)
				var sel_end := VisualBlueprintDraw.screen_to_world(_bp_mod._bp_box_end, _bp_mod._bp_offset, _bp_mod._bp_zoom)
				var sel_rect := Rect2(sel_start, sel_end - sel_start).abs()
				_bp_mod._bp_selected_ids.clear()
				for nid in graph["nodes"]:
					var node_rect := Rect2(graph["nodes"][nid]["pos"], VisualBlueprintDraw.BP_NODE_SIZE)
					if sel_rect.intersects(node_rect):
						_bp_mod._bp_selected_ids.append(nid)
				canvas.queue_redraw()
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_bp_mod._bp_dragging = false
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if _bp_mod._bp_pin_dragging:
				# 尝试连线
				var pin_hit = VisualBlueprintDraw.hit_test_pins(event.position, graph, _bp_mod._bp_offset, _bp_mod._bp_zoom)
				if pin_hit != null and _bp_mod._bp_pin_drag_is_output and not pin_hit[2]:
					_create_event_connection(_bp_mod._bp_pin_drag_from_id, pin_hit[0])
				_bp_mod._bp_pin_dragging = false
				canvas.queue_redraw()
	# 鼠标移动
	if event is InputEventMouseMotion:
		if _bp_mod._bp_dragging:
			_bp_mod._bp_offset += event.relative
			canvas.queue_redraw()
		elif _bp_mod._bp_node_dragging:
			var world_pos := VisualBlueprintDraw.screen_to_world(event.position, _bp_mod._bp_offset, _bp_mod._bp_zoom)
			var new_pos := world_pos - _bp_mod._bp_node_drag_offset
			if _bp_mod._bp_grid_snap:
				new_pos = new_pos.snapped(Vector2(VisualBlueprintDraw.BP_GRID_SIZE, VisualBlueprintDraw.BP_GRID_SIZE))
			graph["nodes"][_bp_mod._bp_node_drag_id]["pos"] = new_pos
			canvas.queue_redraw()
		elif _bp_mod._bp_pin_dragging:
			_bp_mod._bp_temp_connection_end = event.position
			canvas.queue_redraw()
		elif _bp_mod._bp_box_selecting:
			_bp_mod._bp_box_end = event.position
			canvas.queue_redraw()
	# 键盘
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_DELETE and not _bp_mod._bp_selected_ids.is_empty():
			for nid in _bp_mod._bp_selected_ids:
				_delete_event_node(nid)
			_bp_mod._bp_selected_ids.clear()
			canvas.queue_redraw()
		elif event.keycode == KEY_F:
			_bp_mod._fit_canvas_to_nodes(canvas)
