import 'dart:js_interop';

@JS('ysyncPwaBackGesture.setDetailActive')
external void _setDetailActive(JSBoolean active);

void setDetailBackGestureActive(bool active) {
  try {
    _setDetailActive(active.toJS);
  } catch (_) {
    // Older cached HTML may not have loaded the bridge yet.
  }
}
