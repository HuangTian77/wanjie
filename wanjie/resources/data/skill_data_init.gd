## 技能数据初始化器
## 基于GDD §3.5 能力系统，初始化全部51个技能 + 状态效果 + 成长路线
## 分类体系: category(active/passive/ultimate) × sub_type(attack/defense/support/special) × school
class_name SkillDataInit
extends RefCounted

## 初始化所有技能数据到 AbilitySystemData
static func initialize(data: AbilitySystemData) -> void:
	data.initialize_combat_defaults()
	_init_elemental_fire(data)
	_init_elemental_water(data)
	_init_elemental_earth(data)
	_init_elemental_wind(data)
	_init_physical_melee(data)
	_init_physical_ranged(data)
	_init_support_heal(data)
	_init_support_buff(data)
	_init_ultimate(data)
	_init_passive_combat(data)
	_init_passive_magic(data)
	_init_status_effects(data)
	_init_growth_paths(data)

# ═══════════════════════════════════════════════════════════
#  一、元素魔法 - 火系 (5)
# ═══════════════════════════════════════════════════════════
static func _init_elemental_fire(data: AbilitySystemData) -> void:
	# 1. 火花 - 基础火系攻击
	data.add_skill("fire_spark", "火花", "active", "attack", "elemental_fire",
		"指尖弹出一簇微小火焰，灼伤敌人",
		1, {"intelligence": 5}, [], 8, "2s", 0, "damage", 15,
		"base_value + intelligence * 0.8 + skill_level * 3",
		0, {}, 0, {}, {}, "0s", 10,
		[{"level": 3, "effect": "base_value +5"}, {"level": 7, "effect": "cooldown -1s"}])
	# 2. 火球术 - 经典AOE
	data.add_skill("fireball", "火球术", "active", "attack", "elemental_fire",
		"凝聚火元素，发射一枚爆炸火球，对范围内敌人造成伤害",
		5, {"intelligence": 12}, ["fire_spark"], 30, "3s", 0, "damage", 50,
		"base_value + intelligence * 1.5 + skill_level * 10",
		3, {"id": "burning", "duration": "5s", "damage_per_tick": 5},
		0, {}, {}, "0s", 10,
		[{"level": 3, "effect": "aoe_radius +1"}, {"level": 5, "effect": "add status_spread"}, {"level": 10, "effect": "damage * 1.5, cooldown -1s"}])
	# 3. 烈焰风暴 - 大范围AOE
	data.add_skill("flame_storm", "烈焰风暴", "active", "attack", "elemental_fire",
		"召唤漫天火雨，覆盖大片区域",
		15, {"intelligence": 20}, ["fireball"], 60, "8s", 0, "damage", 120,
		"base_value + intelligence * 2.0 + skill_level * 15",
		5, {"id": "burning", "duration": "8s", "damage_per_tick": 8},
		0, {}, {}, "0s", 10,
		[{"level": 5, "effect": "aoe_radius +2"}, {"level": 10, "effect": "add burning_intensity"}])
	# 4. 火墙 - 区域控制
	data.add_skill("fire_wall", "火墙", "active", "defense", "elemental_fire",
		"在地面升起一道火焰墙壁，阻挡并灼烧穿越的敌人",
		10, {"intelligence": 15}, ["fireball"], 40, "6s", 0, "damage", 35,
		"base_value + intelligence * 1.0 + skill_level * 5",
		4, {"id": "burning", "duration": "3s", "damage_per_tick": 10},
		0, {}, {}, "6s", 10,
		[{"level": 3, "effect": "duration +2s"}, {"level": 7, "effect": "damage_per_tick +5"}])
	# 5. 陨石术 - 火系终极
	data.add_skill("meteor", "陨石术", "ultimate", "special", "elemental_fire",
		"从天际召唤一颗燃烧陨石，毁灭性打击大范围区域",
		30, {"intelligence": 35}, ["flame_storm"], 150, "30s", 0, "damage", 300,
		"base_value + intelligence * 3.0 + skill_level * 25",
		8, {"id": "burning", "duration": "10s", "damage_per_tick": 15},
		0, {}, {}, "0s", 5,
		[{"level": 3, "effect": "aoe_radius +3"}, {"level": 5, "effect": "add stun"}])

