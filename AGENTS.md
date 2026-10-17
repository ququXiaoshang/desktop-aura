# 灵动桌面 Aura（desktop-aura）

Windows 桌面美化工具：透明覆盖层复刻桌面图标 + 悬停动效 + 收纳分组 + 壁纸毛玻璃。
Electron 33 + 原生 HTML/CSS/JS，无前端框架。当前版本 **0.2.0**。

## 开工前必做（三步）

1. **读 `HANDOFF.md`** —— 当前进度、卡点、下一步。不要凭本文件猜进度。
2. git 在 `C:\Users\LENOVO\.dsh\tools\mingit\cmd\git.exe`，**PATH 里没有 git**，直接敲 `git` 会报「无法识别」。
3. 先跑一次 `pnpm start` 确认能启动，再动手改。

## 命令

| 用途 | 命令 |
|---|---|
| 启动（开发） | `pnpm start` |
| 打包绿色版 | `pnpm dist`（= `electron-builder --win portable`，当前网络会卡在 NSIS 下载） |
| 重新生成图标 | `python gen-icon.py` |
| 恢复系统桌面图标 | `powershell -File scripts/hide-icons.ps1 0` |

依赖用 **pnpm** 管理，不要用 `npm install` 重装（会写坏 `pnpm-lock.yaml`）。

## 架构

```
main.js (23KB)   主进程：解析 .lnk → 提取图标 / 读注册表参数 / 覆盖层窗口 / 托盘 / IPC / 模式切换
preload.js       contextBridge 桥接（渲染层唯一入口）
renderer/
  index.html + renderer.js + style.css    桌面覆盖层（灵动图标 + 分组盒子）
  settings.*                              设置面板（动效 / 分组 / 关于）
scripts/         18 个 PowerShell 辅助脚本（图标 / 壁纸 / 自启 / 隐藏图标 / 排障）
assets/          icon.png / icon.ico / tray.png（gen-icon.py 生成）
assets/icon-cache/   图标缓存（生成物，已在 .gitignore）
```

覆盖层窗口 = 透明无边框 + `showInactive()` + `focusable:false`；默认 `setIgnoreMouseEvents(true,{forward:true})`，
渲染层在 `mousemove` 里做命中检测，鼠标进入图标或分组标题才切成可交互。

## 硬约束（改了会出问题）

- **渲染层不许 `require` Node 模块**，只能走 preload 暴露的接口；加 IPC 要同步改 `preload.js` 白名单。
- **`config.json` 是用户数据**：字段只增、不改名、不删。旧配置必须能直接读，迁移逻辑放 `migrateGroups()`。
- **PowerShell 脚本一律 UTF-8**（中文路径和中文快捷方式名是常态）。
- **`productName` 不要随手改** —— 它决定 `%APPDATA%\<productName>` 路径，改了单实例锁会分裂。

## 不要重复踩的坑（都真实踩过）

| 坑 | 结论 |
|---|---|
| 用 `SetParent` 贴到 WorkerW | 会被 Electron 重置 → 用 `showInactive` 顶级窗口 |
| 用 `ShowWindow` 隐藏系统图标 | 会破坏图标列表（ListView）→ 用 `HideIcons` 注册表 + `FWF_NOICONS` + 重启 explorer |
| `getFileIcon(.lnk)` | 拿不到真实图标 → 先解析 .lnk 目标再提取 |
| 中文路径 | 编码问题 → 统一 UTF-8 |
| 开机自启 | 测试任务计划方案时误删过 Run 键 → 只动 `HKCU\...\Run`，别碰任务计划 |

## 不要动

- `node_modules/`、`dist/`、`assets/icon-cache/` —— 生成物，不提交、不手改。
- `README.md` 的一期功能描述**已过期**（分组已从「关键词匹配」改为「显式归属」），**以 `HANDOFF.md` 为准**。

## 文档分工

- `HANDOFF.md` —— 活的进度快照，每个里程碑更新一次
- `docs/第一阶段工程总结.md` —— 阶段 A 完整归档（不要改，只读）
