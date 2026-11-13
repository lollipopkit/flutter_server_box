import 'dart:async';

import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:server_box/core/diag.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/ssh/agent.dart';
import 'package:server_box/core/ssh/algorithms.dart';
import 'package:server_box/core/ssh/auth.dart';
import 'package:server_box/core/ssh/host_keys.dart';
import 'package:server_box/core/ssh/identities.dart';
import 'package:server_box/core/ssh/key_unlock.dart';
import 'package:server_box/core/ssh/proxy_command_socket.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/host_cert_authority.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/store/stores.dart';

enum GenSSHClientStatus { socket, key, pwd }

Future<SSHClient> genClient(
  Spi spi, {
  void Function(GenSSHClientStatus)? onStatus,

  /// Private key material supplied when this runs in an isolate.
  String? privateKey,

  /// Jump-host private key material supplied when this runs in an isolate.
  String? jumpPrivateKey,

  /// Preferred in isolate mode; otherwise credentials come from [Stores.key].
  Map<String, String>? privateKeysByKeyId,

  /// Preferred in isolate mode; otherwise servers come from [Stores.server].
  Map<String, Spi>? jumpSpisById,
  Duration timeout = const Duration(seconds: 5),

  /// Jump server supplied when this runs in an isolate with key authentication.
  Spi? jumpSpi,

  /// Handles keyboard-interactive authentication prompts.
  SSHKeyboardInteractiveHandler? onKeyboardInteractive,
  Map<String, String>? knownHostFingerprints,

  /// Preferred in isolate mode; otherwise from [Stores.setting].
  List<HostCertAuthority>? hostCertAuthorities,
  HostKeyPersistCallback? onHostKeyAccepted,
  Future<bool> Function(HostKeyPromptInfo info)? onHostKeyPrompt,
  Set<String>? visitedServerIds,
}) async {
  // Bound once, up front: everything below needs SSH, and a server reached
  // only over monitor's HTTP API has no credential to connect with
  final ssh = spi.ssh;
  if (ssh == null) {
    throw SSHErr(
      type: SSHErrType.connect,
      message: 'No SSH credential configured for ${spi.name}',
    );
  }

  final chainVisitedServerIds = visitedServerIds ?? <String>{};
  final currentServerId = hostKeyServerId(spi);
  if (!chainVisitedServerIds.add(currentServerId)) {
    throw SSHErr(
      type: SSHErrType.connect,
      message:
          'Invalid jump chain: cycle detected at ${spi.name} ($currentServerId)',
    );
  }
  // Also detect address-level cycles for cloned servers.
  final addrKey = 'addr:${ssh.ip}:${ssh.port}';
  if (!chainVisitedServerIds.add(addrKey)) {
    throw SSHErr(
      type: SSHErrType.connect,
      message: 'Invalid jump chain: address cycle at ${ssh.ip}:${ssh.port}',
    );
  }

  // Where the byte stream comes from is the axis that decides which half of
  // this function runs, and a failure looks the same from the outside whichever
  // it was. Recorded before the socket is opened, since a connection that never
  // returns leaves no later crumb.
  //
  // Guarded, because the two `Redact` calls are two hash passes and a regex,
  // and this runs per connection and again per jump hop. On the transfer
  // isolate — which installs no sink, statics being per isolate — that would
  // all be computed for a crumb nothing receives.
  final via = switch (ssh) {
    _ when spi.resolvedJumpIds.isNotEmpty => 'jump',
    _ when ssh.proxyCommand != null => 'proxy',
    _ => 'direct',
  };
  if (Diag.enabled) {
    Diag.crumb(
      SbDiag.server,
      'ssh connect',
      data: {
        'server': Redact.id(spi.id),
        'host': Redact.host(ssh.ip),
        'via': via,
      },
    );
  }

  /// The other end of the crumb above, which on its own says only that a
  /// connection was attempted.
  ///
  /// [at] is which half failed, and the halves fail for unrelated reasons: a
  /// socket that never opens is the network, the jump chain or the
  /// `ProxyCommand`, while everything after it is a key, a password or a host
  /// key that no longer matches. Together with `via` this says which of the
  /// three routes is unreliable and where — a question nothing else here can
  /// answer, since a caller is handed one error and cannot tell the phases
  /// apart either.
  void connectFailed(String at, Object e) {
    if (!Diag.enabled) return;
    Diag.crumb(
      SbDiag.server,
      'ssh connect failed',
      level: DiagLevel.warning,
      data: {'via': via, 'at': at, 'error': Redact.error(e)},
    );
  }

  onStatus?.call(GenSSHClientStatus.socket);

  final hostKeyCache = Map<String, String>.from(
    knownHostFingerprints ?? loadKnownHostFingerprints(),
  );
  final hostKeyPersist = onHostKeyAccepted ?? persistHostKeyFingerprint;
  final hostKeyPrompt = onHostKeyPrompt ?? showHostKeyPrompt;
  final authorities = hostCertAuthorities ?? loadHostCertAuthorities();

  String? alterUser;
  // Where the socket goes: the configured host, or `alterUrl`'s when the
  // first did not answer. The authorities are scoped to the host dialled.
  var dialHost = ssh.ip;
  var dialPort = ssh.port;

  final socket =
      await () async {
        // Proxy
        final jumpSpis = _resolveJumpCandidates(
          spi: spi,
          preloadedJumpSpi: jumpSpi,
          jumpSpisById: jumpSpisById,
        );
        final jumpIds = spi.resolvedJumpIds;
        if (jumpIds.isNotEmpty && jumpSpis.isEmpty) {
          final message = l10n.jumpServersNotFoundFmt(
            spi.name,
            jumpIds.join(', '),
          );
          Loggers.app.warning(message);
          throw SSHErr(type: SSHErrType.connect, message: message);
        }
        if (jumpSpis.isNotEmpty) {
          Object? lastNetworkError;
          StackTrace? lastNetworkStack;

          for (final jumpSpi_ in jumpSpis) {
            SSHClient? jumpClient;
            try {
              String? nextJumpPrivateKey;
              final jumpSpiKeyRef = jumpSpi_.ssh?.keyRef;
              if (jumpSpi != null &&
                  jumpSpi.id == jumpSpi_.id &&
                  jumpPrivateKey != null) {
                // Isolate mode may preload first-hop key and pass it via [jumpPrivateKey].
                nextJumpPrivateKey = jumpPrivateKey;
              } else if (jumpSpiKeyRef != null) {
                nextJumpPrivateKey = privateKeysByKeyId?[jumpSpiKeyRef];
              }

              jumpClient = await genClient(
                jumpSpi_,
                privateKey: nextJumpPrivateKey,
                privateKeysByKeyId: privateKeysByKeyId,
                jumpSpisById: jumpSpisById,
                timeout: timeout,
                onKeyboardInteractive: onKeyboardInteractive,
                knownHostFingerprints: hostKeyCache,
                hostCertAuthorities: authorities,
                onHostKeyAccepted: hostKeyPersist,
                onHostKeyPrompt: hostKeyPrompt,
                visitedServerIds: {...chainVisitedServerIds},
              );

              final forwarded = await jumpClient
                  .forwardLocal(ssh.ip, ssh.port)
                  .timeout(
                    timeout,
                    onTimeout: () => throw TimeoutException(
                      'forwardLocal timed out after ${timeout.inSeconds}s',
                    ),
                  );
              return _JumpSocket(forwarded, jumpClient);
            } catch (e, stack) {
              try {
                jumpClient?.close();
              } catch (_) {}
              if (!isJumpFailoverError(e)) {
                rethrow;
              }
              lastNetworkError = e;
              lastNetworkStack = stack;
              Loggers.app.warning(
                'Jump server ${jumpSpi_.name} failed, trying next candidate',
                e,
                stack,
              );
            }
          }

          Error.throwWithStackTrace(
            lastNetworkError ??
                SSHErr(
                  type: SSHErrType.connect,
                  message: l10n.noJumpServerAvailable,
                ),
            lastNetworkStack ?? StackTrace.current,
          );
        }

        final proxyCommand = ssh.proxyCommand;
        if (proxyCommand != null && proxyCommand.trim().isNotEmpty) {
          return await ProxyCommandSocket.connect(
            command: proxyCommand,
            host: ssh.ip,
            port: ssh.port,
            user: ssh.user,
            originalHost: spi.name,
            jump: ssh.resolvedJumpIds.join(','),
            timeout: timeout,
          );
        }

        // Direct
        try {
          return await SSHSocket.connect(ssh.ip, ssh.port, timeout: timeout);
        } catch (e) {
          Loggers.app.warning('genClient', e);
          if (ssh.alterUrl == null) rethrow;
          try {
            final res = ssh.parseAlterUrl();
            alterUser = res.$2;
            dialHost = res.$1;
            dialPort = res.$3;
            return await SSHSocket.connect(res.$1, res.$3, timeout: timeout);
          } catch (e) {
            Loggers.app.warning('genClient alterUrl', e);
            rethrow;
          }
        }
      }().onError((Object e, s) {
        // Attached rather than wrapping the closure in a `try`, so the body above
        // keeps its indentation and stays reviewable against its own history.
        connectFailed('socket', e);
        Error.throwWithStackTrace(e, s);
      });

  // Everything past here can throw with the socket already open, and the
  // caller is given a key error and no handle — so nobody can close it. A
  // status poll retries, so one unreadable key used to mean one leaked socket
  // per attempt, or on the ProxyCommand path one leaked `/bin/sh` per attempt.
  //
  // `destroy`, not `close`: there is nothing buffered worth flushing, and on
  // the ProxyCommand path this is what kills the process.
  try {
    final client = await _authenticatedClient(
      socket: socket,
      spi: spi,
      ssh: ssh,
      timeout: timeout,
      alterUser: alterUser,
      privateKey: privateKey,
      privateKeysByKeyId: privateKeysByKeyId,
      onStatus: onStatus,
      onKeyboardInteractive: onKeyboardInteractive,
      hostKeyVerifier: HostKeyVerifier(
        spi: spi,
        cache: hostKeyCache,
        persistCallback: hostKeyPersist,
        prompt: hostKeyPrompt,
      ),
      hostCertificateTrust: HostCertAuthority.trustFor(
        authorities,
        host: dialHost,
        port: dialPort,
        alsoKnownAs: [ssh.ip],
      ),
    );
    if (Diag.enabled) {
      Diag.crumb(SbDiag.server, 'ssh connect ok', data: {'via': via});
    }
    return client;
  } catch (e) {
    connectFailed('auth', e);
    socket.destroy();
    rethrow;
  }
}

