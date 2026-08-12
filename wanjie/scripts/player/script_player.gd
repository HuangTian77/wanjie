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
@onready var battle_log_clear: Button = %BattleLogClear
@onready var tavern_panel: PanelContainer = %TavernPanel
@onready var tavern_char_select: OptionButton = %TavernCharSelect
@onready var tavern_msgs: RichTextLabel = %TavernMsgs
@onready var tavern_input: LineEdit = %TavernInput
@onready var econ_label: Label = %EconLabel
@onready var item_label: Label = %ItemLabel
@onready var quest_label: Label = %QuestLabel
@onready var auto_indicator: Label = %AutoIndicator
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
## 最近自动保存时间（秒，用于按钮反馈）
var _last_autosave_time: float = 0.0
## 上次休息时的天数（跨天自动存档用）
var _last_rest_day: int = -1
## 上次休息时间（毫秒，防连点）
var _last_rest_ms: int = 0
## 休息开始时的天数（跨天提示用）
var _rest_start_day: int = -1
## 休息次数统计
var _rest_count: int = 0
## 本场战斗累计伤害
var _total_damage_dealt: int = 0
## 本场掉落物品数
var _loot_count: int = 0
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
	# 加载酒馆好感度
	if GameManager.user_data.tavern_moods is Dictionary:
		_tavern_moods = (GameManager.user_data.tavern_moods as Dictionary).duplicate()
	# 恢复历史折叠状态
	if GameManager.user_data.history_collapsed:
		history_panel.visible = false
		history_toggle.text = "▼ 展开记录"
	else:
		history_panel.visible = true
		history_toggle.text = "▲ 收起记录(%d)" % history_text.get_line_count()
	# 恢复自动推进偏好
	_auto_advance_mode = GameManager.user_data.auto_advance
	# 历史右键复制菜单
	history_text.context_menu_enabled = true
	_init_engines()
	_start_experience()
	history_toggle.pressed.connect(_on_history_toggle_pressed)
	var hclear := get_node_or_null("%HistoryClear")
	if hclear is Button:
		(hclear as Button).pressed.connect(_on_history_clear_pressed)
	var hcopy := get_node_or_null("%HistoryCopy")
	if hcopy is Button:
		(hcopy as Button).pressed.connect(_on_history_copy_pressed)
	ToastManager.info("已消耗 1 点灵感进入剧本")
	# 自动推进已开启提示（偏好恢复）
	if _auto_advance_mode:
		ToastManager.info("▶ 自动推进已开启（A 可关闭）")
	# 定时自动存档（每 5 分钟，可按设置间隔）
	var auto_save_timer := Timer.new()
	auto_save_timer.name = "AutoSaveTimer"
	auto_save_timer.wait_time = maxf(60.0, float(settings_auto_save_interval_min()) * 60.0)
	auto_save_timer.autostart = true
	auto_save_timer.timeout.connect(func():
		_sync_save_state()
		SaveManager.autosave()
		_last_autosave_time = Time.get_ticks_msec() / 1000.0
		_add_history("⏱ 自动存档（第 %d 天）" % (world_state.get_current_day() if world_state else 1))
		# 自动存档静默提示（仅首 3 次 Toast，之后仅历史记录防打扰）
		_auto_save_count += 1
		if _auto_save_count <= 3:
			var time_txt3: String = world_state.get_time_display() if world_state != null else ""
			ToastManager.success("⏱ 已自动存档 · %s" % time_txt3))
	add_child(auto_save_timer)
	# 自动推进计时器
	_auto_continue_timer = Timer.new()
	_auto_continue_timer.one_shot = true
	_auto_continue_timer.timeout.connect(_auto_continue)
	add_child(_auto_continue_timer)
	# 自动战斗辅助计时器（自动推进模式）
	_auto_combat_timer = Timer.new()
	_auto_combat_timer.wait_time = 0.8
	_auto_combat_timer.timeout.connect(func():
		if not _auto_advance_mode or not battle_panel.visible:
			_auto_combat_timer.stop()
			return
		# 低血时自动用药
		if combat_engine != null:
			var ps5: Dictionary = combat_engine.player_combat_stats
			var hp_ratio := 0.0
			if int(ps5.get("max_hp", 100)) > 0:
				hp_ratio = float(int(ps5.get("hp", 0))) / float(int(ps5.get("max_hp", 100)))
			# 强敌逃跑：5 回合后仍低血则逃跑
			if combat_engine.current_round > 5 and hp_ratio < 0.4:
				_battle_log_line("🏃 自动撤退（久战不利）", "#8a8278")
				_on_battle_flee_pressed()
				return
			if hp_ratio <= 0.3:
				_use_first_potion()
			# 自动技能：有 MP 时使用第一个攻击技能
			elif int(ps5.get("mp", 0)) >= 10 and combat_engine.ability_data != null:
				var skills2: Array = combat_engine.ability_data.skills
				if not skills2.is_empty():
					# 随机选一个可用技能（MP 足够时）
					var usable: Array = []
					for sk2 in skills2:
						var cost2: int = int((sk2.get("cost", {}) as Dictionary).get("mana", 0))
						if cost2 <= int(ps5.get("mp", 0)):
							usable.append(sk2)
					var pick: Dictionary = usable[randi() % usable.size()] if not usable.is_empty() else skills2[0]
					var sid2: String = str(pick.get("id", ""))
					if not sid2.is_empty():
						combat_engine.player_use_skill(sid2, 0)
						_refresh_battle_ui()
						return
		_on_battle_attack_pressed())
	add_child(_auto_combat_timer)

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
			# 低血保护：HP<25% 自动暂停自动战斗（提示手动治疗/逃跑）
			var hp_low: int = int(combat_engine.player_combat_stats.get("hp", 0))
			var hp_low_max: int = int(combat_engine.player_combat_stats.get("max_hp", 1))
			if hp_low_max > 0 and hp_low < hp_low_max * 0.25:
				_auto_battle = false
				ToastManager.warning("🛑 生命低于 25%%，自动战斗已暂停（建议治疗或逃跑）")
				var auto_btn := get_node_or_null("BattlePanel/BattleVBox/BattleButtons/AutoBtn")
				if auto_btn is Button:
					(auto_btn as Button).text = "自动"
				return
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
							_battle_log_line("💚 自动使用治疗技能回血", "#7cc47c")
							break
			# 否则 25% 概率释放第一个可用技能
			if not used_skill and combat_engine.ability_data != null and randf() < 0.25:
				for sk in combat_engine.ability_data.skills:
					var mcost: int = int((sk.get("cost", {}) as Dictionary).get("mana", 0))
					if mcost <= int(combat_engine.player_combat_stats.get("mp", 0)):
						combat_engine.player_use_skill(str(sk.get("id", "")), -1)
						_refresh_battle_ui()
						used_skill = true
						_battle_log_line("⚡ 自动释放技能：%s" % str(sk.get("name", "技能")), "#e6c84c")
						break
			if not used_skill:
				# 智能集火：优先攻击低血敌人（<25%）
				var best_t := -1
				var best_ratio := 1.1
				for ei in combat_engine.enemies.size():
					if not combat_engine.enemies[ei].get("is_alive", true):
						continue
					var em: int = maxi(1, int(combat_engine.enemies[ei].get("max_hp", 1)))
					var eh: int = int(combat_engine.enemies[ei].get("hp", 0))
					var r: float = float(eh) / float(em)
					if r < best_ratio:
						best_ratio = r
						best_t = ei
				if best_t >= 0:
					_battle_target = best_t
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
			# 自动模式：短暂延迟后自动继续
			if _auto_advance_mode and not _advancing:
				_auto_continue_timer.start(_auto_advance_delay)
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
		# Esc 优先级：评分弹窗 > 角色面板 > 背包 > 商店 > 世界日志 > 酒馆 > 槽位选择器 > 菜单
		if get_node_or_null("RatingDialog") != null:
			get_node_or_null("RatingDialog").queue_free()
			get_viewport().set_input_as_handled()
			return
		if get_node_or_null("CharStatusDialog") != null:
			get_node_or_null("CharStatusDialog").queue_free()
			get_viewport().set_input_as_handled()
			return
		if get_node_or_null("BagDialog") != null:
			get_node_or_null("BagDialog").queue_free()
			get_viewport().set_input_as_handled()
			return
		if get_node_or_null("ShopDialog") != null:
			get_node_or_null("ShopDialog").queue_free()
			get_viewport().set_input_as_handled()
			return
		if get_node_or_null("WorldLogDialog") != null:
			get_node_or_null("WorldLogDialog").queue_free()
			get_viewport().set_input_as_handled()
			return
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
	# A: 自动推进开关
	elif event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_A and not menu_panel.visible \
			and not battle_panel.visible and _no_dialog_open():
		_auto_advance_mode = not _auto_advance_mode
		# 持久化自动推进偏好
		GameManager.user_data.auto_advance = _auto_advance_mode
		GameManager.user_data.save_user_data()
		if _auto_advance_mode:
			ToastManager.success("▶ 自动推进开启（A 关闭）")
			# 若当前文本已完成则立即继续
			if _typewriter_done and choice_container.get_child_count() == 0:
				_auto_continue_timer.start(_auto_advance_delay)
		else:
			ToastManager.info("⏸ 自动推进关闭")
		get_viewport().set_input_as_handled()
	# B: 快速返回大厅（触发确认）
	elif event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_B and menu_panel.visible and _no_dialog_open():
		_on_menu_back_pressed()
		get_viewport().set_input_as_handled()
	# S: 快速保存（菜单打开时）
	elif event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_S and menu_panel.visible and _no_dialog_open():
		_on_menu_save_pressed()
		get_viewport().set_input_as_handled()
	# L: 快速读档（菜单打开时）
	elif event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_L and menu_panel.visible and _no_dialog_open():
		_on_menu_load_pressed()
		get_viewport().set_input_as_handled()
	# H: 打开操作帮助
	elif event is InputEventKey and event.pressed and event.keycode == KEY_H:
		_on_menu_help_pressed()
		get_viewport().set_input_as_handled()
	# C: 打开角色状态面板
	elif event is InputEventKey and event.pressed and event.keycode == KEY_C and not event.ctrl_pressed \
			and not battle_panel.visible and _no_dialog_open():
		_on_menu_char_pressed()
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
			and event.keycode == KEY_Q:
		# Q 键：使用第一个药水/草药恢复 HP
		_use_first_potion()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and battle_panel.visible \
			and event.keycode >= KEY_1 and event.keycode <= KEY_9:
		var skill_idx: int = event.keycode - KEY_1
		if combat_engine != null and combat_engine.ability_data != null:
			var skills: Array = combat_engine.ability_data.skills
			if skill_idx < skills.size():
				# MP 不足时自动改普攻（回蓝）
				var skill_cost: int = int((skills[skill_idx].get("cost", {}) as Dictionary).get("mana", 0))
				var mp_cur2: int = int(combat_engine.player_combat_stats.get("mp", 0))
				if skill_cost > mp_cur2:
					ToastManager.info("✦ MP 不足（需 %d），已改为普攻" % skill_cost)
					_on_battle_attack_pressed()
				else:
					var sid: String = str(skills[skill_idx].get("id", ""))
					if not sid.is_empty():
						combat_engine.player_use_skill(sid, 0)
						_refresh_battle_ui()
				get_viewport().set_input_as_handled()
			else:
				ToastManager.info("技能 %d 不存在（当前 %d 个技能）" % [skill_idx + 1, skills.size()])
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
	# 有存档 → 从存档继续；否则新开（Toast 区分）
	if SaveManager.has_save(script_data.id):
		ToastManager.info("📂 检测到存档，继续上次进度")
		_continue_from_save()
		return
	ToastManager.info("✨ 开始新的冒险")
	_start_new_experience()

## 新开一局（无存档时的初始流程）
func _start_new_experience() -> void:
	_update_ui()
	ToastManager.info("🌅 冒险开始 · 第一缕晨光" if world_state and world_state.get_period_name() == "清晨" else "🌅 冒险开始")
	var bg_text := ""
	if script_data.worldview and not script_data.worldview.background_story.is_empty():
		bg_text = script_data.worldview.background_story
	else:
		bg_text = script_data.description
	_set_main_text("[b]【%s】[/b]\n\n%s" % [script_data.name, bg_text])
	var start_txt: String = world_state.get_time_display() if world_state else ""
	_add_history("进入世界: %s（%s）" % [script_data.name, start_txt])
	# 进本时世界效果提示（进行中的效果）
	if world_state != null and not world_state.active_effects.is_empty():
		var fx_names: Array[String] = []
		for fxid5 in world_state.active_effects:
			fx_names.append("%s(%dh)" % [fxid5, int(world_state.active_effects[fxid5])])
		ToastManager.info("🌪 世界效果：%s" % "，".join(fx_names))
	# 进本时进行中任务提示
	if script_data != null and script_data.quest_system != null:
		for q6 in script_data.quest_system.quests:
			if str(q6.get("status", "")) == "active":
				ToastManager.info("📋 当前任务：%s" % str(q6.get("name", q6.get("id", ""))))
				break
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
	# 清理任何残留战斗 UI（续档不应直接进入战斗）
	if battle_panel != null:
		battle_panel.visible = false
	if combat_engine != null:
		combat_engine.reset_battle()
	_update_ui()
	var day: int = (sd.world_state.get("game_time", {}) as Dictionary).get("day", 1)
	# 恢复自动推进偏好
	_auto_advance_mode = GameManager.user_data.auto_advance
	# 酒馆恢复（当前角色/历史）
	if TavernManager != null and not TavernManager.current_character.is_empty():
		TavernManager.load_history(str(TavernManager.current_character.get("id", "innkeeper")))
	_set_main_text("[b]【%s】[/b]\n\n已从存档继续…（第 %d 天）" % [script_data.name, day])
	_add_history("继续世界: %s（第 %d 天）" % [script_data.name, day])
	ToastManager.success("第 %d 天 · 继续冒险" % day)
	# 进度百分比
	var prog5 := _get_progress()
	if prog5[1] > 0:
		var pct5 := int(float(prog5[0]) / float(prog5[1]) * 100.0)
		ToastManager.info("📊 剧情进度 %d%%" % pct5)
	_refresh_menu_title()
	_advance_to_next_event()

## 继续提示闪烁（无选择按钮时显示 ▸ 继续，有限闪烁后自动清除）
func _show_continue_blink(show: bool) -> void:
	var hint := get_node_or_null("MainVBox/HintLabel")
	if hint is Label:
		if show:
			(hint as Label).text = "▸ 点击继续"
			if _auto_advance_mode:
				(hint as Label).text = "▶ 自动推进中（A 停止）"
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
## 自动模式推进间隔（秒，A 切换后 ± 调整）
var _auto_advance_delay: float = 0.5
## 自动推进模式开关（A 键切换）
var _auto_advance_mode: bool = false
## 自动模式延迟推进计时器
var _auto_continue_timer: Timer
## 自动战斗辅助计时器（自动推进模式）
var _auto_combat_timer: Timer
## 自动指示呼吸动画已启动
var _auto_indicator_tween_started: bool = false
## 当前显示的任务（切换提示用）
var _last_quest_shown: String = ""
## 本次游玩触发事件计数
var _event_trigger_count: int = 0
## 自动存档次数（前几次提示，之后静默）
var _auto_save_count: int = 0
## 连续逃跑失败计数
var _flee_fail_count: int = 0
## 连续战败场数
var _lose_streak: int = 0
## 连续胜利场数
var _win_streak: int = 0
## 商店刷新次数（本次游玩）
var _shop_refresh_count: int = 0
## 累计购买件数（本次游玩）
var _buy_count: int = 0
## 累计出售件数（本次游玩）
var _sell_count: int = 0
## 本次游玩是否已评分（防重复）
var _rated_this_run: bool = false
## 好感度已满提示标志
var _tavern_mood_full_toast: int = 0
## 已听背景故事的角色（防重复）
var _heard_backgrounds: Dictionary = {}
## 发现彩蛋秘闻次数
var _egg_count: int = 0
## 帮助窗口滚动位置（重开记忆）
var _help_scroll_pos: int = 0
## 酒馆输入历史（↑ 键调出，保留 10 条）
var _tavern_input_history: Array[String] = []
## 连续探索次数（连击奖励）
var _explore_streak: int = 0
## 敌人图鉴（击败敌人 → 次数，本次游玩）
var _enemy_codex: Dictionary = {}
## 当前区域（切换提示用）
var _last_region: String = ""
## 酒馆角色心情（char_id → 0/1/2 档）
var _tavern_moods: Dictionary = {}
## 酒馆未读消息数（顶栏角标）
var _tavern_unread: int = 0
## 历史记录上次所在天（跨天分节）
var _history_last_day: int = 0
## 每日事件计数（第 N 天 → 条数）
var _history_day_stats: Dictionary = {}

## 跨天时统计展示（在日志分节标题下显示当天事件数）
func _add_history_day_count(day: int) -> void:
	var cnt: int = int(_history_day_stats.get(day, 0))
	history_text.text += "[color=#8a7a68]（第 %d 天事件 %d 条）[/color]\n" % [day, cnt]
## 历史折叠时新增条数（未读提示）
var _history_unread: int = 0
## 当前酒馆角色索引
var tavern_char_index: int = 0

## 彩蛋话题发送（bind 参数避免循环变量捕获问题）
func _send_egg_topic(topic: String) -> void:
	tavern_input.text = topic
	_on_tavern_send_pressed()

## 更新酒馆角色下拉（显示心情标记）
func _tavern_update_char_label() -> void:
	var sel := get_node_or_null("TavernPanel/TavernVBox/TavernHeader/TavernCharSelect")
	if sel is OptionButton:
		for i in TAVERN_CHARS.size():
			var name: String = str(TAVERN_CHARS[i].get("name", "角色"))
			var mood_icon := ""
			match _tavern_moods.get(str(TAVERN_CHARS[i].get("id", "")), 0):
				1: mood_icon = " 🙂"
				2: mood_icon = " 😊"
			(sel as OptionButton).set_item_text(i, name + mood_icon)
			var mood_tip := "普通关系"
			match _tavern_moods.get(str(TAVERN_CHARS[i].get("id", "")), 0):
				1: mood_tip = "友好（多聊聊会更好）"
				2: mood_tip = "亲密（对方敞开心扉）"
			(sel as OptionButton).set_item_tooltip(i, "好感度：%s" % mood_tip)
			# 亲密后解锁背景故事
			if _tavern_moods.get(str(TAVERN_CHARS[i].get("id", "")), 0) >= 2 and TAVERN_CHARS[i].has("background"):
				(sel as OptionButton).set_item_tooltip(i, "%s\n📖 背景：%s" % [mood_tip, TAVERN_CHARS[i]["background"]])
## 推进到下一个事件
func _advance_to_next_event() -> void:
	if _advancing:
		return
	_advancing = true
	# 推进时清除主文本 tooltip（防残留）
	main_text.tooltip_text = ""
	if event_engine == null:
		_advancing = false
		return
	if world_state:
		var day_before: int = world_state.get_current_day()
		world_state.advance_time(1)
		# 跨天提示
		if world_state.get_current_day() > day_before:
			ToastManager.info("🌅 新的一天（第 %d 天）" % world_state.get_current_day())
			_add_history("🌅 新的一天开始（第 %d 天）" % world_state.get_current_day())
		var expired: Array = world_state.tick_effects()
		if not expired.is_empty():
			var expired_names: PackedStringArray = []
			for ex in expired:
				expired_names.append(str(ex.get("id", ex)) if ex is Dictionary else str(ex))
			ToastManager.info("⏳ 世界效果已结束：%s" % "、".join(expired_names))
			_add_history("世界效果结束: %s" % "、".join(expired_names))
	_update_ui()

	var triggerable: Array = event_engine.check_triggerable_events()
	if triggerable.is_empty():
		var random_event: Dictionary = event_engine.check_random_events()
		if not random_event.is_empty():
			_run_event(random_event)
		else:
			var time_info := ""
			var scenery := ""
			var region_desc := ""
			var rand_hint := ""
			if world_state:
				time_info = "（%s · %s）" % [world_state.get_time_display(), world_state.get_period_name()]
				# 当前区域
				var cur_r: String = str(world_state.get_variable("current_region", ""))
				if not cur_r.is_empty():
					region_desc = "你正身处📍%s。" % cur_r
				# 时段场景描写（增加氛围）
				match world_state.get_period_name():
					"清晨": scenery = "晨雾还未散尽，鸟鸣从林间传来。"
					"白天": scenery = "阳光正好，远山轮廓清晰可见。"
					"傍晚": scenery = "晚霞把天边染成金色，炊烟袅袅升起。"
					"夜晚": scenery = "月色清冷，唯有虫鸣与风作伴。"
			# 随机事件可遭遇提示
			if script_data != null and script_data.event_system != null:
				var rand_total: int = script_data.event_system.random_events.size() if script_data.event_system.get("random_events") != null else 0
				if rand_total > 0:
					rand_hint = "此世界有 %d 个随机事件可遭遇。" % rand_total
			# 探索连击显示
			if _explore_streak > 1:
				rand_hint += "\n🔍 连续探索 x%d（x5/x10 奖励灵感）" % _explore_streak
			_set_main_text("你在这个世界中继续探索...%s\n%s%s\n暂时没有发现特别的事件。\n\n[color=#8a8278]%s[/color]\n\n[i][点击继续探索][/i]\n\n[color=#8a8278]（可按 A 开启自动推进）[/color]" % [time_info, region_desc, scenery, rand_hint])
			# 探索小奖励（+2 经验鼓励继续）
			if combat_engine != null and not combat_engine.player_combat_stats.is_empty():
				var stats_x: Dictionary = combat_engine.player_combat_stats
				stats_x["exp"] = int(stats_x.get("exp", 0)) + 2
				_sync_save_state()
				_update_ui()
			# 探索连击提示（连续探索 5 次）
			_explore_streak += 1
			if _explore_streak == 5:
				ToastManager.success("🔍 连续探索 x5！获得 +5 灵感")
				GameManager.user_data.inspiration = mini(GameManager.user_data.inspiration_max, GameManager.user_data.inspiration + 5)
				GameManager.user_data.save_user_data()
			elif _explore_streak == 10:
				ToastManager.success("🔍 连续探索 x10！获得 +10 灵感")
				GameManager.user_data.inspiration = mini(GameManager.user_data.inspiration_max, GameManager.user_data.inspiration + 10)
				GameManager.user_data.save_user_data()
			_clear_choices()
			_add_choice_button("继续探索", "_on_continue_exploring")
	else:
		_run_event(triggerable[0])
	_advancing = false

## 统一事件入口: 事件带蓝图图则蓝图驱动, 否则回退传统 event_engine 流程
func _run_event(event: Dictionary) -> void:
	# 遇到事件重置探索连击
	_explore_streak = 0
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
	ToastManager.info("📌 蓝图事件执行中…")
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
		ToastManager.warning("⚠ 蓝图执行出错：%s" % err)
		# 错误详情可复制（含执行日志）
		var err_detail := AcceptDialog.new()
		err_detail.title = "蓝图错误详情"
		err_detail.dialog_text = "%s\n\n%s" % [err, "、".join(PackedStringArray(result.get("log", [])))]
		err_detail.min_size = Vector2i(480, 300)
		add_child(err_detail)
		err_detail.popup_centered()
	elif result.get("success", false):
		_add_history("📌 事件推进完成（%d 步）" % int(result.get("steps", 0)))
		if int(result.get("steps", 0)) > 50:
			ToastManager.info("⚡ 蓝图执行 %d 步完成" % int(result.get("steps", 0)))
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
		btn.tooltip_text = "选择此选项（快捷键 %d）" % (i + 1)
		btn.pressed.connect(_on_blueprint_choice_pressed.bind(i))
		# 渐入动画（可关闭）
		if ThemeManager.animations_enabled:
			btn.modulate.a = 0.0
			var btn_tw := create_tween()
			btn_tw.tween_interval(0.05 * i)
			btn_tw.tween_property(btn, "modulate:a", 1.0, 0.15)
		choice_container.add_child(btn)

