## 模板选择对话框
extends Control

signal template_selected(template_id: String)
signal cancelled

@onready var template_list: ItemList = %TemplateList
@onready var desc_label: RichTextLabel = %DescLabel
@onready var create_btn: Button = %CreateBtn
@onready var name_input: LineEdit = %ScriptNameInput

var _templates: Array[Dictionary] = []

func _ready() -> void:
	_templates = ScriptDataManager.get_templates()
	_refresh_template_list()

func _refresh_template_list() -> void:
	template_list.clear()
	for t in _templates:
		template_list.add_item(t["name"])

func show_dialog() -> void:
	visible = true
	name_input.text = ""
	if not _templates.is_empty():
		template_list.select(0)
		_on_template_selected(0)

func _on_template_selected(index: int) -> void:
	if index < 0 or index >= _templates.size():
		return
	var t: Dictionary = _templates[index]
	desc_label.text = t.get("description", "")
	create_btn.disabled = name_input.text.is_empty()

func _on_name_changed(new_text: String) -> void:
	create_btn.disabled = new_text.is_empty()

func _on_create_pressed() -> void:
	if name_input.text.is_empty():
		return
	var selected := template_list.get_selected_items()
	if selected.is_empty():
		return
	var template_id: String = _templates[selected[0]]["id"]
	var ws := ScriptDataManager.create_script(name_input.text, GameManager.user_data.player_name, template_id)
	if ws != null:
		template_selected.emit(template_id)
	visible = false

func _on_cancel_pressed() -> void:
	visible = false
	cancelled.emit()
