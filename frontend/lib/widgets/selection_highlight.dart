import 'package:flutter/material.dart';

import '../theme/app_design_tokens.dart';

class SelectionHighlight extends StatelessWidget {
  const SelectionHighlight({
    super.key,
    required this.selected,
    required this.child,
  });

  final bool selected;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: selected ? AppDesignTokens.paleBlue : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
    ),
    child: child,
  );
}
