## 编辑器节点类型注册表 - 对标 Godot 4.7.1 节点体系
## 集中定义所有可用节点类型: 分类/图标/继承链/默认属性/信号定义/分组标签
## 供 创建节点对话框、信号面板、检查器、场景树 共享使用
class_name EditorNodeRegistry
extends RefCounted

# ============================================================
# 信号定义库 (对标 Godot 4.7.1)
# 每个信号: {"name": 信号名, "args": [参数名...], "desc": 说明}
# ============================================================

## 通用节点信号 (所有节点继承)
const SIGNALS_NODE := [
	{"name": "ready", "args": [], "desc": "节点进入场景树时调用一次"},
	{"name": "renamed", "args": [], "desc": "节点名称被修改时"},
	{"name": "tree_entered", "args": [], "desc": "节点进入场景树时"},
	{"name": "tree_exiting", "args": [], "desc": "节点即将离开场景树时"},
	{"name": "tree_exited", "args": [], "desc": "节点已离开场景树时"},
	{"name": "child_entered_tree", "args": ["node"], "desc": "子节点进入场景树时"},
	{"name": "child_exiting_tree", "args": ["node"], "desc": "子节点即将离开场景树时"},
]

## CanvasItem 信号 (2D可视节点继承)
const SIGNALS_CANVAS_ITEM := [
	{"name": "draw", "args": [], "desc": "需要重绘时"},
	{"name": "visibility_changed", "args": [], "desc": "可见性发生变化时"},
	{"name": "item_rect_changed", "args": [], "desc": "节点矩形区域变化时"},
	{"name": "hidden", "args": [], "desc": "节点被隐藏时"},
]

## Control 信号 (所有UI控件继承) - 对标 Godot 4.7.1 Control
const SIGNALS_CONTROL := [
	{"name": "gui_input", "args": ["event"], "desc": "接收到GUI输入事件时"},
	{"name": "mouse_entered", "args": [], "desc": "鼠标进入控件区域时"},
	{"name": "mouse_exited", "args": [], "desc": "鼠标离开控件区域时"},
	{"name": "focus_entered", "args": [], "desc": "获得键盘焦点时"},
	{"name": "focus_exited", "args": [], "desc": "失去键盘焦点时"},
	{"name": "resized", "args": [], "desc": "控件尺寸变化时"},
	{"name": "minimum_size_changed", "args": [], "desc": "最小尺寸变化时"},
	{"name": "size_flags_changed", "args": [], "desc": "尺寸标志变化时"},
	{"name": "theme_changed", "args": [], "desc": "主题变化时"},
]

## Button 信号 - 对标 Godot 4.7.1 BaseButton/Button
const SIGNALS_BUTTON := [
	{"name": "pressed", "args": [], "desc": "按钮被点击时"},
	{"name": "button_down", "args": [], "desc": "按钮被按下时"},
	{"name": "button_up", "args": [], "desc": "按钮被释放时"},
	{"name": "toggled", "args": ["toggled_on"], "desc": "切换状态变化时(需toggle_mode)"},
]

## LineEdit 信号 - 对标 Godot 4.7.1
const SIGNALS_LINE_EDIT := [
	{"name": "text_changed", "args": ["new_text"], "desc": "文本内容变化时"},
	{"name": "text_submitted", "args": ["new_text"], "desc": "按下回车提交时"},
	{"name": "text_change_rejected", "args": ["rejected_substring"], "desc": "文本变更被拒绝时"},
	{"name": "caret_changed", "args": [], "desc": "光标位置变化时"},
	{"name": "editing_toggled", "args": ["toggled_on"], "desc": "编辑模式切换时"},
]

