extends SceneTree
## UI 截图工具（需真实窗口/非 headless 运行；headless 的 dummy 驱动不渲染）
## 用法: Godot_v4.7.1-stable_win64.exe --path wanjie tools/ui_screenshot.gd main_hub
##   main_hub | editor | <res://场景路径>
## 输出: <项目根>/_ui_shots/<场景名>.png

const OUT_DIR := "res://../_ui_shots"

func _initialize() -> void:
	# 整体超时保护（防挂起）
	create_timer(20.0).timeout.connect(func(): print("SCREENSHOT_TIMEOUT"); quit(1))
	var arg := ""
	# 兼容 -s script <arg> 与 -- <arg> 两种传参（get_cmdline_user_args 在部分调用下为空，改用全量 args 兜底）
	for a in OS.get_cmdline_args():
		if a == "main_hub" or a == "editor" or a.begins_with("res://"):
			arg = a
		elif a.begins_with("--res "):
			var parts: PackedStringArray = a.trim_prefix("--res ").split("x")
			if parts.size() == 2:
				DisplayServer.window_set_size(Vector2i(int(parts[0]), int(parts[1])))
				root.size = Vector2i(int(parts[0]), int(parts[1]))
				print("SCREENSHOT_RES=", parts[0], "x", parts[1])
	var scenes := _resolve_scenes(arg)
	print("SCREENSHOT_SCENES=", scenes)
	_shot_all(scenes)

func _resolve_scenes(arg: String) -> Array[String]:
	if arg.is_empty() or arg == "main_hub":
		return ["res://scenes/main/main_hub.tscn"]
	if arg == "editor":
		return ["res://scenes/editor/script_editor.tscn"]
	return [arg]

func _shot_all(scenes: Array[String]) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var n := 0
	for sc in scenes:
		var shot := await _shot_one(sc)
		if shot:
			n += 1
	print("SCREENSHOT_OK=", n, "/", scenes.size())
	quit(n == scenes.size() and n > 0)

func _shot_one(scene_path: String) -> bool:
	var packed = load(scene_path)
	if packed == null:
		print("SCREENSHOT_LOAD_FAIL ", scene_path)
		return false
	var inst = packed.instantiate()
	root.add_child(inst)
	# 等渲染稳定（timer 驱动，不依赖 frame_post_draw——headless dummy 下该信号不触发）
	await create_timer(0.9).timeout
	var vp := root.get_viewport()
	var img := vp.get_texture().get_image()
	if img == null or img.is_empty():
		print("SCREENSHOT_EMPTY_IMAGE ", scene_path, " (headless 无渲染?)")
		inst.queue_free()
		return false
	var name := scene_path.get_file().get_basename()
	var out := ProjectSettings.globalize_path(OUT_DIR) + "/" + name + ".png"
	var err := img.save_png(out)
	print("SCREENSHOT_SAVE err=", err, " ", out, " size=", img.get_width(), "x", img.get_height())
	inst.queue_free()
	return err == OK
