import 'dart:async';
import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/core/local/server.dart';
import 'package:server_box/core/ssh/exec.dart';
import 'package:server_box/core/utils/privileged_exec.dart';
import 'package:server_box/core/utils/sudo_password.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/model/virt/virt_backup.dart';
import 'package:server_box/data/model/virt/virt_backup_schedule.dart';
import 'package:server_box/data/model/virt/virt_console.dart';
import 'package:server_box/data/model/virt/virt_create.dart';
import 'package:server_box/data/model/virt/virt_detail.dart';
import 'package:server_box/data/model/virt/virt_error.dart';
import 'package:server_box/data/model/virt/virt_hardware.dart';
import 'package:server_box/data/model/virt/virt_manage.dart';
import 'package:server_box/data/model/virt/virt_resources.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/provider/virt/backend.dart';
import 'package:server_box/src/rust/api/create.dart' as cr;
import 'package:server_box/src/rust/api/exec_session.dart' show SudoEntry;
import 'package:server_box/src/rust/api/hardware.dart' as hw;
import 'package:server_box/src/rust/api/pve.dart' show PveError;
import 'package:server_box/src/rust/api/resource.dart' as res;
import 'package:server_box/src/rust/api/script.dart' as script_ffi;
import 'package:server_box/src/rust/api/virt.dart' as ffi;
import 'package:server_box/src/rust/api/virt_libvirt.dart' as vl;
import 'package:server_box/src/rust/api/virt_model.dart' as vm;
import 'package:server_box/src/rust/api/virt_view.dart' as vv;

part 'libvirt/snapshots.dart';
part 'libvirt/create.dart';
part 'libvirt/clone.dart';
part 'libvirt/storage.dart';
part 'libvirt/manage.dart';
part 'libvirt/hardware.dart';

/// libvirt through `virsh`, run by `ServerNotifier.ensureExec()` — so over
/// SSH, over a monitor agent that grants access, or on this device.
///
/// Scripts and parsers are `sbm_virt::libvirt`'s (FFI). Every script is POSIX
/// `sh`, fed to `sh` on stdin, never run as the login shell's command line.
///
/// **Permissions.** `qemu:///system` wants root or the `libvirt` group. When
/// the daemon refuses this account the script runs again through sudo
/// (`PrivilegedExec`): passwordless first, and when that needs a password,
/// [VirtErrType.sudoPasswordRequired] until [provideSudoPassword]. The
/// password travels on sudo's stdin, never in the command, and lives in this
/// object only. Once sudo was needed, later calls go straight to it.
class LibvirtBackend extends _LibvirtCore with _Snapshots, _Storage, _Hardware, _Create, _Clone, _Manage {
  LibvirtBackend({
    required super.serverId,
    required super.exec,
    super.byteExec,
    super.canStream,
    super.now,
    super.knownSudoPassword,
    super.onSudoRejected,
    @visibleForTesting super.seedTools,
    @visibleForTesting super.uploadReadyTimeout,
  });

  /// Uploads go over whatever of the server carries bytes: its SSH
  /// connection, whichever transport leads for everything else, or this
  /// device's own process.
  factory LibvirtBackend.of(Ref ref, String serverId) {
    bool local() => ref.read(serverProvider(serverId)).spi.local;
    return LibvirtBackend(
      serverId: serverId,
      exec: () => ref.read(serverProvider(serverId).notifier).ensureExec(),
      knownSudoPassword: () => SudoPassword.known(serverId),
      onSudoRejected: () => SudoPassword.forget(serverId),
      // TODO: upload over the Monitor too (its file API, or a byte-stream
      // exec); today an image goes up only through SSH or on this device.
      canStream: () =>
          local() || ref.read(serverProvider(serverId)).capabilities.byteStream,
      byteExec: () async => local()
          ? LocalServer.exec()
          : SshExec(
              await ref.read(serverProvider(serverId).notifier).ensureShellClient(),
            ),
    );
  }

  @override
  VirtHostKind get kind => VirtHostKind.libvirt;

  /// The host probe: whether this server is Proxmox VE, a container, or has
  /// a `virsh` that answers.
  ///
  /// A daemon refusing this account still makes this a libvirt host: the
  /// error is thrown, and the host list counts [VirtErrType.permissionDenied]
  /// and the sudo types as "found".
  Future<vl.VirtHostProbe> probe() => _run(ffi.virtProbeScript(), ffi.virtLibvirtProbe);

