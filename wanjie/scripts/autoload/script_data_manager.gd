## 脚本数据管理器（Autoload单例）
## 管理剧本的CRUD、导入导出、模板系统
extends Node

const SCRIPTS_PATH := "user://scripts/"

## 子系统字段名 -> data/ 下数据文件名映射 (拆分存储)
const SUBSYSTEM_FILES := {
	"worldview": "worldview.json",
	"event_system": "events.json",
	"economy_system": "economy.json",
	"ability_system": "abilities.json",
	"quest_system": "quest.json",
	"combat_system": "combat.json",
}

signal script_created(script_id: String)
signal script_updated(script_id: String)
signal script_deleted(script_id: String)
signal script_imported(script_id: String)

## 所有用户创建的剧本缓存
var user_scripts: Dictionary = {}

func _ready() -> void:
	_ensure_dir()
	_migrate_legacy()
	_load_all_scripts()
	_migrate_split()

## 确保目录存在
func _ensure_dir() -> void:
	DirAccess.make_dir_recursive_absolute(SCRIPTS_PATH)

## 剧本项目文件夹路径: user://scripts/{id}/
func get_script_dir(script_id: String) -> String:
	return SCRIPTS_PATH + script_id

## 剧本主数据文件路径: user://scripts/{id}/script.json
func get_script_file(script_id: String) -> String:
	return SCRIPTS_PATH + script_id + "/script.json"

## 迁移旧单文件剧本 ({id}.json) 为项目目录格式 ({id}/script.json)
func _migrate_legacy() -> void:
	var dir := DirAccess.open(SCRIPTS_PATH)
	if dir == null:
		return
	var legacy_files: Array[String] = []
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with(".json"):
			legacy_files.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	for fname in legacy_files:
		var script_id := fname.get_basename()
		DirAccess.make_dir_recursive_absolute(get_script_dir(script_id))
		var old_path := SCRIPTS_PATH + fname
		var new_path := get_script_file(script_id)
		if not FileAccess.file_exists(new_path):
			DirAccess.rename_absolute(old_path, new_path)
		else:
			DirAccess.remove_absolute(old_path)
		print("ScriptDataManager: 迁移旧剧本 %s → %s/" % [fname, script_id])

## 加载所有用户剧本 (扫描项目目录 {id}/script.json, 兼容旧单文件)
func _load_all_scripts() -> void:
	var dir := DirAccess.open(SCRIPTS_PATH)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry != "." and entry != ".." and not entry.begins_with("."):
			if dir.current_is_dir():
				# 目录格式: {id}/ (script.json + data/ 拆分文件)
				var script := _load_script_dir(get_script_dir(entry))
				if script != null:
					user_scripts[script.id] = script
			elif entry.ends_with(".json"):
				# 旧单文件格式兑底
				var script := _load_script_file(SCRIPTS_PATH + entry)
				if script != null:
					user_scripts[script.id] = script
		entry = dir.get_next()
	dir.list_dir_end()

## 从文件加载单个剧本
func _load_script_file(file_path: String) -> WorldScriptData:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return null
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("ScriptDataManager: 无法解析 %s: %s" % [file_path, json.get_error_message()])
		return null
	file.close()
	return _dict_to_script(json.data)