## 蓝图选择回调: resume_choice 从选择输出端口继续执行
func _on_blueprint_choice_pressed(index: int) -> void:
	if blueprint_executor == null or _blueprint_active_graph.is_empty():
		return
	_blueprint_choices = []
	_add_history("📌 做出选择（#%d）" % (index + 1))
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
	# 蓝图选项标记（📌 前缀提示来自蓝图）
	if method == "_on_blueprint_choice_pressed":
		btn.text = "📌 " + btn.text
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
	# 悬停查看最近历史全文
	history_text.tooltip_text = text
	# 每日事件计数
	var cur_day_stat: int = world_state.get_current_day() if world_state != null else 1
	_history_day_stats[cur_day_stat] = int(_history_day_stats.get(cur_day_stat, 0)) + 1
	# 类型标记（事件/后果/其他 → 便于日志筛选）
	var type_tag := "其他"
	if text.contains("事件") or text.contains("📌") or text.contains("🎲"):
		type_tag = "事件"
	elif text.contains("后果") or text.contains("选择"):
		type_tag = "后果"
	var ts := ""
	if world_state:
		# 跨天分节标题
		var cur_day: int = world_state.get_current_day()
		if _history_last_day != 0 and cur_day != _history_last_day:
			history_text.text += "[color=#c9a06a]── 第 %d 天 ──[/color]\n" % cur_day
			_add_history_day_count(cur_day)
		_history_last_day = cur_day
		ts = "[color=#8a7a68][%d月%d日 %s][/color] " % [
			world_state.get_current_day(),
			world_state.get_current_hour(),
			world_state.get_period_name()]
	history_text.text += "%s[color=#6b5e52]%s[/color]\n" % [ts, text]
	# 自动滚动到底部（新记录可见）
	var hp_scroll := get_node_or_null("MainVBox/HSplit/RightPanel/HistoryPanel") as ScrollContainer
	if hp_scroll != null:
		hp_scroll.scroll_vertical = hp_scroll.get_v_scroll_bar().max_value
	# 行尾类型标记（供日志筛选，浅灰小字）
	if type_tag != "其他":
		history_text.text += "[color=#4a443e][%s][/color]" % type_tag
	# 展开时自动滚动到底（新记录可见）
	if history_panel.visible and history_text.get_line_count() > 0:
		history_text.scroll_to_line(history_text.get_line_count() - 1)
	# 滚动条跟随（保持在底部时自动跟随；用户上翻时不打扰）
	if hp_scroll != null and hp_scroll.get_v_scroll_bar().value >= hp_scroll.get_v_scroll_bar().max_value - 80.0:
		hp_scroll.scroll_vertical = hp_scroll.get_v_scroll_bar().max_value
	# 折叠时提示有新记录（HistoryToggle 金色，展开后清除）
	if not history_panel.visible:
		history_toggle.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
		_history_unread += 1
		history_toggle.text = "▼ 展开记录(%d)" % (history_text.get_line_count() + _history_unread)
		# 新历史条目 Toast（仅间隔提示，防刷屏）
		if _history_unread <= 3 or _history_unread % 10 == 0:
			ToastManager.info("📜 历史新增 %d 条" % _history_unread)
	# 行数上限（防长局历史无限增长卡顿）
	if history_text.get_line_count() > 200:
		var excess2: int = history_text.get_line_count() - 150
		var keep2 := ""
		for i in range(excess2, history_text.get_line_count()):
			keep2 += history_text.get_line(i) + "\n"
		history_text.text = keep2

## 更新UI
func _update_ui() -> void:
	# 自动保存按钮状态（保存后短暂显示"已保存"）
	var save_btn := get_node_or_null("MainVBox/TopBar/TopHBox/SaveBtn")
	if save_btn is Button:
		if _last_autosave_time > 0.0 and int(Time.get_ticks_msec() / 1000.0 - _last_autosave_time) < 5:
			(save_btn as Button).text = "💾 已保存"
		else:
			(save_btn as Button).text = "💾 存档"
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
		# HP 颜色（低血红/中橙/健康绿）
		var hp_c := Color(0.49, 0.77, 0.49)
		if hp_ratio <= 0.3:
			hp_c = Color(0.88, 0.35, 0.31)
		elif hp_ratio <= 0.6:
			hp_c = Color(0.88, 0.63, 0.31)
		hp_label.add_theme_color_override("font_color", hp_c)
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
			# 金币颜色（充足金/紧张红）
			if gold < 20:
				econ_label.add_theme_color_override("font_color", Color(0.9, 0.45, 0.4))
			else:
				econ_label.remove_theme_color_override("font_color")
			item_label.text = "🎒 %d" % economy_engine.player_inventory.size()
		# 遗物 HUD 标记（持有遗物时）
		if int(economy_engine.player_inventory.get("rare_relic", 0)) > 0:
			item_label.text += " ✨"
		else:
			econ_label.text = "💰 0"
			item_label.text = "🎒 0"
		# 自动推进模式指示
		if auto_indicator != null:
			auto_indicator.visible = _auto_advance_mode
			# 开启时呼吸闪烁（仅启动一次）
			if _auto_advance_mode and not _auto_indicator_tween_started:
				_auto_indicator_tween_started = true
				auto_indicator.modulate.a = 1.0
				var atw := create_tween()
				atw.set_loops()
				atw.tween_property(auto_indicator, "modulate:a", 0.4, 0.6)
				atw.tween_property(auto_indicator, "modulate:a", 1.0, 0.6)
		# 任务追踪（当前进行中的任务）
		if script_data != null and script_data.quest_system != null and script_data.quest_system.quests.size() > 0:
			var active_q := ""
			var active_desc := ""
			for q in script_data.quest_system.quests:
				var qstatus: String = str(q.get("status", ""))
				if qstatus.is_empty() or qstatus == "active":
					active_q = str(q.get("name", q.get("id", "")))
					active_desc = str(q.get("description", ""))
					break
			if not active_q.is_empty():
				quest_label.text = "📋 %s" % active_q
				quest_label.visible = true
				quest_label.tooltip_text = "当前任务：%s" % active_q
				if not active_desc.is_empty():
					quest_label.tooltip_text += "\n%s" % active_desc
				# 任务标签颜色（进行中金色高亮）
				quest_label.add_theme_color_override("font_color", Color(0.9, 0.78, 0.5))
				# 任务切换提示（首次出现新任务时）
				if active_q != _last_quest_shown:
					_last_quest_shown = active_q
					ToastManager.info("📋 新任务：%s" % active_q)
			else:
				# 全部任务完成
				quest_label.text = "✅ 任务完成"
				quest_label.visible = true
				quest_label.tooltip_text = "所有任务已完成"
		# 当前事件链
		if world_state:
			var chain: String = str(world_state.get_variable("current_chain", ""))
			if not chain.is_empty():
				chain_label.text = "🔗 %s" % chain
				chain_label.visible = true
				# 链标签颜色（蓝色强调剧情线）
				chain_label.add_theme_color_override("font_color", Color(0.6, 0.75, 0.95))
				# tooltip：链事件进度
				var tip2 := "当前剧情线：%s" % chain
				if script_data != null and script_data.event_system != null:
					var chain_ev := 0
					var chain_done := 0
					for ev in script_data.event_system.events:
						if str(ev.get("chain_id", "")) == chain:
							chain_ev += 1
							var ev_done := false
							if event_engine != null:
								for te in event_engine.triggered_events:
									if str(te.get("event_id", "")) == str(ev.get("id", "")):
										ev_done = true
										break
							if ev_done:
								chain_done += 1
					if chain_ev > 0:
						tip2 += "\n进度 %d/%d" % [chain_done, chain_ev]
				chain_label.tooltip_text = tip2
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
			progress_label.tooltip_text = "已完成 %d/%d 个事件（主线 %d + 随机 %d）" % [
				p[0], p[1],
				(script_data.event_system.story_events.size() if script_data and script_data.event_system else 0),
				(script_data.event_system.random_events.size() if script_data and script_data.event_system and script_data.event_system.get("random_events") != null else 0)]			# 进度条颜色渐变（低=灰黄 中=金 高=绿）
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
				# 进度条金色脉冲动效（通关庆祝）
				if ThemeManager.animations_enabled:
					var tw_prog := create_tween()
					tw_prog.set_loops(3)
					tw_prog.tween_property(progress_label, "modulate:a", 0.4, 0.2)
					tw_prog.tween_property(progress_label, "modulate:a", 1.0, 0.2)
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
		# 新区域探索提示（首次进入）
		if not region_hud.is_empty() and region_hud != _last_region:
			_last_region = region_hud
			if not world_state.explored_regions.has(region_hud):
				world_state.explored_regions.append(region_hud)
				ToastManager.info("📍 进入新区域：%s" % region_hud)
		var region_prefix := " 📍%s" % region_hud if not region_hud.is_empty() else ""
		time_label.text = "🗓 " + world_state.get_time_display() + region_prefix
		# 时段图标（🌅/☀️/🌆/🌙）
		var period_icon := "🌙"
		match world_state.get_period_name():
			"清晨": period_icon = "🌅"
			"白天": period_icon = "☀️"
			"傍晚": period_icon = "🌆"
			"夜晚": period_icon = "🌙"
		time_label.text += " · %s %s" % [period_icon, world_state.get_period_name()]
		time_label.tooltip_text = "世界时间 · 当前区域 · %s" % world_state.get_period_name()
		# 时段配色（清晨暖金/白天亮蓝/傍晚橙/夜晚深蓝）
		match world_state.get_period_name():
			"清晨": time_label.add_theme_color_override("font_color", Color(0.95, 0.8, 0.5))
			"白天": time_label.add_theme_color_override("font_color", Color(0.75, 0.85, 0.95))
			"傍晚": time_label.add_theme_color_override("font_color", Color(0.95, 0.7, 0.45))
			"夜晚": time_label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.9))
		# 世界效果标记（进行中效果加 🌪）
		if not world_state.active_effects.is_empty():
			time_label.text += " 🌪"
			var fx_tip := "世界效果："
			for fxid2 in world_state.active_effects:
				fx_tip += "%s(%dh) " % [fxid2, int(world_state.active_effects[fxid2])]
			time_label.tooltip_text += "\n" + fx_tip
		# tooltip 补充探索进度
		if world_state and not world_state.explored_regions.is_empty():
			time_label.tooltip_text += "\n已探索 %d 个区域：%s" % [
				world_state.explored_regions.size(),
				"、".join(PackedStringArray(world_state.explored_regions))]

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
	# 主线/随机事件标记（chain_id → 📌，random → 🎲）
	var chain_mark := "📌 " if not str(event.get("chain_id", "")).is_empty() else ""
	if chain_mark.is_empty() and str(event.get("trigger_type", "")) == "random":
		chain_mark = "🎲 "
	_set_main_text("[b]%s【%s】[/b]\n\n%s" % [chain_mark, event_name, desc])
	# 历史记录（避免连续重复事件刷屏）
	var hist_line := "事件%s: %s" % [chain_mark, event_name]
	if not history_text.text.ends_with(hist_line):
		_add_history(hist_line)
	# 事件标题 tooltip（描述悬停查看；随机事件含概率）
	var tip_extra := ""
	if str(event.get("trigger_type", "")) == "random" and event.has("probability"):
		tip_extra = "\n触发概率：%.0f%%" % (float(event["probability"]) * 100.0)
	main_text.tooltip_text = "%s\n%s%s" % [event_name, desc, tip_extra]
	# tooltip 闪烁提示（新事件可悬停查看）
	if ThemeManager.animations_enabled:
		main_text.modulate = Color(1, 1, 1, 0.9)
		var tip_tw := create_tween()
		tip_tw.tween_property(main_text, "modulate", Color.WHITE, 0.4)
	# 事件触发计数（本次游玩）
	_event_trigger_count += 1
	# 事件链完成庆祝（当前链全部触发）
	var cur_chain: String = str(event.get("chain_id", "")) if world_state == null else str(world_state.get_variable("current_chain", ""))
	if not cur_chain.is_empty() and script_data != null and script_data.event_system != null:
		var chain_total := 0
		var chain_done := 0
		for ev2 in script_data.event_system.events:
			if str(ev2.get("chain_id", "")) == cur_chain:
				chain_total += 1
				if event_engine != null:
					for te2 in event_engine.triggered_events:
						if str(te2.get("event_id", "")) == str(ev2.get("id", "")):
							chain_done += 1
							break
		if chain_total > 0 and chain_done >= chain_total:
			ToastManager.success("🎊 剧情线「%s」全部完成！" % cur_chain)
			_add_history("🎊 剧情线「%s」完成" % cur_chain)
	# 事件到达动效（屏幕轻微震动，可关闭）
	if ThemeManager.animations_enabled:
		main_text.scale = Vector2.ONE
		main_text.pivot_offset = main_text.size / 2.0
		var etw := create_tween()
		etw.tween_property(main_text, "scale", Vector2(1.01, 1.01), 0.08)
		etw.tween_property(main_text, "scale", Vector2.ONE, 0.12)

func _on_choices_presented(choices: Array) -> void:
	_clear_choices()
	# 选项副作用预览（有后果的显示 ▶）
	for i in choices.size():
		var choice: Dictionary = choices[i]
		# 复用统一选择按钮（序号/动画/键盘）
		var btn := Button.new()
		var btn_text: String = "%d. %s" % [i + 1, choice.get("text", "选择")]
		var cons: Array = choice.get("consequences", [])
		if not cons.is_empty():
			btn_text += " ▶"
		btn.text = btn_text
		# 后果 tooltip 预览（悬停查看效果）
		if not cons.is_empty():
			var cons_txt := "选择后将触发 %d 项后果：\n" % cons.size()
			for c2 in cons:
				if c2 is Dictionary:
					cons_txt += "• %s：%s\n" % [str(c2.get("target", "?")), str(c2.get("effect", "?"))]
			btn.tooltip_text = cons_txt
			# 有后果按钮金色边框高亮（提示有后续影响）
			var border := StyleBoxFlat.new()
			border.bg_color = Color(0.96, 0.925, 0.843, 1.0)
			border.border_color = Color(0.85, 0.65, 0.3, 0.8)
			border.set_border_width_all(2)
			border.set_corner_radius_all(6)
			border.set_content_margin_all(8)
			btn.add_theme_stylebox_override("normal", border)
		btn.custom_minimum_size = Vector2(0, 44)
		btn.add_theme_font_size_override("font_size", 15)
		btn.focus_mode = Control.FOCUS_ALL
		if choice_container.get_child_count() >= 4:
			btn.custom_minimum_size = Vector2(0, 36)
		if i < 9:
			btn.tooltip_text = "快捷键 %d" % (i + 1)
		var choice_id: String = choice.get("id", "")
		btn.pressed.connect(func():
			if ThemeManager.animations_enabled:
				btn.modulate = Color(0.6, 0.6, 0.6)
				btn.scale = Vector2(0.98, 0.98)
			_on_choice_selected(choice_id))
		choice_container.add_child(btn)
		# 逐个延迟浮现
		if ThemeManager.animations_enabled:
			btn.modulate.a = 0.0
			btn.scale = Vector2(0.96, 0.96)
			var t2 := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			t2.tween_interval(i * 0.06)
			t2.set_parallel(true)
			t2.tween_property(btn, "modulate:a", 1.0, 0.2)
			t2.tween_property(btn, "scale", Vector2.ONE, 0.2)
		# 进入动画
		if ThemeManager.animations_enabled:
			btn.modulate.a = 0.0
			var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			tween.tween_property(btn, "modulate:a", 1.0, 0.2).set_delay(i * 0.08)

func _on_choice_selected(choice_id: String) -> void:
	if event_engine == null:
		return
	# 记录选择文本（查当前选项）
	var choice_text := choice_id
	if event_engine.current_choices:
		for c in event_engine.current_choices:
			if str(c.get("id", "")) == choice_id:
				choice_text = str(c.get("text", choice_id))
				break
	var consequences: Array = event_engine.make_choice(choice_id)
	# 有后果选项 Toast 提示（后果即将生效）
	if not consequences.is_empty():
		ToastManager.info("⚠ 此选择将带来 %d 项后果" % consequences.size())
	_add_history("选择: %s" % choice_text)

	var consequence_text := ""
	for c in consequences:
		var target: String = c.get("target", "")
		var effect: String = c.get("effect", "")
		# 后果历史记录（含效果描述）
		if not effect.is_empty():
			_add_history("后果: %s（%s）" % [target, effect])
			_spawn_damage_popup(consequences.size(), false, true)  # 后果数量金色飘字
		# 后果图标（目标映射）
		var cicon := ""
		match target:
			"player": cicon = "👤 "
			"world": cicon = "🌍 "
			"faction": cicon = "🏴 "
			"economy": cicon = "💰 "
		if cicon != "":
			consequence_text += "→ %s%s: %s\n" % [cicon, target, effect]
		else:
			consequence_text += "→ %s: %s\n" % [target, effect]
		_apply_consequence(c)

	if consequence_text.is_empty():
		consequence_text = "你的选择已经改变了世界的走向..."
	else:
		consequence_text = "[color=#c9a06a]%s[/color]" % consequence_text
	_set_main_text("[i]你的选择产生了后果...[/i]\n\n%s\n\n[color=#8a8278]（后果已生效，继续前行）[/color]" % consequence_text)
	# 后果关键节点自动存档（防意外丢失）
	SaveManager.autosave()
	_clear_choices()
	_add_choice_button("继续", "_on_continue_pressed")

func _on_continue_pressed() -> void:
	_clear_choices()
	_sync_save_state()
	# 防连点：忙碌时忽略（避免连点跳过多个事件）
	if _advancing:
		return
	_advance_to_next_event()

## 自动模式推进（打字机完成后自动继续）
func _auto_continue() -> void:
	if _advancing or not _typewriter_done:
		return
	# 有选择按钮时暂停自动（等待玩家决策）；仅"继续探索"类自动通过
	if choice_container.get_child_count() > 0:
		var first: Control = choice_container.get_child(0)
		if first is Button and str((first as Button).text).contains("继续探索"):
			(first as Button).pressed.emit()
		return
	if _auto_advance_mode:
		_on_continue_pressed()

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
					ToastManager.success("🪙 获得 50 金币")
		"world":
			if world_state:
				world_state.set_variable(effect, true)
				ToastManager.info("🌍 世界标记：%s" % effect)
				_add_history("🌍 世界标记：%s" % effect)
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
				ToastManager.info("🏴 势力关系变化：%s %+.0f" % [target, delta])
				_add_history("🏴 势力关系：%s %+.0f" % [target, delta])

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
	# 面板已打开则聚焦而非重复创建
	if tavern_panel.visible:
		tavern_input.grab_focus()
		menu_panel.visible = false
		return
	tavern_panel.visible = true
	menu_panel.visible = false
	# 时段氛围提示（夜晚酒馆）
	if world_state != null and world_state.get_period_name() == "夜晚":
		ToastManager.info("🌙 夜色中，酒馆灯火通明…")
	# 时段氛围（白天/傍晚轻提示）
	elif world_state != null:
		match world_state.get_period_name():
			"清晨": ToastManager.info("🌅 清晨的酒馆只有老板娘在擦杯子…")
			"傍晚": ToastManager.info("🌆 傍晚的旅人陆续进店…")
	# 打开后清除新消息高亮
	var tb := get_node_or_null("MainVBox/TopBar/TopHBox/TavernBtn")
	if tb is Button:
		(tb as Button).remove_theme_color_override("font_color")
		(tb as Button).text = "🏮 酒馆"
	_tavern_unread = 0
	tavern_char_select.clear()
	for i in TAVERN_CHARS.size():
		tavern_char_select.add_item("%s %s" % [TAVERN_CHARS[i].get("icon", ""), TAVERN_CHARS[i]["name"]], i)
	tavern_char_select.item_selected.connect(_on_tavern_char_selected)
	_enter_tavern_char(0)
	# 输入 placeholder 按角色
	tavern_input.placeholder_text = "对%s说话…" % str(TAVERN_CHARS[0].get("name", "角色"))
	tavern_input.grab_focus()
	# 酒馆内帮助按钮（H 键同效）
	var tavern_help_btn := get_node_or_null("TavernPanel/TavernVBox/TavernHeader") as HBoxContainer
	if tavern_help_btn != null and not tavern_help_btn.has_node("TavernHelpBtn"):
		var thb := Button.new()
		thb.name = "TavernHelpBtn"
		thb.text = "❓"
		thb.flat = true
		thb.tooltip_text = "操作帮助（H）"
		thb.pressed.connect(_on_menu_help_pressed)
		tavern_help_btn.add_child(thb)
	# 酒馆说明条（好感度/话题规则）
	var tavern_note := get_node_or_null("TavernPanel/TavernVBox") as VBoxContainer
	if tavern_note != null and not tavern_note.has_node("TavernNote"):
		var note := Label.new()
		note.name = "TavernNote"
		note.text = "多聊天提升好感度 → 亲密后解锁往事与礼物"
		note.add_theme_color_override("font_color", Color(0.6, 0.55, 0.48))
		note.add_theme_font_size_override("font_size", 11)
		tavern_note.add_child(note)
	# 彩蛋话题提示（酒馆顶栏）
	var egg_hint := get_node_or_null("TavernPanel/TavernVBox/TavernHeader") as HBoxContainer
	if egg_hint != null:
		egg_hint.tooltip_text = "试试聊聊：遗物 / 命运 / 酒 / 世界"
	# 彩蛋话题快捷按钮（自动发送）
	var egg_row := get_node_or_null("TavernPanel/TavernVBox") as VBoxContainer
	if egg_row != null and not egg_row.has_node("EggRow"):
		var er := HBoxContainer.new()
		er.name = "EggRow"
		for topic in ["遗物", "命运", "酒", "世界"]:
			var eb := Button.new()
			eb.text = topic
			eb.flat = true
			eb.add_theme_font_size_override("font_size", 11)
			eb.pressed.connect(_send_egg_topic.bind(topic))
			er.add_child(eb)
		# 随机话题按钮
		var rand_eb := Button.new()
		rand_eb.text = "🎲 随机"
		rand_eb.flat = true
		rand_eb.add_theme_font_size_override("font_size", 11)
		rand_eb.pressed.connect(func():
			var topics := ["遗物", "命运", "酒", "世界", "旅途", "天气"]
			_send_egg_topic(topics[randi() % topics.size()]))
		er.add_child(rand_eb)
		egg_row.add_child(er)
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
	# 清空确认（防误删对话记录）
	var confirm_clr := ConfirmationDialog.new()
	confirm_clr.dialog_text = "确定清空 %s 的对话历史？此操作不可恢复。" % char.get("name", "角色")
	confirm_clr.ok_button_text = "清空"
	confirm_clr.confirmed.connect(func():
		# 好感度保留（清空对话不影响情谊）
		var mood_keep: int = _tavern_moods.get(str(char.get("id", "")), 0)
		TavernManager.clear_history()
		tavern_msgs.clear()
		_tavern_append("assistant", char.get("greeting", "你好，旅者。"))
		if mood_keep > 0:
			_tavern_moods[str(char.get("id", ""))] = mood_keep
		# 保存好感度
		if GameManager.user_data != null:
			GameManager.user_data.tavern_moods = _tavern_moods.duplicate()
			GameManager.user_data.save_user_data()
		ToastManager.info("已清空 %s 的对话历史（好感度保留）" % char.get("name", "角色")))
	add_child(confirm_clr)
	confirm_clr.popup_centered()

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
	fd.current_file = "tavern_%s.txt" % str(char.get("id", "chat"))
	# 导出成功提示（FileDialog 回调已有，此处补充当前角色名）
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.current_path = "酒馆对话_%s.txt" % char.get("name", "角色")
	fd.min_size = Vector2i(600, 400)
	add_child(fd)
	fd.file_selected.connect(func(path: String):
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f:
			f.store_string("%s 的对话记录（%s 剧本）\n%s\n" % [char.get("name", "角色"), script_data.name if script_data else "", "=".repeat(24)])
			f.store_string("导出时间：%s\n\n" % Time.get_datetime_string_from_system())
			# 对话统计（条数）
			f.store_string("共 %d 条消息\n\n" % history.size())
			# 好感度信息（导出时记录）
			var mood_exp: int = _tavern_moods.get(str(char.get("id", "")), 0)
			var mood_name_exp := "普通"
			match mood_exp:
				1: mood_name_exp = "友好 🙂"
				2: mood_name_exp = "亲密 😊"
			f.store_string("当前好感度：%s\n" % mood_name_exp)
			# 角色名映射（user/assistant → 玩家/角色名）
			for msg in history:
				var role_txt: String = str(msg.get("role", "?"))
				if role_txt == "assistant":
					role_txt = str(char.get("name", "角色"))
				elif role_txt == "user":
					role_txt = "玩家"
				# 消息时间戳（如有）
				var ts_line := ""
				if msg.has("time"):
					ts_line = "[%s] " % str(msg.get("time", ""))
				f.store_string("%s[%s] %s\n" % [ts_line, role_txt, msg.get("content", "")])
			f.close()
			ToastManager.success("对话已导出")
		else:
			ToastManager.warning("导出失败")
		fd.queue_free())
	fd.popup_centered()

## 导出最近一场战斗日志
func _on_menu_export_battle_log() -> void:
	if battle_log.text.strip_edges().is_empty():
		ToastManager.info("暂无战斗日志（先经历一场战斗）")
		return
	var out_path := "user://battle_log_%s.txt" % Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f:
		f.store_string(battle_log.text)
		f.close()
		ToastManager.success("战斗日志已导出：%s" % ProjectSettings.globalize_path(out_path))

func _on_tavern_close_pressed() -> void:
	TavernManager.end_dialog()
	# 告别语（仅当有对话时显示一次）
	if tavern_msgs.get_line_count() > 1:
		var cur_char: Dictionary = TAVERN_CHARS[tavern_char_index] if tavern_char_index >= 0 and tavern_char_index < TAVERN_CHARS.size() else {}
		var farewell := "（%s目送你离开）下次再来呀。" % str(cur_char.get("name", "老板娘"))
		ToastManager.info(farewell)
	# 关闭时保存对话历史与好感度
	TavernManager.save_history()
	if GameManager.user_data != null:
		GameManager.user_data.tavern_moods = _tavern_moods.duplicate()
		GameManager.user_data.save_user_data()
	tavern_panel.visible = false
	# 焦点还原（键盘可继续操作）
	main_text.grab_focus()

