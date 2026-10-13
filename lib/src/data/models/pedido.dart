import 'package:flutter/foundation.dart';

import 'loja.dart';

enum StatusPedido {
  recebido('recebido', 'Recebido', 'Seu pedido chegou na cozinha'),
  emPreparo('em_preparo', 'Em preparo', 'Estamos preparando com carinho'),
  pronto('pronto', 'Pronto', 'Já está saindo!'),
  entregue('entregue', 'Entregue', 'Bom apetite!'),
  cancelado('cancelado', 'Cancelado', 'Fale com um atendente');

  const StatusPedido(this.api, this.rotulo, this.mensagem);
  final String api;
  final String rotulo;
  final String mensagem;

  static StatusPedido fromApi(String v) => values.firstWhere((e) => e.api == v, orElse: () => recebido);

  /// Etapas exibidas na linha do tempo.
  static const fluxo = [recebido, emPreparo, pronto, entregue];
}

@immutable
class PedidoComplemento {
  const PedidoComplemento({
    required this.grupoId,
    required this.opcaoId,
    required this.nome,
    required this.quantidade,
    required this.precoUnitario,
  });

  final int grupoId;
  final int opcaoId;
  final String nome;
  final int quantidade;
  final double precoUnitario;

  Map<String, dynamic> toJson() => {'grupo_id': grupoId, 'opcao_id': opcaoId, 'quantidade': quantidade};

  /// Formato completo (com nome e preço) para guardar no aparelho.
  Map<String, dynamic> toStorage() => {...toJson(), 'nome': nome, 'preco_unitario': precoUnitario};

  factory PedidoComplemento.fromJson(Map<String, dynamic> j) => PedidoComplemento(
    grupoId: j['grupo_id'] as int,
    opcaoId: j['opcao_id'] as int,
    nome: (j['nome'] as String?) ?? '',
    quantidade: (j['quantidade'] as int?) ?? 1,
    precoUnitario: ((j['preco_unitario'] as num?) ?? 0).toDouble(),
  );
}

@immutable
class PedidoItem {
  const PedidoItem({
    required this.produtoId,
    required this.nome,
    required this.imagemUrl,
    required this.quantidade,
    required this.precoUnitario,
    required this.complementos,
    required this.observacao,
  });

  final int produtoId;
  final String nome;
  final String? imagemUrl;
  final int quantidade;

  /// Preço unitário já com complementos.
  final double precoUnitario;
  final List<PedidoComplemento> complementos;
  final String observacao;

  double get total => precoUnitario * quantidade;

  /// O servidor recalcula preços: o app envia só ids e quantidades.
  Map<String, dynamic> toJson() => {
    'produto_id': produtoId,
    'quantidade': quantidade,
    'observacao': observacao,
    'complementos': complementos.map((c) => c.toJson()).toList(),
  };

  /// Formato completo (o mesmo que o ERP devolve) para guardar no aparelho.
  Map<String, dynamic> toStorage() => {
    'produto_id': produtoId,
    'nome': nome,
    'imagem_url': imagemUrl,
    'quantidade': quantidade,
    'preco_unitario': precoUnitario,
    'complementos': complementos.map((c) => c.toStorage()).toList(),
    'observacao': observacao,
  };

  factory PedidoItem.fromJson(Map<String, dynamic> j) => PedidoItem(
    produtoId: j['produto_id'] as int,
    nome: j['nome'] as String,
    imagemUrl: j['imagem_url'] as String?,
    quantidade: j['quantidade'] as int,
    precoUnitario: (j['preco_unitario'] as num).toDouble(),
    complementos: ((j['complementos'] as List?) ?? const [])
        .map((e) => PedidoComplemento.fromJson(e as Map<String, dynamic>))
        .toList(),
    observacao: (j['observacao'] as String?) ?? '',
  );
}

/// Corpo de `POST externo/simuladores/cardapio/pedidos`. Vira uma Venda no ERP
/// (faturamento_vendas), no mesmo fluxo da integração WooCommerce.
@immutable
class NovoPedido {
  const NovoPedido({
    required this.codigoAcesso,
    required this.tipoConsumo,
    required this.mesa,
    required this.nomeCliente,
    required this.formaPagamentoId,
    required this.observacao,
    required this.itens,
    required this.origem,
    required this.criadoEm,
  });

