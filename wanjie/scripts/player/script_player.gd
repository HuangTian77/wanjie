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
## 自动战斗标记与计时
var _auto_battle: bool = false
## 自动战斗间隔（秒，点击自动按钮循环 0.6/0.3/0.15）
var _auto_interval: float = 0.6
var _auto_timer: float = 0.0

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
@onready var battle_panel: PanelContainer = %BattlePanel
@onready var enemy_info: Label = %EnemyInfo
@onready var battle_log: RichTextLabel = %BattleLog
@onready var tavern_panel: PanelContainer = %TavernPanel
@onready var tavern_char_select: OptionButton = %TavernCharSelect
@onready var tavern_msgs: RichTextLabel = %TavernMsgs
@onready var tavern_input: LineEdit = %TavernInput
@onready var econ_label: Label = %EconLabel
@onready var item_label: Label = %ItemLabel
@onready var quest_label: Label = %QuestLabel
@onready var progress_label: Label = %ProgressLabel
@onready var difficulty_option: OptionButton = %DifficultyOption
## 通关提示是否已显示（防重复）
var _ending_shown: bool = false
## 首次操作提示是否已显示
var _help_shown: bool = false
## 本次体验开始时间（毫秒，菜单显示时长）
var _play_start_time: int = 0
## 战斗当前目标索引（-1 自动选第一个存活）
var _battle_target: int = -1
## 战斗连击计数
var _combo_count: int = 0
## 本次战斗最高连击（结算显示）
var _best_combo: int = 0
## 战斗统计（世界日志）
var _battle_wins: int = 0
var _battle_defeats: int = 0
var _battle_flees: int = 0
@onready var chain_label: Label = %ChainLabel

func _ready() -> void:
	_setup_menu_tooltips()
	_init_engines()
	_start_experience()
	history_toggle.pressed.connect(_on_history_toggle_pressed)
	var hclear := get_node_or_null("%HistoryClear")
	if hclear is Button:
		(hclear as Button).pressed.connect(_on_history_clear_pressed)
	ToastManager.info("已消耗 1 点灵感进入剧本")
	# 定时自动存档（每 5 分钟，可按设置间隔）
	var auto_save_timer := Timer.new()
	auto_save_timer.name = "AutoSaveTimer"
	auto_save_timer.wait_time = maxf(60.0, float(settings_auto_save_interval_min()) * 60.0)
	auto_save_timer.autostart = true
	auto_save_timer.timeout.connect(func():
		_sync_save_state()
		SaveManager.autosave()
		ToastManager.success("已自动存档"))
	add_child(auto_save_timer)

## 自动存档间隔（分钟，读设置，默认 5）
func settings_auto_save_interval_min() -> float:
	var gm: Node = Engine.get_main_loop().root.get_node_or_null("GameManager")
	if gm != null and gm.user_data != null:
		var ud: Resource = gm.user_data
		var v: float = float(ud.get("editor_auto_save_interval")) if ud.get("editor_auto_save_interval") != null else 60.0
		return clampf(v / 60.0, 1.0, 60.0)
	return 5.0

func _process(delta: float) -> void:
	# 自动战斗：定时攻击（间隔可调速）
	if _auto_battle and battle_panel.visible and combat_engine != null and combat_engine.is_active:
		_auto_timer += delta
		if _auto_timer >= _auto_interval:
			_auto_timer = 0.0
			# 智能战斗：HP<50% 优先治疗（MP 够时）
			var used_skill := false
			var hp_now: int = int(combat_engine.player_combat_stats.get("hp", 0))
			var hp_max: int = int(combat_engine.player_combat_stats.get("max_hp", 1))
			if combat_engine.ability_data != null and hp_max > 0 and hp_now < hp_max * 0.5:
				for sk2 in combat_engine.ability_data.skills:
					var etype: String = str(sk2.get("effect", {}).get("type", ""))
					if etype == "heal":
						var mcost2: int = int((sk2.get("cost", {}) as Dictionary).get("mana", 0))
						if mcost2 <= int(combat_engine.player_combat_stats.get("mp", 0)):
							combat_engine.player_use_skill(str(sk2.get("id", "")), -1)
							_refresh_battle_ui()
							used_skill = true
							break
			# 否则 25% 概率释放第一个可用技能
			if not used_skill and combat_engine.ability_data != null and randf() < 0.25:
				for sk in combat_engine.ability_data.skills:
					var mcost: int = int((sk.get("cost", {}) as Dictionary).get("mana", 0))
					if mcost <= int(combat_engine.player_combat_stats.get("mp", 0)):
						combat_engine.player_use_skill(str(sk.get("id", "")), -1)
						_refresh_battle_ui()
						used_skill = true
						break
			if not used_skill:
				_on_battle_attack_pressed()
	# 打字机效果
	if not _typewriter_done and _typewriter_index < _typewriter_text.length():
		_typewriter_timer += delta
		var speed := 0.03 if ThemeManager.animations_enabled else 0.001
		var sp: String = GameManager.user_data.text_speed_preset
		if sp == "slow":
			speed = 0.06
		elif sp == "fast":
			speed = 0.01
		while _typewriter_timer >= speed and _typewriter_index < _typewriter_text.length():
			_typewriter_timer -= speed
			_typewriter_index += 1
			main_text.visible_characters = _typewriter_index
		if _typewriter_index >= _typewriter_text.length():
			_typewriter_done = true
			main_text.text = _typewriter_text
			main_text.visible_characters = -1
			# 打字完成：选择按钮浮现
			choice_container.visible = true
			# 无选择按钮时显示"继续"提示闪烁（有事件后由事件流程添加按钮）
			if choice_container.get_child_count() == 0:
				_show_continue_blink(true)
		else:
			# 打字中光标闪烁（交替显示 ▌）
			var cursor := "▌" if int(_typewriter_index / 3) % 2 == 0 else ""
			main_text.text = _typewriter_text.substr(0, _typewriter_index) + cursor
			main_text.visible_characters = -1

func _unhandled_input(event: InputEvent) -> void:
	# 点击或空格/回车跳过打字机
	var skip := false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		skip = true
	elif event is InputEventKey and event.pressed and not event.echo \
			and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER):
		skip = true
	if skip and not _typewriter_done:
		_skip_typewriter()
		get_viewport().set_input_as_handled()
	# Esc: 切换菜单（菜单已开则关闭）
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		# Esc 优先级：酒馆 > 槽位选择器 > 菜单
		if get_node_or_null("SlotSelector") != null:
			get_node_or_null("SlotSelector").queue_free()
			get_viewport().set_input_as_handled()
			return
		if tavern_panel.visible:
			tavern_panel.visible = false
		elif battle_panel.visible:
			menu_panel.visible = not menu_panel.visible
		else:
			menu_panel.visible = not menu_panel.visible
		get_viewport().set_input_as_handled()
	# H: 打开操作帮助
	elif event is InputEventKey and event.pressed and event.keycode == KEY_H:
		_on_menu_help_pressed()
		get_viewport().set_input_as_handled()
	# T: 打开酒馆
	elif event is InputEventKey and event.pressed and event.keycode == KEY_T:
		if not tavern_panel.visible:
			_on_tavern_pressed()
		else:
			_on_tavern_close_pressed()
		get_viewport().set_input_as_handled()
	# 酒馆中：左/右方向键切换角色
	elif event is InputEventKey and event.pressed and not event.echo and tavern_panel.visible \
			and (event.keycode == KEY_LEFT or event.keycode == KEY_RIGHT):
		var cur: int = tavern_char_select.selected
		var next_idx: int = (cur + 1) % TAVERN_CHARS.size() if event.keycode == KEY_RIGHT else (cur - 1 + TAVERN_CHARS.size()) % TAVERN_CHARS.size()
		tavern_char_select.select(next_idx)
		_enter_tavern_char(next_idx)
		get_viewport().set_input_as_handled()
	# 战斗时：数字键 1-9 释放对应技能
	elif event is InputEventKey and event.pressed and not event.echo and battle_panel.visible \
			and event.keycode == KEY_TAB:
		# Tab 切换攻击目标（模拟点击敌人栏）
		if combat_engine != null and combat_engine.enemies.size() > 1:
			var fake := InputEventMouseButton.new()
			fake.button_index = MOUSE_BUTTON_LEFT
			fake.pressed = true
			_on_enemy_info_clicked(fake)
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and battle_panel.visible \
			and event.keycode >= KEY_1 and event.keycode <= KEY_9:
		var skill_idx: int = event.keycode - KEY_1
		if combat_engine != null and combat_engine.ability_data != null:
			var skills: Array = combat_engine.ability_data.skills
			if skill_idx < skills.size():
				var sid: String = str(skills[skill_idx].get("id", ""))
				if not sid.is_empty():
					combat_engine.player_use_skill(sid, 0)
					_refresh_battle_ui()
					get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and not battle_panel.visible \
			and event.keycode >= KEY_1 and event.keycode <= KEY_9:
		# 非战斗：数字键快速选择剧情选项（1-9）
		var choice_idx: int = event.keycode - KEY_1
		if choice_idx < choice_container.get_child_count():
			var cb: Control = choice_container.get_child(choice_idx)
			if cb is Button:
				(cb as Button).pressed.emit()
				get_viewport().set_input_as_handled()

func _skip_typewriter() -> void:
	_typewriter_index = _typewriter_text.length()
	_typewriter_done = true
	main_text.text = _typewriter_text
	main_text.visible_characters = -1
	choice_container.visible = true

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
	# 记录一次体验（体验数+1、最近体验前置）
	GameManager.record_play(sid)
	GameManager.unlock_achievement("first_play", "首次游玩剧本")
	# 首次体验：弹出操作提示
	var gm: Node = Engine.get_main_loop().root.get_node_or_null("GameManager")
	if gm != null and gm.user_data != null and not gm.user_data.played_script_ids.is_empty():
		if gm.user_data.played_script_ids.size() <= 1 and not _help_shown:
			_help_shown = true
			_on_menu_help_pressed()

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

	# 连接战斗信号（战斗 UI 由 combat_engine 事件驱动）
	combat_engine.combat_started.connect(_on_combat_started)
	combat_engine.combat_round_started.connect(_on_combat_round_started)
	combat_engine.action_taken.connect(_on_combat_action_taken)
	combat_engine.combat_ended.connect(_on_combat_ended)

	# 蓝图执行器: 注入全部引擎, 事件带蓝图图时由蓝图驱动运行时
	blueprint_executor = load("res://scripts/player/blueprint_executor.gd").new()
	blueprint_executor.init_engines(
		event_engine, economy_engine, combat_engine, world_state,
		SaveManager.current_save.player_state if SaveManager.current_save else {},
		script_data
	)
	# 蓝图日志 → 玩家可见（dialog 显示主文本，info/error 进历史）
	blueprint_executor.log_message.connect(_on_blueprint_log)

## 开始体验
func _start_experience() -> void:
	if script_data == null:
		main_text.text = "无法加载剧本数据"
		return
	_play_start_time = Time.get_ticks_msec()
	script_title.text = script_data.name
	# 有存档 → 从存档继续；否则新开
	if SaveManager.has_save(script_data.id):
		_continue_from_save()
		return
	_start_new_experience()

## 新开一局（无存档时的初始流程）
func _start_new_experience() -> void:
	_update_ui()
	var bg_text := ""
	if script_data.worldview and not script_data.worldview.background_story.is_empty():
		bg_text = script_data.worldview.background_story
	else:
		bg_text = script_data.description
	_set_main_text("[b]【%s】[/b]\n\n%s" % [script_data.name, bg_text])
	_add_history("进入世界: %s" % script_data.name)
	_advance_to_next_event()

