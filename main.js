// 灵动桌面 Aura - 主进程
// 第一期 MVP：桌面覆盖层 + 图标 hover 上浮 + 点击启动 + 托盘管理
const { app, BrowserWindow, ipcMain, shell, Tray, Menu, screen, nativeImage } = require('electron');
const path = require('path');
const fs = require('fs');
const os = require('os');
const { execFile, execFileSync } = require('child_process');

const SCRIPTS_DIR = path.join(__dirname, 'scripts');
// 用绝对路径定位 powershell，避免 Electron 主进程 PATH 不含 System32 时 spawn 失败
const POWERSHELL = path.join(
  process.env.SystemRoot || 'C:\\Windows',
  'System32', 'WindowsPowerShell', 'v1.0', 'powershell.exe'
);

// 统一 userData 路径，避免 productName 变化导致配置目录和单实例锁分裂
app.setPath('userData', path.join(process.env.APPDATA || process.env.LOCALAPPDATA || '', '灵动桌面Aura'));

let mainWindow = null;
let tray = null;
let iconsData = [];
// 上浮参数（config.json 可覆盖）+ 图标布局参数（注册表自动读取）
let settings = {
  hover: { liftY: 10, scale: 1.07, duration: 0.28, easing: 'cubic-bezier(0.22, 1.4, 0.36, 1)' },
  icons: { offsetX: 8, offsetY: 8, spacingX: 75, spacingY: 75, iconSize: 48, titleWrap: true },
  groups: [],
  wallpaper: null,
};
let systemIconsHidden = false;
let settingsWindow = null;
let autoStartEnabled = false;
let overlayShownOnce = false;

/* ---------- 单实例锁：防止重复启动导致桌面覆盖层叠加 ---------- */
const gotLock = app.requestSingleInstanceLock();
if (!gotLock) {
  app.quit();
} else {
  app.on('second-instance', () => {
    if (mainWindow) mainWindow.show();
  });
}

/* ---------- 桌面图标读取 ---------- */

// Windows 桌面由「用户桌面」和「公共桌面」两部分组成
function getDesktopDirs() {
  const dirs = [];
  const userDesktop = path.join(process.env.USERPROFILE || '', 'Desktop');
  const publicDesktop = path.join(process.env.PUBLIC || 'C:\\Users\\Public', 'Desktop');
  for (const d of [userDesktop, publicDesktop]) {
    if (d && fs.existsSync(d)) dirs.push(d);
  }
  return dirs;
}

// 批量解析 .lnk 的真实目标路径（PowerShell 一次性完成，避免逐个 spawn）
function resolveLinks(lnkPaths) {
  return new Promise((resolve) => {
    if (!lnkPaths.length) { resolve({}); return; }
    const cacheFile = path.join(app.getPath('userData'), 'links-cache.json');
    let cache = {};
    try { cache = JSON.parse(fs.readFileSync(cacheFile, 'utf8')); } catch { cache = {}; }

    // 检查缓存：.lnk 文件未变则直接复用解析结果
    const result = {};
    const toResolve = [];
    for (const p of lnkPaths) {
      let mtime = 0;
      try { mtime = fs.statSync(p).mtimeMs; } catch { /* 忽略 */ }
      const c = cache[p];
      if (c && c.mtime === mtime) {
        result[p] = { target: c.target, icon: c.icon };
      } else {
        toResolve.push(p);
      }
    }

    if (!toResolve.length) { resolve(result); return; }

    const tmpFile = path.join(os.tmpdir(), 'aura-links-' + Date.now() + '.json');
    let script;
    try {
      fs.writeFileSync(tmpFile, JSON.stringify(toResolve));
      script = path.join(SCRIPTS_DIR, 'resolve-links.ps1');
    } catch { resolve(result); return; }
    execFile(POWERSHELL,
      ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', script, tmpFile],
      { windowsHide: true },
      (err, stdout) => {
        try { fs.unlinkSync(tmpFile); } catch { /* 忽略 */ }
        if (err) { resolve(result); return; }
        try {
          const arr = JSON.parse(stdout);
          for (const r of arr) {
            const p = r.path;
            result[p] = { target: r.target, icon: r.icon };
            let mtime = 0;
            try { mtime = fs.statSync(p).mtimeMs; } catch { /* 忽略 */ }
            cache[p] = { mtime, target: r.target, icon: r.icon };
          }
          try { fs.writeFileSync(cacheFile, JSON.stringify(cache)); } catch { /* 忽略 */ }
        } catch { /* 忽略 */ }
        resolve(result);
      });
  });
}

