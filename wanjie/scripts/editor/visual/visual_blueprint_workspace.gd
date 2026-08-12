## VisualBlueprintWorkspace - 统一蓝图编辑器（UE 风格）
## 所有游戏系统（事件/经济/能力/战斗/世界/玩家/任务）共用一个蓝图工作区:
##   - 左侧/顶部图列表: 管理全部蓝图图（evt:事件图 / sys:系统图）
##   - 中央画布: 节点拖拽/连线/缩放/右键添加（复用 VisualEventBlueprint 成熟交互）
##   - 右侧详情: 节点属性编辑 / 图概览
## 通过 VisualEventBlueprint 的 workspace 模式复用全部画布交互逻辑。
extends "res://scripts/editor/visual/visual_module_base.gd"

## 蓝图交互模块（复用自 visual_event_blueprint.gd）
var _bp_mod = null
## 当前编辑模式（workspace 模式, 供 _bp_mod 分支判断）
var _bp_view: String = "workspace"
## 当前编辑的图 key（如 sys:global / evt:evt_1）
var _current_key: String = ""
## UI 引用
var _graph_list: OptionButton = null
var _canvas: Control = null
var _detail: VBoxContainer = null
## 模块根控件（find_child 用）
var _root_ui: Control = null
## 锁定图 key（非空时隐藏图管理 UI, 固定编辑该子系统蓝图图; 由 visual_system_blueprint 设置）
var _locked_key: String = ""

