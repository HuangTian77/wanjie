## mud_global_config.gd
## 全局配置对话框（对应 ME loader/globalconfig/globalConfig.html/.lua）
##
## 7 标签：游戏设置 / 地图设置 / 战斗设置 / 技能设置 / 导航栏 / 脚本 / 分享奖励。
## 读写 MudData 的 config 键值表（config_get/config_set），导出经 mud_export 各 load_* 消费：
##   game_title/game_version/goods_use_equip_tab/game_debug_trace_log（GameInfo/Setting）
##   game_born_point/map_move_time/map_move_show_log（Navigation/Setting）
##   campaign_default_fail_trigger/campaign_property（NPCCombat/CombatProperty）
##   skill_default_enemy_skill（NPC，-1 表示禁用）
##   navigation/multiple_script/share_reward（Navigation/OnlineFunc/Exchange）
class_name MudGlobalConfig
extends MudEditDialogBase

# ---- 游戏设置 ----
var _game_title: LineEdit
var _game_version: LineEdit
var _equip_tab: CheckBox
var _trace_log: CheckBox

# ---- 地图设置 ----
var _born_point: OptionButton
var _move_time: SpinBox
var _move_log: CheckBox

# ---- 战斗设置 ----
var _fail_trigger: MudTriggerEditor   # RESULT 行（campaign_default_fail_trigger）
var _campaign_property: TextEdit      # JSON

# ---- 技能设置 ----
var _skill_enable: CheckBox
var _skill_select: OptionButton

# ---- 导航栏 / 脚本 / 分享奖励 ----
var _navigation: TextEdit
var _multiple_script: TextEdit
var _share_reward: TextEdit


func _init() -> void:
	super._init()
	min_size = Vector2(820, 600)


## 打开全局配置对话框。
func open_config(data: MudData) -> void:
	_data = data
	_table = "config"
	_row_id = 0
	self.title = "全局配置"
	if not _built:
		_build_body()
		_built = true
	_load_config()
	popup_centered()


func _build_body() -> void:
	var tc := make_tabs()
	_body.add_child(tc)
	_build_game(make_tab_page(tc, "游戏设置"))
	_build_map(make_tab_page(tc, "地图设置"))
	_build_campaign(make_tab_page(tc, "战斗设置"))
	_build_skill(make_tab_page(tc, "技能设置"))
	_build_json_tab(make_tab_page(tc, "导航栏"), "navigation")
	_build_script(make_tab_page(tc, "脚本"))
	_build_json_tab(make_tab_page(tc, "分享奖励"), "share_reward")


# ===================== 游戏设置 =====================

func _build_game(page: VBoxContainer) -> void:
	_game_title = field_line(page, "游戏名称：", "game_title", "")
	_game_version = field_line(page, "游戏版本：", "game_version", "")
	_equip_tab = field_check(page, "装备标签（道具弹出框显示『已装备』标签栏）", "equip_tab", true)
	_trace_log = field_check(page, "测试输出（日志输出脚本 trace 调试数据）", "trace_log", true)
	page.add_child(make_comment("对应导出 GameInfo（名称/版本）与 Setting（装备标签/测试输出）。"))


# ===================== 地图设置 =====================

func _build_map(page: VBoxContainer) -> void:
	_born_point = make_select([], 0)
	_add_labeled(page, "初始出生点：", _born_point)
	_move_time = SpinBox.new()
	_move_time.min_value = 0
	_move_time.max_value = 1000000
	_move_time.value = 300
	_add_labeled(page, "地图移动延时(毫秒)：", _move_time)
	_move_log = field_check(page, "进入场景提示信息（进出节点输出『你来到了xxx』）", "move_log", true)
	page.add_child(make_comment("对应导出 Navigation（出生点）与 Setting（移动延时/提示）。"))


# ===================== 战斗设置 =====================

