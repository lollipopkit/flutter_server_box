import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/bmc_cfg.dart';
import 'package:server_box/data/model/server/custom.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/model/server/wol_cfg.dart';
import 'package:server_box/data/store/server.dart';

part 'server_private_info.freezed.dart';
part 'server_private_info.g.dart';

enum SpiValidationError {
  jumpServerAndProxyCommandConflict,

  /// Neither [Spi.ssh] nor [Spi.monitorHttp] is configured.
  ///
  /// This used to be the opposite complaint — carrying *both* was the error.
  /// A server may now carry both, with [Spi.preferredTransport] saying which
  /// is tried first; what it still may not do is carry neither, which is a
  /// name and an address of nothing.
  noConnectionMethod,
}

/// Which way of reaching a server is tried first.
///
/// Only meaningful when both are configured. Stored **by name**, never by
/// index: an index silently changes meaning when a case is inserted, and this
/// outlives the build that wrote it.
enum ServerTransport {
  ssh,
  monitorHttp;

  static ServerTransport? fromName(Object? name) =>
      ServerTransport.values.firstWhereOrNull((e) => e.name == name);
}

class SpiValidationException implements Exception {
  const SpiValidationException(this.error);

  final SpiValidationError error;

  @override
  String toString() => 'SpiValidationException($error)';
}

/// In the first version, it's called `ServerPrivateInfo` which was designed to
/// store the private information of a server.
///
/// Some params named as `spi` in the codebase which is the abbreviation of `ServerPrivateInfo`.
///
/// Nowaday, more fields are added to this class, and it's renamed to `Spi`.
@freezed
abstract class Spi with _$Spi {
  const Spi._();

  @JsonSerializable(includeIfNull: false)
  const factory Spi({
    required String name,

    /// How to reach this server over SSH, or null if it isn't configured for
    /// SSH at all. A peer of [monitorHttp] — see `ServerConnectCredential`.
    ///
    /// Nested rather than flat (as `ip`/`port`/`user`/... used to be) so that
    /// "has SSH" is expressible. While they were flat and non-nullable, a
    /// monitor-only server had to invent an address and a user named
    /// `monitor` to satisfy them.
    SshCredential? ssh,

    /// Reach this server via a `monitor` instance's HTTP API. A peer of
    /// [ssh]; a server may carry either one, or both.
    MonitorHttpCredential? monitorHttp,

    /// Which of the two is tried first, when both are configured.
    ///
    /// Null on every server with only one way in, which is most of them, and
    /// on every record written before the two could coexist. Read through
    /// [Spix.transport], which resolves that.
    ///
    /// A name this build does not know reads as null rather than throwing.
    /// Without that, one unrecognised word makes `Spi.fromJson` fail and takes
    /// the *whole server record* with it — through a backup restore, a sync,
    /// or a shared QR code. A build that grows a third transport writes a word
    /// this one has never seen, and losing a server over it would be a far
    /// worse answer than falling back to the resolution [Spix.transport]
    /// already does for a preference that names nothing configured.
    @JsonKey(
      includeIfNull: false,
      unknownEnumValue: JsonKey.nullForUndefinedEnumValue,
    )
    ServerTransport? preferredTransport,
    List<String>? tags,
    @Default(true) bool autoConnect,
    ServerCustom? custom,
    WakeOnLanCfg? wolCfg,

    /// This server's BMC, or null when it has none configured. A side channel
    /// beside [wolCfg], not a way of reaching the host — see `BmcCfg`.
    BmcCfg? bmc,

    /// It only applies to SSH terminal.
    Map<String, String>? envs,
    @Default('') @JsonKey(fromJson: Spi.parseId) String id,

    /// Custom system type (unix or windows). If set, skip auto-detection.
    @JsonKey(includeIfNull: false) SystemType? customSystemType,

    /// Disabled command types for this server
    @JsonKey(includeIfNull: false) List<String>? disabledCmdTypes,
  }) = _Spi;

