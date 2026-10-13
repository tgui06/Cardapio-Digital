import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/models/cart_item.dart';
import '../data/models/loja.dart';
import 'chamados.dart';
import 'offline.dart';
import 'settings.dart';

export 'chamados.dart';
export 'offline.dart';

const uuid = Uuid();

/// Aparência em uso: a do ERP, ou o tema escolhido neste aparelho nas configurações.
final aparenciaProvider = Provider<AparenciaCardapio>((ref) {
  final doErp = ref.watch(cardapioProvider.select((c) => c.value?.loja.aparencia)) ?? const AparenciaCardapio();
  final local = ref.watch(settingsProvider.select((s) => s.temaLocal));
  return local.isEmpty ? doErp : doErp.comTema(local);
});

/// Relógio que atualiza a cada 30s (disponibilidade por horário, status da loja).
final clockProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(seconds: 30), (_) => DateTime.now());
});

/// Hora atual (reativa): `ref.watch(nowProvider)`.
final nowProvider = Provider<DateTime>((ref) => ref.watch(clockProvider).value ?? DateTime.now());

// ------------------------------------------------------------ sacola

class CartController extends Notifier<List<CartItem>> {
  @override
  List<CartItem> build() => const [];

  void add(CartItem item) {
    // Mesmo produto com as mesmas escolhas → soma quantidade.
    final i = state.indexWhere((c) => _mesmaConfiguracao(c, item));
    if (i >= 0) {
      final atual = state[i];
      state = [...state]..[i] = atual.copyWith(quantidade: atual.quantidade + item.quantidade);
    } else {
      state = [...state, item];
    }
  }

  bool _mesmaConfiguracao(CartItem a, CartItem b) {
    if (a.produto.id != b.produto.id || a.observacao.trim() != b.observacao.trim()) return false;
    String key(Selecoes s) {
      final parts = <String>[];
      final gs = s.keys.toList()..sort();
      for (final g in gs) {
        final os = s[g]!.entries.where((e) => e.value > 0).toList()..sort((x, y) => x.key.compareTo(y.key));
        for (final o in os) {
          parts.add('$g:${o.key}x${o.value}');
        }
      }
      return parts.join('|');
    }

    return key(a.selecoes) == key(b.selecoes);
  }

  void replace(CartItem item) {
    state = [for (final c in state) c.uid == item.uid ? item : c];
  }

  /// Remove e devolve (índice, item) para permitir "desfazer".
  (int, CartItem)? remove(String uid) {
    final i = state.indexWhere((c) => c.uid == uid);
    if (i < 0) return null;
    final removed = state[i];
    state = [...state]..removeAt(i);
    return (i, removed);
  }

  void restore(int index, CartItem item) {
    final list = [...state];
    list.insert(index.clamp(0, list.length), item);
    state = list;
  }

  void setQuantidade(String uid, int q) {
    if (q <= 0) {
      remove(uid);
      return;
    }
    state = [for (final c in state) c.uid == uid ? c.copyWith(quantidade: q) : c];
  }

  void clear() => state = const [];
}

final cartProvider = NotifierProvider<CartController, List<CartItem>>(CartController.new);

final cartCountProvider = Provider<int>((ref) => ref.watch(cartProvider).fold(0, (s, c) => s + c.quantidade));

final cartSubtotalProvider = Provider<double>((ref) => ref.watch(cartProvider).fold(0.0, (s, c) => s + c.total));

// ------------------------------------------------------------ sessão do pedido

class PedidoSessao {
  const PedidoSessao({this.consumo, this.mesa, this.nome = '', this.observacao = '', this.formaPagamentoId});

  final TipoConsumo? consumo;
  final int? mesa;
  final String nome;
  final String observacao;
  final int? formaPagamentoId;

  PedidoSessao copyWith({
    TipoConsumo? Function()? consumo,
    int? Function()? mesa,
    String? nome,
    String? observacao,
    int? Function()? formaPagamentoId,
  }) => PedidoSessao(
    consumo: consumo != null ? consumo() : this.consumo,
    mesa: mesa != null ? mesa() : this.mesa,
    nome: nome ?? this.nome,
    observacao: observacao ?? this.observacao,
    formaPagamentoId: formaPagamentoId != null ? formaPagamentoId() : this.formaPagamentoId,
  );
}

class SessaoController extends Notifier<PedidoSessao> {
  @override
  PedidoSessao build() {
    final mesaFixa = ref.watch(settingsProvider.select((s) => s.mesaFixa));
    return PedidoSessao(mesa: mesaFixa, consumo: mesaFixa != null ? TipoConsumo.local : null);
  }

  void setConsumo(TipoConsumo c) => state = state.copyWith(consumo: () => c);
  void setMesa(int? m) => state = state.copyWith(mesa: () => m);
  void setNome(String n) => state = state.copyWith(nome: n);
  void setObservacao(String o) => state = state.copyWith(observacao: o);
  void setFormaPagamento(int? id) => state = state.copyWith(formaPagamentoId: () => id);

  /// Novo cliente no totem (ou nova comanda no garçom).
  void reset() {
    final mesaFixa = ref.read(settingsProvider).mesaFixa;
    state = PedidoSessao(mesa: mesaFixa, consumo: mesaFixa != null ? TipoConsumo.local : null);
  }
}

final sessaoProvider = NotifierProvider<SessaoController, PedidoSessao>(SessaoController.new);

/// Taxa de serviço: no local sempre; para levar só se o ERP mandar cobrar.
final cartTaxaProvider = Provider<double>((ref) {
  final cardapio = ref.watch(cardapioProvider).value;
  final consumo = ref.watch(sessaoProvider.select((s) => s.consumo));
  if (cardapio == null || (consumo == TipoConsumo.viagem && !cardapio.loja.taxaServicoViagem)) return 0;
  final sub = ref.watch(cartSubtotalProvider);
  return (sub * cardapio.loja.taxaServicoPercentual / 100 * 100).roundToDouble() / 100;
});

final cartTotalProvider = Provider<double>((ref) => ref.watch(cartSubtotalProvider) + ref.watch(cartTaxaProvider));

/// Zera tudo para o próximo cliente.
void novoAtendimento(WidgetRef ref) {
  ref.read(cartProvider.notifier).clear();
  ref.read(sessaoProvider.notifier).reset();
  // Tablet preso à mesa: o chamado é da mesa (não do cliente) e segue até ser atendido.
  if (ref.read(settingsProvider).mesaFixa == null) ref.read(chamadoMesaProvider.notifier).limpar();
}
