// Renderiza cada tela em celular, tablet retrato e tablet paisagem e falha em
// qualquer exceção de layout (overflow, constraints infinitas etc.).
import 'package:cardapio_digital/src/core/theme/app_theme.dart';
import 'package:cardapio_digital/src/core/widgets/app_image.dart';
import 'package:cardapio_digital/src/data/models/cardapio.dart';
import 'package:cardapio_digital/src/data/models/cart_item.dart';
import 'package:cardapio_digital/src/data/models/loja.dart';
import 'package:cardapio_digital/src/data/models/pedido.dart';
import 'package:cardapio_digital/src/data/repositories/demo_data.dart';
import 'package:cardapio_digital/src/features/attract/attract_screen.dart';
import 'package:cardapio_digital/src/features/cart/cart_view.dart';
import 'package:cardapio_digital/src/features/checkout/checkout_screen.dart';
import 'package:cardapio_digital/src/features/menu/menu_screen.dart';
import 'package:cardapio_digital/src/features/onboarding/onboarding_screen.dart';
import 'package:cardapio_digital/src/features/orders/order_success_screen.dart';
import 'package:cardapio_digital/src/features/orders/orders_screen.dart';
import 'package:cardapio_digital/src/features/product/product_detail_screen.dart';
import 'package:cardapio_digital/src/features/settings/settings_screen.dart';
import 'package:cardapio_digital/src/features/waiter/waiter_home_screen.dart';
import 'package:cardapio_digital/src/state/providers.dart';
import 'package:cardapio_digital/src/state/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

final cardapio = Cardapio.fromJson(demoCardapioJson());

Pedido pedidoExemplo(StatusPedido status) => Pedido(
  id: 1,
  codigoAcesso: 'abc-${status.api}',
  numero: 427,
  tipoConsumo: TipoConsumo.local,
  mesa: 12,
  nomeCliente: 'Guilherme Teixeira',
  itens: [
    CartItem(
      uid: 'x',
      produto: cardapio.produto(28)!,
      quantidade: 2,
      selecoes: const {
        10: {3: 1},
        13: {3: 1},
        11: {1: 2},
      },
      observacao: 'Sem cebola, por favor',
    ).toPedidoItem(),
  ],
  observacao: '',
  subtotal: 125.8,
  taxaServico: 12.58,
  total: 138.38,
  status: status,
  criadoEm: DateTime(2026, 10, 12, 0, 40),
  previsaoMin: 18,
  formaPagamento: 'Pagar no caixa',
);

const sizes = {
  'celular': Size(360, 760),
  'tablet-retrato': Size(800, 1280),
  'tablet-paisagem': Size(1280, 800),
  // Uso principal: tablet deitado na mesa (10", 8" e 7").
  'tablet-8-paisagem': Size(960, 600),
  'tablet-7-paisagem': Size(1024, 600),
};

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    appImageDisableNetwork = true;
  });

  final screens = <String, Widget Function()>{
    'onboarding': () => const OnboardingScreen(),
    'attract': () => const AttractScreen(),
    'menu': () => const MenuScreen(),
    'detalhe': () => ProductDetailScreen(produto: cardapio.produto(28)!, heroTag: 't'),
    'detalhe-indisponivel': () => ProductDetailScreen(produto: cardapio.produto(33)!, heroTag: 't'),
    'sacola': () => const CartScreen(),
    'checkout': () => const CheckoutScreen(),
    'sucesso': () => OrderSuccessScreen(pedido: pedidoExemplo(StatusPedido.emPreparo)),
    'pedidos': () => const OrdersScreen(),
    'mesas': () => const WaiterHomeScreen(),
    'mesa': () => TableScreen(mesa: Mesa.fromJson(demoMesasJson(DateTime.now())[4])),
    'configuracoes': () => const SettingsScreen(),
  };

  for (final MapEntry(key: sizeName, value: size) in sizes.entries) {
    for (final theme in [Brightness.dark, Brightness.light]) {
      for (final MapEntry(key: name, value: build) in screens.entries) {
        testWidgets('$name · $sizeName · ${theme.name}', (tester) async {
          SharedPreferences.setMockInitialValues({'configurado': true, 'modo': 'totem'});
          final prefs = await SharedPreferences.getInstance();
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);

          final container = ProviderContainer(
            retry: (_, _) => null,
            overrides: [
              prefsProvider.overrideWithValue(prefs),
              cardapioProvider.overrideWith(() => CardapioFixo(cardapio)),
              pedidoAoVivoProvider.overrideWith((ref, codigo) => Stream.value(pedidoExemplo(StatusPedido.emPreparo))),
            ],
          );
          addTearDown(container.dispose);
          await container.read(cardapioProvider.future);

          // Sacola com itens variados (opções, observação, quantidade).
          container.read(cartProvider.notifier)
            ..add(
              CartItem(
                uid: 'a',
                produto: cardapio.produto(28)!,
                quantidade: 2,
                selecoes: const {
                  10: {3: 1},
                  13: {3: 1},
                  11: {1: 2},
                },
                observacao: 'Sem cebola, por favor, e o molho à parte',
              ),
            )
            ..add(
              CartItem(
                uid: 'b',
                produto: cardapio.produto(2)!,
                quantidade: 1,
                selecoes: const {
                  1: {3: 1},
                  2: {4: 1},
                },
                observacao: '',
              ),
            );
          container.read(sessaoProvider.notifier).setConsumo(TipoConsumo.local);
          container.read(meusPedidosProvider.notifier)
            ..add(pedidoExemplo(StatusPedido.recebido))
            ..add(pedidoExemplo(StatusPedido.pronto));

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                theme: buildTheme(Brightness.light),
                darkTheme: buildTheme(Brightness.dark),
                themeMode: theme == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
                home: build(),
              ),
            ),
          );
          // Deixa animações de entrada, latência do demo e carregamentos terminarem.
          for (var i = 0; i < 8; i++) {
            await tester.pump(const Duration(milliseconds: 500));
          }
          // Qualquer exceção de layout já faz o teste falhar com o relatório completo.

          // Tira a tela para encerrar timers (slideshow, contagem regressiva etc.).
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(seconds: 3));
        });
      }
    }
  }
}
