import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

import '../models/app_settings.dart';
import '../models/excel_sheet_info.dart';
import 'database_service.dart';

class ImportService {
  ImportService(this.db);

  final DatabaseService db;

  Future<List<ImportLogEntry>> importRows({
    required String sheetName,
    required List<Map<String, dynamic>> rows,
    required AppSettings defaults,
    required void Function(int done, int total) onProgress,
  }) async {
    final logs = <ImportLogEntry>[];

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];

      final serviceCode = _string(row['FM_SERV_CODE']);
      final priceText = _string(row['PRICE']);

      try {
        if (serviceCode.isEmpty) {
          throw const FormatException(
            'Не указан код услуги FM_SERV_CODE.',
          );
        }

        final price = _parsePrice(row['PRICE']);

        final date = _parseDate(row['DATE_FROM']) ??
            _parseDate(defaults.defaultDateFrom);

        if (date == null) {
          throw const FormatException(
            'Не задана дата DATE_FROM.',
          );
        }

        final deviseCode = _effective(
          row,
          'FM_DEVISE_CODE',
          defaults.defaultDeviseCode,
        );

        final priceTypeCode = _effective(
          row,
          'FM_PRICETYPE_CODE',
          defaults.defaultPriceTypeCode,
        );

        final categoryCode = _effective(
          row,
          'FM_PRICE_CATEGORY_CODE',
          defaults.defaultPriceCategoryCode,
        );

        if (priceTypeCode.isEmpty) {
          throw const FormatException(
            'Не задан тип цены (FM_PRICETYPE_CODE).',
          );
        }

        // Формат даты для SQL Server: YYYYMMDD.
        final sqlDate = _sqlDate(date);

        // Поиск услуги.
        // В Excel колонка называется FM_SERV_CODE,
        // в таблице FM_SERV используется поле CODE.
        final service = await db.query(
          '''
SELECT TOP 1 FM_SERV_ID
FROM FM_SERV
WHERE CODE = ${_sqlString(serviceCode)}
''',
        );

        if (service.isEmpty) {
          throw FormatException(
            'Услуга с кодом "$serviceCode" не найдена в FM_SERV.',
          );
        }

        final serviceId = _int(
          service.first['FM_SERV_ID'],
        );

        // Поиск типа цены.
        final type = await db.query(
          '''
SELECT TOP 1 FM_PRICETYPE_ID
FROM FM_PRICETYPE
WHERE FM_PRICETYPE_CODE = ${_sqlString(priceTypeCode)}
''',
        );

        if (type.isEmpty) {
          throw FormatException(
            'Тип цены "$priceTypeCode" не найден.',
          );
        }

        final typeId = _int(
          type.first['FM_PRICETYPE_ID'],
        );

        // Поиск валюты.
        final deviseId = await _lookupOptional(
          'FM_DEVISE',
          'FM_DEVISE_CODE',
          'FM_DEVISE_ID',
          deviseCode,
        );

        // Поиск категории цены.
        final categoryId = await _lookupOptional(
          'FM_PRICE_CATEGORY',
          'FM_PRICE_CATEGORY_CODE',
          'FM_PRICE_CATEGORY_ID',
          categoryCode,
        );

        // Условия поиска существующей цены.
        final categoryCondition = categoryId == null
            ? 'FM_PRICE_CATEGORY_ID IS NULL'
            : 'FM_PRICE_CATEGORY_ID = $categoryId';

        final deviseCondition = deviseId == null
            ? 'FM_DEVISE_ID IS NULL'
            : 'FM_DEVISE_ID = $deviseId';

        // Проверяем, существует ли уже такая цена.
        final existing = await db.query(
          '''
SELECT TOP 1 FM_SERVPRICE_ID
FROM FM_SERVPRICE
WHERE FM_SERV_ID = $serviceId
  AND DATE_FROM >= CONVERT(date, '$sqlDate', 112)
  AND DATE_FROM < DATEADD(
      DAY,
      1,
      CONVERT(date, '$sqlDate', 112)
  )
  AND FM_PRICETYPE_ID = $typeId
  AND $categoryCondition
  AND $deviseCondition
''',
        );

        // Каждая строка обрабатывается в отдельной транзакции.
        await db.execute('BEGIN TRANSACTION');

        try {
          if (existing.isEmpty) {
            final deviseValue = deviseId == null
                ? 'NULL'
                : deviseId.toString();

            final categoryValue = categoryId == null
                ? 'NULL'
                : categoryId.toString();

            await db.execute(
              '''
INSERT INTO FM_SERVPRICE
(
    FM_SERV_ID,
    FM_PRICETYPE_ID,
    PRICE,
    FM_DEVISE_ID,
    DATE_FROM,
    FM_PRICE_CATEGORY_ID
)
VALUES
(
    $serviceId,
    $typeId,
    CAST($price AS MONEY),
    $deviseValue,
    CONVERT(datetime, '$sqlDate', 112),
    $categoryValue
)
''',
            );
          } else {
            final priceId = _int(
              existing.first['FM_SERVPRICE_ID'],
            );

            await db.execute(
              '''
UPDATE FM_SERVPRICE
SET PRICE = CAST($price AS MONEY)
WHERE FM_SERVPRICE_ID = $priceId
''',
            );
          }

          await db.execute('COMMIT TRANSACTION');
        } catch (_) {
          try {
            await db.execute(
              'IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION',
            );
          } catch (_) {
            // Не заменяем первоначальную ошибку
            // возможной ошибкой отката транзакции.
          }

          rethrow;
        }

        logs.add(
          ImportLogEntry(
            sheet: sheetName,
            excelRow: _excelRow(row, i),
            serviceCode: serviceCode,
            price: priceText,
            status: ImportStatus.success,
            message: existing.isEmpty
                ? 'Создана новая цена.'
                : 'Цена обновлена.',
          ),
        );
      } catch (e) {
        logs.add(
          ImportLogEntry(
            sheet: sheetName,
            excelRow: _excelRow(row, i),
            serviceCode: serviceCode,
            price: priceText,
            status: ImportStatus.error,
            message: e.toString().replaceFirst(
              'Exception: ',
              '',
            ),
          ),
        );
      }

