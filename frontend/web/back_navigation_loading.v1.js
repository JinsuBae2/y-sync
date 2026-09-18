// A page-level fallback; it cannot cover WebKit's native swipe snapshots.
(() => {
  let token = 0;
  let timer;
  let panel;
  const record = detail => {
    try { window.ysyncSwipeDiagnostics?.record('back_loading', detail); } catch (_) {}
  };
  function hide(reason) {
    clearTimeout(timer);
    if (panel && !panel.hidden) {
      panel.hidden = true;
      record(reason);
    }
  }
  window.ysyncBackLoading = {
    get token() { return panel && !panel.hidden ? token : 0; },
    complete(expected) {
      if (!expected || expected !== token) return;
      requestAnimationFrame(() => requestAnimationFrame(() => {
        if (expected === token) hide('frame_ready');
      }));
    },
  };
  if (!window.ysyncPwaBackGesture?.enabled) return;
  addEventListener('popstate', () => {
    if (!panel) {
      panel = document.createElement('div');
      panel.setAttribute('role', 'status');
      panel.setAttribute('aria-live', 'polite');
      panel.textContent = '화면을 불러오는 중…';
      panel.style.cssText = 'position:fixed;inset:0;z-index:2147483646;background:#f5f7fa;color:#164687;text-align:center;padding-top:45vh;font:600 16px system-ui';
      panel.style.pointerEvents = 'none';
      document.body.appendChild(panel);
    }
    token++;
    clearTimeout(timer);
    panel.hidden = false;
    record('shown');
    const expected = token;
    timer = setTimeout(() => { if (expected === token) hide('timeout'); }, 2000);
  });
  addEventListener('pagehide', () => { token++; hide('page_hidden'); });
})();
