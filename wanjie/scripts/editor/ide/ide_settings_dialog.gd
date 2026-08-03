## IDE编辑器设置对话框 - 复刻 Godot 4.7.1 Editor Settings
## 分类Tab(界面/场景编辑器/行为) + ConfigFile持久化到 user://editor_settings.cfg
extends AcceptDialog

const IDETheme = preload("res://scripts/editor/ide/ide_theme.gd")

const SETTINGS_PATH := "user://editor_settings.cfg"

signal settings_saved(settings: Dictionary)

## 默认设置
const DEFAULTS := {
	"interface/ui_font_size": 12,
	"interface/theme": "暗色 (Godot)",
	"interface/show_fps": false,
	"editor/show_grid": true,
	"editor/grid_snap": false,
	"editor/grid_step": 8.0,
	"editor/default_domain": "2D",
	"editor/show_signal_icons": true,
	"behavior/auto_save": true,
	"behavior/auto_save_interval": 60,
	"behavior/undo_history_limit": 100,
	"behavior/confirm_delete": true,
}

var _settings: Dictionary = {}
var _editors: Dictionary = {}  # key -> Control (编辑控件)

func _ready() -> void:
	title = "编辑器设置"
	size = Vector2i(560, 460)
	ok_button_text = "关闭"
	_settings = _load_settings()
	_build_ui()

## 静态: 读取设置(供其他模块查询), 不存在则返回默认值
static func load_settings() -> Dictionary:
	var cfg := ConfigFile.new()
	var result: Dictionary = DEFAULTS.duplicate(true)
	if cfg.load(SETTINGS_PATH) == OK:
		for key in DEFAULTS:
			var sec: String = key.get_slice("/", 0)
			var prop: String = key.get_slice("/", 1)
			if cfg.has_section_key(sec, prop):
				result[key] = cfg.get_value(sec, prop)
	return result

func _load_settings() -> Dictionary:
	return load_settings()

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	for key in _settings:
		var sec: String = key.get_slice("/", 0)
		var prop: String = key.get_slice("/", 1)
		cfg.set_value(sec, prop, _settings[key])
	cfg.save(SETTINGS_PATH)
	settings_saved.emit(_settings.duplicate(true))

func _build_ui() -> void:
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_UI)
	add_child(tabs)

	_build_interface_tab(tabs)
	_build_editor_tab(tabs)
	_build_behavior_tab(tabs)

	# 底部按钮: 恢复默认 + 应用
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 6)
	add_child(btn_row)

	var reset_btn := Button.new()
	reset_btn.text = "恢复默认"
	reset_btn.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_UI)
	reset_btn.pressed.connect(_on_reset_defaults)
	btn_row.add_child(reset_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_row.add_child(spacer)

	var apply_btn := Button.new()
	apply_btn.text = "应用并保存"
	apply_btn.add_theme_color_override("font_color", IDETheme.C_ACCENT)
	apply_btn.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_UI)
	apply_btn.pressed.connect(_on_apply)
	btn_row.add_child(apply_btn)

