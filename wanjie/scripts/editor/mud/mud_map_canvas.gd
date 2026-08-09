## MUD编辑器 - 地图画布（对应 ME libs/exui/rpg/map/init.lua 的网格+节点+路径绘制）
## 自定义 Control：网格 + 场景节点 + linkpath 8方向箭头 + 选中/悬停/右键/拖动。
## 纯视图+输入组件：所有数据变更通过信号交给宿主（mud_editor）处理。
## 坐标系：scene.x / scene.y 为 1 基准网格坐标（与 ME 一致），内部格子 0 基准。
class_name MudMapCanvas
extends Control

# ===================== 信号 =====================
## 左键单击选中场景节点
signal scene_selected(scene_id: int)
## 双击场景节点（打开互动编辑）
signal scene_activated(scene_id: int)
## 左键点击空白格（1 基准坐标，用于新建地点）
signal empty_cell_clicked(grid_x: int, grid_y: int)
## 拖动节点到空白格（1 基准坐标）
signal scene_move_requested(scene_id: int, grid_x: int, grid_y: int)
## 拖动节点到另一节点上（交换位置，对应 ME exchange/nodeChange）
signal scene_swap_requested(id1: int, id2: int)
## 连接模式下点击了目标节点
signal link_target_chosen(start_id: int, target_id: int, direct: String, bidirectional: bool)
## 右键节点（请求弹出上下文菜单，global_pos 为屏幕坐标）
signal node_context_requested(scene_id: int, global_pos: Vector2)
## 右键空白格（1 基准坐标）
signal blank_context_requested(grid_x: int, grid_y: int, global_pos: Vector2)
## 提示消息（如连接模式提示）
signal hint_message(msg: String)

# ===================== 数据 =====================
var data: MudData = null
var current_map_id: int = 0

# ===================== 显示常量 =====================
const CELL_W: float = 116.0
const CELL_H: float = 66.0
const NODE_W: float = 88.0
const NODE_H: float = 30.0
const MARGIN: float = 24.0

# 暗色主题配色（对应 ME css/map.css 的语义色）
const C_BG := Color(0.10, 0.10, 0.125, 1)
const C_GRID_EMPTY := Color(0.30, 0.30, 0.34, 0.55)  # 空格虚线框 rgb(210,210,210)→暗色
const C_NODE_BG := Color(0.93, 0.93, 0.95, 1)        # 节点白底 (.item background:white)
const C_NODE_BORDER := Color(0.72, 0.72, 0.76, 1)    # silver 边框
const C_NODE_TEXT := Color(0.10, 0.10, 0.13, 1)
const C_SELECTED := Color(1.0, 0.84, 0.0, 1)         # gold (:current 选中)
const C_HOVER := Color(1.0, 0.84, 0.0, 0.75)         # gold 边框 (:hover)
const C_LINKPOT_BG := Color(0.62, 0.91, 0.26, 1)     # greenyellow (linkpot 连接起点)
const C_LINKPOT_BD := Color(0.62, 0.25, 0.82, 1)     # purple 点线边框
const C_PATH := Color(1.0, 0.28, 0.28, 1)            # 红色路径箭头 rgb(255,0,0)
const C_DRAG_GHOST := Color(1.0, 1.0, 1.0, 0.55)     # 拖动幽灵节点

# ===================== 交互状态 =====================
var _selected_id: int = 0
var _hover_id: int = 0
# 连接模式（对应 ME linkpot / t_map_link_tips "按 ESC 取消连接状态"）
var _link_mode: bool = false
var _link_start_id: int = 0
var _link_direct: String = "east"
var _link_bidir: bool = true
# 拖动
var _drag_id: int = 0
var _drag_moved: bool = false
var _drag_pos: Vector2 = Vector2.ZERO
var _press_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL

# ===================== 公共接口 =====================

func set_data(p_data: MudData, map_id: int) -> void:
	data = p_data
	current_map_id = map_id
	if _selected_id != 0 and data != null:
		if data.get_row_by_id("scene", _selected_id).is_empty():
			_selected_id = 0
	update_minimum_size()
	queue_redraw()

