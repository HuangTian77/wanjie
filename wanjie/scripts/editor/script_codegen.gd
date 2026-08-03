## 剧本代码生成器/解析器 - GDScript 风格格式
## 将 WorldScriptData 序列化为 GDScript 风格代码，并支持反向解析
class_name ScriptCodeGen
extends RefCounted

## 将世界数据序列化为 GDScript 风格代码文本
static func generate(ws: WorldScriptData) -> String:
	var lines: PackedStringArray = []
	lines.append("# script \"%s\"" % ws.name)
	lines.append("# author \"%s\"" % ws.author)
	lines.append("# version \"%s\"" % ws.version)
	if not ws.description.is_empty():
		lines.append("# description \"%s\"" % ws.description.replace("\n", "\\n"))
	if not ws.tags.is_empty():
		lines.append("# tags \"%s\"" % ",".join(ws.tags))
	lines.append("")

	# === 世界观 ===
	if ws.worldview:
		lines.append("# === 世界观 ===")
		var wv := ws.worldview
		if not wv.background_story.is_empty():
			lines.append("worldview.background_story = \"%s\"" % _esc(wv.background_story))
		for era in wv.era_definitions:
			var sn: String = str(era.get("era_name", ""))
			var sy = era.get("start_year", 0)
			var ey = era.get("end_year", 0)
			lines.append("worldview.era(\"%s\", %s, %s)" % [sn, str(sy), str(ey)])
			var ed: String = str(era.get("description", ""))
			if not ed.is_empty():
				lines.append("worldview.era_description(\"%s\", \"%s\")" % [sn, _esc(ed)])
		for tl in wv.timeline:
			lines.append("worldview.timeline(%s, \"%s\", \"%s\")" % [str(tl.get("year", 0)), _esc(str(tl.get("event", ""))), _esc(str(tl.get("impact", "")))])
		for rule in wv.world_rules:
			lines.append("worldview.rule(\"%s\", \"%s\", \"%s\")" % [_esc(str(rule.get("category", ""))), _esc(str(rule.get("key", ""))), _esc(str(rule.get("value", "")))])
			var rd: String = str(rule.get("description", ""))
			if not rd.is_empty():
				lines.append("worldview.rule_description(\"%s\", \"%s\")" % [_esc(str(rule.get("key", ""))), _esc(rd)])
		for fac in wv.factions:
			var fid: String = str(fac.get("id", ""))
			var fn: String = str(fac.get("name", ""))
			lines.append("worldview.faction(\"%s\", \"%s\")" % [fid, fn])
			lines.append("worldview.faction_power(\"%s\", %s)" % [fid, str(fac.get("power_level", 50))])
			var gd: String = str(fac.get("governance_type", ""))
			if not gd.is_empty():
				lines.append("worldview.faction_governance(\"%s\", \"%s\")" % [fid, gd])
			var fd: String = str(fac.get("description", ""))
			if not fd.is_empty():
				lines.append("worldview.faction_description(\"%s\", \"%s\")" % [fid, _esc(fd)])
		for rel in wv.faction_relationships:
			lines.append("worldview.relation(\"%s\", \"%s\", \"%s\", %s)" % [str(rel.get("from_id", "")), str(rel.get("to_id", "")), str(rel.get("type", "neutral")), str(rel.get("intensity", 0.5))])
		var regions: Array = wv.geography.get("regions", [])
		for reg in regions:
			lines.append("worldview.region(\"%s\", \"%s\")" % [str(reg.get("id", "")), _esc(str(reg.get("name", "")))])
			var rd2: String = str(reg.get("description", ""))
			if not rd2.is_empty():
				lines.append("worldview.region_description(\"%s\", \"%s\")" % [str(reg.get("id", "")), _esc(rd2)])
			var cl: String = str(reg.get("climate", ""))
			if not cl.is_empty():
				lines.append("worldview.region_climate(\"%s\", \"%s\")" % [str(reg.get("id", "")), cl])
		for lore in wv.lore_entries:
			lines.append("worldview.lore(\"%s\", \"%s\")" % [str(lore.get("id", "")), _esc(str(lore.get("title", "")))])
			var lc: String = str(lore.get("content", ""))
			if not lc.is_empty():
				lines.append("worldview.lore_content(\"%s\", \"%s\")" % [str(lore.get("id", "")), _esc(lc)])
			var ld: String = str(lore.get("discovery_condition", ""))
			if not ld.is_empty():
				lines.append("worldview.lore_condition(\"%s\", \"%s\")" % [str(lore.get("id", "")), _esc(ld)])
		lines.append("")

	# === 事件系统 ===
	if ws.event_system:
		lines.append("# === 事件系统 ===")
		var es := ws.event_system
		for se in es.story_events:
			var eid: String = str(se.get("id", ""))
			var ename: String = str(se.get("name", ""))
			lines.append("func story_event(\"%s\"):" % eid)
			lines.append("\tname = \"%s\"" % _esc(ename))
			var st: String = str(se.get("trigger_type", "chain"))
			lines.append("\ttrigger = \"%s\"" % st)
			var sd: String = str(se.get("description", ""))
			if not sd.is_empty():
				lines.append("\tdescription = \"%s\"" % _esc(sd))
			var sp: String = str(se.get("prerequisite", ""))
			if not sp.is_empty():
				lines.append("\tprerequisite = \"%s\"" % sp)
			for cond in se.get("conditions", []):
				lines.append("\tcondition(\"%s\", \"%s\")" % [str(cond.get("type", "")), str(cond.get("check", ""))])
			for ch in se.get("choices", []):
				lines.append("\tchoice(\"%s\")" % _esc(str(ch.get("text", ""))))
				for conseq in ch.get("consequences", []):
					lines.append("\t\tconsequence(\"%s\", \"%s\")" % [str(conseq.get("target", "")), str(conseq.get("effect", ""))])
			for br in se.get("branches", []):
				lines.append("\tbranch(\"%s\", \"%s\")" % [str(br.get("condition", "")), str(br.get("next_event", ""))])
			lines.append("")
		for re in es.random_events:
			lines.append("func random_event(\"%s\"):" % str(re.get("id", "")))
			lines.append("\tname = \"%s\"" % _esc(str(re.get("name", ""))))
			lines.append("\tprobability = %s" % str(re.get("probability", 0.1)))
			lines.append("\tcooldown = \"%s\"" % str(re.get("cooldown", "3d")))
			lines.append("")
		for ch2 in es.event_chains:
			lines.append("func event_chain(\"%s\"):" % str(ch2.get("id", "")))
			lines.append("\tname = \"%s\"" % _esc(str(ch2.get("name", ""))))
			lines.append("\tstart = \"%s\"" % str(ch2.get("start_event", "")))
			var cd: String = str(ch2.get("description", ""))
			if not cd.is_empty():
				lines.append("\tdescription = \"%s\"" % _esc(cd))
			lines.append("")

	# === 能力系统 ===
	if ws.ability_system:
		lines.append("# === 能力系统 ===")
		var ab := ws.ability_system
		for sk in ab.skills:
			lines.append("func skill(\"%s\", \"%s\", \"%s\"):" % [str(sk.get("id", "")), _esc(str(sk.get("name", ""))), str(sk.get("category", "active"))])
			var sc: String = str(sk.get("school", ""))
			if not sc.is_empty():
				lines.append("\tschool = \"%s\"" % sc)
			var sdesc: String = str(sk.get("description", ""))
			if not sdesc.is_empty():
				lines.append("\tdescription = \"%s\"" % _esc(sdesc))
			var cost: Dictionary = sk.get("cost", {})
			lines.append("\tcost_mana = %s" % str(cost.get("mana", 0)))
			lines.append("\tcost_cooldown = \"%s\"" % str(cost.get("cooldown", "0s")))
			var effect: Dictionary = sk.get("effect", {})
			if not effect.is_empty():
				lines.append("\teffect_type = \"%s\"" % str(effect.get("type", "")))
				lines.append("\teffect_value = %s" % str(effect.get("base_value", 0)))
			lines.append("")
		for gp in ab.growth_paths:
			lines.append("func growth_path(\"%s\", \"%s\"):" % [str(gp.get("id", "")), _esc(str(gp.get("name", "")))])
			var gpd: String = str(gp.get("description", ""))
			if not gpd.is_empty():
				lines.append("\tdescription = \"%s\"" % _esc(gpd))
			lines.append("")
		for fx in ab.status_effects:
			lines.append("func status_effect(\"%s\", \"%s\", \"%s\"):" % [str(fx.get("id", "")), _esc(str(fx.get("name", ""))), str(fx.get("type", "buff"))])
			lines.append("\tduration = \"%s\"" % str(fx.get("duration", "5s")))
			lines.append("\tdamage_per_tick = %s" % str(fx.get("damage_per_tick", 0)))
			lines.append("")
		if not ab.combat_definition.is_empty():
			lines.append("func combat_config():")
			lines.append("\ttype = \"%s\"" % str(ab.combat_definition.get("type", "")))
			lines.append("\tcritical_rate = %s" % str(ab.combat_definition.get("critical_rate", 0.05)))
			lines.append("\tcritical_damage = %s" % str(ab.combat_definition.get("critical_damage", 1.5)))
			lines.append("")
		if not ab.element_matrix.is_empty():
			lines.append("# 元素相克表")
			for elem in ab.element_matrix:
				for target in ab.element_matrix[elem]:
					lines.append("worldview.element(\"%s\", \"%s\", %s)" % [elem, target, str(ab.element_matrix[elem][target])])
			lines.append("")

	# === 经济系统 ===
	if ws.economy_system:
		lines.append("# === 经济系统 ===")
		var ec := ws.economy_system
		for cu in ec.currencies:
			lines.append("func currency(\"%s\", \"%s\", \"%s\"):" % [str(cu.get("id", "")), _esc(str(cu.get("name", ""))), str(cu.get("type", "universal"))])
			lines.append("\tmax_supply = %s" % str(cu.get("max_supply", -1)))
			lines.append("\tinflation_rate = %s" % str(cu.get("inflation_rate", 0.02)))
			lines.append("")
		for res in ec.resources:
			lines.append("func resource(\"%s\", \"%s\", \"%s\"):" % [str(res.get("id", "")), _esc(str(res.get("name", ""))), str(res.get("category", "material"))])
			lines.append("\tstack_limit = %s" % str(res.get("stack_limit", 999)))
			lines.append("")
		for mkt in ec.markets:
			lines.append("func market(\"%s\", \"%s\"):" % [str(mkt.get("id", "")), _esc(str(mkt.get("name", "")))])
			var ml: String = str(mkt.get("location", ""))
			if not ml.is_empty():
				lines.append("\tlocation = \"%s\"" % _esc(ml))
			for good in mkt.get("goods", []):
				lines.append("\tgood(\"%s\", %s)" % [str(good.get("item", "")), str(good.get("base_price", 0))])
			lines.append("")
		if not ec.trade_rules.is_empty():
			lines.append("func trade_config():")
			lines.append("\tbarter_enabled = %s" % str(ec.trade_rules.get("barter_enabled", false)))
			lines.append("\tbarter_rate = %s" % str(ec.trade_rules.get("barter_rate", 0.8)))
			lines.append("")
		for pr in ec.production_rules:
			lines.append("func production(\"%s\"):" % str(pr.get("resource", "")))
			for src in pr.get("sources", []):
				lines.append("\tsource(\"%s\", \"%s\")" % [str(src.get("type", "")), str(src.get("interval", ""))])
			lines.append("")

	# === 任务系统 ===
	if ws.quest_system:
		lines.append("# === 任务系统 ===")
		var qs := ws.quest_system
		for q in qs.quests:
			lines.append("func quest(\"%s\", \"%s\", \"%s\"):" % [str(q.get("id", "")), _esc(str(q.get("name", ""))), str(q.get("type", "main"))])
			var qd: String = str(q.get("description", ""))
			if not qd.is_empty():
				lines.append("\tdescription = \"%s\"" % _esc(qd))
			lines.append("\tlevel_req = %s" % str(q.get("level_req", 1)))
			for pre in q.get("prerequisites", []):
				lines.append("\tprerequisite(\"%s\")" % str(pre))
			for obj in q.get("objectives", []):
				lines.append("\tobjective(\"%s\", \"%s\", \"%s\", %s)" % [_esc(str(obj.get("description", ""))), str(obj.get("target_type", "kill")), str(obj.get("target_id", "")), str(obj.get("required_count", 1))])
			var qrw: Dictionary = q.get("rewards", {})
			if not qrw.is_empty():
				lines.append("\treward(%s, %s)" % [str(qrw.get("exp", 0)), str(qrw.get("gold", 0))])
				for it in qrw.get("items", []):
					lines.append("\treward_item(\"%s\", %s)" % [str(it.get("id", "")), str(it.get("qty", 1))])
				for uq in qrw.get("unlock_quests", []):
					lines.append("\tunlock(\"%s\")" % str(uq))
			var qtl: int = int(q.get("time_limit", -1))
			if qtl >= 0:
				lines.append("\ttime_limit = %s" % str(qtl))
			if q.get("repeatable", false):
				lines.append("\trepeatable = true")
			lines.append("")
		for qc in qs.quest_chains:
			lines.append("func quest_chain(\"%s\", \"%s\"):" % [str(qc.get("id", "")), _esc(str(qc.get("name", "")))])
			var qcd: String = str(qc.get("description", ""))
			if not qcd.is_empty():
				lines.append("\tdescription = \"%s\"" % _esc(qcd))
			for qid2 in qc.get("quests", []):
				lines.append("\tquest(\"%s\")" % str(qid2))
			lines.append("")

	# === 战斗系统 ===
	if ws.combat_system:
		lines.append("# === 战斗系统 ===")
		var cs := ws.combat_system
		for et in cs.enemy_templates:
			lines.append("func enemy_template(\"%s\", \"%s\", %s, %s, %s):" % [str(et.get("id", "")), _esc(str(et.get("name", ""))), str(et.get("hp", 50)), str(et.get("atk", 10)), str(et.get("def", 5))])
			var et_elem: String = str(et.get("element", ""))
			if not et_elem.is_empty():
				lines.append("\telement = \"%s\"" % et_elem)
			lines.append("\tspeed = %s" % str(et.get("speed", 8)))
			for sk in et.get("skills", []):
				lines.append("\tskill(\"%s\")" % str(sk))
			for lt in et.get("loot", []):
				lines.append("\tloot(\"%s\", %s, %s)" % [str(lt.get("item_id", "")), str(lt.get("chance", 1.0)), str(lt.get("qty", 1))])
			var etd: String = str(et.get("description", ""))
			if not etd.is_empty():
				lines.append("\tdescription = \"%s\"" % _esc(etd))
			lines.append("")
		for npc in cs.npc_pool:
			lines.append("func npc(\"%s\", \"%s\", \"%s\"):" % [str(npc.get("id", "")), _esc(str(npc.get("name", ""))), str(npc.get("role", "villager"))])
			var npc_loc: String = str(npc.get("location", ""))
			if not npc_loc.is_empty():
				lines.append("\tlocation = \"%s\"" % _esc(npc_loc))
			var npc_fac: String = str(npc.get("faction", ""))
			if not npc_fac.is_empty():
				lines.append("\tfaction = \"%s\"" % _esc(npc_fac))
			var npc_disp: String = str(npc.get("disposition", "neutral"))
			if npc_disp != "neutral":
				lines.append("\tdisposition = \"%s\"" % npc_disp)
			var npc_did: String = str(npc.get("dialog_id", ""))
			if not npc_did.is_empty():
				lines.append("\tdialog_id = \"%s\"" % _esc(npc_did))
			var npc_d: String = str(npc.get("description", ""))
			if not npc_d.is_empty():
				lines.append("\tdescription = \"%s\"" % _esc(npc_d))
			lines.append("")
		for bc in cs.battle_configs:
			lines.append("func battle_config(\"%s\", \"%s\"):" % [str(bc.get("id", "")), _esc(str(bc.get("name", "")))])
			for bid in bc.get("enemies", []):
				lines.append("\tenemy(\"%s\")" % str(bid))
			var brw: Dictionary = bc.get("rewards", {})
			if not brw.is_empty():
				lines.append("\treward(%s, %s)" % [str(brw.get("exp", 0)), str(brw.get("gold", 0))])
				for it in brw.get("items", []):
					lines.append("\treward_item(\"%s\", %s)" % [str(it.get("id", "")), str(it.get("qty", 1))])
			lines.append("\tflee_allowed = %s" % ("true" if bc.get("flee_allowed", true) else "false"))
			var bc_terrain: String = str(bc.get("terrain", "plain"))
			if bc_terrain != "plain":
				lines.append("\tterrain = \"%s\"" % bc_terrain)
			var bcd: String = str(bc.get("description", ""))
			if not bcd.is_empty():
				lines.append("\tdescription = \"%s\"" % _esc(bcd))
			lines.append("")

	# === 场景数据（2D/3D, 编辑结果反映到代码） ===
	if ws.metadata.has("scene_2d") and ws.metadata["scene_2d"] is Dictionary and not ws.metadata["scene_2d"].is_empty():
		lines.append("# === 2D 场景 ===")
		_emit_scene_data(ws.metadata["scene_2d"], "scene_2d", lines)
	if ws.metadata.has("scene_3d") and ws.metadata["scene_3d"] is Dictionary and not ws.metadata["scene_3d"].is_empty():
		lines.append("# === 3D 场景 ===")
		_emit_scene_data(ws.metadata["scene_3d"], "scene_3d", lines)

	return "\n".join(lines)

