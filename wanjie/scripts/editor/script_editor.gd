## 剧本编辑器主控制器（IDE式）
## 对应GDD §7.1.2 剧本编辑器界面
extends Control

## 当前编辑的剧本ID
var current_script_id: String = ""
## 当前编辑的剧本数据
var current_script: WorldScriptData = null
## 当前底部标签索引: 0=输出 1=校验 2=模板
var _bottom_tab: int = 0
## 当前编辑模式: "visual" / "code"
var editor_mode: String = "visual"
## 代码编辑器实例
var code_editor = null  # ScriptCodeEditorClass instance
## MUD编辑器实例
var mud_editor = null  # MudEditorClass instance
## 编辑器缓存 key -> Control (模块切换时保留状态)
var _editors: Dictionary = {}
## 当前激活的编辑器key
var _current_editor_key: String = ""
## 当前选中项的检查器数据（已废弃）

## UI节点引用
@onready var script_name_label: Label = %ScriptNameLabel
@onready var version_label: Label = %VersionLabel
@onready var module_tree: Tree = %ModuleTree
@onready var editor_container: VBoxContainer = %EditorContainer
@onready var status_label: Label = %StatusLabel
@onready var node_count_label: Label = %NodeCountLabel
@onready var bottom_tab_bar: TabBar = %BottomTabBar
@onready var output_panel: VBoxContainer = %OutputPanel
@onready var output_log: RichTextLabel = %OutputLog
@onready var validation_panel: HSplitContainer = %ValidationPanel
@onready var error_list: ItemList = %ErrorList
@onready var warning_list: ItemList = %WarningList
@onready var suggestion_list: ItemList = %SuggestionList
@onready var template_panel: VBoxContainer = %TemplatePanel
@onready var template_tree: Tree = %TemplateTree
@onready var mode_visual_btn: Button = %ModeVisualBtn
@onready var mode_code_btn: Button = %ModeCodeBtn
@onready var mode_mud_btn: Button = %ModeMudBtn
@onready var code_editor_container: VBoxContainer = %CodeEditorContainer
@onready var mud_editor_container: VBoxContainer = %MudEditorContainer
@onready var center_vsplit: VSplitContainer = %CenterVSplit
@onready var left_panel: PanelContainer = %LeftPanel
@onready var main_hsplit: HSplitContainer = %MainHSplit
@onready var left_collapse_btn: Button = %LeftCollapseBtn
@onready var file_menu: MenuButton = %FileMenu
@onready var edit_menu: MenuButton = %EditMenu
@onready var view_menu: MenuButton = %ViewMenu
@onready var run_menu: MenuButton = %RunMenu
@onready var help_menu: MenuButton = %HelpMenu
@onready var mode_label: Label = %ModeLabel

## 左侧面板折叠状态
var _left_collapsed: bool = false

## 全局撤销/重做系统
var _undo_redo := UndoRedo.new()
## 自动保存
var _auto_save_timer: Timer = null
var _is_dirty: bool = false
## 脏子系统键集合（差分保存: 键见 SUBSYSTEM_FILES; "__all__"=全量）
var _dirty_subsystems: Dictionary = {}
const AUTO_SAVE_INTERVAL := 60.0  # 秒
## 多标签页
var _tab_container: TabContainer = null
var _tab_editor_map: Dictionary = {}  # tab_name -> editor_key

## 面板场景预加载
const ScriptCodeEditorClass = preload("res://scripts/editor/script_code_editor.gd")
const IDEThemeClass = preload("res://scripts/editor/ide/ide_theme.gd")
const ScriptCodeGenClass = preload("res://scripts/editor/script_codegen.gd")
const MudEditorClass = preload("res://scripts/editor/mud_editor.gd")
## 结构化条件/动作编译器(用preload避免依赖全局类缓存)
const CondCompiler = preload("res://scripts/editor/condition_compiler.gd")
## UI构建工厂 (提取自本文件, 减少单文件体积)
const UIFactoryClass = preload("res://scripts/editor/editor_ui_factory.gd")
var _ui: RefCounted  # EditorUIFactory instance
## Visual module preloads
const VisualEconomyClass = preload("res://scripts/editor/visual/visual_economy.gd")
const VisualAbilityClass = preload("res://scripts/editor/visual/visual_ability.gd")
const VisualQuestClass = preload("res://scripts/editor/visual/visual_quest.gd")
const VisualCombatClass = preload("res://scripts/editor/visual/visual_combat.gd")
const VisualWorldviewClass = preload("res://scripts/editor/visual/visual_worldview.gd")
const VisualMapClass = preload("res://scripts/editor/visual/visual_map.gd")
const VisualTestRunnerClass = preload("res://scripts/editor/visual/visual_test_runner.gd")
const VisualEventClass = preload("res://scripts/editor/visual/visual_event.gd")
const VisualAIAssistantClass = preload("res://scripts/editor/visual/visual_ai_assistant.gd")
const VisualBlueprintWorkspaceClass = preload("res://scripts/editor/visual/visual_blueprint_workspace.gd")
const VisualSystemBlueprintClass = preload("res://scripts/editor/visual/visual_system_blueprint.gd")
## Visual module instances
var _mod_economy: RefCounted
var _mod_ability: RefCounted
var _mod_quest: RefCounted
var _mod_combat: RefCounted
var _mod_worldview: RefCounted
var _mod_map: RefCounted
var _mod_test_runner: RefCounted
var _mod_event: RefCounted
var _mod_ai_assistant: RefCounted
var _mod_blueprint_workspace: RefCounted
var _mod_system_blueprint: RefCounted

## 构建编辑器深色基础主题（供未显式 override 的控件继承, 隔离全局浅色渗入）
func _build_editor_theme() -> Theme:
	var t := Theme.new()
	# 字号与全局 main_theme 对齐（15）, 避免编辑器内控件字号跳变
	t.default_font_size = 15
	t.set_color("font_color", "Label", IDEThemeClass.C_TEXT)
	t.set_color("font_color", "Button", IDEThemeClass.C_TEXT)
	t.set_color("font_hover_color", "Button", IDEThemeClass.C_TEXT)
	t.set_color("font_pressed_color", "Button", IDEThemeClass.C_TEXT)
	t.set_color("font_color", "LineEdit", IDEThemeClass.C_TEXT)
	t.set_color("font_color", "OptionButton", IDEThemeClass.C_TEXT)
	t.set_color("font_color", "CheckBox", IDEThemeClass.C_TEXT)
	t.set_color("font_color", "TabContainer", IDEThemeClass.C_TEXT)
	t.set_color("font_color", "Tree", IDEThemeClass.C_TEXT)
	t.set_color("font_selected_color", "Tree", IDEThemeClass.C_TEXT)
	t.set_color("font_color", "ItemList", IDEThemeClass.C_TEXT)
	t.set_color("font_color", "RichTextLabel", IDEThemeClass.C_TEXT)
	t.set_color("font_color", "ProgressBar", IDEThemeClass.C_TEXT)
	# 弹窗/菜单（MenuButton 弹出菜单文字, 避免深棕文字配深灰背景不可读）
	t.set_color("font_color", "PopupMenu", IDEThemeClass.C_TEXT)
	t.set_color("font_hover_color", "PopupMenu", IDEThemeClass.C_TEXT)
	t.set_color("font_color", "MenuButton", IDEThemeClass.C_TEXT)
	# 深色面板/树/列表背景（左侧模块树/文件系统等继承, 避免浅色渗入）
	var tree_panel := StyleBoxFlat.new()
	tree_panel.bg_color = IDEThemeClass.C_BG_BASE
	tree_panel.set_content_margin_all(4)
	t.set_stylebox("panel", "Tree", tree_panel)
	t.set_stylebox("panel", "ItemList", tree_panel)
	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color = IDEThemeClass.C_BG_BASE
	t.set_stylebox("panel", "PanelContainer", panel_sb)
	t.set_stylebox("panel", "ScrollContainer", panel_sb)
	return t

func _ready() -> void:
	# 编辑器深色主题: 隔离全局浅色主题渗入（未 override 的 Label/Button 继承深色基础）
	theme = _build_editor_theme()
	_ui = UIFactoryClass.new(self)
	_mod_economy = VisualEconomyClass.new(self)
	_mod_ability = VisualAbilityClass.new(self)
	_mod_quest = VisualQuestClass.new(self)
	_mod_combat = VisualCombatClass.new(self)
	_mod_worldview = VisualWorldviewClass.new(self)
	_mod_map = VisualMapClass.new(self)
	_mod_test_runner = VisualTestRunnerClass.new(self)
	_mod_event = VisualEventClass.new(self)
	_mod_ai_assistant = VisualAIAssistantClass.new(self)
	_mod_blueprint_workspace = VisualBlueprintWorkspaceClass.new(self)
	_mod_system_blueprint = VisualSystemBlueprintClass.new(self)
	current_script_id = SceneManager.current_script_id
	_setup_menus()
	_setup_auto_save()
	_load_script()
	_build_module_tree()
	_build_template_tree()
	_setup_template_tree()
	_setup_module_tree_context()
	_update_validation()
	_init_code_editor()
	_init_mud_editor()
	_update_mode_buttons()
	# 根据 metadata 中的编辑器偏好自动切换模式
	_apply_saved_editor_mode()
	# 首次进入编辑器引导
	if not GameManager.user_data.editor_visited:
		GameManager.user_data.editor_visited = true
		GameManager.save_user_data()
		ToastManager.info("欢迎进入编辑器！左侧模块树选择子系统，右侧编辑，Ctrl+S 保存，F1 展开帮助")
	# 锁定编辑器模式：隐藏模式切换按钮（创建剧本时已确定，不允许自由切换）
	_lock_mode_buttons()
	# 显示欢迎编辑器
	_show_welcome_editor()
	_log_output("剧本编辑器已就绪")

