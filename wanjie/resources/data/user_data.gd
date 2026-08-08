## 用户数据模型
## 对应GDD §2.3 核心资源模型
class_name UserData
extends Resource

## 玩家名称
@export var player_name: String = "旅者"
## 首次启动标记（用于欢迎引导）
@export var first_launch: bool = true
## 编辑器首次访问标记（首启引导）
@export var editor_visited: bool = false
## 诗墨（软货币）
@export var shimo: int = 1250
## 界石（硬货币）
@export var jieshi: int = 50
## 灵感点（体力值，最大值10）
@export var inspiration: int = 10
## 灵感点上限
@export var inspiration_max: int = 10
## 创作精力（最大值5）
@export var creation_energy: int = 5
## 创作精力上限
@export var creation_energy_max: int = 5
## 最近游玩的剧本ID列表（按时间倒序，最多10个）
@export var recent_script_ids: Array[String] = []
## 已体验剧本ID列表
@export var played_script_ids: Array[String] = []
## 已创建剧本ID列表
@export var created_script_ids: Array[String] = []
## 收藏的剧本 id（市场/社区雏形）
@export var favorites_script_ids: Array[String] = []
## 成就列表
@export var achievements: Array[String] = []
## 设置：AI功能是否开启
@export var ai_enabled: bool = true
## 设置：AI NPC 对话是否开启（酒馆）
@export var ai_npc_enabled: bool = true
## 设置：难度模式 (adaptive/fixed_easy/fixed_normal/fixed_hard)
@export var difficulty_mode: String = "adaptive"
## 设置：动效是否开启
@export var animations_enabled: bool = true
## 全屏显示
@export var fullscreen: bool = false
## 设置：字体大小 (small/medium/large/xlarge)
@export var font_size_preset: String = "medium"
## 上次资源恢复时间戳（unix 秒, 用于离线恢复灵感/精力）
@export var last_recovery_time: int = 0

## 序列化为字典
func to_dict() -> Dictionary:
	return {
		"player_name": player_name,
		"first_launch": first_launch,
		"editor_visited": editor_visited,
		"shimo": shimo,
		"jieshi": jieshi,
		"inspiration": inspiration,
		"inspiration_max": inspiration_max,
		"creation_energy": creation_energy,
		"creation_energy_max": creation_energy_max,
		"recent_script_ids": recent_script_ids,
		"played_script_ids": played_script_ids,
		"created_script_ids": created_script_ids,
		"favorites_script_ids": favorites_script_ids,
		"achievements": achievements,
		"ai_enabled": ai_enabled,
		"ai_npc_enabled": ai_npc_enabled,
		"difficulty_mode": difficulty_mode,
		"animations_enabled": animations_enabled,
		"fullscreen": fullscreen,
		"font_size_preset": font_size_preset,
		"last_recovery_time": last_recovery_time,
	}

## 从字典还原（字段缺失时使用默认值, 兼容旧存档）
static func from_dict(d: Dictionary) -> UserData:
	var u := UserData.new()
	u.player_name = str(d.get("player_name", u.player_name))
	u.shimo = int(d.get("shimo", u.shimo))
	u.jieshi = int(d.get("jieshi", u.jieshi))
	u.inspiration = int(d.get("inspiration", u.inspiration))
	u.inspiration_max = int(d.get("inspiration_max", u.inspiration_max))
	u.creation_energy = int(d.get("creation_energy", u.creation_energy))
	u.creation_energy_max = int(d.get("creation_energy_max", u.creation_energy_max))
	u.recent_script_ids = _to_string_array(d.get("recent_script_ids", []))
	u.played_script_ids = _to_string_array(d.get("played_script_ids", []))
	u.created_script_ids = _to_string_array(d.get("created_script_ids", []))
	u.favorites_script_ids = _to_string_array(d.get("favorites_script_ids", []))
	u.achievements = _to_string_array(d.get("achievements", []))
	u.ai_enabled = bool(d.get("ai_enabled", u.ai_enabled))
	u.ai_npc_enabled = bool(d.get("ai_npc_enabled", u.ai_npc_enabled))
	u.difficulty_mode = str(d.get("difficulty_mode", u.difficulty_mode))
	u.animations_enabled = bool(d.get("animations_enabled", u.animations_enabled))
	u.font_size_preset = str(d.get("font_size_preset", u.font_size_preset))
	u.last_recovery_time = int(d.get("last_recovery_time", 0))
	return u

## 转字符串数组（容错: JSON 解析后可能是 Array[Variant]）
static func _to_string_array(v) -> Array[String]:
	var result: Array[String] = []
	if v is Array:
		for item in v:
			result.append(str(item))
	return result

## 获取灵感点显示文本
func get_inspiration_display() -> String:
	return "%d/%d" % [inspiration, inspiration_max]

## 获取创作精力显示文本
func get_creation_energy_display() -> String:
	return "%d/%d" % [creation_energy, creation_energy_max]

## 检查是否有足够灵感点
func can_enter_script() -> bool:
	return inspiration > 0

## 消耗灵感点
func consume_inspiration(amount: int = 1) -> bool:
	if inspiration >= amount:
		inspiration -= amount
		return true
	return false

## 检查是否有足够创作精力
func can_create_script() -> bool:
	return creation_energy > 0

## 消耗创作精力
func consume_creation_energy(amount: int = 1) -> bool:
	if creation_energy >= amount:
		creation_energy -= amount
		return true
	return false
