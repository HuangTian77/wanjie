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
@onready var chain_label: Label = %ChainLabel

func _ready() -> void:
	_init_engines()
	_start_experience()
	history_toggle.pressed.connect(_on_history_toggle_pressed)
	ToastManager.info("已消耗 1 点灵感进入剧本")
	# 定时自动存档（每 5 分钟）
	var auto_save_timer := Timer.new()
	auto_save_timer.wait_time = 300.0
	auto_save_timer.autostart = true
	auto_save_timer.timeout.connect(func():
		_sync_save_state()
		SaveManager.autosave()
		ToastManager.success("已自动存档"))
	add_child(auto_save_timer)

func _process(delta: float) -> void:
	# 自动战斗：定时攻击（0.6s 间隔）
	if _auto_battle and battle_panel.visible and combat_engine != null and combat_engine.is_active:
		_auto_timer += delta
		if _auto_timer >= 0.6:
			_auto_timer = 0.0
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
		menu_panel.visible = not menu_panel.visible
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
		# 当前事件链
		if world_state:
			var chain: String = str(world_state.get_variable("current_chain", ""))
			if not chain.is_empty():
				chain_label.text = "🔗 %s" % chain
				chain_label.visible = true
		# 剧情进度（基于事件完成度）
		var p := _get_progress()
		if p[1] > 0:
			progress_label.text = "📊 %d%%" % int(float(p[0]) / float(p[1]) * 100.0)
			progress_label.visible = true
			# 通关提示（全部事件触发一次）
			if p[0] >= p[1] and not _ending_shown:
				_ending_shown = true
				ToastManager.success("🎉 剧情全部体验完毕！")
				GameManager.unlock_achievement("finish_any_script")
		# MP 进度条
		var max_mp: int = ps.get("max_mp", 50)
		mp_bar.max_value = max_mp
		mp_bar.value = max_mp
		# 金币
		var inv: Dictionary = ps.get("inventory", {})
		player_gold_label.text = "金币: %d" % inv.get("gold", 0)
	if world_state:
		time_label.text = "🗓 " + world_state.get_time_display()

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
	_sync_save_state()
	_advance_to_next_event()

func _on_continue_exploring() -> void:
	_sync_save_state()
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
	tavern_char_select.clear()
	for i in TAVERN_CHARS.size():
		tavern_char_select.add_item(TAVERN_CHARS[i]["name"], i)
	tavern_char_select.item_selected.connect(_on_tavern_char_selected)
	_enter_tavern_char(0)
	tavern_input.grab_focus()

func _on_tavern_close_pressed() -> void:
	TavernManager.end_dialog()
	tavern_panel.visible = false

func _on_tavern_char_selected(index: int) -> void:
	_enter_tavern_char(index)

func _enter_tavern_char(index: int) -> void:
	tavern_msgs.clear()
	var char: Dictionary = TAVERN_CHARS[index]
	TavernManager.start_dialog(char)
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
	# 本地演示回复（真实 LLM 接入可替换为 LLMClient 调用）
	var reply := _tavern_mock_reply(text)
	TavernManager.dialog_history.append({"role": "assistant", "content": reply})
	_tavern_append("assistant", reply)
	TavernManager.save_history()

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
	_refresh_battle_ui()
	_battle_log_line("战斗开始！遭遇 %d 个敌人" % enemies.size())
	menu_panel.visible = false

func _on_combat_round_started(round_num: int) -> void:
	_battle_log_line("[color=#c9a06a]第 %d 回合[/color]" % round_num)
	_refresh_battle_ui()

func _on_combat_action_taken(_actor: Dictionary, _action: Dictionary) -> void:
	_refresh_battle_ui()

func _on_combat_ended(result: String) -> void:
	battle_panel.visible = false
	_sync_save_state()
	var msg := "战斗胜利！" if result == "victory" else ("战斗失败…" if result == "defeat" else "成功逃跑")
	# 胜利奖励（经验/金币）——奖励应用并提示
	if result == "victory" and combat_engine != null:
		var rewards: Dictionary = combat_engine.get_rewards()
		var gold: int = int(rewards.get("gold", 0))
		var exp: int = int(rewards.get("experience", 0))
		if economy_engine != null and gold > 0:
			economy_engine.add_currency("gold", gold)
			msg = "战斗胜利！获得 %d 金币、%d 经验" % [gold, exp]
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
				ToastManager.success("🎉 升级！Lv.%d（HP/MP 回满）" % int(stats.get("level", 1)))
				msg += " 🎉 升级 Lv.%d！" % int(stats.get("level", 1))
			_sync_save_state()
	_add_history(msg)
	_set_main_text("[b]战斗结束：%s[/b]" % msg)
	_clear_choices()
	if result == "defeat":
		# 失败：提供重试（读自动存档恢复状态）
		ToastManager.warning("你已阵亡… 进度已保存，可读档重试")
		_add_choice_button("🔄 重试（读档）", "_on_retry_from_save")
	elif result == "fled":
		ToastManager.info("成功逃离战场")
		_add_choice_button("继续", "_on_continue_pressed")
	else:
		# 战斗结束后提供"继续"推进剧情
		_add_choice_button("继续", "_on_continue_pressed")

