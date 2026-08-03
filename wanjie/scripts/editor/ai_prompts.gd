## AI提示词模板库
## 为各AI辅助功能提供结构化Prompt，确保LLM输出符合游戏数据Schema
class_name AIPrompts
extends RefCounted

## === 系统角色定义 ===
const SYSTEM_BASE := """你是「万界诗篇」剧本编辑器的AI创作助手。
你帮助剧本创作者设计游戏世界观、剧情事件、经济系统和能力系统。
你的输出必须结构化为JSON格式，符合游戏引擎的数据Schema。
核心原则：AI增强创造力而非替代，最终决策权属于创作者。"""

## === 8.1.1 世界观生成 ===
const WORLDVIEW_SYSTEM := SYSTEM_BASE + """
你的任务是根据用户描述生成完整的世界观设定。
输出JSON结构：
{
  "era": "时代名称",
  "timeline": ["关键历史事件1", "关键历史事件2", ...],
  "factions": [{"name": "势力名", "trait": "核心特征", "government": "政体", "economy": "经济特色"}],
  "rules": "世界核心规则(魔法/科技/物理法则)",
  "geography": {"regions": [{"name": "地区名", "climate": "气候", "resources": "主要资源"}]},
  "conflicts": ["核心矛盾1", "核心矛盾2"],
  "tone": "整体基调(黑暗/明亮/灰色道德等)"
}"""

static func worldview_user_prompt(keywords: String, style: String, extra: String) -> String:
	var prompt := "请根据以下描述生成世界观设定：\n\n关键词/主题：%s\n" % keywords
	if style != "":
		prompt += "风格偏好：%s\n" % style
	if extra != "":
		prompt += "补充要求：%s\n" % extra
	prompt += "\n请生成完整的世界观JSON。"
	return prompt

## === 8.1.2 事件设计辅助 ===
const EVENT_SYSTEM := SYSTEM_BASE + """
你的任务是辅助设计剧情事件。
输出JSON结构：
{
  "name": "事件名称",
  "trigger_type": "chain|condition|random|manual",
  "description": "事件描述(2-3句话)",
  "conditions": [{"subject": "player|world|faction|time", "field": "字段名", "operator": ">=|<=|==|!=", "value": "值"}],
  "choices": [
    {"text": "选项文本", "consequence": "后果描述", "effects": [{"type": "modify_stat|give_item|trigger_event|change_relation", "target": "目标", "value": "效果值"}]}
  ],
  "prerequisite": "前置事件ID(可选)",
  "tags": ["标签1", "标签2"]
}"""

static func event_user_prompt(theme: String, context_info: String, mode: String) -> String:
	var prompt := ""
	match mode:
		"single":
			prompt = "请设计一个关于「%s」的剧情事件。\n" % theme
		"chain":
			prompt = "请设计一个关于「%s」的事件链(包含3-5个因果关联的事件)。\n输出为事件数组。\n" % theme
		"pool":
			prompt = "请为「%s」场景补充3个随机遭遇事件。\n" % theme
		"condition":
			prompt = "请为以下事件建议合理的触发条件和后果：\n%s\n" % theme
	if context_info != "":
		prompt += "\n当前剧本上下文：\n%s\n" % context_info
	prompt += "\n请输出符合Schema的JSON。"
	return prompt

## === 8.1.3 经济平衡分析 ===
const ECONOMY_SYSTEM := SYSTEM_BASE + """
你的任务是分析游戏经济系统的平衡性。
分析维度：通胀风险、资源枯竭、收支失衡、套利路径、难度匹配。
输出格式：
{
  "overall_score": 0-100,
  "issues": [{"severity": "high|medium|low", "category": "问题类别", "description": "问题描述", "suggestion": "调整建议"}],
  "summary": "总体评价(2-3句话)"
}"""

static func economy_user_prompt(economy_json: String) -> String:
	return "请分析以下经济系统配置的平衡性：\n\n%s\n\n请输出分析报告JSON。" % economy_json

