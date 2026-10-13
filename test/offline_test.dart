// Offline-first: cardápio guardado no aparelho, sincronização por versão e
// fila de pedidos que sobrevive a queda de internet e a reinício do app.
import 'dart:convert';

import 'package:cardapio_digital/src/core/theme/app_theme.dart';
import 'package:cardapio_digital/src/core/theme/temas.dart';
import 'package:cardapio_digital/src/core/widgets/app_image.dart';
import 'package:cardapio_digital/src/data/models/cardapio.dart';
import 'package:cardapio_digital/src/data/models/chamado.dart';
import 'package:cardapio_digital/src/data/models/loja.dart';
import 'package:cardapio_digital/src/data/models/pedido.dart';
import 'package:cardapio_digital/src/data/repositories/cardapio_repository.dart';
import 'package:cardapio_digital/src/data/repositories/demo_data.dart';
import 'package:cardapio_digital/src/features/settings/settings_screen.dart';
import 'package:cardapio_digital/src/state/providers.dart';
import 'package:cardapio_digital/src/state/settings.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ERP de mentira: liga/desliga a "internet" e conta o que recebeu.
class ErpFalso implements CardapioRepository {
  bool online = true;
  String? recusar;
  int downloads = 0;
  int consultasSemMudanca = 0;
  final enviados = <String, int>{};
  Map<String, dynamic> json = {...demoCardapioJson(), 'versao': 'v1'};

  void _rede() {
    if (!online) throw const AppException('Sem conexão com o ERP.', temporario: true);
  }

  @override
  Future<PacoteCardapio?> baixarCardapio({String? versaoAtual}) async {
    _rede();
    if (versaoAtual == json['versao']) {
      consultasSemMudanca++;
      return null;
    }
    downloads++;
    return PacoteCardapio(json);
  }

  @override
  Future<Pedido> enviarPedido(NovoPedido novo) async {
    _rede();
    if (recusar != null) throw AppException(recusar!);
    enviados.update(novo.codigoAcesso, (n) => n + 1, ifAbsent: () => 1);
    return Pedido(
      id: 9,
      codigoAcesso: novo.codigoAcesso,
      numero: 501,
      tipoConsumo: novo.tipoConsumo,
      mesa: novo.mesa,
      nomeCliente: novo.nomeCliente,
      itens: novo.itens,
      observacao: novo.observacao,
      subtotal: 10,
      taxaServico: 1,
      total: 11,
      status: StatusPedido.recebido,
      criadoEm: novo.criadoEm,
      previsaoMin: 15,
      formaPagamento: 'Pagar no caixa',
    );
  }

  @override
  Future<Pedido> consultarPedido(String codigoAcesso) => throw UnimplementedError();

  @override
  Future<List<Pedido>> pedidosDaMesa(int mesa) async => [];

  @override
  Future<List<Mesa>> mesas() async => [];

  @override
  Future<void> testarConexao() async => _rede();

  final chamados = <String, Chamado>{};
  int chamadasRecebidas = 0;

  @override
  Future<Chamado> chamarGarcom(NovoChamado novo) async {
    _rede();
    chamadasRecebidas++;
    return chamados.putIfAbsent(
      novo.codigo,
      () => Chamado(
        id: chamados.length + 1,
        codigo: novo.codigo,
        mesa: novo.mesa,
        motivo: novo.motivo,
        motivoRotulo: 'Pedir a conta',
        status: StatusChamado.aberto,
        criadoEm: novo.criadoEm,
        garcomId: 1,
        garcomNome: 'Carla',
      ),
    );
  }

  @override
  Future<Chamado> consultarChamado(String codigo) async {
    _rede();
    return chamados[codigo]!;
  }

  @override
  Future<List<Chamado>> chamadosAbertos({int? garcomId}) async {
    _rede();
    return chamados.values.where((c) => c.status.emAberto).toList();
  }

  @override
  Future<Chamado> atualizarChamado(String codigo, StatusChamado status, {int? garcomId}) async {
    _rede();
    return chamados[codigo] = chamados[codigo]!.copyWith(status: status);
  }
}

