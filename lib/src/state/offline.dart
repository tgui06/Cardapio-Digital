import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../core/widgets/app_image.dart';
import '../data/local/armazenamento_offline.dart';
import '../data/models/cardapio.dart';
import '../data/models/pedido.dart';
import '../data/repositories/cardapio_repository.dart';
import '../data/repositories/demo_cardapio_repository.dart';
import '../data/repositories/erp_cardapio_repository.dart';
import 'settings.dart';

// Offline-first: o app sempre trabalha com o que está guardado no aparelho.
// A rede só serve para buscar novidades (em segundo plano) e entregar pedidos
// (pela fila). Internet ruim nunca trava o cliente.

// ------------------------------------------------------------ repositório

final _demoRepo = DemoCardapioRepository();

final repositoryProvider = Provider<CardapioRepository>((ref) {
  final (demo, url, token) = ref.watch(settingsProvider.select((s) => (s.demo, s.erpUrl, s.token)));
  if (demo || url.isEmpty) return _demoRepo;
  return ErpCardapioRepository(baseUrl: url, token: token);
});

final armazenamentoProvider = Provider<ArmazenamentoOffline>((ref) => ArmazenamentoOffline(ref.watch(prefsProvider)));

/// Identifica de onde veio o cardápio guardado: outro ERP ou outro token
/// (outra empresa no mesmo ERP) = outro cardápio.
final _origemProvider = Provider<String>((ref) {
  final (demo, url, token) = ref.watch(settingsProvider.select((s) => (s.demo, s.erpUrl, s.token)));
  if (demo || url.isEmpty) return 'demo';
  return '$url|${sha256.convert(utf8.encode(token)).toString().substring(0, 16)}';
});

// ------------------------------------------------------------ estado da sincronização

enum Conexao { desconhecida, online, offline }

@immutable
class SyncInfo {
  const SyncInfo({
    this.conexao = Conexao.desconhecida,
    this.sincronizando = false,
    this.ultimaSync,
    this.erro,
    this.imagensProntas = 0,
    this.imagensTotal = 0,
  });

  final Conexao conexao;
  final bool sincronizando;

  /// Última vez que o app conversou com o ERP com sucesso.
  final DateTime? ultimaSync;
  final String? erro;
  final int imagensProntas;
  final int imagensTotal;

  bool get offline => conexao == Conexao.offline;

  SyncInfo copyWith({
    Conexao? conexao,
    bool? sincronizando,
    DateTime? ultimaSync,
    String? Function()? erro,
    int? imagensProntas,
    int? imagensTotal,
  }) => SyncInfo(
    conexao: conexao ?? this.conexao,
    sincronizando: sincronizando ?? this.sincronizando,
    ultimaSync: ultimaSync ?? this.ultimaSync,
    erro: erro != null ? erro() : this.erro,
    imagensProntas: imagensProntas ?? this.imagensProntas,
    imagensTotal: imagensTotal ?? this.imagensTotal,
  );
}

class SyncController extends Notifier<SyncInfo> {
  @override
  SyncInfo build() => SyncInfo(ultimaSync: ref.read(armazenamentoProvider).sincronizadoEm);

  void inicio() => state = state.copyWith(sincronizando: true);

  void online() => state = state.copyWith(
    conexao: Conexao.online,
    sincronizando: false,
    ultimaSync: DateTime.now(),
    erro: () => null,
  );

  void falha(AppException e) => state = state.copyWith(
    conexao: e.temporario ? Conexao.offline : state.conexao,
    sincronizando: false,
    erro: () => e.mensagem,
  );

  void imagens(int prontas, int total) => state = state.copyWith(imagensProntas: prontas, imagensTotal: total);
}

final syncProvider = NotifierProvider<SyncController, SyncInfo>(SyncController.new);

// ------------------------------------------------------------ cardápio

