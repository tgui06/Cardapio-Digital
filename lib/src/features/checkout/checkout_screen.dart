import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/brand/forven_brand.dart';
import '../../core/navigation.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/pressable.dart';
import '../../data/models/loja.dart';
import '../../data/models/pedido.dart';
import '../../data/repositories/cardapio_repository.dart';
import '../../state/providers.dart';
import '../../state/settings.dart';
import '../orders/order_success_screen.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

enum _Campo { consumo, mesa, nome, pagamento }

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  /// Gerado uma vez: reenviar após erro não duplica a Venda no ERP.
  final _codigoAcesso = uuid.v4();
  late final TextEditingController _nome = TextEditingController(text: ref.read(sessaoProvider).nome);
  late final TextEditingController _obs = TextEditingController(text: ref.read(sessaoProvider).observacao);
  final _keys = {for (final c in _Campo.values) c: GlobalKey()};
  final _erros = <_Campo>{};
  bool _enviando = false;
  bool _mostrarObs = false;

  @override
  void initState() {
    super.initState();
    _mostrarObs = _obs.text.isNotEmpty;
    // Provider não pode mudar durante o build: aplica os padrões após o 1º frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final loja = ref.read(cardapioProvider).requireValue.loja;
      final s = ref.read(sessaoProvider);
      final n = ref.read(sessaoProvider.notifier);
      if (s.consumo == null && loja.modosConsumo.length == 1) n.setConsumo(loja.modosConsumo.first);
      if (s.formaPagamentoId == null && loja.formasPagamento.isNotEmpty) {
        n.setFormaPagamento(loja.formasPagamento.first.id);
      }
    });
  }

  @override
  void dispose() {
    _nome.dispose();
    _obs.dispose();
    super.dispose();
  }

  bool get _garcom => ref.read(settingsProvider).modo == ModoOperacao.garcom;

  Set<_Campo> _validar() {
    final loja = ref.read(cardapioProvider).requireValue.loja;
    final s = ref.read(sessaoProvider);
    return {
      if (s.consumo == null) _Campo.consumo,
      if (s.consumo == TipoConsumo.local && s.mesa == null && _garcom) _Campo.mesa,
      if (loja.exigirNomeCliente && !_garcom && _nome.text.trim().length < 2 && s.mesa == null) _Campo.nome,
      if (loja.formasPagamento.isNotEmpty && s.formaPagamentoId == null) _Campo.pagamento,
    };
  }

  Future<void> _enviar() async {
    final erros = _validar();
    setState(() {
      _erros
        ..clear()
        ..addAll(erros);
    });
    if (erros.isNotEmpty) {
      HapticFeedback.heavyImpact();
      final primeiro = _Campo.values.firstWhere(erros.contains);
      final ctx = _keys[primeiro]?.currentContext;
      if (ctx != null) {
        await Scrollable.ensureVisible(ctx, duration: Motion.slow, curve: Motion.emphasized, alignment: 0.1);
      }
      return;
    }

    final sessaoN = ref.read(sessaoProvider.notifier)
      ..setNome(_nome.text.trim())
      ..setObservacao(_obs.text.trim());
    final s = ref.read(sessaoProvider);
    final itens = ref.read(cartProvider);
    final settings = ref.read(settingsProvider);
    final loja = ref.read(cardapioProvider).requireValue.loja;
    final forma = loja.formasPagamento.where((f) => f.id == s.formaPagamentoId).firstOrNull;

    final novo = NovoPedido(
      codigoAcesso: _codigoAcesso,
      tipoConsumo: s.consumo!,
      mesa: s.consumo == TipoConsumo.local ? s.mesa : null,
      nomeCliente: s.nome,
      formaPagamentoId: s.formaPagamentoId,
      observacao: s.observacao,
      itens: itens.map((i) => i.toPedidoItem()).toList(),
      origem: settings.modo.api,
      criadoEm: DateTime.now(),
    );
    // Como o pedido aparece se a internet estiver fora (o envio fica na fila).
    final previa = Pedido.pendente(
      novo,
      subtotal: ref.read(cartSubtotalProvider),
      taxaServico: ref.read(cartTaxaProvider),
      formaPagamento: forma?.nome ?? '',
      previsaoMin: loja.tempoMedioPreparoMin,
    );

    setState(() => _enviando = true);
    try {
      final pedido = await ref.read(filaPedidosProvider.notifier).registrar(novo, previa);
      HapticFeedback.mediumImpact();
      ref.read(meusPedidosProvider.notifier).add(pedido);
      ref.read(cartProvider.notifier).clear();
      sessaoN.setObservacao('');
      if (!mounted) return;
      final nav = Navigator.of(context);
      // Remove sacola/checkout da pilha: o cardápio fica logo abaixo do sucesso.
      nav.popUntil((r) => r.isFirst || r.settings.name == 'menu');
      nav.push(AppPageRoute<void>(builder: (_) => OrderSuccessScreen(pedido: pedido)));
    } on AppException catch (e) {
      if (mounted) _erro(e.mensagem);
    } catch (e) {
      if (mounted) _erro('Algo deu errado ao enviar. Tente novamente.');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _erro(String msg) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(LucideIcons.circleAlert, color: ctx.palette.danger, size: 40),
        title: const Text('Pedido não enviado'),
        content: Text('$msg\n\nNada foi cobrado. Seus itens continuam na sacola.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _enviar();
            },
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final loja = ref.watch(cardapioProvider).requireValue.loja;
    final s = ref.watch(sessaoProvider);
    final total = ref.watch(cartTotalProvider);
    final expanded = context.isExpanded;

    final form = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (s.mesa != null && s.consumo == TipoConsumo.local) _DestinoCard(mesa: s.mesa!),
        if (loja.modosConsumo.length > 1 && !(s.mesa != null && ref.watch(settingsProvider).mesaFixa != null))
          _Secao(
            key: _keys[_Campo.consumo],
            numero: 1,
            titulo: 'Como vai ser?',
            erro: _erros.contains(_Campo.consumo) ? 'Escolha uma opção' : null,
            child: Row(
              children: [
                for (final (i, m) in loja.modosConsumo.indexed) ...[
                  if (i > 0) const SizedBox(width: Space.sm),
                  Expanded(
                    child: _ChoiceCard(
                      icon: m == TipoConsumo.local ? LucideIcons.utensils : LucideIcons.handbag,
                      title: m.rotulo,
                      subtitle: m == TipoConsumo.local ? 'Servimos na mesa' : 'Embalado para viagem',
                      selected: s.consumo == m,
                      onTap: () {
                        ref.read(sessaoProvider.notifier).setConsumo(m);
                        setState(() => _erros.remove(_Campo.consumo));
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        if (s.consumo == TipoConsumo.local && ref.watch(settingsProvider).mesaFixa == null)
          _Secao(
            key: _keys[_Campo.mesa],
            numero: 2,
            titulo: 'Qual a sua mesa?',
            subtitulo: _garcom ? null : 'Opcional — sem mesa, chamamos você pelo nome no balcão',
            erro: _erros.contains(_Campo.mesa) ? 'Selecione a mesa' : null,
            child: _MesaPicker(
              selecionada: s.mesa,
              onSelect: (m) {
                ref.read(sessaoProvider.notifier).setMesa(m);
                setState(() => _erros.remove(_Campo.mesa));
              },
            ),
          ),
        if (loja.exigirNomeCliente || _garcom)
          _Secao(
            key: _keys[_Campo.nome],
            numero: 3,
            titulo: _garcom ? 'Nome do cliente' : 'Como podemos te chamar?',
            subtitulo: _garcom || s.mesa != null
                ? 'Opcional'
                : 'Usamos seu nome para avisar quando o pedido estiver pronto',
            erro: _erros.contains(_Campo.nome) ? 'Digite seu nome' : null,
            child: TextField(
              controller: _nome,
              textCapitalization: TextCapitalization.words,
              maxLength: 40,
              style: context.text.titleMedium,
              onChanged: (_) => _erros.contains(_Campo.nome) ? setState(() => _erros.remove(_Campo.nome)) : null,
              decoration: InputDecoration(
                hintText: 'Seu nome',
                counterText: '',
                prefixIcon: Icon(LucideIcons.user, color: p.textMuted),
              ),
            ),
          ),
        if (loja.formasPagamento.isNotEmpty)
          _Secao(
            key: _keys[_Campo.pagamento],
            numero: 4,
            titulo: 'Pagamento',
            erro: _erros.contains(_Campo.pagamento) ? 'Escolha como prefere pagar' : null,
            child: Column(
              children: [
                for (final f in loja.formasPagamento.where((f) => f.tipo != 'mesa' || s.consumo != TipoConsumo.viagem))
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.sm),
                    child: _ChoiceCard(
                      icon: switch (f.tipo) {
                        'mesa' => LucideIcons.creditCard,
                        'pix' => LucideIcons.qrCode,
                        'cartao' => LucideIcons.creditCard,
                        _ => LucideIcons.store,
                      },
                      title: f.nome,
                      subtitle: f.descricao,
                      selected: s.formaPagamentoId == f.id,
                      horizontal: true,
                      onTap: () {
                        ref.read(sessaoProvider.notifier).setFormaPagamento(f.id);
                        setState(() => _erros.remove(_Campo.pagamento));
                      },
                    ),
                  ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: Space.xs),
          child: AnimatedSize(
            duration: Motion.base,
            curve: Motion.enter,
            alignment: Alignment.topCenter,
            child: _mostrarObs
                ? TextField(
                    controller: _obs,
                    maxLength: 200,
                    minLines: 2,
                    maxLines: 4,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Observação para a cozinha',
                      hintText: 'Ex.: trazer tudo junto, aniversário na mesa…',
                    ),
                  )
                : Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setState(() => _mostrarObs = true),
                      icon: Icon(LucideIcons.notebookPen, size: 18, color: p.accent),
                      label: Text(
                        'Adicionar observação ao pedido',
                        style: context.text.labelLarge?.copyWith(color: p.accent),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );

    final enviar = AppButton(
      label: _enviando ? 'Enviando…' : 'Enviar pedido',
      icon: LucideIcons.send,
      loading: _enviando,
      onPressed: _enviar,
      trailing: AnimatedMoney(total),
      height: 60,
    );

    return PopScope(
      canPop: !_enviando,
      child: Scaffold(
        appBar: AppBar(
          leadingWidth: 64,
          leading: Padding(
            padding: const EdgeInsets.all(4),
            child: RoundIconButton(
              icon: LucideIcons.arrowLeft,
              label: 'Voltar',
              filled: false,
              onPressed: _enviando ? null : () => Navigator.of(context).pop(),
            ),
          ),
          title: const Text('Finalizar pedido'),
        ),
        body: Stack(
          children: [
            if (expanded)
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 7,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(Space.xl, Space.md, Space.lg, Space.xxl),
                          child: form,
                        ),
                      ),
                      SizedBox(
                        width: 420,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(0, Space.md, Space.xl, 0),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.only(bottom: Space.xl),
                            child: _ResumoCard(footer: enviar),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(context.gutter, Space.xs, context.gutter, Space.xl),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 680),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              form,
                              const SizedBox(height: Space.lg),
                              const _ResumoCard(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.fromLTRB(
                      context.gutter,
                      Space.sm,
                      context.gutter,
                      Space.sm + MediaQuery.paddingOf(context).bottom,
                    ),
                    decoration: BoxDecoration(
                      color: p.surface,
                      border: Border(top: BorderSide(color: p.outline)),
                    ),
                    child: Center(
                      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 680), child: enviar),
                    ),
                  ),
                ],
              ),
            if (_enviando) const _EnviandoOverlay(),
          ],
        ),
      ),
    );
  }
}

// ============================================================================ peças

class _Secao extends StatelessWidget {
  const _Secao({super.key, required this.numero, required this.titulo, this.subtitulo, this.erro, required this.child});

  final int numero;
  final String titulo;
  final String? subtitulo;
  final String? erro;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.xl - 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [Expanded(child: Text(titulo, style: context.text.headlineSmall))],
          ),
          if (subtitulo != null) ...[const SizedBox(height: 2), Text(subtitulo!, style: context.text.bodyMedium)],
          const SizedBox(height: Space.md),
          child,
          AnimatedSize(
            duration: Motion.base,
            child: erro == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: Space.xs),
                    child: Row(
                      children: [
                        Icon(LucideIcons.circleAlert, size: 18, color: p.danger),
                        const SizedBox(width: 6),
                        Text(erro!, style: context.text.labelMedium?.copyWith(color: p.danger)),
                      ],
                    ).animate().shakeX(hz: 5, amount: 4, duration: 380.ms),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Confirma para onde o pedido vai — tranquiliza quem pede pelo tablet da mesa.
class _DestinoCard extends StatelessWidget {
  const _DestinoCard({required this.mesa});

  final int mesa;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      margin: const EdgeInsets.only(bottom: Space.xl - 4),
      padding: const EdgeInsets.all(Space.md + 2),
      decoration: BoxDecoration(
        borderRadius: Radii.rLg,
        gradient: LinearGradient(colors: [p.primarySoft, p.primarySoft.withValues(alpha: 0)]),
        border: Border.all(color: p.primary.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: p.primary,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(color: p.primary.withValues(alpha: 0.45), blurRadius: 18, offset: const Offset(0, 6)),
              ],
            ),
            child: Icon(LucideIcons.armchair, color: p.onPrimary, size: 26),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HighlightText(
                  'Seu pedido vai para a *Mesa $mesa*',
                  highlight: p.accent,
                  style: context.text.titleLarge,
                ),
                const SizedBox(height: 2),
                Text('Servimos aqui na sua mesa assim que ficar pronto', style: context.text.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.horizontal = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final iconBox = AnimatedContainer(
      duration: Motion.base,
      width: 52,
      height: 52,
      decoration: BoxDecoration(color: selected ? p.primary : p.surfaceSunken, borderRadius: BorderRadius.circular(16)),
      child: Icon(icon, size: 26, color: selected ? p.onPrimary : p.textSecondary),
    );
    final texts = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: context.text.titleMedium),
        const SizedBox(height: 2),
        Text(subtitle, style: context.text.bodySmall),
      ],
    );
    final check = AnimatedScale(
      scale: selected ? 1 : 0,
      duration: Motion.base,
      curve: Motion.spring,
      child: Icon(LucideIcons.circleCheck, color: p.accent, size: 26),
    );

    return Pressable(
      onTap: onTap,
      borderRadius: Radii.rLg,
      selected: selected,
      semanticLabel: '$title. $subtitle',
      child: AnimatedContainer(
        duration: Motion.base,
        curve: Motion.enter,
        padding: const EdgeInsets.all(Space.md),
        decoration: BoxDecoration(
          color: selected ? p.primarySoft : p.surfaceRaised,
          borderRadius: Radii.rLg,
          border: Border.all(color: selected ? p.primary : p.outline, width: selected ? 2 : 1),
        ),
        child: horizontal
            ? Row(
                children: [
                  iconBox,
                  const SizedBox(width: Space.md),
                  Expanded(child: texts),
                  check,
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [iconBox, const Spacer(), check]),
                  const SizedBox(height: Space.md),
                  texts,
                ],
              ),
      ),
    );
  }
}