## 从存档继续（优先手动存档槽 0，回退自动存档）
func _continue_from_save() -> void:
	var sd: SaveData = SaveManager.load_game(0, false)
	if sd == null:
		sd = SaveManager.load_game(0, true)
	if sd == null:
		_start_new_experience()
		return
	SaveManager.current_save = sd
	if event_engine:
		event_engine.load_history(sd.event_history)
	if world_state:
		world_state.load_from_dict(sd.world_state)
	if economy_engine:
		economy_engine.load_from_dict(sd.economy_state)
	# 恢复战斗状态（player_state 中的 HP/MP/等级）
	if combat_engine and sd.player_state:
		combat_engine.set_player_stats(sd.player_state)
	_update_ui()
	var day: int = (sd.world_state.get("game_time", {}) as Dictionary).get("day", 1)
	_set_main_text("[b]【%s】[/b]\n\n已从存档继续…（第 %d 天）" % [script_data.name, day])
	_add_history("继续世界: %s（第 %d 天）" % [script_data.name, day])
	_advance_to_next_event()

## 继续提示闪烁（无选择按钮时显示 ▸ 继续，有限闪烁后自动清除）
func _show_continue_blink(show: bool) -> void:
	var hint := get_node_or_null("MainVBox/HintLabel")
	if hint is Label:
		if show:
			(hint as Label).text = "▸ 点击继续"
			var btw := create_tween()
			btw.set_loops(3)
			btw.tween_property(hint, "modulate:a", 0.3, 0.35)
			btw.tween_property(hint, "modulate:a", 1.0, 0.35)
			btw.finished.connect(func():
				if (hint as Label).text == "▸ 点击继续":
					(hint as Label).text = "")
		else:
			(hint as Label).text = ""

## 推进中标志（防连点/防事件嵌套）
var _advancing: bool = false
## 推进到下一个事件
func _advance_to_next_event() -> void:
	if _advancing:
		return
	_advancing = true
	if event_engine == null:
		_advancing = false
		return
	if world_state:
		world_state.advance_time(1)
		var expired: Array = world_state.tick_effects()
		if not expired.is_empty():
			ToastManager.info("⏳ 世界效果已结束：%s" % "、".join(PackedStringArray(expired)))
	_update_ui()

	var triggerable: Array = event_engine.check_triggerable_events()
	if triggerable.is_empty():
		var random_event: Dictionary = event_engine.check_random_events()
		if not random_event.is_empty():
			_run_event(random_event)
		else:
			var time_info := ""
			if world_state:
				time_info = "（%s）" % world_state.get_time_display()
			_set_main_text("你在这个世界中继续探索...%s\n暂时没有发现特别的事件。\n\n[i][点击继续探索][/i]" % time_info)
			_clear_choices()
			_add_choice_button("继续探索", "_on_continue_exploring")
	else:
		_run_event(triggerable[0])
	_advancing = false

## 统一事件入口: 事件带蓝图图则蓝图驱动, 否则回退传统 event_engine 流程
func _run_event(event: Dictionary) -> void:
	if blueprint_executor == null:
		event_engine.trigger_event(event)
		return
	var graph := _get_event_blueprint_graph(event)
	if not graph.is_empty():
		_run_blueprint_event(event, graph)
	else:
		# 事件类型提示（chain/random/player_action）
		var ttype: String = str(event.get("trigger_type", ""))
		match ttype:
			"chain":
				pass  # 主线推进无需强调
			"random":
				ToastManager.info("🎲 随机遭遇")
			"player_action":
				ToastManager.info("🔍 探索发现")
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
	# 蓝图事件标记（随机/主线）
	var bchain_mark := "📌 " if not str(event.get("chain_id", "")).is_empty() else ("🎲 " if str(event.get("trigger_type", "")) == "random" else "")
	_set_main_text("[b]%s【%s】[/b]\n\n%s" % [bchain_mark, event_name, desc])
	_add_history("事件(蓝图)%s: %s" % [bchain_mark, event_name])
	_blueprint_active_graph = graph
	_blueprint_choices = []
	_clear_choices()
	var result: Dictionary = blueprint_executor.execute_graph(graph)
	_sync_save_state()
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
	# 事件切换淡入（视觉过渡，不启用动画时跳过）
	if ThemeManager.animations_enabled and not _typewriter_done:
		main_text.modulate.a = 0.0
		var ftw := create_tween()
		ftw.tween_property(main_text, "modulate:a", 1.0, 0.18)
		# 轻微缩放脉冲（事件到达反馈）
		main_text.pivot_offset = main_text.size / 2.0
		var ptw := create_tween()
		ptw.tween_property(main_text, "scale", Vector2(1.02, 1.02), 0.12)
		ptw.tween_property(main_text, "scale", Vector2.ONE, 0.2)
	_typewriter_text = text
	_typewriter_index = 0
	_typewriter_timer = 0.0
	_typewriter_done = false
	main_text.text = text
	main_text.visible_characters = 0
	# 打字期间隐藏选择按钮（打字完成后浮现）
	choice_container.visible = false
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
	# 键盘可达（Tab/方向键导航）
	btn.focus_mode = Control.FOCUS_ALL
	# 选项多时紧凑（>4 个用 36px 防溢出）
	if choice_container.get_child_count() >= 4:
		btn.custom_minimum_size = Vector2(0, 36)
	# hover 反馈: 文字加深金色 + 轻微上浮（主题已有 hover 背景, 这里强化反馈）
	btn.mouse_entered.connect(func():
		btn.add_theme_color_override("font_color", ThemeManager.C_ACCENT_DARK)
		if ThemeManager.animations_enabled:
			var tw := create_tween()
			tw.tween_property(btn, "scale", Vector2(1.02, 1.02), 0.12)
	)
	btn.mouse_exited.connect(func():
		btn.remove_theme_override("font_color")
		if ThemeManager.animations_enabled:
			var tw := create_tween()
			tw.tween_property(btn, "scale", Vector2.ONE, 0.12)
	)
	if not method.is_empty():
		btn.pressed.connect(func():
			# 按压反馈（快速闪暗后执行选择）
			if ThemeManager.animations_enabled:
				btn.modulate = Color(0.6, 0.6, 0.6)
				btn.scale = Vector2(0.98, 0.98)
			Callable(self, method).call())
	choice_container.add_child(btn)
	# 键盘序号提示（数字键 1-9 快速选择）
	var idx: int = choice_container.get_child_count()
	if idx <= 9:
		btn.tooltip_text = "快捷键 %d" % idx
		btn.text = "%d. %s" % [idx, btn.text]
	# 进入动画（容器内 position 会被布局覆盖, 改用 scale + alpha，逐个延迟浮现）
	if ThemeManager.animations_enabled:
		btn.modulate.a = 0.0
		btn.scale = Vector2(0.96, 0.96)
		var delay := 0.0
		var ch_count: int = choice_container.get_child_count()
		if ch_count > 1:
			delay = (ch_count - 1) * 0.06
		var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_interval(delay)
		tween.set_parallel(true)
		tween.tween_property(btn, "modulate:a", 1.0, 0.2)
		tween.tween_property(btn, "scale", Vector2.ONE, 0.2)

## 添加历史记录
func _add_history(text: String) -> void:
	var ts := ""
	if world_state:
		ts = "[color=#8a7a68][%s][/color] " % world_state.get_time_display()
	history_text.text += "%s[color=#6b5e52]%s[/color]\n" % [ts, text]
	# 折叠时提示有新记录（HistoryToggle 金色，展开后清除）
	if not history_panel.visible:
		history_toggle.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	# 行数上限（防长局历史无限增长卡顿）
	if history_text.get_line_count() > 200:
		var excess2: int = history_text.get_line_count() - 150
		var keep2 := ""
		for i in range(excess2, history_text.get_line_count()):
			keep2 += history_text.get_line(i) + "\n"
		history_text.text = keep2

## 更新UI
func _update_ui() -> void:
	if SaveManager.current_save:
		var ps: Dictionary = SaveManager.current_save.player_state
		player_name_label.text = ps.get("name", "旅者")
		player_level_label.text = "Lv.%d" % ps.get("level", 1)
		# 等级旁经验条（每 100 经验升 1 级）
		var exp_cur: int = int(ps.get("exp", 0))
		var exp_filled := clampi(int(exp_cur / 10.0), 0, 10)
		var exp_bar := ""
		for ei in 10:
			exp_bar += "▰" if ei < exp_filled else "▱"
		player_level_label.text += "  %s %d/100" % [exp_bar, exp_cur]
		player_level_label.tooltip_text = "经验 %d/100（每 100 经验升 1 级）" % exp_cur
		# 经验将满（≥90）金色高亮提示即将升级
		if exp_cur >= 90:
			player_level_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		else:
			player_level_label.remove_theme_color_override("font_color")
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
		# 低血量警示色（<30% 变红）
		var hp_ratio := float(current_hp) / float(max_hp) if max_hp > 0 else 0.0
		if hp_ratio <= 0.3:
			hp_bar.add_theme_stylebox_override("fill", _hp_style(0.9, 0.25, 0.25))
		elif hp_ratio <= 0.6:
			hp_bar.add_theme_stylebox_override("fill", _hp_style(0.9, 0.65, 0.25))
		else:
			hp_bar.add_theme_stylebox_override("fill", _hp_style(0.35, 0.85, 0.4))
		hp_label.text = "HP: %d/%d" % [current_hp, max_hp]
		# 护盾显示（技能获得的护盾值）
		var shield_val: int = int(ps.get("shield", 0))
		if shield_val > 0:
			hp_label.text += "  🛡%d" % shield_val
		# 经济状态（金币/物品）
		if economy_engine != null:
			var gold := 0
			for cid in economy_engine.player_currencies:
				gold += int(economy_engine.player_currencies[cid])
			econ_label.text = "💰 %d" % gold
			item_label.text = "🎒 %d" % economy_engine.player_inventory.size()
		else:
			econ_label.text = "💰 0"
			item_label.text = "🎒 0"
		# 任务追踪（当前进行中的任务）
		if script_data != null and script_data.quest_system != null and script_data.quest_system.quests.size() > 0:
			var active_q := ""
			for q in script_data.quest_system.quests:
				var qstatus: String = str(q.get("status", ""))
				if qstatus.is_empty() or qstatus == "active":
					active_q = str(q.get("name", q.get("id", "")))
					break
			if not active_q.is_empty():
				quest_label.text = "📋 %s" % active_q
				quest_label.visible = true
				quest_label.tooltip_text = "当前任务：%s" % active_q
		# 当前事件链
		if world_state:
			var chain: String = str(world_state.get_variable("current_chain", ""))
			if not chain.is_empty():
				chain_label.text = "🔗 %s" % chain
				chain_label.visible = true
				chain_label.tooltip_text = "当前剧情线：%s" % chain
		# 剧情进度（基于事件完成度）
		var p := _get_progress()
		if p[1] > 0:
			var pct := int(float(p[0]) / float(p[1]) * 100.0)
			# 字符进度条（10 格）
			var filled := int(pct / 10.0)
			var bar := ""
			for i in 10:
				bar += "█" if i < filled else "░"
			progress_label.text = "📊 %s %d%%" % [bar, pct]
			progress_label.visible = true
			progress_label.tooltip_text = "已完成 %d/%d 个事件" % [p[0], p[1]]
			# 进度条颜色渐变（低=灰黄 中=金 高=绿）
			if pct >= 100:
				progress_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
			elif pct >= 50:
				progress_label.add_theme_color_override("font_color", Color(0.9, 0.75, 0.35))
			else:
				progress_label.add_theme_color_override("font_color", Color(0.75, 0.68, 0.5))
			# 通关提示（全部事件触发一次）
			if p[0] >= p[1] and not _ending_shown:
				_ending_shown = true
				ToastManager.success("🎉 剧情全部体验完毕！")
				GameManager.unlock_achievement("finish_any_script")
				# 通关徽章：进度条金色
				progress_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
				progress_label.text = "🏆 通关！%s" % progress_label.text
				_show_finish_stats()
		# MP 进度条（显示当前 MP，低 MP 变暗蓝）
		var max_mp: int = ps.get("max_mp", 50)
		var cur_mp: int = ps.get("mp", max_mp)
		mp_bar.max_value = max_mp
		mp_bar.value = cur_mp
		var mp_ratio: float = float(cur_mp) / float(max_mp) if max_mp > 0 else 1.0
		if mp_ratio < 0.3:
			mp_bar.add_theme_stylebox_override("fill", _hp_style(0.35, 0.5, 0.85))
		else:
			mp_bar.add_theme_stylebox_override("fill", _hp_style(0.4, 0.62, 0.95))
		# 金币
		var inv: Dictionary = ps.get("inventory", {})
		player_gold_label.text = "金币: %d" % inv.get("gold", 0)
	if world_state:
		var region_hud: String = str(world_state.get_variable("current_region", ""))
		var region_prefix := " 📍%s" % region_hud if not region_hud.is_empty() else ""
		time_label.text = "🗓 " + world_state.get_time_display() + region_prefix
		time_label.tooltip_text = "世界时间 · 当前区域"