/// Cardápio guardado no aparelho, atualizado em segundo plano.
///
/// - Abre na hora com a última versão salva (sem esperar a rede).
/// - [sincronizar] manda `?versao=` ao ERP; se nada mudou, a resposta tem poucos bytes.
/// - Só o primeiro uso (logo após parear) depende de internet.
class CardapioController extends AsyncNotifier<Cardapio> {
  bool _sincronizando = false;
  bool _baixandoImagens = false;

  @override
  FutureOr<Cardapio> build() {
    final origem = ref.watch(_origemProvider);
    final repo = ref.watch(repositoryProvider);
    final local = ref.read(armazenamentoProvider);

    final salvo = local.lerCardapio(origem);
    if (salvo != null) {
      // Mostra o que tem e busca novidades logo em seguida, sem bloquear a tela.
      Future.microtask(sincronizar);
      return salvo.cardapio;
    }
    return _primeiroDownload(repo, local, origem);
  }

  Future<Cardapio> _primeiroDownload(CardapioRepository repo, ArmazenamentoOffline local, String origem) async {
    await Future<void>.value(); // não altera outro provider durante o build
    final sync = ref.read(syncProvider.notifier)..inicio();
    try {
      final pacote = (await repo.baixarCardapio())!;
      await local.salvarCardapio(origem, pacote);
      sync.online();
      _depoisDeAtualizar(pacote.cardapio, mudou: true);
      return pacote.cardapio;
    } on AppException catch (e) {
      sync.falha(e);
      rethrow;
    }
  }

  /// Busca mudanças no ERP. Devolve `true` se o cardápio mudou.
  Future<bool> sincronizar() async {
    if (_sincronizando) return false;
    final atual = state.value;
    if (atual == null) {
      // Ainda sem cardápio (primeiro download falhou): tenta tudo de novo.
      if (state.hasError) ref.invalidateSelf();
      return false;
    }
    _sincronizando = true;
    final sync = ref.read(syncProvider.notifier)..inicio();
    final origem = ref.read(_origemProvider);
    try {
      final pacote = await ref
          .read(repositoryProvider)
          .baixarCardapio(versaoAtual: atual.versao.isEmpty ? null : atual.versao);
      if (!ref.mounted) return false;
      final local = ref.read(armazenamentoProvider);
      if (pacote != null) {
        await local.salvarCardapio(origem, pacote);
        if (!ref.mounted) return false;
        state = AsyncData(pacote.cardapio);
      } else {
        await local.marcarSincronizado();
      }
      sync.online();
      _depoisDeAtualizar(pacote?.cardapio ?? atual, mudou: pacote != null);
      return pacote != null;
    } on AppException catch (e) {
      if (ref.mounted) sync.falha(e);
      return false;
    } finally {
      _sincronizando = false;
    }
  }

  /// Deixa fotos e fontes no aparelho para a próxima vez que faltar internet.
  void _depoisDeAtualizar(Cardapio c, {required bool mudou}) {
    if (appImageDisableNetwork) return; // testes: sem rede nem disco
    if (mudou) prepararFontes(c.loja.aparencia.fonte).ignore();
    if (_baixandoImagens || ref.read(_origemProvider) == 'demo') return;
    _baixandoImagens = true;
    final sync = ref.read(syncProvider.notifier);
    var ultimoAviso = DateTime(0);
    preBaixarImagens(
      c.urlsImagens,
      progresso: (prontas, total) {
        // Atualiza a tela no máximo a cada 300 ms (e sempre no fim).
        final agora = DateTime.now();
        if (prontas == total || agora.difference(ultimoAviso).inMilliseconds > 300) {
          ultimoAviso = agora;
          if (ref.mounted) sync.imagens(prontas, total);
        }
      },
    ).whenComplete(() => _baixandoImagens = false).ignore();
  }
}

final cardapioProvider = AsyncNotifierProvider<CardapioController, Cardapio>(CardapioController.new);

/// Cardápio fixo, sem rede (testes e prévias).
class CardapioFixo extends CardapioController {
  CardapioFixo(this.cardapio);

