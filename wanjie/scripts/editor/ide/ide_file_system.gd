## IDE文件系统 - 剧本项目文件管理 (复刻 Godot 4.7.1 FileSystem Dock)
## 上栏：目录树 | 下栏：当前目录文件列表
## 双模式: 剧本列表(未打开剧本时浏览 user://scripts/) / 项目文件(打开剧本后浏览其文件夹)
## 文本文件双击进代码编辑器编辑, 资源文件外部打开
## 右键菜单: 新建剧本/新建文件/新建文件夹/打开/重命名/删除/复制路径/在文件管理器中显示
extends VBoxContainer

signal file_selected(file_path: String)
signal file_activated(file_path: String)
## 双击剧本列表中的剧本/新建剧本时发出, 由代码编辑器接收并打开
signal script_activated(script_id: String)
## 双击文本文件时发出, 由代码编辑器接收并以标签打开编辑
signal text_file_activated(file_path: String)

const IDETheme = preload("res://scripts/editor/ide/ide_theme.gd")
const SCRIPTS_ROOT := "user://scripts/"

## 可编辑文本文件扩展名 (双击在代码编辑器中打开)
const TEXT_EXTS := ["json", "txt", "gd", "lua", "csv", "md", "cfg", "ini", "log", "mud", "xml", "yaml", "yml"]

# 文件类型着色 (Godot 4.7.1 风格)
const FILE_COLORS := {
	".gd": Color(0.55, 0.65, 1.0, 1),      # GDScript 蓝紫
	".tscn": Color(0.51, 0.83, 1.0, 1),    # 场景 浅蓝
	".tres": Color(0.6, 0.9, 0.7, 1),      # 资源 淡绿
	".png": Color(0.95, 0.75, 0.35, 1),    # 图片 黄
	".jpg": Color(0.95, 0.75, 0.35, 1),
	".svg": Color(0.95, 0.75, 0.35, 1),
	".json": Color(0.95, 0.6, 0.35, 1),    # 数据 橙
	".txt": Color(0.8, 0.81, 0.82, 1),     # 文本 灰
	".md": Color(0.8, 0.81, 0.82, 1),
	".mud": Color(0.87, 0.31, 0.35, 1),    # MUD 红
	".lua": Color(0.55, 0.65, 1.0, 1),
	".csv": Color(0.8, 0.81, 0.82, 1),
}

var _dir_tree: Tree
var _file_list: ItemList
var _search_input: LineEdit
var _split: VSplitContainer
var _current_dir: String = SCRIPTS_ROOT
var _context_menu: PopupMenu
var _context_target: Dictionary = {}  # {"path": ..., "is_dir": ...}
var _title_label: Label
var _btn_back: Button
## 当前根剧本ID ("" = 剧本列表模式, 非空 = 该项目文件夹模式)
var _script_root_id: String = ""
## 新建文件/文件夹命名对话框
var _name_dialog: ConfirmationDialog
var _name_input: LineEdit
var _name_dialog_mode: String = ""  # "file" / "folder"

func _ready() -> void:
	add_theme_constant_override("separation", 0)
	_build_ui()
	_build_context_menu()
	_build_name_dialog()
	_scan_dirs()
	_show_dir_files(_current_dir)
	# 剧本增删时刷新列表; 更新时轻量刷新显示名
	ScriptDataManager.script_created.connect(func(_id: String) -> void: refresh())
	ScriptDataManager.script_deleted.connect(_on_script_deleted)
	ScriptDataManager.script_updated.connect(_on_script_updated)