## 读取剧本 metadata 中的编辑器模式设置，自动切换到对应模式
func _apply_saved_editor_mode() -> void:
	if current_script == null:
		return
	var saved_mode: String = current_script.metadata.get("editor_mode", "visual")
	match saved_mode:
		"code":
			_on_mode_code_pressed()
		"mud":
			_on_mode_mud_pressed()
		_:
			pass  # visual 为默认模式，无需切换

## 锁定编辑器模式：隐藏顶栏三个模式切换按钮
func _lock_mode_buttons() -> void:
	mode_visual_btn.visible = false
	mode_code_btn.visible = false
	mode_mud_btn.visible = false

## 加载剧本数据
func _load_script() -> void:
	if current_script_id.is_empty():
		script_name_label.text = "剧本: (未选择)"
		return
	current_script = ScriptDataManager.find_script(current_script_id)
	if current_script == null:
		current_script = GameManager.get_script_data(current_script_id)
	if current_script == null:
		push_warning("ScriptEditor: 找不到剧本: %s" % current_script_id)
		script_name_label.text = "剧本: (未找到)"
		return
	current_script.ensure_subsystems()
	script_name_label.text = "剧本: \"%s\"" % current_script.name
	version_label.text = "v%s" % current_script.version
	_update_node_count()

## 刷新顶栏剧本信息显示
func _update_script_info_display() -> void:
	if current_script == null:
		return
	script_name_label.text = "剧本: \"%s\"" % current_script.name
	version_label.text = "v%s" % current_script.version
	_update_node_count()

## === 模块树构建 ===
func _build_module_tree() -> void:
	module_tree.clear()
	var root := module_tree.create_item()
	root.set_text(0, current_script.name if current_script else "剧本")
	if current_script == null:
		return

	# 蓝图工作区（UE 风格统一蓝图编辑器）
	var bp_item := module_tree.create_item(root)
	bp_item.set_text(0, "🔷 蓝图工作区")
	bp_item.set_metadata(0, {"path": "blueprint/workspace", "type": "blueprint_workspace"})
	bp_item.set_custom_color(0, Color(0.6, 0.8, 1.0, 1))

	# 剧本元数据
	var meta_item := module_tree.create_item(root)
	meta_item.set_text(0, "📋 剧本元数据")
	meta_item.set_metadata(0, {"path": "metadata", "type": "metadata"})
	var stats_item := module_tree.create_item(root)
	stats_item.set_text(0, "📊 剧本统计")
	stats_item.set_metadata(0, {"path": "stats", "type": "stats"})
	stats_item.set_custom_color(0, Color(0.6, 0.9, 0.6, 1))
	meta_item.set_custom_color(0, Color(0.95, 0.85, 0.55, 1))

	# 世界观
	var wv := current_script.worldview
	var wv_item := module_tree.create_item(root)
	wv_item.set_text(0, "📖 世界观")
	wv_item.set_metadata(0, {"path": "worldview/overview", "type": "worldview_overview"})
	wv_item.set_custom_color(0, Color(0.55, 0.8, 1.0, 1))
	_add_leaf(wv_item, "背景故事", "worldview/background", "worldview_bg")
	_add_leaf(wv_item, "时代定义 (%d)" % wv.era_definitions.size(), "worldview/eras", "worldview_eras")
	_add_leaf(wv_item, "时间线 (%d)" % wv.timeline.size(), "worldview/timeline", "worldview_timeline")
	_add_leaf(wv_item, "世界规则 (%d)" % wv.world_rules.size(), "worldview/rules", "worldview_rules")
	_add_leaf(wv_item, "势力设定 (%d)" % wv.factions.size(), "worldview/factions", "worldview_factions")
	_add_leaf(wv_item, "势力关系 (%d)" % wv.faction_relationships.size(), "worldview/relationships", "worldview_rels")
	_add_leaf(wv_item, "地理区域 (%d)" % wv.geography.get("regions", []).size(), "worldview/geography", "worldview_geo")
	_add_leaf(wv_item, "知识条目 (%d)" % wv.lore_entries.size(), "worldview/lore", "worldview_lore")
	_add_leaf(wv_item, "🎨 蓝图", "worldview/blueprint", "blueprint_system")

	# 事件系统
	var es := current_script.event_system
	var ev_item := module_tree.create_item(root)
	ev_item.set_text(0, "📜 事件系统")
	ev_item.set_metadata(0, {"path": "event/overview", "type": "event_overview"})
	ev_item.set_custom_color(0, Color(1.0, 0.75, 0.4, 1))
	_add_leaf(ev_item, "剧情事件 (%d)" % es.story_events.size(), "event/story", "event_story")
	# 每个剧情事件作为子节点
	for se in es.story_events:
		var se_item := module_tree.create_item(ev_item)
		se_item.set_text(0, "  📌 %s" % se.get("name", se.get("id", "?")))
		se_item.set_metadata(0, {"path": "event/story/%s" % se.get("id", ""), "type": "event_detail", "event_id": se.get("id", "")})
		se_item.set_custom_color(0, Color(0.9, 0.7, 0.45, 0.9))
	_add_leaf(ev_item, "随机事件 (%d)" % es.random_events.size(), "event/random", "event_random")
	for re in es.random_events:
		var re_item := module_tree.create_item(ev_item)
		re_item.set_text(0, "  🎲 %s" % re.get("name", re.get("id", "?")))
		re_item.set_metadata(0, {"path": "event/random/%s" % re.get("id", ""), "type": "random_detail", "event_id": re.get("id", "")})
		re_item.set_custom_color(0, Color(0.9, 0.7, 0.45, 0.9))
	_add_leaf(ev_item, "事件链 (%d)" % es.event_chains.size(), "event/chains", "event_chains")
	_add_leaf(ev_item, "🎨 蓝图", "event/blueprint", "blueprint_system")

	# 经济系统
	var ec := current_script.economy_system
	var ec_item := module_tree.create_item(root)
	ec_item.set_text(0, "💰 经济系统")
	ec_item.set_metadata(0, {"path": "economy/overview", "type": "economy_overview"})
	ec_item.set_custom_color(0, Color(0.5, 0.9, 0.5, 1))
	_add_leaf(ec_item, "货币 (%d)" % ec.currencies.size(), "economy/currencies", "economy_curr")
	_add_leaf(ec_item, "资源 (%d)" % ec.resources.size(), "economy/resources", "economy_res")
	_add_leaf(ec_item, "市场 (%d)" % ec.markets.size(), "economy/markets", "economy_mkt")
	_add_leaf(ec_item, "交易规则", "economy/trade_rules", "economy_trade")
	_add_leaf(ec_item, "产出规则 (%d)" % ec.production_rules.size(), "economy/production", "economy_prod")
	_add_leaf(ec_item, "🎨 蓝图", "economy/blueprint", "blueprint_system")

	# 能力系统
	var ab := current_script.ability_system
	var ab_item := module_tree.create_item(root)
	ab_item.set_text(0, "⚔ 能力系统")
	ab_item.set_metadata(0, {"path": "ability/overview", "type": "ability_overview"})
	ab_item.set_custom_color(0, Color(1.0, 0.5, 0.5, 1))
	_add_leaf(ab_item, "技能 (%d)" % ab.skills.size(), "ability/skills", "ability_skills")
	for sk in ab.skills:
		var sk_item := module_tree.create_item(ab_item)
		sk_item.set_text(0, "  🔸 %s" % sk.get("name", sk.get("id", "?")))
		sk_item.set_metadata(0, {"path": "ability/skill/%s" % sk.get("id", ""), "type": "skill_detail", "skill_id": sk.get("id", "")})
		sk_item.set_custom_color(0, Color(1.0, 0.55, 0.55, 0.9))
	_add_leaf(ab_item, "成长路线 (%d)" % ab.growth_paths.size(), "ability/growth", "ability_growth")
	_add_leaf(ab_item, "状态效果 (%d)" % ab.status_effects.size(), "ability/effects", "ability_fx")
	_add_leaf(ab_item, "战斗机制", "ability/combat", "ability_combat")
	_add_leaf(ab_item, "元素相克表", "ability/elements", "ability_elem")
	_add_leaf(ab_item, "🎨 蓝图", "ability/blueprint", "blueprint_system")

	# 任务系统
	var qs := current_script.quest_system
	var quest_item := module_tree.create_item(root)
	quest_item.set_text(0, "📋 任务系统")
	quest_item.set_metadata(0, {"path": "quest/overview", "type": "quest_overview"})
	quest_item.set_custom_color(0, Color(0.9, 0.8, 0.45, 1))
	_add_leaf(quest_item, "任务列表 (%d)" % qs.quests.size(), "quest/list", "quest_list")
	for q in qs.quests:
		var q_item := module_tree.create_item(quest_item)
		q_item.set_text(0, "  📜 %s" % q.get("name", q.get("id", "?")))
		q_item.set_metadata(0, {"path": "quest/detail/%s" % q.get("id", ""), "type": "quest_detail", "quest_id": q.get("id", "")})
		q_item.set_custom_color(0, Color(0.9, 0.8, 0.45, 0.9))
	_add_leaf(quest_item, "任务链 (%d)" % qs.quest_chains.size(), "quest/chains", "quest_chains")
	_add_leaf(quest_item, "🎨 蓝图", "quest/blueprint", "blueprint_system")

	# 战斗系统
	var cs := current_script.combat_system
	var combat_item := module_tree.create_item(root)
	combat_item.set_text(0, "⚔ 战斗系统")
	combat_item.set_metadata(0, {"path": "combat/overview", "type": "combat_overview"})
	combat_item.set_custom_color(0, Color(1.0, 0.55, 0.45, 1))
	_add_leaf(combat_item, "敌人模板 (%d)" % cs.enemy_templates.size(), "combat/enemies", "combat_enemies")
	_add_leaf(combat_item, "NPC池 (%d)" % cs.npc_pool.size(), "combat/npcs", "combat_npcs")
	_add_leaf(combat_item, "战斗配置 (%d)" % cs.battle_configs.size(), "combat/battles", "combat_battles")
	_add_leaf(combat_item, "🎨 蓝图", "combat/blueprint", "blueprint_system")

	# 地图编辑器
	var map_item := module_tree.create_item(root)
	map_item.set_text(0, "🗺 地图")
	map_item.set_metadata(0, {"path": "map/overview", "type": "map_overview"})
	map_item.set_custom_color(0, Color(0.6, 0.85, 0.65, 1))
	var regions: Array = wv.geography.get("regions", [])
	_add_leaf(map_item, "区域定义 (%d)" % regions.size(), "map/regions", "map_region")
	for r in regions:
		var r_item := module_tree.create_item(map_item)
		r_item.set_text(0, "  📍 %s" % r.get("name", r.get("id", "?")))
		r_item.set_metadata(0, {"path": "map/region/%s" % r.get("id", ""), "type": "map_region", "region_id": r.get("id", "")})
		r_item.set_custom_color(0, Color(0.6, 0.85, 0.65, 0.9))
	_add_leaf(map_item, "地点关联", "map/locations", "map_location")
	_add_leaf(map_item, "🎨 蓝图", "map/blueprint", "blueprint_system")

	# 测试运行器
	var test_item := module_tree.create_item(root)
	test_item.set_text(0, "🧪 测试运行器")
	test_item.set_metadata(0, {"path": "test/runner", "type": "test_runner"})
	test_item.set_custom_color(0, Color(0.9, 0.6, 0.9, 1))
	_add_leaf(test_item, "事件触发测试", "test/events", "test_runner")
	_add_leaf(test_item, "实时预览", "test/preview", "test_runner")

	# AI创作助手
	var ai_item := module_tree.create_item(root)
	ai_item.set_text(0, "🤖 AI创作助手")
	ai_item.set_metadata(0, {"path": "ai/assistant", "type": "ai_assistant"})
	ai_item.set_custom_color(0, Color(0.6, 0.8, 1.0, 1))
	_add_leaf(ai_item, "世界观生成", "ai/worldview", "ai_assistant")
	_add_leaf(ai_item, "事件编排", "ai/events", "ai_assistant")
	_add_leaf(ai_item, "经济分析", "ai/economy", "ai_assistant")
	_add_leaf(ai_item, "能力设计", "ai/ability", "ai_assistant")

