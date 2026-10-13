import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/navigation.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/app_image.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/pressable.dart';
import '../../data/models/cardapio.dart';
import '../../data/models/cart_item.dart';
import '../../data/models/loja.dart';
import '../../state/providers.dart';
import '../checkout/checkout_screen.dart';
import '../menu/widgets/product_cards.dart';

void irParaCheckout(BuildContext context) => pushPage<void>(context, (_) => const CheckoutScreen());

/// Página da sacola (celular / tablet retrato).
class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(4),
          child: RoundIconButton(
            icon: LucideIcons.arrowLeft,
            label: 'Voltar ao cardápio',
            filled: false,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        leadingWidth: 64,
        title: const Text('Sua sacola'),
      ),
      body: const SafeArea(top: false, child: CartContent(showHeader: false)),
    );
  }
}

/// Painel fixo à direita no tablet/totem.
class CartPanel extends StatelessWidget {
  const CartPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(left: BorderSide(color: p.outline)),
      ),
      child: const SafeArea(left: false, child: CartContent(showHeader: true)),
    );
  }
}

class CartContent extends ConsumerWidget {
  const CartContent({super.key, required this.showHeader});

  final bool showHeader;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final itens = ref.watch(cartProvider);
    final count = ref.watch(cartCountProvider);
    final cardapio = ref.watch(cardapioProvider).value;
    final sessao = ref.watch(sessaoProvider);

    final header = showHeader
        ? Padding(
            padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.md, Space.sm),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Eyebrow('Seu pedido'),
                      const SizedBox(height: 2),
                      Text('Sacola', style: context.text.headlineMedium),
                    ],
                  ),
                ),
                if (itens.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => _confirmarLimpar(context, ref),
                    icon: Icon(LucideIcons.trash2, size: 18, color: p.textMuted),
                    label: Text('Limpar', style: context.text.labelMedium?.copyWith(color: p.textMuted)),
                  ),
              ],
            ),
          )
        : const SizedBox.shrink();

    if (itens.isEmpty) {
      return Column(
        children: [
          header,
          const Expanded(
            child: EmptyState(
              icon: LucideIcons.shoppingBasket,
              title: 'Sua sacola está vazia',
              message: 'Escolha algo delicioso no cardápio. Toque no + para adicionar.',
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        header,
        if (sessao.mesa != null || sessao.consumo != null)
          Padding(
            padding: EdgeInsets.fromLTRB(showHeader ? Space.lg : Space.md, 0, Space.md, Space.xs),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: Space.xs,
                children: [
                  if (sessao.consumo != null)
                    StatusPill(
                      label: sessao.consumo!.rotulo,
                      color: p.accent,
                      icon: sessao.consumo == TipoConsumo.local ? LucideIcons.utensils : LucideIcons.handbag,
                    ),
                  if (sessao.mesa != null)
                    StatusPill(label: 'Mesa ${sessao.mesa}', color: p.accent, icon: LucideIcons.armchair),
                ],
              ),
            ),
          ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(showHeader ? Space.md : Space.sm, Space.xs, Space.md, Space.md),
            children: [
              for (final (i, item) in itens.indexed)
                _CartLine(key: ValueKey(item.uid), item: item).entrance(context, index: i),
              if (cardapio != null) _Upsell(cardapio: cardapio, itens: itens),
            ],
          ),
        ),
        _Summary(count: count),
      ],
    );
  }

  Future<void> _confirmarLimpar(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limpar a sacola?'),
        content: const Text('Todos os itens serão removidos.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Manter')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Limpar')),
        ],
      ),
    );
    if (ok == true) ref.read(cartProvider.notifier).clear();
  }
}