func _build_ui() -> void:
	# === 标题工具栏 ===
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 4)
	var header_sb := StyleBoxFlat.new()
	header_sb.bg_color = IDETheme.C_BG_TOOL
	header_sb.border_width_bottom = 1
	header_sb.border_color = IDETheme.C_BORDER
	header_sb.content_margin_left = 8.0
	header_sb.content_margin_top = 3.0
	header_sb.content_margin_right = 4.0
	header_sb.content_margin_bottom = 3.0
	var header_panel := PanelContainer.new()
	header_panel.add_theme_stylebox_override("panel", header_sb)
	header_panel.add_child(header)
	add_child(header_panel)

	_btn_back = Button.new()
	_btn_back.text = "⬆"
	_btn_back.tooltip_text = "返回剧本列表"
	_btn_back.flat = true
	_btn_back.custom_minimum_size = Vector2(22, 22)
	_btn_back.visible = false
	IDETheme.style_button(_btn_back)
	_btn_back.pressed.connect(func() -> void: set_script_root(""))
	header.add_child(_btn_back)

	_title_label = Label.new()
	_title_label.text = "剧本库"
	_title_label.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_UI)
	_title_label.add_theme_color_override("font_color", IDETheme.C_TEXT)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)

	var btn_refresh := Button.new()
	btn_refresh.text = "⟳"
	btn_refresh.tooltip_text = "刷新文件系统"
	btn_refresh.flat = true
	btn_refresh.custom_minimum_size = Vector2(22, 22)
	IDETheme.style_button(btn_refresh)
	btn_refresh.pressed.connect(refresh)
	header.add_child(btn_refresh)

	# === 搜索框 ===
	_search_input = LineEdit.new()
	_search_input.placeholder_text = "过滤文件..."
	_search_input.clear_button_enabled = true
	_search_input.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_SMALL)
	var search_sb := StyleBoxFlat.new()
	search_sb.bg_color = IDETheme.C_BG_DARKER
	search_sb.border_width_bottom = 1
	search_sb.border_color = IDETheme.C_BORDER
	search_sb.content_margin_left = 6.0
	search_sb.content_margin_right = 6.0
	search_sb.content_margin_top = 3.0
	search_sb.content_margin_bottom = 3.0
	_search_input.add_theme_stylebox_override("normal", search_sb)
	_search_input.add_theme_color_override("font_color", IDETheme.C_TEXT)
	_search_input.add_theme_color_override("font_placeholder_color", IDETheme.C_TEXT_DISABLED)
	_search_input.text_changed.connect(_on_search_changed)
	add_child(_search_input)

	# === 分栏: 目录树 | 文件列表 ===
	_split = VSplitContainer.new()
	_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_split.dragger_visibility = SplitContainer.DRAGGER_VISIBLE
	add_child(_split)

	# 目录树
	_dir_tree = Tree.new()
	_dir_tree.hide_root = false
	_dir_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var tree_sb := StyleBoxFlat.new()
	tree_sb.bg_color = IDETheme.C_BG_BASE
	_dir_tree.add_theme_stylebox_override("panel", tree_sb)
	_dir_tree.add_theme_color_override("font_color", IDETheme.C_TEXT)
	_dir_tree.add_theme_constant_override("draw_relationship_lines", 1)
	_dir_tree.add_theme_color_override("relationship_line_color", IDETheme.C_SEPARATOR)
	_dir_tree.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_UI)
	_dir_tree.item_selected.connect(_on_dir_selected)
	_dir_tree.gui_input.connect(_on_dir_tree_input)
	_split.add_child(_dir_tree)

	# 文件列表
	_file_list = ItemList.new()
	_file_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_file_list.select_mode = ItemList.SELECT_SINGLE
	var list_sb := StyleBoxFlat.new()
	list_sb.bg_color = IDETheme.C_BG_BASE
	_file_list.add_theme_stylebox_override("panel", list_sb)
	_file_list.add_theme_color_override("font_color", IDETheme.C_TEXT)
	_file_list.add_theme_color_override("font_selected_color", Color(1, 1, 1, 1))
	_file_list.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_UI)
	_file_list.item_selected.connect(_on_file_selected)
	_file_list.item_activated.connect(_on_file_activated)
	_file_list.gui_input.connect(_on_file_list_input)
	_split.add_child(_file_list)

	_split.split_offset = -120

func _build_context_menu() -> void:
	_context_menu = PopupMenu.new()
	_context_menu.id_pressed.connect(_on_context_menu)
	add_child(_context_menu)

