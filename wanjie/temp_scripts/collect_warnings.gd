extends SceneTree
func _initialize() -> void:
	var total_warn := 0
	var files := _collect_gd("res://scripts")
	files.append_array(_collect_gd("res://resources/data"))
	files.append_array(_collect_gd("res://autoload"))
	print("SCANNED ", files.size(), " scripts")
	for f in files:
		var s = load(f)
		if s == null or not (s is GDScript):
			continue
		var g: GDScript = s
		if g.get_script_method_list().is_empty() and g.get_script_property_list().is_empty() and g.get_script_signal_list().is_empty():
			pass
		# 触发编译检查警告
		var warnings = g.get_warnings()
		if warnings != null and warnings.size() > 0:
			total_warn += warnings.size()
			for w in warnings:
				print("WARN ", f, " :: ", w)
	print("TOTAL_WARNINGS=", total_warn)
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
