extends SceneTree
func _initialize() -> void:
	var files := _collect_gd("res://scripts")
	files.append_array(_collect_gd("res://resources/data"))
	files.append_array(_collect_gd("res://autoload"))
	files.append_array(_collect_gd("res://temp_scripts"))
	var errs := 0
	for f in files:
		var s = load(f)
		if s == null:
			errs += 1
			print("LOAD_FAIL ", f)
	print("COMPILED ", files.size(), " LOAD_FAIL=", errs)
	quit(0)
func _collect_gd(dir_path: String) -> Array[String]:
	var result: Array[String] = []
	var d := DirAccess.open(dir_path)
	if d == null:
		return result
	d.list_dir_begin()
	var e := d.get_next()
	while e != "":
		if e.begins_with("."):
			e = d.get_next()
			continue
		var full := dir_path + "/" + e
		if d.current_is_dir():
			result.append_array(_collect_gd(full))
		elif e.ends_with(".gd"):
			result.append(full)
		e = d.get_next()
	d.list_dir_end()
	return result
