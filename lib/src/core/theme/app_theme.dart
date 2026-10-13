import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/models/loja.dart';
import 'app_palette.dart';
import 'temas.dart';
import 'tokens.dart';

/// Tipografia oficial Forven: Public Sans.
/// Bold = títulos e frases de destaque · Medium = subtítulos e CTAs · Regular = textos corridos.
/// Outros pares (escolhidos no ERP) usam a fonte de título em display/headline/titleLarge.
TextTheme _textTheme(AppPalette p, {String fonte = 'public_sans'}) {
  final (titulo, texto) = familiasDaFonte(fonte);
  final forven = titulo == 'Public Sans';
  TextStyle estilo(String familia, double size, FontWeight w, double height, double ls, Color? color) {
    final cor = color ?? p.textPrimary;
    if (familia == 'Public Sans') {
      return GoogleFonts.publicSans(fontSize: size, fontWeight: w, height: height, letterSpacing: ls, color: cor);
    }
    // Tracking negativo foi desenhado para a Public Sans; nas outras, mais suave.
    return GoogleFonts.getFont(
      familia,
      fontSize: size,
      fontWeight: w,
      height: height,
      letterSpacing: ls * 0.5,
      color: cor,
    );
  }

  TextStyle t(double size, FontWeight w, {double height = 1.45, double ls = 0, Color? color}) =>
      estilo(texto, size, w, height, ls, color);
  TextStyle h(double size, FontWeight w, {double height = 1.45, double ls = 0, Color? color}) =>
      estilo(forven ? texto : titulo, size, w, height, ls, color);

  return TextTheme(
    // Títulos grandes com tracking apertado, como no forven.com.br.
    displayLarge: h(60, FontWeight.w800, height: 1.02, ls: -2.2),
    displayMedium: h(46, FontWeight.w800, height: 1.04, ls: -1.6),
    displaySmall: h(34, FontWeight.w700, height: 1.08, ls: -1.0),
    headlineLarge: h(30, FontWeight.w700, height: 1.1, ls: -0.8),
    headlineMedium: h(25, FontWeight.w700, height: 1.15, ls: -0.6),
    headlineSmall: h(21, FontWeight.w700, height: 1.2, ls: -0.4),
    titleLarge: h(19, FontWeight.w600, height: 1.25, ls: -0.2),
    titleMedium: t(16.5, FontWeight.w600, height: 1.3, ls: -0.1),
    titleSmall: t(15, FontWeight.w600, height: 1.3),
    bodyLarge: t(17, FontWeight.w400, height: 1.55, color: p.textSecondary),
    bodyMedium: t(15, FontWeight.w400, height: 1.5, color: p.textSecondary),
    bodySmall: t(13.5, FontWeight.w400, color: p.textMuted),
    labelLarge: t(16, FontWeight.w600, height: 1.2),
    labelMedium: t(14, FontWeight.w500, height: 1.2),
    labelSmall: t(12, FontWeight.w600, height: 1.2, ls: 1.1, color: p.textMuted),
  );
}