class _MesaPicker extends ConsumerWidget {
  const _MesaPicker({required this.selecionada, required this.onSelect});

  final int? selecionada;
  final ValueChanged<int?> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    // Mesas do cadastro do ERP, que vêm junto com o cardápio (funciona offline).
    final numeros =
        ref.watch(cardapioProvider.select((c) => c.value?.numerosMesas)) ?? [for (var i = 1; i <= 16; i++) i];
    return Wrap(
      spacing: Space.xs,
      runSpacing: Space.xs,
      children: [
        for (final n in numeros)
          Pressable(
            onTap: () => onSelect(selecionada == n ? null : n),
            borderRadius: Radii.rMd,
            selected: selecionada == n,
            semanticLabel: 'Mesa $n',
            scale: 0.92,
            child: AnimatedContainer(
              duration: Motion.base,
              width: 60,
              height: 60,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selecionada == n ? p.primary : p.surfaceRaised,
                borderRadius: Radii.rMd,
                border: Border.all(color: selecionada == n ? p.primary : p.outline),
              ),
              child: Text(
                '$n',
                style: context.text.titleLarge?.copyWith(color: selecionada == n ? p.onPrimary : p.textPrimary),
              ),
            ),
          ),
      ],
    );
  }
}

class _ResumoCard extends ConsumerWidget {
  const _ResumoCard({this.footer});

