import 'package:flutter/widgets.dart';

import '../utils/back_navigation_loading.dart';

class AppRootBackGuard extends StatelessWidget {
  const AppRootBackGuard({
    super.key,
    required this.enabled,
    required this.child,
  });

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !enabled,
    onPopInvokedWithResult: (didPop, result) {
      if (enabled && !didPop) completeRootBackLoading();
    },
    child: child,
  );
}
