# 发布指南（wanjie 万界诗篇）

> 将项目导出为可分发的 Windows 应用。所有命令在本机（Windows + Godot 4.7.1）验证通过。

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
