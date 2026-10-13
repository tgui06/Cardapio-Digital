import 'package:flutter/foundation.dart';

import 'cardapio.dart';
import 'pedido.dart';

/// Seleções de um item: grupoId → (opcaoId → quantidade).
typedef Selecoes = Map<int, Map<int, int>>;

@immutable
class CartItem {
  const CartItem({
    required this.uid,
    required this.produto,
    required this.quantidade,
    required this.selecoes,
    required this.observacao,
  });

  final String uid;
  final Produto produto;
  final int quantidade;
  final Selecoes selecoes;
  final String observacao;

  double get precoUnitario {
    var p = produto.preco;
    for (final g in produto.grupos) {
      final sel = selecoes[g.id];
      if (sel == null) continue;
      for (final o in g.opcoes) {
        p += o.precoAdicional * (sel[o.id] ?? 0);
      }
    }
    return p;
  }

  double get total => precoUnitario * quantidade;

  /// Lista legível das escolhas: "Grande · Leite de aveia · 2× Bacon".
  List<String> get resumoOpcoes {
    final out = <String>[];
    for (final g in produto.grupos) {
      final sel = selecoes[g.id];
      if (sel == null) continue;
      for (final o in g.opcoes) {
        final q = sel[o.id] ?? 0;
        if (q > 0) out.add(q > 1 ? '$q× ${o.nome}' : o.nome);
      }
    }
    return out;
  }

  CartItem copyWith({int? quantidade, Selecoes? selecoes, String? observacao}) => CartItem(
    uid: uid,
    produto: produto,
    quantidade: quantidade ?? this.quantidade,
    selecoes: selecoes ?? this.selecoes,
    observacao: observacao ?? this.observacao,
  );

  PedidoItem toPedidoItem() {
    final comps = <PedidoComplemento>[];
    for (final g in produto.grupos) {
      final sel = selecoes[g.id];
      if (sel == null) continue;
      for (final o in g.opcoes) {
        final q = sel[o.id] ?? 0;
        if (q > 0) {
          comps.add(
            PedidoComplemento(
              grupoId: g.id,
              opcaoId: o.id,
              nome: o.nome,
              quantidade: q,
              precoUnitario: o.precoAdicional,
            ),
          );
        }
      }
    }
    return PedidoItem(
      produtoId: produto.id,
      nome: produto.nome,
      imagemUrl: produto.imagemUrl,
      quantidade: quantidade,
      precoUnitario: precoUnitario,
      complementos: comps,
      observacao: observacao,
    );
  }
}
