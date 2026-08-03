## BlueprintCodeGen - 蓝图执行流代码生成（按节点分类拆分）
## 从 script_codegen.gd 的 _compile_exec_chain 提取。
## 沿 exec 连线 DFS 编译节点链，按 8 大分类分派到 handler。
class_name BlueprintCodeGen
extends RefCounted

## 沿执行流连线 DFS 编译节点链（递归入口）
static func compile_exec_chain(graph: Dictionary, node_id: String, lines: PackedStringArray, indent: String, visited: Dictionary) -> void:
	if visited.has(node_id):
		return
	visited[node_id] = true
	if not graph["nodes"].has(node_id):
		return
	var node: Dictionary = graph["nodes"][node_id]
	var node_type: String = node["node_type"]
	match _category(node_type):
		0: _handle_base(graph, node, node_type, lines, indent, visited)
		1: _handle_flow(graph, node, node_type, lines, indent, visited)
		2: _handle_economy(graph, node, node_type, lines, indent, visited)
		3: _handle_story(graph, node, node_type, lines, indent, visited)
		4: _handle_world(graph, node, node_type, lines, indent, visited)
		5: _handle_player(graph, node, node_type, lines, indent, visited)
		6: _handle_combat(graph, node, node_type, lines, indent, visited)
		8: _handle_ability(graph, node, node_type, lines, indent, visited)
		9: _handle_quest(graph, node, node_type, lines, indent, visited)
		_: _handle_other(graph, node, node_type, lines, indent, visited)

## 节点类型 -> 分类: 0=基础 1=flow 2=economy 3=story 4=world 5=player 6=combat 7=其他(通用)
static func _category(node_type: String) -> int:
	match node_type:
		"start", "branch", "sequence", "set_var", "story_event", "print", "expression", "get_var":
			return 0
		"player_give_item", "player_remove_item":
			return 2  # 与经济节点共用处理
		_:
			if node_type.begins_with("flow_"):
				return 1
			if node_type.begins_with("eco_"):
				return 2
			if node_type.begins_with("story_"):
				return 3
			if node_type.begins_with("world_"):
				return 4
			if node_type.begins_with("player_"):
				return 5
			if node_type.begins_with("combat_"):
				return 6
			if node_type.begins_with("ability_"):
				return 8
			if node_type.begins_with("quest_"):
				return 9
			return 7

# === 0. 基础节点 ===

static func _handle_base(graph: Dictionary, node: Dictionary, node_type: String, lines: PackedStringArray, indent: String, visited: Dictionary) -> void:
	match node_type:
		"start":
			lines.append("%s# Event Begin" % indent)
			var succs := _get_exec_successors_ordered(graph, node["id"])
			for succ in succs:
				compile_exec_chain(graph, succ, lines, indent, visited)
		"branch":
			var cond_expr := _resolve_data_input(graph, node["id"], 1)  # port 1 = condition
			lines.append("%sif %s:" % [indent, cond_expr])
			var true_succs := _get_exec_successors_for_port(graph, node["id"], 0)
			for succ in true_succs:
				compile_exec_chain(graph, succ, lines, indent + "\t", visited)
			var false_succs := _get_exec_successors_for_port(graph, node["id"], 1)
			if not false_succs.is_empty():
				lines.append("%selse:" % indent)
				for succ in false_succs:
					compile_exec_chain(graph, succ, lines, indent + "\t", visited)
		"sequence":
			lines.append("%s# Sequence" % indent)
			var outputs: Array = node.get("outputs", [])
			for port_idx in outputs.size():
				var succs := _get_exec_successors_for_port(graph, node["id"], port_idx)
				for succ in succs:
					compile_exec_chain(graph, succ, lines, indent, visited)
		"set_var":
			var var_name: String = node.get("properties", {}).get("var_name", "unknown_var")
			var value_expr := _resolve_data_input(graph, node["id"], 1)  # port 1 = value
			lines.append("%s%s = %s" % [indent, var_name, value_expr])
			var succs := _get_exec_successors_ordered(graph, node["id"])
			for succ in succs:
				compile_exec_chain(graph, succ, lines, indent, visited)
		"story_event":
			var event_id: String = node.get("properties", {}).get("event_id", "")
			lines.append("%sstory_event(\"%s\")" % [indent, event_id])
			var succs := _get_exec_successors_ordered(graph, node["id"])
			for succ in succs:
				compile_exec_chain(graph, succ, lines, indent, visited)
		"print":
			var msg_expr := _resolve_data_input(graph, node["id"], 1)  # port 1 = message
			lines.append("%sprint(%s)" % [indent, msg_expr])
			var succs := _get_exec_successors_ordered(graph, node["id"])
			for succ in succs:
				compile_exec_chain(graph, succ, lines, indent, visited)
		"expression":
			var code: String = node.get("properties", {}).get("code", "")
			if code.is_empty():
				code = "pass"
			lines.append("%s%s" % [indent, code])
			var succs := _get_exec_successors_ordered(graph, node["id"])
			for succ in succs:
				compile_exec_chain(graph, succ, lines, indent, visited)
		"get_var":
			# get_var 通常作为数据源，不在执行流中独立出现
			pass