## HP 条填充样式（按血量百分比配色）
func _hp_style(r: float, g: float, b: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(r, g, b, 0.9)
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_right = 4
	sb.corner_radius_bottom_left = 4
	return sb

## === 事件回调 ===
func _on_event_triggered(event: Dictionary) -> void:
	var desc: String = event.get("description", "发生了某件事...")
	var event_name: String = event.get("name", "未知事件")
	# 主线事件标记（有 chain_id 的显示 📌）
	var chain_mark := "📌 " if not str(event.get("chain_id", "")).is_empty() else ""
	_set_main_text("[b]%s【%s】[/b]\n\n%s" % [chain_mark, event_name, desc])
	_add_history("事件%s: %s" % [chain_mark, event_name])

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
	_sync_save_state()
	# 防连点：忙碌时忽略（避免连点跳过多个事件）
	if _advancing:
		return
	_advance_to_next_event()

func _on_continue_exploring() -> void:
	_sync_save_state()
	if _advancing:
		return
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

	_sync_save_state()

## 同步当前引擎状态到存档（蓝图路径/传统路径共用，防止进度丢失）
func _sync_save_state() -> void:
	if SaveManager.current_save == null:
		return
	_update_ui()
	SaveManager.current_save.event_history = event_engine.to_dict() if event_engine else {}
	SaveManager.current_save.world_state = world_state.to_dict() if world_state else {}
	SaveManager.current_save.economy_state = economy_engine.to_dict() if economy_engine else {}

## 蓝图日志处理：dialog 显示主文本（对话可见），info/error 进历史
func _on_blueprint_log(level: String, text: String) -> void:
	match level:
		"dialog":
			_set_main_text(text)
			_add_history(text)
		"error":
			_add_history("[错误] %s" % text)
		_:
			_add_history(text)

## === 战斗 UI ===

## === 酒馆（AI 对话） ===
const TAVERN_CHARS: Array = [
	{
		"id": "innkeeper",
		"name": "旅店老板娘·艾琳",
		"icon": "🏮",
		"personality": "热情健谈，消息灵通",
		"background": "开了三十年旅店，认识镇上每个人",
		"greeting": "欢迎光临！客官打尖还是住店？最近镇上可不太平…"
	},
	{
		"id": "old_scholar",
		"name": "老学者·费恩",
		"personality": "博学寡言，说话喜欢引经据典",
		"background": "研究古代遗迹的退休学者",
		"greeting": "年轻人，你来得正好。我正想找人讨论那本残缺的古籍。"
	}
]

func _on_tavern_pressed() -> void:
	tavern_panel.visible = true
	menu_panel.visible = false
	# 打开后清除新消息高亮
	var tb := get_node_or_null("MainVBox/TopBar/TopHBox/TavernBtn")
	if tb is Button:
		(tb as Button).remove_theme_color_override("font_color")
		(tb as Button).text = "🏮 酒馆"
	tavern_char_select.clear()
	for i in TAVERN_CHARS.size():
		tavern_char_select.add_item("%s %s" % [TAVERN_CHARS[i].get("icon", ""), TAVERN_CHARS[i]["name"]], i)
	tavern_char_select.item_selected.connect(_on_tavern_char_selected)
	_enter_tavern_char(0)
	tavern_input.grab_focus()
	var hist_count: int = TavernManager.dialog_history.size()
	ToastManager.info("🏮 与 %s 对话（←→切换角色）%s" % [
		TAVERN_CHARS[0].get("name", "角色"),
		"· 历史 %d 条" % hist_count if hist_count > 0 else ""])

## 导出酒馆对话历史为 txt
func _on_export_chat_pressed() -> void:
	if TavernManager.dialog_history.is_empty():
		ToastManager.warning("暂无对话可导出")
		return
	var lines: PackedStringArray = []
	for m in TavernManager.dialog_history:
		var role_txt: String = "玩家" if str(m.get("role", "")) == "user" else str(TavernManager.current_character.get("name", "角色"))
		lines.append("[%s] %s" % [role_txt, str(m.get("content", ""))])
	var path := "user://tavern_export_%s.txt" % Time.get_datetime_string_from_system().replace(":", "").replace(" ", "_")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string("\n".join(lines))
		f.close()
		ToastManager.success("已导出 %d 条对话 → %s" % [lines.size(), path])
	else:
		ToastManager.warning("导出失败")

## 清空当前角色对话历史
func _on_tavern_clear_pressed() -> void:
	var cur: int = tavern_char_select.selected
	var char: Dictionary = TAVERN_CHARS[cur]
	TavernManager.clear_history()
	tavern_msgs.clear()
	_tavern_append("assistant", char.get("greeting", "你好，旅者。"))
	ToastManager.info("已清空 %s 的对话历史" % char.get("name", "角色"))

## 导出当前角色对话记录
func _on_tavern_export_pressed() -> void:
	var cur: int = tavern_char_select.selected
	var char: Dictionary = TAVERN_CHARS[cur]
	var history: Array = TavernManager.load_history(char["id"])
	if history.is_empty():
		ToastManager.warning("暂无对话记录")
		return
	var fd := FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	fd.title = "导出对话记录"
	fd.add_filter("*.txt ; 文本文件")
	fd.current_path = "酒馆对话_%s.txt" % char.get("name", "角色")
	fd.min_size = Vector2i(600, 400)
	add_child(fd)
	fd.file_selected.connect(func(path: String):
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f:
			f.store_string("%s 的对话记录（%s 剧本）\n%s\n" % [char.get("name", "角色"), script_data.name if script_data else "", "=".repeat(24)])
			for msg in history:
				f.store_string("[%s] %s\n" % [msg.get("role", "?"), msg.get("content", "")])
			f.close()
			ToastManager.success("对话已导出")
		else:
			ToastManager.warning("导出失败")
		fd.queue_free())
	fd.popup_centered()

func _on_tavern_close_pressed() -> void:
	TavernManager.end_dialog()
	tavern_panel.visible = false
	# 焦点还原（键盘可继续操作）
	main_text.grab_focus()

func _on_tavern_char_selected(index: int) -> void:
	_enter_tavern_char(index)

func _enter_tavern_char(index: int) -> void:
	tavern_msgs.clear()
	var char: Dictionary = TAVERN_CHARS[index]
	TavernManager.start_dialog(char)
	# 输入框占位提示当前角色
	tavern_input.placeholder_text = "对%s说话…" % char.get("name", "角色")
	# 首次进入该角色：显示一句问候
	if TavernManager.dialog_history.is_empty():
		var greeting := "（%s%s抬头看向你）欢迎光临%s，旅行者。有什么想问的？" % [
			char.get("icon", "🗨"), char.get("name", "角色"), char.get("locale", "小店")]
		TavernManager.dialog_history.append({"role": "assistant", "content": greeting})
		TavernManager.save_history()
		_tavern_append("assistant", greeting)
	# 角色简介提示（性格/背景）
	ToastManager.info("📖 %s：%s（%s）" % [
		char.get("name", "角色"),
		char.get("personality", ""),
		char.get("background", "")])
	# 空输入禁用发送按钮
	var sb := get_node_or_null("TavernPanel/TavernVBox/TavernInputRow/TavernSend")
	if sb is Button:
		(sb as Button).disabled = true
		tavern_input.text_changed.connect(func(t: String):
			(sb as Button).disabled = t.strip_edges().is_empty())
	# 回车直接发送
	if not tavern_input.text_submitted.is_connected(_on_tavern_send_pressed):
		tavern_input.text_submitted.connect(_on_tavern_send_pressed)
	# 恢复历史对话
	var history: Array = TavernManager.load_history(char["id"])
	if not history.is_empty():
		for msg in history:
			_tavern_append(msg.get("role", ""), msg.get("content", ""))
	else:
		_tavern_append("assistant", char["greeting"])

func _on_tavern_send_pressed() -> void:
	var text := tavern_input.text.strip_edges()
	if text.is_empty():
		return
	tavern_input.text = ""
	_tavern_append("user", text)
	TavernManager.dialog_history.append({"role": "user", "content": text})
	# 角色"思考中…"提示（省略号循环动效），延迟模拟回复
	_tavern_append("assistant", "…")
	TavernManager.dialog_history.append({"role": "assistant", "content": ""})
	var dots := 0
	var think_timer := create_tween().set_loops()
	think_timer.tween_interval(0.25)
	think_timer.tween_callback(func():
		dots = (dots % 3) + 1
		if tavern_msgs.get_line_count() > 0:
			tavern_msgs.text = tavern_msgs.text.substr(0, tavern_msgs.text.rfind("…")) + "".repeat(dots))
	await get_tree().create_timer(0.6).timeout
	think_timer.kill()
	var reply := _tavern_mock_reply(text)
	TavernManager.dialog_history[TavernManager.dialog_history.size() - 1]["content"] = reply
	TavernManager.save_history()
	# 重建最后一条为实际回复
	var rt: RichTextLabel = tavern_msgs
	var all_text := rt.text
	var last_idx := all_text.rfind("\n\n")
	if last_idx >= 0:
		rt.text = all_text.substr(0, last_idx) + "\n\n"
	_tavern_append("assistant", reply)
	# 若酒馆面板未打开：顶栏按钮金色高亮提示新消息
	if not tavern_panel.visible:
		var tb := get_node_or_null("MainVBox/TopBar/TopHBox/TavernBtn")
		if tb is Button:
			(tb as Button).add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
			(tb as Button).text = "🏮 酒馆 ·"

func _tavern_append(role: String, content: String) -> void:
	var prefix := "[color=#c9a06a][b]%s[/b][/color] " % ("艾琳" if role == "assistant" and TavernManager.current_character.get("id", "") == "innkeeper" else "费恩" if role == "assistant" else "你")
	tavern_msgs.append_text(prefix + content.replace("[", "［").replace("]", "］") + "\n\n")

func _tavern_mock_reply(text: String) -> String:
	var char_name: String = TavernManager.current_character.get("name", "角色")
	var replies := [
		"（%s若有所思地点点头）嗯，你说得对，继续说下去。" % char_name,
		"（%s压低声音）这事说来话长…改天细聊。" % char_name,
		"（%s微微一笑）有意思。不过这个话题，现在还不是时候。" % char_name,
		"（%s认真打量你）你这话，倒是提醒了我一件事。" % char_name,
	]
	return replies[abs(text.hash()) % replies.size()]
func _on_combat_started(enemies: Array) -> void:
	battle_panel.visible = true
	# 新战斗清空上一场日志
	battle_log.clear()
	_refresh_battle_ui()
	_battle_log_line("战斗开始！遭遇 %d 个敌人" % enemies.size(), "#c9a06a")
	menu_panel.visible = false
	# 战斗标题显示回合（每次动作后刷新）
	var btitle := get_node_or_null("BattlePanel/BattleVBox/BattleTitle")
	if btitle is Label and combat_engine != null:
		(btitle as Label).text = "⚔ 战斗 · 第 %d 回合" % combat_engine.current_round
	# 战斗开始 Toast：敌人数量与目标提示
	if enemies.size() > 1:
		ToastManager.warning("⚔ 遭遇 %d 个敌人！Tab 切换目标" % enemies.size())
	else:
		ToastManager.warning("⚔ 遭遇敌人！")
	# 逃跑按钮 tooltip：当前成功率
	var flee_btn := get_node_or_null("BattlePanel/BattleVBox/BattleButtons/FleeBtn")
	if flee_btn is Button and combat_engine != null:
		(flee_btn as Button).tooltip_text = "成功率 %.0f%%（敏捷影响）" % (combat_engine.last_flee_chance * 100.0)
	# 战斗快捷键提示（替换底部常驻提示）
	var hint := get_node_or_null("MainVBox/HintLabel")
	if hint:
		hint.text = "技能：按 1-9 直接释放 · Tab 切换目标 · Esc 菜单 · H 帮助 · 自动可调速"

func _on_combat_round_started(round_num: int) -> void:
	_battle_log_line("[color=#c9a06a]第 %d 回合[/color]" % round_num)
	_refresh_battle_ui()

func _on_combat_action_taken(_actor: Dictionary, _action: Dictionary) -> void:
	# 每回合刷新标题
	var btitle := get_node_or_null("BattlePanel/BattleVBox/BattleTitle")
	if btitle is Label and combat_engine != null:
		(btitle as Label).text = "⚔ 战斗 · 第 %d 回合" % combat_engine.current_round
		(btitle as Label).tooltip_text = "回合数 = 玩家与敌人轮流行动的轮次"
	# 玩家受击飘字（敌人攻击时）+ HP 红闪反馈 + 日志蓝色
	if _action.get("type", "") == "enemy_attack" and int(_action.get("damage", 0)) > 0:
		_spawn_damage_popup(-int(_action.get("damage", 0)))
		_battle_log_line("%s 攻击你，造成 %d 伤害" % [_actor.get("name", "敌人"), int(_action.get("damage", 0))], "#7fa8d9")
		hp_label.add_theme_color_override("font_color", Color(0.95, 0.3, 0.3))
		var tween := create_tween()
		tween.tween_interval(0.25)
		tween.tween_callback(func():
			hp_label.remove_theme_color_override("font_color"))
	_refresh_battle_ui()

func _on_combat_ended(result: String) -> void:
	battle_panel.visible = false
	# 恢复常驻操作提示（战斗时被快捷键提示替换）
	var hint := get_node_or_null("MainVBox/HintLabel")
	if hint is Label and (hint as Label).text.begins_with("⚔"):
		(hint as Label).text = ""
	# 自动战斗重置
	if _auto_battle:
		_auto_battle = false
		var ab := get_node_or_null("BattlePanel/BattleVBox/BattleButtons/AutoBtn")
		if ab is Button:
			(ab as Button).remove_theme_override("font_color")
			(ab as Button).text = "⚡ 自动"
	_sync_save_state()
	# 战斗统计
	match result:
		"victory": _battle_wins += 1
		"defeat": _battle_defeats += 1
		_: _battle_flees += 1
	var msg := "战斗胜利！" if result == "victory" else ("战斗失败…" if result == "defeat" else "成功逃跑")
	# 结算统计：回合数
	if combat_engine != null:
		msg += "（共 %d 回合）" % combat_engine.current_round
	# 最高连击结算
	if _best_combo >= 2:
		msg += " · 最高连击 x%d" % _best_combo
	_best_combo = 0
	_combo_count = 0
	# 胜利奖励（经验/金币）——奖励应用并提示
	if result == "victory" and combat_engine != null:
		var rewards: Dictionary = combat_engine.get_rewards()
		var gold: int = int(rewards.get("gold", 0))
		var exp: int = int(rewards.get("experience", 0))
		if economy_engine != null and gold > 0:
			economy_engine.add_currency("gold", gold)
			msg = "战斗胜利！获得 %d 金币、%d 经验" % [gold, exp]
			# 胜利奖励金币飘字（金色 +）
			if gold > 0:
				_spawn_damage_popup(gold, false, true)  # 胜利金币金色
			if _best_combo >= 2:
				msg += " · 最高连击 x%d" % _best_combo
			ToastManager.success("战斗胜利！+%d 金币 +%d 经验" % [gold, exp])
			_sync_save_state()
		# 经验升级（每 100 经验升 1 级，属性成长）
		var stats: Dictionary = combat_engine.player_combat_stats
		if not stats.is_empty():
			stats["exp"] = int(stats.get("exp", 0)) + exp
			while int(stats.get("exp", 0)) >= 100:
				stats["exp"] = int(stats.get("exp", 0)) - 100
				stats["level"] = int(stats.get("level", 1)) + 1
				stats["max_hp"] = int(stats.get("max_hp", 100)) + 10
				stats["max_mp"] = int(stats.get("max_mp", 50)) + 5
				stats["atk"] = int(stats.get("atk", 15)) + 2
				stats["def"] = int(stats.get("def", 10)) + 1
				stats["hp"] = stats.get("max_hp", 100)
				stats["mp"] = stats.get("max_mp", 50)
				ToastManager.success("🎉 升级！Lv.%d（HP/MP 回满，攻+2 防+1）" % int(stats.get("level", 1)))
				# 升级 HUD 脉冲（等级标签放大回弹）
				if ThemeManager.animations_enabled:
					player_level_label.pivot_offset = player_level_label.size / 2.0
					var ltw := create_tween()
					ltw.tween_property(player_level_label, "scale", Vector2(1.15, 1.15), 0.12)
					ltw.tween_property(player_level_label, "scale", Vector2.ONE, 0.25)
				msg += " 🎉 升级 Lv.%d！" % int(stats.get("level", 1))
			_sync_save_state()
	# 战斗结算后立即刷新 HUD（经验/等级/金币即时可见）
	_update_ui()
	_add_history(msg)
	var result_color := "[color=#4caf50]" if result == "victory" else ("[color=#e05a4e]" if result == "defeat" else "[color=#c9a06a]")
	_set_main_text("%s战斗结束：%s[/color][/b]" % [result_color, msg])
	_clear_choices()
	if result == "defeat":
		# 失败：提供重试（读自动存档恢复状态）
		ToastManager.warning("你已阵亡… 进度已保存，可读档重试")
		# 阵亡红色屏幕闪烁（视觉反馈）
		if ThemeManager.animations_enabled:
			var veil := ColorRect.new()
			veil.color = Color(0.7, 0.1, 0.1, 0.0)
			veil.set_anchors_preset(Control.PRESET_FULL_RECT)
			veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
			veil.z_index = 90
			add_child(veil)
			var dtw := create_tween()
			dtw.tween_property(veil, "color:a", 0.35, 0.15)
			dtw.tween_property(veil, "color:a", 0.0, 0.6)
			dtw.tween_callback(veil.queue_free)
		_add_choice_button("🔄 重试（读档）", "_on_retry_from_save")
	elif result == "fled":
		ToastManager.success("💨 成功逃离战场！")
		_add_choice_button("继续", "_on_continue_pressed")
	else:
		# 战斗结束后提供"继续"推进剧情
		if result == "victory" and ThemeManager.animations_enabled:
			# 胜利金色屏幕闪烁（正反馈）
			var vveil := ColorRect.new()
			vveil.color = Color(1.0, 0.85, 0.3, 0.0)
			vveil.set_anchors_preset(Control.PRESET_FULL_RECT)
			vveil.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vveil.z_index = 90
			add_child(vveil)
			var vtw := create_tween()
			vtw.tween_property(vveil, "color:a", 0.12, 0.12)
			vtw.tween_property(vveil, "color:a", 0.0, 0.5)
			vtw.tween_callback(vveil.queue_free)
		_add_choice_button("继续", "_on_continue_pressed")

## 战斗失败重试：读自动存档恢复
func _on_retry_from_save() -> void:
	var sd: SaveData = SaveManager.load_game(0, true)
	if sd == null:
		ToastManager.warning("无自动存档，无法重试")
		return
	_restore_save_state(sd)
	ToastManager.success("已从自动存档恢复")
	# 复活飘字（绿色 +HP 显示恢复量）
	if combat_engine and not (combat_engine.player_combat_stats as Dictionary).is_empty():
		var st3: Dictionary = combat_engine.player_combat_stats
		_spawn_damage_popup(int(st3.get("max_hp", 100)))
	_add_history("重新振作，继续冒险…")
	_advance_to_next_event()

## 统一恢复存档状态（读档/重试共用）
func _restore_save_state(sd: SaveData) -> void:
	SaveManager.current_save = sd
	if event_engine:
		event_engine.load_history(sd.event_history)
	if world_state:
		world_state.load_from_dict(sd.world_state)
	if economy_engine:
		economy_engine.load_from_dict(sd.economy_state)
	if combat_engine and sd.player_state:
		combat_engine.set_player_stats(sd.player_state)
	_update_ui()
	_sync_save_state()

func _battle_log_line(line: String, color: String = "") -> void:
	if not color.is_empty():
		battle_log.append_text("[color=%s]%s[/color]\n" % [color, line])
	else:
		battle_log.append_text(line + "\n")
	# 滚动到底 + 新行淡入高亮
	battle_log.scroll_to_line(battle_log.get_line_count() - 1)
	# 行数上限（防长战斗日志无限增长卡顿）
	if battle_log.get_line_count() > 120:
		var excess: int = battle_log.get_line_count() - 80
		var keep := ""
		for i in range(excess, battle_log.get_line_count()):
			keep += battle_log.get_line(i) + "\n"
		battle_log.text = "[i][color=#888]（较早日志已截断）[/color][/i]\n" + keep
		battle_log.scroll_to_line(battle_log.get_line_count() - 1)

func _refresh_battle_ui() -> void:
	if combat_engine == null:
		return
	var parts: Array[String] = []
	var alive := 0
	var total_enemies := 0
	for e in combat_engine.enemies:
		total_enemies += 1
		if e.get("is_alive", true):
			alive += 1
			# 当前目标敌人加 🎯 高亮标记
			var mark := "🎯 " if (total_enemies > 1 and _battle_target == total_enemies - 1) else ""
			parts.append("%s%s HP:%d/%d" % [mark, e.get("name", "?"), int(e.get("hp", 0)), int(e.get("max_hp", 1))])
	var count_txt := ""
	if total_enemies > 1:
		count_txt = "（剩 %d/%d）" % [alive, total_enemies]
	enemy_info.text = "敌人%s：%s" % [count_txt, "；".join(parts) if parts.is_empty() == false else "（无）"]
	# 敌人栏 tooltip：各敌人详情（HP/MP/攻防/状态效果）
	var tip_lines: Array[String] = []
	for e2 in combat_engine.enemies:
		if e2.get("is_alive", true):
			var tline := "%s | HP %d/%d · MP %d/%d · 攻 %d 防 %d" % [
				e2.get("name", "?"), int(e2.get("hp", 0)), int(e2.get("max_hp", 1)),
				int(e2.get("mp", 0)), int(e2.get("max_mp", 0)),
				int(e2.get("atk", 0)), int(e2.get("def", 0))]
			var fx2: Array = e2.get("status_effects", [])
			if not fx2.is_empty():
				var fnames: PackedStringArray = []
				for f in fx2:
					fnames.append(str(f.get("name", "?")))
				tline += " · [效果] %s" % "、".join(fnames)
			tip_lines.append(tline)
	enemy_info.tooltip_text = "\n".join(tip_lines)
	# 目标提示（点击敌人栏循环切换目标）
	if total_enemies > 1:
		var target_name := "自动"
		if _battle_target >= 0 and _battle_target < combat_engine.enemies.size() \
				and combat_engine.enemies[_battle_target].get("is_alive", true):
			target_name = str(combat_engine.enemies[_battle_target].get("name", "?"))
		enemy_info.text += "\n[color=#c9a06a]🎯 目标：%s（点击切换）[/color]" % target_name
	if enemy_info.get_signal_connection_list("gui_input").is_empty():
		enemy_info.gui_input.connect(_on_enemy_info_clicked)
	enemy_info.add_theme_color_override("font_color", Color(0.9, 0.35, 0.35))
	# 玩家状态
	var ps: Dictionary = combat_engine.player_combat_stats
	# 状态效果提示（玩家/敌人 buff）
	var fx_lines: Array[String] = []
	var pfx: Array = ps.get("status_effects", []) if not ps.is_empty() else []
	for fx in pfx:
		fx_lines.append("%s(剩%d)" % [fx.get("name", "?"), int(fx.get("remaining_turns", 0))])
	for e in combat_engine.enemies:
		if e.get("is_alive", true):
			for fx in e.get("status_effects", []):
				fx_lines.append("%s:%s" % [e.get("name", "?"), fx.get("name", "?")])
	if not fx_lines.is_empty():
		enemy_info.text += "\n[效果] %s" % "，".join(fx_lines)
	if not ps.is_empty():
		enemy_info.text += "\n%s HP:%d/%d MP:%d/%d" % [
			ps.get("name", "旅者"), int(ps.get("hp", 0)), int(ps.get("max_hp", 1)),
			int(ps.get("mp", 0)), int(ps.get("max_mp", 1))]
	# 敌人清空且战斗未结束 → 结束
	if alive == 0 and combat_engine.enemies.size() > 0:
		combat_engine.call("_check_combat_end")

## 点击敌人栏：循环切换攻击目标
func _on_enemy_info_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if combat_engine == null:
			return
		# 循环选择下一个存活敌人
		var count: int = combat_engine.enemies.size()
		if count <= 1:
			_battle_target = -1
			return
		for i in range(count):
			_battle_target = (_battle_target + 1) % count
			if combat_engine.enemies[_battle_target].get("is_alive", true):
				break
		ToastManager.info("🎯 目标：%s" % str(combat_engine.enemies[_battle_target].get("name", "?")))
		_refresh_battle_ui()

func _on_battle_attack_pressed() -> void:
	if combat_engine == null:
		return
	var res: Dictionary = combat_engine.player_attack(_battle_target)  # 指定目标（-1 自动选存活）
	if not res.is_empty():
		_battle_log_line("%s 攻击造成 %d 伤害" % [combat_engine.player_combat_stats.get("name", "你"), res.get("damage", 0)], "#e0665a")
		_spawn_damage_popup(-int(res.get("damage", 0)), bool(res.get("critical", false)))
		# 敌人受击闪红（命中反馈）
		if int(res.get("damage", 0)) > 0:
			enemy_info.add_theme_color_override("font_color", Color(1.0, 0.4, 0.35))
			var etw := create_tween()
			etw.tween_interval(0.2)
			etw.tween_callback(func():
				enemy_info.remove_theme_color_override("font_color"))
		# 连击计数（造成伤害 +1，≥3 提示）
		if int(res.get("damage", 0)) > 0:
			_combo_count += 1
			_best_combo = maxi(_best_combo, _combo_count)
			if _combo_count >= 3 and _combo_count % 3 == 0:
				ToastManager.success("🔥 连击 x%d！" % _combo_count)
			# 暴击提示
			if res.get("critical", false):
				ToastManager.info("💥 暴击！")
		else:
			# 未命中：连击中断提示
			if _combo_count >= 3:
				ToastManager.info("连击中断…（x%d）" % _combo_count)
			_combo_count = 0
	_refresh_battle_ui()

## 伤害飘字（战斗手感：上浮淡出）
func _spawn_damage_popup(amount: int, critical: bool = false, is_gold: bool = false) -> void:
	var popup_pos := Vector2.ZERO
	if enemy_info != null and enemy_info.is_visible_in_tree():
		popup_pos = enemy_info.global_position + Vector2(randf_range(20, 120), -10)
	else:
		# fallback：屏幕中心（商店等非战斗场景）
		popup_pos = get_viewport().get_visible_rect().size / 2 + Vector2(randf_range(-80, 80), -40)
	var lbl := Label.new()
	var color := Color(0.95, 0.4, 0.35) if amount < 0 else (Color(1.0, 0.8, 0.3) if is_gold else Color(0.35, 0.9, 0.45))
	lbl.text = ("-%d" % absi(amount)) if amount < 0 else ("+%d" % amount)
	if is_gold:
		lbl.text = "🪙 +%d" % amount
	# 暴击：金色大字 + 更大上浮
	if critical:
		color = Color(1.0, 0.75, 0.25)
		lbl.text += "！"
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", 26 if critical else 22)
	lbl.position = popup_pos
	lbl.z_index = 100
	add_child(lbl)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - (64 if critical else 46), 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.8).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(lbl.queue_free)