  @override
  Future<VirtSnapshot> load() async {
    // Checked here as well as by [_rates] below: the check is what tells a
    // refusal [_run] answers with sudo from a listing.
    final raw = await _run(ffi.virtOverviewScript(), ({required String raw}) async {
      await ffi.virtOverviewCheck(raw: raw);
      return raw;
    });
    final at = _now();
    await _readPoolTypes();
    final vv.VirtHostReport view;
    try {
      view = _rates.view(
        raw: raw,
        atMs: at.millisecondsSinceEpoch,
        poolTypes: _poolTypes,
        upload: _byteExec != null && (_canStream?.call() ?? false),
      );
    } on ffi.VirtFfiError catch (e) {
      throw _toErr(e);
    }
    return view.snapshotOf(serverId);
  }

  @override
  Future<void> power(VirtGuest guest, VirtPowerAction action) async {
    // A crashed domain's start is a destroy first (`sbm_virt::libvirt::host`).
    final plan = ffi.virtLibvirtPowerPlan(
      stateReason: guest.stateReason,
      offered: [for (final a in guest.actions) _kindOf(a)],
      action: _kindOf(action),
    );
    if (plan == null) {
      throw VirtErr(
        type: VirtErrType.unsupported,
        message: '${action.name} is not offered for ${guest.name}',
      );
    }
    for (final (i, step) in plan.indexed) {
      try {
        await _action(step, guest.id);
      } on VirtErr catch (e) {
        // The destroy before a crashed domain's start: already gone.
        final gone =
            plan.length > 1 &&
            i == 0 &&
            e.cause is ffi.VirtFfiError &&
            (e.cause as ffi.VirtFfiError).kind == ffi.VirtErrorKind.invalidState;
        if (!gone) rethrow;
      }
    }
  }

  Future<void> _action(ffi.VirtActionKind kind, String domain) async {
    await _run(
      ffi.virtActionScript(action: kind, domain: domain),
      ({required String raw}) async {
        ffi.parseVirtAction(raw: raw);
        return '';
      },
      action: true,
    );
  }

  @override
  Future<VirtGuestDetail> detail(VirtGuest guest) async => (await _run(
    ffi.virtDomainDetailScript(domain: guest.id),
    ({required String raw}) async => ffi.virtLibvirtGuestDetail(raw: raw),
  )).virt;

  @override
  Future<VirtConsole> console(VirtGuest guest, VirtConsoleKind kind) async {
    switch (kind) {
      case VirtConsoleKind.text:
        return LibvirtSerialConsole(
          command: ffi.virtConsoleCommand(domain: guest.id),
          needsRoot: _viaSudo,
        );
      case VirtConsoleKind.vnc:
        final info = await _run(ffi.virtVncConsoleScript(domain: guest.id), ffi.virtLibvirtVncConsole);
        final display = info.display;
        final port = display?.port;
        if (display == null || display.protocol != 'vnc' || port == null) {
          throw VirtErr(
            type: VirtErrType.unsupported,
            message: display == null
                ? 'No VNC display while ${guest.name} is not running'
                : 'The display is ${display.uri}, not a VNC port',
          );
        }
        return LibvirtVncConsole(
          host: _dialHost(display.host),
          port: port,
          password: info.password,
          passwordKnown: info.passwordKnown,
        );
    }
  }
}

/// What every part of [LibvirtBackend] stands on: how it reaches the host,
/// sudo, and running a script.
abstract class _LibvirtCore implements VirtBackend {
  _LibvirtCore({
    required this.serverId,
    required Future<CommandExec> Function() exec,
    Future<CommandByteExec> Function()? byteExec,
    bool Function()? canStream,
    DateTime Function()? now,
    Future<String?> Function()? knownSudoPassword,
    void Function()? onSudoRejected,
    @visibleForTesting this.seedTools,
    @visibleForTesting this.uploadReadyTimeout = const Duration(seconds: 60),
  }) : _exec = exec,
       _byteExec = byteExec,
       _canStream = canStream,
       _knownSudoPassword = knownSudoPassword,
       _onSudoRejected = onSudoRejected,
       _now = now ?? DateTime.now;

