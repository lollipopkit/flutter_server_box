import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/custom.dart';
import 'package:server_box/data/model/server/pve.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/pve.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/status.dart';

const _raw = '''
{
    "data": [
        {
            "maxmem": 12884901888,
            "type": "lxc",
            "cpu": 0.0544631947461575,
            "netin": 65412250538,
            "template": 0,
            "diskread": 324033204224,
            "maxcpu": 8,
            "disk": 29767077888,
            "diskwrite": 707866570752,
            "node": "pve",
            "vmid": 100,
            "mem": 5389254656,
            "status": "running",
            "netout": 66898114418,
            "uptime": 1204757,
            "id": "lxc/100",
            "maxdisk": 134145380352,
            "name": "Jellyfin"
        },
        {
            "vmid": 101,
            "node": "pve",
            "uptime": 0,
            "netout": 0,
            "status": "stopped",
            "mem": 0,
            "id": "qemu/101",
            "name": "ubuntu",
            "maxdisk": 137438953472,
            "maxmem": 6442450944,
            "cpu": 0,
            "netin": 0,
            "type": "qemu",
            "disk": 0,
            "diskread": 0,
            "template": 0,
            "maxcpu": 8,
            "diskwrite": 0
        },
        {
            "maxcpu": 4,
            "template": 0,
            "diskread": 23287297536,
            "disk": 0,
            "diskwrite": 39555984896,
            "maxmem": 4294967296,
            "type": "qemu",
            "netin": 2190678599,
            "cpu": 0.0516426831961466,
            "id": "qemu/102",
            "maxdisk": 0,
            "name": "win",
            "node": "pve",
            "vmid": 102,
            "mem": 1791827968,
            "status": "running",
            "netout": 213292068,
            "uptime": 1013075
        },
        {
            "maxcpu": 12,
            "id": "node/pve",
            "disk": 358415503360,
            "maxdisk": 998011547648,
            "cgroup-mode": 2,
            "node": "pve",
            "maxmem": 29287632896,
            "type": "node",
            "status": "online",
            "mem": 11522887680,
            "cpu": 0.0451634094268353,
            "level": "",
            "uptime": 1204771
        },
        {
            "id": "storage/pve/DSM",
            "disk": 1250082226176,
            "maxdisk": 9909187887104,
            "storage": "DSM",
            "node": "pve",
            "status": "available",
            "type": "storage",
            "plugintype": "cifs",
            "content": "snippets,backup,images,rootdir,vztmpl,iso",
            "shared": 1
        },
        {
            "type": "storage",
            "status": "available",
            "plugintype": "dir",
            "content": "iso,vztmpl,images,rootdir,backup,snippets",
            "shared": 0,
            "node": "pve",
            "maxdisk": 1967847137280,
            "storage": "hard",
            "id": "storage/pve/hard",
            "disk": 620950544384
        },
        {
            "maxdisk": 998011547648,
            "storage": "local",
            "disk": 358415503360,
            "id": "storage/pve/local",
            "status": "available",
            "type": "storage",
            "plugintype": "dir",
            "content": "backup,snippets,rootdir,images,vztmpl,iso",
            "shared": 0,
            "node": "pve"
        },
        {
            "id": "sdn/pve/localnetwork",
            "node": "pve",
            "sdn": "localnetwork",
            "status": "ok",
            "type": "sdn"
        }
    ]
}''';

void main() {
  test('parse pve', () {
    final list = json.decode(_raw)['data'] as List;
    final pveItems = list.map((e) => PveResIface.fromJson(e)).toList();
    expect(pveItems.length, 8);
  });

  group('expired PVE sessions', () {
    const spi = Spi(
      name: 'pve',
      id: 'pve-id',
      custom: ServerCustom(pveAddr: 'https://pve.example.com:8006'),
    );

    ({
      ProviderContainer container,
      PveNotifier notifier,
      _StatusAdapter adapter,
      void Function() close,
    })
    harness(int statusCode) {
      final container = ProviderContainer(
        overrides: [
          serverProvider(
            spi.id,
          ).overrideWithValue(ServerState(spi: spi, status: InitStatus.status)),
        ],
      );
      final provider = pveProvider(spi);
      final subscription = container.listen(provider, (_, _) {});
      final notifier = container.read(provider.notifier);
      final adapter = _StatusAdapter(statusCode);
      final dio = Dio()..httpClientAdapter = adapter;
      notifier.useSessionForTest(dio);
      return (
        container: container,
        notifier: notifier,
        adapter: adapter,
        close: () {
          subscription.close();
          container.dispose();
        },
      );
    }

    test('resource listing drops a session after HTTP 401', () async {
      final test = harness(401);
      try {
        await test.notifier.list();

        expect(test.notifier.state.isConnected, isFalse);
        expect(test.notifier.state.error?.type, PveErrType.loginFailed);
        expect(test.adapter.closed, isTrue);
      } finally {
        test.close();
      }
    });

    test('VM control drops a session after HTTP 403', () async {
      final test = harness(403);
      try {
        await expectLater(
          test.notifier.start('node', '100'),
          throwsA(isA<DioException>()),
        );

        expect(test.notifier.state.isConnected, isFalse);
        expect(test.notifier.state.error?.type, PveErrType.loginFailed);
        expect(test.adapter.closed, isTrue);
      } finally {
        test.close();
      }
    });
  });
}

class _StatusAdapter implements HttpClientAdapter {
  _StatusAdapter(this.statusCode);

  final int statusCode;
  bool closed = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString('denied', statusCode);
  }

  @override
  void close({bool force = false}) => closed = true;
}