func _add_leaf(parent_item: TreeItem, text: String, path: String, node_type: String) -> void:
	var item := module_tree.create_item(parent_item)
	item.set_text(0, "  " + text)
	item.set_metadata(0, {"path": path, "type": node_type})
	item.set_custom_color(0, Color(0.75, 0.78, 0.85, 1))

## === 模块树点击 ===
## 模块树右键菜单（剧本级操作：封面/导出/删除）
func _setup_module_tree_context() -> void:
	if not module_tree.gui_input.is_connected(_on_module_tree_gui_input):
		module_tree.gui_input.connect(_on_module_tree_gui_input)

func _on_module_tree_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_popup_module_menu(event.global_position)

func _popup_module_menu(pos: Vector2) -> void:
	if current_script == null:
		return
	var menu := PopupMenu.new()
	menu.add_item("🎨 设置封面…", 1)
	menu.add_item("📦 导出剧本…", 2)
	menu.add_item("🗑 删除剧本…", 3)
	menu.id_pressed.connect(_on_module_menu_id)
	add_child(menu)
	menu.popup(Rect2i(pos, Vector2i.ZERO))

func _on_module_menu_id(id: int) -> void:
	match id:
		1: _on_set_cover_pressed()
		2: _on_export_script_pressed()
		3: _confirm_delete_script()

func _confirm_delete_script() -> void:
	if current_script == null:
		return
	var confirm := ConfirmationDialog.new()
	confirm.dialog_text = "确定删除剧本《%s》？将移入回收站（user://scripts_trash 可恢复）。" % current_script.name
	confirm.confirmed.connect(func():
		var sid := current_script.id
		ScriptDataManager.delete_script(sid)
		ToastManager.success("剧本已删除")
		SceneManager.go_back_to_hub())
	add_child(confirm)
	confirm.popup_centered()

func _on_module_tree_selected() -> void:
	var item := module_tree.get_selected()
	if item == null:
		return
	var meta: Dictionary = item.get_metadata(0)
	if meta.is_empty():
		return
	var path: String = meta.get("path", "")
	var title: String = item.get_text(0).strip_edges()
	_open_editor_for_path(path, title, meta)

## === 子系统子分支 -> 蓝图优先路由 ===
## 子分支（非概览页）打开即蓝图界面（锁定 sys:* 图, 可切回表单）
const SUBSYSTEM_LEAVES := {
	"worldview_bg": ["visual_worldview", "worldview_blueprint"],
	"worldview_eras": ["visual_worldview", "worldview_blueprint"],
	"worldview_timeline": ["visual_worldview", "worldview_blueprint"],
	"worldview_rules": ["visual_worldview", "worldview_blueprint"],
	"worldview_factions": ["visual_worldview", "worldview_blueprint"],
	"worldview_rels": ["visual_worldview", "worldview_blueprint"],
	"worldview_geo": ["visual_worldview", "worldview_blueprint"],
	"worldview_lore": ["visual_worldview", "worldview_blueprint"],
	"economy_curr": ["visual_economy", "economy_blueprint"],
	"economy_res": ["visual_economy", "economy_blueprint"],
	"economy_mkt": ["visual_economy", "economy_blueprint"],
	"economy_trade": ["visual_economy", "economy_blueprint"],
	"economy_prod": ["visual_economy", "economy_blueprint"],
	"ability_skills": ["visual_ability", "ability_blueprint"],
	"ability_growth": ["visual_ability", "ability_blueprint"],
	"ability_fx": ["visual_ability", "ability_blueprint"],
	"ability_combat": ["visual_ability", "ability_blueprint"],
	"ability_elem": ["visual_ability", "ability_blueprint"],
	"quest_list": ["visual_quest", "quest_blueprint"],
	"quest_chains": ["visual_quest", "quest_blueprint"],
	"combat_enemies": ["visual_combat", "combat_blueprint"],
	"combat_npcs": ["visual_combat", "combat_blueprint"],
	"combat_battles": ["visual_combat", "combat_blueprint"],
	"map_region": ["visual_map", "map_blueprint"],
	"map_location": ["visual_map", "map_blueprint"],
}

## 编辑器切换核心方法
func _switch_editor(key: String, title: String, panel: Control) -> void:
	if panel == null:
		return
	# 缓存编辑器
	_editors[key] = panel
	_current_editor_key = key
	# 单容器模式：隐藏多标签（若有）
	if _tab_container != null:
		_tab_container.visible = false
	editor_container.visible = true
	# 清除当前内容
	for child in editor_container.get_children():
		editor_container.remove_child(child)
	# 添加新编辑器
	if panel.get_parent() != null:
		panel.get_parent().remove_child(panel)
	editor_container.add_child(panel)
	# 更新状态栏
	status_label.text = "📌 %s" % title

## 显示欢迎编辑器
func _show_welcome_editor() -> void:
	var welcome := _create_welcome_panel()
	_switch_editor("welcome", "🏛 欢迎", welcome)

## 根据数据路径打开/切换编辑器
func _open_editor_for_path(path: String, title: String, meta: Dictionary) -> void:
	var node_type: String = meta.get("type", "")
	var editor_key: String = _get_editor_key(path)
	var panel: Control = null

	# 如果编辑器已缓存，直接激活（多标签：面板已在标签则切换，否则新增）
	if _editors.has(editor_key):
		_activate_module_editor(editor_key, title, _editors[editor_key])
		return

	# 子系统子分支（非概览页）: 蓝图优先（锁定子系统图, 可切回表单）
	if SUBSYSTEM_LEAVES.has(node_type):
		var leaf_info: Array = SUBSYSTEM_LEAVES[node_type]
		panel = _create_system_blueprint(leaf_info[1], {"form_module": leaf_info[0], "form_sub": node_type})
		editor_key = "blueprint_system"
		if panel == null:
			return
		_activate_module_editor(editor_key, title, panel)
		return

	# 根据路径创建对应编辑器
	match node_type:
		"metadata":
			panel = _create_metadata_panel()
			editor_key = "metadata"
		"worldview_overview", "worldview_bg", "worldview_eras", "worldview_timeline", \
		"worldview_rules", "worldview_factions", "worldview_rels", "worldview_geo", "worldview_lore":
			panel = _create_worldview_editor(node_type)
			editor_key = "worldview"
		"event_overview", "event_story", "event_detail", "event_random", "random_detail", "event_chains":
			panel = _create_event_editor(node_type, meta)
			editor_key = "event"
		"economy_overview", "economy_curr", "economy_res", "economy_mkt", "economy_trade", "economy_prod":
			panel = _create_economy_editor(node_type)
			editor_key = "economy"
		"ability_overview", "ability_skills", "ability_growth", "ability_fx", "ability_combat", "ability_elem", "skill_detail":
			panel = _create_ability_editor(node_type, meta)
			editor_key = "ability"
		"quest_overview", "quest_list", "quest_chains", "quest_detail":
			panel = _create_quest_editor(node_type, meta)
			editor_key = "quest"
		"combat_overview", "combat_enemies", "combat_npcs", "combat_battles":
			panel = _create_combat_editor(node_type)
			editor_key = "combat"
		"map_overview", "map_region", "map_location":
			panel = _create_map_editor()
			editor_key = "map"
		"test_runner":
			panel = _create_test_runner()
			editor_key = "test"
		"blueprint_workspace":
			panel = _create_blueprint_workspace()
			editor_key = "blueprint"
		"blueprint_system":
			# 子系统蓝图: 从 path（如 worldview/blueprint）推导 sub_type
			var sys_sub: String = path.get_base_dir() + "_blueprint"
			panel = _create_system_blueprint(sys_sub)
			editor_key = "blueprint_system"
		"ai_assistant":
			panel = _create_ai_assistant()
			editor_key = "ai"
		_:
			panel = _create_placeholder_panel("未实现的编辑区域: %s" % path)

	if panel == null:
		return
	_activate_module_editor(editor_key, title, panel)

