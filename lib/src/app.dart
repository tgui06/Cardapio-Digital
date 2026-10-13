import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'core/theme/app_theme.dart';
import 'features/attract/attract_screen.dart';
import 'features/offline/offline_host.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/totem/inactivity_guard.dart';
import 'features/waiter/waiter_home_screen.dart';
import 'state/providers.dart';
import 'state/settings.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();
final rootMessengerKey = GlobalKey<ScaffoldMessengerState>();

class CardapioApp extends ConsumerWidget {
  const CardapioApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    // Tema, fontes e cantos vêm do ERP; o aparelho pode escolher outro tema localmente.
    final aparencia = ref.watch(aparenciaProvider);

    ref.listen(settingsProvider.select((s) => (s.configurado, s.modo)), (_, next) => aplicarModo(next.$1, next.$2));

    final Widget home;
    if (!settings.configurado) {
      home = const OnboardingScreen();
    } else if (settings.modo == ModoOperacao.garcom) {
      home = const WaiterHomeScreen();
    } else {
      home = const AttractScreen();
    }

    return MaterialApp(
      title: 'Cardápio Forven',
      debugShowCheckedModeBanner: false,
      navigatorKey: rootNavigatorKey,
      scaffoldMessengerKey: rootMessengerKey,
      theme: buildTheme(Brightness.dark, aparencia: aparencia),
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: KeyedSubtree(key: ValueKey((settings.configurado, settings.modo)), child: home),
      builder: (context, child) => OfflineHost(child: InactivityGuard(child: child ?? const SizedBox.shrink())),
    );
  }

  /// Totem: tela sempre ligada e modo imersivo. Garçom: comportamento normal.
  static void aplicarModo(bool configurado, ModoOperacao modo) {
    final totem = configurado && modo == ModoOperacao.totem;
    if (!kIsWeb) {
      SystemChrome.setEnabledSystemUIMode(totem ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
    }
    WakelockPlus.toggle(enable: totem).ignore();
  }
}
