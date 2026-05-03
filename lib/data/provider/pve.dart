import 'dart:async';
import 'dart:io';

import 'package:computer/computer.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/pve.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/server/single.dart';

part 'pve.freezed.dart';
part 'pve.g.dart';

enum PveLoadingStep { none, forwarding, loggingIn, fetchingData }

@freezed
abstract class PveState with _$PveState {
  const factory PveState({
    @Default(null) PveErr? error,
    @Default(null) PveRes? data,
    @Default(null) String? release,
    @Default(false) bool isBusy,
    @Default(false) bool isConnected,
    @Default(PveLoadingStep.none) PveLoadingStep loadingStep,
  }) = _PveState;
}

@riverpod
class PveNotifier extends _$PveNotifier {
  String? addr;
  ServerSocket? _serverSocket;
  final List<SSHForwardChannel> _forwards = [];
  int _localPort = 0;
  Dio? _session;
  bool _ignoreCert = false;
  String? _pendingTfaChallenge;
  Future<void>? _initFuture;
  int _sessionGeneration = 0;

  Dio get session => _session!;
  String get addrValue => addr!;

  SSHClient get _client {
    final serverState = ref.read(serverProvider(spiParam.id));
    final client = serverState.client;
    if (client == null) {
      throw PveErr(type: PveErrType.net, message: l10n.pveServerClientMissing);
    }
    return client;
  }

  @override
  PveState build(Spi spiParam) {
    final pveAddr = spiParam.custom?.pveAddr;
    if (pveAddr == null) {
      return PveState(
        error: PveErr(type: PveErrType.net, message: l10n.pveAddressMissing),
      );
    }
    addr = pveAddr;
    _ignoreCert = spiParam.custom?.pveIgnoreCert ?? false;

    ref.onDispose(() => dispose());
    ref.listen(serverProvider(spiParam.id), (prev, next) {
      final prevClient = prev?.client;
      final nextClient = next.client;
      if (nextClient == null) {
        if (prevClient != null) {
          unawaited(_closeSession(clearPendingTfa: true));
          state = state.copyWith(
            isConnected: false,
            isBusy: false,
            loadingStep: PveLoadingStep.forwarding,
          );
        }
        return;
      }

      if (prevClient == null) {
        Future.microtask(() => _init());
        return;
      }

      if (!identical(prevClient, nextClient)) {
        Future.microtask(() async {
          await _closeSession(clearPendingTfa: true);
          if (!ref.mounted) return;
          state = state.copyWith(
            error: null,
            isConnected: false,
            isBusy: false,
            loadingStep: PveLoadingStep.forwarding,
          );
          await _init();
        });
      }
    });

    final serverState = ref.read(serverProvider(spiParam.id));
    if (serverState.client != null) {
      Future.microtask(() => _init());
    }
    return const PveState(loadingStep: PveLoadingStep.forwarding);
  }