# === 1. 流程控制 (flow) ===

static func _handle_flow(graph: Dictionary, node: Dictionary, node_type: String, lines: PackedStringArray, indent: String, visited: Dictionary) -> void:
	match node_type:
		"flow_start":
			lines.append("%s# 蓝图开始" % indent)
			var succs := _get_exec_successors_ordered(graph, node["id"])
			for succ in succs:
				compile_exec_chain(graph, succ, lines, indent, visited)
		"flow_branch":
			var cond_expr := _resolve_data_input(graph, node["id"], 1)
			lines.append("%sif %s:" % [indent, cond_expr])
			var true_succs := _get_exec_successors_for_port(graph, node["id"], 0)
			for succ in true_succs:
				compile_exec_chain(graph, succ, lines, indent + "\t", visited)
			var false_succs := _get_exec_successors_for_port(graph, node["id"], 1)
			if not false_succs.is_empty():
				lines.append("%selse:" % indent)
				for succ in false_succs:
					compile_exec_chain(graph, succ, lines, indent + "\t", visited)
		"flow_print_log":
			var msg_expr := _resolve_data_input(graph, node["id"], 1)
			lines.append("%sprint(%s)" % [indent, msg_expr])
			var succs := _get_exec_successors_ordered(graph, node["id"])
			for succ in succs:
				compile_exec_chain(graph, succ, lines, indent, visited)
		"flow_set_var":
			var var_name: String = node.get("properties", {}).get("var_name", "unknown_var")
			var value_expr := _resolve_data_input(graph, node["id"], 1)
			lines.append("%s%s = %s" % [indent, var_name, value_expr])
			var succs := _get_exec_successors_ordered(graph, node["id"])
			for succ in succs:
				compile_exec_chain(graph, succ, lines, indent, visited)
		"flow_for_loop":
			var iterations: String = str(node.get("properties", {}).get("iterations", 1))
			lines.append("%sfor _loop_i in range(%s):" % [indent, iterations])
			var body_succs := _get_exec_successors_ordered(graph, node["id"])
			for succ in body_succs:
				compile_exec_chain(graph, succ, lines, indent + "\t", visited)
		"flow_random_select":
			lines.append("%sif randf() < 0.5:" % indent)
			var r0 := _get_exec_successors_for_port(graph, node["id"], 0)
			for succ in r0:
				compile_exec_chain(graph, succ, lines, indent + "\t", visited)
			var r1 := _get_exec_successors_for_port(graph, node["id"], 1)
			if not r1.is_empty():
				lines.append("%selse:" % indent)
				for succ in r1:
					compile_exec_chain(graph, succ, lines, indent + "\t", visited)
		"flow_wait":
			var seconds: String = str(node.get("properties", {}).get("seconds", 1.0))
			lines.append("%sawait get_tree().create_timer(%s).timeout" % [indent, seconds])
			var w_succs := _get_exec_successors_ordered(graph, node["id"])
			for succ in w_succs:
				compile_exec_chain(graph, succ, lines, indent, visited)
		"flow_comment":
			var cmt: String = node.get("properties", {}).get("text", "")
			lines.append("%s# %s" % [indent, cmt])
			var c_succs := _get_exec_successors_ordered(graph, node["id"])
			for succ in c_succs:
				compile_exec_chain(graph, succ, lines, indent, visited)
		"flow_sub_graph":
			var gkey: String = node.get("properties", {}).get("graph_id", "")
			lines.append("%s# 调用子蓝图: %s（运行时由 BlueprintExecutor 执行）" % [indent, gkey])
			var s_succs := _get_exec_successors_ordered(graph, node["id"])
			for succ in s_succs:
				compile_exec_chain(graph, succ, lines, indent, visited)

# === 2. 经济交易 (economy) ===

