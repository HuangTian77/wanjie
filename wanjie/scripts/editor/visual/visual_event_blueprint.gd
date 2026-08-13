## VisualEventBlueprint - 事件蓝图编辑器模块（L3 节点图交互）
## 从 visual_event.gd 提取，通过 _host (duck-typed) 访问宿主 visual_event.gd。
## 宿主共享状态: _host._bp_view / _host._bp_current_event_id / _host._event_list_graph / _host._event_blueprint_graphs
## 宿主方法: _host._mark_dirty() / _host._sync_to_code_editor() / _host._log_output() / _host._ui() / _host._build_event_overview()
## 绘制原语委托 VisualBlueprintDraw（静态工具）
class_name VisualEventBlueprint
extends RefCounted

## 宿主 visual_event.gd 实例 (duck-typed)
var _host

func _init(host) -> void:
	_host = host

# === 蓝图画布状态 ===
var _bp_offset := Vector2.ZERO
var _bp_zoom := 1.0
var _bp_dragging := false
var _bp_drag_start := Vector2.ZERO
## 鼠标位置（引脚 hover 高亮）
var _bp_last_mouse_pos := Vector2(-9999, -9999)
var _bp_node_dragging := false
var _bp_node_drag_id := ""
var _bp_node_drag_offset := Vector2.ZERO
var _bp_box_selecting := false
var _bp_box_start := Vector2.ZERO
var _bp_box_end := Vector2.ZERO
var _bp_selected_ids: Array[String] = []
var _bp_pin_dragging := false
var _bp_pin_drag_from_id := ""
var _bp_pin_drag_from_port := int(-1)
var _bp_pin_drag_is_output := false
var _bp_temp_connection_end := Vector2.ZERO

# 右键菜单/引脚拖拽创建节点的状态
var _bp_ctx_menu_pos := Vector2.ZERO  # 菜单弹出的世界坐标
var _bp_ctx_from_pin_drag := false  # 是否由引脚拖拽触发
var _bp_ctx_drag_from_id := ""  # 拖拽来源节点ID
var _bp_ctx_drag_from_port := int(-1)  # 拖拽来源端口索引
var _bp_ctx_drag_is_output := false  # 拖拽来源是否为输出引脚
var _bp_ctx_drag_data_type := int(-1)  # 拖拽引脚的数据类型

# 蓝图撤销/重做
var _bp_undo_stack: Array[Dictionary] = []
var _bp_redo_stack: Array[Dictionary] = []
const BP_MAX_UNDO := 50
# 蓝图剪贴板
var _bp_clipboard: Dictionary = {}
# 网格吸附
var _bp_grid_snap := true

# 节点搜索弹窗
var _bp_search_popup: PopupPanel = null
var _bp_search_edit: LineEdit = null
var _bp_search_list: ItemList = null
var _bp_search_results: Array[String] = []  # node_ids
## 搜索定位高亮节点（黄框提示）
var _bp_highlight_node: String = ""
## 选中的连线索引（点击连线选中，Delete 删除）
var _bp_selected_connection: int = -1

# 小地图
var _bp_minimap: Control = null
const BP_MINIMAP_SIZE := Vector2(160, 110)

## 坐标转换
func _bp_screen_to_world(screen_pos: Vector2) -> Vector2:
	return VisualBlueprintDraw.screen_to_world(screen_pos, _bp_offset, _bp_zoom)

func _bp_world_to_screen(world_pos: Vector2) -> Vector2:
	return VisualBlueprintDraw.world_to_screen(world_pos, _bp_offset, _bp_zoom)

## 获取当前活动的蓝图画布
func _get_active_graph() -> Dictionary:
	if _host._bp_view == "workspace":
		return _host._workspace_get_graph()
	if _host._bp_view == "event_blueprint" and _host._bp_current_event_id != "":
		return _get_or_create_event_graph(_host._bp_current_event_id)
	return _host._event_list_graph

## 获取或创建事件的蓝图Graph
func _get_or_create_event_graph(event_id: String) -> Dictionary:
	if _host._event_blueprint_graphs.has(event_id):
		return _host._event_blueprint_graphs[event_id]
	# 尝试从持久化数据加载
	if _host._current_script() and _host._current_script().event_system:
		var persisted: Dictionary = _host._current_script().event_system.blueprint_graphs.get(event_id, {})
		if not persisted.is_empty():
			_repair_graph_structure(persisted)
			_host._event_blueprint_graphs[event_id] = persisted
			return persisted
	# 创建新Graph，带一个默认的 Start 节点
	var graph: Dictionary = BlueprintData.make_graph()
	var start_node: Dictionary = BlueprintData.create_node("start", Vector2(100, 200))
	graph["nodes"][start_node["id"]] = start_node
	_host._event_blueprint_graphs[event_id] = graph
	return graph

## 保存事件蓝图到持久化存储
func _save_event_graph(event_id: String) -> void:
	if _host._current_script() and _host._current_script().event_system and _host._event_blueprint_graphs.has(event_id):
		_host._current_script().event_system.blueprint_graphs[event_id] = _host._event_blueprint_graphs[event_id]

## 保存当前活动图的蓝图数据
func _save_active_graph() -> void:
	if _host._bp_view == "workspace":
		_host._workspace_save_graph()
		_host._mark_dirty()
		return
	if _host._bp_view == "event_blueprint" and _host._bp_current_event_id != "":
		_save_event_graph(_host._bp_current_event_id)
	_host._mark_dirty()

## 蓝图撤销: 保存当前状态到undo栈
func _bp_push_undo() -> void:
	var graph := _get_active_graph()
	var snapshot: Dictionary = graph.duplicate(true)  # 深拷贝保留 Vector2/Color（JSON 会丢失）
	_bp_undo_stack.append(snapshot)
	if _bp_undo_stack.size() > BP_MAX_UNDO:
		_bp_undo_stack.pop_front()
	_bp_redo_stack.clear()

## 蓝图撤销 (Ctrl+Z)
func _bp_undo() -> void:
	if _bp_undo_stack.is_empty():
		return
	# 保存当前状态到redo
	var graph := _get_active_graph()
	var current_snapshot: Dictionary = graph.duplicate(true)  # 深拷贝保留 Vector2/Color
	_bp_redo_stack.append(current_snapshot)
	# 恢复上一个状态
	var prev: Dictionary = _bp_undo_stack.pop_back()
	var target := _get_active_graph()
	target["nodes"] = prev.get("nodes", {})
	target["connections"] = prev.get("connections", [])
	target["local_variables"] = prev.get("local_variables", {})
	_save_active_graph()
	_bp_selected_ids.clear()
	var canvas: Control = _host._editor_container().find_child("EventGraphCanvas", true, false)
	if canvas:
		canvas.queue_redraw()
	_log_output("[撤销] 剩余 %d 步" % _bp_undo_stack.size())

## 蓝图重做 (Ctrl+Y)
func _bp_redo() -> void:
	if _bp_redo_stack.is_empty():
		return
	# 保存当前状态到undo
	var graph := _get_active_graph()
	var current_snapshot: Dictionary = graph.duplicate(true)  # 深拷贝保留 Vector2/Color
	_bp_undo_stack.append(current_snapshot)
	# 恢复redo状态
	var next: Dictionary = _bp_redo_stack.pop_back()
	var target := _get_active_graph()
	target["nodes"] = next.get("nodes", {})
	target["connections"] = next.get("connections", [])
	target["local_variables"] = next.get("local_variables", {})
	_save_active_graph()
	_bp_selected_ids.clear()
	var canvas: Control = _host._editor_container().find_child("EventGraphCanvas", true, false)
	if canvas:
		canvas.queue_redraw()
	_log_output("[重做] 剩余 %d 步" % _bp_redo_stack.size())

## 删除选中节点（可撤销）
func _bp_delete_selected(graph: Dictionary, canvas: Control) -> void:
	_bp_push_undo()
	for nid in _bp_selected_ids:
		BlueprintData.remove_node_connections(graph, nid)
		graph["nodes"].erase(nid)
	_bp_selected_ids.clear()
	_save_active_graph()
	_host._sync_to_code_editor()
	canvas.queue_redraw()

## 蓝图复制 (Ctrl+C)
func _bp_copy() -> void:
	if _bp_selected_ids.is_empty():
		return
	var graph := _get_active_graph()
	var clip_nodes: Array[Dictionary] = []
	var clip_connections: Array[Dictionary] = []
	for nid in _bp_selected_ids:
		if graph["nodes"].has(nid):
			clip_nodes.append((graph["nodes"][nid] as Dictionary).duplicate(true))
	# 复制选中节点之间的连线
	for conn in graph.get("connections", []):
		if _bp_selected_ids.has(conn["from_node"]) and _bp_selected_ids.has(conn["to_node"]):
			clip_connections.append((conn as Dictionary).duplicate(true))
	_bp_clipboard = {"nodes": clip_nodes, "connections": clip_connections}
	_log_output("[复制] %d 个节点" % clip_nodes.size())

