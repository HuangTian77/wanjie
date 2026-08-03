## 剧本体验器主控制器
extends Control

## 引擎引用
var world_state: RefCounted = null
var event_engine: RefCounted = null
var economy_engine: RefCounted = null
var combat_engine: RefCounted = null
## 蓝图执行器（事件有蓝图图时驱动运行时）
var blueprint_executor: RefCounted = null
## 当前执行的蓝图图（供 resume_choice 使用）
var _blueprint_active_graph: Dictionary = {}
## 当前蓝图选择的选项文本
var _blueprint_choices: Array = []
## 当前剧本数据
var script_data: WorldScriptData = null
## 当前事件索引
var current_event_index: int = 0
## 打字机效果
var _typewriter_text: String = ""
var _typewriter_index: int = 0
var _typewriter_timer: float = 0.0
var _typewriter_done: bool = true

## UI节点
@onready var script_title: Label = %ScriptTitle
@onready var time_label: Label = %TimeLabel
@onready var main_text: RichTextLabel = %MainText
@onready var choice_container: VBoxContainer = %ChoiceContainer
@onready var history_text: RichTextLabel = %HistoryText
@onready var player_name_label: Label = %PlayerNameLabel
@onready var player_level_label: Label = %PlayerLevelLabel
@onready var hp_bar: ProgressBar = %PlayerHPBar
@onready var hp_label: Label = %PlayerHPLabel
@onready var mp_bar: ProgressBar = %PlayerMPBar
@onready var player_gold_label: Label = %PlayerGoldLabel
@onready var menu_panel: Control = %MenuPanel
@onready var history_panel: Control = %HistoryPanel
@onready var history_toggle: Button = %HistoryToggle

func _ready() -> void:
	_init_engines()
	_start_experience()
	history_toggle.pressed.connect(_on_history_toggle_pressed)

func _process(delta: float) -> void:
	# 打字机效果
	if not _typewriter_done and _typewriter_index < _typewriter_text.length():
		_typewriter_timer += delta
		var speed := 0.03 if ThemeManager.animations_enabled else 0.001
		while _typewriter_timer >= speed and _typewriter_index < _typewriter_text.length():
			_typewriter_timer -= speed
			_typewriter_index += 1
			main_text.visible_characters = _typewriter_index
		if _typewriter_index >= _typewriter_text.length():
			_typewriter_done = true

func _unhandled_input(event: InputEvent) -> void:
	# 点击跳过打字机
	if not _typewriter_done and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_skip_typewriter()
		get_viewport().set_input_as_handled()

func _skip_typewriter() -> void:
	_typewriter_index = _typewriter_text.length()
	_typewriter_done = true
	main_text.visible_characters = -1

## 初始化引擎
func _init_engines() -> void:
	var sid: String = SceneManager.current_script_id
	if sid.is_empty():
		return
	script_data = ScriptDataManager.find_script(sid)
	if script_data == null:
		script_data = GameManager.get_script_data(sid)
	if script_data == null:
		return
	script_data.ensure_subsystems()
	
	world_state = load("res://scripts/player/world_state.gd").new()
	if script_data.worldview:
		world_state.initialize_factions(script_data.worldview)
	
	event_engine = load("res://scripts/player/event_engine.gd").new()
	event_engine.init(script_data.event_system, world_state, {})
	event_engine.choices_presented.connect(_on_choices_presented)
	event_engine.event_triggered.connect(_on_event_triggered)
	
	economy_engine = load("res://scripts/player/economy_engine.gd").new()
	economy_engine.init(script_data.economy_system, {"gold": 100}, {})
	
	combat_engine = load("res://scripts/player/combat_engine.gd").new()
	combat_engine.init(script_data.ability_system)
	combat_engine.set_player_stats({
		"name": GameManager.user_data.player_name,
		"hp": 100, "max_hp": 100,
		"mp": 50, "max_mp": 50,
		"atk": 15, "def": 10,
		"matk": 12, "mdef": 8,
		"speed": 10, "agility": 10,
		"level": 1, "skills": []
	})
	
	SaveManager.start_new_game(sid)
	
	# 蓝图执行器: 注入全部引擎, 事件带蓝图图时由蓝图驱动运行时
	blueprint_executor = load("res://scripts/player/blueprint_executor.gd").new()
	blueprint_executor.init_engines(
		event_engine, economy_engine, combat_engine, world_state,
		SaveManager.current_save.player_state if SaveManager.current_save else {},
		script_data
	)

