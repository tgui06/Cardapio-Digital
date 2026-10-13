import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/pressable.dart';
import '../../data/models/pedido.dart';
import '../../state/providers.dart';
import '../../state/settings.dart';
import 'status_timeline.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  @override
  void initState() {
    super.initState();
    // Tablet da mesa: ao abrir, busca no ERP os pedidos da mesa (desde a última conta fechada).
    final mesa = ref.read(settingsProvider).mesaFixa;
    if (mesa != null) Future.microtask(() => ref.read(meusPedidosProvider.notifier).sincronizarMesa(mesa));
  }

  @override
  Widget build(BuildContext context) {
    final pedidos = ref.watch(meusPedidosProvider);
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.all(4),
          child: RoundIconButton(
            icon: LucideIcons.arrowLeft,
            label: 'Voltar',
            filled: false,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        title: const Text('Meus pedidos'),
      ),
      body: pedidos.isEmpty
          ? const EmptyState(
              icon: LucideIcons.receipt,
              title: 'Nenhum pedido ainda',
              message: 'Quando você enviar um pedido, ele aparece aqui com o status em tempo real.',
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView.separated(
                  padding: EdgeInsets.fromLTRB(context.gutter, Space.sm, context.gutter, Space.xxl),
                  itemCount: pedidos.length,
                  separatorBuilder: (_, _) => const SizedBox(height: Space.md),
                  itemBuilder: (context, i) => OrderCard(
                    key: ValueKey(pedidos[i].codigoAcesso),
                    inicial: pedidos[i],
                    expandidoInicial: i == 0,
                  ).entrance(context, index: i),
                ),
              ),
            ),
    );
  }
}

/// Cartão de pedido com status ao vivo e itens expansíveis.
class OrderCard extends ConsumerStatefulWidget {
  const OrderCard({super.key, required this.inicial, this.expandidoInicial = false});

  final Pedido inicial;
  final bool expandidoInicial;

  @override
  ConsumerState<OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends ConsumerState<OrderCard> {
  late bool _aberto = widget.expandidoInicial;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final pedido = ref.watch(pedidoAoVivoProvider(widget.inicial.codigoAcesso)).value ?? widget.inicial;
    final cor = statusColor(p, pedido.status);
    final progresso = (StatusPedido.fluxo.indexOf(pedido.status) + 1) / StatusPedido.fluxo.length;

    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: Radii.rLg,
        border: Border.all(color: p.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Pressable(
            onTap: () => setState(() => _aberto = !_aberto),
            scale: 0.99,
            semanticLabel:
                'Pedido ${pedido.sincronizado ? pedido.numero : 'na fila'}, ${pedido.status.rotulo}. Toque para ${_aberto ? 'recolher' : 'ver detalhes'}',
            child: Padding(
              padding: const EdgeInsets.all(Space.md),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(color: cor.withValues(alpha: 0.14), borderRadius: Radii.rMd),
                    child: Icon(statusIcon(pedido.status), color: cor, size: 26),
                  ),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: Space.xs,
                          runSpacing: Space.xxs,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              pedido.senha,
                              style: context.text.headlineSmall?.copyWith(
                                color: pedido.sincronizado ? null : context.palette.warning,
                              ),
                            ),
                            StatusPill(
                              label: pedido.status.rotulo,
                              color: cor,
                              pulse: pedido.status != StatusPedido.entregue,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            timeOf(pedido.criadoEm),
                            if (pedido.mesa != null) 'Mesa ${pedido.mesa}' else pedido.tipoConsumo.rotulo,
                            itensLabel(pedido.quantidadeItens),
                          ].join(' · '),
                          style: context.text.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Text(money(pedido.total), style: context.text.titleMedium),
                  const SizedBox(width: Space.xs),
                  AnimatedRotation(
                    turns: _aberto ? 0.5 : 0,
                    duration: Motion.base,
                    child: Icon(LucideIcons.chevronDown, size: 18, color: p.textMuted),
                  ),
                ],
              ),
            ),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(end: progresso),
            duration: const Duration(milliseconds: 600),
            curve: Motion.emphasized,
            builder: (_, v, _) =>
                LinearProgressIndicator(value: v, minHeight: 3, color: cor, backgroundColor: p.surfaceSunken),
          ),
          AnimatedSize(
            duration: Motion.slow,
            curve: Motion.enter,
            alignment: Alignment.topCenter,
            child: !_aberto
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.all(Space.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        StatusTimeline(status: pedido.status),
                        const SizedBox(height: Space.lg),
                        for (final i in pedido.itens)
                          Padding(
                            padding: const EdgeInsets.only(bottom: Space.xs),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 32,
                                  child: Text(
                                    '${i.quantidade}×',
                                    style: context.text.labelMedium?.copyWith(color: p.accent),
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(i.nome, style: context.text.titleSmall),
                                      if (i.complementos.isNotEmpty)
                                        Text(
                                          i.complementos
                                              .map((c) => c.quantidade > 1 ? '${c.quantidade}× ${c.nome}' : c.nome)
                                              .join(' · '),
                                          style: context.text.bodySmall,
                                        ),
                                      if (i.observacao.isNotEmpty)
                                        Text(
                                          '“${i.observacao}”',
                                          style: context.text.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                                        ),
                                    ],
                                  ),
                                ),
                                Text(money(i.total), style: context.text.bodyMedium),
                              ],
                            ),
                          ),
                        if (pedido.taxaServico > 0) ...[
                          Divider(color: p.outline, height: Space.lg),
                          Row(
                            children: [
                              Expanded(child: Text('Serviço', style: context.text.bodyMedium)),
                              Text(money(pedido.taxaServico), style: context.text.bodyMedium),
                            ],
                          ),
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