## TextEdit 信号 - 对标 Godot 4.7.1
const SIGNALS_TEXT_EDIT := [
	{"name": "text_changed", "args": [], "desc": "文本内容变化时"},
	{"name": "text_set", "args": [], "desc": "文本被整体设置时"},
	{"name": "caret_changed", "args": [], "desc": "光标位置变化时"},
	{"name": "gutter_clicked", "args": ["line", "gutter"], "desc": "行号槽被点击时"},
	{"name": "gutter_added", "args": [], "desc": "新增行号槽时"},
]

## CheckBox 信号
const SIGNALS_CHECK_BOX := [
	{"name": "toggled", "args": ["toggled_on"], "desc": "勾选状态变化时"},
]

## ProgressBar 信号
const SIGNALS_PROGRESS_BAR := [
	{"name": "value_changed", "args": ["value"], "desc": "进度值变化时"},
]

## Range 信号 (Slider/SpinBox/ProgressBar继承)
const SIGNALS_RANGE := [
	{"name": "value_changed", "args": ["value"], "desc": "数值变化时"},
	{"name": "changed", "args": [], "desc": "范围参数变化时"},
]

## TextureRect / ColorRect 等纯显示控件无额外信号 (继承Control)

## Container 信号
const SIGNALS_CONTAINER := [
	{"name": "sort_children", "args": [], "desc": "子节点需要重新排列时"},
]

## Node3D 信号 (3D节点继承)
const SIGNALS_NODE3D := [
	{"name": "visibility_changed", "args": [], "desc": "可见性变化时"},
	{"name": "hidden", "args": [], "desc": "节点被隐藏时"},
]

## Camera3D 信号
const SIGNALS_CAMERA_3D := [
	{"name": "camera_changed", "args": [], "desc": "相机属性变化时"},
]

## Light3D 信号
const SIGNALS_LIGHT_3D := [
	{"name": "visibility_changed", "args": [], "desc": "可见性变化时"},
]

# ============================================================
# 节点类型定义
# 每个类型: {
#   "name": 类型名, "category": 分类, "icon": 图标字符,
#   "inherits": 父类型(用于信号继承), "domain": "2d"/"3d",
#   "default_name": 默认节点名, "default_props": 默认属性,
#   "signals": [信号定义...], "desc": 说明
# }
# ============================================================

