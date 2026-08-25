import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y_sync/screens/login_screen.dart';
import 'package:y_sync/screens/pin_setup_screen.dart';
import 'package:y_sync/screens/signup_screen.dart';
import 'package:y_sync/screens/social_signup_screen.dart';

void main() {
  testWidgets('로그인은 학번 로그인과 Google 로그인을 구분해 제공한다', (tester) async {
    _setMobileViewport(tester);
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Y-Sync'), findsOneWidget);
    expect(find.text('학번'), findsOneWidget);
    expect(find.text('로그인'), findsOneWidget);
    expect(find.text('Google로 계속'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('회원가입은 학생 확인 단계를 먼저 보여준다', (tester) async {
    _setMobileViewport(tester);
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SignupScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.text('학생 인증 회원가입'), findsOneWidget);
    expect(find.text('학생 정보 확인'), findsOneWidget);
    expect(find.text('이메일 본인 인증'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('소셜 가입은 계정 연결에 필요한 정보를 표시한다', (tester) async {
    _setMobileViewport(tester);
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: SocialSignupScreen(socialId: 'social-user', provider: 'GOOGLE'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('구글 계정 연동'), findsOneWidget);
    expect(find.text('추가 정보 입력'), findsOneWidget);
    expect(find.text('중복확인'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PIN 설정은 입력과 건너뛰기 동선을 함께 제공한다', (tester) async {
    _setMobileViewport(tester);
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: PinSetupScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.text('간편 PIN 설정 (선택)'), findsOneWidget);
    expect(find.text('PIN 번호 입력 (6자리)'), findsOneWidget);
    expect(find.text('설정 완료 및 시작'), findsOneWidget);
    expect(find.text('다음에 하기 (건너뛰기)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _setMobileViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
