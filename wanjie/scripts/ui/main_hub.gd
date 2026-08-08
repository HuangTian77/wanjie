## 万界大厅主界面控制器
## 对应GDD §7.1.1 主界面设计
extends Control

## UI节点引用
@onready var top_bar: HBoxContainer = %TopBar
@onready var shimo_label: Label = %ShimoLabel
@onready var jieshi_label: Label = %JieshiLabel
@onready var inspiration_label: Label = %InspirationLabel
@onready var carousel_container: Control = %CarouselContainer
@onready var carousel_timer: Timer = %CarouselTimer
@onready var carousel_label: Label = %CarouselLabel
@onready var carousel_indicator: HBoxContainer = %CarouselIndicator
@onready var tab_container: HBoxContainer = %TabContainer
@onready var script_grid: GridContainer = %ScriptGrid
@onready var stats_label: Label = %StatsLabel
## 列表视图模式（单列紧凑）
var _list_view: bool = false
## 排序模式（0 默认/1 名称/2 更新时间/3 评分）
var _sort_mode: int = 0
@onready var recent_container: HBoxContainer = %RecentContainer
@onready var no_recent_label: Label = %NoRecentLabel
@onready var search_input: LineEdit = %SearchInput

## 组件场景
const SCRIPT_CARD_SCENE := preload("res://scenes/components/script_card.tscn")
const RECENT_CARD_SCENE := preload("res://scenes/components/recent_card.tscn")
const EMPTY_STATE_SCENE := preload("res://scenes/components/empty_state.tscn")

## 对话框场景
const CONFIRM_DIALOG_SCENE := preload("res://scenes/ui/confirm_dialog.tscn")
const ScriptSetupDialogClass = preload("res://scripts/ui/script_setup_dialog.gd")

## 对话框（动态创建）
var confirm_dialog: Control = null
var setup_dialog: Control = null

## 标签页按钮引用
var tab_buttons: Array[Button] = []
## 轮播当前索引
var carousel_index: int = 0
## 轮播数据
var featured_scripts: Array[WorldScriptData] = []
## 当前标签页的剧本卡片
var script_cards: Array[Control] = []
## 删除确认回调
var _delete_callback: Callable = Callable()
## 轮播文字切换动画引用
var _carousel_tween: Tween = null
## 轮播指示器样式缓存（避免每次切换重复创建 StyleBox）
var _dot_active_style: StyleBoxFlat = null
var _dot_inactive_style: StyleBoxFlat = null
## 搜索防抖计时器（200ms, 避免每次按键全量遍历剧本）
var _search_timer: Timer = null

## 响应式：卡片最小宽度
const CARD_MIN_WIDTH := 240

func _ready() -> void:
	_refresh_personal_stats()
	GameManager.scripts_changed.connect(func(_i): _refresh_personal_stats())
	# 首次启动欢迎引导
	if GameManager.user_data.first_launch:
		GameManager.user_data.first_launch = false
		GameManager.save_user_data()
		ToastManager.info("欢迎来到万界诗篇！点击下方【创建剧本】开始你的第一个世界")
	_setup_top_bar()
	_setup_carousel()
	_setup_tabs()
	_setup_recent_scripts()
	_refresh_script_grid()
	_connect_signals()
	_setup_dialogs()
	_update_grid_columns()
	# 搜索防抖计时器
	_search_timer = Timer.new()
	_search_timer.one_shot = true
	_search_timer.wait_time = 0.2
	_search_timer.timeout.connect(_refresh_script_grid)
	add_child(_search_timer)
	# 监听窗口大小变化
	get_tree().root.size_changed.connect(_on_window_resized)


func _input(event: InputEvent) -> void:
	# F1: 打开创建剧本（无测试副作用）
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		_on_create_script_pressed()
	# Ctrl+F: 聚焦搜索框
	if event is InputEventKey and event.pressed and event.keycode == KEY_F and event.ctrl_pressed:
		search_input.grab_focus()
		if GameManager.current_tab != 6:
			_on_tab_pressed(6)
		return
	# Esc: 优先关闭打开的对话框，其次取消搜索模式
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if setup_dialog != null and setup_dialog.visible:
			setup_dialog.visible = false
			return
		if GameManager.current_tab == 6:
			search_input.text = ""
			_on_tab_pressed(0)

## 连接信号
func _connect_signals() -> void:
	GameManager.tab_changed.connect(_on_tab_changed)
	GameManager.scripts_changed.connect(_on_scripts_changed)