static func _defs() -> Dictionary:
	return {
		# ---------- 2D: Control 根 ----------
		"Control": {
			"name": "Control", "category": "基础", "icon": "🎛", "inherits": "",
			"domain": "2d", "default_name": "Control",
			"default_props": {"position": "v2:0,0", "size": "v2:100,40", "visible": true},
			"signals": SIGNALS_NODE + SIGNALS_CANVAS_ITEM + SIGNALS_CONTROL,
			"desc": "所有UI控件的基类",
		},
		# ---------- 2D: 按钮类 ----------
		"Button": {
			"name": "Button", "category": "按钮", "icon": "🔘", "inherits": "Control",
			"domain": "2d", "default_name": "Button",
			"default_props": {"position": "v2:20,20", "size": "v2:100,40", "text": "Button", "visible": true},
			"signals": SIGNALS_BUTTON,
			"desc": "标准按钮",
		},
		"CheckBox": {
			"name": "CheckBox", "category": "按钮", "icon": "☑", "inherits": "Control",
			"domain": "2d", "default_name": "CheckBox",
			"default_props": {"position": "v2:20,20", "size": "v2:120,24", "text": "CheckBox", "pressed": false, "visible": true},
			"signals": SIGNALS_CHECK_BOX,
			"desc": "复选框",
		},
		"CheckButton": {
			"name": "CheckButton", "category": "按钮", "icon": "🔲", "inherits": "Control",
			"domain": "2d", "default_name": "CheckButton",
			"default_props": {"position": "v2:20,20", "size": "v2:120,24", "text": "CheckButton", "pressed": false, "visible": true},
			"signals": SIGNALS_CHECK_BOX,
			"desc": "开关按钮",
		},
		"OptionButton": {
			"name": "OptionButton", "category": "按钮", "icon": "📑", "inherits": "Control",
			"domain": "2d", "default_name": "OptionButton",
			"default_props": {"position": "v2:20,20", "size": "v2:120,28", "visible": true},
			"signals": [{"name": "item_selected", "args": ["index"], "desc": "选中某项时"}],
			"desc": "下拉选项按钮",
		},
		"LinkButton": {
			"name": "LinkButton", "category": "按钮", "icon": "🔗", "inherits": "Control",
			"domain": "2d", "default_name": "LinkButton",
			"default_props": {"position": "v2:20,20", "size": "v2:100,24", "text": "Link", "visible": true},
			"signals": SIGNALS_BUTTON,
			"desc": "超链接样式按钮",
		},
		# ---------- 2D: 文本类 ----------
		"Label": {
			"name": "Label", "category": "文本", "icon": "📝", "inherits": "Control",
			"domain": "2d", "default_name": "Label",
			"default_props": {"position": "v2:20,20", "size": "v2:120,24", "text": "Label", "visible": true},
			"signals": [],
			"desc": "静态文本标签",
		},
		"LineEdit": {
			"name": "LineEdit", "category": "文本", "icon": "📄", "inherits": "Control",
			"domain": "2d", "default_name": "LineEdit",
			"default_props": {"position": "v2:20,20", "size": "v2:160,28", "text": "", "placeholder": "", "editable": true, "visible": true},
			"signals": SIGNALS_LINE_EDIT,
			"desc": "单行文本输入框",
		},
		"TextEdit": {
			"name": "TextEdit", "category": "文本", "icon": "📃", "inherits": "Control",
			"domain": "2d", "default_name": "TextEdit",
			"default_props": {"position": "v2:20,20", "size": "v2:200,120", "text": "", "editable": true, "visible": true},
			"signals": SIGNALS_TEXT_EDIT,
			"desc": "多行文本编辑器",
		},
		"RichTextLabel": {
			"name": "RichTextLabel", "category": "文本", "icon": "📜", "inherits": "Control",
			"domain": "2d", "default_name": "RichTextLabel",
			"default_props": {"position": "v2:20,20", "size": "v2:200,100", "text": "", "bbcode_enabled": true, "visible": true},
			"signals": [
				{"name": "meta_clicked", "args": ["meta"], "desc": "点击元链接时"},
				{"name": "meta_hover_started", "args": ["meta"], "desc": "悬停元链接时"},
				{"name": "meta_hover_ended", "args": ["meta"], "desc": "离开元链接时"},
			],
			"desc": "富文本标签(支持BBCode)",
		},
		# ---------- 2D: 显示类 ----------
		"TextureRect": {
			"name": "TextureRect", "category": "显示", "icon": "🖼", "inherits": "Control",
			"domain": "2d", "default_name": "TextureRect",
			"default_props": {"position": "v2:20,20", "size": "v2:100,100", "visible": true},
			"signals": [],
			"desc": "纹理图片显示",
		},
		"ColorRect": {
			"name": "ColorRect", "category": "显示", "icon": "🎨", "inherits": "Control",
			"domain": "2d", "default_name": "ColorRect",
			"default_props": {"position": "v2:20,20", "size": "v2:100,100", "color": "col:0.35,0.6,1.0,1", "visible": true},
			"signals": [],
			"desc": "纯色矩形",
		},
		"Panel": {
			"name": "Panel", "category": "显示", "icon": "📦", "inherits": "Control",
			"domain": "2d", "default_name": "Panel",
			"default_props": {"position": "v2:20,20", "size": "v2:160,120", "visible": true},
			"signals": [],
			"desc": "面板容器(带背景)",
		},
		"ProgressBar": {
			"name": "ProgressBar", "category": "显示", "icon": "📊", "inherits": "Control",
			"domain": "2d", "default_name": "ProgressBar",
			"default_props": {"position": "v2:20,20", "size": "v2:160,20", "min_value": 0.0, "max_value": 100.0, "value": 50.0, "visible": true},
			"signals": SIGNALS_RANGE,
			"desc": "进度条",
		},
		# ---------- 2D: 容器类 ----------
		"VBoxContainer": {
			"name": "VBoxContainer", "category": "容器", "icon": "📚", "inherits": "Control",
			"domain": "2d", "default_name": "VBoxContainer",
			"default_props": {"position": "v2:20,20", "size": "v2:160,120", "separation": 4, "visible": true},
			"signals": SIGNALS_CONTAINER,
			"desc": "垂直排列容器",
		},
		"HBoxContainer": {
			"name": "HBoxContainer", "category": "容器", "icon": "📖", "inherits": "Control",
			"domain": "2d", "default_name": "HBoxContainer",
			"default_props": {"position": "v2:20,20", "size": "v2:160,120", "separation": 4, "visible": true},
			"signals": SIGNALS_CONTAINER,
			"desc": "水平排列容器",
		},
		"MarginContainer": {
			"name": "MarginContainer", "category": "容器", "icon": "🔲", "inherits": "Control",
			"domain": "2d", "default_name": "MarginContainer",
			"default_props": {"position": "v2:20,20", "size": "v2:160,120", "margin": 8, "visible": true},
			"signals": SIGNALS_CONTAINER,
			"desc": "边距容器",
		},
		"CenterContainer": {
			"name": "CenterContainer", "category": "容器", "icon": "⊞", "inherits": "Control",
			"domain": "2d", "default_name": "CenterContainer",
			"default_props": {"position": "v2:20,20", "size": "v2:160,120", "visible": true},
			"signals": SIGNALS_CONTAINER,
			"desc": "居中容器",
		},
		"GridContainer": {
			"name": "GridContainer", "category": "容器", "icon": "🔳", "inherits": "Control",
			"domain": "2d", "default_name": "GridContainer",
			"default_props": {"position": "v2:20,20", "size": "v2:160,120", "columns": 2, "visible": true},
			"signals": SIGNALS_CONTAINER,
			"desc": "网格容器",
		},
		"ScrollContainer": {
			"name": "ScrollContainer", "category": "容器", "icon": "📜", "inherits": "Control",
			"domain": "2d", "default_name": "ScrollContainer",
			"default_props": {"position": "v2:20,20", "size": "v2:200,160", "visible": true},
			"signals": [
				{"name": "scroll_started", "args": [], "desc": "开始滚动时"},
				{"name": "scroll_ended", "args": [], "desc": "结束滚动时"},
			],
			"desc": "滚动容器",
		},
		"TabContainer": {
			"name": "TabContainer", "category": "容器", "icon": "🗂", "inherits": "Control",
			"domain": "2d", "default_name": "TabContainer",
			"default_props": {"position": "v2:20,20", "size": "v2:240,160", "visible": true},
			"signals": [
				{"name": "tab_changed", "args": ["tab"], "desc": "切换标签页时"},
				{"name": "tab_selected", "args": ["tab"], "desc": "选中标签页时"},
				{"name": "tab_close_pressed", "args": ["tab"], "desc": "点击关闭标签时"},
			],
			"desc": "标签页容器",
		},
		# ---------- 2D: 其他控件 ----------
		"ItemList": {
			"name": "ItemList", "category": "控件", "icon": "📋", "inherits": "Control",
			"domain": "2d", "default_name": "ItemList",
			"default_props": {"position": "v2:20,20", "size": "v2:160,120", "visible": true},
			"signals": [
				{"name": "item_selected", "args": ["index"], "desc": "选中某项时"},
				{"name": "item_activated", "args": ["index"], "desc": "激活某项时(双击)"},
				{"name": "multi_selected", "args": ["index", "selected"], "desc": "多选状态变化时"},
				{"name": "item_clicked", "args": ["index", "at_position", "mouse_button_index"], "desc": "点击某项时"},
			],
			"desc": "列表控件",
		},
		"Tree": {
			"name": "Tree", "category": "控件", "icon": "🌳", "inherits": "Control",
			"domain": "2d", "default_name": "Tree",
			"default_props": {"position": "v2:20,20", "size": "v2:200,160", "visible": true},
			"signals": [
				{"name": "item_selected", "args": [], "desc": "选中某项时"},
				{"name": "item_activated", "args": [], "desc": "激活某项时"},
				{"name": "item_edited", "args": [], "desc": "编辑某项时"},
				{"name": "item_collapsed", "args": ["item"], "desc": "折叠状态变化时"},
				{"name": "multi_selected", "args": ["item", "column", "selected"], "desc": "多选状态变化时"},
			],
			"desc": "树形控件",
		},
		"Slider": {
			"name": "HSlider", "category": "控件", "icon": "🎚", "inherits": "Control",
			"domain": "2d", "default_name": "HSlider",
			"default_props": {"position": "v2:20,20", "size": "v2:160,16", "min_value": 0.0, "max_value": 100.0, "value": 50.0, "visible": true},
			"signals": SIGNALS_RANGE + [
				{"name": "drag_started", "args": [], "desc": "开始拖动时"},
				{"name": "drag_ended", "args": ["value_changed"], "desc": "结束拖动时"},
			],
			"desc": "滑动条",
		},
		"SpinBox": {
			"name": "SpinBox", "category": "控件", "icon": "🔢", "inherits": "Control",
			"domain": "2d", "default_name": "SpinBox",
			"default_props": {"position": "v2:20,20", "size": "v2:100,28", "min_value": 0.0, "max_value": 100.0, "value": 0.0, "visible": true},
			"signals": SIGNALS_RANGE,
			"desc": "数字输入框",
		},
		# ---------- 3D: 节点 ----------
		"Node3D": {
			"name": "Node3D", "category": "3D基础", "icon": "📦", "inherits": "",
			"domain": "3d", "default_name": "Node3D",
			"default_props": {"position": "v3:0,0,0", "rotation": "v3:0,0,0", "scale": "v3:1,1,1", "visible": true},
			"signals": SIGNALS_NODE + SIGNALS_NODE3D,
			"desc": "3D空间节点基类",
		},
		"Cube": {
			"name": "Cube", "category": "3D网格", "icon": "🟫", "inherits": "Node3D",
			"domain": "3d", "default_name": "Cube",
			"default_props": {"position": "v3:0,0,0", "rotation": "v3:0,0,0", "scale": "v3:1,1,1", "color": "col:0.8,0.6,0.4,1", "visible": true},
			"signals": [],
			"desc": "立方体网格",
		},
		"Sphere": {
			"name": "Sphere", "category": "3D网格", "icon": "🔵", "inherits": "Node3D",
			"domain": "3d", "default_name": "Sphere",
			"default_props": {"position": "v3:0,0,0", "rotation": "v3:0,0,0", "scale": "v3:1,1,1", "color": "col:0.4,0.6,0.9,1", "visible": true},
			"signals": [],
			"desc": "球体网格",
		},
		"Cylinder": {
			"name": "Cylinder", "category": "3D网格", "icon": "🛢", "inherits": "Node3D",
			"domain": "3d", "default_name": "Cylinder",
			"default_props": {"position": "v3:0,0,0", "rotation": "v3:0,0,0", "scale": "v3:1,1,1", "color": "col:0.7,0.7,0.7,1", "visible": true},
			"signals": [],
			"desc": "圆柱体网格",
		},
		"Capsule": {
			"name": "Capsule", "category": "3D网格", "icon": "💊", "inherits": "Node3D",
			"domain": "3d", "default_name": "Capsule",
			"default_props": {"position": "v3:0,0,0", "rotation": "v3:0,0,0", "scale": "v3:1,1,1", "color": "col:0.6,0.8,0.6,1", "visible": true},
			"signals": [],
			"desc": "胶囊体网格",
		},
		"Plane": {
			"name": "Plane", "category": "3D网格", "icon": "⬜", "inherits": "Node3D",
			"domain": "3d", "default_name": "Plane",
			"default_props": {"position": "v3:0,0,0", "rotation": "v3:0,0,0", "scale": "v3:1,1,1", "color": "col:0.5,0.5,0.55,1", "visible": true},
			"signals": [],
			"desc": "平面网格",
		},
		"Torus": {
			"name": "Torus", "category": "3D网格", "icon": "🍩", "inherits": "Node3D",
			"domain": "3d", "default_name": "Torus",
			"default_props": {"position": "v3:0,0,0", "rotation": "v3:0,0,0", "scale": "v3:1,1,1", "color": "col:0.9,0.7,0.5,1", "visible": true},
			"signals": [],
			"desc": "圆环网格",
		},
		"Prism": {
			"name": "Prism", "category": "3D网格", "icon": "🔺", "inherits": "Node3D",
			"domain": "3d", "default_name": "Prism",
			"default_props": {"position": "v3:0,0,0", "rotation": "v3:0,0,0", "scale": "v3:1,1,1", "color": "col:0.8,0.5,0.7,1", "visible": true},
			"signals": [],
			"desc": "棱柱网格",
		},
		"Light": {
			"name": "Light", "category": "3D灯光相机", "icon": "💡", "inherits": "Node3D",
			"domain": "3d", "default_name": "Light",
			"default_props": {"position": "v3:0,3,0", "rotation": "v3:0,0,0", "scale": "v3:1,1,1", "energy": 1.0, "color": "col:1,1,0.9,1", "visible": true},
			"signals": SIGNALS_LIGHT_3D,
			"desc": "光源",
		},
		"Camera": {
			"name": "Camera", "category": "3D灯光相机", "icon": "🎥", "inherits": "Node3D",
			"domain": "3d", "default_name": "Camera",
			"default_props": {"position": "v3:0,2,5", "rotation": "v3:0,0,0", "scale": "v3:1,1,1", "fov": 75.0, "visible": true},
			"signals": SIGNALS_CAMERA_3D,
			"desc": "3D相机",
		},
	}