func _build_name_dialog() -> void:
	_name_dialog = ConfirmationDialog.new()
	_name_dialog.ok_button_text = "创建"
	_name_input = LineEdit.new()
	_name_input.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_UI)
	_name_input.text_submitted.connect(func(_t: String) -> void:
		_name_dialog.hide()
		_on_name_confirmed()
	)
	_name_dialog.add_child(_name_input)
	_name_dialog.confirmed.connect(_on_name_confirmed)
	add_child(_name_dialog)

# === 公共接口 ===

## 设置文件系统根目录: 非空script_id = 项目文件模式(浏览该剧本文件夹); "" = 剧本列表模式
func set_script_root(script_id: String) -> void:
	_script_root_id = script_id
	if script_id.is_empty():
		_current_dir = SCRIPTS_ROOT
		_title_label.text = "剧本库"
		_btn_back.visible = false
	else:
		_current_dir = ScriptDataManager.get_script_dir(script_id) + "/"
		var ws: WorldScriptData = ScriptDataManager.find_script(script_id)
		_title_label.text = ws.name if ws != null else script_id
		_btn_back.visible = true
	refresh()

func get_script_root_id() -> String:
	return _script_root_id

func refresh() -> void:
	_scan_dirs()
	_show_dir_files(_current_dir)
	# 文件计数标题（剧本库模式显示剧本总数）
	if _script_root_id.is_empty():
		var gm: Node = Engine.get_main_loop().root.get_node_or_null("GameManager")
		var total := 0
		if gm != null and gm.scripts != null:
			total = gm.scripts.size()
		_title_label.text = "剧本库（%d）" % total
	else:
		_title_label.text = "剧本文件"

func _get_root_path() -> String:
	if _script_root_id.is_empty():
		return SCRIPTS_ROOT
	return ScriptDataManager.get_script_dir(_script_root_id) + "/"

func _in_project_mode() -> bool:
	return not _script_root_id.is_empty()

# === 目录树扫描 ===

func _scan_dirs() -> void:
	_dir_tree.clear()
	var root_path := _get_root_path()
	var root := _dir_tree.create_item()
	if _in_project_mode():
		var ws: WorldScriptData = ScriptDataManager.find_script(_script_root_id)
		root.set_text(0, ws.name if ws != null else _script_root_id)
	else:
		root.set_text(0, "剧本库")
	root.set_metadata(0, {"path": root_path, "is_dir": true})
	root.set_custom_color(0, IDETheme.C_YELLOW)
	_scan_dir_recursive(root_path, root)
	# 展开到当前目录
	_expand_to_dir(root, _current_dir)

func _scan_dir_recursive(path: String, parent_item: TreeItem) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not _should_skip(entry):
			var full_path := path.path_join(entry)
			if dir.current_is_dir():
				var item := _dir_tree.create_item(parent_item)
				item.set_text(0, entry)
				item.set_metadata(0, {"path": full_path, "is_dir": true})
				item.set_custom_color(0, IDETheme.C_YELLOW)
				_scan_dir_recursive(full_path, item)
		entry = dir.get_next()
	dir.list_dir_end()

func _expand_to_dir(item: TreeItem, target_path: String) -> void:
	var meta: Dictionary = item.get_metadata(0)
	if meta.get("path", "") == target_path:
		_dir_tree.set_selected(item, 0)
		return
	var child := item.get_first_child()
	while child:
		_expand_to_dir(child, target_path)
		child = child.get_next()

# === 文件列表 ===