## 成就查看面板
func _show_achievements() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "成就"
	dialog.min_size = Vector2i(380, 320)
	add_child(dialog)
	var list := RichTextLabel.new()
	dialog.add_child(list)
	var unlocked: Array = GameManager.user_data.achievements
	var count := 0
	for aid in GameManager.ACHIEVEMENTS:
		var name: String = GameManager.ACHIEVEMENTS[aid]
		if unlocked.has(aid):
			list.append_text("[color=#c9a06a]🏆 %s[/color]\n" % name)
			count += 1
		else:
			list.append_text("[color=#999]🔒 %s[/color]\n" % name)
	list.append_text("\n[color=#888]已解锁 %d / %d[/color]" % [count, GameManager.ACHIEVEMENTS.size()])
	dialog.popup_centered()

## 关于对话框
func _show_about() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "关于万界诗篇"
	dialog.dialog_text = """🌌 万界诗篇 v1.2.0

沙盒式游戏剧本创作与游玩平台

【创作】三模式编辑器 + 蓝图工作区 + 2D/3D 场景 + 6 游戏类型模板
【游玩】事件驱动剧情 + 经济/战斗 + 对话 + 存档继续
【社区】发布 → 市场 → 收藏 → 分享

引擎：Godot 4.7.1
"""
	dialog.min_size = Vector2i(420, 320)
	add_child(dialog)
	dialog.popup_centered()

## 刷新个人统计（剧本数/游玩数/成就数）
func _refresh_personal_stats() -> void:
	var created: int = GameManager.user_data.created_script_ids.size()
	var played: int = GameManager.user_data.played_script_ids.size()
	var ach: int = GameManager.user_data.achievements.size()
	if stats_label != null:
		stats_label.text = "📜 %d 个剧本   🎮 %d 次游玩   🏆 %d 成就" % [created, played, ach]

## 动态创建对话框
func _setup_dialogs() -> void:
	confirm_dialog = CONFIRM_DIALOG_SCENE.instantiate()
	add_child(confirm_dialog)
	confirm_dialog.confirmed.connect(_on_confirm_dialog_confirmed)
	setup_dialog = ScriptSetupDialogClass.new()
	add_child(setup_dialog)
	setup_dialog.setup_completed.connect(_on_script_setup_completed)

## === 响应式网格列数 ===
func _on_window_resized() -> void:
	_update_grid_columns()

func _update_grid_columns() -> void:
	if _list_view:
		script_grid.columns = 1
		return
	var available_width := size.x - 48  # 减去左右 margin
	var columns := clampi(int(available_width / CARD_MIN_WIDTH), 2, 5)
	script_grid.columns = columns

## === 顶栏设置 ===
func _setup_top_bar() -> void:
	_refresh_resource_labels()
	# 资源恢复/变化时实时刷新顶栏
	GameManager.resources_recovered.connect(_refresh_resource_labels)
	# 视图切换按钮（网格/列表）——追加到顶栏
	if has_node("MainMargin/VBox/TopBar"):
		var view_btn := Button.new()
		view_btn.text = "⊞ 视图"
		view_btn.tooltip_text = "切换 网格/列表 视图"
		view_btn.flat = true
		view_btn.pressed.connect(func():
			_list_view = not _list_view
			view_btn.text = "⊟ 列表" if _list_view else "⊞ 网格"
			_update_grid_columns())
		get_node("MainMargin/VBox/TopBar").add_child(view_btn)
	# 关于按钮
	var about_btn := Button.new()
	about_btn.text = "❓"
	about_btn.tooltip_text = "关于"
	about_btn.flat = true
	about_btn.pressed.connect(_show_about)
	# 成就按钮
	var ach_btn := Button.new()
	ach_btn.text = "🏆"
	ach_btn.tooltip_text = "成就"
	ach_btn.flat = true
	ach_btn.pressed.connect(_show_achievements)
	get_node("MainMargin/VBox/TopBar").add_child(ach_btn)
	# 刷新按钮
	var refresh_btn := Button.new()
	refresh_btn.text = "↻"
	refresh_btn.tooltip_text = "刷新剧本库"
	refresh_btn.flat = true
	refresh_btn.pressed.connect(func():
		GameManager.reload_scripts()
		ToastManager.success("剧本库已刷新"))
	get_node("MainMargin/VBox/TopBar").add_child(refresh_btn)
	# 排序选项
	var sort_opt := OptionButton.new()
	sort_opt.add_item("默认排序", 0)
	sort_opt.add_item("按名称", 1)
	sort_opt.add_item("按更新时间", 2)
	sort_opt.add_item("按评分", 3)
	sort_opt.flat = true
	sort_opt.tooltip_text = "排序方式"
	sort_opt.item_selected.connect(func(idx: int):
		_sort_mode = idx
		_refresh_script_grid())
	get_node("MainMargin/VBox/TopBar").add_child(sort_opt)
	get_node("MainMargin/VBox/TopBar").add_child(about_btn)
	GameManager.resources_changed.connect(_refresh_resource_labels)