func set_map(map_id: int) -> void:
	current_map_id = map_id
	_selected_id = 0
	cancel_link_mode(false)
	update_minimum_size()
	queue_redraw()

func get_selected_id() -> int:
	return _selected_id

func set_selected(id: int) -> void:
	_selected_id = id
	queue_redraw()

## 进入连接模式：选中起点后指定方向与双向性，再点击目标节点完成连接
func enter_link_mode(start_id: int, direct: String, bidirectional: bool) -> void:
	_link_mode = true
	_link_start_id = start_id
	_link_direct = direct
	_link_bidir = bidirectional
	if is_inside_tree() and is_visible_in_tree():
		grab_focus()
	hint_message.emit("连接模式：点击目标场景建立 [%s] 路径（%s），按 ESC 取消" % [
		MudSchemaInternal.DIRECTION_NAMES.get(direct, direct),
		"双向" if bidirectional else "单向"])
	queue_redraw()

func cancel_link_mode(notify: bool = true) -> void:
	if not _link_mode:
		return
	_link_mode = false
	_link_start_id = 0
	if notify:
		hint_message.emit("已取消连接")
	queue_redraw()

func is_link_mode() -> bool:
	return _link_mode

## ESC 取消连接（供宿主 _unhandled_input 或自身按键处理调用）
func _gui_input(event: InputEvent) -> void:
	if data == null:
		return
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and k.keycode == KEY_ESCAPE and _link_mode:
			cancel_link_mode()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		_on_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_on_mouse_motion(event as InputEventMouseMotion)

# ===================== 几何辅助 =====================

func _current_map() -> Dictionary:
	if data == null:
		return {}
	return data.get_row_by_id("map", current_map_id)

func _map_size() -> Vector2i:
	var m: Dictionary = _current_map()
	if m.is_empty():
		return Vector2i(0, 0)
	return Vector2i(int(m.get("width", 10)), int(m.get("height", 10)))

## 场景所在 0 基准格子；越界返回 (-1,-1)
func _cell_of_scene(scene: Dictionary) -> Vector2i:
	var x: int = int(scene.get("x", 0))
	var y: int = int(scene.get("y", 0))
	var ms: Vector2i = _map_size()
	if x < 1 or y < 1 or x > ms.x or y > ms.y:
		return Vector2i(-1, -1)
	return Vector2i(x - 1, y - 1)

func _cell_rect(col: int, row: int) -> Rect2:
	return Rect2(MARGIN + col * CELL_W, MARGIN + row * CELL_H, CELL_W, CELL_H)

func _node_rect_at_cell(cell: Vector2i) -> Rect2:
	var cr: Rect2 = _cell_rect(cell.x, cell.y)
	var pos := Vector2(
		cr.position.x + (cr.size.x - NODE_W) * 0.5,
		cr.position.y + (cr.size.y - NODE_H) * 0.5)
	return Rect2(pos, Vector2(NODE_W, NODE_H))

func _node_rect(scene: Dictionary) -> Rect2:
	var cell: Vector2i = _cell_of_scene(scene)
	if cell.x < 0:
		return Rect2()
	return _node_rect_at_cell(cell)

func _node_center(scene: Dictionary) -> Vector2:
	return _node_rect(scene).get_center()

## 当前地图上的全部场景
func _scenes_on_map() -> Array:
	if data == null:
		return []
	return data.rows_where("scene", "mapid", current_map_id)

## 按 0 基准格子查场景（无则空 Dictionary）
func _scene_at_cell(col: int, row: int) -> Dictionary:
	for s in _scenes_on_map():
		var c: Vector2i = _cell_of_scene(s as Dictionary)
		if c.x == col and c.y == row:
			return s as Dictionary
	return {}

## 本地坐标命中测试：返回命中的场景（优先节点矩形，其次所在格）
func _scene_at_pos(pos: Vector2) -> Dictionary:
	for s in _scenes_on_map():
		if _node_rect(s as Dictionary).has_point(pos):
			return s as Dictionary
	return {}

