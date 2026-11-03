import 'dart:io';
import 'package:excel/excel.dart';
import '../models/excel_sheet_info.dart';

class ExcelService {
  static const requiredHeaders = {'FM_SERV_CODE', 'PRICE'};
  Excel? _workbook;

  Future<List<ExcelSheetInfo>> inspect(String path) async {
    final bytes = await File(path).readAsBytes();
    _workbook = Excel.decodeBytes(bytes);
    final result = <ExcelSheetInfo>[];
    for (final name in _workbook!.tables.keys) {
      final sheet = _workbook!.tables[name]!;
      final rows = sheet.rows;
      final headerRow = rows.isEmpty ? <Data?>[] : rows.first;
      final Set<String> headers = headerRow
        .map<String>(
          (cell) => _text(cell?.value).toString().trim().toUpperCase(),
        )
        .where((value) => value.isNotEmpty)
        .toSet();
      final missing = requiredHeaders.difference(headers);
      final dataRows = rows.length > 1 ? rows.skip(1).where((r) => r.any((c) => _text(c?.value).trim().isNotEmpty)).length : 0;
      result.add(ExcelSheetInfo(
        name: name, rowCount: dataRows, headers: headers,
        valid: missing.isEmpty,
        message: missing.isEmpty ? 'Формат подходит' : 'Нет колонок: ${missing.join(', ')}',
      ));
    }
    return result;
  }

  List<Map<String, dynamic>> readRows(String sheetName) {
    final sheet = _workbook?.tables[sheetName];
    if (sheet == null || sheet.rows.isEmpty) return [];
    final headers = sheet.rows.first
        .map((cell) => _text(cell?.value).toString().trim().toUpperCase())
        .toList(growable: false);
    final result = <Map<String, dynamic>>[];
    for (var i = 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      if (row.every((c) => _text(c?.value).trim().isEmpty)) continue;
      final map = <String, dynamic>{};
      for (var j = 0; j < headers.length; j++) {
        if (headers[j].isEmpty) continue;
        map[headers[j]] = _text(j < row.length ? row[j]?.value : null);
      }
      map['_EXCEL_ROW'] = i + 1;
      result.add(map);
    }
    return result;
  }

  static dynamic _text(Object? value) {
    if (value == null) return '';

    return switch (value) {
      TextCellValue(:final value) => _spanText(value),
      IntCellValue(:final value) => value.toString(),
      DoubleCellValue(:final value) => value.toString(),
      BoolCellValue(:final value) => value.toString(),

      DateCellValue(:final year, :final month, :final day) =>
        DateTime(year, month, day),

      DateTimeCellValue(
        :final year,
        :final month,
        :final day,
        :final hour,
        :final minute,
        :final second,
      ) => DateTime(year, month, day, hour, minute, second),

      _ => value.toString(),
    };
  }

  static String _spanText(TextSpan span) {
    final text = span.text ?? '';
    final children = span.children ?? [];

    return text + children.map(_spanText).join();
  }
}
