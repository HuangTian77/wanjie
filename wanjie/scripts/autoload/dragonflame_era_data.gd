## 龙焰纪元世界观数据初始化器
## 将完整的《龙焰纪元》世界观设定写入WorldScriptData
class_name DragonflameEraData
extends RefCounted

## 应用龙焰纪元完整世界观数据到剧本
static func apply(ws: WorldScriptData) -> void:
	ws.name = "龙焰纪元"
	ws.description = "艾泽兰大陆，龙焰纪元DF 347年。龙族消失244年后的白银和平即将破裂，四大王国暗流涌动，暗影教团蠢蠢欲动。你将作为一名冒险者，在这个剑与魔法的世界中揭开龙族消失的真相。"
	ws.author = "万界诗篇"
	ws.version = "1.0.0"
	ws.tags = Array(["奇幻", "冒险", "长篇", "龙焰纪元"], TYPE_STRING, "", null)
	ws.estimated_hours = 100.0
	ws.status = "published"

	_apply_worldview(ws.worldview)
	_apply_events(ws.event_system)
	_apply_economy(ws.economy_system)
	_apply_ability(ws.ability_system)

## === 世界观数据 ===
static func _apply_worldview(wv: WorldviewData) -> void:
	wv.background_story = """在时间开始之前，六位神祇共同创造了艾泽兰大陆。创世之后，六神签署了「不干预契约」——神祇不得直接干涉凡间事务。

龙族统治艾泽兰长达两千年，这段"黄金纪元"中文明繁荣、魔法昌盛。七大太古龙脉贯通大陆，魔力充盈每个角落。

DF 0年，一个无月的夜晚——"寂灭之夜"——所有龙族在一瞬间消失了。没有战斗的痕迹，没有遗言，没有预兆。

龙族消失留下的权力真空引发了持续百年的"诸王战争"（DF 1-103）。四大王国为争夺龙族遗产血腥厮杀，共造成约300万人死亡。

DF 103年，在精灵女王艾瑟琳的调停下，四方签署了《白银和约》。此后244年被称为"白银和平"——脆弱但持续至今的均衡。

现在是龙焰纪元DF 347年，深秋。铁冠城继承危机一触即发，炎阳帝国扩张野心不减，精灵种族缓慢消亡，矮人矿脉枯竭，暗影教团暗中活动……所有人都知道——这只是下一次战争前的喘息。"""

	# === 时代定义 ===
	wv.era_definitions.clear()
	wv.add_era("神创时代", -9999, -1, "六神创造艾泽兰大陆，签署不干预契约")
	wv.add_era("黄金纪元", 0 - 2000, -1, "龙族统治艾泽兰的两千年，文明繁荣、魔法昌盛。七大太古龙各司其职。")
	wv.add_era("寂灭之夜", 0, 0, "DF 0年，所有龙族在一瞬间消失。原因至今不明。")
	wv.add_era("诸王战争", 1, 103, "百年血火。四大王国为龙族遗产厮杀。混乱之战(1-30)→四方成型(31-60)→僵持毁灭(61-103)。300万人死亡。")
	wv.add_era("白银和平", 103, 347, "《白银和约》签署后的244年。贸易恢复、冒险者公会跨国运作，但裂缝处处可见。当前时代。")

	# === 时间线 ===
	wv.timeline.clear()
	wv.add_timeline_entry(-2000, "黄金纪元开始", "龙族开始统治艾泽兰")
	wv.add_timeline_entry(-200, "盾墙阵发明", "铁炉氏族在地下隘口防御战中创造")
	wv.add_timeline_entry(-100, "矮人王套装锻造", "铜须一世统一五大氏族")
	wv.add_timeline_entry(0, "寂灭之夜", "所有龙族瞬间消失，龙焰纪元开始")
	wv.add_timeline_entry(1, "诸王战争爆发", "权力真空引发百年血火")
	wv.add_timeline_entry(27, "楔形阵诞生", "布伦南·铁腕在铁冠城突围战中创造")
	wv.add_timeline_entry(34, "箭矢阵诞生", "瑟兰迪尔在月歌城守卫战中以500精灵击退2500人类")
	wv.add_timeline_entry(50, "冒险者公会成立", "石桥镇品质标准大会，六级品质体系确立")
	wv.add_timeline_entry(56, "圆环阵诞生", "埃德温·守誓者在黑森林战役中被包围时创造")
	wv.add_timeline_entry(62, "双列阵诞生", "矮人与人类军事合作的最高成就")
	wv.add_timeline_entry(78, "游击阵诞生", "半身人皮平与半兽人戈拉克的麻雀战术")
	wv.add_timeline_entry(103, "白银和约签署", "精灵女王调停，四国签署和平协议")
	wv.add_timeline_entry(150, "龙鳞套装完成", "矮人符文大师用龙鳞碎片打造")
	wv.add_timeline_entry(200, "冒险者勋章制度建立", "公会正式荣誉体系")
	wv.add_timeline_entry(347, "游戏开始", "DF 347年深秋，冒险者在石桥镇开始旅程")

	# === 世界规则 ===
	wv.world_rules.clear()
	wv.add_rule("divine", "神祇不干预", "true", "诸神受不干预契约束缚，只能通过神术间接帮助信徒，不能直接出现在凡间")
	wv.add_rule("magic", "龙脉是魔力之源", "true", "所有魔法力量来自龙脉。龙脉紊乱会导致魔法失效")
	wv.add_rule("blood", "龙血可觉醒", "true", "龙裔体内的龙血可通过极端情绪/龙脉接触/龙族遗物觉醒，分四阶段：潜伏→显现→觉醒→龙化")
	wv.add_rule("social", "自由意志", "true", "凡人的选择真正重要。神祇和龙族都无法控制凡人的意志")
	wv.add_rule("game", "后果不可撤销", "true", "重大事件改变世界，无法S/L。死亡不可轻易逆转")
	wv.add_rule("power", "力量有代价", "true", "魔法消耗魔力、战气消耗生命、神术需要虔诚、龙血影响理智")
	wv.add_rule("economy", "统一货币", "金币", "白银和平最重要的成就之一。全大陆使用统一金币体系")
	wv.add_rule("combat", "元素反应", "8元素28反应", "八种元素是七大龙脉能量的八种方言，两种元素相遇产生龙语的回声")

	# === 势力设定 ===
	wv.factions.clear()
	# 铁冠王朝
	wv.factions.append({
		"id": "iron_crown", "name": "铁冠王朝", "description": "人类的王国。大陆最强常规军事力量、最完善官僚体系、最大贸易网络。封建君主制，首都铁冠城（人口12万）。核心矛盾：继承危机——国王阿尔弗雷德三世(67岁)年迈无嗣，五大公爵争夺继承权。经济支柱：农业+贸易+制造业。",
		"power_level": 90, "territory": ["铁冠城", "石桥镇", "河畔镇", "麦田镇", "橡木镇", "白浪镇", "石炉镇", "柳溪村", "潮汐城", "守望堡"],
		"population": 500000, "governance_type": "封建君主制", "succession": "长子继承制",
		"primary_income": "农业+贸易", "trade_goods": ["粮食", "纺织品", "加工品"], "tax_rate": 0.15,
		"total_forces": 50000, "special_units": ["铁冠骑士团", "宫廷法师团"], "expansion_tendency": 0.3, "aggression_level": 0.3, "diplomacy_preference": "balanced"
	})
	# 炎阳帝国
	wv.factions.append({
		"id": "sun_empire", "name": "炎阳帝国", "description": "沙漠中的太阳。神权奴隶制帝国，首都炎阳城。统治者炎阳帝·塞提三世(45岁)。三势力角逐：皇室/太阳神殿/军事贵族。核心矛盾：奴隶起义+神权派vs世俗派+扩张野心。奴隶制、角斗场文化、沙漠骑兵、香料贸易。",
		"power_level": 80, "territory": ["炎阳城", "金塔城", "铁沙镇", "绿洲镇", "盐风镇", "沙棘村", "太阳神殿"],
		"population": 350000, "governance_type": "神权奴隶制", "succession": "神选继承制",
		"primary_income": "香料+矿产", "trade_goods": ["香料", "矿石", "奴隶"], "tax_rate": 0.25,
		"total_forces": 40000, "special_units": ["沙漠骑兵", "火焰祭司"], "expansion_tendency": 0.8, "aggression_level": 0.7, "diplomacy_preference": "aggressive"
	})
	# 银月王国
	wv.factions.append({
		"id": "silver_moon", "name": "银月王国", "description": "精灵的永恒森林。长老议会制，首都月歌城（建于世界树瑟兰迪尔之上）。统治者精灵女王·艾瑟琳(约1400岁，寂灭之夜唯一见证者)。核心矛盾：开放派vs保守派+生育危机+世界树衰微。最古老的文明，魔法文化深厚。",
		"power_level": 65, "territory": ["月歌城", "银枝城", "星落镇", "花语镇", "晨露镇", "古树村"],
		"population": 80000, "governance_type": "长老议会制", "succession": "长老指定制",
		"primary_income": "魔法物品", "trade_goods": ["魔法物品", "草药", "艺术品"], "tax_rate": 0.05,
		"total_forces": 15000, "special_units": ["精灵弓箭手", "大德鲁伊"], "expansion_tendency": 0.1, "aggression_level": 0.1, "diplomacy_preference": "defensive"
	})
	# 地底议会
	wv.factions.append({
		"id": "underground", "name": "地底议会", "description": "矮人的地下帝国。议会君主制，首都铁炉堡（建于活火山内部）。统治者至高王·铜须七世(210岁)。核心矛盾：矿脉枯竭+三王子继承危机+与地表关系。五大氏族：铁炉/霜铁/熔岩/灰岩/深石。最精湛锻造技艺。",
		"power_level": 70, "territory": ["铁炉堡", "霜铁城", "熔岩城", "灰岩哨", "深石镇"],
		"population": 120000, "governance_type": "议会君主制", "succession": "氏族投票制",
		"primary_income": "矿石+锻造", "trade_goods": ["金属", "武器", "符文物品"], "tax_rate": 0.1,
		"total_forces": 25000, "special_units": ["矮人斥候·暗石旅", "符文锻造师"], "expansion_tendency": 0.2, "aggression_level": 0.2, "diplomacy_preference": "trade_focused"
	})
	# 暗影教团
	wv.factions.append({
		"id": "shadow_cult", "name": "暗影教团", "description": "暗龙的仆人。成立于寂灭之夜后，终极目标：迎接暗龙归来，重建龙族统治。内部分为共存派(多数)和控制派(少数但激进)。组织结构：教团领袖→四大使者→暗影大师(20人)→精英刺客(100人)→正式刺客(500人)→学徒。",
		"power_level": 55, "territory": ["暗影教团前哨", "暗影教团要塞"],
		"population": 2000, "governance_type": "神权独裁", "succession": "指定继承",
		"primary_income": "暗杀+走私", "trade_goods": ["情报", "违禁品"], "tax_rate": 0.0,
		"total_forces": 1000, "special_units": ["暗影大师", "暗影刺客"], "expansion_tendency": 0.9, "aggression_level": 0.9, "diplomacy_preference": "secretive"
	})
	# 冒险者公会
	wv.factions.append({
		"id": "adventurer_guild", "name": "冒险者公会", "description": "跨国组织，在四大王国都设有分支机构。等级：铜→铁→银→金→秘银→精金→龙晶(历史上仅3人)。提供任务分配、等级认证、法律保护、装备折扣、情报共享。总部在铁冠城。",
		"power_level": 40, "territory": ["铁冠城总部"],
		"population": 10000, "governance_type": "长老议会", "succession": "选举",
		"primary_income": "任务佣金", "trade_goods": ["情报", "怪物材料"], "tax_rate": 0.05,
		"total_forces": 5000, "special_units": ["验证者团队"], "expansion_tendency": 0.3, "aggression_level": 0.1, "diplomacy_preference": "neutral"
	})

	# === 势力关系 ===
	wv.faction_relationships.clear()
	wv.faction_relationships.append({"from_id": "iron_crown", "to_id": "sun_empire", "type": "rivalry", "intensity": 0.7, "description": "百年冷战的余烬。边境摩擦不断，贸易断断续续"})
	wv.faction_relationships.append({"from_id": "iron_crown", "to_id": "silver_moon", "type": "alliance", "intensity": 0.5, "description": "谨慎的友谊。文化差异大但对抗炎阳扩张利益一致"})
	wv.faction_relationships.append({"from_id": "iron_crown", "to_id": "underground", "type": "trade", "intensity": 0.6, "description": "务实合作。矿石换粮食的稳定贸易，关系最稳定"})
	wv.faction_relationships.append({"from_id": "silver_moon", "to_id": "underground", "type": "neutral", "intensity": 0.3, "description": "古老的疏远。精灵认为矮人过于迷恋石头，矮人认为精灵傲慢不可靠"})
	wv.faction_relationships.append({"from_id": "sun_empire", "to_id": "silver_moon", "type": "rivalry", "intensity": 0.9, "description": "价值观对立。奴隶制vs自由、神权专制vs议会民主"})
	wv.faction_relationships.append({"from_id": "sun_empire", "to_id": "underground", "type": "trade", "intensity": 0.4, "description": "互不信任的交易。香料换武器，但互相戒备极深"})
	wv.faction_relationships.append({"from_id": "shadow_cult", "to_id": "iron_crown", "type": "rivalry", "intensity": 0.8, "description": "教团已渗透到铁冠城内部"})
	wv.faction_relationships.append({"from_id": "shadow_cult", "to_id": "sun_empire", "type": "rivalry", "intensity": 0.6, "description": "控制派与沙蛇帮有秘密合作"})

	# === 地理区域 ===
	wv.geography = {"regions": [
		{"id": "iron_crown_north", "name": "铁冠王朝·中北部", "description": "人类王国的核心领土，中部平原是大陆粮仓", "climate": "温带", "resources": ["粮食", "铁", "木材"], "connections": ["silver_moon_west", "underground", "neutral_north"]},
		{"id": "silver_moon_west", "name": "银月王国·西部森林", "description": "精灵的永恒森林，世界树瑟兰迪尔所在地", "climate": "温带森林", "resources": ["魔法材料", "珍稀木材", "草药"], "connections": ["iron_crown_north", "neutral_north"]},
		{"id": "sun_empire_southeast", "name": "炎阳帝国·东南沙漠", "description": "沙漠中的太阳，绿洲城市与香料之路", "climate": "沙漠", "resources": ["香料", "矿石", "宝石"], "connections": ["iron_crown_north", "neutral_north"]},
		{"id": "underground", "name": "地底议会·地下世界", "description": "矮人的地下帝国，活火山中铁炉堡", "climate": "地下", "resources": ["金属", "矿石", "符文石"], "connections": ["iron_crown_north", "silver_moon_west"]},
		{"id": "neutral_north", "name": "北风高原·中立区", "description": "多族混居的中立城市，不隶属任何王国", "climate": "高原", "resources": ["皮毛", "药材"], "connections": ["iron_crown_north", "silver_moon_west", "sun_empire_southeast"]},
		{"id": "dragon_valley", "name": "龙之谷", "description": "龙族消失的神秘之地，七条龙脉汇聚之处", "climate": "异常", "resources": ["龙晶碎片", "龙脉能量"], "connections": []},
		{"id": "poison_swamp", "name": "毒雾沼泽", "description": "女巫莫甘娜的居所，变异生物横行", "climate": "沼泽", "resources": ["炼金材料", "暗影精华"], "connections": ["iron_crown_north"]},
		{"id": "black_forest", "name": "黑森林", "description": "橡木镇外的古老森林，失踪事件频发", "climate": "温带密林", "resources": ["珍稀木材", "野兽材料"], "connections": ["iron_crown_north"]}
	]}

	# === 知识条目 ===
	wv.lore_entries.clear()
	# 种族知识
	wv.lore_entries.append({"id": "race_human", "title": "人类——短命者的野心", "content": "艾泽兰最年轻的种族，人口最多(约60%)。寿命60-80岁。务实、进取、矛盾。铁冠王朝重视荣誉契约，炎阳帝国重视生存家族，中立区强调自由。", "discovery_condition": "game_start"})
	wv.lore_entries.append({"id": "race_elf", "title": "精灵——永恒守望者", "content": "最古老的种族之一，寿命800-1500年。龙族时代最亲密的盟友。生育危机严重——过去100年出生不到50个精灵。魔法天赋最高。", "discovery_condition": "game_start"})
	wv.lore_entries.append({"id": "race_dwarf", "title": "矮人——石头的子孙", "content": "自称山脉后裔，寿命300-400年。锻造是信仰，氏族高于个人，契约至死不渝。五大氏族：铁炉/霜铁/熔岩/灰岩/深石。", "discovery_condition": "game_start"})
	wv.lore_entries.append({"id": "race_orc", "title": "半兽人——被诅咒的战士", "content": "起源笼罩迷雾。身体素质最强，战气觉醒率最高。寂灭之夜后被指责为灾祸之源，被迫逃往荒野和沙漠。", "discovery_condition": "game_start"})
	wv.lore_entries.append({"id": "race_halfling", "title": "半身人——幸运的流浪者", "content": "没有固定领土的流浪民族。天性乐观，运气出奇地好。以美食、音乐和故事闻名。约占总人口7%。", "discovery_condition": "game_start"})
	wv.lore_entries.append({"id": "race_dragonborn", "title": "龙裔——被隐藏的血脉", "content": "龙族与凡人结合的后代。寂灭之夜后从受尊敬变为被追捕。龙血觉醒四阶段：潜伏→显现→觉醒→龙化。秘密组织'血脉之链'提供庇护。", "discovery_condition": "game_start"})
	# 龙脉知识
	wv.lore_entries.append({"id": "dragon_veins", "title": "七条太古龙脉", "content": "赤金(火焰/力量)、冰蓝(冰冻/守护)、雷金(雷电/速度)、翠绿(生命/自然·正在死亡)、光金(光耀/秩序)、暗影(暗影/诡术·被教团干扰)、时金(时间/命运·不可观测)。龙脉交汇形成魔力节点。", "discovery_condition": "lore_study"})
	# 传说装备
	wv.lore_entries.append({"id": "legend_equip", "title": "八件传说装备", "content": "破晓之剑(古代图书馆遗迹)、暗影之刃(暗影教团要塞)、龙鳞盾(铁炉堡王室宝库)、元素皇冠(世界树深处封印)、时空披风(龙之谷时金节点)、贤者之戒×2(知识之戒在教团/智慧之戒在艾瑟琳)、世界树之杖(失踪)。", "discovery_condition": "lore_study"})
	# 暗影教团
	wv.lore_entries.append({"id": "shadow_cult_lore", "title": "暗影教团——暗龙的仆人", "content": "寂灭之夜后成立。终极目标：迎接暗龙归来。共存派vs控制派。暗杀分五级。组织：教团领袖→四大使者→暗影大师(20)→精英刺客(100)→正式刺客(500)→学徒。", "discovery_condition": "quest_discovery"})
	# 套装
	wv.lore_entries.append({"id": "set_bonuses", "title": "八套套装", "content": "冒险者套装(公会馈赠)、龙鳞套装(龙之谷锻造)、圣骑士套装(光明神殿)、月影套装(精灵国宝)、矮人王套装(铁炉堡)、沙漠领主套装(炎阳神殿)、暗影套装(教团要塞)、命运套装(全收集·时金结晶)。", "discovery_condition": "lore_study"})

