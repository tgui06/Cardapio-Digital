import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/navigation.dart';
import '../../core/brand/forven_brand.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/app_image.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/skeleton.dart';
import '../../data/models/cardapio.dart';
import '../../data/models/loja.dart';
import '../../state/providers.dart';
import '../../state/settings.dart';
import '../cart/cart_view.dart';
import '../chamar_garcom/chamar_garcom.dart';
import '../offline/offline_host.dart';
import '../orders/orders_screen.dart';
import '../settings/settings_screen.dart';
import 'widgets/category_nav.dart';
import 'widgets/destaques_banner.dart';
import 'widgets/product_cards.dart';

class MenuScreen extends ConsumerWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardapio = ref.watch(cardapioProvider);
    return switch (cardapio) {
      AsyncData(:final value) => _MenuView(cardapio: value),
      AsyncError(:final error) => Scaffold(
        body: ErrorView(message: error.toString(), onRetry: () => ref.invalidate(cardapioProvider)),
      ),
      _ => const Scaffold(body: MenuSkeleton()),
    };
  }
}

/// Confirma antes de descartar um pedido em andamento.
Future<bool> confirmarSaida(BuildContext context, WidgetRef ref) async {
  if (ref.read(cartProvider).isEmpty) return true;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(LucideIcons.shoppingBasket, color: ctx.palette.accent, size: 36),
      title: const Text('Cancelar este pedido?'),
      content: const Text('Os itens da sacola serão descartados.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Continuar pedindo')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cancelar pedido')),
      ],
    ),
  );
  return ok ?? false;
}

class _MenuView extends ConsumerStatefulWidget {
  const _MenuView({required this.cardapio});

  final Cardapio cardapio;

  @override
  ConsumerState<_MenuView> createState() => _MenuViewState();
}

class _MenuViewState extends ConsumerState<_MenuView> {
  final _scroll = ScrollController();
  final _sectionKeys = <int, GlobalKey>{};
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  int? _ativa;
  bool _programmatic = false;
  bool _searching = false;
  String _query = '';

  Cardapio get cardapio => widget.cardapio;

  late List<Categoria> _secoes;