## 解析 GDScript 风格代码文本写回世界数据
## 返回 {success: bool, errors: Array[String], warnings: Array[String]}
static func parse(code: String, ws: WorldScriptData) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var lines := code.split("\n")
	var i: int = 0

	# 解析头部元数据
	while i < lines.size():
		var line := lines[i].strip_edges()
		if line.begins_with("# script"):
			ws.name = _extract_quoted(line)
		elif line.begins_with("# author"):
			ws.author = _extract_quoted(line)
		elif line.begins_with("# version"):
			ws.version = _extract_quoted(line)
		elif line.begins_with("# description"):
			ws.description = _extract_quoted(line).replace("\\n", "\n")
		elif line.begins_with("# tags"):
			var tag_str: String = _extract_quoted(line)
			var tag_arr: Array[String] = []
			for t in tag_str.split(","):
				var ts := t.strip_edges()
				if not ts.is_empty():
					tag_arr.append(ts)
			ws.tags = tag_arr
		i += 1

	# 重置子系统数据
	ws.ensure_subsystems()

	# 重新从头解析各区块
	i = 0
	while i < lines.size():
		var line := lines[i].strip_edges()

		# === 2D/3D 场景数据区块（须在跳过注释之前, 因为区块头以 # 开头） ===
		if line.begins_with("# === 2D 场景") or line.begins_with("# === 3D 场景"):
			var scene_key: String = "scene_2d" if line.begins_with("# === 2D") else "scene_3d"
			var scene_root: Dictionary = {"name": "root", "type": "Node", "props": {}, "children": []}
			var stack: Array = []
			i += 1
			# 区块首行: scene_2d "Name": 提取场景名
			if i < lines.size():
				var head := lines[i].strip_edges()
				if head.begins_with("scene_2d ") or head.begins_with("scene_3d "):
					var hn := head.find("\"")
					if hn >= 0:
						scene_root["name"] = head.get_slice("\"", 1)
					i += 1
			while i < lines.size():
				var sl := lines[i].strip_edges()
				if sl.begins_with("# ===") or sl.begins_with("func ") or sl.begins_with("worldview."):
					break
				if sl.begins_with("control "):
					var indent_level := 0
					var raw := lines[i]
					for ch in raw:
						if ch == "\t":
							indent_level += 1
						else:
							break
					var node: Dictionary = _parse_scene_node_line(sl)
					while not stack.is_empty() and stack.back()["indent"] >= indent_level:
						stack.pop_back()
					if stack.is_empty():
						scene_root["children"].append(node)
					else:
						stack.back()["node"]["children"].append(node)
					stack.append({"node": node, "indent": indent_level})
				i += 1
			if not scene_root["children"].is_empty():
				ws.metadata[scene_key] = scene_root
			continue

		# 跳过注释和空行
		if line.is_empty() or line.begins_with("#"):
			i += 1
			continue

		# worldview.xxx = yyy 或 worldview.xxx(...)
		if line.begins_with("worldview."):
			_parse_worldview_line(line, ws.worldview)
			i += 1
			continue

		# func story_event("id"):
		if line.begins_with("func story_event("):
			var eid: String = _extract_first_quoted(line)
			var evt := ws.event_system.add_story_event(eid, "")
			i = _parse_func_block(lines, i + 1, evt, "story_event", errors)
			continue

		# func random_event("id"):
		if line.begins_with("func random_event("):
			var eid: String = _extract_first_quoted(line)
			ws.event_system.add_random_event(eid, "")
			var re_ref: Dictionary = ws.event_system.random_events[ws.event_system.random_events.size() - 1]
			i = _parse_func_block(lines, i + 1, re_ref, "random_event", errors)
			continue

		# func event_chain("id"):
		if line.begins_with("func event_chain("):
			var eid: String = _extract_first_quoted(line)
			ws.event_system.add_event_chain(eid, "", "")
			var ec_ref: Dictionary = ws.event_system.event_chains[ws.event_system.event_chains.size() - 1]
			i = _parse_func_block(lines, i + 1, ec_ref, "event_chain", errors)
			continue

		# func skill("id", "name", "category"):
		if line.begins_with("func skill("):
			var strs := _extract_all_quoted(line)
			var sid: String = strs[0] if strs.size() > 0 else ""
			var sn: String = strs[1] if strs.size() > 1 else ""
			var scat: String = strs[2] if strs.size() > 2 else "active"
			ws.ability_system.add_skill(sid, sn, scat, "magic", "none", "")
			var sk_ref: Dictionary = ws.ability_system.skills[ws.ability_system.skills.size() - 1]
			i = _parse_func_block(lines, i + 1, sk_ref, "skill", errors)
			continue

		# func growth_path("id", "name"):
		if line.begins_with("func growth_path("):
			var strs := _extract_all_quoted(line)
			var gid: String = strs[0] if strs.size() > 0 else ""
			var gn: String = strs[1] if strs.size() > 1 else ""
			ws.ability_system.add_growth_path(gid, gn)
			var gp_ref: Dictionary = ws.ability_system.growth_paths[ws.ability_system.growth_paths.size() - 1]
			i = _parse_func_block(lines, i + 1, gp_ref, "growth_path", errors)
			continue

		# func status_effect("id", "name", "type"):
		if line.begins_with("func status_effect("):
			var strs := _extract_all_quoted(line)
			var fid: String = strs[0] if strs.size() > 0 else ""
			var fn: String = strs[1] if strs.size() > 1 else ""
			var ft: String = strs[2] if strs.size() > 2 else "buff"
			ws.ability_system.add_status_effect(fid, fn, ft)
			var fx_ref: Dictionary = ws.ability_system.status_effects[ws.ability_system.status_effects.size() - 1]
			i = _parse_func_block(lines, i + 1, fx_ref, "status_effect", errors)
			continue

		# func combat_config():
		if line.begins_with("func combat_config("):
			i = _parse_func_block(lines, i + 1, ws.ability_system.combat_definition, "combat_config", errors)
			continue

		# func currency("id", "name", "type"):
		if line.begins_with("func currency("):
			var strs := _extract_all_quoted(line)
			var cid: String = strs[0] if strs.size() > 0 else ""
			var cn: String = strs[1] if strs.size() > 1 else ""
			var ct: String = strs[2] if strs.size() > 2 else "universal"
			ws.economy_system.add_currency(cid, cn, ct)
			var cu_ref: Dictionary = ws.economy_system.currencies[ws.economy_system.currencies.size() - 1]
			i = _parse_func_block(lines, i + 1, cu_ref, "currency", errors)
			continue

		# func resource("id", "name", "category"):
		if line.begins_with("func resource("):
			var strs := _extract_all_quoted(line)
			var rid: String = strs[0] if strs.size() > 0 else ""
			var rn: String = strs[1] if strs.size() > 1 else ""
			var rc: String = strs[2] if strs.size() > 2 else "material"
			ws.economy_system.add_resource(rid, rn, rc)
			var res_ref: Dictionary = ws.economy_system.resources[ws.economy_system.resources.size() - 1]
			i = _parse_func_block(lines, i + 1, res_ref, "resource", errors)
			continue

		# func market("id", "name"):
		if line.begins_with("func market("):
			var strs := _extract_all_quoted(line)
			var mid: String = strs[0] if strs.size() > 0 else ""
			var mn: String = strs[1] if strs.size() > 1 else ""
			ws.economy_system.add_market(mid, mn)
			var mkt_ref: Dictionary = ws.economy_system.markets[ws.economy_system.markets.size() - 1]
			i = _parse_func_block(lines, i + 1, mkt_ref, "market", errors)
			continue

		# func trade_config():
		if line.begins_with("func trade_config("):
			i = _parse_func_block(lines, i + 1, ws.economy_system.trade_rules, "trade_config", errors)
			continue

		# func production("resource"):
		if line.begins_with("func production("):
			var rid: String = _extract_first_quoted(line)
			var pr_ref := {"resource": rid, "sources": []}
			ws.economy_system.production_rules.append(pr_ref)
			i = _parse_func_block(lines, i + 1, pr_ref, "production", errors)
			continue

		# func quest_chain("id", "name"):
		if line.begins_with("func quest_chain("):
			var strs := _extract_all_quoted(line)
			var cid: String = strs[0] if strs.size() > 0 else ""
			var cn: String = strs[1] if strs.size() > 1 else ""
			ws.quest_system.add_quest_chain(cid, cn)
			var qc_ref: Dictionary = ws.quest_system.quest_chains[ws.quest_system.quest_chains.size() - 1]
			i = _parse_func_block(lines, i + 1, qc_ref, "quest_chain", errors)
			continue

		# func quest("id", "name", "type"):
		if line.begins_with("func quest("):
			var strs := _extract_all_quoted(line)
			var qid: String = strs[0] if strs.size() > 0 else ""
			var qn: String = strs[1] if strs.size() > 1 else ""
			var qt: String = strs[2] if strs.size() > 2 else "main"
			ws.quest_system.add_quest(qid, qn, qt)
			var q_ref: Dictionary = ws.quest_system.quests[ws.quest_system.quests.size() - 1]
			i = _parse_func_block(lines, i + 1, q_ref, "quest", errors)
			continue

		# func enemy_template("id", "name", hp, atk, def):
		if line.begins_with("func enemy_template("):
			var strs := _extract_all_quoted(line)
			var nums := _extract_numbers(line)
			var eid: String = strs[0] if strs.size() > 0 else ""
			var en: String = strs[1] if strs.size() > 1 else ""
			var ehp: int = int(nums[0]) if nums.size() > 0 else 50
			var eatk: int = int(nums[1]) if nums.size() > 1 else 10
			var edef: int = int(nums[2]) if nums.size() > 2 else 5
			ws.combat_system.add_enemy_template(eid, en, ehp, eatk, edef)
			var et_ref: Dictionary = ws.combat_system.enemy_templates[ws.combat_system.enemy_templates.size() - 1]
			i = _parse_func_block(lines, i + 1, et_ref, "enemy_template", errors)
			continue

		# func npc("id", "name", "role"):
		if line.begins_with("func npc("):
			var strs := _extract_all_quoted(line)
			var nid: String = strs[0] if strs.size() > 0 else ""
			var nn: String = strs[1] if strs.size() > 1 else ""
			var nr: String = strs[2] if strs.size() > 2 else "villager"
			ws.combat_system.add_npc(nid, nn, nr)
			var npc_ref: Dictionary = ws.combat_system.npc_pool[ws.combat_system.npc_pool.size() - 1]
			i = _parse_func_block(lines, i + 1, npc_ref, "npc", errors)
			continue

		# func battle_config("id", "name"):
		if line.begins_with("func battle_config("):
			var strs := _extract_all_quoted(line)
			var bid: String = strs[0] if strs.size() > 0 else ""
			var bn: String = strs[1] if strs.size() > 1 else ""
			ws.combat_system.add_battle_config(bid, bn)
			var bc_ref: Dictionary = ws.combat_system.battle_configs[ws.combat_system.battle_configs.size() - 1]
			i = _parse_func_block(lines, i + 1, bc_ref, "battle_config", errors)
			continue

		i += 1

	if errors.is_empty():
		return {"success": true, "errors": errors, "warnings": warnings}
	return {"success": false, "errors": errors, "warnings": warnings}