## 模块编辑器激活：走多标签页（子系统面板可多开/切换）
func _activate_module_editor(editor_key: String, title: String, panel: Control) -> void:
	if _tab_container == null:
		_setup_tab_container()
	_open_tab(title, editor_key, panel)
	# 多标签模式：隐藏单容器（子系统面板进标签页）
	editor_container.visible = false
	if _tab_container != null:
		_tab_container.visible = true

## 获取路径对应的编辑器key
func _get_editor_key(path: String) -> String:
	# 子系统蓝图分支独立缓存（避免与对应表单共用编辑器缓存）
	if path.ends_with("/blueprint"):
		return "blueprint_system"
	if path == "metadata":
		return "metadata"
	elif path == "stats":
		return "stats"
	elif path.begins_with("worldview/"):
		return "worldview"
	elif path.begins_with("event/"):
		return "event"
	elif path.begins_with("economy/"):
		return "economy"
	elif path.begins_with("ability/"):
		return "ability"
	elif path.begins_with("quest/"):
		return "quest"
	elif path.begins_with("combat/"):
		return "combat"
	elif path.begins_with("map/"):
		return "map"
	elif path.begins_with("blueprint/"):
		return "blueprint"
	elif path.begins_with("test/"):
		return "test"
	return path

## === 面板创建工厂 ===
func _create_stats_panel() -> Control:
	var panel := _make_scroll_panel()
	var vbox := _make_vbox(panel)
	_add_section_label(vbox, "📊 剧本统计")
	var ws := current_script
	# 事件
	var ev_count := ws.event_system.story_events.size() if ws.event_system else 0
	var rand_count := ws.event_system.random_events.size() if ws.event_system else 0
	var chain_count := ws.event_system.event_chains.size() if ws.event_system else 0
	# 字数（背景+事件描述）
	var words := 0
	if ws.worldview:
		words += ws.worldview.background_story.length()
	if ws.event_system:
		for e in ws.event_system.story_events:
			words += str(e.get("description", "")).length()
	# 技能/经济
	var skill_count: int = ws.ability_system.skills.size() if ws.ability_system else 0
	var npc_count: int = ws.combat_system.combat_npcs.size() if ws.combat_system else 0
	var money_types: int = ws.economy_system.currencies.size() if ws.economy_system else 0
	var stats := [
		["📜 剧情事件", str(ev_count)],
		["🎲 随机事件", str(rand_count)],
		["🔗 事件链", str(chain_count)],
		["✍️ 剧情字数", str(words)],
		["⚔ 技能数", str(skill_count)],
		["👹 NPC", str(npc_count)],
		["💰 货币种类", str(money_types)],
		["📏 预估体验时长", "%d 分钟" % int(ev_count * 3.0)],
		["📈 体验次数", str(ws.play_count)],
		["⭐ 评分", "%.1f（%d人）" % [ws.rating, ws.rating_count]],
	]
	for item in stats:
		var row := HBoxContainer.new()
		var k := Label.new()
		k.text = item[0]
		k.custom_minimum_size.x = 140
		k.add_theme_font_size_override("font_size", 13)
		row.add_child(k)
		var v := Label.new()
		v.text = item[1]
		v.add_theme_color_override("font_color", Color(0.85, 0.75, 0.5))
		v.add_theme_font_size_override("font_size", 13)
		row.add_child(v)
		vbox.add_child(row)
	return panel

func _create_metadata_panel() -> Control:
	var panel := _make_scroll_panel()
	var vbox := _make_vbox(panel)
	_add_section_label(vbox, "📋 剧本元数据")
	_add_text_field(vbox, "名称", current_script.name, func(v): current_script.name = v)
	_add_text_field(vbox, "作者", current_script.author, func(v): current_script.author = v)
	_add_text_field(vbox, "版本", current_script.version, func(v): current_script.version = v)
	_add_text_field(vbox, "简介", current_script.description, func(v): current_script.description = v)
	_add_text_field(vbox, "标签", current_script.get_tags_display(), func(v):
		current_script.tags = Array(v.split(","), TYPE_STRING, "", null)
		for i in current_script.tags.size():
			current_script.tags[i] = current_script.tags[i].strip_edges()
	)
	_add_spin_field(vbox, "预计时长(h)", current_script.estimated_hours, 0.0, 100.0, func(v): current_script.estimated_hours = v)
	return panel

func _create_worldview_editor(sub_type: String) -> Control:
	return _mod_worldview.create(sub_type)



func _create_event_editor(_sub_type: String, _meta: Dictionary) -> Control:
	return _mod_event.create(_sub_type, _meta)


func _create_economy_editor(sub_type: String) -> Control:
	return _mod_economy.create(sub_type)



func _create_ability_editor(sub_type: String, meta: Dictionary) -> Control:
	return _mod_ability.create(sub_type, meta)



## === 任务系统编辑器 ===

func _create_quest_editor(sub_type: String, meta: Dictionary) -> Control:
	return _mod_quest.create(sub_type, meta)



## === 战斗系统编辑器 ===

func _create_combat_editor(sub_type: String) -> Control:
	return _mod_combat.create(sub_type)



func _create_placeholder_panel(text: String) -> Control:
	var panel := _make_scroll_panel()
	var vbox := _make_vbox(panel)
	_add_section_label(vbox, text)
	return panel

## === 地图编辑器 ===

func _create_map_editor() -> Control:
	return _mod_map.create()







## === 测试运行器 ===
func _create_test_runner() -> Control:
	return _mod_test_runner.create()

## === 统一蓝图工作区（UE 风格） ===
func _create_blueprint_workspace() -> Control:
	return _mod_blueprint_workspace.create("blueprint_workspace", {})

## === 子系统蓝图编辑器（各子系统模块下的 🎨 蓝图分支） ===
func _create_system_blueprint(sub_type: String, meta: Dictionary = {}) -> Control:
	return _mod_system_blueprint.create(sub_type, meta)

## === AI创作助手 ===
func _create_ai_assistant() -> Control:
	return _mod_ai_assistant.create()



func _create_welcome_panel() -> Control:
	var panel := _make_scroll_panel()
	var vbox := _make_vbox(panel)
	vbox.add_theme_constant_override("separation", 6)
	# 顶部间距
	var top_spacer := Control.new()
	top_spacer.custom_minimum_size.y = 30
	vbox.add_child(top_spacer)
	# 标题卡片
	var title_card := PanelContainer.new()
	var tc_sb := StyleBoxFlat.new()
	tc_sb.bg_color = Color(0.14, 0.16, 0.22, 1)
	tc_sb.corner_radius_top_left = 8
	tc_sb.corner_radius_top_right = 8
	tc_sb.corner_radius_bottom_right = 8
	tc_sb.corner_radius_bottom_left = 8
	tc_sb.border_width_left = 1
	tc_sb.border_width_top = 1
	tc_sb.border_width_right = 1
	tc_sb.border_width_bottom = 1
	tc_sb.border_color = Color(0.3, 0.4, 0.6, 0.4)
	tc_sb.content_margin_left = 24.0
	tc_sb.content_margin_top = 20.0
	tc_sb.content_margin_right = 24.0
	tc_sb.content_margin_bottom = 20.0
	title_card.add_theme_stylebox_override("panel", tc_sb)
	title_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(title_card)
	var title_vbox := VBoxContainer.new()
	title_vbox.add_theme_constant_override("separation", 8)
	title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_card.add_child(title_vbox)
	# 标题
	var title_lbl := Label.new()
	title_lbl.text = "📖 %s" % (current_script.name if current_script else "万界诗篇")
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_lbl.add_theme_color_override("font_color", C_SECTION_TITLE)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_vbox.add_child(title_lbl)
	# 版本信息
	if current_script:
		var ver_lbl := Label.new()
		ver_lbl.text = "版本 %s · 作者: %s" % [current_script.version, current_script.author]
		ver_lbl.add_theme_font_size_override("font_size", 12)
		ver_lbl.add_theme_color_override("font_color", C_LABEL)
		ver_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_vbox.add_child(ver_lbl)
	# 引导提示
	var hint_lbl := Label.new()
	hint_lbl.text = "从左侧模块树选择一个项目开始编辑\n或使用顶部工具栏切换到代码模式"
	hint_lbl.add_theme_font_size_override("font_size", 13)
	hint_lbl.add_theme_color_override("font_color", C_EMPTY_HINT)
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	title_vbox.add_child(hint_lbl)
	# 统计概览
	if current_script:
		_add_section_label(vbox, "📊 剧本概览")
		var wv := current_script.worldview
		var es := current_script.event_system
		var ec := current_script.economy_system
		var ab := current_script.ability_system
		_add_stat_card(vbox, [
			["时代", str(wv.era_definitions.size())],
			["势力", str(wv.factions.size())],
			["剧情事件", str(es.story_events.size())],
			["随机事件", str(es.random_events.size())],
			["技能", str(ab.skills.size())],
			["货币", str(ec.currencies.size())],
		])
	return panel

