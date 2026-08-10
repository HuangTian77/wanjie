## 存档管理器（Autoload单例）
## 对应GDD §5 存档与数据管理系统
## 管理剧本存档的保存、加载、删除、自动存档
extends Node

const SAVE_BASE_PATH := "user://saves/"
const MAX_MANUAL_SLOTS := 10
const MAX_AUTOSAVE_SLOTS := 3
## 差分存档格式版本
const SAVE_FORMAT_VERSION := 2

signal save_completed(slot: int)
signal load_completed(slot: int)
signal save_deleted(slot: int)

## 当前活跃的存档数据（运行时）
var current_save: SaveData = null
## 当前剧本ID
var current_script_id: String = ""
## 游戏开始时间（用于计算游玩时长）
var session_start_time: float = 0.0

## 获取指定剧本的存档目录
func _get_save_dir(script_id: String) -> String:
	return SAVE_BASE_PATH + script_id + "/"

## 获取存档文件路径
func _get_save_path(script_id: String, slot: int, is_autosave: bool = false) -> String:
	if is_autosave:
		return _get_save_dir(script_id) + "autosave_%d.json" % slot
	return _get_save_dir(script_id) + "save_slot_%02d.json" % slot

## 获取存档元数据路径
func _get_metadata_path(script_id: String) -> String:
	return _get_save_dir(script_id) + "metadata.json"

## 获取存档基准文件路径（差分存档的完整快照基准）
func _get_base_path(script_id: String) -> String:
	return _get_save_dir(script_id) + "base.json"

## 保存游戏到指定槽位
## 自动存档(差分): 写 base.json(完整) + autosave_X.json(仅变化字段的 delta)
## 手动存档(完整): 写完整快照并刷新 base.json, 保证差分基准最新
func save_game(slot: int, is_autosave: bool = false) -> bool:
	if current_save == null or current_script_id.is_empty():
		push_warning("SaveManager: 没有活跃的存档数据")
		return false

	# 更新游玩时长
	current_save.play_time_seconds += Time.get_ticks_msec() / 1000.0 - session_start_time
	session_start_time = Time.get_ticks_msec() / 1000.0

	# 更新时间戳
	current_save.saved_at = Time.get_datetime_string_from_system()
	current_save.is_autosave = is_autosave
	current_save.slot_index = slot

	# 确保目录存在
	var dir_path := _get_save_dir(current_script_id)
	DirAccess.make_dir_recursive_absolute(dir_path)

	var file_path := _get_save_path(current_script_id, slot, is_autosave)
	if is_autosave:
		# === 差分存档: base.json(完整基准) + delta ===
		_write_base_snapshot()
		var delta := _make_delta()
		var payload := {
			"format": SAVE_FORMAT_VERSION,
			"is_autosave": true,
			"saved_at": current_save.saved_at,
			"slot_index": slot,
			"delta": delta,
		}
		if not _write_json(file_path, payload):
			return false
	else:
		# === 完整存档(手动): 全量快照, 并刷新差分基准 ===
		var full := _save_data_to_dict(current_save)
		if not _write_json(file_path, full):
			return false
		_write_base_snapshot()

	# 更新元数据
	_update_metadata(slot, is_autosave)
	save_completed.emit(slot)
	return true

## 从指定槽位加载游戏
func load_game(slot: int, is_autosave: bool = false) -> SaveData:
	var file_path := _get_save_path(current_script_id, slot, is_autosave)
	if not FileAccess.file_exists(file_path):
		push_warning("SaveManager: 存档不存在 %s" % file_path)
		return null

	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("SaveManager: 无法读取文件 %s" % file_path)
		return null

	var json_string := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(json_string)
	if err != OK:
		push_error("SaveManager: JSON解析失败 %s" % json.get_error_message())
		return null

	var data_dict: Dictionary = json.data
	# 兼容差分格式: {format:2, delta} + base.json 合并
	if data_dict.get("format", 1) == SAVE_FORMAT_VERSION and data_dict.has("delta"):
		var base := _load_base(current_script_id)
		var merged := base.duplicate(true)
		var delta: Dictionary = data_dict["delta"]
		for key in delta:
			merged[key] = delta[key]
		data_dict = merged
	current_save = _dict_to_save_data(data_dict)
	session_start_time = Time.get_ticks_msec() / 1000.0
	load_completed.emit(slot)
	return current_save

## 删除指定槽位的存档
func delete_save(script_id: String, slot: int, is_autosave: bool = false) -> bool:
	var file_path := _get_save_path(script_id, slot, is_autosave)
	if FileAccess.file_exists(file_path):
		DirAccess.remove_absolute(file_path)
		save_deleted.emit(slot)
		return true
	return false

## 列出指定剧本的所有存档
func list_saves(script_id: String) -> Array[Dictionary]:
	var saves: Array[Dictionary] = []
	var dir_path := _get_save_dir(script_id)
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return saves

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json") and file_name.begins_with("save_slot_"):
			var slot_str := file_name.trim_prefix("save_slot_").trim_suffix(".json")
			var slot := int(slot_str)
			var info := _read_save_info(dir_path + file_name)
			info["slot"] = slot
			info["is_autosave"] = false
			saves.append(info)
		elif file_name.begins_with("autosave_"):
			var slot_str := file_name.trim_prefix("autosave_").trim_suffix(".json")
			var slot := int(slot_str)
			var info := _read_save_info(dir_path + file_name)
			info["slot"] = slot
			info["is_autosave"] = true
			saves.append(info)
		file_name = dir.get_next()
	dir.list_dir_end()

	saves.sort_custom(func(a, b): return a.get("saved_at", "") > b.get("saved_at", ""))
	return saves

