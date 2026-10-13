import 'dart:async';
import 'dart:convert';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/pedido.dart';
import '../repositories/cardapio_repository.dart';

/// Tudo o que o app guarda para funcionar sem internet fica no SharedPreferences,
/// que já está carregado em memória quando o app abre: o cardápio aparece na hora,
/// sem esperar rede nem disco. (Um cardápio grande tem poucas centenas de KB.)
class ArmazenamentoOffline {
  ArmazenamentoOffline(this._p);

  final SharedPreferences _p;

  static const _kCardapio = 'offline.cardapio.json';
  static const _kOrigem = 'offline.cardapio.origem';
  static const _kSincronizado = 'offline.cardapio.sincronizado_em';
  static const _kFila = 'offline.fila_pedidos';
  static const _kMeusPedidos = 'offline.meus_pedidos';

  // ------------------------------------------------------------ cardápio

  /// Último cardápio baixado de [origem] (endereço do ERP, ou "demo").
  PacoteCardapio? lerCardapio(String origem) {
    if (_p.getString(_kOrigem) != origem) return null;
    final raw = _p.getString(_kCardapio);
    if (raw == null) return null;
    try {
      return PacoteCardapio(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Formato antigo ou corrompido: baixa de novo.
      return null;
    }
  }

  Future<void> salvarCardapio(String origem, PacoteCardapio pacote) async {
    await _p.setString(_kCardapio, jsonEncode(pacote.json));
    await _p.setString(_kOrigem, origem);
    await marcarSincronizado();
  }

  DateTime? get sincronizadoEm => DateTime.tryParse(_p.getString(_kSincronizado) ?? '');

  Future<void> marcarSincronizado() => _p.setString(_kSincronizado, DateTime.now().toIso8601String());

  Future<void> esquecerCardapio() async {
    await _p.remove(_kCardapio);
    await _p.remove(_kOrigem);
    await _p.remove(_kSincronizado);
  }

  // ------------------------------------------------------------ fila de pedidos

  List<PedidoNaFila> lerFila() => _lerLista(_kFila, PedidoNaFila.fromJson);

  Future<void> salvarFila(List<PedidoNaFila> fila) =>
      _p.setString(_kFila, jsonEncode([for (final f in fila) f.toJson()]));

  // ------------------------------------------------------------ pedidos deste aparelho

  List<Pedido> lerMeusPedidos() => _lerLista(_kMeusPedidos, Pedido.fromJson);

  Future<void> salvarMeusPedidos(List<Pedido> pedidos) =>
      _p.setString(_kMeusPedidos, jsonEncode([for (final p in pedidos) p.toJson()]));

  List<T> _lerLista<T>(String chave, T Function(Map<String, dynamic>) fromJson) {
    final raw = _p.getString(chave);
    if (raw == null) return [];
    try {
      return [for (final e in jsonDecode(raw) as List) fromJson(e as Map<String, dynamic>)];
    } catch (_) {
      return [];
    }
  }
}

/// Pedido confirmado pelo cliente que ainda não chegou ao ERP.
class PedidoNaFila {
  const PedidoNaFila({required this.novo, required this.previa, this.tentativas = 0, this.ultimoErro});

  final NovoPedido novo;

  /// Como o pedido aparece para o cliente enquanto não tem número do ERP.
  final Pedido previa;
  final int tentativas;
  final String? ultimoErro;

  String get codigo => novo.codigoAcesso;

  PedidoNaFila falhou(String erro) =>
      PedidoNaFila(novo: novo, previa: previa, tentativas: tentativas + 1, ultimoErro: erro);

  Map<String, dynamic> toJson() => {
    'novo': novo.toStorage(),
    'previa': previa.toJson(),
    'tentativas': tentativas,
    'ultimo_erro': ultimoErro,
  };

  factory PedidoNaFila.fromJson(Map<String, dynamic> j) => PedidoNaFila(
    novo: NovoPedido.fromStorage(j['novo'] as Map<String, dynamic>),
    previa: Pedido.fromJson(j['previa'] as Map<String, dynamic>),
    tentativas: (j['tentativas'] as int?) ?? 0,
    ultimoErro: j['ultimo_erro'] as String?,
  );
}

/// Cache das fotos do cardápio. Guarda por 1 ano: quando a foto muda no ERP, a
/// URL muda junto (`?v=`), então nunca há foto velha.
final cacheImagens = CacheManager(
  Config('cardapio_imagens', stalePeriod: const Duration(days: 365), maxNrOfCacheObjects: 4000),
);

/// Baixa as fotos que ainda não estão no aparelho, 4 por vez.
/// Devolve quantas estão disponíveis offline.
Future<int> preBaixarImagens(Iterable<String> urls, {void Function(int prontas, int total)? progresso}) async {
  final lista = urls.toList();
  var prontas = 0;
  var proxima = 0;
  Future<void> trabalhador() async {
    while (proxima < lista.length) {
      final url = lista[proxima++];
      try {
        if (await cacheImagens.getFileFromCache(url) == null) await cacheImagens.downloadFile(url);
        prontas++;
      } catch (_) {
        // Sem rede ou foto removida: tenta de novo na próxima sincronização.
      }
      progresso?.call(prontas, lista.length);
    }
  }

  await Future.wait([for (var i = 0; i < 4; i++) trabalhador()]);
  return prontas;
}
