## mud_edit_scene.gd
## 场景互动编辑对话框（对应 ME loader/dialogs/editscene.html/.lua）
##
## 3 主标签：对象编辑（复用 MudSceneObjectPanel）、进入触发、离开触发。
## 进入/离开触发各含 3 子标签：触发条件(COND) / 成功触发(RESULT) / 失败触发(RESULT)。
## 字段映射（scene）：
##   进入：et_cond_type/enter_cond/et_cond_ops、et_type/enter_trigger、et_fail_type/enter_trigger_fail
##   离开：lt_cond_type/leave_cond/lt_cond_ops、lt_type/leave_trigger、lt_fail_type/leave_trigger_fail
class_name MudEditScene
extends MudEditDialogBase

var _panel: MudSceneObjectPanel        # 对象编辑
var _et_cond: MudTriggerEditor         # 进入条件（COND）
var _et_succ: MudTriggerEditor         # 进入成功（RESULT）
var _et_fail: MudTriggerEditor         # 进入失败（RESULT）
var _lt_cond: MudTriggerEditor         # 离开条件（COND）
var _lt_succ: MudTriggerEditor         # 离开成功（RESULT）
var _lt_fail: MudTriggerEditor         # 离开失败（RESULT）


func _build_body() -> void:
	var tc := make_tabs()
	_body.add_child(tc)

	# ==== 主标签1：对象编辑 ====
	var obj_page := make_tab_page(tc, "对象编辑")
	_panel = MudSceneObjectPanel.new()
	_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	obj_page.add_child(_panel)

	# ==== 主标签2：进入触发 ====
	var enter_page := make_tab_page(tc, "进入触发")
	var esub := make_tabs()
	enter_page.add_child(esub)
	var e_cond_p := make_tab_page(esub, "触发条件")
	_et_cond = _add_cond_block(e_cond_p, "条件类型：")
	var e_succ_p := make_tab_page(esub, "成功触发")
	_et_succ = _add_result_block(e_succ_p)
	var e_fail_p := make_tab_page(esub, "失败触发")
	_et_fail = _add_result_block(e_fail_p)

	# ==== 主标签3：离开触发 ====
	var leave_page := make_tab_page(tc, "离开触发")
	var lsub := make_tabs()
	leave_page.add_child(lsub)
	var l_cond_p := make_tab_page(lsub, "触发条件")
	_lt_cond = _add_cond_block(l_cond_p, "条件类型：")
	var l_succ_p := make_tab_page(lsub, "成功触发")
	_lt_succ = _add_result_block(l_succ_p)
	var l_fail_p := make_tab_page(lsub, "失败触发")
	_lt_fail = _add_result_block(l_fail_p)


func _add_cond_block(page: VBoxContainer, label: String) -> MudTriggerEditor:
	var te := make_trigger(MudTriggerEditor.Mode.COND, "无条件")
	te.set_type_label(label)
	te.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(te)
	page.add_child(make_comment("进入/离开该场景需满足的条件；类型为『无』则无条件可进入/离开。"))
	return te


func _add_result_block(page: VBoxContainer) -> MudTriggerEditor:
	var te := make_trigger(MudTriggerEditor.Mode.RESULT, "无触发")
	te.set_type_label("触发类型：")
	te.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(te)
	page.add_child(make_comment("条件判定后执行的触发（成功或失败时分别执行对应触发）。"))
	return te


func _load(row: Dictionary) -> void:
	clear_header()
	add_header("场景名称：", str(row.get("name", "")))
	add_header("场景ID：", str(row.get("id", "")))

	_panel.setup(_data, int(row.get("id", 0)))

	load_trigger(_et_cond, row.get("et_cond_type", 0), row.get("enter_cond", ""), row.get("et_cond_ops", 0))
	load_trigger(_et_succ, row.get("et_type", 0), row.get("enter_trigger", ""), 0)
	load_trigger(_et_fail, row.get("et_fail_type", 0), row.get("enter_trigger_fail", ""), 0)
	load_trigger(_lt_cond, row.get("lt_cond_type", 0), row.get("leave_cond", ""), row.get("lt_cond_ops", 0))
	load_trigger(_lt_succ, row.get("lt_type", 0), row.get("leave_trigger", ""), 0)
	load_trigger(_lt_fail, row.get("lt_fail_type", 0), row.get("leave_trigger_fail", ""), 0)


func _collect() -> Dictionary:
	var out: Dictionary = {}
	out.merge(collect_trigger(_et_cond, "et_cond_type", "enter_cond", "et_cond_ops"))
	out.merge(collect_trigger(_et_succ, "et_type", "enter_trigger"))
	out.merge(collect_trigger(_et_fail, "et_fail_type", "enter_trigger_fail"))
	out.merge(collect_trigger(_lt_cond, "lt_cond_type", "leave_cond", "lt_cond_ops"))
	out.merge(collect_trigger(_lt_succ, "lt_type", "leave_trigger"))
	out.merge(collect_trigger(_lt_fail, "lt_fail_type", "leave_trigger_fail"))
	return out


## 覆盖基类保存：先保存对象编辑面板的当前对象，再写回场景触发字段。
func _on_confirmed() -> void:
	if _panel != null:
		_panel.save_current()
	var values: Dictionary = _collect()
	if _data != null and not _table.is_empty():
		_data.update_row(_table, _row_id, values)
	saved.emit(_table, _row_id)
	hide()
