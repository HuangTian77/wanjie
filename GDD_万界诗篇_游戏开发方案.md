Parser Error: Unindent doesn't match the previous indentation level.# 《万界诗篇》游戏设计文档（GDD）

> **文档版本**：v2.0  
> **文档类型**：核心游戏设计文档（Game Design Document）  
> **游戏名称**：万界诗篇（Poems of Ten Thousand Worlds）  
> **游戏类型**：沙盒式世界创造与体验平台  
> **核心定位**：支持玩家自定义世界剧本的沙盒式游戏体验平台  
> **目标平台**：PC（Steam）→ 移动端（后续适配）  
> **变更记录**：v1.0→v2.0 新增AI系统集成章节（§8）

---

## 目录

1. [游戏概述](#1-游戏概述)
2. [核心玩法深度剖析](#2-核心玩法深度剖析)
3. [剧本自定义系统](#3-剧本自定义系统)
4. [剧本运行架构](#4-剧本运行架构)
5. [存档与数据管理系统](#5-存档与数据管理系统)
6. [技术架构与实现方案](#6-技术架构与实现方案)
7. [UI/UX设计与开发规划](#7-uiux设计与开发规划)
8. [AI系统集成](#8-ai系统集成)

---

## 1. 游戏概述

### 1.1 核心概念

**一句话定义**：玩家既是"造物主"（创造世界剧本），也是"旅者"（体验世界剧本）。

《万界诗篇》是一款沙盒式世界创造与体验平台。玩家可以创建完全自定义的世界剧本——定义其物理法则、经济体系、历史脉络、势力格局与事件规则——然后以角色身份进入这些世界，在自创或他人创作的世界中展开冒险。

**核心幻想**：
- **造物主幻想**：编织一整个世界，看它按你设定的规则运转
- **旅者幻想**：踏入无限可能的世界，体验截然不同的文明与故事
- **诗人幻想**：每个世界都是一首诗，每个选择都是一个诗节

### 1.2 核心卖点（USP）

| 卖点 | 描述 | 差异化 |
|------|------|--------|
| **完全自定义剧本** | 从物理法则到经济体系，从历史事件到角色技能，全部可自定义 | 区别于RPG Maker等仅支持剧情编辑的工具 |
| **剧本即游戏** | 每个剧本就是一个完整的、可独立运行的游戏体验 | 区别于Mod系统（依赖本体游戏） |
| **无限世界池** | 社区驱动的剧本分享与发现生态 | 区别于单一世界的沙盒游戏 |
| **规则涌现** | 不同系统之间的交互产生意料之外的游戏体验 | 区别于脚本驱动的线性体验 |
| **零门槛创作** | 可视化编辑器 + 模板系统，无需编程即可创建剧本 | 区别于需要编程能力的游戏引擎 |

### 1.3 目标受众

| 受众类型 | 画像 | 核心需求 | 占比预估 |
|---------|------|---------|---------|
| **世界构建爱好者** | 喜欢TRPG世界观设定、写小说、构建架空世界 | "我有一堆世界观没地方实现" | 30% |
| **沙盒探索者** | 喜欢Minecraft、Terraria等沙盒游戏的自由体验 | "我想要无限可能的游戏世界" | 25% |
| **叙事爱好者** | 喜欢CRPG、视觉小说，重视剧情选择与后果 | "我想要我的选择真正影响世界" | 20% |
| **系统设计师** | 喜欢设计游戏机制、数值系统、经济模型 | "我想设计一套完美的游戏规则" | 15% |
| **社交分享者** | 喜欢创作内容并分享给社区 | "我想让别人体验我创造的世界" | 10% |

### 1.4 产品基调

| 维度 | 定义 |
|------|------|
| **视觉风格** | 手绘水彩风 + 古籍书页质感，营造"翻阅世界诗集"的氛围 |
| **音乐风格** | 管弦乐 + 民族乐器融合，每个剧本可自定义BGM风格 |
| **叙事基调** | 诗意、史诗感、留白，鼓励玩家想象补全 |
| **交互基调** | 沉稳、有仪式感，每一次选择都有"落笔成诗"的重量感 |

### 1.5 竞品差异化战略

| 竞品 | 核心特点 | 本产品差异 |
|------|---------|-----------|
| **RPG Maker** | 2D RPG制作工具，脚本化事件 | 我们支持系统级自定义（经济/能力/物理法则），不仅是剧情编辑 |
| **Mod.io/创意工坊** | 游戏Mod分享平台 | 我们的剧本是完全独立的游戏，不是Mod |
| **AI Dungeon** | AI驱动的无限叙事 | 我们基于确定性规则系统，体验可复现、可调控 |
| **Minecraft** | 3D沙盒建造 | 我们聚焦规则与叙事，而非空间建造 |
| **Terraria** | 2D沙盒冒险 | 我们支持多世界切换，且世界规则完全可定义 |

---

## 2. 核心玩法深度剖析

### 2.1 核心循环（Core Loop）

```
┌─────────────────────────────────────────────────────────┐
│                      元层（Meta Layer）                    │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐           │
│  │  创造世界  │───→│  发布分享  │←──│  体验评价  │           │
│  └──────────┘    └──────────┘    └──────────┘           │
│       │                                │                  │
│       ▼                                ▼                  │
│  ┌──────────┐                    ┌──────────┐           │
│  │  定义规则  │                    │  获取灵感  │           │
│  └──────────┘                    └──────────┘           │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│                    剧本层（World Layer）                   │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐           │
│  │  进入世界  │───→│  探索体验  │───→│  做出选择  │           │
│  └──────────┘    └──────────┘    └──────────┘           │
│       ▲                                │                  │
│       │          ┌──────────┐          │                  │
│       └──────────│  世界反馈  │←─────────┘                  │
│                  └──────────┘                             │
└─────────────────────────────────────────────────────────┘
```

**双循环设计**：
- **创造循环**（造物主模式）：构思 → 定义规则 → 测试运行 → 调优 → 发布
- **体验循环**（旅者模式）：选择世界 → 创建角色 → 探索互动 → 做出选择 → 承受后果

### 2.2 玩家目标体系

| 目标层级 | 目标内容 | 达成标志 |
|---------|---------|---------|
| **短期目标** | 完成第一个剧本的基础设定 | 创建角色+触发第一个事件 |
| **中期目标** | 体验/创造3种不同类型的剧本 | 解锁"多元旅者"成就 |
| **长期目标** | 创造被社区广泛认可的精品剧本 | 剧本获得1000+体验次数 |
| **终极目标** | 构建相互关联的"万界宇宙" | 解锁"万界诗人"成就 |

### 2.3 核心资源模型

| 资源 | 类型 | 获取方式 | 消耗场景 |
|------|------|---------|---------|
| **诗墨（创作资源）** | 软货币 | 完成剧本、社区互动、每日奖励 | 解锁高级模板、特殊组件 |
| **界石（高级资源）** | 硬货币 | 成就奖励、社区评价、付费购买 | 解锁高级系统组件、扩展槽位 |
| **灵感点** | 体力值 | 自然恢复、每日重置 | 进入剧本体验（每次消耗1点） |
| **创作精力** | 创作体力 | 自然恢复 | 发布/更新剧本 |

### 2.4 心流设计

**造物主心流通道**：
```
模板选择（低门槛起步）
  → 可视化编辑（即时反馈）
  → 测试运行（验证成果）
  → 调优迭代（持续改进）
  → 发布分享（获得认可）
```

**旅者心流通道**：
```
世界选择（兴趣驱动）
  → 引导教程（快速理解规则）
  → 自由探索（发现惊喜）
  → 关键抉择（情感投入）
  → 后果体验（成就感/遗憾感）
  → 重玩价值（分支探索）
```

### 2.5 用户旅程地图

| 阶段 | 用户行为 | 情感曲线 | 设计重点 |
|------|---------|---------|---------|
| **发现** | 看到游戏宣传/社区推荐 | 好奇 | 展示精品剧本的吸引力 |
| **入门** | 下载、首次启动 | 期待 | 30秒内进入引导流程 |
| **首次体验** | 进入官方预设剧本 | 新奇→投入 | 确保第一个剧本足够精彩 |
| **首次创造** | 尝试创建自己的剧本 | 兴奋→挫折→成就 | 模板降低门槛，即时预览 |
| **深入探索** | 学习高级系统自定义 | 专注→掌控 | 渐进式功能解锁 |
| **社区参与** | 发布剧本、体验他人作品 | 自豪→惊喜 | 社区反馈机制 |
| **长期留存** | 持续创作/体验/社交 | 满足→期待 | 赛季更新、创作挑战 |

---

## 3. 剧本自定义系统

> 本章是文档的核心章节，详细定义剧本的四大可自定义子系统及其交互规则。

### 3.1 剧本总体结构

每个"世界剧本"（World Script）是一个完整、自洽的游戏世界定义，包含以下结构：

```yaml
WorldScript:
  metadata:          # 元数据
    id: uuid
    name: string
    version: semver
    author: string
    description: string
    tags: [fantasy, sci-fi, ...]
    thumbnail: image_path
    
  worldview:         # 世界观设定（§3.2）
    background_story: text
    world_rules: [Rule, ...]
    factions: [Faction, ...]
    geography: GeographyDefinition
    
  event_system:      # 事件系统（§3.3）
    story_events: [StoryEvent, ...]
    random_events: [RandomEvent, ...]
    trigger_conditions: [Condition, ...]
    event_chains: [EventChain, ...]
    
  economy_system:    # 经济系统（§3.4）
    currencies: [Currency, ...]
    resources: [Resource, ...]
    markets: [Market, ...]
    trade_rules: TradeRules
    
  ability_system:    # 能力系统（§3.5）
    skills: [Skill, ...]
    growth_paths: [GrowthPath, ...]
    combat_mechanics: CombatDefinition
    status_effects: [StatusEffect, ...]
    
  runtime_config:    # 运行配置
    max_players: int
    time_scale: float
    seed: string
    difficulty: enum
```

### 3.2 世界观设定系统

#### 3.2.1 背景故事（Background Story）

**结构定义**：
```yaml
BackgroundStory:
  era_definitions:       # 时代定义
    - era_name: "创世纪元"
      start_year: 0
      end_year: 1000
      description: "诸神创造世界的时代..."
      key_events: [...]
      
  timeline:              # 历史时间线
    - year: 1000
      event: "大分裂"
      impact: "世界分裂为三大势力"
      
  lore_entries:          # 知识条目（可被玩家发现）
    - id: lore_001
      title: "失落的魔法"
      content: "..."
      discovery_condition:
        type: exploration
        target_location: " Ancient Library"
```

**设计规则**：
- 背景故事不直接参与游戏逻辑，但为事件触发、NPC对话提供叙事上下文
- 时间线事件可作为"历史条件"影响当前世界状态
- 知识条目可被玩家在游戏中发现，解锁额外信息

#### 3.2.2 世界规则（World Rules）

世界规则是定义世界底层法则的全局配置，影响所有子系统的运行：

| 规则类别 | 可配置项 | 示例值 | 影响范围 |
|---------|---------|-------|---------|
| **物理法则** | 重力系数、日夜周期、季节长度 | 重力=0.8x，日周期=48分钟 | 全局环境 |
| **魔法规则** | 魔法是否存在、魔法来源、施法代价 | 存在，来源于星辰，代价为寿命 | 能力系统 |
| **生命法则** | 死亡机制、复活条件、寿命上限 | 死亡后灵魂进入轮回 | 角色系统 |
| **社会法则** | 阵营善恶体系、法律体系、阶级制度 | 五阵营光谱，无阶级 | 事件/经济 |
| **信息法则** | 知识传播方式、禁忌知识、通讯手段 | 口耳相传+魔法通讯 | 事件触发 |

**规则冲突处理**：
- 规则之间存在优先级：物理法则 > 生命法则 > 魔法规则 > 社会法则 > 信息法则
- 当规则冲突时，高优先级规则覆盖低优先级
- 编辑器提供"规则冲突检测器"，在创作阶段提示潜在矛盾

#### 3.2.3 势力设定（Factions）

```yaml
Faction:
  id: faction_001
  name: "星辰议会"
  description: "掌控星辰魔法的古老组织"
  
  attributes:
    power_level: 85          # 综合实力（0-100）
    territory: ["北部平原", "星落群岛"]
    population: 100000
    
  relationships:             # 与其他势力的关系
    - target: faction_002
      type: "rivalry"        # alliance/rivalry/neutral/war/trade
      intensity: 0.7         # 关系强度（0-1）
      
  governance:
    type: "council"          # monarchy/council/theocracy/anarchy
    succession: "election"   # heredity/election/appointment
    
  economy_profile:          # 经济特征
    primary_income: "magic_crystal_mining"
    trade_goods: ["星辰碎片", "魔法卷轴"]
    tax_rate: 0.15
    
  military:
    total_forces: 5000
    special_units: ["星辰守卫"]
    
  dynamic_behavior:         # 势力动态行为
    expansion_tendency: 0.3  # 扩张倾向
    aggression_level: 0.4    # 好战程度
    diplomacy_preference: "balanced"
```

**势力动态演化规则**：
- 势力关系根据玩家行为和世界事件动态变化
- 势力实力随时间自然演化（经济增长、军事扩张/收缩）
- 玩家行为可改变势力关系（帮助一方→另一方好感下降）

### 3.3 事件系统

#### 3.3.1 事件类型定义

**剧情事件（Story Events）**：
```yaml
StoryEvent:
  id: story_001
  name: "星辰陨落之夜"
  description: "一颗星辰坠落在北部平原，三大势力争相夺取..."
  
  trigger:
    type: "chain"            # chain/time/condition/player_action
    prerequisite: "story_000" # 前置事件
    delay_after_prereq: "7d"  # 前置事件后延迟
    
  conditions:                # 触发条件组
    - type: world_state
      check: "faction_001.power_level > 70"
    - type: player_state
      check: "player.level >= 5"
    - type: time
      check: "game_day >= 30"
      
  choices:                   # 玩家选择
    - id: choice_a
      text: "帮助星辰议会夺取星辰碎片"
      consequences:
        - target: faction_001
          effect: "relationship +20"
        - target: faction_002
          effect: "relationship -10"
        - target: player
          effect: "receive item_starlight_shard"
          
    - id: choice_b
      text: "将星辰碎片据为己有"
      consequences:
        - target: all_factions
          effect: "relationship -15"
        - target: player
          effect: "receive item_starlight_shard, marked_as_greedy"
          
    - id: choice_c
      text: "摧毁星辰碎片，防止争夺"
      consequences:
        - target: world
          effect: "trigger_magic_storm_7days"
        - target: player
          effect: "gain title_peacemaker"
          
  branches:                  # 后续分支
    - condition: "choice == choice_a"
      next_event: "story_002a"
    - condition: "choice == choice_b"
      next_event: "story_002b"
    - condition: "choice == choice_c"
      next_event: "story_002c"
```

**随机事件（Random Events）**：
```yaml
RandomEvent:
  id: random_001
  name: "旅途遭遇"
  
  trigger:
    type: "random"
    probability: 0.05        # 每次行动触发概率
    cooldown: "3d"           # 最小间隔
    
  weight_table:              # 加权随机池
    - event: "bandit_ambush"
      weight: 30
      conditions: ["player.in_forest"]
    - event: "merchant_encounter"
      weight: 25
      conditions: []
    - event: "mysterious_ruins"
      weight: 15
      conditions: ["game_day > 10"]
    - event: "weather_storm"
      weight: 20
      conditions: ["season == winter"]
    - event: "dragon_sighting"
      weight: 10
      conditions: ["player.level > 15", "world_rule.magic_exists"]
      
  scaling:                   # 难度缩放
    type: "player_level"
    formula: "event_difficulty = base * (1 + player_level * 0.1)"
```

#### 3.3.2 触发条件引擎

**条件类型**：

| 条件类型 | 检查对象 | 示例 | 运算符 |
|---------|---------|------|--------|
| **世界状态** | 全局变量、势力状态 | `faction_001.power > 80` | >, <, ==, !=, >=, <= |
| **玩家状态** | 角色属性、背包、状态 | `player.gold >= 1000` | 同上 |
| **时间条件** | 游戏内时间 | `game_hour >= 18 AND game_hour <= 6` | AND, OR, NOT |
| **位置条件** | 玩家/实体位置 | `player.location == "dark_forest"` | ==, !=, in |
| **历史条件** | 已完成事件、玩家选择 | `event_history.contains("story_001") AND choice == "a"` | contains, not_contains |
| **关系条件** | 实体间关系 | `relationship(player, faction_001) >= 50` | 比较运算符 |
| **组合条件** | 多条件逻辑组合 | `A AND (B OR C) AND NOT D` | 逻辑运算符 |

**条件评估优化**：
- 条件使用延迟评估（Lazy Evaluation），短路逻辑
- 高频条件（时间、位置）使用缓存，低频条件实时计算
- 条件表达式在剧本创建时进行语法校验和依赖检查

#### 3.3.3 事件链与因果网络

```
事件A（星辰陨落）
  ├── 选择a → 事件B1（议会感谢）→ 事件C1（获得议会信任）
  │                                → 事件C2（其他势力警惕）
  ├── 选择b → 事件B2（被标记为贪婪）→ 事件C3（赏金猎人追踪）
  │                                  → 事件C4（黑市联系）
  └── 选择c → 事件B3（魔法风暴）→ 事件C5（风暴中的机会）
                                → 事件C6（势力重新评估）
```

**因果网络规则**：
- 每个选择产生"因果标记"（Causal Mark），存储在玩家状态中
- 后续事件的条件可检查任意历史因果标记
- 因果标记可随时间衰减（可配置衰减率）
- 支持"蝴蝶效应"：早期微小选择影响后期重大事件

### 3.4 经济系统

#### 3.4.1 货币与资源定义

```yaml
EconomySystem:
  currencies:
    - id: gold
      name: "金币"
      type: "universal"        # universal/faction_local/token
      icon: icon_gold
      max_supply: -1           # -1=无限
      inflation_rate: 0.02     # 年通胀率
      
    - id: starlight_crystal
      name: "星辰碎片"
      type: "token"
      max_supply: 100          # 世界总量限制
      acquisition:
        - source: "event_reward"
        - source: "mining"
          location: "starfall_mines"
          
  resources:
    - id: iron_ore
      name: "铁矿"
      category: "material"
      stack_limit: 999
      decay: false
      
    - id: mana_crystal
      name: "魔力水晶"
      category: "material"
      stack_limit: 99
      decay: true
      decay_rate: 0.01         # 每日衰减1%
      
  production:
    - resource: gold
      sources:
        - type: "passive"
          formula: "base_income * (1 + tax_rate * population)"
          interval: "1d"
        - type: "active"
          action: "trade_goods"
          formula: "goods_value * market_demand_multiplier"
          
    - resource: iron_ore
      sources:
        - type: "active"
          action: "mining"
          requires: { location: "mine", tool: "pickaxe" }
          formula: "base_yield * (1 + mining_skill * 0.1)"
```

#### 3.4.2 市场与交易系统

**市场动态模型**：
```yaml
Market:
  id: market_001
  name: "王都集市"
  location: "capital_city"
  
  goods:
    - item: iron_ore
      base_price: 10
      price_formula: "base_price * demand_factor * (1 - supply_ratio)"
      demand_factor: 1.2       # 基础需求系数
      supply_ratio: 0.6        # 当前供应/最大供应
      
    - item: mana_crystal
      base_price: 100
      price_formula: "base_price * scarcity_multiplier"
      scarcity_multiplier: "1 + (max_supply - current_supply) / max_supply"
      
  price_update:
    interval: "6h"             # 价格刷新间隔
    formula: "new_price = old_price * (1 + random(-0.1, 0.1)) * demand_shift"
    
  trade_rules:
    barter_enabled: true       # 是否支持以物易物
    barter_rate: 0.8           # 以物易物折损率
    faction_discount:          # 势力关系折扣
      formula: "discount = relationship / 200"  # 关系100=5%折扣
    smuggling:                 # 黑市交易
      enabled: true
      risk_factor: 0.15        # 被发现概率
      penalty: "fine_500_gold"
```

**经济平衡公式**：
- **产出-消耗平衡**：`总产出率 ≤ 总消耗率 × 1.2`（允许20%盈余增长）
- **通胀控制**：`货币供应量增长率 ≤ GDP增长率 × 1.1`
- **玩家经济**：`玩家收入/小时 ≈ 基准时薪 × (1 + difficulty_bonus)`

### 3.5 能力系统

#### 3.5.1 技能定义

```yaml
Skill:
  id: skill_fireball
  name: "火球术"
  description: "凝聚火元素，发射一枚爆炸火球"
  category: "active"           # active/passive/ultimate
  school: "elemental_fire"     # 法术学派
  
  requirements:
    level: 5
    attributes:
      intelligence: 12
    prerequisites: ["skill_basic_magic"]
    
  cost:
    mana: 30
    cooldown: "3s"
    
  effect:
    type: "damage"
    formula: "base_damage + intelligence * 1.5 + skill_level * 10"
    base_damage: 50
    aoe_radius: 3              # 范围攻击
    status_effect:
      id: "burning"
      duration: "5s"
      damage_per_tick: 5
      
  scaling:                     # 技能成长
    max_level: 10
    level_bonus:
      - level: 3
        effect: "aoe_radius +1"
      - level: 5
        effect: "add status_effect_spread"
      - level: 10
        effect: "damage * 1.5, cooldown -1s"
```

#### 3.5.2 成长路线（Growth Paths）

```yaml
GrowthPath:
  id: path_mage
  name: "法师之路"
  description: "追求知识与魔法的极致"
  
  unlock_condition:
    intelligence >= 15
    skill_basic_magic.learned
    
  stages:
    - stage: 1
      name: "学徒"
      level_range: [1, 10]
      bonuses:
        mana_pool: "+20%"
        magic_damage: "+10%"
      skill_unlocks: ["skill_fireball", "skill_ice_shard"]
      
    - stage: 2
      name: "术士"
      level_range: [11, 25]
      bonuses:
        mana_pool: "+50%"
        magic_damage: "+25%"
        cast_speed: "+15%"
      skill_unlocks: ["skill_chain_lightning", "skill_teleport"]
      special_ability: "mana_regen_outside_combat"
      
    - stage: 3
      name: "大法师"
      level_range: [26, 50]
      bonuses:
        mana_pool: "+100%"
        magic_damage: "+50%"
        cast_speed: "+30%"
      skill_unlocks: ["skill_meteor", "skill_time_stop"]
      special_ability: "spell_combo_system"
      
  branch_points:               # 分支选择
    - at_stage: 2
      choices:
        - path: "path_elementalist"
          name: "元素师"
          focus: "元素魔法极致"
        - path: "path_enchanter"
          name: "附魔师"
          focus: "魔法物品创造"
        - path: "path_archivist"
          name: "博学者"
          focus: "知识即力量"
```

#### 3.5.3 战斗机制

**战斗系统框架**：
```yaml
CombatDefinition:
  type: "hybrid"               # turn_based/real_time/hybrid
  hybrid_mode:
    real_time_exploration: true
    combat_pause_on_skill: true  # 使用技能时暂停
    
  turn_order:                   # 回合制时的行动顺序
    formula: "speed * (1 + agility * 0.01) + random(0, 5)"
    
  damage_formula:
    physical: "ATK * weapon_multiplier - DEF * armor_reduction"
    magical: "spell_power * skill_multiplier - MDEF * resistance"
    final: "base_damage * elemental_modifier * critical_modifier * random(0.9, 1.1)"
    
  elemental_system:
    elements: ["fire", "water", "earth", "wind", "light", "dark"]
    interaction_matrix:
      fire: { water: 0.5, earth: 1.5, wind: 1.2 }
      water: { fire: 2.0, earth: 0.8, wind: 0.7 }
      # ... 完整相克表
      
  status_effects:
    - id: burning
      type: "dot"
      damage_per_tick: 5
      duration: "5s"
      stackable: true
      max_stacks: 3
      
    - id: frozen
      type: "control"
      effect: "cannot_act"
      duration: "3s"
      break_condition: "take_fire_damage"
```

**战斗与世界的关联**：
- 战斗结果影响势力关系（击杀某势力成员→该势力敌对）
- 战斗掉落物受世界经济系统影响（资源稀缺时掉落率提升）
- 战斗中使用的技能影响成长路线评价

---

## 4. 剧本运行架构

### 4.1 剧本独立性原则

**核心原则**：每个剧本是一个完全隔离的运行实例，拥有独立的：
- 世界状态（时间、天气、势力关系）
- 规则体系（物理法则、经济规则、战斗公式）
- 事件状态（已触发事件、当前事件链进度）
- 实体数据（NPC状态、物品分布）

**隔离模型**：
```
┌─────────────────────────────────────────┐
│              引擎层（共享）               │
│  事件引擎 | 经济引擎 | 战斗引擎 | 渲染   │
└─────────────────────────────────────────┘
         │              │              │
    ┌────▼────┐   ┌────▼────┐   ┌────▼────┐
    │ 剧本 A  │   │ 剧本 B  │   │ 剧本 C  │
    │─────────│   │─────────│   │─────────│
    │世界状态A│   │世界状态B│   │世界状态C│
    │规则集 A │   │规则集 B │   │规则集 C │
    │存档数据A│   │存档数据B│   │存档数据C│
    │实体数据A│   │实体数据B│   │实体数据C│
    └─────────┘   └─────────┘   └─────────┘
         完全隔离        完全隔离        完全隔离
```

### 4.2 剧本生命周期

```
创建 → 编辑 → 校验 → 测试 → 发布 → 运行 → 暂停/继续 → 结束/重置
  │                                      │
  └── 迭代更新 ←─────────────────────────┘
```

**状态定义**：

| 状态 | 说明 | 允许操作 |
|------|------|---------|
| **草稿** | 正在编辑中 | 编辑、测试、删除 |
| **校验中** | 提交后自动校验 | 查看校验报告 |
| **已发布** | 可被其他玩家体验 | 体验、评价 |
| **运行中** | 玩家正在体验 | 暂停、保存、退出 |
| **已暂停** | 临时退出 | 继续、重置 |
| **已归档** | 长期未访问 | 恢复、删除 |

### 4.3 剧本间交互（可选扩展）

虽然剧本之间完全独立运行，但提供以下可选的跨剧本交互：

| 交互类型 | 说明 | 限制 |
|---------|------|------|
| **旅者日记** | 玩家在不同剧本中的体验记录汇总 | 仅记录，不影响其他剧本 |
| **成就共享** | 某些成就跨剧本累计 | 仅成就系统，不影响游戏内状态 |
| **灵感传承** | 在一个剧本中获得的设计灵感可用于其他剧本 | 仅创作模式可用 |
| **剧本引用** | 剧本B可引用剧本A的"世界观片段"作为灵感 | 仅复制文本，不共享运行时数据 |

---

## 5. 存档与数据管理系统

### 5.1 存档架构设计

```
/saves
  /{script_id}                    # 每个剧本独立存档目录
    /save_slot_01                 # 存档槽位
      world_state.json            # 世界状态快照
      player_state.json           # 玩家角色状态
      event_history.json          # 事件历史与选择记录
      economy_state.json          # 经济系统状态
      entity_state.json           # 实体/NPC状态
      timestamp.json              # 存档元数据
    /save_slot_02
      ...
    /autosave
      autosave_01.json
      autosave_02.json
      autosave_03.json
    metadata.json                 # 剧本存档元数据
```

### 5.2 存档数据结构

**世界状态（world_state.json）**：
```json
{
  "script_id": "uuid",
  "script_version": "1.2.0",
  "save_version": "1.0.0",
  "game_time": {
    "year": 1023,
    "month": 6,
    "day": 15,
    "hour": 14,
    "minute": 30,
    "total_seconds_elapsed": 4285740
  },
  "world_variables": {
    "magic_storm_active": false,
    "war_started": false,
    "ancient_sealed": true
  },
  "faction_states": {
    "faction_001": {
      "power_level": 82,
      "territory": ["北部平原"],
      "treasury": 50000,
      "relationships": {
        "faction_002": -15,
        "faction_003": 30
      }
    }
  },
  "active_effects": [
    {
      "id": "drought",
      "remaining_duration": "5d",
      "affected_regions": ["南部沙漠"]
    }
  ]
}
```

**玩家状态（player_state.json）**：
```json
{
  "player_id": "uuid",
  "character": {
    "name": "艾琳",
    "level": 12,
    "experience": 4500,
    "attributes": {
      "strength": 14,
      "agility": 16,
      "intelligence": 18,
      "charisma": 12
    },
    "skills": {
      "skill_fireball": { "level": 3, "exp": 200 },
      "skill_ice_shard": { "level": 1, "exp": 50 }
    },
    "growth_path": "path_mage",
    "current_stage": 2,
    "inventory": {
      "gold": 1250,
      "items": [
        { "id": "item_sword_01", "quantity": 1, "durability": 85 },
        { "id": "item_potion_hp", "quantity": 5 }
      ]
    },
    "location": {
      "region": "capital_city",
      "coordinates": [120, 340]
    },
    "status_effects": [],
    "causal_marks": [
      { "id": "marked_greedy", "from_event": "story_001", "intensity": 0.8 },
      { "id": "peacemaker", "from_event": "story_001c", "intensity": 1.0 }
    ]
  },
  "quest_log": {
    "active": ["quest_find_mentor"],
    "completed": ["quest_first_blood", "quest_explore_forest"],
    "failed": []
  }
}
```

**事件历史（event_history.json）**：
```json
{
  "events_triggered": [
    {
      "event_id": "story_001",
      "triggered_at": "1023-06-10T08:00:00",
      "choice_made": "choice_c",
      "consequences_applied": [
        { "target": "world", "effect": "trigger_magic_storm_7days" },
        { "target": "player", "effect": "gain title_peacemaker" }
      ]
    },
    {
      "event_id": "random_003",
      "triggered_at": "1023-06-12T14:30:00",
      "choice_made": "choice_a",
      "consequences_applied": []
    }
  ],
  "choices_history": [
    {
      "event_id": "story_001",
      "choice_id": "choice_c",
      "timestamp": "1023-06-10T08:05:23",
      "context_snapshot": "player was at capital_city, faction_001 relationship was 45"
    }
  ],
  "branch_points": [
    {
      "event_id": "story_001",
      "available_choices": ["choice_a", "choice_b", "choice_c"],
      "chosen": "choice_c",
      "unchosen_consequences": {
        "choice_a": "would have led to story_002a",
        "choice_b": "would have led to story_002b"
      }
    }
  ]
}
```

### 5.3 多存档槽位管理

| 特性 | 设计 |
|------|------|
| **槽位数量** | 每剧本10个手动存档槽位 + 3个自动存档 |
| **自动存档触发** | ①重大事件前 ②进入新区域 ③每游戏日 ④退出游戏时 |
| **存档信息** | 显示：角色名、等级、游戏内时间、现实时间、游戏进度百分比 |
| **存档操作** | 保存、加载、复制、删除、导出、重命名 |
| **版本兼容** | 剧本更新时，旧存档自动迁移（数据迁移脚本） |

### 5.4 存档完整性保障

**数据校验**：
- 每个存档文件附带SHA-256校验和
- 加载时验证数据完整性
- 损坏存档尝试从自动存档恢复

**版本迁移**：
```yaml
migration_chain:
  - from: "1.0.0"
    to: "1.1.0"
    changes:
      - "add field: player.causal_marks"
      - "rename: economy.gold → economy.currency_gold"
      
  - from: "1.1.0"
    to: "1.2.0"
    changes:
      - "add field: faction_states.*.diplomacy_memory"
      - "restructure: event_history format v2"
```

---

## 6. 技术架构与实现方案

### 6.1 技术栈选型

| 层级 | 技术选择 | 理由 |
|------|---------|------|
| **游戏引擎** | Godot 4.7.1 (GDScript) | 开源免费、2D/轻3D能力强、GDScript易上手、社区活跃；4.7.1 支持 HDR、Vulkan 光线追踪、虚拟摇杆、AwaitTweener 等新特性 |
| **脚本语言** | GDScript + Lua | GDScript用于引擎层，Lua用于剧本逻辑（玩家可学习） |
| **数据格式** | JSON + YAML | 人类可读，便于剧本编辑和Mod |
| **后端（社区）** | Node.js + Express | 剧本分享、评价、排行榜 |
| **数据库** | PostgreSQL + Redis | 持久化存储 + 缓存 |
| **版本控制** | Git-like（内部） | 剧本版本管理、协作编辑 |
| **渲染器** | gl_compatibility (OpenGL) | 当前项目使用兼容渲染器，确保广泛硬件支持；后续可评估 Forward+ |
| **第三方插件** | Dialogic 2 / Phantom Camera / LimboAI | 对话系统 / 相机控制 / AI行为树（详见§6.6 插件兼容矩阵） |

### 6.1.1 Godot 4.7.1 升级说明

> **升级记录**：项目已从 Godot 4.4.1 升级至 Godot 4.7.1（2026年7月）。

**已完成的升级操作：**
- `project.godot` 中 `config/features` 已更新为 `PackedStringArray("4.7")`
- `.godot/editor/project_metadata.cfg` 中 `executable_path` 已指向 `Godot_v4.7.1-stable_win64.exe`
- 所有 GDScript 代码已扫描，无废弃 API 使用
- 所有 `.tscn` 场景文件均为 `format=3`，完全兼容 4.7.1
- `.qoder/agents/game-dev.md` 开发规范已同步更新至 4.7.1

**Godot 4.5→4.6→4.7 关键新特性（可利用）：**
- GDScript：抽象类/抽象方法、可变参数函数 (variadic)
- GUI：Control 节点 transform offset（不影响容器布局）、PopupMenu 搜索栏、RichTextLabel 图片 em 缩放
- 动画：AwaitTweener（等待信号后继续）、动画轨道折叠
- 渲染：HDR 输出、Vulkan 光线追踪、AreaLight3D、DrawableTexture、3D 最近邻缩放
- 输入：内置 VirtualJoystick（移动端虚拟摇杆）
- 编辑器：属性组复制粘贴、顶点吸附(B键)、Path3D 碰撞体吸附、场景绘制工具
- 物理：CollisionShape2D 单向碰撞方向支持

**项目未受影响的 4.7 破坏性变更：**
- BlendSpace 点名/索引设置（项目未使用）
- Spectrum Analyzer 报动修复（项目未使用）
- SoftBody3D/Jolt 物理变更（项目未使用）
- 粒子角速度修复（项目未使用）
- Shader 预处理器条件解析限制（项目无自定义 shader）
- Android OBB 支持移除（项目目标平台为 PC）

**首次用 Godot 4.7.1 打开项目注意事项：**
1. 引擎会自动重建 `.godot/imported/` 缓存，首次打开耗时较长
2. `.godot/shader_cache/` 会自动重新生成
3. 场景文件 `format=3` 无需转换，Godot 4.x 全系列兼容
4. `.uid` 文件是 Godot 4.4+ 引入的资源唯一标识符，**严禁手动删除或重命名**，否则会导致场景中的资源引用丢失
5. 移动/重命名脚本时必须连同 `.uid` 文件一起操作（推荐使用 gdscript-file-manager 技能）

### 6.2 核心引擎架构

```
┌─────────────────────────────────────────────────────────────┐
│                      表现层（Presentation）                    │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐       │
│  │ UI系统  │  │ 渲染系统 │  │ 音频系统 │  │ 动画系统 │       │
│  └─────────┘  └─────────┘  └─────────┘  └─────────┘       │
├─────────────────────────────────────────────────────────────┤
│                      逻辑层（Game Logic）                     │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │ 事件引擎  │  │ 经济引擎  │  │ 战斗引擎  │  │ 对话引擎  │   │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘   │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                  │
│  │ 条件引擎  │  │ 成长引擎  │  │ 势力引擎  │                  │
│  └──────────┘  └──────────┘  └──────────┘                  │
├─────────────────────────────────────────────────────────────┤
│                      数据层（Data）                           │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │ 剧本解析器 │  │ 存档管理器 │  │ 资源管理器 │  │ 配置加载器 │   │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘   │
├─────────────────────────────────────────────────────────────┤
│                      平台层（Platform）                       │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                  │
│  │ 文件系统  │  │ 网络通信  │  │ 输入管理  │                  │
│  └──────────┘  └──────────┘  └──────────┘                  │
└─────────────────────────────────────────────────────────────┘
```

### 6.3 关键技术难点

| 难点 | 挑战 | 解决方案 |
|------|------|---------|
| **剧本热加载** | 修改规则后不重启即可生效 | 观察者模式 + 事件总线，规则变更广播到所有订阅引擎 |
| **条件表达式引擎** | 玩家自定义复杂条件逻辑 | 实现安全的表达式解析器（非eval），支持类型检查 |
| **经济系统平衡** | 自定义经济容易失衡 | 提供内置平衡检测工具，模拟运行N天后报告通胀/通缩 |
| **存档体积控制** | 大型世界存档可能很大 | 差分存档（只记录变化量）+ 压缩 + 实体分区加载 |
| **剧本兼容性** | 版本更新后旧存档可能失效 | 强制版本迁移链 + 向后兼容字段 + 废弃字段自动转换 |
| **多人创作协作** | 多人共同编辑同一剧本 | 乐观锁 + 冲突合并策略 + 编辑区域锁定 |

### 6.4 剧本编辑器技术设计

**可视化编辑器架构**：
```
┌──────────────────────────────────────┐
│           剧本编辑器 UI               │
│  ┌────────┐  ┌────────┐  ┌────────┐ │
│  │世界观   │  │事件    │  │经济    │ │
│  │编辑器   │  │编辑器  │  │编辑器  │ │
│  └────────┘  └────────┘  └────────┘ │
│  ┌────────┐  ┌────────┐  ┌────────┐ │
│  │能力    │  │地图    │  │测试    │ │
│  │编辑器   │  │编辑器  │  │运行器  │ │
│  └────────┘  └────────┘  └────────┘ │
├──────────────────────────────────────┤
│         实时预览面板                  │
│  ┌────────────────────────────────┐  │
│  │  文本预览 | 数据视图 | 运行测试 │  │
│  └────────────────────────────────┘  │
└──────────────────────────────────────┘
```

**事件编辑器交互**：
- 节点式编辑器（类似蓝图/可视化脚本）
- 拖拽连接事件节点，定义触发条件和后续分支
- 实时显示事件链流程图
- 一键测试特定事件链

### 6.5 性能优化策略

| 场景 | 优化策略 |
|------|---------|
| **大世界状态** | 分区加载（只处理玩家周围区域的状态更新） |
| **大量NPC** | LOD系统（远处NPC简化行为模拟） |
| **复杂条件评估** | 条件缓存 + 增量更新（只在相关状态变化时重新评估） |
| **存档写入** | 异步写入 + 增量存档 + 后台压缩 |
| **剧本加载** | 懒加载（按需加载子系统）+ 预编译（剧本定义→运行时格式） |

### 6.6 插件兼容矩阵（Godot 4.7.1）

| 插件名 | 当前版本 | 声明支持版本 | Godot 4.7.1 兼容状态 | 风险等级 | 需要手动验证的功能 |
|---------|---------|-------------|---------------------|---------|-------------------|
| **Dialogic 2** | 2.0-Alpha-20 | Godot 4.5+ | ✅ 兼容（明确标注 4.5+） | 中（Alpha版） | 对话框显示、角色系统、时间线、事件触发、存档集成 |
| **Phantom Camera** | 0.11.0.3 | Godot 4.x | ✅ 兼容（纯 GDScript 插件） | 低 | Autoload UID 引用、相机跟随/缩放、2D/3D 相机切换 |
| **LimboAI** | 1.7.x (GDExtension) | Godot 4.6 or higher | ⚠️ 待验证（声明 4.6+，未明确标注 4.7） | 中 | 行为树编辑器、BTPlayer 节点、状态机、可视化调试器 |

**插件详细说明：**

#### Dialogic 2 (2.0-Alpha-20)
- **配置位置**：`project.godot` 中 `[dialogic]` 段管理目录配置（dch_directory / dtl_directory / style_directory）
- **Autoload**：`Dialogic="*res://addons/dialogic/Core/DialogicGameHandler.gd"`
- **注意事项**：仍为 Alpha 版本，API 可能在后续版本变动；升级 Dialogic 版本前必须备份项目
- **验证清单**：对话显示、角色卡加载、时间线播放、分支选择、与 SaveManager 的集成

#### Phantom Camera (0.11.0.3)
- **Autoload**：`PhantomCameraManager="*uid://duq6jhf6unyis"`（使用 UID 引用，确保插件更新后 UID 不变）
- **注意事项**：纯 GDScript 实现，无二进制依赖，兼容性风险极低
- **验证清单**：Autoload 正常初始化、2D 相机跟随、相机缩放/平移、多相机切换

#### LimboAI (1.7.x GDExtension)
- **当前状态**：`limboai.gdextension` 中 `enabled = false`（已禁用）
- **兼容性说明**：`compatibility_minimum = "4.2"`，GDExtension 向下兼容（4.2编译可在4.7运行），但 README 明确标注“Supported Godot Engine: 4.6”
- **建议**：在启用前需确认 LimboAI 是否已发布面向 4.7/4.7.1 的 GDExtension 构建；如无明确兼容版本，保持禁用状态
- **回滚方案**：若 4.7.1 下加载失败，保持 `enabled = false` 即可，不影响项目其他功能

### 6.7 渲染器策略

| 项目 | 当前配置 | 说明 |
|------|---------|------|
| 渲染方法 | `gl_compatibility` | OpenGL 兼容模式，支持最广泛的硬件（包括集显、老旧设备） |
| 纹理过滤 | `default_texture_filter=0` (Nearest) | 像素风格，与手绘水彩视觉风格匹配 |
| 窗口模式 | `mode=2` (全屏) + `canvas_items` 拉伸 | 1280x720 视口，expand 宽高比 |

**后续渲染器评估：**
- **Forward+**：若后续需要 3D 场景、HDR 输出、体积雾、光线追踪等高级渲染特性，可考虑迁移至 Forward+（Vulkan）
- **Mobile**：若后续适配移动端，可评估 Mobile 渲染器（性能与效果的平衡）
- **当前结论**：项目以 2D UI + 文本叙事为主，`gl_compatibility` 完全满足需求，无需迁移

### 6.8 project.godot 配置说明（Godot 4.7.1）

```ini
[application]
config/features=PackedStringArray("4.7")  # 引擎版本标识，影响编辑器兼容性提示

[autoload]
# 核心单例（顺序不可变更）
GameManager / SceneManager / SaveManager / ScriptDataManager / ToastManager
# AI对话酒馆模块
LLMClient / TavernManager
# 第三方插件 Autoload
Dialogic / PhantomCameraManager  # 由插件自动注册，勿手动删除

[dialogic]
# Dialogic 插件配置段，管理对话角色/时间线/样式目录
# 当前为空配置，待实际使用 Dialogic 功能时填充

[rendering]
renderer/rendering_method="gl_compatibility"  # 渲染策略，勿修改
```

**配置约束（必须遵守）：**
- 不修改渲染器设置（gl_compatibility）
- 不改变 Autoload 注册顺序
- 不删除插件自动注册的 Autoload（Dialogic / PhantomCameraManager）
- `.uid` 文件必须纳入版本控制，不可忽略

---

## 7. UI/UX设计与开发规划

### 7.1 核心界面设计

#### 7.1.1 主界面（万界大厅）

```
┌─────────────────────────────────────────────────────────┐
│  [Logo: 万界诗篇]          [诗墨:1250] [界石:50] [⚙设置] │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌─────────────────────────────────────────────────┐    │
│  │            推荐剧本轮播/精选展示                    │    │
│  └─────────────────────────────────────────────────┘    │
│                                                          │
│  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐    │
│  │ 我的  │  │ 热门  │  │ 最新  │  │ 精选  │  │ 搜索  │    │
│  │ 剧本  │  │ 剧本  │  │ 剧本  │  │ 剧本  │  │      │    │
│  └──────┘  └──────┘  └──────┘  └──────┘  └──────┘    │
│                                                          │
│  ┌─────────────────────────────────────────────────┐    │
│  │  最近体验                                         │    │
│  │  ┌────────┐  ┌────────┐  ┌────────┐             │    │
│  │  │剧本A   │  │剧本B   │  │剧本C   │             │    │
│  │  │进度:35%│  │进度:80%│  │进度:12%│             │    │
│  │  └────────┘  └────────┘  └────────┘             │    │
│  └─────────────────────────────────────────────────┘    │
│                                                          │
│  ┌─────────────────────────────────────────────────┐    │
│  │  [+ 创建新剧本]     [+ 导入剧本]                  │    │
│  └─────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

#### 7.1.2 剧本编辑器界面

```
┌─────────────────────────────────────────────────────────┐
│  [←返回]  剧本: "星辰大陆" v1.2    [保存] [测试] [发布]  │
├──────────┬──────────────────────────────────────────────┤
│ 导航面板  │              编辑区域                         │
│          │                                              │
│ 📖世界观  │  ┌──────────────────────────────────────┐   │
│  ├背景故事│  │  事件编辑器（节点视图）                │   │
│  ├世界规则│  │  ┌─────┐    ┌─────┐    ┌─────┐      │   │
│  └势力设定│  │  │事件A│───→│事件B│───→│事件C│      │   │
│          │  │  └─────┘    └─────┘    └─────┘      │   │
│ ⚡事件系统│  │      │          │                     │   │
│  ├剧情事件│  │      ▼          ▼                     │   │
│  ├随机事件│  │  ┌─────┐    ┌─────┐                  │   │
│  └事件链  │  │  │事件D│    │事件E│                  │   │
│          │  │  └─────┘    └─────┘                  │   │
│ 💰经济系统│  └──────────────────────────────────────┘   │
│  ├货币   │                                              │
│  ├资源   │  ┌──────────────────────────────────────┐   │
│  └市场   │  │  属性面板（选中节点详情）              │   │
│          │  │  名称: [星辰陨落之夜      ]           │   │
│ ⚔能力系统│  │  触发: [chain           ▼]           │   │
│  ├技能   │  │  条件: [+ 添加条件]                   │   │
│  ├成长   │  │  选择:                                │   │
│  └战斗   │  │    ├ [帮助议会] → story_002a          │   │
│          │  │    ├ [据为己有] → story_002b          │   │
│ 🗺地图   │  │    └ [摧毁碎片] → story_002c          │   │
│          │  └──────────────────────────────────────┘   │
├──────────┴──────────────────────────────────────────────┤
│  [实时预览] 校验状态: ✅ 无错误  |  节点: 12  |  条件: 28 │
└─────────────────────────────────────────────────────────┘
```

### 7.2 视觉设计风格

| 元素 | 风格定义 |
|------|---------|
| **整体基调** | 古籍书页 + 水彩画质感，温暖的米黄底色 |
| **主色** | 深棕`#4A3728`（文字）+ 琥珀金`#C4975A`（强调） |
| **辅色** | 墨绿`#5A7A5A`（成功）+ 酒红`#8B4A4A`（警告） |
| **背景** | 羊皮纸质感`#F5ECD7` + 微弱纹理 |
| **字体** | 标题：衬线体（思源宋体）；正文：无衬线（思源黑体） |
| **装饰** | 章节分隔使用藤蔓花纹，按钮使用印章风格 |

### 7.3 开发规划

#### 7.3.1 MVP定义（最小可行产品）

**MVP目标**：验证"自定义剧本→体验剧本"的核心循环是否有趣。

| 功能 | MVP范围 | 延后 |
|------|---------|------|
| **剧本创建** | 基础模板 + 事件编辑器（剧情事件） | 高级自定义（经济/能力编辑器） |
| **剧本体验** | 进入剧本、触发事件、做出选择、查看结果 | 战斗系统、经济模拟 |
| **存档系统** | 单槽位存档、基础保存/加载 | 多槽位、自动存档、存档导出 |
| **世界观** | 背景故事文本 + 基础规则配置 | 势力动态演化 |
| **社区功能** | 本地剧本管理 | 在线分享、评价 |

**MVP开发周期**：12-16周

#### 7.3.2 开发里程碑

| 阶段 | 时间 | 目标 | 交付物 |
|------|------|------|--------|
| **Phase 0: 原型验证** | 4周 | 验证核心循环趣味性 | 可运行的事件触发+选择原型 |
| **Phase 1: MVP** | 12-16周 | 完整核心循环 | 基础编辑器+体验器+存档 |
| **Phase 2: 系统深化** | 12周 | 四大子系统完整 | 经济/能力/势力/高级事件 |
| **Phase 3: 社区与打磨** | 8周 | 社区功能+UI打磨 | 剧本分享/评价/排行榜 |
| **Phase 4: 内容扩展** | 持续 | 官方剧本+工具优化 | 3-5个精品官方剧本 |

#### 7.3.3 团队配置

| 角色 | 人数 | 职责 |
|------|------|------|
| **制作人/策划** | 1 | 整体设计、数值平衡、内容规划 |
| **引擎程序员** | 2 | 核心引擎（事件/经济/战斗/存档） |
| **工具程序员** | 1 | 剧本编辑器开发 |
| **前端/UI** | 1 | 界面实现、动效、视觉风格 |
| **美术** | 1 | UI美术、插画、图标 |
| **QA** | 1 | 测试、平衡性验证 |
| **合计** | 7人 | - |

#### 7.3.4 风险评估

| 风险 | 概率 | 影响 | 缓解策略 |
|------|------|------|--------|
| **编辑器复杂度过高** | 高 | 高 | 分阶段实现，MVP只做事件编辑 |
| **剧本平衡困难** | 高 | 中 | 提供自动化平衡检测工具 |
| **存档数据膨胀** | 中 | 中 | 差分存档+压缩+分区加载 |
| **社区内容质量参差** | 中 | 中 | 建立审核机制+社区评分系统 |
| **技术债务积累** | 中 | 高 | 每Phase预留20%时间处理技术债 |
| **引擎升级兼容性** | 低 | 中 | 已完成 4.4.1→4.7.1 升级；后续升级前必须备份+插件兼容确认+回滚方案 |
| **第三方插件 Alpha 稳定性** | 中 | 中 | Dialogic 2 为 Alpha 版，升级前备份；LimboAI 待确认 4.7 兼容后再启用 |

---

## 8. AI系统集成

> 本章规划AI技术在游戏中的全面应用方案。核心原则：**AI增强玩家创造力，而非替代**。所有AI功能定位为“智能助手”，最终决策权始终属于玩家。

### 8.1 AI辅助剧本创作系统

#### 8.1.1 AI世界观生成

**功能描述**：根据玩家输入的关键词/主题/风格偏好，自动生成完整的世界观设定草案。

**技术实现**：
| 组件 | 技术选型 | 说明 |
|------|---------|------|
| **核心模型** | GPT-4o / Claude 3.5 | 长文本生成能力强，支持结构化输出 |
| **本地备选** | Llama 3 70B / Qwen2.5 72B | 可本地部署，降低延迟和成本 |
| **输出格式** | JSON Schema约束 | 确保输出符合§3.2的BackgroundStory结构 |
| **上下文注入** | RAG + Few-shot | 注入优秀剧本示例作为参考 |

**交互设计**：
```
用户输入：
  “我想创建一个蒸汽朋克世界，魔法与机械并存，
   有三个互相竞争的城邦，核心矛盾是能源争夺”

AI输出（草案）：
  ┌─ 时代定义：3个纪元（蒸汽觉醒/机械繁荣/能源危机）
  ├─ 历史时间线：12个关键事件节点
  ├─ 势力设定：3个城邦（各有政治/经济/军事特征）
  ├─ 世界规则：魔法来源=蒸汽能量，代价=机械部件损耗
  └─ [查看完整草案] [重新生成] [微调某部分]
```

**数据流**：
```
输入：关键词/主题/风格描述 + 可选参考作品
  → LLM生成（结构化Prompt + JSON Schema约束）
  → 输出世界观草案（JSON格式，符合§3.2结构）
  → 用户审阅/编辑/确认
  → 写入WorldScript.worldview
```

**成本与性能**：
- 单次生成耗时：5-15秒（云端）/ 30-60秒（本地）
- 单次成本：约¥0.1-0.3（云端API）
- 优化策略：缓存相似请求结果、本地模型处理简单任务

#### 8.1.2 AI事件设计辅助

**功能描述**：辅助生成剧情事件、随机事件池、事件链逻辑。

**生成模式**：

| 模式 | 输入 | 输出 | 场景 |
|------|------|------|------|
| **单事件生成** | 事件主题+触发条件 | 完整StoryEvent结构 | “设计一个关于背叛的事件” |
| **事件链生成** | 起始事件+分支数 | 多分支因果网络 | “设计一个3分支的政治阴谋链” |
| **事件池填充** | 世界设定+已有事件 | 补充缺失类型的随机事件 | “我的森林区域缺少遭遇事件” |
| **条件建议** | 现有事件+世界规则 | 触发条件和后果建议 | “这个事件的后果是否合理” |

**技术实现**：
- 使用Function Calling确保输出符合§3.3的Event Schema
- 事件链生成使用Chain-of-Thought推理确保因果逻辑合理
- 通过RAG注入当前剧本已有事件作为上下文，避免重复和矛盾

**交互设计**：
- 事件编辑器侧边栏增加“AI助手”面板
- 用户可随时描述需求，AI实时建议
- 生成结果以可视化节点图展示，用户可拖拽调整
- 支持“继续发展”、“回滚”、“混合多个方案”操作

#### 8.1.3 AI经济平衡检测

**功能描述**：自动分析经济系统配置，检测失衡问题并提供调整建议。

**检测维度**：

| 检测项 | 检测方法 | 输出 |
|---------|---------|------|
| **通胀风险** | 模拟1000游戏日后货币供应量 | 警告/建议增加消耗点 |
| **资源枯竭** | 模拟有限资源的消耗曲线 | 警告/建议调整产出率 |
| **收入-支出失衡** | 计算玩家平均时收入/支出比 | 建议调整价格/奖励 |
| **市场操纵** | 检测是否存在无限套利路径 | 标记风险交易路径 |
| **难度经济匹配** | 检查经济难度与剧本难度是否一致 | 建议调整参数 |

**技术实现**：
- **数值分析层**：纯算法模拟（蒙特卡洛方法模拟N个玩家行为序列）
- **语义分析层**：LLM分析模拟结果并生成人类可读报告
- **建议生成层**：基于历史优秀剧本的参数分布提供调整建议

**数据流**：
```
EconomySystem配置（JSON）
  → 蒙特卡洛模拟器（10000次模拟）
  → 统计报告（通胀率/枯竭时间/收支比等）
  → LLM分析报告 + 生成调整建议
  → 输出：平衡性报告（评分+问题列表+建议列表）
```

#### 8.1.4 AI能力系统生成

**功能描述**：根据世界观设定自动生成技能树、成长路线。

**生成逻辑**：
```
输入：世界观规则（魔法规则、科技水平等）+ 战斗系统配置
  → 分析世界规则提取能力维度（魔法/科技/体术/社交等）
  → 生成技能分类体系（学派/流派）
  → 为每个技能生成：属性、公式、前置条件、成长曲线
  → 自动构建成长路线分支
  → 平衡性校验（确保各路线强度相近）
  → 输出完整AbilitySystem配置
```

**技术实现**：
- 使用LLM生成技能概念设计（名称、描述、效果）
- 使用规则引擎将概念设计转化为数值配置
- 使用模拟对战验证平衡性（AI控制不同build对战1000次）

### 8.2 AI驱动的动态内容生成

#### 8.2.1 AI NPC对话生成

**功能描述**：基于角色设定和当前情境，实时生成个性化NPC对话。

**技术架构**：
```
┌─────────────────────────────────────────┐
│              NPC对话引擎                 │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐ │
│  │角色设定 │  │情境上下文│  │对话历史 │ │
│  │(Character)│  │(Context) │  │(History) │ │
│  └────┬────┘  └────┬────┘  └────┬────┘ │
│       └──────────┬─┴──────────┘       │
│                  ▼                       │
│  ┌─────────────────────────────────┐ │
│  │    Prompt组装器                    │ │
│  │  系统提示 + 角色设定 + 世界规则 │ │
│  │  + 当前情境 + 关系状态 + 历史  │ │
│  └───────────────┬─────────────────┘ │
│                  ▼                       │
│  ┌─────────────────────────────────┐ │
│  │    LLM推理层                       │ │
│  │    (GPT-4o-mini / 本地Qwen2.5-7B) │ │
│  └───────────────┬─────────────────┘ │
│                  ▼                       │
│  ┌─────────────────────────────────┐ │
│  │    输出过滤层                       │ │
│  │    世界观一致性检查 + 安全过滤   │ │
│  └─────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

**Prompt模板**：
```
[System]
你是{npc_name}，{npc_description}。
你生活在{world_setting}中。
当前情境：{current_situation}
你与对方的关系：{relationship_status}
你的情绪状态：{emotion_state}
你知道的信息：{npc_knowledge}
你不知道的信息：{npc_ignorance}

[Rules]
- 保持角色一致性，不得跳出角色
- 只基于你知道的信息回答
- 语气和用词符合你的身份和时代背景
- 回复控制在1-3句话内（对话）或3-5句话（叙述）
- 如果涉及交易/任务，使用格式：[OFFER:物品/条件]
```

**性能优化**：
| 策略 | 说明 |
|------|------|
| **分层模型** | 重要NPC用GPT-4o-mini，普通NPC用本地7B模型 |
| **对话缓存** | 相似情境的对话缓存复用，仅变化部分重新生成 |
| **预生成池** | 为常见情境预生成对话候选，运行时选取 |
| **流式输出** | 流式返回，减少感知延迟 |
| **Token控制** | 限制NPC上下文窗口在1500 Token内 |

**成本估算**：
- 普通NPC对话：约¥0.002/次（本地模型近乎零成本）
- 重要NPC对话：约¥0.01/次
- 玩家平均每小时触发约30次NPC对话
- 预估每玩家每小时成本：¥0.1-0.3

#### 8.2.2 AI动态事件生成

**功能描述**：根据玩家行为实时生成个性化随机事件。

**触发条件**：
- 剧本定义的随机事件池已耗尽或全部冷却中
- 玩家处于“空白区域”（无预设事件覆盖）
- 玩家行为模式发生显著变化（如突然改变策略）

**生成流程**：
```
玩家行为序列 + 当前世界状态 + 剧本主题
  → 行为模式分析（LLM提取关键行为特征）
  → 事件概念生成（“玩家一直在帮助弱者，生成一个因此引来强敌关注的事件”）
  → 事件结构化（转化为RandomEvent Schema）
  → 一致性校验（检查是否与世界观/已有事件矛盾）
  → 注入当前事件队列
```

**约束规则**：
- 动态事件不得影响主线剧情（保护剧本作者的核心叙事）
- 动态事件难度不超过玩家当前等级+2
- 动态事件奖励不超过预设事件平均值×1.2（防止刷取）
- 每个动态事件标记`is_generated: true`，与作者预设事件区分

#### 8.2.3 AI场景描述生成

**功能描述**：为地点、物品、环境生成沉浸式文字描述。

**生成策略**：

| 场景 | 触发时机 | 描述长度 | 模型选择 |
|------|---------|---------|----------|
| **地点进入** | 玩家首次进入区域 | 3-5句 | GPT-4o-mini |
| **物品查看** | 玩家查看物品详情 | 1-3句 | 本地7B |
| **环境变化** | 天气/时间/事件导致环境变化 | 1-2句 | 本地7B |
| **战斗场景** | 战斗开始时 | 2-4句 | GPT-4o-mini |
| **氛围渲染** | 特定区域氛围描述 | 2-3句 | 本地7B |

**Prompt设计要点**：
- 注入世界风格关键词（“蒸汽朋克”“黑暗奇幻”等）
- 调用五感描写（视觉/听觉/嗅视/触觉）
- 与当前时间和天气联动
- 避免剧透未探索区域

**性能优化**：
- 地点描述首次生成后缓存，后续直接使用
- 使用模板+LLM混合模式：模板提供结构，LLM填充细节
- 预生成常用地点描述，运行时零延迟

### 8.3 AI辅助测试与优化

#### 8.3.1 AI自动化测试

**功能描述**：模拟玩家行为，自动测试剧本的完整性和可玩性。

**测试类型**：

| 测试类型 | 模拟方式 | 检测目标 | 执行时机 |
|---------|---------|---------|----------|
| **流程完整性** | AI Agent按事件链走完所有分支 | 死路径、无法触发的事件 | 剧本发布前 |
| **探索覆盖** | AI随机探索世界各区域 | 未连接区域、死锁状态 | 剧本发布前 |
| **选择覆盖** | AI遍历所有事件选择分支 | 未处理的后果、缺失分支 | 剧本更新时 |
| **极端行为** | AI模拟极端玩家行为（刷钱/不升级/跳过剧情） | 系统崩溃、数值溢出 | 定期回归测试 |
| **多周目测试** | AI模拟不同build多周目游玩 | 存档污染、状态残留 | 版本更新时 |

**技术实现**：
```
┌─────────────────────────────────────────┐
│           AI测试框架                       │
│  ┌─────────────────────────────────────┐ │
│  │  AI Agent（虚拟玩家）                 │ │
│  │  - 行为策略：探索型/速通型/极端型   │ │
│  │  - 决策模型：LLM + 规则混合         │ │
│  │  - 并行实例：同时运行100+Agent     │ │
│  └───────────────────┬─────────────────┘ │
│                      ▼                       │
│  ┌─────────────────────────────────────┐ │
│  │  剧本运行环境（沙箱）                 │ │
│  │  - 加速模式：100x游戏速度           │ │
│  │  - 状态快照：每步记录可回滚         │ │
│  │  - 事件拦截：记录所有触发事件       │ │
│  └───────────────────┬─────────────────┘ │
│                      ▼                       │
│  ┌─────────────────────────────────────┐ │
│  │  测试报告生成                         │ │
│  │  - 覆盖率报告（事件/区域/分支）   │ │
│  │  - 问题列表（死路径/失衡/崩溃）   │ │
│  │  - 修复建议（LLM生成）              │ │
│  └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

**成本与性能**：
- 单次完整测试：约10-30分钟（100x加速）
- 成本：约¥2-5/次（云端LLM Agent决策）
- 优化：本地小模型处理常规决策，仅复杂决策调用云端

#### 8.3.2 AI平衡性分析

**功能描述**：检测数值系统、难度曲线是否合理。

**分析维度**：

| 维度 | 分析方法 | 输出 |
|------|---------|------|
| **难度曲线** | 模拟玩家升级曲线，绘制难度/能力比 | 曲线图+异常点标记 |
| **技能平衡** | 模拟各成长路线通关效率 | 各路线通关时间对比表 |
| **经济平衡** | 见§8.1.3 | 经济平衡报告 |
| **事件难度** | 分析事件触发时玩家能力vs事件难度 | 难度不匹配事件列表 |
| **选择价值** | 分析各选择的收益差异 | 过于明显的“最优解”标记 |

**技术实现**：
- 数值分析使用纯算法（无需LLM）
- 报告生成和调优建议使用LLM
- 支持“一键调优”：LLM根据分析结果自动调整参数（用户确认后生效）

#### 8.3.3 AI Bug检测

**功能描述**：识别逻辑漏洞、死循环、无法触发的事件。

**检测类型**：

| Bug类型 | 检测方法 | 示例 |
|---------|---------|------|
| **死路径** | 图搜索算法遍历事件图，检测不可达节点 | 事件C需要条件A+B，但A和B互斥 |
| **死循环** | 检测事件链中的循环依赖 | 事件A触发B→B触发C→C触发A |
| **条件矛盾** | 静态分析条件表达式逻辑一致性 | 需要`level>50`但世界最高等级30 |
| **资源不可达** | 检查必需资源是否可通过任何路径获得 | 任务需要物品X但没有产出源 |
| **状态污染** | 检测跨分支的状态泄漏 | 分支A设置的变量影响了分支B |
| **时序错误** | 检查事件时间线逻辑一致性 | 事件发生在“世界创建前” |

**技术实现**：
- 静态分析：基于事件图的可达性分析（无需LLM）
- 语义分析：LLM检测“逻辑上不合理但技术上可执行”的问题
- 报告格式：问题描述 + 复现路径 + 修复建议

### 8.4 AI个性化体验

#### 8.4.1 AI难度自适应

**功能描述**：根据玩家表现动态调整游戏难度。

**监测指标**：

| 指标 | 采集方式 | 含义 |
|------|---------|------|
| **战斗胜率** | 最近10场战斗胜负比 | 战斗能力评估 |
| **选择犹豫时间** | 事件选择时的思考时长 | 玩家对内容的熟悉度 |
| **探索覆盖率** | 已探索区域/总区域 | 探索意愿 |
| **死亡次数** | 单位时间内的死亡次数 | 当前难度是否过高 |
| **资源积累速度** | 金币/物品的变化率 | 经济难度评估 |
| **放弃信号** | 频繁存档/读档、长时间停滞 | 挫败感检测 |

**自适应算法**：
```
每5分钟评估一次：
  计算综合表现分 P = Σ(指标i × 权重i)
  
  if P > 0.8:  # 玩家表现优秀
    难度系数 += 0.05（上限1.5）
    触发：解锁隐藏挑战事件、增加稀有奖励概率
    
  elif P < 0.3:  # 玩家表现较差
    难度系数 -= 0.05（下限0.5）
    触发：增加回复道具掉落、NPC给予提示、简化谜题
    
  else:  # 表现正常
    保持不变
```

**实现方式**：
- 不直接修改数值，而是调整“概率参数”（敌人AI激进度、奖励倍率、事件难度选择）
- 玩家可在设置中选择“固定难度”关闭自适应
- 难度变化对玩家透明，不显示“已为你降低难度”（保护体验）

#### 8.4.2 AI内容推荐

**功能描述**：基于玩家偏好推荐剧本和事件选项。

**推荐维度**：

| 推荐场景 | 推荐依据 | 推荐内容 |
|---------|---------|----------|
| **剧本推荐** | 已体验剧本的类型/风格/评分 | 相似风格的新剧本 |
| **事件选项提示** | 玩家历史选择模式 | “根据你的风格，你可能想选...”（可选关闭） |
| **创作素材** | 玩家正在创建的世界观类型 | 相关模板、组件、参考作品 |
| **社区互动** | 玩家擅长的领域 | 需要该类型内容的协作邀请 |

**技术实现**：
- 基于Embedding的相似度推荐（剧本向量化后计算余弦相似度）
- 协同过滤（相似玩家喜欢的剧本）
- 使用LLM生成推荐理由（“因为你很喜欢《星辰大陆》的势力博弈，推荐...”）

#### 8.4.3 AI叙事节奏控制

**功能描述**：根据玩家投入度动态调整剧情节奏。

**节奏检测模型**：

| 玩家状态 | 检测信号 | 节奏调整 |
|---------|---------|----------|
| **高度投入** | 快速响应、连续游玩、主动探索 | 加快节奏，增加事件密度，引入紧张冲突 |
| **轻度投入** | 偶尔响应、多任务切换 | 保持节奏，提供明确目标引导 |
| **即将流失** | 响应变慢、重复操作、长时间停滞 | 触发“亮点事件”（高潮剧情/惊喜奖励） |
| **疲劳信号** | 连续游玩>2小时、操作精度下降 | 游戏内角色建议休息，提供轻松日常事件 |

**实现方式**：
- 不改变剧本内容，而是调整“事件触发间隔”和“事件选择优先级”
- 在剧本定义中标记事件的“节奏类型”（高潮/过渡/日常/探索）
- AI节奏控制器决定下一个触发哪种节奏类型的事件

### 8.5 AI社区与审核

#### 8.5.1 AI内容审核

**功能描述**：自动检测社区剧本中的不当内容、抄袭、违规信息。

**审核维度**：

| 审核类型 | 检测方法 | 处理策略 |
|---------|---------|----------|
| **违规内容** | 关键词过滤 + LLM语义分析 | 自动拒绝发布 + 通知作者修改 |
| **抄袭检测** | 文本相似度对比（与已有剧本库） | 相似度>80%标记为疑似抄袭 |
| **个人信息泄漏** | NER模型检测姓名/电话/地址等 | 自动脱敏处理 |
| **恶意代码** | 静态分析检测死循环/资源耗尽逻辑 | 拒绝发布 + 安全报告 |
| **不当价值导向** | LLM评估是否包含歧视/暴力美化等 | 人工复审队列 |

**审核流程**：
```
剧本提交发布
  → 第一层：规则引擎（关键词/格式/结构校验）  [实时]
  → 第二层：AI审核（语义分析/抄袭检测）       [1-5分钟]
  → 第三层：人工审核（仅对AI标记的内容）     [24小时内]
  → 审核通过 → 发布
```

**技术实现**：
- 第一层：纯正则/规则匹配，零成本
- 第二层：本地分类模型（如BERT微调）+ 云端LLM（复杂案例）
- 抄袭检测：SimHash + 向量相似度双路检测
- 成本：约¥0.5-1/剧本审核

#### 8.5.2 AI质量评分

**功能描述**：对社区剧本进行多维度质量评估。

**评分维度**：

| 维度 | 权重 | 评估方法 |
|------|------|----------|
| **完整性** | 20% | 事件覆盖率、区域连通性、系统完整度 |
| **可玩性** | 25% | AI Agent测试的平均体验评分 |
| **平衡性** | 20% | 经济/战斗/难度平衡检测报告 |
| **原创性** | 15% | 与已有剧本的差异度分析 |
| **叙事质量** | 10% | LLM评估剧情吸引力、角色深度 |
| **技术质量** | 10% | 无Bug、无死路径、性能表现 |

**输出格式**：
```
剧本质量报告
├── 综合评分：8.2/10
├── 完整性：9/10（事件覆盖率100%，3个区域未充分利用）
├── 可玩性：8/10（AI Agent平均体验评分良好）
├── 平衡性：7/10（经济系统轻微通胀，建议调整资源产出）
├── 原创性：9/10（与现有剧本差异度85%）
├── 叙事质量：8/10（主线剧情引人入胜，支线可更丰富）
└── 技术质量：8/10（2个低优先级警告）
```

#### 8.5.3 AI标签生成

**功能描述**：自动为剧本生成分类标签和描述。

**生成策略**：
- 分析剧本的世界观、事件、系统配置提取关键特征
- 生成多维度标签：
  - **类型标签**：奇幻/科幻/历史/现代/恐怖...
  - **玩法标签**：战斗导向/探索导向/叙事导向/经营导向...
  - **难度标签**：新手友好/中等挑战/硬核...
  - **情感标签**：轻松/沉重/史诗/温馨...
  - **规模标签**：短篇(1-2h)/中篇(5-10h)/长篇(20h+)...
- 同时生成一句话描述和详细简介

### 8.6 AI集成架构与成本规划

#### 8.6.1 AI服务分层架构

```
┌─────────────────────────────────────────────────┐
│              AI服务网关（统一入口）                │
│  请求路由 | 负载均衡 | 降级策略 | 成本监控      │
└─────────────────────────────────────────────────┘
         │                    │                    │
    ┌────▼─────┐        ┌────▼─────┐        ┌────▼─────┐
    │ 云端服务  │        │ 本地服务  │        │ 边缘服务  │
    │          │        │          │        │          │
    │ GPT-4o   │        │ Qwen2.5  │        │ 预计算    │
    │ Claude   │        │ 72B      │        │ 缓存      │
    │ GPT-4o   │        │ Llama 3  │        │ CDN分发   │
    │  mini    │        │ 70B      │        │          │
    └──────────┘        └──────────┘        └──────────┘
    复杂任务          中等任务           简单任务
    高成本             中成本              零成本
```

**路由策略**：
| 任务类型 | 路由目标 | 理由 |
|---------|---------|------|
| 世界观生成 | 云端GPT-4o | 需要高质量长文本生成 |
| NPC对话（重要） | 云端GPT-4o-mini | 平衡质量与成本 |
| NPC对话（普通） | 本地7B模型 | 低成本高频调用 |
| 经济平衡检测 | 本地算法+LLM报告 | 算法为主，报告用LLM |
| 内容审核 | 本地分类模型 | 低延迟、隐私安全 |
| 场景描述 | 本地7B+缓存 | 可预生成、可缓存 |
| 标签生成 | 本地7B | 简单分类任务 |

#### 8.6.2 成本估算

**每玩家每月成本估算**：

| AI功能 | 调用频率 | 单次成本 | 月成本 |
|---------|---------|---------|--------|
| NPC对话 | 900次/月 | ¥0.005 | ¥4.5 |
| 场景描述 | 200次/月 | ¥0.001 | ¥0.2 |
| 动态事件 | 30次/月 | ¥0.02 | ¥0.6 |
| 创作辅助 | 10次/月 | ¥0.3 | ¥3.0 |
| 内容推荐 | 50次/月 | ¥0.005 | ¥0.25 |
| **合计** | - | - | **≈¥8.5/月** |

**成本优化策略**：
- **本地模型优先**：70%任务由本地模型处理
- **缓存复用**：相似请求复用结果，减少重复调用
- **批量处理**：非实时任务合并批量调用（降成本30%）
- **用户配额**：免费用户每日AI调用上限，付费用户更高配额
- **渐进式部署**：MVP阶段仅上线核心AI功能，逐步扩展

#### 8.6.3 MVP阶段AI功能优先级

| 优先级 | 功能 | MVP | Phase 2 | Phase 3 |
|---------|------|:---:|:---:|:---:|
| **P0** | AI NPC对话生成 | ✅ | - | - |
| **P0** | AI内容审核 | ✅ | - | - |
| **P1** | AI世界观生成辅助 | - | ✅ | - |
| **P1** | AI事件设计辅助 | - | ✅ | - |
| **P1** | AI场景描述生成 | - | ✅ | - |
| **P1** | AI标签生成 | - | ✅ | - |
| **P2** | AI经济平衡检测 | - | - | ✅ |
| **P2** | AI自动化测试 | - | - | ✅ |
| **P2** | AI难度自适应 | - | - | ✅ |
| **P2** | AI质量评分 | - | - | ✅ |
| **P3** | AI动态事件 | - | - | ✅ |
| **P3** | AI内容推荐 | - | - | ✅ |
| **P3** | AI叙事节奏控制 | - | - | ✅ |
| **P3** | AI能力系统生成 | - | - | ✅ |

#### 8.6.4 AI与现有系统集成方式

**集成原则**：
1. **AI是助手，不是替代**：所有AI输出均为“草案/建议”，玩家确认后才生效
2. **可关闭**：所有AI功能可在设置中关闭，不影响核心游戏体验
3. **透明性**：AI生成的内容明确标记`ai_generated: true`
4. **渐进式**：AI功能逐步上线，确保每步都稳定可靠

**集成点映射**：

| AI功能 | 集成到现有系统的哪个模块 | 集成方式 |
|---------|----------------------|----------|
| AI世界观生成 | §3.2 世界观设定系统 | 编辑器插件，输出写入WorldScript.worldview |
| AI事件设计 | §3.3 事件系统 | 编辑器插件，输出写入EventSystem |
| AI经济平衡 | §3.4 经济系统 | 分析工具，输出报告不直接修改 |
| AI能力生成 | §3.5 能力系统 | 编辑器插件，输出写入AbilitySystem |
| AI NPC对话 | §4 剧本运行架构 | 运行时服务，注入对话引擎 |
| AI动态事件 | §3.3 事件系统 | 运行时服务，动态注入RandomEvent |
| AI场景描述 | §4 剧本运行架构 | 运行时服务，注入渲染层 |
| AI测试 | §5 存档系统 | 独立工具，读取剧本+存档生成报告 |
| AI审核 | §7 社区功能 | 发布流程中间件 |
| AI推荐 | §7 主界面 | 推荐服务，读取玩家行为数据 |

---

### A. 核心术语表

| 术语 | 定义 |
|------|------|
| **世界剧本（World Script）** | 一个完整的、可独立运行的游戏世界定义 |
| **造物主模式** | 玩家创建和编辑剧本的模式 |
| **旅者模式** | 玩家进入剧本体验游戏的模式 |
| **因果标记（Causal Mark）** | 记录玩家选择后果的持久化标记 |
| **规则涌现** | 不同系统规则交互产生的非预期游戏体验 |
| **事件链** | 多个事件按因果/时间关系串联的序列 |
| **势力演化** | 势力状态随时间和玩家行为动态变化 |
| **诗墨** | 游戏内软货币 |
| **界石** | 游戏内硬货币/高级货币 |
| **灵感点** | 进入剧本体验消耗的体力值 |
| **AI服务分层** | 云端/本地/边缘三级AI服务架构，按任务复杂度路由 |
| **因果标记（Causal Mark）** | 记录玩家选择后果的持久化标记，支持事件链因果追踪 |
| **AI Agent测试** | 模拟玩家行为的AI自动化测试框架，支持并行运行100+虚拟玩家 |
| **动态事件生成** | 根据玩家行为实时生成个性化随机事件的AI功能 |
| **叙事节奏控制** | 根据玩家投入度动态调整事件触发间隔和剧情节奏的AI系统 |

### B. 参考竞品详析

| 维度 | 本产品 | RPG Maker | AI Dungeon | Minecraft |
|------|--------|-----------|------------|-----------|
| **自定义深度** | ★★★★★ | ★★★ | ★★ | ★★★★ |
| **上手门槛** | ★★★ | ★★★★ | ★★★★★ | ★★★★ |
| **系统涌现性** | ★★★★ | ★★ | ★★★ | ★★★★★ |
| **叙事能力** | ★★★★★ | ★★★★ | ★★★★ | ★★ |
| **社区生态** | ★★★（起步） | ★★★★★ | ★★★★ | ★★★★★ |
| **独立世界** | ★★★★★ | ★★ | ★ | ★★★ |

---

> **文档维护说明**：本文档应随产品迭代持续更新。每个Phase完成后进行文档Review，确保设计方案与实际实现一致。
