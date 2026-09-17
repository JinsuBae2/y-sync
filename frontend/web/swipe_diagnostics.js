// Opt-in, device-local diagnostics. Never records URLs, tokens or content.
(() => {
  const flagKey = 'ysync.swipe.enabled';
  const logKey = 'ysync.swipe.events';
  const run = `${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
  const eventsAllowed = new Set([
    'page_start', 'page_show', 'page_hide', 'visibility', 'history_pop',
    'touch_start', 'touch_end', 'touch_cancel', 'flutter_start',
    'route_push', 'route_pop', 'route_replace', 'gesture_start', 'gesture_stop',
    'request_start', 'request_end', 'request_error', 'guard_touch',
  ]);
  const detailsAllowed = new Set([
    'notice', 'community', 'other', 'left_edge', 'visible', 'hidden',
    'cached', 'fresh', 'navigate', 'reload', 'back_forward', 'unknown',
    'prevented', 'not_prevented', 'not_cancelable', 'outside_edge', 'multi_touch',
    'flutter_v2',
  ]);
  let flutterVersion = 'unknown';
  let activeTouch;
  const coordinate = value => Number.isFinite(value) && Math.abs(value) <= 100000
    ? Math.round(value) : null;
  let enabled = false;
  let installed = false;
  let panel;
  let events = [];
  const read = key => { try { return sessionStorage.getItem(key); } catch (_) { return null; } };
  const write = (key, value) => { try { sessionStorage.setItem(key, value); } catch (_) {} };
  const remove = key => { try { sessionStorage.removeItem(key); } catch (_) {} };
  function record(event, detail = '', touch) {
    if (event === 'flutter_start') {
      flutterVersion = detail === 'flutter_v2' ? detail : 'unknown';
    }
    if (!enabled || !eventsAllowed.has(event)) return;
    events.push({ at: new Date().toISOString(), run, event,
      detail: detailsAllowed.has(detail) ? detail : '',
      diagnosticVersion: 'diag_v3',
      guardVersion: window.ysyncPwaBackGesture?.version === 'guard_v3' ? 'guard_v3' : 'unknown',
      guardEnabled: typeof window.ysyncPwaBackGesture?.enabled === 'boolean'
        ? window.ysyncPwaBackGesture.enabled : null,
      flutterVersion, ...(touch ? { touch } : {}) });
    events = events.slice(-150);
    write(logKey, JSON.stringify(events));
  }
  function updatePosition(point) {
    if (!activeTouch || point?.identifier !== activeTouch.identifier) return false;
    const x = coordinate(point?.clientX);
    const y = coordinate(point?.clientY);
    if (x === null || y === null) return false;
    activeTouch.lastX = x;
    activeTouch.lastY = y;
    return true;
  }
  function finishTouch(event, e) {
    if (!enabled) return;
    let touch;
    if (activeTouch) {
      const point = Array.from(e.changedTouches || []).find(
        p => p.identifier === activeTouch.identifier);
      const updated = updatePosition(point);
      const { startX, startY, lastX, lastY, viewportWidth } = activeTouch;
      const deltaX = lastX - startX;
      const deltaY = lastY - startY;
      const direction = Math.max(Math.abs(deltaX), Math.abs(deltaY)) < 8 ? 'stationary'
        : Math.abs(deltaX) >= Math.abs(deltaY) ? (deltaX > 0 ? 'right' : 'left')
          : (deltaY > 0 ? 'down' : 'up');
      touch = { startX, startY, viewportWidth, deltaX, deltaY, direction,
        positionSource: updated ? 'changed_touch' : 'last_observed' };
    }
    activeTouch = undefined;
    record(event, '', touch);
  }
  function stop() {
    enabled = false;
    activeTouch = undefined;
    events = [];
    remove(flagKey);
    remove(logKey);
    panel?.remove();
  }
  function enable() {
    if (enabled) return;
    enabled = true;
    write(flagKey, '1');
    try {
      const saved = JSON.parse(read(logKey) || '[]');
      events = Array.isArray(saved) ? saved.filter(e =>
        e && eventsAllowed.has(e.event) && typeof e.run === 'string' &&
        typeof e.at === 'string' && (e.detail === '' || detailsAllowed.has(e.detail))
      ).slice(-150) : [];
    } catch (_) { events = []; }
    record('page_start', performance.getEntriesByType('navigation')[0]?.type || 'unknown');
    if (!installed) {
      installed = true;
      addEventListener('pageshow', e => record('page_show', e.persisted ? 'cached' : 'fresh'));
      addEventListener('pagehide', e => record('page_hide', e.persisted ? 'cached' : 'fresh'));
      addEventListener('popstate', () => record('history_pop'));
      document.addEventListener('visibilitychange', () => record('visibility', document.visibilityState));
      document.addEventListener('touchstart', e => {
        if (!enabled) return;
        const point = e.touches.length === 1 ? e.touches[0] : null;
        const x = coordinate(point?.clientX);
        const y = coordinate(point?.clientY);
        activeTouch = point && x !== null && y !== null ? {
          identifier: point.identifier, startX: x, startY: y, lastX: x, lastY: y,
          viewportWidth: coordinate(window.innerWidth),
        } : undefined;
        record('touch_start', e.touches[0]?.clientX >= 0 && e.touches[0]?.clientX <= 20
          ? 'left_edge' : 'other', activeTouch ? {
            startX: x, startY: y, viewportWidth: activeTouch.viewportWidth,
          } : undefined);
      }, { passive: true });
      // Keep only the latest sample in memory; never persist a movement trace.
      document.addEventListener('touchmove', e => {
        if (!enabled || !activeTouch) return;
        if (e.touches.length !== 1) { activeTouch = undefined; return; }
        updatePosition(e.touches[0]);
      }, { passive: true });
      document.addEventListener('touchend', e => finishTouch('touch_end', e), { passive: true });
      document.addEventListener('touchcancel', e => finishTouch('touch_cancel', e), { passive: true });
    }
    panel = document.createElement('div');
    panel.style.cssText = 'position:fixed;right:8px;top:calc(env(safe-area-inset-top,0px) + 8px);z-index:2147483647;background:white;border:1px solid #164687;border-radius:6px;padding:4px';
    const save = document.createElement('button');
    save.textContent = '진단 저장';
    save.onclick = () => {
      const url = URL.createObjectURL(new Blob([JSON.stringify(events, null, 2)], { type: 'application/json' }));
      const link = document.createElement('a');
      link.href = url;
      link.download = 'ysync-swipe-diagnostics.json';
      document.body.appendChild(link);
      link.click();
      link.remove();
      setTimeout(() => URL.revokeObjectURL(url), 1000);
    };
    const close = document.createElement('button');
    close.textContent = '진단 종료';
    close.onclick = stop;
    panel.appendChild(save);
    panel.appendChild(close);
    document.body.appendChild(panel);
  }
  window.ysyncSwipeDiagnostics = { enable, record: (event, detail) => record(event, detail), export: () => JSON.stringify(events), stop };
  const option = new URLSearchParams(location.search).get('swipeDebug');
  if (option === '0') stop();
  else if (option === '1' || read(flagKey) === '1') enable();
})();