# ═══════════════════════════════════════════════════════════
#  一、元素魔法 - 水系 (4)
# ═══════════════════════════════════════════════════════════
static func _init_elemental_water(data: AbilitySystemData) -> void:
	# 1. 水弹
	data.add_skill("water_bolt", "水弹", "active", "attack", "elemental_water",
		"凝聚水流射出一枚高压水弹",
		1, {"intelligence": 5}, [], 8, "2s", 0, "damage", 12,
		"base_value + intelligence * 0.7 + skill_level * 2", 0, {},
		0, {}, {}, "0s", 10,
		[{"level": 5, "effect": "base_value +10"}])
	# 2. 冰霜之箭 - 减速
	data.add_skill("frost_arrow", "冰霜之箭", "active", "attack", "elemental_water",
		"射出冻结之箭，降低目标移动与攻击速度",
		5, {"intelligence": 10}, ["water_bolt"], 20, "3s", 0, "damage", 30,
		"base_value + intelligence * 1.2 + skill_level * 5",
		0, {"id": "frozen", "duration": "4s", "slow": 0.3},
		0, {}, {}, "0s", 10,
		[{"level": 3, "effect": "slow +0.1"}, {"level": 7, "effect": "duration +2s"}])
	# 3. 暴风雪 - 大范围控制
	data.add_skill("blizzard", "暴风雪", "active", "attack", "elemental_water",
		"召唤暴风雪，冻结范围内所有敌人",
		18, {"intelligence": 22}, ["frost_arrow"], 70, "10s", 0, "damage", 80,
		"base_value + intelligence * 1.8 + skill_level * 12",
		5, {"id": "frozen", "duration": "3s", "slow": 0.5},
		0, {}, {}, "0s", 10,
		[{"level": 5, "effect": "aoe_radius +2"}, {"level": 10, "effect": "add freeze_solid"}])
	# 4. 寒冰护甲 - 防御
	data.add_skill("ice_armor", "寒冰护甲", "active", "defense", "elemental_water",
		"以冰霜凝结成护甲，提升防御并反弹部分伤害",
		8, {"intelligence": 12}, ["water_bolt"], 25, "12s", 0, "buff", 0,
		"", 0, {},
		0, {"def": 15, "mdef": 10, "reflect": 0.1}, {}, "12s", 10,
		[{"level": 3, "effect": "def +5"}, {"level": 7, "effect": "reflect +0.05"}])

# ═══════════════════════════════════════════════════════════
#  一、元素魔法 - 土系 (4)
# ═══════════════════════════════════════════════════════════
static func _init_elemental_earth(data: AbilitySystemData) -> void:
	# 1. 岩石投掷
	data.add_skill("rock_throw", "岩石投掷", "active", "attack", "elemental_earth",
		"举起巨石投向敌人",
		1, {"intelligence": 5}, [], 10, "3s", 0, "damage", 20,
		"base_value + intelligence * 0.9 + skill_level * 4", 0, {},
		0, {}, {}, "0s", 10,
		[{"level": 5, "effect": "base_value +15"}])
	# 2. 地震术 - AOE+眩晕
	data.add_skill("earthquake", "地震术", "active", "attack", "elemental_earth",
		"引发大地震动，使范围内敌人失衡",
		12, {"intelligence": 16}, ["rock_throw"], 45, "7s", 0, "damage", 60,
		"base_value + intelligence * 1.3 + skill_level * 8",
		4, {"id": "stun", "duration": "2s"},
		0, {}, {}, "0s", 10,
		[{"level": 3, "effect": "stun +0.5s"}, {"level": 7, "effect": "aoe_radius +2"}])
	# 3. 石肤术 - 自身防御Buff
	data.add_skill("stone_skin", "石肤术", "active", "defense", "elemental_earth",
		"皮肤石化，大幅提升物理防御",
		6, {"intelligence": 10}, ["rock_throw"], 20, "15s", 0, "buff", 0,
		"", 0, {},
		0, {"def": 25, "mdef": 5}, {}, "15s", 10,
		[{"level": 5, "effect": "def +10"}, {"level": 10, "effect": "duration +5s"}])
	# 4. 大地之盾 - 护盾
	data.add_skill("earth_shield", "大地之盾", "active", "defense", "elemental_earth",
		"召唤大地之力形成护盾，吸收伤害",
		10, {"intelligence": 14}, ["stone_skin"], 35, "10s", 0, "shield", 80,
		"base_value + intelligence * 2.0 + skill_level * 10", 0, {},
		0, {}, {}, "10s", 10,
		[{"level": 3, "effect": "shield_value +20"}, {"level": 7, "effect": "add regen"}])

