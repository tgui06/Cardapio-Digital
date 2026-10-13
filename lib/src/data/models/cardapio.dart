import 'package:flutter/foundation.dart';

import 'chamado.dart';
import 'loja.dart';

/// Selos exibidos nos produtos (configuráveis por item no simulador).
enum ProdutoTag {
  maisPedido('mais_pedido', 'Mais pedido'),
  novo('novo', 'Novidade'),
  chef('chef', 'Escolha do chef'),
  vegano('vegano', 'Vegano'),
  vegetariano('vegetariano', 'Vegetariano'),
  semGluten('sem_gluten', 'Sem glúten'),
  semLactose('sem_lactose', 'Sem lactose'),
  picante('picante', 'Picante'),
  promocao('promocao', 'Promoção');

  const ProdutoTag(this.api, this.rotulo);
  final String api;
  final String rotulo;

  static ProdutoTag? fromApi(String v) {
    for (final t in values) {
      if (t.api == v) return t;
    }
    return null;
  }
}

/// unico = escolha 1 (rádio) · multiplo = várias (checkbox) · quantidade = stepper por opção.
enum TipoGrupo {
  unico('unico'),
  multiplo('multiplo'),
  quantidade('quantidade');

  const TipoGrupo(this.api);
  final String api;

  static TipoGrupo fromApi(String v) => values.firstWhere((e) => e.api == v, orElse: () => multiplo);
}

@immutable
class OpcaoComplemento {
  const OpcaoComplemento({
    required this.id,
    required this.nome,
    this.descricao = '',
    this.precoAdicional = 0,
    this.erpProdutoId,
    this.disponivel = true,
    this.maximo = 1,
  });

  final int id;
  final String nome;
  final String descricao;
  final double precoAdicional;

  /// Vínculo opcional com produto do estoque (CodPro) para baixa no ERP.
  final int? erpProdutoId;
  final bool disponivel;

  /// Máximo por opção quando o grupo é do tipo [TipoGrupo.quantidade].
  final int maximo;

  factory OpcaoComplemento.fromJson(Map<String, dynamic> j) => OpcaoComplemento(
    id: j['id'] as int,
    nome: j['nome'] as String,
    descricao: (j['descricao'] as String?) ?? '',
    precoAdicional: ((j['preco_adicional'] as num?) ?? 0).toDouble(),
    erpProdutoId: j['estoque_produtos_id'] as int?,
    disponivel: (j['disponivel'] as bool?) ?? true,
    maximo: (j['maximo'] as int?) ?? 1,
  );
}

@immutable
class GrupoComplemento {
  const GrupoComplemento({
    required this.id,
    required this.nome,
    this.descricao = '',
    required this.tipo,
    this.minimo = 0,
    this.maximo = 1,
    required this.opcoes,
  });

  final int id;
  final String nome;
  final String descricao;
  final TipoGrupo tipo;
  final int minimo;
  final int maximo;
  final List<OpcaoComplemento> opcoes;

  bool get obrigatorio => minimo > 0;

  String get regraRotulo {
    if (tipo == TipoGrupo.unico) return obrigatorio ? 'Escolha 1' : 'Opcional · até 1';
    if (minimo > 0 && minimo == maximo) return 'Escolha $minimo';
    if (minimo > 0) return 'Escolha de $minimo a $maximo';
    return 'Opcional · até $maximo';
  }

