## 可视化编辑器 - 地图编辑器模块
## 注意: 地图编辑器使用蓝图画布系统，不适用标准导航布局
extends "res://scripts/editor/visual/visual_module_base.gd"

func create(_sub_type: String = "", _meta: Dictionary = {}) -> Control:
	var root := PanelContainer.new()
	root.add_theme_stylebox_override("panel", _ui().make_bg_style())
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 0)
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(main_vbox)
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
	main_vbox.add_child(toolbar_panel)
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 6)
	toolbar_panel.add_child(toolbar)
	_ui().add_toolbar_btn(toolbar, "+ 新区域", func(): _add_map_region(main_vbox))
	_ui().add_toolbar_btn(toolbar, "🔄 自动布局", func(): _auto_layout_map(main_vbox))
	_ui().add_toolbar_btn(toolbar, "🔍 适应画布", func(): _host._mod_event._fit_canvas_to_nodes(main_vbox))
	# 主区域
	var hsplit := HSplitContainer.new()
	hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hsplit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hsplit.add_theme_constant_override("separation", 4)
	main_vbox.add_child(hsplit)
	# 地图画布
	var map_panel := PanelContainer.new()
	map_panel.custom_minimum_size.x = 400
	map_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_panel.size_flags_stretch_ratio = 2.0
	var map_sb := StyleBoxFlat.new()
	map_sb.bg_color = Color(0.1, 0.11, 0.14, 1)
	map_sb.border_width_left = 1
	map_sb.border_width_top = 1
	map_sb.border_width_right = 1
	map_sb.border_width_bottom = 1
	map_sb.border_color = Color(0.2, 0.25, 0.35, 0.3)
	map_sb.content_margin_left = 4.0
	map_sb.content_margin_top = 4.0
	map_sb.content_margin_right = 4.0
	map_sb.content_margin_bottom = 4.0
	map_panel.add_theme_stylebox_override("panel", map_sb)
	hsplit.add_child(map_panel)
	var map_canvas := Control.new()
	map_canvas.name = "MapCanvas"
	map_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_panel.add_child(map_canvas)
	map_canvas.draw.connect(_draw_map.bind(map_canvas))
	map_canvas.gui_input.connect(_on_map_canvas_input.bind(map_canvas))
	# 右侧详情
	var detail_scroll := ScrollContainer.new()
	detail_scroll.custom_minimum_size.x = 280
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.size_flags_stretch_ratio = 1.0
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var detail := VBoxContainer.new()
	detail.name = "MapDetail"
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 6)
	detail_scroll.add_child(detail)
	hsplit.add_child(detail_scroll)
	# 初始显示概览
	_build_map_overview(detail)
	map_canvas.call_deferred("queue_redraw")
	return root

## 同步地图节点数据
func _sync_map_nodes() -> void:
	if _ws() == null:
		return
	var wv := _ws().worldview
	var regions: Array = wv.geography.get("regions", [])
	var bp_node_size: Vector2 = _host._mod_event.BP_NODE_SIZE
	var spacing_x := bp_node_size.x + 50
	var spacing_y := bp_node_size.y + 50
	var col := 0
	var row := 0
	for i in regions.size():
		var r: Dictionary = regions[i]
		var rid: String = r.get("id", "region_%d" % i)
		if not _host._mod_event._map_nodes.has(rid):
			var climate: String = r.get("climate", "unknown")
			_host._mod_event._map_nodes[rid] = {
				"pos": Vector2(40 + col * spacing_x, 40 + row * spacing_y),
				"title": r.get("name", rid),
				"body": ["气候: " + climate]
			}
			col += 1
			if col > 2:
				col = 0
				row += 1
	# 清理已删除的节点
	var valid_ids := {}
	for r in regions:
		valid_ids[r.get("id", "")] = true
	var to_remove := []
	for rid in _host._mod_event._map_nodes:
		if not valid_ids.has(rid):
			to_remove.append(rid)
	for rid in to_remove:
		_host._mod_event._map_nodes.erase(rid)

