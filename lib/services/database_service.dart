import 'package:dart_odbc/dart_odbc.dart';
import '../models/app_settings.dart';
import 'log_service.dart';

class DatabaseService {
  DartOdbc? _client;

  bool get isConnected => _client != null;

  String _connectionString(AppSettings s) {
    final server = s.port.trim().isEmpty
        ? s.server.trim()
        : '${s.server.trim()},${s.port.trim()}';

    final parts = <String>[
      'DRIVER={${s.driver}}',
      'SERVER=$server',
      'DATABASE=${s.database}',
      if (s.trustedConnection)
        'Trusted_Connection=Yes'
      else
        'UID=${s.username};PWD=${s.password}',
      'TrustServerCertificate=Yes',
    ];

    return '${parts.join(';')};';
  }

  Future<void> connect(AppSettings settings) async {
    await disconnect();

    final client = DartOdbc(dsn: '');

    await client.connectWithConnectionString(
      _connectionString(settings),
    );

    _client = client;

    await client.execute('SELECT 1 AS connection_test');
  }

  Future<List<Map<String, dynamic>>> query(
    String sql, {
    List<Object?> params = const [],
  }) async {
    final client = _client;

    if (client == null) {
      throw StateError('Нет подключения к базе данных.');
    }

    try {
      return await client.execute(
        sql,
        params: params,
      );
    } catch (e, stackTrace) {
      await LogService.instance.error(
        'DatabaseService.query',
        'Ошибка выполнения SQL-запроса.',
        exception: e,
        stackTrace: stackTrace,
        context: {
          'sql': sql,
          'parameters': LogService.describeParameters(params),
          'parameterCount': params.length,
        },
      );

      rethrow;
    }
  }

  Future<void> execute(
    String sql, {
    List<Object?> params = const [],
  }) async {
    final client = _client;

    if (client == null) {
      throw StateError('Нет подключения к базе данных.');
    }

    try {
      await client.execute(
        sql,
        params: params,
      );
    } catch (e, stackTrace) {
      await LogService.instance.error(
        'DatabaseService.execute',
        'Ошибка выполнения SQL-команды.',
        exception: e,
        stackTrace: stackTrace,
        context: {
          'sql': sql,
          'parameters': LogService.describeParameters(params),
          'parameterCount': params.length,
        },
      );

      rethrow;
    }
  }

  Future<void> disconnect() async {
    final client = _client;
    _client = null;
    if (client != null) {
      await client.disconnect();
    }
  } 
}
