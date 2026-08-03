## 场景编辑落代码测试: metadata.scene_2d/scene_3d ↔ 代码章节双向转译
extends SceneTree

func _initialize() -> void:
	var ScriptCodeGenClass = load("res://scripts/editor/script_codegen.gd")
	var ws := WorldScriptData.new()
	ws.id = "scene_test"
	ws.ensure_subsystems()
	# 构造 2D 场景数据（scene_editor_2d 导出的结构）
	ws.metadata["scene_2d"] = {
		"name": "MainMenu",
		"type": "Control",
		"props": {},
		"children": [
			{"name": "Background", "type": "ColorRect", "props": {"position": Vector2(0, 0), "size": Vector2(1280, 720), "anchors_preset": "full_rect"}, "children": []},
			{"name": "StartBtn", "type": "Button", "props": {"position": Vector2(560, 340), "size": Vector2(160, 48), "text": "开始游戏"}, "children": [
				{"name": "Label1", "type": "Label", "props": {"position": Vector2(5, 5), "size": Vector2(100, 20)}, "children": []},
			]},
		],
	}
	# 3D 场景
	ws.metadata["scene_3d"] = {
		"name": "Arena",
		"type": "Node3D",
		"props": {},
		"children": [
			{"name": "Ground", "type": "MeshInstance3D", "props": {"position": Vector3(0, 0, 0)}, "children": []},
			{"name": "PlayerSpawn", "type": "Marker3D", "props": {"position": Vector3(2, 0, 2)}, "children": []},
		],
	}
	# === 1. generate 包含场景章节 ===
	var code: String = ScriptCodeGenClass.generate(ws)
	assert(code.find("# === 2D 场景 ===") >= 0, "应生成 2D 场景章节")
	assert(code.find("control \"StartBtn\" type=\"Button\"") >= 0, "应包含按钮节点行")
	assert(code.find("anchors_preset=\"full_rect\"") >= 0, "应包含锚点属性")
	assert(code.find("# === 3D 场景 ===") >= 0, "应生成 3D 场景章节")
	assert(code.find("control \"PlayerSpawn\"") >= 0, "应包含 3D 节点")
	print("PASS generate scene sections")

	# === 2. parse 解析场景章节回数据 ===
	var ws2 := WorldScriptData.new()
	ws2.name = "x"
	ws2.ensure_subsystems()
	var pr: Dictionary = ScriptCodeGenClass.parse(code, ws2)
	assert(pr.get("success", false), "解析应成功")
	assert(ws2.metadata.has("scene_2d"), "应解析回 scene_2d")
	var s2: Dictionary = ws2.metadata["scene_2d"]
	assert(not s2.get("children", []).is_empty(), "scene_2d 应有子节点")
	var children: Array = s2["children"]
	assert(children.size() == 2, "应有 2 个顶层节点")
	var start_btn: Dictionary = children[1]
	assert(start_btn.get("name", "") == "StartBtn", "按钮名应保留")
	assert(start_btn.get("type", "") == "Button", "类型应保留")
	assert(start_btn["props"].has("anchors_preset") == false, "StartBtn 无锚点")
	var bg: Dictionary = children[0]
	assert(bg["props"].get("anchors_preset", "") == "full_rect", "背景锚点应保留")
	assert(bg["props"].get("size") is Vector2 and bg["props"]["size"] == Vector2(1280, 720), "尺寸应保留为 Vector2")
	# 嵌套子节点
	var btn_children: Array = start_btn.get("children", [])
	assert(btn_children.size() == 1 and btn_children[0].get("name", "") == "Label1", "嵌套子节点应保留")
	# 3D
	assert(ws2.metadata.has("scene_3d"), "应解析回 scene_3d")
	var s3: Dictionary = ws2.metadata["scene_3d"]
	var s3_children: Array = s3.get("children", [])
	assert(s3_children.size() == 2, "3D 场景应有 2 节点")
	print("PASS parse scene sections back to data")

	# === 3. 往返一致: 重新 generate 得到相同场景代码 ===
	var code2: String = ScriptCodeGenClass.generate(ws2)
	var extract := func(c: String) -> String:
		var start := c.find("# === 2D 场景")
		if start < 0:
			return ""
		var end := c.find("# === 3D 场景", start)
		if end < 0:
			end = c.length()
		return c.substr(start, end - start)
	assert(extract.call(code) == extract.call(code2), "scene 章节往返应一致")
	print("PASS scene roundtrip stable")

	print("ALL_TESTS_PASSED")
	quit(0)
