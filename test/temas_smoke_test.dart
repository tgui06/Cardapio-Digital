// Aparências configuráveis no ERP (tema, fonte, cantos, layout em lista):
// as telas principais não podem quebrar em nenhuma delas.
import 'package:cardapio_digital/src/core/theme/app_theme.dart';
import 'package:cardapio_digital/src/core/widgets/app_image.dart';
import 'package:cardapio_digital/src/data/models/cardapio.dart';
import 'package:cardapio_digital/src/data/models/loja.dart';
import 'package:cardapio_digital/src/data/models/pedido.dart';
import 'package:cardapio_digital/src/data/repositories/demo_data.dart';
import 'package:cardapio_digital/src/features/attract/attract_screen.dart';
import 'package:cardapio_digital/src/features/checkout/checkout_screen.dart';
import 'package:cardapio_digital/src/features/menu/menu_screen.dart';
import 'package:cardapio_digital/src/features/orders/order_success_screen.dart';
import 'package:cardapio_digital/src/features/settings/settings_screen.dart';
import 'package:cardapio_digital/src/state/providers.dart';
import 'package:cardapio_digital/src/state/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

Cardapio comAparencia(Map<String, dynamic> aparencia, {bool semFotos = false}) {
  final json = demoCardapioJson();
  return Cardapio.fromJson({
    ...json,
    'loja': {
      ...(json['loja'] as Map<String, dynamic>),
      'aparencia': aparencia,
      if (semFotos) 'capa_url': null,
      if (semFotos) 'imagens_destaque': <String>[],
    },
    if (semFotos)
      'produtos': [
        for (final p in json['produtos'] as List) {...(p as Map<String, dynamic>), 'imagem_url': null},
      ],
  });
}

final variantes = <String, Cardapio>{
  'bistro-lista-classica': comAparencia({
    'tema': 'bistro',
    'layout_cards': 'lista',
    'fonte': 'classica',
    'cantos': 'arredondado',
  }),
  'grafite-reto-moderna': comAparencia({'tema': 'grafite', 'fonte': 'moderna', 'cantos': 'reto'}),
  'cafe-elegante-sem-fotos': comAparencia({'tema': 'cafe', 'fonte': 'elegante'}, semFotos: true),
};

const sizes = {'celular': Size(360, 760), 'tablet-paisagem': Size(1280, 800), 'tablet-7-paisagem': Size(1024, 600)};

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    appImageDisableNetwork = true;
  });

  for (final MapEntry(key: variante, value: cardapio) in variantes.entries) {
    final pedidoNaFila = Pedido.pendente(
      NovoPedido(
        codigoAcesso: 'fila-1',
        tipoConsumo: TipoConsumo.local,
        mesa: 4,
        nomeCliente: 'Ana',
        formaPagamentoId: 1,
        observacao: '',
        origem: 'totem',
        criadoEm: DateTime(2026, 10, 12, 9, 30),
        itens: const [],
      ),
      subtotal: 42,
      taxaServico: 4.2,
      formaPagamento: 'Pagar no caixa',
      previsaoMin: 15,
    );
    final screens = <String, Widget Function()>{
      'attract': () => const AttractScreen(),
      'menu': () => const MenuScreen(),
      'checkout': () => const CheckoutScreen(),
      'sucesso-na-fila': () => OrderSuccessScreen(pedido: pedidoNaFila),
      'configuracoes': () => const SettingsScreen(),
    };

    for (final MapEntry(key: sizeName, value: size) in sizes.entries) {
      for (final MapEntry(key: name, value: build) in screens.entries) {
        testWidgets('$variante · $name · $sizeName', (tester) async {
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
              pedidoAoVivoProvider.overrideWith((ref, codigo) => Stream.value(pedidoNaFila)),
            ],
          );
          addTearDown(container.dispose);
          await container.read(cardapioProvider.future);
          container.read(sessaoProvider.notifier).setConsumo(TipoConsumo.local);

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                theme: buildTheme(Brightness.dark, aparencia: cardapio.loja.aparencia),
                home: build(),
              ),
            ),
          );
          for (var i = 0; i < 8; i++) {
            await tester.pump(const Duration(milliseconds: 500));
          }
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(seconds: 3));
          buildTheme(Brightness.dark); // restaura a escala de cantos
        });
      }
    }
  }
}
