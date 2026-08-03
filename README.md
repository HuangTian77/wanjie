# 万界诗篇（Poems of Ten Thousand Worlds）

> **定位**：支持玩家自定义世界剧本的沙盒式游戏体验平台（游戏编辑器 + 游玩器一体化）
> **引擎**：Godot 4.7.1（gl_compatibility） | **语言**：GDScript | **仓库**：Git + Git LFS

玩家既是"造物主"（创造世界剧本），也是"旅者"（体验世界剧本）。类似 Roblox 的定位，但聚焦于**规则与叙事**——零基础用户也能创建并运行复杂游戏/剧本作品。

## ✨ 核心特性

- **三模式剧本编辑器**：可视化表单（L1）/ 规则卡片（L2）/ 蓝图节点图（L3）三模式共享同一数据源，支持自由切换
- **统一蓝图工作区（UE 风格）**：所有游戏系统（事件/经济/能力/战斗/世界/玩家/任务）共用一个蓝图编辑器，节点连接驱动一切，支持子蓝图调用
- **蓝图运行时**：游戏体验由蓝图真正驱动（BlueprintExecutor），事件图/系统图可执行、可暂停选择、可子图调用
- **游戏类型模板**：内置 6 种游戏类型模板（经典RPG/互动小说/模拟经营/回合策略/战斗竞技/探索解谜），选模板即得可运行骨架
- **2D/3D 场景编辑器**：类 Godot 编辑器的可视化场景搭建，编辑结果可双向转译为代码
- **MUD 数据表编辑器**：完整复刻独立 MUDEditor（28 内部表 / 33 导出 txt / 15 标签页 / 地图画布 / 触发器编辑器）
- **AI 辅助创作**：LLM 多供应商接入（OpenAI/DeepSeek/千问/Moonshot/智谱）+ 世界观/事件/经济/能力生成
- **AI 对话酒馆**：角色卡 + 世界书 + Prompt 组装（TavernManager）
- **差分存档**：base.json + delta 增量存储

## 📁 目录结构

```
├── wanjie/                  ← Godot 4.7.1 客户端主项目
│   ├── project.godot        ← 项目配置（Autoload/渲染/输入）
│   ├── scripts/
│   │   ├── autoload/        ← 全局单例（GameManager/ScriptDataManager/LLMClient 等）
│   │   ├── editor/          ← 编辑器系统（visual 蓝图/IDE 组件/MUD 数据表编辑器/2D3D 场景）
│   │   └── player/          ← 运行时引擎（BlueprintExecutor/Event/Economy/Combat/WorldState）
│   ├── resources/data/      ← 10 个 Resource 数据模型类
│   ├── scenes/              ← 大厅/编辑器/体验器/组件场景
│   └── mud_engine/data/     ← MUD 数据表（33 个 txt 导出）
├── ME/                      ← 独立 MUD 编辑器（MUDEditor.exe, Lua 5.1 + luvit + MFC）
├── GDD_万界诗篇_游戏开发方案.md
└── PROJECT_DOCUMENTATION.md ← 项目完整说明文档
```

## 🚀 快速开始

### 克隆并运行

```bash
# 1. 克隆（含 LFS 大文件需要 git-lfs, 见下方说明）
git clone https://github.com/HuangTian77/wanjie.git
cd wanjie

# 2. 拉取 LFS 大文件（引擎 exe + ME 二进制, 约 192MB）
git lfs pull

# 3. 运行项目（Windows）
Godot_v4.7.1-stable_win64.exe --path wanjie
```

### Git LFS 说明

本仓库用 **Git LFS** 管理大文件（Godot 引擎 exe 178MB + ME 编辑器二进制 23MB，共 33 个 LFS 对象）。需要先安装：

- **Windows**：`winget install GitHub.cli` 或从 [git-lfs.github.com](https://git-lfs.github.com) 下载安装，然后 `git lfs install`
- 克隆后务必执行 `git lfs pull`，否则引擎/ME 二进制只是指针文件无法运行

> 不想要引擎 exe 的话，可从 [Godot 官网](https://godotengine.org/download) 下载 4.7.1 stable win64，放仓库根目录即可（.gitignore 已忽略大小写不敏感的同名文件，见配置）。

## 🧪 自动化测试（22 个）

所有测试为 `extends SceneTree` 脚本，位于 `wanjie/temp_scripts/test_*.gd`，headless 运行：

```bash
# Windows PowerShell
cd wanjie
$fail = 0
Get-ChildItem temp_scripts/test_*.gd | ForEach-Object {
  $out = ..\Godot_v4.7.1-stable_win64.exe --headless --path . -s $_.FullName 2>&1 | Out-String
  if ($out -match "ALL_TESTS_PASSED") { Write-Host "PASS $($_.Name)" } else { Write-Host "FAIL $($_.Name)"; $fail++ }
}
exit $fail
```

**覆盖范围**：蓝图运行时（事件流/子图/暂停恢复/编译覆盖/蓝图工作区）、模板系统、场景编辑器与场景代码转译、MUD 全流程与 schema 一致性、UserData 持久化、表单撤销、差分存档、执行器增强、三模式切换、AI 助手。

每次 push 到 GitHub 会由 **GitHub Actions** 自动运行全部测试（见 `.github/workflows/ci.yml`）。

## 📝 开发指南

- **编辑器三模式**：创建剧本时锁定 `metadata.editor_mode`（visual/code/mud），切换走数据转译
- **蓝图数据**：图存 `WorldScriptData.event_system.blueprint_graphs`（`evt:` 事件图 / `sys:` 系统图 key），纯 JSON 随剧本持久化
- **约束**：duck-typed 返回值不能用 `:=`；RefCounted 不能直接调 Node 方法（委托宿主）；`.uid` 文件严禁删除（移动脚本需同步迁移）
- **测试基准**：`--headless --import` 输出 `SCRIPT_ERROR_COUNT=0` + 22/22 测试 PASS

## 📄 文档

- `PROJECT_DOCUMENTATION.md` — 项目完整说明（架构/模块/API/深度完善记录 v1.1）
- `GDD_万界诗篇_游戏开发方案.md` — 游戏设计文档
- `可视化编辑器深度研究与设计方案.md` — 可视化编辑器设计

## 📜 License

保留所有权利（Copyright © 2026）。如需开源许可请与作者联系。