  @override
  void initState() {
    super.initState();
    _computeSecoes();
    _ativa = _secoes.isEmpty ? null : _secoes.first.id;
    _scroll.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant _MenuView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cardapio != widget.cardapio) _computeSecoes();
  }

  void _computeSecoes() {
    _secoes = cardapio.categorias.where((c) => cardapio.produtosDa(c.id).isNotEmpty).toList();
    for (final c in _secoes) {
      _sectionKeys.putIfAbsent(c.id, GlobalKey.new);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  double get _pinnedExtent => switch (context.windowSize) {
    WindowSize.compact => MediaQuery.paddingOf(context).top + kToolbarHeight + CategoryChipsBar.height,
    WindowSize.medium => CategoryChipsBar.height,
    WindowSize.expanded => 0,
  };

  double? _offsetOf(int categoriaId) {
    final ro = _sectionKeys[categoriaId]?.currentContext?.findRenderObject();
    if (ro == null || !ro.attached) return null;
    final viewport = RenderAbstractViewport.maybeOf(ro);
    return viewport?.getOffsetToReveal(ro, 0).offset;
  }

  void _onScroll() {
    if (_programmatic || _query.isNotEmpty || _secoes.isEmpty) return;
    final linha = _scroll.offset + _pinnedExtent + 32;
    var atual = _secoes.first.id;
    for (final c in _secoes) {
      final o = _offsetOf(c.id);
      if (o != null && o <= linha) atual = c.id;
    }
    if (atual != _ativa) setState(() => _ativa = atual);
  }

  Future<void> _goTo(Categoria c) async {
    if (_query.isNotEmpty) _limparBusca();
    setState(() => _ativa = c.id);
    await WidgetsBinding.instance.endOfFrame;
    final o = _offsetOf(c.id);
    if (o == null || !_scroll.hasClients) return;
    final target = (o - _pinnedExtent - Space.xs).clamp(0.0, _scroll.position.maxScrollExtent);
    if (!mounted) return;
    _programmatic = true;
    if (Motion.enabled(context)) {
      await _scroll.animateTo(target, duration: const Duration(milliseconds: 520), curve: Motion.emphasized);
    } else {
      _scroll.jumpTo(target);
    }
    _programmatic = false;
  }

  void _abrirBusca() {
    setState(() => _searching = true);
    _searchFocus.requestFocus();
  }

  void _limparBusca() {
    _searchCtrl.clear();
    _searchFocus.unfocus();
    setState(() {
      _query = '';
      _searching = false;
    });
  }

  void _onQuery(String q) {
    setState(() => _query = q.trim());
    if (_scroll.hasClients && _scroll.offset > 0) {
      // Mantém o topo dos resultados visível.
      final topo = context.isCompact ? 300.0 - kToolbarHeight - MediaQuery.paddingOf(context).top : 0.0;
      if (_scroll.offset > topo) _scroll.jumpTo(topo.clamp(0, _scroll.position.maxScrollExtent));
    }
  }

  List<Produto> get _resultados {
    final tokens = normalize(_query).split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    return cardapio.produtos.where((p) {
      final hay = normalize(
        [p.nome, p.descricao, cardapio.categoria(p.categoriaId).nome, ...p.tags.map((t) => t.rotulo)].join(' '),
      );
      return tokens.every(hay.contains);
    }).toList();
  }

  Future<void> _sair() async {
    final nav = Navigator.of(context);
    if (await confirmarSaida(context, ref)) {
      final modo = ref.read(settingsProvider).modo;
      if (modo == ModoOperacao.totem) novoAtendimento(ref);
      ref.read(cartProvider.notifier).clear();
      if (nav.mounted) nav.pop();
    }
  }

  void _abrirSacola() => pushPage<void>(context, (_) => const CartScreen());

  @override
  Widget build(BuildContext context) {
    final size = context.windowSize;
    final scroll = _buildScroll(size);
    final cartVazio = ref.watch(cartProvider.select((c) => c.isEmpty));

    Widget body;
    if (size == WindowSize.expanded) {
      // Tablet deitado (uso na mesa): trilho de categorias | cardápio | sacola que desliza
      // só quando há itens — sem desperdiçar largura com uma sacola vazia.
      final w = MediaQuery.sizeOf(context).width;
      final dense = w < 1180;
      final cartW = w >= 1440 ? 400.0 : (w >= 1180 ? 360.0 : 320.0);
      body = Row(
        children: [
          CategoryRail(
            dense: dense,
            categorias: _secoes,
            contagem: {for (final c in _secoes) c.id: cardapio.produtosDa(c.id).length},
            ativa: _query.isEmpty ? _ativa : null,
            onSelect: _goTo,
            header: _RailHeader(cardapio: cardapio, dense: dense),
            footer: _RailFooter(onSair: _sair, dense: dense),
          ),
          Expanded(
            child: Column(
              children: [
                _TopBar(cardapio: cardapio, searchField: _searchField()),
                Expanded(child: scroll),
              ],
            ),
          ),
          _SlidingCart(open: !cartVazio, width: cartW),
        ],
      );
    } else {
      body = Stack(
        children: [
          scroll,
          Positioned(
            left: context.gutter,
            right: context.gutter,
            bottom: Space.md + MediaQuery.paddingOf(context).bottom,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: FloatingCartBar(onTap: _abrirSacola),
              ),
            ),
          ),
        ],
      );
    }

    return PopScope(
      canPop: cartVazio,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _sair();
      },
      child: Scaffold(body: body),
    );
  }

  // --------------------------------------------------------------------- scroll

  Widget _buildScroll(WindowSize size) {
    final gutter = context.gutter;
    final buscando = _query.isNotEmpty;
    final slivers = <Widget>[
      if (size == WindowSize.compact)
        _CompactHero(
          cardapio: cardapio,
          onBack: _sair,
          onOrders: () => pushPage<void>(context, (_) => const OrdersScreen()),
        )
      else if (size == WindowSize.medium)
        SliverToBoxAdapter(
          child: _WideHeader(cardapio: cardapio, onBack: _sair),
        ),
      if (size != WindowSize.expanded)
        SliverPersistentHeader(
          pinned: true,
          delegate: _PinnedBar(
            child: AnimatedSwitcher(
              duration: Motion.base,
              child: _searching
                  ? Container(
                      key: const ValueKey('busca'),
                      color: context.palette.background,
                      padding: EdgeInsets.fromLTRB(gutter, 10, gutter, 10),
                      child: _searchField(autoClose: true),
                    )
                  : CategoryChipsBar(
                      key: const ValueKey('chips'),
                      categorias: _secoes,
                      ativa: _ativa,
                      onSelect: _goTo,
                      onSearch: _abrirBusca,
                    ),
            ),
          ),
        ),
      if (buscando)
        ..._resultadosSlivers(size)
      else ...[
        if (cardapio.destaques.isNotEmpty)
          SliverToBoxAdapter(
            child: size == WindowSize.expanded
                ? Padding(
                    padding: EdgeInsets.fromLTRB(gutter, context.isShort ? Space.md : Space.lg, gutter, 0),
                    child: DestaquesBanner(produtos: cardapio.destaques).entrance(context, dy: 0.04),
                  )
                : _Destaques(produtos: cardapio.destaques),
          ),
        for (final c in _secoes) ..._secaoSlivers(c, size),
      ],
      SliverToBoxAdapter(
        child: SizedBox(height: size == WindowSize.expanded ? Space.xxl : 120 + MediaQuery.paddingOf(context).bottom),
      ),
    ];

    return CustomScrollView(
      controller: _scroll,
      // Mantém todas as seções montadas para o "scroll spy" e o salto entre categorias.
      scrollCacheExtent: const ScrollCacheExtent.pixels(40000),
      slivers: slivers,
    );
  }

  Widget _searchField({bool autoClose = false}) {
    final p = context.palette;
    return TextField(
      controller: _searchCtrl,
      focusNode: _searchFocus,
      onChanged: _onQuery,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Buscar no cardápio',
        prefixIcon: Icon(LucideIcons.search, size: 20, color: p.textMuted),
        suffixIcon: (_query.isNotEmpty || autoClose)
            ? IconButton(
                tooltip: 'Limpar busca',
                onPressed: _limparBusca,
                icon: Icon(LucideIcons.x, size: 18, color: p.textMuted),
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: Radii.rPill,
          borderSide: BorderSide(color: p.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: Radii.rPill,
          borderSide: BorderSide(color: p.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: Radii.rPill,
          borderSide: BorderSide(color: p.primary, width: 2),
        ),
      ),
    );
  }

  Widget _produtosSliver(List<Produto> produtos, WindowSize size, String origem) {
    final gutter = context.gutter;
    if (size == WindowSize.compact) {
      return SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: gutter - Space.xs),
        sliver: SliverList.separated(
          itemCount: produtos.length,
          separatorBuilder: (_, _) =>
              Divider(height: 1, indent: Space.xs, endIndent: Space.xs, color: context.palette.outline),
          itemBuilder: (context, i) => ProductTile(
            key: ValueKey('${produtos[i].id}-$origem'),
            produto: produtos[i],
            origem: origem,
          ).entrance(context, index: i, stepMs: 30),
        ),
      );
    }
    if (cardapio.loja.aparencia.lista) {
      // Layout "lista" (ERP › Aparência): foto pequena ao lado do texto, em cartões.
      return SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: gutter),
        sliver: SliverLayoutBuilder(
          builder: (context, c) {
            final cols = math.max(1, (c.crossAxisExtent / 430).floor());
            return SliverGrid.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                mainAxisExtent: 204,
                crossAxisSpacing: Space.md,
                mainAxisSpacing: Space.md,
              ),
              itemCount: produtos.length,
              itemBuilder: (context, i) => DecoratedBox(
                decoration: BoxDecoration(
                  color: context.palette.surface,
                  borderRadius: Radii.rLg,
                  border: Border.all(color: context.palette.outline),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.xs),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ProductTile(
                      key: ValueKey('${produtos[i].id}-$origem'),
                      produto: produtos[i],
                      origem: origem,
                    ),
                  ),
                ),
              ).entrance(context, index: i, stepMs: 35),
            );
          },
        ),
      );
    }
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: gutter),
      sliver: SliverLayoutBuilder(
        builder: (context, c) {
          // Colunas pela largura disponível; altura = foto + área de texto fixa.
          // No tablet deitado a foto é 16:10 para caber mais itens na altura curta da tela.
          final deitado = size == WindowSize.expanded;
          final aspect = deitado ? 16 / 10 : 4 / 3;
          final spacing = deitado ? Space.md + 2 : Space.lg - 4;
          final cols = math.max(2, (c.crossAxisExtent / (deitado ? 250 : 290)).floor());
          final cardW = (c.crossAxisExtent - spacing * (cols - 1)) / cols;
          return SliverGrid.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisExtent: cardW / aspect + (deitado ? 148 : 156),
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
            ),
            itemCount: produtos.length,
            itemBuilder: (context, i) => ProductCard(
              key: ValueKey('${produtos[i].id}-$origem'),
              produto: produtos[i],
              origem: origem,
              imageAspect: aspect,
            ).entrance(context, index: i, stepMs: 35),
          );
        },
      ),
    );
  }

  List<Widget> _secaoSlivers(Categoria c, WindowSize size) {
    final p = context.palette;
    final produtos = cardapio.produtosDa(c.id);
    final fora = !c.disponivelEm(DateTime.now());
    return [
      SliverToBoxAdapter(
        key: _sectionKeys[c.id],
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            context.gutter,
            size == WindowSize.expanded ? Space.xl : Space.xl + 4,
            context.gutter,
            size == WindowSize.expanded ? Space.sm + 2 : Space.md,
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: p.accentSoft, borderRadius: BorderRadius.circular(14)),
                child: Icon(categoryIcon(c.icone), color: p.accent, size: 24),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.nome, style: context.text.headlineMedium),
                    if (c.descricao.isNotEmpty || fora)
                      Text(
                        fora ? 'Disponível ${c.janela!.rotulo}' : c.descricao,
                        style: context.text.bodyMedium?.copyWith(color: fora ? p.warning : null),
                      ),
                  ],
                ),
              ),
              Text(itensLabel(produtos.length), style: context.text.bodySmall),
            ],
          ),
        ),
      ),
      _produtosSliver(produtos, size, 'cat-${c.id}'),
    ];
  }

  List<Widget> _resultadosSlivers(WindowSize size) {
    final r = _resultados;
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(context.gutter, Space.lg, context.gutter, Space.md),
          child: Text(
            r.isEmpty ? 'Nada encontrado' : '${plural(r.length, 'resultado', 'resultados')} para “$_query”',
            style: context.text.headlineSmall,
          ),
        ),
      ),
      if (r.isEmpty)
        const SliverToBoxAdapter(
          child: EmptyState(
            icon: LucideIcons.search,
            title: 'Hmm, não achamos isso',
            message: 'Tente outro nome, um ingrediente ("chocolate") ou uma característica ("vegano").',
          ),
        )
      else
        _produtosSliver(r, size, 'busca'),
    ];
  }
}