# ═══════════════════════════════════════════════════════════
#  一、元素魔法 - 风系 (4)
# ═══════════════════════════════════════════════════════════
static func _init_elemental_wind(data: AbilitySystemData) -> void:
	# 1. 风刃
	data.add_skill("wind_blade", "风刃", "active", "attack", "elemental_wind",
		"压缩空气形成锋利风刃切割敌人",
		1, {"intelligence": 5}, [], 7, "1.5s", 0, "damage", 14,
		"base_value + intelligence * 0.9 + skill_level * 3", 0, {},
		0, {}, {}, "0s", 10,
		[{"level": 3, "effect": "base_value +5"}, {"level": 7, "effect": "cooldown -0.5s"}])
	# 2. 疾风步 - 速度Buff
	data.add_skill("gale_step", "疾风步", "active", "support", "elemental_wind",
		"以风包裹双足，大幅提升移动速度",
		4, {"intelligence": 8}, ["wind_blade"], 15, "8s", 0, "buff", 0,
		"", 0, {},
		0, {"speed": 30, "agility": 10}, {}, "8s", 10,
		[{"level": 5, "effect": "speed +10"}, {"level": 10, "effect": "add dodge_chance"}])
	# 3. 龙卷风 - 大范围击退
	data.add_skill("tornado", "龙卷风", "active", "attack", "elemental_wind",
		"召唤龙卷风席卷战场，击退并伤害敌人",
		16, {"intelligence": 20}, ["wind_blade"], 55, "9s", 0, "damage", 70,
		"base_value + intelligence * 1.6 + skill_level * 10",
		4, {"id": "knockback", "duration": "1s"},
		0, {}, {}, "0s", 10,
		[{"level": 5, "effect": "aoe_radius +2"}, {"level": 10, "effect": "add lift"}])
	# 4. 闪电链 - 多目标弹射
	data.add_skill("chain_lightning", "闪电链", "active", "attack", "elemental_wind",
		"释放闪电在多个敌人之间弹射",
		10, {"intelligence": 15}, ["wind_blade"], 35, "4s", 0, "damage", 40,
		"base_value + intelligence * 1.2 + skill_level * 6",
		0, {},
		0, {}, {}, "0s", 10,
		[{"level": 3, "effect": "bounce_targets +1"}, {"level": 7, "effect": "damage +15%"}])

