import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/models/cardapio.dart';
import '../theme/app_palette.dart';
import '../theme/tokens.dart';
import '../utils/format.dart';
import 'pressable.dart';

// ------------------------------------------------------------------ ícones

IconData categoryIcon(String key) => switch (key) {
  'cafe' => LucideIcons.coffee,
  'pao' => LucideIcons.croissant,
  'salgado' => LucideIcons.drumstick,
  'cerveja' => LucideIcons.beer,
  'promo' => LucideIcons.badgePercent,
  'gelado' => LucideIcons.citrus,
  'ovo' => LucideIcons.egg,
  'compartilhar' => LucideIcons.soup,
  'burger' => LucideIcons.hamburger,
  'prato' => LucideIcons.utensils,
  'pizza' => LucideIcons.pizza,
  'folha' => LucideIcons.leaf,
  'bolo' => LucideIcons.cake,
  'sorvete' => LucideIcons.iceCreamCone,
  'bebida' => LucideIcons.wine,
  'peixe' => LucideIcons.fish,
  _ => LucideIcons.cookingPot,
};

(IconData, Color Function(AppPalette)) tagStyle(ProdutoTag t) => switch (t) {
  ProdutoTag.maisPedido => (LucideIcons.star, (p) => p.warning),
  ProdutoTag.novo => (LucideIcons.sparkles, (p) => p.accent),
  ProdutoTag.chef => (LucideIcons.chefHat, (p) => p.accent),
  ProdutoTag.vegano => (LucideIcons.vegan, (p) => p.success),
  ProdutoTag.vegetariano => (LucideIcons.sprout, (p) => p.success),
  ProdutoTag.semGluten => (LucideIcons.wheatOff, (p) => p.success),
  ProdutoTag.semLactose => (LucideIcons.milkOff, (p) => p.success),
  ProdutoTag.picante => (LucideIcons.flame, (p) => p.danger),
  ProdutoTag.promocao => (LucideIcons.tag, (p) => p.danger),
};

// ------------------------------------------------------------------ selos

class TagBadge extends StatelessWidget {
  const TagBadge(this.tag, {super.key, this.compact = false, this.onImage = false});

  final ProdutoTag tag;
  final bool compact;
  final bool onImage;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (icon, colorOf) = tagStyle(tag);
    final color = onImage ? Colors.white : colorOf(p);
    // Mesmo desenho das badges do logotipo (ERP · CRM · APP · IA): caixa-alta e contorno arredondado.
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 9, vertical: compact ? 3 : 5),
      decoration: BoxDecoration(
        color: onImage ? ForvenColors.marinho.withValues(alpha: 0.62) : color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(compact ? 6 : 7),
        border: Border.all(color: color.withValues(alpha: onImage ? 0.85 : 0.7), width: 1.4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 12 : 14, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              tag.rotulo.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.7,
                fontSize: compact ? 10.5 : 11.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ preço

class PriceText extends StatelessWidget {
  const PriceText({super.key, required this.preco, this.precoOriginal, this.aPartirDe = false, this.style, this.color});

  final double preco;
  final double? precoOriginal;
  final bool aPartirDe;
  final TextStyle? style;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = (style ?? context.text.titleMedium)!.copyWith(color: color ?? p.textPrimary);
    // Uma linha só: em cards estreitos o texto encolhe com reticências em vez de quebrar o layout.
    return Text.rich(
      TextSpan(
        children: [
          if (aPartirDe) TextSpan(text: 'a partir de ', style: context.text.bodySmall),
          TextSpan(text: money(preco), style: s),
          if (precoOriginal != null && precoOriginal! > preco)
            TextSpan(
              text: '  ${money(precoOriginal!)}',
              style: context.text.bodySmall?.copyWith(
                decoration: TextDecoration.lineThrough,
                decorationColor: p.textMuted,
              ),
            ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Valor monetário que "rola" ao mudar.
class AnimatedMoney extends StatelessWidget {
  const AnimatedMoney(this.value, {super.key, this.style});

  final double value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value),
      duration: Motion.enabled(context) ? Motion.slow : Duration.zero,
      curve: Motion.enter,
      builder: (context, v, _) => Text(money(v), style: style),
    );
  }
}

// ------------------------------------------------------------------ stepper

class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 99,
    this.size = 44,
    this.compact = false,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final double size;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget btn(IconData icon, bool enabled, int delta, String label) => Pressable(
      onTap: enabled ? () => onChanged(value + delta) : null,
      borderRadius: BorderRadius.circular(size),
      scale: 0.88,
      semanticLabel: label,
      child: AnimatedContainer(
        duration: Motion.fast,
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: enabled ? (delta > 0 ? p.primary : p.surfaceRaised) : p.surfaceSunken,
          border: delta < 0 ? Border.all(color: p.outline) : null,
        ),
        child: Icon(icon, size: size * 0.42, color: enabled ? (delta > 0 ? p.onPrimary : p.textPrimary) : p.textMuted),
      ),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        btn(value <= 1 && min == 0 ? LucideIcons.trash2 : LucideIcons.minus, value > min, -1, 'Diminuir'),
        SizedBox(
          width: compact ? 32 : 40,
          child: AnimatedSwitcher(
            duration: Motion.base,
            transitionBuilder: (c, a) => ScaleTransition(
              scale: a,
              child: FadeTransition(opacity: a, child: c),
            ),
            child: Text(
              '$value',
              key: ValueKey(value),
              textAlign: TextAlign.center,
              style: context.text.titleMedium,
              semanticsLabel: 'Quantidade $value',
            ),
          ),
        ),
        btn(LucideIcons.plus, value < max, 1, 'Aumentar'),
      ],
    );
  }
}

