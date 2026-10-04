/// `PveBackend`'s certificate policy against a real TLS server on loopback,
/// through the session (`sbm_virt::pve` over FFI) and the authenticated
/// loopback tunnel it is given: an unpinned certificate is shown
/// (`certUnconfirmed`) and pinned by `confirmCert`, a different pin is
/// `certChanged`. The policy itself — a CA-signed certificate needing no pin,
/// idle connections let go before pveproxy closes them — is
/// `crates/sbm_virt/tests/pve_tls.rs`.
///
/// `test/fixtures/virt_tls/` holds a test CA and a `localhost` leaf it signed,
/// valid to 2126. Both are dated from 2019: macOS refuses a TLS leaf issued
/// after July 2019 that is valid for more than 825 days, and a certificate
/// that expires would make this test fail on a date rather than on a change.
/// Made with OpenSSL 3.4+:
///
/// ```sh
/// openssl req -x509 -newkey rsa:2048 -nodes -keyout ca.key -out ca.pem \
///   -not_before 20190101000000Z -not_after 21260101000000Z \
///   -subj "/CN=ServerBox Test CA" \
///   -addext "basicConstraints=critical,CA:TRUE" \
///   -addext "keyUsage=critical,keyCertSign,cRLSign"
/// openssl req -newkey rsa:2048 -nodes -keyout leaf.key -out leaf.csr \
///   -subj "/CN=localhost"
/// openssl x509 -req -in leaf.csr -CA ca.pem -CAkey ca.key -CAcreateserial \
///   -out leaf.pem -not_before 20190601000000Z -not_after 21260101000000Z \
///   -extfile <(printf \
///   'subjectAltName=DNS:localhost,IP:127.0.0.1\nextendedKeyUsage=serverAuth')
/// ```
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/pve_config.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/virt/pve_backend.dart';

import '../../helpers/pve_tunnel.dart';
import '../../helpers/rust_lib_helper.dart';

const _dir = 'test/fixtures/virt_tls';

/// SHA-256 of the leaf's DER form: what the backend must report and pin.
String _leafFingerprint() {
  final pem = File('$_dir/leaf.pem').readAsStringSync();
  final body = pem
      .split('\n')
      .where((l) => !l.startsWith('-----') && l.trim().isNotEmpty)
      .join();
  return sha256.convert(base64.decode(body)).toString();
}

void main() {
  // The certificate pin is decided by sbm_ffi (`certPinAccepts`)
  setUpAll(initRustLibForTest);

  late HttpServer server;
  final authHeaders = <String?>[];

  setUp(() async {
    authHeaders.clear();
    final ctx = SecurityContext()
      ..useCertificateChain('$_dir/leaf.pem')
      ..usePrivateKey('$_dir/leaf.key');
    server = await HttpServer.bindSecure(InternetAddress.loopbackIPv4, 0, ctx);
    server.listen((req) async {
      authHeaders.add(req.headers.value('authorization'));
      final data = switch (req.uri.path) {
        '/api2/json/version' => {'version': '8.2.4'},
        // One guest: a host with none has its permissions asked as well.
        '/api2/json/cluster/resources' => [
          {
            'id': 'lxc/100',
            'type': 'lxc',
            'vmid': 100,
            'node': 'pve',
            'name': 'ct',
            'status': 'running',
          },
        ],
        _ => null,
      };
      req.response
        ..statusCode = data == null ? 404 : 200
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'data': data}));
      await req.response.close();
    });
  });

  tearDown(() => server.close(force: true));

  PveBackend backend({
    String? pin,
    SecurityContext? trust,
    void Function(String)? onConfirmed,
  }) => PveBackend(
    serverId: 'srv',
    config: PveConfig(
      addr: 'https://localhost:8006',
      auth: PveAuth.token,
      tokenId: 'root@pam!sb',
      tokenSecret: 'secret',
      certSha256: pin,
    ),
    // Whatever the configured address, the far end is this test's server —
    // the dialer's job, done here without one.
    tunnel: (_, _) => loopbackTo(server.port),
    connect: (_, _) => ConnectionTask.fromSocket(
      Socket.connect(InternetAddress.loopbackIPv4, server.port),
      () {},
    ),
    // No system roots, so "a CA vouches for it" is exactly the test CA.
    securityContext: trust ?? SecurityContext(withTrustedRoots: false),
    onCertConfirmed: onConfirmed,
  );

  Future<VirtErr> err(Future<Object?> f) async {
    try {
      await f;
    } on VirtErr catch (e) {
      return e;
    }
    fail('expected a VirtErr');
  }

  test('unpinned: refused before any request, shown, then pinned', () async {
    final confirmed = <String>[];
    final pve = backend(onConfirmed: confirmed.add);
    addTearDown(pve.close);

    final e = await err(pve.load());
    expect(e.type, VirtErrType.certUnconfirmed);
    expect(e.cert?.fingerprint, _leafFingerprint());
    expect(e.cert?.subject, contains('localhost'));
    expect(authHeaders, isEmpty, reason: 'the token never left this device');

    // Only what was presented can be pinned.
    expect(
      (await err(pve.confirmCert('00' * 32))).type,
      VirtErrType.certUnconfirmed,
    );

    await pve.confirmCert(e.cert!.fingerprint);
    expect(confirmed, [_leafFingerprint()]);
    expect(pve.config.certSha256, _leafFingerprint());
    await pve.load();
    expect(authHeaders, isNotEmpty);
  });

  test('a pinned certificate is accepted without a CA', () async {
    final pve = backend(pin: _leafFingerprint());
    addTearDown(pve.close);
    await pve.load();
  });

  test('a different certificate than the pinned one is certChanged', () async {
    final old = 'ab' * 32;
    final pve = backend(pin: old);
    addTearDown(pve.close);
    final e = await err(pve.load());
    expect(e.type, VirtErrType.certChanged);
    expect(e.previousFingerprint, old);
    expect(e.cert?.fingerprint, _leafFingerprint());
    expect(authHeaders, isEmpty);
  });

  // An agent whose relay grant was already read refuses the tunnel before
  // anything is dialled.
  test('a tunnel refused before dialling is the load\'s error', () async {
    final pve = PveBackend(
      serverId: 'srv',
      config: const PveConfig(
        addr: 'https://localhost:8006',
        auth: PveAuth.token,
        tokenId: 'root@pam!sb',
        tokenSecret: 'secret',
      ),
      tunnel: (_, _) => Future.error(
        const ServerTcpErr(
          type: ServerTcpErrType.relayNotGranted,
          transport: ServerTransport.monitorHttp,
        ),
      ),
      connect: (_, _) => throw StateError('not dialled'),
    );
    addTearDown(pve.close);
    final e = await err(pve.load());
    expect(e.type, VirtErrType.relayNotGranted);
  });
}