  /// The ISO tools a cloud-init seed may be made with, in order; null: all
  /// of them, in `sbm_virt`'s order. The end-to-end tests narrow it to
  /// make a seed with each tool in turn.
  final List<String>? seedTools;

  /// How long the upload command may take to say it is ready: a shell,
  /// sudo and `read` — seconds at most.
  final Duration uploadReadyTimeout;

  @override
  final String serverId;

  final Future<CommandExec> Function() _exec;
  final Future<CommandByteExec> Function()? _byteExec;
  final bool Function()? _canStream;
  final DateTime Function() _now;
  /// Each guest's last counters, which the next load's usage is diffed
  /// against (`sbm_virt::libvirt::host`).
  final _rates = ffi.LibvirtRates();

  /// This account reaches the daemon only through sudo.
  bool _viaSudo = false;
  String? _sudoPassword;

  /// The sudo password known before this backend asks: one typed for this
  /// server elsewhere this session, or saved with it (`SudoPassword`).
  final Future<String?> Function()? _knownSudoPassword;

  /// Told when sudo refused the password, so it is not offered again.
  final void Function()? _onSudoRejected;
  bool _knownSudoRead = false;

  void _forgetSudoPassword() {
    _sudoPassword = null;
    _onSudoRejected?.call();
  }

  bool get needsSudo => _viaSudo;

  /// The pool types the daemon has a backend for, read once
  /// (`pool-capabilities`); null until read, or where the host could not
  /// say (every type is offered then).
  List<String>? _poolTypes;
  bool _poolTypesRead = false;

  /// [_poolTypes], read on the first [load] that gets this far. A daemon
  /// that gains a backend (LVM installed, the daemon restarted) is seen by
  /// a new backend: this one keeps what it read.
  Future<void> _readPoolTypes() async {
    if (_poolTypesRead) return;
    try {
      _poolTypes = await _run(
        ffi.virtPoolTypesScript(),
        ({required String raw}) async => ffi.parseVirtPoolTypes(raw: raw),
      );
      _poolTypesRead = true;
    } on VirtErr catch (e, s) {
      Loggers.app.info('Virtualization pool capabilities: $e', e, s);
    }
  }

  /// The sudo password for this server, typed by the user after
  /// [VirtErrType.sudoPasswordRequired]. Kept in memory for this backend's
  /// life, and by `SudoPassword` for the session (the provider's
  /// `provideSudoPassword`); a rejected one is forgotten by both.
  void provideSudoPassword(String password) {
    _sudoPassword = password.isEmpty ? null : password;
    _viaSudo = true;
  }

  /// Runs [script] and parses its output, going through sudo when the daemon
  /// refuses this account.
  Future<T> _run<T>(
    String script,
    Future<T> Function({required String raw}) parse, {
    bool action = false,
  }) async {
    final CommandExec exec;
    try {
      exec = await _exec();
    } catch (e) {
      throw _unreachable(e);
    }

    ffi.VirtFfiError? refused;
    if (!_viaSudo) {
      final result = await _exec1(() => exec.run(script, entry: 'sh'));
      try {
        return await parse(raw: result.combined);
      } on ffi.VirtFfiError catch (e) {
        if (e.kind != ffi.VirtErrorKind.permissionDenied) {
          throw _toErr(e, action: action);
        }
        Loggers.app.info('virsh refused on $serverId, trying sudo');
        refused = e;
        _viaSudo = true;
      }
    }

    // Asked once per backend: every call through sudo passes here, and the
    // saved password is behind a rate-limited store.
    if (!_knownSudoRead) {
      _knownSudoRead = true;
      _sudoPassword ??= await _knownSudoPassword?.call();
    }
    final password = _sudoPassword;
    final result = await _exec1(
      () => PrivilegedExec.run(
        exec,
        script,
        isRoot: false,
        password: password,
      ),
    );
    if (result.sudoRejected) {
      if (password == null) {
        throw const VirtErr(
          type: VirtErrType.sudoPasswordRequired,
          message: 'sudo needs a password to reach libvirt',
        );
      }
      _forgetSudoPassword();
      throw const VirtErr(
        type: VirtErrType.sudoPasswordRejected,
        message: 'sudo rejected the password',
      );
    }
    try {
      return await parse(raw: result.combined);
    } on ffi.VirtFfiError catch (e) {
      // Output that is not the script's is sudo itself failing — not
      // installed, or this account not in sudoers. What the user has to change
      // is libvirt's permission, so that is what is reported, with sudo's
      // words after it.
      if (e.kind == ffi.VirtErrorKind.malformed) {
        throw VirtErr(
          type: VirtErrType.permissionDenied,
          message: [
            ?refused?.message,
            result.combined.trim(),
          ].where((m) => m.isNotEmpty).join('\n'),
          cause: e,
        );
      }
      throw _toErr(e, action: action);
    }
  }

