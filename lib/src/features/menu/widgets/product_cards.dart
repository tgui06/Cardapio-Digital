import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/navigation.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/toast.dart';
import '../../../data/models/cardapio.dart';
import '../../../data/models/cart_item.dart';
import '../../../state/providers.dart';
import '../../product/product_detail_screen.dart';

/// Abre o detalhe do produto (página no celular, painel no tablet).
Future<void> openProduct(BuildContext context, Produto produto, {required String heroTag, CartItem? editing}) {
  return pushAdaptive<void>(context, (_) => ProductDetailScreen(produto: produto, heroTag: heroTag, editing: editing));
}

/// "+" rápido: adiciona direto se não houver escolha obrigatória.
void quickAdd(BuildContext context, WidgetRef ref, Produto produto, {required String heroTag}) {
  if (produto.grupos.any((g) => g.obrigatorio)) {
    openProduct(context, produto, heroTag: heroTag);
    return;
  }
  ref
      .read(cartProvider.notifier)
      .add(CartItem(uid: uuid.v4(), produto: produto, quantidade: 1, selecoes: const {}, observacao: ''));
  showToast(context, '${produto.nome} na sacola');
}

/// Tag de Hero única por origem (o mesmo produto aparece em destaques e na lista).
String heroTagFor(Produto p, String origem) => 'produto-${p.id}-$origem';

// ======================================================================== botão +

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap, required this.label, this.size = 44});

  final VoidCallback onTap;
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(size),
      scale: 0.86,
      semanticLabel: label,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: p.primary,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: p.shadow, blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Icon(LucideIcons.plus, color: p.onPrimary, size: size * 0.45),
      ),
    );
  }
}

class _UnavailableBadge extends StatelessWidget {
  const _UnavailableBadge(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.7), borderRadius: Radii.rPill),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(LucideIcons.clock, size: 14, color: Colors.white),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelSmall?.copyWith(color: Colors.white, letterSpacing: 0.2),
          ),
        ),
      ],
    ),
  );
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.produto, this.compact = false});

  final Produto produto;

  /// No card da grade mostra só o tempo de preparo.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final items = <(IconData, String)>[
      if (produto.tempoPreparoMin != null) (LucideIcons.timer, '${produto.tempoPreparoMin} min'),
      if (!compact && produto.serve != null && produto.serve! > 1) (LucideIcons.users, 'Serve ${produto.serve}'),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: Space.sm,
      clipBehavior: Clip.hardEdge,
      children: [
        for (final (icon, label) in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: p.textMuted),
              const SizedBox(width: 4),
              Flexible(
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodySmall),
              ),
            ],
          ),
      ],
    );
  }
}

// ======================================================================== lista (celular)

class ProductTile extends ConsumerWidget {
  const ProductTile({super.key, required this.produto, this.origem = 'lista'});

  final Produto produto;
  final String origem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final cardapio = ref.watch(cardapioProvider).requireValue;
    final now = ref.watch(nowProvider);
    final motivo = cardapio.motivoIndisponivel(produto, now);
    final ok = motivo == null;
    final tag = heroTagFor(produto, origem);
    final firstTag = produto.tags.isEmpty ? null : produto.tags.first;

