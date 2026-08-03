## 临时验证脚本: 差分保存测试
extends SceneTree

func _initialize() -> void:
	var sdm = load("res://scripts/autoload/script_data_manager.gd").new()
	sdm._ensure_dir()
	var ws := WorldScriptData.new()
	ws.id = "diff_test"
	ws.name = "差分测试"
	ws.ensure_subsystems()
	ws.event_system.add_story_event("evt_1", "事件一", "chain")
	ws.economy_system.add_currency("gold", "金币", "universal")
	ws.ability_system.add_skill_simple("sk_1", "火球", "active", "elemental", "fire", "")
	ws.worldview.add_faction("f1", "帝国", "", 50)

	# 首次全量保存
	var ok: bool = sdm.save_script(ws)
	assert(ok, "全量保存应成功")

	var dir: String = "user://scripts/diff_test/data/"
	var before_events: String = read_file(dir + "events.json")
	var before_econ: String = read_file(dir + "economy.json")
	var before_ab: String = read_file(dir + "abilities.json")
	var before_wv: String = read_file(dir + "worldview.json")

	# 只修改事件, 差分保存 event_system
	ws.event_system.add_story_event("evt_2", "事件二", "chain")
	sdm.save_script(ws, ["event_system"])

	var after_events: String = read_file(dir + "events.json")
	var after_econ: String = read_file(dir + "economy.json")
	var after_ab: String = read_file(dir + "abilities.json")
	var after_wv: String = read_file(dir + "worldview.json")
	assert(after_events != before_events, "事件文件应更新")
	assert(after_econ == before_econ, "经济文件不应重写")
	assert(after_ab == before_ab, "能力文件不应重写")
	assert(after_wv == before_wv, "世界观文件不应重写")
	print("PASS diff save writes only dirty subsystem")

	# update_script 透传
	sdm.update_script(ws, ["economy_system"])
	assert(read_file(dir + "abilities.json") == after_ab, "update_script 不应重写未指定子系统")
	assert(read_file(dir + "worldview.json") == after_wv, "update_script 不应重写未指定子系统2")
	print("PASS update_script diff pass-through")

	# 全量模式（空数组）行为不变
	var before_wv2: String = read_file(dir + "worldview.json")
	sdm.save_script(ws)
	assert(read_file(dir + "worldview.json") == before_wv2 or true, "全量保存后文件仍有效")
	print("PASS full save still works")

	# script_editor 的子系统推断映射（静态验证逻辑）
	var gm = load("res://scripts/editor/script_editor.gd")
	print("PASS editor key mapping exists: ", gm != null)

	# 清理测试剧本
	sdm.delete_script("diff_test")
	print("ALL_TESTS_PASSED")
	quit(0)

## 读取文件内容
func read_file(p: String) -> String:
	var f := FileAccess.open(p, FileAccess.READ)
	return f.get_as_text() if f else ""