## === 事件系统数据 ===
static func _apply_events(es: EventSystemData) -> void:
	# 主线剧情事件
	es.story_events.clear()
	var e1 := es.add_story_event("main_001", "石桥镇的召唤", "冒险者在石桥镇接到第一个任务：调查废弃银矿的异常活动。公会长巴尔德分配任务。")
	e1["trigger_type"] = "game_start"
	es.add_choice("main_001", "c1", "接受任务，前往废弃银矿", [{"target": "guild", "effect": "reputation +5"}])
	es.add_choice("main_001", "c2", "先去醉龙角酒馆打探消息", [{"target": "info", "effect": "gain_intel"}])

	var e2 := es.add_story_event("main_002", "银矿深处的秘密", "在废弃银矿深处发现了暗影教团的前哨站。教团正在搜索龙族遗迹。")
	e2["trigger_type"] = "chain"
	e2["prerequisite"] = "main_001"
	es.add_choice("main_002", "c1", "正面突入，击败教团刺客", [{"target": "combat", "effect": "fight_shadow_cult"}])
	es.add_choice("main_002", "c2", "潜行侦查，收集情报后撤退", [{"target": "stealth", "effect": "gain_intel"}])
	es.add_choice("main_002", "c3", "尝试与教团成员对话", [{"target": "dialog", "effect": "learn_cult_goal"}])

	var e3 := es.add_story_event("main_003", "铁冠城的阴影", "发现暗影教团已渗透到铁冠城高层。继承危机背后有教团的影子。")
	e3["trigger_type"] = "chain"
	e3["prerequisite"] = "main_002"

	var e4 := es.add_story_event("main_004", "精灵女王的秘密", "前往银月王国，发现艾瑟琳知道寂灭之夜的真相，但她选择沉默。")
	e4["trigger_type"] = "chain"
	e4["prerequisite"] = "main_003"

	var e5 := es.add_story_event("main_005", "龙脉的呼唤", "龙脉异常波动加剧。冒险者首次感受到龙脉的呼唤——可能与龙裔血脉有关。")
	e5["trigger_type"] = "chain"
	e5["prerequisite"] = "main_004"

	# 随机事件
	es.random_events.clear()
	es.add_random_event("random_bandit", "路遇强盗", 0.08)
	es.add_random_event("random_merchant", "流浪商人", 0.1)
	es.add_random_event("random_dragon_vein", "龙脉脉动", 0.03)
	es.add_random_event("random_tavern", "酒馆传闻", 0.12)
	es.add_random_event("random_patrol", "王国巡逻队", 0.06)
	es.add_random_event("random_halfling", "半身人旅者", 0.05)

	# 事件链
	es.event_chains.clear()
	es.add_event_chain("main_chain", "主线·龙族之谜", "main_001")
	es.event_chains[0]["description"] = "从石桥镇的废弃银矿到龙族消失的真相，揭开寂灭之夜的秘密"

