import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_design_tokens.dart';

class SelectedAttachmentList extends StatelessWidget {
  const SelectedAttachmentList({
    super.key,
    required this.files,
    required this.onRemove,
  });

  final List<PlatformFile> files;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < files.length; index++) ...[
          _SelectedAttachment(
            file: files[index],
            onRemove: () => onRemove(index),
          ),
          if (index < files.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _SelectedAttachment extends StatelessWidget {
  const _SelectedAttachment({required this.file, required this.onRemove});

  final PlatformFile file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final preview = _imagePreview(file);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 48,
              height: 48,
              child:
                  preview ??
                  const ColoredBox(
                    color: AppDesignTokens.paleBlue,
                    child: Icon(
                      Icons.insert_drive_file_outlined,
                      color: AppDesignTokens.blue,
                    ),
                  ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppDesignTokens.navy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _formatBytes(file.size),
                  style: const TextStyle(
                    color: AppDesignTokens.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            tooltip: '첨부 삭제',
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

Widget? _imagePreview(PlatformFile file) {
  const imageExtensions = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'};
  if (!imageExtensions.contains(file.extension?.toLowerCase())) return null;
  final bytes = file.bytes;
  if (bytes != null) return Image.memory(bytes, fit: BoxFit.cover);
  if (!kIsWeb && file.path != null) {
    return Image.file(File(file.path!), fit: BoxFit.cover);
  }
  return null;
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
