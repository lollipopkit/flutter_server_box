/// SSH plumbing shared by the opt-in end-to-end tests: configuration from the
/// environment or the workspace `.env`, the connection parameters `ssh -G`
/// resolves for a destination, and a dartssh2 client — the one the app uses —
/// authenticated with the first identity that loads.
///
/// - `SBM_E2E_SSH_IDENTITY`: a private key file tried before the ones `ssh -G`
///   names.
/// - `SBM_E2E_SSH_KEY_PASSPHRASE`: the passphrase of an encrypted key.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

/// [key] from the environment, else from the workspace-root `.env`.
String? e2eEnv(String key) {
  final fromEnv = Platform.environment[key];
  if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;

  // Workspace-root `.env`, the same file the Rust suite reads. Parsed rather
  // than sourced: only this one key matters and nothing here should inherit
  // the rest of that file.
  final dotenv = File('.env');
  if (!dotenv.existsSync()) return null;
  for (final line in dotenv.readAsLinesSync()) {
    final trimmed = line.trim();
    if (!trimmed.startsWith('$key=')) continue;
    final value = trimmed.substring(key.length + 1).trim().replaceAll(
      RegExp(r'''^["']|["']$'''),
      '',
    );
    if (value.isNotEmpty) return value;
  }
  return null;
}

/// What the system `ssh` would use for [host], so an alias in `~/.ssh/config`
/// works here as it does there. dartssh2 does not read that file.
class SshE2eTarget {
  SshE2eTarget({
    required this.hostname,
    required this.port,
    required this.user,
    required this.identityFiles,
  });

  final String hostname;
  final int port;
  final String user;
  final List<String> identityFiles;

  /// The target, or why there is none — and never a throw.
  ///
  /// `ssh` not being on PATH is a `ProcessException`, and this runs from
  /// `main()`: uncaught, the runner reports the *file* as having failed to
  /// load, with a stack trace, no test name and no mention of `ssh`.
  static Future<({SshE2eTarget? target, String? problem})> resolve(
    String host,
  ) async {
    final ProcessResult result;
    try {
      result = await Process.run('ssh', ['-G', host]);
    } on ProcessException catch (e) {
      return (target: null, problem: 'could not run `ssh -G $host`: ${e.message}');
    }
    if (result.exitCode != 0) {
      return (target: null, problem: 'ssh -G could not resolve $host');
    }

    String? hostname, user;
    var port = 22;
    // A key named for the tests goes first. dartssh2 cannot ask an agent, so
    // a machine whose own keys are encrypted and agent-held needs one.
    final identities = <String>[?e2eEnv('SBM_E2E_SSH_IDENTITY')];
    for (final line in const LineSplitter().convert(result.stdout as String)) {
      final space = line.indexOf(' ');
      if (space < 0) continue;
      final key = line.substring(0, space);
      final value = line.substring(space + 1).trim();
      switch (key) {
        case 'hostname':
          hostname = value;
        case 'user':
          user = value;
        case 'port':
          port = int.tryParse(value) ?? 22;
        case 'identityfile':
          identities.add(
            value.startsWith('~')
                ? value.replaceFirst('~', Platform.environment['HOME'] ?? '~')
                : value,
          );
      }
    }
    if (hostname == null || user == null) {
      return (target: null, problem: 'ssh -G named no hostname or user for $host');
    }
    return (
      target: SshE2eTarget(
        hostname: hostname,
        port: port,
        user: user,
        identityFiles: identities,
      ),
      problem: null,
    );
  }

