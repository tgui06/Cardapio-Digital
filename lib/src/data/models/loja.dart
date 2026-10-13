import 'package:flutter/material.dart';

import '../../core/utils/format.dart';
import 'chamado.dart';

/// Janela de horário "HH:mm"–"HH:mm". Aceita janelas que cruzam a meia-noite.
@immutable
class JanelaHorario {
  const JanelaHorario({required this.inicio, required this.fim});

  final String inicio;
  final String fim;

  factory JanelaHorario.fromJson(Map<String, dynamic> j) =>
      JanelaHorario(inicio: j['inicio'] as String, fim: j['fim'] as String);

  Map<String, dynamic> toJson() => {'inicio': inicio, 'fim': fim};

  static int _min(String hhmm) {
    final p = hhmm.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }

  bool contem(DateTime t) {
    final now = t.hour * 60 + t.minute;
    final a = _min(inicio);
    final b = _min(fim);
    return a <= b ? now >= a && now < b : now >= a || now < b;
  }

  String get rotulo => 'das ${hourLabel(inicio)} às ${hourLabel(fim)}';
}

@immutable
class HorarioFuncionamento {
  const HorarioFuncionamento({required this.diaSemana, required this.janela});

  /// 1 = segunda … 7 = domingo (igual a [DateTime.weekday]).
  final int diaSemana;
  final JanelaHorario janela;

  factory HorarioFuncionamento.fromJson(Map<String, dynamic> j) => HorarioFuncionamento(
    diaSemana: j['dia_semana'] as int,
    janela: JanelaHorario(inicio: j['abre'] as String, fim: j['fecha'] as String),
  );
}

enum TipoConsumo {
  local('local', 'Comer aqui'),
  viagem('viagem', 'Para levar');

  const TipoConsumo(this.api, this.rotulo);
  final String api;
  final String rotulo;

  static TipoConsumo fromApi(String v) => values.firstWhere((e) => e.api == v, orElse: () => local);
}

@immutable
class FormaPagamento {
  const FormaPagamento({required this.id, required this.nome, required this.descricao, required this.tipo});

  final int id;
  final String nome;
  final String descricao;

  /// caixa | mesa | pix | cartao — define o ícone exibido.
  final String tipo;

  factory FormaPagamento.fromJson(Map<String, dynamic> j) => FormaPagamento(
    id: j['id'] as int,
    nome: j['nome'] as String,
    descricao: (j['descricao'] as String?) ?? '',
    tipo: (j['tipo'] as String?) ?? 'caixa',
  );
}

Color? _cor(Object? hex) {
  if (hex is! String || hex.isEmpty) return null;
  final v = hex.replaceAll('#', '');
  if (v.length != 6) return null;
  return Color(int.parse('FF$v', radix: 16));
}

/// Aparência escolhida em ERP › Simuladores › Cardápio › Aparência.
@immutable
class AparenciaCardapio {
  const AparenciaCardapio({
    this.tema = 'forven',
    this.fonte = 'public_sans',
    this.cantos = 'suave',
    this.layoutCards = 'grade',
    this.corPrimaria,
    this.corDestaque,
  });

  /// forven | claro | cafe | bistro | verde | vinho | grafite
  final String tema;

  /// public_sans | classica | moderna | elegante
  final String fonte;

  /// reto | suave | arredondado
  final String cantos;

  /// grade | lista
  final String layoutCards;

  /// Sobrescrevem as cores do tema quando definidas no ERP.
  final Color? corPrimaria;
  final Color? corDestaque;

  bool get lista => layoutCards == 'lista';

