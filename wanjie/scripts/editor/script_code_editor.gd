## 核心编辑器模式主控制器 - 复刻 Godot 4.7.1 编辑器布局
## 组装: 菜单栏 + 顶栏 + 左Dock(场景/文件) + 中央工作区 + 底部面板 + 右Dock(检查器) + 状态栏
## 公共API保持兼容: build_into/load_data/get_code/apply_code/validate_code/export_code/import_code/insert_template
extends Control

const ScriptCodeGenClass = preload("res://scripts/editor/script_codegen.gd")
const IDETheme = preload("res://scripts/editor/ide/ide_theme.gd")
const IDEMenuBarClass = preload("res://scripts/editor/ide/ide_menu_bar.gd")
const IDETopBarClass = preload("res://scripts/editor/ide/ide_top_bar.gd")
const IDEDockLeftClass = preload("res://scripts/editor/ide/ide_dock_left.gd")
const IDEDockRightClass = preload("res://scripts/editor/ide/ide_dock_right.gd")
const IDEWorkspaceClass = preload("res://scripts/editor/ide/ide_workspace.gd")
const IDEBottomPanelClass = preload("res://scripts/editor/ide/ide_bottom_panel.gd")
const IDEStatusBarClass = preload("res://scripts/editor/ide/ide_status_bar.gd")
const IDESettingsDialogClass = preload("res://scripts/editor/ide/ide_settings_dialog.gd")
const IDEAboutDialogClass = preload("res://scripts/editor/ide/ide_about_dialog.gd")
const IDEShortcutsDialogClass = preload("res://scripts/editor/ide/ide_shortcuts_dialog.gd")

var world_script: WorldScriptData = null
var on_code_applied: Callable = Callable()
var on_validation_done: Callable = Callable()

const AUTO_SAVE_INTERVAL := 60.0

# === UI模块引用 ===
var _menu_bar: HBoxContainer
var _top_bar: HBoxContainer
var _dock_left: PanelContainer
var _dock_right: PanelContainer
var _workspace: Control
var _bottom_panel: VBoxContainer
var _find_bar: HBoxContainer = null
var _find_input: LineEdit = null
var _replace_input: LineEdit = null
var _last_find_pos: int = -1
var _find_query: String = ""
var _status_bar: HBoxContainer
var _main_hsplit: HSplitContainer
var _center_vsplit: VSplitContainer

# === 代码编辑状态 ===
var _tabs: Dictionary = {}
var _current_tab: int = -1
var _tab_counter: int = 0
var _validate_timer: Timer = null
var _auto_save_timer: Timer = null
var _error_lines: Array[int] = []
var _bottom_panel_height: int = IDETheme.BOTTOM_PANEL_DEFAULT_HEIGHT

# === 文件对话框 ===
var _export_dialog: FileDialog
var _import_dialog: FileDialog
var _save_dialog: FileDialog
var _open_dialog: FileDialog
var _settings_dialog: AcceptDialog
var _about_dialog: AcceptDialog
var _shortcuts_dialog: AcceptDialog

# === 场景撤销重做 ===
var _scene_undo: Dictionary = {}
var _scene_last_snapshot: Dictionary = {}

# === 场景文件追踪 (真实文件I/O) ===
## 当前2D/3D场景对应的磁盘文件路径 ("" = 未保存到独立文件)
var _scene_file_paths: Dictionary = {"2d": "", "3d": ""}
## 新建场景/脚本命名对话框
var _new_scene_dialog: ConfirmationDialog
var _new_scene_input: LineEdit
var _new_script_dialog: ConfirmationDialog
var _new_script_input: LineEdit
## 导出项目对话框
var _export_project_dialog: FileDialog

func _ready() -> void:
	pass

func build_into(parent: Node) -> void:
	_build_ui(parent)
	_create_new_tab("main.gd", "")

# ============================================================
# 公共接口
# ============================================================

func load_data(ws: WorldScriptData) -> void:
	world_script = ws
	if ws == null:
		_set_active_text("# 未加载剧本数据\n")
		return
	_set_active_text(ScriptCodeGenClass.generate(ws))
	_update_scene_tree()
	_load_scene_editors_data(ws)
	_log("已加载剧本数据: %s" % ws.name, IDETheme.C_GREEN)
	if _top_bar:
		_top_bar.set_scene_title(ws.name + " - 万界诗篇编辑器")
	if _dock_left:
		_dock_left.get_file_system().set_script_root(ws.id)
	_update_script_panel()
	# 重置场景文件路径追踪 (加载新剧本时清除旧路径)
	_scene_file_paths = {"2d": "", "3d": ""}

func get_code() -> String:
	return _get_active_text()

func apply_code() -> Dictionary:
	if world_script == null:
		_log("错误: 未加载剧本", IDETheme.C_RED)
		return {"success": false, "errors": ["未加载剧本"], "warnings": []}
	var result: Dictionary = ScriptCodeGenClass.parse(_get_active_text(), world_script)
	if result["success"]:
		_log("代码已应用 (%d 警告)" % result["warnings"].size(), IDETheme.C_GREEN)
		_set_tab_modified(false)
		_update_scene_tree()
	else:
		_log("解析失败: %d 错误" % result["errors"].size(), IDETheme.C_RED)
		_bottom_panel.switch_to_tab(1)
		for err in result.get("errors", []):
			_bottom_panel.log_error(str(err.get("message", err)), err.get("line", -1))
	if on_code_applied.is_valid():
		on_code_applied.call(result)
	return result

func validate_code() -> Dictionary:
	var result: Dictionary = ScriptCodeGenClass.validate(_get_active_text())
	if result["valid"]:
		_log("语法正确 (%d 警告)" % result["warnings"].size(), IDETheme.C_GREEN)
		_status_bar.set_validation_state("warning" if result["warnings"].size() > 0 else "ok")
	else:
		_log("%d 语法错误" % result["errors"].size(), IDETheme.C_RED)
		_status_bar.set_validation_state("error")
	if on_validation_done.is_valid():
		on_validation_done.call(result)
	return result

