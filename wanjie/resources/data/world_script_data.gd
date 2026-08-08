## 世界剧本数据模型
## 对应GDD §3.1 剧本总体结构
class_name WorldScriptData
extends Resource

## 唯一标识符
@export var id: String = ""
## 剧本名称
@export var name: String = ""
## 版本号
@export var version: String = "1.0.0"
## 作者
@export var author: String = ""
## 简介
@export var description: String = ""
## 标签
@export var tags: Array[String] = []
## 缩略图路径
@export var thumbnail_path: String = ""
## 剧本状态: draft/testing/published/archived
@export var status: String = "draft"
## 创建时间
@export var created_at: String = ""
## 更新时间
@export var updated_at: String = ""
## 玩家体验进度 (0.0 - 1.0)
@export var progress: float = 0.0
## 是否为AI生成
@export var ai_generated: bool = false
## 评分 (0.0 - 10.0)
@export var rating: float = 0.0
## 评分人数（本地平均用）
@export var rating_count: int = 0
## 体验次数
@export var play_count: int = 0
## 预计游玩时长（小时）
@export var estimated_hours: float = 0.0
## 剧本元数据（AI模型、表现形式等扩展配置）
@export var metadata: Dictionary = {}

## === 四大子系统数据 ===
## 世界观设定（§3.2）
@export var worldview: WorldviewData = null
## 事件系统（§3.3）
@export var event_system: EventSystemData = null
## 经济系统（§3.4）
@export var economy_system: EconomySystemData = null
## 能力系统（§3.5）
@export var ability_system: AbilitySystemData = null
## 任务系统（蓝图节点体系扩展）
@export var quest_system: Resource = null
## 战斗/NPC系统（蓝图节点体系扩展）
@export var combat_system: Resource = null

## 初始化子系统（如果为空则创建默认值）
func ensure_subsystems() -> void:
	if worldview == null:
		worldview = WorldviewData.new()
	if event_system == null:
		event_system = EventSystemData.new()
	if economy_system == null:
		economy_system = EconomySystemData.new()
	if ability_system == null:
		ability_system = AbilitySystemData.new()
	if quest_system == null:
		var QuestData = preload("res://resources/data/quest_data.gd")
		quest_system = QuestData.new()
	if combat_system == null:
		var CombatData = preload("res://resources/data/combat_data.gd")
		combat_system = CombatData.new()

## 生成唯一ID
static func generate_id() -> String:
	return "ws_" + str(int(Time.get_unix_time_from_system())) + "_" + str(randi() % 10000)

## 获取格式化标签文本
func get_tags_display() -> String:
	return ", ".join(tags)

## 获取状态显示文本
func get_status_display() -> String:
	match status:
		"draft": return "草稿"
		"testing": return "测试中"
		"published": return "已发布"
		"archived": return "已归档"
		_: return status
