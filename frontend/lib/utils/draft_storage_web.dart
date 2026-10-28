import 'dart:js_interop';

@JS('localStorage.getItem')
external JSString? _read(JSString key);
@JS('localStorage.setItem')
external void _write(JSString key, JSString value);
@JS('localStorage.removeItem')
external void _remove(JSString key);

String? readDraft(String key) => _read(key.toJS)?.toDart;
void writeDraft(String key, String value) => _write(key.toJS, value.toJS);
void removeDraft(String key) => _remove(key.toJS);