  /// The first identity that loads, and why each of the others did not.
  ///
  /// Decrypts with `SBM_E2E_SSH_KEY_PASSPHRASE` when one is set. Nothing
  /// prompts: a test that blocks on a passphrase is the hang this file exists
  /// to measure.
  ///
  /// **[reasons] is the point of the return type.** This used to swallow every
  /// exception and answer an empty list, so a blank passphrase, a wrong one, a
  /// key format the fork does not read and a path that is not there all failed
  /// identically — and the failure the runner printed was a guess written into
  /// the `reason:` of an `expect`. Every one of those has a different fix, and
  /// the loader is the only place that knows which it was.
  ///
  /// [failures] is the subset of [reasons] for keys that were *tried* and did
  /// not open: a wrong passphrase, or a format this fork cannot read. Those are
  /// a broken setup rather than an opt-out — a rotated passphrase would
  /// otherwise leave this suite green with the regression it exists for no
  /// longer running — so the caller fails on them. A key that is absent, or
  /// encrypted with no passphrase configured, is an opt-out and only skips.
  ({List<SSHKeyPair> pairs, List<String> reasons, List<String> failures})
  loadIdentities() {
    final passphrase = e2eEnv('SBM_E2E_SSH_KEY_PASSPHRASE');
    final reasons = <String>[];
    final failures = <String>[];
    for (final path in identityFiles) {
      // The basename, never the path: `ssh -G` resolves `~`, and a home
      // directory is a username. This text ends up in CI logs.
      final name = path.split(Platform.pathSeparator).last;
      final file = File(path);
      if (!file.existsSync()) {
        reasons.add('$name: not on this machine');
        continue;
      }
      final pem = file.readAsStringSync();
      final encrypted = SSHKeyPair.isEncryptedPem(pem);
      if (encrypted && passphrase == null) {
        // The case that cost an afternoon: `.env` carried the key with an
        // empty value, which `_env` reads as unset — correctly — and the
        // failure then blamed the identity file.
        //
        // A skip, not a failure: this is the one case answerable without
        // trying, and it says the secret was never configured. Every ordinary
        // machine has an encrypted key in `~/.ssh`, so failing here would turn
        // `flutter test` red for anyone who named a host and nothing else.
        reasons.add(
          '$name: encrypted, and SBM_E2E_SSH_KEY_PASSPHRASE is empty or unset',
        );
        continue;
      }
      try {
        final pairs = SSHKeyPair.fromPem(pem, encrypted ? passphrase : null);
        if (pairs.isNotEmpty) {
          return (pairs: pairs, reasons: reasons, failures: failures);
        }
        final reason = '$name: parsed, but carried no key pair';
        reasons.add(reason);
        failures.add(reason);
      } catch (e) {
        // The message, not the object: a wrong passphrase and a format this
        // fork cannot read both arrive here and read differently.
        final reason = '$name: $e';
        reasons.add(reason);
        failures.add(reason);
      }
    }
    return (pairs: const [], reasons: reasons, failures: failures);
  }
}

/// Whether [host]:[port] accepts a TCP connection within [within].
///
/// The suites below reach hosts that are virtual machines themselves — a PVE
/// node's guest is the libvirt host the virt tests use — and one left shut
/// down does not fail them: it makes every connection attempt sit in
/// `SYN_SENT` until something times it out. That is a machine that is not
/// there, which reads as a broken test run rather than as a switched-off VM,
/// and it costs the whole `@Timeout` before saying so.
///
/// So a suite asks first, with a bound, and skips when nothing answers. Not a
/// failure: the host being down is the operator's own state, not a defect in
/// the change under test.
Future<bool> e2eReachable(
  String host,
  int port, {
  Duration within = const Duration(seconds: 5),
}) async {
  try {
    final socket = await Socket.connect(host, port, timeout: within);
    socket.destroy();
    return true;
  } catch (_) {
    return false;
  }
}

/// [host]'s SSH destination and a loaded identity, or a skip that names what
/// is missing — [prepareSshE2e] plus the TCP check above.
///
/// Use this instead of [prepareSshE2e] in a suite that talks to the host
/// itself: it turns "the machine is off" into an immediate, named skip rather
/// than a run that appears to hang.
Future<({SshE2eTarget? target, List<SSHKeyPair> identities, String? skip, String? failure})>
prepareReachableSshE2e(String host) async {
  final ready = await prepareSshE2e(host);
  final target = ready.target;
  if (target == null) return ready;
  if (!await e2eReachable(target.hostname, target.port)) {
    return (
      target: null,
      identities: const <SSHKeyPair>[],
      skip: '${target.hostname}:${target.port} is not reachable '
          '(the host may be shut down)',
      failure: null,
    );
  }
  return ready;
}

