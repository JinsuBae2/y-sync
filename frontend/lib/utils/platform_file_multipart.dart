import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http_parser/http_parser.dart';

Future<MultipartFile> platformFileToMultipart(PlatformFile file) async {
  final contentType = _contentType(file.extension);
  if (kIsWeb) {
    // 💡 file_picker 13부터 bytes 게터가 없어졌습니다. 고르는 시점에 전부 메모리에 올리지 않고
    //    필요할 때 읽습니다(withData 제거와 같은 취지).
    return MultipartFile.fromBytes(
      await file.readAsBytes(),
      filename: file.name,
      contentType: contentType,
    );
  }
  final path = file.path;
  if (path == null) throw StateError('${file.name} 파일 경로를 찾을 수 없습니다.');
  return MultipartFile.fromFile(
    path,
    filename: file.name,
    contentType: contentType,
  );
}

MediaType _contentType(String? extension) {
  switch (extension?.toLowerCase()) {
    case 'png':
      return MediaType('image', 'png');
    case 'jpg':
    case 'jpeg':
      return MediaType('image', 'jpeg');
    case 'gif':
      return MediaType('image', 'gif');
    case 'webp':
      return MediaType('image', 'webp');
    case 'pdf':
      return MediaType('application', 'pdf');
    case 'txt':
      return MediaType('text', 'plain');
    case 'hwp':
      return MediaType('application', 'x-hwp');
    case 'hwpx':
      return MediaType('application', 'vnd.hancom.hwpx');
    case 'doc':
      return MediaType('application', 'msword');
    case 'docx':
      return MediaType(
        'application',
        'vnd.openxmlformats-officedocument.wordprocessingml.document',
      );
    case 'xls':
      return MediaType('application', 'vnd.ms-excel');
    case 'xlsx':
      return MediaType(
        'application',
        'vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
    case 'ppt':
      return MediaType('application', 'vnd.ms-powerpoint');
    case 'pptx':
      return MediaType(
        'application',
        'vnd.openxmlformats-officedocument.presentationml.presentation',
      );
    case 'zip':
      return MediaType('application', 'zip');
    default:
      return MediaType('application', 'octet-stream');
  }
}
