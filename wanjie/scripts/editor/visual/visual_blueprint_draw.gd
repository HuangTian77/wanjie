## VisualBlueprintDraw - 蓝图绘制/几何静态工具
## 从 visual_event.gd 提取的纯绘制原语（无状态），供事件列表视图与蓝图视图共用。
## 所有函数通过参数传入 offset/zoom，避免依赖实例状态。
class_name VisualBlueprintDraw
extends RefCounted

# 蓝图常量（原 visual_event.gd）
const BP_NODE_SIZE := Vector2(180, 80)
const BP_PIN_RADIUS := 5.0
const BP_TITLE_HEIGHT := 24.0
const BP_GRID_SIZE := 20.0
const BP_MINIMAP_SIZE := Vector2(160, 110)

## 字体缓存（绘制热点优化: 避免每节点重复查 ThemeDB.fallback_font）
static var _node_bg_cache: StyleBoxFlat = null

## 节点背景圆角框（缓存复用，UE 风格 4px 圆角）
static func _node_bg_box(bg_color: Color) -> StyleBoxFlat:
	if _node_bg_cache == null:
		_node_bg_cache = StyleBoxFlat.new()
		_node_bg_cache.set_corner_radius_all(4)
		_node_bg_cache.set_content_margin_all(0)
	_node_bg_cache.bg_color = bg_color
	return _node_bg_cache
static var _cached_font: Font = null

## 坐标转换（屏幕 -> 世界）
static func screen_to_world(screen_pos: Vector2, offset: Vector2, zoom: float) -> Vector2:
	return (screen_pos - offset) / zoom

## 坐标转换（世界 -> 屏幕）
static func world_to_screen(world_pos: Vector2, offset: Vector2, zoom: float) -> Vector2:
	return world_pos * zoom + offset

## 绘制网格背景（grid_mode: 0=标准 1=粗网格 2=关闭）
static func draw_grid(canvas: Control, offset: Vector2, zoom: float, grid_mode: int = 0) -> void:
	var rect := Rect2(Vector2.ZERO, canvas.size)
	canvas.draw_rect(rect, Color(0.1, 0.11, 0.14, 1.0))
	if grid_mode == 2:
		return
	var effective_grid := BP_GRID_SIZE
	if grid_mode == 1:
		effective_grid = BP_GRID_SIZE * 4
	var grid_step := effective_grid * zoom
	if grid_step < 5.0:
		return
	# 计算可见世界范围
	var start_x := int((screen_to_world(Vector2.ZERO, offset, zoom).x / effective_grid)) - 1
	var end_x := int((screen_to_world(canvas.size, offset, zoom).x / effective_grid)) + 1
	var start_y := int((screen_to_world(Vector2.ZERO, offset, zoom).y / effective_grid)) - 1
	var end_y := int((screen_to_world(canvas.size, offset, zoom).y / effective_grid)) + 1
	var grid_color := Color(0.18, 0.2, 0.25, 0.3)
	var major_color := Color(0.22, 0.25, 0.32, 0.5)
	# 细网格线(横/竖)
	for gx in range(start_x, end_x + 1):
		var sx: float = world_to_screen(Vector2(gx * effective_grid, 0), offset, zoom).x
		var col: Color = major_color if gx % 5 == 0 else grid_color
		canvas.draw_line(Vector2(sx, 0), Vector2(sx, canvas.size.y), col, 1.0)
	for gy in range(start_y, end_y + 1):
		var sy: float = world_to_screen(Vector2(0, gy * effective_grid), offset, zoom).y
		var col: Color = major_color if gy % 5 == 0 else grid_color
		canvas.draw_line(Vector2(0, sy), Vector2(canvas.size.x, sy), col, 1.0)

