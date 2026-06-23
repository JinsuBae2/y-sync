import 'package:file_picker/file_picker.dart';
import 'csv_picker.dart';

Future<CsvPickerResult?> pickCsvFile() async {
  FilePickerResult? result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['csv'],
    withData: true,
  );
  if (result != null && result.files.single.bytes != null) {
    return CsvPickerResult(
      bytes: result.files.single.bytes!,
      name: result.files.single.name,
    );
  }
  return null;
}