static func _handle_economy(graph: Dictionary, node: Dictionary, node_type: String, lines: PackedStringArray, indent: String, visited: Dictionary) -> void:
	match node_type:
		"eco_give_item", "player_give_item":
			var iid: String = node.get("properties", {}).get("item_id", "")
			var qty: String = str(node.get("properties", {}).get("quantity", 1))
			lines.append("%seconomy_engine.add_item(\"%s\", %s)" % [indent, iid, qty])
			var succs := _get_exec_successors_ordered(graph, node["id"])
			for succ in succs:
				compile_exec_chain(graph, succ, lines, indent, visited)
		"eco_remove_item", "player_remove_item":
			var iid: String = node.get("properties", {}).get("item_id", "")
			var qty: String = str(node.get("properties", {}).get("quantity", 1))
			lines.append("%seconomy_engine.remove_item(\"%s\", %s)" % [indent, iid, qty])
			var succs := _get_exec_successors_ordered(graph, node["id"])
			for succ in succs:
				compile_exec_chain(graph, succ, lines, indent, visited)
		"eco_give_currency":
			var cid: String = node.get("properties", {}).get("currency_id", "gold")
			var amt: String = str(node.get("properties", {}).get("amount", 0))
			lines.append("%seconomy_engine.add_currency(\"%s\", %s)" % [indent, cid, amt])
			var succs := _get_exec_successors_ordered(graph, node["id"])
			for succ in succs:
				compile_exec_chain(graph, succ, lines, indent, visited)
		"eco_spend_currency":
			var cid: String = node.get("properties", {}).get("currency_id", "gold")
			var amt: String = str(node.get("properties", {}).get("amount", 0))
			lines.append("%seconomy_engine.player_currencies[\"%s\"] -= %s" % [indent, cid, amt])
			var succs := _get_exec_successors_ordered(graph, node["id"])
			for succ in succs:
				compile_exec_chain(graph, succ, lines, indent, visited)
		"eco_buy":
			var mid: String = node.get("properties", {}).get("market_id", "")
			var bid: String = node.get("properties", {}).get("item_id", "")
			var bq: String = str(node.get("properties", {}).get("quantity", 1))
			lines.append("%seconomy_engine.buy(\"%s\", \"%s\", %s)" % [indent, mid, bid, bq])
			var b_succs := _get_exec_successors_ordered(graph, node["id"])
			for succ in b_succs:
				compile_exec_chain(graph, succ, lines, indent, visited)
		"eco_sell":
			var smid: String = node.get("properties", {}).get("market_id", "")
			var siid: String = node.get("properties", {}).get("item_id", "")
			var sq: String = str(node.get("properties", {}).get("quantity", 1))
			lines.append("%seconomy_engine.sell(\"%s\", \"%s\", %s)" % [indent, smid, siid, sq])
			var s_succs := _get_exec_successors_ordered(graph, node["id"])
			for succ in s_succs:
				compile_exec_chain(graph, succ, lines, indent, visited)
		"eco_barter":
			var give_id: String = node.get("properties", {}).get("give_item", "")
			var give_qty: String = str(node.get("properties", {}).get("give_quantity", 1))
			var get_id: String = node.get("properties", {}).get("get_item", "")
			var get_qty: String = str(node.get("properties", {}).get("get_quantity", 1))
			lines.append("%sif economy_engine.remove_item(\"%s\", %s):" % [indent, give_id, give_qty])
			lines.append("%s\teconomy_engine.add_item(\"%s\", %s)" % [indent, get_id, get_qty])
			var bar_succs := _get_exec_successors_ordered(graph, node["id"])
			for succ in bar_succs:
				compile_exec_chain(graph, succ, lines, indent, visited)
		"eco_refresh_price":
			lines.append("%seconomy_engine.update_market_prices()" % indent)
			var rp_succs := _get_exec_successors_ordered(graph, node["id"])
			for succ in rp_succs:
				compile_exec_chain(graph, succ, lines, indent, visited)
		"eco_adjust_supply":
			var a_mid: String = node.get("properties", {}).get("market_id", "")
			var a_iid: String = node.get("properties", {}).get("item_id", "")
			var a_delta: String = str(node.get("properties", {}).get("supply_delta", 0))
			lines.append("%s# 调整供给: %s/%s %s（运行时由 BlueprintExecutor 处理）" % [indent, a_mid, a_iid, a_delta])
			var adj_succs := _get_exec_successors_ordered(graph, node["id"])
			for succ in adj_succs:
				compile_exec_chain(graph, succ, lines, indent, visited)
		"eco_discount":
			var d_mid: String = node.get("properties", {}).get("market_id", "")
			var d_rate: String = str(node.get("properties", {}).get("discount_rate", 0.8))
			lines.append("%s# 折扣: %s x%s（运行时由 BlueprintExecutor 处理）" % [indent, d_mid, d_rate])
			var disc_succs := _get_exec_successors_ordered(graph, node["id"])
			for succ in disc_succs:
				compile_exec_chain(graph, succ, lines, indent, visited)
		"eco_set_trade_rule":
			var rule_key: String = node.get("properties", {}).get("rule_key", "barter_enabled")
			var rule_val: String = _resolve_data_input(graph, node["id"], 1)
			lines.append("%s# 交易规则 %s = %s（运行时由 BlueprintExecutor 处理）" % [indent, rule_key, rule_val])
			var tr_succs := _get_exec_successors_ordered(graph, node["id"])
			for succ in tr_succs:
				compile_exec_chain(graph, succ, lines, indent, visited)

# === 3. 剧情事件 (story) ===