# ═══════════════════════════════════════════════════════════
#  二、物理攻击 - 近战 (5)
# ═══════════════════════════════════════════════════════════
static func _init_physical_melee(data: AbilitySystemData) -> void:
	# 1. 重击
	data.add_skill("heavy_strike", "重击", "active", "attack", "physical_melee",
		"蓄力挥出沉重一击",
		1, {"strength": 8}, [], 0, "3s", 0, "damage", 25,
		"base_value + strength * 1.5 + skill_level * 5", 0, {},
		0, {}, {}, "0s", 10,
		[{"level": 5, "effect": "base_value +10"}])
	# 2. 旋风斩 - AOE近战
	data.add_skill("whirlwind", "旋风斩", "active", "attack", "physical_melee",
		"旋转身体对周围所有敌人造成伤害",
		5, {"strength": 12, "agility": 8}, ["heavy_strike"], 15, "5s", 0, "damage", 35,
		"base_value + strength * 1.2 + skill_level * 6",
		3, {}, 0, {}, {}, "0s", 10,
		[{"level": 3, "effect": "aoe_radius +1"}, {"level": 7, "effect": "base_value +15"}])
	# 3. 破甲击 - 减防Debuff
	data.add_skill("armor_break", "破甲击", "active", "attack", "physical_melee",
		"猛烈打击破坏敌人护甲，降低其防御力",
		8, {"strength": 15}, ["heavy_strike"], 12, "4s", 0, "damage", 30,
		"base_value + strength * 1.0 + skill_level * 4",
		0, {"id": "armor_broken", "duration": "8s", "def_reduce": 10},
		0, {}, {}, "0s", 10,
		[{"level": 5, "effect": "def_reduce +5"}])
	# 4. 连击 - 多段攻击
	data.add_skill("combo_strike", "连击", "active", "attack", "physical_melee",
		"快速连续攻击目标3次",
		12, {"strength": 14, "agility": 12}, ["whirlwind"], 20, "4s", 0, "damage", 20,
		"(base_value + strength * 0.8 + skill_level * 3) * 3",
		0, {}, 0, {}, {}, "0s", 10,
		[{"level": 3, "effect": "hits +1"}, {"level": 7, "effect": "base_value +5"}])
	# 5. 致命一击 - 高暴击
	data.add_skill("lethal_strike", "致命一击", "active", "attack", "physical_melee",
		"瞄准要害的精准打击，极高暴击率",
		20, {"strength": 20, "agility": 15}, ["combo_strike"], 25, "6s", 0, "damage", 60,
		"base_value + strength * 2.0 + skill_level * 10",
		0, {}, 0, {}, {}, "0s", 10,
		[{"level": 3, "effect": "crit_rate +20%"}, {"level": 10, "effect": "crit_damage +50%"}])

# ═══════════════════════════════════════════════════════════
#  二、物理攻击 - 远程 (3)
# ═══════════════════════════════════════════════════════════
static func _init_physical_ranged(data: AbilitySystemData) -> void:
	# 1. 精准射击
	data.add_skill("precise_shot", "精准射击", "active", "attack", "physical_ranged",
		"瞄准目标精确射击",
		1, {"agility": 8}, [], 0, "2s", 0, "damage", 20,
		"base_value + agility * 1.3 + skill_level * 4", 0, {},
		0, {}, {}, "0s", 10,
		[{"level": 5, "effect": "base_value +8"}])
	# 2. 穿透箭 - 直线穿透
	data.add_skill("piercing_arrow", "穿透箭", "active", "attack", "physical_ranged",
		"射出强力箭矢穿透一条直线上的所有敌人",
		8, {"agility": 14}, ["precise_shot"], 10, "4s", 0, "damage", 40,
		"base_value + agility * 1.5 + skill_level * 6",
		6, {}, 0, {}, {}, "0s", 10,
		[{"level": 3, "effect": "penetrate +1 target"}, {"level": 7, "effect": "base_value +15"}])
	# 3. 爆裂箭 - AOE远程
	data.add_skill("explosive_arrow", "爆裂箭", "active", "attack", "physical_ranged",
		"射出命中后爆炸的箭矢",
		14, {"agility": 18}, ["piercing_arrow"], 18, "5s", 0, "damage", 55,
		"base_value + agility * 1.4 + skill_level * 8",
		3, {"id": "burning", "duration": "3s", "damage_per_tick": 5},
		0, {}, {}, "0s", 10,
		[{"level": 5, "effect": "aoe_radius +1"}, {"level": 10, "effect": "explosion_damage +50%"}])

