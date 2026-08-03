## BlueprintNodeHandlers - 蓝图节点执行处理器（按 8 大分类拆分）
## 从 blueprint_executor.gd 的 _execute_node match 提取。
## 每个 handler 接收 ctx（BlueprintExecutor 实例, duck-typed）作为第一参数，
## 通过 ctx 访问引擎引用与辅助方法: ctx.economy_engine / ctx.world_state / ctx.combat_engine /
## ctx.event_engine / ctx.player_state / ctx.ws_data / ctx._variables / ctx._quest_state /
## ctx._quest_progress / ctx._log() / ctx._resolve_input_bool|string|float|variant()
## 返回: 应走的输出 exec 端口索引
class_name BlueprintNodeHandlers
extends RefCounted

## 基础流程节点（无前缀）
const BASE_FLOW_TYPES: Array[String] = [
	"start", "branch", "sequence", "print", "get_var", "set_var", "expression",
]

## 按前缀分发到对应分类处理器；无法识别返回 -1
static func dispatch(ctx, node_type: String) -> int:
	if node_type in BASE_FLOW_TYPES or node_type.begins_with("flow_"):
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
		return 7
	if node_type.begins_with("quest_"):
		return 8
	return -1

## 分类 -> 处理器映射（由 _execute_node 调用）
static func run(ctx, category: int, node: Dictionary, graph: Dictionary) -> int:
	match category:
		1: return handle_flow(ctx, node, graph)
		2: return handle_economy(ctx, node, graph)
		3: return handle_story(ctx, node, graph)
		4: return handle_world(ctx, node, graph)
		5: return handle_player(ctx, node, graph)
		6: return handle_combat(ctx, node, graph)
		7: return handle_ability(ctx, node, graph)
		8: return handle_quest(ctx, node, graph)
		_:
			ctx._last_error = "未实现的节点类型: %s" % node.get("node_type", "")
			ctx.halt("error", ctx._last_error)
			return 0

# === 1. 流程控制 (flow) ===

static func handle_flow(ctx, node: Dictionary, graph: Dictionary) -> int:
	var node_type: String = node["node_type"]
	var props: Dictionary = node.get("properties", {})
	match node_type:
		"start", "flow_start":
			ctx._log("info", "蓝图开始执行")
			return 0
		"branch", "flow_branch":
			var cond_val: bool = ctx._resolve_input_bool(graph, node, 1)
			return 0 if cond_val else 1
		"sequence", "flow_sequence":
			return 0  # 顺序执行第一个输出(简化)
		"flow_for_loop":
			# 循环: 首次进入读 count 建栈帧, 再次进入(循环回边)递减计数
			# 输出: 端口0=body(循环体), 端口1=done(循环结束)
			var count: int = int(ctx._resolve_input_float(graph, node, 1))
			if ctx._loop_frames.has(node["id"]):
				var frame: Dictionary = ctx._loop_frames[node["id"]]
				if frame["remaining"] > 0:
					frame["remaining"] = int(frame["remaining"]) - 1
					frame["index"] = int(frame["index"]) + 1
					ctx._log("info", "循环 %s 第 %d 次" % [node.get("title", "loop"), frame["index"]])
					return 0  # body
				ctx._loop_frames.erase(node["id"])
				ctx._log("info", "循环 %s 结束" % node.get("title", "loop"))
				return 1  # done
			# 首次进入
			if count > 0:
				ctx._loop_frames[node["id"]] = {"remaining": count - 1, "index": 0}
				ctx._log("info", "开始循环 %s (%d 次)" % [node.get("title", "loop"), count])
				return 0  # body
			ctx._log("info", "循环 %s 执行 0 次" % node.get("title", "loop"))
			return 1  # done
		"flow_print_log", "print":
			var msg: String = ctx._resolve_input_string(graph, node, 1)
			var level: String = props.get("level", "info")
			ctx._log(level, msg)
			return 0
		"flow_wait":
			ctx._log("info", "等待 %s 秒" % str(ctx._resolve_input_float(graph, node, 1)))
			return 0
		"flow_get_var", "get_var":
			return 0
		"flow_set_var", "set_var":
			var vname: String = props.get("var_name", "")
			var val = ctx._resolve_input_variant(graph, node, 1)
			ctx._variables[vname] = val
			if ctx.world_state:
				ctx.world_state.set_variable(vname, val)
			return 0
		"flow_expression", "expression":
			ctx._log("info", "表达式: %s" % props.get("code", ""))
			return 0

		"flow_random_select":
			var bc: int = int(props.get("branch_count", 2))
			var pick: int = randi() % 2  # 输出引脚固定 out_0/out_1
			ctx._log("info", "随机选择分支 %d (共 %d)" % [pick, maxi(bc, 2)])
			return pick
		"flow_sub_graph":
			var gkey: String = props.get("graph_id", "")
			if gkey == "":
				ctx._log("warn", "子蓝图未指定图 key")
				return 0
			var sub_result: Dictionary = ctx.execute_sub_graph(gkey)
			if not sub_result.get("success", false) and sub_result.get("error", "") != "":
				# 子图失败（不含暂停）: 记录错误; 暂停会向上传播由 _pending_choice 处理
				if sub_result.get("error", "") != "halted_by_choice":
					ctx._last_error = sub_result.get("error", "sub_graph_failed")
			ctx._log("info", "子图 %s 执行完成 (steps=%d)" % [gkey, sub_result.get("steps", 0)])
			return 0
	return 0

