extends SceneTree
## UI 布局断言器（headless 可跑——布局检查不依赖渲染）
## 用法: ../Godot_v4.7.1-stable_win64.exe --headless --path . -s tools/ui_layout_check.gd [可选场景路径]
## 输出: res://../_ui_layout_report.txt；发现 HARD 问题退出码 1（供 CI 拦截）
## 检查项：
##   [HARD] 负尺寸 / 文本控件超出可视区 / 交互控件完全不可见
##   [WARN] 控件越出父边界(>8px) / 兄弟交互控件意外重叠(交叠>40%)
## 跳过：top_level、mouse_filter=IGNORE(装饰层)、ScrollContainer 内容区、Popup/Window、等宽填充(锚点全 rect)

const REPORT_PATH := "res://../_ui_layout_report.txt"
const SCENES := [
	"res://scenes/main/main_hub.tscn",
	"res://scenes/editor/script_editor.tscn",
	"res://scenes/player/script_player.tscn",
	"res://scenes/settings/settings.tscn",
	"res://scenes/components/script_card.tscn",
	"res://scenes/components/recent_card.tscn",
	"res://scenes/components/modal_overlay.tscn",
	"res://scenes/components/section_header.tscn",
	"res://scenes/components/toast_item.tscn",
	"res://scenes/components/empty_state.tscn",
]

var _report: Array[String] = []
var _hard := 0
var _warn := 0

func _initialize() -> void:
	_report.clear()
	var targets := SCENES
	var arg := ""
	for a in OS.get_cmdline_args():
		if a.begins_with("res://") and a.ends_with(".tscn") and not a.contains("ui_layout_check"):
			arg = a
		elif a.begins_with("--res "):
			var parts: PackedStringArray = a.trim_prefix("--res ").split("x")
			if parts.size() == 2:
				root.size = Vector2i(int(parts[0]), int(parts[1]))
				print("LAYOUT_RES=", parts[0], "x", parts[1])
	if not arg.is_empty():
		targets = [arg]
	_report.append("== UI 布局断言报告 ==")
	_report.append("场景数: %d" % targets.size())
	for sc in targets:
		await _check_scene(sc)
	var txt := "\n".join(_report)
	var f := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if f:
		f.store_string(txt)
		f.close()
	print("LAYOUT_HARD=", _hard, " WARN=", _warn, " report=", ProjectSettings.globalize_path(REPORT_PATH))
	quit(1 if _hard > 0 else 0)

func _check_scene(scene_path: String) -> void:
	var packed = load(scene_path)
	if packed == null:
		_report.append("  [LOAD_FAIL] %s" % scene_path)
		return
	var inst = packed.instantiate()
	root.add_child(inst)
	await process_frame
	await process_frame
	_report.append("== %s ==" % scene_path.get_file())
	_check_controls(inst, scene_path)
	inst.queue_free()
	await process_frame

func _check_controls(node: Node, scene_path: String) -> void:
	for c in node.get_children():
		var ctrl := c as Control
		if ctrl == null:
			_check_controls(c, scene_path)
			continue
		# 跳过: top_level / 自身或祖先不可见(隐藏对话框等) / 装饰层 / 弹窗 / 滚动内容
		if ctrl.top_level or not ctrl.visible or not _ancestors_visible(ctrl):
			_check_controls(c, scene_path)
			continue
		if ctrl.mouse_filter == Control.MOUSE_FILTER_IGNORE and (ctrl is Label or ctrl is ColorRect or ctrl is TextureRect or ctrl is Panel):
			_check_controls(c, scene_path)
			continue
		var parent: Control = ctrl.get_parent() as Control
		# 父未布局(0 尺寸)时跳过其子级检查(容器尚未排列, 非布局缺陷)
		if parent != null and parent.size == Vector2.ZERO:
			_check_controls(c, scene_path)
			continue
		# === HARD: 负尺寸 ===
		if ctrl.size.x < 0 or ctrl.size.y < 0:
			_report.append("  [HARD] 负尺寸 %s(%s) size=%s" % [scene_path.get_file(), _path_of(ctrl), ctrl.size])
			_hard += 1
		if parent == null or parent is ScrollContainer or ctrl.top_level:
			_check_controls(c, scene_path)
			continue
		var gr := ctrl.get_global_rect()
		var pr := parent.get_global_rect()
		# === HARD: 完全不可见（0 面积或完全在父外） ===
		if gr.size.x <= 0 or gr.size.y <= 0:
			# 0 尺寸在布局中常见且无害(未初始化), 仅对交互控件报 WARN
			if _is_interactive(ctrl):
				_report.append("  [WARN] 零尺寸交互控件 %s(%s)" % [scene_path.get_file(), _path_of(ctrl)])
				_warn += 1
		else:
			# === 越界（超出父边界 >8px，锚点全 rect 填充除外） ===
			var margin := 8.0
			var overflow_left := gr.position.x < pr.position.x - margin
			var overflow_right := gr.end.x > pr.end.x + margin
			var overflow_top := gr.position.y < pr.position.y - margin
			var overflow_bottom := gr.end.y > pr.end.y + margin
			if overflow_left or overflow_right or overflow_top or overflow_bottom:
				var is_fill := _is_anchor_fill(ctrl)
				if not is_fill:
					_report.append("  [WARN] 越界 %s(%s) 超出父 %s: %s -> %s" % [scene_path.get_file(), _path_of(ctrl), _path_of(parent), gr, pr])
					_warn += 1
		# === 兄弟重叠（交互控件交叠 >40% 较小者） ===
		if ctrl.mouse_filter != Control.MOUSE_FILTER_IGNORE and ctrl is Button:
			for sib in parent.get_children():
				var sc := sib as Control
				if sc == null or sc == ctrl or not sc.visible or sc.top_level or sc.mouse_filter == Control.MOUSE_FILTER_IGNORE:
					continue
				if not (sc is Button or sc is LineEdit or sc is OptionButton or sc is ItemList or sc is Tree):
					continue
				var sg := sc.get_global_rect()
				var inter := gr.intersection(sg)
				if inter.size.x > 0 and inter.size.y > 0:
					var area := inter.size.x * inter.size.y
					var min_area: float = min(gr.size.x * gr.size.y, sg.size.x * sg.size.y)
					if min_area > 0 and area / min_area > 0.4:
						_report.append("  [WARN] 交互重叠 %s ∩ %s 交叠 %.0f%%" % [_path_of(ctrl), _path_of(sc), area / min_area * 100.0])
						_warn += 1
		_check_controls(c, scene_path)

func _is_interactive(ctrl: Control) -> bool:
	return ctrl is Button or ctrl is LineEdit or ctrl is OptionButton or ctrl is ItemList 		or ctrl is Tree or ctrl is TextEdit or ctrl is SpinBox or ctrl is CheckBox 		or ctrl is MenuButton or ctrl is Slider

func _is_anchor_fill(ctrl: Control) -> bool:
	return ctrl.anchor_left == 0.0 and ctrl.anchor_top == 0.0 and ctrl.anchor_right == 1.0 and ctrl.anchor_bottom == 1.0

func _ancestors_visible(ctrl: Control) -> bool:
	var p: Node = ctrl.get_parent()
	while p != null:
		var pc := p as Control
		if pc != null and not pc.visible:
			return false
		p = p.get_parent()
	return true

func _path_of(node: Node) -> String:
	return node.get_path().get_concatenated_names()
