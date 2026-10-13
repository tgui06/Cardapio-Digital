import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/buttons.dart';
import '../../state/providers.dart';
import '../../state/settings.dart';

/// No totem, volta para a tela inicial quando o cliente abandona o pedido.
class InactivityGuard extends ConsumerStatefulWidget {
  const InactivityGuard({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<InactivityGuard> createState() => _InactivityGuardState();
}

class _InactivityGuardState extends ConsumerState<InactivityGuard> {
  Timer? _timer;
  bool _perguntando = false;

  bool get _ativo {
    final s = ref.read(settingsProvider);
    return s.configurado && s.modo == ModoOperacao.totem;
  }

  int get _segundos => ref.read(cardapioProvider).value?.loja.tempoInatividadeSegundos ?? 90;

  void _reiniciar() {
    _timer?.cancel();
    if (!_ativo || _perguntando) return;
    _timer = Timer(Duration(seconds: _segundos), _expirou);
  }

  Future<void> _expirou() async {
    final nav = rootNavigatorKey.currentState;
    if (nav == null || !_ativo) return;
    final emAtendimento = nav.canPop() || ref.read(cartProvider).isNotEmpty;
    if (!emAtendimento) return _reiniciar();

    _perguntando = true;
    final continuar = await showDialog<bool>(
      context: nav.context,
      barrierDismissible: false,
      barrierColor: nav.context.palette.scrim,
      builder: (_) => const _AindaAiDialog(),
    );
    _perguntando = false;
    if (continuar != true) {
      novoAtendimento(ref);
      if (ref.read(settingsProvider).mesaFixa == null) ref.read(meusPedidosProvider.notifier).clear();
      nav.popUntil((r) => r.isFirst);
    }
    _reiniciar();
  }

  @override
  void initState() {
    super.initState();
    _reiniciar();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(settingsProvider, (_, _) => _reiniciar());
    return Listener(behavior: HitTestBehavior.translucent, onPointerDown: (_) => _reiniciar(), child: widget.child);
  }
}

class _AindaAiDialog extends StatefulWidget {
  const _AindaAiDialog();

  @override
  State<_AindaAiDialog> createState() => _AindaAiDialogState();
}

class _AindaAiDialogState extends State<_AindaAiDialog> {
  static const _total = 20;
  int _restante = _total;
  late final Timer _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_restante <= 1) {
        t.cancel();
        Navigator.of(context).pop(false);
      } else {
        setState(() => _restante--);
      }
    });
  }

  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Dialog(
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(borderRadius: Radii.rXl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(Space.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 96,
                height: 96,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(end: _restante / _total),
                        duration: const Duration(seconds: 1),
                        builder: (_, v, _) => CircularProgressIndicator(
                          value: v,
                          strokeWidth: 6,
                          strokeCap: StrokeCap.round,
                          backgroundColor: p.surfaceSunken,
                        ),
                      ),
                    ),
                    Text('$_restante', style: context.text.headlineLarge),
                  ],
                ),
              ),
              const SizedBox(height: Space.lg),
              Text('Ainda está aí?', style: context.text.headlineMedium),
              const SizedBox(height: Space.xs),
              Text(
                'Por segurança, vamos recomeçar e limpar a sacola em $_restante segundos.',
                textAlign: TextAlign.center,
                style: context.text.bodyMedium,
              ),
              const SizedBox(height: Space.lg),
              AppButton(
                label: 'Continuar meu pedido',
                icon: LucideIcons.pointer,
                onPressed: () => Navigator.of(context).pop(true),
              ),
              const SizedBox(height: Space.sm),
              AppButton(label: 'Recomeçar', tone: ButtonTone.ghost, onPressed: () => Navigator.of(context).pop(false)),
            ],
          ),
        ),
      ),
    );
  }
}