func _on_tavern_char_selected(index: int) -> void:
	_enter_tavern_char(index)
	# 输入 placeholder 随角色切换更新
	if index >= 0 and index < TAVERN_CHARS.size():
		tavern_input.placeholder_text = "对%s说话…" % str(TAVERN_CHARS[index].get("name", "角色"))
	# 切换角色提示（显示当前角色好感）
	var cname: String = str(TAVERN_CHARS[index].get("name", "角色")) if index >= 0 and index < TAVERN_CHARS.size() else "角色"
	var mood_val: int = _tavern_moods.get(str(TAVERN_CHARS[index].get("id", "")) if index >= 0 and index < TAVERN_CHARS.size() else "", 0)
	var mood_name := "普通"
	match mood_val:
		1: mood_name = "友好 🙂"
		2: mood_name = "亲密 😊"
	ToastManager.info("切换至：%s（好感：%s）" % [cname, mood_name])
	# 好感度满时特殊对话提示
	if mood_val >= 2:
		ToastManager.info("💝 与 %s 的对话将获得更深的情谊" % cname)
	# 好感度满解锁背景故事（仅一次）
	if mood_val >= 2 and index >= 0 and index < TAVERN_CHARS.size() and TAVERN_CHARS[index].has("background") \
			and not _heard_backgrounds.has(str(TAVERN_CHARS[index].get("id", ""))):
		_heard_backgrounds[str(TAVERN_CHARS[index].get("id", ""))] = true
		_tavern_append("assistant", "（她压低声音，说起往事）\n📖 %s" % TAVERN_CHARS[index]["background"])

func _enter_tavern_char(index: int) -> void:
	tavern_char_index = index
	tavern_msgs.clear()
	# 右键复制菜单（选中文本可复制）
	tavern_msgs.context_menu_enabled = true
	var char: Dictionary = TAVERN_CHARS[index]
	TavernManager.start_dialog(char)
	# 输入框占位提示当前角色
	tavern_input.placeholder_text = "对%s说话…（/h 历史 · /c 清空）" % char.get("name", "角色")
	var tavern_title := get_node_or_null("TavernPanel/TavernVBox") as VBoxContainer
	if tavern_title != null and tavern_title.has_node("TavernTitle"):
		(tavern_title.get_node("TavernTitle") as Label).text = "🏮 酒馆 · %s" % char.get("name", "角色")
	# 角色介绍按钮（tooltip 简介）
	var char_desc: String = str(char.get("description", ""))
	if not char_desc.is_empty():
		ToastManager.info("📖 %s：%s" % [char.get("name", "角色"), char_desc])
	# 输入框占位提示当前角色
	tavern_input.placeholder_text = "对%s说话…（/h 历史 · /c 清空）" % char.get("name", "角色")
	# 话题快捷按钮（点击即发送；按角色定制）
	var topics_bar := get_node_or_null("%TavernTopics")
	if topics_bar is HBoxContainer:
		var bar := topics_bar as HBoxContainer
		for c in bar.get_children():
			c.queue_free()
		var topics: Array = ["🗡 剑术", "🏺 传说", "💰 物价", "🗺 地形", "⚔ 战斗"]
		if str(char.get("id", "")) == "old_scholar":
			topics = ["📜 古籍", "🏛 遗迹", "🧙 历史", "🔤 文字", "🗺 地形"]
		var topic_tips := {
			"🗡 剑术": "询问剑术与战斗心得",
			"🏺 传说": "打听古代传说与遗迹",
			"💰 物价": "了解当前物价行情",
			"🗺 地形": "询问周边地形与路线",
			"⚔ 战斗": "请教战斗技巧与敌人弱点",
			"📜 古籍": "请教古籍中的知识",
			"🏛 遗迹": "询问遗迹的线索",
			"🧙 历史": "谈论古代历史",
			"🔤 文字": "请教古文字解读",
		}
		for tp in topics:
			var tbtn := Button.new()
			tbtn.text = tp
			tbtn.flat = true
			tbtn.add_theme_font_size_override("font_size", 12)
			tbtn.tooltip_text = topic_tips.get(tp, "")
			tbtn.pressed.connect(func():
				tavern_input.text = tp
				_on_tavern_send_pressed())
			bar.add_child(tbtn)
	# 首次进入该角色：显示一句问候（夜晚特殊台词）
	if TavernManager.dialog_history.is_empty():
		var is_night: bool = world_state != null and world_state.get_period_name() == "夜晚"
		var greeting := ""
		if is_night and index == 0:
			greeting = "（艾琳打了个哈欠）这么晚还来？也罢，坐吧，夜里的小道消息往往更值钱…"
		elif is_night:
			greeting = "（费恩合上书本）深夜造访，想必是有要紧事？"
		else:
			greeting = "（%s%s抬头看向你）欢迎光临%s，旅行者。有什么想问的？" % [
				char.get("icon", "🗨"), char.get("name", "角色"), char.get("locale", "小店")]
		TavernManager.dialog_history.append({"role": "assistant", "content": greeting})
		TavernManager.save_history()
		_tavern_append("assistant", greeting)
	# 角色简介提示（性格/背景）
	ToastManager.info("📖 %s：%s（%s）" % [
		char.get("name", "角色"),
		char.get("personality", ""),
		char.get("background", "")])
	# 话题引导（提示可聊内容）
	var topics: Array = ["🗡 剑术", "🏺 传说", "💰 物价", "🗺 地形", "⚔ 战斗"]
	ToastManager.info("可聊：%s" % "、".join(PackedStringArray(topics)))
	# 空输入禁用发送按钮
	var sb := get_node_or_null("TavernPanel/TavernVBox/TavernInputRow/TavernSend")
	if sb is Button:
		(sb as Button).disabled = true
		tavern_input.text_changed.connect(func(t: String):
			(sb as Button).disabled = t.strip_edges().is_empty()
			# 字数提示（超 200 字警告）
			if t.length() > 200:
				ToastManager.warning("消息过长（%d/200 字），建议精简" % t.length()))
	# 清空输入按钮（Esc 在输入框内清空文字而非关闭面板）
	var clear_btn := get_node_or_null("TavernPanel/TavernVBox/TavernInputRow/ClearTavernInput") as Button
	if clear_btn == null:
		clear_btn = Button.new()
		clear_btn.name = "ClearTavernInput"
		clear_btn.text = "✕"
		clear_btn.flat = true
		clear_btn.tooltip_text = "清空输入"
		get_node("TavernPanel/TavernVBox/TavernInputRow").add_child(clear_btn)
	clear_btn.pressed.connect(func():
		tavern_input.text = ""
		tavern_input.grab_focus())
	# 回车直接发送
	if not tavern_input.text_submitted.is_connected(_on_tavern_send_pressed):
		tavern_input.text_submitted.connect(_on_tavern_send_pressed)
	# ↑ 键调出上一条输入（输入历史）
	var hist_idx := -1
	tavern_input.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventKey and ev.pressed and not ev.echo:
			if ev.keycode == KEY_UP and not _tavern_input_history.is_empty():
				hist_idx = mini(hist_idx + 1, _tavern_input_history.size() - 1)
				tavern_input.text = _tavern_input_history[_tavern_input_history.size() - 1 - hist_idx]
				tavern_input.caret_column = tavern_input.text.length()
				tavern_input.accept_event()
			elif ev.keycode == KEY_DOWN and hist_idx > -1:
				hist_idx = maxi(hist_idx - 1, -1)
				tavern_input.text = _tavern_input_history[_tavern_input_history.size() - 1 - hist_idx] if hist_idx >= 0 else ""
				tavern_input.accept_event())
	# 恢复历史对话
	var history: Array = TavernManager.load_history(char["id"])
	if not history.is_empty():
		for msg in history:
			_tavern_append(msg.get("role", ""), msg.get("content", ""))
	else:
		# 按好感度选择问候语
		var mood_level: int = _tavern_moods.get(str(char.get("id", "")), 0)
		var greet_txt: String = str(char.get("greeting", "你好，旅者。"))
		match mood_level:
			2: greet_txt = "你来了！%s（语气亲昵）" % greet_txt
			1: greet_txt = "又见面了，%s" % greet_txt
		_tavern_append("assistant", greet_txt)

func _on_tavern_send_pressed() -> void:
	var text := tavern_input.text.strip_edges()
	if text.is_empty():
		# 空消息提示
		tavern_input.placeholder_text = "输入点什么再发送吧…"
		ToastManager.info("先输入一句话再发送")
		return
	tavern_input.text = ""
	# 发送后恢复发送按钮可用态
	var send_btn := get_node_or_null("TavernPanel/TavernVBox/TavernInputRow/TavernSend") as Button
	if send_btn != null:
		send_btn.disabled = true
	# 记录输入历史（去重置顶，保留 10 条）
	_tavern_input_history.erase(text)
	_tavern_input_history.push_front(text)
	if _tavern_input_history.size() > 10:
		_tavern_input_history.resize(10)
	# 关键词彩蛋（特定话题特殊回应）
	var easter_egg := ""
	if text.contains("遗物") or text.contains("宝物"):
		easter_egg = "（神秘地压低声音）听说上古遗物藏在旧矿坑深处…"
	elif text.contains("命运") or text.contains("预言"):
		easter_egg = "（若有所思）命运这种东西，总是喜欢和人开玩笑。"
	elif text.contains("酒"):
		easter_egg = "（递过一杯）尝尝这个，本店招牌，喝了能暖一整天。"
	elif text.contains("世界"):
		easter_egg = "（望向窗外）这个世界，比你想的辽阔得多。"
	elif text.contains("旅途") or text.contains("旅行"):
		easter_egg = "（微笑）旅人总在路上，故事也跟着走。"
	elif text.contains("天气") or text.contains("雨"):
		easter_egg = "（看了看窗外）雨天的旅店最热闹，大家都进来躲雨。"
	if not easter_egg.is_empty():
		_tavern_append("assistant", easter_egg)
		TavernManager.add_message("assistant", easter_egg)
		_egg_count += 1
		if _egg_count == 5:
			ToastManager.success("🗝 发现 5 段秘闻！酒馆话事人成就")
		return
	# 斜杠命令：/h 历史 /c 清空 /help 帮助
	if text.begins_with("/"):
		match text:
			"/h":
				var lines: Array[String] = []
				for m in TavernManager.dialog_history:
					lines.append(_tavern_history_line(m))
				if lines.is_empty():
					_tavern_append("assistant", "（翻看旧账）……还没有任何对话记录呢。")
				else:
					_tavern_append("assistant", "（翻看旧账）这是之前的对话记录——\n%s" % "\n".join(lines))
				return
			"/c":
				TavernManager.dialog_history.clear()
				TavernManager.save_history()
				tavern_msgs.clear()
				_tavern_append("assistant", "（记录已清空）")
				return
			"/help":
				_tavern_append("assistant", "可用指令：\n/h 查看对话历史\n/c 清空对话\n/mood 查看当前好感\n/help 显示本帮助\n\n（试试聊聊「遗物 / 命运 / 酒 / 世界」有惊喜）")
				return
			"/mood":
				var mood_lv: int = _tavern_moods.get(str(TAVERN_CHARS[tavern_char_index].get("id", "")) if tavern_char_index >= 0 and tavern_char_index < TAVERN_CHARS.size() else "", 0)
				var mood_name2 := "普通"
				match mood_lv:
					1: mood_name2 = "友好 🙂"
					2: mood_name2 = "亲密 😊"
				_tavern_append("assistant", "（微微一笑）我们之间的好感是「%s」呢。" % mood_name2)
				return
			_:
				_tavern_append("assistant", "（疑惑）你说的我听不懂…试试 /h 或 /c 或 /help")
				return
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
	# 历史长度上限（保留最近 200 条，防膨胀）
	if TavernManager.dialog_history.size() > 200:
		TavernManager.dialog_history = TavernManager.dialog_history.slice(-200)
	TavernManager.save_history()
	# 重建最后一条为实际回复
	var rt: RichTextLabel = tavern_msgs
	var all_text := rt.text
	var last_idx := all_text.rfind("\n\n")
	if last_idx >= 0:
		rt.text = all_text.substr(0, last_idx) + "\n\n"
	_tavern_append("assistant", reply)
	# 角色心情升温（每 3 次对话 +1 档，最多 😊）
	# 酒馆角色心情（对话升温 🙂/😊）
	var char_id2: String = str(TavernManager.current_character.get("id", "innkeeper")) if TavernManager.current_character != null and not TavernManager.current_character.is_empty() else "innkeeper"
	var mood: int = _tavern_moods.get(char_id2, 0)
	_tavern_moods[char_id2] = mini(mood + 1, 2)
	# 好感度已满提示（仅首次）
	if mood >= 2 and _tavern_mood_full_toast == 0:
		_tavern_mood_full_toast = 1
		ToastManager.info("%s 与你的羁绊已至深处" % str(TavernManager.current_character.get("name", "角色")))
	# 好感档位提升提示
	if _tavern_moods[char_id2] > mood:
		if _tavern_moods[char_id2] == 1:
			ToastManager.success("💛 %s 对你更友善了" % TavernManager.current_character.get("name", "角色"))
		else:
			ToastManager.success("💖 %s 与你亲密无间！" % TavernManager.current_character.get("name", "角色"))
			# 亲密后赠送礼物（随机：金币/药水/遗物）
			if economy_engine != null:
				var gift_roll := randf()
				if gift_roll < 0.15:
					economy_engine.player_inventory["rare_relic"] = int(economy_engine.player_inventory.get("rare_relic", 0)) + 1
					ToastManager.success("🎁 %s 送给你一枚✨遗物！" % TavernManager.current_character.get("name", "角色"))
					_add_history("🎁 %s 赠送遗物" % TavernManager.current_character.get("name", "角色"))
				elif gift_roll < 0.5:
					economy_engine.player_inventory["health_potion"] = int(economy_engine.player_inventory.get("health_potion", 0)) + 2
					ToastManager.success("🎁 %s 送你 2 瓶药水" % TavernManager.current_character.get("name", "角色"))
					_add_history("🎁 %s 赠送 2 瓶药水" % TavernManager.current_character.get("name", "角色"))
				else:
					economy_engine.add_currency("gold", 20)
					ToastManager.success("🎁 %s 送你 20 金币" % TavernManager.current_character.get("name", "角色"))
					_add_history("🎁 %s 好感亲密，赠送 20 金币" % TavernManager.current_character.get("name", "角色"))
				_sync_save_state()
	_tavern_update_char_label()
	# 持久化好感度
	GameManager.user_data.tavern_moods = _tavern_moods.duplicate()
	GameManager.user_data.save_user_data()
	# 若酒馆面板未打开：顶栏按钮金色高亮提示新消息
	if not tavern_panel.visible:
		var tb := get_node_or_null("MainVBox/TopBar/TopHBox/TavernBtn")
		if tb is Button:
			(tb as Button).add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
			_tavern_unread += 1
			(tb as Button).text = "🏮 酒馆(%d)" % _tavern_unread
			# 新消息 Toast（角色对玩家说话）
			ToastManager.info("🏮 酒馆有 %d 条新消息" % _tavern_unread)

## 酒馆历史行（/h 命令用）
func _tavern_history_line(m: Variant) -> String:
	var role: String = str((m as Dictionary).get("role", "?")) if m is Dictionary else "?"
	var content: String = str((m as Dictionary).get("content", "")) if m is Dictionary else ""
	if content.length() > 40:
		content = content.substr(0, 40) + "…"
	return "%s: %s" % [role, content]

func _tavern_append(role: String, content: String) -> void:
	# 消息长度限制（超长截断防卡顿）
	if content.length() > 400:
		content = content.substr(0, 397) + "…"
	var ts := Time.get_time_string_from_system().substr(0, 5)
	var speaker := "你"
	var speaker_color := "#7cc47c"
	if role == "assistant":
		speaker = "艾琳" if TavernManager.current_character.get("id", "") == "innkeeper" else "费恩"
		speaker_color = "#c9a06a"
	var prefix := "[color=#8a8278]%s[/color] [color=%s][b]%s[/b][/color] " % [ts, speaker_color, speaker]
	# 消息气泡背景色（玩家浅绿 / 角色浅棕）
	var bubble := "[bgcolor=#2a2e24]" if role == "user" else "[bgcolor=#2e2a22]"
	tavern_msgs.append_text(bubble + prefix + content.replace("[", "［").replace("]", "］") + "[/bgcolor]\n\n")
	# 历史条数限制（超 120 条清首条，防长会话卡顿）
	if tavern_msgs.get_line_count() > 600:
		tavern_msgs.text = tavern_msgs.text.substr(tavern_msgs.text.find("\n") + 1)
	# 自动滚动到底部（新消息可见）
	tavern_msgs.scroll_to_line(tavern_msgs.get_line_count())

func _tavern_mock_reply(text: String) -> String:
	var char_name: String = TavernManager.current_character.get("name", "角色")
	var char_id: String = str(TavernManager.current_character.get("id", ""))
	# 角色专属台词
	if char_id == "old_scholar" and ("书" in text or "古籍" in text or "遗迹" in text):
		return "（费恩推了推眼镜）说到古籍，我书房里有一卷残页，讲的是失落的铸城之术…"
	if char_id == "old_scholar" and ("历史" in text or "时代" in text):
		return "（费恩捋着胡须）这座城的历史比你以为的古老得多——传说它建在一座更古老的都城废墟之上。"
	if char_id == "old_scholar" and ("文字" in text or "铭文" in text):
		return "（费恩摊开一张拓片）你看这行铭文，是失传的旧体文字，大意是『城门之下，另有城门』…"
	if char_id == "innkeeper" and ("镇" in text or "消息" in text):
		return "（艾琳压低声音）镇上最近来了些奇怪的人，总在打听城北的古井…"
	# 关键词针对性回复
	if "剑" in text or "武" in text:
		return "（%s眼中一亮）说到剑术，我年轻时也练过两手…不过现在更擅长泡茶。" % char_name
	if "传说" in text or "古籍" in text or "遗迹" in text:
		return "（%s压低声音）传说东边荒原下有座古城，每逢月圆会有灯火浮现——真假难说。" % char_name
	if "价" in text or "钱" in text or "金" in text:
		return "（%s掰着手指）最近粮价涨了三成，铁器倒是便宜。想倒卖得趁早。" % char_name
	if "地形" in text or "地图" in text or "路" in text:
		return "（%s指向窗外）北边山路最近不太平，商队都改走西边河谷了。" % char_name
	if "战斗" in text or "敌" in text:
		return "（%s提醒道）荒野的狼群越来越凶，出门记得带够药草。" % char_name
	if "酒" in text or "吃" in text:
		return "（%s端上一杯热茶）本店的招牌是蜜酿果酒，改天请你尝尝。" % char_name
	if "你好" in text or "嗨" in text:
		return "（%s点头致意）你好，旅行者。需要什么尽管开口。" % char_name
	if "谢谢" in text or "多谢" in text:
		return "（%s摆摆手）客气什么，都是街坊邻居。" % char_name
	# 心情影响回复热情度
	var mood: int = _tavern_moods.get(str(TavernManager.current_character.get("id", "")), 0)
	var warm_prefix := ""
	match mood:
		1: warm_prefix = "（%s语气温和了几分）" % char_name
		2: warm_prefix = "（%s笑着凑近了些）" % char_name
	var replies := [
		"（%s若有所思地点点头）嗯，你说得对，继续说下去。" % char_name,
		"（%s压低声音）这事说来话长…改天细聊。" % char_name,
		"（%s微微一笑）有意思。不过这个话题，现在还不是时候。" % char_name,
		"（%s认真打量你）你这话，倒是提醒了我一件事。" % char_name,
	]
	var reply: String = warm_prefix + str(replies[abs(text.hash()) % replies.size()])
	# 30% 概率追加世界观线索（当前区域/任务相关）
	if randf() < 0.3 and world_state != null:
		var region_hint: String = str(world_state.get_variable("current_region", ""))
		var clues := [
			"对了，听说%s那边的旧矿洞最近有异响。" % region_hint if not region_hint.is_empty() else "对了，城西集市明天有集会，或许有你要找的东西。",
			"（压低声音）我在%s见过穿黑斗篷的人，鬼鬼祟祟的。" % region_hint if not region_hint.is_empty() else "（压低声音）城北钟楼半夜会自己响，没人知道为什么。",
		]
		reply += "\n[color=#9ad0e0]（线索）[/color]" + clues[randi() % clues.size()]
	return reply
func _on_combat_started(enemies: Array) -> void:
	battle_panel.visible = true
	# 战斗开场提示（敌人数/类型）
	var names: Array[String] = []
	for e in enemies:
		names.append(str(e.get("name", "敌人")))
	ToastManager.warning("⚔ 遭遇敌人：%s" % "、".join(names))
	# 战斗开场日志
	_battle_log_line("⚔ 遭遇敌人：%s（%d 个）" % ["、".join(names), enemies.size()], "#e6c84c")
	# 战斗开始时关闭其他浮层（菜单/酒馆/面板）
	menu_panel.visible = false
	if tavern_panel != null:
		tavern_panel.visible = false
	var any_dialog := get_node_or_null("CharStatusDialog")
	if any_dialog != null:
		any_dialog.queue_free()
	# 战斗背景色（主区轻微暗红提示战斗氛围）
	main_text.add_theme_color_override("font_color", Color(0.92, 0.86, 0.8))
	# 新战斗清空上一场日志
	battle_log.clear()
	# 右键复制菜单（选中文本可复制）
	battle_log.context_menu_enabled = true
	# 清空日志按钮
	battle_log_clear.pressed.connect(func():
		battle_log.clear()
		_battle_log_line("日志已清空", "#8a8278"))
	_refresh_battle_ui()
	_battle_log_line("战斗开始！遭遇 %d 个敌人" % enemies.size(), "#c9a06a")
	# 敌人威胁度提示（攻击力高的敌人标⚠）
	for e2 in enemies:
		if int(e2.get("atk", 0)) >= int(combat_engine.player_combat_stats.get("atk", 0) if combat_engine != null else 20):
			_battle_log_line("⚠ %s 攻击力高于你，谨慎应对！" % str(e2.get("name", "敌人")), "#e6a23c")
	# 战斗强度总评（全部敌人攻防 vs 玩家）
	if combat_engine != null:
		var total_atk := 0
		var total_def := 0
		for e3 in enemies:
			total_atk += int(e3.get("atk", 0))
			total_def += int(e3.get("def", 0))
		var p_atk: int = int(combat_engine.player_combat_stats.get("atk", 0))
		var p_def: int = int(combat_engine.player_combat_stats.get("def", 0))
		# 难度修正（简单 +30% 攻防评估）
		var diff_mul := 1.0
		match GameManager.user_data.difficulty_mode if GameManager.user_data != null else "normal":
			"easy": diff_mul = 0.7
			"hard": diff_mul = 1.2
		var threat := "适中"
		var threat_color := "#c9a06a"
		var eff_atk := int(total_atk * diff_mul)
		var eff_def := int(total_def * diff_mul)
		if eff_atk > p_atk * 1.5 or eff_def > p_def * 1.5:
			threat = "危险"
			threat_color = "#e05a4e"
			ToastManager.warning("⚠ 敌人明显强于你，考虑逃跑或准备充分再战！")
			_add_history("⚠ 遭遇强敌：%d 个（敌攻 %d vs 你 %d）" % [enemies.size(), total_atk, p_atk])
		elif total_atk < p_atk * 0.7 and total_def < p_def * 0.7:
			threat = "轻松"
			threat_color = "#7cc47c"
		# 难度标记（非普通时提示）
		var diff_mark := ""
		if diff_mul < 1.0:
			diff_mark = "（简单加成）"
		elif diff_mul > 1.0:
			diff_mark = "（困难挑战）"
		_battle_log_line("强度评估：[color=%s]%s[/color]（敌攻 %d vs 你 %d）%s" % [threat_color, threat, eff_atk, p_atk, diff_mark], "")
		# 强度评估 Toast（危险/轻松时提示）
		if threat != "适中":
			ToastManager.info("⚔ 敌人强度：%s" % threat)
		# 强度标记入敌人栏（危险 ⚠ / 轻松 ✓）
		if threat != "适中":
			enemy_info.text += "\n[color=%s]强度：%s[/color]" % [threat_color, threat]
		# 强度明细 tooltip（攻防对比）
		enemy_info.tooltip_text += "\n敌攻 %d vs 你 %d · 敌防 %d vs 你 %d" % [total_atk, p_atk, total_def, p_def]
	# 自动推进在战斗中暂停（需玩家手动战斗）
	if _auto_advance_mode:
		_battle_log_line("⏸ 自动推进已暂停（战斗进行中）", "#8a8278")
		# 自动战斗辅助：自动推进开启时自动攻击
		_auto_combat_timer.start(1.2)
	# 遗物加成提示（持有 rare_relic 时攻击 +5）
	if economy_engine != null and int(economy_engine.player_inventory.get("rare_relic", 0)) > 0:
		_battle_log_line("✨ 遗物共鸣：攻击力 +5", "#e6c84c")
		if combat_engine != null:
			combat_engine.player_combat_stats["atk"] = int(combat_engine.player_combat_stats.get("atk", 15)) + 5
	# 时段提示（夜晚战斗可辨识）
	if world_state != null and world_state.get_period_name() == "夜晚":
		_battle_log_line("夜色中战斗…（视野受限）", "#7fa8d9")
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
	# 敌人信息初始 tooltip（悬停查看详情）
	enemy_info.tooltip_text = "悬停查看敌人攻防/状态效果"
	# 逃跑按钮 tooltip：当前成功率
	var flee_btn := get_node_or_null("BattlePanel/BattleVBox/BattleButtons/FleeBtn")
	if flee_btn is Button and combat_engine != null:
		# 持有烟雾弹类道具提升逃跑率
		var flee_bonus := 0.0
		if economy_engine != null and int(economy_engine.player_inventory.get("smoke_bomb", 0)) > 0:
			flee_bonus = 0.15
		(flee_btn as Button).tooltip_text = "成功率 %.0f%%（敏捷影响%s）" % [
			(combat_engine.last_flee_chance + flee_bonus) * 100.0,
			"，烟雾弹 +15%" if flee_bonus > 0.0 else "；烟雾弹可 +15%（战斗胜利概率掉落）"]
	# 战斗快捷键提示（替换底部常驻提示）
	var hint := get_node_or_null("MainVBox/HintLabel")
	if hint:
		hint.text = "技能：按 1-9 直接释放 · Tab 切换目标 · Q 用药 · Esc 菜单 · H 帮助 · 自动可调速"
		# 药水库存显示
		var potion_count := 0
		if economy_engine != null:
			for item_id in economy_engine.player_inventory:
				if "potion" in str(item_id) or "herb" in str(item_id) or "药" in str(item_id):
					potion_count += int(economy_engine.player_inventory[item_id])
		if potion_count > 0:
			hint.text += " · 🍶药水×%d" % potion_count

