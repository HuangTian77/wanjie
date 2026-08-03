## ScriptTemplates - 游戏类型模板系统
## 模板 = 元数据 + 四大子系统数据 + quest/combat + 预置蓝图图（GraphStore）
## 用户创建剧本时选择游戏类型, 获得可运行的完整骨架, 再基于模板编辑。
class_name ScriptTemplates
extends RefCounted

## 模板元信息列表（UI 展示用）
static func get_template_defs() -> Array[Dictionary]:
	return [
		{"id": "rpg_adventure", "name": "经典RPG冒险", "icon": "⚔️", "tags": ["奇幻", "冒险", "成长"],
			"description": "剑与魔法的奇幻冒险：主线剧情、技能成长、商店交易、战斗历练。"},
		{"id": "visual_novel", "name": "互动小说", "icon": "📖", "tags": ["剧情", "选择", "情感"],
			"description": "以剧情选择为核心：多分支叙事、角色好感、事件链驱动。"},
		{"id": "simulation_tycoon", "name": "模拟经营", "icon": "🏭", "tags": ["经营", "经济", "资源"],
			"description": "资源生产与市场循环：货币、供需、生产规则、经营事件。"},
		{"id": "turn_strategy", "name": "回合策略", "icon": "♟️", "tags": ["策略", "战役", "阵营"],
			"description": "多阵营战役推演：战略资源、战役事件链、回合战斗配置。"},
		{"id": "combat_arena", "name": "战斗竞技", "icon": "🥊", "tags": ["战斗", "竞技", "技能"],
			"description": "竞技场挑战：丰富技能组合、敌人轮换、段位晋升任务。"},
		{"id": "explore_puzzle", "name": "探索解谜", "icon": "🗺️", "tags": ["探索", "解谜", "遗迹"],
			"description": "遗迹探索与谜题分支：区域解锁、线索收集、隐藏结局。"},
		{"id": "dragonflame_worldview", "name": "龙焰纪元·世界观蓝图", "icon": "🐉", "tags": ["奇幻", "世界观", "蓝图模板"],
			"description": "以《龙焰纪元》世界观为示范：四大王国/龙脉/时代/核心规则全部以蓝图节点表达, 展示子页蓝图化编辑方式。"},
	]

## 应用模板到剧本（返回是否成功）
static func apply_template(ws: WorldScriptData, template_id: String) -> bool:
	if ws == null:
		return false
	ws.ensure_subsystems()
	match template_id:
		"rpg_adventure":
			_apply_rpg_adventure(ws)
		"visual_novel":
			_apply_visual_novel(ws)
		"simulation_tycoon":
			_apply_simulation_tycoon(ws)
		"turn_strategy":
			_apply_turn_strategy(ws)
		"combat_arena":
			_apply_combat_arena(ws)
		"explore_puzzle":
			_apply_explore_puzzle(ws)
		"dragonflame_worldview":
			_apply_dragonflame_worldview(ws)
		_:
			return false
	return true

## === 模板公共辅助 ===

static func _set_meta(ws: WorldScriptData, name: String, tags: Array, hours: float) -> void:
	ws.name = name
	ws.tags = Array(tags, TYPE_STRING, "", null)
	ws.estimated_hours = hours
	ws.status = "draft"

## 创建一张含 start 节点的图
static func _new_graph() -> Dictionary:
	var graph := BlueprintData.make_graph()
	var start_node: Dictionary = BlueprintData.create_node("start", Vector2(100, 160))
	graph["nodes"][start_node["id"]] = start_node
	return graph

## 便捷: 在图中加一个节点并接到父节点
## props 特殊键: "_in1"/"_in2" 设置第 1/2 个数据输入引脚的默认值
static func _add_node(graph: Dictionary, parent_id: String, node_type: String, props: Dictionary = {}, pos: Vector2 = Vector2.ZERO) -> String:
	var node: Dictionary = BlueprintData.create_node(node_type, pos)
	for k in props:
		if k == "_in1" or k == "_in2":
			var idx: int = 1 if k == "_in1" else 2
			if node.get("inputs", []).size() > idx:
				node["inputs"][idx]["default_value"] = props[k]
		else:
			node["properties"][k] = props[k]
	graph["nodes"][node["id"]] = node
	if parent_id != "":
		BlueprintData.add_connection(graph, parent_id, 0, node["id"], 0, true)
	return node["id"]

