## 2D/3D 场景编辑器测试: 建场景→编辑→导出/导入一致→场景代码转译
extends SceneTree

func _make_scene() -> Dictionary:
	return {
		"name": "TestScene", "type": "Control", "props": {}, "children": [
			{"name": "Panel1", "type": "PanelContainer", "props": {"position": Vector2(10, 10), "size": Vector2(200, 100)}, "children": [
				{"name": "Btn", "type": "Button", "props": {"position": Vector2(20, 20), "size": Vector2(80, 32), "text": "OK"}, "children": []},
			]},
			{"name": "Lbl", "type": "Label", "props": {"position": Vector2(0, 200), "size": Vector2(300, 24)}, "children": []},
		],
	}

func _initialize() -> void:
	# === 2D 编辑器 ===
	var ed2d = load("res://scripts/editor/scene_editor_2d.gd").new()
	var host := Control.new()
	root.add_child(host)
	ed2d.build_into(host)
	ed2d.load_scene_data(_make_scene())

	var data: Dictionary = ed2d.get_scene_data()
	assert(data.get("name", "") == "TestScene", "场景名应保留")
	var children: Array = data.get("children", [])
	assert(children.size() == 2, "应含 2 个顶层节点")
	var panel: Dictionary = children[0]
	assert(panel.get("type", "") == "PanelContainer", "类型应保留")
	var btn: Dictionary = panel["children"][0]
	assert(btn["props"].get("text", "") == "OK", "文本属性应保留")

	# 编辑: 移动节点 + 修改属性
	btn["props"]["position"] = Vector2(50, 50)
	btn["props"]["text"] = "确定"
	ed2d._save_undo_state()  # 模拟编辑提交

	# 导出 JSON → 导入一致
	var json_str: String = ed2d.export_json()
	var ed2d_b = load("res://scripts/editor/scene_editor_2d.gd").new()
	ed2d_b.build_into(host)
	assert(ed2d_b.import_json(json_str), "JSON 导入应成功")
	var data2: Dictionary = ed2d_b.get_scene_data()
	var btn2: Dictionary = data2["children"][0]["children"][0]
	assert(ed2d_b._get_node_pos(btn2) == Vector2(50, 50), "编辑后的位置应保留")
	assert(btn2["props"].get("text", "") == "确定", "编辑后的文本应保留")
	# export_tscn 可生成
	assert(ed2d_b.export_tscn().begins_with("[gd_scene format=3]"), "应导出 tscn 头")
	print("PASS 2D editor edit & json roundtrip")

	# 对齐工具: 选中两个节点执行左对齐
	ed2d_b._selected_nodes.clear()
	ed2d_b._selected_nodes.append(data2["children"][0])
	ed2d_b._selected_nodes.append(data2["children"][1])
	ed2d_b._align_left()
	var aligned: Array = ed2d_b.get_scene_data()["children"]
	var x0: float = ed2d_b._get_node_pos(aligned[0]).x
	var x1: float = ed2d_b._get_node_pos(aligned[1]).x
	assert(x0 == x1, "左对齐后 x 应相等")
	# 锚点预设
	ed2d_b._apply_anchor_preset("full_rect")
	var anchored: Dictionary = ed2d_b.get_scene_data()["children"][0]["props"]
	assert(anchored.get("anchors_preset", "") == "full_rect", "锚点预设应写入")
	print("PASS 2D align & anchor tools")

	# === 3D 编辑器 ===
	var ed3d = load("res://scripts/editor/scene_editor_3d.gd").new()
	var host3 := Control.new()
	root.add_child(host3)
	ed3d.build_into(host3)
	ed3d.load_scene_data({"name": "Arena", "type": "Node3D", "props": {}, "children": [
		{"name": "Ground", "type": "MeshInstance3D", "props": {"position": Vector3(0, 0, 0)}, "children": []},
	]})
	var d3: Dictionary = ed3d.get_scene_data()
	assert(d3["children"][0].get("name", "") == "Ground", "3D 节点应保留")
	var json3: String = ed3d.export_json()
	var ed3d_b = load("res://scripts/editor/scene_editor_3d.gd").new()
	ed3d_b.build_into(host3)
	assert(ed3d_b.import_json(json3), "3D JSON 导入应成功")
	assert(ed3d_b.get_scene_data()["children"][0].get("name", "") == "Ground", "3D 往返应一致")
	print("PASS 3D editor load/export/import")

	print("ALL_TESTS_PASSED")
	quit(0)
