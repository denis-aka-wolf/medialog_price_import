import 'package:dart_odbc/dart_odbc.dart';

import '../models/app_settings.dart';

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

    final client = DartOdbc(dsn: '');

    await client.connectWithConnectionString(
      _connectionString(settings),
    );

    _client = client;

    try {
      await client.execute('SELECT 1 AS connection_test');
    } catch (_) {
      _client = null;
      await client.disconnect();
      rethrow;
    }
  }

  /// Выполняет SQL-запрос без ODBC-параметров.
  ///
  /// Запрос передаётся драйверу непосредственно через SQLExecDirectW.
  Future<List<Map<String, dynamic>>> query(String sql) async {
    final client = _client;

    if (client == null) {
      throw StateError('Нет подключения к базе данных.');
    }

    return client.execute(sql);
  }

  /// Выполняет SQL-команду без ODBC-параметров.
  Future<void> execute(String sql) async {
    final client = _client;

    if (client == null) {
      throw StateError('Нет подключения к базе данных.');
    }

    await client.execute(sql);
  }

  Future<void> disconnect() async {
    final client = _client;

    _client = null;

    if (client != null) {
      await client.disconnect();
    }
  }
}