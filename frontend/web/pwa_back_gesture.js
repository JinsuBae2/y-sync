// Let Flutter own the back gesture instead of also navigating WebKit history.
(() => {
  window.ysyncPwaBackGesture = {
    // Keep the old bridge callable while cached Flutter bundles are replaced.
    setDetailActive: () => {},
    enabled: false,
  };
  const ios = /iPhone|iPad|iPod/.test(navigator.userAgent) ||
    (/Macintosh/.test(navigator.userAgent) && navigator.maxTouchPoints > 1);
  const standalone = navigator.standalone === true ||
    window.matchMedia('(display-mode: standalone)').matches;
  window.ysyncPwaBackGesture.enabled = ios && standalone;
  if (!ios || !standalone) return;
  document.addEventListener('touchstart', event => {
    if (event.cancelable && event.touches.length === 1 &&
        event.touches[0].clientX >= 0 && event.touches[0].clientX <= 20) {
      // Do not stop propagation: Flutter still needs the pointer/gesture stream.
      event.preventDefault();
    }
  }, { passive: false });
})();
