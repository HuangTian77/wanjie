# CLAUDE.md — Claude Code 项目规范（经 @AGENTS.md 与其他代理共享指令）

> 本文件供 Claude Code 读取。单一事实源是 `AGENTS.md`（OpenAI Codex / Cursor / Copilot / Devin / Gemini CLI / Aider 等也读它），此处通过 @imports 引用，并追加 Claude Code 专属约定。

@AGENTS.md

## Claude Code 专属约定

### 工作流（Claude Code 环境）
- 改代码前先读 `AGENTS.md` 与 `docs/UI_GUIDE.md`（UI 规范）；涉及任务执行遵循 `wanjie-workflow` 模式（Plan→Implement→Verify→Ship）
- **Verify 循环**：每次改动后跑 `bash wanjie/tools/verify_all.sh`（import→27 测试→GdUnit4→gdlint→布局断言），**循环到全绿再继续**，不带着失败推进
- UI 视觉/交互改动需真实窗口验证：`./Godot_v4.7.1-stable_win64.exe --path wanjie -s tools/ui_screenshot.gd <scene>` 等（headless 截不了图）
- 提交前 pre-commit 钩子会自动跑 gdlint + import；被拒先修再提交

### 类型与语法纪律（GDScript 4.7）
- 禁止全局正则改名（会误伤字典键/注释）；unused 参数只精确改签名行加 `_`
- `:=` 对 Variant 返回会触发警告 → 显式类型；autoload 标识符在 `-s` 脚本不可用 → `get_node_or_null("/root/X")`
- 容器内动画用 `offset_transform_*`（4.7 新特性）或 scale/modulate，禁止 position 动画

### 上下文管理
- 本项目文件多（~150 脚本），优先用 grep/explore 定向搜索，避免整目录通读
- 大文件（visual_event.gd 等）分段读取；改前先看目标函数上下文
- 记忆库（memory）每会话自动加载项目速查；CLAUDE.md 在 /compact 后自动重注入

### 提交与推送
- 中文提交信息 `<类型> <摘要>：① ② ③`；单次聚焦
- 推送 master 需临时放宽分支保护：`gh api -X PUT repos/HuangTian77/wanjie/branches/master/protection --input .githooks/gh-loose.json` → push → 恢复（`--input .githooks/gh-restore.json`）
