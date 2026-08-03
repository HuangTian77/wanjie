## IDE统一主题配色 - 精确对齐 Godot 4.7.1 默认暗色主题
class_name IDETheme
extends RefCounted

# === 背景色 (Godot 4.7.1 Default Dark) ===
const C_BG := Color(0.113726, 0.133334, 0.160785, 1)          # #1d2229 主编辑区背景
const C_BG_BASE := Color(0.090196, 0.105882, 0.129412, 1)     # #171b21 面板/Dock背景
const C_BG_TOOL := Color(0.129412, 0.149020, 0.180392, 1)     # #21262e 工具栏背景
const C_BG_DARKER := Color(0.070588, 0.082353, 0.101961, 1)   # #12151a 更深背景(状态栏)
const C_BG_TAB := Color(0.098039, 0.113726, 0.137255, 1)      # #191d23 非活动标签
const C_BG_TAB_ACTIVE := Color(0.129412, 0.149020, 0.180392, 1) # #21262e 活动标签
const C_BG_HIGHLIGHT := Color(0.168628, 0.200000, 0.254902, 1) # #2b3341 选中/悬停高亮
const C_BG_CANVAS := Color(0.149020, 0.168628, 0.200000, 1)   # #262b33 画布背景

# === 文本色 ===
const C_TEXT := Color(0.803922, 0.811765, 0.823529, 1)        # #cdcfd2 主文本
const C_TEXT_DIM := Color(0.545098, 0.556863, 0.576471, 1)    # #8b8e93 次要文本
const C_TEXT_DISABLED := Color(0.400000, 0.411765, 0.431373, 1) # #66696e 禁用文本

# === 强调色 ===
const C_ACCENT := Color(0.278431, 0.549020, 0.749020, 1)      # #478cbf Godot蓝
const C_ACCENT_DIM := Color(0.278431, 0.549020, 0.749020, 0.4) # 蓝色淡化
const C_GREEN := Color(0.556863, 0.749020, 0.431373, 1)       # #8ebf6e 成功
const C_YELLOW := Color(0.901961, 0.784314, 0.333333, 1)      # #e6c855 警告
const C_RED := Color(0.901961, 0.380392, 0.333333, 1)         # #e66155 错误
const C_ORANGE := Color(0.901961, 0.564706, 0.333333, 1)      # #e69055 注意

# === 边框/分隔 ===
const C_BORDER := Color(0.0, 0.0, 0.0, 0.4)                   # 黑色40%边框
const C_SEPARATOR := Color(0.239216, 0.266667, 0.313726, 1)   # #3d4450 分隔线
const C_GRID := Color(0.239216, 0.266667, 0.313726, 0.3)      # 网格线

# === 代码高亮 (Godot 4.7.1 GDScript配色) ===
const C_KEYWORD := Color(1.0, 0.933333, 0.666667, 1)          # #ffefaa 关键字
const C_CONTROL_FLOW := Color(1.0, 0.827451, 0.666667, 1)     # #ffd3aa 控制流
const C_BASE_TYPE := Color(0.666667, 1.0, 0.827451, 1)        # #aaffd3 基础类型
const C_ENGINE_TYPE := Color(0.513726, 0.827451, 1.0, 1)      # #83d3ff 引擎类型
const C_COMMENT := Color(0.400000, 0.427451, 0.466667, 1)     # #666d77 注释
const C_DOC_COMMENT := Color(0.501961, 0.600000, 0.701961, 1) # #8099b3 文档注释
const C_STRING := Color(0.941176, 0.427451, 0.752941, 1)      # #f06dc0 字符串
const C_NUMBER := Color(0.917647, 0.580392, 0.196078, 1)      # #ea9432 数字
const C_FUNCTION := Color(0.400000, 0.639216, 0.807843, 1)    # #66a3ce 函数名
const C_MEMBER_VAR := Color(0.901961, 0.309804, 0.349020, 1)  # #e64f59 成员变量
const C_SYMBOL := Color(0.729412, 0.870588, 1.0, 1)           # #badeff 符号
const C_CARET := Color(0.670588, 0.670588, 0.670588, 1)       # #aaaaaa 光标
const C_SELECTION := Color(0.411765, 0.611765, 0.909804, 0.35) # 选区
const C_CURRENT_LINE := Color(0.411765, 0.611765, 0.909804, 0.12) # 当前行
const C_API_KEYWORD := Color(1.0, 0.901961, 0.501961, 1)      # #ffe680 剧本API
const C_LINE_NUM := Color(0.670588, 0.670588, 0.670588, 0.4)  # 行号

# === 尺寸常量 (Godot 4.7.1) ===
const DOCK_MIN_WIDTH := 220
const DOCK_DEFAULT_WIDTH := 280
const TOP_BAR_HEIGHT := 34
const MENU_BAR_HEIGHT := 28
const STATUS_BAR_HEIGHT := 22
const BOTTOM_PANEL_MIN_HEIGHT := 100
const BOTTOM_PANEL_DEFAULT_HEIGHT := 180
const SCRIPT_PANEL_WIDTH := 200
const SCRIPT_PANEL_MIN_WIDTH := 150
const FONT_SIZE_MENU := 13
const FONT_SIZE_UI := 12
const FONT_SIZE_CODE := 14
const FONT_SIZE_SMALL := 11

