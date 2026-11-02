import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/draft_storage_stub.dart'
    if (dart.library.js_interop) '../utils/draft_storage_web.dart'
    as storage;

final draftStoreProvider = Provider<DraftStore?>(
  (ref) => kIsWeb ? DraftStore() : null,
);

class DraftStore {
  String? read(String key) => storage.readDraft(key);
  void write(String key, String value) => storage.writeDraft(key, value);
  void remove(String key) => storage.removeDraft(key);
}

/// Synchronous writes retain the last edit even when the tab closes immediately.
class WritingDraft extends ValueNotifier<String> {
  WritingDraft(
    this.store, {
    required int memberId,
    required String kind,
    int? postId,
  }) : key = 'y-sync:draft:v1:$memberId:$kind:${postId ?? 'new'}',
       super('입력 내용은 이 브라우저에 자동 저장됩니다. 첨부파일은 복원되지 않습니다.');

  final DraftStore store;
  final String key;
  bool _finished = false;
  String? _lastValue;

  Map<String, dynamic>? restore() {
    try {
      final raw = store.read(key);
      if (raw == null) return null;
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic> ||
          data['title'] is! String ||
          data['content'] is! String) {
        throw const FormatException('Invalid draft');
      }
      _lastValue = raw;
      value = '이전에 작성하던 초안을 복원했습니다. 첨부파일은 다시 선택해주세요.';
      return data;
    } on FormatException {
      value = '저장된 초안을 읽지 못했습니다. 새로 입력하는 내용부터 저장합니다.';
      return null;
    } catch (_) {
      value = '초안 저장소에 접근할 수 없습니다. 이 화면을 닫으면 입력 내용이 사라질 수 있습니다.';
      return null;
    }
  }

  void save(Map<String, dynamic> data, {required bool hasChanges}) {
    if (_finished) return;
    try {
      if (!hasChanges) {
        store.remove(key);
        _lastValue = null;
        value = '입력 내용은 이 브라우저에 자동 저장됩니다. 첨부파일은 복원되지 않습니다.';
        return;
      }
      final encoded = jsonEncode(data);
      if (encoded == _lastValue) return;
      store.write(key, encoded);
      _lastValue = encoded;
      value = '초안이 이 브라우저에 저장되었습니다. 첨부파일은 복원되지 않습니다.';
    } catch (_) {
      value = '초안을 저장하지 못했습니다. 저장 공간이나 브라우저 설정을 확인하고, 화면을 닫기 전에 내용을 복사해주세요.';
    }
  }

  bool discard() {
    try {
      store.remove(key);
      _finished = true;
      return true;
    } catch (_) {
      value = '초안을 지우지 못했습니다. 브라우저 저장소 설정을 확인한 뒤 다시 시도해주세요.';
      return false;
    }
  }

  bool complete() {
    final cleared = discard();
    _finished = true;
    return cleared;
  }
}
