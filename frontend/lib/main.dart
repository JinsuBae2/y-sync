import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_tab_screen.dart';

void main() {
  runApp(
    const ProviderScope(
      child: YSyncApp(),
    ),
  );
}

class YSyncApp extends ConsumerWidget {
  const YSyncApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return MaterialApp(
      title: 'Y-Sync',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A237E), // Deep Navy
          primary: const Color(0xFF1A237E),
          secondary: const Color(0xFFFFC107), // Amber
        ),
        useMaterial3: true,
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
      home: authState.when(
        data: (member) {
          if (member == null) {
            return const LoginScreen();
          }
          return const MainTabScreen();
        },
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stack) => Scaffold(
          body: Center(child: Text('에러가 발생했습니다:\n$error')),
        ),
      ),
    );
  }
}
