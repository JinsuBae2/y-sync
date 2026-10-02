import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PWA 핵심 파일은 Firebase Hosting에서 항상 재검증한다', () {
    final config = jsonDecode(File('firebase.json').readAsStringSync());
    final rules = config['hosting']['headers'] as List<dynamic>;
    // 💡 캐시 외의 헤더만 지정하는 규칙(보안 헤더 등)도 있으므로 Cache-Control이 있는 규칙만 모읍니다.
    final cacheControls = <String, String>{};
    for (final rule in rules.cast<Map<String, dynamic>>()) {
      for (final header in (rule['headers'] as List<dynamic>)
          .cast<Map<String, dynamic>>()) {
        if (header['key'] == 'Cache-Control') {
          cacheControls[rule['source'] as String] = header['value'] as String;
        }
      }
    }

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

  test('웹앱은 모든 경로에 보안 헤더를 내려준다', () {
    // API(nginx)에는 보안 헤더가 있었지만 정작 사용자가 접속하는 웹앱에는 없었습니다.
    // 특히 frame-ancestors/X-Frame-Options가 없으면 다른 사이트가 우리 화면을 덮어
    // 클릭을 가로챌 수 있습니다.
    final config = jsonDecode(File('firebase.json').readAsStringSync());
    final rules = (config['hosting']['headers'] as List<dynamic>)
        .cast<Map<String, dynamic>>();

    final global = rules.firstWhere((rule) => rule['source'] == '**');
    final headers = <String, String>{
      for (final header in (global['headers'] as List<dynamic>)
          .cast<Map<String, dynamic>>())
        header['key'] as String: header['value'] as String,
    };

    expect(headers['X-Frame-Options'], 'DENY');
    expect(headers['X-Content-Type-Options'], 'nosniff');
    expect(headers['Referrer-Policy'], isNotNull);
    expect(headers['Permissions-Policy'], isNotNull);

    final csp = headers['Content-Security-Policy'];
    expect(csp, isNotNull);
    expect(csp, contains("frame-ancestors 'none'"));
    expect(csp, contains("object-src 'none'"));
    expect(csp, contains("base-uri 'self'"));

    // 앱이 실제로 쓰는 출처는 허용되어야 합니다. 빠지면 운영에서 화면이 비거나
    // 첨부파일이 열리지 않습니다.
    expect(csp, contains('https://www.gstatic.com'));
    expect(csp, contains('https://fonts.gstatic.com'));
    expect(csp, contains('amazonaws.com'));
    expect(csp, contains('sslip.io'));
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
