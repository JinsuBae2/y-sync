import 'dart:js_interop';

@JS('ysyncSwipeDiagnostics.enable')
external void _enable();

@JS('ysyncSwipeDiagnostics.record')
external void _record(JSString event, JSString detail);

void enableSwipeDiagnostics() {
  try {
    _enable();
  } catch (_) {
    // An older cached index may not have loaded the optional diagnostic script.
  }
}

void recordSwipeEvent(String event, String detail) {
  try {
    _record(event.toJS, detail.toJS);
  } catch (_) {
    // Diagnostics must never interrupt navigation or requests.
  }
}
