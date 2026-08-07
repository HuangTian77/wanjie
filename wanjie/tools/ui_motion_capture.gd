extends SceneTree
## 动效帧序列捕获（真实窗口）——验证动画确实发生且平滑
## 用法: ../Godot_v4.7.1-stable_win64.exe --path . -s tools/ui_motion_capture.gd [hover|tab]
##   hover: 鼠标移入第一张剧本卡片（触发 hover 动画）  tab: 切换大厅顶部标签
## 产出: _ui_shots/motion_<type>_<frame>.png（每 50ms 一帧 ×12）
## 配合: python tools/ui_analyze.py --motion _ui_shots/motion_hover_*.png（输出帧间差异曲线）

const OUT_DIR := "res://../_ui_shots"
const FRAMES := 12
const INTERVAL := 0.05

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	create_timer(40.0).timeout.connect(func(): print("MOTION_TIMEOUT"); quit(1))
	var mode := "hover"
	for a in OS.get_cmdline_args():
		if a == "hover" or a == "tab":
			mode = a
	await _load_hub()
	await create_timer(0.8).timeout
	match mode:
		"hover":
			await _trigger_hover()
		"tab":
			await _trigger_tab()
	# 连续截帧
	for i in FRAMES:
		var img := root.get_viewport().get_texture().get_image()
		if img != null and not img.is_empty():
			img.save_png(ProjectSettings.globalize_path(OUT_DIR) + "/motion_%s_%02d.png" % [mode, i])
		await create_timer(INTERVAL).timeout
	print("MOTION_CAPTURED=", mode, " frames=", FRAMES)
	quit(0)

func _load_hub() -> void:
	var packed = load("res://scenes/main/main_hub.tscn")
	var inst = packed.instantiate()
	root.add_child(inst)

func _trigger_hover() -> void:
	var cards := root.find_children("*", "ScriptCard", true, false)
	var card: Control = cards.pop_front() as Control if cards.size() > 0 else null
	if card == null:
		# 大厅无卡片时实例化一张测试卡片（验证 hover 动画机制本身）
		var packed = load("res://scenes/components/script_card.tscn")
		card = packed.instantiate()
		card.position = Vector2(400, 300)
		root.add_child(card)
		var fake := WorldScriptData.new()
		fake.name = "动效测试剧本"
		fake.description = "hover 动画验证"
		fake.author = "测试"
		card.setup(fake)
		await create_timer(0.3).timeout
	# 直接调用 hover 代码路径（引擎 mouse_entered 依赖窗口焦点，-s 场景不可靠）
	if card.has_method("_on_mouse_entered"):
		card.call("_on_mouse_entered")
	var pos := card.get_global_rect().get_center()
	_feed_mouse(pos)

func _trigger_tab() -> void:
	var tabs := root.find_children("*", "Button", true, false)
	for t in tabs:
		if (t as Button).text.contains("我的") or (t as Button).text.contains("探索"):
			(t as Button).emit_signal("pressed")
			return
	if tabs.size() > 0:
		(tabs[0] as Button).emit_signal("pressed")

func _feed_mouse(pos: Vector2) -> void:
	# 经 Viewport GUI 系统派发（触发 mouse_entered/hover 状态）
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	root.push_input(ev)
	var ev2 := InputEventMouseMotion.new()
	ev2.position = pos + Vector2(2, 2)
	ev2.global_position = pos + Vector2(2, 2)
	root.push_input(ev2)
