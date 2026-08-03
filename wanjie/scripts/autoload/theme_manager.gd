## 主题管理器（Autoload单例）
## 负责运行时字体大小切换、主题切换、语义化颜色访问
extends Node

## 字体大小预设映射
const FONT_SIZE_MAP := {
	"small": 13,
	"medium": 15,
	"large": 17,
	"xlarge": 20,
}

## 语义化颜色常量（与 main_theme.tres 保持一致）
const C_ACCENT := Color(0.769, 0.588, 0.353, 1.0)
const C_ACCENT_DARK := Color(0.545, 0.396, 0.282, 1.0)
const C_BG_PRIMARY := Color(0.961, 0.925, 0.843, 1.0)
const C_BG_SECONDARY := Color(0.94, 0.91, 0.85, 1.0)
const C_TEXT_PRIMARY := Color(0.29, 0.216, 0.157, 1.0)
const C_TEXT_SECONDARY := Color(0.42, 0.373, 0.322, 1.0)
const C_TEXT_HINT := Color(0.42, 0.373, 0.322, 0.6)
const C_SUCCESS := Color(0.35, 0.6, 0.35, 1.0)
const C_WARNING := Color(0.8, 0.65, 0.2, 1.0)
const C_ERROR := Color(0.8, 0.3, 0.3, 1.0)
const C_INFO := Color(0.3, 0.3, 0.35, 1.0)

## 当前字体预设
var current_font_preset: String = "medium"
## 动效是否启用
var animations_enabled: bool = true

## 主题资源引用
var _main_theme: Theme = null

func _ready() -> void:
	_main_theme = load("res://resources/themes/main_theme.tres")
	_load_persisted_settings()

## 从持久化设置加载
func _load_persisted_settings() -> void:
	var config := ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		current_font_preset = config.get_value("display", "font_size", "medium")
		animations_enabled = config.get_value("display", "animations", true)
		apply_font_preset(current_font_preset)

## 应用字体大小预设
func apply_font_preset(preset: String) -> void:
	if not FONT_SIZE_MAP.has(preset):
		preset = "medium"
	current_font_preset = preset
	var size: int = FONT_SIZE_MAP[preset]
	if _main_theme:
		_main_theme.default_font_size = size
	# 同步更新 ProjectSettings 中的默认字体大小
	ProjectSettings.set_setting("gui/theme/default_font_size", size)

## 获取当前字体大小
func get_current_font_size() -> int:
	return FONT_SIZE_MAP.get(current_font_preset, 15)

## 设置动效开关
func set_animations_enabled(enabled: bool) -> void:
	animations_enabled = enabled

## 创建动画（尊重动效开关）
## 如果动效关闭，直接跳到终态不创建 tween
func create_anim(node: Node) -> Tween:
	var tween := node.create_tween()
	if not animations_enabled:
		tween.set_speed_scale(100.0)  # 极快速度相当于跳过
	return tween

## 获取语义化颜色
func get_color(color_name: String) -> Color:
	match color_name:
		"accent": return C_ACCENT
		"accent_dark": return C_ACCENT_DARK
		"bg_primary": return C_BG_PRIMARY
		"bg_secondary": return C_BG_SECONDARY
		"text_primary": return C_TEXT_PRIMARY
		"text_secondary": return C_TEXT_SECONDARY
		"text_hint": return C_TEXT_HINT
		"success": return C_SUCCESS
		"warning": return C_WARNING
		"error": return C_ERROR
		"info": return C_INFO
		_: return C_TEXT_PRIMARY

## 获取主主题资源
func get_main_theme() -> Theme:
	return _main_theme
