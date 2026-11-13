import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/ssh/agent.dart';
import 'package:server_box/core/ssh/client.dart';
import 'package:server_box/core/ssh/config.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';

void main() {
  group('IdentityAgent, as OpenSSH reads it', () {
    const env = {
      'SSH_AUTH_SOCK': '/run/agent',
      'OP': '/op',
      'EMPTY': '',
      'PCT': '/has-%u',
    };
    String? expand(String value, {Map<String, String> environment = env}) =>
        SSHConfig.expandIdentityAgent(
          value,
          hostname: 'box.example',
          remoteUser: 'deploy',
          originalHost: 'box',
          port: 2222,
          environment: environment,
        );

    test('SSH_AUTH_SOCK and \$NAME are variables', () {
      expect(expand('SSH_AUTH_SOCK'), '/run/agent');
      expect(expand(r'$OP'), '/op');
    });

    test('a variable that is not set, or empty, names no socket', () {
      expect(expand('SSH_AUTH_SOCK', environment: const {}), isNull);
      expect(expand(r'$EMPTY'), isNull);
      expect(expand(r'${MISSING}/agent.sock'), isNull);
    });

    test('a path has \${NAME} and the tokens expanded in one pass', () {
      expect(expand(r'${OP}/agent.sock'), '/op/agent.sock');
      expect(
        expand('/tmp/%r@%h:%p-%n-%%.sock'),
        '/tmp/deploy@box.example:2222-box-%.sock',
      );
      // A variable's value is taken as it is, never read for tokens again.
      expect(expand(r'${PCT}/a.sock'), '/has-%u/a.sock');
    });

    test('a token this does not know names no socket', () {
      expect(expand('/tmp/%C.sock'), isNull);
      expect(expand('/tmp/a.sock%'), isNull);
    });
  });

  test('a named pipe is told from a socket file', () {
    expect(isNamedPipe(windowsAgentPipe), isTrue);
    expect(isNamedPipe('//./pipe/openssh-ssh-agent'), isTrue);
    expect(isNamedPipe(r'\\?\PIPE\agent'), isTrue);
    expect(isNamedPipe('/tmp/agent.sock'), isFalse);
    expect(isNamedPipe(r'C:\Users\me\agent.sock'), isFalse);
  });

  group('a pipe as a socket', () {
    test('carries an agent conversation', () async {
      final io = _FakePipe.answering(
        SSHKeyPairAgent(SSHKeyPair.fromPem(_testPrivateKey)),
      );
      final agent = SSHAgentClient(PipeSocket(io));

      expect(await agent.identities(), hasLength(1));
      await agent.close();
      expect(io.closed, isTrue);
    });

    test('the far end hanging up ends it', () async {
      final io = _FakePipe();
      final socket = PipeSocket(io);
      final ended = socket.stream.toList();

      io.reads.add(null);

      await socket.done;
      expect(await ended, isEmpty);
      expect(io.closed, isTrue);
    });

    test('closing does not wait for a write the pipe never takes', () async {
      final io = _FakePipe()..writeHangs = true;
      final socket = PipeSocket(io);
      socket.stream.listen(null);
      socket.sink.add([1, 2, 3]);
      await Future<void>.delayed(Duration.zero);

      await socket.close().timeout(const Duration(seconds: 1));

      expect(io.closed, isTrue);
      await socket.done;
    });

    test('a failed write reaches done and the stream, once', () async {
      // A read already under way when the end comes still answers.
      final io = _FakePipe()
        ..writeError = StateError('broken pipe')
        ..readsAfterClose = true;
      final socket = PipeSocket(io);
      final errors = <Object>[];
      socket.stream.listen(null, onError: errors.add);

      socket.sink.add([1]);

      await expectLater(socket.done, throwsA(isA<StateError>()));
      // Bytes the pipe still hands over after the end are dropped, not added
      // to a closed stream.
      io.reads.add(Uint8List.fromList([9]));
      await Future<void>.delayed(Duration.zero);
      expect(errors, hasLength(1));
      expect(io.closed, isTrue);
    });
  });

  group('the agent a server names', skip: !sshAgentSupported || isWindows, () {
    late Directory dir;
    late ServerSocket agentSocket;
    late String path;
    final agentConnections = <Socket>[];
    final agentHungUp = <Future<void>>[];

    setUp(() async {
      dir = await Directory('/tmp').createTemp('sbag');
      path = '${dir.path}/a.sock';
      agentSocket = await ServerSocket.bind(
        InternetAddress(path, type: InternetAddressType.unix),
        0,
      );
      final agent = SSHKeyPairAgent(SSHKeyPair.fromPem(_testPrivateKey));
      agentSocket.listen((conn) {
        agentConnections.add(conn);
        final hungUp = Completer<void>();
        agentHungUp.add(hungUp.future);
        final frames = _Frames();
        conn.listen(
          (bytes) async {
            for (final request in frames.add(bytes)) {
              conn.add(_frame(await agent.handleRequest(request)));
            }
          },
          onError: (_) {},
          onDone: hungUp.complete,
        );
      });
    });

    tearDown(() async {
      for (final c in agentConnections) {
        c.destroy();
      }
      agentConnections.clear();
      agentHungUp.clear();
      await agentSocket.close();
      await dir.delete(recursive: true);
    });

    test('offers its keys after the stored ones', () async {
      final client = await _createClient(identityAgent: path);

      expect(client.identities, isNull);
      expect(client.signers, hasLength(1));
      expect(
        client.signers!.single.publicKey,
        SSHKeyPair.fromPem(_testPrivateKey).single.toPublicKey().encode(),
      );
    });

    test('is let go once authentication is over', () async {
      final client = await _createClient(identityAgent: path);
      expect(agentHungUp, hasLength(1));

      client.close();

      await agentHungUp.single.timeout(const Duration(seconds: 5));
    });

    test('one that is not there falls back on the password', () async {
      final client = await _createClient(
        identityAgent: '${dir.path}/missing.sock',
        pwd: 'account-password',
      );

      expect(client.signers, isEmpty);
      expect(await client.onPasswordRequest!(), 'account-password');
    });

    test('one that is not there, and nothing else, is said', () async {
      await expectLater(
        _createClient(identityAgent: '${dir.path}/missing.sock'),
        throwsA(
          isA<SSHErr>()
              .having((e) => e.type, 'type', SSHErrType.agent)
              .having((e) => e.message, 'message', contains('missing.sock')),
        ),
      );
    });
  });
}