  /// UUID gerado no app — idempotência (equivale ao order_key do Woo).
  /// Reenviar o mesmo pedido (fila offline) nunca duplica a venda.
  final String codigoAcesso;
  final TipoConsumo tipoConsumo;
  final int? mesa;
  final String nomeCliente;
  final int? formaPagamentoId;
  final String observacao;
  final List<PedidoItem> itens;

  /// totem | garcom
  final String origem;

  /// Hora em que o cliente confirmou (pode ser bem antes do envio, se estava offline).
  final DateTime criadoEm;

  Map<String, dynamic> toJson() => {
    'codigo_acesso': codigoAcesso,
    'tipo_consumo': tipoConsumo.api,
    'mesa': mesa,
    'nome_cliente': nomeCliente,
    'forma_pagamento_id': formaPagamentoId,
    'observacao': observacao,
    'origem': origem,
    'criado_em': criadoEm.toUtc().toIso8601String(),
    'itens': itens.map((i) => i.toJson()).toList(),
  };

  Map<String, dynamic> toStorage() => {...toJson(), 'itens': itens.map((i) => i.toStorage()).toList()};

  factory NovoPedido.fromStorage(Map<String, dynamic> j) => NovoPedido(
    codigoAcesso: j['codigo_acesso'] as String,
    tipoConsumo: TipoConsumo.fromApi(j['tipo_consumo'] as String),
    mesa: j['mesa'] as int?,
    nomeCliente: (j['nome_cliente'] as String?) ?? '',
    formaPagamentoId: j['forma_pagamento_id'] as int?,
    observacao: (j['observacao'] as String?) ?? '',
    origem: (j['origem'] as String?) ?? 'totem',
    criadoEm: DateTime.parse(j['criado_em'] as String).toLocal(),
    itens: ((j['itens'] as List?) ?? const []).map((e) => PedidoItem.fromJson(e as Map<String, dynamic>)).toList(),
  );
}

@immutable
class Pedido {
  const Pedido({
    required this.id,
    required this.codigoAcesso,
    required this.numero,
    required this.tipoConsumo,
    required this.mesa,
    required this.nomeCliente,
    required this.itens,
    required this.observacao,
    required this.subtotal,
    required this.taxaServico,
    required this.total,
    required this.status,
    required this.criadoEm,
    required this.previsaoMin,
    required this.formaPagamento,
    this.sincronizado = true,
    this.erroEnvio,
  });

  /// Pedido feito sem internet: fica na fila do aparelho até o ERP confirmar.
  factory Pedido.pendente(
    NovoPedido novo, {
    required double subtotal,
    required double taxaServico,
    required String formaPagamento,
    required int previsaoMin,
  }) => Pedido(
    id: 0,
    codigoAcesso: novo.codigoAcesso,
    numero: 0,
    tipoConsumo: novo.tipoConsumo,
    mesa: novo.mesa,
    nomeCliente: novo.nomeCliente,
    itens: novo.itens,
    observacao: novo.observacao,
    subtotal: subtotal,
    taxaServico: taxaServico,
    total: subtotal + taxaServico,
    status: StatusPedido.recebido,
    criadoEm: novo.criadoEm,
    previsaoMin: previsaoMin,
    formaPagamento: formaPagamento,
    sincronizado: false,
  );

  final int id;
  final String codigoAcesso;

  /// Número curto exibido ao cliente (senha).
  final int numero;
  final TipoConsumo tipoConsumo;
  final int? mesa;
  final String nomeCliente;
  final List<PedidoItem> itens;
  final String observacao;
  final double subtotal;
  final double taxaServico;
  final double total;
  final StatusPedido status;
  final DateTime criadoEm;
  final int previsaoMin;
  final String formaPagamento;

  /// false = ainda na fila do aparelho (sem número do ERP).
  final bool sincronizado;

  /// Motivo quando o ERP recusou um pedido que estava na fila.
  final String? erroEnvio;

  /// "#427" ou "Na fila" enquanto o ERP não confirmou.
  String get senha => sincronizado ? '#$numero' : 'Na fila';