class _CartLine extends ConsumerWidget {
  const _CartLine({super.key, required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final tag = 'sacola-${item.uid}';
    final opcoes = item.resumoOpcoes;

    void remover() {
      final removed = ref.read(cartProvider.notifier).remove(item.uid);
      if (removed == null) return;
      ScaffoldMessenger.maybeOf(context)
        ?..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text('${item.produto.nome} removido'),
            action: SnackBarAction(
              label: 'Desfazer',
              onPressed: () => ref.read(cartProvider.notifier).restore(removed.$1, removed.$2),
            ),
          ),
        );
    }

    final line = Pressable(
      onTap: () => openProduct(context, item.produto, heroTag: tag, editing: item),
      borderRadius: Radii.rMd,
      scale: 0.985,
      semanticLabel: '${item.quantidade} ${item.produto.nome}, ${money(item.total)}. Toque para editar',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.xs, vertical: Space.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 68,
              height: 68,
              child: MaybeHero(
                tag: tag,
                child: AppImage(item.produto.imagemUrl, width: 200, borderRadius: Radii.rMd),
              ),
            ),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.produto.nome, style: context.text.titleSmall),
                  if (opcoes.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(opcoes.join(' · '), style: context.text.bodySmall),
                  ],
                  if (item.observacao.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      '“${item.observacao}”',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                    ),
                  ],
                  const SizedBox(height: Space.xs),
                  Row(
                    children: [
                      Expanded(
                        child: AnimatedMoney(item.total, style: context.text.titleSmall?.copyWith(color: p.accent)),
                      ),
                      QuantityStepper(
                        value: item.quantidade,
                        size: 36,
                        compact: true,
                        onChanged: (q) =>
                            q <= 0 ? remover() : ref.read(cartProvider.notifier).setQuantidade(item.uid, q),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return Dismissible(
      key: ValueKey('dismiss-${item.uid}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => remover(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: Space.lg),
        decoration: BoxDecoration(color: p.dangerSoft, borderRadius: Radii.rMd),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Remover', style: context.text.labelMedium?.copyWith(color: p.danger)),
            const SizedBox(width: Space.xs),
            Icon(LucideIcons.trash2, color: p.danger),
          ],
        ),
      ),
      child: line,
    );
  }
}

/// "Que tal adicionar?" — sugere sobremesas/bebidas ainda não escolhidas.
class _Upsell extends ConsumerWidget {
  const _Upsell({required this.cardapio, required this.itens});

  final Cardapio cardapio;
  final List<CartItem> itens;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(nowProvider);
    final noCarrinho = itens.map((i) => i.produto.id).toSet();
    final categoriasNoCarrinho = itens.map((i) => i.produto.categoriaId).toSet();
    final sugeridos = <Produto>[
      for (final i in itens)
        for (final id in i.produto.sugestoes) ?cardapio.produto(id),
    ];
    // Completa com destaques de categorias que ainda não estão na sacola.
    sugeridos.addAll(cardapio.destaques.where((p) => !categoriasNoCarrinho.contains(p.categoriaId)));
    final lista = <int, Produto>{
      for (final p in sugeridos)
        if (!noCarrinho.contains(p.id) && cardapio.disponivelAgora(p, now)) p.id: p,
    }.values.take(6).toList();
    if (lista.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: Space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.xs),
            child: Text('Que tal adicionar?', style: context.text.titleMedium),
          ),
          const SizedBox(height: Space.sm),
          SizedBox(
            height: 172,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Space.xs),
              itemCount: lista.length,
              separatorBuilder: (_, _) => const SizedBox(width: Space.sm),
              itemBuilder: (_, i) => SuggestionCard(produto: lista[i], origem: 'upsell', width: 150),
            ),
          ),
        ],
      ),
    );
  }
}

class _Summary extends ConsumerWidget {
  const _Summary({required this.count});

  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final sub = ref.watch(cartSubtotalProvider);
    final taxa = ref.watch(cartTaxaProvider);
    final total = ref.watch(cartTotalProvider);
    final loja = ref.watch(cardapioProvider).value?.loja;
    final minimo = loja?.pedidoMinimo ?? 0;
    final abaixoMinimo = sub < minimo;