  factory AparenciaCardapio.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const AparenciaCardapio();
    return AparenciaCardapio(
      tema: (j['tema'] as String?) ?? 'forven',
      fonte: (j['fonte'] as String?) ?? 'public_sans',
      cantos: (j['cantos'] as String?) ?? 'suave',
      layoutCards: (j['layout_cards'] as String?) ?? 'grade',
      corPrimaria: _cor(j['cor_primaria']),
      corDestaque: _cor(j['cor_destaque']),
    );
  }

  /// Mesmo visual com outro tema (escolha local feita nas configurações do aparelho).
  AparenciaCardapio comTema(String outro) => AparenciaCardapio(
    tema: outro,
    fonte: fonte,
    cantos: cantos,
    layoutCards: layoutCards,
    corPrimaria: outro == tema ? corPrimaria : null,
    corDestaque: outro == tema ? corDestaque : null,
  );

  @override
  bool operator ==(Object other) =>
      other is AparenciaCardapio &&
      other.tema == tema &&
      other.fonte == fonte &&
      other.cantos == cantos &&
      other.layoutCards == layoutCards &&
      other.corPrimaria == corPrimaria &&
      other.corDestaque == corDestaque;

  @override
  int get hashCode => Object.hash(tema, fonte, cantos, layoutCards, corPrimaria, corDestaque);
}

/// PIN da área do estabelecimento definido no ERP. O app recebe só o hash
/// (sha256 de sal + PIN) e confere offline.
@immutable
class SegurancaPin {
  const SegurancaPin({required this.hash, required this.sal});

  final String hash;
  final String sal;

  static SegurancaPin? fromJson(Object? j) {
    if (j is! Map<String, dynamic>) return null;
    final hash = j['pin_hash'] as String?;
    final sal = j['pin_salt'] as String?;
    if (hash == null || sal == null || hash.isEmpty) return null;
    return SegurancaPin(hash: hash, sal: sal);
  }
}

/// Configuração do estabelecimento vinda do simulador "cardapio" no ERP
/// (/e-commerce/simuladores/cardapio/configuracoes → aba Geral).
@immutable
class LojaConfig {
  const LojaConfig({
    required this.nome,
    required this.slogan,
    required this.logoUrl,
    required this.capaUrl,
    required this.imagensDestaque,
    required this.corPrimaria,
    required this.horarios,
    required this.modosConsumo,
    required this.exigirNomeCliente,
    required this.taxaServicoPercentual,
    required this.pedidoMinimo,
    required this.formasPagamento,
    required this.mensagemBoasVindas,
    required this.tempoInatividadeSegundos,
    required this.tempoMedioPreparoMin,
    required this.permitirObservacaoItem,
    required this.mostrarCalorias,
    this.mostrarTempoPreparo = true,
    this.taxaServicoViagem = false,
    this.aparencia = const AparenciaCardapio(),
    this.seguranca,
    this.intervaloSincronizacaoMin = 5,
    this.chamarGarcom = const ChamarGarcomConfig(),
  });

  final String nome;
  final String slogan;
  final String? logoUrl;
  final String? capaUrl;
  final List<String> imagensDestaque;
  final Color? corPrimaria;
  final List<HorarioFuncionamento> horarios;
  final List<TipoConsumo> modosConsumo;
  final bool exigirNomeCliente;
  final double taxaServicoPercentual;
  final double pedidoMinimo;
  final List<FormaPagamento> formasPagamento;
  final String mensagemBoasVindas;
  final int tempoInatividadeSegundos;
  final int tempoMedioPreparoMin;
  final bool permitirObservacaoItem;
  final bool mostrarCalorias;
  final bool mostrarTempoPreparo;

  /// Cobra a taxa de serviço também nos pedidos para levar.
  final bool taxaServicoViagem;
  final AparenciaCardapio aparencia;

  /// Null = o ERP não definiu PIN (vale o PIN local do aparelho).
  final SegurancaPin? seguranca;

  /// De quanto em quanto tempo o app busca mudanças no ERP.
  final int intervaloSincronizacaoMin;

  /// Botão "Chamar garçom" no topo do tablet da mesa.
  final ChamarGarcomConfig chamarGarcom;

