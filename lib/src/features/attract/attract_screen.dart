import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/brand/forven_brand.dart';
import '../../core/navigation.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/app_image.dart';
import '../chamar_garcom/chamar_garcom.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/pressable.dart';
import '../../data/models/cardapio.dart';
import '../../data/models/loja.dart';
import '../../state/providers.dart';
import '../menu/menu_screen.dart';
import '../settings/settings_screen.dart';

/// Abre o cardápio com nome de rota fixo (o checkout volta até aqui).
Future<void> abrirCardapio(BuildContext context) => Navigator.of(context).push<void>(
  AppPageRoute<void>(
    builder: (_) => const MenuScreen(),
    settings: const RouteSettings(name: 'menu'),
  ),
);

/// Tela de descanso do totem: convida o cliente a começar.
/// Sempre em fundo escuro (como o hero do forven.com.br), nas cores do tema do ERP.
class AttractScreen extends ConsumerWidget {
  const AttractScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardapio = ref.watch(cardapioProvider);
    final aparencia = ref.watch(aparenciaProvider);
    return Theme(
      data: buildTheme(Brightness.dark, aparencia: aparencia, sempreEscuro: true),
      child: Builder(
        builder: (context) => Scaffold(
          backgroundColor: context.palette.vitrineProfunda,
          body: switch (cardapio) {
            AsyncData(:final value) => _Attract(cardapio: value),
            AsyncError(:final error) => Stack(
              children: [
                ErrorView(message: error.toString(), onRetry: () => ref.invalidate(cardapioProvider)),
                Positioned(
                  right: Space.lg,
                  top: Space.lg,
                  child: SafeArea(
                    child: RoundIconButton(
                      icon: LucideIcons.settings,
                      label: 'Configurações',
                      onPressed: () => abrirConfiguracoes(context, ref),
                    ),
                  ),
                ),
              ],
            ),
            _ => const ForvenLoader(mensagem: 'Preparando o cardápio…'),
          },
        ),
      ),
    );
  }
}

/// Carregamento com a marca: o símbolo se desenha em contorno e se preenche.
class ForvenLoader extends StatefulWidget {
  const ForvenLoader({super.key, required this.mensagem});

  final String mensagem;

  @override
  State<ForvenLoader> createState() => _ForvenLoaderState();
}

class _ForvenLoaderState extends State<ForvenLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.enabled(context)) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return BrandBackdrop(
      lineColor: p.brandLine,
      glowColor: p.glow,
      drawIn: false,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 120,
              height: 90,
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  final t = _c.value;
                  final traco = Curves.easeInOutCubic.transform((t / 0.6).clamp(0, 1));
                  final fill =
                      Curves.easeOut.transform(((t - 0.55) / 0.3).clamp(0, 1)) *
                      (t > 0.92 ? (1 - (t - 0.92) / 0.08) : 1);
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      CustomPaint(
                        painter: SymbolOutlinePainter(
                          color: p.destaqueVitrine,
                          progress: traco,
                          strokeWidth: 2,
                          layout: SymbolLayout.centered,
                        ),
                      ),
                      Opacity(
                        opacity: fill.clamp(0, 1),
                        child: Center(
                          child: ForvenLogo(kind: ForvenLogoKind.symbol, height: 82, color: p.logo),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: Space.lg),
            Text(widget.mensagem, style: context.text.titleMedium),
          ],
        ),
      ),
    );
  }
}

class _Attract extends ConsumerStatefulWidget {
  const _Attract({required this.cardapio});

  final Cardapio cardapio;

  @override
  ConsumerState<_Attract> createState() => _AttractState();
}

class _AttractState extends ConsumerState<_Attract> {
  int _index = 0;
  Timer? _timer;