## 创建统一蓝图编辑器
func create(_sub_type: String = "", _meta: Dictionary = {}) -> Control:
	_bp_mod = load("res://scripts/editor/visual/visual_event_blueprint.gd").new(self)
	var root := PanelContainer.new()
	root.add_theme_stylebox_override("panel", _ui().make_bg_style())
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 0)
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(main_vbox)
	# === 顶部工具栏: 图管理 + 快捷节点 + 编译 ===
	var toolbar := PanelContainer.new()
	toolbar.custom_minimum_size.y = 38
	var tb_sb := StyleBoxFlat.new()
	tb_sb.bg_color = Color(0.12, 0.13, 0.16, 1)
	tb_sb.border_width_bottom = 1
	tb_sb.border_color = Color(0.2, 0.25, 0.35, 0.4)
	tb_sb.content_margin_left = 8.0
	tb_sb.content_margin_right = 8.0
	toolbar.add_theme_stylebox_override("panel", tb_sb)
	main_vbox.add_child(toolbar)
	var tb_hbox := HBoxContainer.new()
	tb_hbox.add_theme_constant_override("separation", 6)
	toolbar.add_child(tb_hbox)
	# 图管理区（锁定模式隐藏列表/新建/重命名/删除, 显示当前子系统图提示）
	if not _locked_key.is_empty():
		var lock_lbl := Label.new()
		lock_lbl.text = "🔷 %s" % _locked_key
		lock_lbl.add_theme_font_size_override("font_size", 12)
		lock_lbl.add_theme_color_override("font_color", Color(0.278431, 0.549020, 0.749020, 1))
		lock_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb_hbox.add_child(lock_lbl)
		_ui().add_toolbar_btn(tb_hbox, "|", func(): pass)
	else:
		_graph_list = OptionButton.new()
		_graph_list.custom_minimum_size.x = 220
		_graph_list.add_theme_font_size_override("font_size", 12)
		_graph_list.item_selected.connect(_on_graph_selected)
		tb_hbox.add_child(_graph_list)
		_ui().add_toolbar_btn(tb_hbox, "＋ 新建图", _on_new_graph_pressed)
		# 简易模式隐藏图重命名/删除（避免误操作）
		if EditorMode.is_visible(EditorMode.FIELD_ADVANCED):
			_ui().add_toolbar_btn(tb_hbox, "✎ 重命名", _on_rename_graph_pressed)
			_ui().add_toolbar_btn(tb_hbox, "🗑 删除", _on_delete_graph_pressed)
		_ui().add_toolbar_btn(tb_hbox, "|", func(): pass)
	# 快捷节点
	_ui().add_toolbar_btn(tb_hbox, "+Start", func(): _bp_mod._add_blueprint_node("start"))
	_ui().add_toolbar_btn(tb_hbox, "+Branch", func(): _bp_mod._add_blueprint_node("branch"))
	_ui().add_toolbar_btn(tb_hbox, "+Seq", func(): _bp_mod._add_blueprint_node("sequence"))
	_ui().add_toolbar_btn(tb_hbox, "+SetVar", func(): _bp_mod._add_blueprint_node("set_var"))
	_ui().add_toolbar_btn(tb_hbox, "+GetVar", func(): _bp_mod._add_blueprint_node("get_var"))
	# Print 调试节点仅详细/详尽模式显示
	if EditorMode.is_visible(EditorMode.FIELD_ADVANCED):
		_ui().add_toolbar_btn(tb_hbox, "+Print", func(): _bp_mod._add_blueprint_node("print"))
	_ui().add_toolbar_btn(tb_hbox, "|", func(): pass)
	_ui().add_toolbar_btn(tb_hbox, "编译", _compile_current)
	_ui().add_toolbar_btn(tb_hbox, "🔍 搜索", func(): _bp_mod._open_node_search())
	_ui().add_toolbar_btn(tb_hbox, "适应画布", func(): _bp_mod._fit_canvas_to_nodes(_canvas))
	# 自动布局为进阶操作（简易模式隐藏）
	if EditorMode.is_visible(EditorMode.FIELD_ADVANCED):
		_ui().add_toolbar_btn(tb_hbox, "自动布局", func(): _bp_mod._auto_layout_event_graph())
	# === 主区域: 左图说明 + 画布 + 右详情 ===
	var hsplit := HSplitContainer.new()
	hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hsplit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hsplit.add_theme_constant_override("separation", 4)
	main_vbox.add_child(hsplit)
	# 左列: 图 key 提示 + 图列表（可滚动）
	var left_panel := PanelContainer.new()
	left_panel.custom_minimum_size.x = 170
	var left_sb := StyleBoxFlat.new()
	left_sb.bg_color = Color(0.12, 0.13, 0.17, 1)
	left_sb.border_width_right = 1
	left_sb.border_color = Color(0.2, 0.25, 0.35, 0.3)
	left_panel.add_theme_stylebox_override("panel", left_sb)
	hsplit.add_child(left_panel)
	var left_vbox := VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 4)
	left_panel.add_child(left_vbox)
	_ui().add_section_label(left_vbox, "📚 蓝图图", 1)
	var hint := Label.new()
	hint.text = "evt:xxx = 事件图\nsys:xxx = 系统图\n（含全局/经济/战斗等）"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75, 1))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left_vbox.add_child(hint)
	var list_scroll := ScrollContainer.new()
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_vbox.add_child(list_scroll)
	var list_box := VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.add_child(list_box)
	# 锁定模式无图列表（左列显示子系统说明）
	if _locked_key.is_empty():
		_graph_list.item_selected.connect(func(_i: int):
			var key := _graph_list.get_item_text(_i)
			if key != _current_key:
				_current_key = key
				_on_graph_switched()
		)
	# 中央画布
	var canvas_panel := PanelContainer.new()
	canvas_panel.custom_minimum_size.x = 420
	canvas_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas_panel.size_flags_stretch_ratio = 2.0
	var canvas_sb := StyleBoxFlat.new()
	canvas_sb.bg_color = Color(0.1, 0.11, 0.14, 1)
	canvas_sb.border_width_left = 1
	canvas_sb.border_width_right = 1
	canvas_sb.border_color = Color(0.2, 0.25, 0.35, 0.3)
	canvas_sb.content_margin_left = 4.0
	canvas_sb.content_margin_top = 4.0
	canvas_sb.content_margin_right = 4.0
	canvas_sb.content_margin_bottom = 4.0
	canvas_panel.add_theme_stylebox_override("panel", canvas_sb)
	hsplit.add_child(canvas_panel)
	_canvas = Control.new()
	_canvas.name = "EventGraphCanvas"
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.clip_contents = false
	canvas_panel.add_child(_canvas)
	_canvas.draw.connect(func(): _bp_mod._draw_blueprint_graph(_canvas, _bp_mod._get_active_graph()))
	_canvas.gui_input.connect(func(event: InputEvent): _bp_mod._on_blueprint_canvas_input(event, _canvas))
	_bp_mod._create_minimap(_canvas)
	# 右侧详情
	var detail_scroll := ScrollContainer.new()
	detail_scroll.custom_minimum_size.x = 280
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.size_flags_stretch_ratio = 1.0
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hsplit.add_child(detail_scroll)
	_detail = VBoxContainer.new()
	_detail.name = "EventDetail"
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 6)
	detail_scroll.add_child(_detail)
	# === 初始化图列表与默认图 ===
	_refresh_graph_list()
	_root_ui = root
	return root

