# 巨型控制器拆分规划（P3-5）

> 背景：`script_editor.gd`(1614+ 行)、`script_code_editor.gd`(1380+)、`scene_editor_2d.gd`(1200+)、`visual_event.gd`(2800+) 为巨型控制器，维护/测试成本高。
> 原则：**小步拆分、每次可回归（verify_all PASS=6）、不冒险**——单文件拆分是数日工程，本轮仅出规划，不执行。

## 拆分策略（按风险递增）

### 1. script_editor.gd（模块树+模式+校验+面板工厂，1614 行）— 建议先行
- 面板工厂（`_create_*_editor` 约 40 个函数）→ `scripts/editor/panel_factory.gd`（纯工厂，静态函数）
- 模块树构建（`_build_module_tree` + `_add_leaf`）→ `scripts/editor/module_tree_builder.gd`
- 校验（`_run_validation` + 报告面板）→ `scripts/editor/script_validator.gd`（已有 ScriptValidator 可搬）
- 收益：script_editor 降到 ~800 行；工厂/树可单测

### 2. scene_editor_2d.gd（1207 行）— 中风险
- 画布绘制（`_draw` 相关 300 行）→ `scripts/editor/scene_editor_2d_draw.gd`（静态 draw 助手）
- 交互（拖拽/选择/多选）→ `scripts/editor/scene_editor_2d_interact.gd`
- 检查器（属性 Tree）→ `scripts/editor/scene_editor_2d_inspector.gd`

### 3. visual_event.gd（2800 行）— 高风险，最后
- 内部跨函数共享状态多（_host/_bp_*），拆分易破坏隐式依赖
- 仅拆分纯函数段（布局计算/JSON 序列化助手），交互逻辑不动

### 4. script_code_editor.gd（1380 行）— 中风险
- 历史栈/查找/校验面板拆分

## 拆分验收标准（每步）
1. 功能零变化（import + 27 测试 + GdUnit4 全绿）
2. gdlint 零告警；布局断言 HARD=0
3. 无全局正则改名（只精确搬移函数体）
4. 每次拆分一个文件、一个提交

## 本轮已完成的相关改进（降低未来拆分风险）
- P2-5：2D 撤销栈独立实现（_save_undo_state/_undo/_redo）
- P2-8：多标签页接入（子系统面板生命周期更清晰）
- P3-6：标签关闭释放 _editors 缓存（面板引用管理规范化）