// 用 PowerShell + System.Drawing 批量提取真实图标（exe/dll/ico 都可靠）
// 带缓存：图标源文件未变化时直接复用上次提取的 PNG，加快启动
function extractIcons(sources) {
  return new Promise((resolve) => {
    if (!sources.length) { resolve({}); return; }
    const outDir = getIconCacheDir();
    const cacheFile = path.join(outDir, 'cache.json');
    let cache = {};
    try { cache = JSON.parse(fs.readFileSync(cacheFile, 'utf8')); } catch { cache = {}; }

    const resultMap = {};
    const toExtract = [];

    // 检查缓存：源文件 mtime 未变且 PNG 仍在则直接复用
    for (const s of sources) {
      let mtime = 0;
      try { mtime = fs.statSync(s.source).mtimeMs; } catch { /* 源不存在 */ }
      const c = cache[s.source];
      if (c && c.mtime === mtime) {
        const png = path.join(outDir, c.png);
        if (fs.existsSync(png)) {
          resultMap[s.key] = png;
          continue;
        }
      }
      toExtract.push(s);
    }

    // 全部命中缓存，直接返回
    if (!toExtract.length) { resolve(resultMap); return; }

    // 只提取未缓存的
    const tmpFile = path.join(os.tmpdir(), 'aura-icons-' + Date.now() + '.json');
    let script;
    try {
      fs.mkdirSync(outDir, { recursive: true });
      fs.writeFileSync(tmpFile, JSON.stringify(toExtract));
      script = path.join(SCRIPTS_DIR, 'extract-icons.ps1');
    } catch { resolve(resultMap); return; }

    execFile(POWERSHELL,
      ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', script, tmpFile, outDir],
      { windowsHide: true, maxBuffer: 10 * 1024 * 1024 },
      (err, stdout) => {
        try { fs.unlinkSync(tmpFile); } catch { /* 忽略 */ }
        if (!err) {
          try {
            const arr = JSON.parse(stdout);
            for (const r of arr) {
              if (r.png) {
                resultMap[r.key] = r.png;
                const s = toExtract.find((x) => x.key === r.key);
                if (s) {
                  let mtime = 0;
                  try { mtime = fs.statSync(s.source).mtimeMs; } catch { /* 忽略 */ }
                  cache[s.source] = { mtime, png: path.basename(r.png) };
                }
              }
            }
            try { fs.writeFileSync(cacheFile, JSON.stringify(cache)); } catch { /* 忽略 */ }
          } catch { /* 忽略 */ }
        }
        resolve(resultMap);
      });
  });
}