  void _initSession() {
    _session?.close(force: true);
    _session = Dio()
      ..httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.connectionFactory = cf;
          if (_ignoreCert) {
            client.badCertificateCallback = (_, _, _) => true;
          }
          return client;
        },
        validateCertificate: _ignoreCert ? (_, _, _) => true : null,
      );
  }

  bool get onlyOneNode => state.data?.nodes.length == 1;

  Future<void> reconnect() async {
    await _closeSession(clearPendingTfa: true);
    if (!ref.mounted) return;
    state = state.copyWith(
      error: null,
      data: null,
      release: null,
      isConnected: false,
      isBusy: false,
      loadingStep: PveLoadingStep.forwarding,
    );
    await _init();
  }

  Future<void> _init() async {
    final existing = _initFuture;
    if (existing != null) return existing;
    final future = _initImpl();
    _initFuture = future;
    try {
      await future;
    } finally {
      if (identical(_initFuture, future)) {
        _initFuture = null;
      }
    }
  }

  Future<void> _initImpl() async {
    final generation = _sessionGeneration;
    try {
      if (!ref.mounted) return;
      _initSession();
      state = state.copyWith(loadingStep: PveLoadingStep.forwarding);
      await _forward(generation);
      if (!_isActiveInit(generation)) return;
      state = state.copyWith(loadingStep: PveLoadingStep.loggingIn);
      await _login();
      if (!_isActiveInit(generation)) return;
      state = state.copyWith(loadingStep: PveLoadingStep.fetchingData);
      await _getRelease();
      if (!_isActiveInit(generation)) return;
      state = state.copyWith(isConnected: true);
      await list();
      if (!_isActiveInit(generation)) return;
      state = state.copyWith(loadingStep: PveLoadingStep.none);
    } on PveErr catch (e) {
      if (!_isActiveInit(generation)) return;
      state = state.copyWith(error: e, loadingStep: PveLoadingStep.none);
    } catch (e, s) {
      if (!_isActiveInit(generation)) return;
      Loggers.app.warning('PVE init failed', e, s);
      state = state.copyWith(
        error: PveErr(type: PveErrType.unknown, message: e.toString()),
        loadingStep: PveLoadingStep.none,
      );
    }
  }

  bool _isActiveInit(int generation) {
    return ref.mounted && generation == _sessionGeneration;
  }

  Future<void> _forward(int generation) async {
    final url = Uri.parse(addrValue);
    if (_localPort == 0) {
      final serverSocket = await ServerSocket.bind('localhost', 0);
      if (!_isActiveInit(generation)) {
        await serverSocket.close();
        return;
      }
      _serverSocket = serverSocket;
      _localPort = serverSocket.port;
      serverSocket.listen((socket) async {
        try {
          final forward = await _client.forwardLocal(url.host, url.port);
          _forwards.add(forward);
          forward.stream.cast<List<int>>().pipe(socket);
          socket.cast<List<int>>().pipe(forward.sink);
        } catch (e, s) {
          Loggers.app.warning('PVE forward failed', e, s);
          socket.destroy();
        }
      });
    }
  }

  Future<ConnectionTask<Socket>> cf(
    Uri url,
    String? proxyHost,
    int? proxyPort,
  ) async {
    if (url.isScheme('https')) {
      return SecureSocket.startConnect(
        'localhost',
        _localPort,
        onBadCertificate: (_) => true,
      );
    } else {
      return Socket.startConnect('localhost', _localPort);
    }
  }

  Future<void> _login() async {
    final useKeyAuth = spiParam.keyId != null;
    final password = (useKeyAuth ? spiParam.custom?.pvePwd : spiParam.pwd)
        ?.trim();
    if (password == null || password.isEmpty) {
      throw PveErr(
        type: PveErrType.loginFailed,
        message: l10n.pvePasswordRequired,
      );
    }
    final resp = await _requestTicket({
      'username': spiParam.user,
      'password': password,
      'realm': 'pam',
      'new-format': '1',
    });

    final data = _readTicketData(resp);
    if (data['NeedTFA'] == 1 || data['TFA'] != null) {
      final ticket = data['ticket'];
      if (ticket is! String || ticket.isEmpty) {
        throw PveErr(
          type: PveErrType.invalidResponse,
          message: l10n.pveInvalidResponseData,
        );
      }
      _pendingTfaChallenge = ticket;
      throw PveErr(type: PveErrType.needTfa, message: l10n.pveOtpRequired);
    }

    _pendingTfaChallenge = null;
    _setAuthHeaders(data);
  }

  Future<void> submitTfaCode(String otp) async {
    final challenge = _pendingTfaChallenge;
    if (challenge == null) {
      throw PveErr(
        type: PveErrType.needTfa,
        message: l10n.pveOtpChallengeExpired,
      );
    }
    if (otp.trim().isEmpty) {
      throw PveErr(type: PveErrType.needTfa, message: l10n.pveOtpCodeRequired);
    }

    if (!ref.mounted) return;
    state = state.copyWith(error: null, loadingStep: PveLoadingStep.loggingIn);

    try {
      await _loginWithTfaChallenge(challenge, otp.trim());
      if (!ref.mounted) return;
      state = state.copyWith(loadingStep: PveLoadingStep.fetchingData);
      await _getRelease();
      if (!ref.mounted) return;
      state = state.copyWith(isConnected: true);
      await list();
      if (!ref.mounted) return;
      if (state.error == null) {
        state = state.copyWith(error: null, loadingStep: PveLoadingStep.none);
      } else {
        state = state.copyWith(loadingStep: PveLoadingStep.none);
      }
    } on PveErr catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(error: e, loadingStep: PveLoadingStep.none);
      rethrow;
    } catch (e, s) {
      if (!ref.mounted) return;
      Loggers.app.warning('PVE TFA login failed', e, s);
      state = state.copyWith(
        error: PveErr(type: PveErrType.unknown, message: e.toString()),
        loadingStep: PveLoadingStep.none,
      );
      rethrow;
    }
  }

  Future<void> _loginWithTfaChallenge(String challenge, String otp) async {
    try {
      // The current OTP dialog only collects a code, so this flow supports
      // Proxmox TOTP challenges for now.
      final resp = await _requestTicket({
        'username': spiParam.user,
        'password': 'totp:$otp',
        'realm': 'pam',
        'tfa-challenge': challenge,
        'new-format': '1',
      });
      final data = _readTicketData(resp);
      _pendingTfaChallenge = null;
      _setAuthHeaders(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw PveErr(
          type: PveErrType.needTfa,
          message: l10n.pveOtpVerificationFailed,
        );
      }
      rethrow;
    }
  }

  Future<Response<dynamic>> _requestTicket(Map<String, dynamic> data) {
    return session.post(
      '$addrValue/api2/json/access/ticket',
      data: data,
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );
  }

  Map<String, dynamic> _readTicketData(Response<dynamic> resp) {
    final body = resp.data;
    if (body is! Map<String, dynamic>) {
      throw PveErr(
        type: PveErrType.invalidResponse,
        message: l10n.pveInvalidResponseBody,
      );
    }
    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      throw PveErr(
        type: PveErrType.invalidResponse,
        message: l10n.pveInvalidResponseData,
      );
    }
    return data;
  }

  void _setAuthHeaders(Map<String, dynamic> data) {
    final ticket = data['ticket'];
    if (ticket == null) {
      throw PveErr(
        type: PveErrType.loginFailed,
        message: l10n.pveMissingAuthTicket,
      );
    }
    session.options.headers['CSRFPreventionToken'] =
        data['CSRFPreventionToken'];
    session.options.headers['Cookie'] = 'PVEAuthCookie=$ticket';
  }

  /// Returns true if the PVE version is 8.0 or later
  Future<void> _getRelease() async {
    final resp = await session.get('$addrValue/api2/extjs/version');
    final version = resp.data['data']['release'] as String?;
    if (version != null && ref.mounted) {
      state = state.copyWith(release: version);
    }
  }

  Future<void> list() async {
    if (!state.isConnected || state.isBusy) return;
    state = state.copyWith(isBusy: true);
    try {
      final resp = await session.get('$addrValue/api2/json/cluster/resources');
      final res = resp.data['data'] as List;
      final result = await Computer.shared.start(PveRes.parse, (
        res,
        state.data,
      ));
      if (!ref.mounted) return;
      state = state.copyWith(data: result, error: null);
    } catch (e) {
      if (!ref.mounted) return;
      Loggers.app.warning('PVE list failed', e);
      state = state.copyWith(
        error: PveErr(type: PveErrType.unknown, message: e.toString()),
      );
    } finally {
      if (ref.mounted) {
        state = state.copyWith(isBusy: false);
      }
    }
  }

  Future<bool> reboot(String node, String id) async {
    if (!state.isConnected) return false;
    final resp = await session.post(
      '$addrValue/api2/json/nodes/$node/$id/status/reboot',
    );
    final success = _isCtrlSuc(resp);
    if (success) await list(); // Refresh data
    return success;
  }

  Future<bool> start(String node, String id) async {
    if (!state.isConnected) return false;
    final resp = await session.post(
      '$addrValue/api2/json/nodes/$node/$id/status/start',
    );
    final success = _isCtrlSuc(resp);
    if (success) await list(); // Refresh data
    return success;
  }

  Future<bool> stop(String node, String id) async {
    if (!state.isConnected) return false;
    final resp = await session.post(
      '$addrValue/api2/json/nodes/$node/$id/status/stop',
    );
    final success = _isCtrlSuc(resp);
    if (success) await list(); // Refresh data
    return success;
  }

  Future<bool> shutdown(String node, String id) async {
    if (!state.isConnected) return false;
    final resp = await session.post(
      '$addrValue/api2/json/nodes/$node/$id/status/shutdown',
    );
    final success = _isCtrlSuc(resp);
    if (success) await list(); // Refresh data
    return success;
  }

  bool _isCtrlSuc(Response resp) {
    return resp.statusCode == 200;
  }

  Future<void> dispose() async {
    await _closeSession(clearPendingTfa: true);
  }

  Future<void> _closeSession({required bool clearPendingTfa}) async {
    if (clearPendingTfa) {
      _pendingTfaChallenge = null;
    }
    _sessionGeneration++;
    _initFuture = null;
    _session?.close(force: true);
    _session = null;
    try {
      await _serverSocket?.close();
    } catch (e, s) {
      Loggers.app.warning('Failed to close server socket', e, s);
    } finally {
      _serverSocket = null;
      _localPort = 0;
    }
    final forwards = _forwards.toList();
    _forwards.clear();
    for (final forward in forwards) {
      try {
        await forward.close();
      } catch (e, s) {
        Loggers.app.warning('Failed to close forward', e, s);
      }
    }
  }
}
