## 临时验证脚本: 蓝图新增节点执行语义测试
extends SceneTree

func _initialize() -> void:
	var exe = load("res://scripts/player/blueprint_executor.gd").new()
	var ws := WorldScriptData.new()
	ws.ensure_subsystems()
	ws.ability_system.add_skill_simple("sk_fire", "火球术", "active", "elemental", "fire", "", 10, "2s", "damage", 50)
	var eco := EcoStub.new()
	var ws_state := WSStub.new()
	var combat := CombatStub.new()
	exe.init_engines(null, eco, combat, ws_state, {"hp": 100, "mana": 30, "atk": 20}, ws)

	# === 各新增节点逐一执行 ===
	var cases: Array = [
		["ability_consume", {"resource_type": "mana", "amount": 5}, func(ctx):
			assert(ctx.player_state.get("mana") == 25)],
		["ability_upgrade", {"skill_id": "sk_fire"}, func(ctx):
			assert(ctx.player_state.get("skill_levels", {}).get("sk_fire") == 2)],
		["ability_unlock_school", {"school": "elemental_fire"}, func(ctx):
			assert(ctx.player_state.get("unlocked_schools", []).has("elemental_fire"))],
		["ability_add_prereq", {"skill_id": "sk_fire", "prereq_skill_id": "sk_0"}, func(ctx):
			assert(ctx.player_state.get("skill_prereqs", {}).get("sk_fire") == "sk_0")],
		["player_set_capacity", {"capacity": 80}, func(ctx):
			assert(ctx.player_state.get("inventory_capacity") == 80)],
		["player_set_position", {"x": 10, "y": 20}, func(ctx):
			assert(ctx.player_state.get("location", {}).get("x") == 10)],
		["player_causal_mark", {"mark_id": "mark_1"}, func(ctx):
			assert(ctx.player_state.get("causal_marks", []).has("mark_1"))],
		["world_switch_camp", {"faction_id": "f2"}, func(ctx):
			assert(ctx.player_state.get("faction") == "f2")],
		["world_update_region", {"region_id": "r1", "status": "danger"}, func(ctx):
			assert(ws_state.vars.get("region_r1_status") == "danger")],
		["eco_adjust_supply", {"market_id": "m1", "item_id": "sword", "supply_delta": 2}, func(ctx):
			assert(eco.market_prices["m1"]["sword"] < 10.0)],
		["eco_discount", {"market_id": "m1", "item_id": "sword", "discount_rate": 0.5}, func(ctx):
			assert(eco.market_prices["m1"]["sword"] < 5.0)],
		["eco_set_trade_rule", {"rule_key": "barter_enabled", "rule_value": "false"}, func(ctx):
			assert(ctx.economy_engine.economy_data.trade_rules.get("barter_enabled") == false)],
		["story_dialog", {"speaker": "商人", "text": "欢迎光临"}, func(ctx):
			assert(true)],
		["story_unlock_lore", {"lore_id": "l1"}, func(ctx):
			assert(ctx.player_state.get("unlocked_lore", []).has("l1"))],
		["quest_track", {"quest_id": "q1"}, func(ctx):
			assert(ctx._quest_state.get("tracked") == "q1")],
		["quest_add_objective", {"quest_id": "q1", "description": "杀怪", "required_count": 3}, func(ctx):
			assert(true)],  # 未激活任务无副作用, 仅验证可执行
		["combat_set_stats", {"target": "player", "hp": 55}, func(ctx):
			assert(ctx.combat_engine == null or ctx.combat_engine.player_combat_stats.get("hp") == 55)],
		["flow_random_select", {}, func(ctx):
			assert(true)],
	]
	for c in cases:
		var ntype: String = c[0]
		var props: Dictionary = c[1]
		var verify: Callable = c[2]
		var g := BlueprintData.make_graph()
		var start := BlueprintData.create_node("start", Vector2(0, 0))
		start["id"] = "start_%s" % ntype.replace("_", "")
		var node := BlueprintData.create_node(ntype, Vector2(200, 0))
		node["id"] = "node_%s" % ntype.replace("_", "")
		if not node.has("properties"):
			node["properties"] = {}
		for k in props:
			node["properties"][k] = props[k]
		g["nodes"][start["id"]] = start
		g["nodes"][node["id"]] = node
		BlueprintData.add_connection(g, start["id"], 0, node["id"], 0, true)
		var r: Dictionary = exe.execute_graph(g)
		assert(r.get("success", false))
		verify.call(exe)
	print("PASS 18 new node types execute")

	# 数据源 ability_calc_damage
	var g2 := BlueprintData.make_graph()
	var s2 := BlueprintData.create_node("start", Vector2(0, 0))
	s2["id"] = "s2"
	var sv := BlueprintData.create_node("set_var", Vector2(200, 0))
	sv["id"] = "sv"
	sv["properties"]["var_name"] = "dmg"
	var calc := BlueprintData.create_node("ability_calc_damage", Vector2(400, 0))
	calc["id"] = "calc"
	calc["properties"]["skill_id"] = "sk_fire"
	g2["nodes"][s2["id"]] = s2
	g2["nodes"][sv["id"]] = sv
	g2["nodes"][calc["id"]] = calc
	BlueprintData.add_connection(g2, s2["id"], 0, sv["id"], 0, true)
	BlueprintData.add_connection(g2, calc["id"], 0, sv["id"], 1, false)  # 数据连线
	var r2: Dictionary = exe.execute_graph(g2)
	assert(r2.get("success", false))
	assert(exe._variables.get("dmg") == 60.0)
	print("PASS ability_calc_damage data source")

	print("ALL_TESTS_PASSED")
	quit(0)

class EcoStub:
	var economy_data = null
	var market_prices: Dictionary = {"m1": {"sword": 10.0}}
	var player_currencies: Dictionary = {"gold": 100}
	func _init():
		economy_data = EconomySystemData.new()
		economy_data.trade_rules = {"barter_enabled": true, "barter_rate": 0.8}
	func add_item(_i: String, _q: int = 1) -> void: pass
	func remove_item(_i: String, _q: int = 1) -> bool: return true
	func add_currency(_c: String, _a: int) -> void: pass
	func buy(_m: String, _i: String, _q: int, _c: String) -> bool: return true
	func sell(_m: String, _i: String, _q: int, _c: String) -> bool: return true
	func update_market_prices() -> void: pass
	func get_price(_m: String, _i: String) -> float: return 10.0

class WSStub:
	var vars: Dictionary = {}
	func set_variable(k: String, v) -> void:
		vars[k] = v
	func get_variable(k: String, d = null):
		return vars.get(k, d)
	func advance_time(_h: int) -> void: pass
	func get_time_display() -> String: return "第1天"
	func modify_faction_relationship(_a: String, _b: String, _d: float) -> void: pass
	func add_effect(_e: String, _d: int, _data: Dictionary = {}) -> void: pass

class CombatStub:
	var player_combat_stats: Dictionary = {"hp": 50, "max_hp": 100, "atk": 20, "def": 5}
	var enemies: Array = []
	func start_combat() -> void: pass
	func add_enemy(_e: Dictionary) -> void: enemies.append(_e)
	func player_use_skill(_s: String, _t: int = 0) -> void: pass