## 开始体验
func _start_experience() -> void:
	if script_data == null:
		main_text.text = "无法加载剧本数据"
		return
	script_title.text = script_data.name
	_update_ui()
	var bg_text := ""
	if script_data.worldview and not script_data.worldview.background_story.is_empty():
		bg_text = script_data.worldview.background_story
	else:
		bg_text = script_data.description
	_set_main_text("[b]【%s】[/b]\n\n%s" % [script_data.name, bg_text])
	_add_history("进入世界: %s" % script_data.name)
	_advance_to_next_event()

## 推进到下一个事件
func _advance_to_next_event() -> void:
	if event_engine == null:
		return
	if world_state:
		world_state.advance_time(1)
		world_state.tick_effects()
	_update_ui()
	
	var triggerable: Array = event_engine.check_triggerable_events()
	if triggerable.is_empty():
		var random_event: Dictionary = event_engine.check_random_events()
		if not random_event.is_empty():
			_run_event(random_event)
		else:
			_set_main_text("你在这个世界中继续探索...\n暂时没有发现特别的事件。\n\n[i][点击继续探索][/i]")
			_clear_choices()
			_add_choice_button("继续探索", "_on_continue_exploring")
	else:
		_run_event(triggerable[0])

## 统一事件入口: 事件带蓝图图则蓝图驱动, 否则回退传统 event_engine 流程
func _run_event(event: Dictionary) -> void:
	if blueprint_executor == null:
		event_engine.trigger_event(event)
		return
	var graph := _get_event_blueprint_graph(event)
	if not graph.is_empty():
		_run_blueprint_event(event, graph)
	else:
		event_engine.trigger_event(event)

## 获取事件关联的蓝图图（无图返回空字典）
func _get_event_blueprint_graph(event: Dictionary) -> Dictionary:
	if script_data == null or script_data.event_system == null:
		return {}
	var graphs: Dictionary = script_data.event_system.blueprint_graphs
	var eid: String = event.get("id", "")
	if eid != "" and graphs.has(eid):
		return graphs[eid]
	return {}

## 蓝图驱动事件: 标记触发 → 显示描述 → 执行图 → 处理暂停/选择
func _run_blueprint_event(event: Dictionary, graph: Dictionary) -> void:
	event_engine.mark_triggered(event)
	var event_name: String = event.get("name", "未知事件")
	var desc: String = event.get("description", "发生了某件事...")
	_set_main_text("[b]【%s】[/b]\n\n%s" % [event_name, desc])
	_add_history("事件(蓝图): %s" % event_name)
	_blueprint_active_graph = graph
	_blueprint_choices = []
	_clear_choices()
	var result: Dictionary = blueprint_executor.execute_graph(graph)
	_handle_blueprint_result(result)

## 处理蓝图执行结果: 暂停等待选择 / 出错 / 正常完成
func _handle_blueprint_result(result: Dictionary) -> void:
	var pending: Dictionary = result.get("pending_choice", {})
	if not pending.is_empty():
		_blueprint_choices = pending.get("options", [])
		_show_blueprint_choices()
		return
	var err: String = result.get("error", "")
	if err != "":
		_add_history("[错误] %s" % err)
	_clear_choices()
	_add_choice_button("继续", "_on_continue_pressed")

## 显示蓝图 story_choice 的选择按钮
func _show_blueprint_choices() -> void:
	_clear_choices()
	for i in _blueprint_choices.size():
		var btn := Button.new()
		btn.text = "%d. %s" % [i + 1, _blueprint_choices[i]]
		btn.custom_minimum_size = Vector2(0, 44)
		btn.add_theme_font_size_override("font_size", 15)
		btn.pressed.connect(_on_blueprint_choice_pressed.bind(i))
		choice_container.add_child(btn)

## 蓝图选择回调: resume_choice 从选择输出端口继续执行
func _on_blueprint_choice_pressed(index: int) -> void:
	if blueprint_executor == null or _blueprint_active_graph.is_empty():
		return
	_blueprint_choices = []
	var result: Dictionary = blueprint_executor.resume_choice(_blueprint_active_graph, index)
	_handle_blueprint_result(result)

## 设置主文本（带打字机效果 + BBCode）
func _set_main_text(text: String) -> void:
	_typewriter_text = text
	_typewriter_index = 0
	_typewriter_timer = 0.0
	_typewriter_done = false
	main_text.text = text
	main_text.visible_characters = 0
	if not ThemeManager.animations_enabled:
		_skip_typewriter()

