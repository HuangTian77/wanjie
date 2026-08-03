## 最近体验卡片组件
class_name RecentCard
extends PanelContainer

signal clicked(script_id: String)

@onready var name_label: Label = %RecentName
@onready var progress_bar: ProgressBar = %RecentProgress
@onready var progress_text: Label = %RecentProgressText

var script_id: String = ""

func setup(data: WorldScriptData) -> void:
	script_id = data.id
	name_label.text = data.name
	progress_bar.value = data.progress
	progress_text.text = "进度 %d%%" % int(data.progress * 100)

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)

func _on_mouse_entered() -> void:
	var tween := ThemeManager.create_anim(self)
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "position:y", position.y - 3, 0.12)

func _on_mouse_exited() -> void:
	var tween := ThemeManager.create_anim(self)
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "position:y", position.y + 3, 0.12)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(script_id)
