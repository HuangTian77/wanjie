## Toast通知管理器（Autoload单例）
extends CanvasLayer

## Toast组件场景
const TOAST_SCENE := preload("res://scenes/components/toast_item.tscn")

## 通知队列
var _queue: Array[Dictionary] = []
## 当前显示中的Toast数量
var _active_count: int = 0
## 最大同时显示数
const MAX_ACTIVE := 3
## 容器引用
var _container: VBoxContainer = null

func _ready() -> void:
	layer = 100
	# 创建顶部居中容器
	_container = VBoxContainer.new()
	_container.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_container.offset_left = -160
	_container.offset_top = 12
	_container.offset_right = 160
	_container.offset_bottom = 220
	_container.alignment = BoxContainer.ALIGNMENT_BEGIN
	_container.add_theme_constant_override("separation", 8)
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_container)

## 显示信息通知
func info(text: String) -> void:
	_show_toast(text, "info")

## 显示成功通知
func success(text: String) -> void:
	_show_toast(text, "success")

## 显示警告通知
func warning(text: String) -> void:
	_show_toast(text, "warning")

## 显示错误通知
func error(text: String) -> void:
	_show_toast(text, "error")

## 内部：显示Toast
func _show_toast(text: String, toast_type: String) -> void:
	if _active_count >= MAX_ACTIVE:
		_queue.append({"text": text, "type": toast_type})
		return
	_create_toast(text, toast_type)

## 创建Toast节点
func _create_toast(text: String, toast_type: String) -> void:
	var toast: ToastItem = TOAST_SCENE.instantiate()
	_container.add_child(toast)
	_container.mouse_filter = Control.MOUSE_FILTER_PASS
	_active_count += 1
	toast.setup(text, toast_type)
	toast.finished.connect(_on_toast_finished)

## Toast关闭回调
func _on_toast_finished() -> void:
	_active_count -= 1
	if _active_count <= 0:
		_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_process_queue()

## 处理队列中的通知
func _process_queue() -> void:
	while _active_count < MAX_ACTIVE and not _queue.is_empty():
		var item: Dictionary = _queue.pop_front()
		_create_toast(item["text"], item["type"])
