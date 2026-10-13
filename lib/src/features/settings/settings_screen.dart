import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/navigation.dart';
import '../../core/brand/forven_brand.dart';
import '../../core/theme/app_palette.dart';
import '../../core/utils/format.dart';
import '../../core/theme/temas.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/toast.dart';
import '../../data/models/loja.dart';
import '../../data/repositories/cardapio_repository.dart';
import '../../state/providers.dart';
import '../../state/settings.dart';
import '../offline/offline_host.dart';
import '../waiter/chamados_garcom.dart';

/// No totem as configurações ficam atrás de PIN; no celular do garçom, não.
Future<void> abrirConfiguracoes(BuildContext context, WidgetRef ref) async {
  final s = ref.read(settingsProvider);
  if (s.configurado && s.modo == ModoOperacao.totem) {
    HapticFeedback.heavyImpact();
    // PIN definido no ERP (conferido pelo hash, sem internet) ou, sem ele, o PIN local.
    final seguranca = ref.read(cardapioProvider).value?.loja.seguranca;
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: context.palette.scrim,
      builder: (_) => PinDialog(verificar: (pin) => seguranca != null ? conferirPin(pin, seguranca) : pin == s.pin),
    );
    if (ok != true || !context.mounted) return;
  }
  await pushPage<void>(context, (_) => const SettingsScreen());
}

// ============================================================================ PIN

/// Mesma conta do ERP: sha256(sal + PIN).
bool conferirPin(String pin, SegurancaPin s) => sha256.convert(utf8.encode(s.sal + pin)).toString() == s.hash;

class PinDialog extends StatefulWidget {
  const PinDialog({super.key, required this.verificar, this.titulo = 'Área do estabelecimento'});

  /// O tamanho do PIN do ERP não é conhecido (4 a 8 números): confere a cada dígito.
  final bool Function(String pin) verificar;
  final String titulo;

  static const minimo = 4;
  static const maximo = 8;

  @override
  State<PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<PinDialog> {
  String _digitado = '';
  int _erros = 0;

  void _tecla(String d) {
    if (_digitado.length >= PinDialog.maximo) return;
    HapticFeedback.selectionClick();
    setState(() => _digitado += d);
    if (_digitado.length >= PinDialog.minimo && widget.verificar(_digitado)) {
      Navigator.of(context).pop(true);
    } else if (_digitado.length == PinDialog.maximo) {
      _errou();
    }
  }

  void _confirmar() {
    if (_digitado.length >= PinDialog.minimo && widget.verificar(_digitado)) {
      Navigator.of(context).pop(true);
    } else if (_digitado.isNotEmpty) {
      _errou();
    }
  }

  void _errou() {
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) {
        setState(() {
          _erros++;
          _digitado = '';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget key(String label, {IconData? icon, VoidCallback? onTap}) => Pressable(
      onTap: onTap ?? () => _tecla(label),
      borderRadius: BorderRadius.circular(40),
      scale: 0.9,
      semanticLabel: icon != null ? 'Apagar' : label,
      child: Container(
        width: 72,
        height: 72,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: icon != null ? Colors.transparent : p.surfaceRaised,
          shape: BoxShape.circle,
          border: icon != null ? null : Border.all(color: p.outline),
        ),
        child: icon != null ? Icon(icon, color: p.textSecondary) : Text(label, style: context.text.headlineMedium),
      ),
    );

    return Dialog(
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(borderRadius: Radii.rXl),
      child: Padding(
        padding: const EdgeInsets.all(Space.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.lockKeyhole, size: 36, color: p.accent),
            const SizedBox(height: Space.sm),
            Text(widget.titulo, style: context.text.headlineSmall),
            const SizedBox(height: Space.xxs),
            Text(
              _erros > 0 ? 'PIN incorreto. Tente de novo.' : 'Digite o PIN para continuar',
              style: context.text.bodyMedium?.copyWith(color: _erros > 0 ? p.danger : null),
            ),
            const SizedBox(height: Space.lg),
            Animate(
              key: ValueKey(_erros),
              effects: _erros > 0 ? [ShakeEffect(hz: 6, offset: const Offset(10, 0), duration: 400.ms)] : const [],
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < (_digitado.length < PinDialog.minimo ? PinDialog.minimo : _digitado.length); i++)
                    AnimatedContainer(
                      duration: Motion.fast,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < _digitado.length ? p.primary : Colors.transparent,
                        border: Border.all(color: i < _digitado.length ? p.primary : p.outlineStrong, width: 2),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Space.lg),
            for (final row in const [
              ['1', '2', '3'],
              ['4', '5', '6'],
              ['7', '8', '9'],
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: Space.sm),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final d in row) Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: key(d)),
                  ],
                ),
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: key(
                    '<',
                    icon: LucideIcons.delete,
                    onTap: () => _digitado.isEmpty
                        ? null
                        : setState(() => _digitado = _digitado.substring(0, _digitado.length - 1)),
                  ),
                ),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: key('0')),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: key('ok', icon: LucideIcons.check, onTap: _confirmar),
                ),
              ],
            ),
            const SizedBox(height: Space.xs),
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          ],
        ),
      ),
    );
  }
}