func export_code(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_log("导出失败: 无法打开文件", IDETheme.C_RED)
		return false
	file.store_string(_get_active_text())
	file.close()
	_log("已导出到 %s" % path.get_file(), IDETheme.C_GREEN)
	return true

func import_code(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_log("导入失败: 无法读取文件", IDETheme.C_RED)
		return false
	_set_active_text(file.get_as_text())
	file.close()
	_log("已导入 %s" % path.get_file(), IDETheme.C_GREEN)
	return true

func insert_template(category: String) -> void:
	var template: String = ScriptCodeGenClass.get_template(category)
	if template.is_empty():
		return
	var ce := _get_active_code_edit()
	if ce == null:
		return
	var cursor: int = ce.get_caret_column()
	var line: int = ce.get_caret_line()
	var text := ce.text
	var insert_pos: int = 0
	for i in line:
		insert_pos = text.find("\n", insert_pos) + 1
	insert_pos += cursor
	ce.text = text.substr(0, insert_pos) + template + "\n" + text.substr(insert_pos)
	ce.set_caret_line(line + template.count("\n") + 1)
	ce.set_caret_column(0)
	_set_tab_modified(true)

# ============================================================
# UI构建
# ============================================================

func _build_ui(target: Node) -> void:
	var main_vbox := VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", 0)
	target.add_child(main_vbox)

	_menu_bar = IDEMenuBarClass.new()
	_menu_bar.menu_action.connect(_on_menu_action)
	main_vbox.add_child(_menu_bar)

	_top_bar = IDETopBarClass.new()
	_top_bar.workspace_selected.connect(_on_workspace_selected)
	_top_bar.run_pressed.connect(_on_run_pressed)
	_top_bar.stop_pressed.connect(_on_stop_pressed)
	_top_bar.layout_pressed.connect(_on_layout_pressed)
	main_vbox.add_child(_top_bar)

	_main_hsplit = HSplitContainer.new()
	_main_hsplit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_main_hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_main_hsplit.dragger_visibility = SplitContainer.DRAGGER_VISIBLE
	main_vbox.add_child(_main_hsplit)

	_dock_left = IDEDockLeftClass.new()
	_main_hsplit.add_child(_dock_left)
	_dock_left.get_scene_tree().node_selected.connect(_on_scene_tree_selected)
	_dock_left.get_scene_tree().node_modified.connect(_on_scene_modified)
	_dock_left.get_file_system().file_activated.connect(_on_file_activated)
	_dock_left.get_file_system().script_activated.connect(_open_script_by_id)
	_dock_left.get_file_system().text_file_activated.connect(_open_text_file)

	_center_vsplit = VSplitContainer.new()
	_center_vsplit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_center_vsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_center_vsplit.dragger_visibility = SplitContainer.DRAGGER_VISIBLE
	_main_hsplit.add_child(_center_vsplit)

	_workspace = IDEWorkspaceClass.new()
	_center_vsplit.add_child(_workspace)
	_workspace.run_requested.connect(_on_run_pressed)
	_workspace.editor_selection_changed.connect(_on_editor_selection_changed)
	_workspace.editor_scene_modified.connect(_on_editor_scene_modified)
	_workspace.editor_undo_requested.connect(_scene_undo_action)
	_workspace.editor_redo_requested.connect(_scene_redo_action)
	_workspace.editor_save_requested.connect(_on_editor_save_requested)

	_scene_undo["2d"] = EditorUndoRedo.new()
	_scene_undo["3d"] = EditorUndoRedo.new()

	var script_view: VBoxContainer = _workspace.get_script_view()
	script_view.text_changed.connect(_on_code_changed)
	script_view.cursor_moved.connect(_on_cursor_moved)
	script_view.tab_close_requested.connect(_on_tab_close_requested)
	script_view.get_tab_bar().tab_changed.connect(_on_tab_changed)

	var script_panel: VBoxContainer = _workspace.get_script_panel()
	script_panel.script_selected.connect(_on_panel_script_selected)
	script_panel.method_selected.connect(_on_panel_method_selected)

	_bottom_panel = IDEBottomPanelClass.new()
	_bottom_panel.error_clicked.connect(_on_error_clicked)
	_build_find_bar(main_vbox)
	_center_vsplit.add_child(_bottom_panel)

	_dock_right = IDEDockRightClass.new()
	_main_hsplit.add_child(_dock_right)
	_dock_right.get_inspector().property_changed.connect(_on_property_changed)
	_dock_right.node_connections_changed.connect(_on_node_connections_changed)
	_dock_right.node_groups_changed.connect(_on_node_groups_changed)
	_dock_right.open_script_requested.connect(_on_open_script_requested)
	_dock_right.history_entry_clicked.connect(_on_history_entry_clicked)

	_status_bar = IDEStatusBarClass.new()
	main_vbox.add_child(_status_bar)

	_build_dialogs(target)

	_validate_timer = Timer.new()
	_validate_timer.wait_time = 0.8
	_validate_timer.one_shot = true
	_validate_timer.timeout.connect(_do_validate)
	add_child(_validate_timer)

	_auto_save_timer = Timer.new()
	_auto_save_timer.wait_time = AUTO_SAVE_INTERVAL
	_auto_save_timer.one_shot = false
	_auto_save_timer.timeout.connect(_do_auto_save)
	add_child(_auto_save_timer)
	_auto_save_timer.start()

	_main_hsplit.split_offset = IDETheme.DOCK_DEFAULT_WIDTH
	_center_vsplit.resized.connect(_on_center_vsplit_resized)
	_center_vsplit.dragged.connect(_on_center_vsplit_dragged)
	_load_layout()

func _build_dialogs(target: Node) -> void:
	_export_dialog = FileDialog.new()
	_export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_export_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_export_dialog.add_filter("*.gd", "GDScript")
	_export_dialog.add_filter("*.txt", "Text File")
	_export_dialog.title = "导出剧本代码"
	_export_dialog.file_selected.connect(func(p: String): export_code(p))
	target.add_child(_export_dialog)

	_import_dialog = FileDialog.new()
	_import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_import_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_import_dialog.add_filter("*.gd", "GDScript")
	_import_dialog.add_filter("*.txt", "Text File")
	_import_dialog.add_filter("*.json", "JSON Scene")
	_import_dialog.title = "导入剧本代码"
	_import_dialog.file_selected.connect(func(p: String): import_code(p))
	target.add_child(_import_dialog)

	_save_dialog = FileDialog.new()
	_save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_save_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_save_dialog.add_filter("*.gd", "GDScript")
	_save_dialog.title = "保存文件"
	_save_dialog.file_selected.connect(func(p: String): _save_to_file(p))
	target.add_child(_save_dialog)

	_open_dialog = FileDialog.new()
	_open_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_open_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_open_dialog.add_filter("*.gd", "GDScript")
	_open_dialog.add_filter("*.txt", "Text File")
	_open_dialog.add_filter("*.json", "JSON Scene")
	_open_dialog.title = "打开文件"
	_open_dialog.file_selected.connect(func(p: String): _open_from_file(p))
	target.add_child(_open_dialog)

	# 导出项目对话框 (完整剧本JSON)
	_export_project_dialog = FileDialog.new()
	_export_project_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_export_project_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_export_project_dialog.add_filter("*.json", "JSON Project")
	_export_project_dialog.title = "导出完整剧本项目"
	_export_project_dialog.file_selected.connect(func(p: String): _export_full_project(p))
	target.add_child(_export_project_dialog)

	# 新建场景命名对话框
	_new_scene_dialog = ConfirmationDialog.new()
	_new_scene_dialog.title = "新建场景"
	_new_scene_dialog.ok_button_text = "创建"
	_new_scene_input = LineEdit.new()
	_new_scene_input.placeholder_text = "场景名称 (如: main_scene)"
	_new_scene_input.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_UI)
	_new_scene_input.text_submitted.connect(func(_t: String): _new_scene_dialog.hide(); _on_new_scene_confirmed())
	_new_scene_dialog.add_child(_new_scene_input)
	_new_scene_dialog.confirmed.connect(_on_new_scene_confirmed)
	target.add_child(_new_scene_dialog)

	# 新建脚本命名对话框
	_new_script_dialog = ConfirmationDialog.new()
	_new_script_dialog.title = "新建脚本"
	_new_script_dialog.ok_button_text = "创建"
	_new_script_input = LineEdit.new()
	_new_script_input.placeholder_text = "脚本名称 (如: player_controller.gd)"
	_new_script_input.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_UI)
	_new_script_input.text_submitted.connect(func(_t: String): _new_script_dialog.hide(); _on_new_script_confirmed())
	_new_script_dialog.add_child(_new_script_input)
	_new_script_dialog.confirmed.connect(_on_new_script_confirmed)
	target.add_child(_new_script_dialog)

	_settings_dialog = IDESettingsDialogClass.new()
	_settings_dialog.settings_saved.connect(_on_editor_settings_saved)
	target.add_child(_settings_dialog)

	_about_dialog = IDEAboutDialogClass.new()
	target.add_child(_about_dialog)

	_shortcuts_dialog = IDEShortcutsDialogClass.new()
	target.add_child(_shortcuts_dialog)

