import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/toast.dart';
import '../../data/models/chamado.dart';
import '../../data/repositories/cardapio_repository.dart';
import '../../state/providers.dart';
import '../../state/settings.dart';
import '../chamar_garcom/chamar_garcom.dart';

/// Avisa o garçom (vibração + som + aviso na tela) quando chega um chamado novo.
void ouvirChamadosNovos(BuildContext context, WidgetRef ref) {
  ref.listen(chamadosAbertosProvider, (antes, agora) {
    final conhecidos = antes?.value?.map((c) => c.codigo).toSet();
    if (conhecidos == null) return; // primeira carga: não é novidade
    final novos = (agora.value ?? const <Chamado>[]).where((c) => !conhecidos.contains(c.codigo)).toList();
    if (novos.isEmpty) return;
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);
    final c = novos.first;
    showToast(
      context,
      novos.length == 1 ? 'Mesa ${c.mesa}: ${c.motivoRotulo}' : '${novos.length} chamados novos (mesa ${c.mesa}…)',
      icon: LucideIcons.bellRing,
    );
  });
}

Future<void> atualizarChamado(BuildContext context, WidgetRef ref, Chamado c, StatusChamado status) async {
  HapticFeedback.mediumImpact();
  try {
    await ref
        .read(repositoryProvider)
        .atualizarChamado(c.codigo, status, garcomId: ref.read(settingsProvider).garcomId);
    ref.invalidate(chamadosAbertosProvider);
    if (context.mounted) {
      showToast(
        context,
        status == StatusChamado.atendido ? 'Mesa ${c.mesa} atendida' : 'A mesa ${c.mesa} sabe que você está indo',
      );
    }
  } on AppException catch (e) {
    if (context.mounted) showToast(context, e.mensagem, icon: LucideIcons.circleAlert, error: true);
  }
}

/// Faixa "Chamados" no topo do mapa de mesas.
class ChamadosSliver extends ConsumerWidget {
  const ChamadosSliver({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ativo = ref.watch(cardapioProvider.select((c) => c.value?.loja.chamarGarcom.ativo ?? false));
    final chamados = ref.watch(chamadosAbertosProvider).value ?? const <Chamado>[];
    if (!ativo || chamados.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
    final p = context.palette;
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(context.gutter, 0, context.gutter, Space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(LucideIcons.bellRing, size: 20, color: p.warning).maybeAnimate(
                  context,
                  (a) => a.rotate(begin: -0.05, end: 0.05, duration: const Duration(milliseconds: 280)),
                  onPlayRepeat: true,
                ),
                const SizedBox(width: Space.xs),
                Text('Chamados', style: context.text.titleLarge),
                const SizedBox(width: Space.xs),
                CountBadge(count: chamados.length),
              ],
            ),
            const SizedBox(height: Space.sm),
            LayoutBuilder(
              builder: (context, c) {
                final colunas = (c.maxWidth / 380).floor().clamp(1, 3);
                final largura = (c.maxWidth - Space.sm * (colunas - 1)) / colunas;
                return Wrap(
                  spacing: Space.sm,
                  runSpacing: Space.sm,
                  children: [
                    for (final (i, ch) in chamados.indexed)
                      SizedBox(
                        width: largura,
                        child: ChamadoCard(chamado: ch).entrance(context, index: i),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class ChamadoCard extends ConsumerWidget {
  const ChamadoCard({super.key, required this.chamado});

  final Chamado chamado;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final now = ref.watch(nowProvider);
    final todosVeem = ref.watch(cardapioProvider.select((c) => c.value?.loja.chamarGarcom.todosVeem ?? false));
    final aCaminho = chamado.status == StatusChamado.aCaminho;
    final cor = aCaminho ? p.accent : p.warning;
    final detalhe = [
      'há ${elapsed(chamado.criadoEm, now)}',
      if (aCaminho && chamado.atendidoPorNome != null) '${chamado.atendidoPorNome} a caminho',
      if (!aCaminho && (todosVeem || chamado.garcomNome == null)) chamado.garcomNome ?? 'sem responsável',
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.all(Space.sm),
      decoration: BoxDecoration(
        color: Color.alphaBlend(cor.withValues(alpha: 0.08), p.surface),
        borderRadius: Radii.rLg,
        border: Border.all(color: cor.withValues(alpha: 0.45), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: cor.withValues(alpha: 0.16), borderRadius: Radii.rMd),
            child: Text('${chamado.mesa}', style: context.text.headlineSmall?.copyWith(color: cor)),
          ),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(iconeChamado(_icone(ref)), size: 16, color: cor),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        chamado.motivoRotulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.titleSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(detalhe, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: Space.xs),
          if (!aCaminho)
            RoundIconButton(
              icon: LucideIcons.footprints,
              label: 'Estou indo à mesa ${chamado.mesa}',
              size: 44,
              filled: false,
              onPressed: () => atualizarChamado(context, ref, chamado, StatusChamado.aCaminho),
            ),
          const SizedBox(width: Space.xxs),
          RoundIconButton(
            icon: LucideIcons.check,
            label: 'Mesa ${chamado.mesa} atendida',
            size: 44,
            onPressed: () => atualizarChamado(context, ref, chamado, StatusChamado.atendido),
          ),
        ],
      ),
    );
  }

  String _icone(WidgetRef ref) {
    final motivos = ref.read(cardapioProvider).value?.loja.chamarGarcom.motivos ?? const <MotivoChamado>[];
    for (final m in motivos) {
      if (m.chave == chamado.motivo) return m.icone;
    }
    return 'sino';
  }
}

/// "Garçom: Carla" no topo do mapa de mesas; toque para trocar.
class GarcomChip extends ConsumerWidget {
  const GarcomChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final garcons = ref.watch(cardapioProvider.select((c) => c.value?.garcons)) ?? const <GarcomInfo>[];
    final ativo = ref.watch(cardapioProvider.select((c) => c.value?.loja.chamarGarcom.ativo ?? false));
    if (!ativo || garcons.isEmpty) return const SizedBox.shrink();
    final id = ref.watch(settingsProvider.select((s) => s.garcomId));
    final nome = garcons.where((g) => g.id == id).map((g) => g.nome).firstOrNull;
    final p = context.palette;
    return Pressable(
      onTap: () => escolherGarcom(context),
      borderRadius: Radii.rPill,
      semanticLabel: 'Garçom deste celular: ${nome ?? 'todos os chamados'}. Toque para trocar',
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: Space.sm),
        decoration: BoxDecoration(
          color: p.surfaceRaised,
          borderRadius: Radii.rPill,
          border: Border.all(color: p.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.userRound, size: 18, color: p.accent),
            const SizedBox(width: 6),
            Text(nome ?? 'Todos os chamados', style: context.text.labelMedium),
            const SizedBox(width: 2),
            Icon(LucideIcons.chevronDown, size: 16, color: p.textMuted),
          ],
        ),
      ),
    );
  }
}

/// "Quem é você?": filtra os chamados pelas mesas desse garçom.
Future<void> escolherGarcom(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  constraints: const BoxConstraints(maxWidth: 560),
  builder: (_) => const _EscolherGarcom(),
);

class _EscolherGarcom extends ConsumerWidget {
  const _EscolherGarcom();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final cardapio = ref.watch(cardapioProvider).value;
    final atual = ref.watch(settingsProvider.select((s) => s.garcomId));
    final garcons = cardapio?.garcons ?? const <GarcomInfo>[];