## 蓝图粘贴 (Ctrl+V)
func _bp_paste() -> void:
	if _bp_clipboard.is_empty():
		return
	_bp_push_undo()
	var graph := _get_active_graph()
	var id_map: Dictionary = {}  # 旧ID -> 新ID
	var canvas: Control = _host._editor_container().find_child("EventGraphCanvas", true, false)
	_bp_selected_ids.clear()
	# 粘贴节点
	for clip_node in _bp_clipboard.get("nodes", []):
		var new_id: String = "bp_%s_%d" % [clip_node["node_type"], Time.get_ticks_msec() + randi() % 10000]
		id_map[clip_node["id"]] = new_id
		var new_node: Dictionary = (clip_node as Dictionary).duplicate(true)
		new_node["id"] = new_id
		# 偏移避免重叠
		new_node["pos"] = new_node["pos"] + Vector2(40, 40)
		# 复制节点自动加"副本"标题（避免同名混淆）
		var t: String = str(new_node.get("title", ""))
		if t.is_empty():
			t = BlueprintNodeRegistry.get_display_name(new_node.get("node_type", ""))
		new_node["title"] = "%s·副本" % t
		graph["nodes"][new_id] = new_node
		_bp_selected_ids.append(new_id)
	# 粘贴内部连线
	for clip_conn in _bp_clipboard.get("connections", []):
		var new_from: String = id_map.get(clip_conn["from_node"], "")
		var new_to: String = id_map.get(clip_conn["to_node"], "")
		if new_from != "" and new_to != "":
			BlueprintData.add_connection(graph, new_from, clip_conn["from_port"], new_to, clip_conn["to_port"], clip_conn["is_exec"])
	_save_active_graph()
	_host._sync_to_code_editor()
	if canvas:
		canvas.queue_redraw()
	_log_output("[粘贴] %d 个节点" % id_map.size())

# === 节点搜索弹窗 ===

## 打开节点搜索弹窗
func _open_node_search() -> void:
	if _bp_search_popup == null:
		_build_node_search_popup()
	_bp_search_results.clear()
	_bp_search_edit.text = ""
	_bp_search_list.clear()
	_populate_search_list("")
	var canvas: Control = _host._editor_container().find_child("EventGraphCanvas", true, false)
	if canvas:
		_bp_search_popup.popup_centered(Vector2i(350, 400))
	_bp_search_edit.grab_focus()

## 构建搜索弹窗UI
func _build_node_search_popup() -> void:
	_bp_search_popup = PopupPanel.new()
	_bp_search_popup.size = Vector2(350, 400)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	_bp_search_popup.add_child(vbox)
	# 标题
	var title := Label.new()
	title.text = "搜索节点"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
	vbox.add_child(title)
	# 搜索框
	_bp_search_edit = LineEdit.new()
	_bp_search_edit.placeholder_text = "输入节点名称或类型..."
	_bp_search_edit.text_changed.connect(func(new_text: String): _populate_search_list(new_text))
	vbox.add_child(_bp_search_edit)
	# 结果列表
	_bp_search_list = ItemList.new()
	_bp_search_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bp_search_list.item_selected.connect(_on_search_item_selected)
	vbox.add_child(_bp_search_list)
	# 提示
	var hint := Label.new()
	hint.text = "↑↓选择 Enter确认 Esc关闭"
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	vbox.add_child(hint)
	_host._editor_container().add_child(_bp_search_popup)

## 填充搜索结果
func _populate_search_list(query: String) -> void:
	_bp_search_list.clear()
	_bp_search_results.clear()
	var graph := _get_active_graph()
	var q := query.to_lower()
	# 详尽模式全局搜索：收集所有图
	var graphs_to_search: Array = [[_get_active_graph_key(), graph]]
	if EditorMode.is_exhaustive():
		var ws: Variant = _host._current_script()
		if ws != null:
			for gkey in GraphStore.list_graphs(ws):
				if gkey != _get_active_graph_key():
					graphs_to_search.append([gkey, GraphStore.get_graph(ws, gkey)])
	for ginfo in graphs_to_search:
		var gkey2: String = ginfo[0]
		var g2: Dictionary = ginfo[1]
		for nid in g2["nodes"]:
			var node: Dictionary = g2["nodes"][nid]
			var title_text: String = node.get("title", "")
			var node_type: String = node.get("node_type", "")
			var type_label: String = BlueprintData.get_node_type_label(node_type)
			var props_text := ""
			var props: Dictionary = node.get("properties", {})
			if props.has("event_name"):
				props_text = str(props["event_name"])
			elif props.has("var_name"):
				props_text = str(props["var_name"])
			elif props.has("code"):
				props_text = str(props["code"])
			# 搜索匹配
			var match_text := (title_text + " " + node_type + " " + type_label + " " + props_text).to_lower()
			if q.is_empty() or match_text.find(q) >= 0:
				var display := "%s [%s]" % [title_text, type_label]
				if not props_text.is_empty():
					display += " - %s" % props_text
				if graphs_to_search.size() > 1:
					display = "[%s] %s" % [gkey2, display]
				_bp_search_list.add_item(display)
				_bp_search_results.append(nid)

## 搜索结果选中
func _on_search_item_selected(idx: int) -> void:
	if idx < 0 or idx >= _bp_search_results.size():
		return
	var nid: String = _bp_search_results[idx]
	var graph := _get_active_graph()
	if not graph["nodes"].has(nid):
		return
	var node_pos: Vector2 = graph["nodes"][nid]["pos"]
	# 居中视图到该节点
	var canvas: Control = _host._editor_container().find_child("EventGraphCanvas", true, false)
	if canvas:
		var center: Vector2 = canvas.size / 2.0
		_bp_offset = center - node_pos * _bp_zoom
		_bp_selected_ids = [nid]
		# 定位高亮（黄框，下次交互清除）
		_bp_highlight_node = nid
		canvas.queue_redraw()
	_bp_search_popup.hide()

# === 小地图导航 ===

## 创建小地图控件
func _create_minimap(parent: Control) -> void:
	if _bp_minimap != null:
		return
	_bp_minimap = Control.new()
	_bp_minimap.name = "BlueprintMinimap"
	_bp_minimap.custom_minimum_size = BP_MINIMAP_SIZE
	_bp_minimap.size = BP_MINIMAP_SIZE
	_bp_minimap.anchor_left = 1.0
	_bp_minimap.anchor_right = 1.0
	_bp_minimap.anchor_top = 1.0
	_bp_minimap.anchor_bottom = 1.0
	_bp_minimap.offset_left = -BP_MINIMAP_SIZE.x - 8
	_bp_minimap.offset_top = -BP_MINIMAP_SIZE.y - 8
	_bp_minimap.offset_right = -8
	_bp_minimap.offset_bottom = -8
	_bp_minimap.mouse_filter = Control.MOUSE_FILTER_PASS  # 允许事件穿透到主画布
	parent.add_child(_bp_minimap)
	_bp_minimap.draw.connect(_draw_minimap)
	_bp_minimap.gui_input.connect(_on_minimap_input)

## 绘制小地图
func _draw_minimap() -> void:
	if _bp_minimap == null:
		return
	var graph := _get_active_graph()
	if graph["nodes"].is_empty():
		return
	# 半透明背景
	_bp_minimap.draw_rect(Rect2(Vector2.ZERO, BP_MINIMAP_SIZE), Color(0.08, 0.09, 0.12, 0.75))
	_bp_minimap.draw_rect(Rect2(Vector2.ZERO, BP_MINIMAP_SIZE), Color(0.3, 0.35, 0.45, 0.5), false, 1.0)
	# 计算所有节点的边界
	var min_pos := Vector2(INF, INF)
	var max_pos := Vector2(-INF, -INF)
	for nid in graph["nodes"]:
		var pos: Vector2 = graph["nodes"][nid]["pos"]
		min_pos = Vector2(minf(min_pos.x, pos.x), minf(min_pos.y, pos.y))
		max_pos = Vector2(maxf(max_pos.x, pos.x + VisualBlueprintDraw.BP_NODE_SIZE.x), maxf(max_pos.y, pos.y + VisualBlueprintDraw.BP_NODE_SIZE.y))
	var content_size := max_pos - min_pos + Vector2(100, 100)
	# 计算缩放
	var scale_x := BP_MINIMAP_SIZE.x / content_size.x
	var scale_y := BP_MINIMAP_SIZE.y / content_size.y
	var mm_scale := minf(scale_x, scale_y) * 0.9
	var mm_offset := (BP_MINIMAP_SIZE - content_size * mm_scale) / 2.0 - min_pos * mm_scale + Vector2(50 * mm_scale, 50 * mm_scale)
	# 绘制连线
	for conn in graph.get("connections", []):
		if graph["nodes"].has(conn["from_node"]) and graph["nodes"].has(conn["to_node"]):
			var from_pos: Vector2 = graph["nodes"][conn["from_node"]]["pos"] * mm_scale + mm_offset
			var to_pos: Vector2 = graph["nodes"][conn["to_node"]]["pos"] * mm_scale + mm_offset
			_bp_minimap.draw_line(from_pos, to_pos, Color(0.4, 0.4, 0.5, 0.4), 1.0)
	# 绘制节点缩略图
	for nid in graph["nodes"]:
		var node: Dictionary = graph["nodes"][nid]
		var pos: Vector2 = node["pos"] * mm_scale + mm_offset
		var sz := VisualBlueprintDraw.BP_NODE_SIZE * mm_scale
		var node_color: Color = node.get("color", Color(0.4, 0.4, 0.4, 0.8))
		node_color.a = 0.7
		_bp_minimap.draw_rect(Rect2(pos, sz), node_color)
	# 绘制当前视口范围
	var canvas: Control = _host._editor_container().find_child("EventGraphCanvas", true, false)
	if canvas and canvas.size.x > 0:
		var vp_top_left := _bp_screen_to_world(Vector2.ZERO)
		var vp_bottom_right := _bp_screen_to_world(canvas.size)
		var vp_mm_tl := vp_top_left * mm_scale + mm_offset
		var vp_mm_br := vp_bottom_right * mm_scale + mm_offset
		_bp_minimap.draw_rect(Rect2(vp_mm_tl, vp_mm_br - vp_mm_tl), Color(1.0, 1.0, 1.0, 0.4), false, 1.5)