# ============================================================
# 标签管理
# ============================================================

func _create_new_tab(tab_name: String, text: String, file_path: String = "") -> void:
	var script_view: VBoxContainer = _workspace.get_script_view()
	var tab_bar: TabBar = script_view.get_tab_bar()
	_save_current_tab_text()
	var idx: int = tab_bar.tab_count
	tab_bar.add_tab(tab_name)
	_tabs[idx] = {"name": tab_name, "text": text, "modified": false, "file_path": file_path}
	_current_tab = idx
	_tab_counter += 1
	tab_bar.current_tab = idx
	script_view.set_text(text)
	script_view.set_modified(false)
	_top_bar.set_scene_title(tab_name + " - 万界诗篇编辑器")
	_update_script_panel()

func _save_current_tab_text() -> void:
	if _current_tab >= 0 and _tabs.has(_current_tab):
		var script_view: VBoxContainer = _workspace.get_script_view()
		_tabs[_current_tab]["text"] = script_view.get_text()
		_tabs[_current_tab]["modified"] = script_view.is_modified()

func _on_tab_changed(tab: int) -> void:
	_save_current_tab_text()
	_current_tab = tab
	if _tabs.has(tab):
		var script_view: VBoxContainer = _workspace.get_script_view()
		script_view.set_text(_tabs[tab]["text"])
		script_view.set_modified(_tabs[tab]["modified"])
		_update_tab_title(tab)
		_top_bar.set_scene_title(_tabs[tab]["name"] + " - 万界诗篇编辑器")
	_update_script_panel()

func _on_tab_close_requested(tab_index: int) -> void:
	var script_view: VBoxContainer = _workspace.get_script_view()
	var tab_bar: TabBar = script_view.get_tab_bar()
	if tab_bar.tab_count <= 1:
		return
	_save_current_tab_text()
	_tabs.erase(tab_index)
	tab_bar.remove_tab(tab_index)
	var new_tabs: Dictionary = {}
	for i in tab_bar.tab_count:
		var old_idx: int = i if i < tab_index else i + 1
		if _tabs.has(old_idx):
			new_tabs[i] = _tabs[old_idx]
	_tabs = new_tabs
	if _current_tab >= tab_bar.tab_count:
		_current_tab = tab_bar.tab_count - 1
	tab_bar.current_tab = _current_tab
	if _tabs.has(_current_tab):
		script_view.set_text(_tabs[_current_tab]["text"])
	_update_script_panel()

func _set_tab_modified(modified: bool) -> void:
	var script_view: VBoxContainer = _workspace.get_script_view()
	script_view.set_modified(modified)
	if _tabs.has(_current_tab):
		_tabs[_current_tab]["modified"] = modified
	_update_tab_title(_current_tab)

func _update_tab_title(tab_index: int) -> void:
	if not _tabs.has(tab_index):
		return
	var script_view: VBoxContainer = _workspace.get_script_view()
	var tab_bar: TabBar = script_view.get_tab_bar()
	var tab_name: String = _tabs[tab_index]["name"]
	var modified: bool = _tabs[tab_index]["modified"]
	if tab_index < tab_bar.tab_count:
		tab_bar.set_tab_title(tab_index, tab_name + (" ●" if modified else ""))

# ============================================================
# 脚本面板
# ============================================================

func _update_script_panel() -> void:
	if _workspace == null:
		return
	var script_panel: VBoxContainer = _workspace.get_script_panel()
	if script_panel == null:
		return
	var script_view: VBoxContainer = _workspace.get_script_view()
	var tab_bar: TabBar = script_view.get_tab_bar()
	var scripts: Array = []
	for i in tab_bar.tab_count:
		var t: Dictionary = _tabs.get(i, {})
		scripts.append({"name": t.get("name", tab_bar.get_tab_title(i)), "modified": t.get("modified", false)})
	script_panel.set_scripts(scripts)
	var current_name: String = _tabs.get(_current_tab, {}).get("name", "")
	script_panel.set_current_script(current_name)
	_update_method_outline()

func _update_method_outline() -> void:
	if _workspace == null:
		return
	var script_panel: VBoxContainer = _workspace.get_script_panel()
	if script_panel == null:
		return
	script_panel.set_methods(_parse_methods(_get_active_text()))

func _parse_methods(code: String) -> Array:
	var methods: Array = []
	if code.is_empty():
		return methods
	var lines: PackedStringArray = code.split("\n")
	for i in lines.size():
		var stripped: String = lines[i].strip_edges()
		if stripped.begins_with("func "):
			var fname: String = stripped.substr(5).split("(")[0].strip_edges()
			if not fname.is_empty():
				methods.append({"name": fname, "line": i})
	return methods

func _on_panel_script_selected(index: int) -> void:
	if index == _current_tab:
		return
	var script_view: VBoxContainer = _workspace.get_script_view()
	var tab_bar: TabBar = script_view.get_tab_bar()
	if index >= 0 and index < tab_bar.tab_count:
		tab_bar.current_tab = index

func _on_panel_method_selected(line: int) -> void:
	var script_view: VBoxContainer = _workspace.get_script_view()
	script_view.goto_line(line)

# ============================================================
# 代码编辑辅助
# ============================================================

func _get_active_code_edit() -> CodeEdit:
	if _workspace == null:
		return null
	return _workspace.get_script_view().get_code_edit()

func _get_active_text() -> String:
	var ce := _get_active_code_edit()
	if ce:
		return ce.text
	return ""

func _set_active_text(text: String) -> void:
	var script_view: VBoxContainer = _workspace.get_script_view()
	if script_view:
		script_view.set_text(text)
		if _tabs.has(_current_tab):
			_tabs[_current_tab]["text"] = text
			_tabs[_current_tab]["modified"] = false
		_set_tab_modified(false)
		_update_method_outline()

func _on_code_changed() -> void:
	_set_tab_modified(true)
	_update_method_outline()
	if _validate_timer:
		_validate_timer.start()

func _on_cursor_moved(line: int, column: int) -> void:
	if _status_bar:
		_status_bar.set_cursor_position(line, column)

func _do_validate() -> void:
	var script_view: VBoxContainer = _workspace.get_script_view()
	var ce := _get_active_code_edit()
	if ce == null:
		return
	script_view.set_error_lines([])
	_error_lines.clear()
	var result: Dictionary = ScriptCodeGenClass.validate(ce.text)
	var error_lines: Array = []
	var warning_lines: Array = []
	if not result["valid"]:
		for err in result.get("errors", []):
			var err_line: int = err.get("line", 0)
			error_lines.append(err_line)
			_error_lines.append(err_line)
		script_view.set_error_lines(error_lines)
		_status_bar.set_validation_state("error")
		_bottom_panel.clear_errors()
		for err in result.get("errors", []):
			_bottom_panel.log_error(str(err.get("message", err)), err.get("line", -1))
	elif result["warnings"].size() > 0:
		for w in result.get("warnings", []):
			warning_lines.append(w.get("line", 0))
		script_view.set_warning_lines(warning_lines)
		_status_bar.set_validation_state("warning")
		_bottom_panel.clear_errors()
		for w in result.get("warnings", []):
			_bottom_panel.log_warning(str(w.get("message", w)), w.get("line", -1))
	else:
		_status_bar.set_validation_state("ok")
		_bottom_panel.clear_errors()