## 便捷: 添加带输出的选择节点并接两条分支
static func _add_choice(graph: Dictionary, parent_id: String, text0: String, text1: String, pos: Vector2) -> String:
	var cid: String = _add_node(graph, parent_id, "story_choice", {"choice_0_text": text0, "choice_1_text": text1}, pos)
	return cid

## === 1. 经典RPG冒险 ===

static func _apply_rpg_adventure(ws: WorldScriptData) -> void:
	_set_meta(ws, "新手村的勇者", ["奇幻", "冒险", "成长"], 30.0)
	# 世界观
	var wv: WorldviewData = ws.worldview
	wv.background_story = "艾德兰大陆, 魔王军自黑暗裂隙涌出。身为新手村勇者的你, 踏上讨伐之路。"
	wv.add_era("和平纪元", 0, 300)
	wv.add_era("魔王降临", 300, 347)
	wv.add_timeline_entry(300, "黑暗裂隙开启, 魔王军入侵", "王国联军节节败退")
	wv.add_rule("world", "魔法", "魔力源于世界树, 高阶魔法需世界树祝福")
	wv.add_faction("kingdom", "王国联军", "human", 60)
	wv.add_faction("demon", "魔王军", "demon", 75)
	wv.add_faction("merchant", "商会", "neutral", 40)
	# 事件
	var es: EventSystemData = ws.event_system
	es.add_story_event("intro", "村长嘱托", "chain")
	es.story_events[0]["description"] = "村长交给你一把旧铁剑: 去西边森林讨伐野狼。"
	es.story_events[0]["choices"] = [{"id": "c1", "text": "立刻出发", "consequences": [{"target": "world", "effect": "quest_started"}]}]
	es.add_story_event("wolf_den", "狼穴之战", "chain")
	es.story_events[1]["description"] = "狼穴深处, 头狼扑来!"
	es.story_events[1]["choices"] = [{"id": "c1", "text": "正面迎战", "consequences": [{"target": "player", "effect": "gold +20"}]}]
	es.add_story_event("demon_war", "魔王决战", "chain")
	es.story_events[2]["prerequisite"] = "wolf_den"
	es.story_events[2]["description"] = "黑暗裂隙前, 魔王军集结。最终决战!"
	es.story_events[2]["choices"] = [{"id": "c1", "text": "举起武器", "consequences": [{"target": "world", "effect": "demon_defeated"}]}]
	es.add_random_event("wild_encounter", "野外遭遇", 0.15)
	# 经济
	var ec: EconomySystemData = ws.economy_system
	ec.add_currency("gold", "金币", "universal")
	ec.add_resource("iron", "铁矿石", "material")
	ec.add_resource("herb", "草药", "material")
	ec.add_market("village_shop", "村庄商店", "新手村")
	ec.markets[0]["goods"] = [{"item": "iron", "base_price": 10.0, "demand_factor": 1.0, "supply_ratio": 0.5}]
	# 能力
	var ab: AbilitySystemData = ws.ability_system
	ab.initialize_combat_defaults()
	ab.add_skill_simple("slash", "斩击", "active", "physical", "melee", "基础攻击")
	ab.add_skill_simple("fireball", "火球术", "active", "elemental", "fire", "火焰伤害")
	ab.add_skill_simple("heal", "治疗术", "support", "elemental", "light", "恢复生命")
	ab.add_growth_path("warrior_path", "勇者之路", "物理攻击路线")
	# 任务
	var qs: QuestSystemData = ws.quest_system
	qs.add_quest("q_main1", "讨伐野狼", "main")
	qs.quests[0]["description"] = "前往西边森林讨伐 3 只野狼"
	qs.quests[0]["objectives"] = [{"description": "讨伐野狼", "target_type": "kill", "target_id": "wolf", "required_count": 3}]
	qs.quests[0]["rewards"] = {"exp": 50, "gold": 20}
	qs.add_quest("q_main2", "魔王讨伐", "main")
	qs.quests[1]["description"] = "击败黑暗裂隙前的魔王军"
	qs.quests[1]["rewards"] = {"exp": 300, "gold": 200}
	qs.quests[1]["prerequisites"] = ["q_main1"]
	# 战斗
	var cs: CombatSystemData = ws.combat_system
	cs.add_enemy_template("wolf", "野狼", 30, 8, 3)
	cs.add_enemy_template("demon_soldier", "恶魔士兵", 60, 15, 8)
	cs.add_battle_config("wolf_den_battle", "狼穴遭遇")
	cs.battle_configs[0]["enemies"] = ["wolf"]
	# 蓝图图
	GraphStore.set_graph(ws, "sys:global", _rpg_global_graph())
	GraphStore.set_graph(ws, "sys:economy", _rpg_economy_graph())