## === workspace 宿主接口（供 VisualEventBlueprint duck-typing） ===

## 编辑器容器（画布/详情按名称查找）
func _editor_container() -> Node:
	return _root_ui

## 当前剧本
func _current_script() -> WorldScriptData:
	return _ws()

## 当前图（按 key 从 GraphStore 取, 无则创建空图）
func _workspace_get_graph() -> Dictionary:
	var ws := _ws()
	if ws == null or _current_key == "":
		# 无剧本/无图时返回空图结构（避免调用方对空字典写入崩溃）
		return BlueprintData.make_graph()
	var graph: Dictionary = GraphStore.get_graph(ws, _current_key)
	if graph.is_empty():
		graph = BlueprintData.make_graph()
		GraphStore.set_graph(ws, _current_key, graph)
	elif _bp_mod != null:
		# 加载持久化图: 结构修复（缺键补默认, 防旧/损坏数据崩溃）
		_bp_mod._repair_graph_structure(graph)
	return graph

## 保存当前图到 GraphStore
func _workspace_save_graph() -> void:
	var ws := _ws()
	if ws == null or _current_key == "":
		return
	GraphStore.set_graph(ws, _current_key, _workspace_get_graph())

## 详情面板概览（未选中节点时）
func _workspace_show_overview(detail: Control) -> void:
	_ui().add_section_label(detail, "📚 蓝图工作区", 1)
	_ui().add_info_label(detail, "当前图: %s" % _current_key)
	var graph := _workspace_get_graph()
	_ui().add_info_label(detail, "节点: %d  连线: %d" % [graph.get("nodes", {}).size(), graph.get("connections", []).size()])
	_ui().add_info_label(detail, "右键画布可添加节点, 拖拽引脚连线, 拖拽节点移动, 滚轮缩放。")
	if graph.has("_compiled_code"):
		_ui().add_section_label(detail, "已编译代码", 2)
		var code_label := Label.new()
		code_label.text = graph["_compiled_code"]
		code_label.add_theme_font_size_override("font_size", 10)
		code_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6, 1))
		code_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.add_child(code_label)

## 日志代理
func _log_output(msg: String) -> void:
	_host._log_output(msg)

## 脏标记代理（VisualEventBlueprint 直接调用）
func _mark_dirty() -> void:
	_host._mark_dirty()

## 代码编辑器同步代理
func _sync_to_code_editor() -> void:
	_host._sync_to_code_editor()

## === 图列表管理 ===

func _refresh_graph_list() -> void:
	var ws := _ws()
	# 锁定模式: 固定编辑子系统图（不存在则自动创建含 start 的默认图）
	if not _locked_key.is_empty():
		_current_key = _locked_key
		if ws != null and not GraphStore.has_graph(ws, _locked_key):
			GraphStore.set_graph(ws, _locked_key, _new_default_graph())
		_on_graph_switched()
		return
	if _graph_list == null:
		_on_graph_switched()
		return
	_graph_list.clear()
	var keys: Array[String] = []
	if ws != null:
		keys = GraphStore.list_graphs(ws)
	if keys.is_empty():
		# 无图时创建默认全局图
		_current_key = "sys:global"
		GraphStore.set_graph(ws, _current_key, _new_default_graph())
		keys = GraphStore.list_graphs(ws)
	var idx := 0
	var select_idx := 0
	for key in keys:
		_graph_list.add_item(key)
		if key == _current_key:
			select_idx = idx
		idx += 1
	if not keys.has(_current_key):
		_current_key = keys[0]
	_graph_list.select(select_idx)
	_on_graph_switched()

func _new_default_graph() -> Dictionary:
	var graph := BlueprintData.make_graph()
	var start_node: Dictionary = BlueprintData.create_node("start", Vector2(100, 200))
	graph["nodes"][start_node["id"]] = start_node
	return graph