static func _handle_story(graph: Dictionary, node: Dictionary, node_type: String, lines: PackedStringArray, indent: String, visited: Dictionary) -> void:
	match node_type:
		"story_trigger":
			var eid: String = node.get("properties", {}).get("event_id", "")
			lines.append("%sevent_engine.trigger_event(get_event(\"%s\"))" % [indent, eid])
			var succs := _get_exec_successors_ordered(graph, node["id"])
			for succ in succs:
				compile_exec_chain(graph, succ, lines, indent, visited)
		"story_branch":
			var cond_expr := _resolve_data_input(graph, node["id"], 1)
			lines.append("%sif %s:" % [indent, cond_expr])
			var t_succs := _get_exec_successors_for_port(graph, node["id"], 0)
			for succ in t_succs:
				compile_exec_chain(graph, succ, lines, indent + "\t", visited)
			var f_succs := _get_exec_successors_for_port(graph, node["id"], 1)
			if not f_succs.is_empty():
				lines.append("%selse:" % indent)
				for succ in f_succs:
					compile_exec_chain(graph, succ, lines, indent + "\t", visited)
		"story_choice":
			# 运行时由 BlueprintExecutor 暂停等待玩家输入; 编译为两个分支占位
			var c0: String = node.get("properties", {}).get("choice_0_text", "选项A")
			var c1: String = node.get("properties", {}).get("choice_1_text", "选项B")
			lines.append("%s# 剧情选择（运行时暂停等待输入）: %s / %s" % [indent, c0, c1])
			var c0_succs := _get_exec_successors_for_port(graph, node["id"], 0)
			for succ in c0_succs:
				compile_exec_chain(graph, succ, lines, indent, visited)
			var c1_succs := _get_exec_successors_for_port(graph, node["id"], 1)
			for succ in c1_succs:
				compile_exec_chain(graph, succ, lines, indent, visited)
		"story_record":
			var rid: String = node.get("properties", {}).get("event_id", "")
			lines.append("%sevent_engine.triggered_ids[\"%s\"] = true" % [indent, rid])
			var rec_succs := _get_exec_successors_ordered(graph, node["id"])
			for succ in rec_succs:
				compile_exec_chain(graph, succ, lines, indent, visited)
		"story_dialog":
			var speaker: String = node.get("properties", {}).get("speaker", "")
			var text: String = node.get("properties", {}).get("text", "")
			lines.append("%sprint(\"[%s] %s\")" % [indent, _esc(speaker), _esc(text)])
			var dlg_succs := _get_exec_successors_ordered(graph, node["id"])
			for succ in dlg_succs:
				compile_exec_chain(graph, succ, lines, indent, visited)
		"story_random":
			var prob: String = str(node.get("properties", {}).get("probability", 0.3))
			lines.append("%sif randf() < %s:" % [indent, prob])
			var rnd_succs := _get_exec_successors_ordered(graph, node["id"])
			for succ in rnd_succs:
				compile_exec_chain(graph, succ, lines, indent + "\t", visited)
		"story_unlock_lore":
			var lid: String = node.get("properties", {}).get("lore_id", "")
			lines.append("%sif not player_state.has(\"unlocked_lore\"): player_state[\"unlocked_lore\"] = []" % indent)
			lines.append("%splayer_state[\"unlocked_lore\"].append(\"%s\")" % [indent, _esc(lid)])
			var ul_succs := _get_exec_successors_ordered(graph, node["id"])
			for succ in ul_succs:
				compile_exec_chain(graph, succ, lines, indent, visited)
		"story_jump_chain":
			var cid: String = node.get("properties", {}).get("chain_id", "")
			var jeid: String = node.get("properties", {}).get("event_id", "")
			lines.append("%sworld_state.set_variable(\"current_chain\", \"%s\")" % [indent, _esc(cid)])
			lines.append("%sworld_state.set_variable(\"chain_jump_event\", \"%s\")" % [indent, _esc(jeid)])
			var jc_succs := _get_exec_successors_ordered(graph, node["id"])
			for succ in jc_succs:
				compile_exec_chain(graph, succ, lines, indent, visited)
		"story_causal_mark":
			var mark_id: String = node.get("properties", {}).get("mark_id", "")
			lines.append("%sevent_engine.causal_marks.append({\"id\": \"%s\", \"from_event\": \"\", \"intensity\": 1.0})" % [indent, _esc(mark_id)])
			var cm_succs := _get_exec_successors_ordered(graph, node["id"])
			for succ in cm_succs:
				compile_exec_chain(graph, succ, lines, indent, visited)
		"story_set_prereq", "story_add_condition", "story_add_consequence":
			lines.append("%s# %s（运行时由 BlueprintExecutor 修改事件数据）" % [indent, node_type])
			var md_succs := _get_exec_successors_ordered(graph, node["id"])
			for succ in md_succs:
				compile_exec_chain(graph, succ, lines, indent, visited)

# === 4. 世界势力 (world) ===

