import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'screens/splash_screen.dart';
import 'services/push_notification_service.dart'; // 💡 FCM 추가
import 'widgets/server_availability_gate.dart';
import 'utils/back_navigation_loading.dart';

final _backLoadingObserver = BackNavigationLoadingObserver();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 💡 Firebase 환경 초기화
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 💡 FCM 알림 서비스는 fire-and-forget으로 실행 (await 하지 않음)
  // 모바일 사파리 등에서 requestPermission() 블로킹 시에도 runApp()은 즉시 실행됩니다.
  PushNotificationService().initialize();

  // 💡 한국어 포맷팅 지역화 데이터 초기화
  await initializeDateFormatting('ko_KR', null);

  runApp(const ProviderScope(child: YSyncApp()));
}

class YSyncApp extends ConsumerWidget {
  const YSyncApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 💡 값을 쓰지는 않지만 구독은 유지해야 합니다. 이 watch가 앱 시작 시 로그인 상태 확인을
    //    시작시키고, 계정이 바뀌면 앱 셸이 다시 그려집니다. 지우면 두 동작이 사라집니다.
    ref.watch(authProvider);

    return MaterialApp(
      navigatorObservers: [_backLoadingObserver],
      navigatorKey:
          PushNotificationService.navigatorKey, // 💡 전역 라우팅을 위한 네비게이터 키 등록
      title: 'Y-Sync',
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ko', 'KR'), Locale('en', 'US')],
      locale: const Locale('ko', 'KR'),
      builder: (context, child) =>
          ServerAvailabilityGate(child: child ?? const SizedBox.shrink()),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF164687), // 브랜드 컬러 #164687
          primary: const Color(0xFF164687),
          secondary: const Color(0xFFFFC107), // Amber
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF164687),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 4,
          shadowColor: Colors.black.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