# ============================================================
# 工作区/面板切换
# ============================================================

func _on_workspace_selected(workspace_name: String) -> void:
	_workspace.switch_workspace(workspace_name)
	_refresh_history_panel()

func _on_run_pressed() -> void:
	_log("运行剧本...", IDETheme.C_GREEN)
	var result := apply_code()
	if not result["success"]:
		_log("运行失败: 请先修复语法错误", IDETheme.C_RED)
		return
	_save_scene_editors_data()
	# 保存场景到独立文件 (若已有关联文件)
	_save_scene_to_file_if_tracked("2d")
	_save_scene_to_file_if_tracked("3d")
	# 持久化剧本数据到磁盘
	ScriptDataManager.update_script(world_script)
	# 验证落盘成功
	var verify_path: String = ScriptDataManager.get_script_file(world_script.id)
	if not FileAccess.file_exists(verify_path):
		_log("运行失败: 剧本保存验证失败, 文件不存在", IDETheme.C_RED)
		return
	_log("剧本已保存并验证, 进入体验...", IDETheme.C_GREEN)
	SceneManager.enter_script(world_script.id)

func _on_stop_pressed() -> void:
	_log("停止运行 (在剧本体验中按Esc返回编辑器)", IDETheme.C_YELLOW)

func _on_layout_pressed() -> void:
	_save_layout()
	_log("布局已保存", IDETheme.C_GREEN)

func _toggle_left_dock() -> void:
	_dock_left.visible = not _dock_left.visible

func _toggle_right_dock() -> void:
	_dock_right.visible = not _dock_right.visible

## === 查找替换栏 ===
func _build_find_bar(parent: Control) -> void:
	_find_bar = HBoxContainer.new()
	_find_bar.add_theme_constant_override("separation", 6)
	_find_bar.visible = false
	parent.add_child(_find_bar)
	_find_input = LineEdit.new()
	_find_input.placeholder_text = "查找…"
	_find_input.custom_minimum_size.x = 220
	_find_input.text_submitted.connect(func(_t): _find_next(true))
	_find_bar.add_child(_find_input)
	var prev := Button.new()
	prev.text = "▲"
	prev.tooltip_text = "上一个"
	prev.pressed.connect(func(): _find_next(false))
	_find_bar.add_child(prev)
	var next := Button.new()
	next.text = "▼"
	next.tooltip_text = "下一个"
	next.pressed.connect(func(): _find_next(true))
	_find_bar.add_child(next)
	_replace_input = LineEdit.new()
	_replace_input.placeholder_text = "替换为…"
	_replace_input.custom_minimum_size.x = 180
	_find_bar.add_child(_replace_input)
	var rep_btn := Button.new()
	rep_btn.text = "替换"
	rep_btn.pressed.connect(_replace_current)
	_find_bar.add_child(rep_btn)
	var rep_all := Button.new()
	rep_all.text = "全部"
	rep_all.pressed.connect(_replace_all)
	_find_bar.add_child(rep_all)
	var close := Button.new()
	close.text = "✕"
	close.pressed.connect(func(): _find_bar.visible = false)
	_find_bar.add_child(close)

func _show_find_bar(focus_find: bool) -> void:
	if _find_bar == null:
		return
	_find_bar.visible = true
	_last_find_pos = -1
	if focus_find:
		_find_input.grab_focus()
	else:
		_replace_input.grab_focus()

func _get_code_text() -> String:
	var ce := _get_active_code_edit()
	return ce.text if ce != null else ""

func _set_code_text(new_text: String) -> void:
	var ce := _get_active_code_edit()
	if ce != null:
		ce.text = new_text
		_on_code_changed()

func _find_next(forward: bool) -> bool:
	var query := _find_input.text
	if query.is_empty():
		return false
	if query != _find_query:
		_find_query = query
		_last_find_pos = -1
	var text := _get_code_text()
	var start: int = _last_find_pos + 1 if forward else _last_find_pos - 1
	if start < 0:
		start = 0
	var pos := text.find(query, start)
	if pos < 0:
		pos = text.find(query, 0 if forward else text.length() - 1)
		if pos < 0:
			_log("未找到: %s" % query, IDETheme.C_YELLOW)
			return false
	_last_find_pos = pos
	var ce := _get_active_code_edit()
	if ce != null:
		var from_lc := _char_to_line_col(text, pos)
		var to_lc := _char_to_line_col(text, pos + query.length())
		ce.select(from_lc[0], from_lc[1], to_lc[0], to_lc[1])
		ce.ensure_caret_visible()
	return true

## 字符偏移 → [line, col]（TextEdit.select 用行列坐标）
func _char_to_line_col(text: String, char_pos: int) -> Array:
	var acc := 0
	for l in text.split("\n"):
		if acc + l.length() >= char_pos or acc + l.length() >= text.length():
			return [text.split("\n").find(l), clampi(char_pos - acc, 0, l.length())]
		acc += l.length() + 1
	return [0, 0]

func _replace_current() -> void:
	if _last_find_pos < 0 or _find_query.is_empty():
		_find_next(true)
		if _last_find_pos < 0:
			return
	var text := _get_code_text()
	if text.substr(_last_find_pos, _find_query.length()) != _find_query:
		_last_find_pos = -1
		_find_next(true)
		return
	var repl := _replace_input.text
	_set_code_text(text.substr(0, _last_find_pos) + repl + text.substr(_last_find_pos + _find_query.length()))
	_last_find_pos += repl.length()
	_find_next(true)

func _replace_all() -> void:
	var query := _find_input.text
	if query.is_empty():
		return
	var text := _get_code_text()
	var count := text.count(query)
	if count == 0:
		_log("未找到: %s" % query, IDETheme.C_YELLOW)
		return
	_set_code_text(text.replace(query, _replace_input.text))
	_log("已替换 %d 处: %s" % [count, query], IDETheme.C_GREEN)

func _toggle_bottom_panel() -> void:
	_bottom_panel.toggle_collapse()

func _on_center_vsplit_resized() -> void:
	if _center_vsplit and _center_vsplit.size.y > 0:
		_center_vsplit.split_offset = max(0, int(_center_vsplit.size.y) - _bottom_panel_height)

func _on_center_vsplit_dragged(offset: int) -> void:
	_bottom_panel_height = max(IDETheme.BOTTOM_PANEL_MIN_HEIGHT, int(_center_vsplit.size.y) - offset)

# ============================================================
# 菜单动作
# ============================================================

