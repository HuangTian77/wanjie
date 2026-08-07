# 万界诗篇 — 项目理解总结（AI 协作上下文版）

> **用途**：提供给协作 AI（如 DeepSeek ReasonUX）的完整项目上下文。
> **生成时间**：2026-08 | **引擎**：Godot 4.7.1（gl_compatibility） | **语言**：GDScript | **仓库**：Git + Git LFS
> **配套文档**：`PROJECT_DOCUMENTATION.md`（完整说明 v1.1）、`GDD_万界诗篇_游戏开发方案.md`（1858行设计文档）、`README.md`

---

## 0. 一句话项目定义

**万界诗篇 = "游戏编辑器 + 游玩器"一体化沙盒平台**：玩家用可视化编辑器创建"世界剧本"（世界观/事件/经济/能力/任务/战斗六大系统），剧本由蓝图节点图真正驱动运行，零基础可填表创作、进阶可画蓝图、高级可写代码。类似 Roblox 但聚焦**规则与叙事**而非空间建造。

---

## 1. 整体架构：双系统 + 数据流

### 1.1 双系统结构

```
┌────────────────────────────────────────────────────────────┐
│  ME/（MUD 编辑器 — 独立桌面工具，历史遗产+参考实现）          │
│  Lua 5.1 + luvit + MFC + SQLite + HiLayout UI               │
│  MUDEditor.exe + export/export.lua(1190行, 30+表导出)        │
└─────────────────────────┬──────────────────────────────────┘
                          │ 数据流: SQLite → export.lua → JSON txt
                          ▼
┌────────────────────────────────────────────────────────────┐
│  wanjie/（Godot 4.7.1 客户端 — 主项目，活跃开发）             │
│  GDScript + gl_compatibility 渲染器，窗口 1280×720 全屏      │
│  内含：剧本编辑器(visual/code/mud) + 剧本体验器 + AI系统      │
└────────────────────────────────────────────────────────────┘
```

注意：ME 是独立工具，**不内嵌于 Godot**；Godot 端已完整复刻其功能（`scripts/editor/mud/`，28内部表/33导出txt/15标签页）。

### 1.2 三条核心数据流

**① 创作流（编辑器 → 磁盘）**
```
模块树选择 → visual_*.gd create() 构建UI → 编辑 WorldScriptData 子系统
  → _sync_to_code_editor()（ScriptCodeGen.generate 实时同步代码视图）
  → _mark_dirty() → 自动保存(60s)/手动保存
  → ScriptDataManager.save_script()
  → user://scripts/{id}/script.json + data/{worldview,events,economy,abilities,quest,combat}.json + mud/
```

**② 运行流（磁盘 → 游玩）**
```
main_hub(万界大厅) → SceneManager.enter_script(id)（先确保落盘）
  → script_player.tscn 加载 WorldScriptData
  → 初始化四引擎(WorldState/Event/Economy/Combat) + BlueprintExecutor.init_engines()
  → 事件触发 → GraphStore.get_graph(ws, "evt:<event_id>")
  → BlueprintExecutor.execute_graph() → BlueprintNodeHandlers 按8分类分派
  → 引擎API调用 → UI反馈（story_choice 节点暂停等待玩家选择 → resume_choice 续跑）
```

**③ MUD 流（双向）**
```
外部: ME/SQLite → export.lua → JSON txt → wanjie/mud_engine/data/（32张表）
内部: mud_editor ↔ ws.metadata["mud_data"]（内部格式 _schema_version=2）
      → save_script 时 mud_export 自动导出到 {id}/mud/ 目录
      → 旧导出格式经 MudImport 自动转换
```

### 1.3 模块划分总览

| 层 | 目录 | 文件数 | 职责 |
|---|---|---|---|
| 全局单例 | scripts/autoload/ | 9 | 生命周期、数据、AI、主题 |
| 编辑器 | scripts/editor/ | 38+4子目录 | 三模式编辑器全部实现 |
| 运行时 | scripts/player/ | 8 | 四引擎 + 蓝图执行 + 体验器 |
| UI | scripts/ui/ | 14 | 大厅、对话框、组件 |
| 数据模型 | resources/data/ | 10 | Resource 数据类 |
| 场景 | scenes/ | 20 tscn | 大厅/编辑器/体验器/组件 |

---

## 2. 核心代码结构详解

### 2.1 Autoload 全局单例（project.godot 注册 8 个）

