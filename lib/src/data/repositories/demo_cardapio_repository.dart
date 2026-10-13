import 'dart:math';

import '../models/cardapio.dart';
import '../models/chamado.dart';
import '../models/loja.dart';
import '../models/pedido.dart';
import 'cardapio_repository.dart';
import 'demo_data.dart';

/// Simula o ERP em memória: latência realista e status de pedido que avança
/// sozinho (recebido → em preparo → pronto → entregue).
class DemoCardapioRepository implements CardapioRepository {
  DemoCardapioRepository({this.latency = const Duration(milliseconds: 650)});

  final Duration latency;
  final _pedidos = <Pedido>[];
  final _chamados = <Chamado>[
    // Já chegam dois chamados para o modo Garçom ter o que mostrar.
    Chamado(
      id: 1,
      codigo: 'demo-chamado-7',
      mesa: 7,
      motivo: 'conta',
      motivoRotulo: 'Pedir a conta',
      status: StatusChamado.aberto,
      criadoEm: DateTime.now().subtract(const Duration(minutes: 2)),
      garcomId: 1,
      garcomNome: 'Carla',
    ),
    Chamado(
      id: 2,
      codigo: 'demo-chamado-12',
      mesa: 12,
      motivo: 'garcom',
      motivoRotulo: 'Chamar o garçom',
      status: StatusChamado.aberto,
      criadoEm: DateTime.now().subtract(const Duration(seconds: 40)),
      garcomId: 2,
      garcomNome: 'Diego',
    ),
  ];
  final _rand = Random();
  int _proximoNumero = 400 + Random().nextInt(80);
  Cardapio? _cache;

  Future<void> _delay([double factor = 1]) => Future.delayed(latency * (factor * (0.7 + _rand.nextDouble() * 0.6)));

  /// O demo nunca muda: depois do primeiro download responde "inalterado".
  static const versaoDemo = 'demo-1';

  @override
  Future<PacoteCardapio?> baixarCardapio({String? versaoAtual}) async {
    await _delay(1.4);
    if (versaoAtual == versaoDemo) return null;
    final pacote = PacoteCardapio({...demoCardapioJson(), 'versao': versaoDemo});
    _cache = pacote.cardapio;
    return pacote;
  }

  StatusPedido _statusPor(Pedido p) {
    final s = DateTime.now().difference(p.criadoEm).inSeconds;
    if (s < 20) return StatusPedido.recebido;
    if (s < 60) return StatusPedido.emPreparo;
    if (s < 100) return StatusPedido.pronto;
    return StatusPedido.entregue;
  }

  Pedido _atual(Pedido p) => p.copyWith(status: _statusPor(p));

  @override
  Future<Pedido> enviarPedido(NovoPedido novo) async {
    await _delay(2.2);
    final existente = _pedidos.where((p) => p.codigoAcesso == novo.codigoAcesso);
    if (existente.isNotEmpty) return _atual(existente.first);

    final cardapio = _cache ?? Cardapio.fromJson(demoCardapioJson());
    // Igual ao ERP: recalcula preço a partir do cadastro, ignorando o que veio do app.
    final itens = novo.itens.map((i) {
      final produto = cardapio.produto(i.produtoId)!;
      var unit = produto.preco;
      final comps = <PedidoComplemento>[];
      for (final c in i.complementos) {
        final grupo = produto.grupos.firstWhere((g) => g.id == c.grupoId);
        final opcao = grupo.opcoes.firstWhere((o) => o.id == c.opcaoId);
        unit += opcao.precoAdicional * c.quantidade;
        comps.add(
          PedidoComplemento(
            grupoId: c.grupoId,
            opcaoId: c.opcaoId,
            nome: opcao.nome,
            quantidade: c.quantidade,
            precoUnitario: opcao.precoAdicional,
          ),
        );
      }
      return PedidoItem(
        produtoId: produto.id,
        nome: produto.nome,
        imagemUrl: produto.imagemUrl,
        quantidade: i.quantidade,
        precoUnitario: unit,
        complementos: comps,
        observacao: i.observacao,
      );
    }).toList();

    final subtotal = itens.fold<double>(0, (s, i) => s + i.total);
    final cobraTaxa = novo.tipoConsumo == TipoConsumo.local || cardapio.loja.taxaServicoViagem;
    final taxa = cobraTaxa ? (subtotal * cardapio.loja.taxaServicoPercentual / 100 * 100).roundToDouble() / 100 : 0.0;
    final forma = cardapio.loja.formasPagamento.where((f) => f.id == novo.formaPagamentoId);

    final pedido = Pedido(
      id: _pedidos.length + 1,
      codigoAcesso: novo.codigoAcesso,
      numero: _proximoNumero++,
      tipoConsumo: novo.tipoConsumo,
      mesa: novo.mesa,
      nomeCliente: novo.nomeCliente,
      itens: itens,
      observacao: novo.observacao,
      subtotal: subtotal,
      taxaServico: taxa,
      total: subtotal + taxa,
      status: StatusPedido.recebido,
      criadoEm: novo.criadoEm,
      previsaoMin: cardapio.loja.tempoMedioPreparoMin,
      formaPagamento: forma.isEmpty ? '' : forma.first.nome,
    );
    _pedidos.add(pedido);
    return pedido;
  }

