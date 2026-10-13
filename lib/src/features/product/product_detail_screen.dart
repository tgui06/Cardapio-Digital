import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/app_image.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/toast.dart';
import '../../data/models/cardapio.dart';
import '../../data/models/cart_item.dart';
import '../../state/providers.dart';
import '../menu/widgets/product_cards.dart';
import 'option_group.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({super.key, required this.produto, required this.heroTag, this.editing});

  final Produto produto;
  final String heroTag;

  /// Quando vem da sacola: edita o item em vez de adicionar outro.
  final CartItem? editing;

  @override
  ConsumerState<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  late final Selecoes _sel;
  late int _qtd;
  late final TextEditingController _obs;
  final _scroll = ScrollController();
  late final Map<int, GlobalKey> _groupKeys = {for (final g in widget.produto.grupos) g.id: GlobalKey()};
  final Map<int, int> _shake = {};

  Produto get produto => widget.produto;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    _sel = {
      for (final entry in (e?.selecoes ?? const {}).entries) entry.key: {...entry.value},
    };
    _qtd = e?.quantidade ?? 1;
    _obs = TextEditingController(text: e?.observacao ?? '');
    // Grupo obrigatório com uma única opção disponível: já vem marcado.
    if (e == null) {
      for (final g in produto.grupos) {
        final disp = g.opcoes.where((o) => o.disponivel).toList();
        if (g.obrigatorio && g.tipo == TipoGrupo.unico && disp.length == 1) _sel[g.id] = {disp.first.id: 1};
      }
    }
  }

  @override
  void dispose() {
    _obs.dispose();
    _scroll.dispose();
    super.dispose();
  }

  int _count(GrupoComplemento g) => (_sel[g.id] ?? const {}).values.fold(0, (s, v) => s + v);

  GrupoComplemento? get _faltando {
    for (final g in produto.grupos) {
      if (_count(g) < g.minimo) return g;
    }
    return null;
  }

  double get _unit {
    var p = produto.preco;
    for (final g in produto.grupos) {
      for (final o in g.opcoes) {
        p += o.precoAdicional * (_sel[g.id]?[o.id] ?? 0);
      }
    }
    return p;
  }

  void _setQtdOpcao(GrupoComplemento g, OpcaoComplemento o, int q) {
    setState(() {
      final m = _sel.putIfAbsent(g.id, () => {});
      switch (g.tipo) {
        case TipoGrupo.unico:
          m.clear();
          if (q > 0) m[o.id] = 1;
        case TipoGrupo.multiplo:
          if (q > 0 && _count(g) >= g.maximo && (m[o.id] ?? 0) == 0) {
            HapticFeedback.mediumImpact();
            showToast(context, 'Você já escolheu ${g.maximo} em "${g.nome}"', icon: LucideIcons.info);
            return;
          }
          if (q > 0) {
            m[o.id] = 1;
          } else {
            m.remove(o.id);
          }
        case TipoGrupo.quantidade:
          if (q <= 0) {
            m.remove(o.id);
          } else {
            m[o.id] = q;
          }
      }
      if (m.isEmpty) _sel.remove(g.id);
    });
  }

  Future<void> _confirmar() async {
    final falta = _faltando;
    if (falta != null) {
      HapticFeedback.heavyImpact();
      setState(() => _shake[falta.id] = (_shake[falta.id] ?? 0) + 1);
      final ctx = _groupKeys[falta.id]?.currentContext;
      if (ctx != null) {
        await Scrollable.ensureVisible(ctx, duration: Motion.slow, curve: Motion.emphasized, alignment: 0.12);
      }
      return;
    }
    final cart = ref.read(cartProvider.notifier);
    final item = CartItem(
      uid: widget.editing?.uid ?? uuid.v4(),
      produto: produto,
      quantidade: _qtd,
      selecoes: {
        for (final e in _sel.entries)
          if (e.value.isNotEmpty) e.key: Map.of(e.value),
      },
      observacao: _obs.text.trim(),
    );
    if (widget.editing != null) {
      cart.replace(item);
    } else {
      cart.add(item);
    }
    HapticFeedback.lightImpact();
    if (!mounted) return;
    Navigator.of(context).pop();
    showToast(
      context,
      widget.editing != null ? 'Item atualizado' : '${_qtd > 1 ? '$_qtd× ' : ''}${produto.nome} na sacola',
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardapio = ref.watch(cardapioProvider).requireValue;
    final motivo = cardapio.motivoIndisponivel(produto, ref.watch(nowProvider));
    final content = _Content(
      produto: produto,
      cardapio: cardapio,
      motivo: motivo,
      sel: _sel,
      onChange: _setQtdOpcao,
      groupKeys: _groupKeys,
      shake: _shake,
      obs: _obs,
      editing: widget.editing != null,
    );
    final bar = _BottomBar(
      qtd: _qtd,
      onQtd: (q) => setState(() => _qtd = q),
      total: _unit * _qtd,
      disponivel: motivo == null,
      faltando: _faltando,
      editing: widget.editing != null,
      onConfirm: _confirmar,
    );

    if (context.isCompact) return _compact(content, bar);
    return _dialog(content, bar);
  }

  Widget _compact(Widget content, Widget bar) {
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.background,
      body: CustomScrollView(
        controller: _scroll,
        slivers: [
          SliverAppBar(
            expandedHeight: MediaQuery.sizeOf(context).height * 0.42,
            pinned: true,
            stretch: true,
            backgroundColor: p.background,
            automaticallyImplyLeading: false,
            leading: Padding(
              padding: const EdgeInsets.all(4),
              child: RoundIconButton(
                icon: LucideIcons.arrowLeft,
                label: 'Voltar',
                onImage: true,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            leadingWidth: 64,
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: widget.heroTag,
                    child: AppImage(produto.imagemUrl, width: 1000, semanticLabel: produto.nome),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0, 0.25, 0.75, 1],
                        colors: [
                          Colors.black.withValues(alpha: 0.35),
                          Colors.transparent,
                          Colors.transparent,
                          p.background,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.xl), child: content),
          ),
        ],
      ),
      bottomNavigationBar: bar,
    );
  }

  Widget _dialog(Widget content, Widget bar) {
    final p = context.palette;
    final size = MediaQuery.sizeOf(context);
    final portrait = size.width < 900;
    final image = Stack(
      fit: StackFit.expand,
      children: [
        // Sem Hero aqui: voos de Hero para rotas transparentes deixam a imagem
        // de origem invisível ao voltar. O painel já entra com escala + fade.
        AppImage(produto.imagemUrl, width: 1100, semanticLabel: produto.nome),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: portrait ? Alignment.topCenter : Alignment.centerLeft,
              end: portrait ? Alignment.bottomCenter : Alignment.centerRight,
              stops: const [0.6, 1],
              colors: [Colors.transparent, p.surface.withValues(alpha: 0.5)],
            ),
          ),
        ),
      ],
    );

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => Navigator.of(context).pop()),
        ),
        SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(Space.xl),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: portrait ? 640 : 1120, maxHeight: 780),
                child: Material(
                  color: p.surface,
                  borderRadius: Radii.rXl,
                  clipBehavior: Clip.antiAlias,
                  elevation: 0,
                  child: Stack(
                    children: [
                      if (portrait)
                        Column(
                          children: [
                            Expanded(
                              child: CustomScrollView(
                                controller: _scroll,
                                slivers: [
                                  SliverToBoxAdapter(child: SizedBox(height: 300, child: image)),
                                  SliverPadding(
                                    padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, Space.lg),
                                    sliver: SliverToBoxAdapter(child: content),
                                  ),
                                ],
                              ),
                            ),
                            bar,
                          ],
                        )
                      else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(flex: 5, child: image),
                            Expanded(
                              flex: 6,
                              child: Column(
                                children: [
                                  Expanded(
                                    child: SingleChildScrollView(
                                      controller: _scroll,
                                      padding: const EdgeInsets.fromLTRB(Space.xl, Space.xl, Space.xl, Space.lg),
                                      child: content,
                                    ),
                                  ),
                                  bar,
                                ],
                              ),
                            ),
                          ],
                        ),
                      Positioned(
                        top: Space.md,
                        left: portrait ? null : Space.md,
                        right: portrait ? Space.md : null,
                        child: RoundIconButton(
                          icon: LucideIcons.x,
                          label: 'Fechar',
                          onImage: true,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
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
  }
}