## 绘制通用蓝图节点(事件列表视图用)
static func draw_bp_node(canvas: Control, node: Dictionary, selected: bool, offset: Vector2, zoom: float) -> void:
	var pos: Vector2 = world_to_screen(node.get("pos", Vector2.ZERO), offset, zoom)
	var sz := BP_NODE_SIZE * zoom
	var node_color: Color = node.get("color", Color(0.3, 0.3, 0.4, 1.0))
	# 节点背景
	var bg_color := Color(node_color.r * 0.3, node_color.g * 0.3, node_color.b * 0.3, 0.95)
	canvas.draw_rect(Rect2(pos, sz), bg_color)
	# 选中高亮边框
	if selected:
		canvas.draw_rect(Rect2(pos, sz), Color(1.0, 0.8, 0.2, 0.9), false, 2.0)
	else:
		canvas.draw_rect(Rect2(pos, sz), Color(node_color.r, node_color.g, node_color.b, 0.6), false, 1.0)
	# 标题栏
	var title_rect := Rect2(pos, Vector2(sz.x, BP_TITLE_HEIGHT * zoom))
	canvas.draw_rect(title_rect, node_color)
	# 标题文字（字体缓存: 避免每次绘制重复查 ThemeDB）
	if _cached_font == null:
		_cached_font = ThemeDB.fallback_font
	var title_text: String = node.get("title", "")
	if title_text != "":
		var font_size := int(12 * zoom)
		canvas.draw_string(_cached_font, pos + Vector2(8 * zoom, 16 * zoom), title_text, HORIZONTAL_ALIGNMENT_LEFT, int(sz.x - 16 * zoom), font_size, Color.WHITE)
	# 内容区文字
	var body: Array = node.get("body", [])
	var body_y: float = pos.y + (BP_TITLE_HEIGHT + 14) * zoom
	for line_text in body:
		canvas.draw_string(_cached_font, pos + Vector2(8 * zoom, body_y), str(line_text), HORIZONTAL_ALIGNMENT_LEFT, int(sz.x - 16 * zoom), int(10 * zoom), Color(0.7, 0.75, 0.8))
		body_y += 14 * zoom

## 绘制引脚(事件列表视图用)
static func draw_bp_pins(canvas: Control, node: Dictionary, offset: Vector2, zoom: float) -> void:
	var pos: Vector2 = world_to_screen(node.get("pos", Vector2.ZERO), offset, zoom)
	var sz := BP_NODE_SIZE * zoom
	var pin_y: float = pos.y + sz.y / 2.0
	# 输入引脚(左侧)
	if node.get("inputs", []).size() > 0:
		canvas.draw_circle(Vector2(pos.x, pin_y), BP_PIN_RADIUS * zoom, Color(0.8, 0.8, 0.8, 0.9))
	# 输出引脚(右侧)
	if node.get("outputs", []).size() > 0:
		canvas.draw_circle(Vector2(pos.x + sz.x, pin_y), BP_PIN_RADIUS * zoom, Color(0.8, 0.8, 0.8, 0.9))

## 贝塞尔曲线连线
static func draw_connection(canvas: Control, from_pos: Vector2, to_pos: Vector2, color: Color, width: float, offset: Vector2, zoom: float) -> void:
	var s1 := world_to_screen(from_pos, offset, zoom)
	var s2 := world_to_screen(to_pos, offset, zoom)
	var dist := absf(s2.x - s1.x)
	var ctrl_offset := maxf(dist * 0.4, 50.0)
	var c1 := s1 + Vector2(ctrl_offset, 0)
	var c2 := s2 - Vector2(ctrl_offset, 0)
	# 一次 draw_bezier 调用替代 16 段 draw_line（绘制热点优化）
	canvas.draw_bezier(s1, c1, c2, s2, color, width, false)

## 三次贝塞尔插值
static func cubic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	var tt := t * t
	var uu := u * u
	var uuu := uu * u
	var ttt := tt * t
	return p0 * uuu + p1 * 3.0 * uu * t + p2 * 3.0 * u * tt + p3 * ttt

## 获取引脚世界坐标(事件列表视图简化版)
static func get_pin_world_pos(node: Dictionary, is_output: bool, _port_index: int = 0) -> Vector2:
	var pos: Vector2 = node.get("pos", Vector2.ZERO)
	if is_output:
		return pos + Vector2(BP_NODE_SIZE.x, BP_NODE_SIZE.y / 2.0)
	else:
		return pos + Vector2(0, BP_NODE_SIZE.y / 2.0)

## 命中检测: 节点(屏幕坐标, 事件列表视图)
static func hit_test_node(screen_pos: Vector2, graph: Dictionary, offset: Vector2, zoom: float) -> String:
	var world_pos := screen_to_world(screen_pos, offset, zoom)
	# 从后往前检测(后绘制的在上层)
	var node_ids: Array = graph["nodes"].keys()
	for i in range(node_ids.size() - 1, -1, -1):
		var nid: String = node_ids[i]
		var node: Dictionary = graph["nodes"][nid]
		var node_rect := Rect2(node.get("pos", Vector2.ZERO), BP_NODE_SIZE)
		if node_rect.has_point(world_pos):
			return nid
	return ""

