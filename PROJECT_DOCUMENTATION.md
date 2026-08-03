# 万界诗篇（Poems of Ten Thousand Worlds）— 项目完整说明文档

> **版本**：v1.0 | **引擎**：Godot 4.7.1 | **语言**：GDScript | **渲染器**：gl_compatibility  
> **定位**：支持玩家自定义世界剧本的沙盒式游戏体验平台（游戏编辑器 + 游玩器一体化）

---

## 一、项目概述

### 1.1 核心概念

玩家既是"造物主"（创造世界剧本），也是"旅者"（体验世界剧本）。  
类似罗布乐思（Roblox）的定位，但聚焦于**规则与叙事**而非空间建造，目标是让零基础用户也能创建并运行复杂游戏/剧本作品。

### 1.2 核心卖点

| 卖点 | 描述 |
|------|------|
| 完全自定义剧本 | 从物理法则到经济体系，从历史事件到角色技能，全部可自定义 |
| 剧本即游戏 | 每个剧本就是一个完整的、可独立运行的游戏体验 |
| 零门槛创作 | 可视化编辑器 + 模板系统 + AI辅助，无需编程即可创建剧本 |
| 规则涌现 | 不同系统之间的交互产生意料之外的游戏体验 |

### 1.3 双循环设计

- **创造循环**（造物主模式）：构思 → 定义规则 → 测试运行 → 调优 → 发布
- **体验循环**（旅者模式）：选择世界 → 创建角色 → 探索互动 → 做出选择 → 承受后果

---

## 二、仓库目录结构

```
e:\ZX\QWXM\WJSP\XM1\
├── wanjie/                    ← Godot 4.7.1 客户端主项目
│   ├── project.godot          ← 项目配置（Autoload、渲染、输入映射）
│   ├── assets/                ← 资源（音频/字体/纹理）
│   ├── resources/
│   │   ├── data/              ← Resource数据模型类（10个.gd）
│   │   └── themes/            ← 主题资源
│   ├── scenes/                ← 场景文件（.tscn）
│   │   ├── main/              ← 主大厅 main_hub.tscn
│   │   ├── editor/            ← 剧本编辑器 script_editor.tscn + panels/
│   │   ├── player/            ← 剧本体验器 script_player.tscn
│   │   ├── components/        ← 可复用UI组件（卡片/弹窗/Toast）
│   │   ├── settings/          ← 设置界面
│   │   └── ui/                ← 对话框（确认/模板）
│   ├── scripts/
│   │   ├── autoload/          ← 全局单例（10个）
│   │   ├── editor/            ← 编辑器系统（核心，~40个文件）
│   │   │   ├── visual/        ← 可视化编辑子模块（10个）
│   │   │   ├── ide/           ← IDE式编辑器组件（18个）
│   │   │   ├── mud/           ← MUD数据表编辑器（15+个）
│   │   │   └── panels/        ← 四大系统面板
│   │   ├── player/            ← 运行时引擎（6个）
│   │   └── ui/                ← UI控制器
│   └── mud_engine/            ← MUD数据表（30+张txt）+ 导出脚本
├── ME/                        ← MUD编辑器（独立桌面工具，Lua 5.1 + luvit + MFC）
│   ├── MUDEditor.exe          ← 独立可执行文件
│   ├── export/export.lua      ← 数据导出脚本（1190行）
│   ├── testsvr/               ← 测试服务器 + 数据表
│   └── lexers/                ← 语法高亮
├── GDD_万界诗篇_游戏开发方案.md  ← 游戏设计文档（1858行）
├── GDD_AI对话酒馆_游戏开发方案.md ← AI对话子系统设计文档
└── Godot_v4.4.1-stable_win64.exe ← 引擎可执行文件（实际使用4.7.1）
```

---

## 三、技术架构

### 3.1 双系统架构

