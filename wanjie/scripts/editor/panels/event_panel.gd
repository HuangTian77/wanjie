## 事件编辑面板
extends Control

var event_data: EventSystemData = null

@onready var event_list: ItemList = %EventList
@onready var event_name_edit: LineEdit = %EventNameEdit
@onready var event_desc_edit: TextEdit = %EventDescEdit
@onready var trigger_option: OptionButton = %TriggerOption
@onready var prereq_edit: LineEdit = %PrereqEdit
@onready var condition_list: ItemList = %ConditionList
@onready var choice_list: ItemList = %ChoiceList
@onready var random_event_list: ItemList = %RandomEventList
@onready var chain_list: ItemList = %ChainList

var _current_event_id: String = ""

func _ready() -> void:
	_setup_trigger_options()
	if event_data:
		_refresh_event_list()
		_refresh_random_list()
		_refresh_chain_list()

func _setup_trigger_options() -> void:
	trigger_option.add_item("链式触发 (chain)", 0)
	trigger_option.add_item("时间触发 (time)", 1)
	trigger_option.add_item("条件触发 (condition)", 2)
	trigger_option.add_item("玩家行为 (player_action)", 3)

## === 剧情事件 ===
func _refresh_event_list() -> void:
	event_list.clear()
	if event_data == null: return
	for e in event_data.story_events:
		event_list.add_item(e.get("name", e.get("id", "")))

func _on_add_event_pressed() -> void:
	if event_data == null: return
	var new_id := "story_%03d" % (event_data.story_events.size() + 1)
	event_data.add_story_event(new_id, "新事件", "事件描述")
	_refresh_event_list()

func _on_remove_event_pressed() -> void:
	if event_data == null or event_list.selected_items.is_empty(): return
	var idx: int = event_list.selected_items[0]
	if idx >= 0 and idx < event_data.story_events.size():
		event_data.story_events.remove_at(idx)
		_refresh_event_list()

func _on_event_list_item_selected(index: int) -> void:
	if event_data == null or index >= event_data.story_events.size(): return
	_current_event_id = event_data.story_events[index]["id"]
	_load_event_detail(index)

func _load_event_detail(index: int) -> void:
	var e: Dictionary = event_data.story_events[index]
	event_name_edit.text = e.get("name", "")
	event_desc_edit.text = e.get("description", "")
	prereq_edit.text = e.get("prerequisite", "")
	# 设置触发类型
	match e.get("trigger_type", "chain"):
		"chain": trigger_option.selected = 0
		"time": trigger_option.selected = 1
		"condition": trigger_option.selected = 2
		"player_action": trigger_option.selected = 3
	# 刷新条件和选择列表
	_refresh_conditions()
	_refresh_choices()

func _refresh_conditions() -> void:
	condition_list.clear()
	if event_data == null or _current_event_id.is_empty(): return
	var e := event_data.get_story_event(_current_event_id)
	for c in e.get("conditions", []):
		condition_list.add_item("[%s] %s" % [c.get("type", ""), c.get("check", "")])

func _refresh_choices() -> void:
	choice_list.clear()
	if event_data == null or _current_event_id.is_empty(): return
	var e := event_data.get_story_event(_current_event_id)
	for c in e.get("choices", []):
		choice_list.add_item("%s: %s" % [c.get("id", ""), c.get("text", "")])

func _on_add_condition_pressed() -> void:
	if event_data == null or _current_event_id.is_empty(): return
	event_data.add_condition(_current_event_id, "world_state", "variable == value")
	_refresh_conditions()

func _on_add_choice_pressed() -> void:
	if event_data == null or _current_event_id.is_empty(): return
	var choice_id := "choice_%s" % char(97 + event_data.get_story_event(_current_event_id).get("choices", []).size())
	event_data.add_choice(_current_event_id, choice_id, "新选择")
	_refresh_choices()

func _on_event_name_changed(new_text: String) -> void:
	if event_data == null or _current_event_id.is_empty(): return
	for e in event_data.story_events:
		if e["id"] == _current_event_id:
			e["name"] = new_text
			break
	_refresh_event_list()

func _on_event_desc_changed() -> void:
	if event_data == null or _current_event_id.is_empty(): return
	for e in event_data.story_events:
		if e["id"] == _current_event_id:
			e["description"] = event_desc_edit.text
			break

## === 随机事件 ===
func _refresh_random_list() -> void:
	random_event_list.clear()
	if event_data == null: return
	for e in event_data.random_events:
		random_event_list.add_item("%s (概率:%.0f%%)" % [e.get("name", ""), e.get("probability", 0) * 100])

func _on_add_random_event_pressed() -> void:
	if event_data == null: return
	var new_id := "random_%03d" % (event_data.random_events.size() + 1)
	event_data.add_random_event(new_id, "新随机事件")
	_refresh_random_list()

## === 事件链 ===
func _refresh_chain_list() -> void:
	chain_list.clear()
	if event_data == null: return
	for c in event_data.event_chains:
		chain_list.add_item("%s (起始:%s)" % [c.get("name", ""), c.get("start_event", "")])

func _on_add_chain_pressed() -> void:
	if event_data == null: return
	var new_id := "chain_%03d" % (event_data.event_chains.size() + 1)
	event_data.add_event_chain(new_id, "新事件链", "")
	_refresh_chain_list()

func get_data() -> void:
	pass  # 数据直接写入event_data引用