Future<SSHClient> connectSshE2e(SshE2eTarget target, List<SSHKeyPair> identities) async {
  final socket = await SSHSocket.connect(
    target.hostname,
    target.port,
    timeout: const Duration(seconds: 10),
  );
  final client = SSHClient(
    socket,
    username: target.user,
    identities: identities,
    // The app pins host keys; this test is about the data path, and asking it
    // to also carry a known-hosts store would only give it a second way to fail
    disableHostkeyVerification: true,
  );
  await client.authenticated;
  return client;
}

/// Run [command], write [input] to its stdin, close it, and collect what came
/// back. The shape the app uses in `ServerNotifier`: `stdin.add` then
/// `stdin.close`, with nothing read until the command is done.
///
/// Bounded by [within] as a whole — opening the channel, the exec request,
/// stdin and the output included — because `session.done` never completes on
/// a connection that died under it, and a host that goes down mid-run would
/// otherwise leave this awaiting forever. The suites here are [`@Timeout`]d,
/// but that clock covers the test body; the *teardown* that restores the
/// host's guests runs after it, and an unbounded await there hangs the whole
/// run with no verdict at all.
///
/// Past [within] this throws [TimeoutException] after closing the session, so
/// a caller never mistakes partial output for a finished command, and the
/// next command does not start beside one still running.
Future<({int? exitCode, String stdout, String stderr})> execSshE2e(
  SSHClient client,
  String command,
  Uint8List? input, {
  Duration within = const Duration(seconds: 30),
}) async {
  SSHSession? session;
  var abandoned = false;
  final stdout = <int>[];
  final stderr = <int>[];
  final subs = <StreamSubscription<Uint8List>>[];
  Future<void> run() async {
    final s = await client.execute(command);
    // The deadline passed while the channel was opening: nobody is waiting.
    if (abandoned) {
      s.close();
      return;
    }
    session = s;
    final out = Completer<void>();
    final err = Completer<void>();
    subs
      ..add(s.stdout.listen(stdout.addAll, onDone: out.complete))
      ..add(s.stderr.listen(stderr.addAll, onDone: err.complete));
    if (input != null) {
      s.stdin.add(input);
      await s.stdin.close();
    }
    await s.done;
    await Future.wait([out.future, err.future]);
  }

  try {
    await run().timeout(within);
  } on TimeoutException {
    abandoned = true;
    throw TimeoutException('`$command` did not finish', within);
  } finally {
    for (final sub in subs) {
      await sub.cancel();
    }
    session?.close();
  }
  return (
    exitCode: session?.exitCode,
    stdout: utf8.decode(stdout, allowMalformed: true),
    stderr: utf8.decode(stderr, allowMalformed: true),
  );
}

/// Whether an end-to-end test against [host] can run here: the resolved
/// target and a loaded identity, or why not.
///
/// The rule is the Windows install test's: an unresolvable host or a key that
/// was tried and would not open is a broken setup ([failure]); no identity
/// available at all is an opt-out ([skip]).
Future<({SshE2eTarget? target, List<SSHKeyPair> identities, String? skip, String? failure})>
prepareSshE2e(String host) async {
  final resolved = await SshE2eTarget.resolve(host);
  final target = resolved.target;
  if (target == null) {
    return (
      target: null,
      identities: const <SSHKeyPair>[],
      skip: null,
      failure: resolved.problem ?? 'ssh -G could not resolve $host',
    );
  }
  final loaded = target.loadIdentities();
  if (loaded.pairs.isNotEmpty) {
    return (target: target, identities: loaded.pairs, skip: null, failure: null);
  }
  if (loaded.failures.isNotEmpty) {
    return (
      target: null,
      identities: const <SSHKeyPair>[],
      skip: null,
      failure:
          'every identity ssh -G named for $host failed to load: '
          '${loaded.failures.join('; ')}',
    );
  }
  return (
    target: null,
    identities: const <SSHKeyPair>[],
    skip: loaded.reasons.isEmpty
        ? 'ssh -G named no identity files for $host'
        : 'no identity ssh -G named is available here: '
              '${loaded.reasons.join('; ')}',
    failure: null,
  );
}
