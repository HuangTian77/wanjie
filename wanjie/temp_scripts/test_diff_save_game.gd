## 临时验证脚本: SaveManager 差分存档测试
extends SceneTree

func _initialize() -> void:
	var sm = load("res://scripts/autoload/save_manager.gd").new()

	# === 1. 手动存档（完整快照 + 刷新 base）===
	sm.start_new_game("save_test_script")
	sm.current_save.player_state = {"name": "测试旅者", "level": 1, "hp": 100}
	sm.current_save.world_state = {"time": "第1天"}
	var ok: bool = sm.save_game(0, false)
	assert(ok, "手动存档应成功")
	assert(FileAccess.file_exists(sm._get_base_path("save_test_script")), "base.json 应生成")
	print("PASS manual save (full + base)")

	# === 2. 自动存档（差分: 仅变化字段）===
	sm.current_save.player_state["level"] = 5  # 只改 level
	var ok2: bool = sm.save_game(0, true)
	assert(ok2, "自动存档应成功")
	var delta_path: String = sm._get_save_path("save_test_script", 0, true)
	var f := FileAccess.open(delta_path, FileAccess.READ)
	var j := JSON.new()
	j.parse(f.get_as_text())
	f.close()
	var payload: Dictionary = j.data
	assert(payload.get("format") == 2, "差分文件应有 format=2")
	assert(payload.has("delta"), "差分文件应有 delta")
	var delta: Dictionary = payload["delta"]
	assert(delta.has("player_state"), "player_state 应在 delta 中")
	assert(not delta.has("world_state"), "未变化字段不应在 delta 中")
	print("PASS autosave delta only changed fields")

	# === 3. 加载差分存档（与 base 合并还原）===
	var loaded = sm.load_game(0, true)
	assert(loaded != null, "差分加载应成功")
	assert(loaded.player_state.get("level") == 5, "level 应从 delta 恢复")
	assert(loaded.player_state.get("name") == "测试旅者", "name 应从 base 恢复")
	assert(loaded.world_state.get("time") == "第1天", "world_state 应从 base 恢复")
	print("PASS load merges base + delta")

	# === 4. list_saves 显示信息（差分文件也能读）===
	var saves: Array = sm.list_saves("save_test_script")
	assert(saves.size() >= 1, "应列出存档")
	var found_autosave := false
	for s in saves:
		if s.get("is_autosave", false):
			found_autosave = true
			assert(s.get("player_name") == "测试旅者", "列表应显示 base 中的玩家名")
	assert(found_autosave, "应找到自动存档")
	print("PASS list_saves reads delta info")

	# === 5. 旧格式兼容（完整快照文件仍可直接加载）===
	var loaded2 = sm.load_game(0, false)
	assert(loaded2 != null, "手动存档加载应正常")
	assert(loaded2.player_state.get("level") == 1, "手动存档应恢复其自身快照(level=1)")
	print("PASS legacy full save load")

	# 清理
	var dir := DirAccess.open(sm._get_save_dir("save_test_script"))
	if dir:
		dir.list_dir_begin()
		var e := dir.get_next()
		while e != "":
			if e != "." and e != "..":
				DirAccess.remove_absolute(sm._get_save_dir("save_test_script") + e)
			e = dir.get_next()
	DirAccess.remove_absolute(sm._get_save_dir("save_test_script"))
	print("ALL_TESTS_PASSED")
	quit(0)