## 战斗失败重试：读自动存档恢复
func _on_retry_from_save() -> void:
	var sd: SaveData = SaveManager.load_game(0, true)
	if sd == null:
		ToastManager.warning("无自动存档，无法重试")
		return
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
	ToastManager.success("已从自动存档恢复")
	_add_history("重新振作，继续冒险…")
	_advance_to_next_event()

func _battle_log_line(line: String) -> void:
	battle_log.append_text(line + "\n")

func _refresh_battle_ui() -> void:
	if combat_engine == null:
		return
	var parts: Array[String] = []
	var alive := 0
	for e in combat_engine.enemies:
		if e.get("is_alive", true):
			alive += 1
			parts.append("%s HP:%d/%d" % [e.get("name", "?"), int(e.get("hp", 0)), int(e.get("max_hp", 1))])
	enemy_info.text = "敌人：%s" % ("；".join(parts) if parts.is_empty() == false else "（无）")
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

func _on_battle_attack_pressed() -> void:
	if combat_engine == null:
		return
	var res: Dictionary = combat_engine.player_attack(0)
	if not res.is_empty():
		_battle_log_line("%s 攻击造成 %d 伤害" % [combat_engine.player_combat_stats.get("name", "你"), res.get("damage", 0)])
		_spawn_damage_popup(-int(res.get("damage", 0)))
	_refresh_battle_ui()

## 伤害飘字（战斗手感：上浮淡出）
func _spawn_damage_popup(amount: int) -> void:
	if enemy_info == null or not enemy_info.is_visible_in_tree():
		return
	var lbl := Label.new()
	var color := Color(0.95, 0.4, 0.35) if amount < 0 else Color(0.35, 0.9, 0.45)
	lbl.text = ("-%d" % absi(amount)) if amount < 0 else ("+%d" % amount)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.position = enemy_info.global_position + Vector2(randf_range(20, 120), -10)
	lbl.z_index = 100
	add_child(lbl)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 46, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
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
		# 显示 MP 消耗
		var mana_cost: int = int((s.get("cost", {}) as Dictionary).get("mana", 0))
		var label: String = s.get("name", sid)
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
		combat_engine.player_use_skill(skills[id].get("id", ""), 0)
		_refresh_battle_ui())
	add_child(menu)
	menu.popup(Rect2i(0, 0, 0, 0))
	menu.position = Vector2i(get_viewport().get_visible_rect().size / 2) - Vector2i(100, 50)

func _on_battle_flee_pressed() -> void:
	if combat_engine != null:
		combat_engine.try_flee()

## 自动战斗开关
func _on_battle_auto_pressed() -> void:
	_auto_battle = not _auto_battle
	if _auto_battle:
		_auto_timer = 0.0
		ToastManager.info("自动战斗开启")
	else:
		ToastManager.info("自动战斗关闭")

## === 历史记录折叠 ===
func _on_history_toggle_pressed() -> void:
	history_panel.visible = not history_panel.visible
	history_toggle.text = "▲ 收起记录" if history_panel.visible else "▼ 展开记录"

## === 菜单 ===
func _on_menu_pressed() -> void:
	_refresh_difficulty_option()
	_refresh_menu_title()
	menu_panel.visible = true

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
	dialog.min_size = Vector2i(360, 340)
	add_child(dialog)
	var list := RichTextLabel.new()
	dialog.add_child(list)
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
	dialog.popup_centered()

## 商店弹窗（购买物品）
func _on_menu_shop_pressed() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "商店"
	dialog.min_size = Vector2i(420, 360)
	add_child(dialog)
	var box := VBoxContainer.new()
	dialog.add_child(box)
	var list := RichTextLabel.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(list)
	var gold := 0
	if economy_engine:
		gold = int(economy_engine.player_currencies.get("gold", 0))
	list.append_text("[color=#c9a06a]持有金币: %d[/color]\n\n" % gold)
	var bought_any := false
	# === 出售区（背包物品半价卖出） ===
	var sell_title := Label.new()
	sell_title.text = "【出售】"
	sell_title.add_theme_color_override("font_color", Color(0.55, 0.65, 0.85))
	box.add_child(sell_title)
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
				if economy_engine.sell("market_1", item_id):
					ToastManager.success("已出售 %s +%d 金币" % [item_id, int(price)])
					_sync_save_state()
					_on_menu_shop_pressed()
					dialog.queue_free()
				else:
					ToastManager.warning("出售失败"))
			box.add_child(sell_btn)
			sold_any = true
	if not sold_any:
		var no_sell := Label.new()
		no_sell.text = "（背包为空，无可出售物品）"
		no_sell.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		no_sell.add_theme_font_size_override("font_size", 11)
		box.add_child(no_sell)
	if economy_engine and economy_engine.economy_data:
		for m in economy_engine.economy_data.markets:
			var mid: String = m.get("id", "")
			list.append_text("[b]%s[/b]\n" % m.get("name", mid))
			for g in m.get("goods", []):
				var item_id: String = g.get("item", "")
				var price: float = economy_engine.get_price(mid, item_id)
				var btn := Button.new()
				btn.text = "购买 %s（%d 金币）" % [item_id, int(price)]
				btn.pressed.connect(func():
					if economy_engine.buy(mid, item_id):
						ToastManager.success("已购买 %s" % item_id)
						_sync_save_state()
						_on_menu_shop_pressed()  # 刷新商店
						dialog.queue_free()
					else:
						ToastManager.warning("金币不足！"))
				box.add_child(btn)
				bought_any = true
	if not bought_any:
		list.append_text("[color=#999]当前市场暂无商品…[/color]")
	dialog.popup_centered()