## 小地图点击导航
func _on_minimap_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var graph := _get_active_graph()
		if graph["nodes"].is_empty():
			return
		# 计算边界和缩放（同绘制逻辑）
		var min_pos := Vector2(INF, INF)
		var max_pos := Vector2(-INF, -INF)
		for nid in graph["nodes"]:
			var pos: Vector2 = graph["nodes"][nid]["pos"]
			min_pos = Vector2(minf(min_pos.x, pos.x), minf(min_pos.y, pos.y))
			max_pos = Vector2(maxf(max_pos.x, pos.x + VisualBlueprintDraw.BP_NODE_SIZE.x), maxf(max_pos.y, pos.y + VisualBlueprintDraw.BP_NODE_SIZE.y))
		var content_size := max_pos - min_pos + Vector2(100, 100)
		var scale_x := BP_MINIMAP_SIZE.x / content_size.x
		var scale_y := BP_MINIMAP_SIZE.y / content_size.y
		var mm_scale := minf(scale_x, scale_y) * 0.9
		var mm_offset := (BP_MINIMAP_SIZE - content_size * mm_scale) / 2.0 - min_pos * mm_scale + Vector2(50 * mm_scale, 50 * mm_scale)
		# 将点击位置转换为世界坐标
		var mm_pos: Vector2 = event.position
		var world_pos := (mm_pos - mm_offset) / mm_scale
		# 居中视图到该位置
		var canvas: Control = _host._editor_container().find_child("EventGraphCanvas", true, false)
		if canvas:
			_bp_offset = canvas.size / 2.0 - world_pos * _bp_zoom
			canvas.queue_redraw()
		# 阻止事件继续传播到主画布
		_host._editor_container().get_viewport().set_input_as_handled()

# === 蓝图节点操作 ===

## 日志（委托宿主）
func _log_output(msg: String) -> void:
	_host._log_output(msg)

## 添加蓝图节点(工具栏按钮)
func _add_blueprint_node(node_type: String) -> void:
	var graph := _get_active_graph()
	_bp_push_undo()
	var canvas: Control = _host._editor_container().find_child("EventGraphCanvas", true, false)
	var center_world := _bp_screen_to_world(canvas.size / 2.0) if canvas else Vector2(300, 200)
	# 添加随机偏移避免重叠
	var offset := Vector2(randf_range(-30, 30), randf_range(-30, 30))
	var node: Dictionary = BlueprintData.create_node(node_type, center_world + offset)
	graph["nodes"][node["id"]] = node
	_save_active_graph()
	_host._sync_to_code_editor()
	_bp_selected_ids = [node["id"]]
	if canvas:
		canvas.queue_redraw()
	_log_output("[蓝图] 添加节点: %s (%s)" % [node.get("title", node_type), node["id"]])

## 编译蓝图(将蓝图图转译为GDScript代码)
func _compile_blueprint() -> void:
	var graph := _get_active_graph()
	if graph["nodes"].is_empty():
		_log_output("[蓝图] 无节点可编译")
		return
	# 详尽模式：编译前输出图概览
	if EditorMode.is_exhaustive():
		_log_output("=== 编译报告（详尽）===")
		_log_output("节点 %d 个：%s" % [graph["nodes"].size(), str(graph["nodes"].keys())])
		_log_output("连接 %d 条：%s" % [graph.get("connections", []).size(), str(graph.get("connections", []))])
		_log_output("执行顺序：%s" % str(_bp_compute_exec_order(graph)))
	# 验证蓝图
	var errors: Array[Dictionary] = BlueprintValidator.validate_graph(graph, _host._current_script())
	var error_count: int = 0
	for err in errors:
		_log_output("[蓝图校验] %s" % str(err))
		if err.get("level", "warn") == "error":
			error_count += 1
	if error_count > 0:
		_log_output("[蓝图] 编译中止: %d 个错误" % error_count)
		return
	# 详尽模式：校验通过提示
	if EditorMode.is_exhaustive():
		_log_output("[蓝图校验] 通过（0 错误 / %d 警告）" % (errors.size() - error_count))
	# 生成代码
	const ScriptCodeGenClass = preload("res://scripts/editor/script_codegen.gd")
	var code: String = ScriptCodeGenClass.generate_blueprint_code(graph, _host._current_script())
	if _host._bp_view == "workspace":
		# 工作区系统图: 编译产物写入图自身字段（随剧本持久化）
		graph["_compiled_code"] = code
	elif _host._bp_view == "event_blueprint" and _host._bp_current_event_id != "":
		# 将生成的代码写入事件的 blueprint_code 字段
		if _host._current_script() and _host._current_script().event_system:
			for ev in _host._current_script().event_system.story_events:
				if ev["id"] == _host._bp_current_event_id:
					ev["blueprint_code"] = code
					break
	_host._sync_to_code_editor()
	_host._mark_dirty()
	_log_output("[蓝图] 编译成功, 生成 %d 行代码" % code.split("\n").size())

## 修复图结构: 节点缺 pos/color/inputs/outputs 或为 null 时补默认值（防旧/损坏数据导致崩溃）
func _repair_graph_structure(graph: Dictionary) -> Dictionary:
	for nid in graph.get("nodes", {}):
		var node: Dictionary = graph["nodes"][nid] as Dictionary
		if not node.has("pos") or node["pos"] == null:
			node["pos"] = Vector2(100, 100)
		if not node.has("color") or node["color"] == null:
			node["color"] = Color(0.35, 0.6, 1.0)
		if not node.has("inputs") or node["inputs"] == null:
			node["inputs"] = []
		if not node.has("outputs") or node["outputs"] == null:
			node["outputs"] = []
	return graph

## 取引脚数据类型（节点/引脚缺失时返回 0, 防撤销/切图后拖拽释放崩溃）
func _pin_data_type(graph: Dictionary, node_id: String, port: int, is_output: bool) -> int:
	if not graph.get("nodes", {}).has(node_id):
		return 0
	var node: Dictionary = graph["nodes"][node_id]
	var pins: Array = node.get("outputs", []) if is_output else node.get("inputs", [])
	if port < 0 or port >= pins.size():
		return 0
	return int((pins[port] as Dictionary).get("data_type", 0))

## 绘制蓝图脚本图
func _draw_blueprint_graph(canvas: Control, graph: Dictionary) -> void:
	# 1. 网格背景
	VisualBlueprintDraw.draw_grid(canvas, _bp_offset, _bp_zoom)
	# 2. 连线
	var conn_index := 0
	for conn in graph.get("connections", []):
		if not graph["nodes"].has(conn["from_node"]) or not graph["nodes"].has(conn["to_node"]):
			continue
		var from_node: Dictionary = graph["nodes"][conn["from_node"]]
		var to_node: Dictionary = graph["nodes"][conn["to_node"]]
		var from_pos: Vector2 = BlueprintData.get_pin_world_pos(from_node, true, conn["from_port"])
		var to_pos: Vector2 = BlueprintData.get_pin_world_pos(to_node, false, conn["to_port"])
		if conn["is_exec"]:
			VisualBlueprintDraw.draw_exec_connection(canvas, from_pos, to_pos, _bp_offset, _bp_zoom)
			# 选中连线高亮
			if _bp_selected_connection == conn_index:
				var fs: Vector2 = VisualBlueprintDraw.world_to_screen(from_pos, _bp_offset, _bp_zoom)
				var ts: Vector2 = VisualBlueprintDraw.world_to_screen(to_pos, _bp_offset, _bp_zoom)
				canvas.draw_line(fs, ts, Color(1.0, 0.85, 0.2, 0.95), 3.0 * _bp_zoom)
		else:
			var pin_color: Color = Color(0.5, 0.7, 0.5, 0.8)
			if from_node["outputs"].size() > conn["from_port"]:
				var dt: int = from_node["outputs"][conn["from_port"]]["data_type"]
				pin_color = BlueprintData.PIN_COLORS.get(dt, pin_color)
			VisualBlueprintDraw.draw_connection(canvas, from_pos, to_pos, pin_color, 1.5 * _bp_zoom, _bp_offset, _bp_zoom)
			# 选中连线高亮
			if _bp_selected_connection == conn_index:
				var fs2: Vector2 = VisualBlueprintDraw.world_to_screen(from_pos, _bp_offset, _bp_zoom)
				var ts2: Vector2 = VisualBlueprintDraw.world_to_screen(to_pos, _bp_offset, _bp_zoom)
				canvas.draw_line(fs2, ts2, Color(1.0, 0.85, 0.2, 0.95), 3.0 * _bp_zoom)
		conn_index += 1
	# 3. 节点
	var show_detail: bool = EditorMode.is_exhaustive()
	# 详尽模式：计算执行顺序（BFS 从 start 沿 exec 连接）
	var exec_order: Dictionary = {}
	if show_detail:
		exec_order = _bp_compute_exec_order(graph)
	for nid in graph["nodes"]:
		var node: Dictionary = graph["nodes"][nid]
		var selected: bool = _bp_selected_ids.has(nid)
		VisualBlueprintDraw.draw_blueprint_node(canvas, node, selected, _bp_offset, _bp_zoom, show_detail, _bp_last_mouse_pos, int(exec_order.get(nid, 0)))
	# 3.5 搜索定位高亮（黄框提示）
	if _bp_highlight_node != "" and graph["nodes"].has(_bp_highlight_node):
		var hl_pos: Vector2 = VisualBlueprintDraw.world_to_screen(graph["nodes"][_bp_highlight_node]["pos"], _bp_offset, _bp_zoom)
		canvas.draw_rect(Rect2(hl_pos - Vector2(4, 4), Vector2(180 * _bp_zoom + 8, BlueprintData.calc_node_height(graph["nodes"][_bp_highlight_node]) * _bp_zoom + 8)), Color(1.0, 0.85, 0.2, 0.9), false, 2.0)
	# 4. 拖拽中的临时连线
	if _bp_pin_dragging:
		var from_node: Dictionary = graph["nodes"].get(_bp_pin_drag_from_id, {})
		if not from_node.is_empty():
			var from_pos: Vector2 = BlueprintData.get_pin_world_pos(from_node, _bp_pin_drag_is_output, _bp_pin_drag_from_port)
			var end_screen: Vector2 = _bp_temp_connection_end
			var end_world: Vector2 = _bp_screen_to_world(end_screen)
			if _bp_pin_drag_is_output:
				VisualBlueprintDraw.draw_connection(canvas, from_pos, end_world, Color(1, 1, 1, 0.6), 2.0, _bp_offset, _bp_zoom)
			else:
				VisualBlueprintDraw.draw_connection(canvas, end_world, from_pos, Color(1, 1, 1, 0.6), 2.0, _bp_offset, _bp_zoom)
	# 5. 框选矩形
	if _bp_box_selecting:
		var rect := Rect2(_bp_box_start, _bp_box_end - _bp_box_start).abs()
		canvas.draw_rect(rect, Color(0.3, 0.5, 1.0, 0.15))
		canvas.draw_rect(rect, Color(0.3, 0.5, 1.0, 0.6), false, 1.0)
	# 6. 详尽模式：右下角常驻缩放/坐标指示条
	if EditorMode.is_exhaustive():
		var mouse_world := _bp_screen_to_world(_bp_last_mouse_pos)
		var info_txt: String = "🔍 缩放 %d%% | 鼠标 (%d, %d) | 节点 %d" % [
			int(_bp_zoom * 100.0), int(mouse_world.x), int(mouse_world.y), graph["nodes"].size()]
		var info_pos := Vector2(canvas.size.x - info_txt.length() * 6.5 - 12, canvas.size.y - 10)
		canvas.draw_string(ThemeDB.fallback_font, info_pos, info_txt, HORIZONTAL_ALIGNMENT_LEFT, int(canvas.size.x), int(10), Color(0.55, 0.6, 0.65, 0.8))

