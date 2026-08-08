# AGENTS.md — wanjie 项目规范（AI 代理与开发者每次会话必读）

> 本文件是项目常驻规范（Reasonix/Codex 等每次会话自动加载，类似 Claude Code 的 CLAUDE.md），配套：`docs/UI_GUIDE.md`（UI 规范）、`docs/DEVELOPMENT_WORKFLOW.md`（工作流）、`docs/AI_TOOLS_RESEARCH.md`（AI 工具机制调研）、记忆 `wanjie-ui-architecture`（详细速查）。

## 0. 每次会话启动协议（每次对话自动执行，勿跳过）

1. **上下文对齐（30 秒）**：记忆速查（`wanjie-ui-architecture`）已自动加载 → 定位符号先查 `docs/REPO_MAP.md`（verify 自动刷新，125 文件类/信号/函数+行号）→ 复杂/长期任务 run_skill(`ai-tools-patterns`) 对齐业界设计模式
2. **任务路由**（选一个入口，不要裸做）：
   - 任何开发任务 → run_skill(`wanjie-workflow`)：Plan→Implement→Verify→Ship 生命周期
   - UI 相关任务 → 额外 run_skill(`wanjie-ui-audit`)：审计清单（布局/主题/焦点/动效/性能）+ 验证
   - 复杂/长期/架构设计 → run_skill(`ai-tools-patterns`)：六条设计逻辑（上下文资产/软硬双轨/渐进信任/可恢复/文件即配置/DoD）
3. **强制约束**：改动后必须 `bash wanjie/tools/verify_all.sh` 全绿（PASS=6）才继续/提交；pre-commit 自动门禁（gdlint+import）；提交规范见 §6；交付前勾选 §6.5 DoD
4. **上下文纪律**：优先 REPO_MAP + grep 定向定位；大文件（visual_event.gd 等）分段读；检索用子代理隔离（explore/task）；autoload 在 -s 脚本用 `get_node_or_null("/root/X")`

## 1. 项目概况

- **Godot 4.7.1** 游戏剧本编辑器 + 玩家（wanjie，中文 UI），Windows 开发
- 引擎：`E:\ZX\QWXM\WJSP\XM1\Godot_v4.7.1-stable_win64.exe`（**已入库 Git LFS**）
- 项目目录：`wanjie/`（project.godot 在此）
- 三套 UI 主题：大厅/体验器（暖金 ThemeManager）、编辑器（深色 IDETheme）、编辑器表单（editor_ui_factory 暗色）——**不跨主题用色**，细节见 docs/UI_GUIDE.md

## 2. 目录速览

```
wanjie/scripts/autoload/   # GameManager/SceneManager/ScriptDataManager/ThemeManager/ToastManager...
wanjie/scripts/editor/     # script_editor + visual/（蓝图可视化）+ mud/（MUD 编辑器）+ ide/（IDE 组件）
wanjie/scripts/player/     # script_player + event/economy/combat 引擎 + blueprint_executor/GraphStore
wanjie/scripts/ui/         # main_hub/settings/setup 对话框 + components/（script_card/toast 等）
wanjie/resources/data/     # 数据类（WorldScriptData/EventSystemData/AbilityData...）
wanjie/scenes/             # main/editor/player/settings/components
wanjie/temp_scripts/       # 自研 SceneTree 测试（test_*.gd）+ 工具
wanjie/tools/              # UI 工具链（截图/布局断言/走查/动效/分析）
wanjie/test/               # GdUnit4 测试套件（*_test.gd）
wanjie/addons/             # 插件（gdUnit4 启用；dialogic/phantom_camera 禁用未用）
docs/                      # UI_GUIDE.md / DEVELOPMENT_WORKFLOW.md
```

## 3. 验证命令（改完必跑，顺序执行）

