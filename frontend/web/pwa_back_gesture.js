// Let Flutter own the back gesture instead of also navigating WebKit history.
(() => {
  window.ysyncPwaBackGesture = {
    // Keep the old bridge callable while cached Flutter bundles are replaced.
    setDetailActive: () => {},
    enabled: false,
    version: 'guard_v3',
  };
  const ios = /iPhone|iPad|iPod/.test(navigator.userAgent) ||
    (/Macintosh/.test(navigator.userAgent) && navigator.maxTouchPoints > 1);
  const standalone = navigator.standalone === true ||
    window.matchMedia('(display-mode: standalone)').matches;
  window.ysyncPwaBackGesture.enabled = ios && standalone;
  if (!ios || !standalone) return;
  document.addEventListener('touchstart', event => {
    let outcome;
    if (event.touches.length !== 1) {
      outcome = 'multi_touch';
    } else if (!(event.touches[0].clientX >= 0 && event.touches[0].clientX <= 20)) {
      outcome = 'outside_edge';
    } else if (!event.cancelable) {
      outcome = 'not_cancelable';
    } else {
      // Do not stop propagation: Flutter still needs the pointer/gesture stream.
      event.preventDefault();
      outcome = event.defaultPrevented ? 'prevented' : 'not_prevented';
    }
    try {
      window.ysyncSwipeDiagnostics?.record('guard_touch', outcome);
    } catch (_) { /* Diagnostics must never interrupt touch handling. */ }
  }, { passive: false });
})();
