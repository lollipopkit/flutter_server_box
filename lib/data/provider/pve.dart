import 'dart:async';
import 'dart:io';

import 'package:computer/computer.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/pve.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:dartssh2/dartssh2.dart';

typedef PveCtrlFunc = Future<bool> Function(String node, String id);

final class PveProvider extends ChangeNotifier {
  final Spi spi;
  late String addr;
  late final SSHClient _client;
  late final ServerSocket _serverSocket;
  final List<SSHForwardChannel> _forwards = [];
  int _localPort = 0;

  PveProvider({required this.spi}) {
    final client = spi.server?.value.client;
    if (client == null) {
      throw Exception('Server client is null');
    }
    _client = client;
    final addr = spi.custom?.pveAddr;
    if (addr == null) {
      err.value = 'PVE address is null';
      return;
    }
    this.addr = addr;
    _init();
  }

  final err = ValueNotifier<String?>(null);
  final connected = Completer<void>();

  late final _ignoreCert = spi.custom?.pveIgnoreCert ?? false;
  late final session = Dio()
    ..httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.connectionFactory = cf;
        if (_ignoreCert) {
          client.badCertificateCallback = (_, __, ___) => true;
        }
        return client;
      },
      validateCertificate: _ignoreCert ? (_, __, ___) => true : null,
    );

  final data = ValueNotifier<PveRes?>(null);

  bool get onlyOneNode => data.value?.nodes.length == 1;
  String? release;
  bool isBusy = false;

  Future<void> _init() async {
    try {
      await _forward();
      await _login();
      await _getRelease();
    } on PveErr {
      err.value = l10n.pveLoginFailed;
    } catch (e, s) {
      Loggers.app.warning('PVE init failed', e, s);
      err.value = e.toString();
    } finally {
      connected.complete();
    }
  }

  Future<void> _forward() async {
    final url = Uri.parse(addr);
    if (_localPort == 0) {
      _serverSocket = await ServerSocket.bind('localhost', 0);
      _localPort = _serverSocket.port;
      _serverSocket.listen((socket) async {
        final forward = await _client.forwardLocal(url.host, url.port);
        _forwards.add(forward);
        forward.stream.cast<List<int>>().pipe(socket);
        socket.cast<List<int>>().pipe(forward.sink);
      });
      final newUrl = Uri.parse(addr)
          .replace(host: 'localhost', port: _localPort)
          .toString();
      debugPrint('Forwarding $newUrl to $addr');
    }
  }

  Future<ConnectionTask<Socket>> cf(
      Uri url, String? proxyHost, int? proxyPort) async {
    /* final serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
    final _localPort = serverSocket.port;
    serverSocket.listen((socket) async {
      final forward = await _client.forwardLocal(url.host, url.port);
      forwards.add(forward);
      forward.stream.cast<List<int>>().pipe(socket);
      socket.cast<List<int>>().pipe(forward.sink);
    });*/

    if (url.isScheme('https')) {
      return SecureSocket.startConnect('localhost', _localPort,
          onBadCertificate: (_) => true);
    } else {
      return Socket.startConnect('localhost', _localPort);
    }
  }

  Future<void> _login() async {
    final resp = await session.post(
      '$addr/api2/extjs/access/ticket',
      data: {
        'username': spi.user,
        'password': spi.pwd,
        'realm': 'pam',
        'new-format': '1'
      },
      options: Options(
        headers: {HttpHeaders.contentTypeHeader: Headers.jsonContentType},
      ),
    );
    try {
      final ticket = resp.data['data']['ticket'];
      session.options.headers['CSRFPreventionToken'] =
          resp.data['data']['CSRFPreventionToken'];
      session.options.headers['Cookie'] = 'PVEAuthCookie=$ticket';
    } catch (e) {
      throw PveErr(type: PveErrType.loginFailed, message: e.toString());
    }
  }

  /// Returns true if the PVE version is 8.0 or later
  Future<void> _getRelease() async {
    final resp = await session.get('$addr/api2/extjs/version');
    final version = resp.data['data']['release'] as String?;
    if (version != null) {
      release = version;
    }
  }

  Future<void> list() async {
    await connected.future;
    if (isBusy) return;
    isBusy = true;
    try {
      final resp = await session.get('$addr/api2/json/cluster/resources');
      final res = resp.data['data'] as List;
      final result =
          await Computer.shared.start(PveRes.parse, (res, data.value));
      data.value = result;
    } catch (e) {
      Loggers.app.warning('PVE list failed', e);
      err.value = e.toString();
    } finally {
      isBusy = false;
    }
  }

  Future<bool> reboot(String node, String id) async {
    await connected.future;
    final resp =
        await session.post('$addr/api2/json/nodes/$node/$id/status/reboot');
    return _isCtrlSuc(resp);
  }

  Future<bool> start(String node, String id) async {
    await connected.future;
    final resp =
        await session.post('$addr/api2/json/nodes/$node/$id/status/start');
    return _isCtrlSuc(resp);
  }

  Future<bool> stop(String node, String id) async {
    await connected.future;
    final resp =
        await session.post('$addr/api2/json/nodes/$node/$id/status/stop');
    return _isCtrlSuc(resp);
  }

  Future<bool> shutdown(String node, String id) async {
    await connected.future;
    final resp =
        await session.post('$addr/api2/json/nodes/$node/$id/status/shutdown');
    return _isCtrlSuc(resp);
  }

  bool _isCtrlSuc(Response resp) {
    return resp.statusCode == 200;
  }

  @override
  Future<void> dispose() async {
    super.dispose();
    await _serverSocket.close();
    for (final forward in _forwards) {
      forward.close();
    }
  }
}
