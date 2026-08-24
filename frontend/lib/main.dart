import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_tab_screen.dart';
import 'screens/splash_screen.dart';
import 'services/push_notification_service.dart'; // 💡 FCM 추가

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
    final authState = ref.watch(authProvider);

    return MaterialApp(
      navigatorKey:
          PushNotificationService.navigatorKey, // 💡 전역 라우팅을 위한 네비게이터 키 등록
      title: 'Y-Sync',
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ko', 'KR'),
        Locale('en', 'US'),
      ],
      locale: const Locale('ko', 'KR'),
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
          shadowColor: Colors.black.withOpacity(0.1),
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