```bash
# ① import 零脚本错误
cd /e/ZX/QWXM/WJSP/XM1 && ./Godot_v4.7.1-stable_win64.exe --headless --path wanjie --import 2>&1 | grep -c "SCRIPT ERROR"
# ② 自研测试（27 个，判据 ALL_TESTS_PASSED）
cd wanjie && for f in temp_scripts/test_*.gd; do timeout 90 ../Godot_v4.7.1-stable_win64.exe --headless --path . -s "$f" 2>&1 | grep -q ALL_TESTS_PASSED && echo PASS || echo FAIL; done
# ③ GdUnit4（6 用例，Exit code 0）
../Godot_v4.7.1-stable_win64.exe --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --add res://test --ignoreHeadlessMode
# ④ gdlint 静态 lint（产品代码零告警）
cd /e/ZX/QWXM/WJSP/XM1 && gdlint wanjie/scripts wanjie/resources/data wanjie/autoload wanjie/tools
# ⑤ 布局断言（HARD=0）
./Godot_v4.7.1-stable_win64.exe --headless --path wanjie -s tools/ui_layout_check.gd
# ⚡ 一键跑 ①~⑤：
bash wanjie/tools/verify_all.sh
```

## 4. 代码规范

- **GDScript 缩进用 Tab**；行宽 ≤300（.gdlintrc 已配）；行尾无空格；无 UTF-8 BOM
- 遵守 gdlint（禁用风格类规则见 .gdlintrc）；**gdformat 勿用**（issue #424 会生成 4.7 拒绝的缩进）
- 命名：类 PascalCase、函数/变量 snake_case、常量 UPPER_SNAKE、回调 `_on_xxx`
- unused 参数加 `_` 前缀；改签名**只精确改签名行**，禁止全局正则改名（会误伤字典键/注释）
- 中文注释；CRLF 文件用 edit_file（LF 串可匹配）/ python 写 `newline='\n'`

## 5. 工作流（Codex 式 Plan→Implement→Verify→Ship）

1. **Plan**：todo_write 建任务清单（level 0 phase + level 1 子步骤，仅一个 in_progress）
2. **Implement**：小步修改，每步可回滚（git 保证）
3. **Verify**：改完跑第 3 节验证（至少 import + 相关测试）；真实窗口类工具（截图/走查/动效）需要本机跑
4. **Review**：大改动用 review 工具审查 diff
5. **Ship**：complete_step 签收（带证据）→ `git commit`（规范见下）→ 推送（分支保护需临时放宽：`gh api -X PUT .../protection --input /tmp/loose.json`，推完恢复）

## 6. 提交规范

- 提交信息中文，格式：`<类型> <摘要>：<要点 ① ② ③>`（类型：修复/新增/优化/重构/文档/CI）
- 单次提交聚焦一件事；产物不入库（_ui_shots/、_ui_layout_report.txt、wanjie/reports/ 已忽略）
- 推送 master 需：临时放宽分支保护（CI+1 批准+admin）→ push → 恢复（模板 .githooks/gh-loose.json / gh-restore.json）

## 6.5 Definition of Done（验收标准，交付前逐项勾选）

- [ ] `bash wanjie/tools/verify_all.sh` 输出 PASS=6 全绿（import 0 / 27 测试 / GdUnit4 6/6 / gdlint 0 / 布局 HARD=0 / 符号地图刷新）
- [ ] 涉及 UI 视觉/交互：真实窗口截图或走查验证（ui_screenshot / ui_walkthrough / ui_motion_capture）
- [ ] pre-commit 钩子通过（gdlint + import）
- [ ] 提交信息符合 §6 规范；无产物入库
- [ ] 影响文档时同步更新（docs/UI_GUIDE.md / docs/DEVELOPMENT_WORKFLOW.md / AGENTS.md）

## 7. 已知坑（详见 docs/UI_GUIDE.md §4）

- `top_level` 背景不随父 resize；容器内 position 动画无效（用 offset_transform/scale）
- GDScript 类型推断触发 "Cyclic reference" → untyped；autoload 标识符 -s 脚本不可用 → get_node_or_null
- gdlint/gdformat 与 Python 3.14 / Godot 4.7 的兼容坑；GdUnit4 headless 需 --ignoreHeadlessMode
