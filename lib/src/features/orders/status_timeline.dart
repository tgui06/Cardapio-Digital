import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/tokens.dart';
import '../../data/models/pedido.dart';

IconData statusIcon(StatusPedido s) => switch (s) {
  StatusPedido.recebido => LucideIcons.receipt,
  StatusPedido.emPreparo => LucideIcons.cookingPot,
  StatusPedido.pronto => LucideIcons.bellRing,
  StatusPedido.entregue => LucideIcons.circleCheck,
  StatusPedido.cancelado => LucideIcons.circleX,
};

Color statusColor(AppPalette p, StatusPedido s) => switch (s) {
  StatusPedido.recebido => p.accent,
  StatusPedido.emPreparo => p.warning,
  StatusPedido.pronto => p.success,
  StatusPedido.entregue => p.textMuted,
  StatusPedido.cancelado => p.danger,
};

/// Linha do tempo Recebido → Em preparo → Pronto → Entregue.
class StatusTimeline extends StatelessWidget {
  const StatusTimeline({super.key, required this.status, this.vertical = false});

  final StatusPedido status;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final atual = StatusPedido.fluxo.indexOf(status);
    final passos = StatusPedido.fluxo;

    Widget dot(int i) {
      final feito = i <= atual;
      final corrente = i == atual && status != StatusPedido.entregue;
      Widget d = AnimatedContainer(
        duration: Motion.slow,
        curve: Motion.spring,
        width: corrente ? 48 : 40,
        height: corrente ? 48 : 40,
        decoration: BoxDecoration(
          color: feito ? p.primary : p.surfaceSunken,
          shape: BoxShape.circle,
          border: Border.all(color: feito ? p.primary : p.outline, width: 2),
          boxShadow: corrente ? [BoxShadow(color: p.primary.withValues(alpha: 0.45), blurRadius: 18)] : null,
        ),
        child: Icon(statusIcon(passos[i]), size: corrente ? 22 : 18, color: feito ? p.onPrimary : p.textMuted),
      );
      if (corrente && Motion.enabled(context)) {
        d = d
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scaleXY(begin: 1, end: 1.07, duration: 900.ms, curve: Curves.easeInOut);
      }
      return SizedBox(width: 52, height: 52, child: Center(child: d));
    }

    Widget label(int i) {
      final feito = i <= atual;
      return Text(
        passos[i].rotulo,
        textAlign: vertical ? TextAlign.start : TextAlign.center,
        style: context.text.labelMedium?.copyWith(color: feito ? p.textPrimary : p.textMuted),
      );
    }

    Widget linha(int i, Axis axis) {
      final feito = i < atual;
      return Expanded(
        child: Container(
          margin: axis == Axis.horizontal
              ? const EdgeInsets.symmetric(horizontal: 2)
              : const EdgeInsets.symmetric(vertical: 2),
          height: axis == Axis.horizontal ? 4 : null,
          width: axis == Axis.vertical ? 4 : null,
          decoration: BoxDecoration(color: p.surfaceSunken, borderRadius: Radii.rPill),
          alignment: axis == Axis.horizontal ? Alignment.centerLeft : Alignment.topCenter,
          child: LayoutBuilder(
            builder: (context, c) => AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              curve: Motion.emphasized,
              width: axis == Axis.horizontal ? (feito ? c.maxWidth : 0) : 4,
              height: axis == Axis.vertical ? (feito ? c.maxHeight : 0) : 4,
              decoration: BoxDecoration(color: p.primary, borderRadius: Radii.rPill),
            ),
          ),
        ),
      );
    }

    if (status == StatusPedido.cancelado) {
      return Row(
        children: [
          Icon(statusIcon(status), color: p.danger),
          const SizedBox(width: Space.xs),
          Text('Pedido cancelado · ${status.mensagem}', style: context.text.titleSmall?.copyWith(color: p.danger)),
        ],
      );
    }

    if (vertical) {
      return Column(
        children: [
          for (var i = 0; i < passos.length; i++) ...[
            Row(
              children: [
                dot(i),
                const SizedBox(width: Space.sm),
                Expanded(child: label(i)),
              ],
            ),
            if (i < passos.length - 1)
              SizedBox(
                height: 22,
                child: Row(
                  children: [
                    const SizedBox(width: 24),
                    Column(children: [linha(i, Axis.vertical)]),
                  ],
                ),
              ),
          ],
        ],
      );
    }

    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < passos.length; i++) ...[dot(i), if (i < passos.length - 1) linha(i, Axis.horizontal)],
          ],
        ),
        const SizedBox(height: Space.xs),
        Row(
          children: [
            for (var i = 0; i < passos.length; i++) ...[
              SizedBox(width: 52, height: 22, child: OverflowBox(maxWidth: 110, maxHeight: 22, child: label(i))),
              if (i < passos.length - 1) const Spacer(),
            ],
          ],
        ),
      ],
    );
  }
}
