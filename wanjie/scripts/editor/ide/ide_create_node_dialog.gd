## 创建节点对话框 - 对标 Godot 4.7.1 "创建新节点" 对话框
## 搜索框 + 分类节点类型树 + 类型说明 + 节点名输入
extends AcceptDialog

const IDETheme = preload("res://scripts/editor/ide/ide_theme.gd")
const Registry = preload("res://scripts/editor/editor_node_registry.gd")

signal node_type_confirmed(type_name: String, node_name: String)

var _domain: String = "2d"
var _type_tree: Tree
var _search_edit: LineEdit
var _name_edit: LineEdit
var _desc_label: Label
var _create_btn: Button
var _selected_type: String = ""

func _ready() -> void:
	title = "创建新节点"
	min_size = Vector2i(480, 520)
	size = Vector2i(500, 560)
	_build_ui()
	about_to_popup.connect(_on_about_to_popup)

func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 6)
	add_child(root)

	# === 搜索框 ===
	var search_hbox := HBoxContainer.new()
	search_hbox.add_theme_constant_override("separation", 6)
	root.add_child(search_hbox)
	var search_icon := Label.new()
	search_icon.text = "🔍"
	search_icon.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_UI)
	search_hbox.add_child(search_icon)
	_search_edit = LineEdit.new()
	_search_edit.placeholder_text = "搜索节点类型..."
	_search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_edit.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_UI)
	_search_edit.text_changed.connect(func(_t: String): _refresh_type_tree())
	search_hbox.add_child(_search_edit)

	# === 类型树 ===
	_type_tree = Tree.new()
	_type_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_type_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_type_tree.hide_root = true
	_type_tree.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_UI)
	_type_tree.item_selected.connect(_on_type_selected)
	_type_tree.item_activated.connect(_on_type_activated)
	root.add_child(_type_tree)

	# === 类型说明 ===
	_desc_label = Label.new()
	_desc_label.text = "选择要创建的节点类型"
	_desc_label.custom_minimum_size.y = 40
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_SMALL)
	_desc_label.add_theme_color_override("font_color", IDETheme.C_TEXT_DIM)
	var desc_sb := StyleBoxFlat.new()
	desc_sb.bg_color = IDETheme.C_BG_BASE
	desc_sb.content_margin_left = 8.0
	desc_sb.content_margin_top = 6.0
	desc_sb.content_margin_right = 8.0
	desc_sb.content_margin_bottom = 6.0
	_desc_label.add_theme_stylebox_override("normal", desc_sb)
	root.add_child(_desc_label)

	# === 节点名 ===
	var name_hbox := HBoxContainer.new()
	name_hbox.add_theme_constant_override("separation", 6)
	root.add_child(name_hbox)
	var name_lbl := Label.new()
	name_lbl.text = "节点名称:"
	name_lbl.custom_minimum_size.x = 64
	name_lbl.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_UI)
	name_lbl.add_theme_color_override("font_color", IDETheme.C_TEXT_DIM)
	name_hbox.add_child(name_lbl)
	_name_edit = LineEdit.new()
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.placeholder_text = "留空使用默认名"
	_name_edit.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_UI)
	name_hbox.add_child(_name_edit)

	# === 按钮 ===
	var btn_hbox := HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_END
	btn_hbox.add_theme_constant_override("separation", 8)
	root.add_child(btn_hbox)
	var cancel_btn := Button.new()
	cancel_btn.text = "取消"
	cancel_btn.custom_minimum_size = Vector2(80, 28)
	IDETheme.style_button(cancel_btn)
	cancel_btn.pressed.connect(hide)
	btn_hbox.add_child(cancel_btn)
	_create_btn = Button.new()
	_create_btn.text = "创建"
	_create_btn.custom_minimum_size = Vector2(80, 28)
	_create_btn.disabled = true
	IDETheme.style_button(_create_btn, true)
	_create_btn.pressed.connect(_on_create_pressed)
	btn_hbox.add_child(_create_btn)

# === 公共接口 ===

## 打开对话框: domain="2d"/"3d"/"" (空=全部)
func open_for_domain(domain: String) -> void:
	_domain = domain
	_selected_type = ""
	popup_centered()

func _on_about_to_popup() -> void:
	_search_edit.text = ""
	_name_edit.text = ""
	_selected_type = ""
	_create_btn.disabled = true
	_desc_label.text = "选择要创建的节点类型"
	_refresh_type_tree()
	_search_edit.grab_focus()

func _refresh_type_tree() -> void:
	_type_tree.clear()
	var root_item := _type_tree.create_item()
	var filter_text: String = _search_edit.text.strip_edges().to_lower()
	var categorized: Dictionary = Registry.get_types_by_category(_domain)
	var first_type_item: TreeItem = null
	for category in categorized:
		var types: Array = categorized[category]
		# 过滤
		var matched: Array = []
		for type_name in types:
			if filter_text.is_empty() or type_name.to_lower().contains(filter_text):
				matched.append(type_name)
		if matched.is_empty():
			continue
		var cat_item := _type_tree.create_item(root_item)
		cat_item.set_text(0, "📁 %s" % str(category))
		cat_item.set_custom_color(0, IDETheme.C_TEXT_DIM)
		cat_item.set_selectable(0, false)
		for type_name in matched:
			var def: Dictionary = Registry.get_type(type_name)
			var type_item := _type_tree.create_item(cat_item)
			type_item.set_text(0, "%s %s" % [def.get("icon", "◆"), type_name])
			type_item.set_tooltip_text(0, def.get("desc", ""))
			type_item.set_metadata(0, type_name)
			if first_type_item == null:
				first_type_item = type_item
		cat_item.collapsed = false
	# 搜索时自动选中第一个匹配
	if first_type_item != null and not filter_text.is_empty():
		first_type_item.select(0)
		_on_type_selected()

func _on_type_selected() -> void:
	var item := _type_tree.get_selected()
	if item == null:
		return
	var meta: Variant = item.get_metadata(0)
	if meta is String and not (meta as String).is_empty():
		_selected_type = meta
		var def: Dictionary = Registry.get_type(_selected_type)
		_desc_label.text = "%s %s\n%s\n继承: %s" % [
			def.get("icon", "◆"), _selected_type,
			def.get("desc", ""),
			(def.get("inherits", "") as String) if not def.get("inherits", "").is_empty() else "(根类型)"
		]
		_create_btn.disabled = false
		if _name_edit.text.is_empty():
			_name_edit.placeholder_text = Registry.get_default_name(_selected_type)

func _on_type_activated() -> void:
	# 双击直接创建
	if not _selected_type.is_empty():
		_on_create_pressed()

func _on_create_pressed() -> void:
	if _selected_type.is_empty():
		return
	var node_name: String = _name_edit.text.strip_edges()
	node_type_confirmed.emit(_selected_type, node_name)
	hide()