// ============================================================================ tela

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _testando = false;
  bool _sincronizando = false;

  Future<void> _sincronizar() async {
    setState(() => _sincronizando = true);
    final mudou = await ref.read(cardapioProvider.notifier).sincronizar();
    await ref.read(filaPedidosProvider.notifier).processar();
    if (!mounted) return;
    setState(() => _sincronizando = false);
    final sync = ref.read(syncProvider);
    if (sync.offline) {
      showToast(context, sync.erro ?? 'Sem conexão com o ERP', icon: LucideIcons.cloudOff, error: true);
    } else {
      showToast(context, mudou ? 'Cardápio atualizado' : 'O cardápio já estava em dia');
    }
  }

  Future<void> _testar() async {
    setState(() => _testando = true);
    try {
      await ref.read(repositoryProvider).testarConexao();
      if (mounted) showToast(context, 'Conexão com o ERP funcionando');
    } on AppException catch (e) {
      if (mounted) showToast(context, e.mensagem, icon: LucideIcons.circleAlert, error: true);
    } catch (_) {
      if (mounted) showToast(context, 'Falha ao conectar', icon: LucideIcons.circleAlert, error: true);
    } finally {
      if (mounted) setState(() => _testando = false);
    }
  }

  Future<void> _alterarPin() async {
    final atual = ref.read(settingsProvider).pin;
    final novo = await showDialog<String>(context: context, builder: (_) => const _NovoPinDialog());
    if (novo == null || novo == atual) return;
    await ref.read(settingsProvider.notifier).setPin(novo);
    if (mounted) showToast(context, 'PIN alterado');
  }

  Future<void> _reparear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Parear novamente?'),
        content: const Text('O aparelho volta para a tela de configuração inicial. A sacola atual será descartada.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Continuar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    novoAtendimento(ref);
    Navigator.of(context).popUntil((r) => r.isFirst);
    await ref.read(settingsProvider.notifier).resetar();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    final cardapio = ref.watch(cardapioProvider).value;
    final sync = ref.watch(syncProvider);
    final fila = ref.watch(filaPedidosProvider);
    final pinDoErp = cardapio?.loja.seguranca != null;
    final temaErp = cardapio?.loja.aparencia.tema ?? 'forven';

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
        title: const Text('Configurações'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: EdgeInsets.fromLTRB(context.gutter, Space.xs, context.gutter, Space.xxl),
            children: [
              _Grupo(
                titulo: 'Conexão com o Forven ERP',
                children: [
                  _Linha(
                    icon: s.demo ? LucideIcons.flaskConical : LucideIcons.plugZap,
                    titulo: s.demo ? 'Modo demonstração' : 'Conectado',
                    subtitulo: s.demo ? 'Usando o cardápio de exemplo, sem ERP' : s.erpUrl,
                    trailing: StatusPill(
                      label: s.demo
                          ? 'Demo'
                          : sync.offline
                          ? 'Offline'
                          : 'Online',
                      color: s.demo || sync.offline ? p.warning : p.success,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.md),
                    child: Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            label: 'Testar conexão',
                            icon: LucideIcons.activity,
                            tone: ButtonTone.secondary,
                            loading: _testando,
                            height: 48,
                            onPressed: _testar,
                          ),
                        ),
                        const SizedBox(width: Space.sm),
                        Expanded(
                          child: AppButton(
                            label: 'Parear de novo',
                            icon: LucideIcons.qrCode,
                            tone: ButtonTone.secondary,
                            height: 48,
                            onPressed: _reparear,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              _Grupo(
                titulo: 'Operação',
                children: [
                  Padding(
                    padding: const EdgeInsets.all(Space.md),
                    child: SegmentedButton<ModoOperacao>(
                      segments: const [
                        ButtonSegment(value: ModoOperacao.totem, icon: Icon(LucideIcons.tablet), label: Text('Totem')),
                        ButtonSegment(
                          value: ModoOperacao.garcom,
                          icon: Icon(LucideIcons.smartphone),
                          label: Text('Garçom'),
                        ),
                      ],
                      selected: {s.modo},
                      showSelectedIcon: false,
                      onSelectionChanged: (v) async {
                        Navigator.of(context).popUntil((r) => r.isFirst);
                        novoAtendimento(ref);
                        await n.setModo(v.first);
                      },
                    ),
                  ),
                  if (s.modo == ModoOperacao.garcom && (cardapio?.garcons.isNotEmpty ?? false))
                    _Linha(
                      icon: LucideIcons.userRound,
                      titulo: 'Garçom deste celular',
                      subtitulo:
                          [
                            for (final g in cardapio!.garcons)
                              if (g.id == s.garcomId) '${g.nome} · recebe os chamados das mesas dele',
                          ].firstOrNull ??
                          'Todos os chamados (gerente/caixa)',
                      onTap: () => escolherGarcom(context),
                    ),
                  if (s.modo == ModoOperacao.totem)
                    _Linha(
                      icon: LucideIcons.armchair,
                      titulo: 'Mesa fixa deste totem',
                      subtitulo: s.mesaFixa == null
                          ? 'Nenhuma — balcão/entrada (cliente informa a mesa)'
                          : 'Pedidos vão para a mesa ${s.mesaFixa}',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (s.mesaFixa != null)
                            IconButton(
                              tooltip: 'Remover mesa fixa',
                              onPressed: () => n.setMesaFixa(null),
                              icon: Icon(LucideIcons.x, color: p.textMuted),
                            ),
                          QuantityStepper(
                            value: s.mesaFixa ?? 0,
                            min: 0,
                            max: 99,
                            size: 40,
                            onChanged: (v) => n.setMesaFixa(v == 0 ? null : v),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              _Grupo(
                titulo: 'Aparência',
                children: [
                  Padding(
                    padding: const EdgeInsets.all(Space.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'O tema vem de E-commerce › Simuladores › Cardápio › Aparência. '
                          'Escolha outro só se este aparelho precisar ser diferente.',
                          style: context.text.bodyMedium,
                        ),
                        const SizedBox(height: Space.md),
                        Wrap(
                          spacing: Space.sm,
                          runSpacing: Space.sm,
                          children: [
                            _TemaChip(
                              preset: temaPorValor(temaErp),
                              rotulo: 'Do ERP · ${temaPorValor(temaErp).nome}',
                              selecionado: s.temaLocal.isEmpty,
                              onTap: () => n.setTemaLocal(''),
                            ),
                            for (final t in temasCardapio)
                              _TemaChip(
                                preset: t,
                                rotulo: t.nome,
                                selecionado: s.temaLocal == t.valor,
                                onTap: () => n.setTemaLocal(t.valor),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              _Grupo(
                titulo: 'Cardápio',
                children: [
                  _Linha(
                    icon: LucideIcons.bookOpenText,
                    titulo: cardapio?.loja.nome ?? 'Cardápio',
                    subtitulo: cardapio == null
                        ? 'Carregando…'
                        : '${cardapio.categorias.length} categorias · ${cardapio.produtos.length} itens · '
                              'gerenciado em E-commerce › Simuladores › Cardápio',
                  ),
                  _Linha(
                    icon: LucideIcons.hardDriveDownload,
                    titulo: 'Funciona sem internet',
                    subtitulo: [
                      sync.ultimaSync == null ? 'Ainda não sincronizado' : 'Atualizado ${desde(sync.ultimaSync!)}',
                      if (s.demo)
                        'modo demonstração'
                      else
                        'busca mudanças a cada ${cardapio?.loja.intervaloSincronizacaoMin ?? 5} min',
                      if (sync.imagensTotal > 0) '${sync.imagensProntas}/${sync.imagensTotal} fotos salvas',
                    ].join(' · '),
                    trailing: sync.sincronizando || _sincronizando
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))
                        : null,
                  ),
                  if (fila.isNotEmpty)
                    _Linha(
                      icon: LucideIcons.cloudUpload,
                      titulo: '${plural(fila.length, 'pedido aguardando', 'pedidos aguardando')} envio',
                      subtitulo: fila.first.ultimoErro ?? 'Serão enviados assim que o ERP responder',
                      trailing: StatusPill(label: '${fila.length}', color: p.warning),
                    ),
                  _Linha(
                    icon: LucideIcons.refreshCw,
                    titulo: 'Sincronizar agora',
                    subtitulo: 'Busca preços, fotos e disponibilidade no ERP e envia pedidos pendentes',
                    onTap: _sincronizando ? null : _sincronizar,
                  ),
                ],
              ),
              _Grupo(
                titulo: 'Segurança',
                children: [
                  if (pinDoErp)
                    const _Linha(
                      icon: LucideIcons.shieldCheck,
                      titulo: 'PIN definido no ERP',
                      subtitulo: 'Para trocar: E-commerce › Simuladores › Cardápio › Segurança',
                    )
                  else
                    _Linha(
                      icon: LucideIcons.rectangleEllipsis,
                      titulo: 'Alterar PIN',
                      subtitulo: 'Protege estas configurações no totem (ou defina no ERP para todos os aparelhos)',
                      onTap: _alterarPin,
                    ),
                ],
              ),
              const SizedBox(height: Space.lg),
              Center(
                child: Column(
                  children: [
                    ForvenLogo(height: 24, color: p.logo, badge: 'Cardápio'),
                    const SizedBox(height: Space.sm),
                    Text('Integrado ao Forven ERP', style: context.text.labelMedium),
                    Text('Versão 1.0.0', style: context.text.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TemaChip extends StatelessWidget {
  const _TemaChip({required this.preset, required this.rotulo, required this.selecionado, required this.onTap});

  final TemaPreset preset;
  final String rotulo;
  final bool selecionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget bolinha(Color c) => Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: c,
        shape: BoxShape.circle,
        border: Border.all(color: p.outlineStrong.withValues(alpha: 0.6)),
      ),
    );
    return Pressable(
      onTap: onTap,
      borderRadius: Radii.rPill,
      selected: selecionado,
      semanticLabel: 'Tema $rotulo',
      child: AnimatedContainer(
        duration: Motion.base,
        padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 10),
        decoration: BoxDecoration(
          color: selecionado ? p.primarySoft : p.surfaceRaised,
          borderRadius: Radii.rPill,
          border: Border.all(color: selecionado ? p.primary : p.outline, width: selecionado ? 2 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            bolinha(preset.fundo),
            const SizedBox(width: 3),
            bolinha(preset.primaria),
            const SizedBox(width: 3),
            bolinha(preset.destaque),
            const SizedBox(width: Space.xs),
            Text(rotulo, style: context.text.labelMedium),
          ],
        ),
      ),
    );
  }
}

class _Grupo extends StatelessWidget {
  const _Grupo({required this.titulo, required this.children});

  final String titulo;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: Space.xs, bottom: Space.xs),
            child: Eyebrow(titulo, color: p.textMuted),
          ),
          Container(
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: Radii.rLg,
              border: Border.all(color: p.outline),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
        ],
      ),
    );
  }
}

class _Linha extends StatelessWidget {
  const _Linha({required this.icon, required this.titulo, required this.subtitulo, this.trailing, this.onTap});

  final IconData icon;
  final String titulo;
  final String subtitulo;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final row = Padding(
      padding: const EdgeInsets.all(Space.md),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: p.accentSoft, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: p.accent),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: context.text.titleSmall),
                const SizedBox(height: 2),
                Text(subtitulo, style: context.text.bodySmall),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: Space.sm), trailing!],
          if (onTap != null && trailing == null) Icon(LucideIcons.chevronRight, size: 18, color: p.textMuted),
        ],
      ),
    );
    return onTap == null ? row : Pressable(onTap: onTap, scale: 0.99, child: row);
  }
}

class _NovoPinDialog extends StatefulWidget {
  const _NovoPinDialog();

  @override
  State<_NovoPinDialog> createState() => _NovoPinDialogState();
}

class _NovoPinDialogState extends State<_NovoPinDialog> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final valido = RegExp(r'^\d{4,6}$').hasMatch(_c.text);
    return AlertDialog(
      title: const Text('Novo PIN'),
      content: TextField(
        controller: _c,
        autofocus: true,
        keyboardType: TextInputType.number,
        obscureText: true,
        maxLength: 6,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(labelText: 'De 4 a 6 números'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: valido ? () => Navigator.pop(context, _c.text) : null, child: const Text('Salvar')),
      ],
    );
  }
}