func _on_battle_skill_pressed() -> void:
	if combat_engine == null or combat_engine.ability_data == null:
		return
	var skills: Array = combat_engine.ability_data.skills
	if skills.is_empty():
		_battle_log_line("没有可用的技能")
		return
	var menu := PopupMenu.new()
	menu.name = "BattleSkillMenu"
	for s in skills:
		var sid: String = s.get("id", "")
		# 显示 MP 消耗 + 数字键提示
		var mana_cost: int = int((s.get("cost", {}) as Dictionary).get("mana", 0))
		var label: String = "%d. %s" % [skills.find(s) + 1, s.get("name", sid)]
		if mana_cost > 0:
			label += "（MP %d）" % mana_cost
		menu.add_item(label, skills.find(s))
		# tooltip：技能描述
		var desc: String = str(s.get("description", ""))
		if not desc.is_empty():
			menu.set_item_tooltip(skills.find(s), desc)
		# MP 不足：置灰禁用
		var cur_mp: int = int(combat_engine.player_combat_stats.get("mp", 0))
		if mana_cost > cur_mp:
			menu.set_item_disabled(skills.find(s), true)
			menu.set_item_tooltip(skills.find(s), "魔力不足（需要 %d MP）" % mana_cost)
	menu.id_pressed.connect(func(id: int):
		var sres: Dictionary = combat_engine.player_use_skill(skills[id].get("id", ""), _battle_target)
		if not sres.is_empty():
			var dmg := int(sres.get("damage", 0))
			if dmg > 0:
				_battle_log_line("%s 释放 %s，造成 %d 伤害" % [combat_engine.player_combat_stats.get("name", "你"), skills[id].get("name", "技能"), dmg], "#e0665a")
				_spawn_damage_popup(-dmg, bool(sres.get("critical", false)))
				# 技能命中闪红
				enemy_info.add_theme_color_override("font_color", Color(1.0, 0.4, 0.35))
				var setw := create_tween()
				setw.tween_interval(0.2)
				setw.tween_callback(func():
					enemy_info.remove_theme_color_override("font_color"))
				# 技能伤害计入连击
				_combo_count += 1
				_best_combo = maxi(_best_combo, _combo_count)
				if _combo_count >= 3 and _combo_count % 3 == 0:
					ToastManager.success("🔥 连击 x%d！" % _combo_count)
				if sres.get("critical", false):
					ToastManager.info("💥 技能暴击！")
			var healed := int(sres.get("healed", 0))
			if healed > 0:
				_battle_log_line("%s 释放 %s，恢复 %d 点生命" % [combat_engine.player_combat_stats.get("name", "你"), skills[id].get("name", "技能"), healed], "#7cc47c")
				_spawn_damage_popup(healed)  # 治疗 +绿字飘字
			if sres.get("buffed", false):
				ToastManager.success("🛡 %s 获得增益！" % skills[id].get("name", "技能"))
			if sres.get("shield", 0) > 0:
				ToastManager.info("🛡 获得 %d 点护盾" % int(sres.get("shield", 0)))
		_refresh_battle_ui())
	add_child(menu)
	menu.popup(Rect2i(0, 0, 0, 0))
	menu.position = Vector2i(get_viewport().get_visible_rect().size / 2) - Vector2i(100, 50)