```
┌─────────────────────────────────────────────────────────────┐
│                    ME/ (MUD编辑器 - 独立工具)                  │
│  Lua 5.1 + luvit + MFC + SQLite                             │
│  功能: 数据表管理 → export.lua → JSON txt 文件                 │
└──────────────────────────┬──────────────────────────────────┘
                           │ 数据流: SQLite → JSON txt
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                wanjie/ (Godot客户端 - 主项目)                  │
│  Godot 4.7.1 + GDScript + gl_compatibility                   │
│  功能: 可视化编辑 + 剧本运行时 + AI对话 + 存档                  │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 Autoload 全局单例（10个）

| 单例名 | 文件 | 职责 |
|--------|------|------|
| GameManager | game_manager.gd | 用户数据、剧本列表、全局状态、资源恢复 |
| SceneManager | scene_manager.gd | 场景切换、当前剧本ID传递 |
| SaveManager | save_manager.gd | 存档读写（差分/完整JSON） |
| ScriptDataManager | script_data_manager.gd | 剧本CRUD、导入导出、模板、拆分存储 |
| ToastManager | toast_manager.gd | 全局Toast通知 |
| LLMClient | llm_client.gd | 多供应商LLM API（OpenAI/DeepSeek/通义千问/Moonshot/智谱） |
| TavernManager | tavern_manager.gd | AI对话酒馆（角色卡/世界书/Prompt组装） |
| ThemeManager | theme_manager.gd | 主题管理、动画开关 |
| Dialogic | 插件UID | 对话系统插件（2.0-Alpha-20） |
| PhantomCameraManager | 插件UID | 相机控制插件（0.11.0.3） |

### 3.3 数据模型层（resources/data/）

| 类名 | 文件 | 说明 |
|------|------|------|
| WorldScriptData | world_script_data.gd | **剧本容器**（顶层Resource），包含四大子系统引用 |
| WorldviewData | worldview_data.gd | 世界观（背景故事/时代/时间线/规则/势力/地理） |
| EventSystemData | event_data.gd | 事件系统（剧情事件/随机事件/事件链/触发条件） |
| EconomySystemData | economy_data.gd | 经济系统（货币/资源/市场/交易规则） |
| AbilitySystemData | ability_data.gd | 能力系统（技能/成长路径/战斗机制/状态效果） |
| QuestData | quest_data.gd | 任务系统 |
| CombatData | combat_data.gd | 战斗/NPC系统 |
| SaveData | save_data.gd | 存档数据 |
| UserData | user_data.gd | 用户数据（诗墨/界石/灵感/精力） |
| SkillDataInit | skill_data_init.gd | 技能初始化数据 |

### 3.4 剧本存储结构

```
user://scripts/{id}/
├── script.json          ← 主数据（元数据 + 子系统引用）
├── data/
│   ├── worldview.json   ← 世界观拆分
│   ├── events.json      ← 事件拆分
│   ├── economy.json     ← 经济拆分
│   └── abilities.json   ← 能力拆分
├── mud/                 ← MUD数据表（可选）
└── assets/              ← 剧本专属资源
```

---

## 四、剧本编辑器系统（核心）

### 4.1 三模式编辑器

剧本编辑器支持三种编辑模式，通过 `metadata["editor_mode"]` 锁定：

| 模式 | 说明 | 数据存储 |
|------|------|----------|
| **visual** | 可视化编辑（表单+蓝图节点图） | WorldScriptData 四大子系统 |
| **code** | GDScript风格代码编辑 | 同上（通过ScriptCodeGen双向转译） |
| **mud** | MUD数据表编辑（复刻MUDEditor.exe） | metadata["mud_data"] |

**切换机制**：顶栏"🔄 切换编辑器"按钮 → 当前编辑器 apply/save → WorldScriptData（共享模型）→ 目标编辑器 load/重建

### 4.2 三层渐进编辑模型（L1/L2/L3）

| 层级 | 名称 | 面向用户 | 编辑方式 |
|------|------|----------|----------|
| L1 | 表单层 | 零基础用户 | 填空式下拉编辑 |
| L2 | 规则层 | 初级创作者 | When-Do 卡片 |
| L3 | 节点图/代码层 | 高级用户 | 蓝图节点图 + 自定义代码 |

三层共享同一数据源，支持自由切换视图而不丢失信息。

### 4.3 可视化编辑子模块（scripts/editor/visual/）

所有子模块继承 `VisualModuleBase`（RefCounted），通过 `_host` duck-typed 引用主编辑器：

| 模块 | 文件 | 功能 |
|------|------|------|
| visual_event.gd | 2804行 | 事件编辑器 + 蓝图系统（L1表单/L3节点图） |
| visual_economy.gd | - | 经济系统编辑 |
| visual_ability.gd | - | 能力系统编辑 |
| visual_worldview.gd | - | 世界观编辑 |
| visual_map.gd | - | 地图编辑 |
| visual_quest.gd | - | 任务系统编辑 |
| visual_combat.gd | - | 战斗系统编辑 |
| visual_test_runner.gd | - | 测试运行器 |
| visual_ai_assistant.gd | 324行 | AI辅助创作面板 |
| visual_module_base.gd | 104行 | 基类（_ws/_ui/_log/_sync/_dirty/_rebuild_tree） |

### 4.4 蓝图系统

蓝图系统是游戏规则可视化编辑的核心，采用**自定义绘制**（非GraphEdit控件）：

| 组件 | 文件 | 职责 |
|------|------|------|
| BlueprintData | blueprint_data.gd (355行) | 数据模型：节点/引脚/连线结构、PinDataType枚举、兼容性校验 |
| BlueprintNodeRegistry | blueprint_node_registry.gd (632行) | 节点注册表：8大分类、元数据、参数定义、懒加载 |
| BlueprintValidator | blueprint_validator.gd (212行) | 校验器：参数合法性、引用存在性、连接兼容性、孤立节点 |
| BlueprintExecutor | blueprint_executor.gd (553行) | 运行时执行器：遍历执行流、映射到引擎调用 |
| ScriptCodeGen | script_codegen.gd (1081行) | 代码生成/解析：WorldScriptData ↔ GDScript风格文本 |
| ConditionCompiler | condition_compiler.gd (514行) | 条件编译器：结构化条件 ↔ 运行时条件 双向投影 |

**蓝图节点8大分类**：
1. 流程控制（flow）⚙
2. 经济交易（economy）💰
3. 剧情事件（story）📖
4. 技能能力（ability）✨
5. 战斗系统（combat）⚔
6. 世界势力（world）🌍
7. 角色玩家（player）🧑
8. 任务系统（quest）📋

**引脚类型**：EXEC(0), BOOL(1), INT(2), FLOAT(3), STRING(4), ANY(5)

### 4.5 IDE式编辑器组件（scripts/editor/ide/）

完全复刻 Godot 4.7.1 编辑器风格：

| 组件 | 功能 |
|------|------|
| ide_top_bar.gd | 顶栏三段式结构 |
| ide_dock_left.gd | 左侧Dock（文件系统/场景树） |
| ide_dock_right.gd | 右侧Dock（检查器/节点面板） |
| ide_workspace.gd | 中央四工作区容器 |
| ide_bottom_panel.gd | 底部面板（输出/调试/搜索） |
| ide_status_bar.gd | 状态栏（光标定位等） |
| ide_menu_bar.gd | 菜单栏 |
| ide_file_system.gd | 文件管理系统 |
| ide_scene_tree.gd | 场景树 |
| ide_inspector.gd | 属性检查器 |
| ide_script_panel.gd / ide_script_view.gd | 脚本面板/视图 |
| ide_theme.gd | 集中配色定义 |
| ide_settings_dialog.gd | 设置对话框 |
| ide_shortcuts_dialog.gd | 快捷键对话框 |
| ide_create_node_dialog.gd | 创建节点对话框 |
| ide_signal_dialog.gd | 信号连接对话框 |
| ide_history_panel.gd | 历史面板 |
| ide_about_dialog.gd | 关于对话框 |

### 4.6 MUD数据表编辑器（scripts/editor/mud/）

复刻独立 MUDEditor.exe 的功能，内嵌到 Godot 编辑器中：
- 15个标签页（配置驱动构建）
- 地图画布（MudMapCanvas）
- 数据表Widget（MudTableWidget）
- 导入/导出管道（MudImport / MudExport）
- 触发器编辑器（MudTriggerEditor）
- 多种编辑对话框（物品/技能/场景/路径/属性/对话等）

### 4.7 2D/3D场景编辑器

| 文件 | 行数 | 功能 |
|------|------|------|
| scene_editor_2d.gd | 1075行 | 类Godot 2D编辑器（可视化创建/编辑UI控件、拖拽、缩放、网格吸附） |
| scene_editor_3d.gd | - | 3D场景编辑器（SubViewport渲染） |

---

## 五、运行时引擎（scripts/player/）

剧本体验器（script_player.gd）在运行时加载 WorldScriptData 并驱动四大引擎：

| 引擎 | 文件 | 职责 |
|------|------|------|
| EventEngine | event_engine.gd (268行) | 事件触发、选择处理、因果追踪、冷却管理 |
| EconomyEngine | economy_engine.gd (98行) | 供需定价、买卖交易、库存管理 |
| CombatEngine | combat_engine.gd (306行) | 回合制战斗（HP/MP/ATK/DEF/速度/元素） |
| WorldState | world_state.gd (117行) | 游戏时间推进、世界变量、势力状态、活跃效果 |
| BlueprintExecutor | blueprint_executor.gd (553行) | 蓝图图运行时执行（对接上述四引擎） |
| ScriptPlayer | script_player.gd (373行) | 体验器主控（打字机效果、选择UI、历史面板） |

**执行流程**：
```
ScriptPlayer._init_engines()
  → WorldState / EventEngine / EconomyEngine / CombatEngine 初始化
  → BlueprintExecutor.init_engines(...)
  → 事件触发 → BlueprintExecutor.execute_graph(graph)
  → 遍历执行流节点 → 映射到引擎API调用