static func _handle_world(graph: Dictionary, node: Dictionary, node_type: String, lines: PackedStringArray, indent: String, visited: Dictionary) -> void:
	match node_type:
		"world_set_var":
			var vname: String = node.get("properties", {}).get("var_name", "")
			var value_expr := _resolve_data_input(graph, node["id"], 1)
			lines.append("%sworld_state.set_variable(\"%s\", %s)" % [indent, vname, value_expr])
			var succs := _get_exec_successors_ordered(graph, node["id"])
			for succ in succs:
				compile_exec_chain(graph, succ, lines, indent, visited)
		"world_advance_time":
			var hrs: String = str(node.get("properties", {}).get("hours", 1))
			lines.append("%sworld_state.advance_time(%s)" % [indent, hrs])
			var succs := _get_exec_successors_ordered(graph, node["id"])
			for succ in succs:
				compile_exec_chain(graph, succ, lines, indent, visited)
		"world_faction_relation":
			var fa: String = node.get("properties", {}).get("faction_a", "")
			var fb: String = node.get("properties", {}).get("faction_b", "")
			var delta: String = str(node.get("properties", {}).get("delta", 0.0))
			lines.append("%sworld_state.modify_faction_relationship(\"%s\", \"%s\", %s)" % [indent, fa, fb, delta])
			var succs := _get_exec_successors_ordered(graph, node["id"])
			for succ in succs:
				compile_exec_chain(graph, succ, lines, indent, visited)
		"world_modify_var":
			var mv_name: String = node.get("properties", {}).get("var_name", "")
			var mv_op: String = node.get("properties", {}).get("op", "+")
			var mv_val: String = str(node.get("properties", {}).get("value", 1))
			lines.append("%svar _cur: Variant = world_state.get_variable(\"%s\", 0)" % [indent, _esc(mv_name)])
			lines.append("%sworld_state.set_variable(\"%s\", float(_cur) %s %s)" % [indent, _esc(mv_name), _gds_op(mv_op), mv_val])
			var mv_succs := _get_exec_successors_ordered(graph, node["id"])
			for succ in mv_succs:
				compile_exec_chain(graph, succ, lines, indent, visited)
		"world_faction_power":
			var fp_fid: String = node.get("properties", {}).get("faction_id", "")
			var fp_delta: String = str(node.get("properties", {}).get("delta", 0))
			lines.append("%sworld_state.faction_states[\"%s\"][\"power_level\"] = int(world_state.faction_states[\"%s\"].get(\"power_level\", 50)) + %s" % [indent, _esc(fp_fid), _esc(fp_fid), fp_delta])
			var fp_succs := _get_exec_successors_ordered(graph, node["id"])
			for succ in fp_succs:
				compile_exec_chain(graph, succ, lines, indent, visited)
		"world_add_effect":
			var eff_id: String = node.get("properties", {}).get("effect_id", "")
			var eff_dur: String = str(node.get("properties", {}).get("duration", 5))
			lines.append("%sworld_state.add_effect(\"%s\", %s)" % [indent, _esc(eff_id), eff_dur])
			var eff_succs := _get_exec_successors_ordered(graph, node["id"])
			for succ in eff_succs:
				compile_exec_chain(graph, succ, lines, indent, visited)
		"world_explore_region":
			var ex_rid: String = node.get("properties", {}).get("region_id", "")
			lines.append("%sif not world_state.explored_regions.has(\"%s\"): world_state.explored_regions.append(\"%s\")" % [indent, _esc(ex_rid), _esc(ex_rid)])
			var ex_succs := _get_exec_successors_ordered(graph, node["id"])
			for succ in ex_succs:
				compile_exec_chain(graph, succ, lines, indent, visited)
		"world_switch_camp":
			var camp_fid: String = node.get("properties", {}).get("faction_id", "")
			lines.append("%splayer_state[\"faction\"] = \"%s\"" % [indent, _esc(camp_fid)])
			var camp_succs := _get_exec_successors_ordered(graph, node["id"])
			for succ in camp_succs:
				compile_exec_chain(graph, succ, lines, indent, visited)
		"world_update_region":
			var ur_rid: String = node.get("properties", {}).get("region_id", "")
			var ur_status: String = node.get("properties", {}).get("status", "explored")
			lines.append("%sworld_state.set_variable(\"region_%s_status\", \"%s\")" % [indent, _esc(ur_rid), _esc(ur_status)])
			var ur_succs := _get_exec_successors_ordered(graph, node["id"])
			for succ in ur_succs:
				compile_exec_chain(graph, succ, lines, indent, visited)

# === 5. 角色玩家 (player) ===

