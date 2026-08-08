# wanjie 功能提升研究报告（2026-08，四域并行深度调研）

> 方法：4 路并行子代理（编辑器核心/玩家运行时/数据+AI/大厅+UX）精读核心文件 + 全仓库 grep。未改动代码。目标：给"提升项目所有功能"提供分优先级的路线图。

## 0. 总体结论

**广度已达标**：三模式编辑器 + 15 标签页 MUD + 完整 IDE 布局 + 2D/3D 可视化 + 60+ 蓝图节点 + 事件/经济/战斗引擎 + 差分存档 + 多供应商 AI 客户端——骨架对标商业工具已成型。

**短板在数据闭环与体验深度**：①大厅显示的数据（体验数/进度/最近）**从未被写入**；②玩家体验进度**无法延续**（无继续游戏、蓝图改动不回写存档）；③战斗/对话/探索是**引擎有逻辑、UI 空壳**；④存在 1 个会误退游戏的 bug；⑤安全（API key 明文/提示注入）与架构（巨型控制器/双轨存储）风险。

## 1. P0 — 数据闭环与关键 bug（先修，影响所有功能）

| # | 项 | 证据 | 改动量 |
|---|---|---|---|
| P0-1 | **"关闭菜单"误退游戏 bug**：MenuPanel 的"关闭菜单"按钮实为退出到大厅 | script_player.gd:385-388 | ~5 行 |
| P0-2 | **数据链路断线**：`play_count`/`recent_script_ids`/`progress` 无写入点（或不全）——大厅"体验数/最近体验/进度"永远是空 | game_manager.gd:119-158；script_player.gd:170-360 | ~20 行 |
| P0-3 | **继续游戏入口**：有存档时大厅卡片应"继续"，而非每次 `start_new_game` | scene_manager.gd:58-67；script_player.gd:105 | ~10 行 |
| P0-4 | **蓝图状态回写存档**：蓝图事件获得的物品/金币/变量不写回 current_save，退本 autosave 存的是陈旧快照→**进度丢失** | script_player.gd:365-368 | ~10 行 |

## 2. P1 — 体验补全（中成本，立刻见效）

| # | 项 | 证据 |
|---|---|---|
| P1-1 | **战斗 UI**：战斗引擎 4 信号零连接、attack/flee 无调用方——补战斗面板/敌人条/战斗日志/操作按钮 | combat_engine.gd:7；script_player.gd:93-103 |
| P1-2 | **对话文本显示**：`story_dialog` 节点只写日志，玩家看不到对话 | blueprint_node_handlers.gd:289 |
| P1-3 | **打字机键盘跳过**（Space/Enter）+ 退本"已自动保存"Toast + 进本"消耗灵感"提示 | script_player.gd:58-62,386 |
| P1-4 | 搜索空结果文案区分；轮播指示器按数量动态生成 | main_hub.gd:127-149,242-247 |
| P1-5 | **设置统一持久化**：settings.cfg 与 GameManager 双写、ai/npc_enabled 补写 cfg | settings.gd:100-129 |
| P1-6 | 对话框防重入 + Esc 关闭（setup_dialog / 菜单面板） | main_hub.gd:73-81 |
| P1-7 | 进度回写：退本按 `triggered_events.size()/总事件数` 写 `ws.progress` + `update_script` | script_player.gd:385-388 |
| P1-8 | 战斗日志自动收集（引擎事件 → 主文本/toast） | — |

## 3. P2 — 深度功能（有价值，成本较高）

| # | 项 | 证据 |
|---|---|---|
| P2-1 | **AI 一键应用**：AI 生成 JSON 直接写子系统 + Schema 校验 + 值域清洗（防污染） | ai_service.gd:60-66；visual_ai_assistant.gd |
| P2-2 | **酒馆（TavernManager）补 UI 入口 + 对话落盘**：现无调用方 | tavern_manager.gd:51-96 |
| P2-3 | **存档槽位管理**：删除存档（delete_save 已存在未暴露）、自动档展示 | script_player.gd:441-464 |
| P2-4 | **AI 多轮上下文**：自由对话携带历史（tavern token 预算思路） | visual_ai_assistant.gd:213-217 |
| P2-5 | **2D 编辑器本地撤销**（editor_undo_redo 已框架，scene_editor_2d 空实现）+ 连续拖动合并一步 | editor_undo_redo.gd:81；script_code_editor.gd:704 |
| P2-6 | **编辑菜单补全**：撤销/重做/查找替换接通（当前"编辑"菜单缺失，快捷键体系断裂） | script_editor.gd:735 |
| P2-7 | **校验结果点击跳转**：底部校验面板 error/warning 点击定位到源 | script_editor.gd:723 |
| P2-8 | **多标签页系统接入**：`_setup_tab_container` 已实现未接线（dead-code） | script_editor.gd:1560-1588 |
| P2-9 | 定时自动存档（每 5 分钟）+ 加载存档确认 | save_manager.gd:171-180 |
| P2-10 | AI 输出 Schema 校验 + 单次重试；2D 检查器控件化（SpinBox 代替手输） | — |

## 4. P3 — 架构与安全（长期，降低风险）

| # | 项 | 证据 |
|---|---|---|
| P3-1 | **API key 安全**：明文 `llm_config.ini`/`ai_config.json` → OS 密钥链/混淆 + 权限收紧 | llm_client.gd:86-100 |
| P3-2 | **提示注入防护**：剧本数据拼 prompt 前分隔/过滤；AI 输出应用前 Schema 校验 | ai_prompts.gd:62-98 |
| P3-3 | **数据安全**：Write-Ahead 中途失败无回滚、剧本无回收站/历史版本、base.json 损坏静默退化 | script_data_manager.gd:148-150；save_manager.gd:268-279 |
| P3-4 | **引擎状态单一来源**：三处玩家状态并存（SaveData/combat/economy）→ 统一 world_state | script_player.gd:266-287 |
| P3-5 | **巨型控制器拆分**：script_editor(1614)/script_code_editor(1380)/scene_editor_2d(1207) 行——分批拆模块 | — |
| P3-6 | 双轨存储统一（metadata vs 独立 JSON）、多标签页缓存释放、快捷键三层统一 | script_editor.gd:888,1560；script_code_editor.gd:1257 |
| P3-7 | 战斗/技能字段对齐（buff 结构不匹配、敌人无技能）；子图暂停缺陷修复；story_choice 扩展 >2 选项 | combat_engine.gd:112-113；blueprint_executor.gd:49-54 |

## 5. 建议执行顺序

```
P0（数据闭环+关键 bug，~45 行改动）→ 立即修复，玩家体验闭环成立
  ↓
P1（体验补全，战斗/对话可见 + UX 打磨）→ 一两个迭代内完成
  ↓
P2（深度功能，按需挑选）→ AI 应用/酒馆/撤销/多标签页
  ↓
P3（架构安全，渐进）→ 风险项逐个消除
```

每批交付均过 verify_all（PASS=6）+ 相关测试。P0 为数据正确性基础，建议最先执行。