```

---

## 六、AI系统集成

### 6.1 LLM客户端（全局Autoload）

`LLMClient`（llm_client.gd, 289行）支持多供应商：
- OpenAI（gpt-4o / gpt-4.1）
- DeepSeek（deepseek-chat / deepseek-reasoner）
- 通义千问（qwen-turbo / qwen-plus / qwen-max）
- Moonshot/Kimi（moonshot-v1-8k/32k/128k）
- 智谱AI（glm-4-flash / glm-4 / glm-4-plus）
- 自定义OpenAI兼容API

### 6.2 AI对话酒馆（TavernManager）

作为万界诗篇的"AI NPC对话引擎"子系统集成：
- 角色卡管理（性格/背景/开场白/示例对话）
- 世界书（World Book）上下文注入
- 对话历史 + Prompt组装
- 通过 LLMClient 调用云端API

### 6.3 AI辅助创作（编辑器内嵌）

| 文件 | 职责 |
|------|------|
| ai_service.gd (174行) | AI服务抽象层（多后端：OpenAI兼容/本地Ollama/Mock模拟） |
| ai_prompts.gd (144行) | Prompt模板库（世界观/事件/经济/能力四大模板） |
| visual_ai_assistant.gd (324行) | AI助手面板UI（聊天日志/快捷功能/设置/配置持久化） |

功能：世界观生成、事件编排建议、经济平衡分析、能力设计辅助、自由对话。

---

## 七、UI/UX架构

### 7.1 应用流程

```
main_hub.tscn (万界大厅)
  ├── 剧本卡片网格（创建/编辑/删除/体验）
  ├── 轮播推荐
  ├── 最近游玩
  └── 搜索/标签筛选
       │
       ├──→ script_editor.tscn (剧本编辑器)
       │      ├── 左: 模块树（世界观/事件/经济/能力/任务/战斗/地图/AI助手/测试）
       │      ├── 中: 编辑区（visual/code/mud三模式）
       │      ├── 右: 概览/详情/属性面板
       │      └── 底: 输出/校验/模板
       │
       └──→ script_player.tscn (剧本体验器)
              ├── 主文本（打字机效果）
              ├── 选择按钮
              ├── 玩家状态栏（HP/MP/金币/等级）
              └── 历史面板