## 连线命中检测（返回 connections 索引，未命中 -1）
func _bp_hit_test_connection(screen_pos: Vector2, graph: Dictionary) -> int:
	var conns: Array = graph.get("connections", [])
	for i in conns.size():
		var conn: Dictionary = conns[i]
		var fn: String = str(conn.get("from_node", ""))
		var tn: String = str(conn.get("to_node", ""))
		if not graph["nodes"].has(fn) or not graph["nodes"].has(tn):
			continue
		var from_world: Vector2 = BlueprintData.get_pin_world_pos(graph["nodes"][fn], true, int(conn.get("from_port", 0)))
		var to_world: Vector2 = BlueprintData.get_pin_world_pos(graph["nodes"][tn], false, int(conn.get("to_port", 0)))
		var from_screen: Vector2 = VisualBlueprintDraw.world_to_screen(from_world, _bp_offset, _bp_zoom)
		var to_screen: Vector2 = VisualBlueprintDraw.world_to_screen(to_world, _bp_offset, _bp_zoom)
		if _point_segment_distance(screen_pos, from_screen, to_screen) < 8.0:
			return i
	return -1

## 点到线段距离（避免 Geometry2D 静态类兼容问题）
func _point_segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len2 := ab.length_squared()
	if len2 < 0.0001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / len2, 0.0, 1.0)
	return p.distance_to(a + ab * t)

## 当前激活图 key（workspace 或事件蓝图）
func _get_active_graph_key() -> String:
	if _host != null and _host.has_method("_current_graph_key"):
		return str(_host._current_graph_key())
	return "evt:current"

## 详尽模式：计算节点执行顺序（从 start 沿 exec 连接 BFS）
func _bp_compute_exec_order(graph: Dictionary) -> Dictionary:
	var order: Dictionary = {}
	var starts: Array[String] = []
	for nid in graph["nodes"]:
		var nt: String = str(graph["nodes"][nid].get("node_type", ""))
		if nt == "start" or nt == "flow_start":
			starts.append(nid)
	# 无 start 时按节点 id 顺序兜底
	if starts.is_empty():
		var ids: Array = graph["nodes"].keys()
		ids.sort()
		for i in ids.size():
			order[str(ids[i])] = i + 1
		return order
	var queue: Array[String] = starts.duplicate()
	var visited: Dictionary = {}
	var idx := 1
	while not queue.is_empty():
		var cur: String = queue.pop_front()
		if visited.has(cur):
			continue
		visited[cur] = true
		order[cur] = idx
		idx += 1
		for conn in graph.get("connections", []):
			if str(conn.get("from_node", "")) == cur and bool(conn.get("is_exec", true)):
				var to: String = str(conn.get("to_node", ""))
				if not visited.has(to) and not queue.has(to):
					queue.append(to)
	return order

## 快速添加节点弹窗（输入过滤 + 点击创建，UE 风格）
func _bp_quick_add_popup(canvas: Control) -> void:
	var popup := PopupPanel.new()
	popup.name = "QuickAddPopup"
	popup.size = Vector2i(300, 360)
	popup.position = Vector2i(0, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	popup.add_child(box)
	var title := Label.new()
	title.text = "快速添加节点（输入搜索）"
	title.add_theme_font_size_override("font_size", 13)
	box.add_child(title)
	var edit := LineEdit.new()
	edit.placeholder_text = "输入节点名/类型/描述…"
	box.add_child(edit)
	var list := ItemList.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(list)
	var all_types: Array = BlueprintNodeRegistry.get_all_types(EditorMode.current_mode)
	# 填充全部（按模式过滤）
	var display: Array[String] = []
	for t in all_types:
		var d: Dictionary = BlueprintNodeRegistry.get_definition(t)
		display.append("%s（%s）" % [d.get("name", t), d.get("category", "")])
		list.add_item("%s（%s）" % [d.get("name", t), d.get("category", "")])
	list.add_item("▶ 传统：%s" % "start")
	display.append("start")
	# 过滤
	edit.text_changed.connect(func(t: String):
		var q := t.strip_edges().to_lower()
		list.clear()
		for i in display.size():
			if q.is_empty() or display[i].to_lower().contains(q):
				list.add_item(display[i], null, false)
				list.set_item_metadata(list.item_count - 1, i))
	# 选中创建
	list.item_activated.connect(func(idx: int):
		var meta = list.get_item_metadata(idx)
		var type_idx: int = int(meta)
		var node_type: String = all_types[type_idx] if type_idx < all_types.size() else "start"
		var world_pos := _bp_screen_to_world(canvas.size / 2.0)
		_create_node_at_position_custom(node_type, world_pos)
		popup.queue_free())
	canvas.add_child(popup)
	popup.popup(Rect2i(Vector2i(canvas.size / 2.0 - Vector2(150, 180)), Vector2i(300, 360)))
	edit.grab_focus()

## 指定位置创建节点（快速添加用）
func _create_node_at_position_custom(node_type: String, world_pos: Vector2) -> void:
	var graph := _get_active_graph()
	_bp_push_undo()
	var node: Dictionary = BlueprintData.create_node(node_type, world_pos)
	graph["nodes"][node["id"]] = node
	_save_active_graph()
	_host._sync_to_code_editor()
	var canvas: Control = _host._editor_container().find_child("EventGraphCanvas", true, false)
	if canvas:
		canvas.queue_redraw()

## 详尽模式：查看整图数据 JSON（只读调试）
func _bp_show_graph_data(graph: Dictionary) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "图数据（只读）"
	dialog.min_size = Vector2i(520, 420)
	dialog.size = Vector2i(520, 420)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialog.add_child(scroll)
	var lbl := RichTextLabel.new()
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.bbcode_enabled = true
	lbl.fit_content = true
	var json_txt: String = JSON.stringify(graph, "\t")
	# 简化显示（节点数/连接数 + 前 60 行 JSON）
	var summary := "[b]图数据：%d 节点 / %d 连接[/b]\n\n" % [graph["nodes"].size(), graph.get("connections", []).size()]
	var lines: PackedStringArray = json_txt.split("\n")
	if lines.size() > 60:
		json_txt = ""
		for i in 60:
			json_txt += lines[i] + "\n"
		json_txt += "\n…（共 %d 行，详细数据可复制）" % lines.size()
	lbl.text = summary + "[color=#8a8f9a]%s[/color]" % json_txt
	scroll.add_child(lbl)
	# 复制按钮
	var copy_btn := Button.new()
	copy_btn.text = "⧉ 复制完整 JSON"
	copy_btn.flat = true
	copy_btn.pressed.connect(func():
		DisplayServer.clipboard_set(JSON.stringify(graph, "\t"))
		ToastManager.success("完整图数据已复制"))
	dialog.add_child(copy_btn)
	# 导出文件按钮（详尽调试）
	var save_btn := Button.new()
	save_btn.text = "💾 导出 JSON 文件"
	save_btn.flat = true
	save_btn.pressed.connect(func():
		var out_path := "user://graph_data_%s.json" % Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify(graph, "\t"))
			f.close()
			ToastManager.success("已导出：%s" % ProjectSettings.globalize_path(out_path)))
	dialog.add_child(save_btn)
	var host_node: Node = _host._editor_container()
	host_node.add_child(dialog)
	dialog.popup_centered()

## 蓝图模式画布输入(事件蓝图编辑视图)
## 缩放百分比临时提示（画布上 1 秒淡出）
func _bp_show_zoom(canvas: Control) -> void:
	var lbl := Label.new()
	lbl.text = "%d%%" % int(_bp_zoom * 100.0)
	lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.position = Vector2(12, 12)
	lbl.z_index = 50
	canvas.add_child(lbl)
	# RefCounted 无 create_tween：用宿主节点创建
	var host_node: Node = _host
	var tw: Tween = host_node.create_tween()
	tw.tween_interval(0.9)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.4)
	tw.tween_callback(lbl.queue_free)