  /// Slides da tela de descanso; sem slides cadastrados, usa as fotos dos destaques.
  List<String?> get _imagens {
    final c = widget.cardapio;
    final slides = [...c.loja.imagensDestaque, ?c.loja.capaUrl];
    if (slides.isNotEmpty) return slides;
    final fotos = {
      for (final p in [...c.destaques, ...c.produtos]) ?p.imagemUrl,
    }.take(6).toList();
    return fotos.isEmpty ? const [null] : fotos;
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 7), (_) {
      if (mounted) setState(() => _index++);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Pré-carrega as fotos do slideshow para trocas sem "piscar".
    if (appImageDisableNetwork) return;
    for (final url in _imagens.nonNulls) {
      precacheImage(CachedNetworkImageProvider(sizedImage(url, 1600), cacheManager: cacheImagens), context).ignore();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _comecar([TipoConsumo? consumo]) {
    if (consumo != null) ref.read(sessaoProvider.notifier).setConsumo(consumo);
    abrirCardapio(context);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final loja = widget.cardapio.loja;
    final now = ref.watch(nowProvider);
    final aberto = loja.abertoEm(now);
    final mesa = ref.watch(sessaoProvider.select((s) => s.mesa));
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 900 && size.width > size.height;
    final compact = context.isCompact;
    final destaques = widget.cardapio.destaques;
    final img = _imagens[_index % _imagens.length];

    final titulo = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Eyebrow('${greeting(now)}${mesa != null ? ' · Mesa $mesa' : ''}').entrance(context, index: 1),
        const SizedBox(height: Space.sm),
        HighlightText(
          'Bem-vindo ao\n*${loja.nome}*',
          highlight: p.destaqueVitrine,
          style: (compact ? context.text.displayMedium : context.text.displayLarge)?.copyWith(color: Colors.white),
        ).entrance(context, index: 2),
        const SizedBox(height: Space.md),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Text(loja.mensagemBoasVindas, style: context.text.bodyLarge?.copyWith(fontSize: compact ? 16 : 18.5)),
        ).entrance(context, index: 3),
      ],
    );

    final escolhas = loja.modosConsumo.length > 1 && mesa == null
        ? Wrap(
            spacing: Space.md,
            runSpacing: Space.md,
            children: [
              for (final (i, m) in loja.modosConsumo.indexed)
                _Choice(
                  icon: m == TipoConsumo.local ? LucideIcons.utensils : LucideIcons.handbag,
                  title: m.rotulo,
                  subtitle: m == TipoConsumo.local ? 'Servimos na sua mesa' : 'Embalamos para viagem',
                  onTap: () => _comecar(m),
                ).entrance(context, index: 4 + i),
            ],
          )
        : SizedBox(
            width: 360,
            child: AppButton(
              label: 'Começar meu pedido',
              icon: LucideIcons.arrowRight,
              height: 64,
              onPressed: () => _comecar(mesa != null ? TipoConsumo.local : null),
            ),
          ).entrance(context, index: 4);

    final janela = _PhotoWindow(
      url: img,
      index: _index,
      total: _imagens.length,
      destaque: destaques.isEmpty ? null : destaques[_index % destaques.length],
    );

    final topo = Row(
      children: [
        Flexible(
          child: Pressable(
            onLongPress: () => abrirConfiguracoes(context, ref),
            haptic: false,
            semanticLabel: loja.nome,
            child: BrandMark(nome: loja.nome, light: true, size: compact ? 40 : 48, logoUrl: loja.logoUrl),
          ),
        ),
        const SizedBox(width: Space.sm),
        StatusPill(
          label: compact ? (aberto ? 'Aberto' : 'Fechado') : loja.statusRotulo(now),
          color: aberto ? p.success : p.danger,
          pulse: aberto,
          onImage: true,
        ),
        const Spacer(),
        ChamarGarcomButton(compact: !wide),
      ],
    ).entrance(context);

    final rodape = Row(
      children: [
        Icon(LucideIcons.pointer, color: p.destaqueVitrine, size: 22).maybeAnimate(
          context,
          (a) => a.moveY(begin: 0, end: -5, duration: 800.ms, curve: Curves.easeInOut),
          onPlayRepeat: true,
        ),
        const SizedBox(width: Space.sm),
        Expanded(
          child: Text(
            compact ? 'Toque para começar' : 'Toque em qualquer lugar para começar',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelLarge?.copyWith(color: p.textSecondary),
          ),
        ),
        const SizedBox(width: Space.md),
        Opacity(
          opacity: 0.9,
          child: ForvenLogo(height: compact ? 15 : 18, color: Colors.white, badge: 'Cardápio'),
        ),
      ],
    ).maybeAnimate(context, (a) => a.fadeIn(delay: 700.ms, duration: 500.ms));