## 保存剧本到项目目录 (拆分存储 + Write-Ahead 原子性保障)
## 策略: 先写入 .tmp 后缀临时文件, 全部成功后逐一 rename 覆盖正式文件
## 中途崩溃时正式文件不受影响, 加载时自动清理残留 .tmp
func save_script(script_data: WorldScriptData, dirty_keys: Array = []) -> bool:
	var dir_path := get_script_dir(script_data.id)
	DirAccess.make_dir_recursive_absolute(dir_path + "/data")
	DirAccess.make_dir_recursive_absolute(dir_path + "/assets")
	# === Phase 1: 写入临时文件 ===
	var tmp_files: Array[String] = []  # 记录已写入的临时文件路径
	var final_files: Array[String] = []  # 对应的正式路径
	# 主数据文件（始终写入: 含元数据与 quest/combat 内联数据）
	var meta_path := get_script_file(script_data.id)
	var meta_tmp := meta_path + ".tmp"
	if not _write_json_file(meta_tmp, _script_to_meta_dict(script_data)):
		push_error("ScriptDataManager: 无法写入 %s" % meta_tmp)
		_cleanup_tmp_files(tmp_files)
		return false
	tmp_files.append(meta_tmp)
	final_files.append(meta_path)
	# 各子系统临时文件（差分写入: dirty_keys 非空时仅写列出的子系统）
	for key in SUBSYSTEM_FILES:
		if not dirty_keys.is_empty() and not dirty_keys.has(key):
			continue
		var res: Resource = script_data.get(key)
		if res == null:
			continue
		var fname: String = SUBSYSTEM_FILES[key]
		var final_path := dir_path + "/data/" + fname
		var tmp_path := final_path + ".tmp"
		if not _write_json_file(tmp_path, _resource_to_dict(res)):
			push_warning("ScriptDataManager: 无法写入 %s" % tmp_path)
			_cleanup_tmp_files(tmp_files)
			return false
		tmp_files.append(tmp_path)
		final_files.append(final_path)
	# === Phase 2: 全部写入成功, 原子提交 (rename 覆盖) ===
	for i in tmp_files.size():
		var tmp: String = tmp_files[i]
		var final: String = final_files[i]
		if FileAccess.file_exists(final):
			DirAccess.remove_absolute(final)
		if DirAccess.rename_absolute(tmp, final) != OK:
			push_error("ScriptDataManager: rename 失败 %s → %s" % [tmp, final])
			# 已提交的无法回滚, 但未提交的仍安全
	user_scripts[script_data.id] = script_data
	# MUD数据落盘: 同步导出数据表txt到 {id}/mud/
	_export_mud_files(script_data)
	return true

## 写入 JSON 到指定路径 (成功返回true)
func _write_json_file(path: String, data) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return true

## 清理写入失败的临时文件
func _cleanup_tmp_files(tmp_files: Array[String]) -> void:
	for tmp in tmp_files:
		if FileAccess.file_exists(tmp):
			DirAccess.remove_absolute(tmp)

## 清理剧本目录中残留的 .tmp 文件 (崩溃恢复)
func _cleanup_residual_tmp(dir_path: String) -> void:
	# 检查主文件
	var meta_tmp := dir_path + "/script.json.tmp"
	if FileAccess.file_exists(meta_tmp):
		DirAccess.remove_absolute(meta_tmp)
	# 检查 data/ 子目录
	var data_dir := DirAccess.open(dir_path + "/data")
	if data_dir == null:
		return
	data_dir.list_dir_begin()
	var entry := data_dir.get_next()
	while entry != "":
		if entry.ends_with(".tmp"):
			data_dir.remove(entry)
		entry = data_dir.get_next()
	data_dir.list_dir_end()

## 从项目目录加载单个剧本 (script.json + data/ 拆分文件, 兼容旧内联格式)
func _load_script_dir(dir_path: String) -> WorldScriptData:
	# 清理上次崩溃残留的 .tmp 临时文件 (Write-Ahead 恢复)
	_cleanup_residual_tmp(dir_path)
	var meta_path := dir_path + "/script.json"
	var file := FileAccess.open(meta_path, FileAccess.READ)
	if file == null:
		return null
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("ScriptDataManager: 无法解析 %s: %s" % [meta_path, json.get_error_message()])
		return null
	file.close()
	var d = json.data
	if not d is Dictionary or not d.has("id"):
		return null
	var ws := WorldScriptData.new()
	_apply_meta_to_ws(d, ws)
	ws.ensure_subsystems()
	# 子系统: 优先 data/ 拆分文件, 缺失时回退 script.json 内联数据(旧格式)
	for key in SUBSYSTEM_FILES:
		_load_subsystem_file(dir_path, key, d, ws.get(key))
	return ws