# ============================================================
# 查询API
# ============================================================

## 获取所有类型定义 {type_name: def}
static func get_all_types() -> Dictionary:
	return _defs()

## 获取指定类型定义 (不存在返回空Dictionary)
static func get_type(type_name: String) -> Dictionary:
	return _defs().get(type_name, {})

## 类型是否存在
static func has_type(type_name: String) -> bool:
	return _defs().has(type_name)

## 按域获取类型列表 ("2d"/"3d") -> [type_name...]
static func get_types_by_domain(domain: String) -> Array[String]:
	var result: Array[String] = []
	var defs := _defs()
	for type_name in defs:
		if defs[type_name].get("domain", "") == domain:
			result.append(type_name)
	return result

## 按分类分组 {category: [type_name...]}
static func get_types_by_category(domain: String = "") -> Dictionary:
	var result: Dictionary = {}
	var defs := _defs()
	for type_name in defs:
		var def: Dictionary = defs[type_name]
		if not domain.is_empty() and def.get("domain", "") != domain:
			continue
		var cat: String = def.get("category", "其他")
		if not result.has(cat):
			result[cat] = []
		result[cat].append(type_name)
	return result

## 获取类型图标 (未知类型返回默认)
static func get_icon(type_name: String) -> String:
	var def := get_type(type_name)
	return def.get("icon", "◆")

