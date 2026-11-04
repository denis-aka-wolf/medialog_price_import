import 'package:dart_odbc/dart_odbc.dart';

import '../models/app_settings.dart';
import 'log_service.dart';

class DatabaseService {
  DartOdbc? _client;

  bool get isConnected => _client != null;

  String _connectionString(AppSettings settings) {
    final server = settings.port.trim().isEmpty
        ? settings.server.trim()
        : '${settings.server.trim()},${settings.port.trim()}';

    final parts = <String>[
      'DRIVER={${settings.driver}}',
      'SERVER=$server',
      'DATABASE=${settings.database}',
      if (settings.trustedConnection)
        'Trusted_Connection=Yes'
      else ...[
        'UID=${settings.username}',
        'PWD=${settings.password}',
      ],
      'TrustServerCertificate=Yes',
    ];

    return '${parts.join(';')};';
  }

  Future<void> connect(AppSettings settings) async {
    await disconnect();

    final context = <String, dynamic>{
      'server': settings.server,
      'port': settings.port,
      'database': settings.database,
      'driver': settings.driver,
      'trustedConnection': settings.trustedConnection,
      // Пароль и логин намеренно не записываются в лог.
    };

    await LogService.instance.info(
      'DatabaseService',
      'Начало подключения к SQL Server.',
      context: context,
    );

    final client = DartOdbc(dsn: '');

    try {
      await client.connectWithConnectionString(
        _connectionString(settings),
      );

      await client.execute('SELECT 1 AS connection_test');
      _client = client;

      await LogService.instance.info(
        'DatabaseService',
        'Подключение к SQL Server успешно установлено.',
        context: context,
      );
    } catch (e, stackTrace) {
      try {
        await client.disconnect();
      } catch (disconnectError, disconnectStack) {
        await LogService.instance.error(
          'DatabaseService',
          'Ошибка закрытия соединения после неудачного подключения.',
          exception: disconnectError,
          stackTrace: disconnectStack,
          context: context,
        );
      }

      _client = null;
      await LogService.instance.error(
        'DatabaseService',
        'Не удалось подключиться к SQL Server.',
        exception: e,
        stackTrace: stackTrace,
        context: context,
      );
      rethrow;
    }
  }

  /// Выполняет SQL-запрос без ODBC-параметров.
  Future<List<Map<String, dynamic>>> query(String sql) async {
    final client = _client;

    if (client == null) {
      final error = StateError('Нет подключения к базе данных.');
      await LogService.instance.error(
        'DatabaseService',
        'Попытка выполнить SQL-запрос без подключения.',
        exception: error,
        context: {'sql': sql},
      );
      throw error;
    }

    try {
      return await client.execute(sql);
    } catch (e, stackTrace) {
      await LogService.instance.error(
        'DatabaseService',
        'Ошибка выполнения SQL-запроса.',
        exception: e,
        stackTrace: stackTrace,
        context: {'sql': sql},
      );
      rethrow;
    }
  }

  /// Выполняет SQL-команду без ODBC-параметров.
  Future<void> execute(String sql) async {
    final client = _client;

    if (client == null) {
      final error = StateError('Нет подключения к базе данных.');
      await LogService.instance.error(
        'DatabaseService',
        'Попытка выполнить SQL-команду без подключения.',
        exception: error,
        context: {'sql': sql},
      );
      throw error;
    }

    try {
      await client.execute(sql);
    } catch (e, stackTrace) {
      await LogService.instance.error(
        'DatabaseService',
        'Ошибка выполнения SQL-команды.',
        exception: e,
        stackTrace: stackTrace,
        context: {'sql': sql},
      );
      rethrow;
    }
  }

  Future<void> disconnect() async {
    final client = _client;
    _client = null;

    if (client != null) {
      try {
        await client.disconnect();
        await LogService.instance.info(
          'DatabaseService',
          'Соединение с SQL Server закрыто.',
        );
      } catch (e, stackTrace) {
        await LogService.instance.error(
          'DatabaseService',
          'Ошибка при закрытии соединения с SQL Server.',
          exception: e,
          stackTrace: stackTrace,
        );
        rethrow;
      }
    }
  }
}
