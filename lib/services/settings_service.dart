import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/app_settings.dart';

class SettingsService {
  static File get _file => File(p.join(p.dirname(Platform.resolvedExecutable), 'app_settings.json'));

  Future<AppSettings> load() async {
    if (!await _file.exists()) return const AppSettings();
    try {
      final decoded = jsonDecode(await _file.readAsString()) as Map<String, dynamic>;
      return AppSettings.fromJson(decoded);
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> save(AppSettings settings) async {
    await _file.writeAsString(const JsonEncoder.withIndent('  ').convert(settings.toJson()));
  }

  String get settingsPath => _file.path;
}
