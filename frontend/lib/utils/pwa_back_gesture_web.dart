import 'dart:js_interop';

@JS('ysyncPwaBackGesture.enabled')
external JSBoolean? get _enabled;

bool isIosStandalonePwa() {
  try {
    return _enabled?.toDart ?? false;
  } catch (_) {
    // Older cached HTML may not have loaded the bridge yet.
    return false;
  }
}
