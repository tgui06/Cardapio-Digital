import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_parsing/path_parsing.dart';

import 'forven_paths.dart';

// Regras do manual aplicadas aqui:
// - Logotipo só em versões monocromáticas (preto/marinho sobre claro, branco sobre escuro), sem degradê.
// - Produto do ecossistema = logotipo + badge em caixa-alta com contorno arredondado, alinhada à altura do nome.
// - Símbolo em contorno só como grafismo decorativo, nunca como identificação.

class _PathWriter extends PathProxy {
  final Path path = Path();

  @override
  void moveTo(double x, double y) => path.moveTo(x, y);

  @override
  void lineTo(double x, double y) => path.lineTo(x, y);

  @override
  void cubicTo(double x1, double y1, double x2, double y2, double x3, double y3) =>
      path.cubicTo(x1, y1, x2, y2, x3, y3);

  @override
  void close() => path.close();
}

Path _parse((double, double, String) p, (double, double, double, double) box) {
  final w = _PathWriter();
  writeSvgPathDataToPath(p.$3, w);
  // matrix(1, 0, 0, -1, tx, ty) e depois desloca para a origem da caixa.
  final m = Float64List.fromList([1, 0, 0, 0, 0, -1, 0, 0, 0, 0, 1, 0, p.$1 - box.$1, p.$2 - box.$2, 0, 1]);
  return w.path.transform(m);
}

/// Símbolo (elos) normalizado para a caixa do símbolo.
final Path forvenSymbol = _parse(forvenSymbolPath, forvenSymbolBox);

/// Logotipo completo (símbolo + FORVEN) normalizado para a caixa do logotipo.
final Path forvenLogo = () {
  final p = Path()..addPath(_parse(forvenSymbolPath, forvenLogoBox), Offset.zero);
  for (final l in forvenWordmarkPaths) {
    p.addPath(_parse(l, forvenLogoBox), Offset.zero);
  }
  return p;
}();

Size get _symbolSize => Size(forvenSymbolBox.$3, forvenSymbolBox.$4);
Size get _logoSize => Size(forvenLogoBox.$3, forvenLogoBox.$4);

/// Altura das letras do nome em relação à altura total do logotipo.
const _capRatio = 95.0 / 127.17;

enum ForvenLogoKind { symbol, full }

/// Logotipo oficial Forven. Use [color] branco sobre fundos escuros e marinho/preto sobre claros.
class ForvenLogo extends StatelessWidget {
  const ForvenLogo({
    super.key,
    this.kind = ForvenLogoKind.full,
    this.height = 32,
    this.color = Colors.white,
    this.badge,
  });

  final ForvenLogoKind kind;
  final double height;
  final Color color;