/// The client itself, once there is a socket to build it on.
///
/// Split out so that [genClient] has one place to undo the socket from: every
/// throw in here happens after it is open.
Future<SSHClient> _authenticatedClient({
  required SSHSocket socket,
  required Spi spi,
  required SshCredential ssh,
  required Duration timeout,
  required String? alterUser,
  required String? privateKey,
  required Map<String, String>? privateKeysByKeyId,
  required void Function(GenSSHClientStatus)? onStatus,
  required SSHKeyboardInteractiveHandler? onKeyboardInteractive,
  required HostKeyVerifier hostKeyVerifier,
  required SSHHostCertificateTrust? hostCertificateTrust,
}) async {
  final agent = await openSshAgent(
    ssh,
    hasOtherAuth: ssh.pwd?.isNotEmpty == true || ssh.keyRefs.isNotEmpty,
    originalHost: spi.name,
  );
  try {
    final client = await _clientWith(
      socket: socket,
      spi: spi,
      ssh: ssh,
      timeout: timeout,
      alterUser: alterUser,
      privateKey: privateKey,
      privateKeysByKeyId: privateKeysByKeyId,
      onStatus: onStatus,
      onKeyboardInteractive: onKeyboardInteractive,
      hostKeyVerifier: hostKeyVerifier,
      hostCertificateTrust: hostCertificateTrust,
      agentKeys: agent?.keys ?? const [],
    );
    if (agent != null) {
      // Needed only to sign; once authentication is over either way, nothing
      // asks it again.
      unawaited(
        client.authenticated
            .catchError((Object _) {})
            .whenComplete(agent.client.close),
      );
    }
    return client;
  } catch (_) {
    await agent?.client.close();
    rethrow;
  }
}