| 单例 | 文件(行数) | 职责 |
|---|---|---|
| GameManager | game_manager.gd(162) | 用户数据、剧本列表缓存、灵感/创作精力60s恢复 |
| SceneManager | scene_manager.gd(63) | 场景切换、current_script_id 传递 |
| SaveManager | save_manager.gd(291) | **差分存档**（base.json + delta 增量） |
| ScriptDataManager | script_data_manager.gd(610) | 剧本CRUD、拆分存储、旧格式迁移、模板入口 |
| ToastManager | ui/toast_manager.gd(62) | 全局 Toast 通知 |
| LLMClient | llm_client.gd(262) | 多供应商 LLM API（OpenAI/DeepSeek/千问/Moonshot/智谱/自定义） |
| TavernManager | tavern_manager.gd(144) | AI对话酒馆（角色卡/世界书/Prompt组装） |
| ThemeManager | theme_manager.gd(79) | 主题/动画开关 |

⚠️ **重要变更**：Dialogic 与 PhantomCamera 插件 autoload 已移除（commit 2b9ec26，消除 PhantomCameraManager singleton 报错），`editor_plugins.enabled` 为空。addons/ 目录保留但未启用（dialogic/limboai/phantom_camera）。

另有非 autoload 的 autoload 目录文件：`script_templates.gd`(468，class_name ScriptTemplates 静态模板库)、`dragonflame_era_data.gd`(349，龙焰纪元示范数据)。

### 2.2 数据模型（resources/data/，10个 Resource 类）

```
WorldScriptData（剧本容器，顶层）
├── id/name/version/author/description/tags/status/metadata…
├── worldview: WorldviewData        ← 背景故事/时代/时间线/规则/势力/地理
├── event_system: EventSystemData   ← 剧情事件/随机事件/事件链 + blueprint_graphs（蓝图图存储！）
├── economy_system: EconomySystemData ← 货币/资源/市场/交易规则
├── ability_system: AbilitySystemData ← 技能/成长路径/战斗机制/状态效果
├── quest_system: QuestData         ← 任务/任务链
└── combat_system: CombatData       ← 敌人/NPC/预设战斗
其他：SaveData（存档）、UserData（诗墨/界石/灵感/精力）、SkillDataInit（470行技能初始化）
```

**关键设计**：所有蓝图图统一存于 `event_system.blueprint_graphs: Dictionary`（key→graph），纯 JSON 随 events.json 持久化。key 规范（GraphStore）：
- `evt:<event_id>` — 事件图（每事件一图，触发驱动）
- `sys:<name>` — 系统图（global/economy/combat/quest/world/ability/map，各子系统"🎨 蓝图"分支锁定编辑）

### 2.3 剧本存储结构（user://scripts/{id}/）

```
{id}/
├── script.json        ← 主数据（元数据 + metadata["mud_data"] + 拆分索引）
├── data/
│   ├── worldview.json / events.json / economy.json / abilities.json
│   └── quest.json / combat.json   ← 后加入，含旧剧本迁移兼容
├── mud/               ← MUD 导出 txt（save_script 自动触发）
└── assets/            ← 剧本专属资源
```
旧单文件 `{id}.json` 加载时自动迁移为目录格式。

---

## 3. 剧本编辑器体系（scripts/editor/，项目最大子系统）

### 3.1 主控与三模式

`script_editor.gd`(1396行) 是 IDE 式主控制器：
- **三模式**：visual（可视化）/ code（代码）/ mud（数据表），由 `metadata["editor_mode"]` 锁定，顶栏"🔄 切换编辑器"走内容转译（当前编辑器 → WorldScriptData → 目标编辑器）
- **布局**：菜单栏 + 左模块树 + 中央编辑区 + 右概览/详情 + 底部(输出/校验/模板) + 状态栏
- **机制**：编辑器缓存 `_editors`（切换保留状态）、全局 UndoRedo、60s 自动保存、多标签页
- **模块树**：🔷蓝图工作区 / 📋剧本元数据 / 📖世界观 / 📜事件系统(含各事件子项) / 💰经济 / ✨能力 / 📋任务 / ⚔战斗 / 🗺地图 / 🧪测试运行 / 🤖AI创作助手

### 3.2 L1/L2/L3 三层渐进编辑模型

| 层 | 形式 | 面向 | 实现 |
|---|---|---|---|
| L1 | 表单（下拉/输入） | 零基础 | 各 visual_* 表单 + visual_event_l1_form.gd(772) |
| L2 | When-Do 规则卡片 | 初级 | ConditionCompiler 结构化条件（463行双向编译） |
| L3 | 蓝图节点图 | 高级 | visual_event_blueprint.gd(1024) + 统一蓝图工作区 |