func _show_dir_files(dir_path: String) -> void:
	_current_dir = dir_path
	_file_list.clear()
	var filter: String = _search_input.text.to_lower()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	# 先子目录
	dir.list_dir_begin()
	var entry := dir.get_next()
	var dirs: Array[String] = []
	var files: Array[String] = []
	while entry != "":
		if not _should_skip(entry):
			if dir.current_is_dir():
				dirs.append(entry)
			else:
				files.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()

	dirs.sort()
	files.sort()

	# 剧本列表模式: scripts/ 根下的子目录 = 剧本项目, 显示剧本名
	var at_scripts_root := dir_path == SCRIPTS_ROOT and not _in_project_mode()
	# 项目模式: 标记剧本主数据文件 script.json
	var main_file := ScriptDataManager.get_script_file(_script_root_id) if _in_project_mode() else ""

	for d in dirs:
		if at_scripts_root:
			var ws: WorldScriptData = ScriptDataManager.find_script(d)
			var display := ws.name if ws != null else d
			if not filter.is_empty() \
					and not d.to_lower().contains(filter) \
					and not display.to_lower().contains(filter):
				continue
			var idx := _file_list.add_item("📖 " + display)
			_file_list.set_item_metadata(idx, {"path": dir_path.path_join(d), "is_dir": true, "script_id": d})
			_file_list.set_item_custom_fg_color(idx, Color(0.6, 0.9, 0.7, 1))
		else:
			if not filter.is_empty() and not d.to_lower().contains(filter):
				continue
			var idx := _file_list.add_item("📁 " + d)
			_file_list.set_item_metadata(idx, {"path": dir_path.path_join(d), "is_dir": true})
			_file_list.set_item_custom_fg_color(idx, IDETheme.C_YELLOW)

	for f in files:
		if not filter.is_empty() and not f.to_lower().contains(filter):
			continue
		var full := dir_path.path_join(f)
		var icon := _get_file_icon(f)
		var meta := {"path": full, "is_dir": false}
		var color: Color = FILE_COLORS.get("." + f.get_extension().to_lower(), IDETheme.C_TEXT)
		if _in_project_mode() and full == main_file:
			# 剧本主数据文件: 特殊标记
			icon = "📖"
			color = Color(0.6, 0.9, 0.7, 1)
			meta["is_main_data"] = true
		var idx := _file_list.add_item(icon + " " + f)
		_file_list.set_item_metadata(idx, meta)
		_file_list.set_item_custom_fg_color(idx, color)

func _should_skip(entry_name: String) -> bool:
	if entry_name == "." or entry_name == "..":
		return true
	if entry_name.begins_with("."):
		return true
	if entry_name.ends_with(".import"):
		return true
	if entry_name.ends_with(".uid"):
		return true
	if entry_name.ends_with(".uid"):
		return true
	return false

func _is_text_file(path: String) -> bool:
	return TEXT_EXTS.has(path.get_extension().to_lower())

func _get_file_icon(file_name: String) -> String:
	if file_name.ends_with(".gd") or file_name.ends_with(".lua"):
		return "📜"
	elif file_name.ends_with(".tscn") or file_name.ends_with(".scn"):
		return "🎬"
	elif file_name.ends_with(".tres") or file_name.ends_with(".res"):
		return "📦"
	elif file_name.ends_with(".png") or file_name.ends_with(".jpg") or file_name.ends_with(".svg"):
		return "🖼"
	elif file_name.ends_with(".ogg") or file_name.ends_with(".wav") or file_name.ends_with(".mp3"):
		return "🔊"
	elif file_name.ends_with(".txt") or file_name.ends_with(".md"):
		return "📄"
	elif file_name.ends_with(".json"):
		return "📋"
	elif file_name.ends_with(".csv"):
		return "📊"
	elif file_name.ends_with(".mud"):
		return "🗺"
	else:
		return "📃"

# === 事件处理 ===

func _on_dir_selected() -> void:
	var item := _dir_tree.get_selected()
	if item == null:
		return
	var meta: Dictionary = item.get_metadata(0)
	_show_dir_files(meta.get("path", SCRIPTS_ROOT))

func _on_file_selected(index: int) -> void:
	var meta: Dictionary = _file_list.get_item_metadata(index)
	if not meta.get("is_dir", false):
		file_selected.emit(meta["path"])

func _on_file_activated(index: int) -> void:
	var meta: Dictionary = _file_list.get_item_metadata(index)
	if meta.get("is_dir", false):
		if meta.has("script_id"):
			# 剧本列表模式: 双击剧本 → 打开剧本
			script_activated.emit(meta["script_id"])
		else:
			# 双击目录进入
			_show_dir_files(meta["path"])
		return
	var path: String = meta["path"]
	if _is_text_file(path):
		# 文本文件 → 代码编辑器打开编辑
		text_file_activated.emit(path)
	else:
		# 资源文件 → 外部程序打开
		OS.shell_open(ProjectSettings.globalize_path(path))