func _make_scroll_tab(tabs: TabContainer, tab_name: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = tab_name
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(vbox)
	return vbox

func _build_interface_tab(tabs: TabContainer) -> void:
	var vbox := _make_scroll_tab(tabs, "界面")
	_add_section_label(vbox, "外观")
	_add_option_row(vbox, "主题", "interface/theme", ["暗色 (Godot)", "亮色", "高对比"])
	_add_int_row(vbox, "UI字体大小", "interface/ui_font_size", 9, 20)
	_add_bool_row(vbox, "显示FPS", "interface/show_fps")

func _build_editor_tab(tabs: TabContainer) -> void:
	var vbox := _make_scroll_tab(tabs, "场景编辑器")
	_add_section_label(vbox, "网格")
	_add_bool_row(vbox, "显示网格", "editor/show_grid")
	_add_bool_row(vbox, "网格吸附", "editor/grid_snap")
	_add_float_row(vbox, "吸附步长", "editor/grid_step", 1.0, 128.0)
	_add_section_label(vbox, "节点")
	_add_option_row(vbox, "默认编辑域", "editor/default_domain", ["2D", "3D"])
	_add_bool_row(vbox, "显示信号/分组图标", "editor/show_signal_icons")

func _build_behavior_tab(tabs: TabContainer) -> void:
	var vbox := _make_scroll_tab(tabs, "行为")
	_add_section_label(vbox, "自动保存")
	_add_bool_row(vbox, "启用自动保存", "behavior/auto_save")
	_add_int_row(vbox, "自动保存间隔(秒)", "behavior/auto_save_interval", 10, 600)
	_add_section_label(vbox, "编辑")
	_add_int_row(vbox, "撤销历史上限", "behavior/undo_history_limit", 10, 500)
	_add_bool_row(vbox, "删除前确认", "behavior/confirm_delete")

# === 行构建 ===

func _add_section_label(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_UI)
	label.add_theme_color_override("font_color", IDETheme.C_ACCENT)
	parent.add_child(label)

func _make_row(parent: Control, label_text: String) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 150
	label.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_UI)
	label.add_theme_color_override("font_color", IDETheme.C_TEXT)
	hbox.add_child(label)
	parent.add_child(hbox)
	return hbox

func _add_bool_row(parent: Control, label_text: String, key: String) -> void:
	var hbox := _make_row(parent, label_text)
	var check := CheckBox.new()
	check.button_pressed = bool(_settings.get(key, false))
	check.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_UI)
	hbox.add_child(check)
	_editors[key] = check

func _add_int_row(parent: Control, label_text: String, key: String, min_v: int, max_v: int) -> void:
	var hbox := _make_row(parent, label_text)
	var spin := SpinBox.new()
	spin.min_value = min_v
	spin.max_value = max_v
	spin.step = 1
	spin.value = int(_settings.get(key, 0))
	spin.custom_minimum_size.x = 120
	spin.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_UI)
	hbox.add_child(spin)
	_editors[key] = spin

func _add_float_row(parent: Control, label_text: String, key: String, min_v: float, max_v: float) -> void:
	var hbox := _make_row(parent, label_text)
	var spin := SpinBox.new()
	spin.min_value = min_v
	spin.max_value = max_v
	spin.step = 0.5
	spin.value = float(_settings.get(key, 0.0))
	spin.custom_minimum_size.x = 120
	spin.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_UI)
	hbox.add_child(spin)
	_editors[key] = spin

func _add_option_row(parent: Control, label_text: String, key: String, options: Array) -> void:
	var hbox := _make_row(parent, label_text)
	var opt := OptionButton.new()
	opt.add_theme_font_size_override("font_size", IDETheme.FONT_SIZE_UI)
	var current: String = str(_settings.get(key, ""))
	var selected := 0
	for i in range(options.size()):
		opt.add_item(str(options[i]))
		if str(options[i]) == current:
			selected = i
	opt.selected = selected
	opt.custom_minimum_size.x = 160
	hbox.add_child(opt)
	_editors[key] = opt

# === 收集/应用 ===

func _collect_settings() -> void:
	for key in _editors:
		var ctrl: Control = _editors[key]
		if ctrl is CheckBox:
			_settings[key] = (ctrl as CheckBox).button_pressed
		elif ctrl is SpinBox:
			var sb: SpinBox = ctrl
			_settings[key] = int(sb.value) if sb.step >= 1.0 else sb.value
		elif ctrl is OptionButton:
			var ob: OptionButton = ctrl
			_settings[key] = ob.get_item_text(ob.selected)

func _on_apply() -> void:
	_collect_settings()
	_save_settings()

func _on_reset_defaults() -> void:
	_settings = DEFAULTS.duplicate(true)
	# 重建UI以反映默认值
	for child in get_children():
		if child is TabContainer or child is HBoxContainer:
			child.queue_free()
	_editors.clear()
	_build_ui()

## 打开对话框(居中)
func open() -> void:
	popup_centered()
