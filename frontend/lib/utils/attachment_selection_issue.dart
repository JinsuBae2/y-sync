import 'package:file_picker/file_picker.dart';

import 'platform_file_size.dart';

/// 공지·커뮤니티의 동일한 첨부 제한을 파일별로 설명합니다.
Future<String?> attachmentSelectionIssue({
  required List<PlatformFile> existing,
  required List<PlatformFile> picked,
}) async {
  const mb = 1024 * 1024;
  final issues = <String>[];
  final selected = <String>[];
  final count = existing.length + picked.length;
  if (count > 10) {
    issues.add(
      '첨부 개수 초과: 기존 ${existing.length}개 + 선택 ${picked.length}개 = $count개\n최대 10개까지 첨부할 수 있습니다.',
    );
  }
  var total = 0;
  var allSizesKnown = true;
  for (final (files, prefix) in [(existing, '기존 첨부'), (picked, '선택한 파일')]) {
    for (final file in files) {
      int? size;
      try {
        size = await platformFileSize(file);
      } catch (_) {
        size = null;
      }
      if (size == null || size < 0) {
        allSizesKnown = false;
        issues.add('$prefix: ${file.name}\n크기를 확인할 수 없습니다. 파일을 다시 선택해주세요.');
      } else {
        total += size;
        if (size > 20 * mb) {
          issues.add(
            '$prefix: ${file.name}\n${_size(size)} — 파일당 20MB 제한을 초과했습니다.',
          );
        }
      }
      if (identical(files, picked)) {
        selected.add(
          '• ${file.name}${size != null && size >= 0 ? ' (${_size(size)})' : ''}',
        );
      }
    }
  }
  if (allSizesKnown && total > 50 * mb) {
    issues.add(
      '전체 용량 초과: ${_size(total)} / 최대 50MB\n기존 첨부를 포함한 합계입니다. 파일을 줄이거나 용량을 줄여주세요.',
    );
  }
  if (issues.isEmpty) return null;
  if (count > 10 || (allSizesKnown && total > 50 * mb)) {
    issues.add('이번에 선택한 파일\n${selected.join('\n')}');
  }
  return '${issues.join('\n\n')}\n\n이번에 선택한 파일은 추가되지 않았습니다. 기존 첨부는 유지됩니다.';
}

String _size(int bytes) =>
    '${(bytes / (1024 * 1024)).toStringAsFixed(2)}MB ($bytes바이트)';
