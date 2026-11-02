import 'package:flutter/material.dart';

import '../theme/app_design_tokens.dart';

class AppDialogAction {
  const AppDialogAction({
    required this.label,
    required this.onPressed,
    this.destructive = false,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool destructive;
  final bool isLoading;
}

class AppConfirmationDialog extends StatelessWidget {
  static const barrierColor = Color(0x6110213F);

  const AppConfirmationDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
    this.icon = Icons.help_outline_rounded,
    this.primaryActionIndex,
    this.onClose,
    this.closeLabel = '닫기',
    this.autofocusPrimary = false,
  }) : assert(actions.length > 0),
       assert(
         primaryActionIndex == null ||
             (primaryActionIndex >= 0 && primaryActionIndex < actions.length),
       );

  final String title;
  final Widget content;
  final List<AppDialogAction> actions;
  final IconData icon;
  final int? primaryActionIndex;
  final VoidCallback? onClose;
  final String closeLabel;
  final bool autofocusPrimary;

  @override
  Widget build(BuildContext context) {
    final primary = primaryActionIndex ?? actions.length - 1;
    final order = [
      primary,
      for (var i = 0; i < actions.length; i++)
        if (i != primary) i,
    ];
    return Dialog(
      backgroundColor: AppDesignTokens.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppDesignTokens.paleBlue,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              icon,
                              color: AppDesignTokens.blue,
                              size: 26,
                            ),
                          ),
                          const Spacer(),
                          if (onClose != null)
                            IconButton(
                              tooltip: closeLabel,
                              onPressed: onClose,
                              icon: const Icon(
                                Icons.close_rounded,
                                color: AppDesignTokens.muted,
                                size: 20,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Semantics(
                        header: true,
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppDesignTokens.navy,
                            letterSpacing: -0.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      DefaultTextStyle.merge(
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.6,
                          color: AppDesignTokens.muted,
                        ),
                        child: content,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              for (final index in order) ...[
                if (index != primary) const SizedBox(height: 8),
                if (index == primary)
                  FilledButton(
                    autofocus: autofocusPrimary,
                    onPressed: actions[index].onPressed,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppDesignTokens.blue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: actions[index].isLoading
                        ? Semantics(
                            label: '${actions[index].label} 중',
                            child: const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            actions[index].label,
                            textAlign: TextAlign.center,
                          ),
                  )
                else
                  TextButton(
                    onPressed: actions[index].onPressed,
                    style: TextButton.styleFrom(
                      foregroundColor: actions[index].destructive
                          ? const Color(0xFFB42318)
                          : AppDesignTokens.muted,
                      minimumSize: const Size.fromHeight(44),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      actions[index].label,
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
