## 编辑器模式单例：三档模式（简易 / 详细 / 详尽）
## 简易=游戏开发零基础用户（功能精简）；详细=有经验开发者（标准）；详尽=高级开发者（全部功能）
extends Node

## 模式枚举（min_mode 语义：core=0 简易可见 / advanced=1 详细可见 / expert=2 仅详尽可见）
const SIMPLE: int = 0
const DETAILED: int = 1
const EXHAUSTIVE: int = 2

## 模式名称（UI 显示）
const MODE_NAMES: Array[String] = ["简易", "详细", "详尽"]
## 模式描述（tooltip）
const MODE_DESCS: Array[String] = [
	"为游戏开发零基础用户精简：只显示核心节点与常用字段，自动隐藏高级配置",
	"为有经验的开发者提供标准功能：完整节点分类与常用高级参数",
	"为高级开发者提供最详细功能：全部节点/字段/调试信息与数据视图",
]
## 模式图标（简易无图标，详细 ⚙，详尽 🧠）
const MODE_ICONS: Array[String] = ["🌱", "⚙", "🧠"]

## 字段分级标签（P2 表单分级用）
const FIELD_CORE: int = 0
const FIELD_ADVANCED: int = 1
const FIELD_EXPERT: int = 2

signal mode_changed(mode: int)

var current_mode: int = DETAILED

## 模式切换时保存的画布视图状态（跨面板重建传递）
var _bp_view_state: Dictionary = {}
## 当前激活图 key（模式切换保持）
var _graph_key_state: String = ""

const CONFIG_PATH := "user://editor_mode.cfg"


## 保存当前图 key（模式切换重建前调用）
func set_graph_key_state(key: String) -> void:
	_graph_key_state = key


## 读取并清空图 key 状态
func take_graph_key_state() -> String:
	var k := _graph_key_state
	_graph_key_state = ""
	return k


## 保存蓝图画布视图状态（模式切换重建前调用）
func set_bp_view_state(state: Dictionary) -> void:
	_bp_view_state = state.duplicate()


## 读取并清空蓝图画布视图状态
func take_bp_view_state() -> Dictionary:
	var s := _bp_view_state.duplicate()
	_bp_view_state = {}
	return s


func _ready() -> void:
	_load()


## 模式切换累计次数（统计用）
var switch_count: int = 0

## 设置模式（持久化 + 广播）
func set_mode(mode: int) -> void:
	var m := clampi(mode, SIMPLE, EXHAUSTIVE)
	if m == current_mode:
		return
	current_mode = m
	switch_count += 1
	_save()
	mode_changed.emit(current_mode)


func get_mode() -> int:
	return current_mode


func get_mode_name() -> String:
	return MODE_NAMES[current_mode]


func get_mode_desc() -> String:
	return MODE_DESCS[current_mode]


## 过滤判定：给定最低可见档位，当前模式是否可见
func is_visible(min_mode: int) -> bool:
	return current_mode >= min_mode


## 简易模式快捷判定
func is_simple() -> bool:
	return current_mode == SIMPLE


## 详尽模式快捷判定
func is_exhaustive() -> bool:
	return current_mode == EXHAUSTIVE


func _save() -> void:
	var f := FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	if f:
		f.store_line(str(current_mode))
		f.store_line(str(switch_count))
		f.close()


func _load() -> void:
	if not FileAccess.file_exists(CONFIG_PATH):
		return
	var f := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if f:
		var line := f.get_line().strip_edges()
		var line2 := f.get_line().strip_edges()
		f.close()
		if line.is_valid_int():
			current_mode = clampi(int(line), SIMPLE, EXHAUSTIVE)
		if line2.is_valid_int():
			switch_count = maxi(int(line2), 0)
