import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y_sync/providers/server_availability_provider.dart';
import 'package:y_sync/screens/server_maintenance_screen.dart';
import 'package:y_sync/widgets/server_availability_gate.dart';

void main() {
  test('서버 장애로 처리할 네트워크 오류를 구분한다', () {
    for (final type in [
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.connectionError,
    ]) {
      expect(
        isServerUnavailableError(
          DioException(requestOptions: RequestOptions(), type: type),
        ),
        isTrue,
      );
    }

    expect(
      isServerUnavailableError(
        DioException(
          requestOptions: RequestOptions(),
          type: DioExceptionType.cancel,
        ),
      ),
      isFalse,
    );
  });

  testWidgets('점검 화면은 자동 복구 안내와 수동 재시도를 제공한다', (tester) async {
    var healthCheckCount = 0;
    _setMobileViewport(tester);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serverHealthCheckProvider.overrideWithValue(() async {
            healthCheckCount += 1;
            return false;
          }),
        ],
        child: const MaterialApp(home: ServerMaintenanceScreen()),
      ),
    );

    expect(find.bySemanticsLabel('Y-Sync 천마 로고'), findsOneWidget);
    expect(find.text('잠시 점검 중이에요'), findsOneWidget);
    expect(find.textContaining('자동으로 다시 연결'), findsOneWidget);
    expect(find.byKey(const Key('maintenanceRetryButton')), findsOneWidget);

    await tester.tap(find.byKey(const Key('maintenanceRetryButton')));
    await tester.pump();
    expect(healthCheckCount, 1);

    await tester.pump(const Duration(seconds: 10));
    expect(healthCheckCount, 2);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('서버 장애 상태에서 기존 화면 위에 점검 화면을 표시한다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serverAvailabilityProvider.overrideWith(
            () => _UnavailableServerNotifier(),
          ),
          serverHealthCheckProvider.overrideWithValue(() async => false),
        ],
        child: const MaterialApp(
          home: ServerAvailabilityGate(child: Text('기존 화면')),
        ),
      ),
    );

    expect(find.text('기존 화면'), findsOneWidget);
    expect(find.text('잠시 점검 중이에요'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _UnavailableServerNotifier extends ServerAvailabilityNotifier {
  @override
  ServerAvailability build() => ServerAvailability.unavailable;
}

void _setMobileViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
