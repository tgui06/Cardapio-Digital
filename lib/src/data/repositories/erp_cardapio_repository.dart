import 'package:dio/dio.dart';

import '../models/chamado.dart';
import '../models/pedido.dart';
import 'cardapio_repository.dart';

/// Implementação real: fala com o Forven ERP usando o token do simulador.
class ErpCardapioRepository implements CardapioRepository {
  ErpCardapioRepository({required String baseUrl, required String token})
    : _dio = Dio(
        BaseOptions(
          baseUrl: '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/api/externo/simuladores/cardapio/',
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 20),
          headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
        ),
      );

  final Dio _dio;

  Future<T> _call<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final data = e.response?.data;
      final serverMsg = data is Map ? data['message'] as String? : null;
      if (status == 401) {
        // Token revogado: nada é perdido — a fila espera o aparelho ser pareado de novo.
        throw const AppException('Token inválido ou revogado. Pareie o aparelho novamente.', temporario: true);
      }
      if (status == 404) throw AppException(serverMsg ?? 'Recurso não encontrado no ERP.');
      if (status == 422) throw AppException(serverMsg ?? 'O ERP recusou o pedido.', detalhe: data.toString());
      if (status == null || status >= 500 || status == 408 || status == 429) {
        throw AppException(
          status == null ? 'Sem conexão com o ERP.' : 'O ERP não respondeu ($status).',
          temporario: true,
        );
      }
      throw AppException(serverMsg ?? 'Erro ao comunicar com o ERP ($status).');
    }
  }

  @override
  Future<PacoteCardapio?> baixarCardapio({String? versaoAtual}) => _call(() async {
    final r = await _dio.get<Map<String, dynamic>>('cardapio', queryParameters: {'versao': ?versaoAtual});
    final json = r.data!;
    if (json['inalterado'] == true) return null;
    return PacoteCardapio(json);
  });

  @override
  Future<Pedido> enviarPedido(NovoPedido pedido) => _call(() async {
    final r = await _dio.post<Map<String, dynamic>>('pedidos', data: pedido.toJson());
    return Pedido.fromJson(r.data!);
  });

  @override
  Future<Pedido> consultarPedido(String codigoAcesso) => _call(() async {
    final r = await _dio.get<Map<String, dynamic>>(
      'pedidos/$codigoAcesso',
      options: Options(receiveTimeout: const Duration(seconds: 8)),
    );
    return Pedido.fromJson(r.data!);
  });

  @override
  Future<List<Pedido>> pedidosDaMesa(int mesa) => _call(() async {
    final r = await _dio.get<List<dynamic>>('pedidos', queryParameters: {'mesa': mesa});
    return r.data!.map((e) => Pedido.fromJson(e as Map<String, dynamic>)).toList();
  });

  @override
  Future<List<Mesa>> mesas() => _call(() async {
    final r = await _dio.get<List<dynamic>>('mesas');
    return r.data!.map((e) => Mesa.fromJson(e as Map<String, dynamic>)).toList();
  });

  @override
  Future<Chamado> chamarGarcom(NovoChamado chamado) => _call(() async {
    final r = await _dio.post<Map<String, dynamic>>(
      'chamados',
      data: chamado.toJson(),
      options: Options(receiveTimeout: const Duration(seconds: 8)),
    );
    return Chamado.fromJson(r.data!);
  });

  @override
  Future<Chamado> consultarChamado(String codigo) => _call(() async {
    final r = await _dio.get<Map<String, dynamic>>(
      'chamados/$codigo',
      options: Options(receiveTimeout: const Duration(seconds: 8)),
    );
    return Chamado.fromJson(r.data!);
  });

  @override
  Future<List<Chamado>> chamadosAbertos({int? garcomId}) => _call(() async {
    final r = await _dio.get<List<dynamic>>(
      'chamados',
      queryParameters: {'garcom_id': ?garcomId},
      options: Options(receiveTimeout: const Duration(seconds: 8)),
    );
    return r.data!.map((e) => Chamado.fromJson(e as Map<String, dynamic>)).toList();
  });

  @override
  Future<Chamado> atualizarChamado(String codigo, StatusChamado status, {int? garcomId}) => _call(() async {
    final r = await _dio.put<Map<String, dynamic>>(
      'chamados/$codigo',
      data: {'status': status.api, 'garcom_id': ?garcomId},
    );
    return Chamado.fromJson(r.data!);
  });

  @override
  Future<void> testarConexao() => _call(() async {
    await _dio.get<dynamic>('cardapio', options: Options(receiveTimeout: const Duration(seconds: 8)));
  });
}
