import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_design_tokens.dart';

class ContentFilterBar extends StatelessWidget {
  const ContentFilterBar({
    super.key,
    required this.label,
    required this.icon,
    required this.options,
    required this.selectedValue,
    required this.onChanged,
    this.isGlass = false,
  });

  final String label;
  final IconData icon;
  final List<(String, String)> options;
  final String selectedValue;
  final ValueChanged<String> onChanged;
  final bool isGlass;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          SizedBox(
            width: 46,
            child: Row(
              children: [
                Icon(icon, size: 16, color: AppDesignTokens.muted),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppDesignTokens.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: isGlass
                ? Row(
                    children: [
                      for (final option in options)
                        Expanded(
                          child: _FilterOption(
                            label: option.$2,
                            selected: option.$1 == selectedValue,
                            isGlass: true,
                            onTap: () => onChanged(option.$1),
                          ),
                        ),
                    ],
                  )
                : Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: AppDesignTokens.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppDesignTokens.divider),
                    ),
                    child: Row(
                      children: [
                        for (final option in options)
                          Expanded(
                            child: _FilterOption(
                              label: option.$2,
                              selected: option.$1 == selectedValue,
                              isGlass: false,
                              onTap: () => onChanged(option.$1),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterOption extends StatelessWidget {
  const _FilterOption({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.isGlass,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isGlass;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? AppDesignTokens.paleBlue.withValues(alpha: isGlass ? 0.5 : 1)
                : isGlass
                ? Colors.white.withValues(alpha: 0.22)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isGlass
                ? Border.all(color: Colors.white.withValues(alpha: 0.78))
                : null,
            boxShadow: isGlass
                ? [
                    BoxShadow(
                      color: AppDesignTokens.navy.withValues(alpha: 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? AppDesignTokens.blue : AppDesignTokens.muted,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );

    if (!isGlass) return button;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: button,
        ),
      ),
    );
  }
}