// 读取桌面上的 .lnk / .url / .exe，并提取真实图标
async function listDesktopItems() {
  // 1. 收集所有桌面文件
  const files = [];
  const seen = new Set();
  for (const dir of getDesktopDirs()) {
    let entries = [];
    try { entries = fs.readdirSync(dir); } catch { continue; }
    for (const f of entries) {
      if (!/\.(lnk|url|exe)$/i.test(f)) continue;
      const key = f.toLowerCase();
      if (seen.has(key)) continue;
      seen.add(key);
      files.push({
        name: f.replace(/\.(lnk|url|exe)$/i, ''),
        path: path.join(dir, f),
        ext: path.extname(f).toLowerCase(),
      });
    }
  }

  // 2. 批量解析 .lnk 的目标路径
  const lnkPaths = files.filter((f) => f.ext === '.lnk').map((f) => f.path);
  const resolved = await resolveLinks(lnkPaths);

  // 3. 确定每个文件的图标源（.lnk 用其目标/自定义图标路径）
  const sources = [];
  for (let i = 0; i < files.length; i++) {
    const f = files[i];
    let iconSource = f.path;
    if (f.ext === '.lnk' && resolved[f.path]) {
      const r = resolved[f.path];
      const iconPath = (r.icon || '').split(',')[0];
      if (iconPath && fs.existsSync(iconPath)) {
        iconSource = iconPath;
      } else if (r.target && fs.existsSync(r.target)) {
        iconSource = r.target;
      }
    }
    sources.push({ key: String(i), source: iconSource });
  }

  // 4. 批量提取图标为 PNG
  const pngMap = await extractIcons(sources);

  // 5. 读取 PNG 转 dataURL
  const items = [];
  for (let i = 0; i < files.length; i++) {
    const f = files[i];
    let icon = null;
    const pngPath = pngMap[String(i)];
    if (pngPath && fs.existsSync(pngPath)) {
      try {
        const data = fs.readFileSync(pngPath);
        icon = 'data:image/png;base64,' + data.toString('base64');
      } catch { icon = null; }
    }
    items.push({ ...f, icon });
  }
  return items;
}

/* ---------- 配置与图标布局参数 ---------- */

// 用户配置与缓存目录（打包后放在用户数据目录，方便修改和持久化）
function getUserConfigPath() {
  return path.join(app.getPath('userData'), 'config.json');
}

function getIconCacheDir() {
  return path.join(app.getPath('userData'), 'icon-cache');
}

// 清空图标与快捷方式解析缓存（强制重新提取）
function clearIconCache() {
  try {
    fs.rmSync(getIconCacheDir(), { recursive: true, force: true });
    fs.rmSync(path.join(app.getPath('userData'), 'links-cache.json'), { force: true });
  } catch { /* 忽略 */ }
}

function loadConfig() {
  const p = getUserConfigPath();
  try {
    return JSON.parse(fs.readFileSync(p, 'utf8'));
  } catch {
    // 首次运行：从项目目录复制默认 config.json 到用户数据目录
    const defaultP = path.join(__dirname, 'config.json');
    try {
      if (fs.existsSync(defaultP)) {
        const content = fs.readFileSync(defaultP, 'utf8');
        fs.mkdirSync(path.dirname(p), { recursive: true });
        fs.writeFileSync(p, content);
        return JSON.parse(content);
      }
    } catch { /* 忽略 */ }
    return {};
  }
}

// 把旧版「关键词匹配」分组迁移为「显式归属」分组
function migrateGroups(groups, items) {
  if (!Array.isArray(groups) || groups.length === 0) return groups || [];
  // 新格式：有 items 字段
  if (groups[0].items !== undefined) return groups;
  // 旧格式（match），迁移为 items
  return groups.map((g, i) => {
    const matched = items.filter((it) =>
      (g.match || []).some((kw) => it.name.toLowerCase().includes(String(kw).toLowerCase()))
    );
    return {
      id: 'g' + (i + 1),
      name: g.name,
      items: matched.map((it) => it.path),
      x: 20 + i * 20,
      y: 90 + i * 130,
      collapsed: false,
    };
  });
}

// 保存分组到用户配置（过滤非法路径，防御非图标数据混入）
function saveGroups(groups) {
  const clean = (groups || []).map((g) => ({
    ...g,
    items: (g.items || []).filter((p) => typeof p === 'string' && p.length > 2 && /[\\/]/.test(p)),
  }));
  settings.groups = clean;
  try {
    const cfg = loadConfig();
    cfg.groups = clean;
    fs.writeFileSync(getUserConfigPath(), JSON.stringify(cfg, null, 2));
  } catch { /* 忽略 */ }
}

