import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Totem = autoatendimento (cliente pede sozinho). Garçom = celular do atendente.
enum ModoOperacao {
  totem('totem', 'Totem de autoatendimento'),
  garcom('garcom', 'Garçom');

  const ModoOperacao(this.api, this.rotulo);
  final String api;
  final String rotulo;
}

@immutable
class AppSettings {
  const AppSettings({
    required this.configurado,
    required this.demo,
    required this.erpUrl,
    required this.token,
    required this.modo,
    required this.mesaFixa,
    required this.temaLocal,
    required this.pin,
    this.garcomId,
  });

  /// Já passou pelo pareamento/onboarding?
  final bool configurado;
  final bool demo;
  final String erpUrl;
  final String token;
  final ModoOperacao modo;

  /// Totem preso a uma mesa (tablet na mesa). Null = balcão/totem de entrada.
  final int? mesaFixa;

  /// Tema escolhido neste aparelho. Vazio = segue o tema definido no ERP.
  final String temaLocal;

  /// PIN local para acessar as configurações no totem (vale enquanto o ERP não define um).
  final String pin;

  /// Garçom deste celular (modo Garçom): recebe os chamados das mesas dele. Null = todos.
  final int? garcomId;

  AppSettings copyWith({
    bool? configurado,
    bool? demo,
    String? erpUrl,
    String? token,
    ModoOperacao? modo,
    int? Function()? mesaFixa,
    String? temaLocal,
    String? pin,
    int? Function()? garcomId,
  }) => AppSettings(
    configurado: configurado ?? this.configurado,
    demo: demo ?? this.demo,
    erpUrl: erpUrl ?? this.erpUrl,
    token: token ?? this.token,
    modo: modo ?? this.modo,
    mesaFixa: mesaFixa != null ? mesaFixa() : this.mesaFixa,
    temaLocal: temaLocal ?? this.temaLocal,
    pin: pin ?? this.pin,
    garcomId: garcomId != null ? garcomId() : this.garcomId,
  );
}

final prefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError('override em main()'));

class SettingsController extends Notifier<AppSettings> {
  static const _kConfigurado = 'configurado';
  static const _kDemo = 'demo';
  static const _kUrl = 'erp_url';
  static const _kToken = 'erp_token';
  static const _kModo = 'modo';
  static const _kMesa = 'mesa_fixa';
  static const _kTema = 'tema_local';
  static const _kPin = 'pin';
  static const _kGarcom = 'garcom_id';

  SharedPreferences get _p => ref.read(prefsProvider);

  @override
  AppSettings build() {
    final p = ref.watch(prefsProvider);
    return AppSettings(
      configurado: p.getBool(_kConfigurado) ?? false,
      demo: p.getBool(_kDemo) ?? true,
      erpUrl: p.getString(_kUrl) ?? '',
      token: p.getString(_kToken) ?? '',
      modo: ModoOperacao.values.firstWhere((m) => m.api == p.getString(_kModo), orElse: () => ModoOperacao.totem),
      mesaFixa: p.getInt(_kMesa),
      temaLocal: p.getString(_kTema) ?? '',
      pin: p.getString(_kPin) ?? '1234',
      garcomId: p.getInt(_kGarcom),
    );
  }

  Future<void> conectarErp({required String url, required String token}) async {
    await _p.setString(_kUrl, url);
    await _p.setString(_kToken, token);
    await _p.setBool(_kDemo, false);
    state = state.copyWith(erpUrl: url, token: token, demo: false);
  }

  Future<void> usarDemo() async {
    await _p.setBool(_kDemo, true);
    state = state.copyWith(demo: true);
  }

  Future<void> concluirOnboarding({required ModoOperacao modo, int? mesaFixa}) async {
    await _p.setString(_kModo, modo.api);
    if (mesaFixa == null) {
      await _p.remove(_kMesa);
    } else {
      await _p.setInt(_kMesa, mesaFixa);
    }
    await _p.setBool(_kConfigurado, true);
    state = state.copyWith(modo: modo, mesaFixa: () => mesaFixa, configurado: true);
  }

  Future<void> setModo(ModoOperacao modo) async {
    await _p.setString(_kModo, modo.api);
    state = state.copyWith(modo: modo);
  }

  Future<void> setMesaFixa(int? mesa) async {
    if (mesa == null) {
      await _p.remove(_kMesa);
    } else {
      await _p.setInt(_kMesa, mesa);
    }
    state = state.copyWith(mesaFixa: () => mesa);
  }

  /// '' = seguir o ERP.
  Future<void> setTemaLocal(String tema) async {
    await _p.setString(_kTema, tema);
    state = state.copyWith(temaLocal: tema);
  }

  Future<void> setPin(String pin) async {
    await _p.setString(_kPin, pin);
    state = state.copyWith(pin: pin);
  }

  Future<void> setGarcom(int? id) async {
    if (id == null) {
      await _p.remove(_kGarcom);
    } else {
      await _p.setInt(_kGarcom, id);
    }
    state = state.copyWith(garcomId: () => id);
  }

  /// Volta para a tela de pareamento.
  Future<void> resetar() async {
    await _p.setBool(_kConfigurado, false);
    state = state.copyWith(configurado: false);
  }
}

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(SettingsController.new);