func _build_campaign(page: VBoxContainer) -> void:
	var sub := TabContainer.new()
	sub.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(sub)

	var fail_page := VBoxContainer.new()
	fail_page.name = "失败触发"
	fail_page.add_theme_constant_override("separation", 6)
	sub.add_child(fail_page)
	fail_page.add_child(make_label("默认战斗失败触发（战役未配置失败触发时使用）："))
	_fail_trigger = make_trigger(MudTriggerEditor.Mode.RESULT, "无默认失败触发")
	_fail_trigger.set_type_label("触发类型：")
	_fail_trigger.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fail_page.add_child(_fail_trigger)

	var prop_page := VBoxContainer.new()
	prop_page.name = "属性展现"
	prop_page.add_theme_constant_override("separation", 6)
	sub.add_child(prop_page)
	prop_page.add_child(make_label("战斗界面属性展现配置（JSON 数组）："))
	_campaign_property = TextEdit.new()
	_campaign_property.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_campaign_property.custom_minimum_size = Vector2(0, 160)
	_campaign_property.placeholder_text = '[{"id": 1, "name": "生命"}]'
	prop_page.add_child(_campaign_property)


# ===================== 技能设置 =====================

func _build_skill(page: VBoxContainer) -> void:
	_skill_enable = field_check(page, "敌人默认技能（开启后所有敌人默认携带此技能）", "skill_enable", false)
	_skill_select = make_select([], 0)
	_add_labeled(page, "默认技能：", _skill_select)
	_skill_enable.toggled.connect(func(_on): _skill_select.disabled = not _skill_enable.button_pressed)
	page.add_child(make_comment("对应导出 NPC 的 skillID（禁用时为 -1）。"))


# ===================== 脚本 =====================

func _build_script(page: VBoxContainer) -> void:
	page.add_child(make_label("事件回调处理脚本（multiple_script）："))
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	page.add_child(bar)
	var chk := Button.new()
	chk.text = "语法校验"
	bar.add_child(chk)
	_multiple_script = TextEdit.new()
	_multiple_script.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_multiple_script.custom_minimum_size = Vector2(0, 200)
	_multiple_script.placeholder_text = "-- 事件回调脚本"
	page.add_child(_multiple_script)
	chk.pressed.connect(func():
		_multiple_script.placeholder_text = "语法校验：" + ("配对正常 ✓" if _check_lua(_multiple_script.text) else "存在未配对 ✗")
	)
	page.add_child(make_comment("脚本插件库（script_pluggin）可在对应标签页中编辑。"))


# ===================== 导航栏 / 分享奖励（JSON） =====================

func _build_json_tab(page: VBoxContainer, key: String) -> void:
	var te := TextEdit.new()
	te.size_flags_vertical = Control.SIZE_EXPAND_FILL
	te.custom_minimum_size = Vector2(0, 200)
	page.add_child(te)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	page.add_child(bar)
	var vb := Button.new()
	vb.text = "JSON 校验"
	bar.add_child(vb)
	vb.pressed.connect(func():
		var s: String = te.text.strip_edges()
		te.placeholder_text = "JSON 校验：" + ("空（合法）✓" if s.is_empty() else ("格式正确 ✓" if JSON.parse_string(s) != null else "解析失败 ✗"))
	)
	if key == "navigation":
		_navigation = te
		te.placeholder_text = '[{"type":1,"weight":1,"name":"角色","id":1}]'
		page.add_child(make_comment("导航栏按钮配置（JSON 数组）。对应导出 Navigation。"))
	else:
		_share_reward = te
		te.placeholder_text = '[{"type":2,"subtype":1,"value":1}]'
		page.add_child(make_comment("玩家分享后获得的奖励（JSON 数组）。对应导出 Exchange。"))


# ===================== 加载 / 保存 =====================