  Future<ExecResult> _exec1(Future<ExecResult> Function() run) async {
    try {
      return await run();
    } catch (e) {
      throw _unreachable(e);
    }
  }

  VirtErr _unreachable(Object e) {
    if (e is VirtErr) return e;
    if (e is ServerTcpErr && e.type == ServerTcpErrType.relayNotGranted) {
      return VirtErr(
        type: VirtErrType.relayNotGranted,
        message: e.message,
        cause: e,
      );
    }
    // The agent was reached and said no. "Could not reach this host" would
    // send the user looking at the network instead of at the agent's config.
    if (e is MonitorHttpErr && e.type == MonitorHttpErrType.notGranted) {
      return VirtErr(
        type: VirtErrType.execNotGranted,
        message: e.message,
        cause: e,
      );
    }
    return VirtErr(type: VirtErrType.unreachable, message: '$e', cause: e);
  }
}

ffi.VirtActionKind _kindOf(VirtPowerAction action) => switch (action) {
  VirtPowerAction.start => ffi.VirtActionKind.start,
  VirtPowerAction.shutdown => ffi.VirtActionKind.shutdown,
  VirtPowerAction.reboot => ffi.VirtActionKind.reboot,
  VirtPowerAction.forceStop => ffi.VirtActionKind.forceStop,
  VirtPowerAction.suspend => ffi.VirtActionKind.suspend,
  VirtPowerAction.resume => ffi.VirtActionKind.resume,
};

/// A listen address as something to dial from the hypervisor: a wildcard
/// is the hypervisor itself.
String _dialHost(String? host) => switch (host) {
  null || '' || '0.0.0.0' || '::' || '[::]' => '127.0.0.1',
  final h => h,
};

VirtErr _toErr(ffi.VirtFfiError e, {bool action = false}) {
  final type = switch (e.kind) {
    ffi.VirtErrorKind.notInstalled => VirtErrType.notInstalled,
    ffi.VirtErrorKind.permissionDenied => VirtErrType.permissionDenied,
    ffi.VirtErrorKind.connectFailed => VirtErrType.unreachable,
    ffi.VirtErrorKind.malformed => VirtErrType.invalidResponse,
    ffi.VirtErrorKind.conflict => VirtErrType.conflict,
    // `exists` too: a snapshot name taken is the action refused, with the
    // host's words. Creating a guest tells it apart itself.
    ffi.VirtErrorKind.domainNotFound ||
    ffi.VirtErrorKind.invalidState ||
    ffi.VirtErrorKind.exists ||
    ffi.VirtErrorKind.command =>
      action ? VirtErrType.actionFailed : VirtErrType.unknown,
  };
  return VirtErr(
    type: type,
    message: e.message.isEmpty ? e.kind.name : e.message,
    cause: e,
  );
}

/// A script the parser refused to write: what it was given is this app's
/// fault, not the host's.
String _script(String Function() build) {
  try {
    return build();
  } on ffi.VirtFfiError catch (e) {
    throw VirtErr(type: VirtErrType.unsupported, message: e.message, cause: e);
  }
}

VirtErr _existsOr(VirtErr e) => switch (e.cause) {
  ffi.VirtFfiError(kind: ffi.VirtErrorKind.exists) => VirtErr(
    type: VirtErrType.exists,
    message: e.message == ffi.VirtErrorKind.exists.name ? null : e.message,
    cause: e.cause,
  ),
  _ => e,
};

/// A rule or a mapping of `sbm_virt`'s, its refusal as a [VirtErr].
T _rule<T>(T Function() f) {
  try {
    return f();
  } on PveError catch (e) {
    throw e.virt;
  }
}

Future<String> _parseResource({required String raw}) async {
  ffi.parseVirtResource(raw: raw);
  return '';
}

/// What one upload attempt came to.
enum _Streamed { done, cancelled, notStarted }