## 本地坐标 → 0 基准格子；越界返回 (-1,-1)
func _cell_at_pos(pos: Vector2) -> Vector2i:
	var ms: Vector2i = _map_size()
	if ms.x <= 0 or ms.y <= 0:
		return Vector2i(-1, -1)
	var col: int = int(floor((pos.x - MARGIN) / CELL_W))
	var row: int = int(floor((pos.y - MARGIN) / CELL_H))
	if col < 0 or row < 0 or col >= ms.x or row >= ms.y:
		return Vector2i(-1, -1)
	return Vector2i(col, row)

func _is_valid_cell(cell: Vector2i) -> bool:
	var ms: Vector2i = _map_size()
	return cell.x >= 0 and cell.y >= 0 and cell.x < ms.x and cell.y < ms.y

# ===================== 输入处理 =====================

func _on_mouse_button(mb: InputEventMouseButton) -> void:
	if mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			_press_pos = mb.position
			var scene: Dictionary = _scene_at_pos(mb.position)
			if _link_mode:
				# 连接模式：点击非起点的场景 → 完成连接
				if not scene.is_empty():
					var tid: int = int(scene.get("id", 0))
					if tid != _link_start_id:
						var sid: int = _link_start_id
						var d: String = _link_direct
						var bi: bool = _link_bidir
						cancel_link_mode(false)
						link_target_chosen.emit(sid, tid, d, bi)
				return
			if not scene.is_empty():
				var sid: int = int(scene.get("id", 0))
				_selected_id = sid
				_drag_id = sid
				_drag_moved = false
				scene_selected.emit(sid)
				queue_redraw()
			else:
				var cell: Vector2i = _cell_at_pos(mb.position)
				if _is_valid_cell(cell):
					_selected_id = 0
					empty_cell_clicked.emit(cell.x + 1, cell.y + 1)
					queue_redraw()
		else:
			# 左键释放：结束拖动
			if _drag_id != 0 and _drag_moved:
				_finish_drag(mb.position)
			_drag_id = 0
			_drag_moved = false
	elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
		var scene: Dictionary = _scene_at_pos(mb.position)
		if not scene.is_empty():
			node_context_requested.emit(int(scene.get("id", 0)), mb.global_position)
		else:
			var cell: Vector2i = _cell_at_pos(mb.position)
			if _is_valid_cell(cell):
				blank_context_requested.emit(cell.x + 1, cell.y + 1, mb.global_position)

func _on_mouse_motion(mm: InputEventMouseMotion) -> void:
	var scene: Dictionary = _scene_at_pos(mm.position)
	var new_hover: int = 0
	if not scene.is_empty():
		new_hover = int(scene.get("id", 0))
	if new_hover != _hover_id:
		_hover_id = new_hover
		queue_redraw()
	if _drag_id != 0:
		if mm.position.distance_to(_press_pos) > 6.0:
			_drag_moved = true
		if _drag_moved:
			_drag_pos = mm.position
			queue_redraw()

func _finish_drag(release_pos: Vector2) -> void:
	var cell: Vector2i = _cell_at_pos(release_pos)
	if not _is_valid_cell(cell):
		queue_redraw()
		return
	var target: Dictionary = _scene_at_cell(cell.x, cell.y)
	if target.is_empty():
		scene_move_requested.emit(_drag_id, cell.x + 1, cell.y + 1)
	else:
		var tid: int = int(target.get("id", 0))
		if tid != _drag_id:
			scene_swap_requested.emit(_drag_id, tid)
	queue_redraw()

# ===================== 绘制 =====================

func _get_minimum_size() -> Vector2:
	var ms: Vector2i = _map_size()
	if ms.x <= 0 or ms.y <= 0:
		return Vector2(420, 320)
	return Vector2(ms.x * CELL_W + MARGIN * 2.0, ms.y * CELL_H + MARGIN * 2.0)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), C_BG, true)
	var ms: Vector2i = _map_size()
	if data == null or ms.x <= 0 or ms.y <= 0:
		_draw_empty_hint()
		return
	_draw_grid(ms)
	_draw_linkpaths()
	_draw_nodes(ms)
	_draw_drag_ghost()

