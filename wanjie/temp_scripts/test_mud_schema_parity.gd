## MUD schema 一致性: gameinit.sql(28表) ↔ mud_schema_internal.TABLES + 导出文件清单 parity
extends SceneTree

func _initialize() -> void:
	var SchemaInternal = load("res://scripts/editor/mud/mud_schema_internal.gd")
	var internal_tables: Dictionary = SchemaInternal.TABLES
	var internal_names: Array[String] = []
	for t in internal_tables:
		internal_names.append(str(t).to_lower())
	assert(internal_names.size() == 28, "内部 schema 应有 28 表, 实际 %d" % internal_names.size())
	print("PASS internal schema has 28 tables")

	# === 1. gameinit.sql 表名 ↔ 内部 schema ===
	var abs_path := "E:/ZX/QWXM/WJSP/XM1/ME/_spk_extract/app/libs/gameinit.sql"
	var sql_tables: Array[String] = []
	var f := FileAccess.open(abs_path, FileAccess.READ)
	if f != null:
		var text := f.get_as_text()
		var lower := text.to_lower()
		var pos := 0
		while true:
			var idx := lower.find("create table", pos)
			if idx < 0:
				break
			var name_start := idx + 13
			var name_end := -1
			for ci in range(name_start, lower.length()):
				var c := lower[ci]
				if c == " " or c == "(" or c == "\n" or c == "\t":
					name_end = ci
					break
			if name_end < 0:
				break
			var tname := lower.substr(name_start, name_end - name_start).strip_edges()
			if not tname.is_empty():
				sql_tables.append(tname)
			pos = name_end
	if sql_tables.is_empty():
		print("SKIP sql parity (file not accessible)")
	else:
		assert(sql_tables.size() == 28, "gameinit.sql 应有 28 张表, 实际 %d" % sql_tables.size())
		var missing: Array[String] = []
		for t in sql_tables:
			if not internal_names.has(t):
				missing.append(t)
		if missing.is_empty():
			print("PASS all %d sql tables present in internal schema" % sql_tables.size())
		else:
			assert(false, "内部 schema 缺失表: %s" % str(missing))
		var extra: Array[String] = []
		for t in internal_names:
			if not sql_tables.has(t):
				extra.append(t)
		if not extra.is_empty():
			print("NOTE internal extra tables: ", extra)

	# === 2. 导出文件清单 parity（MudExport txt vs ME/testsvr/data） ===
	var testsvr_files: Array[String] = []
	var testsvr := "E:/ZX/QWXM/WJSP/XM1/ME/testsvr/data"
	if DirAccess.dir_exists_absolute(testsvr):
		var d := DirAccess.open(testsvr)
		d.list_dir_begin()
		var e := d.get_next()
		while e != "":
			if e.ends_with(".txt"):
				testsvr_files.append(e)
			e = d.get_next()
		d.list_dir_end()
	var engine_files: Array[String] = []
	var engine_dir := "E:/ZX/QWXM/WJSP/XM1/wanjie/mud_engine/data"
	if DirAccess.dir_exists_absolute(engine_dir):
		var d2 := DirAccess.open(engine_dir)
		d2.list_dir_begin()
		var e2 := d2.get_next()
		while e2 != "":
			if e2.ends_with(".txt"):
				engine_files.append(e2)
			e2 = d2.get_next()
		d2.list_dir_end()
	if testsvr_files.is_empty() or engine_files.is_empty():
		print("SKIP export file parity (no data dirs)")
	else:
		testsvr_files.sort()
		engine_files.sort()
		assert(testsvr_files.size() == engine_files.size(), "导出文件数应一致: testsvr=%d engine=%d" % [testsvr_files.size(), engine_files.size()])
		var diff: Array[String] = []
		for i in testsvr_files.size():
			if testsvr_files[i] != engine_files[i]:
				diff.append("%s vs %s" % [testsvr_files[i], engine_files[i]])
		if diff.is_empty():
			print("PASS export file list parity (%d files)" % testsvr_files.size())
		else:
			assert(false, "导出文件清单不一致: %s" % str(diff))

	print("ALL_TESTS_PASSED")
	quit(0)
