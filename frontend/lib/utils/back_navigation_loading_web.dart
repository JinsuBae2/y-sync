import 'dart:js_interop';

@JS('ysyncBackLoading.token')
external JSNumber? get _token;
@JS('ysyncBackLoading.complete')
external void _complete(JSNumber token);

int currentBackLoadingToken() {
  try {
    return _token?.toDartInt ?? 0;
  } catch (_) {
    return 0;
  }
}

void completeBackLoading(int token) {
  try {
    _complete(token.toJS);
  } catch (_) {
    // Older HTML may not have the optional loading bridge.
  }
}
