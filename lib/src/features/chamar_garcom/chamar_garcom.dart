import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/pressable.dart';
import '../../data/models/chamado.dart';
import '../../state/providers.dart';
import '../../state/settings.dart';

/// Ícone de cada motivo (mesmas chaves do ERP: ICONES_CHAMADO).
IconData iconeChamado(String chave) => switch (chave) {
  'conta' => LucideIcons.receiptText,
  'ajuda' => LucideIcons.circleQuestionMark,
  'talheres' => LucideIcons.utensilsCrossed,
  'agua' => LucideIcons.glassWater,
  'limpeza' => LucideIcons.sparkles,
  'cardapio' => LucideIcons.bookOpen,
  'pagamento' => LucideIcons.creditCard,
  _ => LucideIcons.bellRing,
};

/// Mesa deste tablet (fixa) ou a escolhida pelo cliente nesta visita.
int? mesaAtual(WidgetRef ref) => ref.watch(sessaoProvider.select((s) => s.mesa));

/// Sino no topo do tablet da mesa. Só aparece no modo totem e se o ERP ligou o recurso.
class ChamarGarcomButton extends ConsumerWidget {
  const ChamarGarcomButton({super.key, this.compact = false, this.padding = EdgeInsets.zero});

  /// Só o ícone (barras estreitas e celular).
  final bool compact;

  /// Espaço em volta, aplicado só quando o botão aparece.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = ref.watch(cardapioProvider.select((c) => c.value?.loja.chamarGarcom));
    final totem = ref.watch(settingsProvider.select((s) => s.modo == ModoOperacao.totem));
    if (cfg == null || !cfg.disponivel || !totem) return const SizedBox.shrink();

    final p = context.palette;
    final estado = ref.watch(chamadoMesaProvider);
    final c = estado.chamado;
    final ativo = estado.emAberto;
    final rotulo = !ativo
        ? 'Chamar garçom'
        : !c!.sincronizado
        ? 'Chamado na fila'
        : c.status == StatusChamado.aCaminho
        ? '${c.quemVem ?? 'Garçom'} a caminho'
        : 'Garçom chamado';

    Widget sino = Icon(
      ativo ? LucideIcons.bellRing : LucideIcons.bell,
      size: 20,
      color: ativo ? p.onPrimary : p.accent,
    );
    if (ativo) {
      sino = sino.maybeAnimate(
        context,
        (a) => a.rotate(begin: -0.045, end: 0.045, duration: 260.ms, curve: Curves.easeInOut),
        onPlayRepeat: true,
      );
    }

    return Padding(
      padding: padding,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (ativo && c!.sincronizado && c.status.emAberto) _Acompanhar(codigo: c.codigo),
          Pressable(
            onTap: () => abrirChamarGarcom(context),
            borderRadius: Radii.rPill,
            semanticLabel: ativo ? '$rotulo. Toque para ver ou cancelar' : 'Chamar o garçom',
            child: AnimatedContainer(
              duration: Motion.base,
              height: 48,
              constraints: const BoxConstraints(minWidth: 48),
              padding: EdgeInsets.symmetric(horizontal: compact ? 0 : Space.md),
              decoration: BoxDecoration(
                color: ativo ? p.primary : p.surfaceRaised,
                borderRadius: Radii.rPill,
                border: Border.all(color: ativo ? p.primary : p.outline),
                boxShadow: ativo
                    ? [BoxShadow(color: p.primary.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 6))]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (compact) SizedBox(width: 46, child: Center(child: sino)) else sino,
                  if (!compact) ...[
                    const SizedBox(width: Space.xs),
                    Text(rotulo, style: context.text.labelLarge?.copyWith(color: ativo ? p.onPrimary : p.textPrimary)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mantém o status do chamado em dia enquanto o sino está na tela.
class _Acompanhar extends ConsumerWidget {
  const _Acompanhar({required this.codigo});

  final String codigo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(chamadoAoVivoProvider(codigo), (_, proximo) {
      final c = proximo.value;
      if (c != null) ref.read(chamadoMesaProvider.notifier).atualizar(c);
    });
    return const SizedBox.shrink();
  }
}

/// Abre o "Como podemos ajudar?": painel no tablet, folha de baixo no celular.
Future<void> abrirChamarGarcom(BuildContext context) {
  HapticFeedback.selectionClick();
  if (context.isCompact) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const SafeArea(child: _PainelChamado()),
    );
  }
  return showDialog<void>(
    context: context,
    barrierColor: context.palette.scrim,
    builder: (ctx) => Dialog(
      backgroundColor: ctx.palette.surface,
      shape: RoundedRectangleBorder(borderRadius: Radii.rXl),
      insetPadding: const EdgeInsets.all(Space.lg),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 620), child: const _PainelChamado()),
    ),
  );
}

class _PainelChamado extends ConsumerStatefulWidget {
  const _PainelChamado();

