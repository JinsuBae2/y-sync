import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'pwa_back_gesture_stub.dart'
    if (dart.library.js_interop) 'pwa_back_gesture_web.dart'
    as platform;

PageRoute<T> adaptivePageRoute<T>({required WidgetBuilder builder}) {
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    return platform.isIosStandalonePwa()
        ? PwaCupertinoPageRoute<T>(builder: builder)
        : CupertinoPageRoute<T>(builder: builder);
  }
  return MaterialPageRoute<T>(builder: builder);
}

class PwaCupertinoPageRoute<T> extends CupertinoPageRoute<T> {
  PwaCupertinoPageRoute({required super.builder});

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final media = MediaQuery.of(context);
    // Flutter 3.41's Cupertino detector uses max(padding.left, 20).
    // Expand only its inherited padding; restore the real padding for content.
    return MediaQuery(
      data: media.copyWith(
        padding: media.padding.copyWith(left: math.max(media.padding.left, 32)),
      ),
      child: super.buildTransitions(
        context,
        animation,
        secondaryAnimation,
        MediaQuery(data: media, child: child),
      ),
    );
  }
}