## 背包查看弹窗
func _on_menu_bag_pressed() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "背包"
	dialog.min_size = Vector2i(360, 300)
	add_child(dialog)
	var box := VBoxContainer.new()
	dialog.add_child(box)
	var title := Label.new()
	title.text = "持有物品"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var list := RichTextLabel.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(list)
	if economy_engine == null or economy_engine.player_inventory.is_empty():
		list.append_text("[color=#999]背包空空如也…[/color]")
	else:
		for item_id in economy_engine.player_inventory:
			var qty: int = int(economy_engine.player_inventory[item_id])
			if qty > 0:
				list.append_text("• %s × %d\n" % [item_id, qty])
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
		b.pressed.connect(func(): chosen[0] = i + 1)
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
	_sync_save_state()
	_write_progress()
	SaveManager.autosave()
	menu_panel.visible = false
	ToastManager.success("已自动保存")
	SceneManager.go_back_to_hub()

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
	var progress_txt := ""
	if p[1] > 0:
		progress_txt = " · %d%%" % int(float(p[0]) / float(p[1]) * 100.0)
	title_node.text = "游戏菜单 · 第 %d 天%s" % [day, progress_txt]

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

## 世界日志（因果标记/选择历史）
func _on_menu_log_pressed() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "世界日志"
	dialog.min_size = Vector2i(400, 360)
	add_child(dialog)
	var list := RichTextLabel.new()
	dialog.add_child(list)
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
				list.append_text("• %s\n" % str(cm.get("mark", cm)))
				has_any = true
		if not event_engine.choices_history.is_empty():
			list.append_text("\n[b]【选择历史】[/b]\n")
			for ch in event_engine.choices_history:
				var cid: String = str(ch.get("choice_id", ch.get("choice", "")))
				var eid: String = str(ch.get("event_id", ""))
				list.append_text("• %s（%s）\n" % [cid, eid])
				has_any = true
	if not has_any:
		list.append_text("[color=#999]暂无世界事件记录…[/color]")
	dialog.popup_centered()

## 休息：时间推进 + 回满状态
func _on_menu_rest_pressed() -> void:
	if world_state:
		world_state.advance_time(8)
	if combat_engine and not (combat_engine.player_combat_stats as Dictionary).is_empty():
		var stats: Dictionary = combat_engine.player_combat_stats
		stats["hp"] = stats.get("max_hp", 100)
		stats["mp"] = stats.get("max_mp", 50)
	_update_ui()
	_sync_save_state()
	ToastManager.success("休息片刻，HP/MP 已回满")
	_add_history("在营地休息了 8 小时，状态恢复")

## 操作帮助弹窗
func _on_menu_help_pressed() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "操作帮助"
	dialog.dialog_text = """【基本操作】
- 点击 / 空格 / 回车：继续剧情、跳过打字机
- 顶部菜单：存档 / 读档 / 酒馆对话 / 评分

【战斗】
- 遭遇敌人后出现战斗面板：攻击 / 技能 / 逃跑
- 技能需消耗 MP，魔力不足无法释放

【酒馆 🏮】
- 与旅店老板娘 / 老学者对话，了解世界观线索
- 对话历史自动保存

【提示】
- 每 5 分钟自动存档，退出前建议手动保存
- 剧本进度会同步到大厅卡片进度条"""
	dialog.min_size = Vector2i(480, 360)
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
	selector.custom_minimum_size = Vector2(320, 220)
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
		btn.custom_minimum_size = Vector2(0, 40)
		match mode:
			"save":
				btn.pressed.connect(_on_slot_save_selected.bind(slot))
			"load":
				btn.pressed.connect(_on_slot_load_selected.bind(slot))
			"delete":
				btn.pressed.connect(_on_slot_delete_selected.bind(slot))
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

## 槽位删除（带确认）
func _on_slot_delete_selected(slot: int) -> void:
	var slot_info := _get_slot_info(slot)
	if slot_info == "(空)":
		return
	var confirm := ConfirmationDialog.new()
	confirm.dialog_text = "确定删除槽位 %d 的存档吗？此操作不可恢复。" % (slot + 1)
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
		SaveManager.load_game(slot)
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