Future<SSHClient> _clientWith({
  required SSHSocket socket,
  required Spi spi,
  required SshCredential ssh,
  required Duration timeout,
  required String? alterUser,
  required String? privateKey,
  required Map<String, String>? privateKeysByKeyId,
  required void Function(GenSSHClientStatus)? onStatus,
  required SSHKeyboardInteractiveHandler? onKeyboardInteractive,
  required HostKeyVerifier hostKeyVerifier,
  required SSHHostCertificateTrust? hostCertificateTrust,
  required List<SSHSigner> agentKeys,
}) async {
  SSHClient passwordClient() {
    onStatus?.call(
      agentKeys.isEmpty ? GenSSHClientStatus.pwd : GenSSHClientStatus.key,
    );
    return SSHClient(
      socket,
      username: alterUser ?? ssh.user,
      signers: agentKeys,
      onPasswordRequest: () => ssh.pwd,
      onUserInfoRequest: onKeyboardInteractive == null
          ? null
          : (request) => onKeyboardInteractive(spi, request),
      onVerifyHostKey: hostKeyVerifier.call,
      hostCertificateTrust: hostCertificateTrust,
      algorithms: SshAlgorithms.of(
        ssh,
        preferCertificates: hostCertificateTrust != null,
        pinnedKeyTypes: hostKeyVerifier.pinnedKeyTypes,
      ),
      handshakeTimeout: timeout,
      authTimeout: timeout,
    );
  }

  final keyRefs = ssh.keyRefs;
  if (keyRefs.isEmpty) {
    return passwordClient();
  }
  final keyMaterial = <String, String>{};
  if (privateKey != null) keyMaterial[keyRefs.first] = privateKey;
  if (privateKeysByKeyId != null) {
    for (final ref in keyRefs) {
      final pem = privateKeysByKeyId[ref];
      if (pem != null) keyMaterial[ref] = pem;
    }
  } else if (privateKey == null || keyRefs.length > 1) {
    try {
      for (final entry in (await resolvePrivateKeysAsync(
        ssh,
        originalHost: spi.name,
      )).entries) {
        keyMaterial.putIfAbsent(entry.key, () => entry.value);
      }
    } catch (e, s) {
      if (ssh.pwd?.isNotEmpty != true && agentKeys.isEmpty) rethrow;
      Loggers.app.warning(
        'SSH key unavailable for ${spi.name}; going on with '
        '${agentKeys.isEmpty ? 'the password' : 'the agent\'s keys'}',
        e,
        s,
      );
      return passwordClient();
    }
  }
  if (keyMaterial.isEmpty) {
    if (ssh.pwd?.isNotEmpty == true || agentKeys.isNotEmpty) {
      return passwordClient();
    }
    throw SSHErr(
      type: SSHErrType.noPrivateKey,
      message: l10n.privateKeyNotFoundFmt(
        ssh.keyId ?? ssh.keyPath ?? keyRefs.first,
      ),
    );
  }

  onStatus?.call(GenSSHClientStatus.key);
  // A key stored encrypted is opened here, once per key per run. Nothing
  // happens for a key that is not — including one already opened before it was
  // handed to another isolate, which is why the transfer path can reach this
  // line with no screen to ask on.
  final openedKeys = <String>[];
  for (final entry in keyMaterial.entries) {
    openedKeys.add(
      await PrivateKeyUnlock.open(
        entry.value,
        cacheKey: entry.key,
        keyName: privateKeyDisplayName(entry.key),
      ),
    );
  }
  final List<SSHKeyPair> identities;
  try {
    // Must use [compute] here, instead of [Computer.shared.start].
    // Which [identitiesOf] does, for whatever it has not parsed yet.
    identities = await identitiesOf(openedKeys);
  } catch (e) {
    // A PEM that will not parse is a key problem and the caller has a category
    // for those. Left raw it arrived as whatever the parser threw — naming
    // neither the key nor the server, and matching none of the handling every
    // other key failure gets.
    throw SSHErr(
      type: SSHErrType.noPrivateKey,
      message: l10n.privateKeyFileUnreadable(
        privateKeyDisplayName(keyRefs.first),
        '$e',
      ),
    );
  }
  return SSHClient(
    socket,
    // The same fallback user the password branch above uses. Key auth read
    // `ssh.user` regardless, so a server reached through its `alterUrl` — which
    // is where `alterUser` comes from — authenticated as the primary host's
    // user and failed with a permission error naming neither.
    username: alterUser ?? ssh.user,
    identities: identities,
    signers: agentKeys,
    onPasswordRequest: ssh.pwd?.isNotEmpty == true ? () => ssh.pwd : null,
    onUserInfoRequest: onKeyboardInteractive == null
        ? null
        : (request) => onKeyboardInteractive(spi, request),
    onVerifyHostKey: hostKeyVerifier.call,
    hostCertificateTrust: hostCertificateTrust,
    algorithms: SshAlgorithms.of(
      ssh,
      preferCertificates: hostCertificateTrust != null,
      pinnedKeyTypes: hostKeyVerifier.pinnedKeyTypes,
    ),
    handshakeTimeout: timeout,
    authTimeout: timeout,
  );
}

