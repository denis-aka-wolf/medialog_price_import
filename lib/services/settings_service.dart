import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/app_settings.dart';
import 'log_service.dart';

class SettingsService {
  static File get _file => File(
        p.join(p.dirname(Platform.resolvedExecutable), 'app_settings.json'),
      );

  Future<AppSettings> load() async {
    try {
      if (!await _file.exists()) {
        await LogService.instance.info(
          'SettingsService',
          'Файл настроек не найден. Используются настройки по умолчанию.',
          context: {'path': _file.path},
        );
        return const AppSettings();
      }

      final decoded =
          jsonDecode(await _file.readAsString()) as Map<String, dynamic>;
      final settings = AppSettings.fromJson(decoded);

      await LogService.instance.info(
        'SettingsService',
        'Настройки успешно загружены.',
        context: {'path': _file.path},
      );
      return settings;
    } catch (e, stackTrace) {
      await LogService.instance.error(
        'SettingsService',
        'Не удалось прочитать файл настроек. Используются настройки по умолчанию.',
        exception: e,
        stackTrace: stackTrace,
        context: {'path': _file.path},
      );
      return const AppSettings();
    }
  }

  Future<void> save(AppSettings settings) async {
    try {
      await _file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(settings.toJson()),
      );
      await LogService.instance.info(
        'SettingsService',
        'Настройки сохранены.',
        context: {'path': _file.path},
      );
    } catch (e, stackTrace) {
      await LogService.instance.error(
        'SettingsService',
        'Не удалось сохранить настройки.',
        exception: e,
        stackTrace: stackTrace,
        context: {'path': _file.path},
      );
      rethrow;
    }
  }

  String get settingsPath => _file.path;
}