      onProgress(i + 1, rows.length);
    }

    return logs;
  }

  /// Поиск необязательного справочного значения.
  ///
  /// Названия таблиц и столбцов задаются внутри приложения,
  /// а значения кодов безопасно экранируются.
  Future<int?> _lookupOptional(
    String table,
    String codeField,
    String idField,
    String code,
  ) async {
    if (code.isEmpty) {
      return null;
    }

    final result = await db.query(
      '''
SELECT TOP 1 $idField
FROM $table
WHERE $codeField = ${_sqlString(code)}
''',
    );

    if (result.isEmpty) {
      throw FormatException(
        'Значение "$code" не найдено в $table.',
      );
    }

    return _int(result.first[idField]);
  }

  /// Возвращает значение из Excel или значение по умолчанию.
  String _effective(
    Map<String, dynamic> row,
    String key,
    String fallback,
  ) {
    final value = _string(row[key]);

    return value.isEmpty ? fallback.trim() : value;
  }

  /// Преобразование значения в строку.
  String _string(Object? value) {
    return value?.toString().trim() ?? '';
  }

  /// Преобразование значения в целое число.
  int _int(Object? value) {
    if (value == null) {
      throw const FormatException(
        'Получено пустое значение идентификатора из базы данных.',
      );
    }

    return int.parse(value.toString());
  }

  /// Номер строки Excel.
  int _excelRow(
    Map<String, dynamic> row,
    int index,
  ) {
    final value = row['_EXCEL_ROW'];

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return index + 2;
  }

  /// Безопасное преобразование строки в SQL-литерал.
  ///
  /// Апострофы удваиваются согласно синтаксису SQL Server.
  /// Например: O'Brien -> N'O''Brien'
  String _sqlString(String value) {
    final escaped = value.replaceAll("'", "''");

    return "N'$escaped'";
  }

  /// Формат даты для SQL Server.
  ///
  /// Используется однозначный формат YYYYMMDD.
  String _sqlDate(DateTime date) {
    return DateFormat('yyyyMMdd').format(date);
  }

  /// Проверка и нормализация цены.
  ///
  /// Возвращает числовую строку без разделителей тысяч.
  /// Максимум 4 знака после запятой.
  String _parsePrice(Object? value) {
    final normalized = _string(value)
        .replaceAll(' ', '')
        .replaceAll(',', '.');

    if (!RegExp(r'^-?\d+(\.\d{1,4})?$').hasMatch(normalized)) {
      throw const FormatException(
        'Некорректная цена PRICE. '
        'Допускается до 4 знаков после запятой.',
      );
    }

    return normalized;
  }

  /// Преобразование даты из Excel или настроек.
  DateTime? _parseDate(Object? value) {
    if (value == null || _string(value).isEmpty) {
      return null;
    }

    if (value is DateTime) {
      return DateTime(
        value.year,
        value.month,
        value.day,
      );
    }

    if (value is DateCellValue) {
      final date = value.asDateTimeLocal();

      return DateTime(
        date.year,
        date.month,
        date.day,
      );
    }

    if (value is DateTimeCellValue) {
      final date = value.asDateTimeLocal();

      return DateTime(
        date.year,
        date.month,
        date.day,
      );
    }

    final text = _string(value);

    for (final format in [
      'yyyy-MM-dd',
      'dd.MM.yyyy',
      'd.M.yyyy',
      'MM/dd/yyyy',
    ]) {
      try {
        final date = DateFormat(format).parseStrict(text);

        return DateTime(
          date.year,
          date.month,
          date.day,
        );
      } catch (_) {
        // Пробуем следующий формат.
      }
    }

    throw FormatException(
      'Некорректная дата DATE_FROM: "$text". '
      'Используйте ДД.ММ.ГГГГ.',
    );
  }
}