static func _rpg_global_graph() -> Dictionary:
	var g := _new_graph()
	var n0: String = g["nodes"].keys()[0]
	var cid := _add_choice(g, n0, "前往狼穴", "在村庄补给", Vector2(300, 160))
	var accept := _add_node(g, cid, "quest_accept", {"quest_id": "q_main1"}, Vector2(560, 100))
	var battle := _add_node(g, accept, "combat_spawn_enemy", {"enemy_template": "wolf", "custom_name": "野狼", "hp": 30}, Vector2(780, 100))
	var start_battle := _add_node(g, battle, "combat_start", {}, Vector2(980, 100))
	var reward := _add_node(g, start_battle, "combat_reward", {"exp": 50, "gold": 20}, Vector2(1180, 100))
	_add_node(g, reward, "quest_complete", {"quest_id": "q_main1"}, Vector2(1380, 100))
	var shop := _add_node(g, cid, "eco_buy", {"market_id": "village_shop", "item_id": "herb", "quantity": 1}, Vector2(560, 300))
	_add_node(g, shop, "eco_give_currency", {"currency_id": "gold", "amount": 10}, Vector2(780, 300))
	return g

static func _rpg_economy_graph() -> Dictionary:
	var g := _new_graph()
	var n0: String = g["nodes"].keys()[0]
	var give := _add_node(g, n0, "eco_give_item", {"item_id": "iron", "quantity": 2}, Vector2(300, 160))
	_add_node(g, give, "eco_give_currency", {"currency_id": "gold", "amount": 5}, Vector2(500, 160))
	return g

## === 2. 互动小说 ===

static func _apply_visual_novel(ws: WorldScriptData) -> void:
	_set_meta(ws, "雨夜的咖啡店", ["剧情", "选择", "情感"], 8.0)
	var wv: WorldviewData = ws.worldview
	wv.background_story = "都市雨夜, 你走进一家即将打烊的咖啡店。店里的神秘客人改变了这个夜晚。"
	wv.add_faction("cafe", "咖啡店", "neutral", 30)
	wv.add_faction("mystery", "神秘组织", "unknown", 70)
	# 事件
	var es: EventSystemData = ws.event_system
	es.add_story_event("rainy_night", "雨夜来客", "chain")
	es.story_events[0]["description"] = "雨声敲打窗棂, 一名戴面具的客人坐在角落。"
	es.story_events[0]["choices"] = [
		{"id": "c1", "text": "上前搭话", "consequences": [{"target": "world", "effect": "talked_to_stranger"}]},
		{"id": "c2", "text": "默默观察", "consequences": [{"target": "world", "effect": "observed"}]},
	]
	es.add_story_event("masked_offer", "面具人的请求", "chain")
	es.story_events[1]["prerequisite"] = "rainy_night"
	es.story_events[1]["description"] = "面具人递来一封泛黄的信。"
	es.story_events[1]["choices"] = [
		{"id": "c1", "text": "收下信", "consequences": [{"target": "player", "effect": "gold +5"}]},
		{"id": "c2", "text": "拒绝", "consequences": [{"target": "world", "effect": "refused"}]},
	]
	es.add_story_event("final_choice", "雨停之前", "chain")
	es.story_events[2]["prerequisite"] = "masked_offer"
	es.story_events[2]["description"] = "雨渐渐停歇, 面具人站起身。最后的邀请。"
	es.story_events[2]["choices"] = [
		{"id": "c1", "text": "一起走", "consequences": [{"target": "world", "effect": "ending_true"}]},
		{"id": "c2", "text": "留在店里", "consequences": [{"target": "world", "effect": "ending_stay"}]},
	]
	# 能力（观察/共情技能）
	var ab: AbilitySystemData = ws.ability_system
	ab.initialize_combat_defaults()
	ab.add_skill_simple("observe", "细致观察", "passive", "physical", "melee", "洞察细节, 提高发现隐藏线索的概率")
	ab.add_skill_simple("empathy", "共情", "support", "elemental", "light", "提升对话信任")
	# 经济（极简）
	var ec: EconomySystemData = ws.economy_system
	ec.add_currency("coin", "硬币", "universal")
	# 任务（好感链）
	var qs: QuestSystemData = ws.quest_system
	qs.add_quest("q_trust", "信任之线", "main")
	qs.quests[0]["description"] = "在对话中积累神秘客人的信任"
	qs.quests[0]["objectives"] = [{"description": "完成三段关键对话", "target_type": "dialogue", "target_id": "masked", "required_count": 3}]
	# 蓝图图: 多分支选择
	var g := _new_graph()
	var n0: String = g["nodes"].keys()[0]
	var c0 := _add_choice(g, n0, "搭话", "观察", Vector2(300, 160))
	var c1 := _add_choice(g, c0, "收下信", "拒绝", Vector2(560, 100))
	_add_node(g, c1, "world_set_var", {"var_name": "ending_true", "_in1": true}, Vector2(820, 100))
	_add_node(g, c1, "world_set_var", {"var_name": "ending_stay", "_in1": true}, Vector2(820, 260))
	var c2 := _add_choice(g, c0, "跟上去", "留下", Vector2(560, 420))
	_add_node(g, c2, "world_set_var", {"var_name": "ending_true", "_in1": true}, Vector2(820, 420))
	_add_node(g, c2, "world_set_var", {"var_name": "ending_stay", "_in1": true}, Vector2(820, 580))
	GraphStore.set_graph(ws, "sys:global", g)