// ============================================================================ cabeçalhos

class _PinnedBar extends SliverPersistentHeaderDelegate {
  _PinnedBar({required this.child});

  final Widget child;

  @override
  double get minExtent => CategoryChipsBar.height;

  @override
  double get maxExtent => CategoryChipsBar.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => child;

  @override
  bool shouldRebuild(covariant _PinnedBar oldDelegate) => true;
}

class _CompactHero extends ConsumerWidget {
  const _CompactHero({required this.cardapio, required this.onBack, required this.onOrders});

  final Cardapio cardapio;
  final VoidCallback onBack;
  final VoidCallback onOrders;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final loja = cardapio.loja;
    final now = ref.watch(nowProvider);
    final aberto = loja.abertoEm(now);
    final sessao = ref.watch(sessaoProvider);
    final pedidos = ref.watch(meusPedidosProvider).length;
    final top = MediaQuery.paddingOf(context).top;
    const expanded = 300.0;

    return SliverAppBar(
      pinned: true,
      expandedHeight: expanded,
      backgroundColor: p.background,
      automaticallyImplyLeading: false,
      leadingWidth: 64,
      leading: Padding(
        padding: const EdgeInsets.all(4),
        child: RoundIconButton(
          icon: LucideIcons.arrowLeft,
          label: 'Sair do cardápio',
          onImage: true,
          onPressed: onBack,
        ),
      ),
      actions: [
        const SyncIndicator(compact: true, padding: EdgeInsets.only(right: Space.xs)),
        const ChamarGarcomButton(compact: true, padding: EdgeInsets.only(right: Space.xs)),
        RoundIconButton(
          icon: LucideIcons.receipt,
          label: 'Meus pedidos',
          onImage: true,
          badge: pedidos,
          onPressed: onOrders,
        ),
        const SizedBox(width: Space.sm),
      ],
      flexibleSpace: LayoutBuilder(
        builder: (context, c) {
          final min = top + kToolbarHeight;
          final t = ((c.maxHeight - min) / (expanded - min)).clamp(0.0, 1.0);
          return Stack(
            fit: StackFit.expand,
            children: [
              Opacity(
                opacity: t,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AppImage(loja.capaUrl, width: 1000),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0, 0.35, 1],
                          colors: [
                            p.imageOverlay.withValues(alpha: 0.55),
                            p.imageOverlay.withValues(alpha: 0.25),
                            p.imageOverlay.withValues(alpha: 0.95),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: Space.md,
                right: Space.md,
                bottom: Space.lg,
                child: Opacity(
                  opacity: Curves.easeIn.transform(t),
                  child: Transform.translate(
                    offset: Offset(0, 16 * (1 - t)),
                    child: Pressable(
                      onLongPress: () => abrirConfiguracoes(context, ref),
                      haptic: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          BrandMark(nome: loja.nome, size: 40, light: true),
                          const SizedBox(height: Space.sm),
                          Text(
                            loja.slogan,
                            style: context.text.bodyLarge?.copyWith(color: Colors.white.withValues(alpha: 0.85)),
                          ),
                          const SizedBox(height: Space.sm),
                          Wrap(
                            spacing: Space.xs,
                            runSpacing: Space.xs,
                            children: [
                              StatusPill(
                                label: loja.statusRotulo(now),
                                color: aberto ? const Color(0xFF74D3A0) : const Color(0xFFF2897A),
                                pulse: aberto,
                                onImage: true,
                              ),
                              if (sessao.mesa != null)
                                StatusPill(
                                  label: 'Mesa ${sessao.mesa}',
                                  color: Colors.white,
                                  icon: LucideIcons.armchair,
                                  onImage: true,
                                ),
                              if (sessao.consumo != null)
                                StatusPill(
                                  label: sessao.consumo!.rotulo,
                                  color: Colors.white,
                                  icon: sessao.consumo == TipoConsumo.local
                                      ? LucideIcons.utensils
                                      : LucideIcons.handbag,
                                  onImage: true,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Título quando recolhido.
              Positioned(
                left: 72,
                right: 72,
                top: top,
                height: kToolbarHeight,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: (1 - t * 2.5).clamp(0.0, 1.0),
                    child: Center(
                      child: Text(
                        loja.nome,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.titleMedium,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _WideHeader extends ConsumerWidget {
  const _WideHeader({required this.cardapio, this.onBack});

  final Cardapio cardapio;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final now = ref.watch(nowProvider);
    final loja = cardapio.loja;
    final aberto = loja.abertoEm(now);
    final sessao = ref.watch(sessaoProvider);
    final pedidos = ref.watch(meusPedidosProvider).length;
    final contexto = [
      greeting(now),
      if (sessao.mesa != null) 'Mesa ${sessao.mesa}',
      if (sessao.consumo != null) sessao.consumo!.rotulo,
    ].join(' · ');

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(context.gutter, Space.lg, context.gutter, Space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (onBack != null) ...[
                  RoundIconButton(icon: LucideIcons.arrowLeft, label: 'Sair do cardápio', onPressed: onBack),
                  const SizedBox(width: Space.md),
                ],
                Expanded(child: Eyebrow(contexto)),
                const SyncIndicator(padding: EdgeInsets.only(right: Space.sm)),
                const ChamarGarcomButton(padding: EdgeInsets.only(right: Space.sm)),
                StatusPill(label: loja.statusRotulo(now), color: aberto ? p.success : p.danger, pulse: aberto),
                if (onBack != null) ...[
                  const SizedBox(width: Space.sm),
                  RoundIconButton(
                    icon: LucideIcons.receipt,
                    label: 'Meus pedidos',
                    badge: pedidos,
                    onPressed: () => pushPage<void>(context, (_) => const OrdersScreen()),
                  ),
                ],
              ],
            ),
            const SizedBox(height: Space.xs),
            HighlightText('O que vai ser *hoje?*', highlight: p.accent, style: context.text.displaySmall),
          ],
        ),
      ),
    );
  }
}

/// Cabeçalho fixo do cardápio no tablet deitado: mesa, saudação, título, busca e pedidos
/// numa única faixa — a altura da tela fica para os produtos.
class _TopBar extends ConsumerWidget {
  const _TopBar({required this.cardapio, required this.searchField});

  final Cardapio cardapio;
  final Widget searchField;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final now = ref.watch(nowProvider);
    final sessao = ref.watch(sessaoProvider);
    final pedidos = ref.watch(meusPedidosProvider).length;
    final short = context.isShort;

    return Container(
      decoration: BoxDecoration(
        color: p.background,
        border: Border(bottom: BorderSide(color: p.outline)),
      ),
      child: SafeArea(
        bottom: false,
        left: false,
        right: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            context.gutter,
            short ? Space.sm + 2 : Space.lg - 4,
            context.gutter,
            short ? Space.sm + 2 : Space.md,
          ),
          child: LayoutBuilder(
            builder: (context, c) {
              // Com a sacola aberta sobra menos largura: título numa linha só (encolhe),
              // saudação some e "Pedidos" vira só ícone. Nada quebra de linha.
              final estreito = c.maxWidth < 760;
              // Tablet de 7–8" deitado: o sino fica só com o ícone para o título caber.
              final apertado = c.maxWidth < 900;
              return Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            if (sessao.mesa != null)
                              Flexible(
                                child: _ContextChip(icon: LucideIcons.armchair, label: 'Mesa ${sessao.mesa}'),
                              )
                            else if (sessao.consumo != null)
                              Flexible(
                                child: _ContextChip(
                                  icon: sessao.consumo == TipoConsumo.local
                                      ? LucideIcons.utensils
                                      : LucideIcons.handbag,
                                  label: sessao.consumo!.rotulo,
                                ),
                              ),
                            if (!estreito) ...[
                              if (sessao.mesa != null || sessao.consumo != null) const SizedBox(width: Space.sm),
                              Flexible(child: Eyebrow(greeting(now), color: p.textMuted)),
                            ],
                          ],
                        ),
                        SizedBox(height: short ? 4 : 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: HighlightText(
                            'O que vai ser *hoje?*',
                            highlight: p.accent,
                            style: short || estreito ? context.text.headlineMedium : context.text.headlineLarge,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Space.md),
                  SizedBox(width: estreito ? 210 : 340, child: searchField),
                  const SizedBox(width: Space.sm),
                  SyncIndicator(
                    compact: estreito,
                    padding: const EdgeInsets.only(right: Space.sm),
                  ),
                  ChamarGarcomButton(
                    compact: apertado,
                    padding: const EdgeInsets.only(right: Space.sm),
                  ),
                  _PedidosButton(count: pedidos, iconOnly: estreito),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ContextChip extends StatelessWidget {
  const _ContextChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: p.primarySoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: p.primary.withValues(alpha: 0.55), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: p.accent),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelSmall?.copyWith(color: p.accent, fontWeight: FontWeight.w800, letterSpacing: 1),
            ),
          ),
        ],
      ),
    );
  }
}

class _PedidosButton extends StatelessWidget {
  const _PedidosButton({required this.count, this.iconOnly = false});

  final int count;
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Pressable(
      onTap: () => pushPage<void>(context, (_) => const OrdersScreen()),
      borderRadius: Radii.rPill,
      semanticLabel: count > 0 ? 'Meus pedidos, $count' : 'Meus pedidos',
      child: Container(
        height: 50,
        padding: EdgeInsets.symmetric(horizontal: iconOnly ? 13 : Space.md),
        decoration: BoxDecoration(
          color: p.surfaceRaised,
          borderRadius: Radii.rPill,
          border: Border.all(color: p.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.receipt, size: 20, color: p.textPrimary),
            if (!iconOnly) ...[const SizedBox(width: Space.xs), Text('Pedidos', style: context.text.labelLarge)],
            if (count > 0) ...[const SizedBox(width: Space.xs), CountBadge(count: count)],
          ],
        ),
      ),
    );
  }
}

/// Topo do trilho: marca da loja + status de funcionamento. Segurar abre as configurações.
class _RailHeader extends ConsumerWidget {
  const _RailHeader({required this.cardapio, required this.dense});

  final Cardapio cardapio;
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final loja = cardapio.loja;
    final now = ref.watch(nowProvider);
    final aberto = loja.abertoEm(now);
    final mark = BrandMark(nome: loja.nome, size: dense ? 48 : 44, showName: false, logoUrl: loja.logoUrl);
    final dot = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: aberto ? p.success : p.danger, shape: BoxShape.circle),
    );

    return Pressable(
      onLongPress: () => abrirConfiguracoes(context, ref),
      borderRadius: Radii.rMd,
      haptic: false,
      semanticLabel: loja.nome,
      child: dense
          ? Column(
              children: [
                mark,
                const SizedBox(height: Space.xs),
                dot,
              ],
            )
          : Row(
              children: [
                mark,
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loja.nome,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700, height: 1.2),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          dot,
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              loja.statusRotulo(now),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.bodySmall?.copyWith(fontSize: 12.5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _RailFooter extends ConsumerWidget {
  const _RailFooter({required this.onSair, required this.dense});

  final VoidCallback onSair;
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final totem = ref.watch(settingsProvider.select((s) => s.modo == ModoOperacao.totem));
    final sair = RoundIconButton(
      icon: totem ? LucideIcons.rotateCcw : LucideIcons.arrowLeft,
      label: totem ? 'Recomeçar' : 'Voltar às mesas',
      size: 44,
      onPressed: onSair,
    );
    if (dense) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          sair,
          const SizedBox(height: Space.sm),
          Opacity(
            opacity: 0.6,
            child: ForvenLogo(kind: ForvenLogoKind.symbol, height: 14, color: p.logo),
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: Opacity(
            opacity: 0.65,
            child: Align(
              alignment: Alignment.centerLeft,
              child: ForvenLogo(height: 14, color: p.logo, badge: 'Cardápio'),
            ),
          ),
        ),
        sair,
      ],
    );
  }
}

/// Sacola lateral que entra deslizando quando o primeiro item é adicionado.
class _SlidingCart extends StatelessWidget {
  const _SlidingCart({required this.open, required this.width});

  final bool open;
  final double width;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: open ? 1 : 0),
      duration: Motion.enabled(context) ? const Duration(milliseconds: 520) : Duration.zero,
      curve: Motion.emphasized,
      builder: (context, t, child) => SizedBox(
        width: width * t,
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.centerLeft,
            minWidth: width,
            maxWidth: width,
            child: Opacity(opacity: t.clamp(0, 1), child: child),
          ),
        ),
      ),
      child: const CartPanel(),
    );
  }
}