func _on_battle_flee_pressed() -> void:
	if combat_engine != null:
		var chance: float = combat_engine.last_flee_chance
		# 尝试逃跑
		combat_engine.try_flee()
		# 若仍在战斗（未逃跑成功）提示成功率
		if battle_panel.visible:
			ToastManager.warning("逃跑失败…成功率 %.0f%%（敏捷越高越易逃脱）" % (chance * 100.0))

## 自动战斗开关（连续点击循环 1x→2x→4x→关）
func _on_battle_auto_pressed() -> void:
	var auto_btn := get_node_or_null("BattlePanel/BattleVBox/BattleButtons/AutoBtn")
	if not _auto_battle:
		_auto_battle = true
		_auto_interval = 0.6
		_auto_timer = 0.0
		ToastManager.info("自动战斗开启（1x）")
	elif _auto_interval == 0.6:
		_auto_interval = 0.3
		ToastManager.info("自动战斗加速（2x）")
	elif _auto_interval == 0.3:
		_auto_interval = 0.15
		ToastManager.info("自动战斗加速（4x）")
	else:
		_auto_battle = false
		ToastManager.info("自动战斗关闭")
	# 状态色：开启金色，关闭还原
	if auto_btn is Button:
		if _auto_battle:
			(auto_btn as Button).add_theme_color_override("font_color", Color(0.95, 0.8, 0.3))
			(auto_btn as Button).text = "⚡ 自动 x%d" % int(0.6 / _auto_interval)
			(auto_btn as Button).tooltip_text = "自动战斗开启（x%d）：再次点击加速，长按 Esc 关闭" % int(0.6 / _auto_interval)
			# 自动开启脉冲（攻击按钮金色呼吸）
			if ThemeManager.animations_enabled:
				var atk_btn := get_node_or_null("BattlePanel/BattleVBox/BattleButtons/AttackBtn")
				if atk_btn is Button:
					var atw := create_tween()
					atw.tween_property(atk_btn, "modulate", Color(1.0, 0.9, 0.5), 0.3)
					atw.tween_property(atk_btn, "modulate", Color.WHITE, 0.3)
		else:
			(auto_btn as Button).remove_theme_override("font_color")
			(auto_btn as Button).text = "⚡ 自动"
	# 自动战斗时禁用手动操作按钮（防冲突）
	for bn in ["FleeBtn", "SkillBtn"]:
		var bb := get_node_or_null("BattlePanel/BattleVBox/BattleButtons/%s" % bn)
		if bb is Button:
			(bb as Button).disabled = _auto_battle
			if _auto_battle:
				(bb as Button).tooltip_text = "自动战斗进行中，先关闭自动"
			elif bn == "SkillBtn":
				(bb as Button).tooltip_text = "释放技能（消耗 MP，快捷键 1-9）"
			else:
				(bb as Button).tooltip_text = "尝试逃跑（成功率受敏捷影响）"

## 清空剧情历史
func _on_history_clear_pressed() -> void:
	history_text.clear()
	ToastManager.info("剧情历史已清空")

## === 历史记录折叠 ===
func _on_history_toggle_pressed() -> void:
	history_panel.visible = not history_panel.visible
	history_toggle.text = "▲ 收起记录" if history_panel.visible else "▼ 展开记录"
	# 展开时滚动到底（看最新记录）
	if history_panel.visible and history_text.get_line_count() > 0:
		history_text.scroll_to_line(history_text.get_line_count() - 1)
	# 展开后清除新记录高亮
	history_toggle.remove_theme_color_override("font_color")

## === 菜单 ===
func _on_menu_pressed() -> void:
	_refresh_difficulty_option()
	_refresh_menu_title()
	# 刷新动态 tooltip（槽位概要随存档变化）
	_setup_menu_tooltips()
	menu_panel.visible = true
	# 焦点到保存按钮（键盘可操作）
	var fb := get_node_or_null("MenuPanel/MenuVBox/SaveBtn")
	if fb is Button:
		(fb as Button).grab_focus()

func _on_menu_save_pressed() -> void:
	_show_slot_selector("save")

func _on_menu_load_pressed() -> void:
	_show_slot_selector("load")

func _on_menu_delete_pressed() -> void:
	_show_slot_selector("delete")

## 角色状态面板
func _on_menu_char_pressed() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "角色状态"
	dialog.min_size = Vector2i(420, 460)
	add_child(dialog)
	# 内容可滚动（区块多时防溢出）
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialog.add_child(scroll)
	var list := RichTextLabel.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scroll.add_child(list)
	var ps: Dictionary = {}
	if SaveManager.current_save:
		ps = SaveManager.current_save.player_state
	elif combat_engine != null:
		ps = combat_engine.player_combat_stats
	if ps.is_empty():
		list.append_text("[color=#999]角色数据未初始化[/color]")
	else:
		var rows := [
			["名称", str(ps.get("name", "旅者"))],
			["等级", "Lv.%d" % int(ps.get("level", 1))],
			["生命", "%d/%d" % [int(ps.get("hp", 0)), int(ps.get("max_hp", 1))]],
			["魔力", "%d/%d" % [int(ps.get("mp", 0)), int(ps.get("max_mp", 1))]],
			["攻击", str(ps.get("atk", 0))],
			["防御", str(ps.get("def", 0))],
			["魔攻", str(ps.get("matk", 0))],
			["魔防", str(ps.get("mdef", 0))],
			["速度", str(ps.get("speed", 0))],
			["敏捷", str(ps.get("agility", 0))],
		]
		for row in rows:
			list.append_text("[color=#c9a06a]%s[/color]  %s\n" % [row[0], row[1]])
		# 货币
		if economy_engine:
			list.append_text("\n[color=#c9a06a]货币[/color]\n")
			for cid in economy_engine.player_currencies:
				list.append_text("• %s × %d\n" % [cid, int(economy_engine.player_currencies[cid])])
		# 势力关系
		if world_state and not world_state.faction_states.is_empty():
			list.append_text("\n[color=#c9a06a]势力关系[/color]\n")
			for fid in world_state.faction_states:
				list.append_text("• %s：%d\n" % [fid, int(world_state.faction_states[fid])])
	dialog.popup_centered()