## === 3. 模拟经营 ===

static func _apply_simulation_tycoon(ws: WorldScriptData) -> void:
	_set_meta(ws, "云端小镇工坊", ["经营", "经济", "资源"], 20.0)
	var wv: WorldviewData = ws.worldview
	wv.background_story = "云端小镇的手工作坊主, 通过采集、生产与贸易, 让小镇繁荣起来。"
	wv.add_faction("guild", "商会", "neutral", 50)
	wv.add_faction("town", "镇议会", "neutral", 45)
	var es: EventSystemData = ws.event_system
	es.add_story_event("first_order", "第一笔订单", "chain")
	es.story_events[0]["description"] = "商会送来订单: 交付 5 份木料。"
	es.story_events[0]["choices"] = [{"id": "c1", "text": "接下订单", "consequences": [{"target": "world", "effect": "order_accepted"}]}]
	es.add_random_event("market_fluc", "市场波动", 0.2)
	var ec: EconomySystemData = ws.economy_system
	ec.add_currency("silver", "银币", "universal")
	ec.add_currency("gold", "金币", "premium")
	ec.add_resource("wood", "木料", "material")
	ec.add_resource("iron", "铁矿石", "material")
	ec.add_resource("cloth", "布料", "material")
	ec.add_market("town_market", "小镇市场", "云端小镇")
	ec.markets[0]["goods"] = [
		{"item": "wood", "base_price": 8.0, "demand_factor": 1.2, "supply_ratio": 0.4},
		{"item": "iron", "base_price": 15.0, "demand_factor": 1.0, "supply_ratio": 0.5},
	]
	ec.trade_rules = {"barter_enabled": true, "barter_rate": 0.8}
	ec.production_rules = [
		{"resource": "wood", "sources": [{"type": "forest", "interval": "2h"}]},
		{"resource": "iron", "sources": [{"type": "mine", "interval": "4h"}]},
	]
	var ab: AbilitySystemData = ws.ability_system
	ab.initialize_combat_defaults()
	ab.add_skill_simple("haggle", "议价", "support", "physical", "melee", "提高交易价格")
	var qs: QuestSystemData = ws.quest_system
	qs.add_quest("q_growth", "小镇繁荣", "main")
	qs.quests[0]["description"] = "将小镇繁荣度提升到 100"
	qs.quests[0]["objectives"] = [{"description": "完成 10 笔交易", "target_type": "trade", "target_id": "market", "required_count": 10}]
	qs.quests[0]["rewards"] = {"exp": 100, "gold": 50}
	var g := _new_graph()
	var n0: String = g["nodes"].keys()[0]
	var prod := _add_node(g, n0, "eco_give_item", {"item_id": "wood", "quantity": 2}, Vector2(300, 160))
	var price := _add_node(g, prod, "eco_refresh_price", {}, Vector2(500, 160))
	_add_node(g, price, "eco_give_currency", {"currency_id": "silver", "amount": 16}, Vector2(700, 160))
	GraphStore.set_graph(ws, "sys:global", g)
	GraphStore.set_graph(ws, "sys:economy", g)