    return Pressable(
      onTap: () => openProduct(context, produto, heroTag: tag),
      borderRadius: Radii.rLg,
      scale: 0.985,
      semanticLabel: '${produto.nome}, ${money(produto.precoAPartirDe)}${ok ? '' : ', $motivo'}',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.md, horizontal: Space.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Opacity(
                opacity: ok ? 1 : 0.55,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (firstTag != null) ...[TagBadge(firstTag, compact: true), const SizedBox(height: Space.xs)],
                    Text(produto.nome, style: context.text.titleMedium),
                    const SizedBox(height: Space.xxs),
                    Text(
                      produto.descricao,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodyMedium,
                    ),
                    const SizedBox(height: Space.sm),
                    // Preço tem prioridade: se não couber, o tempo de preparo desce de linha.
                    Wrap(
                      spacing: Space.sm,
                      runSpacing: Space.xxs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        PriceText(
                          preco: produto.precoAPartirDe,
                          precoOriginal: produto.precoOriginal,
                          aPartirDe: produto.precoVariavel,
                          color: produto.emPromocao ? p.danger : null,
                        ),
                        _MetaRow(produto: produto),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: Space.md),
            SizedBox(
              width: 116,
              height: 116,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: MaybeHero(
                      tag: tag,
                      child: AppImage(produto.imagemUrl, width: 300, borderRadius: Radii.rMd, grayscale: !ok),
                    ),
                  ),
                  if (!ok)
                    Positioned(
                      left: 6,
                      right: 6,
                      bottom: 6,
                      child: Center(child: _UnavailableBadge(produto.disponivel ? 'Fora do horário' : 'Esgotado')),
                    )
                  else
                    Positioned(
                      right: -6,
                      bottom: -6,
                      child: _AddButton(
                        onTap: () => quickAdd(context, ref, produto, heroTag: tag),
                        label: 'Adicionar ${produto.nome}',
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================================================================== grade (tablet)

class ProductCard extends ConsumerWidget {
  const ProductCard({super.key, required this.produto, this.origem = 'grade', this.imageAspect = 4 / 3});

  final Produto produto;
  final String origem;

  /// Proporção da foto (16:10 no tablet deitado, para caber mais itens por tela).
  final double imageAspect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final cardapio = ref.watch(cardapioProvider).requireValue;
    final motivo = cardapio.motivoIndisponivel(produto, ref.watch(nowProvider));
    final ok = motivo == null;
    final tag = heroTagFor(produto, origem);

    return Pressable(
      onTap: () => openProduct(context, produto, heroTag: tag),
      borderRadius: Radii.rLg,
      scale: 0.975,
      semanticLabel: '${produto.nome}, ${money(produto.precoAPartirDe)}${ok ? '' : ', $motivo'}',
      child: Container(
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: Radii.rLg,
          border: Border.all(color: p.outline),
          boxShadow: [BoxShadow(color: p.shadow.withValues(alpha: 0.25), blurRadius: 18, offset: const Offset(0, 8))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: imageAspect,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MaybeHero(
                    tag: tag,
                    child: AppImage(produto.imagemUrl, width: 520, grayscale: !ok),
                  ),
                  if (produto.tags.isNotEmpty)
                    Positioned(
                      left: Space.sm,
                      top: Space.sm,
                      child: TagBadge(produto.tags.first, compact: true, onImage: true),
                    ),
                  if (!ok)
                    Positioned(
                      left: Space.sm,
                      bottom: Space.sm,
                      right: Space.sm,
                      child: Align(alignment: Alignment.centerLeft, child: _UnavailableBadge(motivo)),
                    )
                  else
                    Positioned(
                      right: Space.sm,
                      bottom: Space.sm,
                      child: _AddButton(
                        onTap: () => quickAdd(context, ref, produto, heroTag: tag),
                        label: 'Adicionar ${produto.nome}',
                        size: 46,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Opacity(
                opacity: ok ? 1 : 0.55,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Space.md, Space.md - 2, Space.md, Space.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(produto.nome, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleMedium),
                      const SizedBox(height: Space.xxs),
                      Expanded(
                        child: Text(
                          produto.descricao,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodyMedium?.copyWith(fontSize: 14.5),
                        ),
                      ),
                      LayoutBuilder(
                        builder: (context, c) => Row(
                          children: [
                            Flexible(
                              child: PriceText(
                                preco: produto.precoAPartirDe,
                                precoOriginal: produto.precoOriginal,
                                aPartirDe: produto.precoVariavel && c.maxWidth >= 220,
                                color: produto.emPromocao ? p.danger : null,
                              ),
                            ),
                            if (c.maxWidth >= 250) ...[
                              const SizedBox(width: Space.xs),
                              _MetaRow(produto: produto, compact: true),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================================================================== destaques

class FeaturedCard extends ConsumerWidget {
  const FeaturedCard({super.key, required this.produto});

  final Produto produto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final cardapio = ref.watch(cardapioProvider).requireValue;
    final ok = cardapio.disponivelAgora(produto, ref.watch(nowProvider));
    final tag = heroTagFor(produto, 'destaque');
    final categoria = cardapio.categoria(produto.categoriaId);

    return Pressable(
      onTap: () => openProduct(context, produto, heroTag: tag),
      borderRadius: Radii.rXl,
      scale: 0.975,
      semanticLabel: 'Destaque: ${produto.nome}, ${money(produto.precoAPartirDe)}',
      child: ClipRRect(
        borderRadius: Radii.rXl,
        child: Stack(
          fit: StackFit.expand,
          children: [
            MaybeHero(
              tag: tag,
              child: AppImage(produto.imagemUrl, width: 900, grayscale: !ok),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.25, 0.62, 1],
                  colors: [
                    Colors.transparent,
                    p.imageOverlay.withValues(alpha: 0.55),
                    p.imageOverlay.withValues(alpha: 0.94),
                  ],
                ),
              ),
            ),
            Positioned(
              left: Space.md,
              top: Space.md,
              right: Space.md,
              child: Row(
                children: [
                  Flexible(
                    child: StatusPill(
                      label: categoria.nome,
                      color: Colors.white,
                      icon: categoryIcon(categoria.icone),
                      onImage: true,
                    ),
                  ),
                  if (produto.tags.isNotEmpty) ...[
                    const SizedBox(width: Space.xs),
                    TagBadge(produto.tags.first, onImage: true),
                  ],
                ],
              ),
            ),
            Positioned(
              left: Space.lg - 4,
              right: Space.lg - 4,
              bottom: Space.lg - 4,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          produto.nome,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.headlineMedium?.copyWith(color: Colors.white),
                        ),
                        const SizedBox(height: Space.xxs),
                        Text(
                          produto.descricao,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.82)),
                        ),
                        const SizedBox(height: Space.sm),
                        PriceText(
                          preco: produto.precoAPartirDe,
                          precoOriginal: produto.precoOriginal,
                          aPartirDe: produto.precoVariavel,
                          color: Colors.white,
                          style: context.text.titleLarge,
                        ),
                      ],
                    ),
                  ),
                  if (ok) ...[
                    const SizedBox(width: Space.md),
                    _AddButton(
                      onTap: () => quickAdd(context, ref, produto, heroTag: tag),
                      label: 'Adicionar ${produto.nome}',
                      size: 52,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mini card horizontal usado em "Combina com" e sugestões da sacola.
class SuggestionCard extends ConsumerWidget {
  const SuggestionCard({super.key, required this.produto, required this.origem, this.width = 168});

  final Produto produto;
  final String origem;
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final tag = heroTagFor(produto, origem);
    return SizedBox(
      width: width,
      child: Pressable(
        onTap: () => openProduct(context, produto, heroTag: tag),
        borderRadius: Radii.rMd,
        semanticLabel: '${produto.nome}, ${money(produto.precoAPartirDe)}',
        child: Container(
          decoration: BoxDecoration(
            color: p.surfaceRaised,
            borderRadius: Radii.rMd,
            border: Border.all(color: p.outline),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: width * 0.62,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MaybeHero(tag: tag, child: AppImage(produto.imagemUrl, width: 360)),
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: _AddButton(
                        onTap: () => quickAdd(context, ref, produto, heroTag: tag),
                        label: 'Adicionar ${produto.nome}',
                        size: 40,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(Space.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(produto.nome, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
                    const SizedBox(height: 2),
                    Text(money(produto.precoAPartirDe), style: context.text.bodySmall?.copyWith(color: p.accent)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
