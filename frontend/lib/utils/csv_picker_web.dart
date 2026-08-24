import 'dart:html' as html;
import 'dart:async';
import 'csv_picker.dart';

Future<CsvPickerResult?> pickCsvFile() {
  final completer = Completer<CsvPickerResult?>();
  final uploadInput = html.FileUploadInputElement();
  uploadInput.accept = '.csv';
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