## === 8.1.4 能力系统生成 ===
const ABILITY_SYSTEM := SYSTEM_BASE + """
你的任务是根据世界观规则生成技能/能力系统。
输出JSON结构：
{
  "schools": [
    {"name": "学派名", "theme": "主题", "skills": [
      {"name": "技能名", "description": "效果描述", "tier": 1-3, "cost": "消耗", "cooldown": "冷却", "prerequisites": ["前置技能"]}
    ]}
  ],
  "growth_paths": [{"name": "成长路线名", "school": "所属学派", "description": "路线特色"}]
}"""

static func ability_user_prompt(world_rules: String, combat_config: String) -> String:
	var prompt := "请根据以下世界规则生成能力系统：\n\n世界规则：%s\n" % world_rules
	if combat_config != "":
		prompt += "战斗系统配置：%s\n" % combat_config
	prompt += "\n请生成2-4个学派，每个学派3-5个技能。"
	return prompt

## === 通用对话 ===
static func general_user_prompt(question: String, context_info: String) -> String:
	var prompt := question
	if context_info != "":
		prompt += "\n\n当前剧本上下文：\n%s" % context_info
	return prompt

## === 任务系统 ===
const QUEST_SYSTEM := SYSTEM_BASE + """
你擅长设计游戏任务系统。请基于当前剧本生成任务（main/side/daily/hidden）与任务链。
只输出JSON。"""

static func quest_user_prompt(quest_json: String) -> String:
	var prompt := "请根据当前剧本设计任务系统：\n\n现有任务数据：%s\n" % quest_json
	prompt += "\n请生成2-4个任务（含目标、奖励、前置）和1-2条任务链。"
	return prompt

## === 战斗/NPC ===
const COMBAT_SYSTEM := SYSTEM_BASE + """
你擅长设计游戏战斗与NPC体系。请基于当前剧本生成敌人模板、NPC池与战斗配置。
只输出JSON。"""

static func combat_user_prompt(worldview_json: String) -> String:
	var prompt := "请根据当前剧本设计战斗系统：\n\n世界观：%s\n" % worldview_json
	prompt += "\n请生成2-4个敌人模板、2-3个NPC、1-2个预设战斗。"
	return prompt

## === 事件链 ===
const CHAIN_SYSTEM := SYSTEM_BASE + """
你擅长编排剧情事件链。请基于当前事件设计有因果关联的事件链。
只输出JSON。"""

static func chain_user_prompt(event_json: String) -> String:
	var prompt := "请根据当前事件编排事件链：\n\n现有事件：%s\n" % event_json
	prompt += "\n请生成1-2条事件链（每条含3-5个事件ID的有序串联），并说明因果关系。"
	return prompt

## === 上下文构建辅助 ===

## 从WorldScriptData构建精简上下文(注入Prompt用)
static func build_script_context(ws) -> String:
	if ws == null:
		return ""
	var parts: PackedStringArray = []
	# 世界观摘要
	if ws.worldview:
		parts.append("【世界观】%s" % ws.worldview.background_story)
		if ws.worldview.factions.size() > 0:
			var faction_names: PackedStringArray = []
			for f in ws.worldview.factions:
				faction_names.append(f.get("name", f.get("id", "")))
			parts.append("势力：%s" % ", ".join(faction_names))
	# 事件摘要
	if ws.event_system:
		parts.append("【事件】剧情事件%d个, 随机事件%d个, 事件链%d个" % [
			ws.event_system.story_events.size(),
			ws.event_system.random_events.size(),
			ws.event_system.event_chains.size(),
		])
	# 经济摘要
	if ws.economy_system:
		parts.append("【经济】资源%d种, 货币%d种, 市场%d个" % [
			ws.economy_system.resources.size(),
			ws.economy_system.currencies.size(),
			ws.economy_system.markets.size(),
		])
	# 能力摘要
	if ws.ability_system:
		parts.append("【能力】技能%d个, 状态效果%d个" % [
			ws.ability_system.skills.size(),
			ws.ability_system.status_effects.size(),
		])
	return "\n".join(parts)
