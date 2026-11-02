import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y_sync/providers/api_client_provider.dart';
import 'package:y_sync/providers/community_provider.dart';
import 'package:y_sync/providers/notice_provider.dart';

class DelayedSaveAdapter implements HttpClientAdapter {
  final received = Completer<void>();
  final saved = Completer<void>();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    await requestStream!.drain<void>();
    received.complete();
    await saved.future;
    return ResponseBody.fromString(
      '{}',
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  for (final kind in [
    'notice create',
    'notice update',
    'community create',
    'community update',
  ]) {
    test('$kind 전송 콜백을 전달하며 응답 전에는 저장 완료되지 않는다', () async {
      final adapter = DelayedSaveAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final container = ProviderContainer(
        overrides: [dioProvider.overrideWithValue(dio)],
      );
      addTearDown(container.dispose);
      addTearDown(dio.close);
      final progress = <(int, int)>[];
      void onProgress(int sent, int total) => progress.add((sent, total));
      final notice = container.read(noticeNotifierProvider);
      final community = container.read(communityNotifierProvider);
      final request = switch (kind) {
        'notice create' => notice.createNotice(
          '제목',
          '내용',
          'NEWS',
          onSendProgress: onProgress,
        ),
        'notice update' => notice.updateNotice(
          1,
          '제목',
          '내용',
          'NEWS',
          onSendProgress: onProgress,
        ),
        'community create' => community.createPost(
          category: 'FREE',
          title: '제목',
          content: '내용',
          anonymous: false,
          targetGrade: 'ALL',
          onSendProgress: onProgress,
        ),
        _ => community.updatePost(
          id: 1,
          category: 'FREE',
          title: '제목',
          content: '내용',
          anonymous: false,
          targetGrade: 'ALL',
          onSendProgress: onProgress,
        ),
      };
      var completed = false;
      final tracked = request.then((_) => completed = true);
      await adapter.received.future;
      expect(progress, isNotEmpty);
      expect(progress.last.$1, progress.last.$2);
      expect(progress.last.$2, greaterThan(0));
      expect(completed, isFalse);
      adapter.saved.complete();
      await tracked;
      expect(completed, isTrue);
    });
  }
}