static func _handle_player(graph: Dictionary, node: Dictionary, node_type: String, lines: PackedStringArray, indent: String, visited: Dictionary) -> void:
	match node_type:
		"player_modify_stat":
			var stat: String = node.get("properties", {}).get("stat", "hp")
			var op: String = node.get("properties", {}).get("op", "+")
			var val: String = str(node.get("properties", {}).get("value", 0))
			if op == "set":
				lines.append("%splayer_state[\"%s\"] = %s" % [indent, stat, val])
			else:
				lines.append("%splayer_state[\"%s\"] = player_state.get(\"%s\", 0) %s %s" % [indent, stat, stat, op, val])
			var succs := _get_exec_successors_ordered(graph, node["id"])
			for succ in succs:
				compile_exec_chain(graph, succ, lines, indent, visited)
		"player_teleport":
			var rid: String = node.get("properties", {}).get("region_id", "")
			lines.append("%splayer_state[\"location\"] = {\"region\": \"%s\"}" % [indent, rid])
			var succs := _get_exec_successors_ordered(graph, node["id"])
			for succ in succs:
				compile_exec_chain(graph, succ, lines, indent, visited)
		"player_set_capacity":
			var cap: String = str(node.get("properties", {}).get("capacity", 50))
			lines.append("%splayer_state[\"inventory_capacity\"] = %s" % [indent, cap])
			var cap_succs := _get_exec_successors_ordered(graph, node["id"])
			for succ in cap_succs:
				compile_exec_chain(graph, succ, lines, indent, visited)
		"player_set_position":
			var px: String = str(node.get("properties", {}).get("x", 0))
			var py: String = str(node.get("properties", {}).get("y", 0))
			lines.append("%splayer_state[\"location\"] = {\"x\": %s, \"y\": %s}" % [indent, px, py])
			var pos_succs := _get_exec_successors_ordered(graph, node["id"])
			for succ in pos_succs:
				compile_exec_chain(graph, succ, lines, indent, visited)
		"player_level_exp":
			var mode: String = node.get("properties", {}).get("mode", "add_exp")
			var val: String = str(node.get("properties", {}).get("value", 0))
			match mode:
				"add_exp":
					lines.append("%splayer_state[\"exp\"] = int(player_state.get(\"exp\", 0)) + %s" % [indent, val])
				"set_level":
					lines.append("%splayer_state[\"level\"] = %s" % [indent, val])
				"add_level":
					lines.append("%splayer_state[\"level\"] = int(player_state.get(\"level\", 1)) + %s" % [indent, val])
			var lv_succs := _get_exec_successors_ordered(graph, node["id"])
			for succ in lv_succs:
				compile_exec_chain(graph, succ, lines, indent, visited)
		"player_causal_mark":
			var pmark: String = node.get("properties", {}).get("mark_id", "")
			lines.append("%sif not player_state.has(\"causal_marks\"): player_state[\"causal_marks\"] = []" % indent)
			lines.append("%splayer_state[\"causal_marks\"].append(\"%s\")" % [indent, _esc(pmark)])
			var pm_succs := _get_exec_successors_ordered(graph, node["id"])
			for succ in pm_succs:
				compile_exec_chain(graph, succ, lines, indent, visited)

# === 6. 战斗系统 (combat) ===