# === 2. 经济交易 (economy) ===

static func handle_economy(ctx, node: Dictionary, graph: Dictionary) -> int:
	var node_type: String = node["node_type"]
	var props: Dictionary = node.get("properties", {})
	match node_type:
		"eco_give_item":
			var item_id: String = props.get("item_id", "")
			var qty: int = int(props.get("quantity", 1))
			if ctx.economy_engine and item_id != "":
				ctx.economy_engine.add_item(item_id, qty)
				ctx._log("info", "获得物品 %s x%d" % [item_id, qty])
			return 0
		"eco_remove_item":
			var item_id: String = props.get("item_id", "")
			var qty: int = int(props.get("quantity", 1))
			if ctx.economy_engine and item_id != "":
				var ok: bool = ctx.economy_engine.remove_item(item_id, qty)
				ctx._log("info", "付出物品 %s x%d: %s" % [item_id, qty, "成功" if ok else "不足"])
			return 0
		"eco_give_currency":
			var cur_id: String = props.get("currency_id", "")
			var amount: int = int(props.get("amount", 0))
			if ctx.economy_engine and cur_id != "":
				ctx.economy_engine.add_currency(cur_id, amount)
				ctx._log("info", "获得货币 %s +%d" % [cur_id, amount])
			elif cur_id != "":
				if not ctx.player_state.has("player_currencies"):
					ctx.player_state["player_currencies"] = {}
				ctx.player_state["player_currencies"][cur_id] = int(ctx.player_state["player_currencies"].get(cur_id, 0)) + amount
				ctx._log("info", "获得货币 %s +%d" % [cur_id, amount])
			return 0
		"eco_spend_currency":
			var cur_id: String = props.get("currency_id", "")
			var amount: int = int(props.get("amount", 0))
			if ctx.economy_engine and cur_id != "":
				var have: int = int(ctx.economy_engine.player_currencies.get(cur_id, 0))
				if have >= amount:
					ctx.economy_engine.player_currencies[cur_id] -= amount
					ctx._log("info", "消耗货币 %s -%d" % [cur_id, amount])
				else:
					ctx._log("warn", "货币不足: %s 需要%d 拥有%d" % [cur_id, amount, have])
			return 0
		"eco_buy":
			var mid: String = props.get("market_id", "")
			var iid: String = props.get("item_id", "")
			var qty: int = int(props.get("quantity", 1))
			var cid: String = props.get("currency_id", "gold")
			if ctx.economy_engine:
				var ok: bool = ctx.economy_engine.buy(mid, iid, qty, cid)
				ctx._log("info", "市场购买 %s x%d: %s" % [iid, qty, "成功" if ok else "失败"])
			return 0
		"eco_sell":
			var mid: String = props.get("market_id", "")
			var iid: String = props.get("item_id", "")
			var qty: int = int(props.get("quantity", 1))
			var cid: String = props.get("currency_id", "gold")
			if ctx.economy_engine:
				var ok: bool = ctx.economy_engine.sell(mid, iid, qty, cid)
				ctx._log("info", "市场出售 %s x%d: %s" % [iid, qty, "成功" if ok else "失败"])
			return 0
		"eco_refresh_price":
			if ctx.economy_engine:
				ctx.economy_engine.update_market_prices()
				ctx._log("info", "刷新市场价格")
			return 0
		"eco_barter":
			var give_id: String = props.get("give_item", "")
			var give_qty: int = int(props.get("give_qty", 1))
			var get_id: String = props.get("get_item", "")
			var get_qty: int = int(props.get("get_qty", 1))
			if ctx.economy_engine:
				var ok: bool = ctx.economy_engine.remove_item(give_id, give_qty)
				if ok:
					ctx.economy_engine.add_item(get_id, get_qty)
					ctx._log("info", "以物易物: %s x%d -> %s x%d" % [give_id, give_qty, get_id, get_qty])
				else:
					ctx._log("warn", "以物易物失败: 物品不足")
			return 0

		"eco_adjust_supply":
			var mid: String = props.get("market_id", "")
			var iid: String = props.get("item_id", "")
			var delta: int = int(props.get("supply_delta", props.get("delta", 0)))
			if ctx.economy_engine and mid != "" and iid != "" and ctx.economy_engine.market_prices.has(mid) and ctx.economy_engine.market_prices[mid].has(iid):
				var price: float = float(ctx.economy_engine.market_prices[mid][iid])
				price *= (1.0 - 0.1 * delta) if delta > 0 else (1.0 + 0.1 * -delta)
				ctx.economy_engine.market_prices[mid][iid] = maxf(price, 0.1)
				ctx._log("info", "调整供需 %s/%s (delta=%d) -> 价格 %.1f" % [mid, iid, delta, price])
			return 0
		"eco_discount":
			var mid: String = props.get("market_id", "")
			var iid: String = props.get("item_id", "")
			var rate: float = float(props.get("discount_rate", props.get("rate", 0.2)))
			if ctx.economy_engine and mid != "" and iid != "" and ctx.economy_engine.market_prices.has(mid) and ctx.economy_engine.market_prices[mid].has(iid):
				ctx.economy_engine.market_prices[mid][iid] = maxf(float(ctx.economy_engine.market_prices[mid][iid]) * (1.0 - rate), 0.1)
				ctx._log("info", "折扣 %s/%s -%.0f%%" % [mid, iid, rate * 100])
			return 0
		"eco_set_trade_rule":
			var rule_key: String = props.get("rule_key", "barter_enabled")
			var rule_value: String = str(props.get("rule_value", "true"))
			if ctx.economy_engine and ctx.economy_engine.economy_data:
				if rule_value == "true" or rule_value == "false":
					ctx.economy_engine.economy_data.trade_rules[rule_key] = rule_value == "true"
				elif rule_value.is_valid_float():
					ctx.economy_engine.economy_data.trade_rules[rule_key] = rule_value.to_float()
				else:
					ctx.economy_engine.economy_data.trade_rules[rule_key] = rule_value
				ctx._log("info", "设置交易规则 %s = %s" % [rule_key, rule_value])
			return 0
	return 0