func _on_combat_round_started(round_num: int) -> void:
	_battle_log_line("─ ⚔ 第 %d 回合 ─" % round_num, "#c9a06a")
	# 回合敌人剩余（多敌时）
	if combat_engine != null and combat_engine.enemies.size() > 1:
		var alive_n: int = 0
		for ee in combat_engine.enemies:
			if ee.get("is_alive", true):
				alive_n += 1
		_battle_log_line("敌人剩余：%d/%d" % [alive_n, combat_engine.enemies.size()], "#8a8278")
	# 回合 MP 状态（低 MP 提示）
	if combat_engine != null and not combat_engine.player_combat_stats.is_empty():
		var mp_round: int = int(combat_engine.player_combat_stats.get("mp", 0))
		if mp_round < 3:
			_battle_log_line("✦ MP 紧张（%d），普攻可攒蓝" % mp_round, "#8a8278")
		# 回合低血提示（<30% 建议药水/休息）
		var hp_round: int = int(combat_engine.player_combat_stats.get("hp", 0))
		var hp_round_max: int = maxi(1, int(combat_engine.player_combat_stats.get("max_hp", 100)))
		if hp_round < hp_round_max * 0.3:
			_battle_log_line("🩸 生命危急（%d%%），建议用药/治疗技能" % int(hp_round * 100.0 / hp_round_max), "#e05a4e")
	# 状态效果倒计时日志（剩余 1 回合提示）
	if combat_engine != null and not combat_engine.player_combat_stats.is_empty():
		var ps_fx: Array = combat_engine.player_combat_stats.get("status_effects", [])
		for f2 in ps_fx:
			if int(f2.get("remaining_turns", 0)) == 1:
				_battle_log_line("⏳ %s 还剩 1 回合" % str(f2.get("name", "效果")), "#e6c84c")
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
		# 战斗面板轻微震动（受击反馈）
		if ThemeManager.animations_enabled:
			var base_pos := battle_panel.position
			var shake_tw := create_tween()
			for i in 3:
				shake_tw.tween_property(battle_panel, "position", base_pos + Vector2(randf_range(-4, 4), randf_range(-3, 3)), 0.03)
			shake_tw.tween_property(battle_panel, "position", base_pos, 0.04)
		# 玩家 HP 红闪反馈（血条变红闪烁）
		var hp_lbl := get_node_or_null("MainVBox/HSplit/LeftPanel/LeftVBox/HPHBox/PlayerHPBar") as ProgressBar
		if hp_lbl != null:
			hp_lbl.add_theme_stylebox_override("fill", (func() -> StyleBox:
				var sb := StyleBoxFlat.new()
				sb.bg_color = Color(1.0, 0.25, 0.25)
				return sb).call())
			var hp_tw := create_tween()
			hp_tw.tween_interval(0.3)
			hp_tw.tween_callback(func(): hp_lbl.remove_theme_stylebox_override("fill"))
	# 玩家攻击日志绿色（与敌人蓝色区分）
	elif _action.get("type", "") in ["player_attack", "skill"] and int(_action.get("damage", 0)) > 0:
		# 技能名（若有）
		var skill_name: String = str(_action.get("skill_name", ""))
		if not skill_name.is_empty():
			_battle_log_line("你使用【%s】攻击 %s，造成 %d 伤害" % [skill_name, _actor.get("name", "敌人"), int(_action.get("damage", 0))], "#7cc47c")
		else:
			_battle_log_line("你攻击 %s，造成 %d 伤害" % [_actor.get("name", "敌人"), int(_action.get("damage", 0))], "#7cc47c")
		# 低血警告（HP ≤ 25%）
		if combat_engine != null:
			var ps2: Dictionary = combat_engine.player_combat_stats
			var cur_hp2: int = int(ps2.get("hp", 0))
			var max_hp2: int = int(ps2.get("max_hp", 100))
			if max_hp2 > 0 and cur_hp2 <= max_hp2 * 0.25:
				ToastManager.warning("⚠️ 生命垂危！剩余 %d/%d" % [cur_hp2, max_hp2])
		hp_label.add_theme_color_override("font_color", Color(0.95, 0.3, 0.3))
		var tween := create_tween()
		tween.tween_interval(0.25)
		tween.tween_callback(func():
			hp_label.remove_theme_color_override("font_color"))
	_refresh_battle_ui()

func _on_combat_ended(result: String) -> void:
	battle_panel.visible = false
	# 恢复主文本颜色
	main_text.remove_theme_color_override("font_color")
	# 战斗结束释放焦点回主区
	main_text.grab_focus()
	# 停止自动战斗辅助
	if _auto_combat_timer != null:
		_auto_combat_timer.stop()
	# 战斗结束：自动推进恢复提示
	if _auto_advance_mode:
		ToastManager.info("▶ 战斗结束，自动推进已恢复")
		# 低血自动休息建议（自动模式）
		if combat_engine != null:
			var ps6: Dictionary = combat_engine.player_combat_stats
			var max6: int = int(ps6.get("max_hp", 100))
			if max6 > 0 and int(ps6.get("hp", 0)) < max6 * 0.6:
				ToastManager.warning("💤 生命较低，建议菜单休息回满")
	# 战斗失败：连败提示（≥3 建议调整策略）
	if result == "defeat":
		_lose_streak += 1
		if _lose_streak >= 3:
			ToastManager.warning("连续战败 %d 场…建议：升级/购买装备/调整技能" % _lose_streak)
	# 战败提示自动存档建议（可回滚）
	if result == "defeat":
		ToastManager.info("💡 战败可读档重试（菜单 L）或继续当前状态")
	else:
		_lose_streak = 0
	# 战斗胜利庆祝（胜场计数里程碑，计数在战斗统计处统一累加）
	if result == "victory":
		_win_streak += 1
		if _battle_wins == 0:
			ToastManager.success("🗡 首战告捷！")
		if _win_streak == 5:
			ToastManager.success("🔥 五连胜！势不可挡")
		elif _win_streak == 10:
			ToastManager.success("⚡ 十连胜！战场传说")
		var wins_after: int = _battle_wins + 1
		if wins_after == 10:
			ToastManager.success("🏆 累计 10 胜！战斗专家成就")
		elif wins_after == 50:
			ToastManager.success("🏆 累计 50 胜！百战老兵成就")
	else:
		_win_streak = 0
	# 敌人状态摘要（存活/阵亡）
	if combat_engine != null and not combat_engine.enemies.is_empty():
		var status_parts: Array[String] = []
		var killed_count := 0
		for e in combat_engine.enemies:
			var ename: String = str(e.get("name", "?"))
			if not e.get("is_alive", false):
				killed_count += 1
			status_parts.append(("%s ✅" % ename) if e.get("is_alive", false) else ("%s 💀" % ename))
		_battle_log_line("敌人状态：%s" % "，".join(status_parts), "#8a8278")
		# 全灭提示
		if killed_count > 0 and killed_count == combat_engine.enemies.size():
			ToastManager.success("☠ 敌人全灭！")
	# 恢复常驻操作提示（战斗时被快捷键提示替换）
	var hint := get_node_or_null("MainVBox/HintLabel")
	if hint is Label and (hint as Label).text.begins_with("⚔"):
		(hint as Label).text = ""
	# 自动战斗重置
	if _auto_battle:
		_auto_battle = false
		_battle_log_line("⏹ 自动战斗已停止", "#8a8278")
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
	# 战斗统计即时写入存档（重进保持胜场）
	if SaveManager.current_save != null and combat_engine != null:
		var ps_stats: Dictionary = SaveManager.current_save.player_state
		ps_stats["battle_wins"] = _battle_wins
		ps_stats["battle_defeats"] = _battle_defeats
		ps_stats["battle_flees"] = _battle_flees
	var msg := "战斗胜利！" if result == "victory" else ("战斗失败…" if result == "defeat" else "成功逃跑")
	# 战斗结束日志统计
	var rounds_log: int = combat_engine.current_round if combat_engine != null else 0
	var dmg_log: int = _total_damage_dealt
	_battle_log_line("─ 战斗结束：%s（%d 回合，造成 %d 伤害，掉落 %d 件）─" % [msg, rounds_log, dmg_log, _loot_count], "#c9a06a")
	# 逃跑结果提示（含烟雾弹信息）
	if result == "flee":
		var flee_chance_pct := 50
		if combat_engine != null:
			flee_chance_pct = int(combat_engine.last_flee_chance * 100.0)
		ToastManager.info("💨 成功逃跑（成功率 %d%%）" % flee_chance_pct)
	if result == "defeat":
		ToastManager.warning("💀 战斗失败…可通过菜单读档回到战斗前（自动存档）")
	# 战斗胜利自动存档（失败不覆盖，保留战斗前存档可重试）
	if result == "victory":
		SaveManager.autosave()
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
		# 难度奖励倍率（简单 0.8 / 困难 1.3）
		var reward_mul := 1.0
		match GameManager.user_data.difficulty_mode if GameManager.user_data != null else "normal":
			"easy": reward_mul = 0.8
			"hard": reward_mul = 1.3
		gold = int(gold * reward_mul)
		exp = int(exp * reward_mul)
		if economy_engine != null and gold > 0:
			economy_engine.add_currency("gold", gold)
			msg = "战斗胜利！获得 %d 金币、%d 经验" % [gold, exp]
			# 胜利奖励金币飘字（金色 +）
			if gold > 0:
				_spawn_damage_popup(gold, false, true)  # 胜利金币金色
			if _best_combo >= 2:
				msg += " · 最高连击 x%d" % _best_combo
			ToastManager.success("战斗胜利！+%d 金币 +%d 经验" % [gold, exp])
			_add_history("⚔ 战斗胜利：+%d 金币 +%d 经验" % [gold, exp])
			# 胜利历史含敌人名（若有）
			if not combat_engine.enemies.is_empty():
				var first_enemy: String = str(combat_engine.enemies[0].get("name", "?"))
				_add_history("🏁 击败 %s" % first_enemy)
				# 敌人图鉴计数（本次游玩）
				_enemy_codex[first_enemy] = int(_enemy_codex.get(first_enemy, 0)) + 1
			# 掉落物品入背包
			var loot: Array = rewards.get("loot", [])
			# 演示掉落：30% 概率额外获得烟雾弹（逃跑道具）
			if randf() < 0.3:
				loot.append("smoke_bomb")
			for li in loot:
				var litem: String = str(li)
				economy_engine.player_inventory[litem] = int(economy_engine.player_inventory.get(litem, 0)) + 1
				if not msg.contains("掉落"):
					msg += " · 掉落：%s" % litem
				else:
					msg += "、%s" % litem
				# 掉落日志（战斗日志独立记录）
				_battle_log_line("🎁 掉落：%s" % litem, "#e6c84c")
				_loot_count += 1
				# 稀有掉落庆祝
				if str(li) == "rare_relic":
					ToastManager.success("✨ 获得稀有遗物！永久攻击 +5")
				if litem == "rare_relic":
					ToastManager.success("✨ 稀有掉落！获得遗物 %s" % litem)
					_spawn_damage_popup(1, true)  # 金色大字
				else:
					ToastManager.success("🎁 获得掉落物品：%s" % litem)
				_add_history("🎁 掉落物品：%s" % litem)
			# 稀有掉落：主文本金强调（遗物）
			if loot.has("rare_relic"):
				msg += "（✨ 稀有！）"
			# 战后状态（HP/MP 剩余）
			var ps_post: Dictionary = combat_engine.player_combat_stats
			if not ps_post.is_empty():
				msg += "\n（HP %d/%d · MP %d/%d）" % [
					int(ps_post.get("hp", 0)), int(ps_post.get("max_hp", 100)),
					int(ps_post.get("mp", 0)), int(ps_post.get("max_mp", 50))]
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
				# 新称号提示（属性偏向变化时）
				var atk_n: int = int(stats.get("atk", 0))
				var def_n: int = int(stats.get("def", 0))
				var spd_n: int = int(stats.get("speed", 0))
				var new_job := "旅者"
				if atk_n >= def_n and atk_n >= spd_n:
					new_job = "剑客"
				elif def_n >= atk_n and def_n >= spd_n:
					new_job = "守卫"
				elif spd_n > atk_n and spd_n > def_n:
					new_job = "游侠"
				if new_job != "旅者":
					ToastManager.info("称号：%s" % new_job)
				_add_history("🎉 升级至 Lv.%d" % int(stats.get("level", 1)))
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
		_add_history("⚰ 战斗中阵亡（第 %d 天）" % (world_state.get_current_day() if world_state else 1))
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
	# 读档重置战斗状态（若之前处于战斗）
	if battle_panel != null:
		battle_panel.visible = false
	if combat_engine != null:
		combat_engine.reset_battle()
	# 恢复 Toast（天数/等级/金币）
	if world_state != null:
		var gold_after: int = int((sd.player_state.get("gold", 0)))
		ToastManager.success("进度恢复：第 %d 天 · Lv.%d · 💰%d" % [
			world_state.get_current_day(),
			int(sd.player_state.get("level", 1)),
			gold_after])
	if event_engine:
		event_engine.load_history(sd.event_history)
	if world_state:
		world_state.load_from_dict(sd.world_state)
	if economy_engine:
		economy_engine.load_from_dict(sd.economy_state)
	if combat_engine and sd.player_state:
		combat_engine.set_player_stats(sd.player_state)
	# 恢复自动推进偏好（读档后重置为用户设置）
	_auto_advance_mode = GameManager.user_data.auto_advance
	# 酒馆恢复（当前角色/历史）
	if TavernManager != null and not TavernManager.current_character.is_empty():
		TavernManager.load_history(str(TavernManager.current_character.get("id", "innkeeper")))
		_enter_tavern_char(maxi(0, tavern_char_select.selected))
	# 进度百分比提示
	var prog3 := _get_progress()
	if prog3[1] > 0:
		var pct := int(float(prog3[0]) / float(prog3[1]) * 100.0)
		ToastManager.info("📊 剧情进度 %d%%" % pct)
	# 打字机状态重置（读档后显示恢复文本）
	_typewriter_done = true
	_typewriter_index = 0
	# 恢复最后一条剧情文本到主区
	if event_engine != null and event_engine.event_history.size() > 0:
		var last_ev: Dictionary = event_engine.event_history[event_engine.event_history.size() - 1]
		var last_txt: String = str(last_ev.get("text", ""))
		if not last_txt.is_empty():
			_set_main_text(last_txt)
	# 读档完成关闭菜单与槽位选择器
	if menu_panel != null:
		menu_panel.visible = false
	# 恢复信息汇总（等级/金币/进度）
	var summary: String = "📂 已恢复"
	if world_state != null:
		summary += " · 第 %d 天" % world_state.get_current_day()
	if combat_engine != null and not combat_engine.player_combat_stats.is_empty():
		summary += " · Lv.%d" % int(combat_engine.player_combat_stats.get("level", 1))
	if economy_engine != null:
		summary += " · 💰%d" % int(economy_engine.player_currencies.get("gold", 0))
	ToastManager.success(summary)
	_update_ui()
	_sync_save_state()

func _battle_log_line(line: String, color: String = "") -> void:
	# 时间戳（含游戏日期，跨天战斗可区分）
	var ts := Time.get_time_string_from_system().substr(0, 5)
	if world_state != null:
		ts = "第%d天 %s" % [world_state.get_current_day(), world_state.get_period_name()]
	var prefix := "[color=#7a7268][%s][/color] " % ts
	if not color.is_empty():
		battle_log.append_text(prefix + "[color=%s]%s[/color]\n" % [color, line])
	else:
		battle_log.append_text(prefix + line + "\n")
	# 滚动到底 + 新行淡入高亮
	battle_log.scroll_to_line(battle_log.get_line_count() - 1)
	# 行数上限（防长战斗日志膨胀卡顿）
	if battle_log.get_line_count() > 150:
		var lines_text := battle_log.text.split("\n")
		if lines_text.size() > 120:
			battle_log.text = "\n".join(lines_text.slice(lines_text.size() - 120))
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
	# 战斗 HUD HP/MP 实时刷新（含 MP 变化动画）
	_update_ui()
	var parts: Array[String] = []
	var alive := 0
	var total_enemies := 0
	for e in combat_engine.enemies:
		total_enemies += 1
		if e.get("is_alive", true):
			alive += 1
			# 当前目标敌人加 🎯 高亮标记
			var mark := "🎯 " if (total_enemies > 1 and _battle_target == total_enemies - 1) else ""
			# 文字血条（▓░）
			var e_hp: int = int(e.get("hp", 0))
			var e_max: int = maxi(1, int(e.get("max_hp", 1)))
			var e_ratio: float = float(e_hp) / float(e_max)
			var bar_chars := 8
			var filled := int(round(e_ratio * bar_chars))
			var hp_bar_txt := "▓".repeat(clampi(filled, 0, bar_chars)) + "░".repeat(bar_chars - clampi(filled, 0, bar_chars))
			# 低血敌人红色标记
			var low_tag := " ⚠" if e_ratio < 0.25 else ""
			# 血量颜色提示（低血红/半血红橙）
			var hp_color := "#ffffff"
			if e_ratio < 0.25:
				hp_color = "#e05a4e"
			elif e_ratio < 0.5:
				hp_color = "#e0a04e"
			parts.append("%s[color=%s]%s[/color] HP:%d/%d %s%s" % [mark, hp_color, e.get("name", "?"), e_hp, e_max, hp_bar_txt, low_tag])
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
		else:
			# 目标已死亡/失效 → 自动切换到第一个存活敌人
			for ti in combat_engine.enemies.size():
				if combat_engine.enemies[ti].get("is_alive", true):
					_battle_target = ti
					target_name = str(combat_engine.enemies[ti].get("name", "?"))
					break
		enemy_info.text += "\n[color=#c9a06a]🎯 目标：%s（点击切换）[/color]" % target_name
		enemy_info.tooltip_text = "Tab 或点击切换目标；当前攻击将指向 %s（建议集火低血 ⚠ 敌人）" % target_name
	if enemy_info.get_signal_connection_list("gui_input").is_empty():
		enemy_info.gui_input.connect(_on_enemy_info_clicked)
	enemy_info.add_theme_color_override("font_color", Color(0.9, 0.35, 0.35))
	# 玩家状态
	var ps: Dictionary = combat_engine.player_combat_stats
	# 状态效果提示（玩家/敌人 buff）
	var fx_lines: Array[String] = []
	var pfx: Array = ps.get("status_effects", []) if not ps.is_empty() else []
	for fx in pfx:
		var fx_name: String = str(fx.get("name", "?"))
		var fx_icon := ""
		match fx_name:
			"中毒": fx_icon = "🤢"
			"虚弱": fx_icon = "😵"
			"护盾": fx_icon = "🛡"
			"狂暴": fx_icon = "😤"
			"再生": fx_icon = "💚"
		fx_lines.append("%s%s(剩%d)" % [fx_icon, fx_name, int(fx.get("remaining_turns", 0))])
	for e in combat_engine.enemies:
		if e.get("is_alive", true):
			for fx in e.get("status_effects", []):
				fx_lines.append("%s:%s" % [e.get("name", "?"), fx.get("name", "?")])
	if not fx_lines.is_empty():
		enemy_info.text += "\n[效果] %s" % "，".join(fx_lines)
		enemy_info.tooltip_text = "状态效果说明：中毒=每回合损血，护盾=减伤，狂暴=攻+防-，再生=回血"
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
		# 目标切换闪烁（敌人栏高亮 0.3s）
		enemy_info.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
		var tt := create_tween()
		tt.tween_interval(0.3)
		tt.tween_callback(func(): enemy_info.remove_theme_color_override("font_color"))

func _on_battle_attack_pressed() -> void:
	if combat_engine == null:
		return
	# 命中率提示（攻击按钮 tooltip）
	var atk_tip_btn := get_node_or_null("BattlePanel/BattleVBox/BattleButtons/AttackBtn") as Button
	if atk_tip_btn != null:
		var agi_r: int = int(combat_engine.player_combat_stats.get("agility", 10))
		atk_tip_btn.tooltip_text = "普攻（命中率受敏捷影响，敏捷 %d；回复 MP）" % agi_r
	# 普攻攒蓝提示（MP 不足时战斗日志提示）
	var cur_mp_a: int = int(combat_engine.player_combat_stats.get("mp", 0))
	var res: Dictionary = combat_engine.player_attack(_battle_target)  # 指定目标（-1 自动选存活）
	if not res.is_empty():
		# 普攻回蓝提示（本次攻击回复 MP）
		var mp_gain_a: int = int(res.get("mp_gain", 0))
		if mp_gain_a > 0:
			_battle_log_line("✦ 普攻回复 MP +%d" % mp_gain_a, "#7cc4e0")
			_spawn_mp_popup(mp_gain_a)
		# 攻击落空提示（MISS）
		if int(res.get("damage", 0)) == 0 and not res.get("miss", false):
			_battle_log_line("攻击落空…（闪避）", "#8a8278")
			var miss_lbl := Label.new()
			miss_lbl.text = "MISS"
			miss_lbl.add_theme_color_override("font_color", Color(0.6, 0.58, 0.55))
			miss_lbl.add_theme_font_size_override("font_size", 20)
			miss_lbl.position = enemy_info.global_position + Vector2(randf_range(40, 100), -30)
			miss_lbl.z_index = 100
			add_child(miss_lbl)
			var mtw := create_tween()
			mtw.set_parallel(true)
			mtw.tween_property(miss_lbl, "position:y", miss_lbl.position.y - 40, 0.7).set_ease(Tween.EASE_OUT)
			mtw.tween_property(miss_lbl, "modulate:a", 0.0, 0.7)
			mtw.chain().tween_callback(miss_lbl.queue_free)
		# 普攻小额回蓝（+1 MP 攒蓝机制）
		var stats_a: Dictionary = combat_engine.player_combat_stats
		stats_a["mp"] = mini(int(stats_a.get("max_mp", 50)), int(stats_a.get("mp", 0)) + 1)
		_spawn_mp_popup(1)  # 蓝色 +1 MP 飘字
		# 暴击日志金色（普通红色）
		var is_crit: bool = bool(res.get("critical", false))
		_battle_log_line("%s 攻击造成 %d 伤害%s" % [
			combat_engine.player_combat_stats.get("name", "你"),
			res.get("damage", 0), "（暴击！）" if is_crit else ""],
			"#e6c84c" if is_crit else "#e0665a")
		_spawn_damage_popup(-int(res.get("damage", 0)), is_crit)
		# 敌人受击闪红（命中反馈）
		if int(res.get("damage", 0)) > 0:
			_total_damage_dealt += int(res.get("damage", 0))
			enemy_info.add_theme_color_override("font_color", Color(1.0, 0.4, 0.35))
			var etw2 := create_tween()
			etw2.tween_interval(0.15)
			etw2.tween_callback(func(): enemy_info.remove_theme_color_override("font_color"))
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
	# 快速连发时轻微错位（视觉层叠）
	var spawn_y := randf_range(-16, 16)
	_spawn_mp_popup_impl(amount, critical, is_gold, spawn_y)

## MP 恢复飘字（蓝色，+MP）
func _spawn_mp_popup(amount: int) -> void:
	_spawn_mp_popup_impl(amount, false, false, randf_range(-16, 16), true)