## === 4. 回合策略 ===

static func _apply_turn_strategy(ws: WorldScriptData) -> void:
	_set_meta(ws, "裂土之盟", ["策略", "战役", "阵营"], 40.0)
	var wv: WorldviewData = ws.worldview
	wv.background_story = "三大王国为争夺圣山展开百年战争。你是边境将领, 统率一军。"
	wv.add_faction("north", "北境王国", "human", 60)
	wv.add_faction("south", "南方联盟", "human", 55)
	wv.add_faction("elves", "精灵议会", "elf", 50)
	var es: EventSystemData = ws.event_system
	es.add_story_event("border_skirmish", "边境冲突", "chain")
	es.story_events[0]["description"] = "斥候回报: 南方联盟的部队正在边境集结。"
	es.story_events[0]["choices"] = [{"id": "c1", "text": "主动出击", "consequences": [{"target": "world", "effect": "war_started"}]}]
	es.add_story_event("siege", "圣山围城", "chain")
	es.story_events[1]["prerequisite"] = "border_skirmish"
	es.story_events[1]["description"] = "圣山城下, 决战在即。"
	es.story_events[1]["choices"] = [{"id": "c1", "text": "发动总攻", "consequences": [{"target": "world", "effect": "siege_won"}]}]
	var ec: EconomySystemData = ws.economy_system
	ec.add_currency("gold", "军饷", "universal")
	ec.add_resource("iron", "铁矿石", "material")
	ec.add_resource("food", "军粮", "material")
	ec.add_market("supply_depot", "军需库", "边境要塞")
	var ab: AbilitySystemData = ws.ability_system
	ab.initialize_combat_defaults()
	ab.add_skill_simple("shield_wall", "盾墙", "passive", "physical", "melee", "提升防御")
	ab.add_skill_simple("cavalry_charge", "骑兵冲锋", "active", "physical", "melee", "高额伤害")
	var qs: QuestSystemData = ws.quest_system
	qs.add_quest("q_campaign", "圣山战役", "main")
	qs.quests[0]["description"] = "赢得圣山围城战"
	qs.quests[0]["objectives"] = [{"description": "击败南方联盟主力", "target_type": "battle", "target_id": "siege", "required_count": 1}]
	var cs: CombatSystemData = ws.combat_system
	cs.add_enemy_template("south_sword", "南方剑士", 45, 12, 6)
	cs.add_enemy_template("south_cavalry", "南方骑兵", 55, 16, 5)
	cs.add_battle_config("siege_battle", "圣山决战")
	cs.battle_configs[0]["enemies"] = ["south_sword", "south_cavalry"]
	cs.battle_configs[0]["rewards"] = {"exp": 200, "gold": 100}
	var g := _new_graph()
	var n0: String = g["nodes"].keys()[0]
	var spawn := _add_node(g, n0, "combat_spawn_enemy", {"enemy_template": "south_sword", "custom_name": "南方剑士", "hp": 45}, Vector2(300, 160))
	var battle := _add_node(g, spawn, "combat_start", {}, Vector2(500, 160))
	_add_node(g, battle, "combat_reward", {"exp": 200, "gold": 100}, Vector2(700, 160))
	GraphStore.set_graph(ws, "sys:global", g)
	GraphStore.set_graph(ws, "sys:combat", g)

## === 5. 战斗竞技 ===

