// Botão "Chamar garçom": sino no topo do cardápio → motivos → confirmação com o
// nome do garçom responsável pela mesa. Em tablet deitado, tablet de 7" e celular.
import 'package:cardapio_digital/src/core/theme/app_theme.dart';
import 'package:cardapio_digital/src/core/widgets/app_image.dart';
import 'package:cardapio_digital/src/core/widgets/pressable.dart';
import 'package:cardapio_digital/src/data/models/cardapio.dart';
import 'package:cardapio_digital/src/data/repositories/demo_cardapio_repository.dart';
import 'package:cardapio_digital/src/data/repositories/demo_data.dart';
import 'package:cardapio_digital/src/features/menu/menu_screen.dart';
import 'package:cardapio_digital/src/features/waiter/waiter_home_screen.dart';
import 'package:cardapio_digital/src/state/providers.dart';
import 'package:cardapio_digital/src/state/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    appImageDisableNetwork = true;
  });

  Finder pressable(String label) => find.byWidgetPredicate((w) => w is Pressable && w.semanticLabel == label);

  Future<ProviderContainer> montar(WidgetTester tester, Size size, Widget tela, {String modo = 'totem'}) async {
    SharedPreferences.setMockInitialValues({'configurado': true, 'modo': modo});
    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        repositoryProvider.overrideWithValue(DemoCardapioRepository(latency: Duration.zero)),
        cardapioProvider.overrideWith(() => CardapioFixo(Cardapio.fromJson(demoCardapioJson()))),
      ],
    );
    addTearDown(container.dispose);
    await container.read(cardapioProvider.future);
    container.read(sessaoProvider.notifier).setMesa(3);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: buildTheme(Brightness.dark), home: tela),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    return container;
  }

  Future<void> encerrar(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 7));
  }

  const tamanhos = {
    'tablet-paisagem': Size(1280, 800),
    'tablet-7-paisagem': Size(1024, 600),
    'celular': Size(390, 844),
  };

  for (final MapEntry(key: nome, value: size) in tamanhos.entries) {
    testWidgets('sino chama o garçom da mesa · $nome', (tester) async {
      final container = await montar(tester, size, const MenuScreen());

      await tester.tap(pressable('Chamar o garçom'));
      // Vários quadros: a folha de baixo (celular) sobe animada.
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }
      expect(find.text('Como podemos ajudar?'), findsOneWidget);
      expect(find.text('Mesa 3 · Carla atende você'.toUpperCase()), findsOneWidget);

      await tester.tap(pressable('Pedir a conta'));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(find.text('Chamamos Carla!'), findsOneWidget);
      expect(container.read(chamadoMesaProvider).emAberto, isTrue);

      await tester.tap(find.text('Ok'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Como podemos ajudar?'), findsNothing);

      // O sino mostra que o garçom foi chamado.
      expect(pressable('Garçom chamado. Toque para ver ou cancelar'), findsOneWidget);
      await encerrar(tester);
    });
  }

  testWidgets('sino some quando o ERP desliga o recurso', (tester) async {
    final container = await montar(tester, const Size(1280, 800), const MenuScreen());
    final json = demoCardapioJson();
    final loja = {
      ...(json['loja'] as Map<String, dynamic>),
      'chamar_garcom': {'ativo': false},
    };
    container.read(cardapioProvider.notifier).state = AsyncData(Cardapio.fromJson({...json, 'loja': loja}));
    await tester.pump(const Duration(milliseconds: 300));
    expect(pressable('Chamar o garçom'), findsNothing);
    await encerrar(tester);
  });

  testWidgets('garçom vê os chamados das mesas e marca como atendido', (tester) async {
    await montar(tester, const Size(390, 844), const WaiterHomeScreen(), modo: 'garcom');
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Chamados'), findsOneWidget);
    expect(find.text('Pedir a conta'), findsOneWidget);

    await tester.tap(pressable('Mesa 7 atendida'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Pedir a conta'), findsNothing);
    await encerrar(tester);
  });
}
