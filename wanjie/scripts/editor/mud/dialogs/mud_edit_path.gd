## mud_edit_path.gd
## 路径互动编辑对话框（对应 ME loader/dialogs/editpath.html/.lua）
## 2 标签：通过选项（passcond + 失败提示）、开关选项（opencond）。
## 字段：passcond_type/passcond/passcond_ops/passcond_fail_desc、opencond_type/opencond/opencond_ops。
class_name MudEditPath
extends MudEditDialogBase

var _pass_trigger: MudTriggerEditor
var _open_trigger: MudTriggerEditor
var _fail_desc: LineEdit


func _build_body() -> void:
	var tc := make_tabs()
	_body.add_child(tc)

	# ---- 通过选项 ----
	var pass_page := make_tab_page(tc, "通过选项")
	_pass_trigger = make_trigger(MudTriggerEditor.Mode.COND, "无条件（默认可通过）")
	_pass_trigger.set_type_label("路径通过类型触发：")
	pass_page.add_child(_pass_trigger)
	_fail_desc = field_line(pass_page, "触发失败提示：", "passcond_fail_desc", "")
	pass_page.add_child(make_comment("路径通过指路径可见，但点击到下一节点会判断条件；条件不满足时弹出『触发失败提示』。触发类型为无则默认可通过。"))

	# ---- 开关选项 ----
	var open_page := make_tab_page(tc, "开关选项")
	_open_trigger = make_trigger(MudTriggerEditor.Mode.COND, "无条件（默认显示）")
	_open_trigger.set_type_label("路径开启类型触发：")
	open_page.add_child(_open_trigger)
	open_page.add_child(make_comment("路径开启指路径是否可见受条件影响；条件为真则可见，否则不可见。触发类型为无则默认显示。"))


func _load(row: Dictionary) -> void:
	clear_header()
	add_header("路径：", "#%s  %s → %s（%s）" % [
		str(row.get("id", "")), str(row.get("startpot", "")),
		str(row.get("endpot", "")), str(row.get("direct", ""))])
	load_trigger(_pass_trigger, row.get("passcond_type", 0), row.get("passcond", ""), row.get("passcond_ops", 0))
	load_trigger(_open_trigger, row.get("opencond_type", 0), row.get("opencond", ""), row.get("opencond_ops", 0))
	_fail_desc.text = str(row.get("passcond_fail_desc", ""))


func _collect() -> Dictionary:
	var out: Dictionary = {}
	out.merge(collect_trigger(_pass_trigger, "passcond_type", "passcond", "passcond_ops"))
	out.merge(collect_trigger(_open_trigger, "opencond_type", "opencond", "opencond_ops"))
	out["passcond_fail_desc"] = _fail_desc.text
	return out
