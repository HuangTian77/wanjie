## mud_edit_dialog_base.gd
## MUD 编辑对话框基类（对应 ME loader/dialogs/edit*.lua + .html 的公共骨架）
##
## 提供：暗色主题、确认/取消（ConfirmationDialog）、头部信息区、内容区、
## 表单控件工厂（自动注册到 _fields）、通用字段收集 _collect_fields()。
## 子类（各具体对话框，均为独立顶层类）重写：
##   _build_body()  构建 UI 到 _body
##   _load(row)     用数据行填充控件
##   _collect()     返回要写回的字段字典（默认用 _collect_fields()）
## 注意：本文件及所有对话框子类均不得包含内部类（class Inner:），
##       否则全局枚举常量会退化为 int 导致类型化属性赋值报错。
class_name MudEditDialogBase
extends ConfirmationDialog

signal saved(table: String, id: int)

# ---- 暗色主题色板（与 mud_editor.gd 一致） ----
const C_BG := Color(0.125, 0.125, 0.145, 1)
const C_PANEL := Color(0.165, 0.165, 0.195, 1)
const C_PANEL2 := Color(0.20, 0.20, 0.24, 1)
const C_FIELD := Color(0.10, 0.10, 0.125, 1)
const C_BORDER := Color(0.30, 0.30, 0.36, 1)
const C_TEXT := Color(0.86, 0.86, 0.90, 1)
const C_LABEL := Color(0.58, 0.58, 0.66, 1)
const C_SELECTED := Color(0.28, 0.47, 0.78, 1)
const C_HOVER := Color(0.23, 0.23, 0.29, 1)

var _data: MudData = null
var _table: String = ""
var _row_id: int = 0
var _built: bool = false

var _root: VBoxContainer
var _header: VBoxContainer
var _body: VBoxContainer
var _fields: Dictionary = {}   # field_key -> Control


func _init() -> void:
	ok_button_text = "保存"
	cancel_button_text = "取消"
	min_size = Vector2(760, 560)
	theme = _build_theme()
	confirmed.connect(_on_confirmed)

	_root = VBoxContainer.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_theme_constant_override("separation", 6)
	add_child(_root)

	_header = VBoxContainer.new()
	_header.add_theme_constant_override("separation", 2)
	_root.add_child(_header)

	var sep := HSeparator.new()
	_root.add_child(sep)

	_body = VBoxContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 6)
	_root.add_child(_body)


## 打开对话框：加载 row 并显示。子类先被 _build_body() 构建 UI，再 _load(row)。
func open_dialog(data: MudData, table: String, row_id: int, title: String) -> void:
	_data = data
	_table = table
	_row_id = row_id
	self.title = title
	if not _built:
		_build_body()
		_built = true
	var row: Dictionary = data.get_row_by_id(table, row_id)
	_load(row)
	popup_centered()


# ===================== 子类重写 =====================

func _build_body() -> void:
	pass


func _load(_row: Dictionary) -> void:
	pass


func _collect() -> Dictionary:
	return _collect_fields()


# ===================== 保存 =====================

func _on_confirmed() -> void:
	var values: Dictionary = _collect()
	if _data != null and not _table.is_empty():
		_data.update_row(_table, _row_id, values)
	saved.emit(_table, _row_id)
	hide()


# ===================== 头部信息 =====================

## 添加只读头部信息行（如 名称：xxx）
func add_header(label_text: String, value_text: String) -> void:
	var hb := HBoxContainer.new()
	var lb := Label.new()
	lb.text = label_text
	lb.custom_minimum_size = Vector2(90, 0)
	lb.add_theme_color_override("font_color", C_LABEL)
	hb.add_child(lb)
	var vb := Label.new()
	vb.text = value_text
	vb.add_theme_color_override("font_color", C_TEXT)
	hb.add_child(vb)
	_header.add_child(hb)


func clear_header() -> void:
	for c in _header.get_children():
		c.queue_free()


# ===================== 表单控件工厂 =====================

func _add_labeled(parent: Control, label_text: String, ctrl: Control, label_w: float = 110.0) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	var lb := Label.new()
	lb.text = label_text
	lb.custom_minimum_size = Vector2(label_w, 0)
	lb.add_theme_color_override("font_color", C_LABEL)
	hb.add_child(lb)
	ctrl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(ctrl)
	parent.add_child(hb)


func field_line(parent: Control, label_text: String, key: String, value: Variant = "") -> LineEdit:
	var le := LineEdit.new()
	le.text = str(value)
	_add_labeled(parent, label_text, le)
	_fields[key] = le
	return le


func field_int(parent: Control, label_text: String, key: String, value: Variant = 0, min_v: int = -2147483647, max_v: int = 2147483647) -> SpinBox:
	var sb := SpinBox.new()
	sb.min_value = min_v
	sb.max_value = max_v
	sb.value = float(value) if str(value).is_valid_float() else 0.0
	_add_labeled(parent, label_text, sb)
	_fields[key] = sb
	return sb