    Widget opcao(String titulo, String subtitulo, bool sel, VoidCallback onTap) => Pressable(
      onTap: () {
        onTap();
        Navigator.of(context).pop();
      },
      borderRadius: Radii.rLg,
      selected: sel,
      child: Container(
        padding: const EdgeInsets.all(Space.md),
        decoration: BoxDecoration(
          color: sel ? p.primarySoft : p.surfaceRaised,
          borderRadius: Radii.rLg,
          border: Border.all(color: sel ? p.primary : p.outline, width: sel ? 2 : 1),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: context.text.titleMedium),
                  Text(subtitulo, style: context.text.bodySmall),
                ],
              ),
            ),
            if (sel) Icon(LucideIcons.circleCheck, color: p.primary),
          ],
        ),
      ),
    );

    String mesasDe(int id) {
      final ns = [
        for (final m in cardapio?.mesas ?? const [])
          if (m.garcomId == id) m.numero,
      ];
      if (ns.isEmpty) return 'Sem mesas atribuídas';
      return ns.length <= 6 ? 'Mesas ${ns.join(', ')}' : '${ns.length} mesas (${ns.first} a ${ns.last})';
    }

    final n = ref.read(settingsProvider.notifier);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Quem usa este celular?', style: context.text.headlineSmall),
            const SizedBox(height: Space.xxs),
            Text('Você recebe os chamados das suas mesas.', style: context.text.bodyMedium),
            const SizedBox(height: Space.md),
            for (final g in garcons) ...[
              opcao(g.nome, mesasDe(g.id), atual == g.id, () => n.setGarcom(g.id)),
              const SizedBox(height: Space.xs),
            ],
            opcao('Todos os chamados', 'Para o gerente ou o caixa', atual == null, () => n.setGarcom(null)),
          ],
        ),
      ),
    );
  }
}