三层共享同一 WorldScriptData，切换不丢数据。ConditionCompiler 负责结构化条件 ↔ event_engine 运行时格式双向投影（decompile 失败 raw 透传）。

### 3.3 蓝图系统（核心中的核心，6+组件）

| 组件 | 文件(行数) | 职责 |
|---|---|---|
| BlueprintData | blueprint_data.gd(310) | 图/节点/引脚/连线数据模型、validate_connection、几何计算 |
| BlueprintNodeRegistry | blueprint_node_registry.gd(598) | 8大分类节点注册表（元数据/引脚/参数/数据源），懒加载 |
| BlueprintValidator | blueprint_validator.gd(197) | 参数/引用/连接校验、孤立节点检测（仅 error 中止，warn 放行） |
| BlueprintCodeGen | blueprint_codegen.gd(713) | 沿 exec 流 DFS 编译，8分类 handler 生成真实 GDScript 调用 |
| BlueprintExecutor | blueprint_executor.gd(228) | 运行时执行器（循环栈帧/选择暂停/子图调用栈/防无限循环10000步） |
| BlueprintNodeHandlers | blueprint_node_handlers.gd(791) | 运行时节点处理器，按前缀分派 flow_/eco_/story_/world_/player_/combat_/ability_/quest_ |
| GraphStore | graph_store.gd(67) | 图注册表（evt:/sys: key 规范），编辑器与运行时共用 |
| ConditionCompiler | condition_compiler.gd(463) | L1/L2 结构化条件 ↔ 运行时条件双向编译 |
| ScriptCodeGen | script_codegen.gd(1172) | WorldScriptData ↔ GDScript风格代码双向转译（含 scene_2d/scene_3d 章节） |

**节点8大分类**：流程控制⚙ / 经济交易💰 / 剧情事件📖 / 技能能力✨ / 战斗系统⚔ / 世界势力🌍 / 角色玩家🧑 / 任务系统📋。引脚类型：EXEC/BOOL/INT/FLOAT/STRING/ANY。

**关键运行时机制**：
- 事件带蓝图图 → Executor 驱动；无图回退传统 event_engine 流程
- `story_choice` 节点：暂停执行 → 等玩家选择 → `resume_choice` 续跑
- `flow_sub_graph` 节点：按 key 调用子图（变量隔离、选择暂停向上传播）
- `flow_for_loop`：循环栈帧支持
- 编译产物写入图 `_compiled_code`，与运行时 handler 语义一致

### 3.4 可视化子模块（scripts/editor/visual/，全部继承 VisualModuleBase）

| 模块 | 文件(行数) | 说明 |
|---|---|---|
| visual_module_base.gd | 93 | 基类：_host duck-typed、_ws/_ui/_log/_sync/_dirty/_rebuild_tree、标准布局 |
| visual_event.gd | 769 | 事件模块入口/层切换/事件列表/概览（**已拆分**，组合 _l1_mod + _bp_mod） |
| visual_event_l1_form.gd | 772 | L1 表单（条件/选择/动作编辑） |
| visual_event_blueprint.gd | 1024 | L3 蓝图画布交互（拖拽/连线/缩放/右键菜单/属性面板/50步撤销/搜索/小地图），支持 workspace 模式复用 |
| visual_blueprint_draw.gd | 257 | 纯绘制/几何静态工具 |
| visual_blueprint_workspace.gd | 406 | **统一蓝图编辑器（UE风格）**，模块树顶级"🔷 蓝图工作区"，图列表管理+单画布 |
| visual_system_blueprint.gd | 121 | 各子系统"🎨 蓝图"分支包装（锁定 sys:* key） |
| visual_worldview/economy/ability/quest/combat/map | 37~80 | 各系统模块（标准布局+蓝图分支） |
| visual_test_runner.gd | 111 | 测试运行器 |
| visual_ai_assistant.gd | 346 | AI 辅助创作面板（7个快捷功能：世界观/事件/经济/能力/任务/战斗NPC/事件链） |

### 3.5 IDE 式代码模式（scripts/editor/ide/，20个组件）

**完全复刻 Godot 4.7.1 编辑器**：顶栏三段式、左右 Dock、中央四工作区、底部 badge、状态栏光标定位；快捷键 F5运行/F6验证/Ctrl+S保存。核心：ide_workspace(181) / ide_file_system(565) / ide_inspector(499) / ide_scene_tree(440) / ide_node_panel(395) / ide_script_view(390) / ide_signal_dialog(275) / ide_theme(145，集中配色) 等。

