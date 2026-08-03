## 能力编辑面板
## 编辑技能、成长路线、状态效果
extends Control

## 能力数据引用
var ability_data: AbilitySystemData = null
## 当前选中索引
var _skill_idx: int = -1
var _path_idx: int = -1
var _effect_idx: int = -1

@onready var tab_bar: TabBar = %TabBar
@onready var skill_panel: HSplitContainer = %SkillPanel
@onready var path_panel: HSplitContainer = %PathPanel
@onready var effect_panel: HSplitContainer = %EffectPanel

@onready var skill_list: ItemList = %SkillList
@onready var skill_name_edit: LineEdit = %SkillNameEdit
@onready var skill_cat_option: OptionButton = %SkillCatOption
@onready var skill_school_edit: LineEdit = %SkillSchoolEdit
@onready var skill_mana_edit: SpinBox = %SkillManaEdit
@onready var skill_cd_edit: LineEdit = %SkillCDEdit
@onready var skill_desc_edit: LineEdit = %SkillDescEdit

@onready var path_list: ItemList = %PathList
@onready var path_name_edit: LineEdit = %PathNameEdit
@onready var path_desc_edit: LineEdit = %PathDescEdit
@onready var stage_list: ItemList = %StageList

@onready var effect_list: ItemList = %EffectList
@onready var effect_name_edit: LineEdit = %EffectNameEdit
@onready var effect_type_option: OptionButton = %EffectTypeOption
@onready var effect_dur_edit: LineEdit = %EffectDurEdit
@onready var effect_dmg_edit: SpinBox = %EffectDmgEdit
@onready var effect_stack_toggle: CheckButton = %EffectStackToggle

## 加载数据
func load_data(data: AbilitySystemData) -> void:
	ability_data = data
	_refresh_all()

## 刷新所有列表
func _refresh_all() -> void:
	_refresh_skills()
	_refresh_paths()
	_refresh_effects()

## === TabBar切换 ===
func _on_tab_changed(tab: int) -> void:
	skill_panel.visible = (tab == 0)
	path_panel.visible = (tab == 1)
	effect_panel.visible = (tab == 2)

## === 技能 ===
func _refresh_skills() -> void:
	skill_list.clear()
	if ability_data == null:
		return
	for s in ability_data.skills:
		skill_list.add_item("%s [%s]" % [s.get("name", ""), s.get("category", "")])
	_skill_idx = -1
	_set_skill_detail_visible(false)

func _set_skill_detail_visible(vis: bool) -> void:
	skill_name_edit.editable = vis
	skill_cat_option.disabled = not vis
	skill_school_edit.editable = vis
	skill_mana_edit.editable = vis
	skill_cd_edit.editable = vis
	skill_desc_edit.editable = vis

func _on_add_skill_pressed() -> void:
	if ability_data == null:
		return
	ability_data.add_skill("skill_%d" % ability_data.skills.size(), "新技能")
	_refresh_skills()

func _on_remove_skill_pressed() -> void:
	if ability_data == null or _skill_idx < 0 or _skill_idx >= ability_data.skills.size():
		return
	ability_data.skills.remove_at(_skill_idx)
	_refresh_skills()

func _on_skill_selected(idx: int) -> void:
	_skill_idx = idx
	if idx < 0 or idx >= ability_data.skills.size():
		_set_skill_detail_visible(false)
		return
	var s: Dictionary = ability_data.skills[idx]
	_set_skill_detail_visible(true)
	skill_name_edit.text = s.get("name", "")
	var cat_str: String = s.get("category", "active")
	skill_cat_option.selected = ["active", "passive", "ultimate"].find(cat_str)
	skill_school_edit.text = s.get("school", "")
	var cost: Dictionary = s.get("cost", {})
	skill_mana_edit.value = float(cost.get("mana", 0))
	skill_cd_edit.text = cost.get("cooldown", "0s")
	skill_desc_edit.text = s.get("description", "")

func _on_skill_name_changed(text: String) -> void:
	if _skill_idx >= 0 and _skill_idx < ability_data.skills.size():
		ability_data.skills[_skill_idx]["name"] = text
		skill_list.set_item_text(_skill_idx, "%s [%s]" % [text, ability_data.skills[_skill_idx].get("category", "")])

