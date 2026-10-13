import 'package:flutter/foundation.dart';

/// Opção do botão "Chamar garçom" (configurada em ERP › Simuladores › Cardápio › Garçons & chamados).
@immutable
class MotivoChamado {
  const MotivoChamado({required this.chave, required this.rotulo, required this.icone});

  final String chave;
  final String rotulo;

  /// sino | conta | ajuda | talheres | agua | limpeza | cardapio | pagamento
  final String icone;

  factory MotivoChamado.fromJson(Map<String, dynamic> j) => MotivoChamado(
    chave: j['chave'] as String,
    rotulo: j['rotulo'] as String,
    icone: (j['icone'] as String?) ?? 'sino',
  );
}

/// Configuração do botão "Chamar garçom" vinda do ERP.
@immutable
class ChamarGarcomConfig {
  const ChamarGarcomConfig({
    this.ativo = false,
    this.motivos = const [],
    this.intervaloSeg = 60,
    this.todosVeem = false,
  });

  final bool ativo;
  final List<MotivoChamado> motivos;

  /// Depois de chamar, espera este tempo antes de permitir outro chamado.
  final int intervaloSeg;

  /// true = todo garçom vê todos os chamados.
  final bool todosVeem;

  bool get disponivel => ativo && motivos.isNotEmpty;

  factory ChamarGarcomConfig.fromJson(Object? j) {
    if (j is! Map<String, dynamic>) return const ChamarGarcomConfig();
    return ChamarGarcomConfig(
      ativo: (j['ativo'] as bool?) ?? false,
      motivos: ((j['motivos'] as List?) ?? const [])
          .map((e) => MotivoChamado.fromJson(e as Map<String, dynamic>))
          .toList(),
      intervaloSeg: (j['intervalo_seg'] as num?)?.toInt() ?? 60,
      todosVeem: (j['todos_veem'] as bool?) ?? false,
    );
  }
}

/// Garçom cadastrado no ERP (o celular escolhe "quem sou eu" para filtrar os chamados).
@immutable
class GarcomInfo {
  const GarcomInfo({required this.id, required this.nome});

  final int id;
  final String nome;

  factory GarcomInfo.fromJson(Map<String, dynamic> j) => GarcomInfo(id: j['id'] as int, nome: j['nome'] as String);
}

enum StatusChamado {
  aberto('aberto', 'Aguardando'),
  aCaminho('a_caminho', 'A caminho'),
  atendido('atendido', 'Atendido'),
  cancelado('cancelado', 'Cancelado');

  const StatusChamado(this.api, this.rotulo);
  final String api;
  final String rotulo;

  static StatusChamado fromApi(String v) => values.firstWhere((e) => e.api == v, orElse: () => aberto);

  bool get emAberto => this == aberto || this == aCaminho;
}

/// Corpo de `POST externo/simuladores/cardapio/chamados`.
@immutable
class NovoChamado {
  const NovoChamado({required this.codigo, required this.mesa, required this.motivo, required this.criadoEm});

  /// UUID gerado no app: reenviar (sem internet) nunca duplica o chamado.
  final String codigo;
  final int mesa;
  final String motivo;
  final DateTime criadoEm;

  Map<String, dynamic> toJson() => {
    'codigo': codigo,
    'mesa': mesa,
    'motivo': motivo,
    'criado_em': criadoEm.toUtc().toIso8601String(),
  };
}

@immutable
class Chamado {
  const Chamado({
    required this.codigo,
    required this.mesa,
    required this.motivo,
    required this.motivoRotulo,
    required this.status,
    required this.criadoEm,
    this.id = 0,
    this.garcomId,
    this.garcomNome,
    this.atendidoPorNome,
    this.aCaminhoEm,
    this.atendidoEm,
    this.sincronizado = true,
  });

  /// Chamado feito sem internet: aparece na hora e sai quando a conexão voltar.
  factory Chamado.local(NovoChamado novo, MotivoChamado motivo, {int? garcomId, String? garcomNome}) => Chamado(
    codigo: novo.codigo,
    mesa: novo.mesa,
    motivo: motivo.chave,
    motivoRotulo: motivo.rotulo,
    status: StatusChamado.aberto,
    criadoEm: novo.criadoEm,
    garcomId: garcomId,
    garcomNome: garcomNome,
    sincronizado: false,
  );

  final int id;
  final String codigo;
  final int mesa;
  final String motivo;
  final String motivoRotulo;
  final StatusChamado status;
  final DateTime criadoEm;

  /// Garçom responsável pela mesa (null = vai para todos).
  final int? garcomId;
  final String? garcomNome;

  /// Quem marcou "a caminho"/"atendido".
  final String? atendidoPorNome;
  final DateTime? aCaminhoEm;
  final DateTime? atendidoEm;
  final bool sincronizado;

  /// Nome de quem vem até a mesa ("Carla"), se já se sabe.
  String? get quemVem => atendidoPorNome ?? garcomNome;

  Chamado copyWith({StatusChamado? status, String? atendidoPorNome}) => Chamado(
    id: id,
    codigo: codigo,
    mesa: mesa,
    motivo: motivo,
    motivoRotulo: motivoRotulo,
    status: status ?? this.status,
    criadoEm: criadoEm,
    garcomId: garcomId,
    garcomNome: garcomNome,
    atendidoPorNome: atendidoPorNome ?? this.atendidoPorNome,
    aCaminhoEm: aCaminhoEm,
    atendidoEm: atendidoEm,
    sincronizado: sincronizado,
  );

  static DateTime? _data(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;

  factory Chamado.fromJson(Map<String, dynamic> j) => Chamado(
    id: (j['id'] as int?) ?? 0,
    codigo: j['codigo'] as String,
    mesa: j['mesa'] as int,
    motivo: j['motivo'] as String,
    motivoRotulo: (j['motivo_rotulo'] as String?) ?? '',
    status: StatusChamado.fromApi(j['status'] as String),
    criadoEm: _data(j['criado_em']) ?? DateTime.now(),
    garcomId: j['garcom_id'] as int?,
    garcomNome: j['garcom_nome'] as String?,
    atendidoPorNome: j['atendido_por_nome'] as String?,
    aCaminhoEm: _data(j['a_caminho_em']),
    atendidoEm: _data(j['atendido_em']),
  );
}
