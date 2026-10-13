import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/chamado.dart';
import '../data/repositories/cardapio_repository.dart';
import 'providers.dart';
import 'settings.dart';

// Botão "Chamar garçom": o tablet da mesa abre um chamado e o celular do garçom
// responsável pela mesa recebe. Tudo configurado em ERP › Simuladores › Cardápio.

@immutable
class ChamadoMesaState {
  const ChamadoMesaState({this.chamado, this.enviando = false, this.erro, this.liberadoEm});

  final Chamado? chamado;
  final bool enviando;
  final String? erro;

  /// Antes disso o sino não aceita outro chamado (intervalo definido no ERP).
  final DateTime? liberadoEm;

  bool get emAberto => chamado != null && chamado!.status.emAberto;

  bool liberado(DateTime agora) => liberadoEm == null || !agora.isBefore(liberadoEm!);

  ChamadoMesaState com(Chamado c) => ChamadoMesaState(chamado: c, liberadoEm: liberadoEm);
}

class ChamadoMesaController extends Notifier<ChamadoMesaState> {
  /// Chamado feito sem internet, aguardando reenvio.
  NovoChamado? _pendente;

  /// Depois disso um chamado parado na fila perde o sentido (o cliente já foi atendido ou desistiu).
  static const validadeOffline = Duration(minutes: 10);

  @override
  ChamadoMesaState build() => const ChamadoMesaState();

  Future<void> chamar(MotivoChamado motivo, int mesa) async {
    final cardapio = ref.read(cardapioProvider).value;
    if (cardapio == null) return;
    final novo = NovoChamado(codigo: uuid.v4(), mesa: mesa, motivo: motivo.chave, criadoEm: DateTime.now());
    final cadastro = cardapio.mesa(mesa);
    state = ChamadoMesaState(
      chamado: Chamado.local(novo, motivo, garcomId: cadastro?.garcomId, garcomNome: cadastro?.garcomNome),
      enviando: true,
      liberadoEm: DateTime.now().add(Duration(seconds: cardapio.loja.chamarGarcom.intervaloSeg)),
    );
    try {
      final c = await ref.read(repositoryProvider).chamarGarcom(novo).timeout(const Duration(seconds: 8));
      if (!ref.mounted) return;
      _pendente = null;
      state = state.com(c);
      ref.read(syncProvider.notifier).online();
    } on AppException catch (e) {
      if (!ref.mounted) return;
      if (!e.temporario) {
        state = ChamadoMesaState(erro: e.mensagem);
        return;
      }
      _pendente = novo;
      state = state.com(state.chamado!);
      ref.read(syncProvider.notifier).falha(e);
    } on TimeoutException {
      if (!ref.mounted) return;
      _pendente = novo;
      state = state.com(state.chamado!);
    }
  }

  /// Reenvia o chamado feito sem internet (chamado pelo OfflineHost).
  Future<void> reenviarPendente() async {
    final p = _pendente;
    if (p == null) return;
    if (DateTime.now().difference(p.criadoEm) > validadeOffline) {
      _pendente = null;
      state = const ChamadoMesaState();
      return;
    }
    try {
      final c = await ref.read(repositoryProvider).chamarGarcom(p);
      if (!ref.mounted || _pendente?.codigo != p.codigo) return;
      _pendente = null;
      state = state.com(c);
    } on AppException catch (e) {
      if (!ref.mounted || e.temporario) return;
      _pendente = null;
      state = ChamadoMesaState(erro: e.mensagem);
    }
  }

  /// Status novo vindo do ERP ("a caminho", "atendido").
  void atualizar(Chamado c) {
    if (state.chamado?.codigo == c.codigo) state = state.com(c);
  }

  Future<void> cancelar() async {
    final c = state.chamado;
    if (c == null) return;
    state = const ChamadoMesaState();
    if (_pendente?.codigo == c.codigo) {
      _pendente = null;
      return;
    }
    try {
      await ref.read(repositoryProvider).atualizarChamado(c.codigo, StatusChamado.cancelado);
    } on AppException {
      // Sem internet: o chamado expira sozinho no ERP.
    }
  }

  /// Novo cliente na mesa (totem voltou para a tela de descanso).
  void limpar() {
    _pendente = null;
    state = const ChamadoMesaState();
  }
}

final chamadoMesaProvider = NotifierProvider<ChamadoMesaController, ChamadoMesaState>(ChamadoMesaController.new);

/// Acompanha um chamado da mesa até ser atendido (a cada 4 s).
final chamadoAoVivoProvider = StreamProvider.autoDispose.family<Chamado, String>((ref, codigo) async* {
  final repo = ref.watch(repositoryProvider);
  while (true) {
    try {
      final c = await repo.consultarChamado(codigo);
      yield c;
      if (!c.status.emAberto) return;
    } on AppException catch (e) {
      if (!e.temporario) return;
    }
    await Future<void>.delayed(const Duration(seconds: 4));
  }
});

/// Celular do garçom: chamados em aberto das mesas dele (ou todos), a cada 5 s.
/// Sem internet, mantém a última lista.
final chamadosAbertosProvider = StreamProvider.autoDispose<List<Chamado>>((ref) {
  final repo = ref.watch(repositoryProvider);
  final garcomId = ref.watch(settingsProvider.select((s) => s.garcomId));
  var ultimo = const <Chamado>[];
  Future<List<Chamado>> buscar() async {
    try {
      ultimo = await repo.chamadosAbertos(garcomId: garcomId);
    } on AppException {
      // mantém a última lista
    }
    return ultimo;
  }

  Stream<List<Chamado>> fluxo() async* {
    yield await buscar();
    yield* Stream<void>.periodic(const Duration(seconds: 5)).asyncMap((_) => buscar());
  }

  return fluxo();
});