func _on_skill_cat_changed(idx: int) -> void:
	if _skill_idx >= 0 and _skill_idx < ability_data.skills.size():
		var cats := ["active", "passive", "ultimate"]
		if idx >= 0 and idx < cats.size():
			ability_data.skills[_skill_idx]["category"] = cats[idx]
			skill_list.set_item_text(_skill_idx, "%s [%s]" % [ability_data.skills[_skill_idx].get("name", ""), cats[idx]])

func _on_skill_school_changed(text: String) -> void:
	if _skill_idx >= 0 and _skill_idx < ability_data.skills.size():
		ability_data.skills[_skill_idx]["school"] = text

func _on_skill_mana_changed(value: float) -> void:
	if _skill_idx >= 0 and _skill_idx < ability_data.skills.size():
		ability_data.skills[_skill_idx]["cost"]["mana"] = int(value)

func _on_skill_cd_changed(text: String) -> void:
	if _skill_idx >= 0 and _skill_idx < ability_data.skills.size():
		ability_data.skills[_skill_idx]["cost"]["cooldown"] = text

func _on_skill_desc_changed(text: String) -> void:
	if _skill_idx >= 0 and _skill_idx < ability_data.skills.size():
		ability_data.skills[_skill_idx]["description"] = text

## === 成长路线 ===
func _refresh_paths() -> void:
	path_list.clear()
	if ability_data == null:
		return
	for p in ability_data.growth_paths:
		path_list.add_item("%s (%d阶段)" % [p.get("name", ""), p.get("stages", []).size()])
	_path_idx = -1
	_set_path_detail_visible(false)

func _set_path_detail_visible(vis: bool) -> void:
	path_name_edit.editable = vis
	path_desc_edit.editable = vis

func _on_add_path_pressed() -> void:
	if ability_data == null:
		return
	ability_data.add_growth_path("path_%d" % ability_data.growth_paths.size(), "新路线")
	_refresh_paths()

func _on_remove_path_pressed() -> void:
	if ability_data == null or _path_idx < 0 or _path_idx >= ability_data.growth_paths.size():
		return
	ability_data.growth_paths.remove_at(_path_idx)
	_refresh_paths()

func _on_path_selected(idx: int) -> void:
	_path_idx = idx
	if idx < 0 or idx >= ability_data.growth_paths.size():
		_set_path_detail_visible(false)
		return
	var p: Dictionary = ability_data.growth_paths[idx]
	_set_path_detail_visible(true)
	path_name_edit.text = p.get("name", "")
	path_desc_edit.text = p.get("description", "")
	_refresh_stages()

func _on_path_name_changed(text: String) -> void:
	if _path_idx >= 0 and _path_idx < ability_data.growth_paths.size():
		ability_data.growth_paths[_path_idx]["name"] = text
		path_list.set_item_text(_path_idx, "%s (%d阶段)" % [text, ability_data.growth_paths[_path_idx].get("stages", []).size()])

func _on_path_desc_changed(text: String) -> void:
	if _path_idx >= 0 and _path_idx < ability_data.growth_paths.size():
		ability_data.growth_paths[_path_idx]["description"] = text

## === 阶段 ===
func _refresh_stages() -> void:
	stage_list.clear()
	if _path_idx < 0 or _path_idx >= ability_data.growth_paths.size():
		return
	var stages: Array = ability_data.growth_paths[_path_idx].get("stages", [])
	for st in stages:
		stage_list.add_item("阶段%d: %s (Lv.%d-%d)" % [st.get("stage", 0), st.get("name", ""), st.get("level_range", [1, 10])[0], st.get("level_range", [1, 10])[1]])

func _on_add_stage_pressed() -> void:
	if _path_idx < 0 or _path_idx >= ability_data.growth_paths.size():
		return
	var path_id: String = ability_data.growth_paths[_path_idx]["id"]
	var stages: Array = ability_data.growth_paths[_path_idx].get("stages", [])
	var stage_num := stages.size() + 1
	ability_data.add_growth_stage(path_id, stage_num, "新阶段", [1, 10])
	_refresh_stages()
	_refresh_paths()