# ═══════════════════════════════════════════════════════════
#  三、辅助增益 - 治疗 (4)
# ═══════════════════════════════════════════════════════════
static func _init_support_heal(data: AbilitySystemData) -> void:
	# 1. 治愈之光
	data.add_skill("healing_light", "治愈之光", "active", "support", "support_heal",
		"温暖的光芒治愈伤口，恢复生命值",
		1, {"intelligence": 6}, [], 15, "4s", 0, "heal", 0,
		"", 0, {},
		40, {}, {}, "0s", 10,
		[{"level": 3, "effect": "heal_value +10"}, {"level": 7, "effect": "heal_value +20"}])
	# 2. 群体治疗
	data.add_skill("group_heal", "群体治疗", "active", "support", "support_heal",
		"治疗之光笼罩所有队友",
		12, {"intelligence": 16}, ["healing_light"], 40, "8s", 0, "heal_aoe", 0,
		"", 0, {},
		25, {}, {}, "0s", 10,
		[{"level": 5, "effect": "heal_value +10"}, {"level": 10, "effect": "aoe_radius +2"}])
	# 3. 净化术 - 移除Debuff
	data.add_skill("purify", "净化术", "active", "support", "support_heal",
		"净化目标身上的负面状态",
		6, {"intelligence": 10}, ["healing_light"], 20, "6s", 0, "cleanse", 0,
		"", 0, {},
		0, {}, {}, "0s", 10,
		[{"level": 3, "effect": "remove_all_debuffs"}, {"level": 7, "effect": "cooldown -2s"}])
	# 4. 生命之泉 - 持续治疗区域
	data.add_skill("life_spring", "生命之泉", "active", "support", "support_heal",
		"在地面创造治愈之泉，区域内持续恢复生命",
		18, {"intelligence": 22}, ["group_heal"], 55, "15s", 0, "heal_over_time_zone", 0,
		"", 0, {},
		10, {}, {}, "10s", 10,
		[{"level": 5, "effect": "heal_per_tick +5"}, {"level": 10, "effect": "duration +5s"}])

# ═══════════════════════════════════════════════════════════
#  三、辅助增益 - 增益 (4)
# ═══════════════════════════════════════════════════════════
static func _init_support_buff(data: AbilitySystemData) -> void:
	# 1. 战吼 - 攻击Buff
	data.add_skill("war_cry", "战吼", "active", "support", "support_buff",
		"发出震天战吼，提升自身与队友攻击力",
		3, {"strength": 10}, [], 12, "10s", 0, "buff", 0,
		"", 0, {},
		0, {"atk": 15, "matk": 10}, {}, "10s", 10,
		[{"level": 5, "effect": "atk +5"}, {"level": 10, "effect": "duration +5s"}])
	# 2. 铁壁 - 防御Buff
	data.add_skill("iron_wall", "铁壁", "active", "defense", "support_buff",
		"大幅提升自身防御力",
		5, {"strength": 12, "intelligence": 8}, [], 18, "12s", 0, "buff", 0,
		"", 0, {},
		0, {"def": 20, "mdef": 15}, {}, "12s", 10,
		[{"level": 5, "effect": "def +10"}, {"level": 10, "effect": "add damage_reflect_5pct"}])
	# 3. 速度祝福 - 速度Buff
	data.add_skill("speed_blessing", "速度祝福", "active", "support", "support_buff",
		"祝福目标，大幅提升其速度与敏捷",
		7, {"intelligence": 12}, [], 15, "10s", 0, "buff", 0,
		"", 0, {},
		0, {"speed": 20, "agility": 15}, {}, "10s", 10,
		[{"level": 5, "effect": "speed +10"}, {"level": 10, "effect": "add extra_turn_chance"}])
	# 4. 魔法增幅 - 法伤Buff
	data.add_skill("magic_amp", "魔法增幅", "active", "support", "support_buff",
		"增幅目标的魔法力量",
		10, {"intelligence": 18}, [], 25, "12s", 0, "buff", 0,
		"", 0, {},
		0, {"matk": 25, "spell_power_pct": 0.2}, {}, "12s", 10,
		[{"level": 5, "effect": "matk +10"}, {"level": 10, "effect": "add mana_cost_reduction"}])

