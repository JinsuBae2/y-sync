import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';

final isDemoAccountProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).asData?.value?.isDemo ?? false;
});

bool blockDemoChange(BuildContext context, WidgetRef ref) {
  if (!ref.read(isDemoAccountProvider)) return false;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('데모 계정에서는 변경할 수 없습니다.')),
  );
  return true;
}

class DemoReadOnlyScreen extends StatelessWidget {
  const DemoReadOnlyScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('데모 계정')),
    body: const Center(child: Text('데모 계정에서는 변경할 수 없습니다.')),
  );
}
