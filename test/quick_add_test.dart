import 'package:cardapio_digital/src/core/theme/app_theme.dart';
import 'package:cardapio_digital/src/core/widgets/app_image.dart';
import 'package:cardapio_digital/src/core/widgets/pressable.dart';
import 'package:cardapio_digital/src/data/models/cardapio.dart';
import 'package:cardapio_digital/src/data/repositories/demo_data.dart';
import 'package:cardapio_digital/src/features/menu/menu_screen.dart';
import 'package:cardapio_digital/src/features/product/product_detail_screen.dart';
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

  Finder botao(String label) =>
      find.byWidgetPredicate((w) => w is Pressable && w.semanticLabel == label, skipOffstage: false);

  Future<ProviderContainer> abrirMenu(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'configurado': true});
    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        cardapioProvider.overrideWith(() => CardapioFixo(Cardapio.fromJson(demoCardapioJson()))),
      ],
    );
    addTearDown(container.dispose);
    await container.read(cardapioProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: buildTheme(Brightness.dark), home: const MenuScreen()),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    return container;
  }

  /// Rola até o botão ficar no meio da tela (fora do cabeçalho fixo) e toca.
  Future<void> tocar(WidgetTester tester, Finder f) async {
    await Scrollable.ensureVisible(tester.element(f), alignment: 0.5);
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(f);
    // Vários quadros: o Hero mede a rota nova num quadro "offstage" antes de animar.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<void> encerrar(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  }

  testWidgets('"+" de item sem escolha obrigatória adiciona direto à sacola', (tester) async {
    final semantics = tester.ensureSemantics();
    final container = await abrirMenu(tester);
    final mais = botao('Adicionar Coado na V60').first;
    await tocar(tester, mais);

    expect(container.read(cartCountProvider), 1);
    expect(find.byType(ProductDetailScreen), findsNothing);
    // Leitor de tela enxerga o "+" como botão próprio, separado do card.
    expect(tester.getSemantics(mais).label, 'Adicionar Coado na V60');

    await encerrar(tester);
    semantics.dispose();
  });

  testWidgets('"+" de item com escolha obrigatória abre o detalhe', (tester) async {
    final container = await abrirMenu(tester);
    await tocar(tester, botao('Adicionar Cappuccino cremoso').last);

    expect(container.read(cartCountProvider), 0);
    expect(find.byType(ProductDetailScreen), findsOneWidget);

    await encerrar(tester);
  });
}