  final Cardapio cardapio;

  @override
  FutureOr<Cardapio> build() => cardapio;

  @override
  Future<bool> sincronizar() async => false;
}

// ------------------------------------------------------------ pedidos deste aparelho

/// Pedidos feitos neste aparelho (mais recente primeiro). Guardados no aparelho
/// para sobreviver a reinícios; só os das últimas 16 horas.
class MeusPedidosController extends Notifier<List<Pedido>> {
  ArmazenamentoOffline get _local => ref.read(armazenamentoProvider);

  @override
  List<Pedido> build() {
    final limite = DateTime.now().subtract(const Duration(hours: 16));
    return ref.read(armazenamentoProvider).lerMeusPedidos().where((p) => p.criadoEm.isAfter(limite)).toList();
  }

  void _definir(List<Pedido> lista) {
    state = lista.take(40).toList();
    _local.salvarMeusPedidos(state).ignore();
  }

  void add(Pedido p) => _definir([p, ...state.where((x) => x.codigoAcesso != p.codigoAcesso)]);

  /// Troca a versão local pela que veio do ERP (número, status, valores oficiais).
  void atualizar(Pedido p) {
    if (!state.any((x) => x.codigoAcesso == p.codigoAcesso)) return;
    _definir([for (final x in state) x.codigoAcesso == p.codigoAcesso ? p : x]);
  }

  void clear() => _definir(const []);

  /// Tablet preso a uma mesa: os pedidos da mesa vêm do ERP (desde a última conta fechada),
  /// somados aos que ainda estão na fila deste aparelho. Conta fechada no caixa = lista vazia.
  Future<void> sincronizarMesa(int mesa) async {
    try {
      final daMesa = await ref.read(repositoryProvider).pedidosDaMesa(mesa);
      if (!ref.mounted) return;
      final naFila = state.where((p) => !p.sincronizado && !daMesa.any((d) => d.codigoAcesso == p.codigoAcesso));
      _definir([...naFila, ...daMesa]);
    } on AppException {
      // Sem internet: mantém o que tem.
    }
  }
}

final meusPedidosProvider = NotifierProvider<MeusPedidosController, List<Pedido>>(MeusPedidosController.new);

// ------------------------------------------------------------ fila de envio

/// Pedidos confirmados que ainda não chegaram ao ERP.
///
/// O pedido entra na fila *antes* de ir para a rede. Sem conexão, o cliente vê
/// "pedido registrado" e o envio acontece sozinho quando a internet volta. O
/// `codigo_acesso` (UUID) torna o reenvio seguro: o ERP nunca duplica a venda.
class FilaPedidosController extends Notifier<List<PedidoNaFila>> {
  final _emEnvio = <String>{};
  bool _processando = false;

  /// Tempo máximo que o cliente espera pela rede na hora de confirmar.
  static const esperaMaxima = Duration(seconds: 8);

  @override
  List<PedidoNaFila> build() => ref.read(armazenamentoProvider).lerFila();

  void _definir(List<PedidoNaFila> fila) {
    state = fila;
    ref.read(armazenamentoProvider).salvarFila(fila).ignore();
  }

  void _remover(String codigo) => _definir([
    for (final f in state)
      if (f.codigo != codigo) f,
  ]);

  void _falhou(String codigo, String erro) =>
      _definir([for (final f in state) f.codigo == codigo ? f.falhou(erro) : f]);

