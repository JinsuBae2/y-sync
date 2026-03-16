import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/notice_list_screen.dart';

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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: authState.when(
        data: (member) {
          if (member == null) {
            return const LoginScreen();
          }
          return const NoticeListScreen();
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
