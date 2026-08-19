import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/service/watch_sync.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/model/server/server_private_info.dart';

import 'helpers/spi_fixture.dart';

/// The watch app parses this payload (`PhoneConnMgr.parse`) and has no way to
/// ask for a correction, so its shape is the contract between two processes on
/// two devices that update independently.
void main() {
  Spi monitorSpi({
    required String id,
    required String name,
    String addr = 'https://10.0.0.1:3770',
    String? user = 'admin',
    String? pwd = 'secret',
    bool ignoreCert = false,
  }) {
    return spiFixture(name: name, id: id).copyWith(
      monitorHttp: MonitorHttpCredential(
        addr: addr,
        user: user,
        pwd: pwd,
        ignoreCert: ignoreCert,
      ),
    );
  }

  Map<String, dynamic> payload({
    required List<String> selectedIds,
    List<Spi> servers = const [],
    Map<String, String> tokens = const {},
    List<String> legacyUrls = const [],
  }) {
    return WatchSync.payloadFrom(
      selectedIds: selectedIds,
      lookup: (id) => servers.where((e) => e.id == id).firstOrNull,
      tokens: tokens,
      legacyUrls: legacyUrls,
    );
  }

  test('carries what the watch needs to reach the agent', () {
    final result = payload(
      selectedIds: ['a'],
      servers: [monitorSpi(id: 'a', name: 'Home', ignoreCert: true)],
      tokens: const {'a': 'watch-token'},
    );

    expect(result['v'], 3);
    expect(result['servers'], [
      {
        'id': 'a',
        'name': 'Home',
        'addr': 'https://10.0.0.1:3770',
        'token': 'watch-token',
        'ignoreCert': true,
      },
    ]);
    final server = (result['servers'] as List).single as Map;
    expect(server.containsKey('user'), isFalse);
    expect(server.containsKey('pwd'), isFalse);
  });

  test('keeps the selection order, which is the order of the watch pages', () {
    final result = payload(
      selectedIds: ['c', 'a', 'b'],
      servers: [
        monitorSpi(id: 'a', name: 'A'),
        monitorSpi(id: 'b', name: 'B'),
        monitorSpi(id: 'c', name: 'C'),
      ],
      tokens: const {'a': 'a-token', 'b': 'b-token', 'c': 'c-token'},
    );

    final names = (result['servers'] as List).map((e) => e['name']).toList();
    expect(names, ['C', 'A', 'B']);
  });

  test('drops a picked server that no longer exists', () {
    final result = payload(
      selectedIds: ['gone', 'a'],
      servers: [monitorSpi(id: 'a', name: 'A')],
      tokens: const {'a': 'a-token'},
    );

    expect((result['servers'] as List).single['id'], 'a');
  });

  test('drops a picked server that lost its monitor config', () {
    // The watch has no SSH client, so an SSH-only server is an entry it could
    // never load — worse than not being listed at all.
    final result = payload(
      selectedIds: ['ssh', 'a'],
      servers: [
        spiFixture(name: 'SSH only', id: 'ssh', ip: '10.0.0.9'),
        monitorSpi(id: 'a', name: 'A'),
      ],
      tokens: const {'a': 'a-token', 'ssh': 'ssh-token'},
    );

    expect((result['servers'] as List).single['id'], 'a');
  });

  test('drops a server whose monitor address is blank', () {
    final result = payload(
      selectedIds: ['blank'],
      servers: [monitorSpi(id: 'blank', name: 'Blank', addr: '   ')],
      tokens: const {'blank': 'blank-token'},
    );

    expect(result['servers'], isEmpty);
  });

  test('drops a server when no scoped token could be issued', () {
    final result = payload(
      selectedIds: ['a'],
      servers: [monitorSpi(id: 'a', name: 'A', user: '', pwd: '')],
    );

    expect(result['servers'], isEmpty);
  });

  test('trims the address so the watch can append paths to it', () {
    final result = payload(
      selectedIds: ['a'],
      servers: [
        monitorSpi(id: 'a', name: 'A', addr: '  https://10.0.0.1:3770 '),
      ],
      tokens: const {'a': 'a-token'},
    );

    expect((result['servers'] as List).single['addr'], 'https://10.0.0.1:3770');
  });

  test('still emits the pre-v2 url list for a watch app that has not updated', () {
    // TODO: drop with `SettingStore.watchLegacyUrls`.
    final result = payload(
      selectedIds: const [],
      legacyUrls: ['http://10.0.0.2:3770/status'],
    );

    expect(result['urls'], ['http://10.0.0.2:3770/status']);
    expect(result['servers'], isEmpty);
  });
}
