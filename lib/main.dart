import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