## 清除选择按钮
func _clear_choices() -> void:
	for child in choice_container.get_children():
		child.queue_free()

## 添加选择按钮（卡片式）
func _add_choice_button(text: String, method: String = "") -> void:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 44)
	btn.add_theme_font_size_override("font_size", 15)
	# hover 反馈: 文字加深金色（主题已有 hover 背景, 这里强化文字对比）
	btn.mouse_entered.connect(func():
		btn.add_theme_color_override("font_color", ThemeManager.C_ACCENT_DARK)
	)
	btn.mouse_exited.connect(func():
		btn.remove_theme_override("font_color")
	)
	if not method.is_empty():
		btn.pressed.connect(Callable(self, method))
	choice_container.add_child(btn)
	# 进入动画（容器内 position 会被布局覆盖, 改用 scale + alpha）
	if ThemeManager.animations_enabled:
		btn.modulate.a = 0.0
		btn.scale = Vector2(0.96, 0.96)
		var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.set_parallel(true)
		tween.tween_property(btn, "modulate:a", 1.0, 0.2)
		tween.tween_property(btn, "scale", Vector2.ONE, 0.2)

## 添加历史记录
func _add_history(text: String) -> void:
	history_text.text += "[color=#6b5e52]%s[/color]\n" % text

## 更新UI
func _update_ui() -> void:
	if SaveManager.current_save:
		var ps: Dictionary = SaveManager.current_save.player_state
		player_name_label.text = ps.get("name", "旅者")
		player_level_label.text = "Lv.%d" % ps.get("level", 1)
		# HP 进度条（优先真实战斗状态, 回退事件数推算）
		var max_hp: int = ps.get("max_hp", 100)
		var current_hp: int = max_hp
		if combat_engine != null and combat_engine.get("player_combat_stats") != null and not (combat_engine.player_combat_stats as Dictionary).is_empty():
			current_hp = int(combat_engine.player_combat_stats.get("hp", max_hp))
			max_hp = int(combat_engine.player_combat_stats.get("max_hp", max_hp))
		else:
			current_hp = max_hp - (event_engine.triggered_events.size() * 5 if event_engine else 0)
		current_hp = clampi(current_hp, 0, max_hp)
		hp_bar.max_value = max_hp
		hp_bar.value = current_hp
		hp_label.text = "HP: %d/%d" % [current_hp, max_hp]
		# MP 进度条
		var max_mp: int = ps.get("max_mp", 50)
		mp_bar.max_value = max_mp
		mp_bar.value = max_mp
		# 金币
		var inv: Dictionary = ps.get("inventory", {})
		player_gold_label.text = "金币: %d" % inv.get("gold", 0)
	if world_state:
		time_label.text = world_state.get_time_display()

## === 事件回调 ===
func _on_event_triggered(event: Dictionary) -> void:
	var desc: String = event.get("description", "发生了某件事...")
	var event_name: String = event.get("name", "未知事件")
	_set_main_text("[b]【%s】[/b]\n\n%s" % [event_name, desc])
	_add_history("事件: %s" % event_name)

func _on_choices_presented(choices: Array) -> void:
	_clear_choices()
	for i in choices.size():
		var choice: Dictionary = choices[i]
		var btn := Button.new()
		btn.text = "%d. %s" % [i + 1, choice.get("text", "选择")]
		btn.custom_minimum_size = Vector2(0, 44)
		btn.add_theme_font_size_override("font_size", 15)
		var choice_id: String = choice.get("id", "")
		btn.pressed.connect(_on_choice_selected.bind(choice_id))
		choice_container.add_child(btn)
		# 进入动画
		if ThemeManager.animations_enabled:
			btn.modulate.a = 0.0
			var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			tween.tween_property(btn, "modulate:a", 1.0, 0.2).set_delay(i * 0.08)

func _on_choice_selected(choice_id: String) -> void:
	if event_engine == null:
		return
	var consequences: Array = event_engine.make_choice(choice_id)
	_add_history("选择: %s" % choice_id)
	
	var consequence_text := ""
	for c in consequences:
		var target: String = c.get("target", "")
		var effect: String = c.get("effect", "")
		consequence_text += "→ %s: %s\n" % [target, effect]
		_apply_consequence(c)
	
	if consequence_text.is_empty():
		consequence_text = "你的选择已经改变了世界的走向..."
	_set_main_text("[i]你的选择产生了后果...[/i]\n\n%s" % consequence_text)
	_clear_choices()
	_add_choice_button("继续", "_on_continue_pressed")

