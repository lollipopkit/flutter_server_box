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
import 'package:server_box/data/provider/bmc/bmc.dart';
import 'package:server_box/data/provider/bmc_credential.dart';

import '../../helpers/rust_lib_helper.dart';
import '../../helpers/spi_fixture.dart';

const _cred = BmcCredential(id: 'c', name: 'bmc', user: 'root', pwd: 'p');

final class _Creds extends BmcCredentialNotifier {
  @override
  BmcCredentialState build() => const BmcCredentialState(creds: [_cred]);
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

    final settled = Completer<BmcState>();
    container.listen(bmcProvider(spi), (_, next) {
      if (!next.isBusy && !settled.isCompleted) settled.complete(next);
    }, fireImmediately: true);

    final state = await settled.future.timeout(const Duration(seconds: 20));
    expect(state.failure, isNotNull);
  });
}
