# wanjie UI 指南（Godot 4.7）

> 项目 UI 规范速查（memory `wanjie-ui-architecture` 的版本化持久版）。改 UI 前先读；改完跑文末验证命令集。

## 1. 三套主题体系（勿跨用色源）

| 界面 | 色源 | 主色 | 入口 |
|---|---|---|---|
| 主大厅/体验器（暖金） | `scripts/autoload/theme_manager.gd`（ThemeManager） | `C_ACCENT` 金 `(0.769,0.588,0.353)`、`C_BG_PRIMARY` 米白 `(0.961,0.925,0.843)`、`C_TEXT_PRIMARY` 深棕 | `scenes/main/main_hub.tscn`、`scenes/player/script_player.tscn` |
| 编辑器（深色 IDE） | `scripts/editor/ide/ide_theme.gd`（IDETheme） | `C_BG_BASE #171b21`、`C_BG_TOOL #21262e`、`C_BG_HIGHLIGHT #2b3341`、`C_TEXT #cdcfd2`、`C_ACCENT` 蓝 `#478cbf` | `scenes/editor/script_editor.tscn` |
| 编辑器表单（旧 visual 模块） | `scripts/editor/editor_ui_factory.gd` | 暗色系 `(0.12,0.13,0.16)` 灰蓝（与 IDETheme 同族） | visual 模块（visual_event_editor 等） |

- 全局字体/字号：`resources/themes/main_theme.tres`（编辑器 `_build_editor_theme` 逐控件覆盖，字号与 main_theme 对齐 15px）
- 组件场景：`scenes/components/`（script_card / recent_card / modal_overlay / section_header / empty_state / toast_item）

## 2. 语义色约定

### 2.1 可视化编辑器三档模式（EditorMode）
- 单例：`scripts/autoload/editor_mode.gd`（autoload 名 `EditorMode`），模式持久化 `user://editor_mode.cfg`
- 三档：**SIMPLE=0 简易**（🌱 零基础，只显示核心节点/字段，隐藏调试工具）/ **DETAILED=1 详细**（⚙ 标准，默认）/ **EXHAUSTIVE=2 详尽**（🧠 全部功能 + 调试信息）
- 切换入口：编辑器顶栏 `EditModeOpt` 下拉 / 设置页「编辑器模式」/ 快捷键 `Ctrl+1/2/3` / F1 帮助
- 分级机制：`blueprint_node_registry.gd` 节点 `min_mode`（core=简易可见 / advanced=详细 / expert=仅详尽，31 个 expert 节点）；表单区块按 `EditorMode.is_visible()` 过滤
- 简易模式：隐藏高级节点菜单项、图重命名/删除、+Print、自动布局、迷你地图、事件复制按钮、前置条件/触发条件区块；蓝图隐藏左图列表（顶部中文图名下拉替代）；模块树进阶子系统灰化；L1 新手引导卡片
- 详尽模式：节点 ID 角标/执行顺序圈数字/右下角缩放坐标指示条、参数 label 附原始 key、参数 JSON 只读视图、右键「图数据 JSON」、编译详细报告
- 模式切换：重建当前面板（清 `_editors` 缓存）并淡入动画，画布缩放/偏移经 `EditorMode.bp_view_state` 跨重建保留

### 2.1b 三模式功能总览（入口/层级）
| 维度 | 简易 🌱 | 详细 ⚙ | 详尽 🧠 |
|---|---|---|---|
| 适用人群 | 零基础新手 | 有经验开发者 | 高级开发者 |
| 默认入口 | 首次使用弹窗选择/顶栏下拉 | 默认 | 顶栏下拉/设置页 |
| 节点数量 | 11 核心 | 80+ 全部 | 80+ 全部+31 expert |
| 表单字段 | 核心区块 | 完整区块 | 完整+原始key |
| 调试叠加 | 无 | 无 | 执行顺序/ID/指示条 |
| 右键菜单 | 简版 | 完整 | 完整+调试工具 |
| 快捷键 | Ctrl+S/F5 | 全部 | 全部+书签/网格/叠加 |
| 引导 | 新手卡片/FAQ/进度条 | 无 | 无 |
| 性能 | 最优 | 标准 | 重绘节流已优化 |

### 2.2 三模式完成度清单（190 项验收，P1-P190）
| 领域 | 已交付（P1-P100） |
|---|---|
| 框架 | EditorMode 单例/三档持久化/顶栏下拉/底部切换条/设置页/快捷键 Ctrl+1/2/3+F1/状态栏常驻/首次模式选择弹窗 |
| 分级 | 注册表 11 core+31 expert/表单区块/工具栏/菜单/统计面板/简易折叠子系统/简易灰化 |
| UE 蓝图 | 圆角节点/引脚hover/分类色/迷你地图/搜索定位黄框/连线选中删除/快速节点搜索/分组/对齐/模板/注释框把手/书签/网格切换/调试叠加/执行顺序/ID角标/分类图标 |
| 简易体验 | 新手引导卡片/FAQ/中文图名/大按钮/术语直白/简版统计/编译轻提示 |
| 详尽调试 | 参数key+JSON视图+实时校验/图数据JSON+导出/图统计/编译报告/全局搜索/撤销栈/悬停节点/导出PNG/操作反馈 |
| 状态保持 | 切换前自动保存/画布视图保持/当前图保持/模块树选中保持/切换统计 |
| 高级蓝图（P100+） | 最近使用/全屏/一键导出/节点断点/入出度/注释联动/健康检查/性能压测/图过滤/引脚类型悬停/节点排序/节点树/图属性/进度条/悬停描述/串联/对齐参考线/代码预览/全图概览/收藏夹管理/图标签/节点宽度/发布检查单 |
| 测试文档 | test_editor_mode 25 项断言/UI_GUIDE 三模式说明/快捷键列表/对比表 |
- 错误 `C_RED`/`C_ERROR`、成功 `C_GREEN`/`C_SUCCESS`、警告 `C_YELLOW`/`C_WARNING`、信息 `C_ACCENT`（蓝）
- 同语义同色，不在局部硬编码新色值；StyleBoxFlat 不每次新建（缓存复用，尤其 toast/轮播指示器）