func _spawn_mp_popup_impl(amount: int, critical: bool, is_gold: bool, y_off: float, is_mp: bool = false) -> void:
	var popup_pos := Vector2.ZERO
	if enemy_info != null and enemy_info.is_visible_in_tree():
		popup_pos = enemy_info.global_position + Vector2(randf_range(20, 120), -10 + y_off)
	else:
		# fallback：屏幕中心（商店等非战斗场景）
		popup_pos = get_viewport().get_visible_rect().size / 2 + Vector2(randf_range(-80, 80), -40 + y_off)
	var lbl := Label.new()
	# MP 飘字蓝色（#5ab0d8），其他沿用原色逻辑
	var color := Color(0.35, 0.9, 0.45) if not is_mp else Color(0.35, 0.69, 0.85)
	if amount < 0:
		color = Color(0.95, 0.4, 0.35)
	elif is_gold:
		color = Color(1.0, 0.8, 0.3)
	lbl.text = ("-%d" % absi(amount)) if amount < 0 else ("+%d" % amount)
	if is_mp:
		lbl.text = "✦ +%d" % amount
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
	var cur_mp2 := 0
	for s in skills:
		var sid: String = s.get("id", "")
		# 显示 MP 消耗 + 数字键提示
		var mana_cost: int = int((s.get("cost", {}) as Dictionary).get("mana", 0))
		var label: String = "%d. %s" % [skills.find(s) + 1, s.get("name", sid)]
		if mana_cost > 0:
			label += "（MP %d）" % mana_cost
		# 技能元素属性标签
		var s_elem: String = str(s.get("element", ""))
		if not s_elem.is_empty():
			label += " [%s]" % s_elem
		# 数字快捷键标注
		var skill_idx: int = skills.find(s)
		if skill_idx < 9:
			label = "[%d] %s" % [skill_idx + 1, label]
		menu.add_item(label, skills.find(s))
		# tooltip：技能描述 + 元素克制提示
		var desc: String = str(s.get("description", ""))
		var s_elem2: String = str(s.get("element", ""))
		if not desc.is_empty():
			if not s_elem2.is_empty():
				desc += "\n元素：%s（克制对应抗性弱的目标）" % s_elem2
			menu.set_item_tooltip(skills.find(s), desc)
		# MP 不足：置灰禁用
		var cur_mp: int = int(combat_engine.player_combat_stats.get("mp", 0))
		cur_mp2 = cur_mp
		if mana_cost > cur_mp:
			menu.set_item_disabled(skills.find(s), true)
			menu.set_item_tooltip(skills.find(s), "魔力不足（需要 %d MP）" % mana_cost)
	# MP 全部不足提示
	if cur_mp2 < 1:
		ToastManager.warning("✦ MP 已耗尽，请先普攻攒蓝或休息恢复")
	# 菜单标题显示当前 MP
	var mp_now: int = int(combat_engine.player_combat_stats.get("mp", 0))
	var mp_max: int = int(combat_engine.player_combat_stats.get("max_mp", 50))
	menu.size = Vector2i(260, 0)
	menu.title = "✦ 技能（MP %d/%d）" % [mp_now, mp_max]
	menu.id_pressed.connect(func(id: int):
		var sres: Dictionary = combat_engine.player_use_skill(skills[id].get("id", ""), _battle_target)
		if not sres.is_empty():
			var dmg := int(sres.get("damage", 0))
			# 技能命中提示（关键反馈）
			var sname := str(skills[id].get("name", "技能"))
			if dmg > 0:
				ToastManager.info("⚡ %s 命中！" % sname)
				# 技能暴击 Toast
				if bool(sres.get("critical", false)):
					ToastManager.success("💥 %s 暴击！" % sname)
			# 技能 MP 消耗飘字（蓝色 -）
			var mp_cost_s: int = int((skills[id].get("cost", {}) as Dictionary).get("mana", 0))
			if mp_cost_s > 0:
				_spawn_mp_popup(-mp_cost_s)
			if dmg > 0:
				# 技能暴击日志金色
				var s_crit: bool = bool(sres.get("critical", false))
				_battle_log_line("%s 释放 %s，造成 %d 伤害%s" % [
					combat_engine.player_combat_stats.get("name", "你"),
					skills[id].get("name", "技能"), dmg, "（暴击！）" if s_crit else ""],
					"#e6c84c" if s_crit else "#e0665a")
				_spawn_damage_popup(-dmg, s_crit)
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
				_spawn_damage_popup(healed)  # 绿色恢复飘字
				# 血条绿闪反馈
				var hp_bar := get_node_or_null("MainVBox/HSplit/LeftPanel/LeftVBox/HPHBox/PlayerHPBar") as ProgressBar
				if hp_bar != null:
					hp_bar.add_theme_stylebox_override("fill", (func() -> StyleBox:
						var sb := StyleBoxFlat.new()
						sb.bg_color = Color(0.35, 0.9, 0.45)
						return sb).call())
					var hp_tw2 := create_tween()
					hp_tw2.tween_interval(0.3)
					hp_tw2.tween_callback(func(): hp_bar.remove_theme_stylebox_override("fill"))
			# MP 恢复飘字（蓝色）
			var mp_restored := int(sres.get("mp_restored", 0))
			if mp_restored > 0:
				_spawn_mp_popup(mp_restored)
				_spawn_damage_popup(healed)  # 治疗 +绿字飘字
			if sres.get("buffed", false):
				ToastManager.success("🛡 %s 获得增益！" % skills[id].get("name", "技能"))
			if sres.get("shield", 0) > 0:
				ToastManager.info("🛡 获得 %d 点护盾" % int(sres.get("shield", 0)))
		_refresh_battle_ui())
	add_child(menu)
	menu.popup(Rect2i(0, 0, 0, 0))
	menu.position = Vector2i(get_viewport().get_visible_rect().size / 2) - Vector2i(100, 50)
	# 菜单关闭后焦点回主战斗按钮
	menu.popup_hide.connect(func():
		var atk_btn := get_node_or_null("BattlePanel/BattleVBox/BattleButtons/AttackBtn") as Button
		if atk_btn != null:
			atk_btn.grab_focus())

func _on_battle_flee_pressed() -> void:
	if combat_engine != null:
		# 逃跑成功率 tooltip（含烟雾弹加成）
		var flee_btn := get_node_or_null("BattlePanel/BattleVBox/BattleButtons/FleeBtn") as Button
		if flee_btn != null:
			var base_flee: float = 0.5 + float(combat_engine.player_combat_stats.get("agility", 10)) * 0.02
			var smoke_flee: bool = economy_engine != null and int(economy_engine.player_inventory.get("smoke_bomb", 0)) > 0
			flee_btn.tooltip_text = "逃跑（基础成功率 %d%%%s）" % [int(base_flee * 100.0), "，有烟雾弹 +15%" if smoke_flee else ""]
		# 烟雾弹消耗并提升逃跑成功率
		var flee_bonus := 0.0
		if economy_engine != null and int(economy_engine.player_inventory.get("smoke_bomb", 0)) > 0:
			economy_engine.player_inventory["smoke_bomb"] = int(economy_engine.player_inventory["smoke_bomb"]) - 1
			flee_bonus = 0.15
			_battle_log_line("💨 使用烟雾弹，逃跑成功率 +15%", "#e6c84c")
		var chance: float = combat_engine.last_flee_chance + flee_bonus
		# 尝试逃跑
		combat_engine.try_flee()
		# 若仍在战斗（未逃跑成功）提示成功率
		if battle_panel.visible:
			ToastManager.warning("逃跑失败…成功率 %.0f%%（敏捷越高越易逃脱）" % (chance * 100.0))
			# 有烟雾弹时提示（下次逃跑 +15%）
			if economy_engine != null and int(economy_engine.player_inventory.get("smoke_bomb", 0)) > 0:
				ToastManager.info("💨 背包有烟雾弹（逃跑 +15%），可再次尝试")
			# 连续逃跑失败计数（≥2 提示用技能/药水）
			_flee_fail_count += 1
			if _flee_fail_count >= 2:
				ToastManager.info("多次逃跑失败，可尝试技能/药水或战斗到底")
		else:
			_add_history("🏃 成功逃离战斗")
			ToastManager.success("🏃 成功逃离战斗")
			_flee_fail_count = 0

## 使用背包中第一个药水/草药（Q 键/按钮共用）
func _use_first_potion() -> void:
	if economy_engine == null or economy_engine.player_inventory.is_empty():
		ToastManager.warning("背包里没有药水（商店可购买）")
		return
	for item_id in economy_engine.player_inventory:
		if int(economy_engine.player_inventory[item_id]) <= 0:
			continue
		if "potion" in str(item_id) or "herb" in str(item_id) or "药" in str(item_id):
			if combat_engine != null:
				var ps4: Dictionary = combat_engine.player_combat_stats
				var heal_amt2 := 30
				if "potion" in str(item_id):
					heal_amt2 = 50
				ps4["hp"] = mini(int(ps4.get("max_hp", 100)), int(ps4.get("hp", 0)) + heal_amt2)
				economy_engine.player_inventory[item_id] = int(economy_engine.player_inventory[item_id]) - 1
				_spawn_damage_popup(heal_amt2)  # 药水恢复绿色飘字
				ToastManager.success("🍶 使用 %s 恢复 %d HP" % [item_id, heal_amt2])
				_battle_log_line("🍶 使用 %s 恢复 %d HP" % [item_id, heal_amt2], "#7cc47c")
				_refresh_battle_ui()
				return
				_battle_log_line("💊 使用 %s 恢复 %d HP" % [item_id, heal_amt2], "#7cc47c")
				ToastManager.success("💊 恢复 %d HP" % heal_amt2)
				_refresh_battle_ui()
				_update_ui()
				_sync_save_state()
				return
	ToastManager.warning("没有可用的药水")

## 自动战斗开关（连续点击循环 1x→2x→4x→关）
func _on_battle_auto_pressed() -> void:
	var auto_btn := get_node_or_null("BattlePanel/BattleVBox/BattleButtons/AutoBtn")
	# 自动推进模式已含自动战斗，避免双重攻击
	if _auto_advance_mode and not _auto_battle:
		ToastManager.info("自动推进模式已含自动战斗（A 可关闭）")
		return
	if not _auto_battle:
		_auto_battle = true
		_auto_interval = 0.6
		_auto_timer = 0.0
		ToastManager.info("自动战斗开启（1x，再按加速）")
	elif _auto_interval == 0.6:
		_auto_interval = 0.3
		ToastManager.info("自动战斗加速（2x，再按 4x）")
	elif _auto_interval == 0.3:
		_auto_interval = 0.15
		ToastManager.info("自动战斗加速（4x，再按关闭）")
	else:
		_auto_battle = false
		ToastManager.info("自动战斗关闭")
	# 按钮文本显示当前档位
	if auto_btn is Button:
		if _auto_battle:
			var speed_lbl: String = "自动 1x"
			if _auto_interval == 0.3:
				speed_lbl = "自动 2x"
			elif _auto_interval == 0.15:
				speed_lbl = "自动 4x"
			(auto_btn as Button).text = speed_lbl
		else:
			(auto_btn as Button).text = "自动"
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
## 历史记录复制到剪贴板
func _on_history_copy_pressed() -> void:
	if history_text.text.is_empty():
		ToastManager.info("历史记录为空")
		return
	DisplayServer.clipboard_set(history_text.text)
	ToastManager.success("历史记录已复制到剪贴板")

func _on_history_clear_pressed() -> void:
	if history_text.text.is_empty():
		ToastManager.info("历史记录为空")
		return
	var confirm := ConfirmationDialog.new()
	confirm.dialog_text = "确定清空全部剧情历史？（不可恢复）"
	confirm.confirmed.connect(func():
		history_text.clear()
		_history_last_day = 0
		ToastManager.info("剧情历史已清空"))
	add_child(confirm)
	confirm.popup_centered()

## === 历史记录折叠 ===
func _on_history_toggle_pressed() -> void:
	# 记录展开前的新记录数（用于展开提示）
	var unread_before: int = _history_unread
	history_panel.visible = not history_panel.visible
	_history_unread = 0
	history_toggle.text = "▲ 收起记录(%d)" % history_text.get_line_count() if history_panel.visible else "▼ 展开记录(%d)" % history_text.get_line_count()
	# 展开时轻微淡入动效（面板可见性切换的视觉反馈）
	if history_panel.visible and ThemeManager.animations_enabled:
		history_panel.modulate.a = 0.2
		var tw_panel := create_tween()
		tw_panel.tween_property(history_panel, "modulate:a", 1.0, 0.15)
	else:
		history_panel.modulate.a = 1.0
	# 持久化折叠状态
	GameManager.user_data.history_collapsed = not history_panel.visible
	GameManager.user_data.save_user_data()
	# 展开时滚动到底（看最新记录）
	if history_panel.visible and history_text.get_line_count() > 0:
		history_text.scroll_to_line(history_text.get_line_count() - 1)
	# 展开后清除新记录高亮
	history_toggle.remove_theme_color_override("font_color")
	# 展开提示（收起时再次提醒折叠状态）
	if history_panel.visible and unread_before > 0:
		ToastManager.info("📜 已展开历史（%d 条新记录）" % unread_before)

## === 菜单 ===
func _on_menu_pressed() -> void:
	_refresh_difficulty_option()
	_refresh_menu_title()
	# 刷新动态 tooltip（槽位概要随存档变化）
	_setup_menu_tooltips()
	menu_panel.visible = true
	# 菜单打开提示（含灵感/资源状态轻提示）
	if GameManager.user_data != null and GameManager.user_data.inspiration <= 1:
		ToastManager.info("💡 灵感仅剩 %d 点（每进一本消耗 1）" % GameManager.user_data.inspiration)
	# 世界状态预览（菜单标题下轻提示当前区域/天气）
	if world_state != null:
		var region_preview: String = str(world_state.get_variable("current_region", ""))
		if not region_preview.is_empty():
			var weather_preview: String = str(world_state.get_variable("weather", ""))
			var preview_txt := "📍%s" % region_preview
			if not weather_preview.is_empty():
				preview_txt += " · ☀%s" % weather_preview
			ToastManager.info("🌍 %s" % preview_txt)
	# 焦点到保存按钮（键盘可操作）
	var fb := get_node_or_null("MenuPanel/MenuVBox/SaveBtn")
	if fb is Button:
		(fb as Button).grab_focus()

func _on_menu_save_pressed() -> void:
	# 快速保存到自动存档（Ctrl+S 等效）
	_show_slot_selector("save")

func _on_menu_load_pressed() -> void:
	# 快速读档（含自动存档入口）
	_show_slot_selector("load")

func _on_menu_delete_pressed() -> void:
	# 删除存档入口（含自动存档保护说明）
	ToastManager.info("🗑 删除存档：可删手动槽位；自动存档保留")
	_show_slot_selector("delete")

## 角色状态面板
func _on_menu_char_pressed() -> void:
	# 面板已打开则聚焦而非重复创建
	if get_node_or_null("CharStatusDialog") != null:
		get_node_or_null("CharStatusDialog").queue_free()
	var dialog := AcceptDialog.new()
	dialog.title = "👤 角色状态"
	dialog.min_size = Vector2i(420, 580)
	dialog.name = "CharStatusDialog"
	dialog.ok_button_text = "关闭"
	add_child(dialog)
	# 打开面板时收起菜单（避免遮挡）
	menu_panel.visible = false
	# 快捷操作行（休息/背包/商店）
	var quick_row := HBoxContainer.new()
	dialog.add_child(quick_row)
	var quick_rest := Button.new()
	quick_rest.text = "⛺ 休息"
	quick_rest.flat = true
	quick_rest.tooltip_text = "推进 8 小时，回满 HP/MP"
	quick_rest.pressed.connect(func():
		dialog.queue_free()
		_on_menu_rest_pressed())
	quick_row.add_child(quick_rest)
	var quick_bag := Button.new()
	quick_bag.text = "🎒 背包"
	quick_bag.flat = true
	quick_bag.tooltip_text = "查看物品并使用药水"
	quick_bag.pressed.connect(func():
		dialog.queue_free()
		_on_menu_bag_pressed())
	quick_row.add_child(quick_bag)
	var quick_shop := Button.new()
	quick_shop.text = "🏪 商店"
	quick_shop.flat = true
	quick_shop.tooltip_text = "购买/出售物品（价格随供需波动）"
	quick_shop.pressed.connect(func():
		dialog.queue_free()
		_on_menu_shop_pressed())
	quick_row.add_child(quick_shop)
	# 角色头衔（等级 + 属性倾向）
	var title2 := Label.new()
	title2.text = "旅者"
	if combat_engine != null and not combat_engine.player_combat_stats.is_empty():
		var st2: Dictionary = combat_engine.player_combat_stats
		var char_name2: String = str(st2.get("name", "旅者"))
		# 职业称号（按属性偏向）
		var job_title := "旅者"
		var atk_v: int = int(st2.get("atk", 0))
		var def_v: int = int(st2.get("def", 0))
		var speed_v: int = int(st2.get("speed", 0))
		if atk_v >= def_v and atk_v >= speed_v:
			job_title = "剑客"
		elif def_v >= atk_v and def_v >= speed_v:
			job_title = "守卫"
		elif speed_v > atk_v and speed_v > def_v:
			job_title = "游侠"
		title2.text = "Lv.%d %s · %s" % [int(st2.get("level", 1)), char_name2, job_title]
	title2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title2.add_theme_font_size_override("font_size", 18)
	title2.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
	dialog.add_child(title2)
	# 刷新按钮（重新构建面板）
	var refresh_btn := Button.new()
	refresh_btn.text = "↻ 刷新"
	refresh_btn.flat = true
	refresh_btn.tooltip_text = "重新读取最新角色状态"
	dialog.add_child(refresh_btn)
	refresh_btn.pressed.connect(func():
		dialog.queue_free()
		_on_menu_char_pressed())
	# 内容可滚动（区块多时防溢出）
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialog.add_child(scroll)
	var list := RichTextLabel.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scroll.add_child(list)
	# 经验进度条（RichText 不支持子节点 → 追加在 scroll 内）
	var exp_bar := ProgressBar.new()
	exp_bar.max_value = 100
	exp_bar.value = 0
	exp_bar.custom_minimum_size = Vector2(0, 10)
	exp_bar.show_percentage = false
	exp_bar.visible = false
	exp_bar.name = "ExpBar"
	scroll.add_child(exp_bar)
	# HP/MP 进度条
	var hp_bar2 := ProgressBar.new()
	hp_bar2.max_value = 100
	hp_bar2.value = 0
	hp_bar2.custom_minimum_size = Vector2(0, 10)
	hp_bar2.show_percentage = false
	hp_bar2.visible = false
	hp_bar2.name = "HPBar"
	scroll.add_child(hp_bar2)
	var mp_bar2 := ProgressBar.new()
	mp_bar2.max_value = 50
	mp_bar2.value = 0
	mp_bar2.custom_minimum_size = Vector2(0, 10)
	mp_bar2.show_percentage = false
	mp_bar2.visible = false
	mp_bar2.name = "MPBar"
	scroll.add_child(mp_bar2)
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
			["经验", "%d/100" % int(ps.get("exp", 0))],
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
		# 世界标记（变量）
		if world_state and not world_state.world_variables.is_empty():
			list.append_text("\n[color=#c9a06a]世界标记（%d）[/color]\n" % world_state.world_variables.size())
			var shown := 0
			for vk in world_state.world_variables:
				if shown >= 8:
					break
				list.append_text("• %s = %s\n" % [vk, str(world_state.world_variables[vk])])
				shown += 1
			if world_state.world_variables.size() > 8:
				list.append_text("…等 %d 项\n" % world_state.world_variables.size())
		# 探索区域
		if world_state and not world_state.explored_regions.is_empty():
			list.append_text("\n[color=#c9a06a]已探索区域（%d）[/color]\n" % world_state.explored_regions.size())
			list.append_text("%s\n" % "、".join(PackedStringArray(world_state.explored_regions)))
		# 活跃世界效果
		if world_state and not world_state.active_effects.is_empty():
			list.append_text("\n[color=#c9a06a]进行中的效果（%d）[/color]\n" % world_state.active_effects.size())
			for fx in world_state.active_effects:
				var fx_id: String = str(fx.get("id", "?")) if fx is Dictionary else str(fx)
				var fx_remain: int = int(fx.get("remaining", 0)) if fx is Dictionary else 0
				list.append_text("• %s（剩 %d 小时）\n" % [fx_id, fx_remain])
		# 成就
		if GameManager.user_data.achievements.size() > 0:
			list.append_text("\n[color=#c9a06a]成就（%d）[/color]\n" % GameManager.user_data.achievements.size())
			for ach in GameManager.user_data.achievements:
				list.append_text("• 🏆 %s\n" % str(ach))
		# 本次游玩统计
		list.append_text("\n[color=#c9a06a]本次游玩[/color]\n")
		list.append_text("• 天数：第 %d 天\n" % (world_state.get_current_day() if world_state else 1))
		list.append_text("• 触发事件：%d 个（本次 %d）\n" % [(event_engine.triggered_ids.size() if event_engine != null else 0), _event_trigger_count])
		list.append_text("• 休息：%d 次\n" % _rest_count)
		if _buy_count > 0:
			list.append_text("🛒 购买物品：%d 件\n" % _buy_count)
		if _sell_count > 0:
			list.append_text("💰 出售物品：%d 件\n" % _sell_count)
		if _egg_count > 0:
			list.append_text("🗝 发现酒馆秘闻：%d 段\n" % _egg_count)
	# 敌人图鉴
	if not _enemy_codex.is_empty():
		list.append_text("\n[color=#c9a06a]敌人图鉴（本次）[/color]\n")
		for ename in _enemy_codex:
			var cnt_enc: int = int(_enemy_codex[ename])
			# 首次击败标记（次数 1 为初遇）
			var first_tag := " 🎖" if cnt_enc == 1 else ""
			list.append_text("• %s ×%d%s\n" % [ename, cnt_enc, first_tag])
		list.append_text("• 历史记录：%d 条\n" % history_text.get_line_count())
		list.append_text("• 当前进度：%d%%\n" % (int(_get_progress()[0] * 100.0 / maxf(1.0, float(_get_progress()[1])))))
	dialog.popup_centered()