// ------------------------------------------------------------------ marca

/// Marca do estabelecimento (cliente Forven). Mostra o logo configurado no ERP ou,
/// sem logo, um monograma com as iniciais no quadrado de cantos arredondados.
class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    required this.nome,
    this.size = 44,
    this.showName = true,
    this.light = false,
    this.logoUrl,
  });

  final String nome;
  final double size;
  final bool showName;

  /// Para uso sobre fotos/fundos escuros.
  final bool light;
  final String? logoUrl;

  static String iniciais(String nome) {
    final palavras = nome.split(RegExp(r'\s+')).where((w) => w.length > 2 || RegExp(r'^[A-ZÀ-Ú]').hasMatch(w)).toList();
    if (palavras.isEmpty) return nome.isEmpty ? '' : nome[0].toUpperCase();
    return palavras.take(2).map((w) => w[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fg = light ? Colors.white : p.textPrimary;
    final mark = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: p.primary,
        borderRadius: BorderRadius.circular(size * 0.3),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(color: p.primary.withValues(alpha: 0.45), blurRadius: size * 0.5, offset: Offset(0, size * 0.12)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: logoUrl != null
          ? Image.network(logoUrl!, fit: BoxFit.cover, width: size, height: size)
          : Text(
              iniciais(nome),
              style: GoogleFonts.publicSans(
                color: p.onPrimary,
                fontSize: size * 0.38,
                fontWeight: FontWeight.w800,
                letterSpacing: -size * 0.02,
                height: 1,
              ),
            ),
    );
    if (!showName) return mark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        SizedBox(width: size * 0.3),
        Flexible(
          child: Text(
            nome,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.titleLarge?.copyWith(
              color: fg,
              fontSize: size * 0.44,
              fontWeight: FontWeight.w700,
              letterSpacing: -size * 0.012,
            ),
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ pílula de status

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.pulse = false,
    this.onImage = false,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool pulse;
  final bool onImage;

  @override
  Widget build(BuildContext context) {
    Widget dot = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
    if (pulse && Motion.enabled(context)) {
      dot = dot
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .fade(begin: 1, end: 0.35, duration: 900.ms, curve: Curves.easeInOut);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: onImage ? Colors.black.withValues(alpha: 0.45) : color.withValues(alpha: 0.12),
        borderRadius: Radii.rPill,
        border: onImage ? Border.all(color: Colors.white.withValues(alpha: 0.18)) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) Icon(icon, size: 15, color: onImage ? Colors.white : color) else dot,
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelMedium?.copyWith(color: onImage ? Colors.white : color, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ estados vazios / erro

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.message, this.action});

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(color: p.accentSoft, shape: BoxShape.circle),
                child: Icon(icon, size: 44, color: p.accent),
              ).maybeAnimate(
                context,
                (a) => a.scale(begin: const Offset(0.8, 0.8), curve: Motion.spring, duration: 420.ms),
              ),
              const SizedBox(height: Space.lg),
              Text(title, textAlign: TextAlign.center, style: context.text.headlineSmall),
              const SizedBox(height: Space.xs),
              Text(message, textAlign: TextAlign.center, style: context.text.bodyMedium),
              if (action != null) ...[const SizedBox(height: Space.lg), action!],
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ animação

extension MaybeAnimate on Widget {
  /// Aplica efeitos do flutter_animate só se o sistema permitir animações.
  Widget maybeAnimate(
    BuildContext context,
    Animate Function(Animate a) effects, {
    Duration? delay,
    bool onPlayRepeat = false,
  }) {
    if (!Motion.enabled(context)) return this;
    return effects(animate(delay: delay, onPlay: onPlayRepeat ? (c) => c.repeat(reverse: true) : null));
  }

  /// Entrada padrão: fade + leve subida, com atraso escalonado por índice.
  Widget entrance(BuildContext context, {int index = 0, double dy = 0.08, int stepMs = 45}) {
    if (!Motion.enabled(context)) return this;
    return animate(delay: (stepMs * index.clamp(0, 12)).ms)
        .fadeIn(duration: 320.ms, curve: Motion.enter)
        .slideY(begin: dy, end: 0, duration: 380.ms, curve: Motion.emphasized);
  }
}

/// Rótulo de seção em caixa alta ("SUA SACOLA").
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: context.text.labelSmall?.copyWith(
      color: color ?? context.palette.accent,
      letterSpacing: 1.4,
      fontWeight: FontWeight.w700,
    ),
  );
}

String nomeCurto(String s) => s.split(' ').first;

String itensLabel(int n) => plural(n, 'item', 'itens');
