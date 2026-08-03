extends SceneTree
func _initialize() -> void:
	# 实例化底部面板并构建 UI
	var panel = load("res://scripts/editor/ide/ide_bottom_panel.gd").new()
	panel._build_ui()  # 手动构建
	# 验证资源面板结构
	assert(panel._audio_placeholder != null, "音频面板应存在")
	assert(panel._anim_placeholder != null, "动画面板应存在")
	# 扫描功能
	var items: Array = panel._scan_dir("res://assets/audio")
	assert(items is Array, "扫描应返回数组")
	print("PASS bottom panel build, audio_items=", items.size())
	panel.queue_free()
	print("ALL_TESTS_PASSED")
	quit(0)