// ============================================================================ conteúdo

class _Content extends StatelessWidget {
  const _Content({
    required this.produto,
    required this.cardapio,
    required this.motivo,
    required this.sel,
    required this.onChange,
    required this.groupKeys,
    required this.shake,
    required this.obs,
    required this.editing,
  });

  final Produto produto;
  final Cardapio cardapio;
  final String? motivo;
  final Selecoes sel;
  final void Function(GrupoComplemento, OpcaoComplemento, int) onChange;
  final Map<int, GlobalKey> groupKeys;
  final Map<int, int> shake;
  final TextEditingController obs;
  final bool editing;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final loja = cardapio.loja;
    final categoria = cardapio.categoria(produto.categoriaId);
    final sugestoes = produto.sugestoes
        .map(cardapio.produto)
        .whereType<Produto>()
        .where((s) => cardapio.disponivelAgora(s, DateTime.now()))
        .toList();

    final info = <(IconData, String)>[
      if (produto.tempoPreparoMin != null) (LucideIcons.timer, '${produto.tempoPreparoMin} min de preparo'),
      if (produto.serve != null)
        (LucideIcons.users, produto.serve == 1 ? 'Individual' : 'Serve ${produto.serve} pessoas'),
      if (loja.mostrarCalorias && produto.calorias != null) (LucideIcons.flame, '${produto.calorias} kcal'),
    ];