## 验证代码语法
static func validate(code: String) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var lines := code.split("\n")
	var line_num: int = 0
	var has_script_header: bool = false
	var in_func: bool = false

	for line in lines:
		line_num += 1
		var stripped := line.strip_edges()
		if stripped.is_empty() or stripped.begins_with("#"):
			if stripped.begins_with("# script"):
				has_script_header = true
			continue
		# 检查 func 定义
		if stripped.begins_with("func "):
			if not stripped.ends_with(":"):
				errors.append("第 %d 行: func 定义缺少冒号" % line_num)
			in_func = true
			continue
		# 检查 worldview.xxx 格式
		if stripped.begins_with("worldview."):
			var dot_part: String = stripped.substr(10)
			var eq_or_paren := dot_part.find("=") if dot_part.find("=") >= 0 else dot_part.find("(")
			if eq_or_paren < 0:
				errors.append("第 %d 行: worldview 语句格式错误" % line_num)
			continue
		# 检查缩进行（func 块内部）
		if in_func and (line.begins_with("\t") or line.begins_with("    ")):
			continue
		# 非缩进行结束 func 块
		if in_func and not line.begins_with("\t") and not line.begins_with("    "):
			in_func = false

	if not has_script_header:
		warnings.append("缺少 # script 头部声明")

	return {"valid": errors.is_empty(), "errors": errors, "warnings": warnings}