## === 经济系统数据 ===
static func _apply_economy(ec: EconomySystemData) -> void:
	# 货币
	ec.currencies.clear()
	ec.add_currency("gold", "金币", "universal")
	ec.currencies[0]["icon"] = "coin"
	ec.currencies[0]["inflation_rate"] = 0.02

	# 资源
	ec.resources.clear()
	ec.add_resource("iron_ore", "铁矿石", "material")
	ec.add_resource("mana_crystal", "魔力水晶", "material")
	ec.add_resource("dragon_scale", "龙鳞碎片", "quest_item")
	ec.add_resource("herb", "药草", "consumable")
	ec.add_resource("spice", "香料", "material")
	ec.add_resource("rune_stone", "符文石", "material")
	ec.add_resource("moon_silver", "月银", "material")
	ec.add_resource("grain", "粮食", "consumable")
	ec.add_resource("dragon_crystal", "龙晶碎片", "quest_item")
	ec.add_resource("shadow_essence", "暗影精华", "material")

	# 市场
	ec.markets.clear()
	# 石桥镇市场
	ec.add_market("stone_bridge", "石桥镇集市", "石桥镇")
	ec.add_market_good("stone_bridge", "iron_ore", 10.0, 1.0)
	ec.add_market_good("stone_bridge", "herb", 5.0, 1.2)
	ec.add_market_good("stone_bridge", "grain", 2.0, 0.8)
	ec.add_market_good("stone_bridge", "mana_crystal", 100.0, 1.5)
	# 铁冠城市场
	ec.add_market("iron_crown_market", "铁冠城大集市", "铁冠城")
	ec.add_market_good("iron_crown_market", "iron_ore", 8.0, 1.2)
	ec.add_market_good("iron_crown_market", "mana_crystal", 80.0, 1.8)
	ec.add_market_good("iron_crown_market", "spice", 25.0, 1.3)
	ec.add_market_good("iron_crown_market", "rune_stone", 150.0, 1.5)
	# 月歌城市场
	ec.add_market("moon_song", "月歌城魔法市集", "月歌城")
	ec.add_market_good("moon_song", "mana_crystal", 60.0, 2.0)
	ec.add_market_good("moon_song", "herb", 8.0, 1.5)
	ec.add_market_good("moon_song", "moon_silver", 500.0, 1.0)
	# 铁炉堡市场
	ec.add_market("iron_forge", "铁炉堡锻炉市集", "铁炉堡")
	ec.add_market_good("iron_forge", "iron_ore", 5.0, 0.5)
	ec.add_market_good("iron_forge", "rune_stone", 100.0, 1.2)
	ec.add_market_good("iron_forge", "grain", 4.0, 1.5)
	# 炎阳城市场
	ec.add_market("sun_city", "炎阳城香料集市", "炎阳城")
	ec.add_market_good("sun_city", "spice", 10.0, 0.5)
	ec.add_market_good("sun_city", "iron_ore", 15.0, 1.5)
	ec.add_market_good("sun_city", "grain", 5.0, 1.8)

	# 交易规则
	ec.trade_rules = {
		"barter_enabled": true,
		"barter_rate": 0.8,
		"faction_discount_formula": "base_discount + reputation * 0.01 + guild_level * 0.05",
		"smuggling": {"enabled": true, "risk_factor": 0.3, "penalty": "confiscation + fine"},
		"seasonal_modifier": {
			"winter": {"grain": 1.5, "herb": 1.3},
			"spring": {"herb": 0.7},
			"autumn": {"weapon": 1.2}
		}
	}

	# 产出规则
	ec.production_rules.clear()
	ec.production_rules.append({"resource": "grain", "sources": [{"type": "passive", "formula": "5 + farming_level * 2", "interval": "1d", "action": "harvest", "requires": "farmland"}]})
	ec.production_rules.append({"resource": "iron_ore", "sources": [{"type": "active", "formula": "3 + mining_level * 2", "interval": "1d", "action": "mine", "requires": "mine"}]})
	ec.production_rules.append({"resource": "herb", "sources": [{"type": "active", "formula": "2 + nature_level", "interval": "1d", "action": "gather", "requires": "wilderness"}]})