/// A forwarded channel that owns the jump connection carrying it.
///
/// `forwardLocal` hands back a channel and nothing else, so the authenticated
/// jump client it came from had no owner: on success nobody held it — closing
/// the target closed the channel and left the jump session, its socket and its
/// process running until the far end timed them out — and on a target failure
/// the socket was destroyed with the jump client still open. Every connection
/// through a jump host leaked one, and a status poll that keeps failing on the
/// target's host key leaked one per attempt.
///
/// Everything is the channel's; the only addition is that closing this closes
/// the client behind it, which is the ownership the return type could not
/// express.
class _JumpSocket implements SSHSocket {
  _JumpSocket(this._inner, this._jumpClient);

  final SSHSocket _inner;
  final SSHClient _jumpClient;

  @override
  Stream<Uint8List> get stream => _inner.stream;

  @override
  StreamSink<List<int>> get sink => _inner.sink;

  @override
  Future<void> get done => _inner.done;

  @override
  Future<void> close() async {
    try {
      await _inner.close();
    } finally {
      _jumpClient.close();
    }
  }

  @override
  void destroy() {
    try {
      _inner.destroy();
    } finally {
      _jumpClient.close();
    }
  }

  @override
  Future<void> flush() => _inner.flush();
}


List<Spi> _resolveJumpCandidates({
  required Spi spi,
  required Spi? preloadedJumpSpi,
  required Map<String, Spi>? jumpSpisById,
}) {
  final candidates = <Spi>[];
  for (final jumpId in spi.resolvedJumpIds) {
    final candidate = preloadedJumpSpi?.id == jumpId
        ? preloadedJumpSpi
        : jumpSpisById?[jumpId] ?? Stores.server.fetchOneRaw(jumpId);
    if (candidate == null || candidates.any((e) => e.id == candidate.id)) {
      continue;
    }
    candidates.add(candidate);
  }
  return candidates;
}