```

### 7.2 编辑器布局（复刻Godot IDE）

```
┌─────────────────────────────────────────────────────────────┐
│ 菜单栏 (文件/编辑/视图/运行/帮助) + 模式切换 + 工具按钮       │
├────────┬────────────────────────────────────┬───────────────┤
│ 左Dock │        中央编辑区                    │   右Dock      │
│ 模块树  │  (visual/code/mud 三模式切换)       │  概览/属性    │
│ 文件系统│                                    │  检查器       │
├────────┴────────────────────────────────────┴───────────────┤
│ 底部面板 (输出日志 / 校验结果 / 模板库)                        │
├─────────────────────────────────────────────────────────────┤
│ 状态栏                                                       │
└─────────────────────────────────────────────────────────────┘
```

### 7.3 主题与配色

- 全局主题：`resources/themes/main_theme.tres`
- 默认字号：15
- 窗口：1280×720，全屏模式，canvas_items拉伸
- 编辑器采用暗色主题（IDE风格）
- MUD编辑器独立暗色配色方案

---

## 八、关键设计模式与约束

### 8.1 GDScript编码约束

| 约束 | 说明 |
|------|------|
| 类型推断限制 | 通过duck-typed变量调用方法时，返回值**不能**用`:=`，必须显式标注类型 |
| RefCounted限制 | RefCounted基类脚本**不能**调用Node方法（add_child/get_viewport等），必须委托宿主Node |
| .uid文件 | 严禁删除；移动/重命名脚本必须同步迁移.uid |
| 场景格式 | format=3，兼容4.7.1 |
| 渲染器 | gl_compatibility（非Forward+） |

### 8.2 架构模式

| 模式 | 应用 |
|------|------|
| 模块化子编辑器 | VisualModuleBase基类 + _host duck-typed引用主编辑器 |
| 共享数据模型 | WorldScriptData作为三模式编辑器的唯一数据源 |
| 懒加载注册表 | BlueprintNodeRegistry.ensure_init() 静态初始化 |
| 配置驱动UI | MudTabBuilder通过配置构建15个标签页 |
| 双向编译 | ConditionCompiler: 结构化条件 ↔ 运行时条件 |
| 代码生成/解析 | ScriptCodeGen: WorldScriptData ↔ GDScript风格文本 |
| 信号解耦 | 引擎间通过signal通信，避免硬引用 |

### 8.3 数据序列化

- 所有游戏数据使用 Dictionary/Array（JSON可序列化）
- Resource类仅用于编辑器内的类型安全包装
- 存档格式：完整JSON（计划升级为差分存档）
- MUD数据：30+张txt文件（制表符分隔）

---

## 九、构建与验证

### 9.1 运行环境

- **引擎**：Godot 4.7.1 stable (win64)
- **可执行文件**：`E:\ZX\QWXM\WJSP\XM1\Godot_v4.7.1-stable_win64.exe`
- **项目路径**：`E:\ZX\QWXM\WJSP\XM1\wanjie\`
- **主场景**：`res://scenes/main/main_hub.tscn`

