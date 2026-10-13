import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/pressable.dart';
import '../../data/models/cardapio.dart';

class OptionGroupCard extends StatelessWidget {
  const OptionGroupCard({
    super.key,
    required this.grupo,
    required this.selecoes,
    required this.onChange,
    this.destacarFalta = false,
    this.enabled = true,
  });

  final GrupoComplemento grupo;
  final Map<int, int> selecoes;
  final void Function(OpcaoComplemento opcao, int quantidade) onChange;
  final bool destacarFalta;
  final bool enabled;

  int get _count => selecoes.values.fold(0, (s, v) => s + v);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final ok = _count >= grupo.minimo;
    final cheio = _count >= grupo.maximo;
    final faltaVisivel = destacarFalta && !ok;

    return AnimatedContainer(
      duration: Motion.base,
      decoration: BoxDecoration(
        color: p.surfaceRaised,
        borderRadius: Radii.rLg,
        border: Border.all(color: faltaVisivel ? p.danger : p.outline, width: faltaVisivel ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.md, Space.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(grupo.nome, style: context.text.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        grupo.descricao.isEmpty ? grupo.regraRotulo : '${grupo.regraRotulo} · ${grupo.descricao}',
                        style: context.text.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Space.sm),
                AnimatedSwitcher(
                  duration: Motion.base,
                  transitionBuilder: (c, a) => ScaleTransition(
                    scale: a,
                    child: FadeTransition(opacity: a, child: c),
                  ),
                  child: _Badge(
                    key: ValueKey('$ok-${grupo.obrigatorio}-$_count'),
                    grupo: grupo,
                    count: _count,
                    ok: ok,
                    falta: faltaVisivel,
                  ),
                ),
              ],
            ),
          ),
          for (final o in grupo.opcoes)
            _OptionTile(
              key: ValueKey(o.id),
              grupo: grupo,
              opcao: o,
              quantidade: selecoes[o.id] ?? 0,
              bloqueado:
                  !enabled || !o.disponivel || (cheio && grupo.tipo != TipoGrupo.unico && (selecoes[o.id] ?? 0) == 0),
              grupoCheio: cheio,
              onChange: (q) => onChange(o, q),
            ),
          const SizedBox(height: Space.xs),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({super.key, required this.grupo, required this.count, required this.ok, required this.falta});

  final GrupoComplemento grupo;
  final int count;
  final bool ok;
  final bool falta;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (String label, Color color, IconData? icon) = switch ((grupo.obrigatorio, ok, falta)) {
      (true, true, _) => ('Pronto', p.success, LucideIcons.check),
      (true, false, true) => ('Falta escolher', p.danger, LucideIcons.triangleAlert),
      (true, false, false) => ('Obrigatório', p.warning, null),
      _ => (grupo.tipo == TipoGrupo.unico ? 'Opcional' : '$count/${grupo.maximo}', p.textMuted, null),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: Radii.rPill),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 4)],
          Text(label, style: context.text.labelSmall?.copyWith(color: color, letterSpacing: 0.3)),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    super.key,
    required this.grupo,
    required this.opcao,
    required this.quantidade,
    required this.bloqueado,
    required this.grupoCheio,
    required this.onChange,
  });

  final GrupoComplemento grupo;
  final OpcaoComplemento opcao;
  final int quantidade;
  final bool bloqueado;
  final bool grupoCheio;
  final ValueChanged<int> onChange;

  bool get _selected => quantidade > 0;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isQtd = grupo.tipo == TipoGrupo.quantidade;
    final esgotado = !opcao.disponivel;

    void tap() {
      if (bloqueado && !_selected) return;
      switch (grupo.tipo) {
        case TipoGrupo.unico:
          onChange(_selected && !grupo.obrigatorio ? 0 : 1);
        case TipoGrupo.multiplo:
          onChange(_selected ? 0 : 1);
        case TipoGrupo.quantidade:
          if (!_selected) onChange(1);
      }
    }

    final preco = Text(
      esgotado ? 'Esgotado' : moneyDelta(opcao.precoAdicional),
      style: context.text.labelMedium?.copyWith(
        color: esgotado ? p.danger : (opcao.precoAdicional > 0 ? p.textPrimary : p.success),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.xs, vertical: 2),
      child: Opacity(
        opacity: bloqueado && !_selected ? 0.45 : 1,
        child: Pressable(
          onTap: isQtd && _selected ? null : tap,
          borderRadius: Radii.rMd,
          scale: 0.985,
          selected: _selected,
          semanticLabel: '${opcao.nome}, ${esgotado ? 'esgotado' : moneyDelta(opcao.precoAdicional)}',
          child: AnimatedContainer(
            duration: Motion.base,
            curve: Motion.enter,
            constraints: const BoxConstraints(minHeight: 60),
            padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: Space.xs),
            decoration: BoxDecoration(
              color: _selected ? p.primarySoft : Colors.transparent,
              borderRadius: Radii.rMd,
              border: Border.all(color: _selected ? p.primary.withValues(alpha: 0.6) : Colors.transparent, width: 1.5),
            ),
            child: Row(
              children: [
                if (!isQtd) ...[
                  _Indicator(selected: _selected, round: grupo.tipo == TipoGrupo.unico),
                  const SizedBox(width: Space.sm),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        opcao.nome,
                        style: context.text.titleSmall?.copyWith(
                          fontWeight: _selected ? FontWeight.w800 : FontWeight.w600,
                          decoration: esgotado ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      if (isQtd || opcao.descricao.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        if (opcao.descricao.isNotEmpty) Text(opcao.descricao, style: context.text.bodySmall),
                        if (isQtd) preco,
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: Space.sm),
                if (isQtd)
                  AnimatedSwitcher(
                    duration: Motion.base,
                    child: _selected
                        ? QuantityStepper(
                            key: const ValueKey('stepper'),
                            value: quantidade,
                            min: 0,
                            max: (grupoCheio ? quantidade : opcao.maximo).clamp(0, opcao.maximo),
                            size: 40,
                            compact: true,
                            onChanged: onChange,
                          )
                        : _PlusChip(key: const ValueKey('plus'), enabled: !bloqueado, onTap: tap),
                  )
                else
                  preco,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Indicator extends StatelessWidget {
  const _Indicator({required this.selected, required this.round});

  final bool selected;
  final bool round;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AnimatedContainer(
      duration: Motion.base,
      curve: Motion.spring,
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: round ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: round ? null : BorderRadius.circular(8),
        color: selected ? p.primary : Colors.transparent,
        border: Border.all(color: selected ? p.primary : p.outlineStrong, width: 2),
      ),
      child: AnimatedScale(
        scale: selected ? 1 : 0,
        duration: Motion.base,
        curve: Motion.spring,
        child: round
            ? Center(
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: p.onPrimary, shape: BoxShape.circle),
                ),
              )
            : Icon(LucideIcons.check, size: 16, color: p.onPrimary),
      ),
    );
  }
}

class _PlusChip extends StatelessWidget {
  const _PlusChip({super.key, required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Pressable(
      onTap: enabled ? onTap : null,
      borderRadius: Radii.rPill,
      semanticLabel: 'Adicionar',
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          borderRadius: Radii.rPill,
          border: Border.all(color: p.accent.withValues(alpha: 0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.plus, size: 16, color: p.accent),
            const SizedBox(width: 6),
            Text('Adicionar', style: context.text.labelMedium?.copyWith(color: p.accent)),
          ],
        ),
      ),
    );
  }
}
