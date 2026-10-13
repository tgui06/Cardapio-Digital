import 'package:flutter/material.dart';

import 'app_palette.dart';

/// Temas que o estabelecimento escolhe em ERP › Simuladores › Cardápio › Aparência.
/// Mesmas cores da prévia do ERP (resources/js/.../cardapio/tipos.ts → TEMAS).
@immutable
class TemaPreset {
  const TemaPreset({
    required this.valor,
    required this.nome,
    required this.fundo,
    required this.superficie,
    required this.primaria,
    required this.destaque,
    required this.texto,
  });

  final String valor;
  final String nome;
  final Color fundo;
  final Color superficie;
  final Color primaria;
  final Color destaque;
  final Color texto;

  bool get escuro => fundo.computeLuminance() < 0.3;
  Brightness get brightness => escuro ? Brightness.dark : Brightness.light;

  /// Versão noturna de um tema claro (tela de descanso e vitrines são sempre escuras).
  TemaPreset get versaoEscura => escuro
      ? this
      : TemaPreset(
          valor: '${valor}_escuro',
          nome: nome,
          fundo: Color.lerp(texto, Colors.black, 0.3)!,
          superficie: Color.lerp(texto, Colors.white, 0.08)!,
          primaria: primaria,
          destaque: Color.lerp(primaria, Colors.white, 0.55)!,
          texto: fundo,
        );
}

const temasCardapio = <TemaPreset>[
  TemaPreset(
    valor: 'forven',
    nome: 'Forven Marinho',
    fundo: Color(0xFF0F172A),
    superficie: Color(0xFF1E293B),
    primaria: Color(0xFF3B48E6),
    destaque: Color(0xFFB1B6F5),
    texto: Color(0xFFF8FAFC),
  ),
  TemaPreset(
    valor: 'claro',
    nome: 'Branco Clean',
    fundo: Color(0xFFF8FAFC),
    superficie: Color(0xFFFFFFFF),
    primaria: Color(0xFF3B48E6),
    destaque: Color(0xFF3B48E6),
    texto: Color(0xFF0F172A),
  ),
  TemaPreset(
    valor: 'cafe',
    nome: 'Café Espresso',
    fundo: Color(0xFF140F0C),
    superficie: Color(0xFF241C17),
    primaria: Color(0xFFC8813A),
    destaque: Color(0xFFE9C39A),
    texto: Color(0xFFF6EEE4),
  ),
  TemaPreset(
    valor: 'bistro',
    nome: 'Bistrô',
    fundo: Color(0xFFFAF5EE),
    superficie: Color(0xFFFFFFFF),
    primaria: Color(0xFF8C2F39),
    destaque: Color(0xFF8C2F39),
    texto: Color(0xFF2A1A14),
  ),
  TemaPreset(
    valor: 'verde',
    nome: 'Natural',
    fundo: Color(0xFF0F1A14),
    superficie: Color(0xFF18271F),
    primaria: Color(0xFF2F9E6B),
    destaque: Color(0xFF9FE0BE),
    texto: Color(0xFFF1F7F3),
  ),
  TemaPreset(
    valor: 'vinho',
    nome: 'Adega',
    fundo: Color(0xFF1A0D12),
    superficie: Color(0xFF2A161D),
    primaria: Color(0xFFB8324F),
    destaque: Color(0xFFF2A7B8),
    texto: Color(0xFFFBEFF2),
  ),
  TemaPreset(
    valor: 'grafite',
    nome: 'Grafite',
    fundo: Color(0xFF111111),
    superficie: Color(0xFF1C1C1C),
    primaria: Color(0xFFF59E0B),
    destaque: Color(0xFFFCD34D),
    texto: Color(0xFFFAFAFA),
  ),
];

TemaPreset temaPorValor(String valor) =>
    temasCardapio.firstWhere((t) => t.valor == valor, orElse: () => temasCardapio.first);

/// Texto legível sobre [fundo] (branco ou quase preto).
Color corSobre(Color fundo) => fundo.computeLuminance() > 0.45 ? const Color(0xFF111111) : Colors.white;

