/// `BmcNotifier`'s polling (#1788): the first read must start once `build`
/// has returned, or it reads a state that does not exist yet and never polls
/// again.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';
import 'package:server_box/data/model/server/bmc_credential.dart';
import 'package:server_box/data/model/server/bmc_target.dart';
import 'package:server_box/data/provider/bmc/bmc.dart';
import 'package:server_box/data/provider/bmc/targets.dart';
import 'package:server_box/data/provider/bmc_credential.dart';
import 'package:server_box/src/rust/api/bmc.dart';

import '../../helpers/rust_lib_helper.dart';

const _cred = BmcCredential(id: 'c', name: 'bmc', user: 'root', pwd: 'p');

final class _Creds extends BmcCredentialNotifier {
  @override
  BmcCredentialState build() => const BmcCredentialState(creds: [_cred]);

  /// What the account page does when a password is rotated.
  void rotate(String pwd) =>
      state = BmcCredentialState(creds: [_cred.copyWith(pwd: pwd)]);
}

final class _Targets extends BmcTargetsNotifier {
  _Targets(this._initial);

  final List<BmcTarget> _initial;

  @override
  BmcTargetsState build() => BmcTargetsState(
    targets: {for (final t in _initial) t.id: t},
    order: [for (final t in _initial) t.id],
  );

  void replace(BmcTarget target) {
    state = state.copyWith(targets: {...state.targets, target.id: target});
  }
}

/// The first state after [targetId]'s BMC was read, whatever it said.
Future<BmcState> _settled(ProviderContainer container, String targetId) {
  final settled = Completer<BmcState>();
  container.listen(bmcProvider(targetId), (_, next) {
    if (!next.isBusy && !settled.isCompleted) settled.complete(next);
  }, fireImmediately: true);
  return settled.future.timeout(const Duration(seconds: 20));
}

