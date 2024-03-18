import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:toolbox/data/model/server/pve.dart';
import 'package:toolbox/data/model/server/server_private_info.dart';

final class PveProvider extends ChangeNotifier {
  final ServerPrivateInfo spi;
  late final String addr;
  //late final SSHClient _client;

  PveProvider({
    required this.spi,
  }) {
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
    _init().then((_) => connected.complete());
  }

  final err = ValueNotifier<String?>(null);
  final connected = Completer<void>();
  final session = Dio();

  // int _localPort = 0;
  // String get addr => 'http://127.0.0.1:$_localPort';

  Future<void> _init() async {
    //await _forward();
    await _login();
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
    final ticket = resp.data['data']['ticket'];
    session.options.headers['CSRFPreventionToken'] =
        resp.data['data']['CSRFPreventionToken'];
    session.options.headers['Cookie'] = 'PVEAuthCookie=$ticket';
  }

  Future<PveRes> list() async {
    await connected.future;
    final resp = await session.get('$addr/api2/json/cluster/resources');
    final list = resp.data['data'] as List;
    final items = list.map((e) => PveResIface.fromJson(e)).toList();
    final qemus = <PveQemu>[];
    final lxcs = <PveLxc>[];
    final nodes = <PveNode>[];
    final storages = <PveStorage>[];
    final sdns = <PveSdn>[];
    for (final item in items) {
      switch (item.type) {
        case PveResType.lxc:
          lxcs.add(item as PveLxc);
          break;
        case PveResType.qemu:
          qemus.add(item as PveQemu);
          break;
        case PveResType.node:
          nodes.add(item as PveNode);
          break;
        case PveResType.storage:
          storages.add(item as PveStorage);
          break;
        case PveResType.sdn:
          sdns.add(item as PveSdn);
          break;
      }
    }
    return PveRes(
      qemus: qemus,
      lxcs: lxcs,
      nodes: nodes,
      storages: storages,
      sdns: sdns,
    );
  }
}
