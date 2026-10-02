import 'package:file_picker/file_picker.dart';

/// 💡 file_picker 13부터 `PlatformFile.size`가 없어지고 `lengthSync()`·`length()`로 나뉘었습니다.
///
/// - `lengthSync()`는 네이티브 피커가 이미 알려준 길이를 I/O 없이 돌려줍니다. 없으면 null입니다.
/// - `length()`는 그때 디스크에서 읽습니다. 읽기에 실패하면 null입니다.
///
/// null은 "크기를 알 수 없음"이고 0바이트 파일(`0`)과 구분됩니다. 이전 `size`는 두 경우를
/// 모두 0으로 돌려줘 구분할 수 없었습니다.
Future<int?> platformFileSize(PlatformFile file) async =>
    file.lengthSync() ?? await file.length();

/// 여러 파일의 합계입니다. 하나라도 크기를 알 수 없으면 null입니다.
///
/// 호출부는 null을 "통과"가 아니라 "거절"로 다뤄야 합니다. 서버의 `AttachmentValidator`가
/// 최종 관문이지만, 업로드를 다 보낸 뒤 거절당하는 것보다 고르는 시점에 막는 편이 낫습니다.
Future<int?> platformFilesTotalSize(Iterable<PlatformFile> files) async {
  var total = 0;
  for (final file in files) {
    final size = await platformFileSize(file);
    if (size == null) return null;
    total += size;
  }
  return total;
}
