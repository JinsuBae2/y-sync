// Let Flutter own the back gesture instead of also navigating WebKit history.
(() => {
  window.ysyncPwaBackGesture = {
    // Keep the old bridge callable while cached Flutter bundles are replaced.
    setDetailActive: () => {},
    enabled: false,
    version: 'guard_v4',
    edgeWidth: 32,
  };
  const ios = /iPhone|iPad|iPod/.test(navigator.userAgent) ||
    (/Macintosh/.test(navigator.userAgent) && navigator.maxTouchPoints > 1);
  const standalone = navigator.standalone === true ||
    window.matchMedia('(display-mode: standalone)').matches;
  window.ysyncPwaBackGesture.enabled = ios && standalone;
  if (!ios || !standalone) return;
  document.addEventListener('touchstart', event => {
    // 다중 터치는 확대·축소 같은 다른 동작이므로 건드리지 않습니다.
    if (event.touches.length !== 1) return;
    const x = event.touches[0].clientX;
    if (!(x >= 0 && x <= window.ysyncPwaBackGesture.edgeWidth)) return;
    if (!event.cancelable) return;
    // Do not stop propagation: Flutter still needs the pointer/gesture stream.
    event.preventDefault();
  }, { passive: false });
})();