  int get quantidadeItens => itens.fold(0, (s, i) => s + i.quantidade);

  Pedido copyWith({StatusPedido? status, String? erroEnvio}) => Pedido(
    id: id,
    codigoAcesso: codigoAcesso,
    numero: numero,
    tipoConsumo: tipoConsumo,
    mesa: mesa,
    nomeCliente: nomeCliente,
    itens: itens,
    observacao: observacao,
    subtotal: subtotal,
    taxaServico: taxaServico,
    total: total,
    status: status ?? this.status,
    criadoEm: criadoEm,
    previsaoMin: previsaoMin,
    formaPagamento: formaPagamento,
    sincronizado: sincronizado,
    erroEnvio: erroEnvio ?? this.erroEnvio,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'codigo_acesso': codigoAcesso,
    'numero': numero,
    'tipo_consumo': tipoConsumo.api,
    'mesa': mesa,
    'nome_cliente': nomeCliente,
    'itens': itens.map((i) => i.toStorage()).toList(),
    'observacao': observacao,
    'subtotal': subtotal,
    'taxa_servico': taxaServico,
    'total': total,
    'status': status.api,
    'criado_em': criadoEm.toUtc().toIso8601String(),
    'previsao_min': previsaoMin,
    'forma_pagamento': formaPagamento,
    'sincronizado': sincronizado,
    'erro_envio': erroEnvio,
  };

  factory Pedido.fromJson(Map<String, dynamic> j) => Pedido(
    id: j['id'] as int,
    codigoAcesso: j['codigo_acesso'] as String,
    numero: j['numero'] as int,
    tipoConsumo: TipoConsumo.fromApi(j['tipo_consumo'] as String),
    mesa: j['mesa'] as int?,
    nomeCliente: (j['nome_cliente'] as String?) ?? '',
    itens: ((j['itens'] as List?) ?? const []).map((e) => PedidoItem.fromJson(e as Map<String, dynamic>)).toList(),
    observacao: (j['observacao'] as String?) ?? '',
    subtotal: (j['subtotal'] as num).toDouble(),
    taxaServico: ((j['taxa_servico'] as num?) ?? 0).toDouble(),
    total: (j['total'] as num).toDouble(),
    status: StatusPedido.fromApi(j['status'] as String),
    criadoEm: DateTime.parse(j['criado_em'] as String).toLocal(),
    previsaoMin: (j['previsao_min'] as int?) ?? 20,
    formaPagamento: (j['forma_pagamento'] as String?) ?? '',
    sincronizado: (j['sincronizado'] as bool?) ?? true,
    erroEnvio: j['erro_envio'] as String?,
  );
}

enum StatusMesa {
  livre('livre', 'Livre'),
  ocupada('ocupada', 'Ocupada'),
  conta('conta', 'Pediu a conta');

  const StatusMesa(this.api, this.rotulo);
  final String api;
  final String rotulo;

  static StatusMesa fromApi(String v) => values.firstWhere((e) => e.api == v, orElse: () => livre);
}

@immutable
class Mesa {
  const Mesa({
    required this.numero,
    required this.lugares,
    required this.status,
    required this.totalConsumido,
    required this.abertaEm,
    required this.area,
    this.garcomNome,
    this.chamado,
  });

  final int numero;
  final int lugares;
  final StatusMesa status;
  final double totalConsumido;
  final DateTime? abertaEm;

  /// Salão, Varanda, Balcão…
  final String area;
  final String? garcomNome;

  /// Motivo do chamado em aberto ("Pedir a conta"), se houver.
  final String? chamado;

  factory Mesa.fromJson(Map<String, dynamic> j) => Mesa(
    numero: j['numero'] as int,
    lugares: (j['lugares'] as int?) ?? 4,
    status: StatusMesa.fromApi(j['status'] as String),
    totalConsumido: ((j['total_consumido'] as num?) ?? 0).toDouble(),
    abertaEm: j['aberta_em'] == null ? null : DateTime.parse(j['aberta_em'] as String).toLocal(),
    area: (j['area'] as String?) ?? 'Salão',
    garcomNome: j['garcom_nome'] as String?,
    chamado: (j['chamado'] as Map<String, dynamic>?)?['motivo'] as String?,
  );
}
