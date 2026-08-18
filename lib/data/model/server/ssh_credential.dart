import 'package:flutter/foundation.dart' show listEquals;
import 'package:json_annotation/json_annotation.dart';
import 'package:server_box/data/model/app/error.dart';

part 'ssh_credential.g.dart';

/// Everything needed to reach a server over SSH.
///
/// A peer of [MonitorHttpCredential], not the default: a server may carry
/// either, both, or (briefly, while being edited) neither. These fields used
/// to sit flat on [Spi] with `ip`/`port`/`user` non-nullable, which forced a
/// monitor-only server to invent an address and a user named `monitor` just to
/// satisfy them, and made "is SSH configured" impossible to express.
@JsonSerializable(includeIfNull: false)
final class SshCredential {
  final String ip;
  final int port;
  final String user;
  final String? pwd;

  /// [PrivateKeyInfo.id] of a key held in `Stores.key`, and nothing else.
  ///
  /// It used to mean that *or* a filesystem path, depending on who wrote it:
  /// `~/.ssh/config` import put an `IdentityFile` value straight in here while
  /// every reader looked it up as a store id, so an imported server could only
  /// ever fail to connect. The path now has [keyPath] to itself.
  @JsonKey(name: 'pubKeyId')
  final String? keyId;

  /// A private key on this machine's filesystem, as an `IdentityFile` line
  /// names one. Read when the connection is made, never copied into the app.
  ///
  /// Only ever set by `~/.ssh/config` import, which is desktop-only — there is
  /// no such file to point at on a phone. At most one of this and [keyId] is
  /// set; both being null means password or keyboard-interactive.
  final String? keyPath;

  /// Fallback `user@host:port` tried when [ip] is unreachable
  final String? alterUrl;

  /// [id] of the first jump server.
  ///
  /// Kept for compatibility with old storage and imports. New code should read
  /// [resolvedJumpIds] so failover candidates are included.
  final String? jumpId;

  /// Ordered jump-server candidates. At most the first two are used.
  final List<String>? jumpIds;

  final String? proxyCommand;

  /// Carry the SSH byte stream over this server's `monitor` agent instead of
  /// connecting to [ip]:[port] directly, for hosts whose SSH port isn't
  /// reachable but whose monitor endpoint is.
  ///
  /// A peer of [proxyCommand] and [jumpIds]: all three answer "where does the
  /// socket come from", so at most one may be set. The SSH session on top is
  /// unchanged — same authentication, and this app still verifies the host
  /// key itself, so the agent in the middle can't impersonate the server.
  ///
  const SshCredential({
    required this.ip,
    this.port = 22,
    this.user = 'root',
    this.pwd,
    this.keyId,
    this.keyPath,
    this.alterUrl,
    this.jumpId,
    this.jumpIds,
    this.proxyCommand,
  });

  factory SshCredential.fromJson(Map<String, dynamic> json) =>
      _$SshCredentialFromJson(json);

  Map<String, dynamic> toJson() => _$SshCredentialToJson(this);

  /// [jumpIds] first (at most two are ever used for failover), falling back
  /// to the legacy single [jumpId] only when that list yields nothing.
  List<String> get resolvedJumpIds {
    final ids = <String>[];
    void add(String? id) {
      if (id == null || id.isEmpty || ids.contains(id)) return;
      ids.add(id);
    }

    for (final id in jumpIds ?? const <String>[]) {
      add(id);
      if (ids.length >= 2) break;
    }
    if (ids.isEmpty) add(jumpId);
    return ids;
  }

  String? get firstJumpId {
    final ids = resolvedJumpIds;
    return ids.isEmpty ? null : ids.first;
  }

  /// One name for whichever key this credential uses, or null when it uses
  /// none.
  ///
  /// The transfer isolate is handed key material in a map it looks up by
  /// string, resolved for it on the main isolate (`SshTransferCreds`). That map
  /// was keyed by [keyId] alone, which cannot name a key that came from
  /// [keyPath] — so the two share one namespace here, with the path prefixed
  /// because a store id never contains a separator.
  String? get keyRef {
    final id = keyId;
    if (id != null) return id;
    final path = keyPath;
    return path == null ? null : 'path:$path';
  }

  /// Parses [alterUrl] into its (ip, user, port) parts. Throws [SSHErr] on any
  /// malformed input rather than guessing — the value is user-entered and a
  /// silent fallback would connect somewhere unintended.
  (String ip, String usr, int port) parseAlterUrl() {
    final url = alterUrl;
    if (url == null) {
      throw SSHErr(type: SSHErrType.connect, message: 'alterUrl is null');
    }
    final splited = url.split('@');
    if (splited.length != 2) {
      throw SSHErr(type: SSHErrType.connect, message: 'alterUrl no @');
    }
    final usr = splited[0];
    final idx = splited[1].lastIndexOf(':');
    if (idx == -1) {
      throw SSHErr(type: SSHErrType.connect, message: 'alterUrl no :');
    }
    final ip_ = splited[1].substring(0, idx);
    final port_ = int.tryParse(splited[1].substring(idx + 1));
    if (port_ == null || port_ <= 0 || port_ > 65535) {
      throw SSHErr(type: SSHErrType.connect, message: 'alterUrl port error');
    }
    return (ip_, usr, port_);
  }

  bool get isRoot => user == 'root';

  SshCredential copyWith({
    String? ip,
    int? port,
    String? user,
    Object? pwd = _unset,
    Object? keyId = _unset,
    Object? keyPath = _unset,
    Object? alterUrl = _unset,
    Object? jumpId = _unset,
    Object? jumpIds = _unset,
    Object? proxyCommand = _unset,
  }) {
    return SshCredential(
      ip: ip ?? this.ip,
      port: port ?? this.port,
      user: user ?? this.user,
      pwd: pwd == _unset ? this.pwd : pwd as String?,
      keyId: keyId == _unset ? this.keyId : keyId as String?,
      keyPath: keyPath == _unset ? this.keyPath : keyPath as String?,
      alterUrl: alterUrl == _unset ? this.alterUrl : alterUrl as String?,
      jumpId: jumpId == _unset ? this.jumpId : jumpId as String?,
      jumpIds: jumpIds == _unset
          ? this.jumpIds
          : (jumpIds as List<String>?),
      proxyCommand: proxyCommand == _unset
          ? this.proxyCommand
          : proxyCommand as String?,
    );
  }

  /// Whether reconnecting is required to move from [other] to this.
  bool isSameAs(SshCredential? other) {
    return other != null &&
        ip == other.ip &&
        port == other.port &&
        user == other.user &&
        pwd == other.pwd &&
        keyId == other.keyId &&
        keyPath == other.keyPath &&
        proxyCommand == other.proxyCommand &&
        // Changing how the socket is obtained needs a reconnect just as much
        // as changing the address does
        listEquals(resolvedJumpIds, other.resolvedJumpIds);
  }

  @override
  bool operator ==(Object other) {
    return other is SshCredential &&
        isSameAs(other) &&
        alterUrl == other.alterUrl;
  }

  @override
  int get hashCode => Object.hash(
    ip,
    port,
    user,
    pwd,
    keyId,
    keyPath,
    alterUrl,
    jumpId,
    Object.hashAll(jumpIds ?? const []),
    proxyCommand,
  );
}

/// Sentinel so [SshCredential.copyWith] can tell "leave as-is" from
/// "set to null" — a plain `null` default can't express clearing a field.
const _unset = Object();
