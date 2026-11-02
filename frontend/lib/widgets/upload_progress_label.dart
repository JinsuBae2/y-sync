import 'package:flutter/material.dart';

import '../theme/app_design_tokens.dart';

/// 전송 완료와 서버 저장 완료를 구분해 표시합니다.
class UploadProgressLabel extends StatelessWidget {
  const UploadProgressLabel({
    super.key,
    required this.hasAttachments,
    this.sent,
    this.total,
  });

  final bool hasAttachments;
  final int? sent;
  final int? total;

  @override
  Widget build(BuildContext context) {
    final knownTotal = total != null && total! > 0;
    final progress = knownTotal && sent != null
        ? (sent! / total!).clamp(0.0, 1.0)
        : null;
    final saving = !hasAttachments || progress == 1;
    final label = saving
        ? '서버에 저장 중…'
        : sent == null
        ? '첨부파일 준비 중…'
        : progress == null
        ? '첨부파일 전송 중…'
        : '첨부파일 전송 중 ${(progress * 100).floor()}%';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            value: saving ? null : progress,
            strokeWidth: 2,
            color: AppDesignTokens.blue,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(color: AppDesignTokens.navy),
          ),
        ),
      ],
    );
  }
}
