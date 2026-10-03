/// The BMC client's FFI surface (`sbm_ffi::api::bmc` over `sbm_redfish`):
/// what the app relies on without a BMC — the stored pin format, the pin
/// decision PVE's `HttpClient` asks, the power plan and confirmation, and
/// failures arriving typed.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/cert_fingerprint.dart';
import 'package:server_box/src/rust/api/bmc.dart';

import '../../helpers/rust_lib_helper.dart';

const _dir = 'test/fixtures/virt_tls';

List<int> _leafDer() {
  final pem = File('$_dir/leaf.pem').readAsStringSync();
  final body = pem
      .split('\n')
      .where((l) => !l.startsWith('-----') && l.trim().isNotEmpty)
      .join();
  return base64.decode(body);
}

RedfishSystem _system(PowerState state, List<String> resetTypes) =>
    RedfishSystem(
      powerState: state,
      resetTarget: '/redfish/v1/Systems/1/Actions/ComputerSystem.Reset',
      resetTypes: resetTypes,
    );

void main() {
  setUpAll(initRustLibForTest);

  group('certificate pins', () {
    test('a stored pin comes out of normalisation unchanged', () {
      // What every install already holds: the Dart `certFingerprint`, SHA-256
      // of the DER as lowercase hex without separators.
      final stored = sha256.convert(_leafDer()).toString();
      expect(certNormalizeFingerprint(input: stored), stored);
      expect(certFingerprint(der: _leafDer()), stored);
    });

    test('a pasted spelling reduces to the stored form', () {
      final stored = sha256.convert(_leafDer()).toString();
      final pretty = [
        for (var i = 0; i < stored.length; i += 2) stored.substring(i, i + 2),
      ].join(':').toUpperCase();
      expect(certNormalizeFingerprint(input: pretty), stored);
    });

    test('accepts exactly the pinned certificate', () {
      final der = _leafDer();
      final pin = sha256.convert(der).toString();
      expect(certPinAccepts(pin: pin, der: der), isTrue);
      // Dart compared `pin.toLowerCase()`; an upper-case pin still matches
      expect(certPinAccepts(pin: pin.toUpperCase(), der: der), isTrue);
      expect(certPinAccepts(pin: 'ab' * 32, der: der), isFalse);
      // Nothing reviewed is nothing trusted
      expect(certPinAccepts(pin: null, der: der), isFalse);
      expect(certPinAccepts(pin: '', der: der), isFalse);
      // A prefix of the real fingerprint is not it
      expect(certPinAccepts(pin: pin.substring(0, 32), der: der), isFalse);
    });

    test('reads a certificate as the platform does', () async {
      final ctx = SecurityContext()
        ..useCertificateChain('$_dir/leaf.pem')
        ..usePrivateKey('$_dir/leaf.key');
      final server = await SecureServerSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
        ctx,
      );
      addTearDown(server.close);
      server.listen((s) => s.destroy(), onError: (_) {});

      final info = await bmcFetchServerCert(
        host: '127.0.0.1',
        port: server.port,
      );
      expect(info.fingerprint, sha256.convert(_leafDer()).toString());
      expect(info, certInfoFromDer(der: _leafDer()));

      // The subject and issuer in the form Dart's `X509Certificate` printed,
      // which is what the review dialogs showed before
      final socket = await SecureSocket.connect(
        '127.0.0.1',
        server.port,
        onBadCertificate: (_) => true,
      );
      final peer = socket.peerCertificate!;
      socket.destroy();
      expect(info.subject, peer.subject);
      expect(info.issuer, peer.issuer);
      expect(
        info.notAfter,
        peer.endValidity.millisecondsSinceEpoch ~/ 1000,
      );
      expect(info.isExpired, isFalse);
      // The same formatter a stored pin goes through
      expect(info.prettyFingerprint, prettyCertFingerprint(info.fingerprint));
    });

    test('a closed port is unreachable, not a certificate problem', () async {
      final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = probe.port;
      await probe.close();
      await expectLater(
        bmcFetchServerCert(host: '127.0.0.1', port: port),
        throwsA(
          isA<BmcError>().having(
            (e) => e.failure,
            'failure',
            RedfishFailure.unreachable,
          ),
        ),
      );
    });
  });

  group('client', () {
    test('refuses an address it cannot use, typed', () {
      expect(
        () => BmcClient(baseUrl: 'http://10.0.0.9', user: 'root'),
        throwsA(
          isA<BmcError>().having(
            (e) => e.failure,
            'failure',
            RedfishFailure.invalidUrl,
          ),
        ),
      );
    });

    test('an unpinned certificate is refused at the handshake', () async {
      final ctx = SecurityContext()
        ..useCertificateChain('$_dir/leaf.pem')
        ..usePrivateKey('$_dir/leaf.key');
      final server = await HttpServer.bindSecure(
        InternetAddress.loopbackIPv4,
        0,
        ctx,
      );
      addTearDown(server.close);
      var requests = 0;
      server.listen((req) {
        requests++;
        req.response.close();
      });

      final client = BmcClient(
        baseUrl: 'https://127.0.0.1:${server.port}',
        user: 'root',
        password: 'not sent',
      );
      addTearDown(client.dispose);
      await expectLater(
        client.discover(),
        throwsA(
          isA<BmcError>().having(
            (e) => e.failure,
            'failure',
            RedfishFailure.certificateRejected,
          ),
        ),
      );
      // No request — and so no password — reached whatever answered
      expect(requests, 0);
      await client.close();
    });
  });

  group('power', () {
    test('plans the reset type the service allows', () {
      expect(
        bmcPlan(
          system: _system(PowerState.on_, ['ForceRestart']),
          intent: PowerIntent.restart,
        )?.resetType,
        'ForceRestart',
      );
      expect(
        bmcPlan(
          system: _system(PowerState.on_, [
            'GracefulRestart',
            'ForceRestart',
          ]),
          intent: PowerIntent.restart,
        )?.resetType,
        'GracefulRestart',
      );
      expect(
        bmcPlan(
          system: _system(PowerState.on_, ['On']),
          intent: PowerIntent.forceOff,
        ),
        isNull,
      );
    });

    test('a restart seen only "on" has not been confirmed', () {
      final watch = PowerWatch(
        before: PowerState.on_,
        intent: PowerIntent.restart,
      );
      addTearDown(watch.dispose);
      expect(watch.observe(now: PowerState.on_), isFalse);
      // Passing through a transition is the evidence a restart leaves
      expect(watch.observe(now: PowerState.poweringOff), isFalse);
      expect(watch.observe(now: PowerState.on_), isTrue);
    });

    test('a shutdown lands on "off", not on the way there', () {
      final watch = PowerWatch(
        before: PowerState.on_,
        intent: PowerIntent.gracefulShutdown,
      );
      addTearDown(watch.dispose);
      expect(watch.observe(now: PowerState.poweringOff), isFalse);
      expect(watch.observe(now: PowerState.off), isTrue);
    });
  });
}