  factory GrupoComplemento.fromJson(Map<String, dynamic> j) => GrupoComplemento(
    id: j['id'] as int,
    nome: j['nome'] as String,
    descricao: (j['descricao'] as String?) ?? '',
    tipo: TipoGrupo.fromApi(j['tipo'] as String),
    minimo: (j['minimo'] as int?) ?? 0,
    maximo: (j['maximo'] as int?) ?? 1,
    opcoes: ((j['opcoes'] as List?) ?? const [])
        .map((e) => OpcaoComplemento.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

@immutable
class Categoria {
  const Categoria({
    required this.id,
    required this.nome,
    this.descricao = '',
    required this.icone,
    this.imagemUrl,
    this.janela,
  });

  final int id;
  final String nome;
  final String descricao;

  /// Chave de ícone (ver `categoryIcon`).
  final String icone;
  final String? imagemUrl;

  /// Disponibilidade por horário (ex.: café da manhã das 6h às 12h).
  final JanelaHorario? janela;

  bool disponivelEm(DateTime t) => janela?.contem(t) ?? true;

  factory Categoria.fromJson(Map<String, dynamic> j) => Categoria(
    id: j['id'] as int,
    nome: j['nome'] as String,
    descricao: (j['descricao'] as String?) ?? '',
    icone: (j['icone'] as String?) ?? 'garfo',
    imagemUrl: j['imagem_url'] as String?,
    janela: j['disponibilidade'] == null ? null : JanelaHorario.fromJson(j['disponibilidade'] as Map<String, dynamic>),
  );
}

@immutable
class Produto {
  const Produto({
    required this.id,
    required this.categoriaId,
    required this.erpProdutoId,
    required this.nome,
    required this.descricao,
    required this.preco,
    this.precoOriginal,
    this.imagemUrl,
    this.tags = const [],
    this.alergenicos = const [],
    this.destaque = false,
    this.disponivel = true,
    this.janela,
    this.tempoPreparoMin,
    this.serve,
    this.calorias,
    this.grupos = const [],
    this.sugestoes = const [],
  });

  final int id;
  final int categoriaId;

  /// Produto principal do ERP (estoque_produtos.CodPro) vinculado no simulador.
  final int erpProdutoId;
  final String nome;
  final String descricao;
  final double preco;

  /// Preço "de" quando em promoção.
  final double? precoOriginal;

  /// Null = produto sem foto (o app mostra um ícone no lugar).
  final String? imagemUrl;
  final List<ProdutoTag> tags;
  final List<String> alergenicos;
  final bool destaque;
  final bool disponivel;
  final JanelaHorario? janela;
  final int? tempoPreparoMin;
  final int? serve;
  final int? calorias;
  final List<GrupoComplemento> grupos;

  /// Produtos sugeridos para acompanhar ("Combina com").
  final List<int> sugestoes;

  bool get emPromocao => precoOriginal != null && precoOriginal! > preco;
  bool get temOpcoes => grupos.isNotEmpty;

  /// Menor preço possível considerando grupos obrigatórios (ex.: tamanho P).
  double get precoAPartirDe {
    var p = preco;
    for (final g in grupos.where((g) => g.obrigatorio)) {
      final precos = g.opcoes.where((o) => o.disponivel).map((o) => o.precoAdicional).toList()..sort();
      for (var i = 0; i < g.minimo && i < precos.length; i++) {
        p += precos[i];
      }
    }
    return p;
  }

  bool get precoVariavel => grupos.any((g) => g.obrigatorio && g.opcoes.any((o) => o.precoAdicional > 0));

  factory Produto.fromJson(Map<String, dynamic> j) => Produto(
    id: j['id'] as int,
    categoriaId: j['categoria_id'] as int,
    erpProdutoId: j['estoque_produtos_id'] as int,
    nome: j['nome'] as String,
    descricao: (j['descricao'] as String?) ?? '',
    preco: (j['preco'] as num).toDouble(),
    precoOriginal: (j['preco_original'] as num?)?.toDouble(),
    imagemUrl: j['imagem_url'] as String?,
    tags: ((j['tags'] as List?) ?? const [])
        .map((e) => ProdutoTag.fromApi(e as String))
        .whereType<ProdutoTag>()
        .toList(),
    alergenicos: ((j['alergenicos'] as List?) ?? const []).cast<String>(),
    destaque: (j['destaque'] as bool?) ?? false,
    disponivel: (j['disponivel'] as bool?) ?? true,
    janela: j['disponibilidade'] == null ? null : JanelaHorario.fromJson(j['disponibilidade'] as Map<String, dynamic>),
    tempoPreparoMin: j['tempo_preparo_min'] as int?,
    serve: j['serve'] as int?,
    calorias: j['calorias'] as int?,
    grupos: ((j['grupos_complementos'] as List?) ?? const [])
        .map((e) => GrupoComplemento.fromJson(e as Map<String, dynamic>))
        .toList(),
    sugestoes: ((j['sugestoes'] as List?) ?? const []).cast<int>(),
  );
}

/// Mesa cadastrada no ERP (vem junto do cardápio, disponível offline).
@immutable
class MesaCadastro {
  const MesaCadastro({
    required this.numero,
    this.nome,
    this.lugares = 4,
    this.area = 'Salão',
    this.garcomId,
    this.garcomNome,
  });

  final int numero;
  final String? nome;
  final int lugares;
  final String area;

  /// Garçom responsável: recebe os chamados do botão "Chamar garçom" desta mesa.
  final int? garcomId;
  final String? garcomNome;

  factory MesaCadastro.fromJson(Map<String, dynamic> j) => MesaCadastro(
    numero: j['numero'] as int,
    nome: j['nome'] as String?,
    lugares: (j['lugares'] as int?) ?? 4,
    area: (j['area'] as String?) ?? 'Salão',
    garcomId: j['garcom_id'] as int?,
    garcomNome: j['garcom_nome'] as String?,
  );
}

/// Pacote completo retornado por `GET externo/simuladores/cardapio/cardapio`.
/// O app guarda esse pacote e funciona com ele mesmo sem internet.
@immutable
class Cardapio {
  const Cardapio({
    required this.loja,
    required this.categorias,
    required this.produtos,
    this.mesas = const [],
    this.garcons = const [],
    this.versao = '',
    this.geradoEm,
  });

  final LojaConfig loja;
  final List<Categoria> categorias;
  final List<Produto> produtos;
  final List<MesaCadastro> mesas;
  final List<GarcomInfo> garcons;

  /// Hash do conteúdo: o app manda de volta (`?versao=`) e o ERP só responde
  /// o pacote inteiro quando algo mudou.
  final String versao;
  final DateTime? geradoEm;

  factory Cardapio.fromJson(Map<String, dynamic> j) => Cardapio(
    loja: LojaConfig.fromJson(j['loja'] as Map<String, dynamic>),
    categorias: ((j['categorias'] as List?) ?? const [])
        .map((e) => Categoria.fromJson(e as Map<String, dynamic>))
        .toList(),
    produtos: ((j['produtos'] as List?) ?? const []).map((e) => Produto.fromJson(e as Map<String, dynamic>)).toList(),
    mesas: ((j['mesas'] as List?) ?? const []).map((e) => MesaCadastro.fromJson(e as Map<String, dynamic>)).toList(),
    garcons: ((j['garcons'] as List?) ?? const []).map((e) => GarcomInfo.fromJson(e as Map<String, dynamic>)).toList(),
    versao: (j['versao'] as String?) ?? '',
    geradoEm: DateTime.tryParse((j['gerado_em'] as String?) ?? ''),
  );

  /// Todas as fotos usadas no app — baixadas de antemão para funcionar offline.
  Set<String> get urlsImagens => {
    ?loja.logoUrl,
    ?loja.capaUrl,
    ...loja.imagensDestaque,
    for (final c in categorias) ?c.imagemUrl,
    for (final p in produtos) ?p.imagemUrl,
  };

  MesaCadastro? mesa(int numero) {
    for (final m in mesas) {
      if (m.numero == numero) return m;
    }
    return null;
  }

  /// Números das mesas (cadastro do ERP); sem cadastro, 1 a 16.
  List<int> get numerosMesas => mesas.isEmpty ? [for (var i = 1; i <= 16; i++) i] : [for (final m in mesas) m.numero];

  List<Produto> produtosDa(int categoriaId) => produtos.where((p) => p.categoriaId == categoriaId).toList();

  List<Produto> get destaques => produtos.where((p) => p.destaque).toList();

  Categoria categoria(int id) => categorias.firstWhere((c) => c.id == id);

  Produto? produto(int id) {
    for (final p in produtos) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Produto pode ser pedido agora? (flag do ERP + janela do item + janela da categoria)
  bool disponivelAgora(Produto p, DateTime t) =>
      p.disponivel && (p.janela?.contem(t) ?? true) && categoria(p.categoriaId).disponivelEm(t);

  /// Rótulo explicando por que está indisponível.
  String? motivoIndisponivel(Produto p, DateTime t) {
    if (!p.disponivel) return 'Esgotado no momento';
    final j = p.janela ?? categoria(p.categoriaId).janela;
    if (j != null && !j.contem(t)) return 'Disponível ${j.rotulo}';
    return null;
  }
}