  /// Accepts both the nested layout and the pre-v3 flat one, so old backups,
  /// QR codes shared from older builds and `~/.ssh/config` imports keep
  /// working. Writing only ever produces the nested layout.
  factory Spi.fromJson(Map<String, dynamic> json) =>
      _$SpiFromJson(json.containsKey('ssh') ? json : _liftFlatSsh(json));

  /// Moves the pre-v3 top-level SSH keys under `ssh`.
  ///
  /// A record with none of them is left without SSH rather than given an
  /// empty one: absent means "not configured", and inventing a blank host
  /// would make it look reachable.
  static Map<String, dynamic> _liftFlatSsh(Map<String, dynamic> json) {
    const flatKeys = [
      'ip',
      'port',
      'user',
      'pwd',
      'pubKeyId',
      // Missing from this list, so a flat record carrying one decoded with no
      // key at all — silently turning an `IdentityFile` credential into
      // password auth. Listed whether or not any release wrote it flat: the
      // cost of naming a key nothing carries is nothing.
      'keyPath',
      'identityFiles',
      'alterUrl',
      'jumpId',
      'jumpIds',
      'proxyCommand',
    ];
    final ip = json['ip'];
    if (ip is! String || ip.isEmpty) return json;

    final lifted = Map<String, dynamic>.from(json)
      ..removeWhere((k, _) => flatKeys.contains(k));
    lifted['ssh'] = {
      for (final k in flatKeys)
        if (json[k] != null) k: json[k],
    };
    return lifted;
  }

  @override
  String toString() => 'Spi<$displayAddr>';

  /// Parse the [id], if it's null or empty, generate a new one.
  static String parseId(Object? id) {
    if (id == null || id is! String || id.isEmpty) return ShortId.generate();
    return id;
  }
}

extension Spix on Spi {
  /// Shorthand for the SSH-only helpers; null when this server has no SSH
  /// configuration, which callers must handle rather than assume away.
  List<String> get resolvedJumpIds => ssh?.resolvedJumpIds ?? const [];

  String? get firstJumpId => ssh?.firstJumpId;

  SpiValidationError? validate() {
    final s = ssh;
    if (s == null && monitor == null) {
      return SpiValidationError.noConnectionMethod;
    }
    if (s == null) return null;
    final hasJumpServer = s.resolvedJumpIds.isNotEmpty;
    final proxy = s.proxyCommand;
    final hasProxyCommand = proxy != null && proxy.trim().isNotEmpty;
    if (hasJumpServer && hasProxyCommand) {
      return SpiValidationError.jumpServerAndProxyCommandConflict;
    }
    return null;
  }

  void validateOrThrow() {
    final validationError = validate();
    if (validationError == null) return;
    throw SpiValidationException(validationError);
  }

  /// An address to identify this server by in logs and lists. Prefers SSH,
  /// falls back to the monitor endpoint for servers that have no SSH
  /// configuration, and finally to the opaque [Spi.id].
  String get displayAddr {
    final s = ssh;
    // A tunneled server has no address of its own — showing `user@:22` would
    // be noise, and showing `127.0.0.1` would be wrong on every such server
    if (s != null) return '${s.user}@${s.ip}:${s.port}';
    return monitorHttp?.addr ?? id;
  }

  /// Which way of reaching this server is tried first.
  ///
  /// With one configured there is nothing to prefer, and the answer is
  /// whichever exists — so a stored preference naming the *other* one is
  /// ignored rather than honoured into a dead end. That happens: turning a
  /// server's SSH off leaves the preference behind, and nothing clears it.
  ///
  /// With both, and nothing stored, SSH leads. Not arbitrary — it is what
  /// every such server was before this field existed, and it is the transport
  /// that can do everything, so a server that gains an agent does not quietly
  /// lose its terminal.
  ServerTransport get transport {
    final hasSsh = ssh != null;
    final hasMonitor = monitor != null;
    if (!hasMonitor) return ServerTransport.ssh;
    if (!hasSsh) return ServerTransport.monitorHttp;
    return preferredTransport ?? ServerTransport.ssh;
  }

