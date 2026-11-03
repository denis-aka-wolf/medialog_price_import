import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../models/excel_sheet_info.dart';
import '../services/database_service.dart';
import '../services/excel_service.dart';
import '../services/import_service.dart';
import '../services/settings_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _settingsService = SettingsService();
  final _db = DatabaseService();
  final _excel = ExcelService();
  AppSettings _settings = const AppSettings();
  List<ExcelSheetInfo> _sheets = [];
  final Set<String> _selectedSheets = {};
  List<ImportLogEntry> _logs = [];
  String? _filePath;
  bool _busy = false;
  bool _connected = false;
  int _done = 0, _total = 0;
  String _filter = 'error';
  String _status = 'Не подключено к базе данных';

  @override
  void initState() { super.initState(); _initialize(); }

  Future<void> _initialize() async {
    final loaded = await _settingsService.load();
    if (!mounted) return;
    setState(() => _settings = loaded);
    if (_hasConnectionSettings(loaded)) {
      try { await _connect(loaded, showSuccess: false); }
      catch (e) { if (mounted) await _showConnectionDialog(error: e.toString()); }
    } else {
      await _showConnectionDialog();
    }
  }

  bool _hasConnectionSettings(AppSettings s) => s.server.isNotEmpty && s.database.isNotEmpty && s.driver.isNotEmpty && (s.trustedConnection || (s.username.isNotEmpty));

  Future<void> _connect(AppSettings settings, {bool showSuccess = true}) async {
    setState(() { _busy = true; _status = 'Подключение...'; });
    try {
      await _db.connect(settings);
      await _settingsService.save(settings);
      if (!mounted) return;
      setState(() { _settings = settings; _connected = true; _status = 'Подключено: ${settings.server} / ${settings.database}'; });
      if (showSuccess) _notice('Подключение успешно установлено.');
    } catch (e) {
      if (mounted) setState(() { _connected = false; _status = 'Ошибка подключения'; });
      rethrow;
    } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _showConnectionDialog({String? error}) async {
    final result = await showDialog<AppSettings>(context: context, barrierDismissible: false, builder: (_) => ConnectionDialog(initial: _settings, error: error));
    if (result == null) return;
    try { await _connect(result); }
    catch (e) { if (mounted) await _showConnectionDialog(error: e.toString()); }
  }

  Future<void> _pickExcel() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx'], allowMultiple: false);
    if (result == null || result.files.single.path == null) return;
    setState(() { _busy = true; _filePath = result.files.single.path; _sheets = []; _selectedSheets.clear(); _logs.clear(); });
    try {
      final sheets = await _excel.inspect(_filePath!);
      if (!mounted) return;
      setState(() { _sheets = sheets; _selectedSheets.addAll(sheets.where((s) => s.valid).map((s) => s.name)); });
      _notice('Excel проанализирован. Листов: ${sheets.length}.');
    } catch (e) { _notice('Не удалось прочитать Excel: $e', isError: true); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _startImport() async {
    if (!_connected) { await _showConnectionDialog(); return; }
    final targets = _sheets.where((s) => s.valid && _selectedSheets.contains(s.name)).toList();
    if (targets.isEmpty) { _notice('Выберите хотя бы один подходящий лист.', isError: true); return; }
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Начать импорт?'),
      content: Text('Будут обработаны листы: ${targets.map((e) => e.name).join(', ')}.\nВсего строк: ${targets.fold<int>(0, (sum, s) => sum + s.rowCount)}.\nСуществующие цены будут обновлены.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Импортировать'))],
    ));
    if (confirmed != true) return;
    setState(() { _busy = true; _logs = []; _done = 0; _total = targets.fold(0, (sum, s) => sum + s.rowCount); });
    try {
      final service = ImportService(_db);
      for (final sheet in targets) {
        final rows = _excel.readRows(sheet.name);
        final logs = await service.importRows(sheetName: sheet.name, rows: rows, defaults: _settings, onProgress: (done, total) {
          if (mounted) setState(() { _done++; });
        });
        if (mounted) setState(() => _logs.addAll(logs));
      }
      if (mounted) { setState(() => _filter = 'error'); _notice('Импорт завершён. Успешно: ${_logs.where((e) => e.status == ImportStatus.success).length}, ошибок: ${_logs.where((e) => e.status == ImportStatus.error).length}.'); }
    } catch (e) { _notice('Ошибка импорта: $e', isError: true); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _showImportDefaults() async {
    final result = await showDialog<AppSettings>(context: context, builder: (_) => DefaultsDialog(initial: _settings));
    if (result == null) return;
    await _settingsService.save(result);
    setState(() => _settings = result);
  }

  void _notice(String text, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), backgroundColor: isError ? Colors.red.shade700 : null));
  }

  @override
  void dispose() { _db.disconnect(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final visibleLogs = _logs.where((e) => _filter == 'all' || (_filter == 'error' && e.status == ImportStatus.error) || (_filter == 'success' && e.status == ImportStatus.success)).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Импорт цен Медиалог'), actions: [IconButton(tooltip: 'Настройки подключения', onPressed: _busy ? null : () => _showConnectionDialog(), icon: const Icon(Icons.settings_ethernet)), IconButton(tooltip: 'Параметры импорта', onPressed: _busy ? null : _showImportDefaults, icon: const Icon(Icons.tune)), const SizedBox(width: 12)]),
      body: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _connectionBanner(), const SizedBox(height: 16),
        Row(children: [FilledButton.icon(onPressed: _busy ? null : _pickExcel, icon: const Icon(Icons.folder_open), label: const Text('Выбрать Excel-файл')), const SizedBox(width: 12), Expanded(child: Text(_filePath == null ? 'Файл не выбран' : File(_filePath!).uri.pathSegments.last, overflow: TextOverflow.ellipsis)), if (_filePath != null) TextButton(onPressed: _busy ? null : _showImportDefaults, child: const Text('Параметры файла'))]),
        const SizedBox(height: 12),
        Expanded(flex: 5, child: _sheetsPanel()), const SizedBox(height: 16),
        Row(children: [Text('Журнал импорта', style: Theme.of(context).textTheme.titleLarge), const Spacer(), _statChip('Успешно', _logs.where((e) => e.status == ImportStatus.success).length, Colors.green), const SizedBox(width: 8), _statChip('Ошибки', _logs.where((e) => e.status == ImportStatus.error).length, Colors.red)]),
        const SizedBox(height: 8),
        SegmentedButton<String>(segments: const [ButtonSegment(value: 'error', label: Text('Ошибки')), ButtonSegment(value: 'success', label: Text('Успешно')), ButtonSegment(value: 'all', label: Text('Все'))], selected: {_filter}, onSelectionChanged: (v) => setState(() => _filter = v.first)),
        const SizedBox(height: 8), Expanded(flex: 4, child: _logsPanel(visibleLogs)),
        const SizedBox(height: 12),
        if (_busy && _total > 0) LinearProgressIndicator(value: _done / _total),
        Row(children: [Text(_busy && _total > 0 ? 'Обработано $_done из $_total' : 'Строк в выбранных листах: ${_sheets.where((s) => _selectedSheets.contains(s.name) && s.valid).fold<int>(0, (a, b) => a + b.rowCount)}'), const Spacer(), FilledButton.icon(onPressed: _busy || !_connected || _sheets.isEmpty ? null : _startImport, icon: const Icon(Icons.play_arrow), label: const Text('Начать импорт'))]),
      ])),
    );
  }

  Widget _connectionBanner() => Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), decoration: BoxDecoration(color: _connected ? Colors.green.shade50 : Colors.orange.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: _connected ? Colors.green.shade200 : Colors.orange.shade200)), child: Row(children: [Icon(_connected ? Icons.cloud_done : Icons.cloud_off, color: _connected ? Colors.green.shade800 : Colors.orange.shade900), const SizedBox(width: 10), Expanded(child: Text(_status)), if (!_connected) TextButton(onPressed: _busy ? null : () => _showConnectionDialog(), child: const Text('Настроить'))]));

  Widget _sheetsPanel() => Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Листы Excel', style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 8), Expanded(child: _sheets.isEmpty ? const Center(child: Text('Выберите Excel-файл для анализа листов.')) : ListView.separated(itemCount: _sheets.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (context, i) { final s = _sheets[i]; return CheckboxListTile(value: s.valid && _selectedSheets.contains(s.name), onChanged: s.valid && !_busy ? (v) => setState(() => v == true ? _selectedSheets.add(s.name) : _selectedSheets.remove(s.name)) : null, title: Text(s.name), subtitle: Text('${s.rowCount} строк · ${s.message}'), secondary: Icon(s.valid ? Icons.check_circle : Icons.error, color: s.valid ? Colors.green : Colors.red), controlAffinity: ListTileControlAffinity.leading); }))])));

  Widget _logsPanel(List<ImportLogEntry> logs) => Card(child: logs.isEmpty ? const Center(child: Text('Записи журнала появятся после импорта.')) : ListView.separated(itemCount: logs.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (context, i) { final e = logs[i]; return ListTile(dense: true, leading: Icon(e.status == ImportStatus.success ? Icons.check_circle : Icons.error, color: e.status == ImportStatus.success ? Colors.green : Colors.red), title: Text('Строка ${e.excelRow} · ${e.serviceCode} · ${e.price}'), subtitle: Text('${e.sheet}: ${e.message}'), isThreeLine: true); }));

  Widget _statChip(String label, int count, Color color) => Chip(avatar: Icon(Icons.circle, size: 10, color: color), label: Text('$label: $count'));
}