static func _apply_combat_arena(ws: WorldScriptData) -> void:
	_set_meta(ws, "雷鸣竞技场", ["战斗", "竞技", "技能"], 15.0)
	var wv: WorldviewData = ws.worldview
	wv.background_story = "雷鸣竞技场: 胜者扬名, 败者离场。挑战层层对手, 冲击冠军之位。"
	wv.add_faction("arena", "竞技场管理", "neutral", 55)
	var es: EventSystemData = ws.event_system
	es.add_story_event("challenge_1", "初战", "chain")
	es.story_events[0]["description"] = "第一位对手走上擂台: 铁拳阿德。"
	es.story_events[0]["choices"] = [{"id": "c1", "text": "应战", "consequences": [{"target": "world", "effect": "fight_1"}]}]
	es.add_story_event("challenge_final", "冠军战", "chain")
	es.story_events[1]["prerequisite"] = "challenge_1"
	es.story_events[1]["description"] = "最终对手: 竞技场之王。"
	es.story_events[1]["choices"] = [{"id": "c1", "text": "全力一战", "consequences": [{"target": "world", "effect": "champion"}]}]
	var ec: EconomySystemData = ws.economy_system
	ec.add_currency("gold", "金币", "universal")
	var ab: AbilitySystemData = ws.ability_system
	ab.initialize_combat_defaults()
	ab.add_skill_simple("punch", "重拳", "active", "physical", "melee", "基础伤害")
	ab.add_skill_simple("thunder_slash", "雷斩", "active", "elemental", "lightning", "雷属性伤害")
	ab.add_skill_simple("iron_guard", "铁壁", "passive", "physical", "melee", "减伤")
	ab.add_skill_simple("berserk", "狂化", "active", "physical", "melee", "攻防互换")
	var qs: QuestSystemData = ws.quest_system
	qs.add_quest("q_rank", "段位晋升", "main")
	qs.quests[0]["description"] = "击败全部 5 名对手"
	qs.quests[0]["objectives"] = [{"description": "连胜 5 场", "target_type": "win", "target_id": "arena", "required_count": 5}]
	var cs: CombatSystemData = ws.combat_system
	cs.add_enemy_template("ade", "铁拳阿德", 40, 10, 4)
	cs.add_enemy_template("king", "竞技场之王", 80, 20, 12)
	cs.add_battle_config("arena_1", "初战")
	cs.battle_configs[0]["enemies"] = ["ade"]
	cs.add_battle_config("arena_final", "冠军战")
	cs.battle_configs[1]["enemies"] = ["king"]
	cs.battle_configs[1]["rewards"] = {"exp": 500, "gold": 300}
	var g := _new_graph()
	var n0: String = g["nodes"].keys()[0]
	var learn := _add_node(g, n0, "ability_learn", {"skill_id": "punch"}, Vector2(300, 160))
	var spawn := _add_node(g, learn, "combat_spawn_enemy", {"enemy_template": "ade", "custom_name": "铁拳阿德", "hp": 40}, Vector2(500, 160))
	var battle := _add_node(g, spawn, "combat_start", {}, Vector2(700, 160))
	var reward := _add_node(g, battle, "combat_reward", {"exp": 100, "gold": 50}, Vector2(900, 160))
	_add_node(g, reward, "quest_update_objective", {"quest_id": "q_rank", "objective_idx": 0, "progress": 1}, Vector2(1100, 160))
	GraphStore.set_graph(ws, "sys:global", g)
	GraphStore.set_graph(ws, "sys:combat", g)

## === 6. 探索解谜 ===

