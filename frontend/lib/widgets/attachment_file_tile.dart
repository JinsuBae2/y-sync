import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/attachment.dart';
import '../theme/app_design_tokens.dart';
import '../utils/image_url_helper.dart';

class AttachmentFileTile extends StatelessWidget {
  const AttachmentFileTile({super.key, required this.attachment});

  final Attachment attachment;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _open(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppDesignTokens.divider),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.insert_drive_file_outlined,
                  color: AppDesignTokens.blue,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        attachment.originalFilename,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppDesignTokens.navy,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (attachment.size case final size?) ...[
                        const SizedBox(height: 2),
                        Text(
                          _formatBytes(size),
                          style: const TextStyle(
                            color: AppDesignTokens.muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(
                  Icons.download_rounded,
                  color: AppDesignTokens.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final baseUri = Uri.parse(getCleanImageUrl(attachment.url));
    final uri = baseUri.replace(
      queryParameters: {
        ...baseUri.queryParameters,
        'name': attachment.originalFilename,
      },
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('첨부파일을 열 수 없습니다.')));
    }
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
