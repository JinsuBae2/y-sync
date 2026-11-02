import 'dart:js_interop';

@JS('Notification')
external JSObject? get _notification;

@JS('Notification.permission')
external JSString get _permission;

@JS('isSecureContext')
external JSBoolean get _isSecureContext;

String readNotificationPermission() {
  try {
    if (_notification == null || !_isSecureContext.toDart) {
      return 'unsupported';
    }
    return _permission.toDart;
  } catch (_) {
    return 'unknown';
  }
}