NovoPedido novoPedido(String codigo) => NovoPedido(
  codigoAcesso: codigo,
  tipoConsumo: TipoConsumo.local,
  mesa: 7,
  nomeCliente: 'Ana',
  formaPagamentoId: 1,
  observacao: '',
  origem: 'totem',
  criadoEm: DateTime(2026, 10, 12, 9, 30),
  itens: const [
    PedidoItem(
      produtoId: 1,
      nome: 'Pão de queijo',
      imagemUrl: null,
      quantidade: 2,
      precoUnitario: 5.9,
      complementos: [],
      observacao: '',
    ),
  ],
);

Pedido previaDe(NovoPedido n) =>
    Pedido.pendente(n, subtotal: 11.8, taxaServico: 1.18, formaPagamento: 'Pagar no caixa', previsaoMin: 15);

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    appImageDisableNetwork = true;
  });

  late SharedPreferences prefs;
  late ErpFalso erp;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'configurado': true,
      'demo': false,
      'erp_url': 'http://10.0.2.2:8008',
      'erp_token': 'token-de-teste',
    });
    prefs = await SharedPreferences.getInstance();
    erp = ErpFalso();
  });

  /// Cada container é como uma nova abertura do app no mesmo aparelho.
  ProviderContainer abrirApp() {
    final c = ProviderContainer(
      retry: (_, _) => null,
      overrides: [prefsProvider.overrideWithValue(prefs), repositoryProvider.overrideWithValue(erp)],
    );
    addTearDown(c.dispose);
    return c;
  }

  group('cardápio offline', () {
    test('primeiro uso baixa e guarda; depois abre na hora, mesmo sem internet', () async {
      final primeira = abrirApp();
      final c1 = await primeira.read(cardapioProvider.future);
      expect(c1.produtos, isNotEmpty);
      expect(erp.downloads, 1);
      primeira.dispose();

      erp.online = false;
      final segunda = abrirApp();
      // Sem esperar rede: o valor já está disponível na primeira leitura.
      final estado = segunda.read(cardapioProvider);
      expect(estado, isA<AsyncData<Cardapio>>());
      expect(estado.value!.produtos.length, c1.produtos.length);

      // A busca de novidades em segundo plano falha em silêncio e marca "offline".
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(segunda.read(syncProvider).offline, isTrue);
      expect(segunda.read(cardapioProvider).value, isNotNull);
    });

    test('sincronização manda a versão e só baixa o pacote quando algo mudou', () async {
      final app = abrirApp();
      await app.read(cardapioProvider.future);
      final ctrl = app.read(cardapioProvider.notifier);

      expect(await ctrl.sincronizar(), isFalse);
      expect(erp.downloads, 1);
      expect(erp.consultasSemMudanca, greaterThanOrEqualTo(1));

      final loja = {...(erp.json['loja'] as Map<String, dynamic>), 'nome': 'Café Novo'};
      erp.json = {...erp.json, 'loja': loja, 'versao': 'v2'};
      expect(await ctrl.sincronizar(), isTrue);
      expect(app.read(cardapioProvider).value!.loja.nome, 'Café Novo');

      // A versão nova ficou guardada para a próxima abertura.
      erp.online = false;
      final depois = abrirApp();
      expect(depois.read(cardapioProvider).value!.loja.nome, 'Café Novo');
    });

    test('cardápio de outro ERP (ou outro token) não é reaproveitado', () async {
      await abrirApp().read(cardapioProvider.future);
      await prefs.setString('erp_token', 'outra-empresa');
      erp.online = false;
      final app = abrirApp();
      await expectLater(app.read(cardapioProvider.future), throwsA(isA<AppException>()));
    });
  });

  group('fila de pedidos', () {
    test('sem internet o pedido fica guardado e sai sozinho depois — uma vez só', () async {
      erp.online = false;
      final app = abrirApp();
      final novo = novoPedido('11111111-1111-4111-8111-111111111111');
      final pedido = await app.read(filaPedidosProvider.notifier).registrar(novo, previaDe(novo));
      app.read(meusPedidosProvider.notifier).add(pedido);

      expect(pedido.sincronizado, isFalse);
      expect(pedido.senha, 'Na fila');
      expect(app.read(filaPedidosProvider), hasLength(1));
      app.dispose();

      // App reiniciado: a fila e o pedido continuam lá.
      final reaberto = abrirApp();
      expect(reaberto.read(filaPedidosProvider), hasLength(1));
      expect(reaberto.read(meusPedidosProvider).single.sincronizado, isFalse);

      erp.online = true;
      await reaberto.read(filaPedidosProvider.notifier).processar();
      await reaberto.read(filaPedidosProvider.notifier).processar();

      expect(erp.enviados[novo.codigoAcesso], 1);
      expect(reaberto.read(filaPedidosProvider), isEmpty);
      final oficial = reaberto.read(meusPedidosProvider).single;
      expect(oficial.sincronizado, isTrue);
      expect(oficial.senha, '#501');
    });

    test('com internet o pedido sai na hora e a fila fica vazia', () async {
      final app = abrirApp();
      final novo = novoPedido('22222222-2222-4222-8222-222222222222');
      final pedido = await app.read(filaPedidosProvider.notifier).registrar(novo, previaDe(novo));
      expect(pedido.numero, 501);
      expect(app.read(filaPedidosProvider), isEmpty);
    });

    test('recusa do ERP na hora do pedido não deixa nada na fila', () async {
      erp.recusar = 'Coxinha está esgotado no momento.';
      final app = abrirApp();
      final novo = novoPedido('33333333-3333-4333-8333-333333333333');
      await expectLater(
        app.read(filaPedidosProvider.notifier).registrar(novo, previaDe(novo)),
        throwsA(isA<AppException>().having((e) => e.mensagem, 'mensagem', contains('esgotado'))),
      );
      expect(app.read(filaPedidosProvider), isEmpty);
    });

    test('recusa depois de estar na fila: sai da fila e o pedido mostra o motivo', () async {
      erp.online = false;
      final app = abrirApp();
      final novo = novoPedido('44444444-4444-4444-8444-444444444444');
      final previa = await app.read(filaPedidosProvider.notifier).registrar(novo, previaDe(novo));
      app.read(meusPedidosProvider.notifier).add(previa);

      erp
        ..online = true
        ..recusar = 'Item fora do cardápio.';
      await app.read(filaPedidosProvider.notifier).processar();

      expect(app.read(filaPedidosProvider), isEmpty);
      final p = app.read(meusPedidosProvider).single;
      expect(p.status, StatusPedido.cancelado);
      expect(p.erroEnvio, 'Item fora do cardápio.');
    });
  });

  group('chamar garçom', () {
    const conta = MotivoChamado(chave: 'conta', rotulo: 'Pedir a conta', icone: 'conta');

    test('chama o garçom da mesa e libera o sino de novo só depois do intervalo', () async {
      final app = abrirApp();
      await app.read(cardapioProvider.future);
      await app.read(chamadoMesaProvider.notifier).chamar(conta, 7);

      final estado = app.read(chamadoMesaProvider);
      expect(estado.emAberto, isTrue);
      expect(estado.chamado!.sincronizado, isTrue);
      expect(estado.chamado!.quemVem, 'Carla');
      expect(estado.liberado(DateTime.now()), isFalse);
      expect(erp.chamadasRecebidas, 1);

      await app.read(chamadoMesaProvider.notifier).cancelar();
      expect(app.read(chamadoMesaProvider).emAberto, isFalse);
      expect(erp.chamados.values.single.status, StatusChamado.cancelado);
    });

    test('sem internet o chamado fica guardado e é entregue quando a conexão volta', () async {
      final app = abrirApp();
      await app.read(cardapioProvider.future);
      erp.online = false;
      await app.read(chamadoMesaProvider.notifier).chamar(conta, 7);

      final local = app.read(chamadoMesaProvider).chamado!;
      expect(local.sincronizado, isFalse);
      expect(erp.chamados, isEmpty);

      erp.online = true;
      await app.read(chamadoMesaProvider.notifier).reenviarPendente();
      await app.read(chamadoMesaProvider.notifier).reenviarPendente();

      expect(app.read(chamadoMesaProvider).chamado!.sincronizado, isTrue);
      expect(erp.chamados.keys.single, local.codigo);
    });

    test('pacote do ERP traz o botão, os motivos, os garçons e o responsável de cada mesa', () {
      final c = Cardapio.fromJson(demoCardapioJson());
      expect(c.loja.chamarGarcom.disponivel, isTrue);
      expect(c.loja.chamarGarcom.motivos.map((m) => m.chave), contains('conta'));
      expect(c.garcons.map((g) => g.nome), ['Carla', 'Diego', 'Bruna']);
      expect(c.mesa(12)!.garcomNome, 'Diego');
      final desligado = Cardapio.fromJson({
        ...demoCardapioJson(),
        'loja': {
          ...(demoCardapioJson()['loja'] as Map<String, dynamic>),
          'chamar_garcom': {'ativo': false},
        },
      });
      expect(desligado.loja.chamarGarcom.disponivel, isFalse);
    });
  });

  group('configuração vinda do ERP', () {
    test('PIN do ERP é conferido pelo hash (sha256 de sal + PIN), sem internet', () {
      const sal = 'a1b2c3d4e5f60718';
      final s = SegurancaPin(hash: sha256.convert(utf8.encode('${sal}4321')).toString(), sal: sal);
      expect(conferirPin('4321', s), isTrue);
      expect(conferirPin('1234', s), isFalse);
      expect(conferirPin('43210', s), isFalse);
    });

    test('aparência do ERP: tema, claro/escuro, cores próprias e cantos', () {
      for (final t in temasCardapio) {
        final tema = buildTheme(Brightness.dark, aparencia: AparenciaCardapio(tema: t.valor));
        expect(tema.brightness, t.valor == 'claro' || t.valor == 'bistro' ? Brightness.light : Brightness.dark);
      }
      final custom = buildTheme(
        Brightness.dark,
        aparencia: const AparenciaCardapio(tema: 'cafe', corPrimaria: Color(0xFF00AA55), cantos: 'reto'),
      );
      expect(custom.colorScheme.primary, const Color(0xFF00AA55));
      buildTheme(Brightness.dark); // volta a escala padrão para os outros testes
    });

    test('pacote do ERP: mesas, versão, PIN, intervalo e fotos opcionais', () {
      final json = {
        ...demoCardapioJson(),
        'versao': 'abc',
        'mesas': [
          {'numero': 3, 'nome': null, 'lugares': 4, 'area': 'Varanda'},
          {'numero': 8, 'nome': 'Janela', 'lugares': 2, 'area': 'Salão'},
        ],
      };
      final loja = {
        ...(json['loja'] as Map<String, dynamic>),
        'capa_url': null,
        'seguranca': {'pin_hash': 'h', 'pin_salt': 's'},
        'sincronizacao': {'intervalo_min': 3},
        'aparencia': {'tema': 'bistro', 'layout_cards': 'lista', 'cor_primaria': null},
      };
      final produtos = [
        for (final p in json['produtos'] as List) {...(p as Map<String, dynamic>), 'imagem_url': null},
      ];
      final c = Cardapio.fromJson({...json, 'loja': loja, 'produtos': produtos});
      expect(c.versao, 'abc');
      expect(c.numerosMesas, [3, 8]);
      expect(c.loja.seguranca, isNotNull);
      expect(c.loja.intervaloSincronizacaoMin, 3);
      expect(c.loja.aparencia.lista, isTrue);
      expect(c.loja.capaUrl, isNull);
      expect(c.produtos.first.imagemUrl, isNull);
    });
  });
}