### 3.6 其他编辑器子系统

| 子系统 | 入口 | 规模 |
|---|---|---|
| 代码编辑器 | script_code_editor.gd(1243) | Godot 风格完整 IDE（多标签/查找替换/语法高亮） |
| MUD 编辑器 | mud_editor.gd(765) + mud/(17文件) | 15标签页配置驱动、地图画布、触发器编辑器、导入/导出管道、表搜索过滤 |
| 2D 场景编辑器 | scene_editor_2d.gd(1109) | 类Godot可视化搭建、对齐/分布/锚点、编辑落代码双向转译 |
| 3D 场景编辑器 | scene_editor_3d.gd(1064) | SubViewport 渲染、网格吸附、Vector3 JSON 容错 |
| 校验器 | script_validator.gd(168) | 剧本完整性校验 |

---

## 4. 运行时系统（scripts/player/）

| 组件 | 文件(行数) | 职责 |
|---|---|---|
| ScriptPlayer | script_player.gd(426) | 体验器主控：引擎初始化、打字机效果、选择UI、蓝图/传统双路径 |
| EventEngine | event_engine.gd(255) | 事件触发/选择/因果追踪/冷却 |
| EconomyEngine | economy_engine.gd(84) | 供需定价/买卖/库存 |
| CombatEngine | combat_engine.gd(285) | 回合制战斗（HP/MP/ATK/DEF/速度/元素/状态效果） |
| WorldState | world_state.gd(104) | 游戏时间推进/世界变量/势力状态/活跃效果 |
| BlueprintExecutor | blueprint_executor.gd(228) | 蓝图执行（见 3.3） |
| BlueprintNodeHandlers | blueprint_node_handlers.gd(791) | 节点→引擎调用映射 |
| GraphStore | graph_store.gd(67) | 图注册表 |

**依赖关系**：ScriptPlayer → (四引擎 + Executor)；Executor → Handlers → 四引擎；EventEngine ↔ WorldState（条件求值）。全部 RefCounted，信号解耦。

---

## 5. AI 系统（三层）

| 层 | 组件 | 状态 |
|---|---|---|
| 基础设施 | LLMClient(262)：6供应商（OpenAI/DeepSeek/千问/Moonshot/智谱/自定义OpenAI兼容），HTTP 异步 | ✅ |
| AI对话酒馆 | TavernManager(144)：角色卡/世界书/对话历史/Prompt组装，作为"AI NPC对话引擎"子系统 | ✅ 框架 |
| AI辅助创作 | ai_service.gd(164，多后端抽象含Mock模拟) + ai_prompts.gd(155，7套模板) + visual_ai_assistant.gd(346，面板UI) | ✅ 基础框架 |

AI辅助创作功能：世界观生成/事件编排/经济分析/能力设计/任务生成/战斗NPC/事件链。配置持久化 user://ai_config.json。**当前局限**：AI 输出仅展示在聊天日志，未自动写入剧本数据结构。

---

## 6. 模板系统（ScriptTemplates，468行）

7个模板 = 元数据 + 四子系统 + quest/combat + **预置可执行蓝图图**：
经典RPG冒险⚔️ / 互动小说📖 / 模拟经营🏭 / 回合策略♟️ / 战斗竞技🥊 / 探索解谜🗺️ / 龙焰纪元·世界观蓝图🐉（17节点示范子页蓝图化）。创建剧本时选择即得可运行骨架。

---

## 7. GDD 章节 ↔ 实现状态对照

| GDD章节 | 内容 | 状态 | 说明 |
|---|---|---|---|
| §1 游戏概述 | 定位/USP/受众 | ✅ | 框架落地（大厅/资源模型） |
| §2 核心玩法 | 双循环/资源/心流 | ✅ 基础 | 灵感/精力恢复已实现；社区循环未实现 |
| §3 剧本自定义系统 | 六大子系统数据结构 | ✅ | Resource模型+编辑器全覆盖 |
| §4 剧本运行架构 | 引擎+蓝图执行 | ✅ | 蓝图真正驱动运行（含暂停/子图） |
| §5 存档系统 | 存档架构 | ✅ | 差分存档 base+delta |
| §6 技术架构 | Godot 4.7.1 | ✅ | 已升级，gl_compatibility |
| §7 UI/UX | 大厅/编辑器/体验器 | ✅ | IDE式编辑器完整复刻 |
| §8.1 AI辅助剧本创作 | 生成辅助 | ✅ 基础 | 7功能面板；**结果未自动落数据** |
| §8.2 AI动态内容生成 | 运行时生成 | ⚠️ 部分 | 仅 TavernManager 对话 |
| §8.3 AI平衡性优化 | 数值分析 | ⚠️ 部分 | 仅聊天式分析建议 |
| §8.4 AI对话酒馆 | 角色卡对话 | ✅ 框架 | 未接入剧本运行时NPC |
| §8.5 AI测试与审查 | 自动测试 | ⚠️ 部分 | 有测试运行器模块 |
| §8.6 架构演进规划 | 未来路线 | ⏳ | 规划阶段 |