## 获取默认节点名
static func get_default_name(type_name: String) -> String:
	var def := get_type(type_name)
	return def.get("default_name", type_name)

## 获取默认属性 (已解析 v2/v3/col 字符串为真实类型)
static func get_default_props(type_name: String) -> Dictionary:
	var def := get_type(type_name)
	var raw: Dictionary = def.get("default_props", {})
	var result := {}
	for key in raw:
		result[key] = parse_value(raw[key])
	return result

## 创建节点Dictionary (type/name/children/props)
static func create_node(type_name: String, node_name: String = "") -> Dictionary:
	var final_name: String = node_name if not node_name.is_empty() else get_default_name(type_name)
	return {
		"type": type_name,
		"name": final_name,
		"children": [],
		"props": get_default_props(type_name),
	}

# ============================================================
# 信号查询 (含继承)
# ============================================================

## 获取类型的完整信号列表 (自身 + 继承链), 去重
static func get_signals(type_name: String) -> Array:
	var defs := _defs()
	var collected: Array = []
	var seen: Dictionary = {}
	var current: String = type_name
	var guard := 0
	while not current.is_empty() and guard < 32:
		guard += 1
		var def: Dictionary = defs.get(current, {})
		if def.is_empty():
			break
		for sig in def.get("signals", []):
			var sname: String = sig.get("name", "")
			if not sname.is_empty() and not seen.has(sname):
				seen[sname] = true
				collected.append(sig)
		current = def.get("inherits", "")
	return collected