class ConnectionDialog extends StatefulWidget {
  const ConnectionDialog({super.key, required this.initial, this.error});
  final AppSettings initial;
  final String? error;
  @override
  State<ConnectionDialog> createState() => _ConnectionDialogState();
}

class _ConnectionDialogState extends State<ConnectionDialog> {
  late final controllers = <String, TextEditingController>{
    'server': TextEditingController(text: widget.initial.server), 'port': TextEditingController(text: widget.initial.port),
    'database': TextEditingController(text: widget.initial.database), 'driver': TextEditingController(text: widget.initial.driver),
    'username': TextEditingController(text: widget.initial.username), 'password': TextEditingController(text: widget.initial.password),
  };
  bool trusted = false;
  @override
  void initState() { super.initState(); trusted = widget.initial.trustedConnection; }
  @override
  void dispose() { for (final c in controllers.values) { c.dispose(); } super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(title: const Text('Подключение к Медиалог'), content: SizedBox(width: 480, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
    if (widget.error != null) Container(width: double.infinity, padding: const EdgeInsets.all(10), margin: const EdgeInsets.only(bottom: 12), color: Colors.red.shade50, child: Text('Не удалось подключиться:\n${widget.error}', style: TextStyle(color: Colors.red.shade900))),
    _field('server', 'Сервер (например, SERVER\\SQL)'), _field('port', 'Порт', required: false), _field('database', 'База данных'), _field('driver', 'Имя ODBC-драйвера'),
    const Align(alignment: Alignment.centerLeft, child: Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Имя драйвера можно посмотреть в «Источники данных ODBC» Windows на вкладке «Драйверы». Разрядность драйвера должна совпадать с приложением (обычно x64).'))),
    SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Windows-аутентификация'), value: trusted, onChanged: (v) => setState(() => trusted = v)),
    if (!trusted) ...[_field('username', 'Логин'), _field('password', 'Пароль', obscure: true)],
  ]))), actions: [TextButton(onPressed: () { if (widget.error == null) Navigator.pop(context); }, child: const Text('Отмена')), FilledButton(onPressed: () { final s = widget.initial.copyWith(server: controllers['server']!.text.trim(), port: controllers['port']!.text.trim(), database: controllers['database']!.text.trim(), driver: controllers['driver']!.text.trim(), username: controllers['username']!.text.trim(), password: controllers['password']!.text, trustedConnection: trusted); if (s.server.isEmpty || s.database.isEmpty || s.driver.isEmpty || (!trusted && s.username.isEmpty)) return; Navigator.pop(context, s); }, child: const Text('Подключиться'))]);
  Widget _field(String key, String label, {bool required = true, bool obscure = false}) => Padding(padding: const EdgeInsets.only(bottom: 10), child: TextField(controller: controllers[key], obscureText: obscure, decoration: InputDecoration(labelText: label, isDense: true),));
}