## 命中检测: 引脚(屏幕坐标, 事件列表视图, 返回 [node_id, port_index, is_output] 或 null)
static func hit_test_pins(screen_pos: Vector2, graph: Dictionary, offset: Vector2, zoom: float) -> Variant:
	var world_pos := screen_to_world(screen_pos, offset, zoom)
	var threshold := (BP_PIN_RADIUS + 4.0) / zoom
	for nid in graph["nodes"]:
		var node: Dictionary = graph["nodes"][nid]
		# 输出引脚
		var out_pos := get_pin_world_pos(node, true)
		if world_pos.distance_to(out_pos) < threshold:
			return [nid, 0, true]
		# 输入引脚
		var in_pos := get_pin_world_pos(node, false)
		if world_pos.distance_to(in_pos) < threshold:
			return [nid, 0, false]
	return null

## 绘制单个蓝图节点（带类型引脚, 蓝图视图）
static func draw_blueprint_node(canvas: Control, node: Dictionary, selected: bool, offset: Vector2, zoom: float, show_detail: bool = false, hover_pos: Vector2 = Vector2(-9999, -9999), exec_order: int = 0) -> void:
	var pos: Vector2 = world_to_screen(node.get("pos", Vector2.ZERO), offset, zoom)
	var node_height: float = BlueprintData.calc_node_height(node) * zoom
	var node_width: float = 180.0 * zoom
	var sz := Vector2(node_width, node_height)
	var node_color: Color = node.get("color", Color(0.3, 0.3, 0.4, 1.0))
	# 注释框特殊绘制
	if node["node_type"] == "comment" or node["node_type"] == "flow_comment":
		var comment_sz: Vector2 = node["properties"].get("size", Vector2(300, 200)) * zoom
		canvas.draw_rect(Rect2(pos, comment_sz), Color(0.25, 0.25, 0.2, 0.3))
		canvas.draw_rect(Rect2(pos, comment_sz), Color(0.5, 0.5, 0.3, 0.5), false, 1.0)
		var text: String = node["properties"].get("text", "Comment")
		canvas.draw_string(ThemeDB.fallback_font, pos + Vector2(8, 16) * zoom, text, HORIZONTAL_ALIGNMENT_LEFT, int(comment_sz.x - 16), int(12 * zoom), Color(0.7, 0.7, 0.5))
		return
	# 节点背景（4px 圆角，UE 风格）
	var bg_color := Color(node_color.r * 0.25, node_color.g * 0.25, node_color.b * 0.25, 0.95)
	canvas.draw_style_box(_node_bg_box(bg_color), Rect2(pos, sz))
	# 选中注释框：右下角缩放把手提示（双击快速调整尺寸）
	if selected and (node.get("node_type", "") == "comment" or node.get("node_type", "") == "flow_comment"):
		var handle_pos := pos + sz - Vector2(10, 10) * zoom
		canvas.draw_circle(handle_pos, 5 * zoom, Color(1.0, 0.85, 0.2, 0.9))
	# 选中高亮
	if selected:
		canvas.draw_rect(Rect2(pos, sz), Color(1.0, 0.8, 0.2, 0.9), false, 2.5)
	else:
		canvas.draw_rect(Rect2(pos, sz), Color(node_color.r, node_color.g, node_color.b, 0.5), false, 1.0)
	# 标题栏
	var title_rect := Rect2(pos, Vector2(sz.x, BP_TITLE_HEIGHT * zoom))
	canvas.draw_rect(title_rect, node_color)
	var title_text: String = node.get("title", "")
	if title_text.is_empty():
		title_text = BlueprintNodeRegistry.get_display_name(node["node_type"])
	# 详尽模式：标题前置分类图标
	if show_detail:
		var cat_info: Dictionary = BlueprintNodeRegistry.CATEGORIES.get(str(BlueprintNodeRegistry.get_definition(node["node_type"]).get("category", "")), {})
		var cat_icon: String = str(cat_info.get("icon", ""))
		if cat_icon != "":
			title_text = "%s %s" % [cat_icon, title_text]
	canvas.draw_string(ThemeDB.fallback_font, pos + Vector2(8 * zoom, 16 * zoom), title_text, HORIZONTAL_ALIGNMENT_LEFT, int(sz.x - 16 * zoom), int(11 * zoom), Color.WHITE)
	# 属性摘要
	var props: Dictionary = node.get("properties", {})
	var summary := ""
	if props.has("var_name") and str(props["var_name"]) != "":
		summary = str(props["var_name"])
	elif props.has("event_name") and str(props["event_name"]) != "":
		summary = str(props["event_name"])
	elif props.has("code") and str(props["code"]) != "":
		summary = str(props["code"]).left(20)
	if summary != "":
		canvas.draw_string(ThemeDB.fallback_font, pos + Vector2(8 * zoom, (BP_TITLE_HEIGHT + 14) * zoom), summary, HORIZONTAL_ALIGNMENT_LEFT, int(sz.x - 16 * zoom), int(9 * zoom), Color(0.6, 0.7, 0.8, 0.8))
	# 详尽模式：右下角显示节点 ID 与优先级
	if show_detail:
		canvas.draw_string(ThemeDB.fallback_font, pos + Vector2(8 * zoom, sz.y - 4 * zoom), str(node.get("id", "?")), HORIZONTAL_ALIGNMENT_LEFT, int(sz.x - 16 * zoom), int(8 * zoom), Color(0.5, 0.55, 0.6, 0.7))
	# 详尽模式：执行顺序角标（左上角 圈数字）
	if show_detail and exec_order > 0:
		var order_txt: String = "①"
		var circled := ["①", "②", "③", "④", "⑤", "⑥", "⑦", "⑧", "⑨", "⑩", "⑪", "⑫", "⑬", "⑭", "⑮", "⑯", "⑰", "⑱", "⑲", "⑳"]
		if exec_order <= circled.size():
			order_txt = circled[exec_order - 1]
		else:
			order_txt = "#%d" % exec_order
		var badge_pos := pos + Vector2(sz.x - 18 * zoom, 2 * zoom)
		canvas.draw_circle(badge_pos + Vector2(0, 8 * zoom), 9 * zoom, Color(0.1, 0.1, 0.12, 0.85))
		canvas.draw_string(ThemeDB.fallback_font, badge_pos, order_txt, HORIZONTAL_ALIGNMENT_RIGHT, int(20 * zoom), int(11 * zoom), Color(1, 0.9, 0.5))
	# 绘制引脚（带 hover 高亮）
	draw_typed_pins(canvas, node, pos, offset, zoom, hover_pos)

