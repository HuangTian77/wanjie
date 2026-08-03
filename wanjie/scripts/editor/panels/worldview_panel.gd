## 世界观编辑面板
extends Control

var worldview_data: WorldviewData = null

@onready var bg_edit: TextEdit = %BgEdit
@onready var era_list: ItemList = %EraList
@onready var era_detail: VBoxContainer = %EraDetail
@onready var rule_list: ItemList = %RuleList
@onready var faction_list: ItemList = %FactionList
@onready var faction_detail: VBoxContainer = %FactionDetail
@onready var tab_bar: TabBar = %TabBar
@onready var bg_vbox: VBoxContainer = %BgVBox
@onready var era_vbox: VBoxContainer = %EraVBox
@onready var rule_vbox: VBoxContainer = %RuleVBox
@onready var faction_vbox: VBoxContainer = %FactionVBox

func _ready() -> void:
	if worldview_data:
		_load_data()
	tab_bar.tab_changed.connect(_on_tab_changed)
	_on_tab_changed(0)

## === TabBar切换 ===
func _on_tab_changed(tab: int) -> void:
	bg_vbox.visible = (tab == 0)
	era_vbox.visible = (tab == 1)
	rule_vbox.visible = (tab == 2)
	faction_vbox.visible = (tab == 3)

func _load_data() -> void:
	bg_edit.text = worldview_data.background_story
	_refresh_era_list()
	_refresh_rule_list()
	_refresh_faction_list()

## === 背景故事 ===
func _on_bg_edit_text_changed() -> void:
	if worldview_data:
		worldview_data.background_story = bg_edit.text

## === 时代定义 ===
func _refresh_era_list() -> void:
	era_list.clear()
	if worldview_data == null:
		return
	for i in worldview_data.era_definitions.size():
		var era: Dictionary = worldview_data.era_definitions[i]
		era_list.add_item("%s (%d-%d)" % [era.get("era_name", ""), era.get("start_year", 0), era.get("end_year", 0)])

func _on_add_era_pressed() -> void:
	if worldview_data == null:
		return
	worldview_data.add_era("新时代", 0, 100, "时代描述")
	_refresh_era_list()

func _on_remove_era_pressed() -> void:
	if worldview_data == null or era_list.selected_items.is_empty():
		return
	var idx: int = era_list.selected_items[0]
	if idx >= 0 and idx < worldview_data.era_definitions.size():
		worldview_data.era_definitions.remove_at(idx)
		_refresh_era_list()

## === 世界规则 ===
func _refresh_rule_list() -> void:
	rule_list.clear()
	if worldview_data == null:
		return
	for rule in worldview_data.world_rules:
		rule_list.add_item("[%s] %s = %s" % [rule.get("category", ""), rule.get("key", ""), rule.get("value", "")])

func _on_add_rule_pressed() -> void:
	if worldview_data == null:
		return
	worldview_data.add_rule("physics", "新规则", "值", "描述")
	_refresh_rule_list()

func _on_remove_rule_pressed() -> void:
	if worldview_data == null or rule_list.selected_items.is_empty():
		return
	var idx: int = rule_list.selected_items[0]
	if idx >= 0 and idx < worldview_data.world_rules.size():
		worldview_data.world_rules.remove_at(idx)
		_refresh_rule_list()

## === 势力设定 ===
func _refresh_faction_list() -> void:
	faction_list.clear()
	if worldview_data == null:
		return
	for f in worldview_data.factions:
		faction_list.add_item("%s (实力:%d)" % [f.get("name", ""), f.get("power_level", 0)])

func _on_add_faction_pressed() -> void:
	if worldview_data == null:
		return
	var new_id := "faction_%d" % worldview_data.factions.size()
	worldview_data.add_faction(new_id, "新势力", "势力描述", 50)
	_refresh_faction_list()

func _on_remove_faction_pressed() -> void:
	if worldview_data == null or faction_list.selected_items.is_empty():
		return
	var idx: int = faction_list.selected_items[0]
	if idx >= 0 and idx < worldview_data.factions.size():
		worldview_data.factions.remove_at(idx)
		_refresh_faction_list()

## 收集数据（编辑器调用）
func get_data() -> void:
	if worldview_data:
		worldview_data.background_story = bg_edit.text