func _on_blueprint_canvas_input(event: InputEvent, canvas: Control) -> void:
	var graph := _get_active_graph()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			var old_zoom := _bp_zoom
			_bp_zoom = clampf(_bp_zoom * 1.1, 0.2, 3.0)
			_bp_offset = event.position - (event.position - _bp_offset) * (_bp_zoom / old_zoom)
			canvas.queue_redraw()
			_bp_show_zoom(canvas)
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var old_zoom := _bp_zoom
			_bp_zoom = clampf(_bp_zoom / 1.1, 0.2, 3.0)
			_bp_offset = event.position - (event.position - _bp_offset) * (_bp_zoom / old_zoom)
			canvas.queue_redraw()
			_bp_show_zoom(canvas)
			return
	# 鼠标按下
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# 检测引脚命中
			var pin_hit = VisualBlueprintDraw.hit_test_bp_pins(event.position, graph, _bp_offset, _bp_zoom)
			if pin_hit != null:
				_bp_pin_dragging = true
				_bp_pin_drag_from_id = pin_hit[0]
				_bp_pin_drag_from_port = pin_hit[1]
				_bp_pin_drag_is_output = pin_hit[2]
				_bp_temp_connection_end = event.position
				return
			# 检测节点命中
			var hit_id := VisualBlueprintDraw.hit_test_bp_node(event.position, graph, _bp_offset, _bp_zoom)
			if hit_id != "":
				if not _bp_selected_ids.has(hit_id):
					_bp_selected_ids.clear()
					_bp_selected_ids.append(hit_id)
				_bp_node_dragging = true
				_bp_node_drag_id = hit_id
				_bp_node_drag_offset = _bp_screen_to_world(event.position) - graph["nodes"][hit_id]["pos"]
				_bp_push_undo()
				# 显示属性面板
				_show_bp_node_properties(hit_id)
				canvas.queue_redraw()
				return
			# 检测连线命中（点击连线选中）
			var conn_idx := _bp_hit_test_connection(event.position, graph)
			if conn_idx >= 0:
				_bp_selected_connection = conn_idx
				_bp_selected_ids.clear()
				canvas.queue_redraw()
				# 连线信息提示
				var conns_i: Array = graph.get("connections", [])
				if conn_idx < conns_i.size():
					var cinfo: Dictionary = conns_i[conn_idx]
					var ctype: String = "执行流" if bool(cinfo.get("is_exec", true)) else "数据"
					ToastManager.info("连线：%s 端口%d → 端口%d（%s）｜Delete 删除" % [
						ctype, int(cinfo.get("from_port", 0)), int(cinfo.get("to_port", 0)), ctype])
				return
			# 空白处: 双击打开添加节点菜单，单击框选
			if event.double_click:
				_bp_ctx_from_pin_drag = false
				_bp_ctx_drag_data_type = int(-1)
				_show_bp_context_menu(canvas, event.position)
				return
			_bp_selected_ids.clear()
			_bp_selected_connection = -1
			_bp_box_selecting = true
			_bp_box_start = event.position
			_bp_box_end = event.position
			_hide_bp_node_properties()
			canvas.queue_redraw()
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_bp_dragging = true
			_bp_drag_start = event.position
			_bp_highlight_node = ""
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			# 右键: 引脚拖拽 或 空白处菜单
			var pin_hit = VisualBlueprintDraw.hit_test_bp_pins(event.position, graph, _bp_offset, _bp_zoom)
			if pin_hit != null:
				_bp_pin_dragging = true
				_bp_pin_drag_from_id = pin_hit[0]
				_bp_pin_drag_from_port = pin_hit[1]
				_bp_pin_drag_is_output = pin_hit[2]
				_bp_temp_connection_end = event.position
			else:
				_bp_ctx_menu_pos = _bp_screen_to_world(event.position)
				_bp_ctx_from_pin_drag = false
				_show_bp_context_menu(canvas, event.position)
	# 鼠标释放
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if _bp_pin_dragging:
				# 尝试连线
				var pin_hit = VisualBlueprintDraw.hit_test_bp_pins(event.position, graph, _bp_offset, _bp_zoom)
				if pin_hit != null:
					var target_id: String = pin_hit[0]
					var target_port: int = pin_hit[1]
					var target_is_output: bool = pin_hit[2]
					# 验证连线合法性
					if _bp_pin_drag_is_output and not target_is_output:
						if BlueprintData.validate_connection(graph, _bp_pin_drag_from_id, _bp_pin_drag_from_port, target_id, target_port):
							_bp_push_undo()
							var is_exec: bool = _pin_data_type(graph, _bp_pin_drag_from_id, _bp_pin_drag_from_port, true) == BlueprintData.PinDataType.EXEC
							BlueprintData.add_connection(graph, _bp_pin_drag_from_id, _bp_pin_drag_from_port, target_id, target_port, is_exec)
							_save_active_graph()
							_host._sync_to_code_editor()
					elif not _bp_pin_drag_is_output and target_is_output:
						if BlueprintData.validate_connection(graph, target_id, target_port, _bp_pin_drag_from_id, _bp_pin_drag_from_port):
							_bp_push_undo()
							var is_exec: bool = _pin_data_type(graph, target_id, target_port, true) == BlueprintData.PinDataType.EXEC
							BlueprintData.add_connection(graph, target_id, target_port, _bp_pin_drag_from_id, _bp_pin_drag_from_port, is_exec)
							_save_active_graph()
							_host._sync_to_code_editor()
				else:
					# 拖到空白处: 弹出创建菜单
					_bp_ctx_menu_pos = _bp_screen_to_world(event.position)
					_bp_ctx_from_pin_drag = true
					_bp_ctx_drag_from_id = _bp_pin_drag_from_id
					_bp_ctx_drag_from_port = _bp_pin_drag_from_port
					_bp_ctx_drag_is_output = _bp_pin_drag_is_output
					if graph["nodes"].has(_bp_pin_drag_from_id):
						var from_node: Dictionary = graph["nodes"][_bp_pin_drag_from_id]
						if _bp_pin_drag_is_output and from_node.get("outputs", []).size() > _bp_pin_drag_from_port:
							_bp_ctx_drag_data_type = from_node["outputs"][_bp_pin_drag_from_port]["data_type"]
						elif not _bp_pin_drag_is_output:
							var _fp_ins: Array = from_node.get("inputs", [])
							if _bp_pin_drag_from_port < _fp_ins.size():
								_bp_ctx_drag_data_type = _fp_ins[_bp_pin_drag_from_port].get("data_type", BlueprintData.PinDataType.ANY)
					_show_bp_context_menu(canvas, event.position)
				_bp_pin_dragging = false
				canvas.queue_redraw()
			elif _bp_node_dragging:
				_bp_node_dragging = false
				_save_active_graph()
			elif _bp_box_selecting:
				# 完成框选, 找出框内的所有节点
				_bp_box_selecting = false
				var sel_rect := Rect2(_bp_screen_to_world(_bp_box_start), _bp_screen_to_world(_bp_box_end) - _bp_screen_to_world(_bp_box_start)).abs()
				_bp_selected_ids.clear()
				for nid in graph["nodes"]:
					var node: Dictionary = graph["nodes"][nid]
					var node_height: float = BlueprintData.calc_node_height(node)
					var node_rect := Rect2(node["pos"], Vector2(180.0, node_height))
					if sel_rect.intersects(node_rect):
						_bp_selected_ids.append(nid)
				canvas.queue_redraw()
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_bp_dragging = false
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if _bp_pin_dragging:
				_bp_pin_dragging = false
				canvas.queue_redraw()
	# 鼠标移动
	if event is InputEventMouseMotion:
		# 记录鼠标位置（引脚 hover 高亮用）+ 节流重绘（性能优化：仅移动>4px 或拖拽时）
		var moved := _bp_last_mouse_pos.distance_to(event.position)
		_bp_last_mouse_pos = event.position
		if moved > 4.0 or _bp_dragging or _bp_node_dragging or _bp_pin_dragging:
			canvas.queue_redraw()
		if _bp_dragging:
			_bp_offset += event.relative
			canvas.queue_redraw()
		elif _bp_node_dragging:
			var world_pos := _bp_screen_to_world(event.position)
			var new_pos := world_pos - _bp_node_drag_offset
			if _bp_grid_snap:
				new_pos = new_pos.snapped(Vector2(VisualBlueprintDraw.BP_GRID_SIZE, VisualBlueprintDraw.BP_GRID_SIZE))
			graph["nodes"][_bp_node_drag_id]["pos"] = new_pos
			canvas.queue_redraw()
		elif _bp_pin_dragging:
			_bp_temp_connection_end = event.position
			canvas.queue_redraw()
		elif _bp_box_selecting:
			_bp_box_end = event.position
			canvas.queue_redraw()
	# 键盘快捷键
	if event is InputEventKey and event.pressed:
		if event.ctrl_pressed and event.keycode == KEY_Z:
			_bp_undo()
		elif event.ctrl_pressed and event.keycode == KEY_Y:
			_bp_redo()
		elif event.ctrl_pressed and event.keycode == KEY_C:
			_bp_copy()
		elif event.ctrl_pressed and event.keycode == KEY_V:
			_bp_paste()
		elif event.ctrl_pressed and event.keycode == KEY_D:
			# 就地复制选中节点（复制+粘贴，粘贴带偏移）
			if not _bp_selected_ids.is_empty():
				_bp_copy()
				_bp_paste()
		elif event.ctrl_pressed and event.shift_pressed and event.keycode == KEY_X:
			# 清空当前图所有连线（可撤销）
			var conns: Array = graph.get("connections", [])
			if not conns.is_empty():
				_bp_push_undo()
				graph["connections"] = []
				_save_active_graph()
				_host._sync_to_code_editor()
				canvas.queue_redraw()
				_log_output("[清除连线] 已移除 %d 条连线" % conns.size())
		elif event.keycode == KEY_DELETE:
			# 优先删除选中的连线
			if _bp_selected_connection >= 0:
				var conns2: Array = graph.get("connections", [])
				if _bp_selected_connection < conns2.size():
					_bp_push_undo()
					conns2.remove_at(_bp_selected_connection)
					_save_active_graph()
					_host._sync_to_code_editor()
					_log_output("[删除连线] 已移除")
				_bp_selected_connection = -1
				canvas.queue_redraw()
				return
			if not _bp_selected_ids.is_empty():
				# 多节点删除确认（防误删）
				if _bp_selected_ids.size() >= 3:
					var host_node: Node = _host
					var confirm := ConfirmationDialog.new()
					confirm.dialog_text = "确定删除选中的 %d 个节点？（可撤销）" % _bp_selected_ids.size()
					confirm.confirmed.connect(func():
						_bp_delete_selected(graph, canvas))
					host_node.add_child(confirm)
					confirm.popup_centered()
				else:
					_bp_delete_selected(graph, canvas)
		elif event.keycode == KEY_G and not event.ctrl_pressed and not event.shift_pressed:
			# G 键切换网格吸附
			_bp_grid_snap = not _bp_grid_snap
			_log_output("[网格吸附] %s" % ("开" if _bp_grid_snap else "关"))
		elif event.keycode == KEY_F:
			_fit_canvas_to_nodes(canvas)
		elif event.keycode == KEY_C and not event.ctrl_pressed:
			# C 键：选中节点画布居中
			if not _bp_selected_ids.is_empty():
				var center := Vector2.ZERO
				var count := 0
				for nid in _bp_selected_ids:
					var nd: Dictionary = graph["nodes"].get(nid, {})
					if not nd.is_empty():
						center += Vector2(nd.get("x", 0.0), nd.get("y", 0.0))
						count += 1
				if count > 0:
					center /= count
					_bp_offset = canvas.size / 2.0 - center * _bp_zoom
					canvas.queue_redraw()
		elif event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN] and not _bp_selected_ids.is_empty():
			# 方向键微调选中节点（Shift 加速 10px）
			var step := 10.0 if event.shift_pressed else 1.0
			var delta := Vector2.ZERO
			match event.keycode:
				KEY_LEFT: delta = Vector2(-step, 0)
				KEY_RIGHT: delta = Vector2(step, 0)
				KEY_UP: delta = Vector2(0, -step)
				KEY_DOWN: delta = Vector2(0, step)
			_bp_push_undo()
			for nid in _bp_selected_ids:
				var nd: Dictionary = graph["nodes"].get(nid, {})
				if not nd.is_empty():
					nd["pos"] = Vector2(nd.get("pos", Vector2.ZERO)) + delta
			_save_active_graph()
			_host._sync_to_code_editor()
			canvas.queue_redraw()
		elif event.keycode == KEY_EQUAL or event.keycode == KEY_KP_ADD:
			_bp_zoom = clampf(_bp_zoom * 1.15, 0.2, 3.0)
			canvas.queue_redraw()
		elif event.keycode == KEY_MINUS or event.keycode == KEY_KP_SUBTRACT:
			_bp_zoom = clampf(_bp_zoom / 1.15, 0.2, 3.0)
			canvas.queue_redraw()
		elif event.keycode == KEY_0:
			_bp_zoom = 1.0
			canvas.queue_redraw()