## 获取指定分类的代码模板片段（GDScript 风格）
static func get_template(category: String) -> String:
	match category:
		"background":
			return "worldview.background_story = \"在这里写下背景故事...\""
		"era":
			return "worldview.era(\"时代名称\", 0, 1000)\nworldview.era_description(\"时代名称\", \"时代描述\")"
		"faction":
			return "worldview.faction(\"faction_id\", \"势力名称\")\nworldview.faction_power(\"faction_id\", 50)\nworldview.faction_governance(\"faction_id\", \"monarchy\")\nworldview.faction_description(\"faction_id\", \"势力描述\")"
		"timeline":
			return "worldview.timeline(年份, \"事件描述\", \"影响说明\")"
		"rule":
			return "worldview.rule(\"category\", \"key\", \"value\")\nworldview.rule_description(\"key\", \"规则说明\")"
		"relation":
			return "worldview.relation(\"faction_a\", \"faction_b\", \"alliance\", 0.8)"
		"region":
			return "worldview.region(\"region_id\", \"区域名称\")\nworldview.region_description(\"region_id\", \"区域描述\")\nworldview.region_climate(\"region_id\", \"temperate\")"
		"lore":
			return "worldview.lore(\"lore_id\", \"知识标题\")\nworldview.lore_content(\"lore_id\", \"知识内容\")\nworldview.lore_condition(\"lore_id\", \"发现条件\")"
		"story_event":
			return "func story_event(\"event_id\"):\n\tname = \"事件名称\"\n\ttrigger = \"chain\"\n\tdescription = \"事件描述\"\n\tcondition(\"variable\", \"条件表达式\")\n\tchoice(\"选择文本\")\n\t\tconsequence(\"target\", \"effect\")"
		"random_event":
			return "func random_event(\"event_id\"):\n\tname = \"事件名称\"\n\tprobability = 0.1\n\tcooldown = \"3d\""
		"event_chain":
			return "func event_chain(\"chain_id\"):\n\tname = \"事件链名称\"\n\tstart = \"起始事件ID\"\n\tdescription = \"事件链描述\""
		"skill":
			return "func skill(\"skill_id\", \"技能名称\", \"active\"):\n\tschool = \"fire\"\n\tdescription = \"技能描述\"\n\tcost_mana = 30\n\tcost_cooldown = \"3s\"\n\teffect_type = \"damage\"\n\teffect_value = 100"
		"growth":
			return "func growth_path(\"path_id\", \"路线名称\"):\n\tdescription = \"路线描述\""
		"status_effect":
			return "func status_effect(\"effect_id\", \"效果名称\", \"buff\"):\n\tduration = \"5s\"\n\tdamage_per_tick = 0"
		"combat":
			return "func combat_config():\n\ttype = \"turn_based\"\n\tcritical_rate = 0.05\n\tcritical_damage = 1.5"
		"currency":
			return "func currency(\"currency_id\", \"货币名称\", \"universal\"):\n\tmax_supply = -1\n\tinflation_rate = 0.02"
		"resource":
			return "func resource(\"resource_id\", \"资源名称\", \"material\"):\n\tstack_limit = 999"
		"market":
			return "func market(\"market_id\", \"市场名称\"):\n\tlocation = \"位置\"\n\tgood(\"item_id\", 10)"
		"production":
			return "func production(\"resource_id\"):\n\tsource(\"passive\", \"1h\")"
		"quest":
			return "func quest(\"quest_id\", \"任务名称\", \"main\"):\n\tdescription = \"任务描述\"\n\tlevel_req = 1\n\tprerequisite(\"前置任务ID\")\n\tobjective(\"目标描述\", \"kill\", \"enemy_id\", 5)\n\treward(100, 50)\n\treward_item(\"item_id\", 1)\n\tunlock(\"解锁任务ID\")\n\ttime_limit = -1\n\trepeatable = false"
		"quest_chain":
			return "func quest_chain(\"chain_id\", \"任务链名称\"):\n\tdescription = \"任务链描述\"\n\tquest(\"quest_id_1\")\n\tquest(\"quest_id_2\")"
		"enemy_template":
			return "func enemy_template(\"enemy_id\", \"敌人名称\", 50, 10, 5):\n\telement = \"fire\"\n\tspeed = 8\n\tskill(\"skill_id\")\n\tloot(\"item_id\", 0.5, 1)\n\tdescription = \"敌人描述\""
		"npc":
			return "func npc(\"npc_id\", \"NPC名称\", \"merchant\"):\n\tlocation = \"城镇\"\n\tfaction = \"faction_id\"\n\tdisposition = \"friendly\"\n\tdialog_id = \"dialog_id\"\n\tdescription = \"NPC描述\""
		"battle_config":
			return "func battle_config(\"battle_id\", \"战斗名称\"):\n\tenemy(\"enemy_id\")\n\treward(50, 20)\n\treward_item(\"item_id\", 1)\n\tflee_allowed = true\n\tterrain = \"forest\"\n\tdescription = \"战斗描述\""
		_:
			return ""

