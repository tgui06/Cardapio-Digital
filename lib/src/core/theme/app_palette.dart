import 'package:flutter/material.dart';

/// Cores oficiais do Manual de Identidade Visual Forven (out/2026).
abstract final class ForvenColors {
  /// Azul-marinho — cor base, fundos e grandes áreas.
  static const marinho = Color(0xFF0F172A);

  /// Azul Forven — destaque, frases de impacto e CTAs.
  static const azul = Color(0xFF3B48E6);

  /// Tons de marinho — luz, sombra e profundidade sobre o marinho.
  static const marinho2 = Color(0xFF172133);
  static const marinho3 = Color(0xFF1E293B);

  /// Lavanda — substitui o Azul Forven em destaques e CTAs sobre fundos escuros.
  static const lavanda = Color(0xFFB1B6F5);

  // Escala do Azul Forven usada no forven.com.br.
  static const azul50 = Color(0xFFF5F6FE);
  static const azul100 = Color(0xFFEBEDFD);
  static const azul400 = Color(0xFF8088EF);
  static const azul500 = Color(0xFF5863EA);
  static const azul700 = Color(0xFF323DC4);
  static const azul900 = Color(0xFF1B2068);
  static const azul950 = Color(0xFF111440);
}

/// Tokens semânticos de cor. Componentes nunca usam hex direto: sempre
/// `context.palette.<token>`.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceSunken,
    required this.outline,
    required this.outlineStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.primary,
    required this.primarySoft,
    required this.onPrimary,
    required this.accent,
    required this.accentSoft,
    required this.onAccent,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.dangerSoft,
    required this.scrim,
    required this.shadow,
    required this.imageOverlay,
    required this.glow,
    required this.brandLine,
    required this.logo,
  });

  final Color background;
  final Color surface;
  final Color surfaceRaised;
  final Color surfaceSunken;
  final Color outline;
  final Color outlineStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  /// Preenchimento de CTAs e seleção (Azul Forven).
  final Color primary;
  final Color primarySoft;
  final Color onPrimary;

  /// Destaque em texto/ícones (lavanda no escuro, Azul Forven no claro).
  final Color accent;
  final Color accentSoft;
  final Color onAccent;

  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color danger;
  final Color dangerSoft;
  final Color scrim;
  final Color shadow;

  /// Degradê aplicado sobre fotos para garantir leitura de texto.
  final Color imageOverlay;

  /// Luz ambiente (manchas azuis do fundo).
  final Color glow;

  /// Linhas do grafismo do símbolo em contorno.
  final Color brandLine;

  /// Cor do logotipo neste tema (branco no escuro, marinho no claro).
  final Color logo;

  /// Tema "Marinho" — assinatura do totem.
  factory AppPalette.dark({Color? brand}) {
    final cta = brand ?? ForvenColors.azul;
    return AppPalette(
      background: ForvenColors.marinho,
      surface: ForvenColors.marinho2,
      surfaceRaised: ForvenColors.marinho3,
      surfaceSunken: const Color(0xFF0A1020),
      outline: const Color(0xFF263148),
      outlineStrong: const Color(0xFF37435E),
      textPrimary: const Color(0xFFF8FAFC),
      textSecondary: const Color(0xFFCBD5E1),
      textMuted: const Color(0xFF94A3B8),
      primary: cta,
      primarySoft: cta.withValues(alpha: 0.18),
      onPrimary: Colors.white,
      accent: ForvenColors.lavanda,
      accentSoft: ForvenColors.lavanda.withValues(alpha: 0.12),
      onAccent: ForvenColors.marinho,
      success: const Color(0xFF4ADE80),
      successSoft: const Color(0x244ADE80),
      warning: const Color(0xFFFBBF24),
      warningSoft: const Color(0x24FBBF24),
      danger: const Color(0xFFF87171),
      dangerSoft: const Color(0x24F87171),
      scrim: const Color(0xB3050816),
      shadow: const Color(0x99020617),
      imageOverlay: const Color(0xFF070B18),
      glow: cta.withValues(alpha: 0.28),
      brandLine: Colors.white.withValues(alpha: 0.10),
      logo: Colors.white,
    );
  }

  /// Tema "Branco".
  factory AppPalette.light({Color? brand}) {
    final cta = brand ?? ForvenColors.azul;
    return AppPalette(
      background: const Color(0xFFF8FAFC),
      surface: Colors.white,
      surfaceRaised: Colors.white,
      surfaceSunken: const Color(0xFFF1F5F9),
      outline: const Color(0xFFE2E8F0),
      outlineStrong: const Color(0xFFCBD5E1),
      textPrimary: ForvenColors.marinho,
      textSecondary: const Color(0xFF475569),
      textMuted: const Color(0xFF64748B),
      primary: cta,
      primarySoft: ForvenColors.azul100,
      onPrimary: Colors.white,
      accent: cta,
      accentSoft: ForvenColors.azul50,
      onAccent: Colors.white,
      success: const Color(0xFF15803D),
      successSoft: const Color(0x1A15803D),
      warning: const Color(0xFFB45309),
      warningSoft: const Color(0x1AB45309),
      danger: const Color(0xFFDC2626),
      dangerSoft: const Color(0x1ADC2626),
      scrim: const Color(0x990F172A),
      shadow: const Color(0x260F172A),
      imageOverlay: const Color(0xFF070B18),
      glow: cta.withValues(alpha: 0.14),
      brandLine: ForvenColors.marinho.withValues(alpha: 0.07),
      logo: ForvenColors.marinho,
    );
  }

  @override
  AppPalette copyWith() => this;

  /// Mesma paleta com outra cor de destaque (definida no ERP).
  AppPalette comDestaque(Color? cor) => cor == null
      ? this
      : AppPalette(
          background: background,
          surface: surface,
          surfaceRaised: surfaceRaised,
          surfaceSunken: surfaceSunken,
          outline: outline,
          outlineStrong: outlineStrong,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          textMuted: textMuted,
          primary: primary,
          primarySoft: primarySoft,
          onPrimary: onPrimary,
          accent: cor,
          accentSoft: cor.withValues(alpha: 0.12),
          onAccent: onAccent,
          success: success,
          successSoft: successSoft,
          warning: warning,
          warningSoft: warningSoft,
          danger: danger,
          dangerSoft: dangerSoft,
          scrim: scrim,
          shadow: shadow,
          imageOverlay: imageOverlay,
          glow: glow,
          brandLine: brandLine,
          logo: logo,
        );

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      background: l(background, other.background),
      surface: l(surface, other.surface),
      surfaceRaised: l(surfaceRaised, other.surfaceRaised),
      surfaceSunken: l(surfaceSunken, other.surfaceSunken),
      outline: l(outline, other.outline),
      outlineStrong: l(outlineStrong, other.outlineStrong),
      textPrimary: l(textPrimary, other.textPrimary),
      textSecondary: l(textSecondary, other.textSecondary),
      textMuted: l(textMuted, other.textMuted),
      primary: l(primary, other.primary),
      primarySoft: l(primarySoft, other.primarySoft),
      onPrimary: l(onPrimary, other.onPrimary),
      accent: l(accent, other.accent),
      accentSoft: l(accentSoft, other.accentSoft),
      onAccent: l(onAccent, other.onAccent),
      success: l(success, other.success),
      successSoft: l(successSoft, other.successSoft),
      warning: l(warning, other.warning),
      warningSoft: l(warningSoft, other.warningSoft),
      danger: l(danger, other.danger),
      dangerSoft: l(dangerSoft, other.dangerSoft),
      scrim: l(scrim, other.scrim),
      shadow: l(shadow, other.shadow),
      imageOverlay: l(imageOverlay, other.imageOverlay),
      glow: l(glow, other.glow),
      brandLine: l(brandLine, other.brandLine),
      logo: l(logo, other.logo),
    );
  }
}

/// Vitrines (banner de destaques, tela de descanso) são sempre escuras, com texto
/// branco sobre foto — mas na cor do tema escolhido no ERP, não só no marinho Forven.
extension VitrineX on AppPalette {
  bool get escuro => textPrimary.computeLuminance() > 0.5;

  Color get vitrine => escuro ? Color.lerp(imageOverlay, surfaceRaised, 0.5)! : imageOverlay;

  Color get vitrineProfunda => escuro ? background : Color.lerp(imageOverlay, Colors.black, 0.3)!;

  /// Destaque legível sobre a vitrine (lavanda no tema Forven).
  Color get destaqueVitrine => escuro ? accent : Color.lerp(primary, Colors.white, 0.6)!;
}

extension AppPaletteX on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
  TextTheme get text => Theme.of(this).textTheme;
}
