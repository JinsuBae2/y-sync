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
      height: 36,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AppDesignTokens.paleBlue,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Icon(icon, size: 15, color: AppDesignTokens.blue),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppDesignTokens.blue,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: options.length,
              separatorBuilder: (_, _) => const SizedBox(width: 7),
              itemBuilder: (context, index) {
                final option = options[index];
                final selected = option.$1 == selectedValue;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onChanged(option.$1),
                    borderRadius: BorderRadius.circular(18),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppDesignTokens.blue
                            : AppDesignTokens.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: selected
                              ? AppDesignTokens.blue
                              : AppDesignTokens.divider,
                        ),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: AppDesignTokens.blue.withValues(
                                    alpha: 0.18,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        option.$2,
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : AppDesignTokens.muted,
                          fontSize: 12,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
