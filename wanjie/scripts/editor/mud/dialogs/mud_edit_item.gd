## mud_edit_item.gd
## 物品高级编辑对话框（对应 ME loader/dialogs/edititem.html/.lua）
##
## 5 子页：
##   互动效果：alternation（互动按钮 JSON，完整交互模块编辑器见后续阶段）
##   消耗效果：效果(prop_consume RESULT) + 条件(cond_consume COND + cond_consume_ops)
##   携带效果：效果(prop_carry RESULT) + 条件(cond_carry COND + cond_carry_ops)
##   装配效果：效果(prop_equip + prop_equip_trigger_type 0配置/1脚本) + 条件(cond_equip COND + cond_equip_ops)
##   插槽设置：slots JSON
## 字段格式与 mud_export.load_goods_use() / handle_effect() / mud_import 完全兼容：
##   equipValue/carryValue/consumeValue = handle_effect(trigger_type, prop_*, cond_*, cond_*_ops)
##   注意 handle_effect 的 trigger：0=配置(addValue) 1=脚本(addFunc)，与通用 1配置/2脚本 不同。
class_name MudEditItem
extends MudEditDialogBase

# ---- 互动效果 ----
var _alternation_edit: TextEdit

# ---- 消耗效果 ----
var _consume_effect: MudTriggerEditor   # RESULT 块（prop_consume）
var _consume_cond: MudTriggerEditor     # COND 块（cond_consume）

# ---- 携带效果 ----
var _carry_effect: MudTriggerEditor     # RESULT 块（prop_carry）
var _carry_cond: MudTriggerEditor       # COND 块（cond_carry）

# ---- 装配效果 ----
var _equip_effect: MudTriggerEditor     # RESULT 块（prop_equip + prop_equip_trigger_type）
var _equip_cond: MudTriggerEditor       # COND 块（cond_equip）

# ---- 插槽设置 ----
var _slots_edit: TextEdit


func _build_body() -> void:
	var tc := make_tabs()
	_body.add_child(tc)
	_build_alternation(make_tab_page(tc, "互动效果"))
	_build_effect_pair(make_tab_page(tc, "消耗效果"), "consume")
	_build_effect_pair(make_tab_page(tc, "携带效果"), "carry")
	_build_effect_pair(make_tab_page(tc, "装配效果"), "equip")
	_build_slots(make_tab_page(tc, "插槽设置"))


# ===================== 互动效果 =====================

func _build_alternation(page: VBoxContainer) -> void:
	page.add_child(make_label("互动按钮数据（JSON 数组）："))
	_alternation_edit = TextEdit.new()
	_alternation_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_alternation_edit.custom_minimum_size = Vector2(0, 200)
	_alternation_edit.placeholder_text = '[{"name": "使用", "desc": "", "trigger_succ": {"type": 1, "value": "..."}}]'
	page.add_child(_alternation_edit)
	page.add_child(make_comment("互动效果是包裹中点击物品弹出对话框的可点击按钮（装备/使用/丢弃等）。此处为 JSON 高级编辑，完整可视化交互模块编辑器见后续阶段。"))


# ===================== 消耗/携带/装配 效果（效果+条件 双子页） =====================

## kind: "consume" / "carry" / "equip"
func _build_effect_pair(page: VBoxContainer, kind: String) -> void:
	var sub := TabContainer.new()
	sub.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(sub)

	var effect_page := VBoxContainer.new()
	effect_page.name = "效果"
	effect_page.add_theme_constant_override("separation", 6)
	sub.add_child(effect_page)

	var cond_page := VBoxContainer.new()
	cond_page.name = "条件"
	cond_page.add_theme_constant_override("separation", 6)
	sub.add_child(cond_page)

	var effect_te: MudTriggerEditor = make_trigger(MudTriggerEditor.Mode.RESULT, "无效果")
	effect_te.set_type_label("效果类型：")
	effect_te.size_flags_vertical = Control.SIZE_EXPAND_FILL
	effect_page.add_child(effect_te)

	var cond_te: MudTriggerEditor = make_trigger(MudTriggerEditor.Mode.COND, "无条件")
	cond_te.set_type_label("条件类型：")
	cond_te.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cond_page.add_child(cond_te)

	match kind:
		"consume":
			_consume_effect = effect_te
			_consume_cond = cond_te
			effect_page.add_child(make_comment("消耗效果：使用物品时产生的属性变化（负值表示消耗）。需物品特性支持『可消耗』。"))
		"carry":
			_carry_effect = effect_te
			_carry_cond = cond_te
			effect_page.add_child(make_comment("携带效果：物品在包裹中时生效的属性变化。"))
		"equip":
			_equip_effect = effect_te
			_equip_cond = cond_te
			effect_page.add_child(make_comment("装配效果：物品装备后生效的属性变化。效果类型 配置=数值叠加，脚本=自定义函数。需物品特性支持『可装备』。"))


