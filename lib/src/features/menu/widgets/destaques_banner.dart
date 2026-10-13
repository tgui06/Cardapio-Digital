import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/brand/forven_brand.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/pressable.dart';
import '../../../data/models/cardapio.dart';
import '../../../state/providers.dart';
import 'product_cards.dart';

/// Banner de destaques para o tablet deitado: largura total, foto à direita
/// fundindo no marinho, texto e CTA à esquerda. Avança sozinho e pausa ao toque.
class DestaquesBanner extends ConsumerStatefulWidget {
  const DestaquesBanner({super.key, required this.produtos});

  final List<Produto> produtos;

  @override
  ConsumerState<DestaquesBanner> createState() => _DestaquesBannerState();
}

class _DestaquesBannerState extends ConsumerState<DestaquesBanner> {
  final _page = PageController();
  Timer? _timer;
  DateTime _ultimoToque = DateTime.fromMillisecondsSinceEpoch(0);
  int _atual = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || !_page.hasClients || widget.produtos.length < 2) return;
      if (DateTime.now().difference(_ultimoToque) < const Duration(seconds: 12)) return;
      final next = (_atual + 1) % widget.produtos.length;
      if (Motion.enabled(context)) {
        _page.animateToPage(next, duration: const Duration(milliseconds: 900), curve: Motion.emphasized);
      } else {
        _page.jumpToPage(next);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _page.dispose();
    super.dispose();
  }

  void _ir(int i) {
    _ultimoToque = DateTime.now();
    _page.animateToPage(i, duration: Motion.page, curve: Motion.emphasized);
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    final altura = (h * 0.38).clamp(210.0, 330.0);
    final n = widget.produtos.length;

    return SizedBox(
      height: altura,
      child: Listener(
        onPointerDown: (_) => _ultimoToque = DateTime.now(),
        child: Stack(
          children: [
            Positioned.fill(
              child: PageView.builder(
                controller: _page,
                itemCount: n,
                onPageChanged: (i) => setState(() => _atual = i),
                itemBuilder: (context, i) => AnimatedBuilder(
                  animation: _page,
                  builder: (context, child) {
                    // Parallax leve da foto conforme a página desliza.
                    final pos = _page.hasClients && _page.position.haveDimensions ? (_page.page ?? 0) - i : 0.0;
                    return _Slide(produto: widget.produtos[i], parallax: pos.clamp(-1.0, 1.0));
                  },
                ),
              ),
            ),
            Positioned(
              right: Space.lg,
              bottom: Space.md + 2,
              child: Row(
                children: [
                  Text(
                    '${twoDigits(_atual + 1)} / ${twoDigits(n)}',
                    style: context.text.labelMedium?.copyWith(color: Colors.white.withValues(alpha: 0.8)),
                  ),
                  const SizedBox(width: Space.sm),
                  for (var i = 0; i < n; i++)
                    GestureDetector(
                      onTap: () => _ir(i),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 12),
                        child: AnimatedContainer(
                          duration: Motion.slow,
                          curve: Motion.emphasized,
                          width: i == _atual ? 26 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: i == _atual ? Colors.white : Colors.white.withValues(alpha: 0.35),
                            borderRadius: Radii.rPill,
                          ),
                        ),
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

class _Slide extends ConsumerWidget {
  const _Slide({required this.produto, required this.parallax});

  final Produto produto;
  final double parallax;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final cardapio = ref.watch(cardapioProvider).requireValue;
    final categoria = cardapio.categoria(produto.categoriaId);
    final ok = cardapio.disponivelAgora(produto, ref.watch(nowProvider));
    final tag = heroTagFor(produto, 'banner');
    final short = context.isShort;

    return Pressable(
      onTap: () => openProduct(context, produto, heroTag: tag),
      borderRadius: Radii.rXl,
      scale: 0.99,
      semanticLabel: 'Destaque: ${produto.nome}, ${money(produto.precoAPartirDe)}',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.xl),
        child: LayoutBuilder(
          builder: (context, c) {
            final fotoW = c.maxWidth * 0.66;
            // Banner estreito (sacola aberta em tablet pequeno): texto mais largo e enxuto.
            final estreito = c.maxWidth < 640;
            return Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: p.vitrine),
                // Foto à direita com parallax.
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: -parallax * 60,
                  width: fotoW,
                  child: AppImage(produto.imagemUrl, width: 1200, grayscale: !ok),
                ),
                // Fusão da foto com o marinho.
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      stops: const [0.30, 0.52, 0.78],
                      colors: [p.vitrine, p.vitrine.withValues(alpha: 0.82), p.vitrine.withValues(alpha: 0)],
                    ),
                  ),
                ),
                // Luz e grafismo da marca do lado do texto.
                Positioned(
                  left: -120,
                  top: -140,
                  width: 420,
                  height: 420,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [p.primary.withValues(alpha: 0.32), p.primary.withValues(alpha: 0)],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: -40,
                  bottom: -90,
                  width: 300,
                  height: 220,
                  child: CustomPaint(
                    painter: SymbolOutlinePainter(
                      color: Colors.white.withValues(alpha: 0.07),
                      layout: SymbolLayout.centered,
                      strokeWidth: 1.4,
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Radii.xl),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                ),
                // Texto + CTA
                Positioned(
                  left: short ? Space.lg : Space.xl,
                  top: 0,
                  bottom: 0,
                  width: c.maxWidth * (estreito ? 0.64 : 0.5),
                  child: Opacity(
                    opacity: (1 - parallax.abs() * 1.4).clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(parallax * -40, 0),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: c.maxWidth * (estreito ? 0.64 : 0.5),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
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
                              SizedBox(height: short ? Space.sm : Space.md),
                              Text(
                                produto.nome,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style:
                                    (estreito
                                            ? context.text.headlineMedium
                                            : short
                                            ? context.text.headlineLarge
                                            : context.text.displaySmall)
                                        ?.copyWith(color: Colors.white),
                              ),
                              if (!estreito) ...[
                                SizedBox(height: short ? Space.xxs : Space.xs),
                                Text(
                                  produto.descricao,
                                  maxLines: short ? 1 : 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.text.bodyLarge?.copyWith(color: Colors.white.withValues(alpha: 0.78)),
                                ),
                              ],
                              SizedBox(height: short || estreito ? Space.sm + 2 : Space.lg),
                              Wrap(
                                spacing: Space.lg,
                                runSpacing: Space.sm,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  PriceText(
                                    preco: produto.precoAPartirDe,
                                    precoOriginal: produto.precoOriginal,
                                    aPartirDe: produto.precoVariavel,
                                    color: p.destaqueVitrine,
                                    style: context.text.headlineSmall,
                                  ),
                                  if (ok)
                                    AppButton(
                                      label: 'Adicionar',
                                      icon: LucideIcons.plus,
                                      expand: false,
                                      height: short ? 48 : 52,
                                      onPressed: () => quickAdd(context, ref, produto, heroTag: tag),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