  @override
  ConsumerState<_PainelChamado> createState() => _PainelChamadoState();
}

class _PainelChamadoState extends ConsumerState<_PainelChamado> {
  Timer? _relogio;
  Timer? _fechar;
  int? _mesaEscolhida;

  @override
  void initState() {
    super.initState();
    // Contagem do intervalo entre chamados.
    _relogio = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _relogio?.cancel();
    _fechar?.cancel();
    super.dispose();
  }

  Future<void> _chamar(MotivoChamado motivo, int mesa) async {
    HapticFeedback.mediumImpact();
    ref.read(sessaoProvider.notifier).setMesa(mesa);
    await ref.read(chamadoMesaProvider.notifier).chamar(motivo, mesa);
    if (!mounted) return;
    final estado = ref.read(chamadoMesaProvider);
    if (estado.erro == null) {
      // Confirmação fica alguns segundos e o painel fecha sozinho.
      _fechar = Timer(const Duration(seconds: 6), () {
        if (mounted) Navigator.of(context).maybePop();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final cardapio = ref.watch(cardapioProvider).value;
    final estado = ref.watch(chamadoMesaProvider);
    if (cardapio == null) return const SizedBox.shrink();
    final cfg = cardapio.loja.chamarGarcom;
    final mesa = mesaAtual(ref) ?? _mesaEscolhida;
    final agora = DateTime.now();

    final Widget conteudo;
    if (estado.emAberto) {
      conteudo = _Confirmacao(estado: estado, onCancelar: () => ref.read(chamadoMesaProvider.notifier).cancelar());
    } else if (mesa == null) {
      conteudo = _EscolherMesa(numeros: cardapio.numerosMesas, onEscolher: (m) => setState(() => _mesaEscolhida = m));
    } else {
      final espera = estado.liberado(agora) ? 0 : estado.liberadoEm!.difference(agora).inSeconds + 1;
      final garcom = cardapio.mesa(mesa)?.garcomNome;
      conteudo = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Eyebrow(garcom == null ? 'Mesa $mesa' : 'Mesa $mesa · $garcom atende você'),
          const SizedBox(height: Space.xxs),
          Text('Como podemos ajudar?', style: context.text.headlineMedium),
          if (estado.erro != null) ...[
            const SizedBox(height: Space.sm),
            Text(estado.erro!, style: context.text.bodyMedium?.copyWith(color: p.danger)),
          ],
          if (espera > 0) ...[
            const SizedBox(height: Space.sm),
            Text('Você pode chamar de novo em $espera s', style: context.text.bodyMedium),
          ],
          const SizedBox(height: Space.lg),
          LayoutBuilder(
            builder: (context, c) {
              final colunas = c.maxWidth >= 440 ? 2 : 1;
              final largura = (c.maxWidth - Space.sm * (colunas - 1)) / colunas;
              return Wrap(
                spacing: Space.sm,
                runSpacing: Space.sm,
                children: [
                  for (final (i, m) in cfg.motivos.indexed)
                    SizedBox(
                      width: largura,
                      child: _MotivoCard(
                        motivo: m,
                        enviando: estado.enviando,
                        onTap: espera > 0 || estado.enviando ? null : () => _chamar(m, mesa),
                      ).entrance(context, index: i, stepMs: 40),
                    ),
                ],
              );
            },
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, Space.lg),
      child: AnimatedSize(duration: Motion.base, curve: Motion.emphasized, child: conteudo),
    );
  }
}

class _MotivoCard extends StatelessWidget {
  const _MotivoCard({required this.motivo, required this.onTap, required this.enviando});

  final MotivoChamado motivo;
  final VoidCallback? onTap;
  final bool enviando;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final ativo = onTap != null;
    return Pressable(
      onTap: onTap,
      borderRadius: Radii.rLg,
      semanticLabel: motivo.rotulo,
      child: AnimatedOpacity(
        duration: Motion.fast,
        opacity: ativo || enviando ? 1 : 0.5,
        child: Container(
          height: 76,
          padding: const EdgeInsets.symmetric(horizontal: Space.md),
          decoration: BoxDecoration(
            color: p.surfaceRaised,
            borderRadius: Radii.rLg,
            border: Border.all(color: p.outline),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: p.primarySoft, borderRadius: Radii.rMd),
                child: Icon(iconeChamado(motivo.icone), color: p.accent, size: 22),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Text(
                  motivo.rotulo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleMedium,
                ),
              ),
              Icon(LucideIcons.chevronRight, color: p.textMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _EscolherMesa extends StatelessWidget {
  const _EscolherMesa({required this.numeros, required this.onEscolher});

  final List<int> numeros;
  final ValueChanged<int> onEscolher;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('Chamar garçom'),
        const SizedBox(height: Space.xxs),
        Text('Em qual mesa você está?', style: context.text.headlineMedium),
        const SizedBox(height: Space.lg),
        Wrap(
          spacing: Space.xs,
          runSpacing: Space.xs,
          children: [
            for (final n in numeros)
              Pressable(
                onTap: () => onEscolher(n),
                borderRadius: Radii.rMd,
                semanticLabel: 'Mesa $n',
                scale: 0.92,
                child: Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: p.surfaceRaised,
                    borderRadius: Radii.rMd,
                    border: Border.all(color: p.outline),
                  ),
                  child: Text('$n', style: context.text.titleLarge),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// "Chamamos a Carla!" com o status ao vivo.
class _Confirmacao extends StatelessWidget {
  const _Confirmacao({required this.estado, required this.onCancelar});

  final ChamadoMesaState estado;
  final VoidCallback onCancelar;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = estado.chamado!;
    final quem = c.quemVem;
    final (titulo, texto) = !c.sincronizado
        ? (
            'Chamado guardado',
            'A internet oscilou: avisamos assim que a conexão voltar. Se for urgente, acene para um atendente.',
          )
        : c.status == StatusChamado.aCaminho
        ? ('${quem ?? 'Um atendente'} está a caminho', 'Já já chega na mesa ${c.mesa}.')
        : (quem == null ? 'Chamamos a equipe!' : 'Chamamos $quem!', 'Alguém vem até a mesa ${c.mesa} em instantes.');

    Widget sino = Icon(LucideIcons.bellRing, size: 40, color: c.sincronizado ? p.accent : p.warning);
    sino = sino.maybeAnimate(
      context,
      (a) => a.rotate(begin: -0.06, end: 0.06, duration: 300.ms, curve: Curves.easeInOut),
      onPlayRepeat: true,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: (c.sincronizado ? p.accent : p.warning).withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Center(child: sino),
        ),
        const SizedBox(height: Space.md),
        Text(titulo, textAlign: TextAlign.center, style: context.text.headlineMedium),
        const SizedBox(height: Space.xs),
        Text(texto, textAlign: TextAlign.center, style: context.text.bodyLarge),
        const SizedBox(height: Space.md),
        StatusPill(
          label: '${c.motivoRotulo} · ${c.sincronizado ? c.status.rotulo : 'na fila'}',
          color: c.status == StatusChamado.aCaminho ? p.success : (c.sincronizado ? p.accent : p.warning),
          pulse: true,
        ),
        const SizedBox(height: Space.lg),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Cancelar chamado',
                icon: LucideIcons.bellOff,
                tone: ButtonTone.secondary,
                height: 52,
                onPressed: () {
                  onCancelar();
                  Navigator.of(context).maybePop();
                },
              ),
            ),
            const SizedBox(width: Space.sm),
            Expanded(
              child: AppButton(label: 'Ok', height: 52, onPressed: () => Navigator.of(context).maybePop()),
            ),
          ],
        ),
      ],
    );
  }
}
