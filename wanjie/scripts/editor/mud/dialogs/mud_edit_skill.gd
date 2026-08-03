## mud_edit_skill.gd
## 技能高级编辑对话框（对应 ME loader/dialogs/editskill.html/.lua）
##
## 4 子页：
##   公式：data_type(0脚本1配置) + data(脚本/配置) + 语法校验 + 样例模板
##   装配：equip COND 触发块 → equip_type / equip_data / equip_cond_ops
##   消耗：consume RESULT 触发块 → consume_type / consume_data（无 ops）
##   槽位：slots JSON
## 字段格式与 mud_export.load_skill() / mud_import 完全兼容：
##   func=data  need=generate(equip_type,equip_data,equip_cond_ops)  consume=generate_result(consume_type,consume_data)
class_name MudEditSkill
extends MudEditDialogBase

# ---- 公式 ----
var _data_type_select: OptionButton
var _data_edit: TextEdit

# ---- 装配 ----
var _equip_trigger: MudTriggerEditor   # COND 块

# ---- 消耗 ----
var _consume_trigger: MudTriggerEditor # RESULT 块

# ---- 槽位 ----
var _slots_edit: TextEdit


func _build_body() -> void:
	var tc := make_tabs()
	_body.add_child(tc)
	_build_formula(make_tab_page(tc, "公式"))
	_build_equip(make_tab_page(tc, "装配"))
	_build_consume(make_tab_page(tc, "消耗"))
	_build_slots(make_tab_page(tc, "槽位"))


# ===================== 公式 =====================

func _build_formula(page: VBoxContainer) -> void:
	_data_type_select = field_select(page, "数据类型：", "data_type", [["脚本", 0], ["配置", 1]], 0)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	page.add_child(bar)
	var chk := Button.new()
	chk.text = "语法校验"
	chk.pressed.connect(_on_check)
	bar.add_child(chk)
	_data_edit = MudCodeTheme.make_code_edit("lua", 200)
	_data_edit.placeholder_text = "-- 技能公式脚本，例如：\nreturn function(skill, caster, target)\n    return getProperty('力量') * 2\nend"
	bar.add_child(MudCodeTheme.make_template_button(_data_edit, "skill"))
	page.add_child(_data_edit)
	page.add_child(make_comment("脚本模式：技能效果由 Lua 脚本计算；配置模式：使用配置数据。导出时 func = data。"))


func _on_check() -> void:
	var ok: bool = _check_lua_balance(_data_edit.text)
	_data_edit.placeholder_text = "语法校验：" + ("括号/关键字配对正常 ✓" if ok else "存在未配对的括号或关键字 ✗")


func _check_lua_balance(s: String) -> bool:
	var paren: int = 0
	for ch in s:
		if ch == "(":
			paren += 1
		elif ch == ")":
			paren -= 1
		if paren < 0:
			return false
	if paren != 0:
		return false
	var fns: int = _count_word(s, "function") + _count_word(s, "if") + _count_word(s, "for") + _count_word(s, "while")
	var ends: int = _count_word(s, "end")
	return ends <= fns + 1


func _count_word(s: String, w: String) -> int:
	var c: int = 0
	var i: int = s.find(w)
	while i >= 0:
		c += 1
		i = s.find(w, i + w.length())
	return c


# ===================== 装配 =====================

func _build_equip(page: VBoxContainer) -> void:
	_equip_trigger = make_trigger(MudTriggerEditor.Mode.COND, "无装配条件")
	_equip_trigger.set_type_label("装配条件类型：")
	_equip_trigger.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(_equip_trigger)
	page.add_child(make_comment("装配条件决定技能能否被装配（学习/装备）。导出时 need = 条件数据。"))


# ===================== 消耗 =====================

func _build_consume(page: VBoxContainer) -> void:
	_consume_trigger = make_trigger(MudTriggerEditor.Mode.RESULT, "无消耗")
	_consume_trigger.set_type_label("消耗类型：")
	_consume_trigger.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(_consume_trigger)
	page.add_child(make_comment("消耗配置：使用技能时消耗的属性/物品（负值表示消耗）。导出时 consume = 结果数据。"))


# ===================== 槽位 =====================

func _build_slots(page: VBoxContainer) -> void:
	page.add_child(make_label("技能槽位信息（JSON 数组）："))
	_slots_edit = MudCodeTheme.make_code_edit("json", 160)
	_slots_edit.placeholder_text = '[{"slot": 1, "cnt": 1}]'
	page.add_child(_slots_edit)
	page.add_child(make_comment("槽位占用配置。cnt 为占用数量，导出时自动转换为 slotNum。可在插槽模板页面增加模板。"))


# ===================== 加载 / 收集 =====================

func _load(row: Dictionary) -> void:
	clear_header()
	add_header("技能：", str(row.get("name", "")))
	add_header("ID：", str(row.get("id", "")))
	add_header("描述：", str(row.get("desc", "")))
	add_header("备注：", str(row.get("note", "")))

	# 公式
	_select_by_id(_data_type_select, int(row.get("data_type", 0)))
	_data_edit.text = str(row.get("data", ""))

	# 装配（COND）
	load_trigger(_equip_trigger, row.get("equip_type", 0), row.get("equip_data", ""), row.get("equip_cond_ops", 0))

	# 消耗（RESULT，无 ops）
	load_trigger(_consume_trigger, row.get("consume_type", 0), row.get("consume_data", ""), 0)

	# 槽位
	_slots_edit.text = str(row.get("slots", ""))


func _collect() -> Dictionary:
	var out: Dictionary = {}
	out["data_type"] = _data_type_select.get_selected_id()
	out["data"] = _data_edit.text
	out.merge(collect_trigger(_equip_trigger, "equip_type", "equip_data", "equip_cond_ops"))
	out.merge(collect_trigger(_consume_trigger, "consume_type", "consume_data"))
	out["slots"] = _slots_edit.text.strip_edges()
	return out