class DefaultsDialog extends StatefulWidget {
  const DefaultsDialog({super.key, required this.initial});
  final AppSettings initial;
  @override
  State<DefaultsDialog> createState() => _DefaultsDialogState();
}
class _DefaultsDialogState extends State<DefaultsDialog> {
  late final date = TextEditingController(text: widget.initial.defaultDateFrom);
  late final devise = TextEditingController(text: widget.initial.defaultDeviseCode);
  late final type = TextEditingController(text: widget.initial.defaultPriceTypeCode);
  late final category = TextEditingController(text: widget.initial.defaultPriceCategoryCode);
  @override
  void dispose() { date.dispose(); devise.dispose(); type.dispose(); category.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(title: const Text('Параметры импорта по умолчанию'), content: SizedBox(width: 430, child: Column(mainAxisSize: MainAxisSize.min, children: [
    TextField(controller: date, decoration: const InputDecoration(labelText: 'Дата начала действия (ДД.ММ.ГГГГ)')),
    TextField(controller: devise, decoration: const InputDecoration(labelText: 'Код валюты FM_DEVISE_CODE')),
    TextField(controller: type, decoration: const InputDecoration(labelText: 'Тип цены FM_PRICETYPE_CODE')),
    TextField(controller: category, decoration: const InputDecoration(labelText: 'Категория FM_PRICE_CATEGORY_CODE')),
    const SizedBox(height: 8), const Text('Значения из Excel имеют приоритет над значениями по умолчанию.', style: TextStyle(fontSize: 12)),
  ])), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')), FilledButton(onPressed: () => Navigator.pop(context, widget.initial.copyWith(defaultDateFrom: date.text.trim(), defaultDeviseCode: devise.text.trim(), defaultPriceTypeCode: type.text.trim(), defaultPriceCategoryCode: category.text.trim())), child: const Text('Сохранить'))]);
}