func _refresh_resource_labels() -> void:
	shimo_label.text = str(GameManager.user_data.shimo)
	jieshi_label.text = str(GameManager.user_data.jieshi)
	inspiration_label.text = GameManager.user_data.get_inspiration_display()
	if has_node("%EnergyLabel"):
		var energy_label: Label = %EnergyLabel
		energy_label.text = GameManager.user_data.get_creation_energy_display()

## === 轮播设置 ===
func _setup_carousel() -> void:
	featured_scripts = GameManager.get_featured_scripts()
	_update_carousel()
	carousel_timer.start(5.0)

func _update_carousel() -> void:
	if featured_scripts.is_empty():
		carousel_label.text = "暂无推荐剧本"
		return
	var script_data := featured_scripts[carousel_index]
	carousel_label.text = "%s — %s\n%s" % [script_data.name, script_data.author, script_data.description]
	# 切换文字淡入动效（尊重全局动效开关）
	if _carousel_tween:
		_carousel_tween.kill()
	carousel_label.modulate.a = 0.0
	_carousel_tween = ThemeManager.create_anim(carousel_label)
	_carousel_tween.tween_property(carousel_label, "modulate:a", 1.0, 0.35)
	# 点击轮播进入该剧本（悬停提示）
	if not carousel_label.gui_input.is_connected(_on_carousel_clicked):
		carousel_label.gui_input.connect(_on_carousel_clicked)

## 轮播点击进入剧本
func _on_carousel_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not featured_scripts.is_empty() and carousel_index < featured_scripts.size():
			SceneManager.enter_script(featured_scripts[carousel_index].id)
	# 更新指示器（预创建样式, 避免每次切换重复 duplicate）
	if _dot_active_style == null:
		_dot_active_style = StyleBoxFlat.new()
		_dot_active_style.bg_color = ThemeManager.C_ACCENT
		_dot_active_style.set_corner_radius_all(4)
		_dot_inactive_style = StyleBoxFlat.new()
		_dot_inactive_style.bg_color = Color(0.769, 0.588, 0.353, 0.3)
		_dot_inactive_style.set_corner_radius_all(4)
	# 指示器数量随轮播页数动态增减（tscn 固定 4 个 → 按需补齐/隐藏）
	while carousel_indicator.get_child_count() < featured_scripts.size():
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(8, 8)
		carousel_indicator.add_child(dot)
	for i in carousel_indicator.get_child_count():
		var dot: Panel = carousel_indicator.get_child(i)
		dot.visible = i < featured_scripts.size()
		dot.add_theme_stylebox_override("panel", _dot_active_style if i == carousel_index else _dot_inactive_style)

func _on_carousel_timer_timeout() -> void:
	if featured_scripts.is_empty():
		return
	carousel_index = (carousel_index + 1) % featured_scripts.size()
	_update_carousel()

func _on_carousel_prev_pressed() -> void:
	if featured_scripts.is_empty():
		return
	carousel_index = (carousel_index - 1 + featured_scripts.size()) % featured_scripts.size()
	_update_carousel()
	carousel_timer.start(5.0)

func _on_carousel_next_pressed() -> void:
	if featured_scripts.is_empty():
		return
	carousel_index = (carousel_index + 1) % featured_scripts.size()
	_update_carousel()
	carousel_timer.start(5.0)

## === 标签页设置 ===
func _setup_tabs() -> void:
	var tab_names := ["我的剧本", "热门剧本", "最新剧本", "精选剧本", "收藏", "市场", "搜索"]
	for i in tab_names.size():
		var btn := Button.new()
		btn.text = tab_names[i]
		btn.toggle_mode = true
		btn.button_pressed = (i == 0)
		btn.add_theme_font_size_override("font_size", 14)
		btn.pressed.connect(_on_tab_pressed.bind(i))
		tab_container.add_child(btn)
		tab_buttons.append(btn)
	search_input.visible = false
	search_input.placeholder_text = "搜索剧本名称、标签、作者..."

func _on_tab_pressed(tab_index: int) -> void:
	search_input.visible = (tab_index == 4)
	GameManager.set_current_tab(tab_index)
	_refresh_script_grid()
	# 切到搜索标签时自动聚焦搜索框
	if tab_index == 4:
		search_input.grab_focus()
		search_input.select_all()

func _on_tab_changed(tab_index: int) -> void:
	for i in tab_buttons.size():
		tab_buttons[i].button_pressed = (i == tab_index)