func _draw_empty_hint() -> void:
	var font: Font = ThemeDB.fallback_font
	var msg: String = "请先在右侧「地图」标签新建地图" if data != null else "未加载数据"
	var ts: Vector2 = font.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
	draw_string(font, Vector2((size.x - ts.x) * 0.5, size.y * 0.5), msg,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.5, 0.5, 0.58, 1))

func _draw_grid(ms: Vector2i) -> void:
	for row in ms.y:
		for col in ms.x:
			var cr: Rect2 = _cell_rect(col, row)
			# 空格画虚线框（ME .item:empty dashed）
			if _scene_at_cell(col, row).is_empty():
				_draw_dashed_rect(cr.grow(-6.0), C_GRID_EMPTY, 1.0, 3.0)

func _draw_nodes(_ms: Vector2i) -> void:
	for s in _scenes_on_map():
		var scene: Dictionary = s as Dictionary
		if _drag_moved and int(scene.get("id", 0)) == _drag_id:
			_draw_node(scene, true)   # 原位画半透明
		else:
			_draw_node(scene, false)

func _draw_node(scene: Dictionary, dimmed: bool) -> void:
	var rect: Rect2 = _node_rect(scene)
	if rect.size == Vector2.ZERO:
		return
	var id: int = int(scene.get("id", 0))
	var is_sel: bool = (id == _selected_id)
	var is_hover: bool = (id == _hover_id and not _drag_moved)
	var is_link_start: bool = (_link_mode and id == _link_start_id)

	# 背景（ME: 白底；选中 gold；连接起点 greenyellow）
	var bg: Color = C_NODE_BG
	if is_link_start:
		bg = C_LINKPOT_BG
	elif is_sel:
		bg = C_SELECTED
	if dimmed:
		bg.a = 0.35
	draw_rect(rect, bg, true)

	# 边框（连接起点 purple 点线；选中/悬停 gold）
	if is_link_start:
		_draw_dashed_rect(rect, C_LINKPOT_BD, 2.0, 3.0)
	else:
		var bc: Color = C_NODE_BORDER
		var bw: float = 1.0
		if is_sel:
			bc = C_SELECTED.darkened(0.25)
			bw = 2.0
		elif is_hover:
			bc = C_HOVER
			bw = 2.0
		if dimmed:
			bc.a = 0.35
		draw_rect(rect, bc, false, bw)

	# 名称文本（居中 + 省略号）
	var name: String = str(scene.get("name", ""))
	if name.strip_edges() == "":
		name = "#%d" % id
	# 类型图标（scene 表 noun 字段映射 emoji）
	var noun: String = str(scene.get("noun", ""))
	var noun_icon := ""
	match noun:
		"castle": noun_icon = "🏰"
		"town": noun_icon = "🏘"
		"shop": noun_icon = "🏪"
		"inn": noun_icon = "🏮"
		"forest": noun_icon = "🌲"
		"mountain": noun_icon = "⛰"
		"sea": noun_icon = "🌊"
		"dungeon": noun_icon = "🗻"
		_: noun_icon = "📍"
	name = noun_icon + " " + name
	var font: Font = ThemeDB.fallback_font
	var fs: int = 12
	var max_w: float = rect.size.x - 10.0
	var display: String = name
	while display.length() > 1 and font.get_string_size(display, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > max_w:
		display = display.substr(0, display.length() - 1)
	if display != name:
		display = display.substr(0, display.length() - 1) + ".."
	var ts: Vector2 = font.get_string_size(display, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var tx: float = rect.position.x + (rect.size.x - ts.x) * 0.5
	var ty: float = rect.position.y + (rect.size.y + ts.y * 0.72) * 0.5
	var tc: Color = C_NODE_TEXT
	if dimmed:
		tc.a = 0.35
	draw_string(font, Vector2(tx, ty), display, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tc)

func _draw_drag_ghost() -> void:
	if not _drag_moved or _drag_id == 0:
		return
	var scene: Dictionary = data.get_row_by_id("scene", _drag_id)
	if scene.is_empty():
		return
	var name: String = str(scene.get("name", ""))
	var rect := Rect2(_drag_pos - Vector2(NODE_W, NODE_H) * 0.5, Vector2(NODE_W, NODE_H))
	draw_rect(rect, C_DRAG_GHOST, true)
	draw_rect(rect, C_SELECTED, false, 1.5)
	var font: Font = ThemeDB.fallback_font
	var ts: Vector2 = font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
	draw_string(font, Vector2(rect.position.x + (rect.size.x - ts.x) * 0.5,
		rect.position.y + (rect.size.y + ts.y * 0.72) * 0.5), name,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, C_NODE_TEXT)
	# 目标格高亮
	var cell: Vector2i = _cell_at_pos(_drag_pos)
	if _is_valid_cell(cell):
		draw_rect(_cell_rect(cell.x, cell.y).grow(-4.0), Color(C_SELECTED, 0.25), true)

# ---- 路径箭头 ----

func _draw_linkpaths() -> void:
	if data == null:
		return
	for lp in data.get_table("linkpath"):
		_draw_linkpath(lp as Dictionary)

func _draw_linkpath(lp: Dictionary) -> void:
	var s: Dictionary = data.get_row_by_id("scene", lp.get("startpot"))
	var e: Dictionary = data.get_row_by_id("scene", lp.get("endpot"))
	if s.is_empty() or e.is_empty():
		return
	if int(s.get("mapid", 0)) != current_map_id or int(e.get("mapid", 0)) != current_map_id:
		return
	var p1: Vector2 = _node_center(s)
	var p2: Vector2 = _node_center(e)
	if p1.distance_to(p2) < 2.0:
		return
	var dir: Vector2 = (p2 - p1).normalized()
	# 垂直偏移 4px：让正反两条路径错开（双向时两端箭头都可见）
	var perp := Vector2(-dir.y, dir.x)
	p1 += perp * 4.0
	p2 += perp * 4.0
	var half := Vector2(NODE_W * 0.5, NODE_H * 0.5)
	var edge: float = _rect_edge_dist(dir, half)
	var start_pt: Vector2 = p1 + dir * (edge + 2.0)
	var end_pt: Vector2 = p2 - dir * (edge + 4.0)
	if start_pt.distance_to(end_pt) < 6.0:
		return
	# 隐藏路径(status=1)画暗
	var hidden: bool = int(lp.get("status", 0)) == 1
	var col: Color = C_PATH if not hidden else Color(C_PATH.r, C_PATH.g, C_PATH.b, 0.30)
	draw_line(start_pt, end_pt, col, 1.6, true)
	_draw_arrowhead(end_pt, dir, col)

## 沿 dir 方向从矩形中心到边界的距离
func _rect_edge_dist(dir: Vector2, half: Vector2) -> float:
	var tx: float = 99999.0
	var ty: float = 99999.0
	if absf(dir.x) > 0.0001:
		tx = half.x / absf(dir.x)
	if absf(dir.y) > 0.0001:
		ty = half.y / absf(dir.y)
	return minf(tx, ty)

func _draw_arrowhead(tip: Vector2, dir: Vector2, col: Color) -> void:
	var ang: float = dir.angle()
	var spread: float = 0.45
	var len: float = 9.0
	var a1: float = ang + PI - spread
	var a2: float = ang + PI + spread
	draw_line(tip, tip + Vector2(cos(a1), sin(a1)) * len, col, 1.6, true)
	draw_line(tip, tip + Vector2(cos(a2), sin(a2)) * len, col, 1.6, true)

## 虚线矩形（Godot 4.4 无 draw_dashed_rect，用 4 条虚线拼）
func _draw_dashed_rect(rect: Rect2, color: Color, width: float = 1.0, dash: float = 3.0) -> void:
	var tl: Vector2 = rect.position
	var br: Vector2 = rect.end
	var tr := Vector2(br.x, tl.y)
	var bl := Vector2(tl.x, br.y)
	draw_dashed_line(tl, tr, color, width, dash)
	draw_dashed_line(tr, br, color, width, dash)
	draw_dashed_line(br, bl, color, width, dash)
	draw_dashed_line(bl, tl, color, width, dash)
