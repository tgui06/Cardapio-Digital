import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/tokens.dart';
import 'pressable.dart';

enum ButtonTone { primary, secondary, ghost, danger }

/// Botão principal do app. Altura mínima de 56dp (alvo de toque confortável
/// para totem), com estado de carregamento e ícones opcionais.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.trailing,
    this.tone = ButtonTone.primary,
    this.loading = false,
    this.expand = true,
    this.height = 56,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Conteúdo à direita (ex.: preço total).
  final Widget? trailing;
  final ButtonTone tone;
  final bool loading;
  final bool expand;
  final double height;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final disabled = onPressed == null || loading;
    final (bg, fg, border) = switch (tone) {
      ButtonTone.primary => (p.primary, p.onPrimary, Colors.transparent),
      ButtonTone.secondary => (p.surfaceRaised, p.textPrimary, p.outlineStrong),
      ButtonTone.ghost => (Colors.transparent, p.textPrimary, Colors.transparent),
      ButtonTone.danger => (p.dangerSoft, p.danger, Colors.transparent),
    };
    final radius = Radii.rMd;

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: trailing == null ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
      children: [
        // O rótulo tem prioridade sobre o valor à direita.
        Flexible(
          flex: 3,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: fg))
              else if (icon != null)
                Icon(icon, color: fg, size: IconSizes.md),
              if (loading || icon != null) const SizedBox(width: Space.xs + 2),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelLarge?.copyWith(color: fg, fontSize: 16.5),
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: Space.sm),
          Flexible(
            flex: 2,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: DefaultTextStyle.merge(
                style: context.text.labelLarge?.copyWith(color: fg, fontSize: 16.5),
                child: trailing!,
              ),
            ),
          ),
        ],
      ],
    );

    return AnimatedOpacity(
      duration: Motion.fast,
      opacity: disabled && !loading ? 0.45 : 1,
      child: Pressable(
        onTap: disabled ? null : onPressed,
        borderRadius: radius,
        semanticLabel: semanticLabel ?? label,
        child: AnimatedContainer(
          duration: Motion.base,
          constraints: BoxConstraints(minHeight: height),
          padding: const EdgeInsets.symmetric(horizontal: Space.lg - 2),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: radius,
            border: Border.all(color: border),
            boxShadow: tone == ButtonTone.primary && !disabled
                ? [BoxShadow(color: p.primary.withValues(alpha: 0.28), blurRadius: 18, offset: const Offset(0, 8))]
                : null,
          ),
          child: content,
        ),
      ),
    );
  }
}

/// Botão redondo só com ícone — sempre com rótulo acessível e 48dp de alvo.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.label,
    this.size = 48,
    this.filled = true,
    this.badge,
    this.onImage = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String label;
  final double size;
  final bool filled;
  final int? badge;

  /// Sobre fotos: fundo translúcido escuro para manter contraste.
  final bool onImage;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final bg = onImage ? Colors.black.withValues(alpha: 0.42) : (filled ? p.surfaceRaised : Colors.transparent);
    final fg = onImage ? Colors.white : p.textPrimary;
    return Tooltip(
      message: label,
      child: Pressable(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(size),
        semanticLabel: label,
        scale: 0.92,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: bg,
                shape: BoxShape.circle,
                border: filled && !onImage ? Border.all(color: p.outline) : null,
              ),
              child: Icon(icon, color: fg, size: IconSizes.md),
            ),
            if (badge != null && badge! > 0) Positioned(right: -2, top: -2, child: CountBadge(count: badge!)),
          ],
        ),
      ),
    );
  }
}

class CountBadge extends StatelessWidget {
  const CountBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AnimatedSwitcher(
      duration: Motion.base,
      transitionBuilder: (c, a) => ScaleTransition(
        scale: CurvedAnimation(parent: a, curve: Motion.spring),
        child: c,
      ),
      child: Container(
        key: ValueKey(count),
        constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: p.primary,
          borderRadius: Radii.rPill,
          border: Border.all(color: p.background, width: 2),
        ),
        child: Text('$count', style: context.text.labelSmall?.copyWith(color: p.onPrimary, letterSpacing: 0)),
      ),
    );
  }
}