## 商店弹窗（购买物品）
func _on_menu_shop_pressed() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "商店"
	dialog.min_size = Vector2i(440, 460)
	add_child(dialog)
	var box := VBoxContainer.new()
	dialog.add_child(box)
	# 商品区可滚动（物品多时防溢出）
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inner)
	var list := RichTextLabel.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(list)
	var gold := 0
	if economy_engine:
		gold = int(economy_engine.player_currencies.get("gold", 0))
	list.append_text("[color=#c9a06a]持有金币: %d[/color]\n\n" % gold)
	# 购买按钮 tooltip 提示
	var bought_any := false
	# === 出售区（背包物品半价卖出） ===
	var sell_title := Label.new()
	sell_title.text = "【出售】"
	sell_title.add_theme_color_override("font_color", Color(0.55, 0.65, 0.85))
	inner.add_child(sell_title)
	var sold_any := false
	if economy_engine and not economy_engine.player_inventory.is_empty():
		for item_id in economy_engine.player_inventory:
			var qty: int = int(economy_engine.player_inventory[item_id])
			if qty <= 0:
				continue
			var price := 0.0
			for m in economy_engine.economy_data.markets if economy_engine.economy_data else []:
				var mid: String = m.get("id", "")
				var p: float = economy_engine.get_price(mid, item_id)
				if p > 0.0:
					price = p * 0.5
					break
			var sell_btn := Button.new()
			sell_btn.text = "出售 %s ×%d（+%d 金币）" % [item_id, qty, int(price)]
			sell_btn.pressed.connect(func():
				# 出售确认（防误卖）
				var confirm := ConfirmationDialog.new()
				confirm.dialog_text = "出售 %s ×%d，获得 %d 金币？" % [item_id, qty, int(price)]
				confirm.confirmed.connect(func():
					if economy_engine.sell("market_1", item_id):
						ToastManager.success("已出售 %s +%d 金币（剩余 %d 金币）" % [item_id, int(price), int(economy_engine.player_currencies.get("gold", 0))])
						_spawn_damage_popup(int(price), false, true)  # 出售 +金币飘字
						_sync_save_state()
						_on_menu_shop_pressed()
						dialog.queue_free())
				add_child(confirm)
				confirm.popup_centered())
			inner.add_child(sell_btn)
			sold_any = true
	if not sold_any:
		var no_sell := Label.new()
		no_sell.text = "（背包为空，无可出售物品）"
		no_sell.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		no_sell.add_theme_font_size_override("font_size", 11)
		inner.add_child(no_sell)
	if economy_engine and economy_engine.economy_data:
		for m in economy_engine.economy_data.markets:
			var mid: String = m.get("id", "")
			list.append_text("[b]%s[/b]\n" % m.get("name", mid))
			# 商品按价格升序显示（性价比在前）
			var goods: Array = m.get("goods", [])
			goods.sort_custom(func(a, b):
				return economy_engine.get_price(mid, str(a.get("item", ""))) < economy_engine.get_price(mid, str(b.get("item", ""))))
			for g in goods:
				var item_id: String = g.get("item", "")
				var price: float = economy_engine.get_price(mid, item_id)
				var btn := Button.new()
				btn.text = "购买 %s（%d 金币）" % [item_id, int(price)]
				# 金币不足：置灰禁用
				var gold_now: int = int(economy_engine.player_currencies.get("gold", 0))
				if gold_now < int(price):
					btn.disabled = true
					btn.tooltip_text = "金币不足（需要 %d）" % int(price)
				btn.pressed.connect(func():
					if economy_engine.buy(mid, item_id):
						ToastManager.success("已购买 %s（剩余 %d 金币）" % [item_id, int(economy_engine.player_currencies.get("gold", 0))])
						_spawn_damage_popup(int(price), false, true)  # 购买 +金币飘字
						_sync_save_state()
						_on_menu_shop_pressed()  # 刷新商店
						dialog.queue_free()
					else:
						ToastManager.warning("金币不足！"))
				inner.add_child(btn)
				bought_any = true
	if not bought_any:
		list.append_text("[color=#999]当前市场暂无商品…[/color]")
	dialog.popup_centered()

## 清空当前角色对话历史
## 背包查看弹窗
func _on_menu_bag_pressed() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "背包"
	dialog.min_size = Vector2i(360, 320)
	add_child(dialog)
	var box := VBoxContainer.new()
	dialog.add_child(box)
	var title := Label.new()
	title.text = "持有物品"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var list := RichTextLabel.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scroll.add_child(list)
	if economy_engine == null or economy_engine.player_inventory.is_empty():
		list.append_text("[color=#999]背包空空如也…[/color]")
	else:
		var total_items := 0
		var total_value := 0
		for item_id in economy_engine.player_inventory:
			var qty: int = int(economy_engine.player_inventory[item_id])
			if qty > 0:
				list.append_text("• %s × %d\n" % [item_id, qty])
				total_items += qty
				# 用市场价估值（找不到则跳过）
				if economy_engine.economy_data:
					for m in economy_engine.economy_data.markets:
						var price: float = economy_engine.get_price(str(m.get("id", "")), item_id)
						if price > 0:
							total_value += int(price) * qty
							break
		list.append_text("\n[color=#8a7a68]合计 %d 件 · 预估价值 %d 金币[/color]" % [total_items, total_value])
	dialog.popup_centered()

## 评分：1-5 星（平均后写入剧本）
func _on_menu_rating_pressed() -> void:
	var old := get_node_or_null("RatingDialog")
	if old:
		old.queue_free()
	var dialog := ConfirmationDialog.new()
	dialog.name = "RatingDialog"
	dialog.title = "评分"
	dialog.dialog_text = "为《%s》评分（当前 %.1f ★，%d 人）" % [script_data.name if script_data else "", script_data.rating if script_data else 0.0, script_data.rating_count if script_data else 0]
	dialog.get_ok_button().text = "提交评分"
	add_child(dialog)
	# 星级选择（HBox 5 个 ★ 按钮）
	var stars := HBoxContainer.new()
	stars.add_theme_constant_override("separation", 6)
	var chosen := [0]
	for i in 5:
		var b := Button.new()
		b.text = "★"
		b.modulate = Color(0.8, 0.65, 0.2)
		b.toggle_mode = true
		b.button_group = ButtonGroup.new()
		b.pressed.connect(func():
			chosen[0] = i + 1
			# 选中星标亮度反馈（≤当前全亮，> 当前变暗）
			for si in 5:
				var sb: Button = stars.get_child(si)
				sb.modulate = Color(1.0, 0.85, 0.3) if si < chosen[0] else Color(0.5, 0.4, 0.15))
		stars.add_child(b)
	dialog.add_child(stars)
	dialog.confirmed.connect(func():
		if chosen[0] <= 0:
			return
		var ws: Variant = script_data
		if ws == null:
			return
		var new_rating: float = (ws.rating * ws.rating_count + chosen[0]) / float(ws.rating_count + 1)
		ws.rating = snappedf(new_rating, 0.1)
		ws.rating_count += 1
		ScriptDataManager.update_script(ws, ["rating", "rating_count"])
		ToastManager.success("评分已提交 ★%d" % chosen[0]))
	dialog.popup_centered()
	stars.position = Vector2(120, 70)

func _on_menu_back_pressed() -> void:
	# 返回确认（防误点丢失当前阅读位置）
	var confirm := ConfirmationDialog.new()
	var pnow := _get_progress()
	var prog_txt := ""
	if pnow[1] > 0:
		prog_txt = "（当前进度 %d%%）" % int(float(pnow[0]) / float(pnow[1]) * 100.0)
	confirm.dialog_text = "返回大厅？将自动保存当前进度%s。" % prog_txt
	confirm.confirmed.connect(func():
		_sync_save_state()
		_write_progress()
		SaveManager.autosave()
		menu_panel.visible = false
		ToastManager.success("已自动保存")
		SceneManager.go_back_to_hub())
	add_child(confirm)
	confirm.popup_centered()

## 按事件完成度回写剧本进度（大厅卡片进度条可见）
func _write_progress() -> void:
	var p := _get_progress()
	if p[1] <= 0:
		return
	script_data.progress = clampf(float(p[0]) / float(p[1]), 0.0, 1.0)
	ScriptDataManager.update_script(script_data, ["progress"])

## 计算剧情进度 [done, total]
func _get_progress() -> Array:
	if script_data == null or script_data.event_system == null:
		return [0, 0]
	var total := script_data.event_system.story_events.size()
	if total <= 0:
		return [0, 0]
	var done := 0
	for e in script_data.event_system.story_events:
		if event_engine != null and event_engine.triggered_ids.has(e.get("id", "")):
			done += 1
	return [done, total]

## 关闭菜单（仅隐藏面板，不退出游戏）
## 初始化/刷新难度选项（菜单打开时同步设置页选择）
## 菜单打开时刷新标题（天数/进度）
func _refresh_menu_title() -> void:
	var title_node := menu_panel.find_child("MenuTitle", true, false)
	if title_node == null:
		return
	var p := _get_progress()
	var day := 1
	if world_state:
		day = world_state.get_current_day()
	# 已体验时长
	var mins := 0
	if _play_start_time > 0:
		mins = int((Time.get_ticks_msec() - _play_start_time) / 60000)
	var progress_txt := ""
	if p[1] > 0:
		progress_txt = " · %d%%" % int(float(p[0]) / float(p[1]) * 100.0)
	var time_txt := ""
	if mins > 0:
		time_txt = " · ⏱ %d 分" % mins
	var ach_txt := ""
	var gm: Node = Engine.get_main_loop().root.get_node_or_null("GameManager")
	if gm != null and gm.user_data != null:
		ach_txt = " · 🏆 %d/%d" % [gm.user_data.achievements.size(), gm.ACHIEVEMENTS.size()]
	var save_txt := ""
	var ast := get_node_or_null("AutoSaveTimer")
	if ast is Timer and (ast as Timer).is_stopped() == false:
		var remain: int = int((ast as Timer).time_left / 60.0)
		save_txt = " · 💾 %d分" % remain if remain >= 1 else ""
	var region_menu := ""
	if world_state:
		var rm2: String = str(world_state.get_variable("current_region", ""))
		if not rm2.is_empty():
			region_menu = " · 📍%s" % rm2
	title_node.text = "游戏菜单 · 第 %d 天%s%s%s" % [day, region_menu, progress_txt, time_txt]
	# 副状态行（成就/存档/玩家）
	var status_txt := ""
	var gm2: Node = Engine.get_main_loop().root.get_node_or_null("GameManager")
	if gm2 != null and gm2.user_data != null:
		status_txt += "🏆 %d/%d" % [gm2.user_data.achievements.size(), gm2.ACHIEVEMENTS.size()]
	status_txt += save_txt
	if combat_engine and not combat_engine.player_combat_stats.is_empty():
		var pst: Dictionary = combat_engine.player_combat_stats
		status_txt += " · Lv.%d ❤️%d/%d ⚡%d/%d" % [
			int(pst.get("level", 1)), int(pst.get("hp", 0)), int(pst.get("max_hp", 1)),
			int(pst.get("mp", 0)), int(pst.get("max_mp", 1))]
	if economy_engine:
		status_txt += " · 🪙 %d" % int(economy_engine.player_currencies.get("gold", 0))
	var status_lbl := menu_panel.find_child("MenuStatus", true, false)
	if status_lbl is Label:
		(status_lbl as Label).text = status_txt.strip_edges()