## === 校验面板 ===
func _update_validation() -> void:
	if current_script == null:
		return
	var validator := ScriptValidator.new()
	var report := validator.validate(current_script)
	error_list.clear()
	for e in report.get("errors", []):
		error_list.add_item(str(e))
	# 点击错误条目：有定位则跳转事件，否则复制全文
	var err_report: Dictionary = report
	error_list.item_activated.connect(func(index: int):
		var locs: Array = err_report.get("error_locations", [])
		if index < locs.size():
			var loc: Dictionary = locs[index]
			var ev_id: String = str(loc.get("event_id", ""))
			if not ev_id.is_empty():
				_jump_to_event(ev_id)
				return
		DisplayServer.clipboard_set(error_list.get_item_text(index))
		ToastManager.info("已复制错误信息"))

	warning_list.clear()
	for w in report.get("warnings", []):
		warning_list.add_item(str(w))
	suggestion_list.clear()
	for s in report.get("suggestions", []):
		suggestion_list.add_item(str(s))
	if report["is_valid"]:
		status_label.text = "✅ 无错误"
		_log_output("[color=green]✅ 校验通过[/color]")
	else:
		status_label.text = "⚠ %d错误 %d警告" % [report["error_count"], report["warning_count"]]
		_log_output("[color=red]❌ 校验失败: %d 错误 %d 警告[/color]" % [report["error_count"], report["warning_count"]])
## 校验错误跳转：打开事件编辑器并进入对应事件蓝图
func _jump_to_event(event_id: String) -> void:
	_open_editor_for_path("event/list", "事件列表", {})
	var panel: Variant = _editors.get("event", null)
	if panel != null and panel.has_method("_enter_event_blueprint"):
		panel.call("_enter_event_blueprint", event_id)
		status_label.text = "🎯 已定位事件: %s" % event_id
	else:
		status_label.text = "⚠ 无法定位事件（请先在事件列表中查看）"

func _update_node_count() -> void:
	if current_script == null:
		return
	var ec := 0
	var fc := 0
	var sc := 0
	if current_script.event_system:
		ec = current_script.event_system.story_events.size()
	if current_script.worldview:
		fc = current_script.worldview.factions.size()
	if current_script.ability_system:
		sc = current_script.ability_system.skills.size()
	node_count_label.text = "事件: %d | 势力: %d | 技能: %d" % [ec, fc, sc]

func _on_bottom_tab_changed(tab: int) -> void:
	_bottom_tab = tab
	output_panel.visible = (tab == 0)
	validation_panel.visible = (tab == 1)
	template_panel.visible = (tab == 2)

## 输出日志
func _log_output(msg: String) -> void:
	if output_log:
		output_log.text += msg + "\n"

## 设置菜单栏
func _setup_menus() -> void:
	# 文件菜单
	var fp := file_menu.get_popup()
	fp.add_item("保存 (Ctrl+S)", 1)
	fp.add_item("设置封面...", 5)
	fp.add_item("另存为副本...", 6)
	fp.add_item("导出剧本...", 2)
	fp.add_item("导入剧本...", 3)
	fp.add_separator()
	fp.add_item("返回大厅", 4)
	fp.id_pressed.connect(func(id: int):
		match id:
			1: _on_save_pressed()
			2: _on_export_script_pressed()
			3: _on_import_script_pressed()
			4: _on_back_pressed()
			5: _on_set_cover_pressed()
			6: _on_clone_script_pressed()
	)
	# 编辑菜单
	var ep := edit_menu.get_popup()
	ep.add_item("撤销 (Ctrl+Z)", 12)
	ep.add_item("重做 (Ctrl+Y)", 13)
	ep.add_separator()
	ep.add_item("切换可视化模式", 10)
	ep.add_item("切换代码模式", 11)
	ep.id_pressed.connect(func(id: int):
		match id:
			10: _on_mode_visual_pressed()
			11: _on_mode_code_pressed()
			12: _global_undo()
			13: _global_redo()
	)
	# 视图菜单
	var vp := view_menu.get_popup()
	vp.add_item("收起左侧面板", 20)
	vp.id_pressed.connect(func(id: int):
		match id:
			20: _on_left_collapse_pressed()
	)
	# 运行菜单
	var rp := run_menu.get_popup()
	rp.add_item("测试运行 (F5)", 30)
	rp.add_item("发布剧本", 31)
	rp.id_pressed.connect(func(id: int):
		match id:
			30: _on_test_pressed()
			31: _on_publish_pressed()
	)
	# 帮助菜单
	var hp := help_menu.get_popup()
	hp.add_item("GDScript 剧本语法", 40)
	hp.add_item("关于剧本编辑器", 41)
	hp.id_pressed.connect(func(id: int):
		match id:
			40:
				_log_output("GDScript 剧本语法: 使用 func story_event(\"id\") 定义事件, func skill(\"id\",\"name\",\"type\") 定义技能等")
				bottom_tab_bar.current_tab = 0
				output_panel.visible = true
				validation_panel.visible = false
				template_panel.visible = false
			41: _on_about_pressed()
	)

## 构建模板树（代码模式底部面板用）
func _build_template_tree() -> void:
	if template_tree == null:
		return
	template_tree.clear()
	var root := template_tree.create_item()
	# 世界观
	var wv_item := _add_tree_category(root, "📖 世界观")
	_add_tree_template(wv_item, "背景故事", "background")
	_add_tree_template(wv_item, "时代定义", "era")
	_add_tree_template(wv_item, "势力设定", "faction")
	_add_tree_template(wv_item, "时间线事件", "timeline")
	_add_tree_template(wv_item, "世界规则", "rule")
	_add_tree_template(wv_item, "势力关系", "relation")
	_add_tree_template(wv_item, "地理区域", "region")
	_add_tree_template(wv_item, "知识条目", "lore")
	# 事件系统
	var ev_item := _add_tree_category(root, "📜 事件系统")
	_add_tree_template(ev_item, "剧情事件", "story_event")
	_add_tree_template(ev_item, "随机事件", "random_event")
	_add_tree_template(ev_item, "事件链", "event_chain")
	# 能力系统
	var ab_item := _add_tree_category(root, "⚔ 能力系统")
	_add_tree_template(ab_item, "技能", "skill")
	_add_tree_template(ab_item, "成长路线", "growth")
	_add_tree_template(ab_item, "状态效果", "status_effect")
	_add_tree_template(ab_item, "战斗机制", "combat")
	# 经济系统
	var ec_item := _add_tree_category(root, "💰 经济系统")
	_add_tree_template(ec_item, "货币", "currency")
	_add_tree_template(ec_item, "资源", "resource")
	_add_tree_template(ec_item, "市场", "market")
	_add_tree_template(ec_item, "产出规则", "production")

func _add_tree_category(parent: TreeItem, text: String) -> TreeItem:
	var item := template_tree.create_item(parent)
	item.set_text(0, text)
	item.set_custom_color(0, Color(0.35, 0.6, 1.0, 1))
	item.set_custom_font_size(0, 12)
	item.set_selectable(0, false)
	return item

func _add_tree_template(parent: TreeItem, text: String, category: String) -> void:
	var item := template_tree.create_item(parent)
	item.set_text(0, "  " + text)
	item.set_metadata(0, category)
	item.set_custom_color(0, Color(0.88, 0.88, 0.92, 1))
	item.set_custom_font_size(0, 11)

## 模板树点击 - 插入到代码编辑器
func _setup_template_tree() -> void:
	if not template_tree.item_activated.is_connected(_on_template_selected):
		template_tree.item_activated.connect(_on_template_selected)

func _on_template_selected() -> void:
	var item := template_tree.get_selected()
	if item == null:
		return
	var category: String = item.get_metadata(0)
	if not category.is_empty() and code_editor:
		code_editor.insert_template(category)
		_log_output("已插入模板: %s" % category)

func _on_left_collapse_pressed() -> void:
	_left_collapsed = not _left_collapsed
	if _left_collapsed:
		left_panel.custom_minimum_size.x = 28
		left_collapse_btn.text = "▶"
		# 隐藏内容，保留折叠按钮
		for child in left_panel.get_node("LeftVBox").get_children():
			if child != left_collapse_btn:
				child.visible = false
	else:
		left_panel.custom_minimum_size.x = 240
		left_collapse_btn.text = "◀ 收起"
		for child in left_panel.get_node("LeftVBox").get_children():
			child.visible = true

## === 键盘快捷键 ===
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		# Ctrl+S: 保存
		if event.ctrl_pressed and event.keycode == KEY_S:
			_on_save_pressed()
			get_viewport().set_input_as_handled()
		# Ctrl+Enter: 测试运行
		elif event.ctrl_pressed and event.keycode == KEY_ENTER:
			_on_test_pressed()
			get_viewport().set_input_as_handled()
		# F5: 测试运行
		elif event.keycode == KEY_F5:
			_on_test_pressed()
			get_viewport().set_input_as_handled()
		# Ctrl+Shift+K: 切换代码模式
		elif event.ctrl_pressed and event.shift_pressed and event.keycode == KEY_K:
			if editor_mode == "visual":
				_on_mode_code_pressed()
			else:
				_on_mode_visual_pressed()
			get_viewport().set_input_as_handled()
		# Ctrl+Z / Ctrl+Y: 表单撤销/重做（visual 模式 L1 表单层激活时）
		elif event.ctrl_pressed and event.keycode == KEY_Z:
			if editor_mode == "visual" and _mod_event._l1_mod.can_undo_form():
				_mod_event._l1_mod.undo_form()
				get_viewport().set_input_as_handled()
		elif event.ctrl_pressed and event.keycode == KEY_Y:
			if editor_mode == "visual" and _mod_event._l1_mod.can_redo_form():
				_mod_event._l1_mod.redo_form()
				get_viewport().set_input_as_handled()

## === 顶栏按钮 ===
func _on_back_pressed() -> void:
	# 清理编辑器缓存
	for key in _editors:
		var panel = _editors[key]
		if panel != null and is_instance_valid(panel):
			panel.queue_free()
	_editors.clear()
	SceneManager.go_back_to_hub()

