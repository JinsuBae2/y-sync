import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PWA 핵심 파일은 Firebase Hosting에서 항상 재검증한다', () {
    final config = jsonDecode(File('firebase.json').readAsStringSync());
    final rules = config['hosting']['headers'] as List<dynamic>;
    final cacheControls = <String, String>{
      for (final rule in rules.cast<Map<String, dynamic>>())
        rule['source'] as String:
            (rule['headers'] as List<dynamic>)
                    .cast<Map<String, dynamic>>()
                    .firstWhere(
                      (header) => header['key'] == 'Cache-Control',
                    )['value']
                as String,
    };

    for (final source in [
      '/',
      '/index.html',
      '/flutter_service_worker.js',
      '/flutter_bootstrap.js',
      '/main.dart.js',
      '/version.json',
      '/manifest.json',
    ]) {
      expect(cacheControls[source], contains('no-cache'), reason: source);
    }

    expect(cacheControls['/'], contains('no-store'));
    expect(cacheControls['/flutter_service_worker.js'], contains('no-store'));
  });

  test('데스크톱 PWA는 버전된 천마 아이콘을 참조한다', () {
    final manifest = jsonDecode(File('web/manifest.json').readAsStringSync());
    final iconSources = (manifest['icons'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map((icon) => icon['src'] as String)
        .toList();
    final indexHtml = File('web/index.html').readAsStringSync();

    expect(iconSources, hasLength(4));
    for (final source in iconSources) {
      expect(source, contains('cheonma-v2'));
      expect(File('web/$source').existsSync(), isTrue, reason: source);
    }
    expect(indexHtml, contains('favicon-cheonma-v2.png'));
    expect(indexHtml, contains('manifest.json?v=cheonma-v2'));
  });
}