# === 内部解析方法 ===

## 解析单行 worldview 语句
static func _parse_worldview_line(line: String, wv: WorldviewData) -> void:
	var stmt: String = line.substr(10)  # 去掉 "worldview."

	# worldview.background_story = "xxx"
	if stmt.begins_with("background_story = "):
		wv.background_story = _extract_quoted(stmt)
	# worldview.era("name", start, end)
	elif stmt.begins_with("era("):
		var strs := _extract_all_quoted(stmt)
		var nums := _extract_numbers(stmt)
		var en: String = strs[0] if strs.size() > 0 else ""
		var sy: int = nums[0] if nums.size() > 0 else 0
		var ey: int = nums[1] if nums.size() > 1 else 0
		wv.add_era(en, sy, ey)
	# worldview.era_description("name", "desc")
	elif stmt.begins_with("era_description("):
		var strs := _extract_all_quoted(stmt)
		if strs.size() >= 2:
			for era in wv.era_definitions:
				if era.get("era_name", "") == strs[0]:
					era["description"] = strs[1]
					break
	# worldview.faction("id", "name")
	elif stmt.begins_with("faction("):
		var strs := _extract_all_quoted(stmt)
		var fid: String = strs[0] if strs.size() > 0 else ""
		var fn: String = strs[1] if strs.size() > 1 else ""
		wv.add_faction(fid, fn)
	# worldview.faction_power("id", value)
	elif stmt.begins_with("faction_power("):
		var strs := _extract_all_quoted(stmt)
		var nums := _extract_numbers(stmt)
		if strs.size() >= 1 and nums.size() >= 1:
			for fac in wv.factions:
				if fac.get("id", "") == strs[0]:
					fac["power_level"] = nums[0]
					break
	# worldview.faction_governance("id", "type")
	elif stmt.begins_with("faction_governance("):
		var strs := _extract_all_quoted(stmt)
		if strs.size() >= 2:
			for fac in wv.factions:
				if fac.get("id", "") == strs[0]:
					fac["governance_type"] = strs[1]
					break
	# worldview.faction_description("id", "desc")
	elif stmt.begins_with("faction_description("):
		var strs := _extract_all_quoted(stmt)
		if strs.size() >= 2:
			for fac in wv.factions:
				if fac.get("id", "") == strs[0]:
					fac["description"] = strs[1]
					break
	# worldview.timeline(year, "event", "impact")
	elif stmt.begins_with("timeline("):
		var nums := _extract_numbers(stmt)
		var strs := _extract_all_quoted(stmt)
		var yr: int = nums[0] if nums.size() > 0 else 0
		var ev: String = strs[0] if strs.size() > 0 else ""
		var im: String = strs[1] if strs.size() > 1 else ""
		wv.add_timeline_entry(yr, ev, im)
	# worldview.rule("cat", "key", "val")
	elif stmt.begins_with("rule("):
		var strs := _extract_all_quoted(stmt)
		var cat: String = strs[0] if strs.size() > 0 else ""
		var key: String = strs[1] if strs.size() > 1 else ""
		var val: String = strs[2] if strs.size() > 2 else ""
		wv.add_rule(cat, key, val)
	# worldview.rule_description("key", "desc")
	elif stmt.begins_with("rule_description("):
		var strs := _extract_all_quoted(stmt)
		if strs.size() >= 2:
			for rule in wv.world_rules:
				if rule.get("key", "") == strs[0]:
					rule["description"] = strs[1]
					break
	# worldview.relation("from", "to", "type", intensity)
	elif stmt.begins_with("relation("):
		var strs := _extract_all_quoted(stmt)
		var nums := _extract_numbers(stmt)
		if strs.size() >= 3:
			var intensity: float = float(nums[0]) if nums.size() > 0 else 0.5
			wv.faction_relationships.append({"from_id": strs[0], "to_id": strs[1], "type": strs[2], "intensity": intensity})
	# worldview.region("id", "name")
	elif stmt.begins_with("region("):
		var strs := _extract_all_quoted(stmt)
		var rid: String = strs[0] if strs.size() > 0 else ""
		var rn: String = strs[1] if strs.size() > 1 else ""
		if not wv.geography.has("regions"):
			wv.geography["regions"] = []
		wv.geography["regions"].append({"id": rid, "name": rn, "description": "", "climate": "", "resources": [], "connections": []})
	# worldview.region_description("id", "desc")
	elif stmt.begins_with("region_description("):
		var strs := _extract_all_quoted(stmt)
		if strs.size() >= 2:
			var regions: Array = wv.geography.get("regions", [])
			for reg in regions:
				if reg.get("id", "") == strs[0]:
					reg["description"] = strs[1]
					break
	# worldview.region_climate("id", "climate")
	elif stmt.begins_with("region_climate("):
		var strs := _extract_all_quoted(stmt)
		if strs.size() >= 2:
			var regions: Array = wv.geography.get("regions", [])
			for reg in regions:
				if reg.get("id", "") == strs[0]:
					reg["climate"] = strs[1]
					break
	# worldview.lore("id", "title")
	elif stmt.begins_with("lore("):
		var strs := _extract_all_quoted(stmt)
		var lid: String = strs[0] if strs.size() > 0 else ""
		var lt: String = strs[1] if strs.size() > 1 else ""
		wv.lore_entries.append({"id": lid, "title": lt, "content": "", "discovery_condition": ""})
	# worldview.lore_content("id", "content")
	elif stmt.begins_with("lore_content("):
		var strs := _extract_all_quoted(stmt)
		if strs.size() >= 2:
			for lore in wv.lore_entries:
				if lore.get("id", "") == strs[0]:
					lore["content"] = strs[1]
					break
	# worldview.lore_condition("id", "condition")
	elif stmt.begins_with("lore_condition("):
		var strs := _extract_all_quoted(stmt)
		if strs.size() >= 2:
			for lore in wv.lore_entries:
				if lore.get("id", "") == strs[0]:
					lore["discovery_condition"] = strs[1]
					break
	# worldview.element("from", "to", value) - 元素相克表记录在解析结束后由外层处理
	elif stmt.begins_with("element("):
		pass  # 元素数据暂不处理，由 ability_system 管理

