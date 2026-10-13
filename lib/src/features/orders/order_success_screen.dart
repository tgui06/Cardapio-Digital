import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/navigation.dart';
import '../../core/brand/forven_brand.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/common.dart';
import '../../data/models/loja.dart';
import '../../data/models/pedido.dart';
import '../../state/providers.dart';
import '../../state/settings.dart';
import 'orders_screen.dart';
import 'status_timeline.dart';

class OrderSuccessScreen extends ConsumerStatefulWidget {
  const OrderSuccessScreen({super.key, required this.pedido});

  final Pedido pedido;

  @override
  ConsumerState<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends ConsumerState<OrderSuccessScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
  static const _voltarEm = 45;
  int _restante = _voltarEm;
  Timer? _timer;

  bool get _totem => ref.read(settingsProvider).modo == ModoOperacao.totem;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (Motion.enabled(context)) {
        _anim.forward();
      } else {
        _anim.value = 1;
      }
      if (_totem) {
        _timer = Timer.periodic(const Duration(seconds: 1), (t) {
          if (_restante <= 1) {
            t.cancel();
            _novoPedido();
          } else {
            setState(() => _restante--);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _anim.dispose();
    super.dispose();
  }

  /// Totem: limpa a sessão e volta para a tela de boas-vindas.
  /// Garçom: volta para o mapa de mesas.
  void _novoPedido() {
    _timer?.cancel();
    novoAtendimento(ref);
    // Totem de balcão: próximo cliente não vê o pedido anterior. Tablet da mesa: a lista vem do ERP
    // (pedidos da mesa desde a última conta fechada).
    if (_totem && ref.read(settingsProvider).mesaFixa == null) ref.read(meusPedidosProvider.notifier).clear();
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  void _continuarPedindo() {
    _timer?.cancel();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final ao = ref.watch(pedidoAoVivoProvider(widget.pedido.codigoAcesso));
    final pedido = ao.value ?? widget.pedido;
    final nome = pedido.nomeCliente.isEmpty ? '' : ', ${nomeCurto(pedido.nomeCliente)}';
    final wide = !context.isCompact;

    final ticket = _Ticket(pedido: pedido);

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: wide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 150,
          height: 150,
          child: AnimatedBuilder(
            animation: _anim,
            builder: (_, _) => CustomPaint(
              painter: _SuccessPainter(t: _anim.value, color: p.accent, track: p.accentSoft),
            ),
          ),
        ),
        const SizedBox(height: Space.lg),
        Text(
          pedido.erroEnvio != null
              ? 'Pedido não aceito'
              : pedido.sincronizado
              ? 'Pedido enviado!'
              : 'Pedido registrado!',
          style: context.text.displayMedium,
          textAlign: wide ? TextAlign.start : TextAlign.center,
        ).entrance(context, index: 6),
        const SizedBox(height: Space.xs),
        Text(
          pedido.erroEnvio != null
              ? '${pedido.erroEnvio} Chame um atendente, por favor.'
              : pedido.sincronizado
              ? 'Obrigado$nome! A cozinha já recebeu seu pedido.'
              : 'Obrigado$nome! A internet oscilou, mas seu pedido está guardado neste aparelho '
                    'e vai para a cozinha sozinho em instantes.',
          style: context.text.bodyLarge,
          textAlign: wide ? TextAlign.start : TextAlign.center,
        ).entrance(context, index: 7),
        const SizedBox(height: Space.xl),
        Container(
          padding: const EdgeInsets.all(Space.lg),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: Radii.rLg,
            border: Border.all(color: p.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      pedido.sincronizado ? pedido.status.mensagem : 'Aguardando conexão para enviar',
                      style: context.text.titleMedium,
                    ),
                  ),
                  if (pedido.sincronizado)
                    Text('atualiza sozinho', style: context.text.bodySmall)
                  else
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: p.warning)),
                ],
              ),
              const SizedBox(height: Space.lg),
              StatusTimeline(status: pedido.status),
            ],
          ),
        ).entrance(context, index: 8),
      ],
    );

    final actions = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_totem) ...[
          AppButton(
            label: 'Novo pedido',
            icon: LucideIcons.plus,
            onPressed: _novoPedido,
            trailing: _CountdownRing(restante: _restante, total: _voltarEm),
          ),
          const SizedBox(height: Space.sm),
          AppButton(
            label: 'Pedir mais alguma coisa',
            icon: LucideIcons.utensils,
            tone: ButtonTone.secondary,
            onPressed: _continuarPedindo,
          ),
        ] else ...[
          AppButton(label: 'Voltar às mesas', icon: LucideIcons.layoutGrid, onPressed: _novoPedido),
          const SizedBox(height: Space.sm),
          AppButton(
            label: 'Acompanhar pedidos',
            icon: LucideIcons.receipt,
            tone: ButtonTone.secondary,
            onPressed: () => pushPage<void>(context, (_) => const OrdersScreen()),
          ),
        ],
      ],
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _novoPedido();
      },
      child: Scaffold(
        body: Stack(
          children: [
            // Fundo de marca: luz ambiente azul + elos em contorno se desenhando.
            Positioned.fill(
              child: BrandBackdrop(lineColor: p.brandLine, glowColor: p.glow),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(context.gutter),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: wide ? 1080 : 520),
                    child: wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(flex: 6, child: content),
                              const SizedBox(width: Space.xxl),
                              Expanded(
                                flex: 5,
                                child: Column(
                                  children: [
                                    ticket.entrance(context, index: 5),
                                    const SizedBox(height: Space.lg),
                                    actions,
                                  ],
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              content,
                              const SizedBox(height: Space.lg),
                              ticket.entrance(context, index: 9),
                              const SizedBox(height: Space.lg),
                              actions,
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Ticket extends StatelessWidget {
  const _Ticket({required this.pedido});

  final Pedido pedido;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final info = <(IconData, String, String)>[
      if (pedido.mesa != null)
        (LucideIcons.armchair, 'Mesa', '${pedido.mesa}')
      else
        (
          pedido.tipoConsumo == TipoConsumo.local ? LucideIcons.store : LucideIcons.handbag,
          'Retirada',
          pedido.tipoConsumo == TipoConsumo.local ? 'No balcão' : 'Para levar',
        ),
      (LucideIcons.timer, 'Previsão', '~${pedido.previsaoMin} min'),
      (LucideIcons.coins, 'Total', money(pedido.total)),
    ];

    return ClipPath(
      clipper: const _TicketClipper(),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [p.surfaceRaised, p.surface],
          ),
          border: Border.all(color: p.outline),
        ),
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Eyebrow('Sua senha', color: p.textMuted),
            const SizedBox(height: Space.xxs),
            FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                pedido.senha,
                style: context.text.displayLarge?.copyWith(
                  fontSize: pedido.sincronizado ? 88 : 56,
                  color: pedido.sincronizado ? p.accent : p.warning,
                  height: 1,
                ),
              ),
            ),
            const SizedBox(height: Space.xs),
            Text(
              'Feito às ${timeOf(pedido.criadoEm)} · ${itensLabel(pedido.quantidadeItens)}',
              style: context.text.bodySmall,
            ),
            const SizedBox(height: Space.lg),
            _Dashes(color: p.outlineStrong),
            const SizedBox(height: Space.lg),
            Row(
              children: [
                for (final (icon, l, v) in info)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(icon, size: 20, color: p.textMuted),
                        const SizedBox(height: Space.xxs),
                        Text(l, style: context.text.bodySmall),
                        Text(v, style: context.text.titleSmall),
                      ],
                    ),
                  ),
              ],
            ),
            if (pedido.formaPagamento.isNotEmpty) ...[
              const SizedBox(height: Space.lg),
              Container(
                padding: const EdgeInsets.all(Space.sm),
                decoration: BoxDecoration(color: p.accentSoft, borderRadius: Radii.rMd),
                child: Row(
                  children: [
                    Icon(LucideIcons.info, color: p.accent, size: 20),
                    const SizedBox(width: Space.xs),
                    Expanded(
                      child: Text(pedido.formaPagamento, style: context.text.labelMedium?.copyWith(color: p.accent)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Dashes extends StatelessWidget {
  const _Dashes({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, c) {
      final n = (c.maxWidth / 12).floor();
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [for (var i = 0; i < n; i++) Container(width: 6, height: 2, color: color)],
      );
    },
  );
}

/// Recortes semicirculares nas laterais (efeito de comprovante).
class _TicketClipper extends CustomClipper<Path> {
  const _TicketClipper();

  @override
  Path getClip(Size size) {
    const r = 14.0;
    final radius = Radii.lg;
    final y = size.height * 0.52;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
    final holes = Path()
      ..addOval(Rect.fromCircle(center: Offset(0, y), radius: r))
      ..addOval(Rect.fromCircle(center: Offset(size.width, y), radius: r));
    return Path.combine(PathOperation.difference, path, holes);
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _CountdownRing extends StatelessWidget {
  const _CountdownRing({required this.restante, required this.total});

  final int restante;
  final int total;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      label: 'Voltando ao início em $restante segundos',
      child: SizedBox(
        width: 34,
        height: 34,
        child: Stack(
          alignment: Alignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(end: restante / total),
              duration: const Duration(seconds: 1),
              builder: (_, v, _) => CircularProgressIndicator(
                value: v,
                strokeWidth: 3,
                color: p.onPrimary,
                backgroundColor: p.onPrimary.withValues(alpha: 0.2),
              ),
            ),
            Text('$restante', style: context.text.labelSmall?.copyWith(color: p.onPrimary, letterSpacing: 0)),
          ],
        ),
      ),
    );
  }
}

/// Anel que se desenha, check que se desenha e uma explosão de partículas.
class _SuccessPainter extends CustomPainter {
  _SuccessPainter({required this.t, required this.color, required this.track});

  final double t;
  final Color color;
  final Color track;

  double _seg(double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width * 0.34;

    // Partículas
    final burst = Curves.easeOutCubic.transform(_seg(0.45, 1));
    if (burst > 0 && burst < 1) {
      final rnd = math.Random(7);
      for (var i = 0; i < 18; i++) {
        final ang = (i / 18) * math.pi * 2 + rnd.nextDouble() * 0.3;
        final dist = r + 8 + burst * (size.width * 0.22 + rnd.nextDouble() * 18);
        final pt = c + Offset(math.cos(ang), math.sin(ang)) * dist;
        final paint = Paint()..color = color.withValues(alpha: (1 - burst) * 0.9);
        canvas.drawCircle(pt, (i.isEven ? 4 : 2.6) * (1 - burst * 0.5), paint);
      }
    }

    // Disco de fundo
    final fill = Curves.easeOutBack.transform(_seg(0.0, 0.4));
    canvas.drawCircle(c, r * fill, Paint()..color = track);

    // Anel
    final ring = Curves.easeInOutCubic.transform(_seg(0.05, 0.5));
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      math.pi * 2 * ring,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );

    // Check
    final ck = Curves.easeOutCubic.transform(_seg(0.4, 0.75));
    if (ck > 0) {
      final p1 = c + Offset(-r * 0.42, r * 0.02);
      final p2 = c + Offset(-r * 0.1, r * 0.34);
      final p3 = c + Offset(r * 0.46, -r * 0.3);
      final l1 = (p2 - p1).distance;
      final l2 = (p3 - p2).distance;
      final d = ck * (l1 + l2);
      final path = Path()..moveTo(p1.dx, p1.dy);
      if (d <= l1) {
        final q = Offset.lerp(p1, p2, d / l1)!;
        path.lineTo(q.dx, q.dy);
      } else {
        path.lineTo(p2.dx, p2.dy);
        final q = Offset.lerp(p2, p3, (d - l1) / l2)!;
        path.lineTo(q.dx, q.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SuccessPainter old) => old.t != t || old.color != color;
}
