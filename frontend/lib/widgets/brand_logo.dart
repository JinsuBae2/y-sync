import 'package:flutter/material.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.size = 40,
    this.padding = 5,
    this.borderRadius,
  });

  final double size;
  final double padding;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'Y-Sync 천마 로고',
    child: Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7FF),
        borderRadius: BorderRadius.circular(borderRadius ?? size * 0.24),
      ),
      child: Image.asset(
        'assets/branding/cheonma_logo.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        excludeFromSemantics: true,
      ),
    ),
  );
}
