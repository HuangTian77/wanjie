## 编辑器标签管理器
## 管理多标签的打开/关闭/切换
class_name EditorTabManager
extends RefCounted

## 标签数据
## 每个标签: {id, title, panel, data_path, dirty, inspector_data, inspector_title}
var open_tabs: Array[Dictionary] = []
## 当前激活的标签索引
var active_index: int = -1
## 标签ID计数器
var _next_id: int = 0

## 信号回调（由script_editor设置）
var on_tabs_changed: Callable = Callable()
var on_tab_activated: Callable = Callable()

## 打开或激活标签
## 如果 data_path 已打开，则激活它；否则新建标签
func open_or_activate(data_path: String, title: String, panel: Control = null) -> int:
	# 检查是否已打开
	for i in open_tabs.size():
		if open_tabs[i]["data_path"] == data_path:
			active_index = i
			if on_tab_activated.is_valid():
				on_tab_activated.call(i)
			return i
	# 新建标签
	var tab_id := "tab_%d" % _next_id
	_next_id += 1
	var tab := {
		"id": tab_id,
		"title": title,
		"panel": panel,
		"data_path": data_path,
		"dirty": false,
		"inspector_data": null,
		"inspector_title": ""
	}
	open_tabs.append(tab)
	active_index = open_tabs.size() - 1
	if on_tabs_changed.is_valid():
		on_tabs_changed.call()
	if on_tab_activated.is_valid():
		on_tab_activated.call(active_index)
	return active_index

## 关闭标签
func close_tab(index: int) -> void:
	if index < 0 or index >= open_tabs.size():
		return
	var tab: Dictionary = open_tabs[index]
	if tab["panel"] != null and is_instance_valid(tab["panel"]):
		tab["panel"].queue_free()
	open_tabs.remove_at(index)
	# 调整激活索引
	if open_tabs.is_empty():
		active_index = -1
	elif active_index >= open_tabs.size():
		active_index = open_tabs.size() - 1
	elif active_index > index:
		active_index -= 1
	elif active_index == index:
		active_index = mini(active_index, open_tabs.size() - 1)
	if on_tabs_changed.is_valid():
		on_tabs_changed.call()
	if active_index >= 0 and on_tab_activated.is_valid():
		on_tab_activated.call(active_index)

## 切换到指定标签
func switch_tab(index: int) -> void:
	if index < 0 or index >= open_tabs.size():
		return
	active_index = index
	if on_tab_activated.is_valid():
		on_tab_activated.call(index)

## 获取当前激活的标签数据
func get_active_tab() -> Dictionary:
	if active_index >= 0 and active_index < open_tabs.size():
		return open_tabs[active_index]
	return {}

## 获取当前激活的面板
func get_active_panel() -> Control:
	var tab := get_active_tab()
	if tab.is_empty():
		return null
	var panel = tab.get("panel", null)
	if panel != null and is_instance_valid(panel):
		return panel
	return null

## 设置标签的面板
func set_tab_panel(index: int, panel: Control) -> void:
	if index >= 0 and index < open_tabs.size():
		open_tabs[index]["panel"] = panel

## 获取标签标题列表
func get_tab_titles() -> PackedStringArray:
	var titles := PackedStringArray()
	for tab in open_tabs:
		titles.append(tab["title"])
	return titles

## 获取标签数量
func get_tab_count() -> int:
	return open_tabs.size()

## 标记标签为已修改
func mark_dirty(index: int) -> void:
	if index >= 0 and index < open_tabs.size():
		open_tabs[index]["dirty"] = true

## 检查 data_path 是否已打开
func is_path_open(data_path: String) -> bool:
	for tab in open_tabs:
		if tab["data_path"] == data_path:
			return true
	return false

## 设置标签的检查器数据
func set_inspector_data(data, title: String) -> void:
	if active_index >= 0 and active_index < open_tabs.size():
		open_tabs[active_index]["inspector_data"] = data
		open_tabs[active_index]["inspector_title"] = title

## 获取当前激活标签的检查器数据
func get_active_inspector_data() -> Dictionary:
	var tab := get_active_tab()
	if tab.is_empty():
		return {}
	return {"data": tab.get("inspector_data", null), "title": tab.get("inspector_title", "")}

## 关闭所有标签
func close_all() -> void:
	for tab in open_tabs:
		if tab["panel"] != null and is_instance_valid(tab["panel"]):
			tab["panel"].queue_free()
	open_tabs.clear()
	active_index = -1
	if on_tabs_changed.is_valid():
		on_tabs_changed.call()