  factory LojaConfig.fromJson(Map<String, dynamic> j) {
    final aparencia = AparenciaCardapio.fromJson(j['aparencia'] as Map<String, dynamic>?);
    return LojaConfig(
      nome: j['nome'] as String,
      slogan: (j['slogan'] as String?) ?? '',
      logoUrl: j['logo_url'] as String?,
      capaUrl: j['capa_url'] as String?,
      imagensDestaque: ((j['imagens_destaque'] as List?) ?? const []).cast<String>(),
      corPrimaria: aparencia.corPrimaria ?? _cor(j['cor_primaria']),
      horarios: ((j['horarios'] as List?) ?? const [])
          .map((e) => HorarioFuncionamento.fromJson(e as Map<String, dynamic>))
          .toList(),
      modosConsumo: ((j['modos_consumo'] as List?) ?? const ['local', 'viagem'])
          .map((e) => TipoConsumo.fromApi(e as String))
          .toList(),
      exigirNomeCliente: (j['exigir_nome_cliente'] as bool?) ?? true,
      taxaServicoPercentual: ((j['taxa_servico_percentual'] as num?) ?? 0).toDouble(),
      pedidoMinimo: ((j['pedido_minimo'] as num?) ?? 0).toDouble(),
      formasPagamento: ((j['formas_pagamento'] as List?) ?? const [])
          .map((e) => FormaPagamento.fromJson(e as Map<String, dynamic>))
          .toList(),
      mensagemBoasVindas: (j['mensagem_boas_vindas'] as String?) ?? '',
      tempoInatividadeSegundos: (j['tempo_inatividade_segundos'] as int?) ?? 90,
      tempoMedioPreparoMin: (j['tempo_medio_preparo_min'] as int?) ?? 20,
      permitirObservacaoItem: (j['permitir_observacao_item'] as bool?) ?? true,
      mostrarCalorias: (j['mostrar_calorias'] as bool?) ?? true,
      mostrarTempoPreparo: (j['mostrar_tempo_preparo'] as bool?) ?? true,
      taxaServicoViagem: (j['taxa_servico_viagem'] as bool?) ?? false,
      aparencia: aparencia,
      seguranca: SegurancaPin.fromJson(j['seguranca']),
      intervaloSincronizacaoMin:
          ((j['sincronizacao'] as Map<String, dynamic>?)?['intervalo_min'] as num?)?.toInt().clamp(1, 240) ?? 5,
      chamarGarcom: ChamarGarcomConfig.fromJson(j['chamar_garcom']),
    );
  }

  JanelaHorario? janelaDoDia(DateTime d) {
    for (final h in horarios) {
      if (h.diaSemana == d.weekday) return h.janela;
    }
    return null;
  }

  bool abertoEm(DateTime d) {
    if (horarios.isEmpty) return true;
    final hoje = janelaDoDia(d);
    if (hoje != null && hoje.contem(d)) return true;
    // Janela de ontem que cruzou a meia-noite.
    final ontem = janelaDoDia(d.subtract(const Duration(days: 1)));
    if (ontem != null && JanelaHorario._min(ontem.inicio) > JanelaHorario._min(ontem.fim)) {
      return d.hour * 60 + d.minute < JanelaHorario._min(ontem.fim);
    }
    return false;
  }

  /// "Aberto · fecha às 23h" / "Fechado · abre às 7h".
  String statusRotulo(DateTime d) {
    final hoje = janelaDoDia(d);
    if (abertoEm(d)) {
      return hoje == null ? 'Aberto agora' : 'Aberto · fecha às ${hourLabel(hoje.fim)}';
    }
    if (hoje != null && d.hour * 60 + d.minute < JanelaHorario._min(hoje.inicio)) {
      return 'Fechado · abre às ${hourLabel(hoje.inicio)}';
    }
    final amanha = janelaDoDia(d.add(const Duration(days: 1)));
    return amanha == null ? 'Fechado agora' : 'Fechado · abre amanhã às ${hourLabel(amanha.inicio)}';
  }
}