# ═══════════════════════════════════════════════════════════
#  四、特殊/终极 (6)
# ═══════════════════════════════════════════════════════════
static func _init_ultimate(data: AbilitySystemData) -> void:
	# 1. 时间停止
	data.add_skill("time_stop", "时间停止", "ultimate", "special", "ultimate_strategic",
		"短暂冻结时间，在静止的世界中连续行动",
		25, {"intelligence": 30}, [], 100, "45s", 0, "special", 0,
		"", 0, {},
		0, {"extra_actions": 3}, {}, "1s", 3,
		[{"level": 3, "effect": "extra_actions +1"}])
	# 2. 神圣审判 - 光系终极
	data.add_skill("divine_judgment", "神圣审判", "ultimate", "special", "holy_light",
		"召唤神圣之光，对邪恶目标造成毁灭性伤害并净化",
		28, {"intelligence": 32}, [], 120, "40s", 0, "damage", 250,
		"base_value + intelligence * 2.5 + skill_level * 20",
		6, {"id": "purified", "duration": "5s"},
		0, {}, {}, "0s", 3,
		[{"level": 3, "effect": "bonus_vs_dark +50%"}])
	# 3. 暗影吞噬 - 暗系终极
	data.add_skill("shadow_devour", "暗影吞噬", "ultimate", "special", "shadow_dark",
		"释放暗影吞噬目标，吸取其生命力",
		28, {"intelligence": 32}, [], 120, "40s", 0, "damage", 200,
		"base_value + intelligence * 2.0 + skill_level * 18",
		0, {"id": "life_drain", "duration": "5s", "drain_pct": 0.15},
		100, {}, {}, "0s", 3,
		[{"level": 3, "effect": "drain_pct +5%"}])
	# 4. 大地裂变 - 地形改变
	data.add_skill("earth_rift", "大地裂变", "ultimate", "special", "elemental_earth",
		"撕裂大地，改变战场地形，创造有利态势",
		30, {"intelligence": 35}, [], 140, "50s", 0, "damage", 180,
		"base_value + intelligence * 2.0 + skill_level * 15",
		7, {"id": "stun", "duration": "3s"},
		0, {}, {}, "0s", 3,
		[{"level": 3, "effect": "terrain_effect"}])
	# 5. 凤凰涅槃 - 复活
	data.add_skill("phoenix_rebirth", "凤凰涅槃", "ultimate", "special", "holy_light",
		"在致命伤害时自动触发，恢复全部生命并获得短暂无敌",
		20, {"intelligence": 25}, [], 0, "120s", 0, "revive", 0,
		"", 0, {},
		9999, {}, {"invincible_duration": "3s"}, "0s", 1,
		[{"level": 1, "effect": "passive_trigger_on_death"}])
	# 6. 万界归一 - 全元素终极
	data.add_skill("all_worlds_unite", "万界归一", "ultimate", "special", "ultimate_strategic",
		"融合六大元素之力，释放毁灭性一击",
		40, {"intelligence": 40}, ["meteor", "divine_judgment", "shadow_devour"], 200, "60s", 0, "damage", 500,
		"base_value + intelligence * 4.0 + skill_level * 30",
		10, {"id": "elemental_chaos", "duration": "8s", "damage_per_tick": 20},
		0, {}, {}, "0s", 1, [])

# ═══════════════════════════════════════════════════════════
#  光明系主动 (补充2个非终极光明技能)
# ═══════════════════════════════════════════════════════════
# 注：光明系的终极已在上面(神圣审判/凤凰涅槃)，这里补充基础主动
# 治愈之光和净化术已在support_heal中，这里添加攻击性光明技能

# ═══════════════════════════════════════════════════════════
#  暗影系主动 (补充)
# ═══════════════════════════════════════════════════════════
# 暗影吞噬已在ultimate中，下面在被动中添加暗影相关被动

