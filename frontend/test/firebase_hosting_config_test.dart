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
}
