import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/brand/forven_brand.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/pressable.dart';
import '../../data/repositories/cardapio_repository.dart';
import '../../data/repositories/erp_cardapio_repository.dart';
import '../../state/providers.dart';
import '../../state/settings.dart';

/// Primeira execução: conectar ao ERP (ou demo) → modo de uso → mesa.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _passo = 0;
  ModoOperacao _modo = ModoOperacao.totem;
  int? _mesa;

  Future<void> _parear() async {
    final r = await showModalBottomSheet<(String, String)>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const PairingSheet(),
    );
    if (r == null) return;
    await ref.read(settingsProvider.notifier).conectarErp(url: r.$1, token: r.$2);
    setState(() => _passo = 1);
  }

  Future<void> _demo() async {
    await ref.read(settingsProvider.notifier).usarDemo();
    setState(() => _passo = 1);
  }

  Future<void> _concluir() => ref
      .read(settingsProvider.notifier)
      .concluirOnboarding(modo: _modo, mesaFixa: _modo == ModoOperacao.totem ? _mesa : null);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    // Painel da marca lado a lado só em telas largas deitadas; em retrato fica empilhado.
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 900 && size.width > size.height;

    final passo = AnimatedSwitcher(
      duration: Motion.slow,
      switchInCurve: Motion.enter,
      switchOutCurve: Motion.exit,
      transitionBuilder: (child, a) => FadeTransition(
        opacity: a,
        child: SlideTransition(
          position: Tween(begin: const Offset(0.04, 0), end: Offset.zero).animate(a),
          child: child,
        ),
      ),
      child: KeyedSubtree(
        key: ValueKey(_passo),
        child: switch (_passo) {
          0 => _PassoConexao(onParear: _parear, onDemo: _demo),
          1 => _PassoModo(
            modo: _modo,
            onModo: (m) => setState(() => _modo = m),
            onVoltar: () => setState(() => _passo = 0),
            onAvancar: () => _modo == ModoOperacao.totem ? setState(() => _passo = 2) : _concluir(),
          ),
          _ => _PassoMesa(
            mesa: _mesa,
            onMesa: (m) => setState(() => _mesa = m),
            onVoltar: () => setState(() => _passo = 1),
            onConcluir: _concluir,
          ),
        },
      ),
    );

    final indicador = Row(
      children: [
        for (var i = 0; i < 3; i++)
          AnimatedContainer(
            duration: Motion.slow,
            margin: const EdgeInsets.only(right: 6),
            width: i == _passo ? 28 : 8,
            height: 8,
            decoration: BoxDecoration(color: i <= _passo ? p.primary : p.outlineStrong, borderRadius: Radii.rPill),
          ),
      ],
    );

    final painel = SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(wide ? Space.xxl : Space.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!wide) ...[
                ForvenLogo(height: 26, color: context.palette.logo, badge: 'Cardápio'),
                const SizedBox(height: Space.xl),
              ],
              indicador,
              const SizedBox(height: Space.lg),
              passo,
            ],
          ),
        ),
      ),
    );

    if (!wide) {
      return Scaffold(
        body: BrandBackdrop(lineColor: p.brandLine, glowColor: p.glow, layout: SymbolLayout.corner, child: painel),
      );
    }

    // Painel da marca: sempre no fundo escuro (marinho), com o grafismo do símbolo em contorno.
    final darkTheme = buildTheme(Brightness.dark);
    return Scaffold(
      body: Row(
        children: [
          Expanded(
            child: Theme(
              data: darkTheme,
              child: Builder(
                builder: (context) {
                  final d = context.palette;
                  return ColoredBox(
                    color: ForvenColors.marinho,
                    child: BrandBackdrop(
                      lineColor: d.brandLine,
                      glowColor: d.glow,
                      child: SafeArea(
                        child: LayoutBuilder(
                          builder: (context, c) => SingleChildScrollView(
                            padding: EdgeInsets.all(context.isShort ? Space.xl : Space.xxl),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: c.maxHeight - (context.isShort ? Space.xl : Space.xxl) * 2,
                              ),
                              child: IntrinsicHeight(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const ForvenLogo(
                                      height: 34,
                                      color: Colors.white,
                                      badge: 'Cardápio',
                                    ).entrance(context),
                                    const Spacer(),
                                    HighlightText(
                                      'Seu cardápio,\n*conectado ao ERP.*',
                                      highlight: d.accent,
                                      style: (context.isShort ? context.text.displaySmall : context.text.displayLarge)
                                          ?.copyWith(color: Colors.white),
                                    ).entrance(context, index: 1),
                                    const SizedBox(height: Space.lg),
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 520),
                                      child: Text(
                                        'Pedidos caem direto como venda no Forven ERP. Preços, fotos e disponibilidade '
                                        'vêm de E-commerce › Simuladores › Cardápio.',
                                        style: context.text.bodyLarge,
                                      ),
                                    ).entrance(context, index: 2),
                                    const SizedBox(height: Space.xl),
                                    Wrap(
                                      spacing: Space.xs,
                                      runSpacing: Space.xs,
                                      children: [
                                        for (final (i, (icon, label)) in const [
                                          (LucideIcons.monitorSmartphone, 'Totem e garçom'),
                                          (LucideIcons.refreshCw, 'Sincronizado com o ERP'),
                                          (LucideIcons.receiptText, 'Pedido vira venda'),
                                        ].indexed)
                                          _Pill(icon: icon, label: label).entrance(context, index: 3 + i),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          SizedBox(
            width: MediaQuery.sizeOf(context).width * 0.48,
            child: Center(child: painel),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: Radii.rPill,
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: p.accent),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelMedium?.copyWith(color: p.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================ passos

class _PassoConexao extends StatelessWidget {
  const _PassoConexao({required this.onParear, required this.onDemo});

  final VoidCallback onParear;
  final VoidCallback onDemo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('Passo 1 de 3'),
        const SizedBox(height: Space.xs),
        Text('Vamos conectar este aparelho', style: context.text.displaySmall),
        const SizedBox(height: Space.sm),
        Text(
          'No Forven ERP, abra E-commerce › Simuladores › Cardápio › Segurança & pareamento e gere o QR Code.',
          style: context.text.bodyLarge,
        ),
        const SizedBox(height: Space.xl),
        _OpcaoGrande(
          icon: LucideIcons.qrCode,
          titulo: 'Parear com o Forven ERP',
          subtitulo: 'Ler o QR Code ou digitar endereço e token',
          destaque: true,
          onTap: onParear,
        ),
        const SizedBox(height: Space.md),
        _OpcaoGrande(
          icon: LucideIcons.sparkles,
          titulo: 'Explorar a demonstração',
          subtitulo: 'Cardápio de exemplo completo, sem precisar do ERP',
          onTap: onDemo,
        ),
      ],
    );
  }
}

class _PassoModo extends StatelessWidget {
  const _PassoModo({required this.modo, required this.onModo, required this.onVoltar, required this.onAvancar});

  final ModoOperacao modo;
  final ValueChanged<ModoOperacao> onModo;
  final VoidCallback onVoltar;
  final VoidCallback onAvancar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('Passo 2 de 3'),
        const SizedBox(height: Space.xs),
        Text('Como ele será usado?', style: context.text.displaySmall),
        const SizedBox(height: Space.xl),
        _OpcaoGrande(
          icon: LucideIcons.tablet,
          titulo: 'Totem de autoatendimento',
          subtitulo: 'O cliente faz o pedido sozinho, no balcão ou na mesa',
          selecionado: modo == ModoOperacao.totem,
          onTap: () => onModo(ModoOperacao.totem),
        ),
        const SizedBox(height: Space.md),
        _OpcaoGrande(
          icon: LucideIcons.smartphone,
          titulo: 'Celular do garçom',
          subtitulo: 'Mapa de mesas e lançamento de pedidos por mesa',
          selecionado: modo == ModoOperacao.garcom,
          onTap: () => onModo(ModoOperacao.garcom),
        ),
        const SizedBox(height: Space.xl),
        Row(
          children: [
            AppButton(label: 'Voltar', tone: ButtonTone.ghost, expand: false, onPressed: onVoltar),
            const SizedBox(width: Space.sm),
            Expanded(
              child: AppButton(
                label: modo == ModoOperacao.totem ? 'Continuar' : 'Concluir',
                icon: LucideIcons.arrowRight,
                onPressed: onAvancar,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PassoMesa extends ConsumerWidget {
  const _PassoMesa({required this.mesa, required this.onMesa, required this.onVoltar, required this.onConcluir});

  final int? mesa;
  final ValueChanged<int?> onMesa;
  final VoidCallback onVoltar;
  final VoidCallback onConcluir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    // Mesas cadastradas no ERP (o cardápio já foi baixado no passo 1).
    final numeros =
        ref.watch(cardapioProvider.select((c) => c.value?.numerosMesas)) ?? [for (var n = 1; n <= 20; n++) n];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('Passo 3 de 3'),
        const SizedBox(height: Space.xs),
        Text('Onde fica o totem?', style: context.text.displaySmall),
        const SizedBox(height: Space.sm),
        Text('Se ele ficar preso a uma mesa, os pedidos já saem com o número dela.', style: context.text.bodyLarge),
        const SizedBox(height: Space.xl),
        _OpcaoGrande(
          icon: LucideIcons.store,
          titulo: 'Balcão ou entrada',
          subtitulo: 'O cliente informa a mesa (ou retira no balcão)',
          selecionado: mesa == null,
          onTap: () => onMesa(null),
        ),
        const SizedBox(height: Space.lg),
        Text('Ou escolha a mesa:', style: context.text.titleMedium),
        const SizedBox(height: Space.sm),
        Wrap(
          spacing: Space.xs,
          runSpacing: Space.xs,
          children: [
            for (final n in numeros)
              Pressable(
                onTap: () => onMesa(n),
                borderRadius: Radii.rMd,
                selected: mesa == n,
                scale: 0.92,
                semanticLabel: 'Mesa $n',
                child: AnimatedContainer(
                  duration: Motion.base,
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: mesa == n ? p.primary : p.surfaceRaised,
                    borderRadius: Radii.rMd,
                    border: Border.all(color: mesa == n ? p.primary : p.outline),
                  ),
                  child: Text(
                    '$n',
                    style: context.text.titleMedium?.copyWith(color: mesa == n ? p.onPrimary : p.textPrimary),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: Space.xl),
        Row(
          children: [
            AppButton(label: 'Voltar', tone: ButtonTone.ghost, expand: false, onPressed: onVoltar),
            const SizedBox(width: Space.sm),
            Expanded(
              child: AppButton(label: 'Começar a usar', icon: LucideIcons.check, onPressed: onConcluir),
            ),
          ],
        ),
      ],
    );
  }
}

class _OpcaoGrande extends StatelessWidget {
  const _OpcaoGrande({
    required this.icon,
    required this.titulo,
    required this.subtitulo,
    required this.onTap,
    this.selecionado = false,
    this.destaque = false,
  });

  final IconData icon;
  final String titulo;
  final String subtitulo;
  final VoidCallback onTap;
  final bool selecionado;
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final ativo = selecionado || destaque;
    return Pressable(
      onTap: onTap,
      borderRadius: Radii.rLg,
      selected: selecionado,
      semanticLabel: '$titulo. $subtitulo',
      child: AnimatedContainer(
        duration: Motion.base,
        padding: const EdgeInsets.all(Space.lg - 4),
        decoration: BoxDecoration(
          color: selecionado ? p.primarySoft : p.surfaceRaised,
          borderRadius: Radii.rLg,
          border: Border.all(color: ativo ? p.primary : p.outline, width: selecionado ? 2 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: ativo ? p.primary : p.surfaceSunken,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 28, color: ativo ? p.onPrimary : p.textSecondary),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: context.text.titleMedium),
                  const SizedBox(height: 2),
                  Text(subtitulo, style: context.text.bodySmall),
                ],
              ),
            ),
            Icon(
              selecionado ? LucideIcons.circleCheck : LucideIcons.chevronRight,
              color: selecionado ? p.accent : p.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================ pareamento

/// Aceita `{"url": "...", "token": "..."}` ou `forven-cardapio://parear?url=...&token=...`.
(String, String)? parsePairing(String raw) {
  final s = raw.trim();
  try {
    final j = jsonDecode(s);
    if (j is Map && j['url'] is String && j['token'] is String) return (j['url'] as String, j['token'] as String);
  } catch (_) {}
  final u = Uri.tryParse(s);
  final url = u?.queryParameters['url'];
  final token = u?.queryParameters['token'];
  if (url != null && token != null) return (url, token);
  return null;
}

class PairingSheet extends StatefulWidget {
  const PairingSheet({super.key});

  @override
  State<PairingSheet> createState() => _PairingSheetState();
}

class _PairingSheetState extends State<PairingSheet> {
  final _url = TextEditingController();
  final _token = TextEditingController();
  bool _camera = true;
  bool _testando = false;
  String? _erro;

  @override
  void dispose() {
    _url.dispose();
    _token.dispose();
    super.dispose();
  }

  Future<void> _conectar(String url, String token) async {
    setState(() {
      _testando = true;
      _erro = null;
    });
    try {
      await ErpCardapioRepository(baseUrl: url, token: token).testarConexao();
      if (mounted) Navigator.of(context).pop((url, token));
    } on AppException catch (e) {
      setState(() => _erro = e.mensagem);
    } catch (_) {
      setState(() => _erro = 'Não foi possível validar o endereço informado.');
    } finally {
      if (mounted) setState(() => _testando = false);
    }
  }

  void _onDetect(BarcodeCapture c) {
    if (_testando) return;
    for (final b in c.barcodes) {
      final r = b.rawValue == null ? null : parsePairing(b.rawValue!);
      if (r != null) {
        _url.text = r.$1;
        _token.text = r.$2;
        setState(() => _camera = false);
        _conectar(r.$1, r.$2);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.lg + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Parear com o Forven ERP', style: context.text.headlineMedium),
            const SizedBox(height: Space.md),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, icon: Icon(LucideIcons.camera), label: Text('Ler QR Code')),
                ButtonSegment(value: false, icon: Icon(LucideIcons.keyboard), label: Text('Digitar')),
              ],
              selected: {_camera},
              showSelectedIcon: false,
              onSelectionChanged: (v) => setState(() => _camera = v.first),
            ),
            const SizedBox(height: Space.lg),
            if (_camera)
              ClipRRect(
                borderRadius: Radii.rLg,
                child: SizedBox(
                  height: 320,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      MobileScanner(
                        onDetect: _onDetect,
                        errorBuilder: (context, error) => ColoredBox(
                          color: p.surfaceSunken,
                          child: EmptyState(
                            icon: LucideIcons.cameraOff,
                            title: 'Câmera indisponível',
                            message: 'Permita o acesso à câmera ou use a opção "Digitar".',
                          ),
                        ),
                      ),
                      IgnorePointer(
                        child: Center(
                          child: Container(
                            width: 220,
                            height: 220,
                            decoration: BoxDecoration(
                              borderRadius: Radii.rLg,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              TextField(
                controller: _url,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: 'Endereço do ERP',
                  hintText: 'https://suaempresa.forven.com.br',
                  prefixIcon: Icon(LucideIcons.globe, color: p.textMuted),
                ),
              ),
              const SizedBox(height: Space.md),
              TextField(
                controller: _token,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: 'Token do simulador',
                  hintText: 'sim_…',
                  prefixIcon: Icon(LucideIcons.keyRound, color: p.textMuted),
                ),
              ),
            ],
            if (_erro != null) ...[
              const SizedBox(height: Space.md),
              Container(
                padding: const EdgeInsets.all(Space.sm),
                decoration: BoxDecoration(color: p.dangerSoft, borderRadius: Radii.rMd),
                child: Row(
                  children: [
                    Icon(LucideIcons.circleAlert, color: p.danger),
                    const SizedBox(width: Space.xs),
                    Expanded(
                      child: Text(_erro!, style: context.text.labelMedium?.copyWith(color: p.danger)),
                    ),
                  ],
                ),
              ),
            ],
            if (!_camera || _testando) ...[
              const SizedBox(height: Space.lg),
              AppButton(
                label: 'Testar e conectar',
                icon: LucideIcons.plugZap,
                loading: _testando,
                onPressed: () {
                  final url = _url.text.trim();
                  final token = _token.text.trim();
                  if (!url.startsWith('http') || token.isEmpty) {
                    setState(() => _erro = 'Informe um endereço começando com http(s):// e o token.');
                    return;
                  }
                  _conectar(url, token);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
