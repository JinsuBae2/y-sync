import 'package:flutter/material.dart';

import 'app_confirmation_dialog.dart';

Future<void> showAttachmentSelectionIssue(BuildContext context, String issue) =>
    showDialog<void>(
      context: context,
      barrierColor: AppConfirmationDialog.barrierColor,
      builder: (dialogContext) => AppConfirmationDialog(
        title: '첨부파일을 확인해주세요',
        icon: Icons.attach_file_rounded,
        content: Text(issue),
        actions: [
          AppDialogAction(
            label: '확인',
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );
