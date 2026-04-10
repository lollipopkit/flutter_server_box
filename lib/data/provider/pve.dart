import 'dart:async';
import 'dart:io';

import 'package:computer/computer.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/pve.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/server/single.dart';

part 'pve.freezed.dart';
part 'pve.g.dart';

typedef PveCtrlFunc = Future<bool> Function(String node, String id);

enum PveLoadingStep {
  none,
  forwarding,
  loggingIn,
  fetchingData,
}

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

  Dio get session => _session!;
  String get addrValue => addr!;

  SSHClient get _client {
    final serverState = ref.read(serverProvider(spiParam.id));
    final client = serverState.client;
    if (client == null) {
      throw PveErr(type: PveErrType.net, message: 'Server client is null');
    }
    return client;
  }

  @override
  PveState build(Spi spiParam) {
    ref.onDispose(() => dispose());
    final serverState = ref.watch(serverProvider(spiParam.id));
    if (serverState.client == null) {
      return const PveState(loadingStep: PveLoadingStep.forwarding);
    }
    final pveAddr = spiParam.custom?.pveAddr;
    if (pveAddr == null) {
      return PveState(error: PveErr(type: PveErrType.net, message: 'PVE address is null'));
    }
    addr = pveAddr;
    _ignoreCert = spiParam.custom?.pveIgnoreCert ?? false;
    _initSession();
    Future.microtask(() => _init());
    return const PveState(loadingStep: PveLoadingStep.forwarding);
  }

  void _initSession() {
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
    state = state.copyWith(error: null, isConnected: false, loadingStep: PveLoadingStep.forwarding);
    await _init();
  }

  Future<void> _init() async {
    try {
      if (!ref.mounted) return;
      state = state.copyWith(loadingStep: PveLoadingStep.forwarding);
      await _forward();
      if (!ref.mounted) return;
      state = state.copyWith(loadingStep: PveLoadingStep.loggingIn);
      await _login();
      if (!ref.mounted) return;
      state = state.copyWith(loadingStep: PveLoadingStep.fetchingData);
      await _getRelease();
      if (!ref.mounted) return;
      state = state.copyWith(isConnected: true);
      await list();
      if (!ref.mounted) return;
      state = state.copyWith(loadingStep: PveLoadingStep.none);
    } on PveErr catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(error: e, loadingStep: PveLoadingStep.none);
    } catch (e, s) {
      if (!ref.mounted) return;
      Loggers.app.warning('PVE init failed', e, s);
      state = state.copyWith(error: PveErr(type: PveErrType.unknown, message: e.toString()), loadingStep: PveLoadingStep.none);
    }
  }

  Future<void> _forward() async {
    final url = Uri.parse(addrValue);
    if (_localPort == 0) {
      _serverSocket = await ServerSocket.bind('localhost', 0);
      _localPort = _serverSocket!.port;
      _serverSocket!.listen((socket) async {
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
    final password = useKeyAuth ? spiParam.custom?.pvePwd : spiParam.pwd;
    if (password == null) {
      throw PveErr(type: PveErrType.loginFailed, message: 'PVE password is required. Please set it in server settings.');
    }
    final resp = await _requestTicket({
      'username': spiParam.user,
      'password': password,
      'realm': 'pam',
      'new-format': '1',
    });

    final data = _readTicketData(resp);
    if (data['NeedTFA'] == 1 || data['TFA'] != null) {
      _pendingTfaChallenge = data['ticket'] as String?;
      throw PveErr(type: PveErrType.needTfa, message: 'Two-factor authentication is enabled on this PVE server. Please enter the OTP code.');
    }

    _pendingTfaChallenge = null;
    _setAuthHeaders(data);
  }

  Future<void> submitTfaCode(String otp) async {
    final challenge = _pendingTfaChallenge;
    if (challenge == null) {
      throw PveErr(type: PveErrType.needTfa, message: 'The OTP challenge has expired. Please refresh and try again.');
    }
    if (otp.trim().isEmpty) {
      throw PveErr(type: PveErrType.needTfa, message: 'OTP code is required.');
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
      state = state.copyWith(error: null, loadingStep: PveLoadingStep.none);
    } on PveErr catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(error: e, loadingStep: PveLoadingStep.none);
      rethrow;
    } catch (e, s) {
      if (!ref.mounted) return;
      Loggers.app.warning('PVE TFA login failed', e, s);
      state = state.copyWith(error: PveErr(type: PveErrType.unknown, message: e.toString()), loadingStep: PveLoadingStep.none);
      rethrow;
    }
  }

  Future<void> _loginWithTfaChallenge(String challenge, String otp) async {
    try {
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
        throw PveErr(type: PveErrType.needTfa, message: 'OTP verification failed. Please try again with a fresh code.');
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
      throw PveErr(type: PveErrType.invalidResponse, message: 'PVE login returned an invalid response body.');
    }
    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      throw PveErr(type: PveErrType.invalidResponse, message: 'PVE login response did not contain a valid data payload.');
    }
    return data;
  }

  void _setAuthHeaders(Map<String, dynamic> data) {
    final ticket = data['ticket'];
    if (ticket == null) {
      throw PveErr(type: PveErrType.loginFailed, message: 'PVE login succeeded but no auth ticket was returned.');
    }
    session.options.headers['CSRFPreventionToken'] = data['CSRFPreventionToken'];
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
      state = state.copyWith(error: PveErr(type: PveErrType.unknown, message: e.toString()));
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
    _pendingTfaChallenge = null;
    try {
      await _serverSocket?.close();
    } catch (e, s) {
      Loggers.app.warning('Failed to close server socket', e, s);
    }
    for (final forward in _forwards) {
      try {
        forward.close();
      } catch (e, s) {
        Loggers.app.warning('Failed to close forward', e, s);
      }
    }
  }
}
