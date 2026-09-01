import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y_sync/utils/adaptive_page_route.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('iOS는 가장자리 스와이프가 가능한 Cupertino 라우트를 사용한다', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    final route = adaptivePageRoute<void>(
      builder: (_) => const SizedBox.shrink(),
    );

    expect(route, isA<CupertinoPageRoute<void>>());
  });

  for (final platform in <TargetPlatform>[
    TargetPlatform.android,
    TargetPlatform.fuchsia,
    TargetPlatform.linux,
    TargetPlatform.macOS,
    TargetPlatform.windows,
  ]) {
    test('$platform은 Material 라우트를 유지한다', () {
      debugDefaultTargetPlatformOverride = platform;

      final route = adaptivePageRoute<void>(
        builder: (_) => const SizedBox.shrink(),
      );

      expect(route, isA<MaterialPageRoute<void>>());
    });
  }
}
