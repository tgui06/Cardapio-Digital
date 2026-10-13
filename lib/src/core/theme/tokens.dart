import 'package:flutter/material.dart';

/// Escala de espaçamento (ritmo de 4/8dp).
abstract final class Space {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;
}

abstract final class Radii {
  /// Ajustado pelo tema ("cantos" no ERP): reto 0,4 · suave 1 · arredondado 1,45.
  static double escala = 1;

  // Formas geométricas limpas: cantos médios em controles, generosos em painéis (como o site).
  static double get sm => 10 * escala;
  static double get md => 14 * escala;
  static double get lg => 20 * escala;
  static double get xl => 28 * escala;
  static const double pill = 999;

  static BorderRadius get rSm => BorderRadius.circular(sm);
  static BorderRadius get rMd => BorderRadius.circular(md);
  static BorderRadius get rLg => BorderRadius.circular(lg);
  static BorderRadius get rXl => BorderRadius.circular(xl);
  static BorderRadius get rPill => BorderRadius.circular(pill);
}

/// Durações e curvas — micro-interações entre 150 e 320ms.
abstract final class Motion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration base = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 320);
  static const Duration page = Duration(milliseconds: 380);

  /// expo.out (0.16, 1, 0.3, 1) — recomendação da skill para o estilo "Modern Dark".
  static const Curve enter = Cubic(0.16, 1, 0.3, 1);
  static const Curve exit = Curves.easeInCubic;
  static const Curve spring = Curves.easeOutBack;
  static const Curve emphasized = Cubic(0.16, 1, 0.3, 1);

  /// Respeita a preferência de "reduzir movimento" do sistema.
  static bool enabled(BuildContext context) => !MediaQuery.of(context).disableAnimations;
}

abstract final class IconSizes {
  static const double sm = 18;
  static const double md = 22;
  static const double lg = 28;
  static const double xl = 40;
}

enum WindowSize { compact, medium, expanded }

/// Breakpoints: celular do garçom (compact), tablet retrato (medium),
/// tablet paisagem / totem (expanded).
extension WindowSizeX on BuildContext {
  /// Tablet deitado (uso principal: na mesa do cliente) já é "expanded" a partir de 900 dp,
  /// para cobrir os tablets de 8" (≈ 960×600 dp em paisagem).
  WindowSize get windowSize {
    final s = MediaQuery.sizeOf(this);
    if (s.width >= 1024 || (s.width >= 900 && s.width > s.height)) return WindowSize.expanded;
    if (s.width >= 600) return WindowSize.medium;
    return WindowSize.compact;
  }

  bool get isCompact => windowSize == WindowSize.compact;
  bool get isExpanded => windowSize == WindowSize.expanded;

  /// Paisagem com pouca altura (tablets de 7–8"): cabeçalhos e respiros mais enxutos.
  bool get isShort => MediaQuery.sizeOf(this).height < 700;

  /// Margem lateral adaptativa.
  double get gutter => switch (windowSize) {
    WindowSize.compact => Space.md,
    WindowSize.medium => Space.lg,
    WindowSize.expanded => Space.xl,
  };
}