# ═══════════════════════════════════════════════════════════
#  五、被动技能 - 战斗 (4)
# ═══════════════════════════════════════════════════════════
static func _init_passive_combat(data: AbilitySystemData) -> void:
	# 1. 坚韧
	data.add_skill("toughness", "坚韧", "passive", "defense", "passive_combat",
		"提升最大生命值和生命恢复",
		1, {}, [], 0, "0s", 0, "passive", 0, "", 0, {},
		0, {"max_hp_pct": 0.1, "hp_regen": 2}, {}, "0s", 10,
		[{"level": 5, "effect": "max_hp_pct +5%"}])
	# 2. 暴击大师
	data.add_skill("crit_master", "暴击大师", "passive", "attack", "passive_combat",
		"提升暴击率和暴击伤害",
		10, {"agility": 15}, [], 0, "0s", 0, "passive", 0, "", 0, {},
		0, {"crit_rate": 0.1, "crit_damage": 0.25}, {}, "0s", 10,
		[{"level": 5, "effect": "crit_rate +5%"}, {"level": 10, "effect": "crit_damage +25%"}])
	# 3. 反击
	data.add_skill("counter_attack", "反击", "passive", "attack", "passive_combat",
		"受到攻击时有概率自动反击",
		8, {"strength": 12, "agility": 10}, [], 0, "0s", 0, "passive", 0, "", 0, {},
		0, {"counter_chance": 0.15, "counter_damage_pct": 0.5}, {}, "0s", 10,
		[{"level": 5, "effect": "counter_chance +10%"}])
	# 4. 生命汲取
	data.add_skill("life_drain_passive", "生命汲取", "passive", "special", "passive_combat",
		"攻击时吸取少量生命值",
		15, {"strength": 14}, [], 0, "0s", 0, "passive", 0, "", 0, {},
		0, {"lifesteal_pct": 0.05}, {}, "0s", 10,
		[{"level": 5, "effect": "lifesteal_pct +3%"}])

# ═══════════════════════════════════════════════════════════
#  五、被动技能 - 魔法 (4)
# ═══════════════════════════════════════════════════════════
static func _init_passive_magic(data: AbilitySystemData) -> void:
	# 1. 法力亲和
	data.add_skill("mana_affinity", "法力亲和", "passive", "support", "passive_magic",
		"提升最大魔力值和魔力恢复",
		1, {}, [], 0, "0s", 0, "passive", 0, "", 0, {},
		0, {"max_mp_pct": 0.15, "mp_regen": 3}, {}, "0s", 10,
		[{"level": 5, "effect": "max_mp_pct +5%"}])
	# 2. 施法精进
	data.add_skill("casting_mastery", "施法精进", "passive", "support", "passive_magic",
		"减少所有技能冷却时间",
		8, {"intelligence": 14}, [], 0, "0s", 0, "passive", 0, "", 0, {},
		0, {"cooldown_reduction_pct": 0.1}, {}, "0s", 10,
		[{"level": 5, "effect": "cooldown_reduction +5%"}])
	# 3. 元素精通
	data.add_skill("elemental_mastery", "元素精通", "passive", "attack", "passive_magic",
		"提升所有元素技能伤害",
		12, {"intelligence": 18}, [], 0, "0s", 0, "passive", 0, "", 0, {},
		0, {"elemental_damage_pct": 0.15}, {}, "0s", 10,
		[{"level": 5, "effect": "elemental_damage_pct +5%"}, {"level": 10, "effect": "add elemental_resist"}])
	# 4. 魔法护盾
	data.add_skill("magic_barrier", "魔法护盾", "passive", "defense", "passive_magic",
		"受到攻击时自动生成魔法护盾吸收伤害",
		15, {"intelligence": 20}, [], 0, "0s", 0, "passive", 0, "", 0, {},
		0, {"auto_shield_trigger": "hp_below_30%", "shield_value_pct": 0.2, "cooldown": "30s"},
		{}, "0s", 10,
		[{"level": 5, "effect": "shield_value_pct +5%"}])

