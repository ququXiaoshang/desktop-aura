// 预加载脚本：在渲染进程暴露安全的最小 API 桥
const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('desktop', {
  // 获取桌面图标列表
  getIcons: () => ipcRenderer.invoke('get-icons'),
  // 获取布局与上浮参数
  getSettings: () => ipcRenderer.invoke('get-settings'),
  // 保存上浮参数（设置面板用）
  saveSettings: (hover) => ipcRenderer.send('save-settings', hover),
  // 保存分组（拖拽归类/重命名/拖位置）
  saveGroups: (groups) => ipcRenderer.send('save-groups', groups),
  // 重命名时临时切换窗口可聚焦（让输入框能打字）
  setRenameMode: (on) => ipcRenderer.send('set-rename-mode', on),
  // 订阅「新建分组」事件
  onNewGroup: (cb) => ipcRenderer.on('new-group', () => cb()),
  // 订阅分组更新（设置面板改动分组时刷新）
  onGroupsUpdated: (cb) => ipcRenderer.on('groups-updated', (e, groups) => cb(groups)),
  // 订阅设置更新（主窗口实时刷新）
  onSettingsUpdated: (cb) => ipcRenderer.on('settings-updated', (e, s) => cb(s)),
  // 切换鼠标穿透（true=可交互，false=穿透到桌面）
  setInteractive: (interactive) => ipcRenderer.send('set-interactive', interactive),
  // 启动某个快捷方式
  launch: (p) => ipcRenderer.send('launch', p),
  // 订阅图标刷新事件
  onIconsUpdated: (cb) => ipcRenderer.on('icons-updated', (e, items) => cb(items)),
});
