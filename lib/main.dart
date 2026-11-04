import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'services/log_service.dart';
import 'dart:ui' as ui;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LogService.instance.initialize();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    LogService.instance.error(
      'Flutter',
      'Необработанная ошибка Flutter.',
      exception: details.exception,
      stackTrace: details.stack,
      context: {
        'library': details.library,
        'context': details.context?.toDescription(),
      },
    );
  };

  ui.PlatformDispatcher.instance.onError = (error, stackTrace) {
    LogService.instance.error(
      'Dart',
      'Необработанная асинхронная ошибка.',
      exception: error,
      stackTrace: stackTrace,
    );
    return true;
  };

  runApp(const PriceImportApp());
}

class PriceImportApp extends StatelessWidget {
  const PriceImportApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Импорт цен Медиалог',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF245B83)),
          scaffoldBackgroundColor: const Color(0xFFF5F7FA),
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        home: const HomeScreen(),
      );
}