// 读取当前壁纸文件，缩放到屏幕一半并转成 JPEG dataURL（供毛玻璃背景使用）
function loadWallpaper() {
  return new Promise((resolve) => {
    const cacheFile = path.join(app.getPath('userData'), 'wallpaper-cache.json');

    // 先读缓存：壁纸路径没变且文件未修改时，直接复用，省去 PowerShell + 文件缩放
    try {
      const cached = JSON.parse(fs.readFileSync(cacheFile, 'utf8'));
      if (cached && cached.path && cached.dataUrl) {
        if (fs.existsSync(cached.path) && fs.statSync(cached.path).mtimeMs === cached.mtime) {
          resolve(cached.dataUrl);
          return;
        }
      }
    } catch { /* 无缓存或缓存损坏，走正常加载 */ }

    const script = path.join(SCRIPTS_DIR, 'get-wallpaper.ps1');
    execFile(POWERSHELL,
      ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', script],
      { windowsHide: true },
      (err, stdout) => {
        if (err) { resolve(null); return; }
        const wpPath = (stdout || '').trim();
        if (!wpPath || !fs.existsSync(wpPath)) { resolve(null); return; }
        try {
          let img = nativeImage.createFromPath(wpPath);
          if (img.isEmpty()) { resolve(null); return; }
          const { width, height } = screen.getPrimaryDisplay().bounds;
          img = img.resize({ width: Math.round(width / 2), height: Math.round(height / 2) });
          const buf = img.toJPEG(80);
          const dataUrl = 'data:image/jpeg;base64,' + buf.toString('base64');
          // 写缓存
          try {
            const mtime = fs.statSync(wpPath).mtimeMs;
            fs.writeFileSync(cacheFile, JSON.stringify({ path: wpPath, mtime, dataUrl }));
          } catch { /* 忽略缓存写入失败 */ }
          resolve(dataUrl);
        } catch { resolve(null); }
      });
  });
}

// 从注册表读取 Windows 桌面图标的间距 / 大小，用于复刻系统布局
function loadIconMetrics() {
  return new Promise((resolve) => {
    const cacheFile = path.join(app.getPath('userData'), 'icon-metrics.json');
    // 图标间距/大小基本不变，优先读缓存
    try {
      const cached = JSON.parse(fs.readFileSync(cacheFile, 'utf8'));
      if (cached && cached.spacingX) { resolve(cached); return; }
    } catch { /* 忽略 */ }
    const script = path.join(SCRIPTS_DIR, 'read-icon-metrics.ps1');
    execFile(POWERSHELL,
      ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', script],
      { windowsHide: true },
      (err, stdout) => {
        if (err) { resolve(null); return; }
        try {
          const metrics = JSON.parse(stdout);
          try { fs.writeFileSync(cacheFile, JSON.stringify(metrics)); } catch { /* 忽略 */ }
          resolve(metrics);
        } catch { resolve(null); }
      });
  });
}

/* ---------- 窗口 ---------- */

function createWindow() {
  const { x, y, width, height } = screen.getPrimaryDisplay().bounds;

  mainWindow = new BrowserWindow({
    x, y, width, height,
    transparent: true,      // 透明窗口
    backgroundColor: '#00000000',  // 透明底色，避免首次 showInactive 前内容未合成时闪白屏
    frame: false,           // 无边框
    resizable: false,
    movable: false,
    minimizable: false,
    maximizable: false,
    fullscreenable: false,
    hasShadow: false,
    skipTaskbar: true,      // 不出现在任务栏
    focusable: false,       // 不抢键盘焦点，保持桌面感
    show: false,
    paintWhenInitiallyHidden: true,   // 隐藏时也渲染，showInactive 时内容已就绪
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
      backgroundThrottling: false,   // 隐藏时也持续渲染，避免首次显示图标没画出来
    },
  });

  // 初始状态：鼠标穿透（forward 模式保留 mousemove，供前端做 hover 命中检测）
  mainWindow.setIgnoreMouseEvents(true, { forward: true });
  mainWindow.setAlwaysOnTop(false);

  mainWindow.loadFile(path.join(__dirname, 'renderer', 'index.html'));

  mainWindow.once('ready-to-show', () => {
    // 预热合成器：以 0 透明度 show 一次再隐藏，避免首次切换「启用灵动桌面」时白屏
    mainWindow.setOpacity(0);
    mainWindow.show();
    setTimeout(() => {
      if (mainWindow && !mainWindow.isDestroyed()) {
        mainWindow.showInactive();
        mainWindow.hide();
        mainWindow.setOpacity(1);
      }
    }, 250);
  });

  mainWindow.on('closed', () => { mainWindow = null; });
}

