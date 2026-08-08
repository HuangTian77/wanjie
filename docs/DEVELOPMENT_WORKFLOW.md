# 开发工作流指南（wanjie）

> 面向 AI 代理与开发者的完整工作流。快速入口：`AGENTS.md`（项目规范）、`docs/UI_GUIDE.md`（UI 规范）、`wanjie/tools/verify_all.sh`（一键验证）。

## 1. 任务生命周期（Codex 式）

```
Plan → Implement → Verify（循环到全过）→ Review → Ship
```

| 阶段 | 动作 | 产出 |
|---|---|---|
| Plan | 任务清单（todo_write，phase+子步骤）、explore 摸底、ask 决策 | 任务列表 |
| Implement | 小步修改、单点聚焦、可回滚 | diff |
| Verify | `verify_all.sh` 五道验证循环到全过；UI 类补真实窗口检查 | 验证报告 |
| Review | 大改动 review/security_review 审查 diff | 审查结论 |
| Ship | complete_step 签收 → 提交（pre-commit 自动检查）→ 推送（临时放宽保护） | 提交 + 远程 |

## 2. 验证体系（5 层防线）

| 层 | 工具 | 覆盖 | 位置 |
|---|---|---|---|
| ① import | Godot --import | 全脚本编译 | CI + verify_all |
| ② 单元/集成 | 27 自研 SceneTree 测试 | 核心逻辑回归 | CI + verify_all |
| ③ 框架测试 | GdUnit4 v6.2.0（6 用例） | 蓝图运行时等 | CI + verify_all |
| ④ 静态 lint | gdlint 4.5.0 | 代码质量/风格 | CI + pre-commit + verify_all |
| ⑤ 布局断言 | ui_layout_check.gd | 越界/重叠/响应式 | CI + verify_all |
| 视觉/交互/动效 | ui_screenshot/walkthrough/motion_capture | 真实窗口验证 | 本地 |

一键：`bash wanjie/tools/verify_all.sh`（PASS=6 全绿退出 0，含符号地图刷新）。

## 3. CI（GitHub Actions，master 推送自动跑）

1. LFS 完整性校验（引擎 exe 在 LFS）
2. import 校验（SCRIPT_ERROR=0）
3. 全部 test_*.gd（ALL_TESTS_PASSED）
4. UI 布局断言（LAYOUT_HARD=0）
5. gdlint（产品代码零告警）
6. GdUnit4（Exit code 0）
7. 主场景冒烟（10 帧无错误）

分支保护：master 需要 CI 通过 + 1 批准 + admin 强制。直接推送需临时放宽（`gh api -X PUT repos/HuangTian77/wanjie/branches/master/protection --input /tmp/loose.json`）→ 推完恢复（`--input /tmp/restore.json`）。

## 4. 提交规范

- 中文信息：`<类型> <摘要>：要点① ② ③`（类型：修复/新增/优化/重构/文档/CI）
- 单次提交聚焦一件事；提交前 pre-commit 自动跑 gdlint + import（失败阻止）
- 新克隆需执行 `git config core.hooksPath .githooks` 启用钩子
- 产物不入库：`_ui_shots/`、`_ui_layout_report.txt`、`wanjie/reports/`（已 gitignore）；`_ui_baseline/`（视觉回归基准）**入库**

## 5. 回滚与故障排查

- 测试失败先 `git stash` 可疑文件 → 跑相关测试定位基线 → 精准重做
- 类型/解析错误定位：先跑 `--import` 拿错误行；gdlint 报错用 `.gdlintrc` 配置区分"真实问题"与"风格规则"
- GUI 编辑器报错（headless 不显示）：临时 `treat_warnings_as_errors` + `compile_all.gd` 强制编译全脚本
- 网络波动：推送/下载失败重试；GitHub 直连不稳时用 `gh api`（zipball/保护操作）

## 6. 常用入口速查

```bash
# 一键验证
bash wanjie/tools/verify_all.sh
# 真实窗口 UI 验证
./Godot_v4.7.1-stable_win64.exe --path wanjie -s tools/ui_walkthrough.gd      # 交互走查 13 步
./Godot_v4.7.1-stable_win64.exe --path wanjie -s tools/ui_screenshot.gd main_hub
python wanjie/tools/ui_analyze.py --check _ui_baseline _ui_shots               # 视觉回归
# 静态检查
gdlint wanjie/scripts wanjie/resources/data wanjie/autoload wanjie/tools
```
