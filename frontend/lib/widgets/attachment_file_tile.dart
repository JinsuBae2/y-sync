import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/attachment.dart';
import '../theme/app_design_tokens.dart';
import '../utils/image_url_helper.dart';
import 'app_confirmation_dialog.dart';

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
    var opened = false;
    var invalidAddress = false;
    try {
      final baseUri = Uri.parse(getCleanImageUrl(attachment.url));
      final uri = baseUri.replace(
        queryParameters: {
          ...baseUri.queryParameters,
          'name': attachment.originalFilename,
        },
      );
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on FormatException {
      invalidAddress = true;
    } catch (_) {
      // 플랫폼 예외도 사용자에게 복구 동선을 제공합니다.
    }
    if (opened || !context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierColor: AppConfirmationDialog.barrierColor,
      builder: (dialogContext) => AppConfirmationDialog(
        title: '첨부파일을 열지 못했습니다',
        icon: Icons.file_open_outlined,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(attachment.originalFilename),
            const SizedBox(height: 12),
            Text(
              invalidAddress ? '파일 주소가 올바르지 않습니다. 게시글 작성자에게 파일 확인을 요청해주세요.' : '다시 시도해주세요. 브라우저가 새 창을 차단했다면 팝업 차단 설정을 확인해주세요.\n\n계속 실패하면 게시글 작성자에게 파일 확인을 요청해주세요.',
            ),
          ],
        ),
        actions: [
          AppDialogAction(
            label: '닫기',
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
          if (!invalidAddress)
            AppDialogAction(
              label: '다시 시도',
              onPressed: () {
                Navigator.of(dialogContext).pop();
                // 새 창 열기는 웹의 사용자 클릭 처리 안에서 바로 시작해야 합니다.
                if (context.mounted) _open(context);
              },
            ),
        ],
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