  /// Registra o pedido e tenta entregar na hora.
  ///
  /// - Entregue: devolve o pedido oficial do ERP.
  /// - Sem conexão/lento: devolve [previa] (o pedido fica na fila e sai sozinho).
  /// - Recusado pelo ERP (ex.: item esgotado): lança [AppException] e nada fica na fila.
  Future<Pedido> registrar(NovoPedido novo, Pedido previa) async {
    _definir([...state, PedidoNaFila(novo: novo, previa: previa)]);
    final sync = ref.read(syncProvider.notifier);
    _emEnvio.add(novo.codigoAcesso);
    try {
      final pedido = await ref.read(repositoryProvider).enviarPedido(novo).timeout(esperaMaxima);
      _remover(novo.codigoAcesso);
      sync.online();
      return pedido;
    } on AppException catch (e) {
      if (!e.temporario) {
        _remover(novo.codigoAcesso);
        rethrow;
      }
      _falhou(novo.codigoAcesso, e.mensagem);
      sync.falha(e);
      return previa;
    } on TimeoutException {
      // A requisição pode até chegar depois; o reenvio pela fila é idempotente.
      _falhou(novo.codigoAcesso, 'Conexão lenta');
      return previa;
    } finally {
      _emEnvio.remove(novo.codigoAcesso);
    }
  }

  /// Entrega o que está na fila, na ordem em que foi pedido. Para no primeiro
  /// erro de conexão (tenta de novo no próximo ciclo).
  Future<void> processar() async {
    if (_processando || state.isEmpty) return;
    _processando = true;
    final sync = ref.read(syncProvider.notifier);
    final meus = ref.read(meusPedidosProvider.notifier);
    try {
      for (final item in [...state]) {
        if (_emEnvio.contains(item.codigo)) continue;
        try {
          final pedido = await ref.read(repositoryProvider).enviarPedido(item.novo);
          if (!ref.mounted) return;
          _remover(item.codigo);
          meus.atualizar(pedido);
          sync.online();
        } on AppException catch (e) {
          if (!ref.mounted) return;
          if (e.temporario) {
            _falhou(item.codigo, e.mensagem);
            sync.falha(e);
            break;
          }
          // Recusado de vez: sai da fila e o cliente vê o motivo no acompanhamento.
          _remover(item.codigo);
          meus.atualizar(item.previa.copyWith(status: StatusPedido.cancelado, erroEnvio: e.mensagem));
        }
      }
    } finally {
      _processando = false;
    }
  }
}

final filaPedidosProvider = NotifierProvider<FilaPedidosController, List<PedidoNaFila>>(FilaPedidosController.new);

// ------------------------------------------------------------ acompanhamento

/// Acompanhamento ao vivo de um pedido, tolerante a quedas de conexão:
/// enquanto está na fila mostra a versão local; sem rede, espaça as consultas
/// (5 s → até 30 s) e mostra o último status conhecido.
final pedidoAoVivoProvider = StreamProvider.autoDispose.family<Pedido, String>((ref, codigo) async* {
  final repo = ref.watch(repositoryProvider);
  Pedido? local() {
    for (final p in ref.read(meusPedidosProvider)) {
      if (p.codigoAcesso == codigo) return p;
    }
    return null;
  }

  var espera = const Duration(seconds: 5);
  while (true) {
    final l = local();
    if (l != null && (!l.sincronizado || l.erroEnvio != null)) {
      yield l;
      if (l.erroEnvio != null) return;
      await Future<void>.delayed(const Duration(seconds: 2));
      continue;
    }
    try {
      final p = await repo.consultarPedido(codigo);
      ref.read(meusPedidosProvider.notifier).atualizar(p);
      yield p;
      if (p.status == StatusPedido.entregue || p.status == StatusPedido.cancelado) return;
      espera = const Duration(seconds: 5);
    } on AppException catch (e) {
      if (!e.temporario || l == null) rethrow;
      yield l;
      espera = Duration(seconds: math.min(espera.inSeconds * 2, 30));
    }
    await Future<void>.delayed(espera);
  }
});

// ------------------------------------------------------------ garçom (dados ao vivo)

final mesasProvider = FutureProvider.autoDispose<List<Mesa>>((ref) => ref.watch(repositoryProvider).mesas());

final pedidosDaMesaProvider = FutureProvider.autoDispose.family<List<Pedido>, int>(
  (ref, mesa) => ref.watch(repositoryProvider).pedidosDaMesa(mesa),
);
