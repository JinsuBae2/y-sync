import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_design_tokens.dart';
import 'app_confirmation_dialog.dart';

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
            key: ObjectKey(files[index]),
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
  const _SelectedAttachment({
    super.key,
    required this.file,
    required this.onRemove,
  });

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
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _showDetails(context),
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
                        // 💡 file_picker 13에는 size가 없습니다. lengthSync()는 피커가 알려준 값을
                        //    I/O 없이 돌려주고, 모르면 null입니다. 빌드 중이라 디스크를 읽지 않고
                        //    모르는 경우에는 크기 줄을 숨깁니다.
                        if (file.lengthSync() case final size?) ...[
                          const SizedBox(height: 3),
                          Text(
                            '${_formatBytes(size)} · 눌러서 확인',
                            style: const TextStyle(
                              color: AppDesignTokens.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
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

  void _showDetails(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: AppConfirmationDialog.barrierColor,
      builder: (dialogContext) => AppConfirmationDialog(
        title: '첨부파일 확인',
        icon: Icons.attach_file_rounded,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            SelectableText(file.name),
            if (file.lengthSync() case final size?) ...[
              const SizedBox(height: 8),
              Text(_formatBytes(size)),
            ],
            if (_imagePreview(file, fit: BoxFit.contain)
                case final preview?) ...[
              const SizedBox(height: 16),
              SizedBox(height: 240, child: preview),
            ],
          ],
        ),
        actions: [
          AppDialogAction(
            label: '닫기',
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );
  }
}

Widget? _imagePreview(PlatformFile file, {BoxFit fit = BoxFit.cover}) {
  const imageExtensions = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'};
  if (!imageExtensions.contains(file.extension?.toLowerCase())) return null;
  final path = file.path;
  if (!kIsWeb && path != null) {
    return Image.file(File(path), fit: fit, errorBuilder: _imageError);
  }
  // 💡 웹에는 경로가 없고 file_picker 13에는 동기 bytes 게터도 없으므로 한 번 읽어서 씁니다.
  return _AsyncImagePreview(file: file, fit: fit);
}

/// 파일 바이트를 한 번만 읽어 미리보기를 그립니다.
///
/// build 안에서 readAsBytes()를 부르면 리빌드마다 다시 읽게 되므로 initState에서 한 번만 읽습니다.
class _AsyncImagePreview extends StatefulWidget {
  const _AsyncImagePreview({required this.file, required this.fit});

  final BoxFit fit;

  final PlatformFile file;

  @override
  State<_AsyncImagePreview> createState() => _AsyncImagePreviewState();
}

class _AsyncImagePreviewState extends State<_AsyncImagePreview> {
  late final Future<Uint8List> _bytes = widget.file.readAsBytes();

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: _bytes,
    builder: (context, snapshot) {
      final bytes = snapshot.data;
      if (bytes != null) {
        return Image.memory(bytes, fit: widget.fit, errorBuilder: _imageError);
      }
      // 읽지 못했으면 이미지가 아닌 첨부와 같은 모양으로 둡니다. 읽는 중에는 아이콘 없이 배경만 둡니다.
      final failed = snapshot.connectionState == ConnectionState.done;
      return ColoredBox(
        color: AppDesignTokens.paleBlue,
        child: failed
            ? const Icon(
                Icons.insert_drive_file_outlined,
                color: AppDesignTokens.blue,
              )
            : null,
      );
    },
  );
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

Widget _imageError(
  BuildContext context,
  Object error,
  StackTrace? stackTrace,
) => const Center(
  child: Tooltip(
    message: '이미지 미리보기를 표시할 수 없습니다',
    child: Icon(Icons.broken_image_outlined, color: AppDesignTokens.muted),
  ),
);
