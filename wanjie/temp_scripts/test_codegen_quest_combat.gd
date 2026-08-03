## 临时验证脚本: ScriptCodeGen quest/combat 双向转译测试
extends SceneTree

func _initialize() -> void:
	var ws := WorldScriptData.new()
	ws.name = "测试剧本"
	ws.ensure_subsystems()
	var qs = ws.quest_system
	qs.add_quest("q1", "主线任务", "main", "任务描述")
	qs.add_objective("q1", "击杀5只史莱姆", "kill", "slime", 5)
	qs.set_rewards("q1", 100, 50, [{"id": "sword", "qty": 1}], ["q2"])
	qs.add_quest("q2", "支线任务", "side")
	qs.quests[1]["prerequisites"] = ["q1"]
	qs.quests[1]["time_limit"] = 3600
	qs.quests[1]["repeatable"] = true
	qs.add_quest_chain("chain1", "主线链", ["q1", "q2"], "链描述")
	var cs = ws.combat_system
	cs.add_enemy_template("e1", "史莱姆", 50, 10, 5, "water")
	cs.enemy_templates[0]["speed"] = 6
	cs.enemy_templates[0]["skills"] = ["tackle"]
	cs.enemy_templates[0]["loot"] = [{"item_id": "gel", "chance": 0.5, "qty": 2}]
	cs.enemy_templates[0]["description"] = "软软的怪物"
	cs.add_npc("n1", "商人", "merchant", "小镇", "商会")
	cs.npc_pool[0]["disposition"] = "friendly"
	cs.npc_pool[0]["dialog_id"] = "d1"
	cs.add_battle_config("b1", "新手遭遇", ["e1"], true)
	cs.battle_configs[0]["rewards"] = {"exp": 50, "gold": 20, "items": [{"id": "potion", "qty": 1}]}
	cs.battle_configs[0]["terrain"] = "forest"

	# generate
	var ScriptCodeGenClass = load("res://scripts/editor/script_codegen.gd")
	var code: String = ScriptCodeGenClass.generate(ws)
	assert(code.find("func quest(\"q1\", \"主线任务\", \"main\"):") >= 0)
	assert(code.find("\tobjective(\"击杀5只史莱姆\", \"kill\", \"slime\", 5)") >= 0)
	assert(code.find("\treward(100, 50)") >= 0)
	assert(code.find("\tunlock(\"q2\")") >= 0)
	assert(code.find("func quest_chain(\"chain1\", \"主线链\"):") >= 0)
	assert(code.find("func enemy_template(\"e1\", \"史莱姆\", 50, 10, 5):") >= 0)
	assert(code.find("\tloot(\"gel\", 0.5, 2)") >= 0)
	assert(code.find("func npc(\"n1\", \"商人\", \"merchant\"):") >= 0)
	assert(code.find("func battle_config(\"b1\", \"新手遭遇\"):") >= 0)
	assert(code.find("\tflee_allowed = true") >= 0)
	print("PASS generate quest/combat")

	# parse 回写（用新实例, 保证从头解析）
	var ws2 := WorldScriptData.new()
	ws2.name = "x"
	ws2.ensure_subsystems()
	var result: Dictionary = ScriptCodeGenClass.parse(code, ws2)
	assert(result.get("success", false))
	var qs2 = ws2.quest_system
	assert(qs2.quests.size() == 2)
	var q1: Dictionary = qs2.get_quest("q1")
	assert(q1.get("type") == "main")
	assert(q1.get("objectives", []).size() == 1)
	var obj: Dictionary = q1["objectives"][0]
	assert(obj.get("required_count") == 5)
	var rw: Dictionary = q1.get("rewards", {})
	assert(rw.get("exp") == 100 and rw.get("gold") == 50)
	assert(rw.get("items", []).size() == 1)
	assert(rw.get("unlock_quests", []).has("q2"))
	var q2: Dictionary = qs2.get_quest("q2")
	assert(q2.get("prerequisites", []).has("q1"))
	assert(q2.get("time_limit") == 3600)
	assert(q2.get("repeatable") == true)
	assert(qs2.quest_chains.size() == 1)
	assert(qs2.quest_chains[0].get("quests", []).size() == 2)
	var cs2 = ws2.combat_system
	assert(cs2.enemy_templates.size() == 1)
	var e1: Dictionary = cs2.get_enemy_template("e1")
	assert(e1.get("hp") == 50 and e1.get("atk") == 10)
	assert(e1.get("element") == "water")
	assert(e1.get("speed") == 6)
	assert(e1.get("skills", []).has("tackle"))
	assert(e1.get("loot", []).size() == 1)
	assert(cs2.npc_pool.size() == 1)
	var n1: Dictionary = cs2.get_npc("n1")
	assert(n1.get("role") == "merchant" and n1.get("disposition") == "friendly")
	assert(cs2.battle_configs.size() == 1)
	var b1: Dictionary = cs2.get_battle_config("b1")
	assert(b1.get("enemies", []).has("e1"))
	assert(b1.get("flee_allowed") == true)
	assert(b1.get("rewards", {}).get("exp") == 50)
	print("PASS parse quest/combat roundtrip")

	# 模板
	assert(ScriptCodeGenClass.get_template("quest").begins_with("func quest("), "quest 模板应有")
	assert(ScriptCodeGenClass.get_template("enemy_template").begins_with("func enemy_template("), "enemy 模板应有")
	print("PASS get_template quest/combat")

	print("ALL_TESTS_PASSED")
	quit(0)