# === 右键菜单 ===

## 显示右键菜单（空白处右键 或 引脚拖拽到空白处）
func _show_bp_context_menu(canvas: Control, screen_pos: Vector2) -> void:
	var graph := _get_active_graph()
	# 确定可用的节点类型列表
	var available_types: Array[String]
	if _bp_ctx_from_pin_drag:
		available_types = BlueprintData.get_compatible_node_types(graph, _bp_ctx_drag_data_type, _bp_ctx_drag_is_output)
	else:
		available_types = BlueprintData.get_available_node_types()
	# 按编辑模式过滤（简易隐藏高级节点；基础节点保留）
	var edit_mode: int = EditorMode.current_mode
	# 传统基础节点分级（简易隐藏高级调试类）
	var base_node_mode := {"print": 1, "expression": 1, "random_event": 1}
	var filtered_types: Array[String] = []
	for nt in available_types:
		var reg_def_f: Dictionary = BlueprintNodeRegistry.get_definition(nt)
		if reg_def_f.is_empty():
			if int(base_node_mode.get(nt, 0)) <= edit_mode:
				filtered_types.append(nt)
		elif int(reg_def_f.get("min_mode", 1)) <= edit_mode:
			filtered_types.append(nt)
	available_types = filtered_types
	# 按分类分组
	var categorized: Dictionary = {}  # category -> [node_type, ...]
	var base_types: Array[String] = []
	for nt in available_types:
		var reg_def: Dictionary = BlueprintNodeRegistry.get_definition(nt)
		if reg_def.is_empty():
			base_types.append(nt)
		else:
			var cat: String = reg_def.get("category", "flow")
			if not categorized.has(cat):
				categorized[cat] = []
			categorized[cat].append(nt)
	var popup := PopupMenu.new()
	popup.name = "BpContextMenu"
	popup.size = Vector2i(220, 400)
	# 先添加基础节点(无分类)
	if not base_types.is_empty():
		var base_sub := PopupMenu.new()
		base_sub.name = "BaseNodes"
		for nt in base_types:
			base_sub.add_item(BlueprintData.get_node_type_label(nt))
		base_sub.id_pressed.connect(func(id: int):
			_create_node_at_position(base_types[id])
			popup.queue_free()
		)
		popup.add_child(base_sub)
		popup.add_submenu_item("▶ 基础节点", base_sub.name)
	# 按分类添加注册表节点
	var categories: Dictionary = BlueprintNodeRegistry.get_categories()
	for cat_key in categorized:
		var cat_info: Dictionary = categories.get(cat_key, {"name": cat_key, "icon": ""})
		var cat_sub := PopupMenu.new()
		cat_sub.name = "Cat_%s" % cat_key
		var types_in_cat: Array = categorized[cat_key]
		for nt in types_in_cat:
			var reg_def: Dictionary = BlueprintNodeRegistry.get_definition(nt)
			cat_sub.add_item("%s %s" % [cat_info.get("icon", ""), reg_def.get("name", nt)])
		cat_sub.id_pressed.connect(func(id: int):
			_create_node_at_position(types_in_cat[id])
			popup.queue_free()
		)
		popup.add_child(cat_sub)
		popup.add_submenu_item("%s %s" % [cat_info.get("icon", ""), cat_info.get("name", cat_key)], cat_sub.name)
	# 详尽模式：图数据查看项
	if EditorMode.is_exhaustive():
		popup.add_separator()
		popup.add_item("📋 图数据 JSON", 99001)
		popup.id_pressed.connect(func(id: int):
			if id == 99001:
				_bp_show_graph_data(graph)
			popup.queue_free())
	# 快速添加节点搜索（UE 风格）
	popup.add_separator()
	popup.add_item("🔍 快速添加节点…", 99002)
	popup.id_pressed.connect(func(id: int):
		if id == 99002:
			_bp_quick_add_popup(canvas)
			popup.queue_free())
	# 菜单关闭时清理
	popup.popup_hide.connect(func():
		popup.queue_free()
	)
	canvas.add_child(popup)
	popup.popup(Rect2i(Vector2i(screen_pos), Vector2i(220, 300)))

## 在指定世界坐标创建蓝图节点，若处于引脚拖拽上下文则自动连线
func _create_node_at_position(node_type: String) -> void:
	var graph := _get_active_graph()
	_bp_push_undo()
	var node: Dictionary = BlueprintData.create_node(node_type, _bp_ctx_menu_pos)
	graph["nodes"][node["id"]] = node
	# 如果是从引脚拖拽创建, 自动连线
	if _bp_ctx_from_pin_drag and _bp_ctx_drag_from_id != "":
		if _bp_ctx_drag_is_output:
			# 从输出引脚拖拽创建, 找新节点的第一个兼容输入端口
			var port := _find_compatible_port(node, _bp_ctx_drag_data_type, false)
			if port >= 0:
				var is_exec: bool = _bp_ctx_drag_data_type == BlueprintData.PinDataType.EXEC
				BlueprintData.add_connection(graph, _bp_ctx_drag_from_id, _bp_ctx_drag_from_port, node["id"], port, is_exec)
		else:
			# 从输入引脚拖拽创建, 找新节点的第一个兼容输出端口
			var port := _find_compatible_port(node, _bp_ctx_drag_data_type, true)
			if port >= 0:
				var is_exec: bool = _bp_ctx_drag_data_type == BlueprintData.PinDataType.EXEC
				BlueprintData.add_connection(graph, node["id"], port, _bp_ctx_drag_from_id, _bp_ctx_drag_from_port, is_exec)
	_bp_ctx_from_pin_drag = false
	_bp_ctx_drag_from_id = ""
	_save_active_graph()
	_host._sync_to_code_editor()
	_bp_selected_ids = [node["id"]]
	_bp_redraw_canvas()
	_log_output("[蓝图] 创建节点: %s" % node.get("title", node_type))

## 查找节点上兼容指定数据类型的端口
func _find_compatible_port(node: Dictionary, data_type: int, is_output: bool) -> int:
	var pins: Array = node.get("outputs", []) if is_output else node.get("inputs", [])
	for i in pins.size():
		var pin: Dictionary = pins[i]
		if is_output:
			if BlueprintData._pin_types_compatible(pin["data_type"], data_type):
				return i
		else:
			if BlueprintData._pin_types_compatible(data_type, pin["data_type"]):
				return i
	return -1

