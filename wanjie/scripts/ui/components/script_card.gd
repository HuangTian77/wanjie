## 剧本卡片组件
## 可复用的剧本展示卡片，支持 hover 动效和操作按钮
class_name ScriptCard
extends PanelContainer

signal clicked(script_id: String)
## 双击卡片（进入编辑器）
signal double_clicked(script_id: String)
signal favorite_requested(script_id: String)
signal edit_requested(script_id: String)
signal delete_requested(script_id: String, script_name: String)

@onready var name_label: Label = %CardName
@onready var author_label: Label = %CardAuthor
@onready var desc_label: Label = %CardDesc
@onready var cover_texture: TextureRect = %CoverTexture
@onready var fav_btn: Button = %CardFavBtn
@onready var status_badge: Label = %StatusBadge
@onready var tags_container: HBoxContainer = %CardTags
@onready var rating_label: Label = %CardRating
@onready var play_label: Label = %CardPlay
@onready var progress_label: Label = %CardProgress
@onready var edit_btn: Button = %CardEditBtn
@onready var delete_btn: Button = %CardDeleteBtn

var script_id: String = ""
var script_name: String = ""

## 设置卡片数据
func setup(data: WorldScriptData) -> void:
	script_id = data.id
	script_name = data.name
	name_label.text = data.name
	author_label.text = "by " + data.author
	desc_label.text = data.description if not data.description.is_empty() else "暂无简介"
	rating_label.text = "★ %.1f" % data.rating
	play_label.text = "%d人体验" % data.play_count
	# 封面（thumbnail_path 指向 assets/cover.png，存在则显示）
	var cover_path := ""
	if not data.thumbnail_path.is_empty():
		cover_path = ProjectSettings.globalize_path("user://scripts/%s/%s" % [data.id, data.thumbnail_path])
	if not cover_path.is_empty() and FileAccess.file_exists(cover_path):
		var tex := ImageTexture.create_from_image(Image.load_from_file(cover_path))
		if tex != null:
			cover_texture.texture = tex
			cover_texture.visible = true
	else:
		cover_texture.texture = null
		# 无封面占位：显示渐变底色 + 剧本首字符
		cover_texture.visible = true
		var ph := Label.new()
		ph.name = "CoverPlaceholder"
		ph.text = str(data.name.substr(0, 1)) if not data.name.is_empty() else "📜"
		ph.add_theme_font_size_override("font_size", 48)
		ph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.16, 0.14, 0.12, 0.9)
		bg.corner_radius_top_left = 6
		bg.corner_radius_top_right = 6
		ph.add_theme_stylebox_override("normal", bg)
		cover_texture.add_child(ph)
	# 标签
	for child in tags_container.get_children():
		child.queue_free()
	for tag_text in data.tags:
		var tag_label := Label.new()
		tag_label.text = tag_text
		tag_label.add_theme_font_size_override("font_size", 11)
		tag_label.add_theme_color_override("font_color", ThemeManager.C_ACCENT)
		tags_container.add_child(tag_label)
	# 已发布徽章
	status_badge.visible = data.status == "published"
	# 进度
	if data.progress > 0:
		progress_label.text = "%d%%" % int(data.progress * 100)
		progress_label.visible = true
	else:
		progress_label.visible = false

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)
	fav_btn.pressed.connect(func(): favorite_requested.emit(script_id))
	# 已收藏角标（♥ 高亮）
	var gm: Node = Engine.get_main_loop().root.get_node_or_null("GameManager")
	if gm != null and gm.user_data != null and gm.user_data.favorites_script_ids.has(script_id):
		fav_btn.text = "♥"
		fav_btn.add_theme_color_override("font_color", Color(0.95, 0.45, 0.45))
	edit_btn.pressed.connect(func(): edit_requested.emit(script_id))
	delete_btn.pressed.connect(func(): delete_requested.emit(script_id, script_name))

func _on_mouse_entered() -> void:
	# 容器内 position 会被布局覆盖, 改用 scale 微放大
	var tween := ThemeManager.create_anim(self)
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "scale", Vector2(1.02, 1.02), 0.15)
	var style := get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		var hover_style := style.duplicate()
		hover_style.shadow_size = 8
		hover_style.shadow_color = Color(0.29, 0.216, 0.157, 0.12)
		hover_style.border_color = ThemeManager.C_ACCENT * Color(1, 1, 1, 0.4)
		add_theme_stylebox_override("panel", hover_style)

func _on_mouse_exited() -> void:
	var tween := ThemeManager.create_anim(self)
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "scale", Vector2.ONE, 0.15)
	var style := get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		var normal_style := style.duplicate()
		normal_style.shadow_size = 3
		normal_style.shadow_color = Color(0.29, 0.216, 0.157, 0.06)
		normal_style.border_color = ThemeManager.C_ACCENT * Color(1, 1, 1, 0.2)
		add_theme_stylebox_override("panel", normal_style)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# 点击落在操作按钮上时忽略（避免编辑/删除误触发打开剧本）
		if edit_btn.get_global_rect().has_point(event.global_position) \
			or delete_btn.get_global_rect().has_point(event.global_position):
			return
		if event.double_click:
			double_clicked.emit(script_id)
		else:
			clicked.emit(script_id)
