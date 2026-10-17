// 灵动桌面 Aura - 渲染进程逻辑
(function () {
  const grid = document.getElementById('icon-grid');
  let currentSettings = { hover: {}, icons: {}, groups: [] };
  let items = [];
  let groups = [];
  let dragPath = null;

  // 把参数写入 CSS 变量
  function applySettings(s) {
    currentSettings = s;
    groups = (s.groups || []).map((g) => ({ ...g, items: [...(g.items || [])] }));
    const root = document.documentElement;
    const h = s.hover || {};
    const ic = s.icons || {};
    root.style.setProperty('--icon-size', (ic.iconSize || 48) + 'px');
    root.style.setProperty('--cell-w', (ic.spacingX || 75) + 'px');
    root.style.setProperty('--cell-h', (ic.spacingY || 75) + 'px');
    root.style.setProperty('--offset-x', (ic.offsetX != null ? ic.offsetX : 8) + 'px');
    root.style.setProperty('--offset-y', (ic.offsetY != null ? ic.offsetY : 8) + 'px');
    root.style.setProperty('--lift-y', '-' + (h.liftY != null ? h.liftY : 10) + 'px');
    root.style.setProperty('--hover-scale', String(h.scale != null ? h.scale : 1.07));
    root.style.setProperty('--hover-duration', (h.duration != null ? h.duration : 0.28) + 's');
    root.style.setProperty('--hover-easing', h.easing || 'cubic-bezier(0.22, 1.4, 0.36, 1)');
    root.style.setProperty('--wallpaper', s.wallpaper ? 'url("' + s.wallpaper + '")' : 'none');
  }

  // 计算每个图标归属
  function computeBuckets() {
    const assigned = new Set();
    groups.forEach((g) => (g.items || []).forEach((p) => assigned.add(p)));
    const ungrouped = items.filter((it) => !assigned.has(it.path));
    return { assigned, ungrouped };
  }

  function saveGroups() {
    window.desktop.saveGroups(groups.map((g) => ({ ...g, items: [...(g.items || [])] })));
  }

  // 单个图标元素
  function makeIcon(item) {
    const el = document.createElement('div');
    el.className = 'icon';
    el.dataset.path = item.path;
    el.title = item.name;
    el.draggable = true;

    const imgWrap = document.createElement('div');
    imgWrap.className = 'icon-img';
    if (item.icon) {
      const img = document.createElement('img');
      img.src = item.icon;
      img.draggable = false;
      imgWrap.appendChild(img);
    } else {
      imgWrap.classList.add('no-icon');
    }

    const label = document.createElement('div');
    label.className = 'icon-label';
    label.textContent = item.name;

    el.appendChild(imgWrap);
    el.appendChild(label);

    el.addEventListener('dragstart', (e) => {
      dragPath = item.path;
      e.dataTransfer.setData('text/plain', item.path);
      e.dataTransfer.effectAllowed = 'move';
      window.desktop.setInteractive(true);
      el.classList.add('dragging');
    });
    el.addEventListener('dragend', () => {
      dragPath = null;
      el.classList.remove('dragging');
      window.desktop.setInteractive(false);
    });
    el.addEventListener('click', () => window.desktop.launch(item.path));
    el.addEventListener('mouseenter', () => {
      const rect = el.getBoundingClientRect();
      const root = document.documentElement;
      root.style.setProperty('--bg-x', Math.round(-rect.left) + 'px');
      root.style.setProperty('--bg-y', Math.round(-rect.top) + 'px');
    });
    return el;
  }

  // 分组盒子（绝对定位，可折叠/重命名/拖位置/接收拖入）
  function makeGroupBox(g) {
    const box = document.createElement('div');
    box.className = 'group-box';
    box.dataset.groupId = g.id;
    box.style.left = (g.x || 20) + 'px';
    box.style.top = (g.y || 90) + 'px';
    if (g.collapsed) box.classList.add('collapsed');

    let draggingHeader = false;

    const header = document.createElement('div');
    header.className = 'group-header';
    const caret = document.createElement('span');
    caret.className = 'caret';
    caret.textContent = '▾';
    header.appendChild(caret);
    const nameSpan = document.createElement('span');
    nameSpan.className = 'group-name';
    nameSpan.textContent = g.name;
    header.appendChild(nameSpan);
    const count = document.createElement('span');
    count.className = 'count';
    count.textContent = String((g.items || []).length);
    header.appendChild(count);

    const body = document.createElement('div');
    body.className = 'group-body';
    (g.items || []).forEach((p) => {
      const it = items.find((x) => x.path === p);
      if (it) body.appendChild(makeIcon(it));
    });

    box.appendChild(header);
    box.appendChild(body);

    // 折叠
    header.addEventListener('click', (e) => {
      if (e.target.tagName === 'INPUT') return;
      if (draggingHeader) return;
      g.collapsed = !g.collapsed;
      box.classList.toggle('collapsed', g.collapsed);
      saveGroups();
    });

    // 重命名（双击标题）
    header.addEventListener('dblclick', (e) => {
      e.stopPropagation();
      const input = document.createElement('input');
      input.className = 'group-name-input';
      input.value = g.name;
      header.replaceChild(input, nameSpan);
      window.desktop.setRenameMode(true);
      input.focus();
      input.select();
      let done = false;
      const commit = () => {
        if (done) return;
        done = true;
        g.name = input.value.trim() || g.name;
        saveGroups();
        window.desktop.setRenameMode(false);
        render();
      };
      const cancel = () => {
        if (done) return;
        done = true;
        window.desktop.setRenameMode(false);
        render();
      };
      input.addEventListener('blur', commit);
      input.addEventListener('keydown', (ev) => {
        if (ev.key === 'Enter') commit();
        if (ev.key === 'Escape') cancel();
      });
    });

    // 拖位置（拖动标题）
    header.addEventListener('mousedown', (e) => {
      if (e.target.tagName === 'INPUT') return;
      if (e.detail > 1) return;
      const startX = e.clientX, startY = e.clientY;
      const origX = g.x || 20, origY = g.y || 90;
      let moved = false;
      const move = (ev) => {
        moved = true;
        draggingHeader = true;
        g.x = origX + (ev.clientX - startX);
        g.y = origY + (ev.clientY - startY);
        box.style.left = g.x + 'px';
        box.style.top = g.y + 'px';
      };
      const up = () => {
        draggingHeader = false;
        document.removeEventListener('mousemove', move);
        document.removeEventListener('mouseup', up);
        if (moved) saveGroups();
      };
      document.addEventListener('mousemove', move);
      document.addEventListener('mouseup', up);
    });

    // 接收图标拖入
    box.addEventListener('dragover', (e) => {
      e.preventDefault();
      e.dataTransfer.dropEffect = 'move';
      box.classList.add('drop-target');
    });
    box.addEventListener('dragleave', () => box.classList.remove('drop-target'));
    box.addEventListener('drop', (e) => {
      e.preventDefault();
      e.stopPropagation();
      box.classList.remove('drop-target');
      if (!dragPath) return; // 只处理真正的图标拖拽
      moveIconToGroup(dragPath, g.id);
    });

    return box;
  }

  // 把图标移动到指定分组
  function moveIconToGroup(path, groupId) {
    groups.forEach((g) => { g.items = (g.items || []).filter((x) => x !== path); });
    const target = groups.find((g) => g.id === groupId);
    if (target) target.items.push(path);
    saveGroups();
    render();
  }

  // 把图标移出所有分组
  function removeIconFromGroups(path) {
    groups.forEach((g) => { g.items = (g.items || []).filter((x) => x !== path); });
    saveGroups();
    render();
  }

  // 新建一个空分组
  function createGroup() {
    const id = 'g' + Date.now();
    const g = {
      id,
      name: '新建分组',
      items: [],
      x: 20 + (groups.length % 3) * 220,
      y: 90 + Math.floor(groups.length / 3) * 180,
      collapsed: false,
    };
    groups.push(g);
    saveGroups();
    render();
  }

  // 新建组按钮
  function makeNewGroupButton() {
    const btn = document.createElement('div');
    btn.className = 'new-group-btn';
    btn.textContent = '＋ 新建组';
    btn.addEventListener('click', () => createGroup());
    return btn;
  }

  // 渲染
  function render() {
    grid.innerHTML = '';
    const { ungrouped } = computeBuckets();

    const ungroupedEl = document.createElement('div');
    ungroupedEl.className = 'ungrouped';
    ungrouped.forEach((it) => ungroupedEl.appendChild(makeIcon(it)));
    grid.appendChild(ungroupedEl);

    groups.forEach((g) => grid.appendChild(makeGroupBox(g)));

    grid.appendChild(makeNewGroupButton());
  }

  // 鼠标穿透切换（拖拽期间保持可交互）
  let interactive = false;
  document.addEventListener('mousemove', (e) => {
    if (dragPath) return;
    const el = document.elementFromPoint(e.clientX, e.clientY);
    const onInteractive = !!(el && (el.closest('.icon') || el.closest('.group-header') || el.closest('.new-group-btn')));
    if (onInteractive !== interactive) {
      interactive = onInteractive;
      window.desktop.setInteractive(onInteractive);
    }
  });

  // 空白区域 drop = 移出分组
  grid.addEventListener('dragover', (e) => e.preventDefault());
  grid.addEventListener('drop', (e) => {
    if (e.target.closest('.group-box')) return;
    if (!dragPath) return; // 只处理真正的图标拖拽
    removeIconFromGroups(dragPath);
  });

  window.desktop.onIconsUpdated((newItems) => {
    items = newItems;
    render();
  });
  window.desktop.onSettingsUpdated((s) => applySettings(s));
  window.desktop.onNewGroup(() => createGroup());
  window.desktop.onGroupsUpdated((newGroups) => {
    groups = (newGroups || []).map((g) => ({ ...g, items: [...(g.items || [])] }));
    render();
  });

  // 初次加载
  (async () => {
    const s = await window.desktop.getSettings();
    applySettings(s);
    items = await window.desktop.getIcons();
    render();
  })();
})();
