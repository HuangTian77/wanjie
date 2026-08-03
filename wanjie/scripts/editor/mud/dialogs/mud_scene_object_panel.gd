## mud_scene_object_panel.gd
## 场景对象编辑面板（可复用控件，对应 ME editscene.html 的"对象编辑"标签
## 以及 editsceneobject.html 的主体）。
##
## 左侧列出指定场景下的所有 scene_object 行（显示对象名称），右侧编辑选中对象的
## ctrl 触发块（0无/1配置/2脚本，控制对象是否显示）。切换对象时自动保存上一个。
## ctrl 字段为 JSON：{"trigger":type, "cond":config或script, "cond_ops":ops}。
## 由 MudEditSceneObject 对话框与 MudEditScene 对话框的"对象编辑"标签共用。
class_name MudSceneObjectPanel
extends HBoxContainer

var _data: MudData = null
var _scene_id: int = 0
var _obj_list: ItemList
var _trigger: MudTriggerEditor
var _row_ids: Array = []   # 与列表项一一对应的 scene_object 行 id
var _current_idx: int = -1
var _built: bool = false


## 初始化：设置数据源与场景，构建 UI 并填充列表。
func setup(data: MudData, scene_id: int) -> void:
	_data = data
	_scene_id = scene_id
	if not _built:
		_build()
		_built = true
	refresh()


func _build() -> void:
	add_theme_constant_override("separation", 8)

	# ---- 左：对象列表 ----
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(210, 0)
	left.add_theme_constant_override("separation", 4)
	add_child(left)
	var lb := Label.new()
	lb.text = "场景对象列表："
	left.add_child(lb)
	_obj_list = ItemList.new()
	_obj_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_obj_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_obj_list.item_selected.connect(_on_object_selected)
	left.add_child(_obj_list)

	# ---- 右：触发块 ----
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	add_child(right)
	_trigger = MudTriggerEditor.new(MudTriggerEditor.Mode.COND, "无（默认显示）")
	_trigger.set_data_source(_data)
	_trigger.set_type_label("显示控制触发类型：")
	_trigger.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_trigger)
	var cm := Label.new()
	cm.text = "控制对象是否显示：触发类型为『无』则默认显示；『配置』时条件为真才显示；『脚本』时由 Lua 返回值决定。切换对象会自动保存上一个对象的设置。"
	cm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cm.add_theme_font_size_override("font_size", 12)
	right.add_child(cm)


## 重新填充对象列表（数据变化后调用）。
func refresh() -> void:
	if _obj_list == null:
		return
	_obj_list.clear()
	_row_ids.clear()
	_current_idx = -1
	var rows: Array = _data.rows_where("scene_object", "sceneid", _scene_id)
	for so_v in rows:
		if not (so_v is Dictionary):
			continue
		var so: Dictionary = so_v as Dictionary
		var oid: int = int(so.get("objid", 0))
		var ob: Dictionary = _data.get_row_by_id("object", oid)
		var nm: String = str(ob.get("name", ""))
		if nm.is_empty():
			nm = "对象#%s" % str(oid)
		_obj_list.add_item(nm)
		_row_ids.append(int(so.get("id", 0)))
	if _row_ids.size() > 0:
		_obj_list.select(0)
		_load_object(0)
	else:
		_trigger.set_block(0, "", "", 0)


func _on_object_selected(idx: int) -> void:
	save_current()
	_load_object(idx)


func _load_object(idx: int) -> void:
	if idx < 0 or idx >= _row_ids.size():
		_current_idx = -1
		return
	_current_idx = idx
	var so: Dictionary = _data.get_row_by_id("scene_object", _row_ids[idx])
	var ctrl: Variant = _parse_ctrl(so.get("ctrl", ""))
	if ctrl is Dictionary:
		var cd: Dictionary = ctrl as Dictionary
		_load_trigger(_trigger, cd.get("trigger", 0), cd.get("cond", ""), cd.get("cond_ops", 0))
	else:
		_trigger.set_block(0, "", "", 0)


## 保存当前选中对象的 ctrl 到数据层。
func save_current() -> void:
	if _current_idx < 0 or _current_idx >= _row_ids.size():
		return
	var b: Dictionary = _trigger.get_block()
	var ctrl: Dictionary = {
		"trigger": b["type"],
		"cond": b["script"] if int(b["type"]) == 2 else b["config"],
		"cond_ops": b["ops"],
	}
	_data.update_row("scene_object", _row_ids[_current_idx], {"ctrl": JSON.stringify(ctrl)})


func _load_trigger(te: MudTriggerEditor, type_val: Variant, data_val: Variant, ops_val: Variant) -> void:
	var tp: int = int(type_val)
	var data_str: String = str(data_val) if data_val != null else ""
	if tp == 2:
		te.set_block(2, "", data_str, 0)
	else:
		te.set_block(tp, data_str, "", int(ops_val))


func _parse_ctrl(v: Variant) -> Variant:
	var s: String = "" if v == null else str(v)
	if s.strip_edges().is_empty():
		return null
	return JSON.parse_string(s)
