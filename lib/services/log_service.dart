
import 'dart:convert';
import 'dart:io';

class LogService {
  LogService._();

  static final LogService instance = LogService._();

  Directory? _logDirectory;
  Future<void> _pendingWrites = Future<void>.value();

  String? get logDirectoryPath => _logDirectory?.path;

  /// Инициализация логирования.
  /// Папка logs создаётся рядом с исполняемым файлом приложения.
  Future<void> initialize() async {
    try {
      final executableDirectory =
          File(Platform.resolvedExecutable).parent;

      _logDirectory = Directory(
        '${executableDirectory.path}${Platform.pathSeparator}logs',
      );

      await _logDirectory!.create(recursive: true);

      await info(
        'LogService',
        'Система логирования запущена.',
        context: {
          'executable': Platform.resolvedExecutable,
          'logDirectory': _logDirectory!.path,
          'operatingSystem': Platform.operatingSystem,
          'operatingSystemVersion': Platform.operatingSystemVersion,
        },
      );
    } catch (e, stackTrace) {
      // Если каталог логов создать не удалось, хотя бы выводим причину
      // в stderr. Ошибка логирования не должна останавливать приложение.
      stderr.writeln('LogService initialization failed: $e');
      stderr.writeln(stackTrace);
    }
  }

  /// Информационное сообщение.
  Future<void> info(
    String source,
    String message, {
    Map<String, dynamic>? context,
  }) async {
    await _write(
      level: 'INFO',
      source: source,
      message: message,
      context: context,
    );
  }

  /// Предупреждение.
  Future<void> warning(
    String source,
    String message, {
    Map<String, dynamic>? context,
  }) async {
    await _write(
      level: 'WARNING',
      source: source,
      message: message,
      context: context,
    );
  }

  /// Ошибка с подробной диагностикой.
  Future<void> error(
    String source,
    String message, {
    Object? exception,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) async {
    await _write(
      level: 'ERROR',
      source: source,
      message: message,
      exception: exception,
      stackTrace: stackTrace,
      context: context,
    );
  }

  Future<void> _write({
    required String level,
    required String source,
    required String message,
    Object? exception,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) async {
    final directory = _logDirectory;
    if (directory == null) return;

    final now = DateTime.now();

    final fileName =
        'app_${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}.log';

    final file = File(
      '${directory.path}${Platform.pathSeparator}$fileName',
    );

    final record = <String, dynamic>{
      'timestamp': now.toIso8601String(),
      'level': level,
      'source': source,
      'message': message,
      if (exception != null) ...{
        'exceptionType': exception.runtimeType.toString(),
        'exception': exception.toString(),
      },
      if (context != null && context.isNotEmpty)
        'context': context,
      if (stackTrace != null)
        'stackTrace': stackTrace.toString(),
    };

    final output = const JsonEncoder.withIndent('  ')
        .convert(record);

    _pendingWrites = _pendingWrites.then((_) async {
      try {
        await file.writeAsString(
          '$output\n\n',
          mode: FileMode.append,
          flush: true,
        );
      } catch (_) {
        // Не допускаем падения приложения из-за логирования.
      }
    });

    await _pendingWrites;
  }

  /// Формирование диагностической информации о параметрах SQL.
  static List<Map<String, dynamic>> describeParameters(
    List<Object?> params,
  ) {
    return [
      for (var i = 0; i < params.length; i++)
        {
          'position': i + 1,
          'type': params[i]?.runtimeType.toString() ?? 'null',
          'value': _formatValue(params[i]),
        },
    ];
  }

  static dynamic _formatValue(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value.toIso8601String();

    if (value is List<int>) {
      return '[binary data: ${value.length} bytes]';
    }

    return value.toString();
  }
}