class _Destaques extends StatelessWidget {
  const _Destaques({required this.produtos});

  final List<Produto> produtos;

  @override
  Widget build(BuildContext context) {
    final compact = context.isCompact;
    final w = MediaQuery.sizeOf(context).width;
    final cardW = compact ? w * 0.82 : 440.0;
    final cardH = compact ? 300.0 : 340.0;
    return Padding(
      padding: const EdgeInsets.only(top: Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.gutter),
            child: Row(
              children: [
                Icon(LucideIcons.sparkles, color: context.palette.accent, size: 22),
                const SizedBox(width: Space.xs),
                Flexible(child: Text('Destaques da casa', style: context.text.headlineMedium)),
              ],
            ),
          ),
          const SizedBox(height: Space.md),
          SizedBox(
            height: cardH,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: context.gutter),
              physics: const BouncingScrollPhysics(),
              itemCount: produtos.length,
              separatorBuilder: (_, _) => const SizedBox(width: Space.md),
              itemBuilder: (context, i) => SizedBox(
                width: cardW,
                child: FeaturedCard(produto: produtos[i]),
              ).entrance(context, index: i, dy: 0, stepMs: 70),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================ estados

class MenuSkeleton extends StatelessWidget {
  const MenuSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final g = context.gutter;
    final compact = context.isCompact;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(g),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Skeleton(width: 140, height: 14, radius: 8),
            const SizedBox(height: Space.sm),
            const Skeleton(width: 280, height: 34, radius: 10),
            const SizedBox(height: Space.lg),
            Row(
              children: [
                for (var i = 0; i < 4; i++) ...[
                  const Skeleton(width: 110, height: 44, radius: 22),
                  const SizedBox(width: Space.xs),
                ],
              ],
            ),
            const SizedBox(height: Space.lg),
            Expanded(
              child: compact
                  ? ListView(
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        for (var i = 0; i < 6; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: Space.lg),
                            child: Row(
                              children: [
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Skeleton(width: 160, height: 18, radius: 6),
                                      SizedBox(height: 8),
                                      Skeleton(height: 12, radius: 6),
                                      SizedBox(height: 6),
                                      Skeleton(width: 200, height: 12, radius: 6),
                                      SizedBox(height: 12),
                                      Skeleton(width: 80, height: 16, radius: 6),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: Space.md),
                                Skeleton(width: 116, height: 116, radius: Radii.md),
                              ],
                            ),
                          ),
                      ],
                    )
                  : GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 330,
                        mainAxisExtent: 372,
                        crossAxisSpacing: 20,
                        mainAxisSpacing: 20,
                      ),
                      itemCount: 8,
                      itemBuilder: (_, _) => Skeleton(radius: Radii.lg),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: EmptyState(
        icon: LucideIcons.wifiOff,
        title: 'Não foi possível carregar o cardápio',
        message: message,
        action: AppButton(label: 'Tentar novamente', icon: LucideIcons.refreshCw, expand: false, onPressed: onRetry),
      ),
    );
  }
}