  final Widget? footer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final itens = ref.watch(cartProvider);
    final sub = ref.watch(cartSubtotalProvider);
    final taxa = ref.watch(cartTaxaProvider);
    final total = ref.watch(cartTotalProvider);
    final loja = ref.watch(cardapioProvider).requireValue.loja;

    Widget linha(String a, String b, {TextStyle? style}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(a, style: style ?? context.text.bodyMedium)),
          Text(b, style: style ?? context.text.titleSmall),
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: Radii.rXl,
        border: Border.all(color: p.outline),
        boxShadow: [BoxShadow(color: p.shadow.withValues(alpha: 0.3), blurRadius: 30, offset: const Offset(0, 14))],
      ),
      padding: const EdgeInsets.all(Space.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(LucideIcons.receipt, color: p.accent),
              const SizedBox(width: Space.xs),
              Expanded(child: Text('Resumo', style: context.text.headlineSmall)),
              Text(itensLabel(itens.fold(0, (s, i) => s + i.quantidade)), style: context.text.bodySmall),
            ],
          ),
          const SizedBox(height: Space.md),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final i in itens)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: Space.xs),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: p.accentSoft, borderRadius: BorderRadius.circular(8)),
                          child: Text('${i.quantidade}×', style: context.text.labelMedium?.copyWith(color: p.accent)),
                        ),
                        const SizedBox(width: Space.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(i.produto.nome, style: context.text.titleSmall),
                              if (i.resumoOpcoes.isNotEmpty)
                                Text(i.resumoOpcoes.join(' · '), style: context.text.bodySmall),
                            ],
                          ),
                        ),
                        Text(money(i.total), style: context.text.titleSmall),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.sm),
            child: Divider(height: 1, color: p.outline),
          ),
          linha('Subtotal', money(sub)),
          if (taxa > 0) linha('Serviço (${loja.taxaServicoPercentual.toStringAsFixed(0)}%)', money(taxa)),
          const SizedBox(height: Space.xs),
          Row(
            children: [
              Expanded(child: Text('Total', style: context.text.titleLarge)),
              AnimatedMoney(total, style: context.text.headlineMedium?.copyWith(color: p.accent)),
            ],
          ),
          if (footer != null) ...[const SizedBox(height: Space.lg), footer!],
          const SizedBox(height: Space.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.lock, size: 14, color: p.textMuted),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Pedido enviado direto para o sistema da casa',
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: context.text.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EnviandoOverlay extends StatelessWidget {
  const _EnviandoOverlay();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: ColoredBox(
          color: p.background.withValues(alpha: 0.7),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.cookingPot, size: 72, color: p.accent).maybeAnimate(
                  context,
                  (a) => a.moveY(begin: 4, end: -8, duration: 700.ms, curve: Curves.easeInOut),
                  onPlayRepeat: true,
                ),
                const SizedBox(height: Space.lg),
                Text('Enviando para a cozinha…', style: context.text.headlineSmall),
                const SizedBox(height: Space.xs),
                Text('Só um instante', style: context.text.bodyMedium),
                const SizedBox(height: Space.lg),
                SizedBox(
                  width: 180,
                  child: LinearProgressIndicator(
                    borderRadius: Radii.rPill,
                    minHeight: 6,
                    backgroundColor: p.surfaceSunken,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