func _on_menu_action(action: String) -> void:
	match action:
		"new_scene":
			_on_new_scene()
		"new_script":
			_on_new_script()
		"open":
			_open_dialog.popup_centered()
		"save":
			_on_save_file()
		"save_as":
			_save_dialog.popup_centered()
		"export":
			_export_project_dialog.popup_centered()
		"import":
			_import_dialog.popup_centered()
		"project_settings":
			_settings_dialog.open()
		"undo":
			var ce := _get_active_code_edit()
			if ce != null:
				ce.undo()
		"redo":
			var ce := _get_active_code_edit()
			if ce != null:
				ce.redo()
		"find":
			_show_find_bar(true)
		"replace":
			_show_find_bar(false)
		"tool_regenerate":
			if world_script:
				_set_active_text(ScriptCodeGenClass.generate(world_script))
				_log("已从数据重新生成代码", IDETheme.C_YELLOW)
		"tool_format":
			_format_code()
		"apply":
			apply_code()
		"validate":
			validate_code()
		"run_script":
			_on_run_pressed()
		"stop_script":
			_on_stop_pressed()
		"editor_settings":
			_settings_dialog.open()
		"toggle_left":
			_toggle_left_dock()
		"toggle_right":
			_toggle_right_dock()
		"toggle_bottom":
			_toggle_bottom_panel()
		"layout_default":
			_save_layout()
			_log("布局已保存", IDETheme.C_GREEN)
		"layout_reset":
			_dock_left.visible = true
			_dock_right.visible = true
			if _bottom_panel.is_collapsed():
				_bottom_panel.toggle_collapse()
			_main_hsplit.split_offset = IDETheme.DOCK_DEFAULT_WIDTH
			_center_vsplit.split_offset = -IDETheme.BOTTOM_PANEL_DEFAULT_HEIGHT
			_log("布局已重置", IDETheme.C_GREEN)
		"shortcuts":
			_shortcuts_dialog.open()
		"edit_mode":
			# 编辑模式说明（转发到 script_editor 宿主弹窗）
			var se := get_parent()
			while se != null and not se.has_method("_show_edit_mode_guide"):
				se = se.get_parent()
			if se != null:
				se._show_edit_mode_guide(EditorMode.current_mode)
		"about":
			_about_dialog.open()

func _on_editor_settings_saved(settings: Dictionary) -> void:
	if _auto_save_timer != null:
		var interval: float = float(settings.get("behavior/auto_save_interval", 60))
		_auto_save_timer.wait_time = maxf(interval, 5.0)
		var enabled: bool = bool(settings.get("behavior/auto_save", true))
		_auto_save_timer.stop()
		if enabled:
			_auto_save_timer.start()
	_log("编辑器设置已保存", IDETheme.C_GREEN)

# ============================================================
# 场景树/检查器
# ============================================================

func _update_scene_tree() -> void:
	if world_script == null:
		return
	var root_data := {"type": "WorldScript", "name": world_script.name if world_script.name else "剧本", "children": [], "props": {}}
	if world_script.worldview:
		root_data["children"].append({"type": "Worldview", "name": "世界观", "children": [], "props": {"visible": true}})
	if world_script.event_system:
		var event_children := []
		for se in world_script.event_system.story_events:
			event_children.append({"type": "StoryEvent", "name": se.get("name", se.get("id", "事件")), "children": [], "props": {"visible": true}})
		root_data["children"].append({"type": "EventSystem", "name": "事件系统", "children": event_children, "props": {"visible": true}})
	if world_script.economy_system:
		root_data["children"].append({"type": "EconomySystem", "name": "经济系统", "children": [], "props": {"visible": true}})
	if world_script.ability_system:
		root_data["children"].append({"type": "AbilitySystem", "name": "能力系统", "children": [], "props": {"visible": true}})
	_dock_left.set_scene_data(root_data)

func _on_scene_tree_selected(nodes: Array[Dictionary]) -> void:
	_dock_right.set_selected_nodes(nodes)

func _on_scene_modified() -> void:
	_log("场景已修改", IDETheme.C_YELLOW)

func _on_property_changed(_node: Dictionary, property: String, new_value: Variant) -> void:
	_log("属性变更: %s = %s" % [property, str(new_value)], IDETheme.C_TEXT_DIM)

# ============================================================
# 场景编辑器选中/修改/撤销重做
# ============================================================

func _on_editor_selection_changed(_domain: String, nodes: Array[Dictionary], scene_root: Dictionary) -> void:
	_dock_right.set_selected_nodes(nodes)
	var node: Dictionary = nodes[0] if not nodes.is_empty() else {}
	_dock_right.set_node_panel_target(node, scene_root)

func _on_editor_scene_modified(domain: String) -> void:
	_commit_scene_history(domain, "编辑场景")
	_refresh_history_panel()

func _commit_scene_history(domain: String, action_text: String) -> void:
	if not _scene_undo.has(domain):
		return
	var ur: EditorUndoRedo = _scene_undo[domain]
	var current: Dictionary = _workspace.get_scene_2d() if domain == "2d" else _workspace.get_scene_3d()
	if current.is_empty():
		return
	var before: Variant = _scene_last_snapshot.get(domain, current)
	ur.commit(action_text, before, current)
	_scene_last_snapshot[domain] = current.duplicate(true)

func _refresh_history_panel() -> void:
	var domain: String = _workspace.get_active_editor_domain()
	if domain.is_empty() or not _scene_undo.has(domain):
		return
	var ur: EditorUndoRedo = _scene_undo[domain]
	_dock_right.set_history(ur.get_history())

func _scene_undo_action(domain: String) -> void:
	if not _scene_undo.has(domain):
		return
	var ur: EditorUndoRedo = _scene_undo[domain]
	var result: Dictionary = ur.undo()
	if result.get("valid", false):
		_workspace.reload_editor_scene(domain, result["state"])
		_scene_last_snapshot[domain] = (result["state"] as Dictionary).duplicate(true)
		_log("撤销: %s" % str(result.get("action", "")), IDETheme.C_YELLOW)
	_refresh_history_panel()

func _scene_redo_action(domain: String) -> void:
	if not _scene_undo.has(domain):
		return
	var ur: EditorUndoRedo = _scene_undo[domain]
	var result: Dictionary = ur.redo()
	if result.get("valid", false):
		_workspace.reload_editor_scene(domain, result["state"])
		_scene_last_snapshot[domain] = (result["state"] as Dictionary).duplicate(true)
		_log("重做: %s" % str(result.get("action", "")), IDETheme.C_YELLOW)
	_refresh_history_panel()

func _on_history_entry_clicked(index: int) -> void:
	var domain: String = _workspace.get_active_editor_domain()
	if domain.is_empty() or not _scene_undo.has(domain):
		return
	var ur: EditorUndoRedo = _scene_undo[domain]
	var steps: int = ur.steps_to_entry(index)
	var last_state: Dictionary = {}
	if steps < 0:
		for _i in range(-steps):
			var r: Dictionary = ur.undo()
			if r.get("valid", false):
				last_state = r["state"]
	elif steps > 0:
		for _i in range(steps):
			var r: Dictionary = ur.redo()
			if r.get("valid", false):
				last_state = r["state"]
	if not last_state.is_empty():
		_workspace.reload_editor_scene(domain, last_state)
		_scene_last_snapshot[domain] = last_state.duplicate(true)
	_refresh_history_panel()

func _on_node_connections_changed(_node: Dictionary) -> void:
	var domain: String = _workspace.get_active_editor_domain()
	if not domain.is_empty():
		_commit_scene_history(domain, "修改信号连接")
		_refresh_history_panel()
	_log("信号连接已更新", IDETheme.C_GREEN)

func _on_node_groups_changed(_node: Dictionary) -> void:
	var domain: String = _workspace.get_active_editor_domain()
	if not domain.is_empty():
		_commit_scene_history(domain, "修改节点分组")
		_refresh_history_panel()
	_log("节点分组已更新", IDETheme.C_GREEN)