func _refresh_difficulty_option() -> void:
	if difficulty_option == null:
		return
	difficulty_option.clear()
	difficulty_option.add_item("自适应", 0)
	difficulty_option.add_item("简单", 1)
	difficulty_option.add_item("普通", 2)
	difficulty_option.add_item("困难", 3)
	var mode := "adaptive"
	var gm: Node = Engine.get_main_loop().root.get_node_or_null("GameManager")
	if gm != null and gm.user_data != null:
		mode = gm.user_data.difficulty_mode
	difficulty_option.selected = ["adaptive", "easy", "normal", "hard"].find(mode)
	if difficulty_option.get_signal_connection_list("item_selected").is_empty():
		difficulty_option.item_selected.connect(func(idx: int):
			var modes := ["adaptive", "easy", "normal", "hard"]
			var gm2: Node = Engine.get_main_loop().root.get_node_or_null("GameManager")
			if gm2 != null and gm2.user_data != null:
				gm2.user_data.difficulty_mode = modes[idx]
				gm2.save_user_data()
				ToastManager.info("难度已切换: %s" % modes[idx]))

func _on_menu_close_pressed() -> void:
	menu_panel.visible = false
	# 还原焦点到主界面（键盘 Esc 可继续操作）
	main_text.grab_focus()

## 世界日志（因果标记/选择历史）
func _on_menu_log_pressed() -> void:
	var dialog := AcceptDialog.new()
	var time_str := ""
	var stat_str := ""
	if world_state:
		time_str = " · " + world_state.get_time_display()
	if event_engine:
		stat_str = " · 因果 %d" % event_engine.causal_marks.size()
	if world_state and not world_state.active_effects.is_empty():
		stat_str += " · 效果 %d" % world_state.active_effects.size()
	# 当前地图/区域
	var region_txt := ""
	var cur_region: String = str(world_state.get_variable("current_region", "")) if world_state else ""
	if not cur_region.is_empty():
		region_txt = " · 📍%s" % cur_region
	# 标题精简（统计信息放内容区，避免标题溢出）
	if stat_str.length() > 18:
		stat_str = " · 标记 %d" % (event_engine.causal_marks.size() if event_engine else 0)
	dialog.title = "世界日志%s%s%s" % [time_str, stat_str, region_txt]
	dialog.min_size = Vector2i(480, 420)
	add_child(dialog)
	var box := VBoxContainer.new()
	dialog.add_child(box)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var list := RichTextLabel.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scroll.add_child(list)
	# 内容区顶部完整统计（标题精简后的补充信息）
	var stat_line := ""
	if world_state:
		stat_line = "🗓 %s" % world_state.get_time_display()
	if event_engine:
		var causal_count: int = event_engine.causal_marks.size()
		stat_line += " · 因果标记 %d" % causal_count
		stat_line += " · 选择历史 %d" % event_engine.choices_history.size()
	if world_state and not world_state.active_effects.is_empty():
		stat_line += " · 世界效果 %d" % world_state.active_effects.size()
	if not stat_line.is_empty():
		list.append_text("[color=#9a8f7a]%s[/color]\n\n" % stat_line)
	# 选择历史摘要（最近 5 条）
	if event_engine != null and not event_engine.choices_history.is_empty():
		list.append_text("[b]【选择历史】[/b]\n")
		var ch: Array = event_engine.choices_history
		var start_idx := maxi(0, ch.size() - 5)
		for i in range(start_idx, ch.size()):
			var c: Dictionary = ch[i]
			list.append_text("• %s → %s\n" % [c.get("event_id", "?"), c.get("choice_id", "?")])
		list.append_text("\n")
	# 因果标记详情（最近 5 条）
	if event_engine != null and not event_engine.causal_marks.is_empty():
		list.append_text("[b]【因果标记】[/b]\n")
		var cm: Array = event_engine.causal_marks
		var start_cm := maxi(0, cm.size() - 5)
		for i in range(start_cm, cm.size()):
			var c2: Dictionary = cm[i]
			list.append_text("• %s = %s\n" % [c2.get("key", c2.get("id", "?")), str(c2.get("value", c2.get("state", "?")))])
		list.append_text("\n")
	# 复制日志按钮
	var copy_btn := Button.new()
	copy_btn.text = "⧉ 复制日志"
	copy_btn.pressed.connect(func():
		DisplayServer.clipboard_set(list.text)
		ToastManager.success("日志已复制"))
	box.add_child(copy_btn)
	# 导出日志按钮
	var export_btn := Button.new()
	export_btn.text = "💾 导出日志"
	export_btn.pressed.connect(func():
		var fd := FileDialog.new()
		fd.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		fd.title = "导出世界日志"
		fd.add_filter("*.txt ; 文本文件")
		fd.current_path = "世界日志_%s.txt" % Time.get_datetime_string_from_system().substr(0, 10).replace("-", "")
		fd.min_size = Vector2i(600, 400)
		add_child(fd)
		fd.file_selected.connect(func(path: String):
			var save_path := path
			if not save_path.ends_with(".txt"):
				save_path += ".txt"
			var f := FileAccess.open(save_path, FileAccess.WRITE)
			if f:
				f.store_string(list.text)
				f.close()
				ToastManager.success("日志已导出")
			else:
				ToastManager.warning("导出失败")
			fd.queue_free())
		fd.popup_centered())
	box.add_child(export_btn)
	var has_any := false
	# 已探索区域
	if world_state and not world_state.explored_regions.is_empty():
		list.append_text("[b]【已探索区域】[/b]\n")
		list.append_text("• %s\n" % "、".join(PackedStringArray(world_state.explored_regions)))
		has_any = true
	# 势力关系
	if world_state and not world_state.faction_states.is_empty():
		list.append_text("[b]【势力关系】[/b]\n")
		for fid in world_state.faction_states:
			var rel: Variant = world_state.faction_states[fid]
			var val: float = float(rel.get("relationship", rel)) if rel is Dictionary else float(rel)
			list.append_text("• %s: %s\n" % [fid, str(val)])
			has_any = true
	if event_engine:
		if not event_engine.causal_marks.is_empty():
			list.append_text("[b]【因果标记】[/b]\n")
			for cm in event_engine.causal_marks:
				var cm_day := ""
				if world_state:
					cm_day = "（第 %d 天）" % world_state.get_current_day()
				list.append_text("• %s%s\n" % [str(cm.get("mark", cm)), cm_day])
				has_any = true
		if not event_engine.choices_history.is_empty():
			list.append_text("\n[b]【选择历史】[/b]\n")
			# 分支点统计
			if not event_engine.branch_points.is_empty():
				list.append_text("[color=#888]（共 %d 个剧情分支点）[/color]\n" % event_engine.branch_points.size())
			for ch in event_engine.choices_history:
				var cid: String = str(ch.get("choice_id", ch.get("choice", "")))
				var eid: String = str(ch.get("event_id", ""))
				var ch_day := ""
				if world_state and ch.has("day"):
					ch_day = "（第 %d 天）" % int(ch.get("day", 1))
				var ch_ts: String = str(ch.get("timestamp", ""))
				if not ch_ts.is_empty():
					ch_day += " %s" % ch_ts
				list.append_text("• %s（%s）%s\n" % [cid, eid, ch_day])
				has_any = true
	if not has_any:
		list.append_text("[color=#999]暂无世界事件记录…[/color]")
	# 经济状态
	if economy_engine:
		var gold: int = int(economy_engine.player_currencies.get("gold", 0))
		list.append_text("\n[b]【经济】[/b]\n")
		list.append_text("• 💰 金币 %d · 🎒 物品 %d\n" % [gold, economy_engine.player_inventory.size()])
	# 玩家状态
	if combat_engine and not combat_engine.player_combat_stats.is_empty():
		var pstats: Dictionary = combat_engine.player_combat_stats
		list.append_text("\n[b]【玩家】[/b]\n")
		list.append_text("• 🎖 Lv.%d · ❤️ %d/%d · ⚡ %d/%d\n" % [
			int(pstats.get("level", 1)),
			int(pstats.get("hp", 0)), int(pstats.get("max_hp", 1)),
			int(pstats.get("mp", 0)), int(pstats.get("max_mp", 1))])
		var shd: int = int(pstats.get("shield", 0))
		if shd > 0:
			list.append_text("• 🛡 护盾 %d\n" % shd)
	# 世界效果（进行中）
	if world_state and not world_state.active_effects.is_empty():
		list.append_text("\n[b]【世界效果】[/b]\n")
		var fx_icons := {"blessing": "✨", "curse": "💀", "drought": "☀️", "rain": "🌧", "festival": "🎉"}
		for fx in world_state.active_effects:
			var fxt := str(fx.get("id", "?"))
			var fxr: int = int(fx.get("remaining", 0))
			var fx_dur := "%d 小时" % fxr
			if fxr >= 24:
				fx_dur = "%d 天 %d 小时" % [fxr / 24, fxr % 24]
			list.append_text("• %s %s（剩 %s）\n" % [fx_icons.get(fxt, "🌀"), fxt, fx_dur])
	# 战斗统计
	if _battle_wins + _battle_defeats + _battle_flees > 0:
		list.append_text("\n[b]【战斗】[/b]\n")
		list.append_text("• ⚔️ 胜 %d · 败 %d · 逃 %d\n" % [_battle_wins, _battle_defeats, _battle_flees])
	# 世界变量（关键剧情标记）
	if world_state and not world_state.world_variables.is_empty():
		list.append_text("\n[b]【世界变量】[/b]\n")
		for k in world_state.world_variables:
			var v: Variant = world_state.world_variables[k]
			if v is bool:
				list.append_text("• %s: %s\n" % [k, "是" if v else "否"])
			else:
				list.append_text("• %s: %s\n" % [k, str(v)])
	# 日志行数上限（防长剧情卡顿，截断保留 280 行）
	if list.get_line_count() > 280:
		var keep_txt := ""
		var start_line: int = list.get_line_count() - 240
		for li in range(start_line, list.get_line_count()):
			keep_txt += list.get_line(li) + "\n"
		list.text = "[color=#888]（较早记录已折叠）[/color]\n" + keep_txt
	dialog.popup_centered()

## 休息：时间推进 + 回满状态
func _on_menu_rest_pressed() -> void:
	# 休息确认（推进 8 小时，可能触发随机事件）
	var confirm := ConfirmationDialog.new()
	confirm.dialog_text = "⛺ 休息 8 小时？\\nHP/MP 将回满，时间推进，30% 概率遭遇随机事件。"
	confirm.confirmed.connect(func(): _do_rest())
	add_child(confirm)
	confirm.popup_centered()

func _do_rest() -> void:
	if world_state:
		world_state.advance_time(8)
	var recovered_hp := 0
	var recovered_mp := 0
	if combat_engine and not (combat_engine.player_combat_stats as Dictionary).is_empty():
		var stats: Dictionary = combat_engine.player_combat_stats
		recovered_hp = int(stats.get("max_hp", 100)) - int(stats.get("hp", 0))
		recovered_mp = int(stats.get("max_mp", 50)) - int(stats.get("mp", 0))
		stats["hp"] = stats.get("max_hp", 100)
		stats["mp"] = stats.get("max_mp", 50)
	_update_ui()
	_sync_save_state()
	ToastManager.success("⛺ 休息 8 小时：HP +%d / MP +%d" % [maxi(recovered_hp, 0), maxi(recovered_mp, 0)])
	# 恢复飘字（绿色 +）
	if recovered_hp > 0:
		_spawn_damage_popup(recovered_hp)
	_add_history("在营地休息了 8 小时，状态恢复（HP +%d / MP +%d）" % [maxi(recovered_hp, 0), maxi(recovered_mp, 0)])
	# 休息后概率触发随机事件（30%）
	if event_engine != null and randf() < 0.3:
		var random_event: Dictionary = event_engine.check_random_events()
		if not random_event.is_empty():
			_run_event(random_event)