# === 3. 剧情事件 (story) ===

static func handle_story(ctx, node: Dictionary, graph: Dictionary) -> int:
	var node_type: String = node["node_type"]
	var props: Dictionary = node.get("properties", {})
	match node_type:
		"story_trigger":
			var eid: String = props.get("event_id", "")
			if ctx.event_engine and eid != "" and ctx.ws_data and ctx.ws_data.event_system:
				var ev: Dictionary = ctx.ws_data.event_system.get_story_event(eid)
				if not ev.is_empty():
					ctx.event_engine.trigger_event(ev)
					ctx._log("info", "触发事件: %s" % ev.get("name", eid))
				else:
					ctx._log("warn", "事件不存在: %s" % eid)
			return 0
		"story_record":
			var eid: String = props.get("event_id", "")
			if ctx.event_engine and eid != "":
				ctx.event_engine.triggered_ids[eid] = true
				ctx.event_engine.triggered_events.append({"event_id": eid, "triggered_at": "", "choice_made": "", "consequences_applied": []})
				ctx._log("info", "记录事件: %s" % eid)
			return 0
		"story_causal_mark":
			var mid: String = props.get("mark_id", "")
			var intensity: float = float(props.get("intensity", 1.0))
			if ctx.event_engine and mid != "":
				ctx.event_engine.causal_marks.append({"id": mid, "from_event": "", "intensity": intensity})
				ctx._log("info", "因果标记: %s (%.1f)" % [mid, intensity])
			return 0
		"story_choice":
			# 等待玩家输入: 记录待选选项与所在图（子图内暂停也能正确 resume）并暂停执行
			ctx._pending_choice = {
				"node_id": node["id"],
				"node_type": "story_choice",
				"graph": graph,
				"options": [
					props.get("choice_0_text", "选项A"),
					props.get("choice_1_text", "选项B"),
				],
			}
			ctx.halt("info", "等待玩家选择: [%s / %s]" % [props.get("choice_0_text", "A"), props.get("choice_1_text", "B")])
			return 0
		"story_branch":
			var cond_val: bool = ctx._resolve_input_bool(graph, node, 1)
			return 0 if cond_val else 1

		"story_dialog":
			var speaker: String = props.get("speaker", "")
			var text: String = props.get("text", "")
			ctx._log("dialog", "[%s] %s" % [speaker, text])
			return 0
		"story_jump_chain":
			var cid: String = props.get("chain_id", "")
			var eid: String = props.get("event_id", "")
			if ctx.world_state:
				ctx.world_state.set_variable("current_chain", cid)
				ctx.world_state.set_variable("chain_jump_event", eid)
			ctx._log("info", "跳转事件链 %s -> %s" % [cid, eid])
			return 0
		"story_random":
			var prob: float = float(props.get("probability", 0.3))
			if ctx.event_engine and randf() < prob:
				var rev: Dictionary = ctx.event_engine.check_random_events()
				if not rev.is_empty():
					ctx._log("info", "随机事件触发: %s" % rev.get("name", ""))
			return 0
		"story_set_prereq":
			var eid: String = props.get("event_id", "")
			var pre: String = props.get("prereq_event_id", "")
			if ctx.ws_data and ctx.ws_data.event_system and eid != "":
				var rev: Dictionary = ctx.ws_data.event_system.get_story_event(eid)
				if not rev.is_empty():
					rev["prerequisite"] = pre
					ctx._log("info", "事件 %s 前置设为 %s" % [eid, pre])
			return 0
		"story_add_condition":
			var eid: String = props.get("event_id", "")
			var cond_type: String = props.get("condition_type", "player_state")
			var cond_check: String = props.get("condition_check", "")
			if ctx.ws_data and ctx.ws_data.event_system and eid != "":
				var rev: Dictionary = ctx.ws_data.event_system.get_story_event(eid)
				if not rev.is_empty():
					if not rev.has("conditions"):
						rev["conditions"] = []
					rev["conditions"].append({"type": cond_type, "check": cond_check})
					ctx._log("info", "事件 %s 添加条件: %s" % [eid, cond_check])
			return 0
		"story_add_consequence":
			var eid: String = props.get("event_id", "")
			var choice_text: String = props.get("choice_text", "")
			var target: String = props.get("target", "player")
			var effect: String = props.get("effect", "")
			if ctx.ws_data and ctx.ws_data.event_system and eid != "":
				var rev: Dictionary = ctx.ws_data.event_system.get_story_event(eid)
				if not rev.is_empty():
					for ch in rev.get("choices", []):
						if ch.get("text", "") == choice_text:
							if not ch.has("consequences"):
								ch["consequences"] = []
							ch["consequences"].append({"target": target, "effect": effect})
							break
					ctx._log("info", "事件 %s 选项 %s 添加后果" % [eid, choice_text])
			return 0
		"story_unlock_lore":
			var lid: String = props.get("lore_id", "")
			if lid != "":
				if not ctx.player_state.has("unlocked_lore"):
					ctx.player_state["unlocked_lore"] = []
				if not ctx.player_state["unlocked_lore"].has(lid):
					ctx.player_state["unlocked_lore"].append(lid)
					ctx._log("info", "解锁知识: %s" % lid)
			return 0
	return 0