func _on_open_script_requested(node: Dictionary, method_name: String) -> void:
	_workspace.switch_workspace("script")
	_top_bar.set_active_workspace("script")
	if method_name.is_empty():
		return
	var code: String = _get_active_text()
	if code.find("func " + method_name) >= 0:
		_log("方法已存在: %s" % method_name, IDETheme.C_TEXT_DIM)
		return
	var sig_args: Array = _find_signal_args(node, method_name)
	var params: String = ", ".join(sig_args)
	var stub: String = "\nfunc %s(%s) -> void:\n\tpass  # TODO: 信号回调\n" % [method_name, params]
	var ce := _get_active_code_edit()
	if ce:
		ce.text = ce.text.rstrip("\n") + "\n" + stub
		ce.set_caret_line(ce.get_line_count() - 2)
		_set_tab_modified(true)
	_log("已生成信号回调: %s" % method_name, IDETheme.C_GREEN)

func _find_signal_args(node: Dictionary, method_name: String) -> Array:
	var conns: Variant = node.get("props", {}).get("connections", [])
	if conns is Array:
		for conn in conns:
			if conn.get("method", "") == method_name:
				var args: Variant = conn.get("signal_args", [])
				if args is Array:
					return args
	return []

func _on_error_clicked(line: int) -> void:
	var script_view: VBoxContainer = _workspace.get_script_view()
	script_view.goto_line(line)
	_workspace.switch_workspace("script")
	_top_bar.set_active_workspace("script")

func _on_file_activated(path: String) -> void:
	_open_from_file(path)

# ============================================================
# 文件操作
# ============================================================

func _on_save_file() -> void:
	if not _tabs.has(_current_tab):
		return
	var tab: Dictionary = _tabs[_current_tab]
	var file_path: String = tab.get("file_path", "")
	if not file_path.is_empty():
		_save_tab_to_file(_current_tab)
		return
	if world_script != null:
		_save_script_data()
		return
	var tab_name: String = tab["name"]
	if tab_name.begins_with("untitled"):
		_save_dialog.popup_centered()
	else:
		_log("文件 '%s' 已保存" % tab_name, IDETheme.C_GREEN)
		_set_tab_modified(false)

func _open_text_file(path: String) -> void:
	# 检测是否为场景JSON文件 → 加载到场景编辑器
	if path.get_extension().to_lower() == "json" and _is_scene_json_file(path):
		_open_scene_from_file(path)
		return
	for idx in _tabs:
		if _tabs[idx].get("file_path", "") == path:
			var script_view: VBoxContainer = _workspace.get_script_view()
			script_view.get_tab_bar().current_tab = idx
			return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_log("打开失败: 无法读取 %s" % path, IDETheme.C_RED)
		return
	var text := file.get_as_text()
	file.close()
	_create_new_tab(path.get_file(), text, path)
	_log("已打开 %s" % path.get_file(), IDETheme.C_GREEN)

func _save_tab_to_file(tab_index: int) -> bool:
	if not _tabs.has(tab_index):
		return false
	var tab: Dictionary = _tabs[tab_index]
	var file_path: String = tab.get("file_path", "")
	if file_path.is_empty():
		return false
	var text: String = _get_active_text() if tab_index == _current_tab else tab["text"]
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		_log("保存失败: 无法写入 %s" % file_path, IDETheme.C_RED)
		return false
	file.store_string(text)
	file.close()
	tab["text"] = text
	tab["modified"] = false
	if tab_index == _current_tab:
		_set_tab_modified(false)
	else:
		_update_tab_title(tab_index)
	_log("已保存 %s" % file_path.get_file(), IDETheme.C_GREEN)
	return true

func _open_script_by_id(script_id: String) -> void:
	var ws: WorldScriptData = ScriptDataManager.find_script(script_id)
	if ws == null:
		_log("打开失败: 未找到剧本 %s" % script_id, IDETheme.C_RED)
		return
	if world_script == ws:
		return
	_save_current_if_dirty()
	load_data(ws)
	if _tabs.has(_current_tab):
		_tabs[_current_tab]["name"] = ws.name
		_tabs[_current_tab]["file_path"] = ""
		_update_tab_title(_current_tab)
		_update_script_panel()

func _save_current_if_dirty() -> void:
	if world_script == null or not _is_current_modified():
		return
	_save_script_data()

func _is_current_modified() -> bool:
	if _tabs.has(_current_tab):
		return _tabs[_current_tab].get("modified", false)
	return false

func _save_script_data() -> bool:
	if world_script == null:
		return false
	var result: Dictionary = apply_code()
	if not result["success"]:
		_log("保存失败: 代码存在语法错误", IDETheme.C_RED)
		return false
	_save_scene_editors_data()
	ScriptDataManager.update_script(world_script)
	_log("剧本 '%s' 已保存到本地" % world_script.name, IDETheme.C_GREEN)
	return true

func _do_auto_save() -> void:
	if world_script != null and _tabs.has(_current_tab) \
			and _tabs[_current_tab].get("file_path", "").is_empty() \
			and _is_current_modified():
		var check: Dictionary = ScriptCodeGenClass.validate(_get_active_text())
		if check["valid"]:
			_save_script_data()
	for idx in _tabs:
		var tab: Dictionary = _tabs[idx]
		if not tab.get("file_path", "").is_empty() and tab.get("modified", false):
			_save_tab_to_file(idx)