bool isJumpFailoverError(Object error) {
  final errStr = error.toString().toLowerCase();
  // Exclude auth failures that also contain "too many" (e.g. "too many authentication failures").
  if (errStr.contains('auth') ||
      errStr.contains('permission denied') ||
      errStr.contains('access denied')) {
    return false;
  }
  return errStr.contains('timed out') ||
      errStr.contains('timeout') ||
      errStr.contains('connection refused') ||
      errStr.contains('connection reset') ||
      errStr.contains('connection closed') ||
      errStr.contains('no route to host') ||
      errStr.contains('network unreachable') ||
      errStr.contains('network is unreachable') ||
      errStr.contains('socketexception') ||
      errStr.contains('failed host lookup') ||
      errStr.contains('forwardlocal') ||
      errStr.contains('proxycommand exited') ||
      errStr.contains('proxycommand timed out') ||
      errStr.contains('channel open failed') ||
      errStr.contains('maxsessions') ||
      (errStr.contains('too many') && errStr.contains('session')) ||
      (errStr.contains('session') &&
          errStr.contains('failed') &&
          !errStr.contains('auth'));
}

Future<void> ensureKnownHostKey(
  Spi spi, {
  Duration timeout = const Duration(seconds: 5),
  SSHKeyboardInteractiveHandler? onKeyboardInteractive,
  Map<String, Spi>? jumpSpisById,
  Set<String>? visitedServerIds,
}) async {
  // Bound once, up front: everything below needs SSH, and a server reached
  // only over monitor's HTTP API has no credential to connect with
  final ssh = spi.ssh;
  if (ssh == null) {
    throw SSHErr(
      type: SSHErrType.connect,
      message: 'No SSH credential configured for ${spi.name}',
    );
  }

  final chainVisitedServerIds = visitedServerIds ?? <String>{};
  final currentServerId = hostKeyServerId(spi);
  if (!chainVisitedServerIds.add(currentServerId)) {
    throw SSHErr(
      type: SSHErrType.connect,
      message:
          'Invalid jump chain: cycle detected at ${spi.name} ($currentServerId)',
    );
  }
  final addrKey2 = 'addr:${ssh.ip}:${ssh.port}';
  if (!chainVisitedServerIds.add(addrKey2)) {
    throw SSHErr(
      type: SSHErrType.connect,
      message: 'Invalid jump chain: address cycle at ${ssh.ip}:${ssh.port}',
    );
  }

  final cache = loadKnownHostFingerprints();

  for (final jumpSpi in _resolveJumpCandidates(
    spi: spi,
    preloadedJumpSpi: null,
    jumpSpisById: jumpSpisById,
  )) {
    if (!hasKnownHostFingerprint(jumpSpi, cache)) {
      await ensureKnownHostKey(
        jumpSpi,
        timeout: timeout,
        onKeyboardInteractive: onKeyboardInteractive,
        jumpSpisById: jumpSpisById,
        visitedServerIds: {...chainVisitedServerIds},
      );
      cache.addAll(loadKnownHostFingerprints());
    }
  }

  if (hasKnownHostFingerprint(spi, cache)) {
    return;
  }

  final client = await genClient(
    spi,
    timeout: timeout,
    onKeyboardInteractive: onKeyboardInteractive,
    knownHostFingerprints: cache,
  );

  try {
    await client.authenticated;
  } finally {
    client.close();
  }
}
