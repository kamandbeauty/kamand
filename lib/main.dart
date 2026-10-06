import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'core/theme/app_theme.dart';
import 'data/database/app_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final database = await AppDatabase.open();
    runApp(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: const NameologyApp(),
      ),
    );
  } catch (error) {
    runApp(DatabaseFailureApp(error: error));
  }
}

class DatabaseFailureApp extends StatelessWidget {
  const DatabaseFailureApp({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.storage_rounded, size: 56, color: Colors.redAccent),
                  const SizedBox(height: 16),
                  const Text('راه‌اندازی دیتابیس انجام نشد', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Text('اطلاعات خطا برای بررسی فنی: $error', textAlign: TextAlign.center, style: const TextStyle(color: Colors.blueGrey)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class NameologyApp extends StatelessWidget {
  const NameologyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'علم اسامی',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: const Locale('fa', 'IR'),
      supportedLocales: const [Locale('fa', 'IR'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const AppShell(),
    );
  }
}