# === 4. 世界势力 (world) ===

static func handle_world(ctx, node: Dictionary, graph: Dictionary) -> int:
	var node_type: String = node["node_type"]
	var props: Dictionary = node.get("properties", {})
	match node_type:
		"world_set_var":
			var vname: String = props.get("var_name", "")
			var val = ctx._resolve_input_variant(graph, node, 1)
			if ctx.world_state and vname != "":
				ctx.world_state.set_variable(vname, val)
				ctx._log("info", "设置世界变量: %s = %s" % [vname, str(val)])
			return 0
		"world_modify_var":
			var vname: String = props.get("var_name", "")
			var op: String = props.get("op", "+")
			var val_str: String = props.get("value", "1")
			if ctx.world_state and vname != "":
				var cur = ctx.world_state.get_variable(vname, 0)
				var num_val: float = float(val_str) if val_str.is_valid_float() else 0.0
				var cur_num: float = float(cur) if str(cur).is_valid_float() else 0.0
				var result_val: float = cur_num
				match op:
					"+": result_val = cur_num + num_val
					"-": result_val = cur_num - num_val
					"*": result_val = cur_num * num_val
					"set": result_val = num_val
				ctx.world_state.set_variable(vname, result_val)
				ctx._log("info", "修改世界变量: %s %s %s = %s" % [vname, op, val_str, str(result_val)])
			return 0
		"world_faction_power":
			var fid: String = props.get("faction_id", "")
			var delta: int = int(props.get("delta", 0))
			if ctx.world_state and fid != "" and ctx.world_state.faction_states.has(fid):
				ctx.world_state.faction_states[fid]["power_level"] = int(ctx.world_state.faction_states[fid].get("power_level", 50)) + delta
				ctx._log("info", "势力 %s 实力 %s%d" % [fid, "+" if delta >= 0 else "", delta])
			return 0
		"world_faction_relation":
			var fa: String = props.get("faction_a", "")
			var fb: String = props.get("faction_b", "")
			var delta: float = float(props.get("delta", 0.0))
			if ctx.world_state and fa != "" and fb != "":
				ctx.world_state.modify_faction_relationship(fa, fb, delta)
				ctx._log("info", "势力关系 %s <-> %s: %s%.2f" % [fa, fb, "+" if delta >= 0 else "", delta])
			return 0
		"world_advance_time":
			var hours: int = int(props.get("hours", 1))
			if ctx.world_state:
				ctx.world_state.advance_time(hours)
				ctx._log("info", "推进时间 %d 小时 -> %s" % [hours, ctx.world_state.get_time_display()])
			return 0
		"world_add_effect":
			var eid: String = props.get("effect_id", "")
			var dur: int = int(props.get("duration", 5))
			if ctx.world_state and eid != "":
				ctx.world_state.add_effect(eid, dur)
				ctx._log("info", "添加世界效果: %s (%d回合)" % [eid, dur])
			return 0
		"world_explore_region":
			var rid: String = props.get("region_id", "")
			if ctx.world_state and rid != "" and not ctx.world_state.explored_regions.has(rid):
				ctx.world_state.explored_regions.append(rid)
				ctx._log("info", "探索区域: %s" % rid)
			return 0

		"world_switch_camp":
			var fid: String = props.get("faction_id", "")
			if fid != "":
				ctx.player_state["faction"] = fid
				ctx._log("info", "切换阵营: %s" % fid)
			return 0
		"world_update_region":
			var rid: String = props.get("region_id", "")
			var status: String = props.get("status", "explored")
			if ctx.world_state and rid != "":
				ctx.world_state.set_variable("region_%s_status" % rid, status)
				ctx._log("info", "更新区域 %s -> %s" % [rid, status])
			return 0
	return 0