static func _handle_combat(graph: Dictionary, node: Dictionary, node_type: String, lines: PackedStringArray, indent: String, visited: Dictionary) -> void:
	match node_type:
		"combat_check_end":
			lines.append("%s# 判定战斗胜负" % indent)
			var vic_succs := _get_exec_successors_for_port(graph, node["id"], 0)
			var def_succs := _get_exec_successors_for_port(graph, node["id"], 1)
			var ong_succs := _get_exec_successors_for_port(graph, node["id"], 2)
			lines.append("%sif combat_result == \"victory\":" % indent)
			for succ in vic_succs:
				compile_exec_chain(graph, succ, lines, indent + "\t", visited)
			if not def_succs.is_empty():
				lines.append("%selif combat_result == \"defeat\":" % indent)
				for succ in def_succs:
					compile_exec_chain(graph, succ, lines, indent + "\t", visited)
			if not ong_succs.is_empty():
				lines.append("%selse:" % indent)
				for succ in ong_succs:
					compile_exec_chain(graph, succ, lines, indent + "\t", visited)
		"combat_flee":
			lines.append("%sif try_flee():" % indent)
			var s_succs := _get_exec_successors_for_port(graph, node["id"], 0)
			for succ in s_succs:
				compile_exec_chain(graph, succ, lines, indent + "\t", visited)
			var f_succs := _get_exec_successors_for_port(graph, node["id"], 1)
			if not f_succs.is_empty():
				lines.append("%selse:" % indent)
				for succ in f_succs:
					compile_exec_chain(graph, succ, lines, indent + "\t", visited)
		"combat_start":
			lines.append("%scombat_engine.start_combat()" % indent)
			var cs_succs := _get_exec_successors_ordered(graph, node["id"])
			for succ in cs_succs:
				compile_exec_chain(graph, succ, lines, indent, visited)
		"combat_spawn_enemy":
			var tpl: String = node.get("properties", {}).get("enemy_template", "")
			var ename: String = node.get("properties", {}).get("custom_name", "敌人")
			var hp: String = str(node.get("properties", {}).get("hp", 50))
			var atk: String = str(node.get("properties", {}).get("atk", 10))
			var def_v: String = str(node.get("properties", {}).get("def_val", 5))
			lines.append("%scombat_engine.add_enemy({\"name\": \"%s\", \"hp\": %s, \"max_hp\": %s, \"atk\": %s, \"def\": %s})" % [indent, _esc(ename), hp, hp, atk, def_v])
			var sp_succs := _get_exec_successors_ordered(graph, node["id"])
			for succ in sp_succs:
				compile_exec_chain(graph, succ, lines, indent, visited)
		"combat_damage":
			var d_target: String = node.get("properties", {}).get("target", "enemy_0")
			var d_amt: String = str(node.get("properties", {}).get("amount", 10))
			if d_target == "player":
				lines.append("%scombat_engine.player_combat_stats[\"hp\"] -= %s" % [indent, d_amt])
			else:
				lines.append("%scombat_engine.enemies[%s][\"hp\"] -= %s" % [indent, d_target.trim_prefix("enemy_"), d_amt])
			var dmg_succs := _get_exec_successors_ordered(graph, node["id"])
			for succ in dmg_succs:
				compile_exec_chain(graph, succ, lines, indent, visited)
		"combat_heal":
			var h_amt: String = str(node.get("properties", {}).get("amount", 20))
			lines.append("%scombat_engine.player_combat_stats[\"hp\"] = mini(combat_engine.player_combat_stats[\"hp\"] + %s, combat_engine.player_combat_stats[\"max_hp\"])" % [indent, h_amt])
			var heal_succs := _get_exec_successors_ordered(graph, node["id"])
			for succ in heal_succs:
				compile_exec_chain(graph, succ, lines, indent, visited)
		"combat_add_buff", "combat_remove_buff":
			var eff_id: String = node.get("properties", {}).get("effect_id", "")
			lines.append("%s# %s: %s（运行时由 BlueprintExecutor 处理状态效果）" % [indent, node_type, eff_id])
			var cb_succs := _get_exec_successors_ordered(graph, node["id"])
			for succ in cb_succs:
				compile_exec_chain(graph, succ, lines, indent, visited)
		"combat_reward":
			var r_exp: String = str(node.get("properties", {}).get("exp", 0))
			var r_gold: String = str(node.get("properties", {}).get("gold", 0))
			lines.append("%splayer_state[\"exp\"] = int(player_state.get(\"exp\", 0)) + %s" % [indent, r_exp])
			lines.append("%seconomy_engine.add_currency(\"gold\", %s)" % [indent, r_gold])
			var rw_succs := _get_exec_successors_ordered(graph, node["id"])
			for succ in rw_succs:
				compile_exec_chain(graph, succ, lines, indent, visited)
		"combat_set_stats":
			var st_target: String = node.get("properties", {}).get("target", "player")
			var st_hp: String = str(node.get("properties", {}).get("hp", -1))
			lines.append("%s# %s 属性设置 hp=%s（运行时由 BlueprintExecutor 处理）" % [indent, st_target, st_hp])
			var st_succs := _get_exec_successors_ordered(graph, node["id"])
			for succ in st_succs:
				compile_exec_chain(graph, succ, lines, indent, visited)

# === 7. 技能能力 (ability) ===

static func _handle_ability(graph: Dictionary, node: Dictionary, node_type: String, lines: PackedStringArray, indent: String, visited: Dictionary) -> void:
	match node_type:
		"ability_learn":
			var sid: String = node.get("properties", {}).get("skill_id", "")
			lines.append("%sif not player_state.has(\"skills\"): player_state[\"skills\"] = []" % indent)
			lines.append("%sif not player_state[\"skills\"].has(\"%s\"): player_state[\"skills\"].append(\"%s\")" % [indent, _esc(sid), _esc(sid)])
		"ability_upgrade":
			var sid: String = node.get("properties", {}).get("skill_id", "")
			lines.append("%sif not player_state.has(\"skill_levels\"): player_state[\"skill_levels\"] = {}" % indent)
			lines.append("%splayer_state[\"skill_levels\"][\"%s\"] = int(player_state[\"skill_levels\"].get(\"%s\", 1)) + 1" % [indent, _esc(sid), _esc(sid)])
		"ability_cast":
			var sid: String = node.get("properties", {}).get("skill_id", "")
			var tidx: String = str(node.get("properties", {}).get("target_idx", 0))
			lines.append("%scombat_engine.player_use_skill(\"%s\", %s)" % [indent, _esc(sid), tidx])
		"ability_consume":
			var rt: String = node.get("properties", {}).get("resource_type", "mana")
			var amt: String = str(node.get("properties", {}).get("amount", 0))
			lines.append("%splayer_state[\"%s\"] = int(player_state.get(\"%s\", 0)) - %s" % [indent, _esc(rt), _esc(rt), amt])
		"ability_give_buff", "ability_remove_buff":
			var eid: String = node.get("properties", {}).get("effect_id", "")
			lines.append("%s# %s: %s（运行时由 BlueprintExecutor 处理状态效果）" % [indent, node_type, eid])
		"ability_calc_damage", "ability_get_info":
			lines.append("%s# %s（数据源节点, 运行时由 BlueprintExecutor 求值）" % [indent, node_type])
		"ability_unlock_school":
			var school: String = node.get("properties", {}).get("school", "elemental_fire")
			lines.append("%sif not player_state.has(\"unlocked_schools\"): player_state[\"unlocked_schools\"] = []" % indent)
			lines.append("%sif not player_state[\"unlocked_schools\"].has(\"%s\"): player_state[\"unlocked_schools\"].append(\"%s\")" % [indent, _esc(school), _esc(school)])
		"ability_add_prereq":
			var sid: String = node.get("properties", {}).get("skill_id", "")
			var pre: String = node.get("properties", {}).get("prereq_skill_id", "")
			lines.append("%sif not player_state.has(\"skill_prereqs\"): player_state[\"skill_prereqs\"] = {}" % indent)
			lines.append("%splayer_state[\"skill_prereqs\"][\"%s\"] = \"%s\"" % [indent, _esc(sid), _esc(pre)])
	var succs := _get_exec_successors_ordered(graph, node["id"])
	for succ in succs:
		compile_exec_chain(graph, succ, lines, indent, visited)