func _on_save_pressed() -> void:
	if current_script == null:
		return
	# 代码模式下先应用代码
	if editor_mode == "code" and code_editor:
		code_editor.apply_code()
	ScriptDataManager.update_script(current_script)
	_update_validation()
	_build_module_tree()
	# 保存状态提示
	var now := Time.get_time_string_from_system().substr(0, 5)
	status_label.text = "💾 已保存 %s" % now
	_log_output("[color=green]✅ 已保存 %s[/color]" % now)
	status_label.text = "💾 已保存"
	ToastManager.success("剧本已保存")
	_log_output("💾 剧本已保存: %s" % current_script.name)

func _on_test_pressed() -> void:
	if current_script == null:
		return
	ScriptDataManager.update_script(current_script)
	var validator := ScriptValidator.new()
	var report := validator.validate(current_script)
	if not report["is_valid"]:
		ToastManager.error("剧本有 %d 个错误，建议修复后再测试" % report["error_count"])
		_log_output("[color=red]❌ 测试失败: %d 个错误[/color]" % report["error_count"])
		return
	_log_output("🚀 开始测试: %s" % current_script.name)
	SceneManager.enter_script(current_script_id)

func _on_publish_pressed() -> void:
	if current_script == null:
		return
	current_script.status = "published"
	ScriptDataManager.update_script(current_script)
	status_label.text = "📢 已发布"
	ToastManager.success("剧本已发布")
	GameManager.unlock_achievement("first_publish", "首次发布剧本")
	_log_output("📢 剧本已发布: %s" % current_script.name)

## 另存为副本（克隆剧本）
func _on_clone_script_pressed() -> void:
	if current_script == null:
		_log_output("⚠ 请先加载剧本")
		return
	var cloned := ScriptDataManager.clone_script(current_script.id)
	if cloned != null:
		_log_output("✅ 已创建副本: %s" % cloned.name)
		ToastManager.success("副本已创建: %s" % cloned.name)
	else:
		_log_output("[color=red]❌ 克隆失败[/color]")