### 9.2 验证命令

```powershell
cd E:\ZX\QWXM\WJSP\XM1
$out = .\Godot_v4.7.1-stable_win64.exe --headless --path wanjie --import 2>&1 | Out-String
$errs = ($out | Select-String -Pattern "SCRIPT ERROR" -AllMatches).Matches.Count
Write-Output "SCRIPT_ERROR_COUNT=$errs"
```

期望输出：`SCRIPT_ERROR_COUNT=0`

### 9.3 插件依赖

| 插件 | 版本 | 状态 |
|------|------|------|
| Dialogic | 2.0-Alpha-20 | 启用（4.5+兼容） |
| Phantom Camera | 0.11.0.3 | 启用（稳定） |
| LimboAI | 1.7.x | 已禁用（待确认4.7兼容） |

---

## 十、GDD章节对照（实现状态）

| GDD章节 | 内容 | 实现状态 |
|---------|------|----------|
| §1 游戏概述 | 核心概念/卖点/受众 | ✅ 框架完成 |
| §2 核心玩法 | 双循环/资源模型/心流 | ✅ 基础实现 |
| §3 剧本自定义系统 | 四大子系统数据结构 | ✅ Resource模型完成 |
| §4 剧本运行架构 | 四大引擎 + 蓝图执行 | ✅ 基础实现 |
| §5 存档与数据管理 | 存档/拆分存储/迁移 | ✅ 完成 |
| §6 技术架构 | 双系统/数据流 | ✅ 完成 |
| §7 UI/UX设计 | 大厅/编辑器/体验器 | ✅ IDE式编辑器完成 |
| §8 AI系统集成 | LLM/酒馆/辅助创作 | ✅ 基础框架完成 |

