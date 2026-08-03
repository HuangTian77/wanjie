## MUD 全流程测试: MudData 增删改/级联/导出33txt/导入回读 + 搜索过滤
extends SceneTree

func _initialize() -> void:
	var MudDataClass = load("res://scripts/editor/mud/mud_data.gd")
	var mud = MudDataClass.new()

	# === 1. 建场景与对象（级联关系） ===
	var scene_id: Variant = mud.add_row("scene", {"id": 1, "name": "新手村", "desc": "起点"})
	assert(scene_id != null, "应能添加场景")
	mud.add_row("scene", {"id": 2, "name": "主城", "desc": "中心"})
	# 场景对象
	mud.add_row("scene_object", {"sceneid": 1, "objid": 101, "name": "村长"})
	mud.add_row("scene_object", {"sceneid": 1, "objid": 102, "name": "商人"})
	# 路径
	mud.add_row("linkpath", {"id": 1, "startpot": 1, "endpot": 2, "direct": 1, "cost": 10})
	# 物品/技能
	mud.add_row("item", {"id": 1, "name": "铁剑", "type": "weapon"})
	mud.add_row("skill", {"id": 1, "name": "火球术", "level": 1})
	assert(mud.get_table("scene").size() == 2, "应有 2 个场景")
	assert(mud.get_table("scene_object").size() == 2, "应有 2 个场景对象")
	print("PASS add rows & relations")

	# === 2. 修改 + 删除 ===
	mud.update_row("scene", 1, {"name": "新手村(扩建)"})
	var updated: Dictionary = mud.get_table("scene")[0]
	assert(updated.get("name", "") == "新手村(扩建)", "update 应生效")
	mud.delete_rows_where("scene_object", "objid", 102)
	assert(mud.get_table("scene_object").size() == 1, "删除应生效")
	print("PASS update & delete")

	# === 3. 级联删除场景 ===
	mud.del_scene(1)
	assert(mud.get_table("scene").size() == 1, "级联后应剩 1 场景")
	assert(mud.get_table("scene_object").size() == 0, "场景对象应级联删除")
	var remain_paths: Array = mud.get_table("linkpath")
	var path_ok := true
	for p in remain_paths:
		if str(p.get("startpot", "")) == "1" or str(p.get("endpot", "")) == "1":
			path_ok = false
	assert(path_ok, "路径应级联清理")
	print("PASS cascade delete")

	# === 4. 导出 33 txt 到临时目录 ===
	var MudExportClass = load("res://scripts/editor/mud/mud_export.gd")
	var exporter = MudExportClass.new(mud)
	var tmp_dir := "user://mud_test_export"
	DirAccess.make_dir_recursive_absolute(tmp_dir)
	var count: int = exporter.write_all(tmp_dir)
	assert(count > 0, "导出应生成文件, 实际 %d" % count)
	var files: Array[String] = []
	var d := DirAccess.open(tmp_dir)
	d.list_dir_begin()
	var e := d.get_next()
	while e != "":
		if e.ends_with(".txt"):
			files.append(e)
		e = d.get_next()
	d.list_dir_end()
	assert(files.size() == count, "导出文件数应一致")
	print("PASS export %d txt files" % count)

	# === 5. 导入回读（尽力映射, 主要表可回读） ===
	var MudImportClass = load("res://scripts/editor/mud/mud_import.gd")
	var mud2 = MudImportClass.from_dir(tmp_dir)
	assert(mud2 != null, "导入应返回数据")
	assert(mud2.get_table("scene").size() >= 1, "导入应回读场景")
	print("PASS import roundtrip (scene count=%d)" % mud2.get_table("scene").size())

	# === 6. 表 Widget 搜索过滤 ===
	var WidgetClass = load("res://scripts/editor/mud/mud_table_widget.gd")
	var w = WidgetClass.new()
	w.data = mud2
	w.table_name = "scene"
	# 不实例化 Tree（无容器）, 只测行匹配逻辑
	w._filter_text = "主城"
	assert(w._row_matches({"id": 2, "name": "主城"}), "过滤应匹配主城")
	assert(not w._row_matches({"id": 9, "name": "荒野"}), "过滤不应匹配荒野")
	w.set_filter("")
	assert(w._filter_text == "", "清空过滤应恢复")
	print("PASS table widget filter")

	# 清理临时目录
	if DirAccess.dir_exists_absolute(tmp_dir):
		DirAccess.remove_absolute(tmp_dir)

	print("ALL_TESTS_PASSED")
	quit(0)
