import 'package:file_picker/file_picker.dart';

import 'csv_picker.dart';

Future<CsvPickerResult?> pickCsvFile() async {
  // 💡 file_picker 13: 단일 선택은 pickFile()이고 PlatformFile?를 그대로 돌려줍니다.
  //    FilePickerResult 래퍼와 withData 파라미터는 없어졌습니다.
  final file = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: ['xlsx', 'xls', 'csv'],
  );
  if (file == null) return null;
  return CsvPickerResult(bytes: await file.readAsBytes(), name: file.name);
}