void main() {
  setUpAll(initRustLibForTest);

  test('the first read runs, and reports, once the page opens', () async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();

    final target = BmcTarget(
      id: 'bmc-web',
      name: 'web',
      addr: 'https://127.0.0.1:$port',
      credId: _cred.id,
    );
    final container = ProviderContainer(
      overrides: [
        bmcCredentialProvider.overrideWith(_Creds.new),
        bmcTargetsProvider.overrideWith(() => _Targets([target])),
      ],
    );
    addTearDown(container.dispose);

    final state = await _settled(container, target.id);
    expect(state.failure, isNotNull);
  });

  test('incomplete targets report exact failure (invalidUrl vs noCredential)', () {
    const badUrl = BmcTarget(
      id: 'b-url',
      name: 'bad',
      addr: 'not-a-url',
      credId: 'c',
    );
    const noCred = BmcTarget(
      id: 'b-cred',
      name: 'nocred',
      addr: 'https://127.0.0.1:443',
    );
    final container = ProviderContainer(
      overrides: [
        bmcCredentialProvider.overrideWith(_Creds.new),
        bmcTargetsProvider.overrideWith(() => _Targets([badUrl, noCred])),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(bmcProvider(badUrl.id)).failure, RedfishFailure.invalidUrl);
    expect(container.read(bmcProvider(noCred.id)).failure, RedfishFailure.noCredential);
  });

  test('renaming or retagging a target does not tear down the active session', () async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();

    final target = BmcTarget(
      id: 'bmc-stable',
      name: 'old-name',
      addr: 'https://127.0.0.1:$port',
      credId: _cred.id,
    );
    final targets = _Targets([target]);
    final container = ProviderContainer(
      overrides: [
        bmcCredentialProvider.overrideWith(_Creds.new),
        bmcTargetsProvider.overrideWith(() => targets),
      ],
    );
    addTearDown(container.dispose);

    final before = await _settled(container, target.id);
    expect(before.failure, isNotNull);

    var emissions = 0;
    final sub = container.listen(bmcProvider(target.id), (_, _) => emissions++);
    addTearDown(sub.close);

    targets.replace(target.copyWith(name: 'new-name', tags: const ['rack-a']));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(emissions, 0);
  });

  test('logServices awaits in-flight initial discovery and surfaces real failure', () async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();

    final target = BmcTarget(
      id: 'bmc-direct-logs',
      name: 'web',
      addr: 'https://127.0.0.1:$port',
      credId: _cred.id,
    );
    final container = ProviderContainer(
      overrides: [
        bmcCredentialProvider.overrideWith(_Creds.new),
        bmcTargetsProvider.overrideWith(() => _Targets([target])),
      ],
    );
    addTearDown(container.dispose);

    final sub = container.listen(bmcProvider(target.id), (_, _) {});
    addTearDown(sub.close);

    // Invoked immediately before initial discovery finishes: must wait for
    // discovery rather than throwing a spurious `noSystem`.
    await expectLater(
      container.read(bmcProvider(target.id).notifier).logServices(),
      throwsA(
        isA<BmcError>().having(
          (e) => e.failure,
          'failure',
          isNot(RedfishFailure.noSystem),
        ),
      ),
    );
  });

  test('a rebuild during a read still reads, and does not wait for the timer',
      () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final held = <Socket>[];
    server.listen((socket) {
      if (held.isEmpty) {
        held.add(socket);
      } else {
        socket.destroy();
      }
    });
    addTearDown(() async {
      for (final socket in held) {
        socket.destroy();
      }
      await server.close();
    });

    final target = BmcTarget(
      id: 'bmc-web',
      name: 'web',
      addr: 'https://127.0.0.1:${server.port}',
      credId: _cred.id,
    );
    final container = ProviderContainer(
      overrides: [
        bmcCredentialProvider.overrideWith(_Creds.new),
        bmcTargetsProvider.overrideWith(() => _Targets([target])),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(bmcProvider(target.id), (_, _) {});
    addTearDown(sub.close);

    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (held.isEmpty) {
      if (DateTime.now().isAfter(deadline)) {
        fail('the first read never connected');
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    (container.read(bmcCredentialProvider.notifier) as _Creds).rotate('q');

    final state = await _settled(container, target.id);
    expect(state.failure, isNotNull);
  });

  test('insertMedia and ejectMedia reject a stale expectedGeneration with closed', () async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();

    final target = BmcTarget(
      id: 'bmc-media-gen',
      name: 'web',
      addr: 'https://127.0.0.1:$port',
      credId: _cred.id,
    );
    final container = ProviderContainer(
      overrides: [
        bmcCredentialProvider.overrideWith(_Creds.new),
        bmcTargetsProvider.overrideWith(() => _Targets([target])),
      ],
    );
    addTearDown(container.dispose);

    final sub = container.listen(bmcProvider(target.id), (_, _) {});
    addTearDown(sub.close);

    final notifier = container.read(bmcProvider(target.id).notifier);
    final staleGen = notifier.endpointGeneration + 99;
    const slot = MediaSlot(
      path: '/redfish/v1/Managers/bmc/VirtualMedia/CD1',
      id: 'CD1',
      mediaTypes: ['CD'],
      inserted: false,
    );

    await expectLater(
      notifier.insertMedia(
        slot,
        'https://10.0.0.2/os.iso',
        expectedGeneration: staleGen,
      ),
      throwsA(
        isA<BmcError>().having(
          (e) => e.failure,
          'failure',
          RedfishFailure.closed,
        ),
      ),
    );
    await expectLater(
      notifier.ejectMedia(slot, expectedGeneration: staleGen),
      throwsA(
        isA<BmcError>().having(
          (e) => e.failure,
          'failure',
          RedfishFailure.closed,
        ),
      ),
    );
    await expectLater(
      notifier.setBoot(
        const BootRequest(target: 'Pxe', enabled: 'Once'),
        expectedGeneration: staleGen,
      ),
      throwsA(
        isA<BmcError>().having(
          (e) => e.failure,
          'failure',
          RedfishFailure.closed,
        ),
      ),
    );
    await expectLater(
      notifier.setLocator(true, expectedGeneration: staleGen),
      throwsA(
        isA<BmcError>().having(
          (e) => e.failure,
          'failure',
          RedfishFailure.closed,
        ),
      ),
    );
  });
}