## 解析 func 块内部语句
static func _parse_func_block(lines: PackedStringArray, start: int, target, block_type: String, _errors: Array[String]) -> int:
	var i := start
	# 用于跟踪当前 choice（story_event 中）
	var current_choice: Dictionary = {}
	while i < lines.size():
		var line := lines[i]
		var stripped := line.strip_edges()
		# 空行或注释跳过
		if stripped.is_empty() or stripped.begins_with("#"):
			i += 1
			continue
		# 检测是否已离开 func 块（非缩进行且非空行）
		if not line.begins_with("\t") and not line.begins_with("    ") and not stripped.is_empty():
			return i
		# 检测新的 func 定义
		if stripped.begins_with("func "):
			return i

		# 解析块内语句
		match block_type:
			"story_event":
				if stripped.begins_with("name = "):
					target["name"] = _extract_quoted(stripped)
				elif stripped.begins_with("trigger = "):
					target["trigger_type"] = _extract_quoted(stripped)
				elif stripped.begins_with("description = "):
					target["description"] = _extract_quoted(stripped)
				elif stripped.begins_with("prerequisite = "):
					target["prerequisite"] = _extract_quoted(stripped)
				elif stripped.begins_with("condition("):
					var strs := _extract_all_quoted(stripped)
					var ctype: String = strs[0] if strs.size() > 0 else ""
					var ccheck: String = strs[1] if strs.size() > 1 else ""
					if not target.has("conditions"):
						target["conditions"] = []
					target["conditions"].append({"type": ctype, "check": ccheck})
				elif stripped.begins_with("choice("):
					var ct := _extract_first_quoted(stripped)
					current_choice = {"id": "choice_%d" % target.get("choices", []).size(), "text": ct, "consequences": []}
					if not target.has("choices"):
						target["choices"] = []
					target["choices"].append(current_choice)
				elif stripped.begins_with("consequence(") and current_choice != null:
					var strs := _extract_all_quoted(stripped)
					var ctgt: String = strs[0] if strs.size() > 0 else ""
					var ceff: String = strs[1] if strs.size() > 1 else ""
					current_choice["consequences"].append({"target": ctgt, "effect": ceff})
				elif stripped.begins_with("branch("):
					var strs := _extract_all_quoted(stripped)
					var bc: String = strs[0] if strs.size() > 0 else ""
					var ne: String = strs[1] if strs.size() > 1 else ""
					if not target.has("branches"):
						target["branches"] = []
					target["branches"].append({"condition": bc, "next_event": ne})
			"random_event":
				if stripped.begins_with("name = "):
					target["name"] = _extract_quoted(stripped)
				elif stripped.begins_with("probability = "):
					var val_str: String = stripped.substr(14).strip_edges()
					target["probability"] = float(val_str) if val_str.is_valid_float() else 0.1
				elif stripped.begins_with("cooldown = "):
					target["cooldown"] = _extract_quoted(stripped)
			"event_chain":
				if stripped.begins_with("name = "):
					target["name"] = _extract_quoted(stripped)
				elif stripped.begins_with("start = "):
					target["start_event"] = _extract_quoted(stripped)
				elif stripped.begins_with("description = "):
					target["description"] = _extract_quoted(stripped)
			"skill":
				if stripped.begins_with("school = "):
					target["school"] = _extract_quoted(stripped)
				elif stripped.begins_with("description = "):
					target["description"] = _extract_quoted(stripped)
				elif stripped.begins_with("cost_mana = "):
					if not target.has("cost"):
						target["cost"] = {}
					var val_str: String = stripped.substr(11).strip_edges()
					target["cost"]["mana"] = int(val_str) if val_str.is_valid_int() else 0
				elif stripped.begins_with("cost_cooldown = "):
					if not target.has("cost"):
						target["cost"] = {}
					target["cost"]["cooldown"] = _extract_quoted(stripped)
				elif stripped.begins_with("effect_type = "):
					if not target.has("effect"):
						target["effect"] = {}
					target["effect"]["type"] = _extract_quoted(stripped)
				elif stripped.begins_with("effect_value = "):
					if not target.has("effect"):
						target["effect"] = {}
					var val_str: String = stripped.substr(14).strip_edges()
					target["effect"]["base_value"] = float(val_str) if val_str.is_valid_float() else 0
			"growth_path":
				if stripped.begins_with("description = "):
					target["description"] = _extract_quoted(stripped)
			"status_effect":
				if stripped.begins_with("duration = "):
					target["duration"] = _extract_quoted(stripped)
				elif stripped.begins_with("damage_per_tick = "):
					var val_str: String = stripped.substr(18).strip_edges()
					target["damage_per_tick"] = float(val_str) if val_str.is_valid_float() else 0
			"combat_config":
				if stripped.begins_with("type = "):
					target["type"] = _extract_quoted(stripped)
				elif stripped.begins_with("critical_rate = "):
					var val_str: String = stripped.substr(16).strip_edges()
					target["critical_rate"] = float(val_str) if val_str.is_valid_float() else 0.05
				elif stripped.begins_with("critical_damage = "):
					var val_str: String = stripped.substr(17).strip_edges()
					target["critical_damage"] = float(val_str) if val_str.is_valid_float() else 1.5
			"currency":
				if stripped.begins_with("max_supply = "):
					var val_str: String = stripped.substr(13).strip_edges()
					target["max_supply"] = int(val_str) if val_str.is_valid_int() else -1
				elif stripped.begins_with("inflation_rate = "):
					var val_str: String = stripped.substr(16).strip_edges()
					target["inflation_rate"] = float(val_str) if val_str.is_valid_float() else 0.02
			"resource":
				if stripped.begins_with("stack_limit = "):
					var val_str: String = stripped.substr(14).strip_edges()
					target["stack_limit"] = int(val_str) if val_str.is_valid_int() else 999
			"market":
				if stripped.begins_with("location = "):
					target["location"] = _extract_quoted(stripped)
				elif stripped.begins_with("good("):
					var strs := _extract_all_quoted(stripped)
					var nums := _extract_numbers(stripped)
					var item: String = strs[0] if strs.size() > 0 else ""
					var price: float = float(nums[0]) if nums.size() > 0 else 0
					if not target.has("goods"):
						target["goods"] = []
					target["goods"].append({"item": item, "base_price": price})
			"trade_config":
				if stripped.begins_with("barter_enabled = "):
					var val_str: String = stripped.substr(17).strip_edges()
					target["barter_enabled"] = val_str == "true"
				elif stripped.begins_with("barter_rate = "):
					var val_str: String = stripped.substr(14).strip_edges()
					target["barter_rate"] = float(val_str) if val_str.is_valid_float() else 0.8
			"production":
				if stripped.begins_with("source("):
					var strs := _extract_all_quoted(stripped)
					var stype: String = strs[0] if strs.size() > 0 else ""
					var sinterval: String = strs[1] if strs.size() > 1 else ""
					if not target.has("sources"):
						target["sources"] = []
					target["sources"].append({"type": stype, "interval": sinterval})
			"quest":
				if stripped.begins_with("description = "):
					target["description"] = _extract_quoted(stripped)
				elif stripped.begins_with("level_req = "):
					var val_str: String = stripped.substr(11).strip_edges()
					target["level_req"] = int(val_str) if val_str.is_valid_int() else 1
				elif stripped.begins_with("prerequisite("):
					if not target.has("prerequisites"):
						target["prerequisites"] = []
					target["prerequisites"].append(_extract_first_quoted(stripped))
				elif stripped.begins_with("objective("):
					var strs := _extract_all_quoted(stripped)
					var nums := _extract_numbers(stripped)
					if not target.has("objectives"):
						target["objectives"] = []
					target["objectives"].append({
						"description": strs[0] if strs.size() > 0 else "",
						"target_type": strs[1] if strs.size() > 1 else "kill",
						"target_id": strs[2] if strs.size() > 2 else "",
						"required_count": int(nums[0]) if nums.size() > 0 else 1,
						"current_count": 0,
					})
				elif stripped.begins_with("reward("):
					var nums := _extract_numbers(stripped)
					if not target.has("rewards"):
						target["rewards"] = {"exp": 0, "gold": 0, "items": [], "unlock_quests": []}
					target["rewards"]["exp"] = int(nums[0]) if nums.size() > 0 else 0
					target["rewards"]["gold"] = int(nums[1]) if nums.size() > 1 else 0
				elif stripped.begins_with("reward_item("):
					var strs := _extract_all_quoted(stripped)
					var nums := _extract_numbers(stripped)
					if not target.has("rewards"):
						target["rewards"] = {"exp": 0, "gold": 0, "items": [], "unlock_quests": []}
					target["rewards"]["items"].append({"id": strs[0] if strs.size() > 0 else "", "qty": int(nums[0]) if nums.size() > 0 else 1})
				elif stripped.begins_with("unlock("):
					if not target.has("rewards"):
						target["rewards"] = {"exp": 0, "gold": 0, "items": [], "unlock_quests": []}
					target["rewards"]["unlock_quests"].append(_extract_first_quoted(stripped))
				elif stripped.begins_with("time_limit = "):
					var val_str: String = stripped.substr(12).strip_edges()
					target["time_limit"] = int(val_str) if val_str.is_valid_int() else -1
				elif stripped.begins_with("repeatable = "):
					var val_str: String = stripped.substr(13).strip_edges()
					target["repeatable"] = val_str == "true"
			"quest_chain":
				if stripped.begins_with("description = "):
					target["description"] = _extract_quoted(stripped)
				elif stripped.begins_with("quest("):
					if not target.has("quests"):
						target["quests"] = []
					target["quests"].append(_extract_first_quoted(stripped))
			"enemy_template":
				if stripped.begins_with("element = "):
					target["element"] = _extract_quoted(stripped)
				elif stripped.begins_with("speed = "):
					var val_str: String = stripped.substr(8).strip_edges()
					target["speed"] = int(val_str) if val_str.is_valid_int() else 8
				elif stripped.begins_with("skill("):
					if not target.has("skills"):
						target["skills"] = []
					target["skills"].append(_extract_first_quoted(stripped))
				elif stripped.begins_with("loot("):
					var strs := _extract_all_quoted(stripped)
					var nums := _extract_numbers(stripped)
					if not target.has("loot"):
						target["loot"] = []
					target["loot"].append({
						"item_id": strs[0] if strs.size() > 0 else "",
						"chance": float(nums[0]) if nums.size() > 0 else 1.0,
						"qty": int(nums[1]) if nums.size() > 1 else 1,
					})
				elif stripped.begins_with("description = "):
					target["description"] = _extract_quoted(stripped)
			"npc":
				if stripped.begins_with("location = "):
					target["location"] = _extract_quoted(stripped)
				elif stripped.begins_with("faction = "):
					target["faction"] = _extract_quoted(stripped)
				elif stripped.begins_with("disposition = "):
					target["disposition"] = _extract_quoted(stripped)
				elif stripped.begins_with("dialog_id = "):
					target["dialog_id"] = _extract_quoted(stripped)
				elif stripped.begins_with("description = "):
					target["description"] = _extract_quoted(stripped)
			"battle_config":
				if stripped.begins_with("enemy("):
					if not target.has("enemies"):
						target["enemies"] = []
					target["enemies"].append(_extract_first_quoted(stripped))
				elif stripped.begins_with("reward("):
					var nums := _extract_numbers(stripped)
					if not target.has("rewards"):
						target["rewards"] = {"exp": 0, "gold": 0, "items": []}
					target["rewards"]["exp"] = int(nums[0]) if nums.size() > 0 else 0
					target["rewards"]["gold"] = int(nums[1]) if nums.size() > 1 else 0
				elif stripped.begins_with("reward_item("):
					var strs := _extract_all_quoted(stripped)
					var nums := _extract_numbers(stripped)
					if not target.has("rewards"):
						target["rewards"] = {"exp": 0, "gold": 0, "items": []}
					target["rewards"]["items"].append({"id": strs[0] if strs.size() > 0 else "", "qty": int(nums[0]) if nums.size() > 0 else 1})
				elif stripped.begins_with("flee_allowed = "):
					var val_str: String = stripped.substr(15).strip_edges()
					target["flee_allowed"] = val_str == "true"
				elif stripped.begins_with("terrain = "):
					target["terrain"] = _extract_quoted(stripped)
				elif stripped.begins_with("description = "):
					target["description"] = _extract_quoted(stripped)
		i += 1
	return i