## 绘制类型引脚（执行=三角, 数据=圆形）
static func draw_typed_pins(canvas: Control, node: Dictionary, screen_pos: Vector2, _offset: Vector2, zoom: float, hover_pos: Vector2 = Vector2(-9999, -9999)) -> void:
	var node_width: float = 180.0 * zoom
	var pin_start_y: float = screen_pos.y + (BP_TITLE_HEIGHT + 10) * zoom
	var pin_spacing: float = 20.0 * zoom
	var r: float = BP_PIN_RADIUS * zoom
	# 输入引脚(左侧)
	var inputs: Array = node.get("inputs", [])
	for i in inputs.size():
		var pin: Dictionary = inputs[i]
		var py: float = pin_start_y + i * pin_spacing
		var pin_pos := Vector2(screen_pos.x, py)
		var dt: int = pin.get("data_type", 0)
		var col: Color = BlueprintData.PIN_COLORS.get(dt, Color(0.5, 0.5, 0.5))
		if dt == BlueprintData.PinDataType.EXEC:
			# 执行引脚: 三角形
			var tri: PackedVector2Array = PackedVector2Array([
				pin_pos + Vector2(-r, -r),
				pin_pos + Vector2(-r, r),
				pin_pos + Vector2(r, 0),
			])
			canvas.draw_colored_polygon(tri, col)
		else:
			canvas.draw_circle(pin_pos, r, col)
		# hover 高亮（白圈 + 放大）
		if hover_pos.distance_to(pin_pos) < 14 * zoom:
			canvas.draw_arc(pin_pos, r + 3 * zoom, 0, TAU, 24, Color(1, 1, 1, 0.9), 1.5)
		# 引脚名称
		canvas.draw_string(ThemeDB.fallback_font, pin_pos + Vector2(r + 3, 4) * zoom, pin.get("name", ""), HORIZONTAL_ALIGNMENT_LEFT, int(60 * zoom), int(9 * zoom), Color(0.6, 0.65, 0.7))
	# 输出引脚(右侧)
	var outputs: Array = node.get("outputs", [])
	for i in outputs.size():
		var pin: Dictionary = outputs[i]
		var py: float = pin_start_y + i * pin_spacing
		var pin_pos := Vector2(screen_pos.x + node_width, py)
		var dt: int = pin.get("data_type", 0)
		var col: Color = BlueprintData.PIN_COLORS.get(dt, Color(0.5, 0.5, 0.5))
		if dt == BlueprintData.PinDataType.EXEC:
			# 执行引脚: 三角形
			var tri: PackedVector2Array = PackedVector2Array([
				pin_pos + Vector2(-r, -r),
				pin_pos + Vector2(-r, r),
				pin_pos + Vector2(r, 0),
			])
			canvas.draw_colored_polygon(tri, col)
		else:
			canvas.draw_circle(pin_pos, r, col)
		# hover 高亮（白圈 + 放大）
		if hover_pos.distance_to(pin_pos) < 14 * zoom:
			canvas.draw_arc(pin_pos, r + 3 * zoom, 0, TAU, 24, Color(1, 1, 1, 0.9), 1.5)
		# 引脚名称(右对齐)
		canvas.draw_string(ThemeDB.fallback_font, pin_pos + Vector2(-65 * zoom, 4 * zoom), pin["name"], HORIZONTAL_ALIGNMENT_RIGHT, int(60 * zoom), int(9 * zoom), Color(0.6, 0.65, 0.7))