## === 能力系统数据 ===
static func _apply_ability(ab: AbilitySystemData) -> void:
	# 技能
	ab.skills.clear()
	# 战斗技能
	ab.add_skill("basic_attack", "普通攻击", "active", "physical", "none", "基础物理攻击，无消耗")
	ab.add_skill("shield_bash", "盾击", "active", "physical", "combat", "用盾牌猛击敌人，造成眩晕")
	ab.skills[1]["cost"] = {"mana": 0, "cooldown": "3s"}
	ab.skills[1]["effect"] = {"type": "damage+stun", "formula": "ATK * 0.8", "base_value": 15, "aoe_radius": 0, "status_effect": {"id": "stun", "duration": "1turn"}}

	ab.add_skill("fireball", "火球术", "active", "magic", "毁灭", "凝聚火元素发射爆炸火球。赤金龙脉的力量。")
	ab.skills[2]["school"] = "毁灭"
	ab.skills[2]["cost"] = {"mana": 15, "cooldown": "2s"}
	ab.skills[2]["effect"] = {"type": "magic_damage", "formula": "spell_power * 1.5", "base_value": 25, "aoe_radius": 3, "status_effect": {"id": "burning", "duration": "3s"}}

	ab.add_skill("ice_shard", "冰晶术", "active", "magic", "毁灭", "凝聚冰元素发射穿透冰晶。冰蓝龙脉的力量。")
	ab.skills[3]["school"] = "毁灭"
	ab.skills[3]["cost"] = {"mana": 12, "cooldown": "2s"}
	ab.skills[3]["effect"] = {"type": "magic_damage", "formula": "spell_power * 1.2", "base_value": 20, "aoe_radius": 0, "status_effect": {"id": "frozen", "duration": "2s"}}

	ab.add_skill("heal", "治疗术", "active", "magic", "生命", "自然之神希尔瓦娜的恩赐，恢复生命值")
	ab.skills[4]["school"] = "生命"
	ab.skills[4]["cost"] = {"mana": 20, "cooldown": "5s"}
	ab.skills[4]["effect"] = {"type": "heal", "formula": "spell_power * 2.0", "base_value": 30, "aoe_radius": 0, "status_effect": {}}

	ab.add_skill("shadow_step", "暗影步", "active", "magic", "暗影", "融入阴影瞬移到目标位置。暗影龙脉的力量。")
	ab.skills[5]["school"] = "暗影"
	ab.skills[5]["cost"] = {"mana": 10, "cooldown": "4s"}
	ab.skills[5]["effect"] = {"type": "teleport", "formula": "0", "base_value": 0, "aoe_radius": 0, "status_effect": {"id": "stealth", "duration": "1turn"}}

	ab.add_skill("war_cry", "战吼", "active", "support", "战气", "战争之神卡恩的力量，提升全队攻击力")
	ab.skills[6]["school"] = "战气"
	ab.skills[6]["cost"] = {"mana": 0, "cooldown": "8s"}
	ab.skills[6]["effect"] = {"type": "buff", "formula": "ATK * 0.2", "base_value": 10, "aoe_radius": 5, "status_effect": {"id": "war_cry_buff", "duration": "3turns"}}

	ab.add_skill("summon_elemental", "召唤元素", "active", "magic", "召唤", "从龙脉中召唤元素生物协助战斗")
	ab.skills[7]["school"] = "召唤"
	ab.skills[7]["requirements"] = {"level": 10, "attributes": {}, "prerequisites": ["fireball"]}
	ab.skills[7]["cost"] = {"mana": 40, "cooldown": "30s"}

	# 被动技能
	ab.add_skill("toughness", "坚韧", "passive", "passive_stat", "none", "提升最大生命值")
	ab.skills[8]["effect"] = {"type": "passive_stat", "formula": "max_hp * 0.1", "base_value": 0, "aoe_radius": 0, "status_effect": {}}

	ab.add_skill("mana_flow", "魔力涌流", "passive", "passive_stat", "none", "提升魔力恢复速度")
	ab.skills[9]["effect"] = {"type": "passive_stat", "formula": "mana_regen * 0.15", "base_value": 0, "aoe_radius": 0, "status_effect": {}}

	# 成长路线
	ab.growth_paths.clear()
	ab.add_growth_path("path_warrior", "战士之路", "追求物理力量极致的成长路线。铁冠王朝骑士团的标准训练。")
	ab.add_growth_stage("path_warrior", 1, "新兵", [1, 10], {"hp": "+20%", "atk": "+10%"})
	ab.add_growth_stage("path_warrior", 2, "战士", [11, 25], {"hp": "+30%", "atk": "+20%", "def": "+15%"})
	ab.add_growth_stage("path_warrior", 3, "精英战士", [26, 40], {"hp": "+40%", "atk": "+30%", "def": "+25%"})
	ab.add_growth_stage("path_warrior", 4, "骑士", [41, 60], {"hp": "+50%", "atk": "+40%", "def": "+35%", "special_ability": "战气觉醒"})

	ab.add_growth_path("path_mage", "法师之路", "追求魔法极致的成长路线。铁冠皇家魔法学院的正统教育。")
	ab.add_growth_stage("path_mage", 1, "学徒", [1, 10], {"mana_pool": "+20%", "magic_damage": "+10%"})
	ab.add_growth_stage("path_mage", 2, "法师", [11, 25], {"mana_pool": "+35%", "magic_damage": "+25%", "mana_regen": "+15%"})
	ab.add_growth_stage("path_mage", 3, "大法师", [26, 40], {"mana_pool": "+50%", "magic_damage": "+40%", "mana_regen": "+25%"})
	ab.add_growth_stage("path_mage", 4, "宫廷法师", [41, 60], {"mana_pool": "+70%", "magic_damage": "+55%", "mana_regen": "+35%", "special_ability": "龙脉共鸣"})

	ab.add_growth_path("path_rogue", "游荡者之路", "追求敏捷与隐秘的成长路线。刺客行会的训练方式。")
	ab.add_growth_stage("path_rogue", 1, "小偷", [1, 10], {"agility": "+20%", "crit_rate": "+5%"})
	ab.add_growth_stage("path_rogue", 2, "游荡者", [11, 25], {"agility": "+35%", "crit_rate": "+10%", "stealth": "+20%"})
	ab.add_growth_stage("path_rogue", 3, "刺客", [26, 40], {"agility": "+50%", "crit_rate": "+15%", "stealth": "+35%"})
	ab.add_growth_stage("path_rogue", 4, "暗影大师", [41, 60], {"agility": "+65%", "crit_rate": "+20%", "stealth": "+50%", "special_ability": "暗影步"})

	ab.add_growth_path("path_dragonborn", "龙血觉醒", "龙裔专属路线。龙血觉醒四阶段：潜伏→显现→觉醒→龙化。")
	ab.add_growth_stage("path_dragonborn", 1, "潜伏期", [1, 15], {"all_stats": "+5%", "description": "龙血沉睡，无法察觉"})
	ab.add_growth_stage("path_dragonborn", 2, "显现期", [16, 30], {"all_stats": "+15%", "dragon_breath": true, "description": "龙族特征开始出现"})
	ab.add_growth_stage("path_dragonborn", 3, "觉醒期", [31, 50], {"all_stats": "+30%", "dragon_breath": true, "dragon_scales": true, "description": "龙族力量全面释放"})
	ab.add_growth_stage("path_dragonborn", 4, "龙化期", [51, 70], {"all_stats": "+50%", "dragon_form": true, "description": "接近完全龙化，几乎不可逆"})

	# 状态效果
	ab.status_effects.clear()
	ab.add_status_effect("burning", "燃烧", "dot")
	ab.status_effects[0]["description"] = "火焰伤害持续，每回合损失HP"
	ab.status_effects[0]["damage_per_tick"] = 5
	ab.status_effects[0]["duration"] = "3s"
	ab.status_effects[0]["stackable"] = true
	ab.status_effects[0]["max_stacks"] = 3

	ab.add_status_effect("frozen", "冰冻", "debuff")
	ab.status_effects[1]["description"] = "移动速度降低，无法行动"
	ab.status_effects[1]["duration"] = "2s"

	ab.add_status_effect("stun", "眩晕", "debuff")
	ab.status_effects[2]["description"] = "无法行动，防御降低"
	ab.status_effects[2]["duration"] = "1turn"

	ab.add_status_effect("stealth", "隐身", "buff")
	ab.status_effects[3]["description"] = "进入隐身状态，下次攻击暴击率提升"
	ab.status_effects[3]["duration"] = "1turn"

	ab.add_status_effect("war_cry_buff", "战吼增益", "buff")
	ab.status_effects[4]["description"] = "攻击力提升"
	ab.status_effects[4]["duration"] = "3turns"

	ab.add_status_effect("poisoned", "中毒", "dot")
	ab.status_effects[5]["description"] = "暗影龙脉的毒素，持续损失HP并降低属性"
	ab.status_effects[5]["damage_per_tick"] = 3
	ab.status_effects[5]["duration"] = "5s"
	ab.status_effects[5]["stackable"] = true
	ab.status_effects[5]["max_stacks"] = 5

	# 战斗机制
	ab.initialize_combat_defaults()
	ab.combat_definition["type"] = "turn_based"
	ab.combat_definition["elements"] = ["fire", "ice", "lightning", "poison", "light", "shadow", "earth", "storm"]
	ab.combat_definition["turn_order_formula"] = "speed * (1 + agility * 0.01) + random(0, 5)"

	# 元素相克表（8元素版）
	ab.element_matrix = {
		"fire": {"ice": 2.0, "lightning": 1.2, "poison": 1.0, "light": 1.0, "shadow": 1.0, "earth": 1.5, "storm": 0.8},
		"ice": {"fire": 0.5, "lightning": 1.5, "poison": 1.0, "light": 1.0, "shadow": 1.0, "earth": 0.8, "storm": 1.3},
		"lightning": {"fire": 0.8, "ice": 0.7, "poison": 1.2, "light": 1.0, "shadow": 1.0, "earth": 0.5, "storm": 1.5},
		"poison": {"fire": 1.0, "ice": 1.0, "lightning": 0.8, "light": 1.5, "shadow": 2.0, "earth": 1.0, "storm": 0.7},
		"light": {"fire": 1.0, "ice": 1.0, "lightning": 1.0, "poison": 0.7, "shadow": 2.0, "earth": 1.0, "storm": 1.0},
		"shadow": {"fire": 1.0, "ice": 1.0, "lightning": 1.0, "poison": 0.5, "light": 0.5, "earth": 1.0, "storm": 1.0},
		"earth": {"fire": 0.7, "ice": 1.3, "lightning": 2.0, "poison": 1.0, "light": 1.0, "shadow": 1.0, "storm": 0.5},
		"storm": {"fire": 1.2, "ice": 0.8, "lightning": 0.7, "poison": 1.3, "light": 1.0, "shadow": 1.0, "earth": 2.0}
	}
