## 剧本校验器
## 检查剧本的完整性和一致性
class_name ScriptValidator
extends RefCounted

## 校验结果
var errors: Array[String] = []
var warnings: Array[String] = []
var suggestions: Array[String] = []

## 执行完整校验
func validate(script_data: WorldScriptData) -> Dictionary:
	errors.clear()
	warnings.clear()
	suggestions.clear()
	
	if script_data == null:
		errors.append("剧本数据为空")
		return get_report()
	
	_validate_metadata(script_data)
	_validate_worldview(script_data.worldview)
	_validate_events(script_data.event_system)
	_validate_economy(script_data.economy_system)
	_validate_abilities(script_data.ability_system)
	
	return get_report()

## 获取校验报告
func get_report() -> Dictionary:
	return {
		"is_valid": errors.is_empty(),
		"error_count": errors.size(),
		"warning_count": warnings.size(),
		"suggestion_count": suggestions.size(),
		"errors": errors.duplicate(),
		"warnings": warnings.duplicate(),
		"suggestions": suggestions.duplicate()
	}

## 校验元数据
func _validate_metadata(ws: WorldScriptData) -> void:
	if ws.name.is_empty():
		errors.append("剧本名称不能为空")
	if ws.description.is_empty():
		warnings.append("剧本缺少简介描述")
	if ws.tags.is_empty():
		warnings.append("剧本没有设置标签，建议添加以便搜索")

## 校验世界观
func _validate_worldview(wv: WorldviewData) -> void:
	if wv == null:
		warnings.append("世界观数据为空")
		return
	if wv.background_story.is_empty():
		warnings.append("背景故事为空")
	if wv.era_definitions.is_empty():
		suggestions.append("建议添加至少一个时代定义来丰富世界观")
	if wv.factions.is_empty():
		suggestions.append("建议添加至少一个势力来丰富世界")
	# 检查势力引用
	for rel in wv.faction_relationships:
		var from_id: String = rel.get("from_id", "")
		var to_id: String = rel.get("to_id", "")
		var found_from := false
		var found_to := false
		for f in wv.factions:
			if f["id"] == from_id: found_from = true
			if f["id"] == to_id: found_to = true
		if not found_from:
			errors.append("势力关系引用了不存在的势力: %s" % from_id)
		if not found_to:
			errors.append("势力关系引用了不存在的势力: %s" % to_id)

## 校验事件系统
func _validate_events(es: EventSystemData) -> void:
	if es == null:
		warnings.append("事件系统数据为空")
		return
	# 检查事件链引用
	for e in es.story_events:
		var prereq: String = e.get("prerequisite", "")
		if not prereq.is_empty():
			var found := false
			for other in es.story_events:
				if other["id"] == prereq:
					found = true
					break
			if not found:
				errors.append("事件 '%s' 的前置事件 '%s' 不存在" % [e.get("id", ""), prereq])
		# 检查选择
		if e.get("choices", []).is_empty():
			warnings.append("事件 '%s' 没有玩家选择" % e.get("id", ""))
		# 检查分支指向
		for branch in e.get("branches", []):
			var next_id: String = branch.get("next_event", "")
			if not next_id.is_empty():
				var found := false
				for other in es.story_events:
					if other["id"] == next_id:
						found = true
						break
				if not found:
					warnings.append("事件 '%s' 的分支指向不存在的事件 '%s'" % [e.get("id", ""), next_id])
	# 检查死循环（简单检测）
	for e in es.story_events:
		var visited := {}
		if _has_cycle(e["id"], es, visited):
			errors.append("检测到事件循环: %s" % e["id"])
	if es.story_events.is_empty():
		suggestions.append("建议添加至少一个剧情事件")

## 检测事件循环
func _has_cycle(event_id: String, es: EventSystemData, visited: Dictionary) -> bool:
	if visited.has(event_id):
		return true
	visited[event_id] = true
	var e := es.get_story_event(event_id)
	for branch in e.get("branches", []):
		var next_id: String = branch.get("next_event", "")
		if not next_id.is_empty() and _has_cycle(next_id, es, visited.duplicate()):
			return true
	return false

## 校验经济系统
func _validate_economy(es: EconomySystemData) -> void:
	if es == null:
		suggestions.append("经济系统为空，将使用默认值")
		return
	if es.currencies.is_empty():
		suggestions.append("建议定义至少一种货币")
	if es.resources.is_empty():
		suggestions.append("建议定义至少一种资源")
	# 检查市场商品引用
	for m in es.markets:
		for g in m.get("goods", []):
			var item_id: String = g.get("item", "")
			var found := false
			for r in es.resources:
				if r["id"] == item_id:
					found = true
					break
			for c in es.currencies:
				if c["id"] == item_id:
					found = true
					break
			if not found and not item_id.is_empty():
				warnings.append("市场 '%s' 中的商品 '%s' 未在资源或货币中定义" % [m.get("name", ""), item_id])

## 校验能力系统
func _validate_abilities(as_data: AbilitySystemData) -> void:
	if as_data == null:
		suggestions.append("能力系统为空，将使用默认值")
		return
	# 检查技能前置引用
	for s in as_data.skills:
		for prereq in s.get("requirements", {}).get("prerequisites", []):
			var found := false
			for other in as_data.skills:
				if other["id"] == prereq:
					found = true
					break
			if not found:
				warnings.append("技能 '%s' 的前置技能 '%s' 未定义" % [s.get("name", ""), prereq])
	# 检查成长路线解锁的技能
	for p in as_data.growth_paths:
		for stage in p.get("stages", []):
			for skill_id in stage.get("skill_unlocks", []):
				var found := false
				for s in as_data.skills:
					if s["id"] == skill_id:
						found = true
						break
				if not found:
					warnings.append("成长路线 '%s' 解锁了未定义的技能 '%s'" % [p.get("name", ""), skill_id])
	if as_data.combat_definition.is_empty():
		suggestions.append("建议初始化战斗机制（使用默认值或自定义）")
