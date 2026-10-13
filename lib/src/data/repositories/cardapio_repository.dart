import '../models/cardapio.dart';
import '../models/chamado.dart';
import '../models/pedido.dart';

/// Contrato entre o app e o Forven ERP.
///
/// Endpoints (prefixo `/api/externo/simuladores/cardapio`, Bearer = token do
/// simulador gerado em /e-commerce/simuladores/cardapio/configuracoes):
///   GET  /cardapio?versao={hash}   → pacote completo, ou {"inalterado": true}
///   POST /pedidos                  → [Pedido]  (cria Venda no ERP; idempotente por codigo_acesso)
///   GET  /pedidos/{codigo_acesso}  → [Pedido]
///   GET  /pedidos?mesa={n}         → [List<Pedido>]
///   GET  /mesas                    → [List<Mesa>]
///   POST /chamados                 → [Chamado] (botão "Chamar garçom"; idempotente por codigo)
///   GET  /chamados?garcom_id=      → [List<Chamado>] em aberto (celular do garçom)
///   GET  /chamados/{codigo}        → [Chamado]
///   PUT  /chamados/{codigo}        → [Chamado] (a_caminho | atendido | cancelado)
abstract interface class CardapioRepository {
  /// Baixa o cardápio. Com [versaoAtual], devolve `null` quando nada mudou
  /// no ERP (resposta de poucos bytes — o app segue com o que tem guardado).
  Future<PacoteCardapio?> baixarCardapio({String? versaoAtual});

  Future<Pedido> enviarPedido(NovoPedido pedido);

  Future<Pedido> consultarPedido(String codigoAcesso);

  Future<List<Pedido>> pedidosDaMesa(int mesa);

  Future<List<Mesa>> mesas();

  Future<Chamado> chamarGarcom(NovoChamado chamado);

  Future<Chamado> consultarChamado(String codigo);

  /// Chamados em aberto; com [garcomId], só os das mesas desse garçom (conforme o ERP).
  Future<List<Chamado>> chamadosAbertos({int? garcomId});

  Future<Chamado> atualizarChamado(String codigo, StatusChamado status, {int? garcomId});

  /// Lança [AppException] se não for possível falar com o ERP.
  Future<void> testarConexao();
}

/// Cardápio recém-baixado + o JSON original, que é o que fica guardado no aparelho.
class PacoteCardapio {
  PacoteCardapio(this.json) : cardapio = Cardapio.fromJson(json);

  final Map<String, dynamic> json;
  final Cardapio cardapio;

  String get versao => cardapio.versao;
}

class AppException implements Exception {
  const AppException(this.mensagem, {this.detalhe, this.temporario = false});

  final String mensagem;
  final String? detalhe;

  /// Falha de rede/servidor fora do ar: vale tentar de novo depois (o pedido
  /// fica na fila). `false` = o ERP recusou de fato (ex.: item esgotado).
  final bool temporario;

  @override
  String toString() => mensagem;
}
