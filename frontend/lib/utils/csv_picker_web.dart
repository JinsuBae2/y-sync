// 💡 `dart:html`은 폐기되었고 `package:web` + `dart:js_interop`으로 옮겨야 합니다.
//    다만 이 파일은 관리자 명단 일괄 등록의 파일 선택 경로이고, 파일 선택·읽기는 단위 테스트로
//    검증할 수 없습니다. 잘못 옮기면 학기 초 명단 등록이 조용히 깨지므로, 실제 관리자 계정으로
//    업로드를 확인할 수 있을 때 별도로 옮깁니다. 그때까지 이 두 건만 분석에서 제외합니다.
// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:async';

import 'csv_picker.dart';

Future<CsvPickerResult?> pickCsvFile() {
  final completer = Completer<CsvPickerResult?>();
  final uploadInput = html.FileUploadInputElement();
  uploadInput.accept = '.xlsx,.xls,.csv';
  uploadInput.click();

  uploadInput.onChange.listen((e) {
    final files = uploadInput.files;
    if (files != null && files.isNotEmpty) {
      final file = files[0];
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      reader.onLoadEnd.listen((e) {
        final bytes = reader.result as List<int>;
        completer.complete(CsvPickerResult(bytes: bytes, name: file.name));
      });
    } else {
      completer.complete(null);
    }
  });

  return completer.future;
}
