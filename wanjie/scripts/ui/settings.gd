## 设置场景控制器
extends Control

const SETTINGS_PATH := "user://settings.cfg"

## 节点引用
@onready var player_name_input: LineEdit = %PlayerNameInput
@onready var difficulty_option: OptionButton = %DifficultyOption
@onready var font_size_option: OptionButton = %FontSizeOption
@onready var anim_toggle: CheckButton = %AnimToggle
@onready var fullscreen_toggle: CheckButton = %FullscreenToggle
@onready var text_speed_option: OptionButton = %TextSpeedOption
@onready var auto_save_option: OptionButton = %AutoSaveOption
@onready var editor_mode_option: OptionButton = %EditorModeOption
@onready var fullscreen_toggle: CheckButton = %FullscreenToggle
@onready var master_volume: HSlider = %MasterVolume
@onready var bgm_volume: HSlider = %BGMVolume
@onready var sfx_volume: HSlider = %SFXVolume
@onready var master_percent: Label = %MasterPercent
@onready var bgm_percent: Label = %BGMPercent
@onready var sfx_percent: Label = %SFXPercent
@onready var ai_toggle: CheckButton = %AIToggle
@onready var ai_npc_toggle: CheckButton = %AINPCToggle
@onready var version_label: Label = %VersionLabel

func _ready() -> void:
	_load_settings()
	version_label.text = "万界诗篇 v1.0.0"
	# 连接音量滑块信号
	master_volume.value_changed.connect(_on_master_volume_changed)
	bgm_volume.value_changed.connect(_on_bgm_volume_changed)
	sfx_volume.value_changed.connect(_on_sfx_volume_changed)

## 加载设置到UI
## 全屏切换即时生效
func _on_fullscreen_toggled(enabled: bool) -> void:
	GameManager.user_data.fullscreen = enabled
	_apply_fullscreen(enabled)

func _apply_fullscreen(enabled: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)

func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		GameManager.user_data.player_name = config.get_value("game", "player_name", "旅者")
		GameManager.user_data.difficulty_mode = config.get_value("game", "difficulty", "adaptive")
		GameManager.user_data.font_size_preset = config.get_value("display", "font_size", "medium")
		GameManager.user_data.animations_enabled = config.get_value("display", "animations", true)
		GameManager.user_data.ai_enabled = config.get_value("ai", "enabled", true)
		GameManager.user_data.ai_npc_enabled = config.get_value("ai", "npc_enabled", false)
	var ud := GameManager.user_data
	player_name_input.text = ud.player_name
	# 难度
	var diff_map := ["adaptive", "fixed_easy", "fixed_normal", "fixed_hard"]
	var idx := diff_map.find(ud.difficulty_mode)
	difficulty_option.selected = max(idx, 0)
	# 字体大小
	var font_map := ["small", "medium", "large", "xlarge"]
	idx = font_map.find(ud.font_size_preset)
	font_size_option.selected = max(idx, 0)
	# 动效
	anim_toggle.button_pressed = ud.animations_enabled
	fullscreen_toggle.button_pressed = ud.fullscreen
	var speed_map := ["slow", "standard", "fast"]
	text_speed_option.selected = max(speed_map.find(ud.text_speed_preset), 0)
	var as_map := [60.0, 180.0, 300.0, 600.0]
	var as_idx := 2
	for i in as_map.size():
		if absf(ud.editor_auto_save_interval - as_map[i]) < 5.0:
			as_idx = i
			break
	auto_save_option.selected = as_idx
	# 编辑器模式（同步 EditorMode 单例）
	editor_mode_option.selected = EditorMode.current_mode
	editor_mode_option.tooltip_text = "编辑器三档模式：简易（零基础）/ 详细（标准）/ 详尽（高级全部）"
	editor_mode_option.item_selected.connect(func(idx: int):
		EditorMode.set_mode(idx))
	fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)
	# 全屏
	fullscreen_toggle.button_pressed = (DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	# 音量
	var master_val: float = config.get_value("audio", "master", 0.8)
	var bgm_val: float = config.get_value("audio", "bgm", 0.8)
	var sfx_val: float = config.get_value("audio", "sfx", 0.8)
	master_volume.value = master_val
	bgm_volume.value = bgm_val
	sfx_volume.value = sfx_val
	_update_volume_labels()
	_apply_volume("Master", master_val)
	_apply_volume("BGM", bgm_val)
	_apply_volume("SFX", sfx_val)
	# AI
	ai_toggle.button_pressed = ud.ai_enabled
	ai_npc_toggle.button_pressed = ud.ai_npc_enabled

## 更新音量百分比标签
func _update_volume_labels() -> void:
	master_percent.text = "%d%%" % int(master_volume.value * 100)
	bgm_percent.text = "%d%%" % int(bgm_volume.value * 100)
	sfx_percent.text = "%d%%" % int(sfx_volume.value * 100)

## 应用音量到音频总线
func _apply_volume(bus_name: String, linear_value: float) -> void:
	var bus_idx := AudioServer.get_bus_index(bus_name)
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(linear_value))