    var i = 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(categoryIcon(categoria.icone), size: 16, color: p.accent),
            const SizedBox(width: 6),
            Eyebrow(categoria.nome),
          ],
        ).entrance(context, index: i++),
        const SizedBox(height: Space.xs),
        Text(produto.nome, style: context.text.displaySmall).entrance(context, index: i++),
        const SizedBox(height: Space.sm),
        PriceText(
          preco: produto.preco,
          precoOriginal: produto.precoOriginal,
          color: produto.emPromocao ? p.danger : p.accent,
          style: context.text.headlineSmall?.copyWith(
            fontFamily: context.text.titleLarge?.fontFamily,
            fontWeight: FontWeight.w700,
          ),
        ).entrance(context, index: i++),
        if (produto.tags.isNotEmpty) ...[
          const SizedBox(height: Space.md),
          Wrap(
            spacing: Space.xs,
            runSpacing: Space.xs,
            children: [for (final t in produto.tags) TagBadge(t)],
          ).entrance(context, index: i++),
        ],
        const SizedBox(height: Space.md),
        Text(produto.descricao, style: context.text.bodyLarge?.copyWith(height: 1.55)).entrance(context, index: i++),
        if (info.isNotEmpty) ...[
          const SizedBox(height: Space.lg - 4),
          Wrap(
            spacing: Space.xs,
            runSpacing: Space.xs,
            children: [
              for (final (icon, label) in info)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: p.surfaceSunken, borderRadius: Radii.rPill),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 16, color: p.textSecondary),
                      const SizedBox(width: 6),
                      Text(label, style: context.text.labelMedium?.copyWith(color: p.textSecondary)),
                    ],
                  ),
                ),
            ],
          ).entrance(context, index: i++),
        ],
        if (produto.alergenicos.isNotEmpty) ...[
          const SizedBox(height: Space.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(LucideIcons.circleAlert, size: 18, color: p.warning),
              const SizedBox(width: Space.xs),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Contém: ',
                        style: TextStyle(fontWeight: FontWeight.w700, color: p.textSecondary),
                      ),
                      TextSpan(text: produto.alergenicos.join(', ')),
                    ],
                  ),
                  style: context.text.bodyMedium,
                ),
              ),
            ],
          ).entrance(context, index: i++),
        ],
        if (motivo != null) ...[
          const SizedBox(height: Space.lg),
          Container(
            padding: const EdgeInsets.all(Space.md),
            decoration: BoxDecoration(color: p.warningSoft, borderRadius: Radii.rMd),
            child: Row(
              children: [
                Icon(LucideIcons.clock, color: p.warning),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text(motivo!, style: context.text.titleSmall?.copyWith(color: p.warning)),
                ),
              ],
            ),
          ),
        ],
        for (final g in produto.grupos) ...[
          const SizedBox(height: Space.lg),
          Animate(
            key: ValueKey('shake-${g.id}-${shake[g.id] ?? 0}'),
            effects: (shake[g.id] ?? 0) > 0 && Motion.enabled(context)
                ? [ShakeEffect(hz: 5, offset: const Offset(10, 0), duration: 420.ms)]
                : const [],
            child: OptionGroupCard(
              key: groupKeys[g.id],
              grupo: g,
              selecoes: sel[g.id] ?? const {},
              destacarFalta: (shake[g.id] ?? 0) > 0,
              enabled: motivo == null,
              onChange: (o, q) => onChange(g, o, q),
            ),
          ).entrance(context, index: i++),
        ],
        if (loja.permitirObservacaoItem && motivo == null) ...[
          const SizedBox(height: Space.lg),
          Row(
            children: [
              Icon(LucideIcons.notebookPen, size: 20, color: p.textSecondary),
              const SizedBox(width: Space.xs),
              Flexible(child: Text('Alguma observação?', style: context.text.titleMedium)),
            ],
          ),
          const SizedBox(height: Space.sm),
          TextField(
            controller: obs,
            maxLength: 140,
            minLines: 2,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Ex.: sem cebola, molho à parte, bem quente…'),
          ),
        ],
        if (sugestoes.isNotEmpty && !editing) ...[
          const SizedBox(height: Space.lg),
          Text('Combina com', maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.headlineSmall),
          const SizedBox(height: Space.sm),
          SizedBox(
            height: 186,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: sugestoes.length,
              separatorBuilder: (_, _) => const SizedBox(width: Space.sm),
              itemBuilder: (_, k) => SuggestionCard(produto: sugestoes[k], origem: 'sugestao-${produto.id}'),
            ),
          ),
        ],
      ],
    );
  }
}