## 自动布局事件图
func _auto_layout_event_graph() -> void:
	var graph := _get_active_graph()
	if graph["nodes"].is_empty():
		return
	_bp_push_undo()
	var y := 100.0
	var x := 100.0
	var col_count := 0
	for nid in graph["nodes"]:
		graph["nodes"][nid]["pos"] = Vector2(x, y)
		y += 130.0
		col_count += 1
		if col_count >= 8:
			col_count = 0
			y = 100.0
			x += 250.0
	_save_active_graph()
	_bp_redraw_canvas()
	_log_output("[布局] 自动布局完成")

## 适应画布: 缩放+平移使所有节点可见
func _fit_canvas_to_nodes(canvas_or_parent: Control) -> void:
	var canvas: Control = null
	if canvas_or_parent.name == "EventGraphCanvas":
		canvas = canvas_or_parent
	else:
		canvas = _host._editor_container().find_child("EventGraphCanvas", true, false)
	if canvas == null:
		return
	var graph := _get_active_graph()
	if graph["nodes"].is_empty():
		return
	# 计算所有节点的边界
	var min_pos := Vector2(INF, INF)
	var max_pos := Vector2(-INF, -INF)
	for nid in graph["nodes"]:
		var pos: Vector2 = graph["nodes"][nid]["pos"]
		var node_height: float = VisualBlueprintDraw.BP_NODE_SIZE.y
		if graph["nodes"][nid].has("inputs"):
			node_height = BlueprintData.calc_node_height(graph["nodes"][nid])
		min_pos = Vector2(minf(min_pos.x, pos.x), minf(min_pos.y, pos.y))
		max_pos = Vector2(maxf(max_pos.x, pos.x + 180.0), maxf(max_pos.y, pos.y + node_height))
	var content_size := max_pos - min_pos + Vector2(100, 100)
	# 计算缩放
	var zoom_x: float = canvas.size.x / content_size.x
	var zoom_y: float = canvas.size.y / content_size.y
	_bp_zoom = clampf(minf(zoom_x, zoom_y) * 0.9, 0.2, 2.0)
	# 计算偏移使内容居中
	var content_center := (min_pos + max_pos) / 2.0
	_bp_offset = canvas.size / 2.0 - content_center * _bp_zoom
	canvas.queue_redraw()

## 查找最近的兼容输入端口(用于自动连线)
func _find_nearest_input_port(graph: Dictionary, world_pos: Vector2, data_type: int) -> Array:
	var best_id := ""
	var best_port := -1
	var best_dist := INF
	for nid in graph["nodes"]:
		var node: Dictionary = graph["nodes"][nid]
		for i in node.get("inputs", []).size():
			var pin: Dictionary = node["inputs"][i]
			if BlueprintData._pin_types_compatible(data_type, pin["data_type"]):
				var pin_pos: Vector2 = BlueprintData.get_pin_world_pos(node, false, i)
				var d: float = world_pos.distance_to(pin_pos)
				if d < best_dist:
					best_dist = d
					best_id = nid
					best_port = i
	if best_id != "" and best_dist < 200.0:
		return [best_id, best_port]
	return []

## 打开蓝图节点编辑器(双击节点)
func _open_blueprint_node_editor(node_id: String) -> void:
	var graph := _get_active_graph()
	if not graph["nodes"].has(node_id):
		return
	_bp_selected_ids = [node_id]
	_show_bp_node_properties(node_id)
	_bp_redraw_canvas()

# === 蓝图节点属性面板 ===

## 显示蓝图节点属性面板(选中节点时)
func _show_bp_node_properties(node_id: String) -> void:
	var detail: Control = _host._editor_container().find_child("EventDetail", true, false)
	if detail == null:
		return
	for child in detail.get_children():
		child.queue_free()
	var graph := _get_active_graph()
	if not graph["nodes"].has(node_id):
		return
	var node: Dictionary = graph["nodes"][node_id]
	# 节点分类颜色条（顶部视觉对应画布节点色）
	var node_color: Color = node.get("color", Color(0.4, 0.4, 0.4, 0.8))
	var color_bar := ColorRect.new()
	color_bar.color = node_color
	color_bar.custom_minimum_size.y = 4
	detail.add_child(color_bar)
	# 获取注册表定义
	var reg_def: Dictionary = BlueprintNodeRegistry.get_definition(node["node_type"])
	if reg_def.is_empty():
		# 旧基础节点: 显示基本属性编辑
		_build_basic_node_props(detail, node)
		return
	# === 注册表节点: 动态渲染参数控件 ===
	# 标题栏（可编辑重命名）
	_host._ui().add_text_field(detail, "节点标题", node.get("title", ""), func(v):
		var t2 := str(v).strip_edges()
		if t2.is_empty():
			t2 = BlueprintNodeRegistry.get_display_name(node.get("node_type", ""))
		node["title"] = t2
		_host._mark_dirty()
		_save_active_graph()
		_host._sync_to_code_editor()
		_bp_redraw_canvas())
	# 节点ID
	_host._ui().add_info_label(detail, "ID: %s" % node_id)
	# 参数数量标题
	_host._ui().add_section_label(detail, "⚙ 参数（%d 项）" % reg_def.get("params", []).size())
	# 详尽模式：执行顺序显示
	if EditorMode.is_exhaustive():
		var order_map: Dictionary = _bp_compute_exec_order(graph)
		var order_val: int = int(order_map.get(node_id, 0))
		var order_txt: String = "（未连接，不参与执行流）" if order_val == 0 else "第 %d 步执行" % order_val
		_host._ui().add_info_label(detail, "⚡ 执行顺序：%s" % order_txt)
	# 坐标编辑（X/Y）
	var pos_box := HBoxContainer.new()
	pos_box.add_theme_constant_override("separation", 8)
	detail.add_child(pos_box)
	var pos_lbl := Label.new()
	pos_lbl.text = "坐标"
	pos_lbl.custom_minimum_size.x = 60
	pos_lbl.add_theme_color_override("font_color", EditorUIFactory.C_LABEL)
	pos_lbl.add_theme_font_size_override("font_size", 12)
	pos_box.add_child(pos_lbl)
	var pos_x := SpinBox.new()
	pos_x.min_value = -20000
	pos_x.max_value = 20000
	pos_x.value = node.get("pos", Vector2.ZERO).x
	pos_x.value_changed.connect(func(v: float):
		node["pos"] = Vector2(v, node.get("pos", Vector2.ZERO).y)
		_bp_redraw_canvas())
	pos_box.add_child(pos_x)
	var pos_y := SpinBox.new()
	pos_y.min_value = -20000
	pos_y.max_value = 20000
	pos_y.value = node.get("pos", Vector2.ZERO).y
	pos_y.value_changed.connect(func(v: float):
		node["pos"] = Vector2(node.get("pos", Vector2.ZERO).x, v)
		_bp_redraw_canvas())
	pos_box.add_child(pos_y)
	# 分类+优先级标签
	var cat_info: Dictionary = BlueprintNodeRegistry.CATEGORIES.get(reg_def.get("category", ""), {})
	if not cat_info.is_empty():
		_host._ui().add_info_label(detail, "分类: %s %s | 优先级: %s" % [cat_info.get("icon", ""), cat_info.get("name", ""), reg_def.get("priority", "P1")])
	# 描述
	if reg_def.get("description", "") != "":
		_host._ui().add_info_label(detail, reg_def["description"])
	# 参数控件
	var params: Array = reg_def.get("params", [])
	if params.is_empty():
		_host._ui().add_info_label(detail, "此节点无可配置参数")
	else:
		# 重置全部参数为默认值
		var reset_btn := Button.new()
		reset_btn.text = "↺ 重置参数"
		reset_btn.flat = true
		reset_btn.add_theme_color_override("font_color", Color(0.9, 0.7, 0.4))
		reset_btn.pressed.connect(func():
			var defs: Array = reg_def.get("params", [])
			for p_def in defs:
				node["properties"][p_def["key"]] = p_def.get("default", null)
			_host._mark_dirty()
			_save_active_graph()
			_host._sync_to_code_editor()
			_show_bp_node_properties(node_id)
			_bp_redraw_canvas())
		detail.add_child(reset_btn)
		# 复制参数 JSON
		var json_copy_btn := Button.new()
		json_copy_btn.text = "⧉ 参数JSON"
		json_copy_btn.flat = true
		json_copy_btn.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
		json_copy_btn.tooltip_text = "复制全部参数为 JSON"
		json_copy_btn.pressed.connect(func():
			DisplayServer.clipboard_set(JSON.stringify(node.get("properties", {})))
			_host._log_output("[已复制] 节点参数 JSON"))
		detail.add_child(json_copy_btn)
		# 删除节点按钮
		var del_btn := Button.new()
		del_btn.text = "🗑 删除节点"
		del_btn.flat = true
		del_btn.add_theme_color_override("font_color", Color(0.9, 0.4, 0.35))
		del_btn.pressed.connect(func():
			var canvas: Control = _host._editor_container().find_child("EventGraphCanvas", true, false)
			_bp_selected_ids = [node_id]
			if canvas:
				_bp_delete_selected(graph, canvas)
			_hide_bp_node_properties())
		detail.add_child(del_btn)
		# 详尽模式：参数 JSON 只读预览（调试视图）
		if EditorMode.is_exhaustive():
			var json_view := RichTextLabel.new()
			json_view.bbcode_enabled = true
			json_view.fit_content = true
			json_view.add_theme_font_size_override("normal_font_size", 10)
			json_view.text = "[color=#7f8a96]// 参数原始数据（只读）\n%s[/color]" % JSON.stringify(node.get("properties", {}))
			detail.add_child(json_view)
		var props: Dictionary = node.get("properties", {})
		for param in params:
			var key: String = param["key"]
			var label: String = param.get("label", key)
			# 详尽模式：label 附加原始 key（调试定位用）
			if EditorMode.is_exhaustive():
				label = "%s (%s)" % [label, key]
			var p_type: String = param.get("type", "string")
			var current_val = props.get(key, param.get("default", null))
			match p_type:
				"enum":
					_bp_prop_add_enum(detail, label, param.get("options", []), str(current_val), func(v):
						node["properties"][key] = v
						_save_active_graph()
						_host._sync_to_code_editor()
						_bp_redraw_canvas()
					)
				"ref":
					_bp_prop_add_ref(detail, label, param, str(current_val), func(v):
						node["properties"][key] = v
						_save_active_graph()
						_host._sync_to_code_editor()
						_bp_redraw_canvas()
					)
				"int":
					_bp_prop_add_spin(detail, label, int(current_val) if current_val != null else 0, param.get("min", -99999), param.get("max", 99999), func(v):
						node["properties"][key] = v
						_save_active_graph()
						_host._sync_to_code_editor()
					)
				"float":
					_bp_prop_add_spin(detail, label, float(current_val) if current_val != null else 0.0, param.get("min", -99999.0), param.get("max", 99999.0), func(v):
						node["properties"][key] = v
						_save_active_graph()
						_host._sync_to_code_editor()
					)
				"bool":
					_bp_prop_add_check(detail, label, bool(current_val) if current_val != null else false, func(v):
						node["properties"][key] = v
						_save_active_graph()
						_host._sync_to_code_editor()
					)
				_:
					_bp_prop_add_text(detail, label, str(current_val) if current_val != null else "", func(v):
						node["properties"][key] = v
						_save_active_graph()
						_host._sync_to_code_editor()
						_bp_redraw_canvas()
					, str(param.get("description", "")))