# ===================== 插槽设置 =====================

func _build_slots(page: VBoxContainer) -> void:
	page.add_child(make_label("物品槽位信息（JSON 数组）："))
	_slots_edit = TextEdit.new()
	_slots_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_slots_edit.custom_minimum_size = Vector2(0, 160)
	_slots_edit.placeholder_text = '[{"slot": 1, "cnt": 1}]'
	page.add_child(_slots_edit)
	page.add_child(make_comment("装备槽位占用配置。cnt 为占用数量，导出时自动转换为 slotNum。可在插槽模板页面增加模板。"))


# ===================== 装配效果触发类型映射 =====================
## item.prop_equip_trigger_type：0=配置 1=脚本（handle_effect 约定）
## MudTriggerEditor 块类型：0=无 1=配置 2=脚本

func _load_equip_effect(prop_equip: Variant, trigger_type: Variant) -> void:
	var pe: String = "" if prop_equip == null else str(prop_equip)
	if pe.strip_edges().is_empty():
		_equip_effect.set_block(0, "", "", 0)
	elif int(trigger_type) == 1:
		_equip_effect.set_block(2, "", pe, 0)   # 脚本
	else:
		_equip_effect.set_block(1, pe, "", 0)   # 配置


func _collect_equip_effect() -> Dictionary:
	var b: Dictionary = _equip_effect.get_block()
	var tp: int = int(b["type"])
	if tp == 2:
		return {"prop_equip_trigger_type": 1, "prop_equip": b["script"]}
	elif tp == 1:
		return {"prop_equip_trigger_type": 0, "prop_equip": b["config"]}
	return {"prop_equip_trigger_type": 0, "prop_equip": ""}


# ===================== 加载 / 收集 =====================

func _load(row: Dictionary) -> void:
	clear_header()
	add_header("物品：", str(row.get("name", "")))
	add_header("ID：", str(row.get("id", "")))
	add_header("描述：", str(row.get("desc", "")))
	add_header("备注：", str(row.get("note", "")))

	# 互动效果
	_alternation_edit.text = str(row.get("alternation", ""))

	# 消耗效果（无 trigger_type 字段，按配置处理）
	load_trigger(_consume_effect, 1 if not str(row.get("prop_consume", "")).strip_edges().is_empty() else 0, row.get("prop_consume", ""), 0)
	load_trigger(_consume_cond, 1 if not str(row.get("cond_consume", "")).strip_edges().is_empty() else 0, row.get("cond_consume", ""), row.get("cond_consume_ops", 0))

	# 携带效果
	load_trigger(_carry_effect, 1 if not str(row.get("prop_carry", "")).strip_edges().is_empty() else 0, row.get("prop_carry", ""), 0)
	load_trigger(_carry_cond, 1 if not str(row.get("cond_carry", "")).strip_edges().is_empty() else 0, row.get("cond_carry", ""), row.get("cond_carry_ops", 0))

	# 装配效果（有 prop_equip_trigger_type）
	_load_equip_effect(row.get("prop_equip", ""), row.get("prop_equip_trigger_type", 0))
	load_trigger(_equip_cond, 1 if not str(row.get("cond_equip", "")).strip_edges().is_empty() else 0, row.get("cond_equip", ""), row.get("cond_equip_ops", 0))

	# 插槽
	_slots_edit.text = str(row.get("slots", ""))


func _collect() -> Dictionary:
	var out: Dictionary = {}

	# 互动效果
	out["alternation"] = _alternation_edit.text.strip_edges()

	# 消耗效果（RESULT 无 ops；COND 有 ops）
	var ce: Dictionary = _consume_effect.get_block()
	out["prop_consume"] = ce["script"] if int(ce["type"]) == 2 else ce["config"]
	out.merge(collect_trigger(_consume_cond, "_cc_type", "cond_consume", "cond_consume_ops"))

	# 携带效果
	var ca: Dictionary = _carry_effect.get_block()
	out["prop_carry"] = ca["script"] if int(ca["type"]) == 2 else ca["config"]
	out.merge(collect_trigger(_carry_cond, "_ca_type", "cond_carry", "cond_carry_ops"))

	# 装配效果（含 trigger_type 映射）
	out.merge(_collect_equip_effect())
	out.merge(collect_trigger(_equip_cond, "_eq_type", "cond_equip", "cond_equip_ops"))

	# 插槽
	out["slots"] = _slots_edit.text.strip_edges()

	# 清理临时键
	out.erase("_cc_type")
	out.erase("_ca_type")
	out.erase("_eq_type")
	return out
