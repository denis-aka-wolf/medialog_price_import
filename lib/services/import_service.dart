import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import '../models/app_settings.dart';
import '../models/excel_sheet_info.dart';
import 'database_service.dart';

class ImportService {
  ImportService(this.db);
  final DatabaseService db;

  Future<List<ImportLogEntry>> importRows({required String sheetName, required List<Map<String, dynamic>> rows, required AppSettings defaults, required void Function(int done, int total) onProgress}) async {
    final logs = <ImportLogEntry>[];
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final serviceCode = _string(row['FM_SERV_CODE']);
      final priceText = _string(row['PRICE']);
      try {
        final price = _parsePrice(row['PRICE']);
        final date = _parseDate(row['DATE_FROM']) ?? _parseDate(defaults.defaultDateFrom);
        if (date == null) throw const FormatException('Не задана дата DATE_FROM.');

        final deviseCode = _effective(row, 'FM_DEVISE_CODE', defaults.defaultDeviseCode);
        final priceTypeCode = _effective(row, 'FM_PRICETYPE_CODE', defaults.defaultPriceTypeCode);
        final categoryCode = _effective(row, 'FM_PRICE_CATEGORY_CODE', defaults.defaultPriceCategoryCode);
        if (priceTypeCode.isEmpty) throw const FormatException('Не задан тип цены (FM_PRICETYPE_CODE).');

        final service = await db.query('SELECT TOP 1 FM_SERV_ID FROM FM_SERV WHERE FM_SERV_CODE = ?', params: [serviceCode]);
        if (service.isEmpty) throw FormatException('Услуга с кодом "$serviceCode" не найдена в FM_SERV.');
        final serviceId = _int(service.first['FM_SERV_ID']);

        final type = await db.query('SELECT TOP 1 FM_PRICETYPE_ID FROM FM_PRICETYPE WHERE FM_PRICETYPE_CODE = ?', params: [priceTypeCode]);
        if (type.isEmpty) throw FormatException('Тип цены "$priceTypeCode" не найден.');
        final typeId = _int(type.first['FM_PRICETYPE_ID']);

        final deviseId = await _lookupOptional('FM_DEVISE', 'FM_DEVISE_CODE', 'FM_DEVISE_ID', deviseCode);
        final categoryId = await _lookupOptional('FM_PRICE_CATEGORY', 'FM_PRICE_CATEGORY_CODE', 'FM_PRICE_CATEGORY_ID', categoryCode);

        final existing = await db.query('''
SELECT TOP 1 FM_SERVPRICE_ID FROM FM_SERVPRICE
WHERE FM_SERV_ID = ? AND CONVERT(date, DATE_FROM) = CONVERT(date, ?)
  AND FM_PRICETYPE_ID = ?
  AND ((FM_PRICE_CATEGORY_ID = ?) OR (FM_PRICE_CATEGORY_ID IS NULL AND ? IS NULL))
  AND ((FM_DEVISE_ID = ?) OR (FM_DEVISE_ID IS NULL AND ? IS NULL))
''', params: [serviceId, date, typeId, categoryId, categoryId, deviseId, deviseId]);

        // Each row is isolated in its own SQL transaction.
        await db.execute('BEGIN TRANSACTION');
        try {
          if (existing.isEmpty) {
            await db.execute('''INSERT INTO FM_SERVPRICE
(FM_SERV_ID, FM_PRICETYPE_ID, PRICE, FM_DEVISE_ID, DATE_FROM, FM_PRICE_CATEGORY_ID)
VALUES (?, ?, ?, ?, ?, ?)''', params: [serviceId, typeId, price, deviseId, date, categoryId]);
          } else {
            await db.execute('UPDATE FM_SERVPRICE SET PRICE = ? WHERE FM_SERVPRICE_ID = ?', params: [price, _int(existing.first['FM_SERVPRICE_ID'])]);
          }
          await db.execute('COMMIT TRANSACTION');
        } catch (_) {
          await db.execute('IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION');
          rethrow;
        }
        logs.add(ImportLogEntry(sheet: sheetName, excelRow: row['_EXCEL_ROW'] as int? ?? i + 2, serviceCode: serviceCode, price: priceText, status: ImportStatus.success, message: existing.isEmpty ? 'Создана новая цена.' : 'Цена обновлена.'));
      } catch (e) {
        logs.add(ImportLogEntry(sheet: sheetName, excelRow: row['_EXCEL_ROW'] as int? ?? i + 2, serviceCode: serviceCode, price: priceText, status: ImportStatus.error, message: e.toString().replaceFirst('Exception: ', '')));
      }
      onProgress(i + 1, rows.length);
    }
    return logs;
  }

  Future<int?> _lookupOptional(String table, String codeField, String idField, String code) async {
    if (code.isEmpty) return null;
    final result = await db.query('SELECT TOP 1 $idField FROM $table WHERE $codeField = ?', params: [code]);
    if (result.isEmpty) throw FormatException('Значение "$code" не найдено в $table.');
    return _int(result.first[idField]);
  }

  String _effective(Map<String, dynamic> row, String key, String fallback) {
    final value = _string(row[key]);
    return value.isEmpty ? fallback.trim() : value;
  }

  String _string(Object? value) => value?.toString().trim() ?? '';
  int _int(Object? value) => int.parse(value.toString());

  String _parsePrice(Object? value) {
    final normalized = _string(value).replaceAll(' ', '').replaceAll(',', '.');
    if (!RegExp(r'^-?\d+(\.\d{1,4})?$').hasMatch(normalized)) {
      throw const FormatException('Некорректная цена PRICE. Допускается до 4 знаков после запятой.');
    }
    return normalized;
  }

  DateTime? _parseDate(Object? value) {
    if (value == null || _string(value).isEmpty) return null;
    if (value is DateTime) return DateTime(value.year, value.month, value.day);
    if (value is DateCellValue) {
      final date = value.asDateTimeLocal();
      return DateTime(date.year, date.month, date.day);
    }
    if (value is DateTimeCellValue) {
      final date = value.asDateTimeLocal();
      return DateTime(date.year, date.month, date.day);
    }
    final text = _string(value);
    for (final format in ['yyyy-MM-dd', 'dd.MM.yyyy', 'd.M.yyyy', 'MM/dd/yyyy']) {
      try { final d = DateFormat(format).parseStrict(text); return DateTime(d.year, d.month, d.day); } catch (_) {}
    }
    throw FormatException('Некорректная дата DATE_FROM: "$text". Используйте ДД.ММ.ГГГГ.');
  }
}