/* ---------- 把窗口贴回桌面层（图标之上、普通窗口之下） ---------- */

function getHwnd() {
  if (!mainWindow) return null;
  const buf = mainWindow.getNativeWindowHandle();
  return buf.length >= 8 ? buf.readBigUInt64LE(0).toString() : buf.readUInt32LE(0).toString();
}

function attachToDesktop() {
  if (!mainWindow) return;
  const hwnd = getHwnd();
  if (!hwnd) return;
  const script = path.join(SCRIPTS_DIR, 'attach-to-desktop.ps1');
  execFile(POWERSHELL,
    ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', script, hwnd],
    { windowsHide: true },
    (err, stdout, stderr) => {
      if (err) console.error('[attach] 失败:', (stderr || err.message).trim());
      else console.log('[attach]', (stdout || '').trim());
    });
}

/* ---------- 隐藏 / 显示系统自带的桌面图标 ---------- */

function setSystemIconsVisible(visible, callback) {
  const script = path.join(SCRIPTS_DIR, 'hide-icons.ps1');
  const val = visible ? 0 : 1;
  execFile(POWERSHELL,
    ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', script, String(val)],
    { windowsHide: true },
    (err, stdout, stderr) => {
      if (err) console.error('[hide-icons] 失败:', (stderr || err.message).trim());
      else console.log('[hide-icons]', (stdout || '').trim());
      if (callback) callback();
    });
}

// 查询开机自启状态
function checkAutoStart() {
  return new Promise((resolve) => {
    const script = path.join(SCRIPTS_DIR, 'check-autostart.ps1');
    execFile(POWERSHELL,
      ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', script],
      { windowsHide: true },
      (err, stdout) => {
        if (err) { resolve(false); return; }
        resolve((stdout || '').trim() === 'ON');
      });
  });
}

// 设置 / 取消开机自启
function setAutoStart(enabled) {
  const script = path.join(SCRIPTS_DIR, 'set-autostart.ps1');
  execFile(POWERSHELL,
    ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', script, enabled ? '1' : '0', process.execPath, __dirname],
    { windowsHide: true },
    (err, stdout, stderr) => {
      if (err) console.error('[autostart] 失败:', (stderr || err.message).trim());
      else console.log('[autostart]', (stdout || '').trim());
    });
  // 记录用户意图到配置，供启动时自检恢复
  try {
    const cfg = loadConfig();
    cfg.autostart = enabled;
    fs.writeFileSync(getUserConfigPath(), JSON.stringify(cfg, null, 2));
  } catch { /* 忽略 */ }
}

// 切换「灵动桌面 / 原生桌面」模式
function applyAuraMode(enabled) {
  systemIconsHidden = enabled;
  if (enabled) {
    // 显示期间先保持不可聚焦：show() 会给窗口焦点，可聚焦时会抢走当前应用的键盘焦点；
    // 但 focusable:false 的窗口收不到鼠标按键（已验证：hover 有、click 没有），
    // 所以显示完成后再解除聚焦限制，图标才能点得动。
    if (mainWindow) {
      mainWindow.setFocusable(false);
      if (!mainWindow.isVisible()) {
        mainWindow.show();
        setTimeout(() => {
          if (mainWindow && !mainWindow.isDestroyed()) {
            mainWindow.showInactive();
            mainWindow.setFocusable(true);
            // 首次显示时强制重渲染一次，避免开机第一次切换图标还没渲染出来（空桌面）
            if (!overlayShownOnce) {
              overlayShownOnce = true;
              mainWindow.webContents.send('icons-updated', iconsData);
            }
          }
        }, 160);
      } else {
        mainWindow.showInactive();
        mainWindow.setFocusable(true);
      }
    }
    setSystemIconsVisible(false);
  } else {
    // 先隐藏灵动窗口，再恢复系统图标
    if (mainWindow) {
      mainWindow.setFocusable(false);
      mainWindow.hide();
    }
    setSystemIconsVisible(true);
  }
}