## 开始新游戏
func start_new_game(script_id: String, slot: int = 0) -> SaveData:
	current_script_id = script_id
	current_save = SaveData.create_new(script_id, slot)
	session_start_time = Time.get_ticks_msec() / 1000.0
	return current_save

## 自动存档
func autosave() -> bool:
	if current_save == null:
		return false
	# 轮转自动存档（保留最近3个）
	for i in range(MAX_AUTOSAVE_SLOTS - 1, 0, -1):
		var src := _get_save_path(current_script_id, i - 1, true)
		var dst := _get_save_path(current_script_id, i, true)
		if FileAccess.file_exists(src):
			DirAccess.copy_absolute(src, dst)
	return save_game(0, true)

## 检查存档是否存在
func has_save(script_id: String) -> bool:
	var dir_path := _get_save_dir(script_id)
	return DirAccess.dir_exists_absolute(dir_path)

## 获取指定槽位的存档信息
func get_slot_info(slot: int, is_autosave: bool = false) -> Dictionary:
	if current_script_id.is_empty():
		return {}
	var file_path := _get_save_path(current_script_id, slot, is_autosave)
	if not FileAccess.file_exists(file_path):
		return {}
	return _read_save_info(file_path)

## === 内部方法 ===

func _save_data_to_dict(sd: SaveData) -> Dictionary:
	return {
		"save_id": sd.save_id,
		"script_id": sd.script_id,
		"script_version": sd.script_version,
		"slot_index": sd.slot_index,
		"is_autosave": sd.is_autosave,
		"saved_at": sd.saved_at,
		"play_time_seconds": sd.play_time_seconds,
		"player_state": sd.player_state,
		"world_state": sd.world_state,
		"event_history": sd.event_history,
		"economy_state": sd.economy_state,
		"progress": sd.progress
	}

func _dict_to_save_data(d: Dictionary) -> SaveData:
	var sd := SaveData.new()
	sd.save_id = d.get("save_id", "")
	sd.script_id = d.get("script_id", "")
	sd.script_version = d.get("script_version", "1.0.0")
	sd.slot_index = d.get("slot_index", 0)
	sd.is_autosave = d.get("is_autosave", false)
	sd.saved_at = d.get("saved_at", "")
	sd.play_time_seconds = d.get("play_time_seconds", 0.0)
	sd.player_state = d.get("player_state", {})
	sd.world_state = d.get("world_state", {})
	sd.event_history = d.get("event_history", {})
	sd.economy_state = d.get("economy_state", {})
	sd.progress = d.get("progress", 0.0)
	return sd

func _read_save_info(file_path: String) -> Dictionary:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}
	file.close()
	var d: Dictionary = json.data
	# 差分格式: 与 base 合并后再提取展示信息
	if d.get("format", 1) == SAVE_FORMAT_VERSION and d.has("delta"):
		var base := _load_base(d.get("script_id", current_script_id))
		var merged := base.duplicate(true)
		var delta: Dictionary = d["delta"]
		for key in delta:
			merged[key] = delta[key]
		d = merged
	return {
		"saved_at": d.get("saved_at", ""),
		"play_time": d.get("play_time_seconds", 0.0),
		"player_name": d.get("player_state", {}).get("name", "未知"),
		"level": d.get("player_state", {}).get("level", 1),
		"progress": d.get("progress", 0.0),
		"day": d.get("world_state", {}).get("game_time", {}).get("day", 1),
		"gold": d.get("economy_state", {}).get("currencies", {}).get("gold", 0)
	}

## === 差分存档内部方法 ===

## 写入 JSON 文件
func _write_json(path: String, data) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: 无法打开文件 %s" % path)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true

## 读取完整存档快照（无 base 时返回空）
func _load_base(script_id: String) -> Dictionary:
	var path := _get_base_path(script_id)
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var j := JSON.new()
	if j.parse(file.get_as_text()) != OK:
		return {}
	file.close()
	return j.data.get("full", {})

## 写入 base 完整快照
func _write_base_snapshot() -> void:
	var payload := {
		"format": SAVE_FORMAT_VERSION,
		"script_id": current_script_id,
		"saved_at": current_save.saved_at,
		"full": _save_data_to_dict(current_save),
	}
	_write_json(_get_base_path(current_script_id), payload)

## 生成当前存档相对 base 的变化字段（差分）
func _make_delta() -> Dictionary:
	var base := _load_base(current_script_id)
	var full := _save_data_to_dict(current_save)
	var delta := {}
	for key in full:
		if not base.has(key) or JSON.stringify(base[key]) != JSON.stringify(full[key]):
			delta[key] = full[key]
	return delta

func _update_metadata(_slot: int, _is_autosave: bool) -> void:
	var meta_path := _get_metadata_path(current_script_id)
	var meta := {}
	if FileAccess.file_exists(meta_path):
		var reader := FileAccess.open(meta_path, FileAccess.READ)
		if reader:
			var j := JSON.new()
			if j.parse(reader.get_as_text()) == OK:
				meta = j.data
			reader.close()

	meta["last_save"] = Time.get_datetime_string_from_system()
	meta["total_saves"] = meta.get("total_saves", 0) + 1

	var writer := FileAccess.open(meta_path, FileAccess.WRITE)
	if writer:
		writer.store_string(JSON.stringify(meta, "\t"))
		writer.close()