func _on_search_changed(_text: String) -> void:
	_show_dir_files(_current_dir)

# === 右键菜单 ===

func _on_dir_tree_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			var item := _dir_tree.get_item_at_position(mb.position)
			if item:
				_dir_tree.set_selected(item, 0)
				_context_target = item.get_metadata(0)
				_popup_context(mb.position)

func _on_file_list_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			var idx := _file_list.get_item_at_position(mb.position)
			if idx >= 0:
				_file_list.select(idx)
				_context_target = _file_list.get_item_metadata(idx)
			else:
				_context_target = {"path": _current_dir, "is_dir": true}
			_popup_context(mb.position)

## 按上下文动态构建右键菜单
func _popup_context(pos: Vector2) -> void:
	_context_menu.clear()
	if _context_target.has("script_id"):
		# 剧本列表中的剧本条目
		_context_menu.add_item("打开剧本", 3)
		_context_menu.add_separator()
		_context_menu.add_item("删除剧本", 6)
		_context_menu.add_separator()
		_context_menu.add_item("复制路径", 8)
		_context_menu.add_item("在文件管理器中显示", 9)
	elif _context_target.get("is_dir", false) \
			and not _in_project_mode() \
			and _context_target.get("path", "") == SCRIPTS_ROOT:
		# 剧本列表根空白处/根目录
		_context_menu.add_item("新建剧本", 0)
		_context_menu.add_separator()
		_context_menu.add_item("复制路径", 8)
		_context_menu.add_item("在文件管理器中显示", 9)
	else:
		# 项目文件模式 (或列表模式下的普通目录)
		if _context_target.get("is_dir", false):
			_context_menu.add_item("新建文件...", 1)
			_context_menu.add_item("新建文件夹...", 2)
			_context_menu.add_separator()
		_context_menu.add_item("打开", 3)
		if not _context_target.has("is_main_data"):
			_context_menu.add_item("重命名...", 5)
			_context_menu.add_item("删除", 6)
		_context_menu.add_separator()
		_context_menu.add_item("复制路径", 8)
		_context_menu.add_item("在文件管理器中显示", 9)
	_context_menu.popup(Rect2i(Vector2i(get_screen_position()) + Vector2i(pos), Vector2i(200, 280)))

func _on_context_menu(id: int) -> void:
	match id:
		0: _create_new_script()
		1: _create_new_file()
		2: _create_new_folder()
		3: _open_item()
		5: _rename_item()
		6: _delete_item()
		8: _copy_path()
		9: _show_in_file_manager()

func _get_context_dir() -> String:
	var path: String = _context_target.get("path", _current_dir)
	if _context_target.get("is_dir", false):
		return path
	return path.get_base_dir()

func _create_new_script() -> void:
	# 新建剧本: 自动生成不重名名称, 立即保存到本地并打开
	var base_name := "新剧本"
	var script_name := base_name
	var counter := 1
	while _script_name_exists(script_name):
		script_name = "%s_%d" % [base_name, counter]
		counter += 1
	var ws: WorldScriptData = ScriptDataManager.create_script(script_name)
	if ws != null:
		refresh()
		script_activated.emit(ws.id)

func _script_name_exists(script_name: String) -> bool:
	for sid in ScriptDataManager.user_scripts:
		var ws = ScriptDataManager.user_scripts[sid]
		if ws is WorldScriptData and ws.name == script_name:
			return true
	return false

func _create_new_file() -> void:
	_name_dialog_mode = "file"
	_name_dialog.title = "新建文件"
	_name_input.placeholder_text = "如: notes.txt"
	_name_input.text = ""
	_name_dialog.popup_centered(Vector2i(320, 100))
	_name_input.call_deferred("grab_focus")

func _create_new_folder() -> void:
	_name_dialog_mode = "folder"
	_name_dialog.title = "新建文件夹"
	_name_input.placeholder_text = "文件夹名"
	_name_input.text = ""
	_name_dialog.popup_centered(Vector2i(320, 100))
	_name_input.call_deferred("grab_focus")

