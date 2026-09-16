import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'pwa_back_gesture_stub.dart'
    if (dart.library.js_interop) 'pwa_back_gesture_web.dart'
    as platform;

// A type marker avoids changing route names or browser URLs.
class _ContentDetailRoute<T> extends CupertinoPageRoute<T> {
  _ContentDetailRoute({required super.builder});
}

class PwaDetailBackGestureObserver extends NavigatorObserver {
  PwaDetailBackGestureObserver({
    this.setActive = platform.setDetailBackGestureActive,
  });

  final void Function(bool) setActive;

  @override
  void didChangeTop(Route<dynamic> topRoute, Route<dynamic>? previousTopRoute) {
    setActive(topRoute is _ContentDetailRoute);
  }
}

PageRoute<T> adaptivePageRoute<T>({required WidgetBuilder builder}) {
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    return _ContentDetailRoute<T>(builder: builder);
  }
  return MaterialPageRoute<T>(builder: builder);
}