func field_text(parent: Control, label_text: String, key: String, value: Variant = "", min_h: float = 80.0) -> TextEdit:
	var te := TextEdit.new()
	te.text = str(value)
	te.custom_minimum_size = Vector2(0, min_h)
	_add_labeled(parent, label_text, te)
	_fields[key] = te
	return te


func field_check(parent: Control, label_text: String, key: String, checked: bool = false) -> CheckBox:
	var cb := CheckBox.new()
	cb.button_pressed = checked
	cb.text = label_text
	parent.add_child(cb)
	_fields[key] = cb
	return cb


## options: [[label, id], ...]
func field_select(parent: Control, label_text: String, key: String, options: Array, selected_id: Variant = 0) -> OptionButton:
	var ob := OptionButton.new()
	for opt in options:
		ob.add_item(str(opt[0]), int(opt[1]))
	_select_by_id(ob, int(selected_id))
	_add_labeled(parent, label_text, ob)
	_fields[key] = ob
	return ob


## 独立 OptionButton（不注册到 _fields）
func make_select(options: Array, selected_id: Variant = 0) -> OptionButton:
	var ob := OptionButton.new()
	for opt in options:
		ob.add_item(str(opt[0]), int(opt[1]))
	_select_by_id(ob, int(selected_id))
	return ob


func make_label(text: String, color: Color = C_LABEL) -> Label:
	var lb := Label.new()
	lb.text = text
	lb.add_theme_color_override("font_color", color)
	return lb


func make_comment(text: String) -> Label:
	var lb := Label.new()
	lb.text = text
	lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lb.add_theme_color_override("font_color", Color(0.45, 0.45, 0.52, 1))
	lb.add_theme_font_size_override("font_size", 12)
	return lb


## 标签容器（各对话框的子标签页）
func make_tabs() -> TabContainer:
	var tc := TabContainer.new()
	tc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return tc


## 带标题的标签页
func make_tab_page(tc: TabContainer, tab_title: String) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.name = tab_title
	page.add_theme_constant_override("separation", 6)
	tc.add_child(page)
	return page


## 触发块（条件/结果），自动设置数据源
func make_trigger(mode: int, none_label: String = "无条件") -> MudTriggerEditor:
	var te := MudTriggerEditor.new(mode, none_label)
	te.set_data_source(_data)
	return te


# ===================== 通用收集 =====================

func _collect_fields() -> Dictionary:
	var out: Dictionary = {}
	for key in _fields:
		var c: Variant = _fields[key]
		if c is LineEdit:
			out[key] = (c as LineEdit).text
		elif c is SpinBox:
			out[key] = int((c as SpinBox).value)
		elif c is TextEdit:
			out[key] = (c as TextEdit).text
		elif c is CheckBox:
			out[key] = 1 if (c as CheckBox).button_pressed else 0
		elif c is OptionButton:
			out[key] = (c as OptionButton).get_selected_id()
	return out


func _select_by_id(ob: OptionButton, id: int) -> void:
	for i in range(ob.item_count):
		if ob.get_item_id(i) == id:
			ob.select(i)
			return
	if ob.item_count > 0:
		ob.select(0)


## 数值转换（用于 JSON 字段）
func _num(s: String) -> Variant:
	var t: String = s.strip_edges()
	if t.is_valid_int():
		return t.to_int()
	if t.is_valid_float():
		return t.to_float()
	return t


## 加载“type+data+ops”触发字段（type=2 时 data 存的是脚本）。
## 对应 ME 各表 xxx_type / xxx / xxx_ops 三字段与 trigger_ui 的绑定。
func load_trigger(te: MudTriggerEditor, type_val: Variant, data_val: Variant, ops_val: Variant) -> void:
	var tp: int = int(type_val)
	var data_str: String = str(data_val) if data_val != null else ""
	if tp == 2:
		te.set_block(2, "", data_str, 0)
	else:
		te.set_block(tp, data_str, "", int(ops_val))


## 收集触发字段 → {type_key, data_key, ops_key}。
## ops_key 传空字符串时表示该表无 ops 字段（如 RESULT 触发），则不写出 ops。
func collect_trigger(te: MudTriggerEditor, type_key: String, data_key: String, ops_key: String = "") -> Dictionary:
	var b: Dictionary = te.get_block()
	var out: Dictionary = {}
	out[type_key] = b["type"]
	if int(b["type"]) == 2:
		out[data_key] = b["script"]
	else:
		out[data_key] = b["config"]
		if ops_key != "":
			out[ops_key] = b["ops"]
	return out


# ===================== 暗色主题 =====================