    Widget row(String l, Widget v, {bool strong = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(l, style: strong ? context.text.titleMedium : context.text.bodyMedium)),
          DefaultTextStyle.merge(style: strong ? context.text.titleLarge : context.text.titleSmall, child: v),
        ],
      ),
    );

    return Container(
      padding: EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, Space.md + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(
        color: p.surfaceRaised,
        border: Border(top: BorderSide(color: p.outline)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          row('Subtotal · ${itensLabel(count)}', AnimatedMoney(sub)),
          if (taxa > 0)
            row('Serviço (${loja!.taxaServicoPercentual.toStringAsFixed(0)}%) · opcional', AnimatedMoney(taxa)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.xs),
            child: Divider(height: 1, color: p.outline),
          ),
          row('Total', AnimatedMoney(total), strong: true),
          if (abaixoMinimo) ...[
            const SizedBox(height: Space.xs),
            Text('Pedido mínimo de ${money(minimo)}', style: context.text.bodySmall?.copyWith(color: p.danger)),
          ],
          const SizedBox(height: Space.md),
          AppButton(
            label: 'Finalizar pedido',
            icon: LucideIcons.arrowRight,
            onPressed: abaixoMinimo ? null : () => irParaCheckout(context),
          ),
        ],
      ),
    );
  }
}

/// Barra flutuante "Ver sacola" no celular e tablet retrato.
class FloatingCartBar extends ConsumerStatefulWidget {
  const FloatingCartBar({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  ConsumerState<FloatingCartBar> createState() => _FloatingCartBarState();
}

class _FloatingCartBarState extends ConsumerState<FloatingCartBar> with SingleTickerProviderStateMixin {
  late final AnimationController _bump = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

  @override
  void dispose() {
    _bump.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final count = ref.watch(cartCountProvider);
    final total = ref.watch(cartSubtotalProvider);
    ref.listen(cartCountProvider, (prev, next) {
      if ((prev ?? 0) < next && Motion.enabled(context)) _bump.forward(from: 0);
    });

    return AnimatedSlide(
      offset: count == 0 ? const Offset(0, 1.6) : Offset.zero,
      duration: Motion.slow,
      curve: count == 0 ? Motion.exit : Motion.spring,
      child: AnimatedOpacity(
        opacity: count == 0 ? 0 : 1,
        duration: Motion.base,
        child: AnimatedBuilder(
          animation: _bump,
          builder: (context, child) {
            final t = _bump.value;
            final s = 1 + 0.06 * (t < 0.5 ? t * 2 : (1 - t) * 2);
            return Transform.scale(scale: s, child: child);
          },
          child: Pressable(
            onTap: count == 0 ? null : widget.onTap,
            borderRadius: Radii.rLg,
            semanticLabel: 'Ver sacola, ${itensLabel(count)}, ${money(total)}',
            child: Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: Space.sm),
              decoration: BoxDecoration(
                color: p.primary,
                borderRadius: Radii.rLg,
                boxShadow: [
                  BoxShadow(color: p.primary.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: p.onPrimary.withValues(alpha: 0.14), borderRadius: Radii.rMd),
                    alignment: Alignment.center,
                    child: AnimatedSwitcher(
                      duration: Motion.base,
                      transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                      child: Text(
                        '$count',
                        key: ValueKey(count),
                        style: context.text.titleMedium?.copyWith(color: p.onPrimary),
                      ),
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Text('Ver sacola', style: context.text.labelLarge?.copyWith(color: p.onPrimary)),
                  ),
                  AnimatedMoney(total, style: context.text.titleMedium?.copyWith(color: p.onPrimary)),
                  const SizedBox(width: Space.xs),
                  Icon(LucideIcons.chevronRight, color: p.onPrimary, size: 18),
                  const SizedBox(width: Space.xs),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
