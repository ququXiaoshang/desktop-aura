# 灵动桌面 Aura（desktop-aura）

一个 Windows 桌面美化工具：让桌面图标「灵动」起来——鼠标碰到图标就上浮，并支持收纳分组、壁纸毛玻璃质感。

> 当前版本 **0.2.0**（阶段 A 完成）。绿色版 `dist\win-unpacked\灵动桌面Aura.exe` 双击可用。

---

## 一、功能总览

| 功能 | 说明 | 状态 |
|---|---|---|
| 图标 hover 上浮 | 鼠标碰到图标上浮 + 放大 + 投影，带弹性缓动 | ✅ |
| 点击启动 | 点击图标启动对应程序 | ✅ |
| 灵动 / 原生模式切换 | 托盘勾选「启用灵动桌面」一键切换 | ✅ |
| 鼠标穿透 | 图标之外区域穿透，不影响右键桌面、框选 | ✅ |
| 复刻系统布局 | 图标大小 / 间距 / 字体自动读取系统设置 | ✅ |
| 收纳分组 | 拖拽归类、双击改名、拖动盒子改位置、新建组、折叠、实时持久化 | ✅ |
| 设置面板 | 动效 / 分组 / 关于 三标签，滑块实时预览 | ✅ |
| 壁纸毛玻璃 | hover 图标时卡片显示壁纸对应区域的模糊背景 | ✅ |
| 开机自启 | 注册表 Run 键 + 启动自检恢复 | ✅ |
| 图标自动同步 | 手动强制刷新 + 每 60 秒自动检测图标变化 | ✅ |

---

## 二、技术栈与架构

- **Electron 33**（透明无边框覆盖层窗口 + 设置面板窗口 + 托盘）
- **原生 HTML / CSS / JavaScript**（无前端框架，代码简单好维护）
- **PowerShell**（图标提取、隐藏系统图标、壁纸读取等系统交互）

### 进程结构

```
┌─────────────────────────────────────────────┐
│  主进程 main.js                             │
│  · 解析桌面 .lnk → 提取真实图标             │
│  · 读取注册表（图标间距 / 大小 / 壁纸路径） │
│  · 创建透明全屏覆盖层                        │
│  · 托盘菜单、设置面板窗口                    │
│  · 调用 PowerShell 脚本                      │
└──────────────┬──────────────────────────────┘
               │ IPC（contextBridge 安全桥接）
┌──────────────▼──────────────────────────────┐
│  渲染进程 renderer/                         │
│  · index.html（覆盖层）+ renderer.js        │
│  · settings.html（设置面板）+ settings.js   │
└─────────────────────────────────────────────┘
```

---

## 三、目录结构

```
desktop-aura/
├── main.js                  主进程（图标 / 窗口 / 托盘 / IPC / 缓存 / 模式切换）
├── preload.js               contextBridge 安全桥接
├── config.json              用户默认配置（hover / icons / groups / autostart）
├── package.json             项目与打包配置
├── gen-icon.py              图标生成脚本（PIL）
├── renderer/
│   ├── index.html           桌面覆盖层页面
│   ├── renderer.js          渲染 / 分组 / 命中检测 / 毛玻璃定位
│   ├── style.css            布局、上浮动效、分组盒子、毛玻璃
│   ├── settings.html        设置面板页面
│   ├── settings.css         设置面板样式
│   └── settings.js          设置面板逻辑（实时预览 + 保存）
├── scripts/                 PowerShell 辅助脚本
│   ├── extract-icons.ps1    提取真实图标（exe / dll / ico）
│   ├── resolve-links.ps1    解析 .lnk 快捷方式目标
│   ├── hide-icons.ps1       隐藏 / 显示系统桌面图标
│   ├── get-wallpaper.ps1    读取当前壁纸路径
│   ├── read-icon-metrics.ps1 读取图标间距 / 大小
│   ├── set-autostart.ps1    设置开机自启
│   ├── check-autostart.ps1  检查自启状态
│   └── （其余为排障辅助脚本）
├── assets/                  图标资源（icon.png / icon.ico / tray.png）
├── docs/                    文档归档
├── AGENTS.md                项目约定
├── HANDOFF.md               进度快照
├── README.md                本文件
└── dist/                    打包产物（不提交）
```