static func _apply_explore_puzzle(ws: WorldScriptData) -> void:
	_set_meta(ws, "失落遗迹", ["探索", "解谜", "遗迹"], 12.0)
	var wv: WorldviewData = ws.worldview
	wv.background_story = "古老遗迹深处隐藏着失落的文明。解开谜题, 收集线索, 抵达真相。"
	wv.add_faction("ruins", "遗迹守卫", "unknown", 65)
	wv.geography = {"regions": [
		{"id": "entrance", "name": "遗迹入口", "description": "石门上的铭文闪烁着微光"},
		{"id": "hall", "name": "回响大厅", "description": "巨大的石像注视着来者"},
		{"id": "chamber", "name": "最终密室", "description": "传说中的宝物所在"},
	]}
	var es: EventSystemData = ws.event_system
	es.add_story_event("gate_riddle", "石门谜题", "chain")
	es.story_events[0]["description"] = "石门铭文: '光明照不到的角落, 隐藏着钥匙'。"
	es.story_events[0]["choices"] = [
		{"id": "c1", "text": "检查阴影处", "consequences": [{"target": "world", "effect": "key_found"}]},
		{"id": "c2", "text": "强行推门", "consequences": [{"target": "player", "effect": "gold -5"}]},
	]
	es.add_story_event("final_room", "最终密室", "chain")
	es.story_events[1]["prerequisite"] = "gate_riddle"
	es.story_events[1]["description"] = "密室中央, 宝箱上刻着最后一行谜语。"
	es.story_events[1]["choices"] = [
		{"id": "c1", "text": "按古老仪式开启", "consequences": [{"target": "world", "effect": "treasure_obtained"}]},
		{"id": "c2", "text": "直接砸开", "consequences": [{"target": "player", "effect": "gold -20"}]},
	]
	# 能力（解谜与探索技能）
	var ab: AbilitySystemData = ws.ability_system
	ab.initialize_combat_defaults()
	ab.add_skill_simple("decipher", "古语解读", "passive", "elemental", "light", "解读遗迹铭文")
	ab.add_skill_simple("stealth", "潜行", "active", "physical", "melee", "避开遗迹守卫")
	var ec: EconomySystemData = ws.economy_system
	ec.add_currency("gold", "金币", "universal")
	ec.add_resource("key", "遗迹钥匙", "special")
	var qs: QuestSystemData = ws.quest_system
	qs.add_quest("q_riddle", "解开谜题", "main")
	qs.quests[0]["description"] = "解开遗迹中的所有谜题"
	qs.quests[0]["objectives"] = [{"description": "解开门谜", "target_type": "puzzle", "target_id": "gate", "required_count": 1}]
	qs.quests[0]["rewards"] = {"exp": 80, "gold": 30}
	var g := _new_graph()
	var n0: String = g["nodes"].keys()[0]
	var explore := _add_node(g, n0, "world_explore_region", {"region_id": "entrance"}, Vector2(300, 160))
	var key := _add_node(g, explore, "eco_give_item", {"item_id": "key", "quantity": 1}, Vector2(500, 160))
	var unlock := _add_node(g, key, "story_unlock_lore", {"lore_id": "ruins_history"}, Vector2(700, 160))
	_add_node(g, unlock, "quest_update_objective", {"quest_id": "q_riddle", "objective_idx": 0, "progress": 1}, Vector2(900, 160))
	GraphStore.set_graph(ws, "sys:global", g)

## === 龙焰纪元·世界观蓝图模板（示范: 世界观以蓝图节点表达） ===