# === 5. 角色玩家 (player) ===

static func handle_player(ctx, node: Dictionary, graph: Dictionary) -> int:
	var node_type: String = node["node_type"]
	var props: Dictionary = node.get("properties", {})
	match node_type:
		"player_modify_stat":
			var stat: String = props.get("stat", "hp")
			var op: String = props.get("op", "+")
			var val: int = int(props.get("value", 0))
			var cur: int = int(ctx.player_state.get(stat, 0))
			match op:
				"+": ctx.player_state[stat] = cur + val
				"-": ctx.player_state[stat] = cur - val
				"set": ctx.player_state[stat] = val
			ctx._log("info", "玩家属性 %s %s%d -> %s" % [stat, op, val, str(ctx.player_state[stat])])
			return 0
		"player_give_item":
			var iid: String = props.get("item_id", "")
			var qty: int = int(props.get("quantity", 1))
			if ctx.economy_engine and iid != "":
				ctx.economy_engine.add_item(iid, qty)
				ctx._log("info", "玩家获得 %s x%d" % [iid, qty])
			return 0
		"player_remove_item":
			var iid: String = props.get("item_id", "")
			var qty: int = int(props.get("quantity", 1))
			if ctx.economy_engine and iid != "":
				ctx.economy_engine.remove_item(iid, qty)
				ctx._log("info", "玩家移除 %s x%d" % [iid, qty])
			return 0
		"player_teleport":
			var rid: String = props.get("region_id", "")
			if rid != "":
				if not ctx.player_state.has("location"):
					ctx.player_state["location"] = {}
				ctx.player_state["location"]["region"] = rid
				ctx._log("info", "传送到: %s" % rid)
			return 0
		"player_level_exp":
			var mode: String = props.get("mode", "add_exp")
			var val: int = int(props.get("value", 0))
			match mode:
				"add_exp":
					ctx.player_state["exp"] = int(ctx.player_state.get("exp", 0)) + val
					ctx._log("info", "经验 +%d -> %d" % [val, ctx.player_state["exp"]])
				"set_level":
					ctx.player_state["level"] = val
					ctx._log("info", "等级设为 %d" % val)
				"add_level":
					ctx.player_state["level"] = int(ctx.player_state.get("level", 1)) + val
					ctx._log("info", "等级 +%d -> %d" % [val, ctx.player_state["level"]])
			return 0

		"player_causal_mark":
			var mid: String = props.get("mark_id", "")
			if mid != "":
				if not ctx.player_state.has("causal_marks"):
					ctx.player_state["causal_marks"] = []
				ctx.player_state["causal_marks"].append(mid)
				ctx._log("info", "玩家因果标记: %s" % mid)
			return 0
		"player_set_capacity":
			var cap: int = int(props.get("capacity", 50))
			ctx.player_state["inventory_capacity"] = cap
			ctx._log("info", "背包容量设为 %d" % cap)
			return 0
		"player_set_position":
			var px: int = int(props.get("x", 0))
			var py: int = int(props.get("y", 0))
			if not ctx.player_state.has("location"):
				ctx.player_state["location"] = {}
			ctx.player_state["location"]["x"] = px
			ctx.player_state["location"]["y"] = py
			ctx._log("info", "玩家位置设为 (%d, %d)" % [px, py])
			return 0
	return 0

