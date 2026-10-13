import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/pressable.dart';
import '../../state/providers.dart';
import '../../state/settings.dart';

/// Mantém o aparelho em dia com o ERP sem atrapalhar o cliente:
/// - busca mudanças no cardápio a cada N minutos (definido no ERP) e ao voltar do segundo plano;
/// - entrega os pedidos da fila a cada 20 s enquanto houver algum pendente.
class OfflineHost extends ConsumerStatefulWidget {
  const OfflineHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<OfflineHost> createState() => _OfflineHostState();
}

class _OfflineHostState extends ConsumerState<OfflineHost> {
  Timer? _cardapio;
  Timer? _fila;
  late final AppLifecycleListener _ciclo;

  @override
  void initState() {
    super.initState();
    _ciclo = AppLifecycleListener(onResume: _acordar);
    _fila = Timer.periodic(const Duration(seconds: 20), (_) => _entregarPendentes());
    ref.listenManual(
      cardapioProvider.select((c) => c.value?.loja.intervaloSincronizacaoMin),
      (_, min) => _agendar(min ?? 5),
      fireImmediately: true,
    );
  }

  void _acordar() {
    ref.read(cardapioProvider.notifier).sincronizar();
    _entregarPendentes();
  }

  /// Pedidos e chamados de garçom feitos sem internet.
  void _entregarPendentes() {
    ref.read(filaPedidosProvider.notifier).processar();
    ref.read(chamadoMesaProvider.notifier).reenviarPendente();
    // Tablet da mesa: atualiza "Meus pedidos" com o que o ERP tem para a mesa.
    final s = ref.read(settingsProvider);
    if (s.configurado && s.modo == ModoOperacao.totem && s.mesaFixa != null) {
      ref.read(meusPedidosProvider.notifier).sincronizarMesa(s.mesaFixa!);
    }
  }

  /// Em desenvolvimento (flutter run), confere o ERP a cada 10 s para ver na hora o que
  /// muda no painel; sem mudança a resposta tem poucos bytes. Em produção, vale o ERP.
  static const intervaloDev = Duration(seconds: 10);

  void _agendar(int minutos) {
    _cardapio?.cancel();
    _cardapio = Timer.periodic(
      kDebugMode ? intervaloDev : Duration(minutes: minutos),
      (_) => ref.read(cardapioProvider.notifier).sincronizar(),
    );
  }

  @override
  void dispose() {
    _cardapio?.cancel();
    _fila?.cancel();
    _ciclo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A internet voltou: entrega o que ficou na fila na hora.
    ref.listen(syncProvider.select((s) => s.conexao), (antes, agora) {
      if (agora == Conexao.online && antes != Conexao.online) _entregarPendentes();
    });
    return widget.child;
  }
}

/// Selo discreto no topo: só aparece sem internet ou com pedidos aguardando envio.
class SyncIndicator extends ConsumerWidget {
  const SyncIndicator({super.key, this.compact = false, this.padding = EdgeInsets.zero});

  /// Só o ícone (barras estreitas).
  final bool compact;

  /// Espaço em volta, aplicado só quando o selo aparece.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final offline = ref.watch(syncProvider.select((s) => s.offline));
    final fila = ref.watch(filaPedidosProvider.select((f) => f.length));
    if (!offline && fila == 0) return const SizedBox.shrink();

    final (icone, rotulo, cor) = offline
        ? (LucideIcons.cloudOff, fila > 0 ? 'Offline · $fila na fila' : 'Offline', p.warning)
        : (LucideIcons.cloudUpload, 'Enviando $fila', p.accent);

    final selo = Pressable(
      onTap: () => mostrarStatusConexao(context),
      borderRadius: Radii.rPill,
      semanticLabel: '$rotulo. Toque para detalhes',
      child: AnimatedContainer(
        duration: Motion.base,
        height: 36,
        padding: EdgeInsets.symmetric(horizontal: compact ? 9 : Space.sm),
        decoration: BoxDecoration(
          color: cor.withValues(alpha: 0.14),
          borderRadius: Radii.rPill,
          border: Border.all(color: cor.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 17, color: cor),
            if (!compact) ...[
              const SizedBox(width: 6),
              Text(rotulo, style: context.text.labelMedium?.copyWith(color: cor)),
            ],
          ],
        ),
      ),
    );
    return Padding(padding: padding, child: selo);
  }
}

/// Explica ao cliente (sem assustar) o que acontece sem internet.
Future<void> mostrarStatusConexao(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  constraints: const BoxConstraints(maxWidth: 560),
  builder: (_) => const _StatusConexao(),
);

class _StatusConexao extends ConsumerWidget {
  const _StatusConexao();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final sync = ref.watch(syncProvider);
    final fila = ref.watch(filaPedidosProvider);

    final titulo = sync.offline ? 'Sem conexão no momento' : 'Conectado';
    final texto = sync.offline
        ? 'Pode continuar pedindo normalmente: o cardápio está salvo neste aparelho e os pedidos '
              'são enviados sozinhos assim que a internet voltar.'
        : fila.isEmpty
        ? 'Tudo em dia com o estabelecimento.'
        : 'Enviando os pedidos que ficaram guardados.';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: (sync.offline ? p.warning : p.success).withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    sync.offline ? LucideIcons.cloudOff : LucideIcons.cloudCheck,
                    color: sync.offline ? p.warning : p.success,
                  ),
                ),
                const SizedBox(width: Space.md),
                Expanded(child: Text(titulo, style: context.text.headlineSmall)),
              ],
            ),
            const SizedBox(height: Space.md),
            Text(texto, style: context.text.bodyLarge),
            if (fila.isNotEmpty) ...[
              const SizedBox(height: Space.md),
              for (final f in fila)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.xs),
                  child: Row(
                    children: [
                      Icon(LucideIcons.clock, size: 18, color: p.textMuted),
                      const SizedBox(width: Space.xs),
                      Expanded(
                        child: Text(
                          '${itensLabel(f.previa.quantidadeItens)} · ${money(f.previa.total)}'
                          '${f.novo.mesa != null ? ' · Mesa ${f.novo.mesa}' : ''}',
                          style: context.text.titleSmall,
                        ),
                      ),
                      Text(hora(f.novo.criadoEm), style: context.text.bodySmall),
                    ],
                  ),
                ),
            ],
            if (sync.ultimaSync != null) ...[
              const SizedBox(height: Space.sm),
              Text('Cardápio atualizado ${desde(sync.ultimaSync!)}', style: context.text.bodySmall),
            ],
            const SizedBox(height: Space.lg),
            AppButton(
              label: sync.sincronizando ? 'Verificando…' : 'Tentar agora',
              icon: LucideIcons.refreshCw,
              tone: ButtonTone.secondary,
              loading: sync.sincronizando,
              onPressed: () {
                ref.read(cardapioProvider.notifier).sincronizar();
                ref.read(filaPedidosProvider.notifier).processar();
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// "agora há pouco", "há 5 min", "há 2 h", "em 12/10 às 14:05".
String desde(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'agora há pouco';
  if (d.inMinutes < 60) return 'há ${d.inMinutes} min';
  if (d.inHours < 24) return 'há ${d.inHours} h';
  return 'em ${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')} às ${hora(t)}';
}

String hora(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