// 彻底还原：交给独立脚本恢复系统图标 + 清自启，然后退出（异常场景也能靠 还原桌面.bat 手动还原）
function restoreEverythingAndQuit() {
  systemIconsHidden = false;
  try {
    const cfg = loadConfig();
    cfg.autostart = false;
    fs.writeFileSync(getUserConfigPath(), JSON.stringify(cfg, null, 2));
  } catch { /* 忽略 */ }
  execFile(POWERSHELL,
    ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', path.join(SCRIPTS_DIR, 'restore-all.ps1')],
    { windowsHide: true },
    (err, stdout, stderr) => {
      if (err) console.error('[restore-all] 失败:', (stderr || err.message).trim());
      else console.log('[restore-all]', (stdout || '').trim());
      app.quit();
    });
}

/* ---------- 设置面板 ---------- */

function openSettings() {
  if (settingsWindow) { settingsWindow.focus(); return; }
  settingsWindow = new BrowserWindow({
    width: 460,
    height: 620,
    title: '灵动桌面设置',
    icon: path.join(__dirname, 'assets', 'icon.png'),
    resizable: false,
    maximizable: false,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });
  settingsWindow.setMenuBarVisibility(false);
  settingsWindow.loadFile(path.join(__dirname, 'renderer', 'settings.html'));
  settingsWindow.on('closed', () => { settingsWindow = null; });
}

/* ---------- 托盘 ---------- */

function createTray() {
  const iconPath = path.join(__dirname, 'assets', 'tray.png');
  const icon = nativeImage.createFromPath(iconPath);
  tray = new Tray(icon);
  tray.setToolTip('灵动桌面 Aura');
  const menu = Menu.buildFromTemplate([
    {
      label: '刷新桌面图标',
      click: async () => {
        clearIconCache(); // 强制清缓存，重新提取所有图标
        iconsData = await listDesktopItems();
        if (mainWindow) mainWindow.webContents.send('icons-updated', iconsData);
      },
    },
    {
      label: '启用灵动桌面',
      type: 'checkbox',
      checked: systemIconsHidden,
      click: (item) => {
        const newState = !systemIconsHidden;
        item.checked = newState;
        applyAuraMode(newState);
      },
    },
    { label: '新建分组', click: () => { if (mainWindow) mainWindow.webContents.send('new-group'); } },
    {
      label: '开机自启',
      type: 'checkbox',
      checked: autoStartEnabled,
      click: (item) => setAutoStart(item.checked),
    },
    { label: '窗口置底', click: () => { if (mainWindow) { mainWindow.moveBottom(); mainWindow.setAlwaysOnTop(false); } } },
    { label: '设置…', click: () => openSettings() },
    { label: '彻底还原系统桌面并退出', click: () => restoreEverythingAndQuit() },
    { type: 'separator' },
    { label: '退出', click: () => app.quit() },
  ]);
  tray.setContextMenu(menu);
  tray.on('double-click', () => { if (mainWindow) mainWindow.show(); });
}

/* ---------- IPC ---------- */

ipcMain.handle('get-icons', () => iconsData);
ipcMain.handle('get-settings', () => settings);

// 设置面板保存并实时应用上浮参数
ipcMain.on('save-settings', (e, newHover) => {
  if (!newHover || typeof newHover !== 'object') return;
  settings.hover = { ...settings.hover, ...newHover };
  try {
    const cfg = loadConfig();
    cfg.hover = settings.hover;
    fs.writeFileSync(getUserConfigPath(), JSON.stringify(cfg, null, 2));
  } catch { /* 忽略写回失败 */ }
  if (mainWindow) mainWindow.webContents.send('settings-updated', settings);
});