static func _apply_dragonflame_worldview(ws: WorldScriptData) -> void:
	_set_meta(ws, "龙焰纪元·世界观蓝图", ["奇幻", "世界观", "蓝图模板"], 20.0)
	# 世界观数据（表单层可读）
	var wv: WorldviewData = ws.worldview
	wv.background_story = "艾泽兰大陆, 龙焰纪元 DF 347 年。龙族消失 244 年后的白银和平即将破裂, 四大王国暗流涌动。"
	wv.add_era("创世与诸神", -3000, -2000)
	wv.add_era("龙族黄金纪元", -2000, 0)
	wv.add_era("寂灭之夜", 0, 1)
	wv.add_era("诸王战争", 1, 103)
	wv.add_era("白银和平", 103, 347)
	wv.add_rule("world", "龙脉", "所有魔力源于龙脉, 龙脉紊乱会导致魔法失效")
	wv.add_rule("world", "神祇", "诸神受不干预契约束缚, 不得直接干涉凡间")
	wv.add_rule("world", "龙血", "龙裔的龙血可通过极端情绪/龙脉接触觉醒")
	wv.add_faction("ironcrown", "铁冠王朝", "human", 70)
	wv.add_faction("sunflare", "炎阳帝国", "human", 65)
	wv.add_faction("silvermoon", "银月王国", "elf", 55)
	wv.add_faction("deepcouncil", "地底议会", "dwarf", 60)
	# 势力关系
	wv.faction_relationships = [
		{"from_id": "ironcrown", "to_id": "sunflare", "type": "cold_war", "intensity": -0.6},
		{"from_id": "ironcrown", "to_id": "deepcouncil", "type": "alliance", "intensity": 0.7},
		{"from_id": "ironcrown", "to_id": "silvermoon", "type": "friendship", "intensity": 0.4},
		{"from_id": "silvermoon", "to_id": "deepcouncil", "type": "distrust", "intensity": -0.3},
		{"from_id": "sunflare", "to_id": "silvermoon", "type": "conflict", "intensity": -0.8},
	]
	wv.geography = {"regions": [
		{"id": "ironcrown_lands", "name": "铁冠王朝（中北部平原）", "description": "大陆粮仓与贸易中心"},
		{"id": "sunflare_desert", "name": "炎阳帝国（东南沙漠）", "description": "绿洲城邦与角斗场"},
		{"id": "silvermoon_forest", "name": "银月王国（西部森林）", "description": "世界树瑟兰迪尔所在"},
		{"id": "deepcouncil_under", "name": "地底议会（地下世界）", "description": "铁炉堡与五大氏族"},
		{"id": "dragon_valley", "name": "龙之谷（中立险地）", "description": "龙族遗迹与金色裂缝"},
	]}
	# 世界观蓝图图（节点表达设定, 运行时可执行初始化）
	var g := _new_graph()
	var n0: String = g["nodes"].keys()[0]
	var prev: String = n0
	var pos_y := 140.0
	# 1. 世界设定变量
	prev = _add_node(g, prev, "world_set_var", {"var_name": "world_name", "_in1": "艾泽兰"}, Vector2(320, pos_y))
	prev = _add_node(g, prev, "world_set_var", {"var_name": "era", "_in1": "龙焰纪元DF347"}, Vector2(520, pos_y))
	prev = _add_node(g, prev, "world_set_var", {"var_name": "dragon_era", "_in1": "白银和平（脆弱均衡）"}, Vector2(720, pos_y))
	pos_y += 120.0
	# 2. 四大王国势力初始化
	prev = _add_node(g, prev, "world_faction_power", {"faction_id": "ironcrown", "delta": 0}, Vector2(320, pos_y))
	prev = _add_node(g, prev, "world_faction_power", {"faction_id": "sunflare", "delta": 0}, Vector2(520, pos_y))
	prev = _add_node(g, prev, "world_faction_power", {"faction_id": "silvermoon", "delta": 0}, Vector2(720, pos_y))
	prev = _add_node(g, prev, "world_faction_power", {"faction_id": "deepcouncil", "delta": 0}, Vector2(920, pos_y))
	pos_y += 120.0
	# 3. 王国间关系（六条）
	prev = _add_node(g, prev, "world_faction_relation", {"faction_a": "ironcrown", "faction_b": "sunflare", "delta": -60.0}, Vector2(320, pos_y))
	prev = _add_node(g, prev, "world_faction_relation", {"faction_a": "ironcrown", "faction_b": "deepcouncil", "delta": 40.0}, Vector2(520, pos_y))
	prev = _add_node(g, prev, "world_faction_relation", {"faction_a": "ironcrown", "faction_b": "silvermoon", "delta": 25.0}, Vector2(720, pos_y))
	prev = _add_node(g, prev, "world_faction_relation", {"faction_a": "silvermoon", "faction_b": "deepcouncil", "delta": -15.0}, Vector2(920, pos_y))
	prev = _add_node(g, prev, "world_faction_relation", {"faction_a": "sunflare", "faction_b": "silvermoon", "delta": -50.0}, Vector2(1120, pos_y))
	pos_y += 120.0
	# 4. 设定说明（注释节点, 展示世界观文本）
	prev = _add_node(g, prev, "flow_comment", {"text": "核心规则: ①神祇不干预 ②龙脉为魔力之源 ③龙血可觉醒 ④自由意志 ⑤后果不可撤销 ⑥力量有代价"}, Vector2(320, pos_y))
	prev = _add_node(g, prev, "flow_comment", {"text": "七条太古龙脉: 赤金(火)/冰蓝(冰)/雷金(雷)/翠绿(生命)/光金(秩序)/暗影(诡术)/时金(时间)"}, Vector2(620, pos_y))
	prev = _add_node(g, prev, "flow_comment", {"text": "龙裔: 隐藏血脉的种族, 龙血四阶段觉醒(潜伏/显现/觉醒/龙化)"}, Vector2(920, pos_y))
	pos_y += 120.0
	# 5. 收尾
	_add_node(g, prev, "print", {"text": "世界观初始化完成"}, Vector2(320, pos_y))
	GraphStore.set_graph(ws, "sys:worldview", g)
