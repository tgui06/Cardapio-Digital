import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/pressable.dart';
import '../../../data/models/cardapio.dart';

/// Trilho vertical de categorias do tablet deitado (navegação lateral, como pede o
/// padrão "adaptive navigation" para telas ≥ 900 dp em paisagem).
/// [dense] = trilho estreito com ícone sobre o rótulo, para tablets de 7–8".
class CategoryRail extends StatefulWidget {
  const CategoryRail({
    super.key,
    required this.categorias,
    required this.contagem,
    required this.ativa,
    required this.onSelect,
    required this.header,
    required this.footer,
    this.dense = false,
  });

  final List<Categoria> categorias;
  final Map<int, int> contagem;
  final int? ativa;
  final ValueChanged<Categoria> onSelect;
  final Widget header;
  final Widget footer;
  final bool dense;

  static double widthFor(BuildContext context, {required bool dense}) => dense ? 112 : 248;

  @override
  State<CategoryRail> createState() => _CategoryRailState();
}

class _CategoryRailState extends State<CategoryRail> {
  final _keys = <int, GlobalKey>{};

  @override
  void didUpdateWidget(covariant CategoryRail old) {
    super.didUpdateWidget(old);
    // Mantém a categoria ativa visível no trilho enquanto o cardápio rola.
    if (old.ativa != widget.ativa && widget.ativa != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _keys[widget.ativa]?.currentContext;
        if (ctx != null && ctx.mounted) {
          Scrollable.ensureVisible(
            ctx,
            duration: Motion.slow,
            curve: Motion.enter,
            alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
          );
          Scrollable.ensureVisible(
            ctx,
            duration: Motion.slow,
            curve: Motion.enter,
            alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final dense = widget.dense;
    return Container(
      width: CategoryRail.widthFor(context, dense: dense),
      decoration: BoxDecoration(
        color: p.surfaceSunken,
        border: Border(right: BorderSide(color: p.outline)),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                dense ? Space.sm : Space.lg - 4,
                Space.lg - 4,
                dense ? Space.sm : Space.md,
                Space.md,
              ),
              child: widget.header,
            ),
            if (!dense)
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.lg - 4, Space.xs, Space.md, Space.xs),
                child: Eyebrow('Cardápio', color: p.textMuted),
              ),
            Expanded(
              child: ShaderMask(
                // Esmaece as bordas da lista para indicar que ela rola.
                shaderCallback: (r) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0, 0.03, 0.92, 1],
                  colors: [Colors.transparent, Colors.black, Colors.black, Colors.transparent],
                ).createShader(r),
                blendMode: BlendMode.dstIn,
                child: ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: dense ? Space.xs : Space.sm, vertical: Space.xs),
                  itemCount: widget.categorias.length,
                  itemBuilder: (context, i) {
                    final c = widget.categorias[i];
                    return Padding(
                      key: _keys.putIfAbsent(c.id, GlobalKey.new),
                      padding: const EdgeInsets.only(bottom: 4),
                      child: dense
                          ? _DenseItem(categoria: c, selected: c.id == widget.ativa, onTap: () => widget.onSelect(c))
                          : _Item(
                              categoria: c,
                              count: widget.contagem[c.id] ?? 0,
                              selected: c.id == widget.ativa,
                              onTap: () => widget.onSelect(c),
                            ),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                dense ? Space.xs : Space.md,
                Space.xs,
                dense ? Space.xs : Space.md,
                Space.md,
              ),
              child: widget.footer,
            ),
          ],
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.categoria, required this.count, required this.selected, required this.onTap});

  final Categoria categoria;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Pressable(
      onTap: onTap,
      borderRadius: Radii.rMd,
      selected: selected,
      semanticLabel: categoria.nome,
      child: AnimatedContainer(
        duration: Motion.base,
        curve: Motion.enter,
        height: 56,
        padding: const EdgeInsets.only(left: 6, right: Space.sm),
        decoration: BoxDecoration(
          color: selected ? p.surfaceRaised : Colors.transparent,
          borderRadius: Radii.rMd,
          border: Border.all(color: selected ? p.outline : Colors.transparent),
        ),
        child: Row(
          children: [
            // Indicador lateral da categoria ativa.
            AnimatedContainer(
              duration: Motion.base,
              curve: Motion.spring,
              width: 3,
              height: selected ? 24 : 0,
              decoration: BoxDecoration(color: p.primary, borderRadius: Radii.rPill),
            ),
            const SizedBox(width: 7),
            AnimatedContainer(
              duration: Motion.base,
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: selected ? p.primary : p.surface,
                borderRadius: BorderRadius.circular(11),
                boxShadow: selected
                    ? [BoxShadow(color: p.primary.withValues(alpha: 0.45), blurRadius: 14, offset: const Offset(0, 4))]
                    : null,
              ),
              child: Icon(categoryIcon(categoria.icone), size: 19, color: selected ? p.onPrimary : p.textSecondary),
            ),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Text(
                categoria.nome,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelLarge?.copyWith(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? p.textPrimary : p.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DenseItem extends StatelessWidget {
  const _DenseItem({required this.categoria, required this.selected, required this.onTap});

  final Categoria categoria;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Pressable(
      onTap: onTap,
      borderRadius: Radii.rMd,
      selected: selected,
      semanticLabel: categoria.nome,
      child: AnimatedContainer(
        duration: Motion.base,
        padding: const EdgeInsets.symmetric(vertical: Space.xs, horizontal: 4),
        decoration: BoxDecoration(color: selected ? p.surfaceRaised : Colors.transparent, borderRadius: Radii.rMd),
        child: Column(
          children: [
            AnimatedContainer(
              duration: Motion.base,
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: selected ? p.primary : p.surface,
                borderRadius: BorderRadius.circular(14),
                boxShadow: selected
                    ? [BoxShadow(color: p.primary.withValues(alpha: 0.45), blurRadius: 14, offset: const Offset(0, 4))]
                    : null,
              ),
              child: Icon(categoryIcon(categoria.icone), size: 22, color: selected ? p.onPrimary : p.textSecondary),
            ),
            const SizedBox(height: 6),
            Text(
              categoria.nome,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelSmall?.copyWith(
                letterSpacing: 0,
                height: 1.15,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? p.textPrimary : p.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Barra horizontal fixa de categorias (celular e tablet retrato).
class CategoryChipsBar extends StatefulWidget {
  const CategoryChipsBar({
    super.key,
    required this.categorias,
    required this.ativa,
    required this.onSelect,
    required this.onSearch,
  });

  final List<Categoria> categorias;
  final int? ativa;
  final ValueChanged<Categoria> onSelect;
  final VoidCallback onSearch;

  static const double height = 68;

  @override
  State<CategoryChipsBar> createState() => _CategoryChipsBarState();
}

class _CategoryChipsBarState extends State<CategoryChipsBar> {
  final _keys = <int, GlobalKey>{};

  @override
  void didUpdateWidget(covariant CategoryChipsBar old) {
    super.didUpdateWidget(old);
    if (old.ativa != widget.ativa && widget.ativa != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _keys[widget.ativa]?.currentContext;
        if (ctx != null && ctx.mounted) {
          Scrollable.ensureVisible(ctx, duration: Motion.slow, curve: Motion.enter, alignment: 0.35);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      height: CategoryChipsBar.height,
      decoration: BoxDecoration(
        color: p.background,
        border: Border(bottom: BorderSide(color: p.outline)),
      ),
      child: Row(
        children: [
          Padding(
            padding: EdgeInsets.only(left: context.gutter - 4, right: 4),
            child: Tooltip(
              message: 'Buscar',
              child: Pressable(
                onTap: widget.onSearch,
                borderRadius: Radii.rPill,
                semanticLabel: 'Buscar no cardápio',
                child: Container(
                  width: 48,
                  height: 44,
                  decoration: BoxDecoration(
                    color: p.surfaceRaised,
                    borderRadius: Radii.rPill,
                    border: Border.all(color: p.outline),
                  ),
                  child: Icon(LucideIcons.search, size: 20, color: p.textPrimary),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.only(left: 4, right: context.gutter),
              itemCount: widget.categorias.length,
              separatorBuilder: (_, _) => const SizedBox(width: Space.xs),
              itemBuilder: (context, i) {
                final c = widget.categorias[i];
                final sel = c.id == widget.ativa;
                return Center(
                  child: Pressable(
                    key: _keys.putIfAbsent(c.id, GlobalKey.new),
                    onTap: () => widget.onSelect(c),
                    borderRadius: Radii.rPill,
                    selected: sel,
                    semanticLabel: c.nome,
                    child: AnimatedContainer(
                      duration: Motion.base,
                      curve: Motion.enter,
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: sel ? p.primary : p.surfaceRaised,
                        borderRadius: Radii.rPill,
                        border: Border.all(color: sel ? p.primary : p.outline),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(categoryIcon(c.icone), size: 18, color: sel ? p.onPrimary : p.textSecondary),
                          const SizedBox(width: 8),
                          Text(
                            c.nome,
                            style: context.text.labelMedium?.copyWith(color: sel ? p.onPrimary : p.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
