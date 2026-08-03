## mud_edit_scene_object.gd
## 场景对象编辑对话框（对应 ME loader/dialogs/editsceneobject.html/.lua）
##
## 以"场景"为上下文打开，主体复用 MudSceneObjectPanel（左对象列表 + 右触发块）。
## 确认时保存当前选中对象的 ctrl 并关闭。
class_name MudEditSceneObject
extends MudEditDialogBase

var _scene_id: int = 0
var _panel: MudSceneObjectPanel


## 以场景为上下文打开对话框。
func open_for_scene(data: MudData, scene_id: int, title: String) -> void:
	_data = data
	_table = "scene_object"
	_scene_id = scene_id
	_row_id = 0
	self.title = title
	if not _built:
		_build_body()
		_built = true
	clear_header()
	var sc: Dictionary = data.get_row_by_id("scene", scene_id)
	add_header("场景：", "#%s  %s" % [str(scene_id), str(sc.get("name", ""))])
	_panel.setup(data, scene_id)
	popup_centered()


func _build_body() -> void:
	_panel = MudSceneObjectPanel.new()
	_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(_panel)


## 覆盖基类保存：保存当前对象后关闭。
func _on_confirmed() -> void:
	if _panel != null:
		_panel.save_current()
	saved.emit("scene", _scene_id)
	hide()