## 设置剧本封面（选择图片 → assets/cover.png）
func _on_set_cover_pressed() -> void:
	if current_script == null:
		_log_output("⚠ 请先加载剧本")
		return
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray(["*.png ; PNG 图片", "*.jpg ; JPG 图片", "*.webp ; WebP 图片"])
	dialog.title = "选择封面图片"
	dialog.min_size = Vector2i(600, 400)
	add_child(dialog)
	dialog.file_selected.connect(func(path: String):
		if ScriptDataManager.set_cover(current_script.id, path):
			_log_output("✅ 封面已设置")
			ToastManager.success("封面已设置")
		else:
			_log_output("[color=red]❌ 封面设置失败[/color]")
		dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.popup_centered()

## 导出剧本到磁盘文件（.wspk 打包：含 assets 资源；.json 兼容单文件）
func _on_export_script_pressed() -> void:
	if current_script == null:
		_log_output("⚠ 请先加载剧本")
		return
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.title = "导出剧本"
	dialog.add_filter("*.json ; 剧本文件（含封面）")
	dialog.current_path = current_script.name + ".json"
	dialog.min_size = Vector2i(600, 400)
	add_child(dialog)
	dialog.file_selected.connect(func(path: String):
		# 先保存当前编辑状态
		ScriptDataManager.update_script(current_script)
		var success: bool = ScriptDataManager.export_script(current_script.id, path)
		if success:
			_log_output("✅ 剧本已导出: %s" % path)
			ToastManager.success("导出成功")
		else:
			_log_output("[color=red]❌ 导出失败: 无法写入文件[/color]")
			dialog.queue_free()
	)
	dialog.popup_centered()

## 从磁盘导入剧本文件
func _on_import_script_pressed() -> void:
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.title = "导入剧本"
	dialog.add_filter("*.json", "JSON 剧本文件")
	dialog.min_size = Vector2i(600, 400)
	add_child(dialog)
	dialog.file_selected.connect(func(path: String):
		var imported: WorldScriptData = ScriptDataManager.import_script(path)
		if imported != null:
			current_script = imported
			current_script_id = imported.id
			_build_module_tree()
			_update_validation()
			_update_script_info_display()
			_sync_to_code_editor()
			_log_output("✅ 剧本已导入: %s (id=%s)" % [imported.name, imported.id])
			ToastManager.success("导入成功: %s" % imported.name)
		else:
			_log_output("[color=red]❌ 导入失败: 文件格式无效[/color]")
		dialog.queue_free()
	)
	dialog.popup_centered()

## 关于对话框
func _on_about_pressed() -> void:
	var about := AcceptDialog.new()
	about.title = "关于剧本编辑器"
	about.dialog_text = "万界诗篇 · 剧本编辑器 v1.0\n\n基于 Godot 4.7.1 构建\n支持可视化/代码/MUD三种编辑模式\n\n功能: 事件系统 | 经济系统 | 能力系统 | 任务系统 | 战斗系统 | 地图编辑"
	about.ok_button_text = "确定"
	add_child(about)
	about.popup_centered()
	about.confirmed.connect(about.queue_free)

## === 配色常量 (引用UIFactory集中定义) ===
const C_BG_CARD := UIFactoryClass.C_BG_CARD
const C_BG_ROW := UIFactoryClass.C_BG_ROW
const C_BG_ROW_ALT := UIFactoryClass.C_BG_ROW_ALT
const C_ACCENT := UIFactoryClass.C_ACCENT
const C_ACCENT_DIM := UIFactoryClass.C_ACCENT_DIM
const C_SECTION_TITLE := UIFactoryClass.C_SECTION_TITLE
const C_LABEL := UIFactoryClass.C_LABEL
const C_TEXT := UIFactoryClass.C_TEXT
const C_INFO := UIFactoryClass.C_INFO
const C_GREEN := UIFactoryClass.C_GREEN
const C_BORDER := UIFactoryClass.C_BORDER
const C_DANGER := UIFactoryClass.C_DANGER
const C_EMPTY_HINT := UIFactoryClass.C_EMPTY_HINT

## === 字段友好标签映射 (引用UIFactory) ===
const FIELD_LABELS := UIFactoryClass.FIELD_LABELS

## === UI构建辅助方法 (委托给 EditorUIFactory) ===

func _make_bg_style() -> StyleBoxFlat:
	return _ui.make_bg_style()

func _make_content_style() -> StyleBoxFlat:
	return _ui.make_content_style()

func _make_nav_style() -> StyleBoxFlat:
	return _ui.make_nav_style()

func _add_nav_title(parent: Control, text: String) -> void:
	_ui.add_nav_title(parent, text)

func _add_nav_btn(parent: Control, text: String, key: String, active_key: String, on_select: Callable) -> void:
	_ui.add_nav_btn(parent, text, key, active_key, on_select)

func _add_toolbar_btn(parent: Control, text: String, on_press: Callable) -> Button:
	return _ui.add_toolbar_btn(parent, text, on_press)

func _make_scroll_panel() -> PanelContainer:
	return _ui.make_scroll_panel()

func _make_vbox(parent: Control) -> VBoxContainer:
	return _ui.make_vbox(parent)

func _add_section_label(parent: Control, text: String, level: int = 1) -> void:
	_ui.add_section_label(parent, text, level)

func _add_hseparator(parent: Control) -> void:
	_ui.add_hseparator(parent)

func _add_info_label(parent: Control, text: String) -> void:
	_ui.add_info_label(parent, text)

func _add_stat_card(parent: Control, stats: Array) -> void:
	_ui.add_stat_card(parent, stats)

func _add_text_field(parent: Control, label_text: String, value: String, on_change: Callable) -> void:
	_ui.add_text_field(parent, label_text, value, on_change)

func _add_labeled_field(parent: Control, label_text: String, value: String, on_change: Callable) -> void:
	_ui.add_labeled_field(parent, label_text, value, on_change)

func _add_multiline_field(parent: Control, value: String, on_change: Callable) -> void:
	_ui.add_multiline_field(parent, value, on_change)

func _add_spin_field(parent: Control, label_text: String, value: float, min_val: float, max_val: float, on_change: Callable) -> void:
	_ui.add_spin_field(parent, label_text, value, min_val, max_val, on_change)

func _add_button(parent: Control, text: String, on_press: Callable) -> void:
	_ui.add_button(parent, text, on_press)

func _field_label(field: String) -> String:
	return _ui.field_label(field)

func _add_list_editor(parent: Control, data_array: Array, fields: Array, on_add: Callable) -> void:
	_ui.add_list_editor(parent, data_array, fields, on_add)

func _add_dict_editor(parent: Control, data: Dictionary, keys: Array) -> void:
	_ui.add_dict_editor(parent, data, keys)

## === 模式切换 ===

## 数据同步到代码编辑器
func _sync_to_code_editor() -> void:
	if code_editor and current_script and editor_mode == "visual":
		code_editor.load_data(current_script)

## 初始化代码编辑器
func _init_code_editor() -> void:
	code_editor = ScriptCodeEditorClass.new()
	code_editor.on_code_applied = func(result: Dictionary):
		if result.get("success", false):
			_build_module_tree()
			_update_validation()
	code_editor.build_into(code_editor_container)

## 初始化MUD编辑器
func _init_mud_editor() -> void:
	mud_editor = MudEditorClass.new()
	mud_editor.build_into(mud_editor_container)
	if current_script:
		mud_editor.load_data(current_script)

func _on_script_settings_pressed() -> void:
	if current_script == null:
		_log_output("⚠ 请先加载剧本")
		return
	_build_script_settings_dialog()

func _build_script_settings_dialog() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "⚙ 剧本设置"
	dialog.min_size = Vector2i(420, 320)
	add_child(dialog)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	dialog.add_child(vbox)

	# === 1. 世界类型 ===
	var world_type_hbox := HBoxContainer.new()
	world_type_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(world_type_hbox)
	var world_type_label := Label.new()
	world_type_label.text = "世界类型:"
	world_type_label.custom_minimum_size.x = 90
	world_type_hbox.add_child(world_type_label)
	var world_type_opt := OptionButton.new()
	world_type_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	world_type_opt.add_item("奇幻世界", 0)
	world_type_opt.add_item("科幻世界", 1)
	world_type_opt.add_item("历史架空", 2)
	world_type_opt.add_item("现代都市", 3)
	world_type_opt.add_item("末日废土", 4)
	world_type_opt.add_item("蒸汽朋克", 5)
	world_type_opt.add_item("自定义", 6)
	# 读取当前值
	var wv = current_script.worldview
	if wv:
		var wt_str: String = wv.world_type
		match wt_str:
			"科幻世界": world_type_opt.selected = 1
			"历史架空": world_type_opt.selected = 2
			"现代都市": world_type_opt.selected = 3
			"末日废土": world_type_opt.selected = 4
			"蒸汽朋克": world_type_opt.selected = 5
			"自定义": world_type_opt.selected = 6
			_: world_type_opt.selected = 0
	world_type_hbox.add_child(world_type_opt)

	# === 2. 默认AI模型 ===
	var ai_hbox := HBoxContainer.new()
	ai_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(ai_hbox)
	var ai_label := Label.new()
	ai_label.text = "默认AI模型:"
	ai_label.custom_minimum_size.x = 90
	ai_hbox.add_child(ai_label)
	var ai_opt := OptionButton.new()
	ai_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ai_opt.add_item("GPT-4o", 0)
	ai_opt.add_item("GPT-4o-mini", 1)
	ai_opt.add_item("Claude 3.5", 2)
	ai_opt.add_item("Qwen2.5-72B（本地）", 3)
	ai_opt.add_item("无（不使用AI）", 4)
	# 读取当前值
	var meta_dict: Dictionary = current_script.metadata
	if not meta_dict.is_empty():
		var ai_val: Variant = meta_dict.get("default_ai_model") if meta_dict.has("default_ai_model") else "GPT-4o"
		var ai_str: String = ai_val as String
		match ai_str:
			"GPT-4o-mini": ai_opt.selected = 1
			"Claude 3.5": ai_opt.selected = 2
			"Qwen2.5-72B（本地）": ai_opt.selected = 3
			"无（不使用AI）": ai_opt.selected = 4
			_: ai_opt.selected = 0
	ai_hbox.add_child(ai_opt)

	# === 3. 界面表现形式 ===
	var mode_hbox := VBoxContainer.new()
	mode_hbox.add_theme_constant_override("separation", 6)
	vbox.add_child(mode_hbox)
	var mode_title := Label.new()
	mode_title.text = "界面表现形式:"
	mode_hbox.add_child(mode_title)
	var mode_group := ButtonGroup.new()
	var mode_names: Array[String] = [
		"📜 传统对话形式（文字冒泡）视觉小说风格，逐段展示文本+选项分支）",
		"🖥 MUD游玩形式（命令行终端风格，输入指令交互，文字滚动输出）",
		"🎬 场景转换形式（场景卡片切换风格，每个场景有背景描述/角色立绘位）"
	]
	var mode_values: Array[String] = ["dialogue", "mud", "scene"]
	var mode_buttons: Array[CheckBox] = []
	for i in 3:
		var cb := CheckBox.new()
		cb.text = mode_names[i]
		cb.button_group = mode_group
		cb.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		mode_hbox.add_child(cb)
		mode_buttons.append(cb)
	# 读取当前值
	var current_mode: String = "dialogue"
	if not meta_dict.is_empty():
		var pm_val: Variant = meta_dict.get("presentation_mode") if meta_dict.has("presentation_mode") else "dialogue"
		current_mode = pm_val as String
	for i in 3:
		if mode_values[i] == current_mode:
			mode_buttons[i].button_pressed = true

	# === 确认按钮 ===
	dialog.confirmed.connect(func():
		# 写入数据
		var world_types: Array[String] = ["奇幻世界", "科幻世界", "历史架空", "现代都市", "末日废土", "蒸汽朋克", "自定义"]
		var ai_models: Array[String] = ["GPT-4o", "GPT-4o-mini", "Claude 3.5", "Qwen2.5-72B（本地）", "无（不使用AI）"]
		var selected_mode: String = "dialogue"
		for i in 3:
			if mode_buttons[i].button_pressed:
				selected_mode = mode_values[i]
				break
		# 写入 worldview.world_type
		if wv:
			wv.world_type = world_types[world_type_opt.selected]
		# 写入 metadata
		current_script.metadata["default_ai_model"] = ai_models[ai_opt.selected]
		current_script.metadata["presentation_mode"] = selected_mode
		# 持久化
		ScriptDataManager.update_script(current_script)
		_log_output("✅ 剧本设置已更新")
		# 刷新顶栏信息
		_update_script_info_display()
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.popup_centered()

## === 切换编辑器（带内容转译） ===
func _on_switch_editor_pressed() -> void:
	if current_script == null:
		_log_output("⚠ 请先加载剧本")
		return
	_build_switch_editor_dialog()

## 当前模式显示名
func _get_mode_display() -> String:
	match editor_mode:
		"code": return "💻 核心编辑器"
		"mud": return "🖥 MUD编辑器"
		_: return "📊 可视化编辑器"

## 模式短名
func _mode_name(mode: String) -> String:
	match mode:
		"code": return "核心编辑器"
		"mud": return "MUD编辑器"
		_: return "可视化编辑器"

## 构建切换编辑器对话框（纯代码动态构建，带明确的确认/取消按钮）
func _build_switch_editor_dialog() -> void:
	var overlay_root := Control.new()
	overlay_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay_root)

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.5)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_root.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.14, 0.15, 0.19, 1.0)
	panel_style.border_color = Color(0.6, 0.85, 0.85, 1.0)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(12)
	panel_style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "🔄 切换编辑器"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.6, 0.85, 0.85, 1))
	vbox.add_child(title)

	var cur_label := Label.new()
	cur_label.text = "当前编辑器: %s" % _get_mode_display()
	cur_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(cur_label)

	var info := Label.new()
	info.text = "切换时，当前编辑器中的编辑内容将自动转译并同步到目标编辑器。"
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_font_size_override("font_size", 12)
	info.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75, 1))
	vbox.add_child(info)

	vbox.add_child(HSeparator.new())

	var target_label := Label.new()
	target_label.text = "选择目标编辑器:"
	target_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(target_label)

	var mode_group := ButtonGroup.new()
	var mode_keys: Array[String] = ["visual", "code", "mud"]
	var mode_titles: Array[String] = ["📊 可视化编辑器", "💻 核心编辑器", "🖥 MUD编辑器"]
	var mode_descs: Array[String] = [
		"表单式编辑世界观/事件/经济/能力模块",
		"GDScript 风格代码编辑，与模型双向编译",
		"MUD 数据表编辑（地图/物品/NPC/技能）",
	]
	var mode_buttons: Dictionary = {}
	for i in mode_keys.size():
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		vbox.add_child(hbox)
		var rb := CheckBox.new()
		rb.text = mode_titles[i]
		rb.button_group = mode_group
		rb.button_pressed = (mode_keys[i] == editor_mode)
		hbox.add_child(rb)
		var desc := Label.new()
		desc.text = mode_descs[i]
		desc.add_theme_font_size_override("font_size", 11)
		desc.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6, 1))
		hbox.add_child(desc)
		mode_buttons[mode_keys[i]] = rb

	vbox.add_child(HSeparator.new())

	# 按钮行（明确可见的确认/取消按钮）
	var btn_box := HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_box)

	var cancel_btn := Button.new()
	cancel_btn.text = "取消"
	cancel_btn.custom_minimum_size = Vector2(100, 36)
	btn_box.add_child(cancel_btn)

	var confirm_btn := Button.new()
	confirm_btn.text = "🔄 确认切换"
	confirm_btn.custom_minimum_size = Vector2(140, 36)
	var confirm_style := StyleBoxFlat.new()
	confirm_style.bg_color = Color(0.3, 0.55, 0.55, 1.0)
	confirm_style.set_corner_radius_all(6)
	confirm_style.set_content_margin_all(8)
	confirm_btn.add_theme_stylebox_override("normal", confirm_style)
	var confirm_hover := confirm_style.duplicate()
	confirm_hover.bg_color = Color(0.38, 0.68, 0.68, 1.0)
	confirm_btn.add_theme_stylebox_override("hover", confirm_hover)
	btn_box.add_child(confirm_btn)

	cancel_btn.pressed.connect(func(): overlay_root.queue_free())

	confirm_btn.pressed.connect(func():
		var target_mode := ""
		for mode_key in mode_buttons:
			if (mode_buttons[mode_key] as CheckBox).button_pressed:
				target_mode = mode_key
				break
		if target_mode.is_empty() or target_mode == editor_mode:
			ToastManager.warning("请选择与当前不同的编辑器模式")
			return
		overlay_root.queue_free()
		_switch_editor_with_translation(target_mode)
	)

## 切换编辑器并转译内容
## 转译路径: 当前编辑器 → 共享数据模型(WorldScriptData) → 目标编辑器
func _switch_editor_with_translation(target_mode: String) -> void:
	var from_mode := editor_mode
	# 切换动作内部自动完成转译:
	#   离开时 - 当前编辑器内容落盘到共享模型 (apply_code / save_data)
	#   进入时 - 从共享模型加载到目标编辑器 (load_data / 重建模块树)
	match target_mode:
		"visual": _on_mode_visual_pressed()
		"code": _on_mode_code_pressed()
		"mud": _on_mode_mud_pressed()
	# 持久化转译后的数据
	ScriptDataManager.update_script(current_script)
	_log_output("🔄 编辑器已切换: %s → %s，编辑内容已转译同步" % [_mode_name(from_mode), _mode_name(target_mode)])
	ToastManager.success("已切换到%s，编辑内容已转译" % _mode_name(target_mode))