func _on_search_text_changed(_new_text: String) -> void:
	# 防抖: 停止并重启计时器, 停止输入 200ms 后才刷新
	_search_timer.stop()
	_search_timer.start()

## === 剧本网格（组件化） ===
func _refresh_script_grid() -> void:
	for card in script_cards:
		card.queue_free()
	script_cards.clear()

	var scripts_list: Array[WorldScriptData]
	if GameManager.current_tab == 6:
		scripts_list = _search_scripts(search_input.text)
	else:
		scripts_list = GameManager.get_scripts_by_tab(GameManager.current_tab)
	# 排序（名称/更新时间/评分）
	match _sort_mode:
		1:
			scripts_list.sort_custom(func(a, b): return a.name < b.name)
		2:
			scripts_list.sort_custom(func(a, b): return a.updated_at > b.updated_at)
		3:
			scripts_list.sort_custom(func(a, b): return a.rating > b.rating)

	if scripts_list.is_empty():
		if GameManager.current_tab == 6:
			# 搜索无结果：区分文案，不显示创建按钮
			var empty_search: EmptyState = EMPTY_STATE_SCENE.instantiate()
			script_grid.add_child(empty_search)
			empty_search.setup("未找到匹配的剧本", "🔍", "", false)
			script_cards.append(empty_search)
		else:
			_show_empty_state()
		return

	for script_data in scripts_list:
		var card: ScriptCard = SCRIPT_CARD_SCENE.instantiate()
		script_grid.add_child(card)
		card.setup(script_data)
		card.clicked.connect(_on_card_clicked)
		card.edit_requested.connect(_on_edit_script_pressed)
		card.delete_requested.connect(_on_delete_script_pressed)
		card.favorite_requested.connect(_on_favorite_pressed)
		script_cards.append(card)

func _search_scripts(query: String) -> Array[WorldScriptData]:
	if query.is_empty():
		var all: Array[WorldScriptData] = []
		for s in GameManager.scripts.values():
			all.append(s)
		return all
	var result: Array[WorldScriptData] = []
	var q := query.to_lower()
	for s in GameManager.scripts.values():
		if q in s.name.to_lower() or q in s.description.to_lower() or s.tags.any(func(t): return q in t.to_lower()):
			result.append(s)
	return result

func _show_empty_state() -> void:
	var empty: EmptyState = EMPTY_STATE_SCENE.instantiate()
	script_grid.add_child(empty)
	empty.setup("这里还没有剧本", "📜", "创建新剧本", true)
	empty.action_pressed.connect(_on_create_script_pressed)
	script_cards.append(empty)

func _on_favorite_pressed(script_id: String) -> void:
	var fav := GameManager.toggle_favorite(script_id)
	ToastManager.success("已收藏 ♥" if fav else "已取消收藏")
	if fav:
		GameManager.unlock_achievement("first_favorite", "收藏第一个剧本")
	_refresh_script_grid()
	if GameManager.current_tab == 4:
		_on_tab_pressed(4)

func _on_card_clicked(script_id: String) -> void:
	# 详情弹窗（大图/描述/评分/操作），避免误触直接进入
	var ws: Variant = GameManager.get_script_data(script_id)
	if ws == null:
		return
	var dialog := AcceptDialog.new()
	dialog.title = ws.name
	dialog.min_size = Vector2i(460, 420)
	add_child(dialog)
	var box := VBoxContainer.new()
	dialog.add_child(box)
	# 封面
	var cover_path := ""
	if not ws.thumbnail_path.is_empty():
		cover_path = ProjectSettings.globalize_path("user://scripts/%s/%s" % [ws.id, ws.thumbnail_path])
	if not cover_path.is_empty() and FileAccess.file_exists(cover_path):
		var tex := ImageTexture.create_from_image(Image.load_from_file(cover_path))
		if tex != null:
			var cover := TextureRect.new()
			cover.texture = tex
			cover.custom_minimum_size.y = 140
			cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			box.add_child(cover)
	# 信息
	var info := RichTextLabel.new()
	info.custom_minimum_size.y = 150
	info.bbcode_enabled = true
	info.append_text("[color=#c9a06a][b]%s[/b][/color]  by %s\n" % [ws.name, ws.author])
	info.append_text("★ %.1f（%d人） · %d人体验 · 📜%s\n" % [ws.rating, ws.rating_count, ws.play_count, str(ws.status)])
	info.append_text("\n%s" % ws.description)
	box.add_child(info)
	# 操作
	var btns := HBoxContainer.new()
	var play := Button.new()
	play.text = "▶ 体验"
	play.pressed.connect(func():
		dialog.queue_free()
		SceneManager.enter_script(script_id))
	btns.add_child(play)
	var edit := Button.new()
	edit.text = "✏ 编辑"
	edit.pressed.connect(func():
		dialog.queue_free()
		SceneManager.open_script_editor(script_id))
	btns.add_child(edit)
	var fav := Button.new()
	fav.text = "♥ 收藏" if not GameManager.is_favorite(script_id) else "♡ 取消收藏"
	fav.pressed.connect(func():
		GameManager.toggle_favorite(script_id)
		dialog.queue_free()
		ToastManager.success("收藏已更新"))
	btns.add_child(fav)
	# 同标签搜索（社区发现）
	if not ws.tags.is_empty():
		var tag_btn := Button.new()
		tag_btn.text = "🔍 同标签"
		tag_btn.pressed.connect(func():
			dialog.queue_free()
			search_input.text = str(ws.tags[0])
			_on_tab_pressed(6)
			search_input.grab_focus())
		btns.add_child(tag_btn)
	box.add_child(btns)
	dialog.popup_centered()

