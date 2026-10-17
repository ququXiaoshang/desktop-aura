// 灵动桌面 Aura - 设置面板逻辑
(function () {
  // ===== 标签页切换 =====
  const tabs = document.querySelectorAll('.tab');
  const contents = {
    effects: document.getElementById('tab-effects'),
    groups: document.getElementById('tab-groups'),
    about: document.getElementById('tab-about'),
  };
  tabs.forEach((tab) => {
    tab.addEventListener('click', () => {
      tabs.forEach((t) => t.classList.remove('active'));
      tab.classList.add('active');
      Object.keys(contents).forEach((k) => { contents[k].hidden = (k !== tab.dataset.tab); });
    });
  });

  // ===== 动效设置 =====
  const liftY = document.getElementById('liftY');
  const scale = document.getElementById('scale');
  const duration = document.getElementById('duration');
  const easing = document.getElementById('easing');
  const liftYVal = document.getElementById('liftY-val');
  const scaleVal = document.getElementById('scale-val');
  const durationVal = document.getElementById('duration-val');
  const reset = document.getElementById('reset');

  let timer = null;
  function currentHover() {
    return {
      liftY: Number(liftY.value),
      scale: Number(scale.value) / 100,
      duration: Number(duration.value) / 100,
      easing: easing.value,
    };
  }
  function push() { window.desktop.saveSettings(currentHover()); }
  function updateLabels() {
    liftYVal.textContent = liftY.value + 'px';
    scaleVal.textContent = (Number(scale.value) / 100).toFixed(2);
    durationVal.textContent = (Number(duration.value) / 100).toFixed(2) + 's';
  }
  function onInput() { updateLabels(); clearTimeout(timer); timer = setTimeout(push, 120); }
  liftY.addEventListener('input', onInput);
  scale.addEventListener('input', onInput);
  duration.addEventListener('input', onInput);
  easing.addEventListener('change', push);
  reset.addEventListener('click', () => {
    liftY.value = 10;
    scale.value = 107;
    duration.value = 28;
    easing.value = 'cubic-bezier(0.22, 1.4, 0.36, 1)';
    updateLabels();
    push();
  });

  // ===== 分组管理 =====
  let groups = [];
  const groupList = document.getElementById('group-list');
  const addGroup = document.getElementById('add-group');

  function saveGroups() {
    window.desktop.saveGroups(groups.map((g) => ({ ...g, items: [...(g.items || [])] })));
  }

  function renderGroups() {
    groupList.innerHTML = '';
    if (!groups.length) {
      const empty = document.createElement('div');
      empty.className = 'empty';
      empty.textContent = '还没有分组，点击「＋ 新建分组」创建。';
      groupList.appendChild(empty);
      return;
    }
    groups.forEach((g, i) => {
      const row = document.createElement('div');
      row.className = 'group-row';

      const nameInput = document.createElement('input');
      nameInput.type = 'text';
      nameInput.value = g.name;
      nameInput.addEventListener('change', () => {
        g.name = nameInput.value.trim() || g.name;
        saveGroups();
      });

      const count = document.createElement('span');
      count.className = 'group-count';
      count.textContent = (g.items || []).length + ' 个图标';

      const del = document.createElement('button');
      del.className = 'del-btn';
      del.textContent = '删除';
      del.addEventListener('click', () => {
        groups.splice(i, 1);
        saveGroups();
        renderGroups();
      });

      row.appendChild(nameInput);
      row.appendChild(count);
      row.appendChild(del);
      groupList.appendChild(row);
    });
  }

  addGroup.addEventListener('click', () => {
    groups.push({
      id: 'g' + Date.now(),
      name: '新建分组',
      items: [],
      x: 20 + (groups.length % 3) * 220,
      y: 90 + Math.floor(groups.length / 3) * 180,
      collapsed: false,
    });
    saveGroups();
    renderGroups();
  });

  // ===== 加载 =====
  (async () => {
    const s = await window.desktop.getSettings();
    const h = s.hover || {};
    if (h.liftY != null) liftY.value = Math.round(h.liftY);
    if (h.scale != null) scale.value = Math.round(h.scale * 100);
    if (h.duration != null) duration.value = Math.round(h.duration * 100);
    if (h.easing) easing.value = h.easing;
    updateLabels();
    groups = (s.groups || []).map((g) => ({ ...g, items: [...(g.items || [])] }));
    renderGroups();
  })();
})();