## 音量变化回调
func _on_master_volume_changed(_value: float) -> void:
	_apply_volume("Master", master_volume.value)
	master_percent.text = "%d%%" % int(master_volume.value * 100)

func _on_bgm_volume_changed(_value: float) -> void:
	_apply_volume("BGM", bgm_volume.value)
	bgm_percent.text = "%d%%" % int(bgm_volume.value * 100)

func _on_sfx_volume_changed(_value: float) -> void:
	_apply_volume("SFX", sfx_volume.value)
	sfx_percent.text = "%d%%" % int(sfx_volume.value * 100)

## 字体大小实时预览
func _on_font_size_changed(index: int) -> void:
	var font_map := ["small", "medium", "large", "xlarge"]
	if index >= 0 and index < font_map.size():
		ThemeManager.apply_font_preset(font_map[index])

## 保存设置
func _on_save_pressed() -> void:
	var ud := GameManager.user_data
	ud.player_name = player_name_input.text
	var diff_map := ["adaptive", "fixed_easy", "fixed_normal", "fixed_hard"]
	ud.difficulty_mode = diff_map[difficulty_option.selected]
	var font_map := ["small", "medium", "large", "xlarge"]
	ud.font_size_preset = font_map[font_size_option.selected]
	ud.animations_enabled = anim_toggle.button_pressed
	ud.fullscreen = fullscreen_toggle.button_pressed
	var speed_map2 := ["slow", "standard", "fast"]
	ud.text_speed_preset = speed_map2[text_speed_option.selected]
	var as_map2 := [60.0, 180.0, 300.0, 600.0]
	ud.editor_auto_save_interval = as_map2[auto_save_option.selected]
	ud.ai_enabled = ai_toggle.button_pressed
	ud.ai_npc_enabled = ai_npc_toggle.button_pressed
	# 全屏切换
	if fullscreen_toggle.button_pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	# 应用动效设置到 ThemeManager
	ThemeManager.set_animations_enabled(ud.animations_enabled)
	_apply_fullscreen(ud.fullscreen)
	ThemeManager.apply_font_preset(ud.font_size_preset)
	# 持久化到配置文件
	var config := ConfigFile.new()
	config.set_value("game", "player_name", ud.player_name)
	config.set_value("game", "difficulty", ud.difficulty_mode)
	config.set_value("display", "font_size", ud.font_size_preset)
	config.set_value("display", "animations", ud.animations_enabled)
	config.set_value("display", "fullscreen", ud.fullscreen)
	config.set_value("audio", "master", master_volume.value)
	config.set_value("audio", "bgm", bgm_volume.value)
	config.set_value("audio", "sfx", sfx_volume.value)
	config.set_value("ai", "enabled", ud.ai_enabled)
	config.set_value("ai", "npc_enabled", ud.ai_npc_enabled)
	config.save(SETTINGS_PATH)
	# user_data 侧同步持久化（settings.cfg 与 user_data 双源一致）
	GameManager.save_user_data()
	SceneManager.go_back_to_hub()

## 返回
func _on_back_pressed() -> void:
	SceneManager.go_back_to_hub()

## 清除缓存
func _on_clear_cache_pressed() -> void:
	var dir := DirAccess.open("user://")
	if dir:
		if dir.dir_exists("cache"):
			_clear_directory("user://cache")
	$SaveConfirmPopup.visible = true
	$SaveConfirmPopup/Label.text = "缓存已清除"
	await get_tree().create_timer(2.0).timeout
	$SaveConfirmPopup.visible = false

## 恢复默认设置（确认后重置偏好）
func _on_reset_defaults_pressed() -> void:
	var confirm := ConfirmationDialog.new()
	confirm.dialog_text = "确定恢复默认设置？\n仅重置偏好项（姓名/文本速度/动画等），剧本与存档不受影响。"
	confirm.confirmed.connect(func():
		GameManager.user_data.reset_to_defaults()
		GameManager.save_user_data()
		_load_settings()
		ToastManager.success("已恢复默认设置"))
	add_child(confirm)
	confirm.popup_centered()

## 导出数据
func _on_export_data_pressed() -> void:
	var export_dialog: FileDialog = $ExportDialog
	export_dialog.popup_centered_ratio(0.5)

func _clear_directory(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if dir.current_is_dir():
			_clear_directory(path.path_join(file_name))
			dir.remove(file_name)
		else:
			dir.remove(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

## 导出到选定目录
func _on_export_dialog_dir_selected(dir_path: String) -> void:
	var exported_count := 0
	for sid in ScriptDataManager.user_scripts:
		var export_file := dir_path.path_join("%s.json" % sid)
		if ScriptDataManager.export_script(sid, export_file):
			exported_count += 1
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.save(dir_path.path_join("settings.cfg"))
	$SaveConfirmPopup.visible = true
	$SaveConfirmPopup/Label.text = "已导出 %d 个文件到:\n%s" % [exported_count + 1, dir_path]
	await get_tree().create_timer(3.0).timeout
	$SaveConfirmPopup.visible = false