# === 场景编辑器配色 (2D/3D视口专用, 略偏紫) ===
const C_SCENE_BG := Color(0.13, 0.12, 0.15, 1)
const C_SCENE_BG_TOOL := Color(0.16, 0.17, 0.22, 1)
const C_SCENE_BG_PANEL := Color(0.11, 0.10, 0.13, 1)
const C_SCENE_BG_CANVAS := Color(0.18, 0.18, 0.22, 1)
const C_SCENE_TEXT := Color(0.88, 0.88, 0.92, 1)
const C_SCENE_ACCENT := Color(0.35, 0.6, 1.0, 1)
const C_SCENE_GREEN := Color(0.55, 0.85, 0.55, 1)
const C_SCENE_YELLOW := Color(0.95, 0.85, 0.45, 1)
const C_SCENE_RED := Color(1.0, 0.45, 0.45, 1)
const C_SCENE_LABEL := Color(0.65, 0.7, 0.8, 1)
const C_SCENE_BORDER := Color(0.3, 0.33, 0.4, 0.6)
const C_SCENE_GRID := Color(0.3, 0.3, 0.35, 0.3)
const C_SCENE_SELECT := Color(0.35, 0.6, 1.0, 0.4)
const C_SCENE_HANDLE := Color(0.35, 0.6, 1.0, 0.9)
const C_SCENE_HIGHLIGHT := Color(1.0, 0.6, 0.2, 1)

# === MUD编辑器配色 ===
const C_MUD_BG := Color(0.125, 0.125, 0.145, 1)
const C_MUD_TEXT := Color(0.86, 0.86, 0.90, 1)
const C_MUD_ACCENT := Color(0.95, 0.75, 0.35, 1)

# === StyleBox创建辅助 ===
static func create_panel_style(bg_color: Color, border_width: int = 0, border_color: Color = C_BORDER) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	if border_width > 0:
		sb.border_width_bottom = border_width
		sb.border_width_top = border_width
		sb.border_width_left = border_width
		sb.border_width_right = border_width
		sb.border_color = border_color
	sb.content_margin_left = 4.0
	sb.content_margin_top = 4.0
	sb.content_margin_right = 4.0
	sb.content_margin_bottom = 4.0
	return sb

static func create_flat_style(bg_color: Color, radius: int = 3) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	return sb

static func create_button_style(normal_color: Color = Color(0, 0, 0, 0), hover_color: Color = Color(1, 1, 1, 0.08), pressed_color: Color = Color(1, 1, 1, 0.15)) -> Dictionary:
	var sb_normal := StyleBoxFlat.new()
	sb_normal.bg_color = normal_color
	sb_normal.corner_radius_top_left = 3
	sb_normal.corner_radius_top_right = 3
	sb_normal.corner_radius_bottom_left = 3
	sb_normal.corner_radius_bottom_right = 3
	var sb_hover := StyleBoxFlat.new()
	sb_hover.bg_color = hover_color
	sb_hover.corner_radius_top_left = 3
	sb_hover.corner_radius_top_right = 3
	sb_hover.corner_radius_bottom_left = 3
	sb_hover.corner_radius_bottom_right = 3
	var sb_pressed := StyleBoxFlat.new()
	sb_pressed.bg_color = pressed_color
	sb_pressed.corner_radius_top_left = 3
	sb_pressed.corner_radius_top_right = 3
	sb_pressed.corner_radius_bottom_left = 3
	sb_pressed.corner_radius_bottom_right = 3
	return {"normal": sb_normal, "hover": sb_hover, "pressed": sb_pressed}

## 应用Godot风格到任意Button
static func style_button(btn: Button, accent: bool = false) -> void:
	var styles := create_button_style()
	btn.add_theme_stylebox_override("normal", styles["normal"])
	btn.add_theme_stylebox_override("hover", styles["hover"])
	btn.add_theme_stylebox_override("pressed", styles["pressed"])
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if accent:
		btn.add_theme_color_override("font_color", C_ACCENT)
	else:
		btn.add_theme_color_override("font_color", C_TEXT)
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 0.9))
	btn.add_theme_font_size_override("font_size", FONT_SIZE_UI)

## 创建Godot风格分隔线
static func make_vseparator() -> VSeparator:
	var vs := VSeparator.new()
	vs.add_theme_color_override("separator", C_SEPARATOR)
	vs.add_theme_constant_override("separation", 6)
	return vs

static func make_hseparator() -> HSeparator:
	var hs := HSeparator.new()
	hs.add_theme_color_override("separator", C_SEPARATOR)
	hs.add_theme_constant_override("separation", 4)
	return hs