## 绘制执行流连线（白色粗线 + 箭头）
static func draw_exec_connection(canvas: Control, from_pos: Vector2, to_pos: Vector2, offset: Vector2, zoom: float) -> void:
	var s1 := world_to_screen(from_pos, offset, zoom)
	var s2 := world_to_screen(to_pos, offset, zoom)
	var dist := absf(s2.x - s1.x)
	var ctrl_offset := maxf(dist * 0.4, 50.0)
	var c1 := s1 + Vector2(ctrl_offset, 0)
	var c2 := s2 - Vector2(ctrl_offset, 0)
	var segments := 16
	var prev := s1
	var width: float = 2.5 * zoom
	for i in range(1, segments + 1):
		var t: float = float(i) / float(segments)
		var pt := cubic_bezier(s1, c1, c2, s2, t)
		canvas.draw_line(prev, pt, Color(0.9, 0.9, 0.95, 0.85), width)
		prev = pt
	# 箭头（中点处）
	var mid := cubic_bezier(s1, c1, c2, s2, 0.5)
	var mid2 := cubic_bezier(s1, c1, c2, s2, 0.52)
	var dir := (mid2 - mid).normalized()
	var arrow_size: float = 6.0 * zoom
	var perp := Vector2(-dir.y, dir.x)
	var tri: PackedVector2Array = PackedVector2Array([
		mid + dir * arrow_size,
		mid - dir * arrow_size * 0.5 + perp * arrow_size * 0.6,
		mid - dir * arrow_size * 0.5 - perp * arrow_size * 0.6,
	])
	canvas.draw_colored_polygon(tri, Color(0.9, 0.9, 0.95, 0.85))

## 蓝图模式引脚命中检测（支持变长引脚列表）
static func hit_test_bp_pins(screen_pos: Vector2, graph: Dictionary, offset: Vector2, zoom: float) -> Variant:
	var world_pos := screen_to_world(screen_pos, offset, zoom)
	var threshold := (BP_PIN_RADIUS + 5.0) / zoom
	for nid in graph.get("nodes", {}):
		var node: Dictionary = graph["nodes"][nid]
		# 输出引脚
		var outputs: Array = node.get("outputs", [])
		for i in outputs.size():
			var pin_pos: Vector2 = BlueprintData.get_pin_world_pos(node, true, i)
			if world_pos.distance_to(pin_pos) < threshold:
				return [nid, i, true]
		# 输入引脚
		var inputs: Array = node.get("inputs", [])
		for i in inputs.size():
			var pin_pos: Vector2 = BlueprintData.get_pin_world_pos(node, false, i)
			if world_pos.distance_to(pin_pos) < threshold:
				return [nid, i, false]
	return null

## 蓝图模式节点命中检测
static func hit_test_bp_node(screen_pos: Vector2, graph: Dictionary, offset: Vector2, zoom: float) -> String:
	var world_pos := screen_to_world(screen_pos, offset, zoom)
	var node_ids: Array = graph["nodes"].keys()
	for i in range(node_ids.size() - 1, -1, -1):
		var nid: String = node_ids[i]
		var node: Dictionary = graph["nodes"][nid]
		var node_height: float = BlueprintData.calc_node_height(node)
		var node_rect := Rect2(node.get("pos", Vector2.ZERO), Vector2(180.0, node_height))
		if node_rect.has_point(world_pos):
			return nid
	return ""
