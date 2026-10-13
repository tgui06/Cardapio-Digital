import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/navigation.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/skeleton.dart';
import '../../data/models/loja.dart';
import '../../data/models/pedido.dart';
import '../../state/providers.dart';
import '../attract/attract_screen.dart';
import '../menu/menu_screen.dart';
import '../offline/offline_host.dart';
import '../orders/orders_screen.dart';
import '../settings/settings_screen.dart';
import 'chamados_garcom.dart';

Color corMesa(AppPalette p, StatusMesa s) => switch (s) {
  StatusMesa.livre => p.success,
  StatusMesa.ocupada => p.accent,
  StatusMesa.conta => p.warning,
};

/// Tela inicial do garçom: mapa de mesas.
class WaiterHomeScreen extends ConsumerStatefulWidget {
  const WaiterHomeScreen({super.key});

  @override
  ConsumerState<WaiterHomeScreen> createState() => _WaiterHomeScreenState();
}

class _WaiterHomeScreenState extends ConsumerState<WaiterHomeScreen> {
  StatusMesa? _filtro;
  String? _area;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final mesas = ref.watch(mesasProvider);
    final loja = ref.watch(cardapioProvider).value?.loja;
    final now = ref.watch(nowProvider);
    ouvirChamadosNovos(context, ref);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(mesasProvider.future),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(context.gutter, Space.md, context.gutter, Space.sm),
                  child: Row(
                    children: [
                      Expanded(child: BrandMark(nome: loja?.nome ?? 'Forven', size: 38)),
                      const SyncIndicator(padding: EdgeInsets.only(right: Space.xs)),
                      RoundIconButton(
                        icon: LucideIcons.receipt,
                        label: 'Pedidos enviados',
                        badge: ref.watch(meusPedidosProvider).length,
                        onPressed: () => pushPage<void>(context, (_) => const OrdersScreen()),
                      ),
                      const SizedBox(width: Space.xs),
                      RoundIconButton(
                        icon: LucideIcons.settings,
                        label: 'Configurações',
                        onPressed: () => abrirConfiguracoes(context, ref),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(context.gutter, Space.md, context.gutter, Space.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Eyebrow('${greeting(now)} · ${timeOf(now)}'),
                      const SizedBox(height: Space.xxs),
                      Row(
                        children: [
                          Expanded(child: Text('Mesas', style: context.text.displaySmall)),
                          const GarcomChip(),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const ChamadosSliver(),
              ...switch (mesas) {
                AsyncData(:final value) => _conteudo(value, p),
                AsyncError(:final error) => [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: ErrorView(message: error.toString(), onRetry: () => ref.invalidate(mesasProvider)),
                  ),
                ],
                _ => [
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: context.gutter),
                    sliver: SliverGrid.builder(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 200,
                        mainAxisExtent: 176,
                        crossAxisSpacing: Space.sm,
                        mainAxisSpacing: Space.sm,
                      ),
                      itemCount: 12,
                      itemBuilder: (_, _) => Skeleton(radius: Radii.lg),
                    ),
                  ),
                ],
              },
              const SliverToBoxAdapter(child: SizedBox(height: Space.xxl)),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _conteudo(List<Mesa> todas, AppPalette p) {
    final areas = {for (final m in todas) m.area}.toList();
    final mesas = todas
        .where((m) => (_filtro == null || m.status == _filtro) && (_area == null || m.area == _area))
        .toList();
    int qtd(StatusMesa s) => todas.where((m) => m.status == s).length;
    final aberto = todas.where((m) => m.status != StatusMesa.livre).fold<double>(0, (s, m) => s + m.totalConsumido);

    Widget chip(String label, bool sel, VoidCallback onTap, {Color? cor, int? count}) => Pressable(
      onTap: onTap,
      borderRadius: Radii.rPill,
      selected: sel,
      child: AnimatedContainer(
        duration: Motion.base,
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: sel ? p.textPrimary : p.surfaceRaised,
          borderRadius: Radii.rPill,
          border: Border.all(color: sel ? p.textPrimary : p.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (cor != null) ...[
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
            ],
            Text(label, style: context.text.labelMedium?.copyWith(color: sel ? p.background : p.textPrimary)),
            if (count != null) ...[
              const SizedBox(width: 6),
              Text('$count', style: context.text.labelMedium?.copyWith(color: sel ? p.background : p.textMuted)),
            ],
          ],
        ),
      ),
    );

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: context.gutter),
          child: Row(
            children: [
              _Kpi(
                label: 'Ocupadas',
                valor: '${qtd(StatusMesa.ocupada) + qtd(StatusMesa.conta)}/${todas.length}',
                icon: LucideIcons.usersRound,
              ),
              const SizedBox(width: Space.sm),
              _Kpi(label: 'Em aberto', valor: money(aberto), icon: LucideIcons.coins),
              const SizedBox(width: Space.sm),
              _Kpi(
                label: 'Contas',
                valor: '${qtd(StatusMesa.conta)}',
                icon: LucideIcons.hand,
                destaque: qtd(StatusMesa.conta) > 0,
              ),
            ],
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: SizedBox(
          height: 68,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: context.gutter, vertical: 12),
            children: [
              chip('Todas', _filtro == null, () => setState(() => _filtro = null), count: todas.length),
              for (final s in StatusMesa.values) ...[
                const SizedBox(width: Space.xs),
                chip(
                  s.rotulo,
                  _filtro == s,
                  () => setState(() => _filtro = _filtro == s ? null : s),
                  cor: corMesa(p, s),
                  count: qtd(s),
                ),
              ],
              const SizedBox(width: Space.md),
              for (final a in areas) ...[
                chip(a, _area == a, () => setState(() => _area = _area == a ? null : a)),
                const SizedBox(width: Space.xs),
              ],
            ],
          ),
        ),
      ),
      if (mesas.isEmpty)
        const SliverToBoxAdapter(
          child: EmptyState(
            icon: LucideIcons.armchair,
            title: 'Nenhuma mesa aqui',
            message: 'Ajuste os filtros acima.',
          ),
        )
      else
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: context.gutter),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              mainAxisExtent: 176,
              crossAxisSpacing: Space.sm,
              mainAxisSpacing: Space.sm,
            ),
            itemCount: mesas.length,
            itemBuilder: (context, i) => _MesaCard(mesa: mesas[i]).entrance(context, index: i, stepMs: 25),
          ),
        ),
    ];
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.valor, required this.icon, this.destaque = false});

  final String label;
  final String valor;
  final IconData icon;
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(Space.sm),
        decoration: BoxDecoration(
          color: destaque ? p.warningSoft : p.surface,
          borderRadius: Radii.rMd,
          border: Border.all(color: destaque ? p.warning.withValues(alpha: 0.4) : p.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: destaque ? p.warning : p.textMuted),
            const SizedBox(height: Space.xs),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(valor, style: context.text.titleLarge),
            ),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _MesaCard extends ConsumerWidget {
  const _MesaCard({required this.mesa});

  final Mesa mesa;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final cor = corMesa(p, mesa.status);
    final livre = mesa.status == StatusMesa.livre;
    // Chamado do botão "Chamar garçom" (lista ao vivo, ou o que veio no mapa de mesas).
    final chamando =
        mesa.chamado != null || (ref.watch(chamadosAbertosProvider).value?.any((c) => c.mesa == mesa.numero) ?? false);
    return Pressable(
      onTap: () => pushPage<void>(context, (_) => TableScreen(mesa: mesa)),
      borderRadius: Radii.rLg,
      semanticLabel: 'Mesa ${mesa.numero}, ${mesa.status.rotulo}${livre ? '' : ', ${money(mesa.totalConsumido)}'}',
      child: Container(
        padding: const EdgeInsets.all(Space.md),
        decoration: BoxDecoration(
          color: livre ? p.surface : Color.alphaBlend(cor.withValues(alpha: 0.08), p.surface),
          borderRadius: Radii.rLg,
          border: Border.all(
            color: chamando ? p.warning : (livre ? p.outline : cor.withValues(alpha: 0.5)),
            width: chamando ? 2 : (livre ? 1 : 1.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text('${mesa.numero}', style: context.text.displaySmall?.copyWith(height: 1)),
                  ),
                ),
                if (chamando)
                  Icon(LucideIcons.bellRing, size: 20, color: p.warning)
                else
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              mesa.garcomNome == null ? '${mesa.area} · ${mesa.lugares} lugares' : '${mesa.area} · ${mesa.garcomNome}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall,
            ),
            const Spacer(),
            Text(
              mesa.status.rotulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelMedium?.copyWith(color: cor),
            ),
            if (!livre) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      money(mesa.totalConsumido),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleSmall,
                    ),
                  ),
                  if (mesa.abertaEm != null)
                    Flexible(
                      child: Text(
                        elapsed(mesa.abertaEm!, DateTime.now()),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================================ mesa

class TableScreen extends ConsumerWidget {
  const TableScreen({super.key, required this.mesa});

  final Mesa mesa;

  void _novoPedido(BuildContext context, WidgetRef ref) {
    final s = ref.read(sessaoProvider.notifier);
    ref.read(cartProvider.notifier).clear();
    s.reset();
    s
      ..setMesa(mesa.numero)
      ..setConsumo(TipoConsumo.local);
    abrirCardapio(context);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final pedidos = ref.watch(pedidosDaMesaProvider(mesa.numero));
    final cor = corMesa(p, mesa.status);

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.all(4),
          child: RoundIconButton(
            icon: LucideIcons.arrowLeft,
            label: 'Voltar às mesas',
            filled: false,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        title: Text('Mesa ${mesa.numero}'),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => ref.refresh(pedidosDaMesaProvider(mesa.numero).future),
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(context.gutter, Space.xs, context.gutter, Space.lg),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(Space.lg),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color.alphaBlend(cor.withValues(alpha: 0.16), p.surface), p.surface],
                            ),
                            borderRadius: Radii.rXl,
                            border: Border.all(color: p.outline),
                          ),
                          child: Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.end,
                            spacing: Space.lg,
                            runSpacing: Space.md,
                            children: [
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  StatusPill(label: mesa.status.rotulo, color: cor),
                                  const SizedBox(height: Space.sm),
                                  Text('${mesa.area} · ${mesa.lugares} lugares', style: context.text.bodyMedium),
                                  if (mesa.abertaEm != null)
                                    Text(
                                      'Aberta às ${timeOf(mesa.abertaEm!)} (${elapsed(mesa.abertaEm!, DateTime.now())})',
                                      style: context.text.bodySmall,
                                    ),
                                ],
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Consumo', style: context.text.bodySmall),
                                  Text(
                                    money(mesa.totalConsumido),
                                    style: context.text.headlineLarge?.copyWith(color: p.accent),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: Space.lg),
                        Text('Pedidos lançados pelo app', style: context.text.headlineSmall),
                        const SizedBox(height: Space.sm),
                        switch (pedidos) {
                          AsyncData(:final value) when value.isEmpty => Padding(
                            padding: const EdgeInsets.symmetric(vertical: Space.xl),
                            child: Text(
                              'Nenhum pedido enviado por este app para esta mesa ainda.',
                              textAlign: TextAlign.center,
                              style: context.text.bodyMedium,
                            ),
                          ),
                          AsyncData(:final value) => Column(
                            children: [
                              for (final (i, ped) in value.indexed)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: Space.sm),
                                  child: OrderCard(
                                    key: ValueKey(ped.codigoAcesso),
                                    inicial: ped,
                                    expandidoInicial: i == 0,
                                  ),
                                ),
                            ],
                          ),
                          AsyncError(:final error) => Text(
                            error.toString(),
                            style: context.text.bodyMedium?.copyWith(color: p.danger),
                          ),
                          _ => const Padding(
                            padding: EdgeInsets.all(Space.xl),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        },
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(context.gutter, Space.sm, context.gutter, Space.md),
                  child: AppButton(
                    label: 'Novo pedido para a mesa ${mesa.numero}',
                    icon: LucideIcons.plus,
                    height: 60,
                    onPressed: () => _novoPedido(context, ref),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