func _on_continue_pressed() -> void:
	_clear_choices()
	_advance_to_next_event()

func _on_continue_exploring() -> void:
	_advance_to_next_event()

## 应用后果
func _apply_consequence(consequence: Dictionary) -> void:
	var target: String = consequence.get("target", "")
	var effect: String = consequence.get("effect", "")
	
	match target:
		"player":
			if "gold" in effect or "receive" in effect:
				if economy_engine:
					economy_engine.add_currency("gold", 50)
		"world":
			if world_state:
				world_state.set_variable(effect, true)
		_:
			if world_state and target.begins_with("faction"):
				var delta := 10.0
				if "+" in effect:
					var num_str := effect.get_slice("+", 1).strip_edges()
					delta = float(num_str) if num_str.is_valid_float() else 10.0
				elif "-" in effect:
					var num_str := effect.get_slice("-", 1).strip_edges()
					delta = -float(num_str) if num_str.is_valid_float() else -10.0
				world_state.modify_faction_relationship(target, "player", delta)
	
	if SaveManager.current_save:
		SaveManager.current_save.event_history = event_engine.to_dict()
		SaveManager.current_save.world_state = world_state.to_dict() if world_state else {}
		SaveManager.current_save.economy_state = economy_engine.to_dict() if economy_engine else {}

## === 历史记录折叠 ===
func _on_history_toggle_pressed() -> void:
	history_panel.visible = not history_panel.visible
	history_toggle.text = "▲ 收起记录" if history_panel.visible else "▼ 展开记录"

## === 菜单 ===
func _on_menu_pressed() -> void:
	menu_panel.visible = true

func _on_menu_save_pressed() -> void:
	_show_slot_selector("save")

func _on_menu_load_pressed() -> void:
	_show_slot_selector("load")

func _on_menu_back_pressed() -> void:
	SaveManager.autosave()
	menu_panel.visible = false
	SceneManager.go_back_to_hub()

## 显示槽位选择器
func _show_slot_selector(mode: String) -> void:
	var old := get_node_or_null("SlotSelector")
	if old:
		old.queue_free()
	
	var selector := PanelContainer.new()
	selector.name = "SlotSelector"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.96, 0.925, 0.843, 0.98)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(16)
	style.shadow_color = Color(0.29, 0.216, 0.157, 0.2)
	style.shadow_size = 10
	selector.add_theme_stylebox_override("panel", style)
	selector.custom_minimum_size = Vector2(320, 220)
	selector.set_anchors_preset(Control.PRESET_CENTER)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	selector.add_child(vbox)
	
	var title_label := Label.new()
	title_label.text = "选择存档槽位" if mode == "save" else "选择加载槽位"
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)
	
	for slot in 3:
		var btn := Button.new()
		var slot_info := _get_slot_info(slot)
		btn.text = "槽位 %d: %s" % [slot + 1, slot_info]
		btn.custom_minimum_size = Vector2(0, 40)
		if mode == "save":
			btn.pressed.connect(_on_slot_save_selected.bind(slot))
		else:
			btn.pressed.connect(_on_slot_load_selected.bind(slot))
		vbox.add_child(btn)
	
	var cancel_btn := Button.new()
	cancel_btn.text = "取消"
	cancel_btn.pressed.connect(func(): selector.queue_free())
	vbox.add_child(cancel_btn)
	
	add_child(selector)

## 获取槽位信息
func _get_slot_info(slot: int) -> String:
	var save_info := SaveManager.get_slot_info(slot)
	if save_info.is_empty():
		return "(空)"
	return "%s | Lv.%d | %s" % [
		save_info.get("player_name", "?"),
		save_info.get("level", 1),
		save_info.get("play_time", "0:00")
	]

## 槽位保存
func _on_slot_save_selected(slot: int) -> void:
	SaveManager.save_game(slot)
	_add_history("游戏已保存到槽位 %d" % (slot + 1))
	var sel := get_node_or_null("SlotSelector")
	if sel:
		sel.queue_free()
	menu_panel.visible = false

## 槽位加载
func _on_slot_load_selected(slot: int) -> void:
	SaveManager.load_game(slot)
	_add_history("已从槽位 %d 加载" % (slot + 1))
	var sel := get_node_or_null("SlotSelector")
	if sel:
		sel.queue_free()
	menu_panel.visible = false
	_update_ui()
