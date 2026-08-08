# 发布指南（wanjie 万界诗篇）

> 将项目导出为可分发的 Windows 应用。所有命令在本机（Windows + Godot 4.7.1）验证通过。

## 0. 当前功能概览（2026-08，S1-S15 交付）

**创作（编辑器）**：三模式（可视化/代码/MUD）+ 蓝图工作区（60+ 节点/多图/子图/缩放快捷键）+ 2D/3D 场景编辑器（拖拽/撤销/复制粘贴快捷键/对齐）+ 模板系统（6 游戏类型）+ 剧本统计 + 校验跳转/报告导出 + 查找替换 + 多标签页 + 事件复制删除 + 通用列表复制 + 封面/克隆/发布确认/导出分享（内嵌封面 .json）

**游玩（体验器）**：事件驱动剧情（传统+蓝图双轨）+ 经济/战斗引擎（战斗 UI/自动攻击/奖励/技能 MP/状态效果）+ 商店（购买/出售）+ 休息系统 + 酒馆 AI 对话 + 存档系统（继续游戏/自动存档/多槽位/回收站）+ HUD（金币/物品/角色/时钟）+ 评分 + 背包 + 操作帮助

**社区（本地闭环）**：发布（确认对话框+published 状态）→ 市场标签页 → 收藏 → 分享文件导入导出 + 成就系统（解锁/查看）+ 个人统计

**系统**：设置（全屏/字号/动效/文本速度/AI/自动保存间隔）+ 首启引导 + 操作帮助 + 版本 1.2.0 + 导出构建（wanjie.exe）

## 1. 前置条件

- Godot 4.7.1 导出模板已安装：`%APPDATA%\Godot\export_templates\4.7.1.stable\`
- 引擎：`Godot_v4.7.1-stable_win64.exe`（仓库根，Git LFS）

## 2. 导出（已验证）

```bash
cd E:\ZX\QWXM\WJSP\XM1
.\Godot_v4.7.1-stable_win64.exe --headless --path wanjie --export-release "Windows Desktop" "E:\ZX\QWXM\WJSP\XM1\build\wanjie.exe"
```

产物：`build/wanjie.exe`（约 125MB，含资源内嵌 PCK）。

## 3. 发布前检查清单（DoD）

- [ ] `bash wanjie/tools/verify_all.sh` PASS=6 全绿
- [ ] 真实窗口走查 `tools/ui_walkthrough.gd`：exit=0、WALK_ERRORS=0、产品代码零错误
- [ ] 导出版冒烟：`build/wanjie.exe --headless --quit-after 10` 零 SCRIPT ERROR
- [ ] 三场景截图/布局/动效验证通过
- [ ] 版本信息：export_presets.cfg（file_version/product_name 等）

## 4. 分发内容

- `wanjie.exe`（主程序）
- 首次运行自动创建 `user://` 数据目录（剧本/用户数据/存档）

## 5. 版本迭代

1. 更新 `export_presets.cfg` 的 `application/file_version` / `product_version`
2. 改代码 → verify_all → 走查 → 导出 → 冒烟
3. 提交推送（中文提交规范，见 AGENTS.md §6）

## 6. 已知发布限制（诚实清单）

- 社区/市场为本地闭环（发布→本地市场→分享 .json 文件）；远程服务器/账号待接入（接口已预留，见 docs/FEATURE_IMPROVEMENT_PLAN.md §6）
- 无音效/音乐资产（体验器无音频）
- 2D/3D 场景编辑器画布交互（地图编辑器）部分待补（visual_map 有 has_method 保护）