// ============================================================================ barra inferior

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.qtd,
    required this.onQtd,
    required this.total,
    required this.disponivel,
    required this.faltando,
    required this.editing,
    required this.onConfirm,
  });

  final int qtd;
  final ValueChanged<int> onQtd;
  final double total;
  final bool disponivel;
  final GrupoComplemento? faltando;
  final bool editing;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    // No celular o botão é estreito: rótulo curto e sem ícone (o selo "Obrigatório" mostra o que falta).
    final compact = context.isCompact || context.isShort;
    final label = !disponivel
        ? (compact ? 'Indisponível' : 'Indisponível agora')
        : faltando != null
        ? (context.isCompact ? 'Escolher' : 'Escolher opções')
        : editing
        ? (compact ? 'Atualizar' : 'Atualizar item')
        : 'Adicionar';
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.outline)),
      ),
      padding: EdgeInsets.fromLTRB(
        Space.md,
        Space.sm + 2,
        Space.md,
        Space.sm + 2 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Row(
        children: [
          QuantityStepper(
            value: qtd,
            min: 1,
            max: 50,
            size: compact ? 40 : 44,
            compact: compact,
            onChanged: disponivel ? onQtd : (_) {},
          ),
          SizedBox(width: compact ? Space.sm : Space.md),
          Expanded(
            child: AppButton(
              label: label,
              icon: compact
                  ? null
                  : faltando != null && disponivel
                  ? LucideIcons.pointer
                  : LucideIcons.shoppingBag,
              onPressed: disponivel ? onConfirm : null,
              trailing: disponivel ? AnimatedMoney(total) : null,
              semanticLabel: '$label, total ${money(total)}',
            ),
          ),
        ],
      ),
    );
  }
}