## 通关统计弹窗（天数/等级/金币/事件数）
func _show_finish_stats() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "🎉 通关！"
	dialog.min_size = Vector2i(420, 320)
	add_child(dialog)
	var list := RichTextLabel.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialog.add_child(list)
	var day := 1
	if world_state:
		day = world_state.get_current_day()
	var lv := 1
	var gold := 0
	if combat_engine and not combat_engine.player_combat_stats.is_empty():
		lv = int(combat_engine.player_combat_stats.get("level", 1))
	if economy_engine:
		gold = int(economy_engine.player_currencies.get("gold", 0))
	var p := _get_progress()
	list.append_text("[color=#c9a06a][b]%s[/b][/color]\n\n" % script_data.name)
	list.append_text("🗓 通关天数：%d 天\n" % day)
	list.append_text("🎖 等级：Lv.%d\n" % lv)
	list.append_text("💰 持有金币：%d\n" % gold)
	list.append_text("📖 触发事件：%d 个\n" % p[0])
	list.append_text("⚔ 战斗统计：胜 %d · 负 %d · 逃 %d\n" % [_battle_wins, _battle_defeats, _battle_flees])
	list.append_text("\n[color=#888]感谢体验！可返回大厅查看成就与进度。[/color]")
	dialog.popup_centered()

## 属性详情弹窗（完整战斗属性/经验/效果）
func _on_player_stats_pressed() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "属性详情"
	dialog.min_size = Vector2i(420, 380)
	add_child(dialog)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialog.add_child(scroll)
	var list := RichTextLabel.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scroll.add_child(list)
	if combat_engine == null or combat_engine.player_combat_stats.is_empty():
		list.append_text("[color=#999]暂无战斗属性[/color]")
		dialog.popup_centered()
		return
	var st: Dictionary = combat_engine.player_combat_stats
	list.append_text("[b]等级 Lv.%d[/b]  经验 %d/100\n" % [int(st.get("level", 1)), int(st.get("exp", 0))])
	list.append_text("❤️ HP %d/%d   ⚡ MP %d/%d\n" % [int(st.get("hp", 0)), int(st.get("max_hp", 1)), int(st.get("mp", 0)), int(st.get("max_mp", 1))])
	list.append_text("⚔ 攻击 %d    🛡 防御 %d    🏃 速度 %d\n\n" % [int(st.get("atk", 0)), int(st.get("def", 0)), int(st.get("speed", 0))])
	list.append_text("[b]【状态效果】[/b]\n")
	var fx: Array = st.get("status_effects", [])
	if fx.is_empty():
		list.append_text("（无）\n")
	else:
		for f in fx:
			list.append_text("• %s（剩 %d 回合）\n" % [f.get("name", "?"), int(f.get("remaining_turns", 0))])
	list.append_text("\n[b]【金币】[/b] %d" % (int(economy_engine.player_currencies.get("gold", 0)) if economy_engine else 0))
	dialog.popup_centered()

## 菜单按钮 tooltip 统一补全
func _setup_menu_tooltips() -> void:
	var tips := {
		"SaveBtn": "保存当前进度到存档槽",
		"LoadBtn": "读取已保存的进度",
		"DeleteBtn": "删除当前存档",
		"CharBtn": "查看角色状态与装备",
		"ShopBtn": "购买/出售物品（金币交易）",
		"ExportChatBtn": "导出酒馆对话历史为 txt",
		"BagBtn": "查看背包物品与价值",
		"RatingBtn": "为本剧本评分（1-5 星）",
		"LogBtn": "查看世界事件日志",
		"RestBtn": "推进 8 小时并回满 HP/MP",
		"PlayerStatsBtn": "查看完整战斗属性与经验",
		"HelpBtn": "查看操作帮助与快捷键",
	}
	for n in tips:
		var b := get_node_or_null("MenuPanel/MenuVBox/%s" % n)
		if b is Button:
			(b as Button).tooltip_text = tips[n]
	# 保存按钮 tooltip 显示各槽位概要（动态）
	var sb2 := get_node_or_null("MenuPanel/MenuVBox/SaveBtn")
	if sb2 is Button:
		var slots_txt := ""
		for si in 3:
			var si2 := _get_slot_info(si)
			if slots_txt != "":
				slots_txt += "\n"
			slots_txt += "槽位 %d: %s" % [si + 1, si2]
		(sb2 as Button).tooltip_text = "保存到槽位（当前：\n%s）" % slots_txt
	# 读档按钮 tooltip 同（非空槽位）
	var lb2 := get_node_or_null("MenuPanel/MenuVBox/LoadBtn")
	if lb2 is Button:
		var load_txt := ""
		for si in 3:
			var li := _get_slot_info(si)
			if li != "(空)":
				if load_txt != "":
					load_txt += "\n"
				load_txt += "槽位 %d: %s" % [si + 1, li]
		(lb2 as Button).tooltip_text = "读取存档（%s）" % (load_txt if load_txt != "" else "暂无存档")

## 通关结算（可重复查看）
func _on_menu_finish_stats_pressed() -> void:
	if _get_progress()[0] <= 0:
		ToastManager.info("尚未体验任何事件，暂无可结算内容")
		return
	_show_finish_stats()

## 操作帮助弹窗
func _on_menu_help_pressed() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "操作帮助"
	dialog.dialog_text = """【基本操作】
- 点击 / 空格 / 回车：继续剧情、跳过打字机
- H：随时打开本帮助
- T：快捷打开 / 关闭酒馆
- Esc：打开 / 关闭菜单
- 顶部菜单：存档 / 读档 / 酒馆对话 / 评分

【战斗】
- 遭遇敌人后出现战斗面板：攻击 / 技能 / 逃跑
- 数字键 1-9：直接释放对应技能
- 自动战斗按钮：连续点击可调速（1x/2x/4x）
- Tab / 点击敌人栏：切换攻击目标（多敌人时）
- 技能需消耗 MP，魔力不足会置灰禁用

【酒馆 🏮】
- 与旅店老板娘 / 老学者对话，了解世界观线索
- 对话历史自动保存

【提示】
- 每 5 分钟自动存档，退出前建议手动保存
- 剧本进度会同步到大厅卡片进度条"""
	dialog.min_size = Vector2i(520, 480)
	add_child(dialog)
	dialog.popup_centered()

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
	selector.custom_minimum_size = Vector2(340, 300)
	selector.set_anchors_preset(Control.PRESET_CENTER)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	selector.add_child(vbox)

	var title_label := Label.new()
	title_label.text = "选择存档槽位" if mode == "save" else ("选择加载槽位" if mode == "load" else "选择删除槽位")
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)

	for slot in 3:
		var btn := Button.new()
		var slot_info := _get_slot_info(slot)
		btn.text = "槽位 %d: %s" % [slot + 1, slot_info]
		btn.tooltip_text = "槽位 %d 详情：%s" % [slot + 1, slot_info]
		btn.custom_minimum_size = Vector2(0, 40)
		match mode:
			"save":
				btn.pressed.connect(_on_slot_save_selected.bind(slot))
			"load":
				btn.pressed.connect(_on_slot_load_selected.bind(slot))
			"delete":
				btn.pressed.connect(_on_slot_delete_selected.bind(slot))
		vbox.add_child(btn)

	# 自动存档槽位（独立第 4 项）
	if mode != "delete":
		var auto_info := SaveManager.get_slot_info(0, true)
		var auto_txt := "(空)"
		if not auto_info.is_empty():
			var apct := ""
			var ap: float = float(auto_info.get("progress", 0.0))
			if ap > 0.0:
				apct = " | %d%%" % int(ap * 100.0)
			auto_txt = "%s | Lv.%d%s | %s" % [
				auto_info.get("player_name", "?"), auto_info.get("level", 1), apct, _fmt_play_time(auto_info.get("play_time", 0))]
		var auto_btn := Button.new()
		auto_btn.text = "自动存档: %s" % auto_txt
		auto_btn.custom_minimum_size = Vector2(0, 40)
		match mode:
			"save":
				auto_btn.pressed.connect(func():
					SaveManager.autosave()
					_add_history("已保存到自动存档")
					selector.queue_free()
					menu_panel.visible = false
					ToastManager.success("已自动保存"))
			"load":
				auto_btn.pressed.connect(func():
					var sd2: SaveData = SaveManager.load_game(0, true)
					if sd2 == null:
						ToastManager.warning("自动存档不存在")
						return
					_restore_save_state(sd2)
					selector.queue_free()
					menu_panel.visible = false)
		vbox.add_child(auto_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "取消"
	cancel_btn.pressed.connect(func(): selector.queue_free())
	vbox.add_child(cancel_btn)

	add_child(selector)
	# 淡入动画（可关闭）
	if ThemeManager.animations_enabled:
		selector.modulate.a = 0.0
		var stw := create_tween()
		stw.tween_property(selector, "modulate:a", 1.0, 0.15)

## 格式化游玩时长（秒 → Xh Ym / Ym / Xs）
func _fmt_play_time(sec_val: Variant) -> String:
	var total := int(float(sec_val))
	if total <= 0:
		return "0:00"
	var h := total / 3600
	var m := (total % 3600) / 60
	if h > 0:
		return "%dh %02dm" % [h, m]
	return "%dm" % m

## 获取槽位信息
func _get_slot_info(slot: int) -> String:
	var save_info := SaveManager.get_slot_info(slot)
	if save_info.is_empty():
		return "(空)"
	var prog_pct := ""
	var pp: float = float(save_info.get("progress", 0.0))
	if pp > 0.0:
		prog_pct = " | %d%%" % int(pp * 100.0)
	return "%s | Lv.%d%s | %s" % [
		save_info.get("player_name", "?"),
		save_info.get("level", 1),
		prog_pct,
		_fmt_play_time(save_info.get("play_time", 0))
	]

## 槽位保存
func _on_slot_save_selected(slot: int) -> void:
	var ok := SaveManager.save_game(slot)
	if ok:
		_add_history("游戏已保存到槽位 %d（第 %d 天）" % [slot + 1, world_state.get_current_day() if world_state else 1])
		ToastManager.success("已保存到槽位 %d" % (slot + 1))
	else:
		ToastManager.warning("保存失败")
	var sel := get_node_or_null("SlotSelector")
	if sel:
		sel.queue_free()
	menu_panel.visible = false

## 槽位删除（带确认）
func _on_slot_delete_selected(slot: int) -> void:
	var slot_info := _get_slot_info(slot)
	if slot_info == "(空)":
		ToastManager.info("该槽位为空，无需删除")
		return
	var confirm := ConfirmationDialog.new()
	confirm.dialog_text = "确定删除槽位 %d 的存档（%s）吗？此操作不可恢复。" % [slot + 1, slot_info]
	confirm.confirmed.connect(func():
		SaveManager.delete_save(script_data.id if script_data else "", slot)
		ToastManager.success("存档已删除")
		var sel := get_node_or_null("SlotSelector")
		if sel:
			sel.queue_free())
	add_child(confirm)
	confirm.popup_centered()

## 槽位加载
func _on_slot_load_selected(slot: int) -> void:
	# 加载确认（覆盖当前进度不可恢复）
	var slot_info := _get_slot_info(slot)
	if slot_info == "(空)":
		ToastManager.warning("该槽位为空")
		return
	var confirm := ConfirmationDialog.new()
	confirm.dialog_text = "从槽位 %d 加载？当前未保存进度将被覆盖。" % (slot + 1)
	confirm.confirmed.connect(func():
		var sd3: SaveData = SaveManager.load_game(slot)
		if sd3 == null:
			ToastManager.warning("读取失败")
			return
		_restore_save_state(sd3)
		_add_history("已从槽位 %d 加载" % (slot + 1))
		var sel := get_node_or_null("SlotSelector")
		if sel:
			sel.queue_free()
		menu_panel.visible = false
		_update_ui()
		# 恢复三引擎状态
		var sd := SaveManager.current_save
		if sd:
			if event_engine:
				event_engine.load_history(sd.event_history)
			if world_state:
				world_state.load_from_dict(sd.world_state)
			if economy_engine:
				economy_engine.load_from_dict(sd.economy_state)
			_set_main_text("[b]已加载存档[/b]\n\n%s" % script_data.name)
			_advance_to_next_event())
	add_child(confirm)
	confirm.popup_centered()