func _load_config() -> void:
	# 游戏设置
	_game_title.text = str(_data.config_get("game_title", ""))
	_game_version.text = str(_data.config_get("game_version", ""))
	_equip_tab.button_pressed = int(_data.config_get("goods_use_equip_tab", 1)) == 1
	_trace_log.button_pressed = int(_data.config_get("game_debug_trace_log", 1)) == 1

	# 地图设置
	_fill_scene_options(_born_point, int(_data.config_get("game_born_point", 1)))
	_move_time.value = float(_data.config_get("map_move_time", 300))
	_move_log.button_pressed = int(_data.config_get("map_move_show_log", 1)) == 1

	# 战斗设置
	var ft: Variant = _data.config_get("campaign_default_fail_trigger")
	if ft == null or str(ft).strip_edges().is_empty():
		_fail_trigger.set_block(0, "", "", 0)
	else:
		_fail_trigger.set_block(1, ft, "", 0)
	_campaign_property.text = "" if _data.config_get("campaign_property") == null else str(_data.config_get("campaign_property"))

	# 技能设置
	var sk: int = int(_data.config_get("skill_default_enemy_skill", -1))
	_skill_enable.button_pressed = sk >= 0
	_fill_skill_options(_skill_select, sk if sk >= 0 else 0)
	_skill_select.disabled = not _skill_enable.button_pressed

	# 导航栏 / 脚本 / 分享奖励
	_navigation.text = "" if _data.config_get("navigation") == null else str(_data.config_get("navigation"))
	_multiple_script.text = "" if _data.config_get("multiple_script") == null else str(_data.config_get("multiple_script"))
	_share_reward.text = "" if _data.config_get("share_reward") == null else str(_data.config_get("share_reward"))


func _fill_scene_options(ob: OptionButton, keep_id: int) -> void:
	ob.clear()
	var scenes: Array = _data.get_table("scene")
	scenes.sort_custom(func(a, b): return int(a.get("id", 0)) < int(b.get("id", 0)))
	var sel: int = -1
	for i in scenes.size():
		var sid: int = int((scenes[i] as Dictionary).get("id", 0))
		ob.add_item("%s(#%d)" % [str((scenes[i] as Dictionary).get("name", "")), sid], sid)
		if sid == keep_id:
			sel = i
	if ob.item_count > 0:
		ob.select(sel if sel >= 0 else 0)


func _fill_skill_options(ob: OptionButton, keep_id: int) -> void:
	ob.clear()
	var skills: Array = _data.get_table("skill")
	skills.sort_custom(func(a, b): return int(a.get("id", 0)) < int(b.get("id", 0)))
	var sel: int = -1
	for i in skills.size():
		var sid: int = int((skills[i] as Dictionary).get("id", 0))
		ob.add_item("%s(#%d)" % [str((skills[i] as Dictionary).get("name", "")), sid], sid)
		if sid == keep_id:
			sel = i
	if ob.item_count > 0:
		ob.select(sel if sel >= 0 else 0)


## 覆盖基类保存：写入各 config 键。
func _on_confirmed() -> void:
	_data.config_set("game_title", _game_title.text)
	_data.config_set("game_version", _game_version.text)
	_data.config_set("goods_use_equip_tab", 1 if _equip_tab.button_pressed else 0)
	_data.config_set("game_debug_trace_log", 1 if _trace_log.button_pressed else 0)

	_data.config_set("game_born_point", _born_point.get_selected_id())
	_data.config_set("map_move_time", int(_move_time.value))
	_data.config_set("map_move_show_log", 1 if _move_log.button_pressed else 0)

	var fb: Dictionary = _fail_trigger.get_block()
	var fcfg: String = fb["config"] if int(fb["type"]) == 1 else (fb["script"] if int(fb["type"]) == 2 else "")
	_data.config_set("campaign_default_fail_trigger", fcfg)
	_data.config_set("campaign_property", _campaign_property.text.strip_edges())

	var sk_id: int = _skill_select.get_selected_id() if _skill_enable.button_pressed else -1
	_data.config_set("skill_default_enemy_skill", sk_id)

	_data.config_set("navigation", _navigation.text.strip_edges())
	_data.config_set("multiple_script", _multiple_script.text)
	_data.config_set("share_reward", _share_reward.text.strip_edges())

	saved.emit("config", 0)
	hide()


func _check_lua(s: String) -> bool:
	var paren: int = 0
	for ch in s:
		if ch == "(":
			paren += 1
		elif ch == ")":
			paren -= 1
		if paren < 0:
			return false
	return paren == 0
