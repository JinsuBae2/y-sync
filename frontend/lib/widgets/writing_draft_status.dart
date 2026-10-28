import 'package:flutter/material.dart';

import '../services/writing_draft.dart';
import '../theme/app_design_tokens.dart';

class WritingDraftStatus extends StatelessWidget {
  const WritingDraftStatus({super.key, required this.draft});
  final WritingDraft? draft;

  @override
  Widget build(BuildContext context) => draft == null
      ? const SizedBox.shrink()
      : ValueListenableBuilder<String>(
          valueListenable: draft!,
          builder: (context, message, _) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              message,
              style: const TextStyle(
                color: AppDesignTokens.muted,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        );
}