func _draw_map(canvas: Control) -> void:
	if _ws() == null:
		return
	var canvas_size := canvas.size
	if canvas_size.x < 10 or canvas_size.y < 10:
		return
	# 同步数据
	_sync_map_nodes()
	var bp_node_size: Vector2 = _host._mod_event.BP_NODE_SIZE
	# 1. 绘制网格背景
	_host._mod_event._draw_bp_grid(canvas)
	# 2. 绘制连线(区域关联)
	var wv := _ws().worldview
	var regions: Array = wv.geography.get("regions", [])
	var region_color := Color(0.25, 0.55, 0.35, 1)
	for r in regions:
		var rid: String = r.get("id", "")
		var connections: Array = r.get("connections", [])
		for conn_id in connections:
			if _host._mod_event._map_nodes.has(rid) and _host._mod_event._map_nodes.has(conn_id):
				var from_pos: Vector2 = _host._mod_event._map_pin_world_pos(_host._mod_event._map_nodes[rid]["pos"], bp_node_size, true, 0)
				var to_pos: Vector2 = _host._mod_event._map_pin_world_pos(_host._mod_event._map_nodes[conn_id]["pos"], bp_node_size, false, 0)
				var from_screen: Vector2 = _host._mod_event._bp_world_to_screen(from_pos)
				var to_screen: Vector2 = _host._mod_event._bp_world_to_screen(to_pos)
				_host._mod_event._draw_bp_connection(canvas, from_screen, to_screen, Color(0.5, 0.8, 0.5, 0.6), 2.0)
	# 3. 绘制节点
	for rid in _host._mod_event._map_nodes:
		var node: Dictionary = _host._mod_event._map_nodes[rid]
		var is_selected: bool = _host._mod_event._bp_mod._bp_selected_ids.has(rid)
		# 更新body内容
		var body: Array = []
		for r in regions:
			if r.get("id", "") == rid:
				body = ["气候: " + r.get("climate", "unknown")]
				break
		_host._mod_event._draw_bp_node(canvas, node["pos"], bp_node_size, node["title"], region_color, body, is_selected, ["入口"], ["出口"])
	# 4. 绘制临时连线
	if _host._mod_event._bp_mod._bp_pin_dragging:
		var from_node: Dictionary = _host._mod_event._map_nodes.get(_host._mod_event._bp_mod._bp_pin_drag_from_id, {})
		if not from_node.is_empty():
			var from_pin: Vector2 = _host._mod_event._map_pin_world_pos(from_node["pos"], bp_node_size, _host._mod_event._bp_mod._bp_pin_drag_is_output, _host._mod_event._bp_mod._bp_pin_drag_from_port)
			var from_screen: Vector2 = _host._mod_event._bp_world_to_screen(from_pin)
			_host._mod_event._draw_bp_connection(canvas, from_screen, _host._mod_event._bp_mod._bp_temp_connection_end, Color(0.5, 0.8, 0.5, 0.5), 1.5)
	# 5. 绘制框选矩形
	if _host._mod_event._bp_mod._bp_box_selecting:
		var box_screen_start: Vector2 = _host._mod_event._bp_world_to_screen(_host._mod_event._bp_mod._bp_box_start)
		var box_screen_end: Vector2 = _host._mod_event._bp_world_to_screen(_host._mod_event._bp_mod._bp_box_end)
		var box_rect := Rect2(box_screen_start, box_screen_end - box_screen_start).abs()
		canvas.draw_rect(box_rect, Color(0.3, 0.6, 1.0, 0.15))
		canvas.draw_rect(box_rect, Color(0.3, 0.6, 1.0, 0.6), false, 1.0)
	# 6. 绘制缩放信息
	var font := ThemeDB.fallback_font
	canvas.draw_string(font, Vector2(8, canvas_size.y - 8), "缩放: %.0f%%" % (_host._mod_event._bp_mod._bp_zoom * 100), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.5, 0.5, 0.6, 0.6))

