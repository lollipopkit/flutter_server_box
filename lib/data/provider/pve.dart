import 'dart:async';

import 'package:computer/computer.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/material.dart';
import 'package:toolbox/core/extension/context/locale.dart';
import 'package:toolbox/data/model/app/error.dart';
import 'package:toolbox/data/model/server/pve.dart';
import 'package:toolbox/data/model/server/server_private_info.dart';
import 'package:toolbox/data/res/logger.dart';

typedef PveCtrlFunc = Future<bool> Function(String node, String id);

final class PveProvider extends ChangeNotifier {
  final ServerPrivateInfo spi;
  late final String addr;
  //late final SSHClient _client;

  PveProvider({required this.spi}) {
    // final client = _spi.server?.client;
    // if (client == null) {
    //   throw Exception('Server client is null');
    // }
    // _client = client;
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
      validateCertificate: _ignoreCert ? (_, __, ___) => true : null,
    );
  final data = ValueNotifier<PveRes?>(null);
  bool get onlyOneNode => data.value?.nodes.length == 1;
  String? release;
  bool isBusy = false;

  // int _localPort = 0;
  // String get addr => 'http://127.0.0.1:$_localPort';

  Future<void> _init() async {
    try {
      //await _forward();
      await _login();
      await _release;
    } on PveErr {
      err.value = l10n.pveLoginFailed;
    } catch (e) {
      Loggers.app.warning('PVE init failed', e);
      err.value = e.toString();
    } finally {
      connected.complete();
    }
  }

  // Future<void> _forward() async {
  //   var retries = 0;
  //   while (retries < 3) {
  //     try {
  //       _localPort = Random().nextInt(1000) + 37000;
  //       print('Forwarding local port $_localPort');
  //       final serverSocket = await ServerSocket.bind('localhost', _localPort);
  //       final forward = await _client.forwardLocal('127.0.0.1', 8006);
  //       serverSocket.listen((socket) {
  //         forward.stream.cast<List<int>>().pipe(socket);
  //         socket.pipe(forward.sink);
  //       });
  //       return;
  //     } on SocketException {
  //       retries++;
  //     }
  //   }
  //   throw Exception('Failed to bind local port');
  // }

  Future<void> _login() async {
    final resp = await session.post('$addr/api2/extjs/access/ticket', data: {
      'username': spi.user,
      'password': spi.pwd,
      'realm': 'pam',
      'new-format': '1'
    });
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
  Future<void> get _release async {
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
}