/// Tema do app. Com [aparencia] (vinda do ERP), o tema escolhido lá define cores,
/// claro/escuro, fontes e cantos; sem ela, usa a identidade Forven em [brightness].
ThemeData buildTheme(Brightness brightness, {Color? brand, AparenciaCardapio? aparencia, bool sempreEscuro = false}) {
  final AppPalette p;
  if (aparencia == null) {
    p = brightness == Brightness.dark ? AppPalette.dark(brand: brand) : AppPalette.light(brand: brand);
    Radii.escala = 1;
  } else {
    final preset = sempreEscuro ? temaPorValor(aparencia.tema).versaoEscura : temaPorValor(aparencia.tema);
    brightness = preset.brightness;
    p = paletaDoTema(preset, primaria: aparencia.corPrimaria, destaque: aparencia.corDestaque);
    Radii.escala = escalaDosCantos(aparencia.cantos);
  }
  final text = _textTheme(p, fonte: aparencia?.fonte ?? 'public_sans');
  final scheme = ColorScheme(
    brightness: brightness,
    primary: p.primary,
    onPrimary: p.onPrimary,
    secondary: p.accent,
    onSecondary: p.onAccent,
    error: p.danger,
    onError: Colors.white,
    surface: p.surface,
    onSurface: p.textPrimary,
    onSurfaceVariant: p.textSecondary,
    outline: p.outline,
    outlineVariant: p.outline,
    surfaceContainerHighest: p.surfaceRaised,
    shadow: p.shadow,
    scrim: p.scrim,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.background,
    canvasColor: p.background,
    textTheme: text,
    extensions: [p],
    splashFactory: InkSparkle.splashFactory,
    highlightColor: Colors.transparent,
    dividerColor: p.outline,
    iconTheme: IconThemeData(color: p.textPrimary, size: IconSizes.md),
    appBarTheme: AppBarTheme(
      backgroundColor: p.background,
      foregroundColor: p.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
      systemOverlayStyle: brightness == Brightness.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surfaceSunken,
      contentPadding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.md),
      hintStyle: text.bodyMedium?.copyWith(color: p.textMuted),
      labelStyle: text.bodyMedium,
      floatingLabelStyle: text.labelMedium?.copyWith(color: p.accent),
      border: OutlineInputBorder(
        borderRadius: Radii.rMd,
        borderSide: BorderSide(color: p.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: Radii.rMd,
        borderSide: BorderSide(color: p.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: Radii.rMd,
        borderSide: BorderSide(color: p.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: Radii.rMd,
        borderSide: BorderSide(color: p.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: Radii.rMd,
        borderSide: BorderSide(color: p.danger, width: 2),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: brightness == Brightness.dark ? const Color(0xFFF6EEE4) : const Color(0xFF22180F),
      contentTextStyle: text.labelLarge?.copyWith(
        color: brightness == Brightness.dark ? const Color(0xFF22180F) : const Color(0xFFF6EEE4),
      ),
      actionTextColor: p.accent,
      shape: RoundedRectangleBorder(borderRadius: Radii.rMd),
      insetPadding: const EdgeInsets.all(Space.md),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface,
      modalBackgroundColor: p.surface,
      showDragHandle: true,
      dragHandleColor: p.outlineStrong,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl))),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.onPrimary : p.textMuted),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? p.primary : p.surfaceSunken,
      ),
      trackOutlineColor: WidgetStateProperty.all(p.outline),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: p.accent),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.primary : null),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.onPrimary : p.textPrimary,
        ),
        side: WidgetStateProperty.all(BorderSide(color: p.outlineStrong)),
        textStyle: WidgetStateProperty.all(text.labelMedium),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.primary,
        foregroundColor: p.onPrimary,
        textStyle: text.labelLarge,
        shape: RoundedRectangleBorder(borderRadius: Radii.rSm),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: p.accent, textStyle: text.labelLarge),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: Radii.rXl),
      titleTextStyle: text.headlineSmall,
      contentTextStyle: text.bodyMedium,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder()},
    ),
  );
}

/// Baixa uma vez as fontes do tema; depois o google_fonts as guarda no aparelho
/// e o cardápio mantém a tipografia mesmo sem internet.
Future<void> prepararFontes(String fonte) async {
  final (titulo, texto) = familiasDaFonte(fonte);
  try {
    await GoogleFonts.pendingFonts([
      for (final familia in {titulo, texto})
        for (final peso in const [FontWeight.w400, FontWeight.w500, FontWeight.w600, FontWeight.w700, FontWeight.w800])
          GoogleFonts.getFont(familia, fontWeight: peso),
    ]);
  } catch (_) {
    // Sem internet: tenta de novo na próxima sincronização (até lá, fonte do sistema).
  }
}