## 隐藏属性面板(恢复概览)
func _hide_bp_node_properties() -> void:
	var detail: Control = _host._editor_container().find_child("EventDetail", true, false)
	if detail == null:
		return
	for child in detail.get_children():
		child.queue_free()
	if _host._bp_view == "event_list":
		_host._build_event_overview(detail)
	elif _host._bp_view == "workspace":
		_host._workspace_show_overview(detail)
	else:
		_host._ui().add_info_label(detail, "点击节点查看属性")

## 重绘画布快捷方法（画布不可见时跳过, 避免隐藏状态下的无效重绘）
func _bp_redraw_canvas() -> void:
	var canvas: Control = _host._editor_container().find_child("EventGraphCanvas", true, false)
	if canvas == null:
		return
	# L1 表单层激活时 L3 容器隐藏, 跳过重绘省开销
	if not canvas.is_visible_in_tree():
		return
	canvas.queue_redraw()

## 旧基础节点属性编辑
func _build_basic_node_props(detail: Control, node: Dictionary) -> void:
	# 标题可编辑（对齐注册表节点）
	_host._ui().add_text_field(detail, "节点标题", node.get("title", ""), func(v):
		var t2 := str(v).strip_edges()
		if t2.is_empty():
			t2 = BlueprintData.get_node_type_label(node.get("node_type", ""))
		node["title"] = t2
		_host._mark_dirty()
		_save_active_graph()
		_host._sync_to_code_editor()
		_bp_redraw_canvas())
	_host._ui().add_info_label(detail, "ID: %s" % node["id"])
	var props: Dictionary = node.get("properties", {})
	match node["node_type"]:
		"get_var", "set_var":
			_bp_prop_add_text(detail, "变量名", str(props.get("var_name", "")), func(v):
				node["properties"]["var_name"] = v
				_save_active_graph()
				_host._sync_to_code_editor()
				_bp_redraw_canvas()
			)
		"expression":
			_host._ui().add_section_label(detail, "表达式代码", 2)
			_bp_prop_add_text(detail, "代码", str(props.get("code", "")), func(v):
				node["properties"]["code"] = v
				_save_active_graph()
				_host._sync_to_code_editor()
			)
		"story_event", "random_event":
			_bp_prop_add_text(detail, "事件名", str(props.get("event_name", "")), func(v):
				node["properties"]["event_name"] = v
				_save_active_graph()
				_host._sync_to_code_editor()
				_bp_redraw_canvas()
			)
		_:
			_host._ui().add_info_label(detail, "此节点无额外属性")

## --- 属性面板控件辅助函数 ---

## 添加枚举下拉框
func _bp_prop_add_enum(parent: Control, label: String, options: Array, current: String, on_change: Callable) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	parent.add_child(hbox)
	var lbl := Label.new()
	lbl.text = label + ":"
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", EditorUIFactory.C_LABEL)
	lbl.custom_minimum_size.x = 80
	hbox.add_child(lbl)
	var opt := OptionButton.new()
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.add_theme_font_size_override("font_size", 12)
	var selected_idx := 0
	for i in options.size():
		var item_text: String = str(options[i]) if not options[i] is Dictionary else options[i].get("label", str(options[i]))
		opt.add_item(item_text)
		var item_id: String = str(options[i]) if not options[i] is Dictionary else str(options[i].get("id", options[i]))
		if item_id == current or item_text == current:
			selected_idx = i
	opt.selected = selected_idx
	opt.item_selected.connect(func(idx: int):
		var val = options[idx] if not options[idx] is Dictionary else options[idx].get("id", str(options[idx]))
		on_change.call(str(val))
	)
	hbox.add_child(opt)

## 添加引用下拉框(从数据池动态获取)
func _bp_prop_add_ref(parent: Control, label: String, param_def: Dictionary, current: String, on_change: Callable) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	parent.add_child(hbox)
	var lbl := Label.new()
	lbl.text = label + ":"
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", EditorUIFactory.C_LABEL)
	lbl.custom_minimum_size.x = 80
	hbox.add_child(lbl)
	var opt := OptionButton.new()
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.add_theme_font_size_override("font_size", 12)
	var options: Array = BlueprintNodeRegistry.get_param_options(param_def, _host._current_script())
	opt.add_item("(未选择)")
	var selected_idx := 0
	for i in options.size():
		var item: Dictionary = options[i]
		opt.add_item(item.get("label", item.get("id", "")))
		if str(item.get("id", "")) == current:
			selected_idx = i + 1
	opt.selected = selected_idx
	opt.item_selected.connect(func(idx: int):
		if idx == 0:
			on_change.call("")
		else:
			on_change.call(str(options[idx - 1].get("id", "")))
	)
	hbox.add_child(opt)

## 添加数值输入框
func _bp_prop_add_spin(parent: Control, label: String, current: float, min_val: float, max_val: float, on_change: Callable) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	parent.add_child(hbox)
	var lbl := Label.new()
	lbl.text = label + ":"
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", EditorUIFactory.C_LABEL)
	lbl.custom_minimum_size.x = 80
	hbox.add_child(lbl)
	var spin := SpinBox.new()
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.min_value = min_val
	spin.max_value = max_val
	spin.value = current
	spin.step = 1.0 if min_val == int(min_val) and max_val == int(max_val) else 0.1
	spin.add_theme_font_size_override("font_size", 12)
	spin.value_changed.connect(func(v: float):
		on_change.call(v)
	)
	hbox.add_child(spin)

## 添加复选框
func _bp_prop_add_check(parent: Control, label: String, current: bool, on_change: Callable) -> void:
	var check := CheckButton.new()
	check.text = label
	check.button_pressed = current
	check.add_theme_font_size_override("font_size", 12)
	check.toggled.connect(func(v: bool):
		on_change.call(v)
	)
	parent.add_child(check)

## 添加文本输入框
func _bp_prop_add_text(parent: Control, label: String, current: String, on_change: Callable, hint: String = "") -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	parent.add_child(vbox)
	var lbl := Label.new()
	lbl.text = label + ":"
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", EditorUIFactory.C_LABEL)
	if not hint.is_empty():
		lbl.tooltip_text = hint
	vbox.add_child(lbl)
	var edit := LineEdit.new()
	edit.text = current
	edit.add_theme_font_size_override("font_size", 12)
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 详尽模式：文本参数实时校验提示（空值/表达式括号）
	if EditorUIFactory != null and EditorMode.is_exhaustive():
		edit.text_changed.connect(func(t: String):
			var warn := ""
			if t.strip_edges().is_empty():
				warn = "空值"
			elif t.count("(") != t.count(")"):
				warn = "括号不匹配"
			elif t.count("{") != t.count("}"):
				warn = "花括号不匹配"
			if warn != "":
				edit.add_theme_color_override("font_color", Color(1.0, 0.4, 0.35))
				edit.tooltip_text = "⚠ %s" % warn
			else:
				edit.add_theme_color_override("font_color", Color(0.85, 0.87, 0.9))
				edit.tooltip_text = hint)
	edit.text_submitted.connect(func(v: String):
		on_change.call(v)
	)
	edit.focus_exited.connect(func():
		on_change.call(edit.text)
	)
	vbox.add_child(edit)
	# 复制值到剪贴板
	var copy_btn := Button.new()
	copy_btn.text = "⧉"
	copy_btn.flat = true
	copy_btn.custom_minimum_size = Vector2(24, 20)
	copy_btn.tooltip_text = "复制参数值"
	copy_btn.pressed.connect(func():
		DisplayServer.clipboard_set(edit.text)
		_host._log_output("[已复制] %s = %s" % [label, edit.text]))
	vbox.add_child(copy_btn)
	# 粘贴剪贴板值
	var paste_btn := Button.new()
	paste_btn.text = "📋"
	paste_btn.flat = true
	paste_btn.custom_minimum_size = Vector2(24, 20)
	paste_btn.tooltip_text = "粘贴到参数"
	paste_btn.pressed.connect(func():
		var cb: String = DisplayServer.clipboard_get()
		if not cb.is_empty():
			edit.text = cb
			on_change.call(cb)
			_host._log_output("[已粘贴] %s = %s" % [label, cb]))
	vbox.add_child(paste_btn)