## 3. 交互与可访问性

- 焦点链完整：面板打开焦点进内容区、关闭后返回触发者；模态（modal_overlay）捕获焦点；Esc 关闭
- 深色主题下 Tree/ItemList 必须设 `selected_color`/`selection_color`（否则选中行不可见/反白）
- hover 至少 2 态（normal/hover），禁用态可辨
- 动效 150-300ms，`tween.set_ease(EASE_OUT)` + `TRANS_CUBE`；新输入打断旧 tween（`kill()`）

## 4. Godot UI 坑（已踩，勿重犯）

1. `top_level=true` 的 ColorRect 不随父容器 resize → 用组件 `_draw()` 自绘背景
2. 容器（HBox/VBox/Grid）内子控件 `position`/`offset` 动画无效（布局覆盖）→ 用 `scale`/`modulate`
3. `anchors_preset` + offset 组合易越界（参考 CarouselNext bug：锚 0.5 + offset(30,70) 底边出容器）→ 对称检查
4. GDScript 显式类型推断可触发 GUI "Cannot infer/Cyclic reference" → 用 untyped `var x =`
5. `ctrl is Window/Popup` 类型检查编译报错（Window 非 Control 子类）→ 删掉或改走父链
6. CRLF 文件：edit_file 用 LF 串可匹配；python 写文件 `newline='\n'`
7. `min()`/`max()` 返回 Variant，`:=` 推断会触发警告 → 显式 `var x: float = min(...)`

## 5. 验证命令集（改完必跑）

```bash
# ① import 零错误
cd /e/ZX/QWXM/WJSP/XM1 && ./Godot_v4.7.1-stable_win64.exe --headless --path wanjie --import 2>&1 | grep -c "SCRIPT ERROR"
# ② 全量测试（27 个，PASS 判据 ALL_TESTS_PASSED）
cd wanjie && for f in temp_scripts/test_*.gd; do timeout 90 ../Godot_v4.7.1-stable_win64.exe --headless --path . -s "$f" 2>&1 | grep -q ALL_TESTS_PASSED && echo PASS || echo FAIL; done
# ③ UI 布局断言（10 场景越界/重叠/零尺寸，HARD>0 退出码 1）
./Godot_v4.7.1-stable_win64.exe --headless --path wanjie -s tools/ui_layout_check.gd
# ④ 全脚本零警告（treat_warnings_as_errors 临时开启，编译 150 脚本后恢复）
# ⑤ 视觉确认（真实窗口，headless dummy 截不了图）
./Godot_v4.7.1-stable_win64.exe --path wanjie -s tools/ui_screenshot.gd main_hub
python tools/ui_analyze.py _ui_shots/main_hub.png
```

CI（`.github/workflows/ci.yml`）已含：import 校验、全部测试、**UI 布局断言**、主场景冒烟。

## 6. 当前基线

- 27/27 测试 PASS、import/编辑器加载/主场景零错误零警告
- 布局断言 10 场景 HARD=0 WARN=0
- PhantomCamera/Dialogic 插件已禁用（autoload 移除，未使用；需要时重新启用）

## 7. Godot 4.7 新特性（调研 2026-08）

- **`Control.offset_transform_*`**（官方重磅 UI 特性）：`offset_transform_enabled/offset/rotation/scale` 让 Control 平移/旋转/缩放**不被容器布局覆盖**（类似 CSS transform，纯视觉）→ 容器内动画优先用这个，其次 scale/modulate；**不要再尝试 position 动画**（布局会覆盖）
- **PopupMenu 搜索栏**：长菜单项可用（官方 PR #11423）
- **Tree 拖放**：新 drop 位置指示器
- 4.7 无主题系统级变更，现有三套主题工作流不受影响

## 8. 工具生态调研结论（2026-08）

| 工具 | 状态 | 结论 |
|---|---|---|
| gdtoolkit（gdlint/gdformat）4.5.0 | pip 可装、Windows headless 可跑 | ⚠️ gdformat 对嵌套多行 lambda 输出 4.7 拒绝的缩进（issue #424）；gdlint 跳过 static func（#425）；Python 3.14 无官方背书 |
| GdUnit4 v6.2.1 | 官方兼容 Godot 4.7/4.7.1 | 断言库/Scene Runner/JUnit+HTML 报告/GitHub Action，无覆盖率 |
| GUT 9.7.1 | 对应 4.7.x | 老牌稳定，无覆盖率 |
| 视觉回归 | 生态无成熟工具 | 自建截图+pixel diff 是主流（本项目 ui_analyze.py 方向正确） |
| GDScript 覆盖率 | 无成熟方案 | C# 生态才有（GoDotTest+coverlet） |
