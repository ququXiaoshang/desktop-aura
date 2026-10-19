# 交接快照

> 更新于 **2026-10-19** ｜ 版本 0.2.0 ｜ 阶段 A + 切换流畅度优化完成
> 规矩：每完成一个能验证的里程碑，就更新本文档顶部日期 + 「下一步第一件事」，然后 commit 一次。

## 一句话现状

阶段 A 全部完成。绿色版 `dist\win-unpacked\灵动桌面Aura.exe` 双击可用，启动约 0.5–0.6 秒。
唯一大项——单文件 exe 打包——因网络原因卡住，当前用绿色版目录分发。
新增 `pnpm release`：把绿色版一键压成 `release\desktop-aura-<版本>-win-x64.zip`，可直接分发到其他 Windows x64 电脑（零依赖）。
切模式优化已完成：改用 `ShowWindow` 隐藏/显示桌面 `SysListView32`（参考开源项目 KONEWS/DesktopIconToggle），不再重启 explorer —— 秒切、无白屏、任务栏不丢；注册表+重启 explorer 仅作兜底。

## 已验证可用（能跑过）

- [x] 图标悬停上浮 + 放大 + 投影 + 弹性缓动
- [x] 点击图标启动对应程序
- [x] 托盘一键切「灵动 / 原生」两套桌面，图标不重叠
- [x] 鼠标穿透：图标以外区域不挡右键、不挡框选
- [x] 复刻系统图标大小 / 间距 / 字体（自动读注册表）
- [x] 收纳分组：拖拽归类、双击改名、拖动盒子改位置、新建组、折叠、实时持久化
- [x] 设置面板：动效 / 分组 / 关于 三标签，滑块实时预览
- [x] 壁纸毛玻璃：hover 时显示壁纸对应区域的模糊背景
- [x] 开机自启：注册表 Run 键 + 启动自检恢复
- [x] 性能：图标/壁纸/解析/参数 四类缓存 + 启动并行化（2–4s → 0.5–0.6s）
- [x] 切换流畅：`ShowWindow` 免重启 explorer 切换（秒切、无白屏、任务栏不丢）
- [x] 首显就绪：窗口预热 + `backgroundThrottling:false`，开机第一次切换图标即正常

## 未完成 / 卡住

- [ ] **单文件 exe 打包** —— 卡在 electron-builder 25 下载 NSIS 工具失败（网络）
  - 已试：builder 26 → 有 `ElectronDownloadCacheMode` bug，降级 25
  - 已试：25 → 卡 NSIS 工具下载
  - 已试：7z 自解压 → 不适合常驻应用（弹窗 / 每次解压 / 权限）
  - **结论：留到阶段 B，换正常网络环境后一条命令的事。不要再在这上面耗时间。**

## 下一步第一件事（按推荐度排序，你拍板）

1. **多屏适配** — 目前只覆盖主屏，副屏不显示（见「已知遗留问题」）。
2. **单文件 exe 打包** — 已留到阶段 B，换正常网络后一条命令（见「未完成 / 卡住」）。
3. **远程仓库 + Releases** — 建 Git 远端（GitHub/Gitee）并承载分发 zip，供公开分发；待定平台与地址。

> 已解决（2026-10-19）：**切模式延迟 / 任务栏消失 / 流畅度** —— 改用 `ShowWindow` 隐藏桌面 `SysListView32`（参考 KONEWS/DesktopIconToggle），不再重启 explorer；广播刷新方案彻底弃用。

> 已决策（2026-10-17）：开机默认「原生桌面」、由用户在托盘勾选切「灵动桌面」，**不做**「双击直接进灵动」。
> 已清理（2026-10-17）：dist 打包残留 —— `_1` 文件已消失；修复 `assets/icon-cache/**` 生成物被误打包（`package.json` 的 `build.files` 加排除项，并删除 dist 内误打包副本）。

## 已知遗留问题

| 问题 | 说明 |
|---|---|
| 自启项可能被安全软件清理 | 有自检恢复，但需要应用先启动过一次才能补回 |
| 多屏未适配 | 只覆盖主屏，副屏不显示 |
| 动态壁纸下的毛玻璃 | 用静态备份图，与实时画面略有差异 |
| 毛玻璃为简化版 | 只做模糊，无实时折射 |

## 关键文件速查

| 文件 | 职责 |
|---|---|
| `main.js` | 主进程全部逻辑（23KB），改功能主要在这 |
| `preload.js` | contextBridge 白名单，加 IPC 要同步改这里 |
| `renderer/renderer.js` | 覆盖层渲染 / 分组 / 命中检测 / 毛玻璃定位 |
| `renderer/settings.js` | 设置面板逻辑 + 实时预览 |
| `config.json` | 用户配置：hover / icons / groups |
| `scripts/hide-icons.ps1` | 隐藏/显示系统桌面图标（ShowWindow 优先，注册表+重启 explorer 兜底） |

## 会话记录

- **2026-10-17**：阶段 A 收尾。整理 `AGENTS.md` / `HANDOFF.md`，归档 `docs/第一阶段工程总结.md`，初始化 git 仓库并首次提交。
- **2026-10-17（规范化）**：补 `LICENSE`(MIT) / `.editorconfig` / `.gitattributes`，`package.json` 加 `engines`，`README.md` 全面重写对齐实际功能（分组已为显式归属、默认原生模式、pnpm）。
- **2026-10-17（阶段 B 起步）**：决策「开机默认原生 + 托盘切灵动」保持现状（不改 `main.js`）；清理 dist 打包残留（`_1` 文件已不存在，修复 `assets/icon-cache/**` 生成物被误打包 —— `package.json` 的 `build.files` 加排除项并删除 dist 内误打包副本）。
- **2026-10-17（切模式延迟优化 → 已回滚，搁置）**：尝试 `hide-icons.ps1` 广播刷新替代重启 explorer，**隐藏生效但恢复失效（切不回原生）**，回滚到重启 explorer 稳定版；`main.js` 白屏修复（透明背景色 + 延迟 `showInactive`）保留。切模式延迟 / 任务栏消失 / 流畅度决定**以后再做**。
- **2026-10-17（可移植分发）**：新增 `scripts/zip-release.ps1` + `pnpm release`，把绿色版压成单个 zip 分发；README 补「部署到其他电脑」（普通用户 / 开发机两条路径）、去掉写死的本机路径；`.gitignore` 加 `release/`。
- **2026-10-17（安全兜底）**：新增 `scripts/restore-all.ps1` + 根目录 `还原桌面.bat`（应用没开也能一键还原：显示系统图标 + 清 `FWF_NOICONS` + 删自启 + 重启 explorer）；托盘加「彻底还原系统桌面并退出」。`zip-release.ps1` 会把还原入口一起打进 zip。另加 `使用说明.md` 随包分发。
- **2026-10-19（切换流畅度 → 彻底解决）**：调研开源项目 [KONEWS/DesktopIconToggle](https://github.com/KONEWS/DesktopIconToggle)，确认不重启 explorer 的正道是 `ShowWindow` 隐藏桌面 `SysListView32`（注册表方案会**销毁** ListView，两者不能混用）。改动：`hide-icons.ps1` 改为「ShowWindow 优先 + 注册表兜底」；`main.js` 加窗口预热（0 透明度 show 一次防白屏）+ `backgroundThrottling:false`（首显图标即就绪）+ 首次显示强制重渲染。效果：切模式秒切、无白屏、任务栏不丢、开机第一次切换即正常。附带：新增 `scripts/test-showwindow.ps1`（诊断用）。