## 商店弹窗（购买物品）
func _on_menu_shop_pressed() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "🏪 商店"
	dialog.min_size = Vector2i(440, 480)
	dialog.name = "ShopDialog"
	add_child(dialog)
	# 打开商店时收起菜单（避免遮挡）
	menu_panel.visible = false
	# 商店提示条（价格波动规则）
	var shop_hint := Label.new()
	shop_hint.text = "购买抬价 2% · 出售拉低 2% · 买卖差约 52%（低买高卖）"
	shop_hint.add_theme_color_override("font_color", Color(0.6, 0.55, 0.48))
	shop_hint.add_theme_font_size_override("font_size", 11)
	dialog.add_child(shop_hint)
	var box := VBoxContainer.new()
	dialog.add_child(box)
	# 刷新价格按钮（随机波动 ±20%）
	var refresh_row := HBoxContainer.new()
	box.add_child(refresh_row)
	var refresh_btn := Button.new()
	refresh_btn.text = "🔄 刷新价格"
	refresh_btn.flat = true
	refresh_btn.tooltip_text = "商人重新报价（±20% 波动）"
	refresh_btn.pressed.connect(func():
		if economy_engine != null and economy_engine.economy_data != null:
			var mid3: String = ""
			for m in economy_engine.economy_data.markets:
				mid3 = str(m.get("id", ""))
				for g in m.get("goods", []):
					var item_id3: String = str(g.get("item", ""))
					var base: float = float(g.get("price", 10))
					var new_price := base * (0.8 + randf() * 0.4)
					economy_engine.set_price(mid3, item_id3, new_price)
			ToastManager.info("💰 商人重新报价")
			_add_history("💰 商人重新报价（价格波动）")
			# 刷新涨跌统计（比刷新前）
			var up_cnt := 0
			var down_cnt := 0
			if economy_engine != null and economy_engine.economy_data != null:
				for m4 in economy_engine.economy_data.markets:
					for g4 in m4.get("goods", []):
						var iid4: String = str(g4.get("item", ""))
						var now_p: float = economy_engine.get_price(str(m4.get("id", "")), iid4)
						if now_p > float(g4.get("price", now_p)) * 1.02:
							up_cnt += 1
						elif now_p < float(g4.get("price", now_p)) * 0.98:
							down_cnt += 1
			if up_cnt > 0 or down_cnt > 0:
				_battle_log_line("📈 涨价 %d 项 · 📉 降价 %d 项" % [up_cnt, down_cnt], "#8a8278")
			# 刷新次数提示（每日可多次，价格随机波动）
			_shop_refresh_count += 1
			if _shop_refresh_count == 5:
				ToastManager.info("已刷新 5 次，价格会更随机（低买高卖机会增多）")
		dialog.queue_free()
		_on_menu_shop_pressed())
	refresh_row.add_child(refresh_btn)
	var refresh_lbl := Label.new()
	refresh_lbl.text = "（可反复刷新比价）"
	refresh_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	refresh_lbl.add_theme_font_size_override("font_size", 11)
	refresh_row.add_child(refresh_lbl)
	# 商品区可滚动（物品多时防溢出）
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inner)
	# 商品搜索框（过滤商品列表）
	var search_row_s := HBoxContainer.new()
	inner.add_child(search_row_s)
	var search_lbl_s := Label.new()
	search_lbl_s.text = "🔍"
	search_lbl_s.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	search_row_s.add_child(search_lbl_s)
	var search_edit_s := LineEdit.new()
	search_edit_s.placeholder_text = "搜索商品…"
	search_edit_s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_row_s.add_child(search_edit_s)
	var list := RichTextLabel.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(list)
	var gold := 0
	if economy_engine:
		gold = int(economy_engine.player_currencies.get("gold", 0))
	# 余额颜色：充足金色 / 紧张红色
	var gold_color := "#c9a06a" if gold >= 50 else "#e05a4e"
	list.append_text("[color=%s]持有金币: %d[/color]（背包 %d 件）\n\n" % [gold_color, gold, economy_engine.player_inventory.size() if economy_engine else 0])
	# 金币不足整体提示（<50）
	if gold < 50:
		list.append_text("[color=#e05a4e]金币紧张，先出售背包物品换钱！[/color]\n\n")
		# 一键去背包按钮
		var go_bag := Button.new()
		go_bag.text = "🎒 去背包出售"
		go_bag.flat = true
		go_bag.pressed.connect(func():
			dialog.queue_free()
			_on_menu_bag_pressed())
		inner.add_child(go_bag)
	# 购买数量选择（1-9）
	var qty_row := HBoxContainer.new()
	inner.add_child(qty_row)
	var qty_lbl := Label.new()
	qty_lbl.text = "购买数量："
	qty_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	qty_row.add_child(qty_lbl)
	var qty_spin := SpinBox.new()
	qty_spin.min_value = 1
	qty_spin.max_value = 99
	qty_spin.value = 1
	qty_spin.tooltip_text = "购买数量（1-99，×单价）；Shift 点击购买按钮买最大"
	qty_spin.custom_minimum_size.x = 70
	qty_row.add_child(qty_spin)
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
		var buy_title2 := Label.new()
		buy_title2.text = "【购买】"
		buy_title2.add_theme_color_override("font_color", Color(0.75, 0.65, 0.45))
		inner.add_child(buy_title2)
		for m in economy_engine.economy_data.markets:
			var mid: String = m.get("id", "")
			# 市场名 + 商品数
			var goods_all: Array = m.get("goods", [])
			list.append_text("[b]%s[/b]（%d 件）\n" % [m.get("name", mid), goods_all.size()])
			# 商品按价格升序显示（性价比在前）
			var goods: Array = goods_all.duplicate()
			goods.sort_custom(func(a, b):
				return economy_engine.get_price(mid, str(a.get("item", ""))) < economy_engine.get_price(mid, str(b.get("item", ""))))
			for g in goods:
				var item_id: String = g.get("item", "")
				# 搜索过滤（商品名/ID 包含关键词）
				if not search_edit_s.text.strip_edges().is_empty() \
						and not str(item_id).to_lower().contains(search_edit_s.text.strip_edges().to_lower()):
					continue
				var price: float = economy_engine.get_price(mid, item_id)
				# 难度价格修正（简单 -15% / 困难 +20%）
				var price_mul := 1.0
				match GameManager.user_data.difficulty_mode if GameManager.user_data != null else "normal":
					"easy": price_mul = 0.85
					"hard": price_mul = 1.2
				var final_price := int(price * price_mul)
				var btn := Button.new()
				btn.text = "购买 %s（%d 金币）" % [item_id, final_price]
				# 已持有数量提示
				var held_qty: int = int(economy_engine.player_inventory.get(item_id, 0))
				if held_qty > 0:
					btn.text += "（持有 %d）" % held_qty
				# 供需状态 tooltip
				var base_p: float = float(g.get("price", price))
				var supply_state := "稳定"
				if price < base_p * 0.95:
					supply_state = "供过于求（降价）"
				elif price > base_p * 1.05:
					supply_state = "供不应求（涨价）"
				btn.tooltip_text = "%s：现价 %d / 基价 %d（%s）" % [item_id, int(price), int(base_p), supply_state]
				# 商品用途描述追加
				var good_desc: String = str(g.get("description", ""))
				if not good_desc.is_empty():
					btn.tooltip_text += "\n%s" % good_desc
				btn.tooltip_text += "\n点击购买「数量」所选个"
				# 低价买入提示（现价 < 基价 10% 以上，倒卖机会）
				if price < base_p * 0.9:
					btn.tooltip_text += "\n[color=#7cc47c]低价机会：买入后价格回升可获利[/color]"
				# 商品描述 tooltip
				var item_desc: String = str(g.get("description", ""))
				if not item_desc.is_empty():
					btn.tooltip_text = item_desc
				# 价格波动标记（相对基础价）
				if price < base_p * 0.95:
					btn.text += " ↓"
					btn.tooltip_text = "低于基础价，划算！"
				elif price > base_p * 1.05:
					btn.text += " ↑"
					btn.tooltip_text = "高于基础价，可等刷新降价"
				# 批量购买（数量 × 单价）
				btn.pressed.connect(func():
					var qty_buy: int = int(qty_spin.value)
					# 数量上限提示（超出当前金币可承受量时提示）
					var gold_for_qty: int = int(economy_engine.player_currencies.get("gold", 0))
					if qty_buy > 1 and qty_buy * final_price > gold_for_qty:
						ToastManager.info("💰 金币仅够买 %d 个（已按最大可购量处理）" % maxi(0, int(gold_for_qty / maxf(1.0, float(final_price)))))
					# Shift 点击：剩余金币最大购买
					if Input.is_key_pressed(KEY_SHIFT):
						var gold_left: int = int(economy_engine.player_currencies.get("gold", 0))
						var max_buy: int = int(gold_left / maxf(1.0, float(final_price)))
						qty_buy = maxi(1, mini(9, max_buy))
					var total_price: int = final_price * qty_buy
					# 大额购买确认（≥100 金币）
					if total_price >= 100:
						var confirm_buy := ConfirmationDialog.new()
						confirm_buy.dialog_text = "确定花费 %d 金币购买 %d 个 %s？" % [total_price, qty_buy, item_id]
						confirm_buy.confirmed.connect(func():
							_do_shop_buy_qty(mid, item_id, final_price, qty_buy, dialog))
						add_child(confirm_buy)
						confirm_buy.popup_centered()
						return
					_do_shop_buy_qty(mid, item_id, int(price), qty_buy, dialog))
				# 金币不足：置灰禁用
				var gold_now: int = int(economy_engine.player_currencies.get("gold", 0))
				if gold_now < final_price:
					btn.disabled = true
					btn.tooltip_text = "金币不足（需要 %d）" % final_price
				inner.add_child(btn)
				bought_any = true
	if not bought_any:
		if not search_edit_s.text.strip_edges().is_empty():
			list.append_text("[color=#999]没有匹配「%s」的商品[/color]" % search_edit_s.text.strip_edges())
		else:
			list.append_text("[color=#999]当前市场暂无商品…[/color]")
	dialog.popup_centered()

## 清空当前角色对话历史
## 商店购买执行（支持数量；普通购买与大额确认共用）
func _do_shop_buy_qty(market_id: String, item_id: String, unit_price: int, qty: int, dialog: AcceptDialog) -> void:
	if economy_engine.buy(market_id, item_id, qty):
		ToastManager.success("已购买 %d 个 %s（剩余 %d 金币）" % [qty, item_id, int(economy_engine.player_currencies.get("gold", 0))])
		_add_history("🛒 购买 %d 个 %s" % [qty, item_id])
		_buy_count += qty
		_spawn_damage_popup(unit_price * qty, false, true)  # 购买 +金币飘字
		_add_history("💰 购买 %d 个 %s（-%d 金币）" % [qty, item_id, unit_price * qty])
		_sync_save_state()
		_on_menu_shop_pressed()  # 刷新商店
		dialog.queue_free()
	else:
		var need: int = unit_price * qty
		var have: int = int(economy_engine.player_currencies.get("gold", 0))
		# 区分金币不足与数量上限
		var cur_qty: int = int(economy_engine.player_inventory.get(item_id, 0))
		if cur_qty + qty > 99:
			ToastManager.warning("已达数量上限（99 个 %s）" % item_id)
			return
		ToastManager.warning("金币不足！需要 %d，当前 %d（差 %d）" % [need, have, maxi(0, need - have)])
		# 金币不足引导（背包/休息）
		_add_history("💰 购买失败：金币不足（需 %d）" % need)
		# 金币不足红色飘字
		_spawn_damage_popup(-need, false, false)

## 全部卖出普通物品（遗物除外）
func _do_sell_all(dialog: AcceptDialog) -> void:
	var total_gain := 0
	var sold_any := false
	for si in economy_engine.player_inventory.keys():
		if str(si) == "rare_relic":
			continue
		var qty: int = int(economy_engine.player_inventory[si])
		if qty <= 0:
			continue
		var up := 10
		if economy_engine.economy_data != null:
			for m in economy_engine.economy_data.markets:
				for g in m.get("goods", []):
					if str(g.get("item", "")) == str(si):
						up = int(economy_engine.get_price(str(m.get("id", "")), str(si)))
		total_gain += maxi(1, up / 2) * qty
		economy_engine.player_inventory[si] = 0
		sold_any = true
	if sold_any:
		economy_engine.add_currency("gold", total_gain)
		_sell_count += 1
		ToastManager.success("💰 全部卖出 +%d 金币" % total_gain)
		_add_history("💰 全部卖出 +%d 金币" % total_gain)
		_spawn_damage_popup(total_gain, false, true)  # 金币金色飘字
		_sync_save_state()
		# 卖出后商店余额同步（重开商店显示最新金币）
		_on_menu_bag_pressed()
		dialog.queue_free()
	else:
		ToastManager.info("没有可卖出的物品（遗物保留）")

## 背包查看弹窗
func _on_menu_bag_pressed() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "🎒 背包"
	dialog.min_size = Vector2i(360, 340)
	dialog.name = "BagDialog"
	add_child(dialog)
	# 打开背包时收起菜单（避免遮挡）
	menu_panel.visible = false
	var box := VBoxContainer.new()
	dialog.add_child(box)
	var title := Label.new()
	title.text = "持有物品"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	# 物品件数统计（标题旁）
	if economy_engine != null:
		var item_total_qty := 0
		for it_id in economy_engine.player_inventory:
			item_total_qty += int(economy_engine.player_inventory[it_id])
		title.text = "持有物品（共 %d 件）" % item_total_qty
	# 背包总估值（半价出售价合计）
	if economy_engine != null and not economy_engine.player_inventory.is_empty():
		var total_value := 0
		for item_id in economy_engine.player_inventory:
			var unit_v := 10
			if economy_engine.economy_data != null:
				for m in economy_engine.economy_data.markets:
					for g in m.get("goods", []):
						if str(g.get("item", "")) == str(item_id):
							unit_v = int(economy_engine.get_price(str(m.get("id", "")), str(item_id)))
							break
			total_value += maxi(1, unit_v / 2) * int(economy_engine.player_inventory[item_id])
		var val_lbl := Label.new()
		val_lbl.text = "背包估值：%d 金币（可出售）" % total_value
		val_lbl.add_theme_color_override("font_color", Color(0.8, 0.7, 0.5))
		val_lbl.add_theme_font_size_override("font_size", 11)
		val_lbl.tooltip_text = "按当前市场半价估算；实际出售价随供需波动"
		box.add_child(val_lbl)
	# 使用药水按钮（恢复 HP 的道具）
	if economy_engine != null and not economy_engine.player_inventory.is_empty():
		var use_row := HBoxContainer.new()
		box.add_child(use_row)
		var use_lbl := Label.new()
		use_lbl.text = "可使用："
		use_lbl.add_theme_color_override("font_color", Color(0.8, 0.7, 0.5))
		use_row.add_child(use_lbl)
		# 刷新背包按钮（使用/出售后状态同步）
		var bag_refresh := Button.new()
		bag_refresh.text = "↻"
		bag_refresh.flat = true
		bag_refresh.tooltip_text = "刷新背包"
		bag_refresh.pressed.connect(func():
			_on_menu_bag_pressed()
			dialog.queue_free())
		use_row.add_child(bag_refresh)
		for item_id in economy_engine.player_inventory:
			if int(economy_engine.player_inventory[item_id]) <= 0:
				continue
			if "potion" in str(item_id) or "herb" in str(item_id) or "药" in str(item_id):
				var use_btn := Button.new()
				use_btn.text = "%s ×%d" % [item_id, int(economy_engine.player_inventory[item_id])]
				use_btn.flat = true
				use_btn.tooltip_text = "使用后恢复 HP（%s）" % ("大回复" if "potion" in str(item_id) else "小回复")
				use_btn.pressed.connect(func():
					if combat_engine != null:
						var ps3: Dictionary = combat_engine.player_combat_stats
						var heal_amt := 30
						if "potion" in str(item_id):
							heal_amt = 50
						ps3["hp"] = mini(int(ps3.get("max_hp", 100)), int(ps3.get("hp", 0)) + heal_amt)
						economy_engine.player_inventory[item_id] = int(economy_engine.player_inventory[item_id]) - 1
						ToastManager.success("💊 使用 %s 恢复 %d HP" % [item_id, heal_amt])
						_add_history("💊 使用 %s 恢复 %d HP" % [item_id, heal_amt])
						_update_ui()
						_sync_save_state()
						_spawn_damage_popup(heal_amt)
						_on_menu_bag_pressed()
						dialog.queue_free())
				use_row.add_child(use_btn)
	# 出售行（所有物品半价卖出，获取金币）
	if economy_engine != null and not economy_engine.player_inventory.is_empty():
		var sell_row := HBoxContainer.new()
		box.add_child(sell_row)
		var sell_lbl := Label.new()
		sell_lbl.text = "出售："
		sell_lbl.add_theme_color_override("font_color", Color(0.8, 0.7, 0.5))
		sell_row.add_child(sell_lbl)
		# 一键全部卖出（稀有遗物除外）
		var sell_all := Button.new()
		sell_all.text = "⚡ 全部卖出"
		sell_all.flat = true
		sell_all.tooltip_text = "卖出所有普通物品（遗物除外）"
		sell_all.pressed.connect(func():
			# 全部卖出确认（防误点）
			var confirm_sell_all := ConfirmationDialog.new()
			confirm_sell_all.dialog_text = "确定卖出所有普通物品？（遗物保留）"
			confirm_sell_all.ok_button_text = "全部卖出"
			confirm_sell_all.confirmed.connect(func():
				_do_sell_all(dialog))
			add_child(confirm_sell_all)
			confirm_sell_all.popup_centered())
		sell_row.add_child(sell_all)
		# 按单价降序排列出售按钮（贵重物品优先）
		var sell_items: Array = []
		for item_id2 in economy_engine.player_inventory:
			if int(economy_engine.player_inventory[item_id2]) <= 0:
				continue
			var unit_price := 10
			if str(item_id2) == "rare_relic":
				unit_price = 100
			elif economy_engine.economy_data != null:
				for m in economy_engine.economy_data.markets:
					for g in m.get("goods", []):
						if str(g.get("item", "")) == str(item_id2):
							unit_price = int(economy_engine.get_price(str(m.get("id", "")), str(item_id2)))
			sell_items.append({"id": item_id2, "price": unit_price})
		sell_items.sort_custom(func(a, b): return a["price"] > b["price"])
		for si in sell_items:
			var item_id2: String = str(si["id"])
			var unit_price: int = int(si["price"])
			var sell_btn := Button.new()
			sell_btn.text = "%s ×%d（+%d💰）" % [item_id2, int(economy_engine.player_inventory[item_id2]), maxi(1, unit_price / 2)]
			sell_btn.flat = true
			sell_btn.tooltip_text = "按半价卖出（单价 %d）" % unit_price
			sell_btn.pressed.connect(func():
				var gain := maxi(1, unit_price / 2)
				economy_engine.add_currency("gold", gain)
				economy_engine.player_inventory[item_id2] = int(economy_engine.player_inventory[item_id2]) - 1
				ToastManager.success("💰 卖出 %s +%d 金币" % [item_id2, gain])
				_add_history("💰 卖出 %s +%d 金币" % [item_id2, gain])
				_sell_count += 1
				_spawn_damage_popup(gain, false, true)  # 卖出金币金色飘字
				_sync_save_state()
				_on_menu_bag_pressed()
				dialog.queue_free())
			sell_row.add_child(sell_btn)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var list := RichTextLabel.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scroll.add_child(list)
	if economy_engine == null or economy_engine.player_inventory.is_empty():
		list.append_text("[color=#999]背包空空如也…（商店可购买物品）[/color]")
	else:
		var total_items := 0
		var total_value := 0
		# 按物品类型排序（遗物 > 药水 > 道具 > 其他）
		var sorted_ids: Array = economy_engine.player_inventory.keys()
		sorted_ids.sort_custom(func(a, b):
			var type_a := "其他"
			var type_b := "其他"
			if str(a) == "rare_relic": type_a = "遗物"
			elif "potion" in str(a) or "herb" in str(a): type_a = "药水"
			elif "smoke" in str(a) or "bomb" in str(a): type_a = "道具"
			if str(b) == "rare_relic": type_b = "遗物"
			elif "potion" in str(b) or "herb" in str(b): type_b = "药水"
			elif "smoke" in str(b) or "bomb" in str(b): type_b = "道具"
			return ["遗物", "药水", "道具", "其他"].find(type_a) < ["遗物", "药水", "道具", "其他"].find(type_b))
		for item_id in sorted_ids:
			var qty: int = int(economy_engine.player_inventory[item_id])
			if qty > 0:
				# 物品类型标签
				var type_tag := ""
				if str(item_id) == "rare_relic":
					type_tag = " [遗物]"
				elif "potion" in str(item_id) or "herb" in str(item_id):
					type_tag = " [药水]"
				elif "smoke" in str(item_id) or "bomb" in str(item_id):
					type_tag = " [道具]"
				# 遗物不可出售标记
				var relic_tag := "（不可出售，永久加成）" if str(item_id) == "rare_relic" else ""
				list.append_text("• %s × %d%s%s\n" % [item_id, qty, type_tag, relic_tag])
				total_items += qty
				# 遗物 Tooltip 说明（持有效果）
				if str(item_id) == "rare_relic":
					list.append_text("[color=#e6c84c]  ✨ 战斗攻击 +5（永久）[/color]\n")
				if str(item_id) == "smoke_bomb":
					list.append_text("[color=#8a8278]  💨 战斗中逃跑成功率 +15%（自动消耗）[/color]\n")
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
	# 打开评分时收起菜单（避免遮挡）
	menu_panel.visible = false
	# 评分按钮显示当前评分
	var rating_btn := get_node_or_null("MenuPanel/MenuVBox/RatingBtn") as Button
	if rating_btn != null and script_data != null and script_data.rating_count > 0:
		rating_btn.text = "★ 评分（%.1f · %d 人）" % [script_data.rating, script_data.rating_count]
	# 评分提示（评分影响大厅精选排序）
	var rating_tip := Label.new()
	rating_tip.text = "评分越高越容易在「精选」榜出现"
	# 已评过分时提示当前分数
	if script_data != null and script_data.rating_count > 0:
		rating_tip.text = "当前评分 %.1f（%d 人）· 评分越高越容易在「精选」榜出现" % [script_data.rating, script_data.rating_count]
	rating_tip.add_theme_color_override("font_color", Color(0.6, 0.55, 0.48))
	rating_tip.add_theme_font_size_override("font_size", 11)
	var dialog := ConfirmationDialog.new()
	dialog.name = "RatingDialog"
	dialog.title = "评分"
	dialog.dialog_text = "为《%s》评分（当前 %.1f ★，%d 人）" % [script_data.name if script_data else "", script_data.rating if script_data else 0.0, script_data.rating_count if script_data else 0]
	# 已评过分时显示我的评分
	if GameManager.user_data != null and GameManager.user_data.rating_history.has(script_data.id if script_data else ""):
		var my_stars: int = int(GameManager.user_data.rating_history[script_data.id]["stars"])
		dialog.dialog_text += "\n（我的评分：%s）" % "★".repeat(my_stars)
	dialog.get_ok_button().text = "提交评分"
	dialog.get_cancel_button().text = "下次再说"
	# Esc 关闭视为"下次再说"（不提交）
	dialog.exclusive = true
	add_child(dialog)
	# 星级选择（HBox 5 个 ★ 按钮）
	var stars := HBoxContainer.new()
	stars.add_theme_constant_override("separation", 6)
	var chosen := [0]
	# 预填当前评分（已有评分则预选对应星）
	if script_data != null and script_data.rating_count > 0 and not _rated_this_run:
		chosen[0] = clampi(int(round(script_data.rating)), 1, 5)
		# 预选星亮起（等星星创建后应用）
		stars.ready.connect(func():
			for si in mini(5, chosen[0]):
				var sb0: Button = stars.get_child(si)
				sb0.modulate = Color(1.0, 0.85, 0.3)
				sb0.button_pressed = true)
	for i in 5:
		var b := Button.new()
		b.text = "★"
		b.modulate = Color(0.8, 0.65, 0.2)
		b.toggle_mode = true
		b.tooltip_text = "%d 星：%s" % [i + 1, ["很差", "一般", "不错", "很棒", "神作"][i]]
		b.tooltip_text = "%d 星" % (i + 1)
		b.button_group = ButtonGroup.new()
		b.pressed.connect(func():
			chosen[0] = i + 1
			# 选中星标亮度反馈（≤当前全亮，> 当前变暗）
			for si in 5:
				var sb: Button = stars.get_child(si)
				sb.modulate = Color(1.0, 0.85, 0.3) if si < chosen[0] else Color(0.5, 0.4, 0.15)
			# 星级文字提示（点击即显示所选等级）
			ToastManager.info("选择 %d 星：%s（点击确认提交）" % [chosen[0], ["很差", "一般", "不错", "很棒", "神作"][chosen[0] - 1]]))
		stars.add_child(b)
	dialog.add_child(stars)
	dialog.confirmed.connect(func():
		if chosen[0] <= 0:
			ToastManager.info("请先点击星星选择评分")
			return
		# 防重复提交（本次游玩仅一次）
		if _rated_this_run:
			ToastManager.info("本次游玩已评过分")
			return
		_rated_this_run = true
		var ws: Variant = script_data
		if ws == null:
			return
		var new_rating: float = (ws.rating * ws.rating_count + chosen[0]) / float(ws.rating_count + 1)
		ws.rating = snappedf(new_rating, 0.1)
		ws.rating_count += 1
		ScriptDataManager.update_script(ws, ["rating", "rating_count"])
		ToastManager.success("评分已提交 ★%d" % chosen[0])
		_add_history("⭐ 你给剧本评了 %d 星" % chosen[0])
		# 评分按钮即时刷新
		var rb2 := get_node_or_null("MenuPanel/MenuVBox/RatingBtn") as Button
		if rb2 != null and script_data != null and script_data.rating_count > 0:
			rb2.text = "★ 评分（%.1f · %d 人）" % [script_data.rating, script_data.rating_count]
		# 大厅精选排序数据即时生效
		GameManager.scripts_changed.emit(script_data.id)
		# 评分后本地剧本库同步（返回大厅时即时显示新评分）
		GameManager.call_deferred("reload_scripts")
		# 评分历史记录（user_data）
		if not GameManager.user_data.rating_history.has(script_data.id):
			GameManager.user_data.rating_history[script_data.id] = {}
		GameManager.user_data.rating_history[script_data.id]["stars"] = chosen[0]
		GameManager.user_data.rating_history[script_data.id]["at"] = Time.get_datetime_string_from_system()
		GameManager.user_data.save_user_data()
		# 首次评分成就
		GameManager.user_data.unlock_achievement("first_rating", "首次为剧本评分")
		# 提交后自动关闭评分弹窗
		dialog.hide())
	dialog.popup_centered()
	stars.position = Vector2(120, 70)
	# 取消评分轻提示（未打扰）
	dialog.canceled.connect(func():
		if chosen[0] > 0:
			ToastManager.info("评分未提交（可选 ★）"))