## 加载单个子系统: 优先 data/ 拆分文件, 回退 script.json 内联(旧格式)
func _load_subsystem_file(dir_path: String, key: String, inline_d: Dictionary, res: Resource) -> void:
	if res == null:
		return
	var fname: String = SUBSYSTEM_FILES[key]
	var split_path := dir_path + "/data/" + fname
	if FileAccess.file_exists(split_path):
		var f := FileAccess.open(split_path, FileAccess.READ)
		if f == null:
			return
		var j := JSON.new()
		if j.parse(f.get_as_text()) == OK and j.data is Dictionary:
			_dict_to_resource(j.data, res)
		f.close()
	elif inline_d.get(key) is Dictionary:
		_dict_to_resource(inline_d[key], res)

## 一次性迁移: 将 script.json 内联子系统数据的旧剧本拆分为 data/ 子文件
func _migrate_split() -> void:
	var ids: Array = user_scripts.keys()
	for script_id in ids:
		var ws: WorldScriptData = user_scripts[script_id]
		if not DirAccess.dir_exists_absolute(get_script_dir(script_id) + "/data"):
			save_script(ws)
			print("ScriptDataManager: 拆分旧剧本 %s → data/ 子文件" % ws.name)

## 保存时同步导出MUD数据表到剧本项目文件夹 ({id}/mud/)
## 兼容新内部格式(_schema_version=2)与旧导出格式; 无MUD数据时跳过
func _export_mud_files(ws: WorldScriptData) -> void:
	var mud_val: Variant = ws.metadata.get("mud_data", null)
	if not (mud_val is Dictionary) or (mud_val as Dictionary).is_empty():
		return
	var d: Dictionary = mud_val as Dictionary
	var mud: MudData
	if MudData.is_internal_format(d):
		mud = MudData.new()
		mud.from_dict(d)
	elif MudImport.is_export_format(d):
		mud = MudImport.from_dict(d)
	else:
		return
	var exporter := MudExport.new(mud)
	var count := exporter.write_all(get_script_dir(ws.id) + "/mud")
	print("ScriptDataManager: 已导出 %d 个MUD数据表 → %s/mud/" % [count, ws.id])

## 创建新剧本
func create_script(script_name: String, author: String = "旅者", template_id: String = "", extra_metadata: Dictionary = {}) -> WorldScriptData:
	var ws := WorldScriptData.new()
	ws.id = WorldScriptData.generate_id()
	ws.name = script_name
	ws.author = author
	ws.version = "1.0.0"
	ws.status = "draft"
	ws.created_at = Time.get_datetime_string_from_system()
	ws.updated_at = ws.created_at
	ws.ensure_subsystems()
	
	# 合并额外 metadata（编辑器模式、运行类型等）
	if not extra_metadata.is_empty():
		ws.metadata.merge(extra_metadata)
	
	# 如果指定了模板，应用模板数据
	if not template_id.is_empty():
		_apply_template(ws, template_id)
	
	save_script(ws)
	script_created.emit(ws.id)
	return ws

## 更新剧本
## dirty_keys: 仅需保存的子系统键列表（worldview/event_system/economy_system/ability_system）
## 非空时只写列出的子系统拆分文件 + 主文件；空则全量写入（向后兼容）
func update_script(script_data: WorldScriptData, dirty_keys: Array = []) -> void:
	script_data.updated_at = Time.get_datetime_string_from_system()
	save_script(script_data, dirty_keys)
	script_updated.emit(script_data.id)

