/// `BmcNotifier`'s polling (#1788): the first read must start once `build`
/// has returned, or it reads a state that does not exist yet and never polls
/// again.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';
import 'package:server_box/data/model/server/bmc_cfg.dart';
import 'package:server_box/data/model/server/bmc_credential.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/bmc/bmc.dart';
import 'package:server_box/data/provider/bmc_credential.dart';

import '../../helpers/rust_lib_helper.dart';
import '../../helpers/spi_fixture.dart';

const _cred = BmcCredential(id: 'c', name: 'bmc', user: 'root', pwd: 'p');

final class _Creds extends BmcCredentialNotifier {
  @override
  BmcCredentialState build() => const BmcCredentialState(creds: [_cred]);

  /// What the account page does when a password is rotated.
  void rotate(String pwd) =>
      state = BmcCredentialState(creds: [_cred.copyWith(pwd: pwd)]);
}

/// The first state after [spi]'s BMC was read, whatever it said.
Future<BmcState> _settled(ProviderContainer container, Spi spi) {
  final settled = Completer<BmcState>();
  container.listen(bmcProvider(spi), (_, next) {
    if (!next.isBusy && !settled.isCompleted) settled.complete(next);
  }, fireImmediately: true);
  return settled.future.timeout(const Duration(seconds: 20));
}

void main() {
  setUpAll(initRustLibForTest);

  test('the first read runs, and reports, once the page opens', () async {
    // Nothing listens there: the read fails fast, which is a result.
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();

    final spi = spiFixture(name: 'web', id: 'web').copyWith(
      bmc: BmcCfg(addr: 'https://127.0.0.1:$port', credId: _cred.id),
    );
    final container = ProviderContainer(
      overrides: [bmcCredentialProvider.overrideWith(_Creds.new)],
    );
    addTearDown(container.dispose);

    final state = await _settled(container, spi);
    expect(state.failure, isNotNull);
  });

  test('a rebuild during a read still reads, and does not wait for the timer',
      () async {
    // The first connection is held open and never answered, so the first
    // build's read is still going when the account changes; every later one
    // is closed at once, which is a result.
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

    final spi = spiFixture(name: 'web', id: 'web').copyWith(
      bmc: BmcCfg(addr: 'https://127.0.0.1:${server.port}', credId: _cred.id),
    );
    final container = ProviderContainer(
      overrides: [bmcCredentialProvider.overrideWith(_Creds.new)],
    );
    addTearDown(container.dispose);
    final sub = container.listen(bmcProvider(spi), (_, _) {});
    addTearDown(sub.close);

    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (held.isEmpty) {
      if (DateTime.now().isAfter(deadline)) fail('the first read never connected');
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    (container.read(bmcCredentialProvider.notifier) as _Creds).rotate('q');

    final state = await _settled(container, spi);
    expect(state.failure, isNotNull);
  });
}
