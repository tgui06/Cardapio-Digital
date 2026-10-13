import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/local/armazenamento_offline.dart' show cacheImagens;
import '../theme/app_palette.dart';
import '../theme/tokens.dart';
import 'skeleton.dart';

export '../../data/local/armazenamento_offline.dart' show cacheImagens;

/// Pede ao CDN a largura certa para cada uso (economiza dados no totem).
String sizedImage(String url, int width) {
  if (!url.contains('images.unsplash.com')) return url;
  return url.replaceFirst(RegExp(r'w=\d+'), 'w=$width');
}

/// Testes de widget não têm rede nem path_provider: desliga as imagens remotas.
bool appImageDisableNetwork = false;

class AppImage extends StatelessWidget {
  const AppImage(
    this.url, {
    super.key,
    this.width = 800,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.grayscale = false,
    this.semanticLabel,
  });

  final String? url;

  /// Largura solicitada ao CDN, em pixels.
  final int width;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final bool grayscale;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget img = url == null || appImageDisableNetwork
        ? _Fallback(color: p.surfaceSunken, icon: p.textMuted)
        : CachedNetworkImage(
            imageUrl: sizedImage(url!, width),
            // Cache próprio de longa duração: as fotos continuam aparecendo sem internet.
            cacheManager: cacheImagens,
            fit: fit,
            fadeInDuration: const Duration(milliseconds: 280),
            fadeOutDuration: const Duration(milliseconds: 120),
            placeholder: (_, _) => const Skeleton(),
            errorWidget: (_, _, _) => _Fallback(color: p.surfaceSunken, icon: p.textMuted),
          );
    if (grayscale) {
      img = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          0.2126, 0.7152, 0.0722, 0, 0, //
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0, 0, 0, 1, 0,
        ]),
        child: img,
      );
    }
    if (borderRadius != null) img = ClipRRect(borderRadius: borderRadius!, child: img);
    return Semantics(image: true, label: semanticLabel, excludeSemantics: semanticLabel == null, child: img);
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.color, required this.icon});

  final Color color;
  final Color icon;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: color,
    child: Center(child: Icon(LucideIcons.utensils, color: icon, size: 32)),
  );
}

/// Hero só no layout compacto. No tablet o detalhe abre num painel transparente
/// (`opaque: false`), e Heroes da rota de baixo ficam invisíveis depois que o painel fecha.
class MaybeHero extends StatelessWidget {
  const MaybeHero({super.key, required this.tag, required this.child});

  final Object tag;
  final Widget child;

  @override
  Widget build(BuildContext context) => context.isCompact ? Hero(tag: tag, child: child) : child;
}