func _on_remove_stage_pressed() -> void:
	var sel := stage_list.get_selected_items()
	if sel.is_empty() or _path_idx < 0 or _path_idx >= ability_data.growth_paths.size():
		return
	var stages: Array = ability_data.growth_paths[_path_idx].get("stages", [])
	var idx: int = sel[0]
	if idx >= 0 and idx < stages.size():
		stages.remove_at(idx)
		ability_data.growth_paths[_path_idx]["stages"] = stages
		_refresh_stages()
		_refresh_paths()

## === 状态效果 ===
func _refresh_effects() -> void:
	effect_list.clear()
	if ability_data == null:
		return
	for e in ability_data.status_effects:
		effect_list.add_item("%s [%s]" % [e.get("name", ""), e.get("type", "")])
	_effect_idx = -1
	_set_effect_detail_visible(false)

func _set_effect_detail_visible(vis: bool) -> void:
	effect_name_edit.editable = vis
	effect_type_option.disabled = not vis
	effect_dur_edit.editable = vis
	effect_dmg_edit.editable = vis
	effect_stack_toggle.disabled = not vis

func _on_add_effect_pressed() -> void:
	if ability_data == null:
		return
	ability_data.add_status_effect("effect_%d" % ability_data.status_effects.size(), "新效果")
	_refresh_effects()

func _on_remove_effect_pressed() -> void:
	if ability_data == null or _effect_idx < 0 or _effect_idx >= ability_data.status_effects.size():
		return
	ability_data.status_effects.remove_at(_effect_idx)
	_refresh_effects()

func _on_effect_selected(idx: int) -> void:
	_effect_idx = idx
	if idx < 0 or idx >= ability_data.status_effects.size():
		_set_effect_detail_visible(false)
		return
	var e: Dictionary = ability_data.status_effects[idx]
	_set_effect_detail_visible(true)
	effect_name_edit.text = e.get("name", "")
	var type_str: String = e.get("type", "buff")
	effect_type_option.selected = ["buff", "debuff", "dot", "control"].find(type_str)
	effect_dur_edit.text = e.get("duration", "5s")
	effect_dmg_edit.value = float(e.get("damage_per_tick", 0))
	effect_stack_toggle.button_pressed = e.get("stackable", false)

func _on_effect_name_changed(text: String) -> void:
	if _effect_idx >= 0 and _effect_idx < ability_data.status_effects.size():
		ability_data.status_effects[_effect_idx]["name"] = text
		effect_list.set_item_text(_effect_idx, "%s [%s]" % [text, ability_data.status_effects[_effect_idx].get("type", "")])

func _on_effect_type_changed(idx: int) -> void:
	if _effect_idx >= 0 and _effect_idx < ability_data.status_effects.size():
		var types := ["buff", "debuff", "dot", "control"]
		if idx >= 0 and idx < types.size():
			ability_data.status_effects[_effect_idx]["type"] = types[idx]
			effect_list.set_item_text(_effect_idx, "%s [%s]" % [ability_data.status_effects[_effect_idx].get("name", ""), types[idx]])

func _on_effect_dur_changed(text: String) -> void:
	if _effect_idx >= 0 and _effect_idx < ability_data.status_effects.size():
		ability_data.status_effects[_effect_idx]["duration"] = text

func _on_effect_dmg_changed(value: float) -> void:
	if _effect_idx >= 0 and _effect_idx < ability_data.status_effects.size():
		ability_data.status_effects[_effect_idx]["damage_per_tick"] = int(value)

func _on_effect_stack_changed(pressed: bool) -> void:
	if _effect_idx >= 0 and _effect_idx < ability_data.status_effects.size():
		ability_data.status_effects[_effect_idx]["stackable"] = pressed

## === 战斗机制 ===
func _on_init_combat_pressed() -> void:
	if ability_data == null:
		return
	ability_data.initialize_combat_defaults()

## 获取数据（数据直接写入引用）
func get_data() -> void:
	pass
