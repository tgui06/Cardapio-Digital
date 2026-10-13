import 'package:cardapio_digital/src/core/theme/app_theme.dart';
import 'package:cardapio_digital/src/data/models/cardapio.dart';
import 'package:cardapio_digital/src/data/models/loja.dart';
import 'package:cardapio_digital/src/data/models/pedido.dart';
import 'package:cardapio_digital/src/data/repositories/demo_data.dart';
import 'package:cardapio_digital/src/features/orders/order_success_screen.dart';
import 'package:cardapio_digital/src/state/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('cardápio de demonstração respeita o contrato da API', () {
    final c = Cardapio.fromJson(demoCardapioJson());
    expect(c.categorias, isNotEmpty);
    expect(c.produtos.every((p) => c.categorias.any((cat) => cat.id == p.categoriaId)), isTrue);
    // Bacon smash: 42,90 + onion rings 6,00 + bacon 5,00
    final smash = c.produto(28)!;
    expect(smash.precoAPartirDe, 42.90);
  });

  testWidgets('tela de sucesso renderiza no tablet', (tester) async {
    SharedPreferences.setMockInitialValues({'configurado': true, 'modo': 'garcom'});
    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final pedido = Pedido(
      id: 1,
      codigoAcesso: 'abc',
      numero: 427,
      tipoConsumo: TipoConsumo.local,
      mesa: 12,
      nomeCliente: 'Guilherme',
      itens: const [],
      observacao: '',
      subtotal: 80.3,
      taxaServico: 8.03,
      total: 88.33,
      status: StatusPedido.recebido,
      criadoEm: DateTime(2026, 10, 12, 0, 40),
      previsaoMin: 18,
      formaPagamento: 'Pagar no caixa',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [prefsProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          theme: buildTheme(Brightness.dark),
          home: OrderSuccessScreen(pedido: pedido),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Pedido enviado!'), findsOneWidget);
    expect(find.text('#427'), findsOneWidget);
  });
}
