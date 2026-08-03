## mud_edit_talk.gd
## 互动编辑对话框（对应 ME loader/dialogs/edittalk.html/.lua）
##
## 2 主标签：互动控制（含 条件/成功/失败 3 子标签）、显示控制。
## 字段映射（module_talk）：
##   条件：trigger_type / condition / cond_ops          （COND）
##   成功：succ_type / succ_trigger + trigger_count      （RESULT + 次数）
##   失败：fail_type / fail_trigger + fail_desc          （RESULT + 失败文本）
##   显示：visible_cond_trigger_type / visible_cond / visible_cond_ops （COND）
class_name MudEditTalk
extends MudEditDialogBase

var _cond_trigger: MudTriggerEditor    # 条件（COND）
var _succ_trigger: MudTriggerEditor    # 成功（RESULT）
var _fail_trigger: MudTriggerEditor    # 失败（RESULT）
var _visible_trigger: MudTriggerEditor # 显示控制（COND）
var _count: SpinBox                    # 成功执行次数 trigger_count
var _fail_desc: LineEdit               # 失败提示 fail_desc


func _build_body() -> void:
	var tc := make_tabs()
	_body.add_child(tc)

	# ==== 主标签1：互动控制 ====
	var interact_page := make_tab_page(tc, "互动控制")
	var sub := make_tabs()
	interact_page.add_child(sub)

	# -- 子标签：条件 --
	var cond_page := make_tab_page(sub, "条件")
	_cond_trigger = make_trigger(MudTriggerEditor.Mode.COND, "无条件")
	_cond_trigger.set_type_label("条件类型：")
	_cond_trigger.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cond_page.add_child(_cond_trigger)
	cond_page.add_child(make_comment("触发条件需全部满足才算成功触发（可选『满足一个』）。同类型条目会自动去重。"))

	# -- 子标签：成功 --
	var succ_page := make_tab_page(sub, "成功")
	_count = field_int(succ_page, "执行次数：", "trigger_count", 0, 0, 999999)
	_succ_trigger = make_trigger(MudTriggerEditor.Mode.RESULT, "无触发")
	_succ_trigger.set_type_label("触发类型：")
	_succ_trigger.size_flags_vertical = Control.SIZE_EXPAND_FILL
	succ_page.add_child(_succ_trigger)
	succ_page.add_child(make_comment("条件满足后执行的触发。执行次数：成功 n 次后不再触发，0 或留空为永久触发。"))

	# -- 子标签：失败 --
	var fail_page := make_tab_page(sub, "失败")
	_fail_desc = field_line(fail_page, "失败文本：", "fail_desc", "")
	_fail_trigger = make_trigger(MudTriggerEditor.Mode.RESULT, "无触发")
	_fail_trigger.set_type_label("触发类型：")
	_fail_trigger.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fail_page.add_child(_fail_trigger)
	fail_page.add_child(make_comment("条件不满足时弹出『失败文本』并执行此触发。"))

	# ==== 主标签2：显示控制 ====
	var visible_page := make_tab_page(tc, "显示控制")
	_visible_trigger = make_trigger(MudTriggerEditor.Mode.COND, "无条件（默认可见）")
	_visible_trigger.set_type_label("条件类型：")
	_visible_trigger.size_flags_vertical = Control.SIZE_EXPAND_FILL
	visible_page.add_child(_visible_trigger)
	visible_page.add_child(make_comment("不增加条件则互动默认可见；增加条件后需同时满足才会显示当前互动。"))


func _load(row: Dictionary) -> void:
	clear_header()
	var oid: int = int(row.get("objid", 0))
	var ob: Dictionary = _data.get_row_by_id("object", oid)
	add_header("互动名称：", str(row.get("name", "")))
	add_header("互动对象：", "#%s  %s" % [str(oid), str(ob.get("name", ""))])
	add_header("互动ID：", str(row.get("id", "")))

	load_trigger(_cond_trigger, row.get("trigger_type", 0), row.get("condition", ""), row.get("cond_ops", 0))
	load_trigger(_succ_trigger, row.get("succ_type", 0), row.get("succ_trigger", ""), 0)
	load_trigger(_fail_trigger, row.get("fail_type", 0), row.get("fail_trigger", ""), 0)
	load_trigger(_visible_trigger, row.get("visible_cond_trigger_type", 0), row.get("visible_cond", ""), row.get("visible_cond_ops", 0))
	_count.value = float(row.get("trigger_count", 0)) if str(row.get("trigger_count", 0)).is_valid_float() else 0.0
	_fail_desc.text = str(row.get("fail_desc", ""))


func _collect() -> Dictionary:
	var out: Dictionary = {}
	out.merge(collect_trigger(_cond_trigger, "trigger_type", "condition", "cond_ops"))
	out.merge(collect_trigger(_succ_trigger, "succ_type", "succ_trigger"))
	out.merge(collect_trigger(_fail_trigger, "fail_type", "fail_trigger"))
	out.merge(collect_trigger(_visible_trigger, "visible_cond_trigger_type", "visible_cond", "visible_cond_ops"))
	out["trigger_count"] = int(_count.value)
	out["fail_desc"] = _fail_desc.text
	return out