  /// The other way in, when there is one.
  ServerTransport? get fallbackTransport {
    if (ssh == null || monitor == null) return null;
    return transport == ServerTransport.ssh
        ? ServerTransport.monitorHttp
        : ServerTransport.ssh;
  }

  /// This server's monitor agent, or null when it has none configured.
  MonitorHttpCredential? get monitor {
    final m = monitorHttp;
    if (m == null || m.addr.trim().isEmpty) return null;
    return m;
  }

  /// The pre-1155 storage key.
  ///
  /// SSH-only by construction: no install old enough to still be keyed this
  /// way could have had a monitor server, so [migrateId] bails out rather
  /// than inventing a key for one.
  String get oldId {
    final s = ssh;
    return s == null ? id : '${s.user}@${s.ip}:${s.port}';
  }

  /// Save the [Spi] to the local storage.
  void save() => ServerStore.instance.put(this);

  /// Migrate the [oldId] to the new generated [id] by [ShortId.generate].
  ///
  /// Returns:
  /// - `null` if the [id] is not empty.
  /// - The new [id] if the [id] is empty.
  String? migrateId() {
    if (id.isNotEmpty) return null;
    if (ssh == null) return null;
    ServerStore.instance.deleteById(oldId);
    final newSpi = copyWith(id: ShortId.generate());
    newSpi.save();
    return newSpi.id;
  }

  /// Json encode to string.
  String toJsonString() => json.encode(toJson());

  /// Returns true if the connection info is the same as [other].
  bool isSameAs(Spi other) {
    final a = ssh, b = other.ssh;
    if (a == null || b == null) return a == b;
    return a.isSameAs(b);
  }

  /// Returns true if the connection should be re-established.
  ///
  /// [ServerCustom.cmds] used to count: custom commands were spliced into the
  /// generated script, so changing one meant reinstalling the script, and the
  /// reconnect is what did that. They are files on the server now, written on
  /// their own, and reconnecting for them would only cost the user their
  /// session — including during the one-time migration, which edits this very
  /// field while the connection it would tear down is being set up.
  bool shouldReconnect(Spi old) {
    return !isSameAs(old) ||
        ssh?.alterUrl != old.ssh?.alterUrl ||
        monitorHttp != old.monitorHttp ||
        // Which transport leads decides where the status poll goes and which
        // connection `ensureExec` opens, so changing it has to tear down what
        // the old answer built.
        transport != old.transport;
  }

  /// Parse the SSH [SshCredential.alterUrl] to (ip, user, port).
  (String ip, String usr, int port) parseAlterUrl() {
    final s = ssh;
    if (s == null) {
      throw SSHErr(type: SSHErrType.connect, message: 'no ssh credential');
    }
    return s.parseAlterUrl();
  }

  /// Just for showing the struct of the class.
  ///
  /// **NOT** the default value.
  static final example = Spi(
    name: 'name',
    ssh: SshCredential(
      ip: 'ip',
      port: 22,
      user: 'root',
      pwd: 'pwd',
      keyId: 'private_key_id',
      alterUrl: 'user@ip:port',
      proxyCommand: 'socat - PROXY:proxy.example.com:%h:%p,proxyport=8080',
    ),
    tags: ['tag1', 'tag2'],
    autoConnect: true,
    custom: ServerCustom(
      pveAddr: 'http://localhost:8006',
      pveIgnoreCert: false,
      cmds: {'echo': 'echo hello'},
      preferTempDev: 'nvme-pci-0400',
      logoUrl: 'https://example.com/logo.png',
    ),
    id: 'id',
  );

  /// Returns true if the SSH user is 'root'.
  bool get isRoot => ssh?.isRoot ?? false;
}
