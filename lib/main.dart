import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/app.dart';
import 'src/state/settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
  final s = container.read(settingsProvider);
  CardapioApp.aplicarModo(s.configurado, s.modo);

  container.dispose();

  runApp(
    ProviderScope(
      // Erros aparecem na hora (com botão "tentar novamente") em vez de retry silencioso.
      retry: (retryCount, error) => null,
      overrides: [prefsProvider.overrideWithValue(prefs)],
      child: const CardapioApp(),
    ),
  );
}