---

## 十一、文件统计

| 类别 | 数量 | 说明 |
|------|------|------|
| GDScript文件 | ~100个 | 含autoload/editor/player/ui |
| 场景文件 | 20个 | .tscn |
| Resource数据类 | 10个 | resources/data/ |
| MUD数据表 | 30+张 | mud_engine/data/ |
| 编辑器核心文件 | ~40个 | scripts/editor/ |
| 总代码量（估） | ~30000行 | GDScript |

---

## 十二、核心API速查

### WorldScriptData（剧本容器）
```gdscript
var id: String
var name: String
var version: String
var worldview: WorldviewData
var event_system: EventSystemData
var economy_system: EconomySystemData
var ability_system: AbilitySystemData
var quest_system: Resource
var combat_system: Resource
var metadata: Dictionary  # 扩展配置（editor_mode, mud_data等）
func ensure_subsystems() -> void
```

### BlueprintData（蓝图数据）
```gdscript
static func make_graph() -> Dictionary
static func create_node(graph, node_type, pos) -> String
static func add_connection(graph, from_node, from_port, to_node, to_port) -> bool
static func validate_connection(graph, from_node, from_port, to_node, to_port) -> bool
static func get_pin_world_pos(node, pin_type, pin_index) -> Vector2
static func calc_node_height(node) -> float
static func find_entry_nodes(graph) -> Array
```

### BlueprintNodeRegistry（节点注册表）
```gdscript
static func get_definition(node_type) -> Dictionary
static func get_all_types() -> Array[String]
static func get_types_by_category(category) -> Array[String]
static func create_node(node_type) -> Dictionary
static func get_param_options(node_type, param_name, ws) -> Array
static func search_nodes(query) -> Array[String]
```

### ConditionCompiler（条件编译器）
```gdscript
static func compile_condition(structured: Dictionary) -> Dictionary  # 结构化→运行时
static func decompile_condition(runtime: Dictionary) -> Dictionary   # 运行时→结构化
static func compile_action(structured: Dictionary) -> Dictionary
static func decompile_action(runtime: Dictionary) -> Dictionary
```

### ScriptCodeGen（代码生成器）
```gdscript
static func generate(ws: WorldScriptData) -> String          # 数据→代码
static func parse(code: String) -> WorldScriptData           # 代码→数据
static func generate_blueprint_code(graph, ws) -> String     # 蓝图→代码
```

### LLMClient（AI客户端）
```gdscript
func chat(messages: Array, options: Dictionary = {}) -> void  # 异步请求
signal response_received(content: String)
signal request_failed(error: String)
# 支持: openai / deepseek / qwen / moonshot / zhipu / custom
```

---

## 十三、开发注意事项

1. **PowerShell不支持`&&`**，使用`;`分隔命令
2. **duck-typed访问**：`_host.xxx()` 返回值不能用`:=`推断类型，必须显式标注
3. **RefCounted ≠ Node**：可视化模块基类是RefCounted，不能调用add_child/get_viewport
4. **模式锁定**：编辑器进入时根据metadata锁定模式，隐藏切换按钮
5. **MUD数据独立**：MUD编辑器数据存于metadata["mud_data"]，与四大子系统独立
6. **自动保存**：60秒间隔，_is_dirty标记驱动
7. **撤销/重做**：全局UndoRedo + 蓝图独立undo/redo栈
8. **JSON序列化**：注意int/float类型转换（Godot JSON默认float）

---

## 十四、深度完善记录（v1.1）

> 本轮在既有编辑器体系上完成的架构升级与功能补全（2026-08）。

### 14.1 蓝图运行时（蓝图真正实现功能）