# === 6. 战斗系统 (combat) ===

static func handle_combat(ctx, node: Dictionary, graph: Dictionary) -> int:
	var node_type: String = node["node_type"]
	var props: Dictionary = node.get("properties", {})
	match node_type:
		"combat_spawn_enemy":
			if ctx.combat_engine:
				var tpl: String = props.get("enemy_template", "")
				var ename: String = props.get("custom_name", "")
				var hp: int = int(props.get("hp", 50))
				var atk: int = int(props.get("atk", 10))
				var def_v: int = int(props.get("def_val", 5))
				var elem: String = props.get("element", "")
				# 如果有模板, 从数据读取
				if tpl != "" and ctx.ws_data and ctx.ws_data.combat_system:
					var t: Dictionary = ctx.ws_data.combat_system.get_enemy_template(tpl)
					if not t.is_empty():
						ename = ename if ename != "" else t.get("name", "敌人")
						hp = t.get("hp", hp)
						atk = t.get("atk", atk)
						def_v = t.get("def", def_v)
						elem = t.get("element", elem)
				if ename == "":
					ename = "敌人"
				ctx.combat_engine.add_enemy({"name": ename, "hp": hp, "max_hp": hp, "atk": atk, "def": def_v, "element": elem})
				ctx._log("info", "生成敌人: %s (HP:%d)" % [ename, hp])
			return 0
		"combat_start":
			if ctx.combat_engine:
				ctx.combat_engine.start_combat()
				ctx._log("info", "战斗开始!")
			return 0
		"combat_damage":
			var target: String = props.get("target", "enemy_0")
			var amount: int = int(props.get("amount", 10))
			if ctx.combat_engine:
				if target == "player":
					ctx.combat_engine.player_combat_stats["hp"] -= amount
					ctx._log("info", "玩家受到 %d 伤害" % amount)
				elif target.begins_with("enemy_"):
					var idx: int = int(target.trim_prefix("enemy_"))
					if idx < ctx.combat_engine.enemies.size():
						ctx.combat_engine.enemies[idx]["hp"] -= amount
						ctx._log("info", "%s 受到 %d 伤害" % [ctx.combat_engine.enemies[idx].get("name", "敌人"), amount])
			return 0
		"combat_heal":
			var target: String = props.get("target", "player")
			var amount: int = int(props.get("amount", 20))
			if ctx.combat_engine:
				if target == "player":
					ctx.combat_engine.player_combat_stats["hp"] = mini(ctx.combat_engine.player_combat_stats["hp"] + amount, ctx.combat_engine.player_combat_stats["max_hp"])
					ctx._log("info", "玩家恢复 %d 生命" % amount)
			return 0
		"combat_check_end":
			if ctx.combat_engine:
				if ctx.combat_engine.player_combat_stats.get("hp", 0) <= 0:
					ctx._log("info", "战斗失败")
					return 1  # defeat
				var all_dead: bool = true
				for e in ctx.combat_engine.enemies:
					if e.get("is_alive", true):
						all_dead = false
						break
				if all_dead and not ctx.combat_engine.enemies.is_empty():
					ctx._log("info", "战斗胜利!")
					return 0  # victory
			return 2  # ongoing
		"combat_reward":
			var exp_r: int = int(props.get("exp", 0))
			var gold_r: int = int(props.get("gold", 0))
			ctx.player_state["exp"] = int(ctx.player_state.get("exp", 0)) + exp_r
			if ctx.economy_engine:
				ctx.economy_engine.add_currency("gold", gold_r)
			var iid: String = props.get("item_id", "")
			var iqty: int = int(props.get("item_qty", 0))
			if iid != "" and iqty > 0 and ctx.economy_engine:
				ctx.economy_engine.add_item(iid, iqty)
			ctx._log("info", "战斗奖励: 经验+%d 金币+%d" % [exp_r, gold_r])
			return 0
		"combat_flee":
			var chance: float = float(props.get("base_chance", 0.5))
			if randf() < chance:
				ctx._log("info", "逃跑成功!")
				return 0
			ctx._log("info", "逃跑失败!")
			return 1

		"combat_add_buff":
			var eid: String = props.get("effect_id", "")
			var dur: int = int(props.get("duration", 3))
			var target: String = props.get("target", "player")
			if ctx.combat_engine and eid != "":
				var target_stats: Dictionary = ctx.combat_engine.player_combat_stats
				if target.begins_with("enemy_"):
					var idx: int = int(target.trim_prefix("enemy_"))
					if idx < ctx.combat_engine.enemies.size():
						target_stats = ctx.combat_engine.enemies[idx]
				if not target_stats.has("status_effects"):
					target_stats["status_effects"] = []
				target_stats["status_effects"].append({"id": eid, "remaining_turns": dur, "damage_per_tick": 0})
				ctx._log("info", "施加状态 %s 到 %s (%d回合)" % [eid, target, dur])
			return 0
		"combat_remove_buff":
			var eid: String = props.get("effect_id", "")
			var target: String = props.get("target", "player")
			if ctx.combat_engine and eid != "":
				var target_stats: Dictionary = ctx.combat_engine.player_combat_stats
				if target.begins_with("enemy_"):
					var idx: int = int(target.trim_prefix("enemy_"))
					if idx < ctx.combat_engine.enemies.size():
						target_stats = ctx.combat_engine.enemies[idx]
				if target_stats.has("status_effects"):
					for i in range(target_stats["status_effects"].size() - 1, -1, -1):
						if target_stats["status_effects"][i].get("id", "") == eid:
							target_stats["status_effects"].remove_at(i)
				ctx._log("info", "移除状态 %s 从 %s" % [eid, target])
			return 0
		"combat_set_stats":
			var target: String = props.get("target", "player")
			var hp_v: int = int(props.get("hp", -1))
			var atk_v: int = int(props.get("atk", -1))
			var def_v: int = int(props.get("def", -1))
			if ctx.combat_engine:
				var ts: Dictionary = ctx.combat_engine.player_combat_stats
				if target.begins_with("enemy_"):
					var idx: int = int(target.trim_prefix("enemy_"))
					if idx < ctx.combat_engine.enemies.size():
						ts = ctx.combat_engine.enemies[idx]
				if hp_v >= 0:
					ts["hp"] = hp_v
				if atk_v >= 0:
					ts["atk"] = atk_v
				if def_v >= 0:
					ts["def"] = def_v
				ctx._log("info", "设置 %s 属性 hp=%s atk=%s def=%s" % [target, ts.get("hp"), ts.get("atk"), ts.get("def")])
			return 0
	return 0