func _build_theme() -> Theme:
	var t := Theme.new()

	# 对话框窗口背景
	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color = C_BG
	panel_sb.border_width_bottom = 1
	panel_sb.border_width_top = 1
	panel_sb.border_width_left = 1
	panel_sb.border_width_right = 1
	panel_sb.border_color = C_BORDER
	panel_sb.content_margin_left = 10
	panel_sb.content_margin_right = 10
	panel_sb.content_margin_top = 10
	panel_sb.content_margin_bottom = 10
	t.set_stylebox("panel", "PopupMenu", panel_sb)

	# 窗口自身面板
	var win_sb := StyleBoxFlat.new()
	win_sb.bg_color = C_BG
	t.set_stylebox("panel", "Window", win_sb)

	# 按钮
	for st in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = C_PANEL2 if st == "normal" else (C_HOVER if st == "hover" else C_SELECTED)
		sb.border_width_bottom = 1
		sb.border_width_top = 1
		sb.border_width_left = 1
		sb.border_width_right = 1
		sb.border_color = C_BORDER
		sb.corner_radius_top_left = 3
		sb.corner_radius_top_right = 3
		sb.corner_radius_bottom_left = 3
		sb.corner_radius_bottom_right = 3
		sb.content_margin_left = 8
		sb.content_margin_right = 8
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
		t.set_stylebox(st, "Button", sb)
	t.set_color("font_color", "Button", C_TEXT)
	t.set_color("font_hover_color", "Button", C_TEXT)
	t.set_color("font_pressed_color", "Button", C_TEXT)

	# 单行输入
	var le_sb := StyleBoxFlat.new()
	le_sb.bg_color = C_FIELD
	le_sb.border_width_bottom = 1
	le_sb.border_width_top = 1
	le_sb.border_width_left = 1
	le_sb.border_width_right = 1
	le_sb.border_color = C_BORDER
	le_sb.corner_radius_top_left = 2
	le_sb.corner_radius_top_right = 2
	le_sb.corner_radius_bottom_left = 2
	le_sb.corner_radius_bottom_right = 2
	le_sb.content_margin_left = 5
	le_sb.content_margin_right = 5
	le_sb.content_margin_top = 3
	le_sb.content_margin_bottom = 3
	t.set_stylebox("normal", "LineEdit", le_sb)
	t.set_color("font_color", "LineEdit", C_TEXT)
	t.set_color("caret_color", "LineEdit", C_TEXT)

	# 多行输入
	t.set_stylebox("normal", "TextEdit", le_sb.duplicate())
	t.set_color("font_color", "TextEdit", C_TEXT)
	t.set_color("caret_color", "TextEdit", C_TEXT)

	# 标签
	t.set_color("font_color", "Label", C_TEXT)

	# 下拉框
	t.set_stylebox("normal", "OptionButton", le_sb.duplicate())
	t.set_stylebox("hover", "OptionButton", le_sb.duplicate())
	t.set_stylebox("pressed", "OptionButton", le_sb.duplicate())
	t.set_stylebox("focus", "OptionButton", le_sb.duplicate())
	t.set_color("font_color", "OptionButton", C_TEXT)

	# SpinBox
	t.set_color("font_color", "SpinBox", C_TEXT)

	# TabContainer
	var tab_sb := StyleBoxFlat.new()
	tab_sb.bg_color = C_PANEL
	tab_sb.border_width_bottom = 1
	tab_sb.border_color = C_BORDER
	tab_sb.content_margin_left = 6
	tab_sb.content_margin_right = 6
	tab_sb.content_margin_top = 6
	tab_sb.content_margin_bottom = 6
	t.set_stylebox("panel", "TabContainer", tab_sb)
	var tab_btn := StyleBoxFlat.new()
	tab_btn.bg_color = C_PANEL2
	tab_btn.border_width_bottom = 1
	tab_btn.border_color = C_BORDER
	tab_btn.content_margin_left = 10
	tab_btn.content_margin_right = 10
	tab_btn.content_margin_top = 4
	tab_btn.content_margin_bottom = 4
	t.set_stylebox("tab_unselected", "TabContainer", tab_btn)
	var tab_sel := StyleBoxFlat.new()
	tab_sel.bg_color = C_SELECTED
	tab_sel.content_margin_left = 10
	tab_sel.content_margin_right = 10
	tab_sel.content_margin_top = 4
	tab_sel.content_margin_bottom = 4
	t.set_stylebox("tab_selected", "TabContainer", tab_sel)
	t.set_color("font_selected_color", "TabContainer", C_TEXT)
	t.set_color("font_unselected_color", "TabContainer", C_LABEL)

	# 分隔线
	var sep_sb := StyleBoxFlat.new()
	sep_sb.bg_color = C_BORDER
	sep_sb.content_margin_top = 1
	sep_sb.content_margin_bottom = 1
	t.set_stylebox("separator", "HSeparator", sep_sb)

	# 滚动容器
	var scroll_sb := StyleBoxFlat.new()
	scroll_sb.bg_color = C_PANEL
	t.set_stylebox("panel", "ScrollContainer", scroll_sb)

	# ItemList
	var il_sb := StyleBoxFlat.new()
	il_sb.bg_color = C_FIELD
	il_sb.border_width_bottom = 1
	il_sb.border_width_top = 1
	il_sb.border_width_left = 1
	il_sb.border_width_right = 1
	il_sb.border_color = C_BORDER
	t.set_stylebox("panel", "ItemList", il_sb)
	t.set_color("font_color", "ItemList", C_TEXT)
	t.set_color("guide_color", "ItemList", C_BORDER)

	return t