## 删除剧本 (递归删除整个项目文件夹)
func delete_script(script_id: String) -> bool:
	var script_dir := get_script_dir(script_id)
	if DirAccess.dir_exists_absolute(script_dir):
		_remove_dir_recursive(script_dir)
	# 兼容旧单文件残留
	var legacy_file := SCRIPTS_PATH + script_id + ".json"
	if FileAccess.file_exists(legacy_file):
		DirAccess.remove_absolute(legacy_file)
	user_scripts.erase(script_id)
	script_deleted.emit(script_id)
	return true

## 递归删除目录及其全部内容
func _remove_dir_recursive(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry != "." and entry != "..":
			if dir.current_is_dir():
				_remove_dir_recursive(path.path_join(entry))
			else:
				dir.remove(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)

## 获取剧本
func find_script(script_id: String) -> WorldScriptData:
	return user_scripts.get(script_id, null) as WorldScriptData

## 导出剧本为JSON文件
func export_script(script_id: String, export_path: String) -> bool:
	var script_data := find_script(script_id)
	if script_data == null:
		return false
	var dict := _script_to_dict(script_data)
	var file := FileAccess.open(export_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(dict, "\t"))
	file.close()
	return true

## 从JSON文件导入剧本
func import_script(import_path: String) -> WorldScriptData:
	var file := FileAccess.open(import_path, FileAccess.READ)
	if file == null:
		return null
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return null
	file.close()
	
	var ws := _dict_to_script(json.data as Dictionary)
	if ws == null:
		return null
	
	# 生成新ID避免冲突
	ws.id = WorldScriptData.generate_id()
	ws.status = "draft"
	ws.created_at = Time.get_datetime_string_from_system()
	ws.updated_at = ws.created_at
	
	save_script(ws)
	script_imported.emit(ws.id)
	return ws

## === 模板系统 ===

## 获取可用剧本题材分支列表 (龙焰纪元等具体剧本名不属于题材分支)
func get_templates() -> Array[Dictionary]:
	var result: Array[Dictionary] = [
		{
			"id": "fantasy_adventure",
			"name": "奇幻冒险",
			"description": "剑与魔法的经典奇幻世界，包含势力博弈和探索元素",
			"tags": ["奇幻", "冒险", "中篇"]
		},
		{
			"id": "sci_fi_exploration",
			"name": "科幻探索",
			"description": "未来科技世界，星际探索与文明发现",
			"tags": ["科幻", "探索", "中篇"]
		},
		{
			"id": "historical_strategy",
			"name": "历史策略",
			"description": "基于历史背景的战争策略世界，注重外交与军事",
			"tags": ["历史", "策略", "长篇"]
		}
	]
	# 游戏类型模板（预置可运行骨架 + 蓝图图）
	var ScriptTemplatesClass = load("res://scripts/autoload/script_templates.gd")
	for t in ScriptTemplatesClass.get_template_defs():
		result.append(t)
	# 完整剧本模板（具体世界观的完整示例）
	result.append({
		"id": "dragonflame_era",
		"name": "龙焰纪元",
		"description": "艾泽兰大陆完整示例剧本：五时代、六势力、主线剧情与技能树",
		"tags": ["奇幻", "长篇", "示例"]
	})
	return result

## 应用模板到剧本
func _apply_template(ws: WorldScriptData, template_id: String) -> void:
	# 游戏类型模板优先（含完整骨架与蓝图图）
	var ScriptTemplatesClass = load("res://scripts/autoload/script_templates.gd")
	if ScriptTemplatesClass.apply_template(ws, template_id):
		return
	match template_id:
		"dragonflame_era":
			# 懒加载（32KB 静态数据, 仅使用该模板时加载, 避免拖慢启动）
			var DragonflameEraDataClass = load("res://scripts/autoload/dragonflame_era_data.gd")
			DragonflameEraDataClass.apply(ws)
		"fantasy_adventure":
			_apply_fantasy_template(ws)
		"sci_fi_exploration":
			_apply_scifi_template(ws)
		"historical_strategy":
			_apply_history_template(ws)

func _apply_fantasy_template(ws: WorldScriptData) -> void:
	ws.description = "一个剑与魔法并存的奇幻世界，冒险者在大陆上展开史诗般的旅程"
	ws.tags = Array(["奇幻", "冒险", "中篇"], TYPE_STRING, "", null)
	ws.estimated_hours = 10.0
	# 世界观
	ws.worldview.background_story = "在艾尔德拉大陆，魔法是万物运转的核心力量。三大势力——星辰议会、暗影教团和自由联盟——维持着脆弱的和平。古老的预言暗示，一场改变世界格局的风暴即将来临..."
	ws.worldview.add_era("创世纪元", 0, 500, "诸神创造世界的时代")
	ws.worldview.add_era("魔法觉醒纪元", 501, 1000, "魔法被凡人掌握的时代")
	ws.worldview.add_era("纷争纪元", 1001, 1500, "三大势力形成的动荡时代")
	ws.worldview.add_rule("magic", "魔法存在", "true", "魔法是世界核心力量")
	ws.worldview.add_rule("physics", "重力系数", "1.0", "标准重力")
	ws.worldview.add_faction("faction_council", "星辰议会", "掌控星辰魔法的古老组织", 85)
	ws.worldview.add_faction("faction_shadow", "暗影教团", "信奉暗影之力的神秘教团", 70)
	ws.worldview.add_faction("faction_alliance", "自由联盟", "由自由城邦组成的松散联盟", 60)
	# 事件
	ws.event_system.add_story_event("story_001", "星辰陨落之夜", "一颗星辰坠落在北部平原，三大势力争相夺取")
	ws.event_system.add_choice("story_001", "choice_a", "帮助星辰议会夺取碎片", [{"target": "faction_council", "effect": "relationship +20"}])
	ws.event_system.add_choice("story_001", "choice_b", "将碎片据为己有", [{"target": "player", "effect": "receive_starlight_shard"}])
	ws.event_system.add_choice("story_001", "choice_c", "摧毁碎片防止争夺", [{"target": "world", "effect": "trigger_magic_storm"}])
	# 经济
	ws.economy_system.add_currency("gold", "金币", "universal")
	ws.economy_system.add_resource("mana_crystal", "魔力水晶", "material")
	ws.economy_system.add_market("capital_market", "王都集市", "capital_city")
	ws.economy_system.add_market_good("capital_market", "mana_crystal", 100.0, 1.5)
	# 能力
	ws.ability_system.add_skill("fireball", "火球术", "active", "magic", "elemental_fire", "凝聚火元素发射爆炸火球")
	ws.ability_system.add_skill("ice_shard", "冰晶术", "active", "magic", "elemental_water", "凝聚冰元素发射穿透冰晶")
	ws.ability_system.add_growth_path("path_mage", "法师之路", "追求魔法极致的成长路线")
	ws.ability_system.add_growth_stage("path_mage", 1, "学徒", [1, 10], {"mana_pool": "+20%", "magic_damage": "+10%"})
	ws.ability_system.add_status_effect("burning", "燃烧", "dot")
	ws.ability_system.initialize_combat_defaults()

func _apply_scifi_template(ws: WorldScriptData) -> void:
	ws.description = "在遥远的未来，人类文明已扩展至银河系边缘，探索未知星系成为最重要的使命"
	ws.tags = Array(["科幻", "探索", "中篇"], TYPE_STRING, "", null)
	ws.estimated_hours = 10.0
	ws.worldview.background_story = "公元3200年，人类掌握了超光速航行技术。星际联邦已殖民了数百个星系，但银河系边缘仍然是未知的禁区。一支探险队发现了一个古老的 alien 遗迹，这将改变人类对宇宙的认知..."
	ws.worldview.add_era("地球时代", 0, 2200, "人类尚未离开太阳系")
	ws.worldview.add_era("星际扩张时代", 2201, 3000, "超光速航行发明，大规模殖民开始")
	ws.worldview.add_era("探索时代", 3001, 3500, "向银河系边缘进发")
	ws.worldview.add_rule("physics", "超光速航行", "true", "曲率引擎技术已成熟")
	ws.worldview.add_faction("faction_federation", "星际联邦", "人类最大的政治实体", 90)
	ws.worldview.add_faction("faction_corporation", "联合企业体", "控制星际贸易的巨型公司联盟", 75)
	ws.worldview.add_faction("faction_explorer", "探索者公会", "独立的星际探索组织", 50)
	ws.event_system.add_story_event("story_001", "神秘信号", "探险队在银河边缘接收到一段来历不明的信号")
	ws.economy_system.add_currency("credit", "星际信用点", "universal")
	ws.economy_system.add_resource("dark_matter", "暗物质", "material")
	ws.ability_system.add_skill("hack", "系统入侵", "active", "attack", "tech", "入侵敌方电子系统")
	ws.ability_system.add_skill("shield", "能量护盾", "active", "defense", "tech", "生成临时防护力场")
	ws.ability_system.initialize_combat_defaults()

func _apply_history_template(ws: WorldScriptData) -> void:
	ws.description = "公元1200年，大陆上群雄割据，你将建立自己的王国，通过外交或武力统一天下"
	ws.tags = Array(["历史", "策略", "长篇"], TYPE_STRING, "", null)
	ws.estimated_hours = 20.0
	ws.worldview.background_story = "这是一个类似中世纪欧洲的世界。老国王驾崩，王位空悬，五大贵族各怀心思。有人想通过联姻获取正统性，有人磨刀霍霍准备武力夺位，还有人暗中联络外族企图里应外合..."
	ws.worldview.add_era("统一王朝", 0, 1199, "持续数百年的大一统时代")
	ws.worldview.add_era("乱世", 1200, 1300, "老国王驾崩，群雄并起")
	ws.worldview.add_rule("social", "继承制度", "heredity", "王位世袭制")
	ws.worldview.add_faction("faction_north", "北境公国", "尚武的北方贵族", 80)
	ws.worldview.add_faction("faction_south", "南方王国", "富庶的南方商人联盟", 70)
	ws.worldview.add_faction("faction_church", "圣光教会", "拥有广泛信众的宗教势力", 65)
	ws.event_system.add_story_event("story_001", "老王驾崩", "统治大陆数百年的老国王去世，各方势力开始行动")
	ws.economy_system.add_currency("gold", "金币", "universal")
	ws.economy_system.add_resource("iron", "铁矿", "material")
	ws.economy_system.add_resource("grain", "粮食", "consumable")
	ws.ability_system.add_skill("rally", "鼓舞士气", "active", "support", "command", "提升部队战斗力")
	ws.ability_system.add_skill("negotiate", "外交斡旋", "active", "support", "diplomacy", "改善与其他势力的关系")
	ws.ability_system.initialize_combat_defaults()

## === 序列化方法 ===

## 剧本元信息字典 (顶层字段, 不含子系统) - 用于 script.json 拆分保存
func _script_to_meta_dict(ws: WorldScriptData) -> Dictionary:
	return {
		"id": ws.id,
		"name": ws.name,
		"version": ws.version,
		"author": ws.author,
		"description": ws.description,
		"tags": ws.tags,
		"thumbnail_path": ws.thumbnail_path,
		"status": ws.status,
		"created_at": ws.created_at,
		"updated_at": ws.updated_at,
		"progress": ws.progress,
		"ai_generated": ws.ai_generated,
		"rating": ws.rating,
		"play_count": ws.play_count,
		"estimated_hours": ws.estimated_hours,
		"metadata": ws.metadata
	}

## 完整剧本字典 (元信息+内联子系统) - 用于单文件导出
func _script_to_dict(ws: WorldScriptData) -> Dictionary:
	var d := _script_to_meta_dict(ws)
	# 序列化子系统
	if ws.worldview:
		d["worldview"] = _resource_to_dict(ws.worldview)
	if ws.event_system:
		d["event_system"] = _resource_to_dict(ws.event_system)
	if ws.economy_system:
		d["economy_system"] = _resource_to_dict(ws.economy_system)
	if ws.ability_system:
		d["ability_system"] = _resource_to_dict(ws.ability_system)
	if ws.quest_system:
		d["quest_system"] = _resource_to_dict(ws.quest_system)
	if ws.combat_system:
		d["combat_system"] = _resource_to_dict(ws.combat_system)
	return d

## 从字典还原顶层元信息字段
func _apply_meta_to_ws(d: Dictionary, ws: WorldScriptData) -> void:
	ws.id = d.get("id", "")
	ws.name = d.get("name", "")
	ws.version = d.get("version", "1.0.0")
	ws.author = d.get("author", "")
	ws.description = d.get("description", "")
	ws.tags = Array(d.get("tags", []), TYPE_STRING, "", null)
	ws.thumbnail_path = d.get("thumbnail_path", "")
	ws.status = d.get("status", "draft")
	ws.created_at = d.get("created_at", "")
	ws.updated_at = d.get("updated_at", "")
	ws.progress = d.get("progress", 0.0)
	ws.ai_generated = d.get("ai_generated", false)
	ws.rating = d.get("rating", 0.0)
	ws.play_count = d.get("play_count", 0)
	ws.estimated_hours = d.get("estimated_hours", 0.0)
	ws.metadata = d.get("metadata", {})

## 完整字典 -> 剧本 (内联子系统, 用于导入/旧单文件)
func _dict_to_script(d: Dictionary) -> WorldScriptData:
	if not d is Dictionary or not d.has("id"):
		return null
	var ws := WorldScriptData.new()
	_apply_meta_to_ws(d, ws)
	# 反序列化子系统（从JSON无损还原）
	ws.ensure_subsystems()
	if d.get("worldview") is Dictionary:
		_dict_to_resource(d["worldview"], ws.worldview)
	if d.get("event_system") is Dictionary:
		_dict_to_resource(d["event_system"], ws.event_system)
	if d.get("economy_system") is Dictionary:
		_dict_to_resource(d["economy_system"], ws.economy_system)
	if d.get("ability_system") is Dictionary:
		_dict_to_resource(d["ability_system"], ws.ability_system)
	if d.get("quest_system") is Dictionary:
		_dict_to_resource(d["quest_system"], ws.quest_system)
	if d.get("combat_system") is Dictionary:
		_dict_to_resource(d["combat_system"], ws.combat_system)
	return ws

func _resource_to_dict(res: Resource) -> Dictionary:
	var d := {}
	for prop in res.get_property_list():
		if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			d[prop.name] = res.get(prop.name)
	return d

## 泛型资源反序列化: 从字典还原属性值 (与 _resource_to_dict 互逆)
func _dict_to_resource(d: Dictionary, res: Resource) -> void:
	for prop in res.get_property_list():
		if not (prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		if not d.has(prop.name):
			continue
		var value = d[prop.name]
		# JSON解析产生的是无类型Array, 类型化数组属性需显式转换
		if prop.type == TYPE_ARRAY and value is Array:
			value = _to_typed_array(value, prop.hint_string)
		res.set(prop.name, value)

## 根据属性hint将无类型Array转为对应的类型化Array
## 类型化数组属性的 hint_string 格式为 "<元素类型号>:<类名>", 如 "27:" = Array[Dictionary], "4:" = Array[String]
func _to_typed_array(arr: Array, hint_string: String) -> Array:
	if not hint_string.contains(":"):
		return arr
	var elem_type := hint_string.get_slice(":", 0).to_int()
	var cls_name := hint_string.get_slice(":", 1)
	if elem_type == TYPE_NIL or elem_type == TYPE_OBJECT:
		return arr
	return Array(arr, elem_type, cls_name, null)