func _on_menu_back_pressed() -> void:
	# 返回确认（防误点丢失当前阅读位置）
	var confirm := ConfirmationDialog.new()
	var pnow := _get_progress()
	var prog_txt := ""
	if pnow[1] > 0:
		prog_txt = "（当前进度 %d%%）" % int(float(pnow[0]) / float(pnow[1]) * 100.0)
	var battle_note2 := "\n⚠ 当前处于战斗中，返回将放弃战斗！" if battle_panel.visible else ""
	# 返回确认含资源统计
	var res_stats := ""
	if economy_engine != null:
		var gold_back: int = int(economy_engine.player_currencies.get("gold", 0))
		var items_back: int = economy_engine.player_inventory.size()
		res_stats = "\n（💰 %d · 🎒 %d 件）" % [gold_back, items_back]
	# 返回按钮文案明确（自动保存说明）
	confirm.ok_button_text = "返回大厅并保存"
	confirm.cancel_button_text = "继续游戏"
	confirm.dialog_text = "返回大厅？将自动保存当前进度%s。%s%s" % [prog_txt, battle_note2, res_stats]
	# 灵感消耗提示（再次进入需消耗灵感）
	var insp_back: int = GameManager.user_data.inspiration if GameManager.user_data != null else 0
	if insp_back <= 1:
		confirm.dialog_text += "\n⚠ 灵感仅剩 %d 点（再次进入需消耗 1 点）" % insp_back
	# 确认信息含等级
	if combat_engine != null and not combat_engine.player_combat_stats.is_empty():
		var lv_now: int = int(combat_engine.player_combat_stats.get("level", 1))
		confirm.dialog_text += "\n（当前 Lv.%d）" % lv_now
	confirm.confirmed.connect(func():
		_sync_save_state()
		_write_progress()
		SaveManager.autosave()
		# 清理战斗状态（返回大厅）
		if combat_engine != null:
			combat_engine.reset_battle()
		# 返回自动存档时间标记（菜单保存按钮反馈）
		_last_autosave_time = Time.get_ticks_msec() / 1000.0
		menu_panel.visible = false
		var back_time: String = world_state.get_time_display() if world_state != null else ""
		ToastManager.success("已自动保存 · %s" % back_time)
		_add_history("🏠 返回大厅（已自动保存，第 %d 天）" % (world_state.get_current_day() if world_state != null else 1))
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
	# 主线 + 随机事件合并统计
	var total := script_data.event_system.story_events.size()
	var rand_events: Array = script_data.event_system.random_events if script_data.event_system.get("random_events") != null else []
	total += rand_events.size()
	if total <= 0:
		return [0, 0]
	var done := 0
	for e in script_data.event_system.story_events:
		if event_engine != null and event_engine.triggered_ids.has(e.get("id", "")):
			done += 1
	for e in rand_events:
		if event_engine != null and event_engine.triggered_ids.has(e.get("id", "")):
			done += 1
	return [done, total]

## 是否有对话框/槽位选择器打开（菜单快捷键防护）
func _no_dialog_open() -> bool:
	if get_node_or_null("SlotSelector") != null:
		return false
	if get_node_or_null("CharStatusDialog") != null:
		return false
	if get_node_or_null("RatingDialog") != null:
		return false
	if get_node_or_null("TavernPanel") != null and tavern_panel.visible:
		return false
	for c in get_children():
		if c is AcceptDialog and (c as AcceptDialog).visible:
			return false
	return true

## 关闭菜单（仅隐藏面板，不退出游戏）
## 初始化/刷新难度选项（菜单打开时同步设置页选择）
## 菜单打开时刷新标题（天数/进度）
func _refresh_menu_title() -> void:
	var title_node := menu_panel.find_child("MenuTitle", true, false)
	if title_node == null:
		return
	var script_name: String = script_data.name if script_data != null else "剧本"
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
	# 存档数统计（手动槽位已用数）
	var slot_count := 0
	for si in 3:
		if SaveManager.get_slot_info(si) != {}:
			slot_count += 1
	var slot_txt := " · 📚 %d档" % slot_count if slot_count > 0 else ""
	var region_menu := ""
	if world_state:
		var rm2: String = str(world_state.get_variable("current_region", ""))
		if not rm2.is_empty():
			region_menu = " · 📍%s" % rm2
	# 当前难度显示
	var diff_txt := ""
	if GameManager.user_data != null:
		var diff_cn := {"adaptive": "自适应", "easy": "简单", "normal": "普通", "hard": "困难"}
		diff_txt = " · 🎚%s" % str(diff_cn.get(GameManager.user_data.difficulty_mode, "普通"))
	var day_full := ""
	if world_state:
		day_full = world_state.get_time_display().get_slice(" ", 1) + " " + world_state.get_time_display().get_slice(" ", 2)
	# 世界时间完整显示（含日期/时段）
	var world_time_txt := ""
	if world_state:
		world_time_txt = " · 🕐%s" % world_state.get_time_display()
		# 世界效果标记（进行中效果）
		if not world_state.active_effects.is_empty():
			world_time_txt += " 🌪%d" % world_state.active_effects.size()
	title_node.text = "%s · %s%s%s%s%s%s%s%s" % [script_name, day_full if day_full != "" else "第 %d 天" % day, world_time_txt, region_menu, diff_txt, progress_txt, time_txt, save_txt, slot_txt]
	# 副状态行（成就/存档/玩家）
	var status_txt := ""
	var gm2: Node = Engine.get_main_loop().root.get_node_or_null("GameManager")
	if gm2 != null and gm2.user_data != null:
		status_txt += "🏆 %d/%d" % [gm2.user_data.achievements.size(), gm2.ACHIEVEMENTS.size()]
		# 灵感/资源显示（诗墨）
		status_txt += " · ✨%d 灵感 · 📜%d 诗墨" % [gm2.user_data.inspiration, gm2.user_data.shimo]
	status_txt += save_txt
	if combat_engine and not combat_engine.player_combat_stats.is_empty():
		var pst: Dictionary = combat_engine.player_combat_stats
		status_txt += " · Lv.%d ❤️%d/%d ⚡%d/%d" % [
			int(pst.get("level", 1)), int(pst.get("hp", 0)), int(pst.get("max_hp", 1)),
			int(pst.get("mp", 0)), int(pst.get("max_mp", 1))]
	if economy_engine:
		status_txt += " · 🪙 %d" % int(economy_engine.player_currencies.get("gold", 0))
		# 背包物品数
		var inv_count2: int = economy_engine.player_inventory.size()
		if inv_count2 > 0:
			status_txt += " · 🎒%d" % inv_count2
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
				# 难度中文名
				var mode_cn := {"adaptive": "自适应", "easy": "简单", "normal": "普通", "hard": "困难"}
				ToastManager.info("难度已切换：%s（下次战斗生效）" % str(mode_cn.get(modes[idx], modes[idx])))
				# 菜单标题难度显示
				_refresh_menu_title())

func _on_menu_close_pressed() -> void:
	menu_panel.visible = false
	# 关闭槽位选择器（若打开）
	var sel := get_node_or_null("SlotSelector")
	if sel:
		sel.queue_free()
	# 有未保存进度时轻提示（防遗忘）
	if _last_autosave_time > 0.0 and Time.get_ticks_msec() / 1000.0 - _last_autosave_time > 120.0:
		ToastManager.info("💾 距上次保存已超 2 分钟，可随时 S 保存")
	# 还原焦点到主界面（键盘 Esc 可继续操作）
	main_text.grab_focus()
	# 战斗进行中关闭菜单时提示（防忘记战斗）
	if battle_panel.visible:
		ToastManager.info("⚔ 战斗进行中，可继续攻击/技能/逃跑")

## 世界日志（因果标记/选择历史）
func _on_menu_log_pressed() -> void:
	var dialog := AcceptDialog.new()
	# 打开日志时收起菜单（避免遮挡）
	menu_panel.visible = false
	dialog.name = "WorldLogDialog"
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
	# 标题 tooltip：统计说明
	dialog.tooltip_text = "世界日志：因果标记=剧情关键选择；冷却=随机事件再触发倒计时"
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
	list.context_menu_enabled = true  # 右键复制
	scroll.add_child(list)
	# 历史筛选下拉（全部/事件/后果/其他）
	var filter_row := HBoxContainer.new()
	box.add_child(filter_row)
	var filter_lbl := Label.new()
	filter_lbl.text = "筛选："
	filter_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	filter_row.add_child(filter_lbl)
	var filter_opt := OptionButton.new()
	filter_opt.add_item("全部")
	filter_opt.add_item("事件")
	filter_opt.add_item("后果")
	filter_opt.add_item("其他")
	filter_opt.add_item("仅今日")
	filter_row.add_child(filter_opt)
	# 日志内关键字搜索
	var search_row := HBoxContainer.new()
	box.add_child(search_row)
	var search_lbl := Label.new()
	search_lbl.text = "搜索："
	search_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	search_row.add_child(search_lbl)
	var search_edit := LineEdit.new()
	search_edit.placeholder_text = "在日志中搜索关键字…"
	search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_row.add_child(search_edit)
	search_edit.text_changed.connect(func(_t: String):
		# 关键字过滤（与类型筛选叠加）
		var kw: String = search_edit.text.strip_edges()
		var filtered := ""
		var match_count := 0
		var full := history_text.text
		for line in full.split("\n"):
			var keeps := true
			match filter_opt.selected:
				1: keeps = line.contains("事件") or line.contains("📌") or line.contains("🎲")
				2: keeps = line.contains("后果") or line.contains("选择")
				3: keeps = not (line.contains("事件") or line.contains("后果") or line.contains("选择"))
			if not kw.is_empty() and not line.contains(kw):
				keeps = false
			if keeps and not line.strip_edges().is_empty():
				# 命中关键字高亮（金色）
				if not kw.is_empty() and line.contains(kw):
					filtered += "[color=#e6c84c]%s[/color]\n" % line
				else:
					filtered += line + "\n"
				match_count += 1
		list.clear()
		if not filtered.is_empty():
			list.append_text("[color=#8a7a68]匹配 %d 条[/color]\n\n" % match_count)
			list.append_text(filtered)
		else:
			list.append_text("[color=#999]（无匹配记录）[/color]"))
	filter_opt.item_selected.connect(func(_idx: int):
		# 按前缀过滤历史（事件/后果/其他行）
		var filtered := ""
		var match_count := 0
		var full := history_text.text
		for line in full.split("\n"):
			var keeps := true
			match filter_opt.selected:
				1: keeps = line.contains("事件") or line.contains("📌") or line.contains("🎲")
				2: keeps = line.contains("后果") or line.contains("选择")
				3: keeps = not (line.contains("事件") or line.contains("后果") or line.contains("选择"))
				4: keeps = line.contains("第 %d 天" % (world_state.get_current_day() if world_state != null else 1))
			if keeps and not line.strip_edges().is_empty():
				filtered += line + "\n"
				match_count += 1
		list.clear()
		if not filtered.is_empty():
			list.append_text("[color=#8a7a68]匹配 %d 条[/color]\n\n" % match_count)
			list.append_text(filtered)
		else:
			var fnames2 := ["全部", "事件", "后果", "其他", "仅今日"]
			list.append_text("[color=#999]（「%s」筛选下无匹配记录）[/color]" % fnames2[filter_opt.selected]))
	# 内容区顶部完整统计（标题精简后的补充信息）
	var stat_line := ""
	stat_line = "📜 历史 %d 条" % history_text.get_line_count()
	if world_state:
		stat_line += " · 🗓 %s" % world_state.get_time_display()
	if combat_engine != null and not combat_engine.player_combat_stats.is_empty():
		stat_line += " · Lv.%d" % int(combat_engine.player_combat_stats.get("level", 1))
	if event_engine:
		var causal_count: int = event_engine.causal_marks.size()
		stat_line += " · 因果标记 %d" % causal_count
		stat_line += " · 选择历史 %d" % event_engine.choices_history.size()
	# 每日统计（第 N 天 → 事件数）
	if not _history_day_stats.is_empty():
		var day_parts: Array[String] = []
		for d in _history_day_stats:
			day_parts.append("D%d:%d" % [int(d), int(_history_day_stats[d])])
		stat_line += " · 📅 %s" % " ".join(day_parts)
		# 随机事件冷却
		if event_engine.cooldowns != null and not event_engine.cooldowns.is_empty():
			stat_line += " · 冷却 %d" % event_engine.cooldowns.size()
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
		if ch.size() > 5:
			list.append_text("[color=#8a8278]…共 %d 条选择[/color]\n" % ch.size())
		list.append_text("\n")
	# 因果标记详情（默认 5 条，多时显示"查看全部"）
	if event_engine != null and not event_engine.causal_marks.is_empty():
		list.append_text("[b]【因果标记】[/b]\n")
		var cm: Array = event_engine.causal_marks
		var show_all: bool = cm.size() <= 5
		var start_cm := 0 if show_all else maxi(0, cm.size() - 5)
		for i in range(start_cm, cm.size()):
			var c2: Dictionary = cm[i]
			list.append_text("• %s = %s\n" % [c2.get("key", c2.get("id", "?")), str(c2.get("value", c2.get("state", "?")))])
		if not show_all:
			list.append_text("[color=#8a8278]…共 %d 条（%s）[/color]\n" % [cm.size(), "选择【刷新】查看最近 5 条"])
		list.append_text("\n")
	# 空状态提示
	if (event_engine == null or event_engine.choices_history.is_empty()) \
			and (event_engine == null or event_engine.causal_marks.is_empty()):
		list.append_text("[color=#999]暂无世界记录——做出选择、触发事件后将在此呈现。[/color]\n")
	# 随机事件冷却详情
	if event_engine != null and event_engine.cooldowns != null and not event_engine.cooldowns.is_empty():
		list.append_text("[b]【事件冷却】[/b]\n")
		for cid in event_engine.cooldowns:
			list.append_text("• %s：剩 %d 回合\n" % [cid, int(event_engine.cooldowns[cid])])
		list.append_text("\n")
	# 背包摘要（含遗物数）
	if economy_engine != null and not economy_engine.player_inventory.is_empty():
		var relic_count: int = int(economy_engine.player_inventory.get("rare_relic", 0))
		var bag_size: int = 0
		for it2 in economy_engine.player_inventory:
			bag_size += int(economy_engine.player_inventory[it2])
		stat_line += " · 背包 %d 件" % bag_size
		if relic_count > 0:
			stat_line += "（✨遗物×%d）" % relic_count
	# 势力关系摘要（追加到日志列表）
	if world_state != null and script_data != null and script_data.worldview != null:
		var rels: Array = script_data.worldview.faction_relationships
		if not rels.is_empty():
			var rel_line := "\n[color=#c9a06a]【势力关系】[/color]\n"
			for rel in rels:
				var fa: String = str(rel.get("faction_a", "?"))
				var fb: String = str(rel.get("faction_b", "?"))
				var relv: float = world_state.get_faction_relationship(fa, fb)
				# 关系状态标签
				var rel_state := "中立"
				var rel_color := "#c9a06a"
				if relv >= 50.0:
					rel_state = "友好"
					rel_color = "#7cc47c"
				elif relv <= -50.0:
					rel_state = "敌对"
					rel_color = "#e05a4e"
				elif relv < 0.0:
					rel_state = "紧张"
					rel_color = "#e6a23c"
				rel_line += "• %s ⇄ %s：[color=%s]%s[/color]（%+.0f）\n" % [fa, fb, rel_color, rel_state, relv]
			list.append_text(rel_line)
	var copy_btn := Button.new()
	copy_btn.text = "⧉ 复制日志"
	copy_btn.flat = true
	copy_btn.pressed.connect(func():
		DisplayServer.clipboard_set(list.text)
		ToastManager.success("日志已复制"))
	box.add_child(copy_btn)
	# 导出日志按钮（保存 txt 到用户目录）
	var export_log := Button.new()
	export_log.text = "💾 导出"
	export_log.flat = true
	export_log.pressed.connect(func():
		var out_path2 := "user://world_log_%s.txt" % Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
		var f2 := FileAccess.open(out_path2, FileAccess.WRITE)
		if f2:
			f2.store_string(list.text)
			f2.close()
			ToastManager.success("日志已导出：%s" % ProjectSettings.globalize_path(out_path2)))
	box.add_child(export_log)
	# 刷新按钮（重新打开获取最新数据）
	var refresh_log_btn := Button.new()
	refresh_log_btn.text = "↻ 刷新"
	refresh_log_btn.flat = true
	refresh_log_btn.tooltip_text = "重新读取最新世界状态"
	refresh_log_btn.pressed.connect(func():
		dialog.queue_free()
		_on_menu_log_pressed())
	box.add_child(refresh_log_btn)
	# 清空历史按钮（确认后清空）
	var clear_log_btn := Button.new()
	clear_log_btn.text = "🗑 清空历史"
	clear_log_btn.flat = true
	clear_log_btn.add_theme_color_override("font_color", Color(0.9, 0.4, 0.35))
	clear_log_btn.pressed.connect(func():
		var cfm := ConfirmationDialog.new()
		cfm.dialog_text = "确定清空全部历史记录？此操作不可撤销。"
		cfm.confirmed.connect(func():
			history_text.clear()
			_history_last_day = 0
			_add_history("📜 历史已清空")
			ToastManager.info("历史记录已清空")
			dialog.queue_free()
			_on_menu_log_pressed())
		add_child(cfm)
		cfm.popup_centered())
	box.add_child(clear_log_btn)
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
	# 战斗中不可休息（需先结束战斗）
	if battle_panel.visible:
		ToastManager.warning("战斗中无法休息！请先结束战斗")
		return
	# 休息确认（推进 8 小时，可能触发随机事件）
	var confirm := ConfirmationDialog.new()
	var hp_now2: int = 0
	var mp_now2: int = 0
	var hp_max2 := 100
	if combat_engine != null:
		hp_now2 = int(combat_engine.player_combat_stats.get("hp", 0))
		mp_now2 = int(combat_engine.player_combat_stats.get("mp", 0))
		hp_max2 = int(combat_engine.player_combat_stats.get("max_hp", 100))
	# 满血时休息提示（收益低，可考虑探索）
	var full_note := ""
	if hp_now2 >= hp_max2 and combat_engine != null:
		full_note = "\n⚠ 当前 HP 已满，休息收益较低，建议继续探索。"
	confirm.dialog_text = "⛺ 休息 8 小时？\nHP/MP 将回满（当前 %d/%d），时间推进，30% 概率遭遇随机事件。%s" % [hp_now2, mp_now2, full_note]
	# 夜晚休息事件概率说明（30%→40%）
	if world_state != null and world_state.get_period_name() == "夜晚":
		confirm.dialog_text += "\n（夜晚休息事件概率提升至 40%）"
	# 休息按钮文字明确
	confirm.ok_button_text = "休息 8 小时"
	confirm.cancel_button_text = "取消"
	confirm.confirmed.connect(func():
		menu_panel.visible = false
		_do_rest())
	add_child(confirm)
	confirm.popup_centered()

func _do_rest() -> void:
	# 防连点（1 秒内不可重复休息）
	var now_ms := Time.get_ticks_msec()
	if now_ms - _last_rest_ms < 1000:
		return
	_last_rest_ms = now_ms
	if world_state:
		# 休息后时段提示（睡醒时间）
		world_state.advance_time(8)
		ToastManager.info("🌅 醒来时已是%s" % world_state.get_period_name())
		# 天气/氛围提示
		var weather: String = str(world_state.get_variable("weather", ""))
		if not weather.is_empty():
			ToastManager.info("☀ 今日天气：%s" % weather)
		# 休息地点氛围（区域名）
		var rest_region: String = str(world_state.get_variable("current_region", ""))
		if not rest_region.is_empty():
			_add_history("⛺ 在 %s 扎营休息" % rest_region)
	var recovered_hp := 0
	var recovered_mp := 0
	if combat_engine and not (combat_engine.player_combat_stats as Dictionary).is_empty():
		var stats: Dictionary = combat_engine.player_combat_stats
		# 难度恢复倍率（困难恢复 80%）
		var rest_mul := 1.0
		match GameManager.user_data.difficulty_mode if GameManager.user_data != null else "normal":
			"hard": rest_mul = 0.8
		recovered_hp = int((int(stats.get("max_hp", 100)) - int(stats.get("hp", 0))) * rest_mul)
		recovered_mp = int((int(stats.get("max_mp", 50)) - int(stats.get("mp", 0))) * rest_mul)
		stats["hp"] = mini(int(stats.get("max_hp", 100)), int(stats.get("hp", 0)) + recovered_hp)
		stats["mp"] = mini(int(stats.get("max_mp", 50)), int(stats.get("mp", 0)) + recovered_mp)
		# 战斗状态同步（恢复满后刷新 HUD）
		_refresh_battle_ui()
	# 世界效果结算（休息跨小时，检查到期）
	if world_state:
		var expired_fx: Array = world_state.tick_effects()
		if not expired_fx.is_empty():
			ToastManager.info("🌪 世界效果结束：%s" % "，".join(PackedStringArray(expired_fx)))
	# 清理残留战斗状态（休息后退出战斗）
	if combat_engine != null and combat_engine.in_battle:
		combat_engine.reset_battle()
		if battle_panel != null:
			battle_panel.visible = false
	# 休息后自动存档（跨天节点）
	if world_state and world_state.get_current_day() != _last_rest_day:
		SaveManager.autosave()
		_add_history("⛺ 休息后自动存档（第 %d 天）" % world_state.get_current_day())
		_last_rest_day = world_state.get_current_day()
	_update_ui()
	_sync_save_state()
	var rest_time_txt: String = world_state.get_time_display() if world_state != null else ""
	ToastManager.success("⛺ 休息 8 小时：HP +%d / MP +%d · %s" % [maxi(recovered_hp, 0), maxi(recovered_mp, 0), rest_time_txt])
	# 恢复不足时提示（困难模式）
	if recovered_hp < 50 and GameManager.user_data != null and GameManager.user_data.difficulty_mode == "hard":
		ToastManager.info("困难模式：休息恢复 80%（HP +%d）" % recovered_hp)
	# 恢复飘字（绿色 +，HP 与 MP 分别）
	if recovered_hp > 0:
		_spawn_damage_popup(recovered_hp)
	if recovered_mp > 0:
		_spawn_damage_popup(recovered_mp)
	_add_history("在营地休息了 8 小时，状态恢复（HP +%d / MP +%d）" % [maxi(recovered_hp, 0), maxi(recovered_mp, 0)])
	# 跨天提示（休息前后天数不同）
	if world_state != null and _rest_start_day >= 0 and world_state.get_current_day() > _rest_start_day:
		ToastManager.info("🗓 新的一天开始了（第 %d 天）" % world_state.get_current_day())
	_rest_start_day = world_state.get_current_day() if world_state != null else -1
	_rest_count += 1
	# 休息后菜单标题刷新（时间/状态变化）
	_refresh_menu_title()
	_update_ui()
	# 休息后自动推进续跑（自动模式）
	if _auto_advance_mode:
		_auto_continue_timer.start(1.0)
	# 世界效果随休息减少 8 小时
	if world_state and not world_state.active_effects.is_empty():
		for fxid in world_state.active_effects.keys():
			var fxr: int = int(world_state.active_effects[fxid])
			fxr -= 8
			if fxr <= 0:
				world_state.active_effects.erase(fxid)
				ToastManager.info("⏳ 世界效果 %s 已结束" % fxid)
			else:
				world_state.active_effects[fxid] = fxr
	# 休息后概率触发随机事件（30%，满血时 45% 因旅途更安逸）
	var rest_event_chance := 0.3
	if world_state and world_state.get_period_name() == "夜晚":
		rest_event_chance = 0.4  # 夜晚休息更易遭遇事件
	if combat_engine != null and not combat_engine.player_combat_stats.is_empty():
		var rest_max: int = int(combat_engine.player_combat_stats.get("max_hp", 100))
		var rest_hp: int = int(combat_engine.player_combat_stats.get("hp", 0))
		if rest_max > 0 and rest_hp >= rest_max:
			rest_event_chance = 0.45
	if event_engine != null and randf() < rest_event_chance:
		ToastManager.info("⛺ 休息时发生了事件…")
		_add_history("⛺ 休息中遭遇事件")
		var random_event: Dictionary = event_engine.check_random_events()
		if not random_event.is_empty():
			_run_event(random_event)
	# 休息后任务状态检查（任务到期/完成提示）
	if script_data != null and script_data.quest_system != null:
		for qr in script_data.quest_system.quests:
			if str(qr.get("status", "")) == "active":
				ToastManager.info("📋 任务进行中：%s" % str(qr.get("name", qr.get("id", ""))))
				break

## 通关统计弹窗（天数/等级/金币/事件数）
func _show_finish_stats() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "🎉 通关！"
	dialog.min_size = Vector2i(420, 340)
	add_child(dialog)
	var list := RichTextLabel.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.context_menu_enabled = true  # 右键复制
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
	var finish_time_txt: String = world_state.get_time_display() if world_state != null else ""
	list.append_text("🗓 通关时刻：%s\n" % finish_time_txt)
	list.append_text("🎖 等级：Lv.%d\n" % lv)
	list.append_text("💰 持有金币：%d\n" % gold)
	if economy_engine != null:
		var item_count := 0
		for iid in economy_engine.player_inventory:
			item_count += int(economy_engine.player_inventory[iid])
		list.append_text("🎒 持有物品：%d 件\n" % item_count)
	list.append_text("📖 触发事件：%d 个\n" % p[0])
	# 本次游玩时长
	if _play_start_time > 0:
		var played_sec: int = int((Time.get_ticks_msec() - _play_start_time) / 1000)
		list.append_text("⏱ 游玩时长：%s\n" % _fmt_play_time(float(played_sec)))
	list.append_text("⚔ 战斗统计：胜 %d · 负 %d · 逃 %d\n" % [_battle_wins, _battle_defeats, _battle_flees])
	# 胜率显示（有战斗记录时）
	var total_battles: int = _battle_wins + _battle_defeats + _battle_flees
	if total_battles > 0:
		var win_rate := int(float(_battle_wins) / float(total_battles) * 100.0)
		list.append_text("📊 胜率 %d%%（%d 场）\n" % [win_rate, total_battles])
	if _win_streak >= 2:
		list.append_text("🔥 当前连胜：%d 场\n" % _win_streak)
	list.append_text("🔥 最高连击：x%d\n" % _best_combo)
	# 解锁成就展示
	if not GameManager.user_data.achievements.is_empty():
		list.append_text("🏆 成就：%d 个\n" % GameManager.user_data.achievements.size())
	list.append_text("\n[color=#888]感谢体验！可返回大厅查看成就与进度。[/color]")
	# 复制统计按钮
	var copy_stats_btn := Button.new()
	copy_stats_btn.text = "⧉ 复制统计"
	copy_stats_btn.pressed.connect(func():
		DisplayServer.clipboard_set(list.text)
		ToastManager.success("统计已复制"))
	dialog.add_child(copy_stats_btn)
	# 返回大厅按钮（自动保存）
	var back_stats_btn := Button.new()
	back_stats_btn.text = "🏠 返回大厅"
	back_stats_btn.pressed.connect(func():
		_sync_save_state()
		_write_progress()
		SaveManager.autosave()
		dialog.queue_free()
		SceneManager.go_back_to_hub())
	dialog.add_child(back_stats_btn)
	dialog.popup_centered()