# === 7. 技能能力 (ability) ===

static func handle_ability(ctx, node: Dictionary, graph: Dictionary) -> int:
	var node_type: String = node["node_type"]
	var props: Dictionary = node.get("properties", {})
	match node_type:
		"ability_learn":
			var sid: String = props.get("skill_id", "")
			if sid != "":
				if not ctx.player_state.has("skills"):
					ctx.player_state["skills"] = []
				if not ctx.player_state["skills"].has(sid):
					ctx.player_state["skills"].append(sid)
					ctx._log("info", "学习技能: %s" % sid)
			return 0
		"ability_cast":
			var sid: String = props.get("skill_id", "")
			var tidx: int = int(props.get("target_idx", 0))
			if ctx.combat_engine and sid != "":
				ctx.combat_engine.player_use_skill(sid, tidx)
				ctx._log("info", "施放技能: %s" % sid)
			return 0
		"ability_give_buff":
			var eid: String = props.get("effect_id", "")
			var dur: int = int(props.get("duration", 3))
			if ctx.combat_engine and eid != "":
				var target_stats: Dictionary = ctx.combat_engine.player_combat_stats
				if props.get("target", "self") == "enemy" and not ctx.combat_engine.enemies.is_empty():
					target_stats = ctx.combat_engine.enemies[0]
				if not target_stats.has("status_effects"):
					target_stats["status_effects"] = []
				target_stats["status_effects"].append({"id": eid, "remaining_turns": dur, "damage_per_tick": 0})
				ctx._log("info", "施加状态: %s (%d回合)" % [eid, dur])
			return 0

		"ability_consume":
			var rt: String = props.get("resource_type", "mana")
			var amount: int = int(props.get("amount", 0))
			ctx.player_state[rt] = int(ctx.player_state.get(rt, 0)) - amount
			ctx._log("info", "消耗 %s %d -> %d" % [rt, amount, ctx.player_state[rt]])
			return 0
		"ability_upgrade":
			var sid: String = props.get("skill_id", "")
			if sid != "":
				if not ctx.player_state.has("skill_levels"):
					ctx.player_state["skill_levels"] = {}
				ctx.player_state["skill_levels"][sid] = int(ctx.player_state["skill_levels"].get(sid, 1)) + 1
				ctx._log("info", "技能 %s 升级 -> Lv%d" % [sid, ctx.player_state["skill_levels"][sid]])
			return 0
		"ability_remove_buff":
			var eid: String = props.get("effect_id", "")
			if ctx.combat_engine and eid != "" and ctx.combat_engine.player_combat_stats.has("status_effects"):
				for i in range(ctx.combat_engine.player_combat_stats["status_effects"].size() - 1, -1, -1):
					if ctx.combat_engine.player_combat_stats["status_effects"][i].get("id", "") == eid:
						ctx.combat_engine.player_combat_stats["status_effects"].remove_at(i)
			if eid != "":
				ctx._log("info", "移除状态效果: %s" % eid)
			return 0
		"ability_unlock_school":
			var school: String = props.get("school", "elemental_fire")
			if not ctx.player_state.has("unlocked_schools"):
				ctx.player_state["unlocked_schools"] = []
			if not ctx.player_state["unlocked_schools"].has(school):
				ctx.player_state["unlocked_schools"].append(school)
				ctx._log("info", "解锁学派: %s" % school)
			return 0
		"ability_add_prereq":
			var sid: String = props.get("skill_id", "")
			var pre: String = props.get("prereq_skill_id", "")
			if sid != "":
				if not ctx.player_state.has("skill_prereqs"):
					ctx.player_state["skill_prereqs"] = {}
				ctx.player_state["skill_prereqs"][sid] = pre
				ctx._log("info", "技能 %s 前置设为 %s" % [sid, pre])
			return 0
	return 0