- **运行时驱动**：`ScriptPlayer` 事件带蓝图图时由 `BlueprintExecutor` 驱动（标记触发 → 执行图 → story_choice 暂停 → resume_choice 续跑），无图回退传统 `event_engine` 流程
- **GraphStore**（scripts/player/graph_store.gd）：蓝图图注册表，key 规范 `evt:<event_id>` 事件图 / `sys:<name>` 系统图，运行时与编辑器共用
- **子图机制**：`flow_sub_graph` 节点按 key 调用子图（`execute_sub_graph` 变量隔离、子图内 story_choice 暂停向上传播可 resume）；属性面板经 `blueprint_graphs` 数据池下拉选图
- **编译全覆盖**：`BlueprintCodeGen` 8 大分类（flow/economy/story/world/player/combat/ability/quest）全部节点生成真实 GDScript 调用（语义与运行时 handler 一致），仅数据源与复杂状态节点保留说明注释；校验仅 error 中止（warn 放行），孤立 start 入口不再误报

### 14.2 统一蓝图编辑器（UE 风格）

- `visual_blueprint_workspace.gd`：模块树顶级条目"🔷 蓝图工作区"，所有系统（事件/经济/能力/战斗/世界/玩家/任务）共用一个蓝图编辑器
- 图列表（新建/重命名/删除/切换）、单画布编辑（复用 `VisualEventBlueprint` 成熟交互：拖拽/连线/缩放/右键分类菜单/属性面板/50步撤销/搜索/小地图）、编译（产物写入图 `_compiled_code`）
- 与 L1/L3、code 模式共享同一 WorldScriptData（图存 `blueprint_graphs` 随 events.json 持久化）

### 14.3 游戏类型模板系统

- `script_templates.gd`：模板 = 元数据 + 四子系统 + quest/combat + 预置可执行蓝图图
- 6 个游戏类型：经典RPG冒险 / 互动小说 / 模拟经营 / 回合策略 / 战斗竞技 / 探索解谜（创建剧本时可选，带 icon/描述/推荐标签）
- quest/combat 纳入拆分存储（data/quest.json、data/combat.json，含旧剧本迁移兼容）；`dragonflame_era` 补 UI 入口

### 14.4 2D/3D 场景编辑器

- 2D 补齐：上/下/水平/垂直对齐、水平/垂直等距分布、锚点预设（左上/居中/全屏）
- 3D 补齐：拖拽网格吸附、Vector3 JSON 容错
- **编辑落代码**：`ScriptCodeGen` 新增 `scene_2d`/`scene_3d` 章节双向转译——IDE 内 2D/3D 编辑实时反映到代码文本，代码解析回场景数据（含 Vector2/3 类型还原、嵌套层级、场景名）
- JSON 往返容错：2D/3D 编辑器 `_to_vec2/_to_vec3/_set_pos_x/_set_pos_y` 修复坐标字符串化导致的编辑崩溃

### 14.5 MUD 编辑器

- 表搜索/过滤：`MudTableWidget.set_filter` + 15 个标签页搜索框
- schema 一致性验证：`gameinit.sql` 28 表 ↔ `mud_schema_internal.TABLES` 完全一致；导出文件清单与 ME/testsvr/data parity（32 txt）
- 数据接入闭环：metadata["mud_data"] ↔ 剧本 `{id}/mud/` 目录自动导出（save_script 触发）

### 14.6 测试套件（22 个 SceneTree 测试脚本, wanjie/temp_scripts/）

蓝图运行时：test_blueprint_runtime / _link / _subgraph / _codegen_coverage / _workspace
模板：test_templates
场景：test_scene_editor / test_codegen_scene
MUD：test_mud_full / test_mud_schema_parity
回归：test_blueprint_split / test_user_data_persist / test_form_undo / test_diff_save(_game) / test_executor_enhance / test_node_coverage / test_mode_switch / test_visual_event_split / test_ai_assistant / test_ide_panel / test_codegen_quest_combat

验证基线：`SCRIPT_ERROR_COUNT=0`（--headless --import）+ 22/22 测试 PASS + 主场景 smoke 10 帧零错误。
