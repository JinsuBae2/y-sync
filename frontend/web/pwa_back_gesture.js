// Let Flutter own the detail back gesture instead of also navigating WebKit history.
(() => {
  let detailActive = false;
  window.ysyncPwaBackGesture = {
    setDetailActive: value => { detailActive = value === true; },
  };
  const ios = /iPhone|iPad|iPod/.test(navigator.userAgent) ||
    (/Macintosh/.test(navigator.userAgent) && navigator.maxTouchPoints > 1);
  const standalone = navigator.standalone === true ||
    window.matchMedia('(display-mode: standalone)').matches;
  if (!ios || !standalone) return;
  document.addEventListener('touchstart', event => {
    if (detailActive && event.cancelable && event.touches.length === 1 &&
        event.touches[0].clientX >= 0 && event.touches[0].clientX <= 20) {
      // Do not stop propagation: Flutter still needs the pointer/gesture stream.
      event.preventDefault();
    }
  }, { passive: false });
})();