# === 辅助解析工具 ===

static func _extract_quoted(line: String) -> String:
	var start := line.find("\"")
	if start < 0:
		return ""
	var end := line.rfind("\"")
	if end <= start:
		return ""
	return line.substr(start + 1, end - start - 1)

static func _extract_first_quoted(line: String) -> String:
	return _extract_quoted(line)

static func _extract_all_quoted(line: String) -> Array[String]:
	var result: Array[String] = []
	var search_start: int = 0
	while true:
		var s := line.find("\"", search_start)
		if s < 0:
			break
		var e := line.find("\"", s + 1)
		if e < 0:
			break
		result.append(line.substr(s + 1, e - s - 1))
		search_start = e + 1
	return result

static func _extract_numbers(line: String) -> Array[int]:
	var result: Array[int] = []
	var regex := RegEx.new()
	regex.compile("-?\\d+")
	for m in regex.search_all(line):
		var pos: int = m.get_start()
		var before := line.substr(0, pos)
		if before.count("\"") % 2 == 0:
			result.append(int(m.get_string()))
	return result

static func _esc(text: String) -> String:
	return text.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n")

## === 场景数据序列化/解析（scene_2d / scene_3d 章节） ===

## 场景节点树 -> 代码行
static func _emit_scene_data(root: Dictionary, prefix: String, lines: PackedStringArray) -> void:
	lines.append("%s \"%s\":" % [prefix, _esc(str(root.get("name", "root")))])
	_emit_scene_children(root.get("children", []), lines, "\t")

