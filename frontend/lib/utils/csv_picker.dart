import 'csv_picker_stub.dart'
    if (dart.library.html) 'csv_picker_web.dart'
    if (dart.library.io) 'csv_picker_mobile.dart';

abstract class CsvPicker {
  static Future<CsvPickerResult?> pickCsv() => pickCsvFile();
}

class CsvPickerResult {
  final List<int> bytes;
  final String name;
  CsvPickerResult({required this.bytes, required this.name});
}
