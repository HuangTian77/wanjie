## Toast 通知条目组件
## 支持图标、文本、自动关闭进度条、进入/退出动画
class_name ToastItem
extends PanelContainer

signal finished

@onready var icon_label: Label = %ToastIcon
@onready var text_label: Label = %ToastText
@onready var progress_bar: ProgressBar = %ToastProgress

var _duration: float = 2.5
var _elapsed: float = 0.0
var _closing: bool = false

## 图标映射
const ICONS := {
	"info": "ℹ",
	"success": "✔",
	"warning": "⚠",
	"error": "✖",
}

## 颜色映射
const COLORS := {
	"info": Color(0.3, 0.3, 0.35, 0.95),
	"success": Color(0.35, 0.6, 0.35, 0.95),
	"warning": Color(0.8, 0.65, 0.2, 0.95),
	"error": Color(0.8, 0.3, 0.3, 0.95),
}

## 样式缓存（按类型, 避免每次弹出重复创建 StyleBox）
static var _style_cache: Dictionary = {}

func _get_cached_styles(toast_type: String) -> Dictionary:
	if _style_cache.has(toast_type):
		return _style_cache[toast_type]
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = COLORS.get(toast_type, COLORS["info"])
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(12)
	panel_style.shadow_color = Color(0, 0, 0, 0.15)
	panel_style.shadow_size = 4
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(1, 1, 1, 0.3)
	fill_style.set_corner_radius_all(2)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(1, 1, 1, 0.1)
	bg_style.set_corner_radius_all(2)
	var cached := {"panel": panel_style, "fill": fill_style, "bg": bg_style}
	_style_cache[toast_type] = cached
	return cached

func setup(text: String, toast_type: String = "info", duration: float = 2.5) -> void:
	_duration = duration
	text_label.text = text
	icon_label.text = ICONS.get(toast_type, "ℹ")
	# 从缓存取样式（避免重复创建）
	var styles: Dictionary = _get_cached_styles(toast_type)
	add_theme_stylebox_override("panel", styles["panel"])
	progress_bar.add_theme_stylebox_override("fill", styles["fill"])
	progress_bar.add_theme_stylebox_override("background", styles["bg"])

func _ready() -> void:
	progress_bar.max_value = _duration
	# 进入动画：从上方滑入
	position.y -= 20
	modulate.a = 0.0
	var tween := ThemeManager.create_anim(self)
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y + 20, 0.25)
	tween.tween_property(self, "modulate:a", 1.0, 0.2)

func _process(delta: float) -> void:
	if _closing:
		return
	_elapsed += delta
	progress_bar.value = _elapsed
	if _elapsed >= _duration:
		_start_close()

func _start_close() -> void:
	_closing = true
	var tween := ThemeManager.create_anim(self)
	tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_property(self, "position:y", position.y - 10, 0.3)
	tween.tween_callback(func():
		finished.emit()
		queue_free()
	)

## 点击提前关闭
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not _closing:
			_start_close()