## 判断类型是否拥有某信号
static func type_has_signal(type_name: String, signal_name: String) -> bool:
	for sig in get_signals(type_name):
		if sig.get("name", "") == signal_name:
			return true
	return false

## 生成默认回调方法名 (Godot风格: _on_<节点名>_<信号名>)
static func make_default_callback(node_name: String, signal_name: String) -> String:
	var clean_name: String = _to_snake(node_name)
	if clean_name.is_empty():
		clean_name = "node"
	return "_on_%s_%s" % [clean_name, signal_name]

## 将名称转为snake_case (用于方法名)
static func _to_snake(text: String) -> String:
	var result := ""
	for i in text.length():
		var c: String = text[i]
		if c >= "A" and c <= "Z":
			if i > 0:
				result += "_"
			result += c.to_lower()
		elif c == " " or c == "-":
			result += "_"
		else:
			result += c
	# 合并连续下划线
	while result.contains("__"):
		result = result.replace("__", "_")
	return result.strip_edges().trim_prefix("_").trim_suffix("_")

# ============================================================
# 分组标签 (Godot Groups) - 常用预设
# ============================================================

## 常用分组预设 (供分组面板快捷添加)
static func get_common_groups() -> Array[String]:
	return ["player", "enemy", "npc", "item", "projectile", "trigger", "ui", "pickups", "obstacles", "boss"]