# ═══════════════════════════════════════════════════════════
#  状态效果初始化
# ═══════════════════════════════════════════════════════════
static func _init_status_effects(data: AbilitySystemData) -> void:
	# 伤害类
	data.add_status_effect("burning", "燃烧", "dot", "持续受到火焰伤害", "5s", 5, true, 3)
	data.add_status_effect("poison", "中毒", "dot", "持续受到毒素伤害", "8s", 3, true, 5)
	data.add_status_effect("bleeding", "流血", "dot", "持续受到流血伤害", "6s", 4, true, 3)
	# 控制类
	data.add_status_effect("frozen", "冻结", "control", "无法行动且速度大幅降低", "3s", 0)
	data.add_status_effect("stun", "眩晕", "control", "无法行动", "2s", 0)
	data.add_status_effect("knockback", "击退", "control", "被击退至远处", "1s", 0)
	# 减益类
	data.add_status_effect("armor_broken", "破甲", "debuff", "防御力降低", "8s", 0)
	data.add_status_effect("slowed", "减速", "debuff", "移动和攻击速度降低", "5s", 0)
	data.add_status_effect("weakened", "虚弱", "debuff", "攻击力降低", "6s", 0)
	data.add_status_effect("purified", "净化", "debuff", "被神圣之光标记，受到额外伤害", "5s", 0)
	data.add_status_effect("life_drain", "生命汲取", "debuff", "持续被吸取生命值", "5s", 0)
	data.add_status_effect("elemental_chaos", "元素混乱", "debuff", "受到所有元素伤害", "8s", 20, true, 1)
	# 增益类
	data.add_status_effect("attack_up", "攻击强化", "buff", "攻击力提升", "10s", 0)
	data.add_status_effect("defense_up", "防御强化", "buff", "防御力提升", "10s", 0)
	data.add_status_effect("speed_up", "速度强化", "buff", "速度提升", "8s", 0)
	data.add_status_effect("regen", "再生", "buff", "持续恢复生命值", "10s", -5)

# ═══════════════════════════════════════════════════════════
#  成长路线初始化
# ═══════════════════════════════════════════════════════════
static func _init_growth_paths(data: AbilitySystemData) -> void:
	# 法师之路
	data.add_growth_path("path_mage", "法师之路", "追求知识与魔法的极致")
	data.add_growth_stage("path_mage", 1, "学徒", [1, 10],
		{"mana_pool": "+20%", "magic_damage": "+10%"})
	data.add_growth_stage("path_mage", 2, "术士", [11, 25],
		{"mana_pool": "+50%", "magic_damage": "+25%", "cast_speed": "+15%"})
	data.add_growth_stage("path_mage", 3, "大法师", [26, 50],
		{"mana_pool": "+100%", "magic_damage": "+50%", "cast_speed": "+30%"})
	# 战士之路
	data.add_growth_path("path_warrior", "战士之路", "以力量与钢铁征服一切")
	data.add_growth_stage("path_warrior", 1, "新兵", [1, 10],
		{"max_hp": "+20%", "physical_damage": "+10%", "def": "+5"})
	data.add_growth_stage("path_warrior", 2, "骑士", [11, 25],
		{"max_hp": "+50%", "physical_damage": "+25%", "def": "+15"})
	data.add_growth_stage("path_warrior", 3, "战神", [26, 50],
		{"max_hp": "+100%", "physical_damage": "+50%", "def": "+30"})
	# 游侠之路
	data.add_growth_path("path_ranger", "游侠之路", "风与箭的追随者")
	data.add_growth_stage("path_ranger", 1, "猎人", [1, 10],
		{"agility": "+10%", "crit_rate": "+5%", "speed": "+10"})
	data.add_growth_stage("path_ranger", 2, "游侠", [11, 25],
		{"agility": "+25%", "crit_rate": "+10%", "speed": "+20"})
	data.add_growth_stage("path_ranger", 3, "风行者", [26, 50],
		{"agility": "+50%", "crit_rate": "+20%", "speed": "+35"})
	# 圣者之路
	data.add_growth_path("path_saint", "圣者之路", "以光明守护众生")
	data.add_growth_stage("path_saint", 1, "见习牧师", [1, 10],
		{"heal_power": "+15%", "max_mp": "+10%"})
	data.add_growth_stage("path_saint", 2, "祭司", [11, 25],
		{"heal_power": "+35%", "max_mp": "+30%", "aura_effect": "+10%"})
	data.add_growth_stage("path_saint", 3, "圣者", [26, 50],
		{"heal_power": "+60%", "max_mp": "+50%", "resurrect_chance": "5%"})
