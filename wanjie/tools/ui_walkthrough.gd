extends SceneTree
## 交互式 UI 走查（真实窗口模式，驱动真实场景路由 + 分步截图）
## 用法: ../Godot_v4.7.1-stable_win64.exe --path . -s tools/ui_walkthrough.gd [可选剧本名]
## 流程: 大厅 → 创建剧本 → 编辑器 → 各子系统(世界/事件/经济/能力/任务/战斗/地图/蓝图/MUD) → 体验器 → 回大厅
## 产出: _ui_shots/walkthrough_*.png + 报告（错误/耗时）
## 退出码: 0=全流程无错误, 1=有失败

const OUT_DIR := "res://../_ui_shots"
var _errs := 0
var _report: Array[String] = []

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	create_timer(90.0).timeout.connect(func(): print("WALK_TIMEOUT"); quit(1))
	_report.append("== UI 交互走查报告 ==")
	# 1. 大厅
	await _goto("res://scenes/main/main_hub.tscn", "walkthrough_01_hub")
	# 2. 创建剧本进入编辑器
	var sdm: Variant = root.get_node_or_null("/root/ScriptDataManager")
	var sm: Variant = root.get_node_or_null("/root/SceneManager")
	if sdm == null or sm == null:
		_report.append("  [FAIL] autoload 未就绪")
		_errs += 1
		_finish()
		return
	var ws: Variant = sdm.create_script("走查测试", "测试玩家", "", {})
	if ws == null:
		_report.append("  [FAIL] create_script 失败")
		_errs += 1
	else:
		sm.open_script_editor(ws.id)
		await _wait_scene(0.8)
		await _shot("walkthrough_02_editor")
		# 3. 各子系统模块
		var subs: Array = [
			["世界", "worldview/overview"], ["事件", "event/overview"], ["经济", "economy/overview"],
			["能力", "ability/overview"], ["任务", "quest/overview"], ["战斗", "combat/overview"],
			["地图", "map/overview"], ["蓝图", "blueprint/workspace"], ["MUD", "mud"],
		]
		for i in subs.size():
			var ok: bool = false
			if subs[i][1] == "mud":
				ok = _open_mud_mode()
			else:
				ok = _open_editor_sub(i + 3, subs[i][1])
			_report.append("  模块[%s] 打开=%s" % [subs[i][0], "OK" if ok else "FAIL"])
			if not ok:
				_errs += 1
			await _shot("walkthrough_%02d_%s" % [i + 3, subs[i][0]])
		# 4. 体验器
		sm.enter_script(ws.id)
		await _wait_scene(0.8)
		await _shot("walkthrough_12_player")
		# 5. 回大厅
		sm.go_back_to_hub()
		await _wait_scene(0.8)
		await _shot("walkthrough_13_hub_back")
	_finish()

func _finish() -> void:
	print("\n".join(_report))
	print("WALK_ERRORS=", _errs)
	quit(1 if _errs > 0 else 0)

## 切换场景并等稳定
func _goto(scene_path: String, shot_name: String) -> void:
	var sm: Variant = root.get_node_or_null("/root/SceneManager")
	if sm != null:
		sm.change_scene(scene_path)
	else:
		change_scene_to_file(scene_path)
	await _wait_scene(0.8)
	await _shot(shot_name)

func _wait_scene(sec: float) -> void:
	await create_timer(sec).timeout

## 截图当前根场景
func _shot(name: String) -> void:
	await create_timer(0.3).timeout
	var img := root.get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		_report.append("  [WARN] 截图空 %s (headless?)" % name)
		return
	var out := ProjectSettings.globalize_path(OUT_DIR) + "/" + name + ".png"
	img.save_png(out)

## 切换编辑器到 MUD 模式
func _open_mud_mode() -> bool:
	var ed := root.find_child("ScriptEditor", true, false) as Control
	if ed == null:
		return false
	if ed.has_method("_on_mode_mud_pressed"):
		ed.call("_on_mode_mud_pressed")
		return true
	return false

## 编辑器模块树选中 path 对应的子系统
func _open_editor_sub(_tab_index: int, path: String) -> bool:
	var ed := root.find_child("ScriptEditor", true, false) as Control
	if ed == null:
		return false
	# 直接调用编辑器打开路由（等价于点击模块树条目）
	var opened: bool = false
	# 通过模块树 Tree 节点模拟选择
	var tree := ed.find_child("*Tree*", true, false) as Tree
	if tree != null:
		for item in _collect_items(tree.get_root()):
			var meta: Variant = item.get_metadata(0)
			if meta is Dictionary and meta.get("path", "") == path:
				tree.set_selected(item, 0)
				tree.item_selected.emit()
				opened = true
				break
	return opened

func _collect_items(item: TreeItem) -> Array:
	var out: Array = []
	if item == null:
		return out
	out.append(item)
	for c in item.get_children():
		out.append_array(_collect_items(c))
	return out