# ============================================================
# 属性值序列化/解析 (v2:/v3:/col: 前缀字符串 <-> 真实类型)
# 与 script_code_editor 的 _json_safe/_from_json 保持兼容
# ============================================================

## 解析 "v2:x,y" / "v3:x,y,z" / "col:r,g,b,a" 为真实类型, 其他原样返回
static func parse_value(v: Variant) -> Variant:
	if v is String:
		var s: String = v
		if s.begins_with("v2:"):
			var parts := s.substr(3).split(",")
			if parts.size() >= 2:
				return Vector2(float(parts[0]), float(parts[1]))
		elif s.begins_with("v3:"):
			var parts := s.substr(3).split(",")
			if parts.size() >= 3:
				return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))
		elif s.begins_with("col:"):
			var parts := s.substr(4).split(",")
			if parts.size() >= 4:
				return Color(float(parts[0]), float(parts[1]), float(parts[2]), float(parts[3]))
	return v

## 将真实类型序列化为前缀字符串 (用于注册表默认值定义)
static func serialize_value(v: Variant) -> Variant:
	if v is Vector2:
		return "v2:%s,%s" % [str(v.x), str(v.y)]
	elif v is Vector3:
		return "v3:%s,%s,%s" % [str(v.x), str(v.y), str(v.z)]
	elif v is Color:
		return "col:%s,%s,%s,%s" % [str(v.r), str(v.g), str(v.b), str(v.a)]
	return v
