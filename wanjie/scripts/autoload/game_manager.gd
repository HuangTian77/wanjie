## 全局状态管理器（Autoload单例）
## 管理用户数据、剧本列表、全局游戏状态
extends Node

## 用户数据
var user_data: UserData = null
## 所有可用剧本（key=id, value=WorldScriptData）
var scripts: Dictionary = {}
## 当前选中的标签页索引
var current_tab: int = 0
## 信号：剧本列表变化
signal scripts_changed
## 信号：标签页切换
signal tab_changed(tab_index: int)
## 信号：资源恢复（灵感/精力变化时触发）
signal resources_recovered
## 信号：用户资源/货币变化（诗墨/界石/灵感/精力任意变化时触发）
signal resources_changed

## 恢复计时器
var _recovery_timer: Timer = null

## 用户数据持久化路径
const USER_DATA_PATH := "user://user_data.json"

func _ready() -> void:
	_initialize_user_data()
	# 监听ScriptDataManager的信号
	ScriptDataManager.script_created.connect(_on_script_created)
	ScriptDataManager.script_deleted.connect(_on_script_deleted)
	ScriptDataManager.script_imported.connect(_on_script_imported)
	# 加载用户已保存的剧本
	_load_user_scripts()
	# 启动资源恢复计时器（60秒恢复1点）
	_setup_recovery_timer()

## 启动资源恢复计时器
func _setup_recovery_timer() -> void:
	_recovery_timer = Timer.new()
	_recovery_timer.wait_time = 60.0
	_recovery_timer.autostart = true
	_recovery_timer.timeout.connect(_on_recovery_tick)
	add_child(_recovery_timer)

## 每60秒恢复资源
func _on_recovery_tick() -> void:
	var recovered := false
	if user_data.inspiration < user_data.inspiration_max:
		user_data.inspiration += 1
		recovered = true
	if user_data.creation_energy < user_data.creation_energy_max:
		user_data.creation_energy += 1
		recovered = true
	if recovered:
		user_data.last_recovery_time = int(Time.get_unix_time_from_system())
		_save_user_data()
		resources_recovered.emit()

## 加载用户已保存的剧本
func _load_user_scripts() -> void:
	for sid in ScriptDataManager.user_scripts:
		var ws = ScriptDataManager.user_scripts[sid]
		if ws != null and not scripts.has(sid):
			scripts[sid] = ws

## 初始化用户数据
func _initialize_user_data() -> void:
	# 优先从持久化文件加载
	if FileAccess.file_exists(USER_DATA_PATH):
		var f := FileAccess.open(USER_DATA_PATH, FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				user_data = UserData.from_dict(parsed)
				_recover_offline_resources()
				return
	# 首次运行: 默认数据
	user_data = UserData.new()
	user_data.player_name = "旅者"
	user_data.shimo = 1250
	user_data.jieshi = 50
	user_data.inspiration = 10
	user_data.creation_energy = 5
	user_data.recent_script_ids = []
	user_data.last_recovery_time = int(Time.get_unix_time_from_system())
	_save_user_data()

## 保存用户数据（外部变更后调用: 资源消耗/获得等）
func save_user_data() -> void:
	_save_user_data()

## 写入用户数据到磁盘
func _save_user_data() -> void:
	if user_data == null:
		return
	var f := FileAccess.open(USER_DATA_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(user_data.to_dict()))
	resources_changed.emit()

## 离线恢复: 按时间差补发灵感/精力（每分钟1点, 封顶到上限）
func _recover_offline_resources() -> void:
	var now := int(Time.get_unix_time_from_system())
	var elapsed: int = maxi(now - user_data.last_recovery_time, 0)
	var recovered_ticks: int = int(elapsed / 60)
	if recovered_ticks <= 0:
		user_data.last_recovery_time = now
		return
	user_data.inspiration = mini(user_data.inspiration + recovered_ticks, user_data.inspiration_max)
	user_data.creation_energy = mini(user_data.creation_energy + recovered_ticks, user_data.creation_energy_max)
	user_data.last_recovery_time = now
	_save_user_data()

## 根据ID获取剧本数据
func get_script_data(script_id: String) -> WorldScriptData:
	return scripts.get(script_id, null) as WorldScriptData

## 获取按标签过滤的剧本列表
func get_scripts_by_tab(tab_index: int) -> Array[WorldScriptData]:
	var result: Array[WorldScriptData] = []
	match tab_index:
		0: # 我的剧本
			for sid in user_data.created_script_ids:
				if scripts.has(sid):
					result.append(scripts[sid])
		1: # 热门
			var all := scripts.values()
			all.sort_custom(func(a, b): return a.play_count > b.play_count)
			for s in all:
				result.append(s)
		2: # 最新
			var all := scripts.values()
			all.sort_custom(func(a, b): return a.created_at > b.created_at)
			for s in all:
				result.append(s)
		3: # 精选
			var all := scripts.values()
			all.sort_custom(func(a, b): return a.rating > b.rating)
			for s in all:
				result.append(s)
		4: # 收藏（市场/社区雏形）
			result = get_favorites()
	return result

## 获取推荐剧本（用于轮播）
func get_featured_scripts() -> Array[WorldScriptData]:
	var result: Array[WorldScriptData] = []
	var all := scripts.values()
	all.sort_custom(func(a, b): return a.rating > b.rating)
	for i in mini(4, all.size()):
		result.append(all[i])
	return result

## 获取最近体验的剧本
func get_recent_scripts() -> Array[WorldScriptData]:
	var result: Array[WorldScriptData] = []
	for sid in user_data.recent_script_ids:
		if scripts.has(sid):
			result.append(scripts[sid])
	return result

## 记录一次体验（体验数+1、最近体验前置、持久化剧本）
func record_play(script_id: String) -> void:
	var ws := get_script_data(script_id)
	if ws == null:
		return
	ws.play_count += 1
	user_data.recent_script_ids.erase(script_id)
	user_data.recent_script_ids.push_front(script_id)
	if user_data.recent_script_ids.size() > 5:
		user_data.recent_script_ids.resize(5)
	_save_user_data()
	ScriptDataManager.update_script(ws, ["play_count"])

## 收藏/取消收藏（返回是否已收藏）
func toggle_favorite(script_id: String) -> bool:
	var favorites := user_data.favorites_script_ids
	if favorites.has(script_id):
		favorites.erase(script_id)
		_save_user_data()
		return false
	favorites.append(script_id)
	_save_user_data()
	return true

func is_favorite(script_id: String) -> bool:
	return user_data.favorites_script_ids.has(script_id)

## 收藏列表
func get_favorites() -> Array[WorldScriptData]:
	var result: Array[WorldScriptData] = []
	for sid in user_data.favorites_script_ids:
		var ws := get_script_data(sid)
		if ws != null:
			result.append(ws)
	return result

## 切换标签页
func set_current_tab(tab_index: int) -> void:
	current_tab = tab_index
	tab_changed.emit(tab_index)

## === ScriptDataManager信号处理 ===
func _on_script_created(script_id: String) -> void:
	var ws := ScriptDataManager.find_script(script_id)
	if ws:
		scripts[script_id] = ws
		user_data.created_script_ids.append(script_id)
		save_user_data()
		scripts_changed.emit()

func _on_script_deleted(script_id: String) -> void:
	scripts.erase(script_id)
	user_data.created_script_ids.erase(script_id)
	save_user_data()
	scripts_changed.emit()

func _on_script_imported(script_id: String) -> void:
	_on_script_created(script_id)