func _on_name_confirmed() -> void:
	var new_name := _name_input.text.strip_edges()
	if new_name.is_empty() or new_name.contains("/") or new_name.contains("\\") or new_name.contains(":"):
		return
	var target_dir := _get_context_dir()
	var new_path := target_dir.path_join(new_name)
	if FileAccess.file_exists(new_path) or DirAccess.dir_exists_absolute(new_path):
		push_warning("文件系统: '%s' 已存在" % new_name)
		return
	if _name_dialog_mode == "file":
		var f := FileAccess.open(new_path, FileAccess.WRITE)
		if f != null:
			f.close()
	else:
		DirAccess.make_dir_recursive_absolute(new_path)
	refresh()

## 剧本更新时轻量刷新: 项目模式更新标题, 列表模式更新对应条目显示名
func _on_script_updated(script_id: String) -> void:
	var ws: WorldScriptData = ScriptDataManager.find_script(script_id)
	if ws == null:
		return
	if script_id == _script_root_id:
		_title_label.text = ws.name
	for i in range(_file_list.item_count):
		var meta: Dictionary = _file_list.get_item_metadata(i)
		if meta.get("script_id", "") == script_id:
			_file_list.set_item_text(i, "📖 " + ws.name)
			return

func _on_script_deleted(script_id: String) -> void:
	if script_id == _script_root_id:
		# 当前根剧本被删除 → 返回剧本列表
		set_script_root("")
	else:
		refresh()

func _open_item() -> void:
	if _context_target.is_empty():
		return
	if _context_target.has("script_id"):
		script_activated.emit(_context_target["script_id"])
	elif _context_target.get("is_dir", false):
		_show_dir_files(_context_target["path"])
	else:
		var path: String = _context_target["path"]
		if _is_text_file(path):
			text_file_activated.emit(path)
		else:
			OS.shell_open(ProjectSettings.globalize_path(path))

func _rename_item() -> void:
	if _context_target.is_empty():
		return
	if _context_target.has("is_main_data"):
		push_warning("文件系统: script.json 是剧本主数据, 不能重命名")
		return
	var old_path: String = _context_target["path"]
	# 禁止重命名剧本项目文件夹 (scripts/ 直属目录, 目录名=剧本ID)
	if old_path.get_base_dir() + "/" == SCRIPTS_ROOT:
		push_warning("文件系统: 剧本项目文件夹不能重命名")
		return
	var dir_path := old_path.get_base_dir()
	var old_name := old_path.get_file()
	# 简单自动重命名（加后缀）
	var new_name := old_name.get_basename() + "_renamed"
	if not old_name.get_extension().is_empty():
		new_name += "." + old_name.get_extension()
	var new_path := dir_path.path_join(new_name)
	DirAccess.rename_absolute(old_path, new_path)
	refresh()

func _delete_item() -> void:
	if _context_target.is_empty():
		return
	# 剧本: 通过 ScriptDataManager 删除 (同步缓存+信号+递归删目录)
	if _context_target.has("script_id"):
		ScriptDataManager.delete_script(_context_target["script_id"])
		return
	if _context_target.has("is_main_data"):
		push_warning("文件系统: script.json 是剧本主数据, 不能删除 (请删除整个剧本)")
		return
	var path: String = _context_target["path"]
	# 禁止删除剧本项目文件夹 (应使用"删除剧本")
	if _context_target.get("is_dir", false) and path.get_base_dir() + "/" == SCRIPTS_ROOT:
		push_warning("文件系统: 请在剧本列表中删除整个剧本项目")
		return
	if _context_target.get("is_dir", false):
		_remove_dir_recursive(path)
	else:
		DirAccess.remove_absolute(path)
	refresh()

## 递归删除目录及其全部内容
func _remove_dir_recursive(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry != "." and entry != "..":
			if dir.current_is_dir():
				_remove_dir_recursive(path.path_join(entry))
			else:
				dir.remove(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)

func _copy_path() -> void:
	if _context_target.is_empty():
		return
	DisplayServer.clipboard_set(_context_target["path"])

func _show_in_file_manager() -> void:
	if _context_target.is_empty():
		return
	OS.shell_show_in_file_manager(ProjectSettings.globalize_path(_context_target["path"]))