  @override
  Future<Pedido> consultarPedido(String codigoAcesso) async {
    await _delay(0.4);
    final p = _pedidos.firstWhere(
      (p) => p.codigoAcesso == codigoAcesso,
      orElse: () => throw const AppException('Pedido não encontrado.'),
    );
    return _atual(p);
  }

  @override
  Future<List<Pedido>> pedidosDaMesa(int mesa) async {
    await _delay(0.5);
    return _pedidos.where((p) => p.mesa == mesa).map(_atual).toList().reversed.toList();
  }

  @override
  Future<List<Mesa>> mesas() async {
    await _delay(0.8);
    final base = demoMesasJson(DateTime.now()).map(Mesa.fromJson).toList();
    return [
      for (final m in base)
        () {
          final doApp = _pedidos.where((p) => p.mesa == m.numero).toList();
          if (doApp.isEmpty) return m;
          final total = doApp.fold<double>(0, (s, p) => s + p.total);
          return Mesa(
            numero: m.numero,
            lugares: m.lugares,
            status: m.status == StatusMesa.livre ? StatusMesa.ocupada : m.status,
            totalConsumido: m.totalConsumido + total,
            abertaEm: m.abertaEm ?? doApp.first.criadoEm,
            area: m.area,
          );
        }(),
    ];
  }

  /// Simula o garçom: "a caminho" depois de 8 s e "atendido" depois de 30 s.
  Chamado _chamadoAtual(Chamado c) {
    if (!c.status.emAberto || c.codigo.startsWith('demo-')) return c;
    final s = DateTime.now().difference(c.criadoEm).inSeconds;
    if (s >= 30) return c.copyWith(status: StatusChamado.atendido, atendidoPorNome: c.garcomNome ?? 'Equipe');
    if (s >= 8) return c.copyWith(status: StatusChamado.aCaminho, atendidoPorNome: c.garcomNome ?? 'Equipe');
    return c;
  }

  @override
  Future<Chamado> chamarGarcom(NovoChamado novo) async {
    await _delay(0.5);
    for (final c in _chamados) {
      if (c.codigo == novo.codigo ||
          (c.mesa == novo.mesa && c.motivo == novo.motivo && _chamadoAtual(c).status.emAberto)) {
        return _chamadoAtual(c);
      }
    }
    final cardapio = _cache ?? Cardapio.fromJson(demoCardapioJson());
    final motivo = cardapio.loja.chamarGarcom.motivos.firstWhere(
      (m) => m.chave == novo.motivo,
      orElse: () => throw const AppException('Motivo de chamado indisponível. Atualize o cardápio.'),
    );
    final mesa = cardapio.mesa(novo.mesa);
    final c = Chamado(
      id: _chamados.length + 1,
      codigo: novo.codigo,
      mesa: novo.mesa,
      motivo: motivo.chave,
      motivoRotulo: motivo.rotulo,
      status: StatusChamado.aberto,
      criadoEm: novo.criadoEm,
      garcomId: mesa?.garcomId,
      garcomNome: mesa?.garcomNome,
    );
    _chamados.add(c);
    return c;
  }

  @override
  Future<Chamado> consultarChamado(String codigo) async {
    await _delay(0.3);
    return _chamadoAtual(
      _chamados.firstWhere(
        (c) => c.codigo == codigo,
        orElse: () => throw const AppException('Chamado não encontrado.'),
      ),
    );
  }

  @override
  Future<List<Chamado>> chamadosAbertos({int? garcomId}) async {
    await _delay(0.3);
    return _chamados
        .map(_chamadoAtual)
        .where((c) => c.status.emAberto && (garcomId == null || c.garcomId == null || c.garcomId == garcomId))
        .toList();
  }

  @override
  Future<Chamado> atualizarChamado(String codigo, StatusChamado status, {int? garcomId}) async {
    await _delay(0.3);
    final i = _chamados.indexWhere((c) => c.codigo == codigo);
    if (i < 0) throw const AppException('Chamado não encontrado.');
    final nome = switch (garcomId) {
      1 => 'Carla',
      2 => 'Diego',
      3 => 'Bruna',
      _ => null,
    };
    _chamados[i] = _chamados[i].copyWith(status: status, atendidoPorNome: nome);
    return _chamados[i];
  }

  @override
  Future<void> testarConexao() => _delay(0.6);
}
