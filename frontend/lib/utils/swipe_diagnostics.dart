import 'package:flutter/widgets.dart';

import 'swipe_diagnostics_stub.dart'
    if (dart.library.js_interop) 'swipe_diagnostics_web.dart'
    as platform;

void initializeSwipeDiagnostics() {
  if (const bool.fromEnvironment('SWIPE_DIAGNOSTICS')) {
    platform.enableSwipeDiagnostics();
  }
  recordSwipeEvent('flutter_start', 'flutter_v2');
}

void recordSwipeEvent(String event, [String detail = '']) {
  platform.recordSwipeEvent(event, detail);
}

/// Only list endpoint categories are recorded; never request contents.
String? swipeListCategory(String path) {
  final normalized = path.split('?').first;
  if (normalized == '/notices' || normalized == '/notices/search') {
    return 'notice';
  }
  if (normalized == '/community' || normalized == '/community/search') {
    return 'community';
  }
  return null;
}

class SwipeDiagnosticsObserver extends NavigatorObserver {
  SwipeDiagnosticsObserver({this.record = recordSwipeEvent});

  final void Function(String, String) record;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    record('route_push', '');
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    record('route_pop', '');
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    record('route_replace', '');
  }

  @override
  void didStartUserGesture(
    Route<dynamic> route,
    Route<dynamic>? previousRoute,
  ) {
    record('gesture_start', '');
  }

  @override
  void didStopUserGesture() {
    record('gesture_stop', '');
  }
}