func _save_to_file(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_log("保存失败", IDETheme.C_RED)
		return
	file.store_string(_get_active_text())
	file.close()
	var fname: String = path.get_file()
	if _tabs.has(_current_tab):
		_tabs[_current_tab]["name"] = fname
		_tabs[_current_tab]["file_path"] = path
		_tabs[_current_tab]["modified"] = false
	var script_view: VBoxContainer = _workspace.get_script_view()
	script_view.get_tab_bar().set_tab_title(_current_tab, fname)
	script_view.set_modified(false)
	_log("已保存 %s" % fname, IDETheme.C_GREEN)

func _open_from_file(path: String) -> void:
	# 检测是否为场景JSON文件 → 加载到对应场景编辑器
	if path.get_extension().to_lower() == "json" and _is_scene_json_file(path):
		_open_scene_from_file(path)
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_log("打开失败: 无法读取文件", IDETheme.C_RED)
		return
	var text := file.get_as_text()
	file.close()
	_create_new_tab(path.get_file(), text, path)
	_log("已打开 %s" % path.get_file(), IDETheme.C_GREEN)

# ============================================================
# 新建场景 (真实文件I/O)
# ============================================================

func _on_new_scene() -> void:
	var domain: String = _workspace.get_active_editor_domain()
	if domain.is_empty():
		_log("请先切换到2D或3D工作区再新建场景", IDETheme.C_YELLOW)
		return
	if world_script == null:
		_log("请先打开一个剧本项目", IDETheme.C_RED)
		return
	_new_scene_input.text = ""
	_new_scene_input.placeholder_text = "场景名称 (如: main_scene) [%s]" % domain.to_upper()
	_new_scene_dialog.popup_centered(Vector2i(360, 120))
	_new_scene_input.call_deferred("grab_focus")

func _on_new_scene_confirmed() -> void:
	var scene_name: String = _new_scene_input.text.strip_edges()
	if scene_name.is_empty():
		scene_name = "new_scene"
	# 清理非法文件名字符
	scene_name = scene_name.replace(" ", "_").replace("/", "_").replace("\\", "_").replace(":", "_")
	var domain: String = _workspace.get_active_editor_domain()
	if domain.is_empty():
		return
	# 构建场景数据
	var scene_data: Dictionary
	if domain == "2d":
		scene_data = {"type": "Control", "name": scene_name, "children": [], "props": {}, "_meta": {"domain": "2d", "created": Time.get_datetime_string_from_system()}}
	else:
		scene_data = {"type": "Node3D", "name": scene_name, "children": [], "props": {}, "_meta": {"domain": "3d", "created": Time.get_datetime_string_from_system()}}
	# 创建实际磁盘文件: user://scripts/{id}/scenes/{name}.json
	var scenes_dir: String = ScriptDataManager.get_script_dir(world_script.id) + "/scenes"
	DirAccess.make_dir_recursive_absolute(scenes_dir)
	var file_path: String = scenes_dir + "/" + scene_name + ".json"
	# 避免覆盖: 自动追加数字后缀
	var counter: int = 2
	while FileAccess.file_exists(file_path):
		file_path = scenes_dir + "/" + scene_name + "_" + str(counter) + ".json"
		counter += 1
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		_log("新建场景失败: 无法写入 %s" % file_path, IDETheme.C_RED)
		return
	file.store_string(JSON.stringify(scene_data, "  "))
	file.close()
	# 加载到编辑器
	if domain == "2d":
		_workspace.load_scene_2d(scene_data)
	else:
		_workspace.load_scene_3d(scene_data)
	_scene_file_paths[domain] = file_path
	_commit_scene_history(domain, "新建%s场景" % domain.to_upper())
	_refresh_history_panel()
	# 刷新文件系统面板
	_dock_left.refresh_files()
	_log("已新建%s场景 → %s" % [domain.to_upper(), file_path.get_file()], IDETheme.C_GREEN)

# ============================================================
# 新建脚本 (真实文件I/O)
# ============================================================

func _on_new_script() -> void:
	if world_script == null:
		# 无剧本时创建纯内存标签 (兼容旧行为)
		_create_new_tab("untitled_%d.gd" % _tab_counter, "extends Node\n")
		return
	_new_script_input.text = ""
	_new_script_dialog.popup_centered(Vector2i(360, 120))
	_new_script_input.call_deferred("grab_focus")

func _on_new_script_confirmed() -> void:
	var script_name: String = _new_script_input.text.strip_edges()
	if script_name.is_empty():
		script_name = "new_script.gd"
	# 确保有.gd扩展名
	if not script_name.ends_with(".gd"):
		script_name += ".gd"
	# 清理非法字符
	script_name = script_name.replace(" ", "_").replace("/", "_").replace("\\", "_").replace(":", "_")
	# 创建实际磁盘文件: user://scripts/{id}/scripts/{name}.gd
	var scripts_dir: String = ScriptDataManager.get_script_dir(world_script.id) + "/scripts"
	DirAccess.make_dir_recursive_absolute(scripts_dir)
	var file_path: String = scripts_dir + "/" + script_name
	var counter: int = 2
	while FileAccess.file_exists(file_path):
		var base: String = script_name.get_basename()
		file_path = scripts_dir + "/" + base + "_" + str(counter) + ".gd"
		counter += 1
	# 生成GDScript模板内容
	var class_name_str: String = script_name.get_basename().replace("_", " ").capitalize().replace(" ", "")
	var content: String = "## %s\n## 创建于: %s\nextends Node\n\n\nclass_name %s\n\n\nfunc _ready() -> void:\n\tpass\n" % [script_name, Time.get_datetime_string_from_system(), class_name_str]
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		_log("新建脚本失败: 无法写入 %s" % file_path, IDETheme.C_RED)
		return
	file.store_string(content)
	file.close()
	# 在编辑器中打开为新标签 (绑定文件路径, 保存时直接写回磁盘)
	_create_new_tab(script_name, content, file_path)
	# 刷新文件系统面板
	_dock_left.refresh_files()
	_log("已新建脚本 → %s" % file_path.get_file(), IDETheme.C_GREEN)

# ============================================================
# 场景文件保存/打开 (真实文件I/O)
# ============================================================

## 将场景数据保存到已追踪的磁盘文件 (若有关联路径)
func _save_scene_to_file_if_tracked(domain: String) -> void:
	var file_path: String = _scene_file_paths.get(domain, "")
	if file_path.is_empty():
		return
	var scene_data: Dictionary = _workspace.get_scene_2d() if domain == "2d" else _workspace.get_scene_3d()
	if scene_data.is_empty():
		return
	var json_data: Dictionary = _json_safe(scene_data)
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		_log("场景保存失败: 无法写入 %s" % file_path, IDETheme.C_RED)
		return
	file.store_string(JSON.stringify(json_data, "  "))
	file.close()
	_log("场景已保存 → %s" % file_path.get_file(), IDETheme.C_GREEN)

## 保存当前活动场景到磁盘 (Ctrl+S在场景工作区时触发)
func _save_active_scene_to_file() -> bool:
	var domain: String = _workspace.get_active_editor_domain()
	if domain.is_empty():
		return false
	var file_path: String = _scene_file_paths.get(domain, "")
	if file_path.is_empty():
		# 无关联文件 → 新建场景流程 (让用户命名)
		_on_new_scene()
		return false
	_save_scene_to_file_if_tracked(domain)
	return true

## 从磁盘文件打开场景到编辑器
func _open_scene_from_file(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_log("打开场景失败: 无法读取 %s" % path, IDETheme.C_RED)
		return
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		_log("打开场景失败: 非法JSON格式", IDETheme.C_RED)
		return
	var scene_data: Dictionary = _from_json(parsed) as Dictionary
	var domain: String = str(scene_data.get("_meta", {}).get("domain", ""))
	# 自动推断域: 根节点类型
	if domain.is_empty():
		var root_type: String = str(scene_data.get("type", ""))
		if root_type in ["Node3D", "MeshInstance3D", "Camera3D", "DirectionalLight3D"]:
			domain = "3d"
		else:
			domain = "2d"
	# 加载到对应编辑器
	if domain == "3d":
		_workspace.load_scene_3d(scene_data)
		_workspace.switch_workspace("3d")
		_top_bar.set_active_workspace("3d")
	else:
		_workspace.load_scene_2d(scene_data)
		_workspace.switch_workspace("2d")
		_top_bar.set_active_workspace("2d")
	_scene_file_paths[domain] = path
	_commit_scene_history(domain, "打开场景文件")
	_refresh_history_panel()
	_log("已打开场景 %s → %s编辑器" % [path.get_file(), domain.to_upper()], IDETheme.C_GREEN)

## 检测JSON文件是否为场景文件 (含type+children结构)
func _is_scene_json_file(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return false
	var d: Dictionary = parsed as Dictionary
	return d.has("type") and d.has("children")

## 导出完整剧本项目 (元信息+子系统+场景 合并为单文件JSON)
func _export_full_project(path: String) -> void:
	if world_script == null:
		_log("导出失败: 未加载剧本", IDETheme.C_RED)
		return
	# 先保存当前编辑状态
	_save_scene_editors_data()
	ScriptDataManager.update_script(world_script)
	# 使用ScriptDataManager的导出功能
	var success: bool = ScriptDataManager.export_script(world_script.id, path)
	if success:
		_log("完整剧本已导出 → %s" % path.get_file(), IDETheme.C_GREEN)
	else:
		_log("导出失败: 无法写入 %s" % path, IDETheme.C_RED)

# ============================================================
# 快捷键
# ============================================================

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F5:
			apply_code()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F6:
			validate_code()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F7:
			_on_run_pressed()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F8:
			_on_stop_pressed()
			get_viewport().set_input_as_handled()
		elif event.ctrl_pressed:
			match event.keycode:
				KEY_S:
					if event.shift_pressed:
						# Ctrl+Shift+S: 另存为
						_save_dialog.popup_centered()
					else:
						# Ctrl+S: 场景工作区保存场景文件; 脚本工作区保存代码
						if not _save_active_scene_to_file():
							_on_save_file()
					get_viewport().set_input_as_handled()
				KEY_N:
					if event.shift_pressed:
						_on_new_script()
					else:
						_on_new_scene()
					get_viewport().set_input_as_handled()
				KEY_O:
					_open_dialog.popup_centered()
					get_viewport().set_input_as_handled()
				KEY_Z:
					var domain: String = _workspace.get_active_editor_domain()
					if not domain.is_empty():
						_scene_undo_action(domain)
						get_viewport().set_input_as_handled()
				KEY_Y:
					var domain_r: String = _workspace.get_active_editor_domain()
					if not domain_r.is_empty():
						_scene_redo_action(domain_r)
						get_viewport().set_input_as_handled()
				KEY_1:
					_toggle_left_dock()
					get_viewport().set_input_as_handled()
				KEY_2:
					_toggle_right_dock()
					get_viewport().set_input_as_handled()
				KEY_3:
					_toggle_bottom_panel()
					get_viewport().set_input_as_handled()
			if event.shift_pressed and event.keycode == KEY_X:
				_toggle_bottom_panel()
				get_viewport().set_input_as_handled()

## 2D/3D编辑器保存按钮回调: 保存场景到磁盘文件
func _on_editor_save_requested(domain: String) -> void:
	var file_path: String = _scene_file_paths.get(domain, "")
	if file_path.is_empty():
		# 无关联文件 → 提示用户命名保存
		_log("场景尚未关联文件, 请使用 场景→新建场景 或 Ctrl+S 保存", IDETheme.C_YELLOW)
		_on_new_scene()
		return
	_save_scene_to_file_if_tracked(domain)
	# 同步写入metadata (随剧本一起持久化)
	_save_scene_editors_data()
	if world_script != null:
		ScriptDataManager.update_script(world_script)

# ============================================================
# 场景编辑器数据 (2D/3D) - 存于 world_script.metadata + 独立文件
# ============================================================

func _load_scene_editors_data(ws: WorldScriptData) -> void:
	if _workspace == null:
		return
	var s2d: Variant = ws.metadata.get("scene_2d", null)
	if s2d is Dictionary:
		_workspace.load_scene_2d(_from_json(s2d) as Dictionary)
	var s3d: Variant = ws.metadata.get("scene_3d", null)
	if s3d is Dictionary and _workspace.has_method("load_scene_3d"):
		_workspace.load_scene_3d(_from_json(s3d) as Dictionary)

func _save_scene_editors_data() -> void:
	if world_script == null or _workspace == null:
		return
	var scene_2d: Dictionary = _workspace.get_scene_2d()
	if not scene_2d.is_empty():
		world_script.metadata["scene_2d"] = _json_safe(scene_2d)
	if _workspace.has_method("get_scene_3d"):
		var scene_3d: Dictionary = _workspace.get_scene_3d()
		if not scene_3d.is_empty():
			world_script.metadata["scene_3d"] = _json_safe(scene_3d)

func _json_safe(v: Variant) -> Variant:
	if v is Vector2:
		return {"__t": "v2", "x": v.x, "y": v.y}
	elif v is Vector3:
		return {"__t": "v3", "x": v.x, "y": v.y, "z": v.z}
	elif v is Color:
		return {"__t": "col", "r": v.r, "g": v.g, "b": v.b, "a": v.a}
	elif v is Dictionary:
		var r := {}
		for k in v:
			r[k] = _json_safe(v[k])
		return r
	elif v is Array:
		var r := []
		for item in v:
			r.append(_json_safe(item))
		return r
	else:
		return v

func _from_json(v: Variant) -> Variant:
	if v is Dictionary:
		var t: String = str(v.get("__t", ""))
		if t == "v2":
			return Vector2(float(v.get("x", 0.0)), float(v.get("y", 0.0)))
		elif t == "v3":
			return Vector3(float(v.get("x", 0.0)), float(v.get("y", 0.0)), float(v.get("z", 0.0)))
		elif t == "col":
			return Color(float(v.get("r", 1.0)), float(v.get("g", 1.0)), float(v.get("b", 1.0)), float(v.get("a", 1.0)))
		var r := {}
		for k in v:
			r[k] = _from_json(v[k])
		return r
	elif v is Array:
		var r := []
		for item in v:
			r.append(_from_json(item))
		return r
	else:
		return v

# ============================================================
# 格式化代码
# ============================================================

func _format_code() -> void:
	var ce := _get_active_code_edit()
	if ce == null:
		return
	var text: String = ce.text
	var lines: PackedStringArray = text.split("\n")
	var result: PackedStringArray = PackedStringArray()
	var indent_level: int = 0
	var prev_blank: bool = false
	for i in lines.size():
		var stripped: String = lines[i].strip_edges()
		if stripped.is_empty():
			if not prev_blank and result.size() > 0:
				result.append("")
			prev_blank = true
			continue
		prev_blank = false
		if stripped.begins_with("elif ") or stripped.begins_with("else:") \
				or stripped.begins_with("except") or stripped.begins_with("finally:"):
			indent_level = maxi(indent_level - 1, 0)
		var formatted: String = "\t".repeat(indent_level) + stripped
		result.append(formatted.rstrip(" \t"))
		if stripped.ends_with(":"):
			indent_level += 1
	while result.size() > 0 and result[result.size() - 1].is_empty():
		result.remove_at(result.size() - 1)
	var new_text: String = "\n".join(result) + "\n"
	if new_text != text:
		ce.text = new_text
		_set_tab_modified(true)
		_log("代码已格式化 (%d 行)" % result.size(), IDETheme.C_GREEN)
	else:
		_log("代码已是规范格式", IDETheme.C_TEXT_DIM)

# ============================================================
# 布局保存/恢复
# ============================================================

const LAYOUT_PATH := "user://editor_layout.cfg"

func _save_layout() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("layout", "left_dock_visible", _dock_left.visible)
	cfg.set_value("layout", "right_dock_visible", _dock_right.visible)
	cfg.set_value("layout", "bottom_collapsed", _bottom_panel.is_collapsed())
	cfg.set_value("layout", "hsplit_offset", _main_hsplit.split_offset)
	cfg.set_value("layout", "bottom_panel_height", _bottom_panel_height)
	cfg.save(LAYOUT_PATH)

func _load_layout() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(LAYOUT_PATH) != OK:
		return
	_dock_left.visible = cfg.get_value("layout", "left_dock_visible", true)
	_dock_right.visible = cfg.get_value("layout", "right_dock_visible", true)
	var collapsed: bool = cfg.get_value("layout", "bottom_collapsed", false)
	if collapsed and not _bottom_panel.is_collapsed():
		_bottom_panel.toggle_collapse()
	_main_hsplit.split_offset = cfg.get_value("layout", "hsplit_offset", IDETheme.DOCK_DEFAULT_WIDTH)
	_bottom_panel_height = cfg.get_value("layout", "bottom_panel_height", IDETheme.BOTTOM_PANEL_DEFAULT_HEIGHT)

# ============================================================
# 日志
# ============================================================

func _log(msg: String, color: Color = IDETheme.C_TEXT) -> void:
	if _bottom_panel:
		_bottom_panel.log_message(msg, color)