# === 8. 任务系统 (quest) ===

static func _handle_quest(graph: Dictionary, node: Dictionary, node_type: String, lines: PackedStringArray, indent: String, visited: Dictionary) -> void:
	match node_type:
		"quest_accept":
			var qid: String = node.get("properties", {}).get("quest_id", "")
			lines.append("%squest_state[\"%s\"] = \"active\"" % [indent, _esc(qid)])
		"quest_update_objective":
			var qid: String = node.get("properties", {}).get("quest_id", "")
			var oidx: String = str(node.get("properties", {}).get("objective_idx", 0))
			var prog: String = str(node.get("properties", {}).get("progress", 1))
			lines.append("%sif quest_state.get(\"%s\", \"\") == \"active\": quest_progress[\"%s\"][%s] = int(quest_progress[\"%s\"].get(%s, 0)) + %s" % [indent, _esc(qid), _esc(qid), oidx, _esc(qid), oidx, prog])
		"quest_complete":
			var qid: String = node.get("properties", {}).get("quest_id", "")
			lines.append("%squest_state[\"%s\"] = \"completed\"" % [indent, _esc(qid)])
		"quest_fail":
			var qid: String = node.get("properties", {}).get("quest_id", "")
			lines.append("%squest_state[\"%s\"] = \"failed\"" % [indent, _esc(qid)])
		"quest_reward":
			var qid: String = node.get("properties", {}).get("quest_id", "")
			var r_exp: String = str(node.get("properties", {}).get("exp", 0))
			var r_gold: String = str(node.get("properties", {}).get("gold", 0))
			lines.append("%splayer_state[\"exp\"] = int(player_state.get(\"exp\", 0)) + %s" % [indent, r_exp])
			lines.append("%seconomy_engine.add_currency(\"gold\", %s)" % [indent, r_gold])
		"quest_add_objective":
			var qid: String = node.get("properties", {}).get("quest_id", "")
			lines.append("%s# 添加目标: %s（运行时由 BlueprintExecutor 处理）" % [indent, qid])
		"quest_check", "quest_track":
			lines.append("%s# %s（数据源/追踪节点, 运行时由 BlueprintExecutor 处理）" % [indent, node_type])
	var succs := _get_exec_successors_ordered(graph, node["id"])
	for succ in succs:
		compile_exec_chain(graph, succ, lines, indent, visited)

# === 7. 其他/通用 ===

static func _handle_other(graph: Dictionary, node: Dictionary, node_type: String, lines: PackedStringArray, indent: String, visited: Dictionary) -> void:
	# 注册表节点的通用编译: 生成注释+属性摘要
	var reg_def: Dictionary = BlueprintNodeRegistry.get_definition(node_type)
	if not reg_def.is_empty():
		lines.append("%s# %s (%s)" % [indent, reg_def["name"], node_type])
		var props: Dictionary = node.get("properties", {})
		for pk in props:
			if props[pk] != null and str(props[pk]) != "":
				lines.append("%s#   %s = %s" % [indent, pk, str(props[pk])])
	else:
		lines.append("%s# Unknown node: %s" % [indent, node_type])
	var succs := _get_exec_successors_ordered(graph, node["id"])
	for succ in succs:
		compile_exec_chain(graph, succ, lines, indent, visited)

# === 内部辅助 ===

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
				"get_var", "flow_get_var":
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

## 转义字符串中的引号
static func _esc(text: String) -> String:
	return text.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n")

## 操作符转 GDScript 符号（set 无对应二元操作符, 默认 +）
static func _gds_op(op: String) -> String:
	match op:
		"+": return "+"
		"-": return "-"
		"*": return "*"
		_ : return "+"
