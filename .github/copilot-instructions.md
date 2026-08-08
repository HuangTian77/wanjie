# GitHub Copilot 项目指令（与 AGENTS.md 对齐）

> 供 GitHub Copilot（IDE/CLI/Code Review）读取。内容与根 `AGENTS.md` 保持一致，防止冲突；Copilot 也直接消费 AGENTS.md。

## 项目
Godot 4.7.1 游戏剧本编辑器 + 玩家（wanjie，中文 UI）。项目目录 `wanjie/`，引擎 exe 在仓库根（Git LFS）。

## 构建与验证（命令均已实测）
```bash
cd /e/ZX/QWXM/WJSP/XM1
# import 校验（SCRIPT_ERROR=0）
./Godot_v4.7.1-stable_win64.exe --headless --path wanjie --import 2>&1 | grep -c "SCRIPT ERROR"
# 一键全量验证（推荐）：import→27 测试→GdUnit4→gdlint→布局断言
bash wanjie/tools/verify_all.sh
# 静态 lint
gdlint wanjie/scripts wanjie/resources/data wanjie/autoload wanjie/tools
```

## 代码约定
- GDScript：Tab 缩进、行宽 ≤300、无 BOM/行尾空格、遵守 .gdlintrc
- 命名：类 PascalCase、函数/变量 snake_case、常量 UPPER_SNAKE、回调 `_on_xxx`
- 三套 UI 主题不跨用色（暖金 ThemeManager / 深色 IDETheme / 表单暗色），见 docs/UI_GUIDE.md
- 已知坑：禁止全局正则改名；容器内动画用 offset_transform/scale；autoload 在 -s 脚本用 get_node_or_null

## 验收标准（Definition of Done）
- [ ] import 零 SCRIPT ERROR
- [ ] `verify_all.sh` PASS=6 全绿（27 测试 + GdUnit4 6/6 + gdlint 0 + 布局 HARD=0 + 符号地图刷新）
- [ ] 提交信息中文规范 `<类型> <摘要>：① ② ③`
- [ ] 产物不入库（_ui_shots/、_ui_layout_report.txt、wanjie/reports/）