func _on_graph_selected(index: int) -> void:
	var key := _graph_list.get_item_text(index)
	if key != _current_key:
		_current_key = key
		_on_graph_switched()

func _on_graph_switched() -> void:
	if _canvas:
		_canvas.queue_redraw()
	_refresh_detail_overview()

func _refresh_detail_overview() -> void:
	if _detail == null:
		return
	for child in _detail.get_children():
		child.queue_free()
	_workspace_show_overview(_detail)

func _on_new_graph_pressed() -> void:
	var ws := _ws()
	if ws == null:
		return
	_show_text_dialog("新建蓝图图", "输入图名称（如 global / economy / combat）:", func(name: String):
		var key := name.strip_edges()
		if key.is_empty():
			return
		if not key.begins_with("sys:") and not key.begins_with("evt:"):
			key = "sys:" + key
		if GraphStore.has_graph(ws, key):
			_log_output("[蓝图] 图已存在: %s" % key)
			return
		GraphStore.set_graph(ws, key, _new_default_graph())
		_current_key = key
		_refresh_graph_list()
		_log_output("[蓝图] 新建图: %s" % key)
	)

func _on_rename_graph_pressed() -> void:
	var ws := _ws()
	if ws == null or _current_key == "":
		return
	_show_text_dialog("重命名图", "当前: %s\n输入新名称:" % _current_key, func(name: String):
		var new_key := name.strip_edges()
		if new_key.is_empty() or new_key == _current_key:
			return
		if not new_key.begins_with("sys:") and not new_key.begins_with("evt:"):
			new_key = "sys:" + new_key
		if GraphStore.has_graph(ws, new_key):
			_log_output("[蓝图] 图已存在: %s" % new_key)
			return
		var graph: Dictionary = _workspace_get_graph()
		GraphStore.remove_graph(ws, _current_key)
		GraphStore.set_graph(ws, new_key, graph)
		_current_key = new_key
		_refresh_graph_list()
		_log_output("[蓝图] 重命名 -> %s" % new_key)
	)

func _on_delete_graph_pressed() -> void:
	var ws := _ws()
	if ws == null or _current_key == "":
		return
	GraphStore.remove_graph(ws, _current_key)
	_log_output("[蓝图] 删除图: %s" % _current_key)
	_current_key = ""
	_refresh_graph_list()

func _compile_current() -> void:
	_bp_mod._compile_blueprint()
	_refresh_detail_overview()

## 简易文本输入对话框
func _show_text_dialog(title: String, prompt: String, on_confirm: Callable) -> void:
	var overlay := PanelContainer.new()
	overlay.name = "TextInputOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.4)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(380, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.17, 0.22, 1)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(16)
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 12
	panel.add_theme_stylebox_override("panel", sb)
	overlay.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title_label)
	var prompt_label := Label.new()
	prompt_label.text = prompt
	prompt_label.add_theme_font_size_override("font_size", 12)
	prompt_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85, 1))
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(prompt_label)
	var line_edit := LineEdit.new()
	line_edit.custom_minimum_size.y = 30
	vbox.add_child(line_edit)
	var btn_hbox := HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_END
	btn_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_hbox)
	var cancel_btn := Button.new()
	cancel_btn.text = "取消"
	btn_hbox.add_child(cancel_btn)
	var ok_btn := Button.new()
	ok_btn.text = "确定"
	ok_btn.add_theme_color_override("font_color", _ui().C_ACCENT)
	btn_hbox.add_child(ok_btn)
	# 容器引用（匿名函数内自引用）
	var container: PanelContainer = panel
	var close := func():
		if overlay.get_parent():
			overlay.queue_free()
	cancel_btn.pressed.connect(close)
	ok_btn.pressed.connect(func():
		on_confirm.call(line_edit.text)
		close.call()
	)
	line_edit.text_submitted.connect(func(_t: String):
		on_confirm.call(line_edit.text)
		close.call()
	)
	# 挂到编辑器容器（必须有宿主容器, 否则跳过）
	if _host and _host.has_method("_editor_container"):
		_host._editor_container().add_child(overlay)
	else:
		_log_output("[蓝图] 无法挂载输入对话框（无编辑器容器）")
		overlay.queue_free()
		return
	line_edit.grab_focus.call_deferred()