    final Widget corpo;
    if (wide) {
      corpo = Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 11,
            child: Align(
              alignment: Alignment.centerLeft,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titulo,
                    const SizedBox(height: Space.xxl),
                    escolhas,
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: Space.xxl),
          Expanded(
            flex: 10,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.lg),
              child: janela,
            ),
          ),
        ],
      );
    } else {
      corpo = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: Space.lg),
          Expanded(flex: compact ? 7 : 10, child: janela),
          SizedBox(height: compact ? Space.lg : Space.xl),
          Expanded(
            flex: compact ? 12 : 9,
            child: Align(
              alignment: Alignment.topLeft,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titulo,
                    SizedBox(height: compact ? Space.lg : Space.xl),
                    escolhas,
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _comecar(mesa != null ? TipoConsumo.local : null),
      child: BrandBackdrop(
        lineColor: p.brandLine,
        glowColor: p.glow,
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? Space.lg : Space.xxl,
              compact ? Space.md : Space.xl,
              compact ? Space.lg : Space.xxl,
              compact ? Space.md : Space.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                topo,
                Expanded(child: corpo),
                SizedBox(height: compact ? Space.md : Space.lg),
                rodape,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Janela" de fotos com cantos generosos (como os cards do site), Ken Burns
/// e um card flutuante com um destaque da casa.
class _PhotoWindow extends StatelessWidget {
  const _PhotoWindow({required this.url, required this.index, required this.total, required this.destaque});

  final String? url;
  final int index;
  final int total;
  final Produto? destaque;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final anim = Motion.enabled(context);
    final compact = context.isCompact;
    final radius = BorderRadius.circular(compact ? Radii.xl : 36);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(color: p.primary.withValues(alpha: 0.35), blurRadius: 80, spreadRadius: -10),
          BoxShadow(color: p.shadow, blurRadius: 40, offset: const Offset(0, 24)),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 1400),
              layoutBuilder: (current, previous) => Stack(fit: StackFit.expand, children: [...previous, ?current]),
              child: TweenAnimationBuilder<double>(
                key: ValueKey(index),
                tween: Tween(begin: 1.0, end: anim ? 1.12 : 1.0),
                duration: const Duration(seconds: 9),
                builder: (_, s, child) => Transform.scale(
                  scale: s,
                  alignment: index.isEven ? Alignment.topLeft : Alignment.bottomRight,
                  child: child,
                ),
                child: AppImage(url, width: 1400),
              ),
            ),
            // Vinheta marinho para integrar a foto ao fundo da marca.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.45, 1],
                  colors: [Colors.transparent, context.palette.vitrineProfunda.withValues(alpha: 0.85)],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
            ),
            if (destaque != null)
              Positioned(
                left: compact ? Space.md : Space.lg,
                right: compact ? Space.md : null,
                bottom: compact ? Space.md : Space.lg,
                child: AnimatedSwitcher(
                  duration: Motion.slow,
                  switchInCurve: Motion.enter,
                  transitionBuilder: (c, a) => FadeTransition(
                    opacity: a,
                    child: SlideTransition(
                      position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(a),
                      child: c,
                    ),
                  ),
                  child: _DestaqueCard(key: ValueKey(destaque!.id), produto: destaque!),
                ),
              ),
            Positioned(
              right: compact ? Space.md : Space.lg,
              top: compact ? Space.md : Space.lg,
              child: Row(
                children: [
                  for (var i = 0; i < total; i++)
                    AnimatedContainer(
                      duration: Motion.slow,
                      margin: const EdgeInsets.only(left: 6),
                      width: i == index % total ? 24 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: i == index % total ? Colors.white : Colors.white.withValues(alpha: 0.4),
                        borderRadius: Radii.rPill,
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

class _DestaqueCard extends StatelessWidget {
  const _DestaqueCard({super.key, required this.produto});

  final Produto produto;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ClipRRect(
      borderRadius: Radii.rLg,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          padding: const EdgeInsets.all(Space.sm),
          decoration: BoxDecoration(
            color: context.palette.vitrineProfunda.withValues(alpha: 0.62),
            borderRadius: Radii.rLg,
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 56, height: 56, child: AppImage(produto.imagemUrl, width: 200, borderRadius: Radii.rMd)),
              const SizedBox(width: Space.sm),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Eyebrow('Destaque da casa'),
                    const SizedBox(height: 3),
                    Text(
                      produto.nome,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleMedium?.copyWith(color: Colors.white),
                    ),
                    Text(
                      money(produto.precoAPartirDe),
                      style: context.text.labelMedium?.copyWith(color: p.destaqueVitrine),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Space.sm),
            ],
          ),
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({required this.icon, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Pressable(
      onTap: onTap,
      borderRadius: Radii.rXl,
      semanticLabel: '$title. $subtitle',
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(Space.lg - 4),
        decoration: BoxDecoration(
          color: context.palette.vitrine.withValues(alpha: 0.75),
          borderRadius: Radii.rXl,
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: p.primary,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: p.primary.withValues(alpha: 0.5), blurRadius: 22, offset: const Offset(0, 8)),
                ],
              ),
              child: Icon(icon, color: p.onPrimary, size: 28),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.text.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: context.text.bodySmall),
                ],
              ),
            ),
            Icon(LucideIcons.arrowRight, color: p.destaqueVitrine, size: 22),
          ],
        ),
      ),
    );
  }
}
