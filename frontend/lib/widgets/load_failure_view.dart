import 'package:flutter/material.dart';

import '../theme/app_design_tokens.dart';

class LoadFailureView extends StatelessWidget {
  const LoadFailureView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            color: AppDesignTokens.muted,
            size: 32,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppDesignTokens.navy,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '잠시 후 다시 시도해주세요.',
            style: TextStyle(color: AppDesignTokens.muted),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('다시 시도'),
            style: TextButton.styleFrom(foregroundColor: AppDesignTokens.blue),
          ),
        ],
      ),
    ),
  );
}