Future<SSHClient> _createClient({
  required String identityAgent,
  String? pwd,
}) async {
  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final peers = <Socket>[];
  server.listen(peers.add);
  addTearDown(() async {
    for (final p in peers) {
      p.destroy();
    }
    await server.close();
  });
  final client = await genClient(
    Spi(
      name: 'agent',
      id: 'agent',
      ssh: SshCredential(
        ip: '127.0.0.1',
        port: server.port,
        user: 'tester',
        pwd: pwd,
        identityAgent: identityAgent,
      ),
    ),
    knownHostFingerprints: const {},
  );
  client.authenticated.ignore();
  client.done.ignore();
  addTearDown(client.close);
  return client;
}

Uint8List _frame(Uint8List payload) => (BytesBuilder()
      ..add((ByteData(4)..setUint32(0, payload.length)).buffer.asUint8List())
      ..add(payload))
    .takeBytes();

class _Frames {
  final _buffer = BytesBuilder();

  List<Uint8List> add(List<int> bytes) {
    _buffer.add(bytes);
    var all = _buffer.takeBytes();
    final frames = <Uint8List>[];
    while (all.length >= 4) {
      final length = ByteData.sublistView(all, 0, 4).getUint32(0);
      if (all.length < 4 + length) break;
      frames.add(Uint8List.sublistView(all, 4, 4 + length));
      all = Uint8List.sublistView(all, 4 + length);
    }
    _buffer.add(all);
    return frames;
  }
}

final String _testPrivateKey = File(
  'packages/dartssh2/test/fixtures/ssh-ed25519/id_ed25519',
).readAsStringSync();

/// A pipe whose reads a test feeds, or which answers like [answering]'s agent.
class _FakePipe implements PipeIo {
  _FakePipe();

  factory _FakePipe.answering(SSHAgentHandler agent) {
    final pipe = _FakePipe();
    final frames = _Frames();
    pipe._onWrite = (bytes) async {
      for (final request in frames.add(bytes)) {
        pipe.reads.add(_frame(await agent.handleRequest(request)));
      }
    };
    return pipe;
  }

  final reads = StreamController<Uint8List?>();
  late final _reads = StreamIterator(reads.stream);
  Future<void> Function(List<int>)? _onWrite;
  var writeHangs = false;
  Object? writeError;
  var closed = false;

  /// Whether a read waiting when this closes still answers with what comes.
  var readsAfterClose = false;

  @override
  Future<Uint8List?> read() async {
    if (closed && !readsAfterClose) return null;
    final more = await _reads.moveNext();
    return more && (readsAfterClose || !closed) ? _reads.current : null;
  }

  @override
  Future<void> write(List<int> data) async {
    if (writeHangs) return Completer<void>().future;
    if (writeError case final e?) throw e;
    await _onWrite?.call(data);
  }

  @override
  Future<void> close() async {
    closed = true;
    // What the real one does: a read waiting answers none.
    if (!readsAfterClose) reads.add(null);
  }
}