## 属性详情弹窗（完整战斗属性/经验/效果）
func _on_player_stats_pressed() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "属性详情"
	dialog.min_size = Vector2i(420, 440)
	add_child(dialog)
	# 打开属性面板时收起菜单（避免遮挡）
	menu_panel.visible = false
	# 属性面板头部（等级/职业倾向快览）
	var head_lbl := Label.new()
	head_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head_lbl.add_theme_font_size_override("font_size", 16)
	head_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
	if combat_engine != null and not combat_engine.player_combat_stats.is_empty():
		var hst: Dictionary = combat_engine.player_combat_stats
		var htend := "均衡型"
		if int(hst.get("atk", 0)) >= int(hst.get("def", 0)) * 2:
			htend = "力量型"
		elif int(hst.get("def", 0)) >= int(hst.get("atk", 0)) * 2:
			htend = "守护型"
		head_lbl.text = "Lv.%d %s · %s" % [int(hst.get("level", 1)), str(hst.get("name", "旅者")), htend]
		# 高等级光环标记
		var hlvl: int = int(hst.get("level", 1))
		if hlvl >= 10:
			head_lbl.text += " ⭐"
		elif hlvl >= 5:
			head_lbl.text += " ✨"
	dialog.add_child(head_lbl)
	# 刷新按钮（重建面板）
	var refresh_stats_btn := Button.new()
	refresh_stats_btn.text = "↻ 刷新"
	refresh_stats_btn.flat = true
	dialog.add_child(refresh_stats_btn)
	refresh_stats_btn.pressed.connect(func():
		dialog.queue_free()
		_on_player_stats_pressed())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialog.add_child(scroll)
	var list := RichTextLabel.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.context_menu_enabled = true  # 右键复制
	scroll.add_child(list)
	if combat_engine == null or combat_engine.player_combat_stats.is_empty():
		list.append_text("[color=#999]暂无战斗属性[/color]")
		dialog.popup_centered()
		return
	# 复制属性按钮
	var copy_attr_btn := Button.new()
	copy_attr_btn.text = "⧉ 复制属性"
	copy_attr_btn.flat = true
	copy_attr_btn.pressed.connect(func():
		DisplayServer.clipboard_set(list.text)
		ToastManager.success("属性已复制"))
	dialog.add_child(copy_attr_btn)
	var st: Dictionary = combat_engine.player_combat_stats
	list.append_text("[b]等级 Lv.%d[/b]  经验 %d/100\n" % [int(st.get("level", 1)), int(st.get("exp", 0))])
	# 更新经验进度条（scroll 内的 ExpBar）
	var exp_bar2 := scroll.find_child("ExpBar", true, false) as ProgressBar
	if exp_bar2 != null:
		exp_bar2.value = mini(100, int(st.get("exp", 0)))
		exp_bar2.visible = true
	# HP/MP 进度条（HPBar/MPBar）
	var hp_prog := scroll.find_child("HPBar", true, false) as ProgressBar
	if hp_prog != null:
		hp_prog.max_value = maxi(1, int(st.get("max_hp", 100)))
		hp_prog.value = clampi(int(st.get("hp", 0)), 0, int(st.get("max_hp", 100)))
		hp_prog.visible = true
	var mp_prog := scroll.find_child("MPBar", true, false) as ProgressBar
	if mp_prog != null:
		mp_prog.max_value = maxi(1, int(st.get("max_mp", 50)))
		mp_prog.value = clampi(int(st.get("mp", 0)), 0, int(st.get("max_mp", 50)))
		mp_prog.visible = true
	list.append_text("❤️ HP %d/%d   ⚡ MP %d/%d\n" % [int(st.get("hp", 0)), int(st.get("max_hp", 1)), int(st.get("mp", 0)), int(st.get("max_mp", 1))])
	list.append_text("⚔ [color=#e0665a]攻击 %d[/color]    🛡 [color=#6a9fd8]防御 %d[/color]    🏃 [color=#7cc47c]速度 %d[/color]\n\n" % [int(st.get("atk", 0)), int(st.get("def", 0)), int(st.get("speed", 0))])
	list.append_text("「攻」：物理伤害基础\n")
	list.append_text("「防」：减免受到的伤害（至少 1）\n")
	list.append_text("「速」：决定先手与逃跑率\n\n")
	# 暴击率估算（基于速度）
	var crit_rate := 5 + int(st.get("speed", 0)) / 5
	list.append_text("🎯 暴击率 ≈ %d%%（速度影响）\n\n" % crit_rate)
	# 闪避率估算
	var dodge_rate := 3 + int(st.get("speed", 0)) / 8
	list.append_text("💨 闪避率 ≈ %d%%（速度影响）\n\n" % dodge_rate)
	# 攻防公式说明（tooltip 已在滚动列表外 → 直接文本提示）
	# 状态效果显示（角色面板）
	var char_fx: Array = st.get("status_effects", [])
	if not char_fx.is_empty():
		var fx_txt := "\n[color=#c9a06a]【状态效果】[/color]\n"
		for cfx in char_fx:
			fx_txt += "• %s（剩 %d 回合）\n" % [str(cfx.get("name", "?")), int(cfx.get("remaining_turns", 0))]
		list.append_text(fx_txt)
	# 已学技能列表
	var skills: Array = st.get("skills", [])
	if not skills.is_empty():
		var skill_txt := "\n[color=#c9a06a]【技能】[/color]\n"
		for sk in skills:
			skill_txt += "• %s（MP %d）\n" % [str(sk.get("name", sk.get("id", "?"))), int((sk.get("cost", {}) as Dictionary).get("mana", 0))]
		list.append_text(skill_txt)
	# MP/HP 概览
	list.append_text("❤️ HP %d/%d    ✦ MP %d/%d\n\n" % [
		int(st.get("hp", 0)), int(st.get("max_hp", 100)),
		int(st.get("mp", 0)), int(st.get("max_mp", 50))])
	# 护盾显示（技能获得的护盾值）
	var shield_show: int = int(st.get("shield", 0))
	if shield_show > 0:
		list.append_text("🛡 护盾：%d（减免伤害）\n\n" % shield_show)
	list.append_text("[color=#7a7268]普攻回复 +1 MP；技能消耗 MP；休息回满[/color]\n\n")
	# 元素抗性（基于属性均衡的简单换算）
	var elem_fire: int = 0
	var elem_ice: int = 0
	var elem_thunder: int = 0
	var def_total: int = int(st.get("def", 0))
	if def_total >= 30:
		elem_fire = 10
		elem_ice = 10
		elem_thunder = 10
	elif def_total >= 15:
		elem_fire = 5
		elem_ice = 5
		elem_thunder = 5
	list.append_text("🔥 火抗 %d%% · ❄ 冰抗 %d%% · ⚡ 雷抗 %d%%\n\n" % [elem_fire, elem_ice, elem_thunder])
	# 职业倾向（属性偏向判断）
	var tend := "均衡型"
	var tend_mark := "⚖"
	if int(st.get("atk", 0)) >= int(st.get("def", 0)) * 2:
		tend = "力量型（攻击专精）"
		tend_mark = "🗡"
	elif int(st.get("def", 0)) >= int(st.get("atk", 0)) * 2:
		tend = "守护型（防御专精）"
		tend_mark = "🛡"
	elif int(st.get("speed", 0)) >= int(st.get("atk", 0)) + int(st.get("def", 0)):
		tend = "敏捷型（速度专精）"
		tend_mark = "💨"
	list.append_text("%s 倾向：%s\n\n" % [tend_mark, tend])
	# 本次游玩统计（休息/事件/战斗）
	list.append_text("[color=#c9a06a]【本次冒险】[/color]\n")
	list.append_text("• 休息 %d 次 · 触发事件 %d 个\n" % [_rest_count, _event_trigger_count])
	list.append_text("• 战斗：胜 %d · 败 %d · 逃 %d\n" % [_battle_wins, _battle_defeats, _battle_flees])
	# 货币显示（金币/诗墨）
	if economy_engine != null:
		var gold_cur: int = int(economy_engine.player_currencies.get("gold", 0))
		var items_cur: int = economy_engine.player_inventory.size()
		list.append_text("• 💰 金币 %d · 🎒 物品 %d 件\n" % [gold_cur, items_cur])
	# 经验进度（每 100 经验升级）
	var exp_now: int = int(st.get("exp", 0))
	if exp_now >= 100:
		list.append_text("✨ 经验：%d/100（[color=#e6c84c]已满，战斗胜利后升级！[/color]）\n\n" % exp_now)
	else:
		list.append_text("✨ 经验：%d/100（%d%%）\n\n" % [exp_now, mini(100, int(exp_now * 100.0 / 100.0))])
	list.append_text("[b]【状态效果】[/b]\n")
	var fx: Array = st.get("status_effects", [])
	if fx.is_empty():
		list.append_text("（无）\n")
	else:
		# 效果说明映射
		var fx_desc := {
			"中毒": "每回合损失生命",
			"虚弱": "攻击力降低",
			"护盾": "减免伤害",
			"狂暴": "攻击提升但防御降低",
			"再生": "每回合恢复生命",
			"迟缓": "速度降低",
		}
		for f in fx:
			var fname: String = str(f.get("name", "?"))
			var ficon := ""
			match fname:
				"中毒": ficon = "🤢 "
				"虚弱": ficon = "😵 "
				"护盾": ficon = "🛡 "
				"狂暴": ficon = "😤 "
				"恢复": ficon = "💚 "
				"眩晕": ficon = "💫 "
			# 效果说明追加
			var fdesc: String = fx_desc.get(fname, "")
			var fdesc_txt := ""
			if not fdesc.is_empty():
				fdesc_txt = "（%s）" % fdesc
			list.append_text("• %s%s%s（剩 %d 回合）\n" % [ficon, fname, fdesc_txt, int(f.get("remaining_turns", 0))])
	list.append_text("\n[b]【金币】[/b] %d" % (int(economy_engine.player_currencies.get("gold", 0)) if economy_engine else 0))
	# 经验进度条
	var exp_bar := ProgressBar.new()
	exp_bar.max_value = 100.0
	exp_bar.value = float(int(st.get("exp", 0)))
	exp_bar.custom_minimum_size = Vector2(0, 14)
	exp_bar.tooltip_text = "经验 %d/100（每 100 升 1 级）" % int(st.get("exp", 0))
	dialog.add_child(exp_bar)
	# HP/MP 条
	var hp_bar := ProgressBar.new()
	hp_bar.max_value = maxf(1.0, float(int(st.get("max_hp", 1))))
	hp_bar.value = float(int(st.get("hp", 0)))
	hp_bar.custom_minimum_size = Vector2(0, 12)
	hp_bar.tooltip_text = "HP %d/%d" % [int(st.get("hp", 0)), int(st.get("max_hp", 1))]
	dialog.add_child(hp_bar)
	var mp_bar := ProgressBar.new()
	mp_bar.max_value = maxf(1.0, float(int(st.get("max_mp", 1))))
	mp_bar.value = float(int(st.get("mp", 0)))
	mp_bar.custom_minimum_size = Vector2(0, 12)
	mp_bar.tooltip_text = "MP %d/%d" % [int(st.get("mp", 0)), int(st.get("max_mp", 1))]
	dialog.add_child(mp_bar)
	dialog.popup_centered()

## 菜单按钮 tooltip 统一补全
func _setup_menu_tooltips() -> void:
	var tips := {
		"SaveBtn": "保存当前进度到存档槽（S）",
		"LoadBtn": "读取已保存的进度（L）",
		"DeleteBtn": "删除当前存档",
		"CharBtn": "查看角色状态与装备",
		"ShopBtn": "购买/出售物品（金币交易）",
		"ExportChatBtn": "导出酒馆对话历史为 txt",
		"BagBtn": "查看背包物品与价值",
		"RatingBtn": "为本剧本评分（1-5 星）；评分影响大厅精选排序",
		"LogBtn": "查看世界事件日志",
		"RestBtn": "休息 8 小时：回满 HP/MP，30% 概率遭遇事件，跨天自动存档",
		"PlayerStatsBtn": "查看完整战斗属性与经验",
		"HelpBtn": "查看操作帮助与快捷键（H）",
		"BackBtn": "返回大厅（B 键，自动保存）",
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
	dialog.title = "❓ 操作帮助"
	# 打开帮助时收起菜单（避免遮挡）
	menu_panel.visible = false
	# 打字机跳过状态保存（帮助关闭后恢复）
	var typewriter_paused: bool = not _typewriter_done
	# 帮助打开时暂停自动推进（避免错过选择）
	var auto_paused: bool = _auto_advance_mode
	if auto_paused:
		_auto_advance_mode = false
	dialog.dialog_text = """【基本操作】
- 点击 / 空格 / 回车：继续剧情、跳过打字机
- A：切换自动推进（打字完成后自动继续，遇选择暂停）
- H：随时打开本帮助
- C：打开角色状态面板
- T：快捷打开 / 关闭酒馆
- Q：使用背包药水（战斗中恢复 HP）
- Esc：打开 / 关闭菜单
- 顶部菜单：存档 / 读档 / 酒馆对话 / 评分
- 菜单中：S 保存 · L 读档 · B 返回大厅

【战斗】
- 遭遇敌人后出现战斗面板：攻击 / 技能 / 逃跑
- 数字键 1-9：直接释放对应技能（MP 不足自动改普攻）
- 普攻回复 MP +2；MP 飘字提示
- 自动战斗按钮：连续点击可调速（1x/2x/4x）
- Tab / 点击敌人栏：切换攻击目标（多敌人时）
- 技能需消耗 MP，魔力不足会置灰禁用
- 敌人强度有评估（危险/适中/轻松），打不过可逃跑

【酒馆 🏮】
- 与旅店老板娘 / 老学者对话，了解世界观线索
- 多聊天提升好感度（亲密后解锁往事与礼物）
- 试试聊「遗物 / 命运 / 酒 / 世界」有隐藏回应
- 指令：/h 历史 · /c 清空 · /mood 好感 · /help 帮助
- 对话历史自动保存

【商店 🏪】
- 购买物品（价格随供需波动），出售背包物品换金币
- Shift 点击购买：用剩余金币买最多数量
- 商品搜索框可快速过滤商品
- 价格刷新按钮：商人重新报价（±20% 波动）

【难度 🎚】
- 简单：敌人弱 20%、奖励 ×0.8、商店便宜 15%
- 普通：标准体验
- 困难：敌人强 35%、奖励 ×1.3、商店贵 20%、休息只回 80%
- 自适应：随角色等级动态调整（推荐）

【提示】
- 每 5 分钟自动存档（可在设置调整），退出前建议手动保存
- 存档槽 3 个 + 独立自动存档（自动覆盖）
- 休息跨天自动存档；返回大厅自动保存
- 剧本进度会同步到大厅卡片进度条

【世界 🌍】
- 探索触发事件；连续探索有奖励
- 世界效果（🌪）影响战斗与事件，休息时结算
- 势力关系影响对话与事件走向
- 通关所有事件解锁成就"""
	dialog.min_size = Vector2i(620, 560)
	add_child(dialog)
	# 帮助文本放入滚动容器（长文本可滚动）
	var help_scroll := ScrollContainer.new()
	help_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialog.add_child(help_scroll)
	# 记忆上次滚动位置（关闭后重开保持）
	help_scroll.scroll_vertical = _help_scroll_pos
	dialog.closed.connect(func():
		_help_scroll_pos = help_scroll.scroll_vertical)
	var help_lbl := RichTextLabel.new()
	help_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	help_lbl.fit_content = true
	help_lbl.bbcode_enabled = true
	# 快捷键加粗高亮（帮助文本中按键名加粗金色）
	var help_txt: String = dialog.dialog_text
	for key in ["空格", "回车", "A", "H", "C", "T", "Q", "Esc", "S", "L", "B", "1-9", "Tab", "Shift"]:
		help_txt = help_txt.replace(key, "[b][color=#e6c84c]%s[/color][/b]" % key)
	help_lbl.text = help_txt + "\n\n[color=#8a8278]万界 · v1.2.0（体验版）[/color]"
	# 字体大小随设置
	var help_fs := 14
	match GameManager.user_data.font_size_preset:
		"small": help_fs = 12
		"large": help_fs = 17
	help_lbl.add_theme_font_size_override("normal_font_size", help_fs)
	help_scroll.add_child(help_lbl)
	# 复制帮助按钮
	var copy_help := Button.new()
	copy_help.text = "⧉ 复制帮助"
	copy_help.flat = true
	copy_help.pressed.connect(func():
		DisplayServer.clipboard_set(dialog.dialog_text)
		ToastManager.success("帮助已复制"))
	dialog.add_child(copy_help)
	# 帮助关闭恢复自动推进
	dialog.closed.connect(func():
		if auto_paused:
			_auto_advance_mode = true
		# 打字机恢复（若之前未完成）
		if typewriter_paused:
			_typewriter_done = false)
	dialog.dialog_text = ""
	dialog.popup_centered()

## 显示槽位选择器
func _show_slot_selector(mode: String) -> void:
	var old := get_node_or_null("SlotSelector")
	if old:
		old.queue_free()

	var selector := PanelContainer.new()
	selector.name = "SlotSelector"
	# 槽位选择器标题 tooltip
	selector.tooltip_text = "存档槽：手动保存位置；自动存档每 5 分钟（可设置调整）"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.96, 0.925, 0.843, 0.98)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(16)
	style.shadow_color = Color(0.29, 0.216, 0.157, 0.2)
	style.shadow_size = 10
	selector.add_theme_stylebox_override("panel", style)
	selector.custom_minimum_size = Vector2(360, 320)
	selector.set_anchors_preset(Control.PRESET_CENTER)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	selector.add_child(vbox)

	var title_label := Label.new()
	title_label.text = "选择存档槽位" if mode == "save" else ("选择加载槽位" if mode == "load" else "选择删除槽位")
	# 副标题统计（已用槽位）
	var used_slots := 0
	for si3 in 3:
		if _get_slot_info(si3) != "(空)":
			used_slots += 1
	title_label.tooltip_text = "已使用 %d/3 个槽位 · 自动存档独立" % used_slots
	# 槽位空态引导（保存模式且全空时）
	if mode == "save" and used_slots == 0:
		var empty_note := Label.new()
		empty_note.text = "💡 尚无存档，保存后将在此继续游戏"
		empty_note.add_theme_color_override("font_color", Color(0.75, 0.65, 0.5))
		empty_note.add_theme_font_size_override("font_size", 11)
		vbox.add_child(empty_note)
	# 槽位已满提示（保存模式）
	if mode == "save" and used_slots >= 3:
		var full_note := Label.new()
		full_note.text = "⚠ 3 个槽位已满：保存将覆盖所选槽位"
		full_note.add_theme_color_override("font_color", Color(0.85, 0.55, 0.2))
		full_note.add_theme_font_size_override("font_size", 11)
		vbox.add_child(full_note)
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)

	for slot in 3:
		var btn := Button.new()
		var slot_info := _get_slot_info(slot)
		btn.text = "槽位 %d: %s" % [slot + 1, slot_info]
		btn.tooltip_text = "槽位 %d 详情：%s（点击可%s）" % [slot + 1, slot_info, "保存" if mode == "save" else ("读取" if mode == "load" else "删除")]
		btn.custom_minimum_size = Vector2(0, 40)
		# 空槽位样式（浅色提示可保存）
		if slot_info == "(空)" and mode == "save":
			btn.text = "槽位 %d:（空 — 点击保存到此处）" % (slot + 1)
		# 读档/删除模式：空槽位禁用
		if slot_info == "(空)" and mode != "save":
			btn.disabled = true
			btn.tooltip_text = "该槽位为空，无可操作存档"
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
		var sep := HSeparator.new()
		vbox.add_child(sep)
		var auto_info := SaveManager.get_slot_info(0, true)
		var auto_txt := "(空)"
		if not auto_info.is_empty():
			var apct := ""
			var ap: float = float(auto_info.get("progress", 0.0))
			if ap > 0.0:
				apct = " | %d%%" % int(ap * 100.0)
			auto_txt = "%s | Lv.%d%s | %s%s" % [
				auto_info.get("player_name", "?"), auto_info.get("level", 1), apct, _fmt_play_time(auto_info.get("play_time", 0)),
				(" | 第 %d 天" % int(auto_info.get("day", 1))) if auto_info.has("day") else ""]
		var auto_btn := Button.new()
		auto_btn.text = "自动存档: %s" % auto_txt
		# 自动存档图标（已有存档时）
		if not auto_info.is_empty():
			auto_btn.text = "⏱ 自动存档: %s" % auto_txt
		if not auto_info.is_empty():
			var auto_saved: String = str(auto_info.get("saved_at", "无"))
			auto_btn.tooltip_text = "上次自动保存：%s（每小时自动覆盖，无需手动管理）" % auto_saved.substr(5, 5) if auto_saved.length() >= 10 else auto_saved
		else:
			auto_btn.tooltip_text = "尚无自动存档"
		auto_btn.custom_minimum_size = Vector2(0, 40)
		match mode:
			"save":
				auto_btn.pressed.connect(func():
					SaveManager.autosave()
					_add_history("已保存到自动存档")
					selector.queue_free()
					menu_panel.visible = false
					var time_txt2: String = world_state.get_time_display() if world_state != null else ""
					ToastManager.success("已自动保存 · %s" % time_txt2))
			"load":
				auto_btn.pressed.connect(func():
					var sd2: SaveData = SaveManager.load_game(0, true)
					if sd2 == null:
						ToastManager.warning("自动存档不存在")
						return
					ToastManager.success("⏱ 已从自动存档恢复")
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
		selector.scale = Vector2(0.95, 0.95)
		selector.pivot_offset = selector.size / 2.0
		var stw := create_tween()
		stw.set_parallel(true)
		stw.tween_property(selector, "modulate:a", 1.0, 0.15)
		stw.tween_property(selector, "scale", Vector2.ONE, 0.15)

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
	return "%s | Lv.%d%s | %s%s%s%s" % [
		save_info.get("player_name", "?"),
		save_info.get("level", 1),
		prog_pct,
		_fmt_play_time(save_info.get("play_time", 0)),
		(" | 第 %d 天" % int(save_info.get("day", 1))) if save_info.has("day") else "",
		(" | 💰%d" % int(save_info.get("gold", 0))) if save_info.has("gold") else "",
		(" | %s" % str(save_info.get("saved_at", "")).substr(5, 5)) if save_info.has("saved_at") else ""]

## 槽位保存
func _on_slot_save_selected(slot: int) -> void:
	# 覆盖已有存档确认
	if _get_slot_info(slot) != "(空)":
		var confirm_ov := ConfirmationDialog.new()
		confirm_ov.dialog_text = "槽位 %d 已有存档（%s），确定覆盖？" % [slot + 1, _get_slot_info(slot)]
		# 覆盖按钮明确文字
		confirm_ov.ok_button_text = "覆盖保存"
		confirm_ov.cancel_button_text = "取消"
		confirm_ov.confirmed.connect(func():
			_do_save_slot(slot))
		add_child(confirm_ov)
		confirm_ov.popup_centered()
		return
	_do_save_slot(slot)

## 槽位保存执行
func _do_save_slot(slot: int) -> void:
	var ok := SaveManager.save_game(slot)
	if ok:
		_last_autosave_time = Time.get_ticks_msec() / 1000.0
		# 保存完成提示（含槽位名）
		ToastManager.success("💾 已保存到槽位 %d" % (slot + 1))
		_add_history("游戏已保存到槽位 %d（第 %d 天）" % [slot + 1, world_state.get_current_day() if world_state else 1])
		var time_txt: String = world_state.get_time_display() if world_state != null else ""
		# 保存含当前剧情进度
		var prog := _get_progress()
		var prog_pct := 0
		if prog[1] > 0:
			prog_pct = int(prog[0] * 100.0 / float(prog[1]))
		ToastManager.success("已保存到槽位 %d · %s · 进度 %d%%" % [slot + 1, time_txt, prog_pct])
		# 手动保存后重置自动存档计时（避免紧接重复存档）
		var ast := get_node_or_null("AutoSaveTimer") as Timer
		if ast != null:
			ast.start()
		# 保存后刷新 HUD 与菜单
		_update_ui()
		_refresh_menu_title()
	else:
		ToastManager.warning("保存失败（磁盘空间不足或目录不可写）")
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
	# 删除确认按钮文字（红色警示）
	confirm.ok_button_text = "确认删除"
	confirm.cancel_button_text = "取消"
	confirm.confirmed.connect(func():
		SaveManager.delete_save(script_data.id if script_data else "", slot)
		ToastManager.success("存档已删除")
		_add_history("🗑 已删除槽位 %d 存档" % (slot + 1))
		# 删除后刷新槽位列表
		var slot_sel := get_node_or_null("SlotSelector")
		if slot_sel:
			_show_slot_selector("delete")
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
	var battle_note := "（当前战斗中的进度将被放弃）" if battle_panel.visible else ""
	confirm.dialog_text = "从槽位 %d 加载？当前未保存进度将被覆盖。%s" % [slot + 1, battle_note]
	confirm.confirmed.connect(func():
		var sd3: SaveData = SaveManager.load_game(slot)
		if sd3 == null:
			ToastManager.warning("读取失败")
			return
		ToastManager.success("📂 已读取槽位 %d 存档" % (slot + 1))
		_restore_save_state(sd3)
		# 关闭槽位选择器并刷新
		var slot_sel2 := get_node_or_null("SlotSelector")
		if slot_sel2:
			slot_sel2.queue_free()
		_update_ui()
		_refresh_menu_title()
		_add_history("已从槽位 %d 加载" % (slot + 1))
		var day_loaded: int = world_state.get_current_day() if world_state else 1
		# 加载含进度与等级
		var lv_loaded: int = 1
		if combat_engine != null and not combat_engine.player_combat_stats.is_empty():
			lv_loaded = int(combat_engine.player_combat_stats.get("level", 1))
		ToastManager.success("已从槽位 %d 加载（第 %d 天 · Lv.%d）" % [slot + 1, day_loaded, lv_loaded])
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