func _on_mode_visual_pressed() -> void:
	if editor_mode == "visual":
		return
	# 切换前保存/应用数据
	if code_editor:
		code_editor.apply_code()
	if mud_editor and editor_mode == "mud":
		mud_editor.save_data()
	editor_mode = "visual"
	# 过渡动画
	var tween := create_tween()
	tween.tween_property(code_editor_container, "modulate:a", 0.0, 0.1)
	tween.tween_property(mud_editor_container, "modulate:a", 0.0, 0.1)
	tween.tween_callback(func():
		main_hsplit.visible = true
		code_editor_container.visible = false
		mud_editor_container.visible = false
		code_editor_container.modulate.a = 1.0
	)
	tween.tween_property(main_hsplit, "modulate:a", 1.0, 0.1)
	_update_mode_buttons()
	_build_module_tree()
	_update_validation()
	mode_label.text = "可视化模式"
	mode_label.add_theme_color_override("font_color", Color(0.55, 0.85, 0.55, 1))
	_log_output("切换到可视化模式")

func _on_mode_code_pressed() -> void:
	if editor_mode == "code":
		return
	# 切换前保存MUD数据
	if mud_editor and editor_mode == "mud":
		mud_editor.save_data()
	editor_mode = "code"
	# 过渡动画
	var tween := create_tween()
	tween.tween_property(main_hsplit, "modulate:a", 0.0, 0.1)
	tween.tween_property(mud_editor_container, "modulate:a", 0.0, 0.1)
	tween.tween_callback(func():
		main_hsplit.visible = false
		mud_editor_container.visible = false
		code_editor_container.visible = true
		code_editor_container.modulate.a = 1.0
	)
	tween.tween_property(code_editor_container, "modulate:a", 1.0, 0.1)
	_update_mode_buttons()
	# 加载数据到代码编辑器
	if code_editor and current_script:
		code_editor.load_data(current_script)
	mode_label.text = "代码模式"
	mode_label.add_theme_color_override("font_color", Color(0.55, 0.65, 0.85, 1))
	_log_output("切换到代码模式 (GDScript)")

func _on_mode_mud_pressed() -> void:
	if editor_mode == "mud":
		return
	# 切换前应用代码
	if code_editor and editor_mode == "code":
		code_editor.apply_code()
	editor_mode = "mud"
	# 过渡动画
	var tween := create_tween()
	tween.tween_property(main_hsplit, "modulate:a", 0.0, 0.1)
	tween.tween_property(code_editor_container, "modulate:a", 0.0, 0.1)
	tween.tween_callback(func():
		main_hsplit.visible = false
		code_editor_container.visible = false
		mud_editor_container.visible = true
		mud_editor_container.modulate.a = 1.0
	)
	tween.tween_property(mud_editor_container, "modulate:a", 1.0, 0.1)
	_update_mode_buttons()
	# 加载数据到MUD编辑器
	if mud_editor and current_script:
		mud_editor.load_data(current_script)
	mode_label.text = "MUD模式"
	mode_label.add_theme_color_override("font_color", Color(0.95, 0.75, 0.35, 1))
	_log_output("切换到MUD编辑器模式")

func _update_mode_buttons() -> void:
	mode_visual_btn.disabled = editor_mode == "visual"
	mode_code_btn.disabled = editor_mode == "code"
	mode_mud_btn.disabled = editor_mode == "mud"

# === 阶段4: 全局基础设施 ===

# --- 4.1 全局撤销/重做 ---

## 标记数据已修改
func _mark_dirty(subsystem: String = "") -> void:
	_is_dirty = true
	if subsystem == "":
		# 未指定子系统: 按当前活动编辑器推断
		var mapped := _map_editor_key_to_subsystem(_current_editor_key)
		_dirty_subsystems[mapped if mapped != "" else "__all__"] = true
	else:
		_dirty_subsystems[subsystem] = true

## 编辑器 key -> 子系统键映射（用于差分保存推断）
## quest/combat 数据内联于主文件(始终写入), 返回对应键使其不触发拆分文件重写
func _map_editor_key_to_subsystem(key: String) -> String:
	if key.begins_with("event_"):
		return "event_system"
	if key.begins_with("economy_"):
		return "economy_system"
	if key.begins_with("ability_"):
		return "ability_system"
	if key.begins_with("worldview_"):
		return "worldview"
	if key.begins_with("quest_"):
		return "quest_system"
	if key.begins_with("combat_"):
		return "combat_system"
	if key.begins_with("map_"):
		return "worldview"
	return ""  # welcome/mud/code 等 → 全量

## 全局撤销
func _global_undo() -> void:
	if _undo_redo.has_undo():
		_undo_redo.undo()
		_mark_dirty()
		_log_output("[撤销] %s" % _undo_redo.get_current_action_name())

## 全局重做
func _global_redo() -> void:
	if _undo_redo.has_redo():
		_undo_redo.redo()
		_mark_dirty()
		_log_output("[重做] %s" % _undo_redo.get_current_action_name())

# --- 4.2 自动保存 ---

## 设置自动保存定时器
func _setup_auto_save() -> void:
	_auto_save_timer = Timer.new()
	_auto_save_timer.wait_time = AUTO_SAVE_INTERVAL
	_auto_save_timer.autostart = true
	_auto_save_timer.timeout.connect(_do_auto_save)
	add_child(_auto_save_timer)

## 执行自动保存
func _do_auto_save() -> void:
	if not _is_dirty or current_script == null:
		return
	# 保存剧本数据
	_save_current_script()
	_is_dirty = false
	status_label.text = "💾 已自动保存"
	_log_output("[自动保存] 剧本数据已保存")

## 手动保存 (Ctrl+S)
func _save_current_script() -> void:
	if current_script == null:
		return
	# 通过剧本数据管理器持久化到本地 (user://scripts/), 差分写入脏子系统
	ScriptDataManager.update_script(current_script, _dirty_subsystems.keys())
	_dirty_subsystems.clear()
	_is_dirty = false
	status_label.text = "💾 已保存"

# --- 4.3 多标签页编辑 ---

## 初始化标签页容器（替换editor_container的直接使用）
func _setup_tab_container() -> void:
	if _tab_container != null:
		return
	_tab_container = TabContainer.new()
	_tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Godot 4.7：关闭按钮配置在 TabBar（TabContainer 不再有 tabs_closable）
	var tab_bar := _tab_container.get_tab_bar()
	tab_bar.tab_close_display_policy = TabBar.CLOSE_BUTTON_SHOW_ACTIVE_ONLY
	# 挂载到 editor_container 所在位置（多标签与单容器互斥显示）
	var parent := editor_container.get_parent()
	if parent:
		parent.add_child(_tab_container)
		parent.move_child(_tab_container, editor_container.get_index())
	_tab_container.visible = false
	# 连接标签关闭信号
	# 连接标签关闭信号（4.7 在 TabBar 上）
	tab_bar.tab_close_pressed.connect(_on_tab_close)
	_tab_container.tab_changed.connect(_on_tab_changed)

## 打开新标签页（panel 已在标签中则激活，避免重复）
func _open_tab(tab_name: String, editor_key: String, panel: Control) -> void:
	if _tab_container == null:
		_setup_tab_container()
	# panel 已在标签容器中 → 直接激活该标签
	if panel.get_parent() == _tab_container:
		for i in _tab_container.get_tab_count():
			if _tab_container.get_child(i) == panel:
				_tab_container.current_tab = i
				_tab_container.set_tab_title(i, tab_name)
				_current_editor_key = editor_key
				return
	# 标题已存在 → 激活
	for i in _tab_container.get_tab_count():
		if _tab_container.get_tab_title(i) == tab_name:
			_tab_container.current_tab = i
			_current_editor_key = editor_key
			return
	# 新增标签
	if panel.get_parent() != null:
		panel.get_parent().remove_child(panel)
	_tab_container.add_child(panel)
	var idx := _tab_container.get_tab_count() - 1
	_tab_container.set_tab_title(idx, tab_name)
	_current_editor_key = editor_key
	_tab_editor_map[tab_name] = editor_key
	_tab_container.current_tab = idx

## 关闭标签页
func _on_tab_close(tab_idx: int) -> void:
	var tab_name := _tab_container.get_tab_title(tab_idx)
	var child := _tab_container.get_child(tab_idx)
	_tab_container.remove_child(child)
	child.queue_free()
	_tab_editor_map.erase(tab_name)
	# 同步释放 _editors 缓存（防止重开引用已释放面板）
	var key_to_erase: String = ""
	for k in _editors:
		if _editors[k] == child:
			key_to_erase = k
			break
	if not key_to_erase.is_empty():
		_editors.erase(key_to_erase)

## 标签页切换
func _on_tab_changed(tab_idx: int) -> void:
	if tab_idx < 0 or tab_idx >= _tab_container.get_tab_count():
		return
	var tab_name := _tab_container.get_tab_title(tab_idx)
	status_label.text = "📑 %s" % tab_name

# --- 4.4 状态栏增强 ---

## 更新蓝图状态信息
func _update_blueprint_status() -> void:
	var graph: Dictionary = _mod_event._bp_mod._get_active_graph()
	var node_count: int = graph["nodes"].size()
	var conn_count: int = graph["connections"].size()
	var zoom_pct: int = int(_mod_event._bp_mod._bp_zoom * 100)
	if node_count_label:
		node_count_label.text = "节点: %d | 连线: %d | 缩放: %d%%" % [node_count, conn_count, zoom_pct]