  /// Badge de produto (ex.: "CARDÁPIO"), seguindo o padrão ERP/CRM/APP/IA.
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final src = kind == ForvenLogoKind.symbol ? _symbolSize : _logoSize;
    final logo = SizedBox(
      height: height,
      width: height * src.width / src.height,
      child: CustomPaint(painter: _FillPainter(kind == ForvenLogoKind.symbol ? forvenSymbol : forvenLogo, src, color)),
    );
    if (badge == null || kind == ForvenLogoKind.symbol) {
      return Semantics(label: 'Forven', image: true, child: logo);
    }
    final cap = height * _capRatio;
    return Semantics(
      label: 'Forven $badge',
      image: true,
      // Nunca transborda: em espaço curto o conjunto inteiro encolhe junto (proporção preservada).
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            logo,
            SizedBox(width: cap * 0.16),
            Container(
              height: cap,
              padding: EdgeInsets.symmetric(horizontal: cap * 0.16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(cap * 0.2),
                border: Border.all(color: color, width: math.max(1.2, cap * 0.075)),
              ),
              child: Text(
                badge!.toUpperCase(),
                style: GoogleFonts.publicSans(
                  color: color,
                  fontSize: cap * 0.62,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  letterSpacing: cap * 0.02,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FillPainter extends CustomPainter {
  _FillPainter(this.path, this.src, this.color);

  final Path path;
  final Size src;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / src.width, size.height / src.height);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..isAntiAlias = true,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FillPainter old) => old.color != color || old.path != path;
}

/// Grafismo de fundo: o símbolo em contorno, em linhas finas, repetido em escala grande
/// (como no hero do forven.com.br). [progress] desenha a linha de 0 a 1; [drift] desloca devagar.
class SymbolOutlinePainter extends CustomPainter {
  SymbolOutlinePainter({
    required this.color,
    this.progress = 1,
    this.drift = 0,
    this.strokeWidth = 1.2,
    this.layout = SymbolLayout.hero,
  });

  final Color color;
  final double progress;
  final double drift;
  final double strokeWidth;
  final SymbolLayout layout;

  static final List<ui.PathMetric> _metrics = forvenSymbol.computeMetrics().toList();

  void _draw(Canvas canvas, Offset center, double scale, double rotation, double alpha) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.scale(scale);
    canvas.translate(-_symbolSize.width / 2, -_symbolSize.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth / scale
      ..strokeJoin = StrokeJoin.round
      ..color = color.withValues(alpha: color.a * alpha);
    for (final m in _metrics) {
      canvas.drawPath(m.extractPath(0, m.length * progress.clamp(0, 1)), paint);
    }
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final d = drift * 2 * math.pi;
    switch (layout) {
      case SymbolLayout.hero:
        // Dois elos gigantes vazando pelas bordas, como no site.
        _draw(canvas, Offset(size.width * 0.96 + math.sin(d) * 14, size.height * 0.38), s * 0.0068, 0, 1);
        _draw(canvas, Offset(size.width * 0.02, size.height * 1.02 + math.cos(d) * 12), s * 0.0046, 0, 0.7);
      case SymbolLayout.centered:
        _draw(canvas, Offset(size.width / 2, size.height / 2), s / _symbolSize.width * 0.9, 0, 1);
      case SymbolLayout.corner:
        _draw(canvas, Offset(size.width * 0.98 + math.sin(d) * 8, size.height * 0.05), s * 0.0042, 0, 1);
    }
  }

  @override
  bool shouldRepaint(covariant SymbolOutlinePainter old) =>
      old.progress != progress || old.drift != drift || old.color != color || old.layout != layout;
}

enum SymbolLayout { hero, centered, corner }

/// Fundo de marca: grafismo de elos em contorno + luz ambiente azul em oscilação lenta.
class BrandBackdrop extends StatefulWidget {
  const BrandBackdrop({
    super.key,
    required this.lineColor,
    required this.glowColor,
    this.layout = SymbolLayout.hero,
    this.drawIn = true,
    this.child,
  });

  final Color lineColor;
  final Color glowColor;
  final SymbolLayout layout;

  /// Anima o traçado do símbolo ao aparecer.
  final bool drawIn;
  final Widget? child;

  @override
  State<BrandBackdrop> createState() => _BrandBackdropState();
}

class _BrandBackdropState extends State<BrandBackdrop> with TickerProviderStateMixin {
  late final AnimationController _draw = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
  late final AnimationController _drift = AnimationController(vsync: this, duration: const Duration(seconds: 18));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final anim = !MediaQuery.of(context).disableAnimations;
    if (anim) {
      if (widget.drawIn && !_draw.isAnimating && _draw.value == 0) _draw.forward();
      if (!widget.drawIn) _draw.value = 1;
      if (!_drift.isAnimating) _drift.repeat();
    } else {
      _draw.value = 1;
      _drift.stop();
    }
  }

  @override
  void dispose() {
    _draw.dispose();
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedBuilder(
          animation: _drift,
          builder: (context, _) {
            final t = _drift.value * 2 * math.pi;
            return Stack(
              fit: StackFit.expand,
              children: [
                // Luz ambiente: duas manchas de azul Forven se movendo devagar.
                Align(
                  alignment: Alignment(-0.7 + math.sin(t) * 0.15, -0.8 + math.cos(t) * 0.1),
                  child: _Glow(color: widget.glowColor, size: 620),
                ),
                Align(
                  alignment: Alignment(0.9 + math.cos(t) * 0.1, 0.7 + math.sin(t) * 0.12),
                  child: _Glow(color: widget.glowColor.withValues(alpha: widget.glowColor.a * 0.6), size: 520),
                ),
              ],
            );
          },
        ),
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: Listenable.merge([_draw, _drift]),
            builder: (context, _) => CustomPaint(
              painter: SymbolOutlinePainter(
                color: widget.lineColor,
                progress: Curves.easeInOutCubic.transform(_draw.value),
                drift: _drift.value,
                layout: widget.layout,
              ),
            ),
          ),
        ),
        ?widget.child,
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    ),
  );
}

/// Texto com palavras em destaque, como nos títulos do site ("**Venda** em **qualquer** lugar").
/// Marque os trechos de destaque com *asteriscos*.
class HighlightText extends StatelessWidget {
  const HighlightText(this.text, {super.key, required this.style, required this.highlight, this.textAlign});

  final String text;
  final TextStyle? style;
  final Color highlight;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final parts = text.split('*');
    return Text.rich(
      TextSpan(
        children: [
          for (var i = 0; i < parts.length; i++)
            TextSpan(
              text: parts[i],
              style: i.isOdd ? TextStyle(color: highlight) : null,
            ),
        ],
      ),
      style: style,
      textAlign: textAlign,
    );
  }
}
