import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y_sync/providers/api_client_provider.dart';
import 'package:y_sync/providers/auth_provider.dart';

/// 💡 가입 인증 증표가 클라이언트에서 올바르게 전달되는지 고정합니다.
///
/// 증표는 인증 응답에만 실려 오며, 가입 요청에 그대로 실어 보내야 합니다.
/// 서버가 증표를 요구하므로 클라이언트가 이를 흘리면 정상 가입이 막힙니다.
void main() {
  late List<RequestOptions> sent;
  late Dio dio;

  ProviderContainer containerWith(Map<String, dynamic> verifyResponse) {
    sent = [];
    dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    dio.httpClientAdapter = _StubAdapter(sent, verifyResponse);
    final container = ProviderContainer(
      overrides: [dioProvider.overrideWithValue(dio)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('인증 응답의 증표를 읽어 돌려준다', () async {
    final container = containerWith({
      'success': true,
      'verificationGrant': 'grant-abc',
      'message': '인증이 성공적으로 완료되었습니다.',
    });

    final grant = await container
        .read(authProvider.notifier)
        .verifyCode('2305001', '123456');

    expect(grant, 'grant-abc');
  });

  test('인증에 실패하면 증표를 만들어내지 않는다', () async {
    final container = containerWith({'success': false});

    final grant = await container
        .read(authProvider.notifier)
        .verifyCode('2305001', '000000');

    expect(grant, isNull);
  });

  test('증표를 내려주지 않는 구버전 응답도 증표 없음으로 다룬다', () async {
    // 증표 없이 가입을 시도하면 서버가 거부하므로, 없는 값을 지어내면 안 됩니다.
    final container = containerWith({'success': true});

    final grant = await container
        .read(authProvider.notifier)
        .verifyCode('2305001', '123456');

    expect(grant, isNull);
  });

  test('가입 요청에 증표를 그대로 실어 보낸다', () async {
    final container = containerWith({
      'success': true,
      'verificationGrant': 'g',
    });

    await container
        .read(authProvider.notifier)
        .signup('2305001', 'Strong1234!', '학생', verificationGrant: 'grant-abc');

    final signupRequest = sent.firstWhere((r) => r.path == '/auth/signup');
    final body = signupRequest.data as Map<String, dynamic>;
    expect(body['verificationGrant'], 'grant-abc');
    expect(body['loginId'], '2305001');
  });
}

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.sent, this.verifyResponse);

  final List<RequestOptions> sent;
  final Map<String, dynamic> verifyResponse;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    sent.add(options);
    final body = options.path.contains('verify-code')
        ? verifyResponse
        : <String, dynamic>{'message': '회원가입 성공'};
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}