**明确未完成的功能边界**：
1. 社区分享/发布生态（无限世界池）— 无网络层
2. 付费货币（界石）体系 — 无支付
3. AI 生成结果自动写入剧本数据（当前只读展示）
4. AI 对话酒馆接入剧本运行时 NPC
5. 移动端适配（GDD 远期）
6. 多人联机

---

## 8. 关键依赖关系图

```
                    WorldScriptData（中枢数据模型）
                    ▲        ▲         ▲          ▲
        编辑写入 │   代码转译 │   运行时读取 │   蓝图图存储 │
    ┌───────────┘        │           │       (blueprint_graphs)
visual_*.gd 模块     ScriptCodeGen   ScriptPlayer    GraphStore
    │                    ▲           │               ▲   ▲
    └── _sync_to_code ───┘           └─ BlueprintExecutor ─┘
                                      │        │
                              BlueprintNodeHandlers
                                      │
                    WorldState / Event / Economy / Combat 引擎

script_editor.gd（主控）
    ├── preload 全部 visual 模块（_mod_* 实例，duck-typed RefCounted）
    ├── EditorUIFactory（UI构建）
    ├── ScriptCodeEditorClass（code模式）/ MudEditorClass（mud模式）
    └── ScriptDataManager（持久化）← GameManager（列表缓存）← main_hub（入口）
```

**共享约定**：
- 所有可视化模块继承 VisualModuleBase，经 `_host` duck-typed 访问主编辑器
- 蓝图图只存 `event_system.blueprint_graphs`，跨模块经 GraphStore 读写
- 编辑器与运行时共用 BlueprintData/Registry/GraphStore（编辑态与运行态语义一致）

---

## 9. 工程约束速查（协作 AI 必读）

| 约束 | 说明 |
|---|---|
| duck-typed 类型推断 | 经无类型变量调用方法的返回值**禁用 `:=`**，必须显式标注类型 |
| RefCounted ≠ Node | visual 模块是 RefCounted，不能 add_child/get_viewport，委托 `_host.editor_container` |
| .uid 文件 | 严禁删除；移动/重命名脚本必须同步迁移 .uid |
| JSON 类型 | Godot JSON 反序列化数字默认 float，需 int/float 转换 |
| 类型化数组传参 | Godot 4.7 对未类型化字面量传 Array[String] 参数会运行时校验失败 |
| 对话框 | AcceptDialog 不可靠，用纯代码 Control+遮罩+CenterContainer 模式 |
| 模式锁定 | 编辑器模式由 metadata["editor_mode"] 锁定，切换走转译 |
| MUD 数据独立 | metadata["mud_data"] 与四子系统独立存储，互译需映射 |
| PowerShell | 不支持 `&&`，用 `;` 分隔 |

**验证基线**：
```powershell
cd E:\ZX\QWXM\WJSP\XM1
$out = .\Godot_v4.7.1-stable_win64.exe --headless --path wanjie --import 2>&1 | Out-String
$errs = ($out | Select-String -Pattern "SCRIPT ERROR" -AllMatches).Matches.Count
Write-Output "SCRIPT_ERROR_COUNT=$errs"   # 期望 0
```
另有 22 个 SceneTree 测试（wanjie/temp_scripts/test_*.gd，输出 ALL_TESTS_PASSED），GitHub Actions CI 每次 push 自动运行。

---

## 10. 代码规模统计（2026-08 实测）

| 区域 | 文件数 | 总行数(约) |
|---|---|---|
| autoload | 9 | 2,300 |
| editor（含 ide/mud/visual/panels） | 75 | 24,000 |
| player | 8 | 2,300 |
| ui | 14 | 1,200 |
| resources/data | 10 | 1,400 |
| **合计 GDScript** | **~116** | **~31,000** |

最大单文件：script_code_editor.gd(1243) / script_editor.gd(1396) / script_codegen.gd(1172) / scene_editor_2d.gd(1109) / scene_editor_3d.gd(1064) / visual_event_blueprint.gd(1024)。