---

## 四、运行方法

### 开发模式

```powershell
cd C:\Users\LENOVO\desktop-aura
pnpm install     # 首次安装依赖（使用 pnpm，不要用 npm）
pnpm start       # 启动
```

### 使用绿色版

双击 `dist\win-unpacked\灵动桌面Aura.exe`（或桌面快捷方式）。

> 启动后默认是**原生桌面**，托盘勾选「启用灵动桌面」才切换到灵动桌面。
> 退出应用时会自动恢复系统桌面图标，不会让桌面变空。

---

## 五、配置说明（config.json）

配置文件位置：`%APPDATA%\灵动桌面Aura\config.json`（首次运行自动生成）。

```json
{
  "hover": {
    "liftY": 10,
    "scale": 1.07,
    "duration": 0.28,
    "easing": "cubic-bezier(0.22, 1.4, 0.36, 1)"
  },
  "icons": {
    "offsetX": 8,
    "offsetY": 8
  },
  "groups": [],
  "autostart": false
}
```

| 字段 | 说明 |
|---|---|
| `hover.liftY` | 上浮高度（px） |
| `hover.scale` | 放大倍数 |
| `hover.duration` | 动画时长（秒） |
| `hover.easing` | 弹性曲线 |
| `icons.offsetX/Y` | 图标区整体偏移 |
| `groups` | 分组列表（显式归属，每个图标属于哪个组） |
| `autostart` | 是否开机自启（记录用户意图） |

- `hover` 也可通过托盘「设置…」面板实时调整。
- `groups` 由拖拽归类 / 新建组自动维护，无需手动编辑。
- 图标大小、间距自动读取系统值。

---

## 六、核心原理

1. **图标来源**：解析桌面 `.lnk` 快捷方式，拿到真实目标路径（exe / ico），再用 PowerShell 的 `System.Drawing.ExtractAssociatedIcon` 提取真实图标，缓存为 PNG。
2. **覆盖层窗口**：透明无边框全屏窗口，`show()` 强制渲染后转 `showInactive()`，不抢键盘焦点。
3. **鼠标穿透**：默认 `setIgnoreMouseEvents(true, { forward: true })`，渲染层 `mousemove` 命中检测，鼠标进入图标或分组标题才切为可交互。
4. **隐藏系统图标**：改注册表 `HideIcons` + Shell Bags 的 `FWF_NOICONS` 标志位 + 重启资源管理器（这是可靠方案，`ShowWindow` 会破坏图标列表）。
5. **毛玻璃**：读取壁纸文件 → 缩放 → hover 图标时用伪元素显示壁纸对应区域的模糊背景。
6. **缓存**：图标、壁纸、快捷方式解析、图标参数四类缓存，启动约 0.5 秒。

---

## 七、已知限制

- **切灵动模式延迟**：第一次切换需要重启资源管理器（约 2-3 秒，开机后更久），这是隐藏系统图标的必要代价。
- **多屏**：目前只覆盖主屏，副屏未适配。
- **动态壁纸**：毛玻璃使用壁纸的静态备份图，与动态画面略有差异。
- **毛玻璃为简化版**：只做壁纸模糊，不做实时折射。
- **单文件 exe**：当前为绿色版目录，单文件打包留待后续。

---

## 八、常见问题

**Q：依赖安装失败？**
```powershell
pnpm install
```
（本项目用 pnpm；若 Electron 下载慢，`.npmrc` 已配置国内镜像。）

**Q：想恢复系统桌面图标？**
托盘取消「启用灵动桌面」，或：
```powershell
powershell -File scripts/hide-icons.ps1 0
```

**Q：图标显示空白？**
托盘「刷新桌面图标」强制重新提取；或等待 60 秒自动检测刷新。

**Q：想换回图标散落（不分组）？**
删除所有分组后，图标自动回到散落状态。

---

## 九、许可证

[MIT](LICENSE)