# === 8. 任务系统 (quest) ===

static func handle_quest(ctx, node: Dictionary, graph: Dictionary) -> int:
	var node_type: String = node["node_type"]
	var props: Dictionary = node.get("properties", {})
	match node_type:
		"quest_accept":
			var qid: String = props.get("quest_id", "")
			if qid != "":
				ctx._quest_state[qid] = "active"
				ctx._quest_progress[qid] = {}
				ctx._log("info", "接取任务: %s" % qid)
			return 0
		"quest_update_objective":
			var qid: String = props.get("quest_id", "")
			var oidx: int = int(props.get("objective_idx", 0))
			var prog: int = int(props.get("progress", 1))
			if qid != "" and ctx._quest_state.get(qid, "") == "active":
				if not ctx._quest_progress.has(qid):
					ctx._quest_progress[qid] = {}
				ctx._quest_progress[qid][oidx] = int(ctx._quest_progress[qid].get(oidx, 0)) + prog
				ctx._log("info", "任务 %s 目标%d 进度+%d" % [qid, oidx, prog])
			return 0
		"quest_complete":
			var qid: String = props.get("quest_id", "")
			if qid != "":
				ctx._quest_state[qid] = "completed"
				ctx._log("info", "完成任务: %s" % qid)
			return 0
		"quest_fail":
			var qid: String = props.get("quest_id", "")
			if qid != "":
				ctx._quest_state[qid] = "failed"
				ctx._log("info", "任务失败: %s" % qid)
			return 0
		"quest_reward":
			var qid: String = props.get("quest_id", "")
			var exp_r: int = int(props.get("exp", 0))
			var gold_r: int = int(props.get("gold", 0))
			ctx.player_state["exp"] = int(ctx.player_state.get("exp", 0)) + exp_r
			if ctx.economy_engine and gold_r > 0:
				ctx.economy_engine.add_currency("gold", gold_r)
			ctx._log("info", "任务奖励: %s (经验+%d 金币+%d)" % [qid, exp_r, gold_r])
			return 0

		"quest_add_objective":
			var qid: String = props.get("quest_id", "")
			var desc: String = props.get("description", "")
			var target_type: String = props.get("target_type", "kill")
			var target_id: String = props.get("target_id", "")
			var req_count: int = int(props.get("required_count", 1))
			if qid != "" and ctx._quest_state.get(qid, "") == "active":
				if not ctx._quest_progress.has(qid):
					ctx._quest_progress[qid] = {}
				ctx._quest_progress[qid][ctx._quest_progress[qid].size()] = {"desc": desc, "type": target_type, "target": target_id, "required": req_count, "current": 0}
				ctx._log("info", "任务 %s 添加目标: %s" % [qid, desc])
			return 0
		"quest_track":
			var qid: String = props.get("quest_id", "")
			ctx._quest_state["tracked"] = qid
			ctx._log("info", "追踪任务: %s" % qid)
			return 0
	return 0
