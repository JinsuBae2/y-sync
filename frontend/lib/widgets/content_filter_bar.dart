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
  });

  final String label;
  final IconData icon;
  final List<(String, String)> options;
  final String selectedValue;
  final ValueChanged<String> onChanged;

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
            child: Container(
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
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppDesignTokens.paleBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
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
  }
}