## === 最近体验（组件化） ===
func _setup_recent_scripts() -> void:
	var recent := GameManager.get_recent_scripts()
	if recent.is_empty():
		no_recent_label.visible = true
		return
	no_recent_label.visible = false
	for script_data in recent:
		var card: RecentCard = RECENT_CARD_SCENE.instantiate()
		recent_container.add_child(card)
		card.setup(script_data)
		card.clicked.connect(_on_card_clicked)

## === 底部操作栏 ===
func _on_create_script_pressed() -> void:
	if setup_dialog != null and setup_dialog.visible:
		return  # 防重入：对话框已打开时不重复消耗/弹出
	if not GameManager.user_data.consume_creation_energy():
		ToastManager.warning("精力不足，无法创建剧本！请等待恢复或稍后再试")
		return
	GameManager.save_user_data()
	setup_dialog.show_dialog()

## 剧本设置对话框确认回调
func _on_script_setup_completed(config: Dictionary) -> void:
	var script_name: String = config.get("name", "未命名剧本")
	var template_id: String = config.get("template_id", "")
	var editor_mode: String = config.get("editor_mode", "visual")
	var run_type: String = config.get("run_type", "local")
	var tags: Array = config.get("tags", [])
	# 构建 metadata
	var meta := {
		"editor_mode": editor_mode,
		"run_type": run_type,
	}
	if run_type == "online":
		meta["online"] = true
	elif run_type == "server":
		meta["server_based"] = true
	# 创建剧本
	var ws := ScriptDataManager.create_script(script_name, GameManager.user_data.player_name, template_id, meta)
	if ws == null:
		ToastManager.error("剧本创建失败")
		return
	# 设置标签
	if not tags.is_empty():
		ws.tags = Array(tags, TYPE_STRING, "", null)
		ScriptDataManager.update_script(ws)
	ToastManager.success("剧本「%s」创建成功！" % script_name)
	# 进入编辑器
	SceneManager.open_script_editor(ws.id)

func _on_import_script_pressed() -> void:
	var file_dialog := FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = PackedStringArray(["*.json ; 剧本文件"])
	file_dialog.title = "导入剧本"
	add_child(file_dialog)
	file_dialog.file_selected.connect(func(path: String):
		var ws: WorldScriptData = ScriptDataManager.import_script(path)
		if ws != null:
			ToastManager.success("导入成功: %s" % ws.name)
		else:
			ToastManager.error("导入失败，请检查文件格式")
		file_dialog.queue_free()
	)
	file_dialog.canceled.connect(func(): file_dialog.queue_free())
	file_dialog.popup_centered(Vector2i(600, 400))

func _on_settings_pressed() -> void:
	SceneManager.open_settings()

## 编辑剧本
func _on_edit_script_pressed(script_id: String) -> void:
	SceneManager.open_script_editor(script_id)

## 删除剧本
func _on_delete_script_pressed(script_id: String, script_name: String) -> void:
	_delete_callback = func():
		ScriptDataManager.delete_script(script_id)
		ToastManager.success("已删除剧本: %s" % script_name)
	confirm_dialog.show_dialog("确认删除", "确定要删除剧本 \"%s\" 吗？\n此操作不可撤销。" % script_name)

## === 确认对话框 ===
func _on_confirm_dialog_confirmed() -> void:
	if _delete_callback.is_valid():
		_delete_callback.call()
		_delete_callback = Callable()

## 信号处理 ===
func _on_scripts_changed() -> void:
	_refresh_script_grid()
	_setup_recent_scripts()