// 分组变更（拖拽归类/重命名/拖位置）后保存，并通知主窗口刷新
ipcMain.on('save-groups', (e, groups) => {
  saveGroups(groups);
  if (mainWindow) mainWindow.webContents.send('groups-updated', settings.groups);
});

// 重命名时临时切换窗口可聚焦
ipcMain.on('set-rename-mode', (e, on) => {
  if (!mainWindow) return;
  try {
    // 结束后要恢复成「灵动模式开 = 可聚焦」，不能一律设 false，
    // 否则图标会退回「点不动」的状态
    mainWindow.setFocusable(on ? true : systemIconsHidden);
    if (on) mainWindow.showInactive();
  } catch { /* 忽略 */ }
});

// 前端检测到鼠标进入/离开图标时，切换「穿透 / 可交互」
ipcMain.on('set-interactive', (e, interactive) => {
  if (!mainWindow) return;
  mainWindow.setIgnoreMouseEvents(!interactive, { forward: !interactive });
});

// 点击图标 → 启动对应程序
ipcMain.on('launch', (e, p) => {
  if (typeof p !== 'string' || !p) return;
  shell.openPath(p)
    .then((err) => {
      if (err) console.error('[launch] 打开失败:', p, err);
    })
    .catch((err) => console.error('[launch] 异常:', p, err && err.message));
});

/* ---------- 启动 ---------- */

app.whenReady().then(async () => {
  // 合并用户配置（config.json）
  const cfg = loadConfig();
  if (cfg.hover) settings.hover = { ...settings.hover, ...cfg.hover };
  if (cfg.icons) settings.icons = { ...settings.icons, ...cfg.icons };
  if (cfg.groups) settings.groups = cfg.groups;

  // 并行执行：图标、壁纸、图标参数（都带缓存，命中时无需 PowerShell）
  const [items, wallpaper, metrics] = await Promise.all([
    listDesktopItems(),
    loadWallpaper(),
    loadIconMetrics(),
  ]);

  settings.wallpaper = wallpaper;
  if (metrics) settings.icons = { ...settings.icons, ...metrics };
  // 自启状态直接读配置（不再每次启动跑 PowerShell 读注册表）
  autoStartEnabled = cfg.autostart === true;

  iconsData = items;
  // 迁移旧格式分组（关键词匹配 → 显式归属），并写回
  const oldGroups = settings.groups;
  settings.groups = migrateGroups(settings.groups, iconsData);
  if (Array.isArray(oldGroups) && oldGroups.length && oldGroups[0].items === undefined) {
    saveGroups(settings.groups); // 发生了迁移，持久化新格式
  }
  createWindow();
  createTray();
  // 默认原生模式：确保系统图标显示，灵动窗口隐藏（用户手动勾选「启用灵动桌面」才切换）
  applyAuraMode(false);

  // 预热 PowerShell：后台先跑一个空命令，避免用户切模式时遇到冷启动延迟
  execFile(POWERSHELL, ['-NoProfile', '-Command', 'exit'], { windowsHide: true }, () => {});

  // 自动检测图标变化（每 60 秒检查一次，图标源变化会自动重新提取并刷新）
  setInterval(async () => {
    try {
      const newItems = await listDesktopItems();
      const changed = newItems.length !== iconsData.length ||
        newItems.some((it, i) => !iconsData[i] || iconsData[i].icon !== it.icon || iconsData[i].path !== it.path);
      if (changed) {
        iconsData = newItems;
        if (mainWindow) mainWindow.webContents.send('icons-updated', iconsData);
      }
    } catch { /* 忽略 */ }
  }, 60000);
});

// 常驻托盘：关闭窗口不退出应用
app.on('window-all-closed', () => { /* 保持运行，由托盘退出 */ });

// 退出前若曾隐藏系统桌面图标，则自动恢复，避免桌面图标消失
app.on('will-quit', () => {
  if (systemIconsHidden) {
    try {
      execFileSync(POWERSHELL,
        ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', path.join(SCRIPTS_DIR, 'hide-icons.ps1'), '0'],
        { windowsHide: true, stdio: 'ignore' });
    } catch { /* 忽略恢复失败 */ }
  }
});
