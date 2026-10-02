import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'back_navigation_loading_stub.dart'
    if (dart.library.js_interop) 'back_navigation_loading_web.dart'
    as platform;

Future<void> completeRootBackLoading() async {
  final token = platform.currentBackLoadingToken();
  if (token == 0) return;
  await SchedulerBinding.instance.endOfFrame;
  platform.completeBackLoading(token);
}

class BackNavigationLoadingObserver extends NavigatorObserver {
  BackNavigationLoadingObserver({
    this.capture = platform.currentBackLoadingToken,
    this.complete = platform.completeBackLoading,
  });

  final int Function() capture;
  final void Function(int) complete;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final token = capture();
    if (token == 0) return;
    _afterTransition(route, token);
  }

  Future<void> _afterTransition(Route<dynamic> route, int token) async {
    if (route is TransitionRoute<dynamic>) await route.completed;
    await SchedulerBinding.instance.endOfFrame;
    complete(token);
  }
}