static func _emit_scene_children(children: Array, lines: PackedStringArray, indent: String) -> void:
	for child in children:
		var line := "%scontrol \"%s\" type=\"%s\"" % [indent, _esc(str(child.get("name", ""))), _esc(str(child.get("type", "Control")))]
		var props: Dictionary = child.get("props", {})
		for pk in ["position", "size", "rotation", "scale", "anchors_preset", "color", "text"]:
			if props.has(pk) and props[pk] != null and str(props[pk]) != "":
				line += " %s=\"%s\"" % [pk, _esc(str(props[pk]))]
		lines.append(line)
		var sub: Array = child.get("children", [])
		if not sub.is_empty():
			_emit_scene_children(sub, lines, indent + "\t")

## 代码行 -> 场景节点
static func _parse_scene_node_line(line: String) -> Dictionary:
	var name := ""
	var node_type := "Control"
	var props: Dictionary = {}
	var rest := line
	var name_start := line.find("\"")
	if name_start >= 0:
		name = line.get_slice("\"", 1)
		rest = line.substr(line.find("\"", name_start + 1) + 1)
	# 提取 key="value" 对
	var pos := 0
	while pos < rest.length():
		var eq := rest.find("=", pos)
		if eq < 0:
			break
		var key := rest.substr(pos, eq - pos).strip_edges()
		var vstart := rest.find("\"", eq + 1)
		if vstart < 0:
			break
		var vend := rest.find("\"", vstart + 1)
		if vend < 0:
			break
		var val := rest.substr(vstart + 1, vend - vstart - 1)
		if key == "type":
			node_type = val
		elif key == "name":
			name = val
		else:
			props[key] = _parse_scene_prop_value(key, val)
		pos = vend + 1
	return {"name": name, "type": node_type, "props": props, "children": []}

## 场景属性字符串 -> 类型化值
static func _parse_scene_prop_value(key: String, val: String) -> Variant:
	if key == "position" or key == "size":
		# "(x, y)" -> Vector2
		var nums: PackedStringArray = val.trim_prefix("(").trim_suffix(")").split(",")
		if nums.size() == 2:
			return Vector2(float(nums[0].strip_edges()), float(nums[1].strip_edges()))
	if key == "rotation" or key == "scale":
		if val.is_valid_float():
			return float(val)
	if key == "anchors_preset" or key == "color" or key == "text":
		return val
	return val

# === 蓝图脚本代码生成 ===

## 将蓝图图编译为 GDScript 代码
static func generate_blueprint_code(graph: Dictionary, _ws: WorldScriptData) -> String:
	var lines: PackedStringArray = []
	lines.append("# === Blueprint Generated ===")
	# 生成变量声明
	for var_name in graph.get("local_variables", {}):
		var vdata: Dictionary = graph["local_variables"][var_name]
		var vtype: String = BlueprintData.get_var_type_string(vdata.get("type", BlueprintData.PinDataType.ANY))
		var vval: Variant = vdata.get("value", null)
		if vval == null:
			match vdata.get("type", BlueprintData.PinDataType.ANY):
				BlueprintData.PinDataType.BOOL:
					vval = false
				BlueprintData.PinDataType.INT:
					vval = 0
				BlueprintData.PinDataType.FLOAT:
					vval = 0.0
				BlueprintData.PinDataType.STRING:
					vval = ""
				_:
					vval = null
		if vval == null:
			lines.append("var %s: Variant = null" % var_name)
		else:
			lines.append("var %s: %s = %s" % [var_name, vtype, _value_to_code(vval)])
	lines.append("")
	# 找到所有入口节点
	var entry_nodes := BlueprintData.find_entry_nodes(graph)
	if entry_nodes.is_empty():
		lines.append("# (no entry nodes found)")
		return "\n".join(lines)
	# 从每个入口节点开始编译执行流
	var entry_idx: int = 0
	for start_nid in entry_nodes:
		var func_name: String = "_blueprint_entry"
		if entry_idx > 0:
			func_name = "_blueprint_entry_%d" % entry_idx
		lines.append("func %s():" % func_name)
		var visited: Dictionary = {}  # 防止循环
		_compile_exec_chain(graph, start_nid, lines, "\t", visited)
		lines.append("")
		entry_idx += 1
	return "\n".join(lines)

## 沿执行流连线 DFS 编译节点链
static func _compile_exec_chain(graph: Dictionary, node_id: String, lines: PackedStringArray, indent: String, visited: Dictionary) -> void:
	# 委托到 BlueprintCodeGen（按 8 大分类拆分, 见 blueprint_codegen.gd）
	BlueprintCodeGen.compile_exec_chain(graph, node_id, lines, indent, visited)

## 获取节点执行流后继（按端口顺序）
static func _get_exec_successors_ordered(graph: Dictionary, node_id: String) -> Array[String]:
	var result: Array[String] = []
	var outputs: Array = graph["nodes"][node_id].get("outputs", [])
	for port_idx in outputs.size():
		if outputs[port_idx]["data_type"] == BlueprintData.PinDataType.EXEC:
			for conn in graph["connections"]:
				if conn["is_exec"] and conn["from_node"] == node_id and conn["from_port"] == port_idx:
					result.append(conn["to_node"])
	return result

## 获取节点指定端口的执行流后继
static func _get_exec_successors_for_port(graph: Dictionary, node_id: String, port: int) -> Array[String]:
	var result: Array[String] = []
	for conn in graph["connections"]:
		if conn["is_exec"] and conn["from_node"] == node_id and conn["from_port"] == port:
			result.append(conn["to_node"])
	return result

## 解析数据引脚的输入值（内联表达式）
static func _resolve_data_input(graph: Dictionary, node_id: String, port: int) -> String:
	# 查找连接到该端口的数据源
	for conn in graph["connections"]:
		if not conn["is_exec"] and conn["to_node"] == node_id and conn["to_port"] == port:
			var src_nid: String = conn["from_node"]
			if not graph["nodes"].has(src_nid):
				continue
			var src_node: Dictionary = graph["nodes"][src_nid]
			match src_node["node_type"]:
				"get_var":
					return src_node.get("properties", {}).get("var_name", "unknown")
				"expression":
					return src_node.get("properties", {}).get("code", "null")
				_:
					return "/* %s */" % src_node.get("title", "unknown")
	# 没有连接: 返回默认值
	var node: Dictionary = graph["nodes"].get(node_id, {})
	var inputs: Array = node.get("inputs", [])
	if port < inputs.size():
		var pin: Dictionary = inputs[port]
		var dv: Variant = pin.get("default_value", null)
		if dv != null:
			return _value_to_code(dv)
		match pin.get("data_type", BlueprintData.PinDataType.ANY):
			BlueprintData.PinDataType.BOOL: return "false"
			BlueprintData.PinDataType.INT: return "0"
			BlueprintData.PinDataType.FLOAT: return "0.0"
			BlueprintData.PinDataType.STRING: return "\"\""
			_: return "null"
	return "null"

## 将值转换为 GDScript 代码字面量
static func _value_to_code(val: Variant) -> String:
	if val == null:
		return "null"
	match typeof(val):
		TYPE_BOOL: return "true" if val else "false"
		TYPE_INT: return str(val)
		TYPE_FLOAT: return str(val)
		TYPE_STRING: return "\"%s\"" % _esc(str(val))
		_: return str(val)