/// Paleta completa do app a partir das 5 cores do tema.
/// "forven" e "claro" usam as paletas oficiais da marca, ajustadas à mão.
AppPalette paletaDoTema(TemaPreset t, {Color? primaria, Color? destaque}) {
  if (t.valor == 'forven') return AppPalette.dark(brand: primaria).comDestaque(destaque);
  if (t.valor == 'claro') return AppPalette.light(brand: primaria).comDestaque(destaque);

  final cta = primaria ?? t.primaria;
  final acc = destaque ?? t.destaque;
  Color mix(Color a, Color b, double f) => Color.lerp(a, b, f)!;

  if (t.escuro) {
    return AppPalette(
      background: t.fundo,
      surface: mix(t.fundo, t.superficie, 0.6),
      surfaceRaised: t.superficie,
      surfaceSunken: mix(t.fundo, Colors.black, 0.35),
      outline: mix(t.superficie, t.texto, 0.10),
      outlineStrong: mix(t.superficie, t.texto, 0.20),
      textPrimary: t.texto,
      textSecondary: mix(t.texto, t.fundo, 0.18),
      textMuted: mix(t.texto, t.fundo, 0.40),
      primary: cta,
      primarySoft: cta.withValues(alpha: 0.18),
      onPrimary: corSobre(cta),
      accent: acc,
      accentSoft: acc.withValues(alpha: 0.12),
      onAccent: t.fundo,
      success: const Color(0xFF4ADE80),
      successSoft: const Color(0x244ADE80),
      warning: const Color(0xFFFBBF24),
      warningSoft: const Color(0x24FBBF24),
      danger: const Color(0xFFF87171),
      dangerSoft: const Color(0x24F87171),
      scrim: t.fundo.withValues(alpha: 0.72),
      shadow: Colors.black.withValues(alpha: 0.6),
      imageOverlay: mix(t.fundo, Colors.black, 0.4),
      glow: cta.withValues(alpha: 0.26),
      brandLine: t.texto.withValues(alpha: 0.09),
      logo: t.texto,
    );
  }
  return AppPalette(
    background: t.fundo,
    surface: t.superficie,
    surfaceRaised: t.superficie,
    surfaceSunken: mix(t.fundo, t.texto, 0.04),
    outline: mix(t.fundo, t.texto, 0.11),
    outlineStrong: mix(t.fundo, t.texto, 0.22),
    textPrimary: t.texto,
    textSecondary: mix(t.texto, t.fundo, 0.28),
    textMuted: mix(t.texto, t.fundo, 0.42),
    primary: cta,
    primarySoft: cta.withValues(alpha: 0.12),
    onPrimary: corSobre(cta),
    accent: acc,
    accentSoft: acc.withValues(alpha: 0.08),
    onAccent: corSobre(acc),
    success: const Color(0xFF15803D),
    successSoft: const Color(0x1A15803D),
    warning: const Color(0xFFB45309),
    warningSoft: const Color(0x1AB45309),
    danger: const Color(0xFFDC2626),
    dangerSoft: const Color(0x1ADC2626),
    scrim: t.texto.withValues(alpha: 0.6),
    shadow: t.texto.withValues(alpha: 0.15),
    imageOverlay: mix(t.texto, Colors.black, 0.5),
    glow: cta.withValues(alpha: 0.14),
    brandLine: t.texto.withValues(alpha: 0.07),
    logo: t.texto,
  );
}

/// Pares de fontes oferecidos no ERP (título, texto).
(String, String) familiasDaFonte(String fonte) => switch (fonte) {
  'classica' => ('Playfair Display', 'Karla'),
  'moderna' => ('Poppins', 'Poppins'),
  'elegante' => ('Cormorant Garamond', 'Inter'),
  _ => ('Public Sans', 'Public Sans'),
};

/// Multiplicador dos raios de canto (reto | suave | arredondado).
double escalaDosCantos(String cantos) => switch (cantos) {
  'reto' => 0.4,
  'arredondado' => 1.45,
  _ => 1.0,
};