## 地图编辑器输入包装
func _on_map_canvas_input(event: InputEvent, canvas: Control) -> void:
	var on_click := func(rid: String):
		var detail: VBoxContainer = canvas.get_parent().get_parent().find_child("MapDetail", true, false)
		if detail:
			_build_map_region_detail(detail, rid)
	var on_dbl_click := func(rid: String):
		var detail: VBoxContainer = canvas.get_parent().get_parent().find_child("MapDetail", true, false)
		if detail:
			_build_map_region_detail(detail, rid)
	var on_connect := func(from_id: String, to_id: String):
		_create_map_connection(from_id, to_id)
	var on_delete := func(rid: String):
		_delete_map_region(rid)
	_host._mod_event._on_bp_canvas_input(event, canvas, _host._mod_event._map_nodes, on_click, on_dbl_click, on_connect, on_delete)

## 创建地图连接
func _create_map_connection(from_id: String, to_id: String) -> void:
	if _ws() == null:
		return
	var wv := _ws().worldview
	var regions: Array = wv.geography.get("regions", [])
	for r in regions:
		if r.get("id", "") == from_id:
			var connections: Array = r.get("connections", [])
			if not connections.has(to_id):
				connections.append(to_id)
				break
	_sync()

## 删除地图区域
func _delete_map_region(rid: String) -> void:
	if _ws() == null:
		return
	var wv := _ws().worldview
	var regions: Array = wv.geography.get("regions", [])
	for i in range(regions.size() - 1, -1, -1):
		if regions[i].get("id", "") == rid:
			regions.remove_at(i)
			break
	# 同时删除其他区域对该区域的连接引用
	for r in regions:
		var connections: Array = r.get("connections", [])
		var idx := connections.find(rid)
		if idx >= 0:
			connections.remove_at(idx)
	_rebuild_tree()

func _build_map_overview(detail: VBoxContainer) -> void:
	for child in detail.get_children():
		child.queue_free()
	var wv := _ws().worldview
	var regions: Array = wv.geography.get("regions", [])
	_ui().add_section_label(detail, "🗺 地图概览")
	_ui().add_stat_card(detail, [
		["区域", "%d 个" % regions.size()],
	])
	_ui().add_hseparator(detail)
	_ui().add_info_label(detail, "点击左侧地图中的区域查看详情")

func _build_map_region_detail(detail: VBoxContainer, region_id: String) -> void:
	for child in detail.get_children():
		child.queue_free()
	var wv := _ws().worldview
	var regions: Array = wv.geography.get("regions", [])
	var region: Dictionary = {}
	for r in regions:
		if r.get("id", "") == region_id:
			region = r
			break
	if region.is_empty():
		_ui().add_section_label(detail, "区域未找到")
		return
	_ui().add_section_label(detail, "📍 %s" % region.get("name", region_id))
	_ui().add_text_field(detail, "名称", region.get("name", ""), func(v): region["name"] = v; _sync())
	_ui().add_multiline_field(detail, region.get("description", ""), func(v): region["description"] = v; _sync())
	_ui().add_text_field(detail, "气候", region.get("climate", "temperate"), func(v): region["climate"] = v; _sync())

func _add_map_region(main_vbox: VBoxContainer) -> void:
	var wv := _ws().worldview
	if not wv.geography.has("regions"):
		wv.geography["regions"] = []
	var regions: Array = wv.geography["regions"]
	regions.append({"id": "region_%d" % regions.size(), "name": "新区域", "description": "", "climate": "temperate", "resources": [], "connections": []})
	_rebuild_tree()
	var canvas: Control = main_vbox.find_child("MapCanvas", true, false)
	if canvas:
		canvas.queue_redraw()

func _auto_layout_map(main_vbox: VBoxContainer) -> void:
	# 清空节点位置，让重新同步时自动布局
	_host._mod_event._map_nodes.clear()
	_host._mod_event._bp_mod._bp_offset = Vector2.ZERO
	_host._mod_event._bp_mod._bp_zoom = 1.0
	var canvas: Control = main_vbox.find_child("MapCanvas", true, false)
	if canvas:
		canvas.queue_redraw()
