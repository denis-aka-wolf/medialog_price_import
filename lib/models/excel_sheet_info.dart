class ExcelSheetInfo {
  const ExcelSheetInfo({required this.name, required this.rowCount, required this.headers, required this.valid, required this.message});
  final String name;
  final int rowCount;
  final Set<String> headers;
  final bool valid;
  final String message;
}

class ImportLogEntry {
  const ImportLogEntry({required this.sheet, required this.excelRow, required this.serviceCode, required this.price, required this.status, required this.message});
  final String sheet;
  final int excelRow;
  final String serviceCode;
  final String price;
  final ImportStatus status;
  final String message;
}

enum ImportStatus { success, error }
